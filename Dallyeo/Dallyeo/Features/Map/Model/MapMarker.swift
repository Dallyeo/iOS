//
//  MapMarker.swift
//  Dallyeo
//
//  지도 마커 종류 (디자인시스템 마커 세트 대응)
//

import CoreLocation

struct MapMarker: Equatable {

    enum Kind: Equatable {
        case place            // 일반 장소 (초록 물방울)
        case currentLocation  // 현재 위치 pin
        case start            // 출발 (흰 내비 화살표)
        case waypoint(Int)    // 경유 (번호 원, 1~5)
        case destination      // 도착 (흰 깃발)
    }

    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    static func == (lhs: MapMarker, rhs: MapMarker) -> Bool {
        lhs.kind == rhs.kind
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
