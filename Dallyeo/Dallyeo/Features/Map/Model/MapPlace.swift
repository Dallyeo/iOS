//
//  MapPlace.swift
//  Dallyeo
//
//  지도뷰에서 사용하는 장소 모델
//

import Foundation
import CoreLocation

struct MapPlace: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let category: PlaceCategory
    let latitude: Double
    let longitude: Double
    let thumbnailURL: String?
    let distance: String?
    var address: String? = nil   // V05 검색결과 등에서 사용
    var subtitle: String? = nil  // "양식 · 수송로" (카테고리 · 지역)
    var badge: String? = nil     // "착한식당" 등 배지

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum PlaceCategory: String, Sendable {
    case attraction = "attraction"  // 관광지
    case restaurant = "restaurant"  // 음식점
}
