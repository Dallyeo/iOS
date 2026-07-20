//
//  ProviderCredential.swift
//  Dallyeo
//
//  OAuth 제공자에서 획득한 네이티브 인증 결과.
//  백엔드 토큰 교환(AuthBackend)의 입력으로 사용.
//

import Foundation

struct ProviderCredential: Sendable {
    let provider: AuthProviderKind

    /// 카카오 OAuth 액세스 토큰
    let accessToken: String?
    /// 애플 identityToken (JWT) / OIDC id_token
    let idToken: String?
    /// 애플 authorization code
    let authorizationCode: String?
    /// 제공자측 사용자 식별자 (애플 stable user id 등)
    let providerUserId: String?
    /// 닉네임 / 이름 (제공될 때만 — 애플은 최초 로그인 시에만)
    let displayName: String?
}
