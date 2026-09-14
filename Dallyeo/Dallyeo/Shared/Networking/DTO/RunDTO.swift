//
//  RunDTO.swift
//  Dallyeo
//
//  POST /runs · POST /runs/{id}/image (API.md 7장)
//

import Foundation
import CoreLocation

/// 좌표 한 점. 요청/응답에서 같은 형태로 쓴다.
struct RunPointDTO: Codable, Sendable {
    let lat: Double
    let lng: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        self.lat = coordinate.latitude
        self.lng = coordinate.longitude
    }
}

/// `POST /runs`의 `run` 파트(JSON).
///
/// **전체 경로는 보내지 않는다** — 서버는 출발·도착 2점만 저장하고,
/// 경로 그림은 같이 올리는 코스 이미지가 대신한다(API.md 7장).
/// `averagePaceSeconds`도 보내지 않는다. 거리·시간으로 서버가 계산해 응답에 넣어준다.
///
/// 400 조건: `distanceMeters`·`durationSeconds` ≤ 0 / `start`·`end` 누락 /
/// `finishedAt < startedAt` / `image` 파트 누락.
/// 저장하지 못한 기록을 기기에 보관했다 다시 올리므로 `Decodable`도 필요하다
/// (`PendingRunStore` 참고).
struct RunSaveRequest: Codable, Sendable {
    /// 시드(공식) 코스를 달렸으면 그 id, 직접 만든 경로면 nil.
    /// **업적 판정의 기준**이라 공식 코스면 꼭 보낸다. nil이면 "개척자" 업적 대상.
    let courseId: String?
    let start: RunPointDTO
    let end: RunPointDTO
    let distanceMeters: Int
    let durationSeconds: Int
    /// 없으면 "얼리버드"(8시 이전 시작) 업적만 판정되지 않는다.
    let startedAt: String   // ISO8601 (UTC)
    /// 기록의 날짜. 없으면 서버 저장 시각을 쓴다.
    let finishedAt: String  // ISO8601 (UTC)
}

/// 업적 한 건. 목록(API.md 8.1)과 저장 응답의 `newAchievements`가 같은 형태다.
struct AchievementDTO: Codable, Sendable {
    let code: String
    /// `GUNSAN` / `JEONJU` / `COMMON`. COMMON은 지역 무관이라
    /// 코드 접두사로 지역을 판정하면 안 된다.
    let category: String?
    let sortOrder: Int?
    let name: String
    let description: String?
    /// 도장 이미지(획득=컬러 / 미획득=흑백). 서버 기준 절대 경로.
    let iconOnUrl: String?
    let iconOffUrl: String?
    let unlocked: Bool?
    let unlockedAt: String?
}

/// `POST /runs` (201) · `POST /runs/{id}/image` (200) 공통 응답.
///
/// ⚠️ 러닝 계열 응답은 값이 없으면 **키 자체가 빠진다**(`null`로 오지 않음).
/// 그래서 전부 옵셔널이다.
struct RunRecordDTO: Decodable, Sendable {
    let id: Int
    let courseId: String?
    /// 코스를 못 찾으면 키가 없다. 코스명은 이 값 유무로 판단한다.
    let courseName: String?
    let start: RunPointDTO?
    let end: RunPointDTO?
    let distanceMeters: Int?
    let durationSeconds: Int?
    /// 서버가 거리·시간으로 계산해 준다.
    let averagePaceSeconds: Int?
    /// 서버 기준 절대 경로(`/uploads/runs/….jpg`). 표시할 때 base URL을 붙인다.
    let imageUrl: String?
    let startedAt: String?
    let finishedAt: String?
    /// 이번 러닝으로 **처음 달성한** 업적만 담긴다 — 결과창 도장.
    /// 저장 응답에만 있고 조회 API에는 이 필드 자체가 없다.
    let newAchievements: [AchievementDTO]?
}
