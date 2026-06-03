# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Status

This is the iOS repository for **달여(Dallyeo)**. Greenfield project — Swift/SwiftUI 네이티브 앱.

Do not invent build/test/lint commands without confirming with the user first.

## Governing Workflow: AWS AIDLC

All software-development requests in this repository are governed by the **AWS AI-Driven Development Lifecycle (AIDLC) workflow**. This OVERRIDES any built-in default workflow.

**Before doing any development work**, load and follow:

- Core workflow: `aidlc-rules/aws-aidlc-rules/core-workflow.md`

---

# Project Context — 달여(DallYeo) iOS

> 이 섹션은 무엇을 만드는지와 기술 제약을 정의합니다. AIDLC 워크플로우와 함께 매 세션 적용됩니다.

## Output language (strict)
- 모든 산출물, 문서, 유저스토리, 계획, 질문, UI 텍스트, 코드 주석 → 한국어.
- 코드 식별자 (변수/함수/타입/파일명) → 영어.

## 서비스 소개
**달여(Dallyeo)** — 달리는 여행. 러닝 코스 위에 관광지와 미식을 얹은 런트립 플래너.
완주 후엔 주변 맛집까지 — 달리는 이유가 생기는 여행 앱.

## 앱 역할 분담

```
iOS (이 레포)
  └── 지도/위치/운동 등 네이티브 기능 담당 화면 (V03~V09)
  └── WKWebView 컨테이너로 웹뷰 화면 호스팅
  └── 브릿지 iOS 구현체
  └── 인증(OAuth) 전담

FE 레포 (DallYeo_FE)
  └── 웹뷰 화면 (V01, V02, V10~V14)
  └── 하단 탭바 (웹뷰 안에서 관리)
  └── 브릿지 인터페이스 소스 오브 트루스
```

## 담당 화면 (V03~V09)

| 화면 ID | 화면명 | 우선순위 | 핵심 기능 |
|---------|--------|----------|-----------|
| V03 | 지도뷰 | A | 카카오맵, 현재위치, 장소마커, 바텀시트 |
| V04 | 검색뷰 | A | 장소 검색, 유사검색어, 최근검색 |
| V05 | 검색결과뷰 | B | 지도+바텀시트, 장소 핀 표시 |
| V06 | 위치정보뷰 | B | 장소 상세, 출발지/경유지/도착지 설정 |
| V07 | 경로수정뷰 | B | 경유지 편집, T MAP 경로, 거리 표시 |
| V08 | 코스확인뷰 | C | 지도+경로+주변 편의시설, 러닝 시작 |
| V09 | 코스진행뷰 | C | 실시간 위치 추적, HealthKit, 일시정지/종료 |

## 기술 스택

```
Language    Swift 6
UI          SwiftUI (iOS 26+)
지도         카카오맵 iOS SDK (UIViewRepresentable 래핑)
경로         T MAP 보행자 경로 API (백엔드 프록시 경유)
위치         CoreLocation
운동/건강    HealthKit
웹뷰         WKWebView
아키텍처     MVVM
```

## iOS 설정

- **최소 버전**: iOS 26.0+
- **Liquid Glass 비활성화**: Info.plist에 `UIDesignRequiresCompatibility = YES`

## 폴더 구조

```
Dallyeo/
  App/                    # AppDelegate, SceneDelegate, 진입점, 설정
  Features/
    Map/                  # V03 지도뷰
      View/
      ViewModel/
      Model/
    Search/               # V04 검색뷰
    SearchResult/         # V05 검색결과뷰
    LocationInfo/         # V06 위치정보뷰
    RouteEdit/            # V07 경로수정뷰
    CourseConfirm/        # V08 코스확인뷰
    Running/              # V09 코스진행뷰
    WebContainer/         # WKWebView 컨테이너 + 브릿지
  Domain/                 # 공통 모델, 인터페이스
  Shared/                 # 공통 UI 컴포넌트, 유틸, 익스텐션
```

## Native ↔ Web Bridge

브릿지 인터페이스 소스 오브 트루스: FE 레포 CLAUDE.md.
iOS는 WKScriptMessageHandler 구현체만 담당.
브릿지 이름: `window.DallYeoBridge`

### Web → Native (iOS 구현)

```swift
// WKScriptMessageHandler로 수신, requestId로 Promise resolve
login(provider: "kakao"|"apple"|"google")   → AppSession
logout()                                     → void
openCourseSearch()                           → V04 진입
openCourseConfirm(course)                    → V08 진입
startRun(course)                             → V09 진입
getPermissionStatus(type: "location"|"notification") → PermissionStatus
requestPermission(type)                      → PermissionStatus
openOSSettings()                             → void
pickProfilePhoto()                           → String (이미지 URL)
share(payload)                               → void
openExternalUrl(url)                         → void
```

### Native → Web (iOS 이벤트 발송)

```swift
// webView.evaluateJavaScript로 발송
'runCompleted'     → RunResult
// RunResult: 경로 폴리라인 + 정적 지도 이미지 URL + 거리/시간/페이스/칼로리/완주율
'runCancelled'
'permissionChanged'
'sessionChanged'
```

### 브릿지 기본 구조

