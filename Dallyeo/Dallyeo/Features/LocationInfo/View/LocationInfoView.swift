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
    var bottomSheetVisible: Bool = true
    /// 역할 설정 완료 → V07 경로수정뷰로
    var onRoleSet: (() -> Void)?

    init(place: MapPlace, bottomSheetVisible: Bool = true, onRoleSet: (() -> Void)? = nil) {
        _viewModel = State(initialValue: LocationInfoViewModel(place: place))
        self.bottomSheetVisible = bottomSheetVisible
        self.onRoleSet = onRoleSet
    }

    private var place: MapPlace { viewModel.place }

    var body: some View {
        KakaoMapView(
            userLocation: nil,
            places: [place],
            showsPlaceMarkers: true
        )
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            backButton
                .padding(.leading, 16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: .constant(bottomSheetVisible)) {
            detailSheet
                .presentationDetents([.height(340), .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .interactiveDismissDisabled()
        }
        .task { await viewModel.load() }
    }

    // MARK: - 뒤로가기 (플로팅 원형, V03과 동일)

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "arrow.backward")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColor.gray900)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(AppColor.white)
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                }
        }
    }

    // MARK: - 상세 바텀시트

    private var detailSheet: some View {
        ScrollView {
            PlaceSummaryCard(
                data: viewModel.cardData,
                onPhotoTap: { photoViewerIndex = $0 }
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
