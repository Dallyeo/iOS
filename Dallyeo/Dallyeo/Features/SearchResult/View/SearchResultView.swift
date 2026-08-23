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
    @State private var sheetDetent: PresentationDetent = .medium

    /// 네비게이션 최상단일 때만 바텀시트 표시 (push된 화면 위 시트 충돌 방지)
    var bottomSheetVisible: Bool = true
    /// 결과 선택 시 V06 위치정보뷰로
    var onSelectPlace: ((MapPlace) -> Void)?
    /// 검색바 탭 — V04로 돌아가 검색어 수정
    var onEditQuery: (() -> Void)?
    /// 닫기(X) — 검색 초기 화면(V03)으로
    var onClose: (() -> Void)?

    init(
        query: String,
        bottomSheetVisible: Bool = true,
        onSelectPlace: ((MapPlace) -> Void)? = nil,
        onEditQuery: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: SearchResultViewModel(query: query))
        self.bottomSheetVisible = bottomSheetVisible
        self.onSelectPlace = onSelectPlace
        self.onEditQuery = onEditQuery
        self.onClose = onClose
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
                .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: .constant(bottomSheetVisible)) {
            resultSheet
                // 기본을 medium으로 연다. 최소(120pt)로 열면 카드가 거의 가려지고
                // 남은 영역이 시트 드래그 영역과 겹쳐, 결과를 눌러도 선택이 아니라
                // 시트 확장으로 먹힌다. Figma(542:925)도 절반쯤 열린 상태가 기본.
                .presentationDetents([.height(120), .medium, .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColor.white)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .interactiveDismissDisabled()
        }
        .task {
            await viewModel.search()
        }
    }

    // MARK: - 검색바 (V06과 공용 — Figma 542:992)

    private var searchBar: some View {
        SearchContextHeader(
            query: viewModel.query,
            regionText: viewModel.regionText,
            onBack: { dismiss() },                       // → V04
            onEditQuery: { onEditQuery?() ?? dismiss() }, // → V04에서 검색어 수정
            onClose: { onClose?() }                      // → V03
        )
    }

    // MARK: - 결과 바텀시트

    private var resultSheet: some View {
        Group {
            if viewModel.results.isEmpty {
                noResultView
            } else {
                resultList
            }
        }
        .background(AppColor.white)
    }

    /// 검색 결과 없음 (Figma 822:4998 V05_empty2)
    private var noResultView: some View {
        VStack(spacing: 15) {
            Image("ic_no_result")
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(AppColor.gray300)
            Text("장소를 찾을 수 없어요")
                .font(AppFont.pretendard(15, .medium))
                .tracking(AppFont.tracking(-2, size: 15))
                .foregroundStyle(AppColor.disabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultList: some View {
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
