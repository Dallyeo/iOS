//
//  RegionName.swift
//  Dallyeo
//
//  역지오코딩 결과를 지역 칩용 짧은 지역명으로 변환 (V03/V04 공유)
//

import Foundation

enum RegionName {

    /// administrativeArea / locality → 짧은 지역명
    /// - 특별시/광역시/특별자치시: administrativeArea 사용 (서울특별시→서울, 부산광역시→부산, 세종특별자치시→세종)
    /// - 그 외(도 단위): locality 사용 (군산시→군산, 관악구→관악)
    static func short(admin: String?, locality: String?) -> String? {
        let metroSuffixes = ["특별자치시", "특별시", "광역시"]
        if let a = admin, let suffix = metroSuffixes.first(where: { a.hasSuffix($0) }) {
            return String(a.dropLast(suffix.count))
        }
        if let l = locality {
            for suffix in ["특별자치시", "광역시", "특별시", "시", "군", "구"] where l.hasSuffix(suffix) {
                return String(l.dropLast(suffix.count))
            }
            return l
        }
        return admin
    }
}
