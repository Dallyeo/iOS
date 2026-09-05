//
//  RouteDraft.swift
//  Dallyeo
//
//  러닝 코스 경로 초안 (V06 위치정보 → V07 경로수정 공유 상태)
//

import SwiftUI
import CoreLocation

@MainActor
@Observable
final class RouteDraft {

    var start: MapPlace?
    var waypoints: [MapPlace] = []   // 최대 maxWaypoints개
    var destination: MapPlace?

    /// T MAP 보행자 경로 폴리라인. V07에서 계산해 여기 저장 → V08/V09가 이어받는다.
    /// (ViewModel에만 두면 화면 전환 시 유실되므로 draft가 보관)
    var routePolyline: [CLLocationCoordinate2D] = []
    /// T MAP 실거리(m). 못 구하면 nil → 직선거리 폴백.
    var routeMeters: Int?

    /// 현재 검색으로 채우려는 지점 슬롯 (V07 행 탭 → 검색 → 결과 선택 시 이 슬롯에 할당)
    var editingSlot: EditSlot?

    /// 경유지 최대 개수. 기능명세 기준 3 (팀 확정 — Figma HiFi는 5개 프레임이지만 명세가 우선).
    ///
    /// 3이어야 하는 실질적인 이유도 있다: `insertCurrentLocationAsStart`가 원래 출발지를
    /// 경유지로 한 칸 더 밀어 넣으므로 실제 경유지는 최대 4개가 되는데,
    /// T MAP 경유지 상한이 5라 여기가 5면 6개가 되어 경로를 못 받는다.
    static let maxWaypoints = 3

    /// "현재 위치" 지점의 고정 id. 이미 현재 위치에서 출발하는 코스인지 판별하는 데 쓴다.
    static let currentLocationID = "current"

    /// 현재 위치를 출발지로 끼워 넣을 최소 거리(m).
    /// V09 경로 이탈 판정과 같은 1km — 원래 이 거리에서 "그만두시겠습니까"가 떴다.
    static let autoStartDistanceThreshold: Double = 1000

    enum EditSlot: Equatable {
        case start
        case waypoint(String)   // waypoint id
        case destination
    }

    /// 검색 결과를 편집 중인 슬롯에 할당
    func assign(_ place: MapPlace, to slot: EditSlot) {
        switch slot {
        case .start:
            start = place
        case .destination:
            destination = place
        case .waypoint(let id):
            if let idx = waypoints.firstIndex(where: { $0.id == id }) {
                waypoints[idx] = place
            }
        }
    }

    /// 빈 경유지 칸. 좌표가 0,0이라 경로 계산·마커에서 무시된다.
    static func emptyWaypoint() -> MapPlace {
        MapPlace(id: UUID().uuidString, name: "", category: .tour,
                 latitude: 0, longitude: 0, thumbnailURL: nil, distance: nil)
    }

    /// "현재 위치" 플레이스홀더 (실제 좌표는 위치 서비스 연동 시 주입)
    static func currentLocationPlace(_ coordinate: (lat: Double, lng: Double)? = nil) -> MapPlace {
        MapPlace(
            id: currentLocationID,
            name: "현재 위치",
            category: .tour,
            latitude: coordinate?.lat ?? 0,
            longitude: coordinate?.lng ?? 0,
            thumbnailURL: nil,
            distance: nil,
            address: nil
        )
    }

    // MARK: - 역할 설정

    func setStart(_ place: MapPlace) {
        start = place
    }

    /// 경유지 추가. 출발지 미설정 시 현재 위치로 자동 설정.
    func addWaypoint(_ place: MapPlace, currentLocation: MapPlace) {
        if start == nil { start = currentLocation }
        guard waypoints.count < Self.maxWaypoints else { return }
        waypoints.append(place)
    }

    /// 도착지 설정. 출발지 미설정 시 현재 위치로 자동 설정.
    func setDestination(_ place: MapPlace, currentLocation: MapPlace) {
        if start == nil { start = currentLocation }
        destination = place
    }

    // MARK: - 현재 위치에서 출발

    /// 출발지가 현재 위치에서 멀면 **현재 위치를 새 출발지로 끼워 넣고
    /// 원래 출발지를 경유지1로 내린다.**
    ///
    /// 러닝은 결국 지금 서 있는 자리에서 시작할 수밖에 없다. 그런데 출발지가 1km 넘게
    /// 떨어져 있으면 시작하자마자 경로 이탈로 잡혀 "러닝을 그만두시겠습니까"가 떴다.
    /// 코스를 현재 위치에서부터 이어 붙여 그 상황 자체를 없앤다.
    ///
    /// 직접 만든 코스(V07→V08)에만 적용한다. 추천 코스는 BE 코스를 그대로 달려야 하므로
    /// 이 draft를 거치지 않는다.
    ///
    /// - Returns: 실제로 끼워 넣었으면 true (호출부는 이때만 경로를 다시 계산하면 된다)
    @discardableResult
    func insertCurrentLocationAsStart(_ current: CLLocationCoordinate2D) -> Bool {
        guard let original = start, original.latitude != 0 || original.longitude != 0 else { return false }
        // 이미 현재 위치에서 출발하는 코스는 손대지 않는다.
        // (V08에 다시 들어올 때마다 "현재 위치"가 겹겹이 쌓이는 것을 막는다)
        guard original.id != Self.currentLocationID else { return false }

        let distance = CLLocation(latitude: current.latitude, longitude: current.longitude)
            .distance(from: CLLocation(latitude: original.latitude, longitude: original.longitude))
        guard distance > Self.autoStartDistanceThreshold else { return false }

        start = Self.currentLocationPlace((lat: current.latitude, lng: current.longitude))
        waypoints.insert(original, at: 0)
        return true
    }

    // MARK: - T MAP 보행자 경로

    /// 경로 계산에 실제로 쓰이는 지점 좌표 (출발→경유→도착 순, 빈 경유지 칸 제외)
    var validCoordinates: [CLLocationCoordinate2D] {
        ([start] + waypoints.map { Optional($0) } + [destination])
            .compactMap { $0 }
            .filter { $0.latitude != 0 || $0.longitude != 0 }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// T MAP 보행자 경로 재계산.
    ///
    /// 계산 주체가 draft인 이유: 결과(`routePolyline`/`routeMeters`)를 draft가 보관하고,
    /// V07(지점 편집)과 V08(현재 위치 삽입) 두 곳에서 다시 계산해야 한다.
    /// 실패하거나 경유지가 T MAP 상한을 넘으면 **비워서** 직선거리 폴백으로 되돌린다
    /// (그대로 두면 지금 지점 구성과 다른 옛 경로선이 지도에 남는다).
    func recalculateRoute() async {
        let coords = validCoordinates
        guard coords.count >= 2 else {
            routePolyline = []; routeMeters = nil; return
        }
        let mids = Array(coords.dropFirst().dropLast())
        guard mids.count <= TMapService.maxPassPoints else {
            routePolyline = []; routeMeters = nil; return
        }
        do {
            let route = try await TMapService.pedestrianRoute(
                start: coords.first!, waypoints: mids, destination: coords.last!
            )
            routePolyline = route.polyline
            routeMeters = route.totalMeters
        } catch {
            routePolyline = []
            routeMeters = nil   // 직선거리 폴백
        }
    }
}
