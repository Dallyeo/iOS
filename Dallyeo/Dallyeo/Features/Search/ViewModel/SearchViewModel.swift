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
    var currentAddress: String?                // 역지오코딩 결과 (예: "군산시 내흥2길")

    // MARK: - 저장소

    private let recentKey = "v04_recent_searches"
    private let maxRecent = 10

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

    /// 위치 칩 텍스트: 권한+위치 있으면 현재 주소, 아니면 권한 안내
    var locationChipText: String {
        currentAddress ?? "위치 권한 허용"
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
            // "군산시 내흥2길" = locality + thoroughfare
            let parts = [placemark.locality, placemark.thoroughfare].compactMap { $0 }
            let address = parts.isEmpty ? placemark.name : parts.joined(separator: " ")
            Task { @MainActor in
                self?.currentAddress = address
            }
        }
    }

    // MARK: - 최근 검색

    private func loadRecent() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    func addRecent(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        recentSearches.removeAll { $0 == t }          // 중복 제거 후 최상단
        recentSearches.insert(t, at: 0)
        if recentSearches.count > maxRecent {
            recentSearches = Array(recentSearches.prefix(maxRecent))
        }
        persistRecent()
    }

    func removeRecent(_ term: String) {
        recentSearches.removeAll { $0 == term }
        persistRecent()
    }

    func clearRecent() {
        recentSearches.removeAll()
        persistRecent()
    }

    private func persistRecent() {
        UserDefaults.standard.set(recentSearches, forKey: recentKey)
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

    // MARK: - 유사 검색어 (TODO: 백엔드 TourAPI 키워드 검색 프록시 연동)

    func updateSuggestions() async {
        guard canSearch else {
            suggestions = []
            return
        }
        // TODO: 백엔드 프록시(/search?keyword=) 호출 → suggestions 채우기
        suggestions = []
    }
}

// MARK: - CLLocationManagerDelegate

extension SearchViewModel: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
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
