//
//  PendingRunStore.swift
//  Dallyeo
//
//  저장하지 못한 러닝 기록을 기기에 들고 있다가 나중에 다시 올린다.
//
//  게스트로 달리면 `POST /runs`가 토큰을 요구해 저장이 안 되는데, 결과화면에는
//  "지금 이 화면을 벗어나시면 기록이 저장되지 않습니다. 로그인 하시겠습니까?"가
//  뜬다. 즉 **로그인하면 저장된다고 약속**해 놓은 상태다. 그 약속을 지키려면
//  기록과 지도 이미지를 기기에 남겨 뒀다가 로그인 시점에 올려야 한다.
//  (서버는 이 데이터를 한 번도 받은 적이 없어서 서버가 대신 들고 있을 수 없다.)
//
//  네트워크 실패로 못 올린 것도 같이 담는다. 사유만 다를 뿐 "나중에 다시 올린다"는
//  똑같다.
//

import Foundation
import OSLog

enum PendingRunStore {

    /// 보관 중인 기록 하나. JSON 본문과 이미지 파일이 한 쌍이다.
    struct Entry: Sendable {
        let id: String
        let body: RunSaveRequest
        let imageURL: URL
    }

    /// 보관 기간. 지나면 올리지 않고 지운다.
    /// 백엔드 가이드(`client-run-sync-guide.md` §8) 권장치.
    static let expiry: TimeInterval = 30 * 24 * 60 * 60

    /// 한 번에 들고 있을 최대 건수. 오래된 것부터 버린다.
    /// 게스트로 계속 달리는 사람의 디스크를 무한정 쓰지 않기 위한 상한.
    static let maxEntries = 20

    // MARK: - 쓰기

    /// 저장 실패한 기록을 보관한다.
    static func save(_ body: RunSaveRequest, jpeg: Data) {
        do {
            let dir = try directory()
            // 파일명 앞에 시각을 붙여 이름만으로 오래된 순 정렬이 된다.
            let id = "\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)"
            try JSONEncoder().encode(body).write(to: dir.appending(path: "\(id).json"))
            try jpeg.write(to: dir.appending(path: "\(id).jpg"))
            log("보관 \(id) — \(body.distanceMeters)m, 이미지 \(jpeg.count) bytes")
            trimIfNeeded()
        } catch {
            log("보관 실패 — \(error)")
        }
    }

    /// 보관분을 지운다. 업로드에 성공했거나 만료됐을 때.
    static func remove(_ entry: Entry) {
        guard let dir = try? directory() else { return }
        try? FileManager.default.removeItem(at: dir.appending(path: "\(entry.id).json"))
        try? FileManager.default.removeItem(at: entry.imageURL)
    }

    // MARK: - 읽기

    /// 보관 중인 기록을 오래된 순으로 돌려준다. 만료된 것은 지우고 제외한다.
    static func pending() -> [Entry] {
        // URL 기반 API를 쓴다. `URL.path()`는 퍼센트 인코딩된 경로를 주는데
        // (`Application Support` → `Application%20Support`) `atPath:` 계열은
        // 그걸 못 읽어 목록이 항상 비어 버린다.
        guard let dir = try? directory(),
              let urls = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        let names = urls.map(\.lastPathComponent)
        let deadline = Date().addingTimeInterval(-expiry)
        var entries: [Entry] = []
        for name in names.filter({ $0.hasSuffix(".json") }).sorted() {
            let id = String(name.dropLast(5))
            let jsonURL = dir.appending(path: name)
            let imageURL = dir.appending(path: "\(id).jpg")

            guard let data = try? Data(contentsOf: jsonURL),
                  let body = try? JSONDecoder().decode(RunSaveRequest.self, from: data),
                  FileManager.default.fileExists(atPath: imageURL.path(percentEncoded: false)) else {
                // 짝이 깨졌으면 올릴 수 없다. 남겨둬도 계속 실패하므로 정리한다.
                try? FileManager.default.removeItem(at: jsonURL)
                try? FileManager.default.removeItem(at: imageURL)
                continue
            }
            let entry = Entry(id: id, body: body, imageURL: imageURL)
            // 보관 시각은 파일명 앞부분에서 읽는다.
            if let stamp = TimeInterval(id.split(separator: "-").first.map(String.init) ?? ""),
               Date(timeIntervalSince1970: stamp) < deadline {
                log("만료 폐기 \(id)")
                remove(entry)
                continue
            }
            entries.append(entry)
        }
        return entries
    }

    // MARK: - 내부

    /// 상한을 넘으면 오래된 것부터 버린다.
    private static func trimIfNeeded() {
        let entries = pending()
        guard entries.count > maxEntries else { return }
        for entry in entries.prefix(entries.count - maxEntries) {
            log("상한 초과 폐기 \(entry.id)")
            remove(entry)
        }
    }

    /// 보관 폴더. 사용자 문서가 아니라 앱 지원 폴더에 둔다(파일 앱에 노출되지 않는다).
    private static func directory() throws -> URL {
        let base = URL.applicationSupportDirectory.appending(path: "PendingRuns")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static let logger = Logger(subsystem: "com.dallyeo.app", category: "run-record")

    private static func log(_ message: String) {
        logger.info("[보관] \(message, privacy: .public)")
    }
}
