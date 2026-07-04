//
//  RunningViewModel.swift
//  Dallyeo
//
//  V09 코스진행뷰 ViewModel — 위치추적/타이머/지표/카운트다운
//  (iPhone 단독: CoreLocation + 타이머. HKWorkoutSession은 watchOS 전용이라 미사용)
//

import SwiftUI
import CoreLocation

@MainActor
@Observable
final class RunningViewModel: NSObject {

    enum Phase {
        case countdown   // 진입 3초 카운트다운
        case running
        case paused
        case finished
    }

    // MARK: - 상태

    var phase: Phase = .countdown
    var countdownValue: Int = 3

    var elapsedSec: Int = 0
    var distanceMeters: Double = 0
    var currentPaceSecPerKm: Int = 0     // 0이면 미측정(정지)
    var calories: Int = 0

    var userLocation: CLLocationCoordinate2D?
    var traveledPath: [CLLocationCoordinate2D] = []

    /// 경로 이탈(1km 초과) 알림
    var showDeviationAlert: Bool = false

    // MARK: - 경로 지점

    /// 남은 목표 지점들(경유지→도착지, 유효 좌표만)
    private let targets: [MapPlace]
    private var nextTargetIndex: Int = 0

    /// 지도 마커/폴리라인용 전체 경로 지점
    let routePlaces: [MapPlace]

    var nextTarget: MapPlace? {
        nextTargetIndex < targets.count ? targets[nextTargetIndex] : nil
    }

    /// 다음 지점 라벨 (경유지 / 도착지)
    var nextTargetLabel: String {
        guard let next = nextTarget else { return "" }
        return next.id == targets.last?.id ? "도착지" : "경유지"
    }

    /// 다음 지점까지 남은 거리(m)
    var remainingToNextMeters: Double {
        guard let next = nextTarget, let loc = userLocation else { return 0 }
        return Self.distance(loc, next.coordinate)
    }

    // MARK: - 완주율

    var completionRate: Double {
        guard !targets.isEmpty else { return 0 }
        return Double(nextTargetIndex) / Double(targets.count)
    }

    // MARK: - 설정

    private let locationManager = CLLocationManager()
    private var timer: Timer?
    private let bodyWeightKg: Double = 65   // TODO: 프로필 연동
    private let arrivalThreshold: Double = 30      // 지점 도착 판정(m)
    private let deviationThreshold: Double = 1000  // 경로 이탈(m)

    var onFinish: ((RunResult) -> Void)?

    // MARK: - Init

    init(draft: RouteDraft) {
        let ordered = (draft.waypoints + [draft.destination].compactMap { $0 })
            .filter { $0.latitude != 0 && $0.longitude != 0 }
        self.targets = ordered
        self.routePlaces = ([draft.start].compactMap { $0 } + ordered)
            .filter { $0.latitude != 0 && $0.longitude != 0 }
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    // MARK: - 라이프사이클

    func start() {
        startCountdown()
    }

    private func startCountdown() {
        phase = .countdown
        countdownValue = 3
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickCountdown() }
        }
    }

    private func tickCountdown() {
        countdownValue -= 1
        if countdownValue <= 0 {
            beginRunning()
        }
    }

    private func beginRunning() {
        phase = .running
        locationManager.startUpdatingLocation()
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickRunning() }
        }
    }

    private func tickRunning() {
        guard phase == .running else { return }
        elapsedSec += 1
        updateCalories()
    }

    func pause() {
        guard phase == .running else { return }
        phase = .paused
        locationManager.stopUpdatingLocation()
        currentPaceSecPerKm = 0
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
        locationManager.startUpdatingLocation()
    }

    func finish() {
        phase = .finished
        timer?.invalidate()
        locationManager.stopUpdatingLocation()
        onFinish?(makeResult())
    }

    // MARK: - 계산

    private func updateCalories() {
        // 간단 추정: kcal ≈ 거리(km) × 체중(kg) × 1.036
        calories = Int((distanceMeters / 1000) * bodyWeightKg * 1.036)
    }

    /// 평균 페이스(초/km)
    private var averagePaceSecPerKm: Int {
        guard distanceMeters > 0 else { return 0 }
        return Int(Double(elapsedSec) / (distanceMeters / 1000))
    }

    private func makeResult() -> RunResult {
        RunResult(
            distanceKm: distanceMeters / 1000,
            durationSec: elapsedSec,
            paceSecPerKm: averagePaceSecPerKm,
            calories: calories,
            completionRate: completionRate,
            traveledPath: traveledPath
        )
    }

    private func advanceTargetIfReached() {
        guard let next = nextTarget, let loc = userLocation else { return }
        if Self.distance(loc, next.coordinate) <= arrivalThreshold {
            nextTargetIndex += 1
            if nextTargetIndex >= targets.count {
                finish()   // 도착지 도달 → 자동 종료
            }
        }
    }

    private func checkDeviation() {
        guard let loc = userLocation, !routePlaces.isEmpty, !showDeviationAlert else { return }
        let nearest = routePlaces.map { Self.distance(loc, $0.coordinate) }.min() ?? 0
        if nearest > deviationThreshold {
            showDeviationAlert = true
        }
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

// MARK: - CLLocationManagerDelegate

extension RunningViewModel: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            guard self.phase == .running else { return }
            // 누적 거리
            if let last = self.traveledPath.last {
                self.distanceMeters += Self.distance(last, loc.coordinate)
            }
            self.traveledPath.append(loc.coordinate)
            self.userLocation = loc.coordinate
            // 현재 페이스 (speed m/s → 초/km)
            self.currentPaceSecPerKm = loc.speed > 0.3 ? Int(1000 / loc.speed) : 0
            self.advanceTargetIfReached()
            self.checkDeviation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
