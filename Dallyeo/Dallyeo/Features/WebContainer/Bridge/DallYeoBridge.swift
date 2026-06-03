//
//  DallYeoBridge.swift
//  Dallyeo
//
//  메인 브릿지 클래스 - Web ↔ Native 통신
//

import Foundation
import WebKit
import UIKit

@MainActor
final class DallYeoBridge: NSObject, WKScriptMessageHandler {

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
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String,
              let requestId = body["requestId"] as? String else {
            return
        }

        let payload = body["payload"] as? [String: Any]

        await handleAction(action, payload: payload, requestId: requestId)
    }

    // MARK: - Action Handler

    private func handleAction(_ action: String, payload: [String: Any]?, requestId: String) async {
        guard let bridgeAction = BridgeAction(rawValue: action) else {
            reject(requestId: requestId, error: .unknownAction)
            return
        }

        switch bridgeAction {
        case .login:
            await handleLogin(payload: payload, requestId: requestId)

        case .logout:
            await handleLogout(requestId: requestId)

        case .openCourseSearch:
            coordinator?.openCourseSearch()
            resolve(requestId: requestId)

        case .openCourseConfirm:
            coordinator?.openCourseConfirm()
            resolve(requestId: requestId)

        case .startRun:
            coordinator?.startRun()
            resolve(requestId: requestId)

        case .getPermissionStatus:
            handleGetPermissionStatus(payload: payload, requestId: requestId)

        case .requestPermission:
            await handleRequestPermission(payload: payload, requestId: requestId)

        case .openOSSettings:
            openOSSettings()
            resolve(requestId: requestId)

        case .pickProfilePhoto:
            // TODO: 이미지 피커 구현
            reject(requestId: requestId, error: .notImplemented)

        case .share:
            handleShare(payload: payload, requestId: requestId)

        case .openExternalUrl:
            handleOpenExternalUrl(payload: payload, requestId: requestId)
        }
    }

    // MARK: - Login/Logout

    private func handleLogin(payload: [String: Any]?, requestId: String) async {
        // TODO: OAuth 네이티브 로그인 구현
        reject(requestId: requestId, error: .notImplemented)
    }

    private func handleLogout(requestId: String) async {
        do {
            try KeychainManager.shared.delete(for: "session")
            resolve(requestId: requestId)
            emit("sessionChanged", payload: ["session": nil])
        } catch {
            reject(requestId: requestId, error: BridgeError(code: "LOGOUT_FAILED", message: error.localizedDescription))
        }
    }

    // MARK: - Permission

    private func handleGetPermissionStatus(payload: [String: Any]?, requestId: String) {
        guard let typeString = payload?["type"] as? String,
              let type = PermissionType(rawValue: typeString) else {
            reject(requestId: requestId, error: .invalidPayload)
            return
        }

        let status = permissionHandler.getPermissionStatus(type: type)
        resolve(requestId: requestId, data: [
            "type": status.type.rawValue,
            "status": status.status.rawValue
        ])
    }

    private func handleRequestPermission(payload: [String: Any]?, requestId: String) async {
        guard let typeString = payload?["type"] as? String,
              let type = PermissionType(rawValue: typeString) else {
            reject(requestId: requestId, error: .invalidPayload)
            return
        }

        let status = await permissionHandler.requestPermission(type: type)
        resolve(requestId: requestId, data: [
            "type": status.type.rawValue,
            "status": status.status.rawValue
        ])
    }

    // MARK: - OS Settings

    private func openOSSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Share

    private func handleShare(payload: [String: Any]?, requestId: String) {
        guard let text = payload?["text"] as? String else {
            reject(requestId: requestId, error: .invalidPayload)
            return
        }

        var items: [Any] = [text]

        if let urlString = payload?["url"] as? String,
           let url = URL(string: urlString) {
            items.append(url)
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        resolve(requestId: requestId)
    }

    // MARK: - External URL

    private func handleOpenExternalUrl(payload: [String: Any]?, requestId: String) {
        guard let urlString = payload?["url"] as? String,
              let url = URL(string: urlString) else {
            reject(requestId: requestId, error: .invalidPayload)
            return
        }

        UIApplication.shared.open(url)
        resolve(requestId: requestId)
    }

    // MARK: - Promise Resolution

    func resolve(requestId: String, data: [String: Any]? = nil) {
        let response: [String: Any] = [
            "requestId": requestId,
            "success": true,
            "data": data as Any
        ]

        sendResponse(response)
    }

    func reject(requestId: String, error: BridgeError) {
        let response: [String: Any] = [
            "requestId": requestId,
            "success": false,
            "error": [
                "code": error.code,
                "message": error.message
            ]
        ]

        sendResponse(response)
    }

    private func sendResponse(_ response: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: response),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = "window.DallYeoBridge._handleResponse(\(jsonString))"
        webView?.evaluateJavaScript(js)
    }

    // MARK: - Native → Web Events

    func emit(_ event: String, payload: [String: Any?]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = "window.DallYeoBridge._emit('\(event)', \(jsonString))"
        webView?.evaluateJavaScript(js)
    }
}
