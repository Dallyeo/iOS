//
//  CourseDTO.swift
//  Dallyeo
//
//  /courses 계열 응답 (CourseSummary / CourseDetail)
//

import Foundation
import CoreLocation

/// GET /courses 요소
struct CourseSummaryDTO: Decodable, Sendable {
    let id: String
    let name: String
    /// 지역 **코드 문자열** ("GUNSAN" / "JEONJU").
    /// ※ be-api-spec.md에는 `region:Region`으로 적혀 객체처럼 읽히지만,
    ///   실제 응답은 문자열이다. RegionDTO(객체)로 두면 디코딩이 실패한다.
    let region: String
    let distanceCategory: String   // CourseDistance enum 문자열
    let totalMeters: Int
    let waypointCount: Int
}

/// GET /courses/{id}
struct CourseDetailDTO: Decodable, Sendable {
    let id: String
    let name: String
    let region: String             // CourseSummaryDTO.region과 동일 (코드 문자열)
    let distanceCategory: String
    let totalMeters: Int
    let polyline: [PolylinePointDTO]       // 경로 폴리라인
    let cumulativeMeters: [Int]            // polyline 각 점까지 누적거리
    let waypointAnchors: [WaypointAnchorDTO]
}

struct PolylinePointDTO: Decodable, Sendable {
    let lat: Double
    let lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct WaypointAnchorDTO: Decodable, Sendable {
    let name: String
    let polylineIndex: Int   // polyline 배열 내 위치
}
