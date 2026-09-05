//
//  PlaceCardView.swift
//  Dallyeo
//
//  장소 카드 (바텀시트 그리드 아이템) — HiFi
//

import SwiftUI

struct PlaceCardView: View {

    let place: MapPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 썸네일 (177×173 ≈ 정사각) — 실제 사진은 백엔드 thumbnailURL
            // 고정 비율 박스 + 오버레이 + 클립 (scaledToFill 오버플로우 방지)
            Rectangle()
                .fill(AppColor.gray300)
                .aspectRatio(177.0 / 173.0, contentMode: .fit)
                .overlay { thumbnail }
                .clipped()

            // 텍스트 영역 (padding 14)
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(AppFont.sf(15, .semibold))   // Figma: SF Pro Semibold 15
                    .foregroundStyle(AppColor.gray900)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let subtitle = place.subtitle {
                        Text(subtitle)
                            .font(AppFont.pretendard(12, .medium))
                            .foregroundStyle(AppColor.gray500)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    ForEach(place.badges, id: \.self) { badge in
                        Text(badge)
                            .font(AppFont.pretendard(10, .semibold))
                            .foregroundStyle(AppColor.primary)
                            .lineLimit(1)
                            .layoutPriority(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                            .background(
                                AppColor.primary200,   // P_200
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }
                // 배지 유무와 무관하게 행 높이 고정 → 카드 높이 통일
                .frame(minHeight: 24)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .background(AppColor.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlString = place.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                AppColor.gray300
            }
        } else {
            AppColor.gray300
        }
    }
}
