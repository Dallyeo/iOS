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
            VStack(alignment: .leading, spacing: 14) {
                headerBlock
                photoStrip
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background(AppColor.white)
        .safeAreaInset(edge: .bottom) { roleButtons }
    }

    // 제목/카테고리/거리/시간/주소 + 우측 배지
    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                // 이름 + 카테고리
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(place.name)
                        .font(AppFont.pretendard(17, .semibold))   // P_SB_17
                        .foregroundStyle(AppColor.gray900)
                    Text(viewModel.categoryLabel)
                        .font(AppFont.pretendard(12, .light))       // P_L_12
                        .foregroundStyle(AppColor.gray700)
                }

                // 거리 + 영업시간
                HStack(spacing: 8) {
                    if let distance = place.distance {
                        Text(distance)
                            .font(AppFont.sf(15, .semibold))         // SF_SB_15
                            .foregroundStyle(AppColor.gray700)
                    }
                    if let hours = viewModel.businessHours {
                        Text(hours)
                            .font(AppFont.sf(12, .light))            // SF_L_12
                            .foregroundStyle(AppColor.gray700)
                    }
                }

                // 주소
                if let address = place.address {
                    Text(address)
                        .font(AppFont.sf(12, .medium))               // SF_M_12
                        .foregroundStyle(AppColor.gray700)
                }
            }

            Spacer(minLength: 8)

            // 배지 (러닝 추천 / 착한식당) — 우측 상단
            if !viewModel.badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(viewModel.badges, id: \.self) { badge in
                        Text(badge)
                            .font(AppFont.pretendard(10, .semibold)) // P_SB_10
                            .tracking(-0.2)
                            .foregroundStyle(AppColor.primary)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .background(AppColor.primary200, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // 사진 가로 스크롤 (190×127, radius 8)
    @ViewBuilder
    private var photoStrip: some View {
        let urls = viewModel.imageURLs
        if !urls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(urls, id: \.self) { urlString in
                        photo(urlString)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func photo(_ urlString: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppColor.gray200)
            .frame(width: 190, height: 127)
            .overlay {
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                routeDraft.addWaypoint(place, currentLocation: RouteDraft.currentLocationPlace())
                onRoleSet?()
            }
            roleButton("도착", style: .filled) {
                routeDraft.setDestination(place, currentLocation: RouteDraft.currentLocationPlace())
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
