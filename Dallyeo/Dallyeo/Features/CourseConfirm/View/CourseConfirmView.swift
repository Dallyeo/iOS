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
    /// 하단 패널이 지도를 가리는 높이. 코스 전체 보기 시 이만큼 보정한다.
    /// (경유지 수에 따라 패널 높이가 달라져 실측이 필요하다)
    @State private var panelHeight: CGFloat = 0
    /// 상태바/다이나믹 아일랜드에 마커가 가리지 않도록 확보할 상단 높이
    @State private var safeAreaTop: CGFloat = 0
    /// "수정" → V07 경로수정으로 복귀.
    /// nil이면 수정 칩 자체를 감춘다 — 추천 코스는 손댈 수 없다.
    var onEdit: (() -> Void)?
    /// "러닝 시작하기" → V09 코스진행 (카운트다운은 V09에서).
    /// 확정된 코스를 그대로 넘겨 V09가 다시 만들지 않게 한다.
    var onStart: ((RunCourse) -> Void)?

    /// V07에서 만든 코스로 진입
    init(draft: RouteDraft,
         onEdit: (() -> Void)? = nil,
         onStart: ((RunCourse) -> Void)? = nil) {
        _viewModel = State(initialValue: CourseConfirmViewModel(draft: draft))
        self.onEdit = onEdit
        self.onStart = onStart
    }

    /// 추천 코스(BE)로 진입.
    /// 수정을 받지 않는다 — 코스를 고치면 더 이상 그 코스가 아니게 되고,
    /// 완주율·업적이 기준 삼는 원본 거리·경유지가 무너진다.
    init(courseId: String,
         onStart: ((RunCourse) -> Void)? = nil) {
        _viewModel = State(initialValue: CourseConfirmViewModel(courseId: courseId))
        self.onEdit = nil
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
                placeMarkerRole: .nearby,
                routePolyline: viewModel.routePolyline,
                markers: viewModel.mapMarkers,
                // 패널 높이를 재기 전에는 맞춤을 미룬다 (카메라 맞춤은 1회성이라 선반영 필요)
                fitCoordinates: panelHeight > 0 ? viewModel.boundsCoordinates : [],
                fitBottomInset: panelHeight,
                fitTopInset: safeAreaTop
            )
            .ignoresSafeArea()

            bottomPanel
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    panelHeight = $0
                }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: {
            safeAreaTop = $0
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
        Button { if let course = viewModel.course { onStart?(course) } } label: {
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
