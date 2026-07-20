//
//  KakaoAuthProvider.swift
//  Dallyeo
//
//  카카오 로그인 (카카오 로그인 SDK: KakaoSDKAuth / KakaoSDKUser).
//  카카오톡 설치 시 톡으로, 아니면 카카오계정으로 로그인.
//

import Foundation
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

@MainActor
final class KakaoAuthProvider: AuthProviding {

    func authenticate() async throws -> ProviderCredential {
        let token = try await requestLogin()
        // 닉네임은 부가 정보 — 실패해도 로그인 자체는 성공 처리
        let displayName = try? await fetchNickname()

        return ProviderCredential(
            provider: .kakao,
            accessToken: token.accessToken,
            idToken: token.idToken,
            authorizationCode: nil,
            providerUserId: nil,
            displayName: displayName
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

    private func fetchNickname() async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            UserApi.shared.me { user, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: user?.kakaoAccount?.profile?.nickname)
                }
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
