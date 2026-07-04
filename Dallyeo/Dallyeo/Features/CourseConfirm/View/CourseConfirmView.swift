//
//  CourseConfirmView.swift
//  Dallyeo
//
//  V08 코스확인뷰 — 지도(경로+주변 마커) + 코스 요약 카드 + 러닝 시작
//

import SwiftUI

struct CourseConfirmView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CourseConfirmViewModel
    /// "수정" → V07 경로수정으로 복귀
    var onEdit: (() -> Void)?
    /// "러닝 시작하기" → V09 코스진행 (카운트다운은 V09에서)
    var onStart: (() -> Void)?

    init(draft: RouteDraft,
         onEdit: (() -> Void)? = nil,
         onStart: (() -> Void)? = nil) {
        _viewModel = State(initialValue: CourseConfirmViewModel(draft: draft))
        self.onEdit = onEdit
        self.onStart = onStart
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // TODO: 경로 폴리라인(T MAP) + 주변 편의시설/관광지 마커는 백엔드 연동 시 추가
            KakaoMapView(
                userLocation: nil,
                places: viewModel.routePlaces,
                showsPlaceMarkers: true
            )
            .ignoresSafeArea()

            summaryCard
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 코스 요약 카드

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 수정 칩 + 총 거리
            HStack {
                Button { onEdit?() } label: {
                    Text("수정")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColor.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().stroke(AppColor.primary, lineWidth: 1.5)
                        )
                }
                Spacer()
                Text(viewModel.totalDistanceText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.gray900)
            }

            Rectangle()
                .fill(AppColor.primary)
                .frame(height: 2)

            // 코스 지점 리스트
            VStack(alignment: .leading, spacing: 10) {
                pointRow(label: "출발지", name: viewModel.startName, emphasized: true)
                ForEach(Array(viewModel.waypointNames.enumerated()), id: \.offset) { idx, name in
                    waypointRow(index: idx + 1, name: name)
                }
                pointRow(label: "도착지", name: viewModel.destinationName, emphasized: true)
            }

            Button { onStart?() } label: {
                Text("러닝 시작하기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(AppColor.white)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
        )
    }

    // 출발지 / 도착지 행
    private func pointRow(label: String, name: String, emphasized: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColor.gray900)
            Text("-")
                .foregroundStyle(AppColor.gray500)
            Text(name)
                .font(.system(size: 14, weight: emphasized ? .semibold : .regular))
                .foregroundStyle(AppColor.gray900)
        }
    }

    // 경유지 행 (불릿 + 들여쓰기)
    private func waypointRow(index: Int, name: String) -> some View {
        HStack(spacing: 6) {
            Text("•")
                .foregroundStyle(AppColor.gray500)
            Text("경유지 \(index)")
                .font(.system(size: 13))
                .foregroundStyle(AppColor.gray500)
            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(AppColor.gray700)
            Spacer()
        }
        .padding(.leading, 8)
    }
}
