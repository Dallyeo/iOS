//
//  MapViewModel.swift
//  Dallyeo
//
//  V03 지도뷰 ViewModel
//

import SwiftUI
import CoreLocation
import UIKit

@MainActor
@Observable
final class MapViewModel: NSObject {

    // MARK: - 상태

    var attractions: [MapPlace] = []
    var restaurants: [MapPlace] = []
    var selectedSegment: PlaceSegment = .attraction

    var userLocation: CLLocationCoordinate2D?
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined

    var isLoading: Bool = false

    // 권한 거부(설정 유도) / GPS 실패(재시도) 알럿
    var showPermissionAlert: Bool = false
    var showGPSErrorAlert: Bool = false

    // MARK: - 바텀시트

    enum BottomSheetDetent {
        case min, mid, full
    }

    // MARK: - 세그먼트

    enum PlaceSegment: String, CaseIterable {
        case attraction = "추천 관광지"
        case restaurant = "추천 음식점"
    }

    // MARK: - 현재 목록

    var currentPlaces: [MapPlace] {
        switch selectedSegment {
        case .attraction: return attractions
        case .restaurant: return restaurants
        }
    }

    // MARK: - Location

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocationIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            // iOS는 한 번 거부되면 시스템 팝업을 다시 못 띄우므로 설정 유도 알럿
            showPermissionAlert = true
        @unknown default:
            break
        }
    }

    /// GPS 실패 시 재시도. 권한이 없으면 설정 유도 알럿으로 전환.
    func retryLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            break
        }
    }

    /// 설정 앱으로 이동 (권한 거부 상태에서 직접 변경 유도)
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - 데이터 로드 (백엔드 연동 전 stub)

    func loadPlaces() async {
        isLoading = true
        // TODO: 백엔드 API 연동
        isLoading = false
    }
}

// MARK: - CLLocationManagerDelegate

extension MapViewModel: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.userLocation = location.coordinate
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.locationAuthStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            case .denied, .restricted:
                self.showPermissionAlert = true
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.showGPSErrorAlert = true
        }
    }
}
