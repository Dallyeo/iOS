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
    let category: String        // API.md category enum 문자열
    /// 좌표는 **null일 수 있다** (API.md: 키워드 검색/지역 목록에서 좌표 없는 항목 존재).
    /// 옵셔널이 아니면 한 건만 null이어도 배열 전체 디코딩이 실패해 검색 결과가 통째로 사라진다.
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let thumbnailUrl: String?
    let distanceMeters: Double?  // nearby 전용
    /// 배지 코드 (`MODEL_RESTAURANT` / `GOOD_PRICE`). 예전엔 상세에만 있었다.
    let badges: [String]?

    /// 좌표가 없으면 nil. 지도에 찍을 수 없는 항목은 호출부에서 걸러낸다.
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// GET /places/{id}
struct PlaceDetailDTO: Decodable, Sendable {
    let id: String
    let name: String
    let category: String
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let businessHours: String?
    let imageUrl: String?
    /// API.md 배지 코드: `MODEL_RESTAURANT`(모범음식점) / `GOOD_PRICE`(착한가격업소)
    let badges: [String]?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
