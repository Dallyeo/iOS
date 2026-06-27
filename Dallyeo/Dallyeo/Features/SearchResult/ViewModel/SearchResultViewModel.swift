//
//  SearchResultViewModel.swift
//  Dallyeo
//
//  V05 검색결과뷰 ViewModel — 검색어, 결과 목록(지도 핀 + 리스트)
//

import SwiftUI

@MainActor
@Observable
final class SearchResultViewModel {

    var query: String
    var results: [MapPlace] = []
    var isLoading: Bool = false

    init(query: String) {
        self.query = query
        // V05 진입 시 검색어를 최근검색에 추가 (스펙)
        RecentSearchStore.add(query)
    }

    /// 검색 실행 (TODO: 백엔드 TourAPI 키워드 검색 프록시 연동)
    func search() async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        RecentSearchStore.add(term)
        isLoading = true
        // 백엔드 연동 전 stub — 군산 좌표 더미 결과 (마커/리스트 검증용)
        results = Self.dummyResults(for: term)
        isLoading = false
    }

    // MARK: - 더미 데이터 (백엔드 연동 시 제거)

    private static func dummyResults(for term: String) -> [MapPlace] {
        [
            MapPlace(id: "1", name: "\(term) 군산수송점", category: .restaurant,
                     latitude: 35.9745, longitude: 126.7180, thumbnailURL: nil,
                     distance: nil, address: "전북특별자치도 군산시 서수송1길 2 1층"),
            MapPlace(id: "2", name: "\(term) 군산점", category: .restaurant,
                     latitude: 35.9678, longitude: 126.7365, thumbnailURL: nil,
                     distance: nil, address: "전북특별자치도 군산시 조촌로 4"),
            MapPlace(id: "3", name: "\(term) 나운점", category: .restaurant,
                     latitude: 35.9601, longitude: 126.7012, thumbnailURL: nil,
                     distance: nil, address: "전북특별자치도 군산시 나운로 121")
        ]
    }
}
