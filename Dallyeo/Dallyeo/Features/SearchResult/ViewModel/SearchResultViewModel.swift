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
    /// 지역 칩 텍스트. 공용 위치 제공자에서 읽는다(V03/V04와 동일한 값).
    var regionText: String { LocationProvider.shared.displayRegionName }

    /// 현위치. 카드의 거리 표시와 Kakao 거리순 정렬에 쓴다.
    /// 예전엔 주입받는 프로퍼티였는데 아무도 넣어주지 않아 항상 nil이었고,
    /// 그래서 카드에 거리가 한 번도 뜨지 않았다. 지역 칩처럼 공용 제공자에서 읽는다.
    private var currentCoordinate: CLLocationCoordinate2D? { LocationProvider.shared.current }

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
        //    좌표 없는 항목은 지도에 찍을 수 없어 제외한다 → 남는 게 없으면 Kakao로 넘어간다.
        let origin = currentCoordinate

        if let beResults = try? await DallyeoAPI.searchPlaces(keyword: term) {
            let mapped = beResults.compactMap { Self.mapPlace(from: $0, origin: origin) }
            if !mapped.isEmpty {
                results = mapped
                return
            }
        }

        // 2) Kakao 전국 검색 폴백 (사진 없음 — 텍스트 카드 상태)
        do {
            let kakao = try await KakaoLocalService.searchKeyword(term, near: origin, size: 15)
            results = kakao.map { Self.mapPlace(from: $0, origin: origin) }
        } catch {
            results = []
        }
    }

    /// 공용 카드 데이터. 리스트에는 영업시간/배지가 없음(상세에서만 제공).
    func cardData(for place: MapPlace) -> PlaceCardData {
        PlaceCardData(
            name: place.name,
            categoryLabel: place.categoryLabel,
            distance: place.distance,
            businessHours: nil,
            address: place.address,
            badges: place.badges,
            imageURLs: place.thumbnailURL.map { [$0] } ?? []
        )
    }

    // MARK: - 매핑

    /// 현위치 → 장소 직선거리(m). 현위치를 모르면 nil.
    private static func meters(from origin: CLLocationCoordinate2D?,
                               to coord: CLLocationCoordinate2D) -> Double? {
        guard let origin else { return nil }
        return CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
    }

    private static func distanceText(_ meters: Double?) -> String? {
        guard let meters else { return nil }
        return meters < 1000 ? "\(Int(meters))m" : String(format: "%.1fkm", meters / 1000)
    }

    /// BE PlaceSummary → MapPlace. 좌표가 없으면 nil(지도에 찍을 수 없다).
    private static func mapPlace(from d: PlaceSummaryDTO,
                                 origin: CLLocationCoordinate2D?) -> MapPlace? {
        guard let coord = d.coordinate else { return nil }
        let category = PlaceCategory(backend: d.category)
        // `/places/search`는 distanceMeters를 주지 않는다(`/places/nearby` 전용).
        // Figma 카드에는 현위치 기준 거리가 있어야 하므로 직접 잰다.
        let meters = d.distanceMeters ?? Self.meters(from: origin, to: coord)
        let thumb = d.thumbnailUrl?.replacingOccurrences(of: "http://", with: "https://")
        return MapPlace(
            id: d.id, name: d.name, category: category,
            latitude: coord.latitude, longitude: coord.longitude,
            thumbnailURL: thumb, distance: distanceText(meters), address: d.address,
            badges: PlaceBadge.labels(from: d.badges)
        )
    }

    /// Kakao → MapPlace (사진 없음)
    private static func mapPlace(from k: KakaoPlace,
                                 origin: CLLocationCoordinate2D?) -> MapPlace {
        // 카카오 분류를 우리 분류로 옮긴다. 없는 종류(지하철역·은행 등)는
        // 카카오가 준 이름을 그대로 보여준다 — 예전에는 전부 "관광지"로 뭉갰다.
        let mapped = PlaceCategory.from(kakaoGroupCode: k.categoryGroupCode)
        let category = mapped ?? .tour
        let labelOverride = mapped == nil ? k.categoryGroupName : nil
        return MapPlace(
            id: k.id,
            name: k.name,
            category: category,
            latitude: k.coordinate.latitude,
            longitude: k.coordinate.longitude,
            thumbnailURL: nil,
            // 카카오가 near 좌표를 받았을 때만 distance를 준다. 없으면 직접 잰다.
            distance: distanceText(k.distance.flatMap(Double.init)
                                   ?? meters(from: origin, to: k.coordinate)),
            address: k.roadAddress ?? k.address,
            categoryLabelOverride: labelOverride
        )
    }
}
