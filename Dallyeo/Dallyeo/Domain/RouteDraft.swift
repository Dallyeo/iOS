//
//  RouteDraft.swift
//  Dallyeo
//
//  러닝 코스 경로 초안 (V06 위치정보 → V07 경로수정 공유 상태)
//

import SwiftUI

@MainActor
@Observable
final class RouteDraft {

    var start: MapPlace?
    var waypoints: [MapPlace] = []   // 최대 3개
    var destination: MapPlace?

    /// 현재 검색으로 채우려는 지점 슬롯 (V07 행 탭 → 검색 → 결과 선택 시 이 슬롯에 할당)
    var editingSlot: EditSlot?

    static let maxWaypoints = 3

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

    /// "현재 위치" 플레이스홀더 (실제 좌표는 위치 서비스 연동 시 주입)
    static func currentLocationPlace(_ coordinate: (lat: Double, lng: Double)? = nil) -> MapPlace {
        MapPlace(
            id: "current",
            name: "현재 위치",
            category: .attraction,
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
}
