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
    /// 진행 방향(도, 진북 기준). 정지 상태 등으로 못 구하면 nil.
    /// 지도를 이 방향으로 돌려 "가는 쪽이 화면 위"가 되게 한다(내비게이션 방식).
    var headingDegrees: Double?

    /// 현재 떠 있는 알럿. 디자인은 일시정지(569:673) / 종료 확인(569:1142) 2종.
    /// 경로 이탈도 스펙상 "종료할 것인지 묻는다"라 종료 확인을 재사용한다.
    enum ActiveAlert: Identifiable {
        case paused
        case finishConfirm
        case deviated

        var id: Int {
            switch self {
            case .paused: 0
            case .finishConfirm: 1
            case .deviated: 2
            }
        }
    }

    var activeAlert: ActiveAlert?

    // MARK: - 경로 지점

    /// 진행할 코스 (V08에서 확정된 것을 그대로 받는다)
    let course: RunCourse

    /// 남은 목표 지점들(경유지→도착지, 유효 좌표만)
    private let targets: [CoursePoint]
    private var nextTargetIndex: Int = 0

    var nextTarget: CoursePoint? {
        nextTargetIndex < targets.count ? targets[nextTargetIndex] : nil
    }

    /// 지도 마커 = 경유지 + 도착지 + 현재 위치.
    ///
    /// **출발지 마커는 그리지 않는다.** 러닝 시작 시점에는 현재 위치가 곧 출발지라
    /// 두 마커가 같은 자리에 겹쳐 뭉개진다. Figma V09 프레임(609:603)에도 경유 번호와
    /// 현재위치만 있다. 시작 지점은 경로선으로 이미 드러난다.
    /// (도착지는 진행 중 목적지 확인용으로 남긴다 — 팀 확인 완료)
    var mapMarkers: [MapMarker] {
        var result = course.points
            .filter { if case .start = $0.role { false } else { true } }
            .filter(\.hasCoordinate)
            .map { MapMarker(coordinate: $0.coordinate, kind: $0.markerKind) }
        if let loc = userLocation {
            result.append(MapMarker(coordinate: loc, kind: .currentLocation))
        }
        return result
    }

    /// 지나온 구간을 지울 기준 위치.
    ///
    /// **경로에서 멀리 벗어나 있으면 nil을 준다.** 벗어난 상태에서는 "경로상 가장 가까운
    /// 점"이 실제로 지나온 곳과 무관하게 잡혀, 지나지도 않은 구간이 지워진다.
    /// 다시 경로로 돌아오면 자연스럽게 갱신이 재개된다.
    var routeProgressPosition: CLLocationCoordinate2D? {
        guard let loc = userLocation, !course.polyline.isEmpty else { return nil }
        let nearest = course.polyline.map { Self.distance(loc, $0) }.min() ?? .greatestFiniteMagnitude
        return nearest <= Self.onRouteThreshold ? loc : nil
    }

    /// 경로 위에 있다고 볼 거리(m). GPS 오차와 인도/차도 폭을 감안한 값.
    private static let onRouteThreshold: Double = 50

    /// 다음 지점 라벨 (경유지 / 도착지)
    var nextTargetLabel: String {
        guard let next = nextTarget else { return "" }
        if case .destination = next.role { return "도착지" }
        return "경유지"
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

    /// 코스 총 거리(m). T MAP/BE 실거리를 그대로 쓴다 (직선거리 재계산 안 함)
    private var totalCourseMeters: Double {
        Double(course.totalMeters)
    }

    /// 진행률(0~1) — 이동 거리 기준. 하단 진행 바 화살표 위치용
    var progressFraction: Double {
        guard totalCourseMeters > 0 else { return 0 }
        return min(distanceMeters / totalCourseMeters, 1)
    }

    // MARK: - 설정

    private let locationManager = CLLocationManager()
    private var timer: Timer?

    /// 칼로리 계산용 체중(kg).
    /// 온보딩(웹)에서 입력받은 값을 브릿지로 넘겨줄 수 있게 되면 그때 주입한다.
    /// 그전까지는 기본값 — 입력하지 않은 사용자도 있으므로 기본값은 계속 필요하다.
    var bodyWeightKg: Double = RunningViewModel.defaultBodyWeightKg
    static let defaultBodyWeightKg: Double = 65

    // MARK: 위치 샘플 필터/집계

    /// 직전에 채택한 위치 샘플
    private var lastSample: CLLocation?
    /// 최근 구간 (현재 페이스 계산용)
    private var recentSamples: [(distance: Double, duration: TimeInterval)] = []
    /// 칼로리 누적(소수 유지). Int로 바로 담으면 구간마다 버림이 쌓인다.
    private var caloriesAccumulator: Double = 0

    /// 이보다 정확도가 나쁜 샘플은 버린다(m)
    private static let maxAcceptableAccuracy: Double = 30
    /// 이보다 작게 움직였으면 노이즈로 본다(m)
    private static let minMovementMeters: Double = 3
    /// 사람이 낼 수 있는 최대 속도(m/s). 약 27km/h — 이보다 빠르면 튄 좌표다.
    private static let maxPlausibleSpeed: Double = 7.5
    /// 현재 페이스를 계산할 최근 구간 길이(초)
    private static let paceWindowSeconds: TimeInterval = 30
    private let arrivalThreshold: Double = 30      // 지점 도착 판정(m)
    private let deviationThreshold: Double = 1000  // 경로 이탈(m)

    var onFinish: ((RunResult) -> Void)?

    // MARK: - Init

    init(course: RunCourse) {
        self.course = course
        // 출발지는 이미 지나온 지점이므로 목표에서 제외
        self.targets = course.points
            .filter { if case .start = $0.role { false } else { true } }
            .filter(\.hasCoordinate)
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
    }

    func pause() {
        guard phase == .running else { return }
        phase = .paused
        locationManager.stopUpdatingLocation()
        currentPaceSecPerKm = 0
        // 재개 시 정지 구간이 페이스에 섞이지 않도록 최근 구간과 직전 샘플을 비운다
        recentSamples.removeAll()
        lastSample = nil
        activeAlert = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
        locationManager.startUpdatingLocation()
        activeAlert = nil
    }

    /// 하단 "끝내기" — 바로 끝내지 않고 확인을 받는다 (Figma 569:1142)
    func requestFinish() {
        activeAlert = .finishConfirm
    }

    func dismissAlert() {
        activeAlert = nil
    }

    func finish() {
        phase = .finished
        timer?.invalidate()
        locationManager.stopUpdatingLocation()
        onFinish?(makeResult())
    }

    // MARK: - 계산


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

    /// 코스 경로선에서 1km 초과로 벗어나면 종료 여부를 묻는다.
    /// 지점이 아니라 **폴리라인 전체**와의 최단 거리로 판정한다 (지점 기준이면 지점 사이 구간에서 오탐).
    private func checkDeviation() {
        guard let loc = userLocation, activeAlert == nil else { return }
        let reference = course.polyline.isEmpty
            ? course.points.filter(\.hasCoordinate).map(\.coordinate)
            : course.polyline
        guard !reference.isEmpty else { return }
        let nearest = reference.map { Self.distance(loc, $0) }.min() ?? 0
        if nearest > deviationThreshold {
            activeAlert = .deviated
        }
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    // MARK: - 위치 샘플 처리

    /// 위치 샘플 하나를 받아 거리·페이스·방향을 갱신한다.
    ///
    /// GPS는 도심에서 10~20m씩 튄다. 걸러내지 않으면 **가만히 서 있어도 거리와
    /// 칼로리가 계속 올라간다.** 아래 두 가지로 거른다:
    ///  - 정확도가 나쁜 샘플은 버린다
    ///  - 직전 샘플 대비 이동이 정확도보다 작으면 노이즈로 보고 거리에 넣지 않는다
    private func ingest(_ location: CLLocation) {
        // 1) 정확도가 나쁘거나 알 수 없는 샘플은 버린다
        let accuracy = location.horizontalAccuracy
        guard accuracy > 0, accuracy <= Self.maxAcceptableAccuracy else { return }

        // 2) 지도 표시용 현재 위치·방향은 항상 갱신 (거리에 안 넣더라도 위치는 보여야 한다)
        userLocation = location.coordinate
        if location.course >= 0 { headingDegrees = location.course }

        defer {
            lastSample = location
            advanceTargetIfReached()
            checkDeviation()
        }

        guard let previous = lastSample else {
            traveledPath.append(location.coordinate)
            return
        }

        let moved = location.distance(from: previous)
        let elapsed = location.timestamp.timeIntervalSince(previous.timestamp)

        // 3) 이동량이 GPS 오차 범위 안이면 실제로 움직인 게 아니다
        guard moved >= max(Self.minMovementMeters, accuracy * 0.5) else { return }
        // 4) 사람이 낼 수 없는 속도면 튄 좌표다
        guard elapsed > 0, moved / elapsed <= Self.maxPlausibleSpeed else { return }

        distanceMeters += moved
        traveledPath.append(location.coordinate)
        recentSamples.append((distance: moved, duration: elapsed))
        trimRecentSamples()
        updateCurrentPace()
        accumulateCalories(distance: moved, duration: elapsed)
    }

    /// 최근 구간만 남긴다. 전체 평균으로 페이스를 내면 값이 굼떠서
    /// 지금 빠른지 느린지가 안 보인다.
    private func trimRecentSamples() {
        var total = recentSamples.reduce(0) { $0 + $1.duration }
        while total > Self.paceWindowSeconds, recentSamples.count > 1 {
            total -= recentSamples.removeFirst().duration
        }
    }

    /// 현재 페이스 = 최근 구간의 시간 ÷ 거리
    private func updateCurrentPace() {
        let distance = recentSamples.reduce(0) { $0 + $1.distance }
        let duration = recentSamples.reduce(0) { $0 + $1.duration }
        guard distance > 0, duration > 0 else { currentPaceSecPerKm = 0; return }
        currentPaceSecPerKm = Int(duration / (distance / 1000))
    }

    /// 칼로리 = MET × 체중(kg) × 시간(h). 구간별로 누적한다.
    /// MET은 그 구간의 속도로 매핑한다 (걷기~3.5, 조깅~8, 러닝~10, 빠름~11.5).
    private func accumulateCalories(distance: Double, duration: TimeInterval) {
        let speed = distance / duration          // m/s
        let met: Double
        switch speed {
        case ..<1.4:  met = 3.5    // 걷기
        case ..<2.2:  met = 6.0    // 빠른 걷기
        case ..<2.7:  met = 8.0    // 조깅
        case ..<3.3:  met = 10.0   // 러닝
        default:      met = 11.5   // 빠른 러닝
        }
        caloriesAccumulator += met * bodyWeightKg * (duration / 3600)
        calories = Int(caloriesAccumulator)
    }
}

// MARK: - CLLocationManagerDelegate

extension RunningViewModel: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            guard self.phase == .running else { return }
            self.ingest(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
