//
//  CourseConfirmView.swift
//  Dallyeo
//
//  V08 코스확인뷰 — 지도(경로선 + 지점/주변 마커) + 코스 요약 카드 + 러닝 시작.
//  Figma 565:523 기준.
//

import SwiftUI

struct CourseConfirmView: View {

    @State private var viewModel: CourseConfirmViewModel
    /// "수정" → V07 경로수정으로 복귀
    var onEdit: (() -> Void)?
    /// "러닝 시작하기" → V09 코스진행 (카운트다운은 V09에서)
    var onStart: (() -> Void)?

    /// V07에서 만든 코스로 진입
    init(draft: RouteDraft,
         onEdit: (() -> Void)? = nil,
         onStart: (() -> Void)? = nil) {
        _viewModel = State(initialValue: CourseConfirmViewModel(draft: draft))
        self.onEdit = onEdit
        self.onStart = onStart
    }

    /// 추천 코스(BE)로 진입
    init(courseId: String,
         onEdit: (() -> Void)? = nil,
         onStart: (() -> Void)? = nil) {
        _viewModel = State(initialValue: CourseConfirmViewModel(courseId: courseId))
        self.onEdit = onEdit
        self.onStart = onStart
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.gray200
                .ignoresSafeArea()

            KakaoMapView(
                userLocation: nil,
                places: viewModel.nearbyPlaces,
                showsPlaceMarkers: true,
                routePolyline: viewModel.routePolyline,
                markers: viewModel.mapMarkers
            )
            .ignoresSafeArea()

            bottomPanel
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
    }

    // MARK: - 하단 패널 (grabber + 카드 + 시작 버튼)

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(AppColor.grabber)
                .frame(width: 50, height: 5)

            content

            startButton
        }
        .padding(.top, 10)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                .fill(AppColor.whiteDim)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -4)
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(width: 370, height: 200)
        } else if viewModel.loadFailed {
            VStack(spacing: 12) {
                Text("코스를 불러오지 못했어요.")
                    .font(AppFont.pretendard(15, .medium))
                    .foregroundStyle(AppColor.gray500)
                Button("다시 시도") {
                    Task { await viewModel.load() }
                }
                .font(AppFont.pretendard(15, .semibold))
                .foregroundStyle(AppColor.primary)
            }
            .frame(width: 370, height: 200)
        } else {
            CourseSummaryCard(
                distanceText: viewModel.totalDistanceText,
                points: viewModel.points,
                onEdit: onEdit
            )
        }
    }

    private var startButton: some View {
        Button { onStart?() } label: {
            Text("러닝 시작하기")
                .font(AppFont.pretendard(17, .semibold))
                .foregroundStyle(AppColor.white)
                .frame(width: 370, height: 59)
                .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.course == nil)
        .opacity(viewModel.course == nil ? 0.5 : 1)
    }
}
