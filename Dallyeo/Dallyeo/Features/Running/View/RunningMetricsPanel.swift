//
//  RunningMetricsPanel.swift
//  Dallyeo
//
//  V09 하단 패널 — 진행 바 + 지표 3열 + 끝내기/일시정지.
//  Figma 609:603 하단부 실측 반영.
//

import SwiftUI

struct RunningMetricsPanel: View {

    let elapsedText: String
    let paceText: String
    let caloriesText: String
    /// 0~1. 진행 바 채움 비율
    let progress: Double
    let isPaused: Bool

    var onFinish: () -> Void
    var onTogglePause: () -> Void

    // Figma 실측
    private let barHeight: CGFloat = 7
    private let metricsWidth: CGFloat = 310
    private let columnSpacing: CGFloat = 50
    private let rowSpacing: CGFloat = 3
    private let finishButtonWidth: CGFloat = 103
    private let pauseButtonWidth: CGFloat = 251
    private let buttonHeight: CGFloat = 59

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            metrics
                .padding(.top, 39)   // 바(640) → 지표(679)
            buttons
                .padding(.top, 39)   // 지표 하단(726) → 버튼(765)
                .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity)
        .background(
            AppColor.white
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -4)
        )
    }

    // MARK: - 진행 바 (배경 Primary/200, 채움 Primary/500)

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(AppColor.primary200)
                Rectangle()
                    .fill(AppColor.primary500)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.linear(duration: 0.3), value: progress)
            }
        }
        .frame(height: barHeight)
    }

    // MARK: - 지표 3열

    private var metrics: some View {
        HStack(spacing: columnSpacing) {
            metric(elapsedText, "진행 시간")
            metric(paceText, "현재 페이스")
            metric(caloriesText, "칼로리")
        }
        .frame(width: metricsWidth)
        .overlay(alignment: .leading) { separator(offsetX: 95) }
        .overlay(alignment: .leading) { separator(offsetX: 215) }
    }

    /// 열 사이 세로 구분선 (Figma 609:624 x141 / 609:625 x261 — 지표 프레임 기준 95 / 215)
    private func separator(offsetX: CGFloat) -> some View {
        Rectangle()
            .fill(AppColor.gray300)
            .frame(width: 1, height: 56)
            .offset(x: offsetX)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: rowSpacing) {
            Text(value)
                .font(AppFont.pretendard(20, .semibold))
                .tracking(AppFont.tracking(-2, size: 20))
                .foregroundStyle(AppColor.black)
            Text(label)
                .font(AppFont.pretendard(14, .medium))
                .tracking(AppFont.tracking(-2, size: 14))
                .foregroundStyle(AppColor.gray500)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 버튼

    private var buttons: some View {
        HStack(spacing: 16) {
            Button(action: onFinish) {
                Text("끝내기")
                    .font(AppFont.pretendard(17, .semibold))
                    .foregroundStyle(AppColor.whiteDim)
                    .frame(width: finishButtonWidth, height: buttonHeight)
                    .background(AppColor.gray300, in: RoundedRectangle(cornerRadius: 8))
            }
            Button(action: onTogglePause) {
                Text(isPaused ? "재개" : "일시정지")
                    .font(AppFont.pretendard(17, .semibold))
                    .foregroundStyle(AppColor.white)
                    .frame(width: pauseButtonWidth, height: buttonHeight)
                    .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .buttonStyle(.plain)
    }
}
