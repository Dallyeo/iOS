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

/// 장소 카테고리. BE(`/places`) 값을 그대로 옮긴다.
/// TourAPI 분류 체계라 `관광지`는 `tour` 하나만 가리킨다 — 전체를 묶는 상위 개념이 아니다.
/// (예전에는 음식점 외 전부를 `.attraction`으로 뭉개 안경점이 "관광지"로 표시됐다)
enum PlaceCategory: String, Sendable, CaseIterable {
    case tour        // 관광지
    case culture     // 문화시설
    case festival    // 축제·공연
    case shopping    // 쇼핑
    case restaurant  // 음식점
    case cafe        // 카페
    case stay        // 숙박

    /// BE 카테고리 문자열 → 카테고리. 모르는 값은 관광지로 둔다.
    init(backend: String) {
        switch backend.uppercased() {
        case "TOUR":       self = .tour
        case "CULTURE":    self = .culture
        case "FESTIVAL":   self = .festival
        case "SHOPPING":   self = .shopping
        case "RESTAURANT": self = .restaurant
        case "CAFE":       self = .cafe
        case "STAY":       self = .stay
        default:           self = .tour
        }
    }

    /// 카드에 표시할 이름
    var label: String {
        switch self {
        case .tour:       "관광지"
        case .culture:    "문화시설"
        case .festival:   "축제"
        case .shopping:   "쇼핑"
        case .restaurant: "음식점"
        case .cafe:       "카페"
        case .stay:       "숙박"
        }
    }

    /// 지도 마커와 V03 세그먼트용 묶음.
    /// 디자인시스템 마커가 관광지/편의시설 2종뿐이고 V03 세그먼트도 둘뿐이라 묶어야 한다.
    /// 쇼핑·숙박은 러닝과 무관해 지도에 띄우지 않는다(PM 확인 대기 — 확정되면 조정).
    var group: Group {
        switch self {
        case .tour, .culture, .festival: .attraction
        case .restaurant, .cafe:         .food
        case .shopping, .stay:           .other
        }
    }

    enum Group {
        case attraction   // 관광지 계열
        case food         // 음식점 계열
        case other        // 지도에 표시하지 않음
    }
}
