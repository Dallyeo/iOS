//
//  KakaoAuthProvider.swift
//  Dallyeo
//
//  카카오 로그인 (카카오 로그인 SDK: KakaoSDKAuth / KakaoSDKUser).
//  카카오톡 설치 시 톡으로, 아니면 카카오계정으로 로그인.
//

import Foundation
import OSLog
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

@MainActor
final class KakaoAuthProvider: AuthProviding {

    private static let log = Logger(subsystem: "com.dallyeo.app", category: "auth.kakao")

    func authenticate() async throws -> ProviderCredential {
        let token = try await requestLogin()
        Self.log.info("카카오 토큰 수신: idToken=\(token.idToken != nil ? "있음(OIDC)" : "없음", privacy: .public), accessToken=\(token.accessToken.isEmpty ? "없음" : "있음", privacy: .public)")

        // id_token 방식으로 백엔드가 신원(sub)/프로필을 처리하므로
        // 클라이언트에서 /v2/user/me 로 닉네임을 받지 않는다. (displayName 은 백엔드 /me 담당)
        return ProviderCredential(
            provider: .kakao,
            accessToken: token.accessToken,
            idToken: token.idToken,
            authorizationCode: nil,
            providerUserId: nil,
            displayName: nil
        )
    }

    private func requestLogin() async throws -> OAuthToken {
        try await withCheckedThrowingContinuation { continuation in
            let handler: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: AuthError.failed("kakao_no_token"))
                }
            }

            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: handler)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: handler)
            }
        }
    }

    private static func mapError(_ error: Error) -> AuthError {
        // 사용자 취소 판정
        if let sdkError = error as? SdkError,
           case .ClientFailed(let reason, _) = sdkError,
           reason == .Cancelled {
            return .cancelled
        }
        return .failed(error.localizedDescription)
    }
}
