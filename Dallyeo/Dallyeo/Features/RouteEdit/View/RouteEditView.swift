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

    init(draft: RouteDraft, onConfirm: (() -> Void)? = nil) {
        _viewModel = State(initialValue: RouteEditViewModel(draft: draft))
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 0) {
            editPanel
            mapArea
        }
        .background(AppColor.white)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 편집 패널

    private var editPanel: some View {
        VStack(spacing: 0) {
            pointRow(name: viewModel.start?.name, placeholder: "출발지 설정", trailing: .none)
            Divider()

            ForEach(viewModel.waypoints) { wp in
                pointRow(
                    name: wp.name.isEmpty ? nil : wp.name,
                    placeholder: "경유지 설정",
                    trailing: .remove(wp)
                )
                Divider()
            }

            // 도착지 행 + 경유지 추가(+)
            pointRow(name: viewModel.destination?.name, placeholder: "도착지 설정", trailing: .add)
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

    private func pointRow(name: String?, placeholder: String, trailing: RowTrailing) -> some View {
        ZStack {
            // 지점명 (가운데 정렬)
            Text(name ?? placeholder)
                .font(.system(size: 16))
                .foregroundStyle(name == nil ? AppColor.gray500 : AppColor.gray900)
                .frame(maxWidth: .infinity, alignment: .center)

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

    // MARK: - 지도 + 거리

    private var mapArea: some View {
        KakaoMapView(
            userLocation: nil,
            places: viewModel.markerPlaces,
            showsPlaceMarkers: true
        )
        .overlay(alignment: .top) {
            // 총 거리 말풍선 (TODO: T MAP 실제 경로 거리)
            Text("총 \(viewModel.totalDistanceText)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppColor.primary, in: Capsule())
                .padding(.top, 12)
        }
    }
}
