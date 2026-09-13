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
    ///
    /// 목록에서 이미 받아온 값을 폴백으로 둔다. `/places/{id}`는 TourAPI를 실시간
    /// 호출해 간헐적으로 502가 나는데(API.md 9-3), 그때 배지까지 사라지면
    /// 목록에선 보이던 게 상세에서 없어져 버린다. 목록과 상세의 배지는 같은 값이다.
    var badges: [String] {
        let fromDetail = PlaceBadge.labels(from: detail?.badges)
        return fromDetail.isEmpty ? place.badges : fromDetail
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
