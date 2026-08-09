//
//  WaypointNumberBadge.swift
//  Dallyeo
//
//  V08 코스 지점 리스트의 경유지 번호 배지.
//
//  Figma(565:539~543) 구성: 26×26 Primary/700 채운 원 위에 20×20 흰 원을 얹고
//  그 안에서 숫자를 도려낸 형태 → 결과적으로 3pt 초록 링 + 초록 숫자.
//  SVG 5종을 번들하는 대신 동일 지오메트리를 SwiftUI로 재현한다(경유지 수 변화에 유연).
//

import SwiftUI

struct WaypointNumberBadge: View {

    let number: Int

    /// Figma 실측
    private let outerSize: CGFloat = 26
    private let innerSize: CGFloat = 20   // 링 두께 = (26 - 20) / 2 = 3

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColor.primary)
                .frame(width: outerSize, height: outerSize)

            Circle()
                .fill(AppColor.white)
                .frame(width: innerSize, height: innerSize)

            Text("\(number)")
                .font(AppFont.pretendard(13, .semibold))
                .foregroundStyle(AppColor.primary)
        }
        .frame(width: outerSize, height: outerSize)
    }
}

#Preview {
    HStack(spacing: 8) {
        ForEach(1...5, id: \.self) { WaypointNumberBadge(number: $0) }
    }
    .padding()
}
