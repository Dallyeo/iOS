//
//  RouteEditView.swift
//  Dallyeo
//
//  V07 경로수정뷰 — 경유지 편집 + 경로/거리 표시
//

import SwiftUI

struct RouteEditView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RouteEditViewModel
    var onConfirm: (() -> Void)?
    /// 지점 슬롯 편집(검색으로 채우기) 요청
    var onEditSlot: ((RouteDraft.EditSlot) -> Void)?

    init(draft: RouteDraft,
         onConfirm: (() -> Void)? = nil,
         onEditSlot: ((RouteDraft.EditSlot) -> Void)? = nil) {
        _viewModel = State(initialValue: RouteEditViewModel(draft: draft))
        self.onConfirm = onConfirm
        self.onEditSlot = onEditSlot
    }

    var body: some View {
        VStack(spacing: 0) {
            // 상단: 흰 패널 (하단 라운드 + 그림자, 상태바까지 흰색)
            editPanel
                .background(
                    UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16)
                        .fill(AppColor.white)
                        .ignoresSafeArea(edges: .top)
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                )

            // 하단: 지도 (바닥까지 꽉 차게) + T MAP 경로선 + 총거리 칩
            KakaoMapView(
                userLocation: nil,
                places: [],
                routePolyline: viewModel.routePolyline,
                markers: viewModel.mapMarkers
            )
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                if viewModel.mapMarkers.count >= 2 {
                    distanceChip
                        .padding(.top, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // 지점 구성이 바뀔 때마다 T MAP 보행자 경로 재계산
        .task(id: viewModel.routeSignature) {
            await viewModel.recalculateRoute()
        }
    }

    /// 총 거리 말풍선(칩) — T MAP 실거리(없으면 직선거리)
    private var distanceChip: some View {
        HStack(spacing: 6) {
            if viewModel.isRouting {
                ProgressView().scaleEffect(0.7)
            }
            Text(viewModel.totalDistanceText)
                .font(AppFont.pretendard(14, .semibold))
                .foregroundStyle(AppColor.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppColor.primary, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }

    // MARK: - 편집 패널

    private var editPanel: some View {
        VStack(spacing: 0) {
            pointRow(role: .start, name: viewModel.start?.name, placeholder: "출발지 설정",
                     trailing: .none, slot: .start)
            Divider()

            ForEach(viewModel.waypoints) { wp in
                pointRow(
                    role: .waypoint,
                    name: wp.name.isEmpty ? nil : wp.name,
                    placeholder: "경유지 설정",
                    trailing: .remove(wp),
                    slot: .waypoint(wp.id)
                )
                Divider()
            }

            // 도착지 행 + 경유지 추가(+)
            pointRow(role: .destination, name: viewModel.destination?.name, placeholder: "도착지 설정",
                     trailing: .add, slot: .destination)

            // 취소 / 확인 (각 초록/회색 fill, radius 8)
            HStack(spacing: 16) {
                actionButton("취소", filled: AppColor.gray300, enabled: true) { dismiss() }
                actionButton("확인", filled: viewModel.canConfirm ? AppColor.primary : AppColor.gray300,
                             enabled: viewModel.canConfirm) { onConfirm?() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        .background(AppColor.white)
    }

    private func actionButton(_ title: String, filled: Color, enabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.pretendard(14, .medium))   // P_M_14
                .foregroundStyle(AppColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 37)
                .background(filled, in: RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!enabled)
    }

    private enum PointRole { case start, waypoint, destination }

    private enum RowTrailing {
        case none
        case remove(MapPlace)
        case add
    }

    private func pointRow(role: PointRole, name: String?, placeholder: String,
                          trailing: RowTrailing, slot: RouteDraft.EditSlot) -> some View {
        let isFilled = name != nil
        // 출발/도착 = SemiBold Gray900, 경유 = Medium Gray700, 미설정 = Gray500
        let nameFont = role == .waypoint ? AppFont.pretendard(15, .medium) : AppFont.pretendard(15, .semibold)
        let nameColor: Color = !isFilled ? AppColor.gray500
            : (role == .waypoint ? AppColor.gray700 : AppColor.gray900)

        return ZStack {
            // 지점명 (가운데 정렬) — 탭 시 검색으로 설정
            Text(name ?? placeholder)
                .font(nameFont)
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 44)
                .contentShape(Rectangle())
                .onTapGesture { onEditSlot?(slot) }

            // 순서 핸들(좌, 상하 chevron) + 액션(우)
            HStack {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColor.gray500)
                Spacer()
                switch trailing {
                case .none:
                    Color.clear.frame(width: 24, height: 24)
                case .remove(let place):
                    Button { viewModel.removeWaypoint(place) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 18))
                            .foregroundStyle(AppColor.gray500)
                            .frame(width: 24, height: 24)
                    }
                case .add:
                    Button { viewModel.addWaypointSlot() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                            .foregroundStyle(viewModel.canAddWaypoint ? AppColor.gray500 : AppColor.gray300)
                            .frame(width: 24, height: 24)
                    }
                    .disabled(!viewModel.canAddWaypoint)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }
}
