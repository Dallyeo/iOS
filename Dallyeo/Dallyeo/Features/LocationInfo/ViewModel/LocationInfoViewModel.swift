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
        place.categoryLabel
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

    /// 배지 목록 (예: 모범음식점, 착한가격업소).
    /// BE가 코드 문자열로 주므로 한글로 옮겨서 내보낸다.
    var badges: [String] {
        PlaceBadge.labels(from: detail?.badges)
    }

    /// 표시할 사진 한 장. 상세 이미지를 우선하고 없으면 카드 썸네일을 쓴다.
    ///
    /// 예전에는 둘 다 넣어 가로 스크롤로 보여줬는데, 같은 장소 사진이 두 장
    /// 겹쳐 나오고 두 번째가 화면 밖으로 걸쳐 보여 어색했다. 팀 결정으로 한 장만 쓴다.
    var imageURLs: [String] {
        guard let url = detail?.imageUrl ?? place.thumbnailURL else { return [] }
        return [url.replacingOccurrences(of: "http://", with: "https://")]
    }

    /// 공용 카드 데이터
    var cardData: PlaceCardData {
        PlaceCardData(
            name: place.name,
            categoryLabel: categoryLabel,
            distance: place.distance,
            businessHours: businessHours,
            address: place.address,
            badges: badges,
            imageURLs: imageURLs
        )
    }
}
