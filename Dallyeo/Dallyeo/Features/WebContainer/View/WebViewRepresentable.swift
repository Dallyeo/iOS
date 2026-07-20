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

    /// FE 배포본(웹뷰 V01/V02/V10~V14). 로컬 번들 대신 원격 URL 로드.
    static let webAppURL = URL(string: "https://dallyeo.vercel.app")!

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // 브릿지 메시지 핸들러 등록 (FE 명세: window.webkit.messageHandlers.dallyeo)
        contentController.add(bridge, name: "dallyeo")

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

        // 웹앱 로드 (FE 원격 배포본)
        loadWebApp(webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Safe Area CSS 변수 주입
        injectSafeAreaCSS(to: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Load Web App (원격)

    private func loadWebApp(_ webView: WKWebView) {
        webView.load(URLRequest(url: Self.webAppURL))
    }

    // MARK: - Load Local HTML (번들 폴백 — 현재 미사용, 오프라인/개발용 보존)

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

            <button class="btn" onclick="testOpenCourseSearch()">코스 검색 열기 (V04, 단방향)</button>
            <button class="btn" onclick="testGetLocationPermission()">위치 권한 확인</button>
            <button class="btn" onclick="testRequestLocationPermission()">위치 권한 요청</button>
            <button class="btn" onclick="testGetCurrentSession()">현재 세션 조회</button>
            <button class="btn" onclick="testLogout()">로그아웃</button>

            <div id="log">로그가 여기에 표시됩니다...</div>

            <script>
                function log(msg) {
                    const el = document.getElementById('log');
                    el.textContent = new Date().toLocaleTimeString() + ' ' + msg + '\\n' + el.textContent;
                }

                async function testOpenCourseSearch() {
                    log('openCourseSearch 호출 (단방향)...');
                    window.DallYeoBridge.send('openCourseSearch');
                    log('전송 완료');
                }

                async function testGetLocationPermission() {
                    log('getPermissionStatus 호출...');
                    try {
                        const result = await window.DallYeoBridge.call('getPermissionStatus', { type: 'location' });
                        log('결과: ' + JSON.stringify(result));
                    } catch(e) { log('에러: ' + JSON.stringify(e)); }
                }

                async function testRequestLocationPermission() {
                    log('requestPermission 호출...');
                    try {
                        const result = await window.DallYeoBridge.call('requestPermission', { type: 'location' });
                        log('결과: ' + JSON.stringify(result));
                    } catch(e) { log('에러: ' + JSON.stringify(e)); }
                }

                async function testGetCurrentSession() {
                    log('getCurrentSession 호출...');
                    try {
                        const result = await window.DallYeoBridge.call('getCurrentSession');
                        log('결과: ' + JSON.stringify(result));
                    } catch(e) { log('에러: ' + JSON.stringify(e)); }
                }

                async function testLogout() {
                    log('logout 호출...');
                    try {
                        await window.DallYeoBridge.call('logout');
                        log('로그아웃 완료');
                    } catch(e) { log('에러: ' + JSON.stringify(e)); }
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

    // FE 명세 기준 브릿지 주입 스크립트
    // - window.DallYeoBridge.postMessage(jsonString) 으로 웹에서 호출
    // - 응답: window.__dallyeoBridgeResolve({ id, ok, data/error })
    // - 이벤트: window.__dallyeoBridgeEmit({ event, payload })
    private static let bridgeInitScript = """
    (function() {
        var _pending = {};
        var _listeners = {};
        var _seq = 0;

        // 네이티브 → 웹: Promise resolve
        window.__dallyeoBridgeResolve = function(msg) {
            var p = _pending[msg.id];
            if (!p) return;
            delete _pending[msg.id];
            if (msg.ok) { p.resolve(msg.data); }
            else        { p.reject(msg.error); }
        };

        // 네이티브 → 웹: 이벤트
        window.__dallyeoBridgeEmit = function(msg) {
            var fns = _listeners[msg.event] || [];
            fns.forEach(function(fn) { fn(msg.payload); });
        };

        // 웹 → 네이티브: 메시지 전송
        window.DallYeoBridge = {
            postMessage: function(jsonString) {
                window.webkit.messageHandlers.dallyeo.postMessage(jsonString);
            },

            // 편의 메서드 (응답 필요)
            call: function(method, params) {
                return new Promise(function(resolve, reject) {
                    var id = 'req_' + (++_seq);
                    _pending[id] = { resolve: resolve, reject: reject };
                    setTimeout(function() {
                        if (_pending[id]) {
                            delete _pending[id];
                            reject({ kind: 'timeout' });
                        }
                    }, 10000);
                    window.DallYeoBridge.postMessage(
                        JSON.stringify({ id: id, method: method, params: params || {} })
                    );
                });
            },

            // 편의 메서드 (단방향)
            send: function(method, params) {
                window.DallYeoBridge.postMessage(
                    JSON.stringify({ method: method, params: params || {} })
                );
            },

            on: function(event, callback) {
                if (!_listeners[event]) { _listeners[event] = []; }
                _listeners[event].push(callback);
            },

            off: function(event, callback) {
                var fns = _listeners[event];
                if (!fns) return;
                var i = fns.indexOf(callback);
                if (i > -1) { fns.splice(i, 1); }
            }
        };
    })();
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
            // 링크 클릭 중 "외부 호스트"만 Safari로 열기.
            // 웹앱 자체 호스트(FE SPA 라우팅)는 웹뷰 안에서 처리.
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               let host = url.host,
               host != WebViewRepresentable.webAppURL.host {
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
