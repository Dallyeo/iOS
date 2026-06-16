//
//  MapPlace.swift
//  Dallyeo
//
//  지도뷰에서 사용하는 장소 모델
//

import Foundation

struct MapPlace: Identifiable, Sendable {
    let id: String
    let name: String
    let category: PlaceCategory
    let latitude: Double
    let longitude: Double
    let thumbnailURL: String?
    let distance: String?
}

enum PlaceCategory: String, Sendable {
    case attraction = "attraction"  // 관광지
    case restaurant = "restaurant"  // 음식점
}
