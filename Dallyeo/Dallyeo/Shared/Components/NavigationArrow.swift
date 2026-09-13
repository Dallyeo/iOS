//
//  NavigationArrow.swift
//  Dallyeo
//
//  아래를 향한 화살표(윗변 가운데가 파인 삼각형).
//  Figma 956:2374 벡터를 26×26 기준으로 옮겼다.
//  ※ 원본 SVG path는 위를 향하고 노드에 180° 회전이 걸려 있다. 여기서는
//    회전 대신 y를 뒤집어 처음부터 아래를 향하게 그린다(Figma 렌더 기준).
//

import SwiftUI

struct NavigationArrow: Shape {

    /// 원본 벡터의 기준 크기. 다른 크기로 쓰면 이 비율로 확대·축소된다.
    private static let reference: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 원본 좌표를 주어진 사각형에 맞춘다. 비율은 유지하지 않는다(정사각형 전제).
        let sx = rect.width / Self.reference
        let sy = rect.height / Self.reference
        // y를 뒤집어 아래를 향하게 한다.
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + (Self.reference - y) * sy)
        }

        path.move(to: p(13, 19.5))
        path.addLine(to: p(6.0125, 22.4792))
        // 왼쪽 아래 둥근 꼬리
        path.addCurve(to: p(4.60417, 21.0437),
                      control1: p(5.0, 22.85), control2: p(4.45, 22.2))
        path.addLine(to: p(11.9979, 4.3875))
        // 꼭짓점
        path.addCurve(to: p(14.0021, 4.3875),
                      control1: p(12.3, 3.7), control2: p(13.7, 3.7))
        path.addLine(to: p(21.3958, 21.0437))
        // 오른쪽 아래 둥근 꼬리
        path.addCurve(to: p(19.9875, 22.4792),
                      control1: p(21.55, 22.2), control2: p(21.0, 22.85))
        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationArrow()
        .fill(AppColor.primary)
        .frame(width: 104, height: 104)
        .padding()
}
