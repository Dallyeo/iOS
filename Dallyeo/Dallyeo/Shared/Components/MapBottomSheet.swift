//
//  MapBottomSheet.swift
//  Dallyeo
//
//  지도 위에 얹는 바텀시트 (V03 지도 / V05 검색결과 / V06 위치정보 공용).
//
//  ── SwiftUI `.sheet`을 쓰지 않는 이유 ──
//  `.presentationBackgroundInteraction`으로 배경 터치를 열어줘도, UIKit 시트의
//  제스처 인식기가 터치를 먼저 붙잡고 있다가 "시트 드래그가 아니다"라고 판단이
//  선 뒤에야 놓아준다. 그동안의 손가락 이동은 지도에 전달되지 않고 버려진다.
//
//  시뮬레이터 실측(V03, 같은 스와이프):
//      시트 있음   40pt 스와이프 → 지도 0.0pt      120pt → 25pt
//      시트 제거   40pt 스와이프 → 지도 34.7pt
//      V07(시트 없는 화면)        120pt → 136pt
//  초기 이동 약 95pt가 통째로 삼켜져 "지도가 둔감하다"는 QA 피드백이 나왔다.
//
//  그래서 시트를 화면 계층 안(overlay)에 직접 그리고 드래그도 우리가 처리한다.
//  V08 코스확인이 쓰던 방식과 같은 구조다.
//

import SwiftUI

// MARK: - 단(detent)

/// 바텀시트가 차지할 높이. 화면 높이를 받아 실제 pt로 환산한다.
enum SheetDetent: Hashable {
    /// 화면 바닥에서부터의 높이(pt)
    case height(CGFloat)
    /// 화면 높이 대비 비율
    case fraction(CGFloat)
    /// 상단 안전영역 아래로 이만큼 더 비우고 나머지를 채운다
    case fromSafeTop(CGFloat)

    func resolved(containerHeight: CGFloat, safeTop: CGFloat) -> CGFloat {
        let value: CGFloat = switch self {
        case .height(let h):      h
        case .fraction(let f):    containerHeight * f
        case .fromSafeTop(let t): containerHeight - safeTop - t
        }
        return min(max(value, 0), containerHeight)
    }
}

/// 시트 높이 계산에 필요한 화면 치수. `onGeometryChange`가 Sendable을 요구해
/// 뷰 바깥에 둔다.
nonisolated private struct SheetGeometry: Equatable, Sendable {
    let height: CGFloat
    let top: CGFloat
    let bottom: CGFloat
}

// MARK: - 컨테이너

private struct MapBottomSheetModifier<Sheet: View>: ViewModifier {

    let isPresented: Bool
    let detents: [SheetDetent]
    @Binding var selection: SheetDetent
    let background: Color
    @ViewBuilder let sheet: () -> Sheet

    /// 드래그 중 손가락을 따라가는 임시 변위(위로 끌면 음수)
    @State private var dragTranslation: CGFloat = 0
    @State private var containerHeight: CGFloat = 0
    @State private var safeTop: CGFloat = 0
    @State private var safeBottom: CGFloat = 0

    /// 드래그 손잡이 영역 높이. 이 영역에서만 시트 크기를 바꾼다.
    /// 시트 본문까지 제스처를 걸면 안쪽 ScrollView와 싸운다.
    private let grabberAreaHeight: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: SheetGeometry.self) {
                SheetGeometry(height: $0.size.height + $0.safeAreaInsets.top + $0.safeAreaInsets.bottom,
                              top: $0.safeAreaInsets.top,
                              bottom: $0.safeAreaInsets.bottom)
            } action: {
                containerHeight = $0.height
                safeTop = $0.top
                safeBottom = $0.bottom
            }
            .overlay(alignment: .bottom) {
                if isPresented, containerHeight > 0 {
                    sheetBody
                }
            }
            .ignoresSafeArea(edges: .bottom)
    }

    // MARK: 높이 계산

    private var resolvedDetents: [CGFloat] {
        detents.map { $0.resolved(containerHeight: containerHeight, safeTop: safeTop) }
            .sorted()
    }

    private var selectedHeight: CGFloat {
        selection.resolved(containerHeight: containerHeight, safeTop: safeTop)
    }

    /// 지금 그릴 높이. 드래그 중에는 최소/최대 단을 조금 넘도록 두되 고무줄처럼 저항을 준다.
    private var currentHeight: CGFloat {
        let raw = selectedHeight - dragTranslation
        guard let lo = resolvedDetents.first, let hi = resolvedDetents.last else { return raw }
        if raw < lo { return lo - (lo - raw) * 0.25 }
        if raw > hi { return hi + (raw - hi) * 0.25 }
        return raw
    }

    // MARK: 시트

    private var sheetBody: some View {
        VStack(spacing: 0) {
            grabber
            sheet()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, safeBottom)
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentHeight, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                .fill(background)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -4)
        }
        .clipped()
    }

    /// 드래그 손잡이 (Figma: 50×5 캡슐)
    ///
    /// `highPriorityGesture`인 이유: 아래에 깔린 카카오맵은 UIKit 뷰라 터치를 직접
    /// 처리한다. 그냥 `gesture`로 달면 지도 쪽이 먼저 집어가 손잡이가 반응하지 않는다.
    private var grabber: some View {
        ZStack {
            Color.clear
            Capsule()
                .fill(AppColor.grabber)
                .frame(width: 50, height: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: grabberAreaHeight)
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { dragTranslation = $0.translation.height }
            .onEnded { value in
                // 던진 속도를 조금 반영해 다음 단을 고른다.
                // 단, 끌던 방향과 같을 때만 더한다 — 손을 떼며 감속하면 예측값이
                // 되레 뒤로 당겨서, 충분히 끌었는데도 원래 단으로 돌아가 버린다.
                let flick = value.predictedEndTranslation.height - value.translation.height
                let boost = (flick < 0) == (value.translation.height < 0) ? flick : 0
                let projected = selectedHeight - value.translation.height - boost * 0.3
                let target = nearestDetent(to: projected)
                withAnimation(.snappy(duration: 0.25)) {
                    selection = target
                    dragTranslation = 0
                }
            }
    }

    private func nearestDetent(to height: CGFloat) -> SheetDetent {
        detents.min {
            abs($0.resolved(containerHeight: containerHeight, safeTop: safeTop) - height)
                < abs($1.resolved(containerHeight: containerHeight, safeTop: safeTop) - height)
        } ?? selection
    }
}

// MARK: - 사용부

extension View {

    /// 지도 위 바텀시트. `.sheet` 대신 쓴다 — 이유는 파일 상단 주석 참고.
    ///
    /// - Parameters:
    ///   - isPresented: false면 그리지 않는다(푸시된 화면 위에서 숨길 때).
    ///   - detents: 스냅할 단들. 순서는 상관없다.
    ///   - selection: 현재 단. 드래그가 끝나면 가장 가까운 단으로 바뀐다.
    func mapBottomSheet<Sheet: View>(
        isPresented: Bool = true,
        detents: [SheetDetent],
        selection: Binding<SheetDetent>,
        background: Color = AppColor.white,
        @ViewBuilder content: @escaping () -> Sheet
    ) -> some View {
        modifier(MapBottomSheetModifier(
            isPresented: isPresented,
            detents: detents,
            selection: selection,
            background: background,
            sheet: content
        ))
    }
}
