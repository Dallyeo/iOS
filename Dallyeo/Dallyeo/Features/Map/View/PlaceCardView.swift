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
            // 썸네일 (상단 라운드) — 실제 사진은 백엔드 thumbnailURL
            thumbnail
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .clipped()

            // 텍스트 영역
            VStack(alignment: .leading, spacing: 4) {
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColor.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppColor.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(AppColor.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
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
