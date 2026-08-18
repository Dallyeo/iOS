//
//  WebConfig.swift
//  Dallyeo
//
//  웹 컨테이너 설정 (FE 웹앱 URL)
//

import Foundation

enum WebConfig {
    /// 배포된 FE 웹앱 URL (개발/검증용).
    /// TODO: prod 릴리스는 번들 로드(loadLocalHTML)로 전환 가능.
    static let webURLString = "https://dallyeo.vercel.app"
}
