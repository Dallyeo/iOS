//
//  RunResult.swift
//  Dallyeo
//
//  V09 코스진행 종료 시 산출되는 러닝 결과.
//  웹에 `runCompleted`로 넘긴다. 저장(`POST /runs`)은 웹이 이 값으로 수행한다.
//

import CoreLocation
import Foundation

struct RunResult {
    let distanceKm: Double          // 이동 거리
    let durationSec: Int            // 진행 시간(초)
    let paceSecPerKm: Int           // 평균 페이스(초/km), 0이면 미측정
    let calories: Int               // 소모 칼로리(추정)
    let completionRate: Double      // 완주율 0.0~1.0
    let traveledPath: [CLLocationCoordinate2D]  // 실제 이동 경로

    // MARK: 웹이 `POST /runs`에 실어 보내는 값

    /// BE 추천 코스를 달렸으면 그 id, 직접 만든 경로면 nil.
    let courseId: String?
    /// 카운트다운이 끝나고 실제로 달리기 시작한 시각.
    let startedAt: Date
    /// 종료(또는 도착지 도달) 시각.
    let finishedAt: Date
}
