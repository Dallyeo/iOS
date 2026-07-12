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
            thumbnail
                .aspectRatio(177.0 / 173.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

            // 텍스트 영역 (padding 14)
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColor.gray900)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let subtitle = place.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColor.gray500)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if let badge = place.badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColor.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            // Figma 배지 배경 #C6F3DF
                            .background(
                                Color(red: 198 / 255, green: 243 / 255, blue: 223 / 255),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }
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
