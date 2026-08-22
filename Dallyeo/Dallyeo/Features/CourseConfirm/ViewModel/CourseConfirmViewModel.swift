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

    /// 코스 지점 마커 (출발/경유/도착)
    var mapMarkers: [MapMarker] { course?.mapMarkers ?? [] }
    /// 코스 전체가 보이도록 카메라를 맞출 좌표들
    var boundsCoordinates: [CLLocationCoordinate2D] { course?.boundsCoordinates ?? [] }

    // MARK: - 로드

    func load() async {
        // 추천 코스는 먼저 코스를 받아온다. 직접 만든 코스는 이미 확정 상태.
        if case .backend(let courseId) = source {
            guard course == nil, !isLoading else { return }

            isLoading = true
            loadFailed = false
            do {
                let detail = try await DallyeoAPI.courseDetail(id: courseId)
                course = RunCourse(detail: detail)
            } catch {
                loadFailed = true
            }
            // 주변 장소는 코스 표시를 막지 않는다 — 여기서 로딩을 끝낸다.
            isLoading = false
            guard !loadFailed else { return }
        }
        await loadNearbyPlaces()
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

        // 최대 5지점 × 4카테고리 = 20회. 순차로 돌리면 수 초가 걸리므로 병렬로 던진다.
        let radius = Self.nearbyRadiusMeters
        let requests = samples.flatMap { coord in
            Self.nearbyCategories.map { (coord, $0) }
        }

        let fetched = await withTaskGroup(of: [PlaceSummaryDTO].self) { group in
            for (coord, category) in requests {
                group.addTask {
                    (try? await DallyeoAPI.nearbyPlaces(
                        lat: coord.latitude,
                        lng: coord.longitude,
                        radius: radius,
                        category: category
                    )) ?? []
                }
            }
            var all: [PlaceSummaryDTO] = []
            for await result in group { all += result }
            return all
        }

        // id 중복 제거 후 가까운 순으로 상한을 둔다.
        // (샘플 지점들의 반경 1km가 서로 겹쳐 수백 개까지 쌓일 수 있다)
        var seen = Set<String>()
        nearbyPlaces = fetched
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
            .prefix(Self.maxNearbyMarkers)
            .map(MapPlace.init(dto:))
    }

    /// 코스 근방 검색 반경(m). 스펙 "코스 근방 1km".
    private static let nearbyRadiusMeters = 1000
    /// 코스 주변에 표시할 카테고리.
    ///
    /// 스펙(V08)은 "코스 근방 1km에 있는 **편의시설과 관광지**"라 음식점은 대상이 아니다.
    /// 디자인시스템에도 음식점 마커가 없다(관광지=분홍, 편의시설=하늘색, 초록 pin은
    /// "검색/선택한 위치" 전용). 편의시설은 BE에 카테고리 자체가 없어 현재는 관광지만.
    ///
    /// BE 유효 카테고리(실측): TOUR CULTURE FESTIVAL SHOPPING CAFE RESTAURANT STAY
    /// (ATTRACTION/CONVENIENCE/TOILET 등은 400)
    private static let nearbyCategories = ["TOUR", "CULTURE", "FESTIVAL"]
    /// 샘플 지점 최대 개수. (지점당 카테고리 4회 호출 → 과다 요청 방지)
    private static let maxSamples = 5
    /// 지도에 찍을 주변 마커 상한. 넘으면 지도가 마커로 뒤덮인다.
    private static let maxNearbyMarkers = 40

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
            category: PlaceCategory(backend: dto.category),
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

