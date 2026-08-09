//
//  AppColor.swift
//  Dallyeo
//
//  디자인 시스템 색상 토큰 (Figma 디자인시스템 페이지 기준)
//

import SwiftUI

enum AppColor {

    // MARK: - 뉴트럴
    static let white = Color(hex: "#FFFFFF")      // 디자인 "Off-White" (카드/버튼/시트)
    static let whiteDim = Color(hex: "#FAFAFA")   // 디자인 "White"
    static let black = Color(hex: "#000000")

    // MARK: - Primary (브랜드 그린)
    static let primary = Color(hex: "#13C674")     // P_700
    static let primary500 = Color(hex: "#72D794")  // P_500
    static let primary200 = Color(hex: "#C6F3DF")  // P_200 (연녹 배지 등)

    // MARK: - Gray scale
    static let gray200 = Color(hex: "#F3F3F3")  // 화면 배경
    static let gray250 = Color(hex: "#F3F3F3")  // 세그먼트 컨테이너 (변경 ECECEC→F3F3F3)
    static let gray300 = Color(hex: "#CCCCCC")  // 썸네일 플레이스홀더 (변경 DFDFDF→CCCCCC)
    static let gray400 = Color(hex: "#929292")  // 경유지명 등 약한 보조 텍스트
    static let gray500 = Color(hex: "#838383")  // 보조 텍스트 / 미선택
    static let gray700 = Color(hex: "#5E5E5E")  // 선택 텍스트 / 총거리
    static let gray750 = Color(hex: "#585858")  // 코스 지점명 (출발·도착)
    static let gray900 = Color(hex: "#2B2B2B")  // 본문 텍스트

    /// 바텀시트 grabber 전용. 디자인시스템 페이지의 Gray/300(#CCCCCC)과 달리
    /// V08 프레임은 Gray/300을 #DFDFDF로 렌더 → 화면 실물 기준으로 분리.
    static let grabber = Color(hex: "#DFDFDF")

    // MARK: - 기타
    static let disabled = Color(hex: "#B8B8B8")
    static let red = Color(hex: "#FF383C")
}
