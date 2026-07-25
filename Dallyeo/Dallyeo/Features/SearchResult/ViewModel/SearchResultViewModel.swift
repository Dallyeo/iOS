//
//  SearchResultViewModel.swift
//  Dallyeo
//
//  V05 검색결과뷰 ViewModel — 검색어, 결과 목록(지도 핀 + 리스트)
//

import SwiftUI
import CoreLocation

@MainActor
@Observable
final class SearchResultViewModel {

    var query: String
    var results: [MapPlace] = []
    var isLoading: Bool = false

    /// 거리순 정렬용 현재 좌표 (V05 진입 시 주입 가능)
    var currentCoordinate: CLLocationCoordinate2D?

    init(query: String) {
        self.query = query
        // V05 진입 시 검색어를 최근검색에 추가 (스펙)
        RecentSearchStore.add(query)
    }

    /// 검색 실행 (카카오 키워드 검색 직접 호출)
    func search() async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        RecentSearchStore.add(term)
        isLoading = true
        defer { isLoading = false }
        do {
            let places = try await KakaoLocalService.searchKeyword(term, near: currentCoordinate, size: 15)
            results = places.map { Self.mapPlace(from: $0) }
        } catch {
            results = []
        }
    }

    // MARK: - 매핑

    private static func mapPlace(from k: KakaoPlace) -> MapPlace {
        // 카카오 category_group_code: FD6(음식점)/CE7(카페) → 음식점, 그 외 → 관광지
        let category: PlaceCategory = (k.categoryGroupCode == "FD6" || k.categoryGroupCode == "CE7")
            ? .restaurant : .attraction
        return MapPlace(
            id: k.id,
            name: k.name,
            category: category,
            latitude: k.coordinate.latitude,
            longitude: k.coordinate.longitude,
            thumbnailURL: nil,
            distance: k.distance.flatMap { Int($0) }.map { $0 < 1000 ? "\($0)m" : String(format: "%.1fkm", Double($0) / 1000) },
            address: k.roadAddress ?? k.address
        )
    }
}
