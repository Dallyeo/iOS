//
//  RecentSearchStore.swift
//  Dallyeo
//
//  최근 검색어 로컬 저장소 (V04 검색뷰 / V05 검색결과뷰 공유)
//

import Foundation

enum RecentSearchStore {

    private static let key = "v04_recent_searches"
    private static let maxCount = 10

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        var list = load()
        list.removeAll { $0 == t }      // 중복 제거 후 최상단
        list.insert(t, at: 0)
        if list.count > maxCount { list = Array(list.prefix(maxCount)) }
        save(list)
    }

    static func remove(_ term: String) {
        var list = load()
        list.removeAll { $0 == term }
        save(list)
    }

    static func clear() {
        save([])
    }

    private static func save(_ list: [String]) {
        UserDefaults.standard.set(list, forKey: key)
    }
}
