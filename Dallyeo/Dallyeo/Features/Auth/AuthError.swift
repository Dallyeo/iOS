//
//  AuthError.swift
//  Dallyeo
//
//  인증 에러 (브릿지 error.kind 로 매핑: cancelled | failed)
//

import Foundation

enum AuthError: Error, Sendable {
    /// 사용자가 소셜 로그인을 취소
    case cancelled
    /// 그 외 실패 (메시지는 브릿지 error.message 로 전달)
    case failed(String)
}
