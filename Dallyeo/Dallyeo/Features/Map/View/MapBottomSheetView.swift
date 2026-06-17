//
//  MapBottomSheetView.swift
//  Dallyeo
//
//  V03 바텀시트 콘텐츠 (세그먼트 + 장소 그리드)
//

import SwiftUI

struct MapBottomSheetView: View {

    @Binding var selectedSegment: MapViewModel.PlaceSegment
    let places: [MapPlace]
    let isLoading: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 세그먼트
            segmentControl
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 12)

            // 장소 그리드
            if isLoading {
                loadingGrid
            } else if places.isEmpty {
                emptyView
            } else {
                placeGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 세그먼트

    private var segmentControl: some View {
        HStack(spacing: 8) {
            ForEach(MapViewModel.PlaceSegment.allCases, id: \.self) { segment in
                Button {
                    selectedSegment = segment
                } label: {
                    Text(segment.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            selectedSegment == segment
                                ? AppColor.gray700
                                : AppColor.gray500
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedSegment == segment
                                ? AppColor.white
                                : Color.clear
                            , in: RoundedRectangle(cornerRadius: 8)
                        )
                }
            }
        }
        .padding(4)
        .background(AppColor.gray250, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 그리드

    private var placeGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(places) { place in
                    PlaceCardView(place: place)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 로딩

    private var loadingGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColor.gray300)
                        .aspectRatio(177.0 / 160.0, contentMode: .fit)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 비어있을 때

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("주변 장소를 불러오는 중이에요")
                .font(.system(size: 14))
                .foregroundStyle(AppColor.gray500)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
