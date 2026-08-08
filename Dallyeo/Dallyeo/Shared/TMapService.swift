//
//  TMapService.swift
//  Dallyeo
//
//  T MAP 보행자 경로 API (SK Open API) — V07 경로수정/V08 코스 경로선.
//  ※ 팀 협의: 도보경로는 앱에서 직접 호출. appKey는 Secrets.xcconfig(gitignore).
//  응답은 GeoJSON: LineString feature 좌표 이어붙여 폴리라인, 첫 feature.properties에 총거리.
//

import Foundation
import CoreLocation

/// 보행자 경로 결과
struct PedestrianRoute: Sendable {
    let polyline: [CLLocationCoordinate2D]  // 경로선 좌표 (순서대로)
    let totalMeters: Int                    // 총 도보 거리(m)
}

enum TMapService {

    enum ServiceError: Error { case missingKey, badResponse, tooManyWaypoints }

    /// T MAP 보행자 경유지 최대 개수 (API 제약)
    static let maxPassPoints = 5

    private static var appKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "TMAP_APP_KEY") as? String
    }

    /// 보행자 경로 계산. 경유지는 순서대로(최대 5개), 좌표(0,0) 빈 지점은 호출 전에 제거해서 넘길 것.
    static func pedestrianRoute(
        start: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D] = [],
        destination: CLLocationCoordinate2D,
        searchOption: String = "0"   // 0:추천 4:대로우선 10:최단 30:계단제외
    ) async throws -> PedestrianRoute {
        guard let key = appKey, !key.isEmpty else { throw ServiceError.missingKey }
        guard waypoints.count <= maxPassPoints else { throw ServiceError.tooManyWaypoints }

        var body: [String: Any] = [
            "startX": String(start.longitude),
            "startY": String(start.latitude),
            "endX": String(destination.longitude),
            "endY": String(destination.latitude),
            "startName": "출발",
            "endName": "도착",
            "reqCoordType": "WGS84GEO",
            "resCoordType": "WGS84GEO",
            "searchOption": searchOption
        ]
        // 경유지: "lng,lat_lng,lat" 형식
        if !waypoints.isEmpty {
            body["passList"] = waypoints.map { "\($0.longitude),\($0.latitude)" }.joined(separator: "_")
        }

        var request = URLRequest(url: URL(string: "https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "appKey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ServiceError.badResponse
        }
        return try parse(data)
    }

    // MARK: - GeoJSON 파싱

    private static func parse(_ data: Data) throws -> PedestrianRoute {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else {
            throw ServiceError.badResponse
        }

        var polyline: [CLLocationCoordinate2D] = []
        var totalMeters = 0

        for feature in features {
            // 총거리: Point feature의 properties.totalDistance (첫 지점에 담김)
            if let props = feature["properties"] as? [String: Any],
               let total = props["totalDistance"] as? Int, total > 0 {
                totalMeters = total
            }
            // 경로선: LineString 좌표 이어붙이기
            guard let geometry = feature["geometry"] as? [String: Any],
                  geometry["type"] as? String == "LineString",
                  let coords = geometry["coordinates"] as? [[Double]] else { continue }
            for c in coords where c.count >= 2 {
                polyline.append(CLLocationCoordinate2D(latitude: c[1], longitude: c[0]))
            }
        }

        guard !polyline.isEmpty else { throw ServiceError.badResponse }
        return PedestrianRoute(polyline: polyline, totalMeters: totalMeters)
    }
}
