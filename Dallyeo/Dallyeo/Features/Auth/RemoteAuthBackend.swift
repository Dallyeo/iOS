//
//  RemoteAuthBackend.swift
//  Dallyeo
//
//  BE 인증 API(§5) 실연동 구현.
//    POST /auth/login/{provider}  🌐  소셜 토큰 → 앱 세션
//    POST /auth/refresh           🌐  Refresh Token 회전
//    POST /auth/logout            🔒  서버측 Refresh Token 무효화
//

import Foundation
import OSLog

nonisolated struct RemoteAuthBackend: AuthBackend {

    private static let log = Logger(subsystem: "com.dallyeo.app", category: "auth.backend")

    // MARK: - 로그인

    func exchange(_ credential: ProviderCredential) async throws -> AppSession {
        let code = try Self.authorizationCode(from: credential)

        Self.log.info("auth 교환 요청: POST /auth/login/\(credential.provider.rawValue, privacy: .public)")
        // 애플은 identity token(JWT)을 그대로 보낸다. 401 이 나면 서버가 기대하는 client_id 와
        // 토큰의 aud 가 다른 경우가 대부분이라, 대조할 수 있게 클레임 요약을 남긴다.
        if credential.provider == .apple {
            Self.log.info("apple id_token 클레임: \(JWTClaimsPeek.summary(of: code), privacy: .public)")
        }
        do {
            let dto = try await DallyeoAPI.login(
                provider: credential.provider,
                authorizationCode: code
            )
            let session = try Self.makeSession(from: dto, fallbackDisplayName: credential.displayName)
            Self.log.info("auth 교환 성공: userId=\(session.userId, privacy: .public), onboardingRequired=\(String(describing: dto.onboardingRequired), privacy: .public)")
            return session
        } catch {
            throw Self.mapError(error, context: "login")
        }
    }

    // MARK: - 갱신

    func refresh(_ session: AppSession) async throws -> AppSession {
        guard let refreshToken = session.refreshToken else {
            throw AuthError.failed("no_refresh_token")
        }

        Self.log.info("auth 갱신 요청: POST /auth/refresh")
        do {
            let dto = try await DallyeoAPI.refresh(refreshToken: refreshToken)
            // 갱신 응답에는 user 가 없다 → 기존 사용자 메타를 유지하고 토큰만 교체.
            return session.replacingTokens(
                accessToken: dto.accessToken,
                refreshToken: dto.refreshToken,
                expiresAt: Self.expiryDate(from: dto.accessTokenExpiresIn)
            )
        } catch {
            throw Self.mapError(error, context: "refresh")
        }
    }

    // MARK: - 로그아웃

    func logout(accessToken: String) async throws {
        Self.log.info("auth 로그아웃 요청: POST /auth/logout")
        do {
            try await DallyeoAPI.logout(accessToken: accessToken)
        } catch {
            throw Self.mapError(error, context: "logout")
        }
    }

    // MARK: - 매핑

    /// BE 가 받는 `authorizationCode` 는 제공자별로 다른 토큰이다.
    /// - kakao: 카카오 access token (서버가 카카오 사용자 조회로 검증)
    /// - apple: identity token(JWT) (서버가 애플 JWKS 로 검증)
    private static func authorizationCode(from credential: ProviderCredential) throws -> String {
        let token: String? = switch credential.provider {
        case .kakao: credential.accessToken
        case .apple: credential.idToken
        }
        guard let token, !token.isEmpty else {
            log.error("전송할 토큰 없음: provider=\(credential.provider.rawValue, privacy: .public)")
            throw AuthError.failed("missing_token")
        }
        return token
    }

    /// 로그인 응답에는 `user` 가 반드시 온다. 없으면 세션 식별자를 만들 수 없어 실패로 처리.
    private static func makeSession(from dto: AuthTokenDTO, fallbackDisplayName: String?) throws -> AppSession {
        guard let user = dto.user else {
            log.error("로그인 응답에 user 없음 — userId 확정 불가")
            throw AuthError.failed("missing_user")
        }
        return AppSession(
            userId: String(user.id),
            displayName: user.nickname ?? fallbackDisplayName,
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            expiresAt: expiryDate(from: dto.accessTokenExpiresIn),
            onboardingRequired: dto.onboardingRequired,
            profileImageUrl: user.profileImageUrl
        )
    }

    private static func expiryDate(from seconds: Int?) -> Date? {
        guard let seconds else { return nil }
        return Date().addingTimeInterval(TimeInterval(seconds))
    }

    /// APIClientError → AuthError. 401 은 재로그인 유도가 필요해 메시지로 구분한다.
    private static func mapError(_ error: Error, context: String) -> AuthError {
        if let authError = error as? AuthError { return authError }

        guard let apiError = error as? APIClientError else {
            log.error("auth \(context, privacy: .public) 실패(기타): \(error.localizedDescription, privacy: .public)")
            return .failed(error.localizedDescription)
        }

        switch apiError {
        case .unauthorized:
            log.error("auth \(context, privacy: .public) 401 — 소셜 검증 실패 또는 토큰 무효")
            return .failed("unauthorized")
        case .business(let body):
            let message = body.message ?? body.code ?? "server_error"
            log.error("auth \(context, privacy: .public) 비즈니스 오류: \(message, privacy: .public)")
            return .failed(message)
        case .badStatus(let code):
            log.error("auth \(context, privacy: .public) HTTP \(code)")
            return .failed("http_\(code)")
        case .transport(let underlying):
            log.error("auth \(context, privacy: .public) 네트워크 실패: \(underlying.localizedDescription, privacy: .public)")
            return .failed("network_error")
        case .decoding:
            log.error("auth \(context, privacy: .public) 응답 파싱 실패")
            return .failed("invalid_response")
        case .emptyData:
            log.error("auth \(context, privacy: .public) 응답 data 없음")
            return .failed("empty_response")
        case .invalidURL:
            return .failed("invalid_url")
        }
    }
}
