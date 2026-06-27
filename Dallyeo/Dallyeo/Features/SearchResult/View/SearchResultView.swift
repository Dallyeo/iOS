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

                if !viewModel.query.isEmpty {
                    Button { viewModel.query = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.gray500)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
            LazyVStack(spacing: 12) {
                ForEach(viewModel.results) { place in
                    Button { onSelectPlace?(place) } label: {
                        resultRow(place)
                    }
                }
            }
            .padding(16)
        }
        .background(AppColor.white)
    }

    private func resultRow(_ place: MapPlace) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColor.gray300)
                .frame(width: 56, height: 56)
                .overlay {
                    if let urlString = place.thumbnailURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.gray900)
                    .lineLimit(1)
                if let address = place.address {
                    Text(address)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.gray500)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.gray200, in: RoundedRectangle(cornerRadius: 8))
    }
}
