//
//  RecentSearchStore.swift
//  Dallyeo
//
//  최근 검색어 로컬 저장소 (V04 검색뷰 / V05 검색결과뷰 공유)
//

import Foundation

enum RecentSearchStore {

    private static let key = "v04_recent_searches"
    private static let dateKey = "v04_recent_search_dates"   // [term: "MM.dd"]
    private static let maxCount = 10

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// 검색어별 저장 날짜 표시용 문자열("MM.dd"). 없으면 nil.
    static func date(for term: String) -> String? {
        dateMap()[term]
    }

    static func add(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        var list = load()
        list.removeAll { $0 == t }      // 중복 제거 후 최상단
        list.insert(t, at: 0)
        if list.count > maxCount { list = Array(list.prefix(maxCount)) }
        save(list)

        var dates = dateMap()
        dates[t] = todayString()
        pruneAndSaveDates(&dates, keeping: list)
    }

    static func remove(_ term: String) {
        var list = load()
        list.removeAll { $0 == term }
        save(list)
        var dates = dateMap()
        dates[term] = nil
        pruneAndSaveDates(&dates, keeping: list)
    }

    static func clear() {
        save([])
        UserDefaults.standard.removeObject(forKey: dateKey)
    }

    // MARK: - 내부

    private static func save(_ list: [String]) {
        UserDefaults.standard.set(list, forKey: key)
    }

    private static func dateMap() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: dateKey) as? [String: String] ?? [:]
    }

    /// 최근 목록에 없는 날짜는 제거 후 저장
    private static func pruneAndSaveDates(_ dates: inout [String: String], keeping list: [String]) {
        let set = Set(list)
        dates = dates.filter { set.contains($0.key) }
        UserDefaults.standard.set(dates, forKey: dateKey)
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "MM.dd"
        return f.string(from: Date())
    }
}
