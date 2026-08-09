//
//  CourseConfirmViewModel.swift
//  Dallyeo
//
//  V08 코스확인뷰 ViewModel — 코스 요약 + 코스 근방 장소
//

import SwiftUI
import CoreLocation

@MainActor
@Observable
final class CourseConfirmViewModel {

    /// 코스 소스. V07에서 만든 코스는 즉시 확정, 추천 코스는 BE 로드가 필요하다.
    enum Source {
        case draft(RouteDraft)
        case backend(courseId: String)
    }

    private let source: Source

    private(set) var course: RunCourse?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    /// 코스 근방 관광지/음식점 (지도 마커용)
    private(set) var nearbyPlaces: [MapPlace] = []

    init(source: Source) {
        self.source = source
        if case .draft(let draft) = source {
            self.course = RunCourse(draft: draft)
        }
    }

    /// V07에서 진입
    convenience init(draft: RouteDraft) {
        self.init(source: .draft(draft))
    }

    /// 추천 코스에서 진입
    convenience init(courseId: String) {
        self.init(source: .backend(courseId: courseId))
    }

    // MARK: - 표시용

    var courseName: String { course?.name ?? RunCourse.ownCourseName }
    var totalDistanceText: String { course?.totalDistanceText ?? "-" }
    var points: [CoursePoint] { course?.points ?? [] }
    var routePolyline: [CLLocationCoordinate2D] { course?.polyline ?? [] }

    /// 지도 마커 = 코스 지점 + 근방 장소
    var mapMarkers: [MapMarker] { course?.mapMarkers ?? [] }

    // MARK: - 로드

    func load() async {
        guard case .backend(let courseId) = source else {
            // 직접 만든 코스는 이미 확정 → 근방 장소만 조회
            await loadNearbyPlaces()
            return
        }
        guard course == nil, !isLoading else { return }

        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let detail = try await DallyeoAPI.courseDetail(id: courseId)
            course = RunCourse(detail: detail)
            await loadNearbyPlaces()
        } catch {
            loadFailed = true
        }
    }

    // MARK: - 코스 근방 장소

    /// 코스 근방 관광지/음식점 조회.
    ///
    /// BE에 경로 기준 검색(`/places/along-route`)이 아직 없어서 `/places/nearby`로 대신한다.
    /// `/places/nearby`는 **거리순 30건 하드캡**이라 한 지점만 조회하면 코스 전체를 덮지 못한다.
    /// → 폴리라인을 일정 간격으로 샘플링해 여러 번 호출하고 id로 중복 제거한다.
    ///
    /// 편의시설(화장실/편의점)은 BE에 카테고리 자체가 없어 MVP1에서 제외한다.
    private func loadNearbyPlaces() async {
        let samples = sampleCoordinates()
        guard !samples.isEmpty else { return }

        var merged: [String: MapPlace] = [:]
        for coord in samples {
            for category in Self.nearbyCategories {
                guard let dtos = try? await DallyeoAPI.nearbyPlaces(
                    lat: coord.latitude,
                    lng: coord.longitude,
                    radius: Self.nearbyRadiusMeters,
                    category: category
                ) else { continue }
                for dto in dtos where merged[dto.id] == nil {
                    merged[dto.id] = MapPlace(dto: dto)
                }
            }
        }
        nearbyPlaces = Array(merged.values)
    }

    /// 코스 근방 검색 반경(m). 스펙 "코스 근방 1km".
    private static let nearbyRadiusMeters = 1000
    /// BE 유효 카테고리(실측). ATTRACTION/CONVENIENCE 등은 400을 반환하므로 쓰지 않는다.
    private static let nearbyCategories = ["TOUR", "CULTURE", "RESTAURANT", "CAFE"]
    /// 샘플 지점 최대 개수. (지점당 카테고리 4회 호출 → 과다 요청 방지)
    private static let maxSamples = 5

    /// 폴리라인을 균등 간격으로 샘플링. 폴리라인이 없으면 코스 지점을 쓴다.
    private func sampleCoordinates() -> [CLLocationCoordinate2D] {
        guard let course else { return [] }

        let line = course.polyline
        guard line.count > 1 else {
            return Array(course.points.filter(\.hasCoordinate).map(\.coordinate).prefix(Self.maxSamples))
        }

        // 반경 1km 원들이 코스를 대략 덮도록 2km 간격을 목표로 하되 maxSamples를 넘지 않는다.
        let spacing = Double(Self.nearbyRadiusMeters * 2)
        let targetCount = max(1, Int((Double(course.totalMeters) / spacing).rounded(.up)))
        let count = min(targetCount, Self.maxSamples)

        guard count > 1 else { return [line[line.count / 2]] }

        let step = Double(line.count - 1) / Double(count - 1)
        return (0..<count).map { line[Int((Double($0) * step).rounded())] }
    }
}

// MARK: - DTO 매핑

private extension MapPlace {

    init(dto: PlaceSummaryDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            category: PlaceCategory(backendCategory: dto.category),
            latitude: dto.latitude,
            longitude: dto.longitude,
            thumbnailURL: dto.thumbnailUrl,
            distance: dto.distanceMeters.map { $0 >= 1000
                ? String(format: "%.1fkm", $0 / 1000)
                : "\(Int($0))m" },
            address: dto.address
        )
    }
}

private extension PlaceCategory {

    /// BE 카테고리 문자열 → 앱 카테고리.
    /// 실측 유효값: TOUR, CULTURE, FESTIVAL, SHOPPING, CAFE, RESTAURANT, STAY
    init(backendCategory: String) {
        switch backendCategory {
        case "RESTAURANT", "CAFE": self = .restaurant
        default:                   self = .attraction
        }
    }
}
