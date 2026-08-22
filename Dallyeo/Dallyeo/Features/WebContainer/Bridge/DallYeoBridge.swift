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
            handleGetCurrentSession(id: id)

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
    func emitRunCompleted(_ result: RunResult) {
        emit("runCompleted", payload: [
            "runId": UUID().uuidString,
            "distanceKm": result.distanceKm,
            "durationSec": result.durationSec,
            "paceSecPerKm": result.paceSecPerKm,
            "calories": result.calories,
            "completionRate": result.completionRate,
            "polyline": result.traveledPath.map { ["lat": $0.latitude, "lng": $0.longitude] }
        ])
    }

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
        AuthService.shared.logout()
        resolve(id: id)
        emitSessionChanged(status: "unauthenticated")
    }

    // MARK: - Session

    private func handleGetCurrentSession(id: String) {
        // 로그인 상태면 { session, token }, 미로그인이면 null (FE 규격)
        if let session = AuthService.shared.currentSession {
            resolve(id: id, data: sessionData(session))
        } else {
            callResolve(["id": id, "ok": true, "data": NSNull()])
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

    /// { session: {...}, token } — login / getCurrentSession resolve.data
    private func sessionData(_ session: AppSession) -> [String: Any] {
        ["session": sessionMeta(session), "token": session.accessToken]
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
