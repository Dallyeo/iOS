//
//  AppleAuthProvider.swift
//  Dallyeo
//
//  애플 로그인 (AuthenticationServices, 별도 SDK 불필요).
//  "Sign in with Apple" capability(entitlement) 필요.
//

import AuthenticationServices
import UIKit

@MainActor
final class AppleAuthProvider: NSObject, AuthProviding {

    private var continuation: CheckedContinuation<ProviderCredential, Error>?
    // ASAuthorizationController 는 delegate 를 weak 로 참조하므로
    // 콜백 수신까지 강한 참조를 유지한다.
    private var controller: ASAuthorizationController?

    func authenticate() async throws -> ProviderCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<ProviderCredential, Error>) {
        controller = nil
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthProvider: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(AuthError.failed("apple_invalid_credential")))
            return
        }

        let idToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        // fullName 은 최초 로그인 시에만 제공됨
        let formatter = PersonNameComponentsFormatter()
        let name = credential.fullName.map { formatter.string(from: $0) }
        let displayName = (name?.isEmpty == false) ? name : nil

        finish(.success(ProviderCredential(
            provider: .apple,
            accessToken: nil,
            idToken: idToken,
            authorizationCode: authCode,
            providerUserId: credential.user,
            displayName: displayName
        )))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finish(.failure(AuthError.cancelled))
        } else {
            finish(.failure(AuthError.failed(error.localizedDescription)))
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthProvider: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
