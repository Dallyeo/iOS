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
    ///
    /// 세션 확인보다 바디·이미지를 **먼저** 만든다. 게스트면 저장은 못 해도
    /// 그 둘을 보관해 뒀다가 로그인 시점에 올려야 하기 때문이다.
    static func save(_ result: RunResult, snapshot: UIImage?) async -> Result<Saved, Failure> {
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
            clientRunId: result.clientRunId,
            courseId: result.courseId,
            start: RunPointDTO(start),
            end: RunPointDTO(end),
            distanceMeters: meters,
            durationSeconds: result.durationSec,
            // 서버가 계산하지 않는 값이라 지금 안 보내면 기록 화면에서 영영 못 본다.
            // 보관해 뒀다 나중에 올릴 때도 이 값이 그대로 쓰인다(재계산 불가).
            calories: result.calories,
            startedAt: iso.string(from: result.startedAt),
            finishedAt: iso.string(from: result.finishedAt)
        )

        // 게스트. 결과화면이 "로그인하면 저장된다"고 안내하므로 버리지 않고 보관한다.
        guard let session = await AuthService.shared.currentSession() else {
            log("세션 없음 — 보관 후 로그인 때 올린다 (게스트)")
            PendingRunStore.save(body, jpeg: jpeg)
            return .failure(.notSignedIn)
        }

        do {
            let record = try await DallyeoAPI.saveRun(body, jpeg: jpeg, accessToken: session.accessToken)
            let achievements = record.newAchievements ?? []
            log("저장 완료 id=\(record.id), 신규 업적 \(achievements.count)개, 이미지 \(jpeg.count) bytes → \(record.imageUrl ?? "없음")")
            return .success(Saved(recordId: record.id,
                                  newAchievements: achievements,
                                  imageUrl: record.imageUrl))
        } catch {
            log("저장 실패 — \(meters)m, 이미지 \(jpeg.count) bytes, \(error)")
            // 서버가 잠깐 안 되는 것일 수 있으니 버리지 않고 보관한다.
            PendingRunStore.save(body, jpeg: jpeg)
            return .failure(.network)
        }
    }

    /// 보관해 둔 기록을 올린다. 로그인 직후와 앱 진입 시 호출한다.
    ///
    /// 게스트로 달린 기록은 이때 비로소 서버에 올라간다. 올린 결과의
    /// `newAchievements`는 따로 띄우지 않는다 — 도장은 기록 화면에서 보여주지
    /// 않기로 했고(팀 확인), 업적 탭에는 다음 조회 때 자연히 반영된다.
    @discardableResult
    static func flushPending() async -> Int {
        let entries = PendingRunStore.pending()
        log("[보관] 대기 \(entries.count)건")
        guard !entries.isEmpty else { return 0 }
        guard let session = await AuthService.shared.currentSession() else {
            log("[보관] 세션 없음 — \(entries.count)건 그대로 둠")
            return 0
        }

        var uploaded = 0
        for entry in entries {
            guard let jpeg = try? Data(contentsOf: entry.imageURL) else {
                PendingRunStore.remove(entry)
                continue
            }
            do {
                let record = try await DallyeoAPI.saveRun(
                    entry.body, jpeg: jpeg, accessToken: session.accessToken
                )
                log("[보관] 올림 완료 id=\(record.id), 신규 업적 \((record.newAchievements ?? []).count)개, \(record.calories.map { "\($0)kcal" } ?? "칼로리 없음") → \(record.imageUrl ?? "이미지 없음")")
                PendingRunStore.remove(entry)
                uploaded += 1
            } catch {
                // 데이터가 잘못된 경우(400)만 버린다. 다시 보내도 계속 실패하고
                // 붙들고 있으면 매번 같은 요청을 반복하게 된다.
                // 서버 오류(500)·네트워크 실패는 나중에 성공할 수 있으므로 남긴다.
                if isPermanentRejection(error) {
                    log("[보관] 데이터 오류로 폐기 \(entry.id): \(error)")
                    PendingRunStore.remove(entry)
                } else {
                    log("[보관] 올리기 실패 — 다음에 재시도 \(entry.id): \(error)")
                }
            }
        }
        return uploaded
    }

    /// 다시 보내도 소용없는 실패인지.
    ///
    /// 400 계열(필수 필드 누락·형식 오류·이미지 문제)만 해당한다.
    /// `INTERNAL_ERROR`(500)도 같은 `business`로 오지만 그건 재시도 대상이다.
    private static func isPermanentRejection(_ error: Error) -> Bool {
        guard case APIClientError.business(let body) = error else { return false }
        return body.code == "VALIDATION_ERROR" || body.code == "BAD_REQUEST"
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
