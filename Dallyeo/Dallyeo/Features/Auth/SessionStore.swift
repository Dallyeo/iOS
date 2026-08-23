//
//  SessionStore.swift
//  Dallyeo
//
//  세션(AppSession)의 단일 저장 출처 — Keychain.
//  웹은 토큰을 메모리에만 두므로, 영구 저장은 네이티브가 전담.
//

import Foundation

@MainActor
final class SessionStore {

    /// Keychain account 키 (기존 브릿지 logout 과 동일)
    private let key = "session"

    func save(_ session: AppSession) throws {
        try KeychainManager.shared.save(session, for: key)
    }

    func load() -> AppSession? {
        do {
            return try KeychainManager.shared.load(for: key)
        } catch {
            return nil
        }
    }

    func clear() {
        try? KeychainManager.shared.delete(for: key)
    }
}
