//
//  DallyeoAPIClient.swift
//  Dallyeo
//
//  BE 공통 HTTP 클라이언트 (GET + ApiResponse 언래핑)
//

import Foundation

struct DallyeoAPIClient {

    static let shared = DallyeoAPIClient()

    var baseURL: URL = APIConfig.baseURL
    var session: URLSession = .shared

    /// 외부 API 지연으로 실패했을 때 다시 시도하기 전 대기 시간.
    private static let retryDelay: Duration = .milliseconds(300)

    /// GET 요청 후 `ApiResponse<T>`를 벗겨 `T` 반환.
    /// - query 값이 nil인 항목은 자동 생략.
    /// - retries: 외부 API 오류(502 / `EXTERNAL_API_ERROR`)일 때만 추가 시도 횟수.
    ///   `/places/*`는 TourAPI를 실시간 호출해 간헐적으로 502가 난다(API.md 9-3).
    func get<T: Decodable>(
        _ path: String,
        query: [String: String?] = [:],
        retries: Int = 0,
        as type: T.Type = T.self
    ) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await perform(path, query: query, as: type)
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

    private func perform<T: Decodable>(
        _ path: String,
        query: [String: String?],
        as type: T.Type
    ) async throws -> T {
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
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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

        // 2xx 아니면 에러 바디 파싱 시도
        guard (200..<300).contains(http.statusCode) else {
            if let wrapped = try? JSONDecoder().decode(APIResponse<EmptyBody>.self, from: data),
               let err = wrapped.error {
                throw APIClientError.business(err)
            }
            throw APIClientError.badStatus(http.statusCode)
        }

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
