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

    /// 지금 끌고 있는 행의 현재 위치. nil이면 드래그 중이 아님.
    @State private var draggingRow: Int?
    /// 이미 한 칸 넘기는 데 쓴 이동량
    @State private var consumedDrag: CGFloat = 0
    /// 행 하나의 세로 간격(행 높이 + 구분선). 첫 행에서 실측해 채운다.
    @State private var rowPitch: CGFloat = 54

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
                markers: viewModel.mapMarkers,
                // 경로 전체가 보이도록 카메라를 맞춘다. 지점이 바뀌면 다시 맞춰진다.
                // (경로 계산 전에는 지점 좌표로라도 맞춘다)
                fitCoordinates: viewModel.routePolyline.isEmpty
                    ? viewModel.mapMarkers.map(\.coordinate)
                    : viewModel.routePolyline,
                fitTopInset: 56   // 총거리 칩이 가리는 높이
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
                     trailing: .none, slot: .start, rowIndex: 0)
            Divider()

            ForEach(Array(viewModel.waypoints.enumerated()), id: \.element.id) { offset, wp in
                pointRow(
                    role: .waypoint,
                    name: wp.name.isEmpty ? nil : wp.name,
                    placeholder: "경유지 설정",
                    trailing: .remove(wp),
                    slot: .waypoint(wp.id),
                    rowIndex: offset + 1
                )
                Divider()
            }

            // 도착지 행 + 경유지 추가(+)
            pointRow(role: .destination, name: viewModel.destination?.name, placeholder: "도착지 설정",
                     trailing: .add, slot: .destination, rowIndex: viewModel.rowCount - 1)

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

    // MARK: - 순서 변경 드래그

    /// 한 칸 넘길 때마다 소모한 이동량. `translation`은 시작점 기준 누적이라
    /// 이미 반영한 만큼을 빼야 다음 칸을 정확히 셀 수 있다.
    private func reorderGesture(startingAt rowIndex: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if draggingRow == nil {
                    draggingRow = rowIndex
                    consumedDrag = 0
                }
                guard let current = draggingRow else { return }

                let remaining = value.translation.height - consumedDrag
                guard abs(remaining) >= rowPitch else { return }

                let step = remaining > 0 ? 1 : -1
                let target = min(max(current + step, 0), viewModel.rowCount - 1)
                guard target != current else { return }

                withAnimation(.snappy(duration: 0.18)) {
                    viewModel.moveRow(from: current, to: target)
                }
                draggingRow = target
                consumedDrag += CGFloat(step) * rowPitch
            }
            .onEnded { _ in
                draggingRow = nil
                consumedDrag = 0
            }
    }

    private enum PointRole { case start, waypoint, destination }

    private enum RowTrailing {
        case none
        case remove(MapPlace)
        case add
    }

    private func pointRow(role: PointRole, name: String?, placeholder: String,
                          trailing: RowTrailing, slot: RouteDraft.EditSlot,
                          rowIndex: Int) -> some View {
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
                // 위아래로 끌어서 지점 순서를 바꾼다.
                Image("ic_expand_all")     // 디자인시스템 expand_all
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(draggingRow == rowIndex ? AppColor.primary : AppColor.gray500)
                    // 잡는 영역만 넓히고 행 높이는 그대로 둔다.
                    // (frame으로 키우면 행이 20pt쯤 두꺼워져 Figma와 어긋난다)
                    .padding(10)
                    .contentShape(Rectangle())
                    .padding(-10)
                    .gesture(reorderGesture(startingAt: rowIndex))
                Spacer()
                switch trailing {
                case .none:
                    Color.clear.frame(width: 24, height: 24)
                case .remove(let place):
                    Button { viewModel.removeWaypoint(place) } label: {
                        Image("ic_check_indeterminate_small")   // 디자인시스템 경유지 제거
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(AppColor.gray500)
                    }
                case .add:
                    Button { viewModel.addWaypointSlot() } label: {
                        Image("ic_add")            // 디자인시스템 add
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(viewModel.canAddWaypoint ? AppColor.gray500 : AppColor.gray300)
                    }
                    .disabled(!viewModel.canAddWaypoint)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        // 드래그로 몇 칸 넘겼는지 세려면 실제 행 간격이 필요하다.
        // 첫 행에서 한 번만 재고 구분선 1pt를 더한다.
        .background {
            if rowIndex == 0 {
                GeometryReader { proxy in
                    Color.clear.onAppear { rowPitch = proxy.size.height + 1 }
                }
            }
        }
    }
}
