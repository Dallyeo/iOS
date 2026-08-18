//
//  RunningView.swift
//  Dallyeo
//
//  V09 코스진행뷰 — 지도(코스+현위치) + 다음 지점 안내 + 진행 지표.
//  Figma 609:603 기준. 상단 턴바이턴 방향 안내(화살표/"우회전")는 회의 결정으로 MVP 제외,
//  남은 거리·다음 지점명만 표시한다.
//

import SwiftUI

struct RunningView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RunningViewModel
    /// 종료 시 결과 전달 (→ 웹 V10, runCompleted 이벤트는 후속)
    var onFinish: ((RunResult) -> Void)?

    init(course: RunCourse, onFinish: ((RunResult) -> Void)? = nil) {
        _viewModel = State(initialValue: RunningViewModel(course: course))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                nextTargetBanner
                KakaoMapView(
                    userLocation: viewModel.userLocation,
                    places: [],
                    followsUser: true,
                    routePolyline: viewModel.course.polyline,
                    markers: viewModel.mapMarkers,
                    heading: viewModel.headingDegrees,
                    // 지나온 구간은 지운다 (내비게이션 방식)
                    routeProgressPosition: viewModel.userLocation
                )
                RunningMetricsPanel(
                    elapsedText: formatTime(viewModel.elapsedSec),
                    paceText: formatPace(viewModel.currentPaceSecPerKm),
                    caloriesText: "\(viewModel.calories)",
                    progress: viewModel.progressFraction,
                    isPaused: viewModel.phase == .paused,
                    onFinish: { viewModel.requestFinish() },
                    onTogglePause: {
                        viewModel.phase == .paused ? viewModel.resume() : viewModel.pause()
                    }
                )
            }
            .ignoresSafeArea(edges: .bottom)

            if viewModel.phase == .countdown {
                countdownOverlay
            }

            if let alert = viewModel.activeAlert {
                alertView(for: alert)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.onFinish = { result in
                onFinish?(result)
                dismiss()
            }
            viewModel.start()
        }
    }

    // MARK: - 상단 다음 지점 안내

    /// Figma 609:616 중 방향(아이콘·"우회전") 제외. 남은 거리 + 다음 지점명만.
    private var nextTargetBanner: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(formatDistance(viewModel.remainingToNextMeters))
                    .font(AppFont.pretendard(30, .bold))
                    .foregroundStyle(AppColor.black)
                if let name = viewModel.nextTarget?.name, !name.isEmpty {
                    Text("\(name) 방면")
                        .font(AppFont.pretendard(15, .medium))
                        .tracking(AppFont.tracking(-2, size: 15))
                        .foregroundStyle(AppColor.gray500)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.white)
    }

    // MARK: - 알럿

    @ViewBuilder
    private func alertView(for alert: RunningViewModel.ActiveAlert) -> some View {
        switch alert {
        case .paused:
            DallyeoAlert(
                title: "일시정지했어요.",
                message: "이어서 뛰려면 재개를 눌러주세요.",
                secondaryTitle: "끝내기",
                primaryTitle: "재개",
                onSecondary: { viewModel.finish() },
                onPrimary: { viewModel.resume() }
            )
        case .finishConfirm, .deviated:
            DallyeoAlert(
                title: "러닝을 그만두시겠어요?",
                secondaryTitle: "취소",
                primaryTitle: "확인",
                onSecondary: { viewModel.dismissAlert() },
                onPrimary: { viewModel.finish() }
            )
        }
    }

    // MARK: - 카운트다운

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            Text("\(viewModel.countdownValue)")
                .font(AppFont.pretendard(96, .bold))
                .foregroundStyle(AppColor.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: viewModel.countdownValue)
        }
    }

    // MARK: - 포맷

    private func formatDistance(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters))m" : DistanceFormat.km(meters: meters)
    }

    private func formatTime(_ sec: Int) -> String {
        let h = sec / 3600, m = (sec % 3600) / 60, s = sec % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%02d:%02d", m, s)
    }

    private func formatPace(_ secPerKm: Int) -> String {
        guard secPerKm > 0 else { return "-'--\"" }
        return String(format: "%d'%02d\"", secPerKm / 60, secPerKm % 60)
    }
}
