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
    /// 우리 분류에 없는 종류일 때 대신 보여줄 이름 (예: 카카오의 "지하철역").
    /// 있으면 `category.label` 대신 이 값을 쓴다.
    var categoryLabelOverride: String? = nil
    var badge: String? = nil     // "착한식당" 등 배지

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 화면에 표시할 카테고리 이름
    var categoryLabel: String { categoryLabelOverride ?? category.label }
}

/// 장소 카테고리. BE(`/places`) 값을 그대로 옮긴다.
/// TourAPI 분류 체계라 `관광지`는 `tour` 하나만 가리킨다 — 전체를 묶는 상위 개념이 아니다.
/// (예전에는 음식점 외 전부를 `.attraction`으로 뭉개 안경점이 "관광지"로 표시됐다)
///
/// 값은 BE `API.md`의 category enum 10종과 1:1로 맞춘다.
enum PlaceCategory: String, Sendable, CaseIterable {
    case tour         // 관광지
    case culture      // 문화시설
    case festival     // 축제·공연
    case travelCourse // 여행코스
    case leports      // 레포츠
    case shopping     // 쇼핑
    case restaurant   // 음식점
    case cafe         // 카페
    case stay         // 숙박
    case etc          // 기타

    /// BE 카테고리 문자열 → 카테고리.
    ///
    /// 모르는 값은 `.etc`("기타")로 둔다. 예전엔 `.tour`로 떨어뜨렸는데,
    /// 그 탓에 BE가 보내는 TRAVEL_COURSE/LEPORTS/ETC가 전부 "관광지"로 표시됐다.
    /// 나중에 BE에 카테고리가 추가돼도 같은 사고가 반복되지 않게 기타로 받는다.
    init(backend: String) {
        switch backend.uppercased() {
        case "TOUR":          self = .tour
        case "CULTURE":       self = .culture
        case "FESTIVAL":      self = .festival
        case "TRAVEL_COURSE": self = .travelCourse
        case "LEPORTS":       self = .leports
        case "SHOPPING":      self = .shopping
        case "RESTAURANT":    self = .restaurant
        case "CAFE":          self = .cafe
        case "STAY":          self = .stay
        default:              self = .etc
        }
    }

    /// 카카오 로컬 카테고리 그룹 코드 → 카테고리.
    /// 우리 분류에 없는 종류(지하철역·은행·병원 등)는 nil을 준다.
    /// nil이면 카카오가 준 분류명을 그대로 보여준다 — 억지로 관광지로 뭉개지 않는다.
    static func from(kakaoGroupCode code: String?) -> PlaceCategory? {
        switch code {
        case "AT4": .tour        // 관광명소
        case "CT1": .culture     // 문화시설
        case "FD6": .restaurant  // 음식점
        case "CE7": .cafe        // 카페
        case "AD5": .stay        // 숙박
        case "MT1", "CS2": .shopping   // 대형마트, 편의점
        default: nil             // 지하철역/은행/병원/학교/주차장/주유소/공공기관 등
        }
    }

    /// 카드에 표시할 이름
    var label: String {
        switch self {
        case .tour:         "관광지"
        case .culture:      "문화시설"
        case .festival:     "축제"
        case .travelCourse: "여행코스"
        case .leports:      "레포츠"
        case .shopping:     "쇼핑"
        case .restaurant:   "음식점"
        case .cafe:         "카페"
        case .stay:         "숙박"
        case .etc:          "기타"
        }
    }

    /// 지도 마커와 V03 세그먼트용 묶음.
    /// 디자인시스템 마커가 관광지/편의시설 2종뿐이고 V03 세그먼트도 둘뿐이라 묶어야 한다.
    /// 쇼핑·숙박·기타는 러닝과 무관해 지도에 띄우지 않는다(PM 확인 대기 — 확정되면 조정).
    var group: Group {
        switch self {
        case .tour, .culture, .festival, .travelCourse, .leports: .attraction
        case .restaurant, .cafe:                                  .food
        case .shopping, .stay, .etc:                              .other
        }
    }

    enum Group {
        case attraction   // 관광지 계열
        case food         // 음식점 계열
        case other        // 지도에 표시하지 않음
    }
}
