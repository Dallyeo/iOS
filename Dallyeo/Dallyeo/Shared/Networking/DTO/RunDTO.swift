//
//  RunDTO.swift
//  Dallyeo
//
//  POST /runs · POST /runs/{id}/image (API.md 7장)
//

import Foundation
import CoreLocation

/// 경로 좌표 한 점. 요청/응답에서 같은 형태로 쓴다.
struct RunPointDTO: Codable, Sendable {
    let lat: Double
    let lng: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        self.lat = coordinate.latitude
        self.lng = coordinate.longitude
    }
}

/// POST /runs 요청.
///
/// API.md: `polyline` 비어있음 / `distanceMeters`·`durationSeconds` ≤ 0 /
/// 필수 필드 누락 / `finishedAt < startedAt` → 400.
struct RunSaveRequest: Encodable, Sendable {
    /// 시드(공식) 코스를 달렸으면 그 id, 직접 만든 경로면 nil.
    let courseId: String?
    let polyline: [RunPointDTO]
    let distanceMeters: Int
    let durationSeconds: Int
    let averagePaceSeconds: Int
    let startedAt: String   // ISO8601 (UTC)
    let finishedAt: String  // ISO8601 (UTC)
}

/// 업적 한 건. 목록(API.md 8.1)과 저장 응답의 `newAchievements`가 같은 형태다.
struct AchievementDTO: Codable, Sendable {
    let code: String
    let name: String
    let description: String?
    let unlocked: Bool?
    let unlockedAt: String?
}

/// POST /runs (201) · POST /runs/{id}/image (200) 공통 응답.
struct RunRecordDTO: Decodable, Sendable {
    let id: Int
    let courseId: String?
    let courseName: String?
    let distanceMeters: Int?
    let durationSeconds: Int?
    let averagePaceSeconds: Int?
    /// 서버 기준 절대 경로(`/uploads/runs/….jpg`). 저장 직후엔 nil, 이미지 업로드 후 채워진다.
    let imageUrl: String?
    let startedAt: String?
    let finishedAt: String?
    /// 이번 러닝으로 **처음 달성한** 업적만 담긴다 — 결과창 도장.
    /// 저장 응답에만 있고 조회 API에는 이 필드 자체가 없다.
    let newAchievements: [AchievementDTO]?
}
