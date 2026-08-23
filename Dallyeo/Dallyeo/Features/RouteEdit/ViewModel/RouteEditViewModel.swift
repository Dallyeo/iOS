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

    /// 종류별 지도 마커 (출발=A / 경유=번호 / 도착=깃발). 빈 좌표 제외.
    var mapMarkers: [MapMarker] {
        var result: [MapMarker] = []
        if let s = draft.start, s.latitude != 0 || s.longitude != 0 {
            result.append(MapMarker(coordinate: s.coordinate, kind: .start))
        }
        var n = 1
        for wp in draft.waypoints where wp.latitude != 0 || wp.longitude != 0 {
            result.append(MapMarker(coordinate: wp.coordinate, kind: .waypoint(n)))
            n += 1
        }
        if let d = draft.destination, d.latitude != 0 || d.longitude != 0 {
            result.append(MapMarker(coordinate: d.coordinate, kind: .destination))
        }
        return result
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
        // 빈 경유지 칸 추가 (placeholder). 실제 장소는 검색으로 채움
        draft.waypoints.append(RouteDraft.emptyWaypoint())
    }

    func removeWaypoint(_ place: MapPlace) {
        draft.waypoints.removeAll { $0.id == place.id }
        reorderIndex = nil
    }

    // MARK: - 순서 변경 (스펙 V07 "↕ 선택 → 순서를 변경한다")

    /// 순서를 바꾸려고 먼저 고른 행. 두 번째 행을 고르면 둘의 자리가 맞바뀐다.
    /// 스펙이 드래그가 아니라 "선택"이라 두 번 탭으로 교환하는 방식을 쓴다.
    var reorderIndex: Int?

    /// 편집 패널에 보이는 순서대로의 지점. 출발·도착은 미설정이면 nil.
    /// (경유지 빈 칸은 좌표 0,0짜리 placeholder라 nil이 아니다)
    private var rowPlaces: [MapPlace?] {
        [draft.start] + draft.waypoints.map { Optional($0) } + [draft.destination]
    }

    /// 행 개수 — 출발 + 경유지 + 도착
    var rowCount: Int { draft.waypoints.count + 2 }

    /// ↕ 탭. 처음 누르면 그 행을 고르고, 다른 행을 누르면 두 행을 맞바꾼다.
    /// 같은 행을 다시 누르면 선택을 푼다.
    func selectForReorder(_ index: Int) {
        guard let picked = reorderIndex else {
            reorderIndex = index
            return
        }
        reorderIndex = nil
        guard picked != index else { return }
        swapRows(picked, index)
    }

    private func swapRows(_ a: Int, _ b: Int) {
        var rows = rowPlaces
        guard rows.indices.contains(a), rows.indices.contains(b) else { return }
        rows.swapAt(a, b)

        draft.start = rows.first ?? nil
        draft.destination = rows.last ?? nil
        // 가운데로 밀려온 자리가 비면(출발/도착이 미설정이었던 경우) 빈 칸으로 채워
        // 행 개수를 유지한다. 그냥 버리면 경유지가 한 칸 사라진다.
        draft.waypoints = rows.dropFirst().dropLast().map { $0 ?? RouteDraft.emptyWaypoint() }
    }

    // MARK: - T MAP 보행자 경로

    /// T MAP 도보경로 폴리라인 (지도 렌더용). 실패/미계산 시 빈 배열.
    /// 저장소는 `draft` — V08/V09가 같은 경로를 이어받아야 하므로 ViewModel에 두지 않는다.
    var routePolyline: [CLLocationCoordinate2D] {
        get { draft.routePolyline }
        set { draft.routePolyline = newValue }
    }
    /// T MAP 실거리(m). 못 구하면 nil → 직선거리로 폴백.
    var routeMeters: Int? {
        get { draft.routeMeters }
        set { draft.routeMeters = newValue }
    }
    var isRouting = false

    /// 유효 지점 좌표(빈 경유지 제외)
    private var validCoords: [CLLocationCoordinate2D] {
        orderedPlaces
            .filter { $0.latitude != 0 && $0.longitude != 0 }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// 지점 구성 변경 감지용 시그니처 (좌표 나열)
    var routeSignature: String {
        validCoords.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
    }

    /// T MAP 보행자 경로 재계산 (지점 2개 이상일 때). 실패 시 직선거리로 폴백.
    func recalculateRoute() async {
        let coords = validCoords
        guard coords.count >= 2 else {
            routePolyline = []; routeMeters = nil; return
        }
        let start = coords.first!
        let end = coords.last!
        let mids = Array(coords.dropFirst().dropLast())
        guard mids.count <= TMapService.maxPassPoints else { return }

        isRouting = true
        defer { isRouting = false }
        do {
            let route = try await TMapService.pedestrianRoute(start: start, waypoints: mids, destination: end)
            routePolyline = route.polyline
            routeMeters = route.totalMeters
        } catch {
            routePolyline = []
            routeMeters = nil   // 직선거리 폴백
        }
    }

    /// 직선 거리 합산 (km) — T MAP 실패 시 폴백
    var straightDistanceKm: Double {
        let coords = validCoords
        guard coords.count >= 2 else { return 0 }
        var meters: Double = 0
        for i in 1..<coords.count {
            meters += Self.haversine(coords[i - 1], coords[i])
        }
        return meters / 1000
    }

    /// 표시용 총거리. T MAP 실거리 우선, 없으면 직선거리.
    /// 포맷은 V08/V09와 공유 — `DistanceFormat` 참조.
    var totalDistanceText: String {
        if let m = routeMeters {
            return DistanceFormat.km(meters: m)
        }
        return DistanceFormat.km(meters: straightDistanceKm * 1000)
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
