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

            ForEach(viewModel.waypoints) { wp in
                pointRow(
                    name: wp.name.isEmpty ? nil : wp.name,
                    placeholder: "경유지 설정",
                    trailing: .remove(wp)
                )
            }

            if viewModel.canAddWaypoint {
                Button { viewModel.addWaypointSlot() } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColor.primary)
                        Text("경유지 추가")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColor.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }

            pointRow(name: viewModel.destination?.name, placeholder: "도착지 설정", trailing: .none)

            Divider()

            HStack(spacing: 0) {
                Button("취소") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(AppColor.gray500)
                Button("확인") {
                    onConfirm?()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(viewModel.canConfirm ? AppColor.primary : AppColor.gray300)
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
    }

    private func pointRow(name: String?, placeholder: String, trailing: RowTrailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundStyle(AppColor.gray500)
            Text(name ?? placeholder)
                .font(.system(size: 16))
                .foregroundStyle(name == nil ? AppColor.gray500 : AppColor.gray900)
            Spacer()
            switch trailing {
            case .none:
                EmptyView()
            case .remove(let place):
                Button { viewModel.removeWaypoint(place) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.gray500)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
