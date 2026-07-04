//
//  RunningView.swift
//  Dallyeo
//
//  V09 코스진행뷰 — 지도(경로+현위치) + 진행지표 + 카운트다운
//

import SwiftUI

struct RunningView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RunningViewModel
    /// 종료 시 결과 전달 (→ 웹 V10, runCompleted 이벤트는 후속)
    var onFinish: ((RunResult) -> Void)?

    init(draft: RouteDraft, onFinish: ((RunResult) -> Void)? = nil) {
        _viewModel = State(initialValue: RunningViewModel(draft: draft))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                nextTargetBar
                KakaoMapView(
                    userLocation: viewModel.userLocation,
                    places: viewModel.routePlaces,
                    showsPlaceMarkers: true,
                    followsUser: true
                )
                progressBar
                bottomPanel
            }

            if viewModel.phase == .countdown {
                countdownOverlay
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
        .alert("경로를 벗어났어요", isPresented: $viewModel.showDeviationAlert) {
            Button("계속하기", role: .cancel) {}
            Button("종료", role: .destructive) { viewModel.finish() }
        } message: {
            Text("코스에서 1km 이상 벗어났습니다. 계속 진행할까요?")
        }
    }

    // MARK: - 진행 바 (달린 만큼 화살표 이동)

    private var progressBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let markerW: CGFloat = 26
            let x = max(0, min(w - markerW, w * viewModel.progressFraction - markerW / 2))
            ZStack(alignment: .topLeading) {
                // 지도/패널 경계에 붙는 초록 라인
                Rectangle()
                    .fill(AppColor.primary)
                    .frame(height: 5)
                // 라인 위 초록 화살표 (달린 만큼 좌→우 이동)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColor.primary)
                    .frame(width: markerW)
                    .offset(x: x, y: -4)
                    .animation(.linear(duration: 0.3), value: viewModel.progressFraction)
            }
        }
        .frame(height: 24)
        .background(AppColor.white)
    }

    // MARK: - 상단 다음 지점 안내

    private var nextTargetBar: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(AppColor.gray900)
                Text(viewModel.nextTargetLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColor.gray900)
            }

            Divider().frame(height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(formatDistance(viewModel.remainingToNextMeters))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppColor.gray900)
                if let name = viewModel.nextTarget?.name {
                    Text(name)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.gray500)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColor.white)
    }

    // MARK: - 하단 지표 + 버튼

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                metric(formatTime(viewModel.elapsedSec), "진행 시간")
                Divider().frame(height: 36)
                metric(formatPace(viewModel.currentPaceSecPerKm), "현재 페이스")
                Divider().frame(height: 36)
                metric("\(viewModel.calories)", "칼로리")
            }

            HStack(spacing: 0) {
                Button { viewModel.finish() } label: {
                    Text("끝내기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                Rectangle()
                    .fill(AppColor.white.opacity(0.5))
                    .frame(width: 1, height: 24)
                Button {
                    viewModel.phase == .paused ? viewModel.resume() : viewModel.pause()
                } label: {
                    Text(viewModel.phase == .paused ? "재개" : "일시정지")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
            .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(AppColor.white)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.gray900)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(AppColor.gray500)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 카운트다운

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            Text("\(viewModel.countdownValue)")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: viewModel.countdownValue)
        }
    }

    // MARK: - 포맷

    private func formatDistance(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters))m" : String(format: "%.1fkm", meters / 1000)
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
