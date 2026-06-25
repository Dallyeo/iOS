//
//  SearchSuggestion.swift
//  Dallyeo
//
//  V04 검색뷰 — 유사 검색어(자동완성) 항목
//

import Foundation

struct SearchSuggestion: Identifiable, Sendable {
    let id: String
    let name: String       // 장소명
    let address: String?   // 주소(부가 정보)
}
