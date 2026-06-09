//
//  AppSession.swift
//  Dallyeo
//
//  세션 모델 - 인증 상태 관리
//

import Foundation

struct AppSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }
}
