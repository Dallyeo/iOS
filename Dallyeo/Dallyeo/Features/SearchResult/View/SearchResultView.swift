//
//  SearchResultView.swift
//  Dallyeo
//
//  V05 검색결과뷰 — 지도(결과 핀) + 검색바 + 바텀시트(결과 리스트)
//

import SwiftUI

struct SearchResultView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SearchResultViewModel
    @FocusState private var fieldFocused: Bool

    /// 네비게이션 최상단일 때만 바텀시트 표시 (push된 화면 위 시트 충돌 방지)
    var bottomSheetVisible: Bool = true
    /// 결과 선택 시 V06 위치정보뷰로
    var onSelectPlace: ((MapPlace) -> Void)?

    init(query: String, bottomSheetVisible: Bool = true, onSelectPlace: ((MapPlace) -> Void)? = nil) {
        _viewModel = State(initialValue: SearchResultViewModel(query: query))
        self.bottomSheetVisible = bottomSheetVisible
        self.onSelectPlace = onSelectPlace
    }

    var body: some View {
        KakaoMapView(
            userLocation: nil,
            places: viewModel.results,
            showsPlaceMarkers: true
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: .constant(bottomSheetVisible)) {
            resultSheet
                .presentationDetents([.height(120), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColor.white)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .interactiveDismissDisabled()
        }
        .task {
            await viewModel.search()
        }
    }

    // MARK: - 검색바

    private var searchBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.gray900)
                    .frame(width: 24, height: 24)
            }

            HStack(spacing: 8) {
                TextField("장소 검색", text: $viewModel.query)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.gray900)
                    .focused($fieldFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await viewModel.search() } }

                // 현재 지역 칩 (초록)
                Text(viewModel.regionText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 8))

                if !viewModel.query.isEmpty {
                    Button { viewModel.query = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.gray500)
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(AppColor.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColor.gray300, lineWidth: 1)
            )
        }
    }

    // MARK: - 결과 바텀시트

    private var resultSheet: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, place in
                    Button { onSelectPlace?(place) } label: {
                        PlaceSummaryCard(data: viewModel.cardData(for: place))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 카드 사이 구분선 (0.5pt, #B8B8B8)
                    if index < viewModel.results.count - 1 {
                        Rectangle()
                            .fill(AppColor.disabled)
                            .frame(height: 0.5)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(AppColor.white)
    }
}
