//
//  AuthDTO.swift
//  Dallyeo
//
//  BE 인증 API(§5) 요청/응답 DTO.
//  POST /auth/login/{provider} · POST /auth/refresh · POST /auth/logout
//

import Foundation

// MARK: - 요청

/// POST /auth/login/{provider}
/// - kakao: 카카오 access token
/// - apple: identity token (JWT)
nonisolated struct AuthLoginRequest: Encodable {
    let authorizationCode: String
}

/// POST /auth/refresh
nonisolated struct AuthRefreshRequest: Encodable {
    let refreshToken: String
}

// MARK: - 응답

/// 로그인/갱신 공통 토큰 응답.
/// `onboardingRequired`/`user` 는 로그인 응답에만 있고 갱신 응답에는 없다 → optional.
nonisolated struct AuthTokenDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    /// Access Token 만료(초). 스펙 기준 86400(24h).
    let accessTokenExpiresIn: Int?
    /// 신체정보(키/체중) 미입력이면 true → 웹이 온보딩 화면으로 분기.
    let onboardingRequired: Bool?
    let user: AuthUserDTO?
}

nonisolated struct AuthUserDTO: Decodable {
    /// BE 회원 식별자 (정수). 브릿지 session.userId 로는 문자열 변환해 전달.
    let id: Int
    /// 소셜 닉네임 또는 자동생성(러너####)
    let nickname: String?
    let gender: String?
    let height: Double?
    let weight: Double?
    let profileImageUrl: String?
}
