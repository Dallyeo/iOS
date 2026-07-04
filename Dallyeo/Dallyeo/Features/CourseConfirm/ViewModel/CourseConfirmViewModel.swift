//
//  CourseConfirmViewModel.swift
//  Dallyeo
//
//  V08 코스확인뷰 ViewModel — 코스 요약 + 주변 편의시설(백엔드 대기)
//

import SwiftUI
import CoreLocation

@MainActor
@Observable
final class CourseConfirmViewModel {

    /// 직접 검색으로 만든 코스 기본 이름
    let courseName: String = "나만의 러닝 코스"

    private let start: MapPlace?
    private let waypoints: [MapPlace]
    private let destination: MapPlace?

    /// 지도 마커/경로용 전체 지점 (출발→경유→도착, 유효 좌표만)
    let routePlaces: [MapPlace]

    /// 코스 근방 1km 편의시설/관광지
    /// TODO: 백엔드 `/places/along-route`(경로 기준 반경 검색) 연동. 현재는 빈 배열.
    var nearbyPlaces: [MapPlace] = []

    init(draft: RouteDraft) {
        self.start = draft.start
        self.waypoints = draft.waypoints
        self.destination = draft.destination
        self.routePlaces = ([draft.start] + draft.waypoints.map { Optional($0) } + [draft.destination])
            .compactMap { $0 }
            .filter { $0.latitude != 0 && $0.longitude != 0 }
    }

    // MARK: - 표시용

    var startName: String { start?.name ?? "현재 위치" }
    var destinationName: String { destination?.name ?? "-" }
    var waypointNames: [String] { waypoints.map { $0.name } }

    /// 총 거리 표시. 실제 거리는 T MAP 보행자 경로(백엔드 프록시) 연동 시 대체
    var totalDistanceText: String {
        guard totalCourseMeters > 0 else { return "-" }
        return String(format: "%.1fkm", totalCourseMeters / 1000)
    }

    /// 코스 총 직선 거리(m) — 임시. 실제는 T MAP 보행자 경로로 대체
    private var totalCourseMeters: Double {
        guard routePlaces.count >= 2 else { return 0 }
        return (1..<routePlaces.count).reduce(0.0) { sum, i in
            let a = routePlaces[i - 1].coordinate
            let b = routePlaces[i].coordinate
            return sum + CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        }
    }
}
