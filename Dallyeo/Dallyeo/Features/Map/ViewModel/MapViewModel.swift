//
//  MapViewModel.swift
//  Dallyeo
//
//  V03 지도뷰 ViewModel
//

import SwiftUI
import CoreLocation

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
    var errorMessage: String?

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
            errorMessage = "위치 권한이 필요합니다. 설정에서 허용해 주세요."
        @unknown default:
            break
        }
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
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "위치를 가져올 수 없습니다."
        }
    }
}
