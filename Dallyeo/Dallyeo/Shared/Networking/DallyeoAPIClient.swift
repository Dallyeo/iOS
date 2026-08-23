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

    // MARK: - GET

    /// GET 요청 후 `ApiResponse<T>`를 벗겨 `T` 반환.
    /// - query 값이 nil인 항목은 자동 생략.
    func get<T: Decodable>(
        _ path: String,
        query: [String: String?] = [:],
        bearer: String? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", query: query, bearer: bearer)
        let data = try await send(request)
        return try unwrap(data, as: T.self)
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
