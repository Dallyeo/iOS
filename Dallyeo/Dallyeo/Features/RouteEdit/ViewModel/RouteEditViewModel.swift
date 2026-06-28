//
//  RouteEditViewModel.swift
//  Dallyeo
//
//  V07 경로수정뷰 ViewModel — 경유지 편집, 총거리 계산
//

import SwiftUI
import CoreLocation

@MainActor
@Observable
final class RouteEditViewModel {

    private let draft: RouteDraft

    init(draft: RouteDraft) {
        self.draft = draft
    }

    // MARK: - 지점 접근

    var start: MapPlace? { draft.start }
    var waypoints: [MapPlace] { draft.waypoints }
    var destination: MapPlace? { draft.destination }

    /// 전체 지점(순서대로) — 빈 칸 무시
    var orderedPlaces: [MapPlace] {
        ([draft.start] + draft.waypoints.map { Optional($0) } + [draft.destination])
            .compactMap { $0 }
    }

    /// 지도 마커용 — 유효 좌표만 (현재위치 placeholder 0,0 등 제외)
    var markerPlaces: [MapPlace] {
        orderedPlaces.filter { $0.latitude != 0 && $0.longitude != 0 }
    }

    // MARK: - 검증 (스펙)

    /// 출발지·도착지 모두 설정돼야 확인 가능
    var canConfirm: Bool {
        draft.start != nil && draft.destination != nil
    }

    /// 경유지 최대 3개 도달 시 추가 불가
    var canAddWaypoint: Bool {
        draft.waypoints.count < RouteDraft.maxWaypoints
    }

    // MARK: - 편집

    func addWaypointSlot() {
        guard canAddWaypoint else { return }
        // 빈 경유지 칸 추가 (placeholder). 실제 장소는 검색으로 채움(TODO)
        draft.waypoints.append(
            MapPlace(id: UUID().uuidString, name: "", category: .attraction,
                     latitude: 0, longitude: 0, thumbnailURL: nil, distance: nil)
        )
    }

    func removeWaypoint(_ place: MapPlace) {
        draft.waypoints.removeAll { $0.id == place.id }
    }

    func moveWaypoint(from source: IndexSet, to destinationIndex: Int) {
        draft.waypoints.move(fromOffsets: source, toOffset: destinationIndex)
    }

    // MARK: - 총 거리 (TODO: T MAP 보행자 경로 API — 백엔드 프록시. 현재는 직선 합 stub)

    /// 빈 경유지(좌표 0)는 무시하고 직선 거리 합산 (km)
    var totalDistanceKm: Double {
        let coords = orderedPlaces
            .filter { $0.latitude != 0 && $0.longitude != 0 }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard coords.count >= 2 else { return 0 }
        var meters: Double = 0
        for i in 1..<coords.count {
            meters += Self.haversine(coords[i - 1], coords[i])
        }
        return meters / 1000
    }

    var totalDistanceText: String {
        String(format: "%.1fkm", totalDistanceKm)
    }

    private static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let r = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}
