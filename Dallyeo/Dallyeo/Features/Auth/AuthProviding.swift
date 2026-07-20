//
//  AuthProviding.swift
//  Dallyeo
//
//  OAuth 제공자 추상화. 네이티브 로그인 UI를 띄우고
//  ProviderCredential 을 반환한다. (백엔드 교환 이전 단계)
//

import Foundation

@MainActor
protocol AuthProviding {
    /// 소셜 로그인을 수행하고 제공자 인증 결과를 반환.
    /// 사용자가 취소하면 AuthError.cancelled, 그 외 실패는 AuthError.failed.
    func authenticate() async throws -> ProviderCredential
}
