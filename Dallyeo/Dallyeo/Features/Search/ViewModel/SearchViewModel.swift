//
//  SearchViewModel.swift
//  Dallyeo
//
//  V04 검색뷰 ViewModel — 검색어, 최근검색(로컬), 유사검색어, 현재위치 칩
//

import SwiftUI
import CoreLocation
import UIKit

@MainActor
@Observable
final class SearchViewModel: NSObject {

    // MARK: - 상태

    var query: String = ""
    var recentSearches: [String] = []
    var suggestions: [SearchSuggestion] = []   // 유사검색어 (백엔드 연동 전 stub)

    // 위치 칩
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    var currentRegion: String?                 // 짧은 지역명 (예: "군산", "서울")
    var currentCoordinate: CLLocationCoordinate2D?   // 검색 거리순 정렬용

    // MARK: - 위치

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // MARK: - 파생 상태

    /// 무입력 상태에서 검색 실행 방지
    var canSearch: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 타이핑 중이면 유사검색어, 아니면 최근검색 노출
    var isTyping: Bool { canSearch }

    /// 위치 칩 텍스트: 현재 지역명. 아직 못 구했으면 기본값.
    var locationChipText: String {
        currentRegion ?? LocationProvider.shared.displayRegionName
    }

    // MARK: - Init

    override init() {
        super.init()
        loadRecent()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationAuthStatus = locationManager.authorizationStatus
    }

    // MARK: - 위치 칩

    /// 화면 진입 시 권한 있으면 현재위치 1회 요청
    func refreshLocationIfAuthorized() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }

    /// 위치 칩 탭: 권한 상태별 분기
    func handleLocationChipTap() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            openAppSettings()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()   // 현재위치 갱신
        @unknown default:
            break
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "ko_KR")
        ) { [weak self] placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let region = RegionName.short(
                admin: placemark.administrativeArea,
                locality: placemark.locality
            )
            Task { @MainActor in
                self?.currentRegion = region
            }
        }
    }

    // MARK: - 최근 검색

    private func loadRecent() {
        recentSearches = RecentSearchStore.load()
    }

    func addRecent(_ term: String) {
        RecentSearchStore.add(term)
        recentSearches = RecentSearchStore.load()
    }

    func removeRecent(_ term: String) {
        RecentSearchStore.remove(term)
        recentSearches = RecentSearchStore.load()
    }

    func clearRecent() {
        RecentSearchStore.clear()
        recentSearches = RecentSearchStore.load()
    }

    // MARK: - 검색 실행

    /// 검색 실행. 무입력이면 nil 반환(방지). 성공 시 최근검색에 추가하고 검색어 반환.
    @discardableResult
    func submitSearch() -> String? {
        guard canSearch else { return nil }
        let term = query.trimmingCharacters(in: .whitespaces)
        addRecent(term)
        return term
    }

    /// 최근검색어 재사용
    func reuse(_ term: String) -> String {
        query = term
        addRecent(term)
        return term
    }

    // MARK: - 유사 검색어 (카카오 키워드 검색 직접 호출)

    func updateSuggestions() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            suggestions = []
            return
        }
        do {
            let places = try await KakaoLocalService.searchKeyword(q, near: currentCoordinate, size: 15)
            // 응답 지연 사이 검색어가 바뀌었으면 무시
            guard q == query.trimmingCharacters(in: .whitespaces) else { return }
            suggestions = places.map {
                SearchSuggestion(id: $0.id, name: $0.name, address: $0.roadAddress ?? $0.address)
            }
        } catch {
            suggestions = []
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension SearchViewModel: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentCoordinate = location.coordinate
            self.reverseGeocode(location)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.locationAuthStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 위치 실패 시 칩은 "위치 권한 허용" 유지 (별도 처리 없음)
    }
}
