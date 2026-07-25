//
//  RegionDTO.swift
//  Dallyeo
//
//  GET /regions 응답 요소
//

import Foundation

struct RegionDTO: Decodable, Sendable {
    let code: String   // 예: "GUNSAN"
    let name: String   // 예: "군산"
}
