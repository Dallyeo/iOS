//
//  WebViewRepresentable.swift
//  Dallyeo
//
//  WKWebView를 SwiftUI에서 사용하기 위한 래퍼
//

import SwiftUI
import WebKit

struct WebViewRepresentable: UIViewRepresentable {
    let bridge: DallYeoBridge

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // 브릿지 메시지 핸들러 등록
        contentController.add(bridge, name: "DallYeoBridge")

        // 브릿지 초기화 스크립트 주입
        let bridgeScript = WKUserScript(
            source: Self.bridgeInitScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bridgeScript)

        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // 스와이프 뒤로가기 비활성화 (네이티브에서 처리)
        webView.allowsBackForwardNavigationGestures = false

        // 브릿지에 웹뷰 연결
        Task { @MainActor in
            bridge.webView = webView
        }

        // 로컬 HTML 로드
        loadLocalHTML(webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Safe Area CSS 변수 주입
        injectSafeAreaCSS(to: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Load Local HTML

    private func loadLocalHTML(_ webView: WKWebView) {
        guard let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "Resources/WebApp"
        ) else {
            // 번들에 없으면 개발용 더미 로드
            loadDevelopmentHTML(webView)
            return
        }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func loadDevelopmentHTML(_ webView: WKWebView) {
        // 개발 중 더미 HTML
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
            <title>달여 - 브릿지 테스트</title>
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    padding: calc(var(--sat, 0px) + 20px) 20px calc(var(--sab, 0px) + 20px);
                    background: #f5f5f5;
                }
                h1 { font-size: 24px; margin-bottom: 20px; }
                .btn {
                    display: block;
                    width: 100%;
                    padding: 16px;
                    margin-bottom: 12px;
                    border: none;
                    border-radius: 12px;
                    background: #007AFF;
                    color: white;
                    font-size: 16px;
                    cursor: pointer;
                }
                .btn:active { opacity: 0.8; }
                #log {
                    margin-top: 20px;
                    padding: 16px;
                    background: white;
                    border-radius: 12px;
                    font-size: 14px;
                    white-space: pre-wrap;
                    max-height: 300px;
                    overflow-y: auto;
                }
            </style>
        </head>
        <body>
            <h1>🏃 달여 브릿지 테스트</h1>

            <button class="btn" onclick="testOpenCourseSearch()">코스 검색 열기 (V04)</button>
            <button class="btn" onclick="testGetLocationPermission()">위치 권한 확인</button>
            <button class="btn" onclick="testRequestLocationPermission()">위치 권한 요청</button>
            <button class="btn" onclick="testOpenSettings()">설정 열기</button>
            <button class="btn" onclick="testShare()">공유하기</button>

            <div id="log">로그가 여기에 표시됩니다...</div>

            <script>
                function log(msg) {
                    const el = document.getElementById('log');
                    el.textContent = new Date().toLocaleTimeString() + ' ' + msg + '\\n' + el.textContent;
                }

                async function testOpenCourseSearch() {
                    log('openCourseSearch 호출...');
                    const result = await window.DallYeoBridge.call('openCourseSearch');
                    log('결과: ' + JSON.stringify(result));
                }

                async function testGetLocationPermission() {
                    log('getPermissionStatus 호출...');
                    const result = await window.DallYeoBridge.call('getPermissionStatus', { type: 'location' });
                    log('결과: ' + JSON.stringify(result));
                }

                async function testRequestLocationPermission() {
                    log('requestPermission 호출...');
                    const result = await window.DallYeoBridge.call('requestPermission', { type: 'location' });
                    log('결과: ' + JSON.stringify(result));
                }

                async function testOpenSettings() {
                    log('openOSSettings 호출...');
                    const result = await window.DallYeoBridge.call('openOSSettings');
                    log('결과: ' + JSON.stringify(result));
                }

                async function testShare() {
                    log('share 호출...');
                    const result = await window.DallYeoBridge.call('share', {
                        text: '달여로 러닝 코스를 공유합니다!',
                        url: 'https://dallyeo.com'
                    });
                    log('결과: ' + JSON.stringify(result));
                }

                // 이벤트 리스너
                window.DallYeoBridge.on('sessionChanged', (data) => {
                    log('이벤트 수신 - sessionChanged: ' + JSON.stringify(data));
                });
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - Safe Area Injection

    private func injectSafeAreaCSS(to webView: WKWebView) {
        let insets = webView.safeAreaInsets
        let js = """
            document.documentElement.style.setProperty('--sat', '\(insets.top)px');
            document.documentElement.style.setProperty('--sab', '\(insets.bottom)px');
            document.documentElement.style.setProperty('--sal', '\(insets.left)px');
            document.documentElement.style.setProperty('--sar', '\(insets.right)px');
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Bridge Init Script

    private static let bridgeInitScript = """
    window.DallYeoBridge = {
        _pendingRequests: {},
        _eventListeners: {},
        _requestId: 0,

        call: function(action, payload) {
            return new Promise((resolve, reject) => {
                const requestId = 'req_' + (++this._requestId);
                this._pendingRequests[requestId] = { resolve, reject };

                window.webkit.messageHandlers.DallYeoBridge.postMessage({
                    action: action,
                    requestId: requestId,
                    payload: payload || {}
                });
            });
        },

        _handleResponse: function(response) {
            const pending = this._pendingRequests[response.requestId];
            if (pending) {
                delete this._pendingRequests[response.requestId];
                if (response.success) {
                    pending.resolve(response.data);
                } else {
                    pending.reject(response.error);
                }
            }
        },

        _emit: function(event, data) {
            const listeners = this._eventListeners[event] || [];
            listeners.forEach(fn => fn(data));
        },

        on: function(event, callback) {
            if (!this._eventListeners[event]) {
                this._eventListeners[event] = [];
            }
            this._eventListeners[event].push(callback);
        },

        off: function(event, callback) {
            const listeners = this._eventListeners[event];
            if (listeners) {
                const index = listeners.indexOf(callback);
                if (index > -1) {
                    listeners.splice(index, 1);
                }
            }
        }
    };
    """
}

// MARK: - Coordinator

extension WebViewRepresentable {
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 페이지 로드 완료 후 Safe Area 재주입
            let insets = webView.safeAreaInsets
            let js = """
                document.documentElement.style.setProperty('--sat', '\(insets.top)px');
                document.documentElement.style.setProperty('--sab', '\(insets.bottom)px');
                document.documentElement.style.setProperty('--sal', '\(insets.left)px');
                document.documentElement.style.setProperty('--sar', '\(insets.right)px');
            """
            webView.evaluateJavaScript(js)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // 외부 링크는 Safari에서 열기
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               url.host != nil && !url.isFileURL {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        // MARK: - WKUIDelegate

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            // JavaScript alert 처리
            completionHandler()
        }
    }
}
