//
//  AppColor.swift
//  Dallyeo
//
//  디자인 시스템 색상 토큰 (현재 V03 사용분만 정의)
//

import SwiftUI

enum AppColor {
    static let white = Color(hex: "#FFFFFF")

    // Gray scale
    static let gray250 = Color(hex: "#ECECEC")  // 세그먼트 컨테이너
    static let gray300 = Color(hex: "#DFDFDF")  // 카드 썸네일 플레이스홀더
    static let gray500 = Color(hex: "#838383")  // 보조 텍스트 / 미선택
    static let gray700 = Color(hex: "#5E5E5E")  // 선택 텍스트
    static let gray900 = Color(hex: "#2B2B2B")  // 본문 텍스트
}
