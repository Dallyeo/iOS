//
//  LocationInfoView.swift
//  Dallyeo
//
//  V06 위치정보뷰 — 장소 상세 + 출발/경유/도착 설정 (HiFi 반영)
//

import SwiftUI

struct LocationInfoView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(RouteDraft.self) private var routeDraft

    @State private var viewModel: LocationInfoViewModel
    /// 사진 전체화면 뷰어 시작 인덱스 (nil이면 닫힘)
    @State private var photoViewerIndex: Int?
    /// 바텀시트 현재 단. 기본은 중간.
    @State private var sheetDetent: PresentationDetent = .height(340)
    var bottomSheetVisible: Bool = true
    /// 역할 설정 완료 → V07 경로수정뷰로
    var onRoleSet: (() -> Void)?
    /// 검색바 탭 — V04로 돌아가 검색어 수정
    var onEditQuery: (() -> Void)?
    /// 닫기(X) — 검색 초기 화면(V03)으로
    var onClose: (() -> Void)?

    init(
        place: MapPlace,
        bottomSheetVisible: Bool = true,
        onRoleSet: (() -> Void)? = nil,
        onEditQuery: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: LocationInfoViewModel(place: place))
        self.bottomSheetVisible = bottomSheetVisible
        self.onRoleSet = onRoleSet
        self.onEditQuery = onEditQuery
        self.onClose = onClose
    }

    private var place: MapPlace { viewModel.place }

    var body: some View {
        KakaoMapView(
            userLocation: nil,
            places: [place],
            showsPlaceMarkers: true
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            // Figma 542:992 — V05와 같은 헤더를 쓴다(디자인상 V06은 V05의 상세 상태).
            SearchContextHeader(
                query: place.name,
                regionText: LocationProvider.shared.displayRegionName,
                onBack: { dismiss() },                        // → V05
                onEditQuery: { onEditQuery?() ?? dismiss() }, // → V04
                onClose: { onClose?() }                       // → V03
            )
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: .constant(bottomSheetVisible)) {
            detailSheet
                // 스펙 V06: 꽉참/중간/최소 3단 고정.
                // 최소는 "지점명 + 출발/경유/도착만 남는" 높이.
                // detent만 나열하면 가장 낮은 단으로 열려서, 기본은 중간으로 고정한다.
                .presentationDetents(
                    [.height(Self.minSheetHeight), .height(340), .large],
                    selection: $sheetDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .interactiveDismissDisabled()
        }
        .task { await viewModel.load() }
    }

    /// 바텀시트 최소 높이 — 드래그바 + 지점명/카테고리 + 역할 버튼(40) + 여백.
    /// 이보다 낮추면 출발/경유/도착 버튼이 가려져 스펙("지점명, 출발지, 경유지,
    /// 도착지만 남기고 축소")을 못 맞춘다.
    private static let minSheetHeight: CGFloat = 150

    // MARK: - 상세 바텀시트

    private var detailSheet: some View {
        ScrollView {
            PlaceSummaryCard(
                data: viewModel.cardData,
                onPhotoTap: { photoViewerIndex = $0 },
                photoLayout: .detail
            )
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background(AppColor.white)
        .safeAreaInset(edge: .bottom) { roleButtons }
        // 사진 탭 → 전체화면 뷰어 (Notion V06: "꽉찬 화면으로 사진 보기")
        .fullScreenCover(item: Binding(
            get: { photoViewerIndex.map(PhotoIndex.init) },
            set: { photoViewerIndex = $0?.value }
        )) { item in
            PhotoViewer(urls: viewModel.imageURLs, startIndex: item.value)
        }
    }

    /// fullScreenCover(item:) 용 Identifiable 래퍼
    private struct PhotoIndex: Identifiable {
        let value: Int
        var id: Int { value }
    }

    // MARK: - 출발 / 경유 / 도착 (각 70×40, radius 24, gap 10, 우측 정렬)

    private var roleButtons: some View {
        HStack(spacing: 10) {
            Spacer()
            roleButton("출발", style: .outline) {
                routeDraft.setStart(place)
                onRoleSet?()
            }
            roleButton("경유", style: .tonal) {
                routeDraft.addWaypoint(place, currentLocation: RouteDraft.currentLocationPlace(LocationProvider.shared.currentTuple))
                onRoleSet?()
            }
            roleButton("도착", style: .filled) {
                routeDraft.setDestination(place, currentLocation: RouteDraft.currentLocationPlace(LocationProvider.shared.currentTuple))
                onRoleSet?()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private enum RoleStyle { case outline, tonal, filled }

    private func roleButton(_ title: String, style: RoleStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.sf(15, .medium))   // SF_M_15
                .foregroundStyle(style == .filled ? AppColor.white : AppColor.primary)
                .frame(width: 70, height: 40)
                .background {
                    switch style {
                    case .outline:
                        RoundedRectangle(cornerRadius: 24)
                            .fill(AppColor.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(AppColor.primary, lineWidth: 1)
                            )
                    case .tonal:
                        RoundedRectangle(cornerRadius: 24).fill(AppColor.primary200)
                    case .filled:
                        RoundedRectangle(cornerRadius: 24).fill(AppColor.primary)
                    }
                }
        }
    }
}
