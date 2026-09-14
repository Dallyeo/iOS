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

    /// 중복 저장 방지 키. **러닝이 끝난 시점에 한 번** 만들어 재전송에도 같은 값을 쓴다.
    ///
    /// 저장은 됐는데 응답만 유실되면 앱은 성공/실패를 구분할 수 없어 다시 보낸다.
    /// 이 키가 없으면 같은 러닝이 여러 건 쌓이는데, 기록 삭제 API가 없어 되돌릴 수
    /// 없고 누적 업적(완주 10회·100km)까지 부풀려진다.
    /// 전송 시점에 만들면 재시도마다 값이 달라져 의미가 없다.
    let clientRunId: String
    /// BE 추천 코스를 달렸으면 그 id, 직접 만든 경로면 nil.
    let courseId: String?
    /// 출발지·도착지 이름. 결과 화면이 `옥돌해변 → 몽돌해변`으로 보여준다.
    /// 서버는 이 값을 저장하지 않아(좌표만 남는다) 앱이 넘겨야 나온다.
    let startPlaceName: String?
    let endPlaceName: String?
    /// 카운트다운이 끝나고 실제로 달리기 시작한 시각.
    let startedAt: Date
    /// 종료(또는 도착지 도달) 시각.
    let finishedAt: Date
}
