//
//  AppSession.swift
//  Dallyeo
//
//  세션 모델 - 인증 상태 관리
//

import Foundation

struct AppSession: Codable, Sendable {
    /// 사용자 식별자 (브릿지 session.userId)
    let userId: String
    /// 표시용 이름 (브릿지 session.displayName, 선택)
    let displayName: String?
    /// 백엔드 앱 세션 토큰 = 웹 Bearer 토큰 (브릿지 token)
    let accessToken: String
    /// 갱신 토큰 (백엔드 준비 전에는 nil)
    let refreshToken: String?
    /// 만료 시각 (브릿지 session.expiresAt, 선택). nil 이면 만료 판정 안 함.
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }
}
