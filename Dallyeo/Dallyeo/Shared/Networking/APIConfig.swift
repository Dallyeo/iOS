//
//  APIConfig.swift
//  Dallyeo
//
//  BE API 기본 설정 (base URL)
//

import Foundation

enum APIConfig {
    /// BE base URL.
    /// TODO: 승환에게 실제 도메인 확인 후 교체.
    /// - Info.plist에 `API_BASE_URL`이 있으면 그것을 우선 사용(빌드별 주입 가능).
    ///   ※ Secrets.xcconfig로 주입 시 xcconfig는 `//`를 주석 처리하므로
    ///     `API_BASE_URL = https:/$()/도메인` 형태로 이스케이프 필요.
    /// - 없으면 아래 placeholder 사용.
    static let baseURL: URL = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://REPLACE-WITH-BE-DOMAIN")!
    }()
}
