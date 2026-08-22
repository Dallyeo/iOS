//
//  DallyeoAPI.swift
//  Dallyeo
//
//  BE 엔드포인트 정의 (인증 불필요 API). base URL 확정 후 바로 사용 가능.
//  스펙: docs/be-api-spec.md
//

import Foundation

enum DallyeoAPI {

    private static var client: DallyeoAPIClient { .shared }

    // MARK: - 지역

    /// GET /regions
    static func regions() async throws -> [RegionDTO] {
        try await client.get("/regions")
    }

    // MARK: - 장소

    // `/places/*`는 TourAPI를 실시간으로 호출해 간헐적으로 502가 난다.
    // API.md 9-3이 1~2회 재시도를 권장한다(두 번째부터는 서버 캐시라 빠르다).
    private static let placesRetries = 1

    /// GET /places?region=&category=
    static func places(region: String, category: String? = nil) async throws -> [PlaceSummaryDTO] {
        try await client.get("/places", query: ["region": region, "category": category], retries: placesRetries)
    }

    /// GET /places/search?keyword=&region=&category=
    static func searchPlaces(keyword: String, region: String? = nil, category: String? = nil) async throws -> [PlaceSummaryDTO] {
        try await client.get("/places/search", query: ["keyword": keyword, "region": region, "category": category], retries: placesRetries)
    }

    /// GET /places/nearby?lat=&lng=&radius=&category=
    static func nearbyPlaces(lat: Double, lng: Double, radius: Int? = nil, category: String? = nil) async throws -> [PlaceSummaryDTO] {
        try await client.get("/places/nearby", query: [
            "lat": String(lat), "lng": String(lng),
            "radius": radius.map(String.init), "category": category
        ], retries: placesRetries)
    }

    /// GET /places/{id}
    static func placeDetail(id: String) async throws -> PlaceDetailDTO {
        try await client.get("/places/\(id)", retries: placesRetries)
    }

    // MARK: - 코스

    /// GET /courses?region=&distance=
    static func courses(region: String? = nil, distance: String? = nil) async throws -> [CourseSummaryDTO] {
        try await client.get("/courses", query: ["region": region, "distance": distance])
    }

    /// GET /courses/{id}
    static func courseDetail(id: String) async throws -> CourseDetailDTO {
        try await client.get("/courses/\(id)")
    }
}
