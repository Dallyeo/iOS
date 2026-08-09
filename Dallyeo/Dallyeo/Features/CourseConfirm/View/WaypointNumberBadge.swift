//
//  WaypointNumberBadge.swift
//  Dallyeo
//
//  경유지 번호 배지. 디자인시스템 `경유` 컴포넌트(549:602, 변형 경유1~5).
//
//  Figma 구성 그대로:
//    26×26 컨테이너 (bg primary/700 #13C674, radius 13, padding 3)
//      └ 20×20 SF Symbol `N.circle.fill` (색 White #FAFAFA)
//  흰 심볼의 숫자 부분이 뚫려 있어 뒤의 초록이 비친다.
//

import SwiftUI

struct WaypointNumberBadge: View {

    let number: Int

    /// Figma 실측
    private let containerSize: CGFloat = 26
    private let symbolSize: CGFloat = 20   // padding 3 → 26 - 3*2

    var body: some View {
        Circle()
            .fill(AppColor.primary)
            .frame(width: containerSize, height: containerSize)
            .overlay {
                Image(systemName: "\(number).circle.fill")
                    .resizable()
                    .frame(width: symbolSize, height: symbolSize)
                    .foregroundStyle(AppColor.whiteDim)
            }
    }
}

#Preview {
    HStack(spacing: 8) {
        ForEach(1...5, id: \.self) { WaypointNumberBadge(number: $0) }
    }
    .padding()
    .background(AppColor.white)
}
