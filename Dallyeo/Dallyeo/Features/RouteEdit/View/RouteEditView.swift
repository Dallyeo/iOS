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

            // 하단: 지도 (바닥까지 꽉 차게)
            // TODO: 거리 말풍선은 T MAP 경로 폴리라인과 함께 경로 위에 표시
            KakaoMapView(
                userLocation: nil,
                places: viewModel.markerPlaces,
                showsPlaceMarkers: true
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 편집 패널

    private var editPanel: some View {
        VStack(spacing: 0) {
            pointRow(name: viewModel.start?.name, placeholder: "출발지 설정",
                     trailing: .none, slot: .start)
            Divider()

            ForEach(viewModel.waypoints) { wp in
                pointRow(
                    name: wp.name.isEmpty ? nil : wp.name,
                    placeholder: "경유지 설정",
                    trailing: .remove(wp),
                    slot: .waypoint(wp.id)
                )
                Divider()
            }

            // 도착지 행 + 경유지 추가(+)
            pointRow(name: viewModel.destination?.name, placeholder: "도착지 설정",
                     trailing: .add, slot: .destination)
            Divider()

            HStack(spacing: 0) {
                Button("취소") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(AppColor.gray700)
                Button("확인") {
                    onConfirm?()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(viewModel.canConfirm ? AppColor.gray900 : AppColor.gray300)
                .disabled(!viewModel.canConfirm)
            }
            .font(.system(size: 16, weight: .semibold))
            .padding(.vertical, 14)
        }
        .background(AppColor.white)
    }

    private enum RowTrailing {
        case none
        case remove(MapPlace)
        case add
    }

    private func pointRow(name: String?, placeholder: String,
                          trailing: RowTrailing, slot: RouteDraft.EditSlot) -> some View {
        ZStack {
            // 지점명 (가운데 정렬) — 탭 시 검색으로 설정
            Text(name ?? placeholder)
                .font(.system(size: 16))
                .foregroundStyle(name == nil ? AppColor.gray500 : AppColor.gray900)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .onTapGesture { onEditSlot?(slot) }

            // 핸들(좌) + 액션(우)
            HStack {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16))
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
        .padding(.vertical, 16)
    }
}
