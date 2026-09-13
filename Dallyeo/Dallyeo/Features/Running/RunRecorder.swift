//
//  RunRecorder.swift
//  Dallyeo
//
//  완주 결과를 백엔드에 저장한다 (`POST /runs` → `POST /runs/{id}/image`).
//
//  저장을 앱이 맡는 이유:
//   - 기록 이미지는 카카오맵 뷰를 캡처해야 해서 iOS만 만들 수 있고,
//     그 업로드에 필요한 `id`가 저장 응답에서만 나온다. 웹이 저장하면
//     "웹이 id 받음 → 앱에 되돌려줌 → 앱이 업로드"로 왕복이 하나 더 생긴다.
//   - 거리·시간·페이스·좌표를 측정한 주체가 앱이다.
//
//  결과창 도장(`newAchievements`)도 저장 응답에만 담겨 오므로 여기서 받아
//  웹으로 넘겨야 한다. 조회 API에는 그 필드가 아예 없다.
//

import Foundation
import OSLog
import UIKit

enum RunRecorder {

    /// 저장 결과. 웹에 넘길 값만 담는다.
    struct Saved: Sendable {
        let recordId: Int
        let newAchievements: [AchievementDTO]
        /// 이미지까지 붙었는지. 기록은 남았는데 이미지만 실패할 수 있다.
        let hasImage: Bool
    }

    enum Failure: Error, Equatable, Sendable {
        /// 비로그인. `POST /runs`가 토큰을 요구해 저장 자체가 불가능하다.
        case notSignedIn
        /// 서버가 400으로 막는 조건을 이미 만족하지 못함(좌표 없음 등).
        case notEnoughData
        case network
    }

    /// 기록을 저장하고 스냅샷을 붙인다.
    ///
    /// 이미지 업로드가 실패해도 **기록은 남으므로 성공으로 본다.** 나중에 재업로드할 수 있다.
    static func save(_ result: RunResult, snapshot: UIImage?) async -> Result<Saved, Failure> {
        guard let session = await AuthService.shared.currentSession() else {
            log("세션 없음 — 저장 건너뜀 (게스트)")
            return .failure(.notSignedIn)
        }

        // 서버가 400으로 막는 조건은 미리 걸러 무의미한 요청을 줄인다.
        let meters = Int((result.distanceKm * 1000).rounded())
        guard !result.traveledPath.isEmpty, meters > 0, result.durationSec > 0 else {
            log("저장 조건 미달 — 좌표 \(result.traveledPath.count)개, \(meters)m, \(result.durationSec)초")
            return .failure(.notEnoughData)
        }

        let body = RunSaveRequest(
            courseId: result.courseId,
            polyline: result.traveledPath.map(RunPointDTO.init),
            distanceMeters: meters,
            durationSeconds: result.durationSec,
            averagePaceSeconds: result.paceSecPerKm,
            startedAt: iso.string(from: result.startedAt),
            finishedAt: iso.string(from: result.finishedAt)
        )

        let record: RunRecordDTO
        do {
            record = try await DallyeoAPI.saveRun(body, accessToken: session.accessToken)
        } catch {
            log("저장 실패 — 좌표 \(body.polyline.count)개, \(body.distanceMeters)m, \(error)")
            return .failure(.network)
        }

        let achievements = record.newAchievements ?? []
        log("저장 완료 id=\(record.id), 신규 업적 \(achievements.count)개")

        let uploaded = await uploadImage(snapshot, runId: record.id, token: session.accessToken)
        return .success(Saved(recordId: record.id,
                              newAchievements: achievements,
                              hasImage: uploaded))
    }

    /// 스냅샷을 올린다. 실패해도 기록은 이미 저장돼 있으므로 조용히 넘어간다.
    private static func uploadImage(_ image: UIImage?, runId: Int, token: String) async -> Bool {
        guard let image else { log("스냅샷 없음 — 이미지 생략"); return false }
        // 서버 상한 10MB. 지도 한 장은 압축률 0.8이면 보통 1MB 안쪽이다.
        guard let jpeg = image.jpegData(compressionQuality: 0.8), jpeg.count < 10_000_000 else {
            log("이미지 인코딩 실패 또는 용량 초과")
            return false
        }
        do {
            _ = try await DallyeoAPI.uploadRunImage(runId: runId, jpeg: jpeg, accessToken: token)
            log("이미지 업로드 완료 \(jpeg.count) bytes")
            return true
        } catch {
            log("이미지 업로드 실패 — \(error)")
            return false
        }
    }

    /// `POST /runs`는 ISO8601(UTC)을 받는다.
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let logger = Logger(subsystem: "com.dallyeo.app", category: "run-record")

    private static func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}
