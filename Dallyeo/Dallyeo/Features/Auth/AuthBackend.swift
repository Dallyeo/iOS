//
//  AuthBackend.swift
//  Dallyeo
//
//  제공자 인증 결과(ProviderCredential)를 백엔드 앱 세션(AppSession)으로 교환.
//
//  ⚠️ 백엔드 엔드포인트(POST /auth/oauth/{provider}) 미준비 → 현재는 StubAuthBackend 로
//     플로우만 검증. 엔드포인트 확정 시 RemoteAuthBackend 구현으로 교체.
//

import Foundation

protocol AuthBackend: Sendable {
    func exchange(_ credential: ProviderCredential) async throws -> AppSession
}

/// 백엔드 미준비 상태의 임시 구현. 목(mock) 세션을 발급한다.
/// 실제 토큰이 아니므로 API 호출은 성공하지 않는다(플로우 검증 전용).
struct StubAuthBackend: AuthBackend {
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
}
