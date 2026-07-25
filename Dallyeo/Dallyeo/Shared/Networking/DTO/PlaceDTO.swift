//
//  PlaceDTO.swift
//  Dallyeo
//
//  /places 계열 응답 (PlaceSummary / PlaceDetail)
//

import Foundation
import CoreLocation

/// GET /places, /places/search, /places/nearby 요소
struct PlaceSummaryDTO: Decodable, Sendable {
    let id: String
    let name: String
    let category: String        // CategoryType enum 문자열 (값 확인 필요)
    let latitude: Double
    let longitude: Double
    let address: String?
    let thumbnailUrl: String?
    let distanceMeters: Double?  // nearby 전용

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// GET /places/{id}
struct PlaceDetailDTO: Decodable, Sendable {
    let id: String
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let businessHours: String?
    let imageUrl: String?
    let badges: [String]?        // 예: ["착한식당"]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
