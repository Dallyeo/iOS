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

    private let manager = CLLocationManager()

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
}

extension LocationProvider: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in self.current = coord }
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
