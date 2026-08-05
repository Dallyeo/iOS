//
//  SearchResultViewModel.swift
//  Dallyeo
//
//  V05 검색결과뷰 ViewModel — BE /places/search 우선, 없으면 Kakao 폴백.
//

import SwiftUI
import CoreLocation

@MainActor
@Observable
final class SearchResultViewModel {

    var query: String
    var results: [MapPlace] = []
    var isLoading: Bool = false

    /// 검색바 지역칩
    var regionText: String = "군산"

    /// 거리순 정렬용 현재 좌표 (V05 진입 시 주입 가능)
    var currentCoordinate: CLLocationCoordinate2D?

    init(query: String) {
        self.query = query
        // V05 진입 시 검색어를 최근검색에 추가 (스펙)
        RecentSearchStore.add(query)
    }

    /// 검색 실행. BE 큐레이션 검색 우선 → 결과 없으면 Kakao 전국 검색 폴백.
    func search() async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        RecentSearchStore.add(term)
        isLoading = true
        defer { isLoading = false }

        // 1) BE 큐레이션 검색 (썸네일 포함)
        if let beResults = try? await DallyeoAPI.searchPlaces(keyword: term), !beResults.isEmpty {
            results = beResults.map { Self.mapPlace(from: $0) }
            return
        }

        // 2) Kakao 전국 검색 폴백 (사진 없음 — 텍스트 카드 상태)
        do {
            let kakao = try await KakaoLocalService.searchKeyword(term, near: currentCoordinate, size: 15)
            results = kakao.map { Self.mapPlace(from: $0) }
        } catch {
            results = []
        }
    }

    /// 공용 카드 데이터. 리스트에는 영업시간/배지가 없음(상세에서만 제공).
    func cardData(for place: MapPlace) -> PlaceCardData {
        PlaceCardData(
            name: place.name,
            categoryLabel: place.category == .attraction ? "관광지" : "음식점",
            distance: place.distance,
            businessHours: nil,
            address: place.address,
            badges: [],
            imageURLs: place.thumbnailURL.map { [$0] } ?? []
        )
    }

    // MARK: - 매핑

    /// BE PlaceSummary → MapPlace
    private static func mapPlace(from d: PlaceSummaryDTO) -> MapPlace {
        let category: PlaceCategory = d.category.uppercased() == "RESTAURANT" ? .restaurant : .attraction
        let distance = d.distanceMeters.map { m in
            m < 1000 ? "\(Int(m))m" : String(format: "%.1fkm", m / 1000)
        }
        let thumb = d.thumbnailUrl?.replacingOccurrences(of: "http://", with: "https://")
        return MapPlace(
            id: d.id, name: d.name, category: category,
            latitude: d.latitude, longitude: d.longitude,
            thumbnailURL: thumb, distance: distance, address: d.address
        )
    }

    /// Kakao → MapPlace (사진 없음)
    private static func mapPlace(from k: KakaoPlace) -> MapPlace {
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
