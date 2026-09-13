//
//  DallyeoAPIClient.swift
//  Dallyeo
//
//  BE 공통 HTTP 클라이언트 (GET/POST + ApiResponse 언래핑)
//

import Foundation

struct DallyeoAPIClient {

    static let shared = DallyeoAPIClient()

    var baseURL: URL = APIConfig.baseURL
    var session: URLSession = .shared

    /// 외부 API 지연으로 실패했을 때 다시 시도하기 전 대기 시간.
    private static let retryDelay: Duration = .milliseconds(300)

    // MARK: - GET

    /// GET 요청 후 `ApiResponse<T>`를 벗겨 `T` 반환.
    /// - query 값이 nil인 항목은 자동 생략.
    /// - retries: 외부 API 오류(502 / `EXTERNAL_API_ERROR`)일 때만 추가 시도 횟수.
    ///   `/places/*`는 TourAPI를 실시간 호출해 간헐적으로 502가 난다(API.md 9-3).
    func get<T: Decodable>(
        _ path: String,
        query: [String: String?] = [:],
        bearer: String? = nil,
        retries: Int = 0,
        as type: T.Type = T.self
    ) async throws -> T {
        var attempt = 0
        while true {
            do {
                let request = try makeRequest(path: path, method: "GET", query: query, bearer: bearer)
                let data = try await send(request)
                return try unwrap(data, as: T.self)
            } catch {
                guard attempt < retries, Self.isExternalAPIError(error) else { throw error }
                attempt += 1
                try? await Task.sleep(for: Self.retryDelay)
            }
        }
    }

    /// 외부 관광 API 지연/오류라서 재시도할 만한 실패인지.
    private static func isExternalAPIError(_ error: Error) -> Bool {
        switch error {
        case APIClientError.badStatus(502):                     true
        case APIClientError.business(let body):                 body.code == "EXTERNAL_API_ERROR"
        default:                                                false
        }
    }

    // MARK: - POST

    /// JSON 바디를 실어 POST 후 `ApiResponse<T>`를 벗겨 `T` 반환.
    func post<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        bearer: String? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        var request = try makeRequest(path: path, method: "POST", bearer: bearer)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIClientError.decoding(error)
        }
        let data = try await send(request)
        return try unwrap(data, as: T.self)
    }

    /// 응답 본문이 없는 POST (204 등). 바디가 와도 무시한다.
    func postNoContent(
        _ path: String,
        bearer: String? = nil
    ) async throws {
        let request = try makeRequest(path: path, method: "POST", bearer: bearer)
        _ = try await send(request)
    }

    // MARK: - 파일 업로드

    /// `multipart/form-data` 파트 하나.
    ///
    /// 러닝 저장(API.md 7.1)은 JSON 파트와 파일 파트를 **한 요청에 같이** 보낸다.
    enum MultipartPart: Sendable {
        /// 이름 붙은 JSON 파트. 파일명 없이 `Content-Type: application/json`만 붙는다.
        case json(name: String, data: Data)
        case file(name: String, fileName: String, mimeType: String, data: Data)
    }

    /// 여러 파트를 `multipart/form-data`로 올린다.
    func upload<T: Decodable>(
        _ path: String,
        parts: [MultipartPart],
        bearer: String? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        var request = try makeRequest(path: path, method: "POST", bearer: bearer)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        for part in parts {
            append("--\(boundary)\r\n")
            switch part {
            case .json(let name, let data):
                append("Content-Disposition: form-data; name=\"\(name)\"\r\n")
                append("Content-Type: application/json; charset=UTF-8\r\n\r\n")
                body.append(data)
            case .file(let name, let fileName, let mimeType, let data):
                append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
                append("Content-Type: \(mimeType)\r\n\r\n")
                body.append(data)
            }
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        request.httpBody = body

        let data = try await send(request)
        return try unwrap(data, as: T.self)
    }

    // MARK: - 내부 공통

    private func makeRequest(
        path: String,
        method: String,
        query: [String: String?] = [:],
        bearer: String? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL),
              var comps = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw APIClientError.invalidURL
        }
        let items = query.compactMap { key, value in
            value.map { URLQueryItem(name: key, value: $0) }
        }
        if !items.isEmpty { comps.queryItems = items }
        guard let finalURL = comps.url else { throw APIClientError.invalidURL }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// 요청 전송 + 상태코드 검증. 성공 시 원본 바디를 반환(빈 바디 가능).
    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.badStatus(-1)
        }

        guard (200..<300).contains(http.statusCode) else {
            // 401은 세션 파기/재로그인 분기가 필요해 따로 구분한다.
            if http.statusCode == 401 { throw APIClientError.unauthorized }
            if let wrapped = try? JSONDecoder().decode(APIResponse<EmptyBody>.self, from: data),
               let err = wrapped.error {
                throw APIClientError.business(err)
            }
            throw APIClientError.badStatus(http.statusCode)
        }

        return data
    }

    /// `ApiResponse<T>` 언래핑.
    private func unwrap<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let wrapped: APIResponse<T>
        do {
            wrapped = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        } catch {
            throw APIClientError.decoding(error)
        }

        if wrapped.success == false, let err = wrapped.error {
            throw APIClientError.business(err)
        }
        guard let value = wrapped.data else {
            throw APIClientError.emptyData
        }
        return value
    }
}
