//
//  KakaoLocalService.swift
//  Dallyeo
//
//  카카오 로컬 REST API (키워드/장소 검색) — V04 유사검색어 / V05 검색결과
//  ※ 팀 협의: 주소·장소 검색은 앱에서 직접 호출. REST 키는 Secrets.xcconfig(gitignore).
//

import Foundation
import CoreLocation

/// 카카오 검색 결과 장소
struct KakaoPlace: Sendable {
    let id: String
    let name: String
    let address: String?
    let roadAddress: String?
    let coordinate: CLLocationCoordinate2D
    let categoryGroupCode: String?
    let distance: String?   // 미터(문자열), 좌표 전달 시에만 제공
}

enum KakaoLocalService {

    enum ServiceError: Error { case missingKey, badResponse }

    private static var restKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_KEY") as? String
    }

    /// 키워드로 장소 검색. 좌표를 주면 거리순 정렬 + distance 제공.
    static func searchKeyword(
        _ query: String,
        near coord: CLLocationCoordinate2D? = nil,
        size: Int = 15
    ) async throws -> [KakaoPlace] {
        guard let key = restKey, !key.isEmpty else { throw ServiceError.missingKey }

        var comps = URLComponents(string: "https://dapi.kakao.com/v2/local/search/keyword.json")!
        var items = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "size", value: String(size))
        ]
        if let coord {
            items.append(URLQueryItem(name: "x", value: String(coord.longitude)))
            items.append(URLQueryItem(name: "y", value: String(coord.latitude)))
            items.append(URLQueryItem(name: "sort", value: "distance"))
        }
        comps.queryItems = items

        var request = URLRequest(url: comps.url!)
        request.setValue("KakaoAK \(key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ServiceError.badResponse
        }
        return try JSONDecoder().decode(KakaoKeywordResponse.self, from: data)
            .documents.map { $0.toPlace() }
    }
}

// MARK: - DTO

private struct KakaoKeywordResponse: Decodable {
    let documents: [Document]

    struct Document: Decodable {
        let id: String
        let placeName: String
        let addressName: String?
        let roadAddressName: String?
        let x: String
        let y: String
        let categoryGroupCode: String?
        let distance: String?

        enum CodingKeys: String, CodingKey {
            case id, x, y, distance
            case placeName = "place_name"
            case addressName = "address_name"
            case roadAddressName = "road_address_name"
            case categoryGroupCode = "category_group_code"
        }

        func toPlace() -> KakaoPlace {
            KakaoPlace(
                id: id,
                name: placeName,
                address: addressName,
                roadAddress: roadAddressName,
                coordinate: CLLocationCoordinate2D(
                    latitude: Double(y) ?? 0,
                    longitude: Double(x) ?? 0
                ),
                categoryGroupCode: categoryGroupCode,
                distance: distance
            )
        }
    }
}
