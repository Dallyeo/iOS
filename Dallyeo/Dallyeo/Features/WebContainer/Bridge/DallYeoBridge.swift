//
//  DallYeoBridge.swift
//  Dallyeo
//
//  메인 브릿지 클래스 - Web ↔ Native 통신
//

import Foundation
import WebKit
import UIKit
import OSLog
import CoreLocation

@MainActor
final class DallYeoBridge: NSObject, WKScriptMessageHandler {

    private static let log = Logger(subsystem: "com.dallyeo.app", category: "bridge")

    weak var webView: WKWebView?
    weak var coordinator: AppCoordinator?

    private let permissionHandler = PermissionHandler()

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            await handleMessage(message)
        }
    }

    private func handleMessage(_ message: WKScriptMessage) async {
        // 웹에서 JSON 문자열로 전달
        guard let jsonString = message.body as? String,
              let data = jsonString.data(using: .utf8),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = body["method"] as? String else {
            return
        }

        let id = body["id"] as? String
        let params = body["params"] as? [String: Any]

        await handleMethod(method, params: params, id: id)
    }

    // MARK: - Method Handler

    private func handleMethod(_ method: String, params: [String: Any]?, id: String?) async {
        guard let bridgeMethod = BridgeMethod(rawValue: method) else {
            if let id { reject(id: id, error: .unknownMethod) }
            return
        }

        switch bridgeMethod {
        case .login:
            guard let id else { return }
            await handleLogin(params: params, id: id)

        case .logout:
            guard let id else { return }
            await handleLogout(id: id)

        case .getCurrentSession:
            guard let id else { return }
            await handleGetCurrentSession(id: id)

        case .getPermissionStatus:
            guard let id else { return }
            handleGetPermissionStatus(params: params, id: id)

        case .requestPermission:
            guard let id else { return }
            await handleRequestPermission(params: params, id: id)

        case .openCourseSearch:
            coordinator?.openCourseSearch()   // 단방향, 응답 없음

        case .openCourseConfirm:
            coordinator?.openCourseConfirm(courseId: Self.courseId(from: params))

        case .startRun:
            // 코스 id가 없으면 어떤 코스를 뛸지 알 수 없다 → 무시
            guard let id = Self.courseId(from: params) else { return }
            coordinator?.startRun(courseId: id)
        }
    }

    /// 웹이 넘긴 course 객체에서 id를 꺼낸다.
    /// `{course: {id: "..."}}` / `{courseId: "..."}` / `{course: "..."}` 모두 받아 준다.
    /// (FE 페이로드 형태가 확정되기 전이라 흔한 형태를 모두 수용)
    private static func courseId(from params: [String: Any]?) -> String? {
        guard let params else { return nil }
        if let id = params["courseId"] as? String { return id }
        if let course = params["course"] as? [String: Any] {
            return course["id"] as? String
        }
        if let id = params["course"] as? String { return id }
        return nil
    }

    // MARK: - Native → Web 이벤트

    /// 러닝 완료 → 웹 V10 완주 결과뷰로 결과 전달.
    ///
    /// 웹은 페이로드를 검증한 뒤에만 결과 화면으로 이동한다:
    /// `runId: string`, `distanceKm: number`, `completionRate: number`가 모두 있어야 한다.
    /// (배포 번들에서 확인 — 하나라도 없으면 이벤트를 조용히 버린다)
    /// runId는 아직 BE 기록 저장이 없어 클라이언트에서 생성한다.
    /// 완주 결과를 웹에 넘긴다.
    ///
    /// **키 이름은 웹이 읽는 그대로여야 한다.** 웹은 이 값을 그대로 `POST /runs`
    /// 바디로 변환해 저장하는데, 이름이 하나라도 어긋나면 `undefined`가 실려
    /// 백엔드가 400을 뱉고 "기록 저장에 실패했어요"만 뜬다.
    ///
    /// 웹 변환부(`_9`)가 읽는 키:
    ///   courseId · routePolyline · distanceKm · durationSec
    ///   avgPaceSecPerKm · startedAt · completedAt
    /// 결과화면 표시에 추가로 쓰는 키:
    ///   runId · calories · completionRate
    /// - Parameter saved: 백엔드 저장 결과. 실패했거나 비로그인이면 nil.
    func emitRunCompleted(_ result: RunResult,
                          saved: RunRecorder.Saved? = nil,
                          saveFailure: RunRecorder.Failure? = nil) {
        var payload: [String: Any] = [
            "runId": UUID().uuidString,
            "distanceKm": result.distanceKm,
            "durationSec": result.durationSec,
            "avgPaceSecPerKm": result.paceSecPerKm,
            "calories": result.calories,
            "completionRate": result.completionRate,
            "routePolyline": result.traveledPath.map { ["lat": $0.latitude, "lng": $0.longitude] },
            "startedAt": Self.iso.string(from: result.startedAt),
            "completedAt": Self.iso.string(from: result.finishedAt)
        ]
        // 직접 만든 코스는 id가 없다. nil을 그대로 넣으면 JSONSerialization이 실패해
        // 이벤트가 통째로 안 나간다(결과화면이 아예 안 뜬다). 키를 빼면
        // 웹이 `e.courseId ?? null`로 받아 null을 보낸다.
        if let courseId = result.courseId {
            payload["courseId"] = courseId
        }
        // 출발지·도착지 이름. 결과화면의 `옥돌해변 → 몽돌해변` 줄인데,
        // 웹은 **둘 다 있을 때만** 그린다(하나만 오면 "지정된 위치"로 대체).
        // 서버는 좌표만 저장하므로 앱이 안 넘기면 얻을 데가 없다.
        if let start = result.startPlaceName, !start.isEmpty {
            payload["startPlaceName"] = start
        }
        if let end = result.endPlaceName, !end.isEmpty {
            payload["endPlaceName"] = end
        }
        // 출발·도착 좌표. 결과화면이 `endLocation`으로 주변 맛집(`/places/nearby`)을
        // 조회하는데, 이 값이 없으면 쿼리 자체가 비활성화돼 맛집이 안 뜬다.
        // 러닝 기록과 맛집은 성격이 다른 데이터라 웹이 각각 따로 요청한다.
        if let start = result.traveledPath.first {
            payload["startLocation"] = ["lat": start.latitude, "lng": start.longitude]
        }
        if let end = result.traveledPath.last {
            payload["endLocation"] = ["lat": end.latitude, "lng": end.longitude]
        }
        // 저장 성공 시에만 실린다.
        //  - recordId: 웹이 `GET /runs/{id}`로 다시 불러올 수 있는 키.
        //    브릿지로 넘긴 값은 웹뷰가 리로드되면 날아가지만 이건 남는다.
        //  - newAchievements: 결과창 도장. 저장 응답에만 오는 값이라
        //    앱이 받아서 넘기지 않으면 다시 얻을 방법이 없다.
        //
        // 기존 필드는 그대로 둔다 — 웹이 조회 방식으로 옮기기 전에도 화면이 떠야 한다.
        if let saved {
            payload["recordId"] = saved.recordId
            if let imageUrl = saved.imageUrl.map(Self.absoluteURLString) {
                payload["imageUrl"] = imageUrl
                // 웹 결과화면은 `staticMapImageUrl`이라는 이름으로 읽는다(서버는 `imageUrl`).
                // 어느 쪽이 정리되든 화면이 뜨도록 둘 다 싣는다.
                payload["staticMapImageUrl"] = imageUrl
            }
            payload["newAchievements"] = saved.newAchievements.map { achievement in
                var item: [String: Any] = ["code": achievement.code, "name": achievement.name]
                if let c = achievement.category { item["category"] = c }
                if let s = achievement.sortOrder { item["sortOrder"] = s }
                if let d = achievement.description { item["description"] = d }
                // 도장 이미지도 서버 기준 경로라 절대 URL로 바꿔 넘긴다.
                if let on = achievement.iconOnUrl { item["iconOnUrl"] = Self.absoluteURLString(on) }
                if let off = achievement.iconOffUrl { item["iconOffUrl"] = Self.absoluteURLString(off) }
                if let u = achievement.unlocked { item["unlocked"] = u }
                if let at = achievement.unlockedAt { item["unlockedAt"] = at }
                return item
            }
        }
        // 저장 결과를 웹이 판단할 수 있게 같이 넘긴다. 네이티브가 토스트를 덮어
        // 띄우면 웹 결과화면과 두 겹으로 겹쳐서, 안내 문구는 웹이 그리게 둔다.
        payload["saved"] = saved != nil
        if let saveFailure {
            payload["saveFailReason"] = Self.reasonCode(saveFailure)
        }
        emit("runCompleted", payload: payload)
    }

    /// 서버가 주는 이미지 경로를 웹이 그대로 `<img src>`에 쓸 수 있는 절대 URL로 바꾼다.
    ///
    /// 서버는 `/uploads/runs/….jpg` 같은 **서버 기준 절대 경로**를 준다. 웹은 다른
    /// 도메인에서 뜨므로 이대로 넘기면 웹 도메인 기준으로 풀려 404가 난다.
    private static func absoluteURLString(_ path: String) -> String {
        guard !path.hasPrefix("http://"), !path.hasPrefix("https://") else { return path }
        return URL(string: path, relativeTo: APIConfig.baseURL)?.absoluteString ?? path
    }

    /// 저장 실패 사유를 웹이 분기할 수 있는 문자열로 바꾼다.
    ///  - `notSignedIn`: 게스트. "로그인하면 기록이 남아요" 유도.
    ///  - `notEnoughData`: 거리·시간이 0이라 애초에 안 보냄.
    ///  - `noSnapshot`: 지도 캡처 실패. 이미지가 필수라 저장을 시도조차 못 함.
    ///  - `network`: 요청 실패(서버 오류 포함). 재시도 안내.
    private static func reasonCode(_ failure: RunRecorder.Failure) -> String {
        switch failure {
        case .notSignedIn:   "notSignedIn"
        case .notEnoughData: "notEnoughData"
        case .noSnapshot:    "noSnapshot"
        case .network:       "network"
        }
    }

    /// `POST /runs`가 요구하는 ISO8601(UTC). 웹이 이 문자열을 그대로 넘긴다.
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// 러닝을 결과 없이 빠져나감
    func emitRunCancelled() {
        emit("runCancelled", payload: [:])
    }

    // MARK: - Login/Logout

    private func handleLogin(params: [String: Any]?, id: String) async {
        guard let providerString = params?["provider"] as? String,
              let provider = AuthProviderKind(rawValue: providerString) else {
            Self.log.error("login: 잘못된 provider 파라미터 (\(String(describing: params?["provider"]), privacy: .public))")
            reject(id: id, error: .invalidParams)
            return
        }

        Self.log.info("login 시작: provider=\(provider.rawValue, privacy: .public)")
        do {
            let session = try await AuthService.shared.login(provider: provider)
            Self.log.info("login 성공: userId=\(session.userId, privacy: .public)")
            resolve(id: id, data: sessionData(session))
            emitSessionChanged(
                status: "authenticated",
                session: sessionMeta(session),
                token: session.accessToken
            )
        } catch let error as AuthError {
            switch error {
            case .cancelled:
                Self.log.notice("login 취소: provider=\(provider.rawValue, privacy: .public)")
                reject(id: id, error: .cancelled)
            case .failed(let message):
                Self.log.error("login 실패: provider=\(provider.rawValue, privacy: .public) msg=\(message, privacy: .public)")
                reject(id: id, error: .failed(message))
            }
        } catch {
            Self.log.error("login 실패(기타): \(error.localizedDescription, privacy: .public)")
            reject(id: id, error: .failed(error.localizedDescription))
        }
    }

    private func handleLogout(id: String) async {
        await AuthService.shared.logout()
        resolve(id: id)
        emitSessionChanged(status: "unauthenticated")
    }

    // MARK: - Session

    private func handleGetCurrentSession(id: String) async {
        // 로그인 상태면 { session, token }, 미로그인이면 null (FE 규격)
        // 만료 시 AuthService 가 refreshToken 으로 갱신을 시도한다.
        if let session = await AuthService.shared.currentSession() {
            resolve(id: id, data: sessionData(session))
        } else {
            callResolve(["id": id, "ok": true, "data": NSNull()])
            // 저장된 세션이 갱신 실패로 파기됐을 수 있으므로 웹 상태를 맞춰 준다.
            emitSessionChanged(status: "unauthenticated")
        }
    }

    // MARK: - 세션 → 브릿지 페이로드

    /// { userId, displayName?, expiresAt?(ISO8601) }
    private func sessionMeta(_ session: AppSession) -> [String: Any] {
        var meta: [String: Any] = ["userId": session.userId]
        if let displayName = session.displayName {
            meta["displayName"] = displayName
        }
        if let expiresAt = session.expiresAt {
            meta["expiresAt"] = ISO8601DateFormatter().string(from: expiresAt)
        }
        return meta
    }

    /// { session: {...}, token, onboardingRequired? } — login / getCurrentSession resolve.data
    /// `onboardingRequired` 는 FE 규격 외 추가 필드(BE 로그인 응답). 웹이 온보딩 분기에 사용.
    private func sessionData(_ session: AppSession) -> [String: Any] {
        var data: [String: Any] = [
            "session": sessionMeta(session),
            "token": session.accessToken
        ]
        if let onboardingRequired = session.onboardingRequired {
            data["onboardingRequired"] = onboardingRequired
        }
        return data
    }

    // MARK: - Permission

    private func handleGetPermissionStatus(params: [String: Any]?, id: String) {
        guard let typeString = params?["type"] as? String,
              let type = PermissionType(rawValue: typeString) else {
            reject(id: id, error: .invalidParams)
            return
        }

        let status = permissionHandler.getPermissionStatus(type: type)
        resolve(id: id, data: ["status": status.status.rawValue])
    }

    private func handleRequestPermission(params: [String: Any]?, id: String) async {
        guard let typeString = params?["type"] as? String,
              let type = PermissionType(rawValue: typeString) else {
            reject(id: id, error: .invalidParams)
            return
        }

        let status = await permissionHandler.requestPermission(type: type)
        resolve(id: id, data: ["status": status.status.rawValue])
    }

    // MARK: - Promise Resolution
    // window.__dallyeoBridgeResolve({ id, ok, data })

    func resolve(id: String, data: Any? = nil) {
        var response: [String: Any] = ["id": id, "ok": true]
        if let data {
            response["data"] = data
        }
        callResolve(response)
    }

    func reject(id: String, error: BridgeErrorPayload) {
        var errorDict: [String: Any] = ["kind": error.kind]
        if let message = error.message {
            errorDict["message"] = message
        }
        let response: [String: Any] = [
            "id": id,
            "ok": false,
            "error": errorDict
        ]
        callResolve(response)
    }

    private func callResolve(_ payload: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = "window.__dallyeoBridgeResolve(\(jsonString));"
        webView?.evaluateJavaScript(js)
    }

    // MARK: - Native → Web 이벤트
    // window.__dallyeoBridgeEmit({ event, payload })

    func emit(_ event: String, payload: [String: Any]) {
        let message: [String: Any] = ["event": event, "payload": payload]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = "window.__dallyeoBridgeEmit(\(jsonString));"
        webView?.evaluateJavaScript(js)
    }

    // MARK: - 편의 이벤트

    func emitSessionChanged(status: String, session: [String: Any]? = nil, token: String? = nil) {
        var payload: [String: Any] = ["status": status]
        if let session { payload["session"] = session }
        if let token   { payload["token"] = token }
        emit("sessionChanged", payload: payload)
    }
}
