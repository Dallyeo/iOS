//
//  DistanceFormat.swift
//  Dallyeo
//
//  거리 표기 통일. V07 경로수정 / V08 코스확인 / V09 코스진행이 같은 코스를 다루므로
//  화면마다 포맷이 다르면 같은 경로가 다른 숫자로 보인다(예: 0.25km vs 0.3km).
//  표기 규칙은 여기 한 곳에서만 정의한다.
//

import Foundation

enum DistanceFormat {

    /// 러닝 거리 표기. 소수 2자리 = 10m 단위까지 보여 준다.
    /// 예: 250m → "0.25km", 4031m → "4.03km", 24157m → "24.16km"
    static func km(meters: Int) -> String {
        km(meters: Double(meters))
    }

    static func km(meters: Double) -> String {
        guard meters > 0 else { return "-" }
        return String(format: "%.2fkm", meters / 1000)
    }
}
