//
//  PlaceCardView.swift
//  Dallyeo
//
//  장소 카드 (바텀시트 그리드 아이템)
//

import SwiftUI

struct PlaceCardView: View {

    let place: MapPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 썸네일
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .aspectRatio(177.0 / 160.0, contentMode: .fit)
                .overlay {
                    if let urlString = place.thumbnailURL,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color(.systemGray5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

            // 장소명
            Text(place.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            // 거리
            if let distance = place.distance {
                Text(distance)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
