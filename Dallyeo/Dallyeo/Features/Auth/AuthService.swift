//
//  AuthService.swift
//  Dallyeo
//
//  인증 오케스트레이터: 제공자 로그인 → 백엔드 교환 → 세션 저장.
//  브릿지(DallYeoBridge)에서 login/getCurrentSession/logout 처리에 사용.
//

import Foundation
import OSLog

@MainActor
final class AuthService {

    private static let log = Logger(subsystem: "com.dallyeo.app", category: "auth.service")

    static let shared = AuthService()

    private let store = SessionStore()
    private let backend: AuthBackend

    init(backend: AuthBackend = RemoteAuthBackend()) {
        self.backend = backend
    }

    /// 저장된 세션. 만료되었으면 Refresh Token 으로 갱신을 시도하고,
    /// 갱신까지 실패하면 세션을 파기하고 nil 을 반환한다(재로그인 유도).
    func currentSession() async -> AppSession? {
        guard let session = store.load() else { return nil }
        guard session.isExpired else { return session }

        guard session.refreshToken != nil else {
            Self.log.notice("세션 만료 + refreshToken 없음 → 세션 파기")
            store.clear()
            return nil
        }

        do {
            let renewed = try await backend.refresh(session)
            try store.save(renewed)
            Self.log.info("토큰 갱신 성공: userId=\(renewed.userId, privacy: .public)")
            return renewed
        } catch {
            Self.log.error("토큰 갱신 실패 → 세션 파기: \(String(describing: error), privacy: .public)")
            store.clear()
            return nil
        }
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

    /// 서버측 Refresh Token 무효화 후 로컬 세션 파기.
    /// 서버 호출이 실패해도 로컬 파기는 반드시 수행한다(사용자 관점 로그아웃은 성공해야 함).
    func logout() async {
        if let token = store.load()?.accessToken {
            do {
                try await backend.logout(accessToken: token)
            } catch {
                Self.log.notice("서버 로그아웃 실패(로컬 세션은 파기): \(String(describing: error), privacy: .public)")
            }
        }
        store.clear()
    }
}
