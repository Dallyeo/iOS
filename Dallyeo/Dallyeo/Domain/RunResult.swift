//
//  RunResult.swift
//  Dallyeo
//
//  V09 코스진행 종료 시 산출되는 러닝 결과 (→ 웹 V10, runCompleted 이벤트용)
//

import CoreLocation

struct RunResult {
    let distanceKm: Double          // 이동 거리
    let durationSec: Int            // 진행 시간(초)
    let paceSecPerKm: Int           // 평균 페이스(초/km), 0이면 미측정
    let calories: Int               // 소모 칼로리(추정)
    let completionRate: Double      // 완주율 0.0~1.0
    let traveledPath: [CLLocationCoordinate2D]  // 실제 이동 경로
    // TODO: 정적 지도 이미지 URL은 백엔드 제공
}