```swift
class DallYeoBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    weak var coordinator: AppCoordinator?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String,
              let requestId = body["requestId"] as? String else { return }

        switch action {
        case "login":               handleLogin(body, requestId)
        case "logout":              handleLogout(requestId)
        case "openCourseSearch":    coordinator?.openCourseSearch()
        case "openCourseConfirm":   handleOpenCourseConfirm(body)
        case "startRun":            handleStartRun(body)
        case "getPermissionStatus": handlePermissionStatus(body, requestId)
        case "requestPermission":   handleRequestPermission(body, requestId)
        case "openOSSettings":      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        case "pickProfilePhoto":    handlePickProfilePhoto(requestId)
        case "share":               handleShare(body)
        case "openExternalUrl":     handleOpenExternalUrl(body)
        default: break
        }
    }

    func emit(_ event: String, payload: String) {
        let js = "window.DallYeoBridge._emit('\(event)', \(payload))"
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js)
        }
    }
}
```

## 인증/세션 규칙

- **WebView 안에서 OAuth 절대 금지** (Google disallowed_useragent 차단).
- Kakao/Apple/Google 로그인 → 네이티브에서 처리 → 백엔드 세션 토큰 발급 → **Keychain 저장**.
- 웹뷰에 세션 토큰 주입 (Bearer 헤더용). 웹뷰는 localStorage에 저장 안 함.
- 로그인/로그아웃/만료 시 `sessionChanged` 이벤트 발송.

## 지도/경로 규칙

- 카카오맵 iOS SDK → `UIViewRepresentable`로 래핑하여 SwiftUI에서 사용.
- T MAP 보행자 경로 API → 백엔드 프록시 경유. 카카오맵 오버레이로 시각화.
- **V10, V12 지도 = 정적 이미지** (백엔드 제공 URL). 지도 SDK 사용 안 함. 확대/축소 없음.
- V03~V09 지도는 확대/축소 가능.
- 공공 API (TourAPI 등) 직접 호출 금지 → 백엔드 프록시 경유.

## 화면별 주요 비즈니스 로직

### V03 지도뷰
- 바텀시트 크기: 꽉참/중간/최소 3단계 고정 (`.presentationDetents`)
- 위치 권한 없음 시 권한 요청, GPS 실패 시 재시도 안내
- 바텀시트: 추천 관광지 / 추천 음식점 세그먼트 전환

### V04 검색뷰
- 타이핑 시 실시간 유사 검색어 표시
- 최근 검색 리스트 표시 및 재사용
- 무입력 상태에서 검색 실행 방지

### V05 검색결과뷰
- 검색된 장소들을 지도에 핀으로 표시
- 바텀시트 크기 자유롭게 조절 가능
- 이 뷰에서 검색된 단어는 모두 최근 검색 리스트에 추가

### V06 위치정보뷰
- 출발지/경유지/도착지 중 하나로 장소 설정
- 경유지/도착지 선택 시 출발지 자동 = 현재 위치
- 바텀시트 크기: 꽉참/중간/최소 3단계 고정

### V07 경로수정뷰
- 경유지 최대 3개, 최대 도달 시 + 버튼 비활성화
- 출발지/도착지 미설정 시 확인 버튼 비활성화
- 빈 경유지 칸은 경로 계산 시 무시
- 지점 변경 시 경로 및 총 거리(km) 실시간 재계산 및 말풍선 표시

### V08 코스확인뷰
- 직접 검색으로 만든 코스 이름 = '나만의 러닝 코스'
- 코스 근방 1km 편의시설/관광지 핀 표시
- 러닝 시작 버튼 → 카운트다운 3초 팝업 → V09 진입

### V09 코스진행뷰
- 경로 이탈 1km 초과 시 종료 확인 팝업
- 일시정지/재개/종료 기능
- 진행 정보 실시간 갱신: 시간, 페이스, 칼로리, 진행도 %
- 종료 또는 도착지 도달 시 V10으로 RunResult 전달 (브릿지 `runCompleted` 이벤트)

## HealthKit

- V09에서만 사용.
- 필요 권한: 걷기/달리기 거리, 활성 에너지, 심박수.
- `HKWorkoutSession` + `HKLiveWorkoutBuilder`로 운동 세션 관리.

## iOS 특이사항

- **좌측 스와이프 뒤로가기** 모든 화면에서 동작해야 함 (웹뷰에서 가로채기 금지).
- 바텀시트: `.presentationDetents` 사용.
- Safe Area 값을 웹뷰에 CSS 변수로 주입.

```swift
// Safe Area 웹뷰 주입
let insets = view.safeAreaInsets
let js = """
  document.documentElement.style.setProperty('--sat', '\(insets.top)px');
  document.documentElement.style.setProperty('--sab', '\(insets.bottom)px');
"""
webView.evaluateJavaScript(js)
```

## 웹뷰 로컬 번들

```swift
let url = Bundle.main.url(forResource: "index",
                           withExtension: "html",
                           subdirectory: "WebApp")!
webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
```

## 개발 우선순위

```
1순위 (MVP 1 - A)
  └── WKWebView 컨테이너 + 브릿지 기본 구조
  └── V03 지도뷰 (카카오맵, 현재위치, 바텀시트)
  └── V04 검색뷰

2순위 (MVP 1 - B)
  └── V05 검색결과뷰
  └── V06 위치정보뷰
  └── V07 경로수정뷰 (T MAP 연동)

3순위 (MVP 1 - C)
  └── V08 코스확인뷰
  └── V09 코스진행뷰 (HealthKit 포함)
```

## Hard Constraints

- 공공 API 직접 호출 금지 → 백엔드 프록시 경유.
- WebView 안에서 OAuth 핸들쉐이크 절대 금지.
- V10/V12 지도 = 정적 이미지, 지도 SDK 사용 안 함.
- 모든 민감 데이터 Keychain 저장.
- 좌측 스와이프 뒤로가기 모든 화면에서 동작.
