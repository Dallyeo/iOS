//
//  LocationInfoView.swift
//  Dallyeo
//
//  V06 위치정보뷰 — 장소 상세 + 출발/경유/도착 설정
//

import SwiftUI

struct LocationInfoView: View {

    @Environment(\.dismiss) private var dismiss
    let place: MapPlace
    var bottomSheetVisible: Bool = true
    /// 역할 설정 완료 → V07 경로수정뷰로
    var onRoleSet: (() -> Void)?

    @Environment(RouteDraft.self) private var routeDraft

    private var categoryLabel: String {
        place.category == .attraction ? "관광지" : "음식점"
    }

    var body: some View {
        KakaoMapView(
            userLocation: nil,
            places: [place],
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
            detailSheet
                .presentationDetents([.height(300), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .interactiveDismissDisabled()
        }
    }

    // MARK: - 검색바 (장소명 표시)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.gray900)
                    .frame(width: 24, height: 24)
            }
            HStack {
                Text(place.name)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.gray900)
                    .lineLimit(1)
                Spacer()
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

    // MARK: - 상세 바텀시트

    private var detailSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 이름 + 카테고리
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(place.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColor.gray900)
                    Text(categoryLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.gray500)
                }

                // 거리 + 영업시간
                HStack(spacing: 8) {
                    if let distance = place.distance {
                        Text(distance)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.gray900)
                    }
                    Text("00:00-00:00")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.gray500)
                }

                // 주소
                if let address = place.address {
                    Text(address)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.gray500)
                }

                // 이미지
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColor.gray300)
                    .frame(height: 160)
                    .overlay {
                        if let urlString = place.thumbnailURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
            }
            .padding(16)
        }
        .background(AppColor.white)
        .safeAreaInset(edge: .bottom) { roleButtons }
    }

    // MARK: - 출발 / 경유 / 도착

    private var roleButtons: some View {
        HStack(spacing: 8) {
            roleButton("출발", filled: false) {
                routeDraft.setStart(place)
                onRoleSet?()
            }
            roleButton("경유", filled: false) {
                routeDraft.addWaypoint(place, currentLocation: RouteDraft.currentLocationPlace())
                onRoleSet?()
            }
            roleButton("도착", filled: true) {
                routeDraft.setDestination(place, currentLocation: RouteDraft.currentLocationPlace())
                onRoleSet?()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColor.white)
    }

    private func roleButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(filled ? AppColor.white : AppColor.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    if filled {
                        Capsule().fill(AppColor.primary)
                    } else {
                        Capsule().stroke(AppColor.primary, lineWidth: 1.5)
                    }
                }
        }
    }
}
