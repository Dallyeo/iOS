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

    /// 현재 지역명 (검색바 지역칩). 못 구했으면 기본값.
    /// 지역 칩 텍스트. 공용 위치 제공자에서 읽는다.
    var regionText: String { LocationProvider.shared.displayRegionName }

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


    // MARK: - 데이터 로드 (BE /places 연동)

    private var didLoadNearby = false

    /// 추천 장소 로드. 현위치 있으면 주변(nearby), 없으면 기본 지역(군산).
    func loadPlaces() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dtos: [PlaceSummaryDTO]
            if let loc = userLocation {
                dtos = try await DallyeoAPI.nearbyPlaces(lat: loc.latitude, lng: loc.longitude, radius: 3000)
            } else {
                dtos = try await DallyeoAPI.places(region: "GUNSAN")
            }
            // 좌표 없는 항목은 지도에 찍을 수 없어 제외
            let places = dtos.compactMap { Self.mapPlace(from: $0) }
            attractions = places.filter { $0.category.group == .attraction }
            restaurants = places.filter { $0.category.group == .food }
        } catch {
            attractions = []
            restaurants = []
        }
    }

    /// PlaceSummary DTO → MapPlace. 좌표가 없으면 nil.
    private static func mapPlace(from d: PlaceSummaryDTO) -> MapPlace? {
        guard let coord = d.coordinate else { return nil }
        let category = PlaceCategory(backend: d.category)
        let distance = d.distanceMeters.map { m in
            m < 1000 ? "\(Int(m))m" : String(format: "%.1fkm", m / 1000)
        }
        // 시/도(첫 토큰) 제거한 축약 주소를 부제로
        let subtitle = d.address.map { addr -> String in
            var parts = addr.split(separator: " ").map(String.init)
            if parts.count > 1 { parts.removeFirst() }
            return parts.joined(separator: " ")
        }
        // http 이미지 → https (ATS 대응)
        let thumb = d.thumbnailUrl?.replacingOccurrences(of: "http://", with: "https://")
        return MapPlace(
            id: d.id, name: d.name, category: category,
            latitude: coord.latitude, longitude: coord.longitude,
            thumbnailURL: thumb, distance: distance,
            address: d.address, subtitle: subtitle, badge: nil
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension MapViewModel: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.userLocation = location.coordinate
            // 현위치 최초 확보 시 주변 장소로 재로드
            if !self.didLoadNearby {
                self.didLoadNearby = true
                await self.loadPlaces()
            }
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
