//
//  RunCourse.swift
//  Dallyeo
//
//  V08 코스확인 / V09 코스진행 공용 코스 모델.
//
//  코스는 두 경로로 만들어진다:
//   1) V07 경로수정에서 직접 구성 (RouteDraft + T MAP 폴리라인)
//   2) 메인뷰 추천 코스 선택 (BE `GET /courses/{id}`)
//  두 소스를 이 타입 하나로 통일해 V08/V09가 출처를 몰라도 되게 한다.
//

import Foundation
import CoreLocation

// MARK: - 코스 지점

/// 코스를 구성하는 지점 (출발 / 경유 / 도착)
struct CoursePoint: Identifiable, Hashable {

    enum Role: Hashable {
        case start
        case waypoint(Int)     // 1-based 표시 번호
        case destination
    }

    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let role: Role

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 좌표가 실제로 채워졌는지. (0,0)은 미설정 placeholder로 취급한다.
    var hasCoordinate: Bool {
        latitude != 0 || longitude != 0
    }

    /// 지도 마커 종류
    var markerKind: MapMarker.Kind {
        switch role {
        case .start:          .start
        case .waypoint(let n): .waypoint(n)
        case .destination:    .destination
        }
    }
}

// MARK: - 코스

struct RunCourse {

    /// 직접 검색으로 만든 코스의 기본 이름 (스펙: V08)
    static let ownCourseName = "나만의 러닝 코스"

    let name: String
    /// 출발 → 경유… → 도착 순서
    let points: [CoursePoint]
    /// 경로선. BE 코스는 `CourseDetail.polyline`, 직접 만든 코스는 T MAP 결과.
    let polyline: [CLLocationCoordinate2D]
    /// `polyline` 각 점까지의 누적 거리(m). BE 코스만 제공, 없으면 빈 배열.
    let cumulativeMeters: [Int]
    /// 코스 총 거리(m)
    let totalMeters: Int

    // MARK: 표시용

    /// "23km" — Figma V08 총거리 표기.
    /// 10km 이상은 정수, 미만은 소수 1자리로 자릿수 폭주를 막는다.
    var totalDistanceText: String {
        guard totalMeters > 0 else { return "-" }
        let km = Double(totalMeters) / 1000
        return km >= 10
            ? String(format: "%.0fkm", km)
            : String(format: "%.1fkm", km)
    }

    var startPoint: CoursePoint? { points.first { $0.role == .start } }
    var destinationPoint: CoursePoint? { points.first { $0.role == .destination } }
    var waypointPoints: [CoursePoint] {
        points.filter { if case .waypoint = $0.role { true } else { false } }
    }

    /// 지도 마커 (좌표 없는 지점 제외)
    var mapMarkers: [MapMarker] {
        points
            .filter(\.hasCoordinate)
            .map { MapMarker(coordinate: $0.coordinate, kind: $0.markerKind) }
    }

    /// 지도 카메라를 맞출 좌표들. 경로선이 있으면 그것을, 없으면 지점들을 쓴다.
    var boundsCoordinates: [CLLocationCoordinate2D] {
        polyline.isEmpty ? points.filter(\.hasCoordinate).map(\.coordinate) : polyline
    }
}

// MARK: - BE 코스 → RunCourse

extension RunCourse {

    /// `GET /courses/{id}` 응답에서 생성.
    ///
    /// `waypointAnchors`는 실측상 항상 정렬돼 있고 첫 앵커의 `polylineIndex`가 0,
    /// 마지막이 `polyline.count - 1`이다. 따라서 **첫 앵커 = 출발, 마지막 = 도착,
    /// 사이 = 경유**로 해석한다. 앵커가 2개면 경유지 없는 코스다.
    init(detail: CourseDetailDTO) {
        let coords = detail.polyline.map(\.coordinate)
        let anchors = detail.waypointAnchors

        func coordinate(at index: Int) -> CLLocationCoordinate2D? {
            coords.indices.contains(index) ? coords[index] : nil
        }

        var built: [CoursePoint] = []
        for (i, anchor) in anchors.enumerated() {
            let role: CoursePoint.Role
            if i == 0 {
                role = .start
            } else if i == anchors.count - 1 {
                role = .destination
            } else {
                role = .waypoint(i)   // 1-based: 두 번째 앵커가 경유 1
            }
            let c = coordinate(at: anchor.polylineIndex)
            built.append(
                CoursePoint(
                    id: "\(detail.id)-\(i)",
                    name: anchor.name,
                    latitude: c?.latitude ?? 0,
                    longitude: c?.longitude ?? 0,
                    role: role
                )
            )
        }

        self.name = detail.name
        self.points = built
        self.polyline = coords
        self.cumulativeMeters = detail.cumulativeMeters
        self.totalMeters = detail.totalMeters
    }
}

// MARK: - RouteDraft → RunCourse

extension RunCourse {

    /// V07에서 직접 구성한 코스에서 생성.
    /// 이름은 스펙에 따라 항상 "나만의 러닝 코스".
    @MainActor
    init(draft: RouteDraft) {
        var built: [CoursePoint] = []

        if let s = draft.start {
            built.append(CoursePoint(id: "start-\(s.id)", name: s.name,
                                     latitude: s.latitude, longitude: s.longitude,
                                     role: .start))
        }
        // 빈 경유지 칸(이름 없음)은 스펙상 경로 계산에서 제외 → 표시에서도 뺀다.
        var number = 1
        for wp in draft.waypoints where !wp.name.isEmpty {
            built.append(CoursePoint(id: "wp-\(wp.id)", name: wp.name,
                                     latitude: wp.latitude, longitude: wp.longitude,
                                     role: .waypoint(number)))
            number += 1
        }
        if let d = draft.destination {
            built.append(CoursePoint(id: "dest-\(d.id)", name: d.name,
                                     latitude: d.latitude, longitude: d.longitude,
                                     role: .destination))
        }

        let line = draft.routePolyline
        self.name = Self.ownCourseName
        self.points = built
        self.polyline = line
        self.cumulativeMeters = []
        // T MAP 실거리 우선. 실패했으면 지점 간 직선거리 합으로 폴백.
        self.totalMeters = draft.routeMeters
            ?? Self.straightLineMeters(built.filter(\.hasCoordinate).map(\.coordinate))
    }

    /// 좌표열의 직선거리 합(m)
    private static func straightLineMeters(_ coords: [CLLocationCoordinate2D]) -> Int {
        guard coords.count >= 2 else { return 0 }
        let meters = (1..<coords.count).reduce(0.0) { sum, i in
            let a = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            return sum + a.distance(from: b)
        }
        return Int(meters.rounded())
    }
}
