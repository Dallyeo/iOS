//
//  LocationProvider.swift
//  Dallyeo
//
//  앱 전역 현재 위치 제공자. "현재 위치" 출발지 좌표 주입 등에 사용.
//  (V03 지도, V06 역할설정, V09 러닝에서 공유)
//

import Foundation
import CoreLocation

@MainActor
@Observable
final class LocationProvider: NSObject {

    static let shared = LocationProvider()

    private(set) var current: CLLocationCoordinate2D?

    /// 현재 위치의 짧은 지역명("군산", "서울"…). 아직 못 구했으면 nil.
    /// 지역 칩(V03/V04/V05)이 모두 이 값을 쓴다. 화면마다 따로 역지오코딩하면
    /// 값이 어긋나거나(V05는 아예 상수였다) 같은 요청을 중복으로 날리게 된다.
    private(set) var regionName: String?

    /// 지역명을 아직 못 구했을 때 쓰는 기본값 (서비스 기본 지역)
    static let defaultRegionName = "군산"

    /// 표시용 지역명. 못 구했으면 기본값.
    var displayRegionName: String { regionName ?? Self.defaultRegionName }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    /// 마지막으로 역지오코딩한 좌표. 조금 움직였다고 매번 다시 부르지 않는다.
    private var lastGeocodedLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// 위치 업데이트 시작 (권한 있으면 즉시, 없으면 요청)
    func start() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    /// currentLocationPlace 주입용 튜플
    var currentTuple: (lat: Double, lng: Double)? {
        current.map { ($0.latitude, $0.longitude) }
    }

    // MARK: - 지역명 해석

    /// 좌표 → 짧은 지역명. 500m 이상 움직였을 때만 다시 조회한다.
    private func resolveRegion(for coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let last = lastGeocodedLocation, last.distance(from: location) < 500 { return }
        lastGeocodedLocation = location

        geocoder.reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "ko_KR")
        ) { [weak self] placemarks, _ in
            guard let placemark = placemarks?.first,
                  let name = RegionName.short(
                      admin: placemark.administrativeArea,
                      locality: placemark.locality
                  ) else { return }
            Task { @MainActor in self?.regionName = name }
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.current = coord
            self.resolveRegion(for: coord)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }
}
