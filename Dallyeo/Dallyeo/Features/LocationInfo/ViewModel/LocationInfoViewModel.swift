//
//  LocationInfoViewModel.swift
//  Dallyeo
//
//  V06 위치정보뷰 ViewModel — /places/{id} 상세 로드
//

import SwiftUI

@MainActor
@Observable
final class LocationInfoViewModel {

    let place: MapPlace

    /// BE 상세 (영업시간/이미지/배지). 로드 전엔 nil.
    var detail: PlaceDetailDTO?
    var isLoading = false

    init(place: MapPlace) {
        self.place = place
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        detail = try? await DallyeoAPI.placeDetail(id: place.id)
    }

    // MARK: - 표시 값

    var categoryLabel: String {
        place.category == .attraction ? "관광지" : "음식점"
    }

    /// 영업시간. BE가 `<br>` 태그를 섞어 보내므로 개행으로 치환.
    var businessHours: String? {
        guard let raw = detail?.businessHours, !raw.isEmpty else { return nil }
        return raw
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 배지 목록 (예: 러닝 추천, 착한식당)
    var badges: [String] {
        detail?.badges ?? []
    }

    /// 가로 스크롤 이미지 목록. 상세 imageUrl + 카드 썸네일 (중복/nil 제거, http→https).
    var imageURLs: [String] {
        var urls: [String] = []
        if let d = detail?.imageUrl { urls.append(d) }
        if let t = place.thumbnailURL { urls.append(t) }
        return urls
            .map { $0.replacingOccurrences(of: "http://", with: "https://") }
            .reduce(into: [String]()) { acc, u in if !acc.contains(u) { acc.append(u) } }
    }
}
