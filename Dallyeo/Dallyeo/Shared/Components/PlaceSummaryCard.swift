//
//  PlaceSummaryCard.swift
//  Dallyeo
//
//  장소 요약 카드 (V05 검색결과 행 / V06 위치정보 상단 공용)
//  Figma 실측: 제목 P_SB_17, 카테고리 P_L_12, 거리 SF_SB_15, 시간 SF_L_12,
//  주소 SF_M_12, 배지 P_SB_10(bg P_200 r8 pad5×16), 사진 190×127 r8 가로스크롤.
//

import SwiftUI

/// 카드 표시 데이터. 소스(BE 상세/BE 요약/Kakao)마다 채워지는 필드가 다름 — 없는 건 자연스럽게 생략.
struct PlaceCardData {
    let name: String
    let categoryLabel: String
    let distance: String?
    let businessHours: String?
    let address: String?
    let badges: [String]
    let imageURLs: [String]
}

struct PlaceSummaryCard: View {

    /// 사진 영역 크기. 화면마다 다르다.
    enum PhotoLayout {
        /// V05 검색결과 행 — 190×100 여러 장 가로 스크롤, 간격 16 (Figma 542:944)
        case list
        /// V06 위치정보 — 370×127 카드 폭 꽉 참 (Figma 542:1012)
        case detail

        var photoWidth: CGFloat { self == .list ? 190 : 370 }
        var photoHeight: CGFloat { self == .list ? 100 : 127 }
        var spacing: CGFloat { self == .list ? 16 : 0 }
    }

    let data: PlaceCardData
    /// 사진 탭 콜백. 지정 시 사진이 탭 가능(전체화면 뷰어용). nil이면 사진은 표시만(카드 전체 탭이 우선).
    var onPhotoTap: ((Int) -> Void)? = nil
    var photoLayout: PhotoLayout = .list

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBlock
            photoStrip
        }
    }

    // 제목/카테고리/거리/시간/주소 + 우측 배지
    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(data.name)
                        .font(AppFont.pretendard(17, .semibold))   // P_SB_17
                        .foregroundStyle(AppColor.gray900)
                        .lineLimit(1)
                    Text(data.categoryLabel)
                        .font(AppFont.pretendard(12, .light))       // P_L_12
                        .foregroundStyle(AppColor.gray700)
                }

                HStack(spacing: 8) {
                    if let distance = data.distance {
                        Text(distance)
                            .font(AppFont.sf(15, .semibold))         // SF_SB_15
                            .foregroundStyle(AppColor.gray700)
                    }
                    if let hours = data.businessHours {
                        Text(hours)
                            .font(AppFont.sf(12, .light))            // SF_L_12
                            .foregroundStyle(AppColor.gray700)
                            .lineLimit(1)
                    }
                }

                if let address = data.address {
                    Text(address)
                        .font(AppFont.sf(12, .medium))               // SF_M_12
                        .foregroundStyle(AppColor.gray700)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if !data.badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(data.badges, id: \.self) { badge in
                        Text(badge)
                            .font(AppFont.pretendard(10, .semibold)) // P_SB_10
                            .tracking(-0.2)
                            .foregroundStyle(AppColor.primary)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .background(AppColor.primary200, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // 사진 영역. 크기는 화면(photoLayout)에 따라 다르고, 없으면 빈 자리를 그린다.
    @ViewBuilder
    private var photoStrip: some View {
        if data.imageURLs.isEmpty {
            photoPlaceholder
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: photoLayout.spacing) {
                    ForEach(Array(data.imageURLs.enumerated()), id: \.element) { index, urlString in
                        if let onPhotoTap {
                            Button { onPhotoTap(index) } label: { photo(urlString) }
                                .buttonStyle(.plain)
                        } else {
                            photo(urlString)
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    /// 사진 없음 자리. 사진 한 장이 아니라 **카드 폭 전체(370)** 를 차지한다.
    /// (Figma: V05 리스트 822:5193 370×100 / V06 상세 822:5140 370×127)
    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppColor.gray200)
            .frame(width: 370, height: photoLayout.photoHeight)
            .overlay {
                Image("ic_hide_image")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(AppColor.gray300)
            }
    }

    private func photo(_ urlString: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppColor.gray200)
            .frame(width: photoLayout.photoWidth, height: photoLayout.photoHeight)
            .overlay {
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
