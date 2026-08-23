//
//  AppSession.swift
//  Dallyeo
//
//  세션 모델 - 인증 상태 관리
//

import Foundation

nonisolated struct AppSession: Codable, Sendable {
    /// 사용자 식별자 (브릿지 session.userId). BE `user.id`(Int)를 문자열로 변환해 담는다.
    let userId: String
    /// 표시용 이름 (브릿지 session.displayName, 선택). BE `user.nickname`.
    let displayName: String?
    /// 백엔드 앱 세션 토큰 = 웹 Bearer 토큰 (브릿지 token)
    let accessToken: String
    /// 갱신 토큰. 회전 정책이라 갱신 때마다 새 값으로 교체 저장한다.
    let refreshToken: String?
    /// 만료 시각 (브릿지 session.expiresAt, 선택). nil 이면 만료 판정 안 함.
    let expiresAt: Date?
    /// 신체정보 미입력 → 웹이 온보딩 화면으로 분기 (로그인 응답에만 포함, 갱신 시 유지)
    let onboardingRequired: Bool?
    /// 프로필 이미지 URL (BE `user.profileImageUrl`)
    let profileImageUrl: String?

    init(
        userId: String,
        displayName: String?,
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date?,
        onboardingRequired: Bool? = nil,
        profileImageUrl: String? = nil
    ) {
        self.userId = userId
        self.displayName = displayName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.onboardingRequired = onboardingRequired
        self.profileImageUrl = profileImageUrl
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    /// 갱신 응답으로 토큰만 교체한 새 세션. 사용자 메타(닉네임/온보딩 여부)는 유지한다.
    func replacingTokens(accessToken: String, refreshToken: String?, expiresAt: Date?) -> AppSession {
        AppSession(
            userId: userId,
            displayName: displayName,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            onboardingRequired: onboardingRequired,
            profileImageUrl: profileImageUrl
        )
    }
}
