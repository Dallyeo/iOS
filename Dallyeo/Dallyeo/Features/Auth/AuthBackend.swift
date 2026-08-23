//
//  AuthBackend.swift
//  Dallyeo
//
//  제공자 인증 결과(ProviderCredential)를 백엔드 앱 세션(AppSession)으로 교환.
//  실구현: RemoteAuthBackend (BE §5 인증 API)
//

import Foundation

nonisolated protocol AuthBackend: Sendable {
    /// 소셜 토큰 → 앱 세션 교환. `POST /auth/login/{provider}`
    func exchange(_ credential: ProviderCredential) async throws -> AppSession
    /// Refresh Token 으로 토큰 재발급. `POST /auth/refresh`
    /// 회전 정책이라 새 refreshToken 도 함께 받는다.
    func refresh(_ session: AppSession) async throws -> AppSession
    /// 서버측 Refresh Token 무효화. `POST /auth/logout`
    func logout(accessToken: String) async throws
}

/// 백엔드 없이 플로우만 검증할 때 쓰는 임시 구현. 목(mock) 세션을 발급한다.
/// 실제 토큰이 아니므로 보호 API 호출은 성공하지 않는다.
nonisolated struct StubAuthBackend: AuthBackend {
    func exchange(_ credential: ProviderCredential) async throws -> AppSession {
        let userId = credential.providerUserId
            ?? "\(credential.provider.rawValue)_\(UUID().uuidString.prefix(8))"
        let token = "stub.\(credential.provider.rawValue).\(UUID().uuidString)"

        return AppSession(
            userId: userId,
            displayName: credential.displayName,
            accessToken: token,
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(60 * 60)  // 1시간
        )
    }

    func refresh(_ session: AppSession) async throws -> AppSession {
        throw AuthError.failed("stub_refresh_unsupported")
    }

    func logout(accessToken: String) async throws {}
}
