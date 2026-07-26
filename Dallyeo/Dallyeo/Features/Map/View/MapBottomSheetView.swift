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
    /// 카드 탭 → V06 위치정보뷰 진입
    var onSelectPlace: ((MapPlace) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 세그먼트
            segmentControl
                .padding(.horizontal, 16)
                .padding(.top, 23)
                .padding(.bottom, 24)   // Figma 컨테이너 gap 24

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
                        .font(.system(size: 15, weight: selectedSegment == segment ? .bold : .medium))
                        .foregroundStyle(
                            selectedSegment == segment
                                ? AppColor.gray900
                                : AppColor.gray500
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)   // Figma 세그먼트 높이 51
                        .background {
                            if selectedSegment == segment {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColor.white)
                                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(AppColor.gray250, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 그리드

    private var placeGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {   // Figma 행 간격 24
                ForEach(places) { place in
                    Button {
                        onSelectPlace?(place)
                    } label: {
                        PlaceCardView(place: place)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            // 상단은 세그먼트 하단 여백(24)이 담당 → 카드 top padding 없음
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
