//
//  JWTClaimsPeek.swift
//  Dallyeo
//
//  진단 전용 — 서버로 보내는 id_token 의 핵심 클레임(aud/iss/exp/nonce 유무)만 훑어본다.
//  서명 검증은 하지 않는다(검증 주체는 백엔드). 토큰 원문·sub 전체는 로그에 남기지 않는다.
//

import Foundation

nonisolated enum JWTClaimsPeek {

    /// 로그용 한 줄 요약. 파싱 실패 시 그 사실을 반환한다.
    static func summary(of token: String) -> String {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let payload = decodeBase64URL(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            return "JWT 파싱 실패(형식 아님, 길이=\(token.count))"
        }

        let aud = json["aud"] as? String ?? "없음"
        let iss = json["iss"] as? String ?? "없음"
        let hasNonce = json["nonce"] != nil
        let sub = (json["sub"] as? String).map { String($0.prefix(8)) + "…" } ?? "없음"

        var expText = "없음"
        if let exp = json["exp"] as? TimeInterval {
            let remaining = Int(exp - Date().timeIntervalSince1970)
            expText = remaining > 0 ? "\(remaining)초 남음" : "만료됨(\(remaining)초 경과)"
        }

        return "aud=\(aud), iss=\(iss), sub=\(sub), exp=\(expText), nonce=\(hasNonce ? "있음" : "없음")"
    }

    /// JWT 는 base64url(패딩 없음) 이라 표준 Base64 로 복원해서 디코딩한다.
    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
