//
//  RunRecorder.swift
//  Dallyeo
//
//  완주 결과를 백엔드에 저장한다 (`POST /runs`, multipart).
//
//  저장을 앱이 맡는 이유:
//   - 저장 요청에 **코스 이미지가 필수**인데, 그 이미지는 카카오맵 뷰를 캡처해야
//     만들 수 있어 iOS만 만들 수 있다. 웹이 저장하려면 앱에서 이미지를 건네받아야 한다.
//   - 거리·시간·좌표를 측정한 주체가 앱이다.
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
        /// 서버 기준 절대 경로(`/uploads/runs/….jpg`). 표시할 때 base URL을 붙인다.
        let imageUrl: String?
    }

    enum Failure: Error, Equatable, Sendable {
        /// 비로그인. `POST /runs`가 토큰을 요구해 저장 자체가 불가능하다.
        case notSignedIn
        /// 서버가 400으로 막는 조건을 이미 만족하지 못함(좌표 없음, 거리/시간 0).
        case notEnoughData
        /// 지도 캡처 실패. 이미지가 필수라 캡처가 없으면 저장을 시도할 수 없다.
        case noSnapshot
        case network
    }

    /// 기록과 지도 스냅샷을 한 요청으로 저장한다.
    static func save(_ result: RunResult, snapshot: UIImage?) async -> Result<Saved, Failure> {
        guard let session = await AuthService.shared.currentSession() else {
            log("세션 없음 — 저장 건너뜀 (게스트)")
            return .failure(.notSignedIn)
        }

        // 서버가 400으로 막는 조건은 미리 걸러 무의미한 요청을 줄인다.
        let meters = Int((result.distanceKm * 1000).rounded())
        guard let start = result.traveledPath.first,
              let end = result.traveledPath.last,
              meters > 0, result.durationSec > 0 else {
            log("저장 조건 미달 — 좌표 \(result.traveledPath.count)개, \(meters)m, \(result.durationSec)초")
            return .failure(.notEnoughData)
        }

        // 이미지는 선택이 아니라 필수 파트다(누락 시 400).
        guard let snapshot else {
            log("지도 캡처 실패 — 이미지가 필수라 저장 불가")
            return .failure(.noSnapshot)
        }
        // 서버 상한 10MB. 지도 한 장은 압축률 0.8이면 보통 1MB 안쪽이다.
        guard let jpeg = snapshot.jpegData(compressionQuality: 0.8), jpeg.count < 10_000_000 else {
            log("이미지 인코딩 실패 또는 용량 초과")
            return .failure(.noSnapshot)
        }

        let body = RunSaveRequest(
            courseId: result.courseId,
            start: RunPointDTO(start),
            end: RunPointDTO(end),
            distanceMeters: meters,
            durationSeconds: result.durationSec,
            startedAt: iso.string(from: result.startedAt),
            finishedAt: iso.string(from: result.finishedAt)
        )

        do {
            let record = try await DallyeoAPI.saveRun(body, jpeg: jpeg, accessToken: session.accessToken)
            let achievements = record.newAchievements ?? []
            log("저장 완료 id=\(record.id), 신규 업적 \(achievements.count)개, 이미지 \(jpeg.count) bytes → \(record.imageUrl ?? "없음")")
            return .success(Saved(recordId: record.id,
                                  newAchievements: achievements,
                                  imageUrl: record.imageUrl))
        } catch {
            log("저장 실패 — \(meters)m, 이미지 \(jpeg.count) bytes, \(error)")
            return .failure(.network)
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
