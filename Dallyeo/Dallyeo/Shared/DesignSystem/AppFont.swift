//
//  AppFont.swift
//  Dallyeo
//
//  디자인 시스템 타이포그래피 (Figma 디자인시스템 페이지 기준)
//
//  디자인은 폰트를 2계열로 사용:
//   - Pretendard: 브랜드 한글 (제목/카테고리/배지 등). OTF 번들 (Resources/Fonts).
//   - SF Pro    : 숫자/영문 위주 (거리·시간·주소·버튼 라벨). SwiftUI `.system`이 SF Pro.
//  Figma 스타일명(P_*, SF_*)의 size/line-height/letter-spacing을 그대로 토큰화.
//

import SwiftUI

enum AppFont {

    // MARK: - Pretendard (번들 OTF)

    /// Pretendard 웨이트 → 번들 PostScript 이름
    enum Pretendard: String {
        case light = "Pretendard-Light"       // 300
        case regular = "Pretendard-Regular"   // 400
        case medium = "Pretendard-Medium"     // 500
        case semibold = "Pretendard-SemiBold" // 600
        case bold = "Pretendard-Bold"         // 700
    }

    /// Pretendard 폰트. (fixedSize — Dynamic Type 미대응, 디자인 픽셀 고정)
    static func pretendard(_ size: CGFloat, _ weight: Pretendard) -> Font {
        .custom(weight.rawValue, fixedSize: size)
    }

    /// SF Pro (system). 숫자/영문 토큰용.
    static func sf(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: - Figma letter-spacing(%) → tracking(pt) 환산 헬퍼
    // Figma는 %(em) 단위, SwiftUI `.tracking`은 pt. tracking = size * percent/100.

    /// letter-spacing % → pt
    static func tracking(_ percent: CGFloat, size: CGFloat) -> CGFloat {
        size * percent / 100
    }
}
