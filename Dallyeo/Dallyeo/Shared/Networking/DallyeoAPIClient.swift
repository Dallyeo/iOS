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

    /// GET 요청 후 `ApiResponse<T>`를 벗겨 `T` 반환.
    /// - query 값이 nil인 항목은 자동 생략.
    func get<T: Decodable>(
        _ path: String,
        query: [String: String?] = [:],
        as type: T.Type = T.self
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
