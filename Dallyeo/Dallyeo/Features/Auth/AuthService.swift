//
//  AuthService.swift
//  Dallyeo
//
//  인증 오케스트레이터: 제공자 로그인 → 백엔드 교환 → 세션 저장.
//  브릿지(DallYeoBridge)에서 login/getCurrentSession/logout 처리에 사용.
//

import Foundation

@MainActor
final class AuthService {

    static let shared = AuthService()

    private let store = SessionStore()
    private let backend: AuthBackend

    init(backend: AuthBackend = StubAuthBackend()) {
        self.backend = backend
    }

    /// 저장된 유효 세션. 만료되었으면 제거 후 nil.
    var currentSession: AppSession? {
        guard let session = store.load() else { return nil }
        if session.isExpired {
            store.clear()
            return nil
        }
        return session
    }

    /// 소셜 로그인 → 백엔드 교환 → Keychain 저장. 실패 시 AuthError throw.
    func login(provider: AuthProviderKind) async throws -> AppSession {
        let authProvider: AuthProviding
        switch provider {
        case .kakao: authProvider = KakaoAuthProvider()
        case .apple: authProvider = AppleAuthProvider()
        }

        let credential = try await authProvider.authenticate()
        let session = try await backend.exchange(credential)
        try store.save(session)
        return session
    }

    func logout() {
        store.clear()
    }
}
