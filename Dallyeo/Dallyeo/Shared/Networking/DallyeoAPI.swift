//
//  DallyeoAPI.swift
//  Dallyeo
//
//  BE 엔드포인트 정의. base URL 확정 후 바로 사용 가능.
//  스펙: docs/be-api-spec.md
//

import Foundation

enum DallyeoAPI {

    private static var client: DallyeoAPIClient { .shared }

    // MARK: - 인증

    /// POST /auth/login/{provider} 🌐
    /// - Parameter authorizationCode: kakao=카카오 access token / apple=identity token(JWT)
    static func login(provider: AuthProviderKind, authorizationCode: String) async throws -> AuthTokenDTO {
        try await client.post(
            "/auth/login/\(provider.rawValue)",
            body: AuthLoginRequest(authorizationCode: authorizationCode)
        )
    }

    /// POST /auth/refresh 🌐
    /// 회전(rotation): 응답의 새 refreshToken 으로 교체 저장해야 한다.
    static func refresh(refreshToken: String) async throws -> AuthTokenDTO {
        try await client.post(
            "/auth/refresh",
            body: AuthRefreshRequest(refreshToken: refreshToken)
        )
    }

    /// POST /auth/logout 🔒 (204, 본문 없음)
    static func logout(accessToken: String) async throws {
        try await client.postNoContent("/auth/logout", bearer: accessToken)
    }

    // MARK: - 지역

    /// GET /regions
    static func regions() async throws -> [RegionDTO] {
        try await client.get("/regions")
    }

    // MARK: - 장소

    // `/places/*`는 TourAPI를 실시간으로 호출해 간헐적으로 502가 난다.
    // API.md 9-3이 1~2회 재시도를 권장한다(두 번째부터는 서버 캐시라 빠르다).
    private static let placesRetries = 2

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

    // MARK: - 러닝 기록

    /// POST /runs 🔒 (multipart/form-data)
    ///
    /// `run`(JSON) + `image`(파일) **두 파트를 한 요청에** 보낸다. 이미지는 필수라
    /// 누락하면 400이다. JSON으로 보내면 서버가 500을 준다.
    ///
    /// 저장할 때 서버가 업적까지 판정해 **이번에 처음 딴 것만** `newAchievements`로 준다.
    /// 조회 API에는 그 필드가 없어서, 여기서 못 받으면 결과창 도장을 다시 얻을 길이 없다.
    static func saveRun(
        _ body: RunSaveRequest, jpeg: Data, accessToken: String
    ) async throws -> RunRecordDTO {
        let json: Data
        do {
            json = try JSONEncoder().encode(body)
        } catch {
            throw APIClientError.decoding(error)
        }
        return try await client.upload(
            "/runs",
            parts: [
                .json(name: "run", data: json),
                .file(name: "image", fileName: "route.jpg", mimeType: "image/jpeg", data: jpeg)
            ],
            bearer: accessToken
        )
    }

    /// POST /runs/{id}/image 🔒
    ///
    /// 이미 저장된 기록의 이미지를 **교체**한다. 최초 이미지는 저장(7.1) 때 함께 올라가므로
    /// 여기는 다시 올릴 때만 쓴다. 허용 형식 jpeg/png/webp/heic/heif, 최대 10MB.
    static func replaceRunImage(
        runId: Int, jpeg: Data, accessToken: String
    ) async throws -> RunRecordDTO {
        try await client.upload(
            "/runs/\(runId)/image",
            parts: [.file(name: "image", fileName: "route.jpg", mimeType: "image/jpeg", data: jpeg)],
            bearer: accessToken
        )
    }
}
