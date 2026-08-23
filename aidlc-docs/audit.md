# AIDLC 감사 추적

## 2026-06-16 11:05 — 사용자 요청

> Figma 디자인을 참고해서 V03 지도뷰 구현/수정
> URL: https://www.figma.com/design/rOWOGmdzTz81lhFOumuvnJ/%EB%8B%AC%EC%97%AC?node-id=267-588&m=dev

### 분석 결과 (Figma V03 프레임 직접 확인)

V03 관련 프레임: V03_지도부1, V03_지도부2, V03_지도부3

**현재 코드 대비 차이점:**

1. 세그먼트 탭 색상 반전
   - Figma: 선택됨=흰색 배경, 미선택=회색(systemGray6) 배경
   - 현재 코드: 선택됨=systemGray6(회색), 미선택=투명
   - 파일: MapBottomSheetView.swift

2. 카드 이미지 비율
   - Figma: 177px × 160px (약 1.1:1)
   - 현재: aspectRatio(1) 정사각형
   - 파일: PlaceCardView.swift

### 코드 생성 계획

→ aidlc-docs/construction/plans/v03-map-view-code-generation-plan.md 참조

---

## 2026-08-09 — 사용자 요청

> 지금 feat/map-markers 머지하고 V08부터 갈까? (V08은 BE polyline만 확인되면 T MAP 없이 바로 됨)
> 머지하고 서버 확인해줘
> 푸시했어 V08 시작해
> 현재 로컬에서 피그마 앱 켜져있고
> https://www.figma.com/design/rOWOGmdzTz81lhFOumuvnJ/%EB%8B%AC%EC%97%AC?node-id=441-1208&m=dev
> 주소야 이거 보고확인해

### 선행 조치
- `feat/map-markers` → `main` fast-forward 머지 (마커 SVG 5종 + MapMarker.swift + KakaoMapView 개편)
- `origin/main` 푸시 완료 (사용자 직접 실행, 10커밋)

### BE 서버 실측 (https://dallyeo.cloud, 인증 불요)
- `GET /courses` 200 — 코스 10개
- `GET /courses/{id}` 200 — 10/10 전부 polyline 보유
  - `polyline.count == cumulativeMeters.count` 10/10 일치
  - `cumulativeMeters.last == totalMeters` 10/10 일치
  - `waypointAnchors` 오름차순 / index 0 시작 / 마지막 index == polyline.count-1 → 10/10 정상
- 필터는 코드값만: `region=GUNSAN|JEONJU`, `distance=SHORT` 등. 한글(`region=군산`)은 400
- `GET /places/nearby?lat=&lng=&radius=` 200 — radius 동작 확인, **결과 30건 하드캡(거리순)**, `limit`/`size` 파라미터 무시
- 유효 category: `TOUR` `CULTURE` `FESTIVAL` `SHOPPING` `CAFE` `RESTAURANT` `STAY`
  무효(400): `ATTRACTION` `CONVENIENCE` `LEISURE` `LODGING` `FOOD` `STORE` `TOILET`
- `GET /places/along-route` **404 — 미구현**

### 결정 사항
- V08 경로선은 BE `CourseDetail.polyline`으로 렌더 (T MAP 불필요) — 확정
- 편의시설 마커는 BE 데이터 소스 부재 → MVP1에서 제외, 관광지/음식점만 표시 (사용자 승인)

### 회의 결과 반영
- V09 방향(턴바이턴) 안내 MVP 제외 → V09 범위 축소
- 경로탐색 옵션 V07 추가 → 디자인 확정 대기 (신규 작업)
- 남원/익산 보류 → `/regions`가 GUNSAN/JEONJU 2개뿐이라 코드 조치 불요
- 로그인은 웹 담당으로 확인됨 (단 WebView OAuth 금지 제약과 충돌 소지 → 팀 확인 필요)

### Figma HiFi 확보
- Figma 데스크톱 Dev Mode MCP 서버(127.0.0.1:3845) 경유로 노드 직접 조회
- V08 프레임: `565:523` V08_코스확인 모달 경유5 / 변형 `565:604`~`565:692`(경유4~없음) / `566:579`
- Dev Mode 라이선스 잠김으로 웹 Dev Mode는 사용 불가, MCP는 정상 동작

### 코드 생성 계획
→ `aidlc-docs/construction/plans/v08-course-confirm-code-generation-plan.md` 참조

---

## 2026-08-09 (2) — 사용자 요청

> V09 시작하기 전 푸시해야해?
> 나중에 푸시할게 머지하고 브랜치 따서 하자

### 선행 조치
- `feat/v08-hifi` → `main` (V08 코스확인 HiFi + BE 연동)
- `feat/v05-photo` → `main` (V05/V06 사진 영역 + 결과 없음 화면)
- 신규 브랜치 `feat/v09-hifi`. origin 푸시는 사용자가 나중에 일괄 수행 예정(7커밋 대기)

### Figma V09 확보 (Dev Mode MCP)
- `609:603` V09_진행중 / `609:746` V09_진행중_임박 (UI 동일, 지도 상태만 다름)
- `569:1142` 진행중알럿_1 (종료 확인) / `569:673` 진행중알럿_2 (일시정지)

### 코드 생성 계획
→ `aidlc-docs/construction/plans/v09-running-code-generation-plan.md` 참조

---

## 2026-08-23 — 사용자 요청

> 브릿지 문서 참고해서, 메인에서 '코스 생성' 버튼 누를때랑 추천코스 누를 때
> 각각 코스생성뷰, 추천코스뷰로 넘어가게 연결해줘

### 조사 결과 — 코드 변경 불요 (이미 연결됨)

`7c54fe8 feat: 웹 ↔ 네이티브 통합` 에서 배선 완료 상태.

| 단계 | 코스 생성 | 추천코스 |
|---|---|---|
| 웹 버튼 | `create-course-button` | `course-card-{id}` |
| 웹 호출 | `openCourseSearch()` | `openCourseConfirm(course)` |
| 네이티브 수신 | DallYeoBridge.swift:88 | DallYeoBridge.swift:91 |
| 화면 | V04 SearchView | V08 CourseConfirmView(courseId:) |

### 사용자 증상의 원인
- 실기기에서 "V04 검색뷰 + 뒤로가기" 임시 화면이 뜸
- → `44ea4bc` 시점의 `PlaceholderView(title: "V04 검색뷰")`. `7c54fe8`에서 제거됨
- → **기기에 설치된 앱이 구버전**. 재빌드/재설치로 해소

### 데이터 경로 검증 (2026-08-23 실호출)
- 웹 코스 목록: `GET https://dallyeo.cloud/courses?region=` (baseUrl 오버라이드로 MSW 우회)
- 네이티브 `APIConfig.baseURL` = `https://dallyeo.cloud` — 동일 서버
- `/regions` → GUNSAN, JEONJU 2개만
- `/courses?region=GUNSAN` → 6개 정상 (실 ID 예: `gunsan-jjamppong-run`)
- `/courses/{id}` → `polyline` 포함 정상
- → 웹이 넘긴 courseId를 네이티브 V08이 그대로 조회 가능. 불일치 없음

### 미해결 (별도 판단 필요)
- V08 진입 후 뒤로가기 시 웹 메인이 아니라 V03 지도뷰로 복귀
  (NavigationStack 루트가 MapView이기 때문). 웹 추천코스 진입 동선상 어색할 수 있음
- FE 브릿지 문서 §5 `startRun` — 배포 번들에 호출부 없음(웹 미구현) 확인

---

## 2026-08-23 — 인증 백엔드 실연동 (feat/auth)

### 요청
BE 인증 API 스펙(§5) 확정본 수령 — `POST /auth/login/{provider}`, `POST /auth/refresh`, `POST /auth/logout`.
현재 `StubAuthBackend`(목 세션)로만 배선된 인증 플로우를 실제 엔드포인트에 연결.

### 착수 시점 상태 (조사 결과)
- `AuthService`(기본 backend = `StubAuthBackend`) → 백엔드로 나가는 요청 **0건**.
  로그인 성공 시 웹뷰에 주입되는 토큰은 `stub.kakao.<UUID>` 문자열.
- `DallyeoAPIClient` 는 GET 전용, `DallyeoAPI` 에 auth 엔드포인트 없음.
- 카카오 SDK 연동(id_token/access token 수신)·Keychain 저장·브릿지 규격은 이미 완료.

### 스펙 대비 확인된 차이
1. 카카오는 **access token** 전송 (기존 "OIDC id_token 통일" 결정 폐기)
2. `user.id` 가 Int → `AppSession.userId`(String) 변환 필요
3. 로그아웃이 서버 호출(🔒) 필요 — 현재는 로컬 clear만
4. refresh 회전(rotation) 정책 → 자동로그인 조각2 구현 가능해짐
5. `onboardingRequired` 는 FE 브릿지 규격에 없는 필드

### 산출물
- `aidlc-docs/construction/plans/auth-remote-backend-code-generation-plan.md`
- 코드: `RemoteAuthBackend.swift`(신규), `AuthDTO.swift`(신규) + `DallyeoAPIClient`/`DallyeoAPI`/`AppSession`/`AuthBackend`/`AuthService`/`DallYeoBridge` 수정
- 빌드 성공.

### 실기기 1차 검증 결과 (2026-08-23)
| 제공자 | 결과 | 원인 | 조치 |
|---|---|---|---|
| 카카오 | 무응답(교환 요청 자체 없음) | `onOpenURL` 핸들러 부재 → SDK 가 인가 코드 수신 불가 | `DallyeoApp` 에 `AuthController.handleOpenUrl` 배선 (수정 완료) |
| 애플 | 401 UNAUTHORIZED | 서버측 Apple JWKS 검증 실패 (전송 형식은 정상) | 백엔드 client_id(aud) 대조 필요 — `JWTClaimsPeek` 진단 로그 추가 |

### 실기기 2차 검증 (2026-08-23, onOpenURL 수정 후)
- **카카오 로그인 성공** — 앱 버그 해소 확인. 로그아웃(`POST /auth/logout`)도 정상 호출.
- 애플 401 지속. 전송 클레임 `aud=cloud.dallyeo.app` / `iss=https://appleid.apple.com` / exp 유효 / nonce 없음 — 모두 정상.
- 카카오 성공으로 요청 형식·네트워크·라우팅 배제 → **서버 Apple 검증 분기 문제로 확정. 앱측 조치 불가, 백엔드 대기.**

- 서버 상태 확인(더미 토큰): `/auth/login/{kakao,apple}` → 401, `/auth/login/google` → 400. 스펙대로 동작 중.
- `APIErrorBody`(code/message) 형태 실제 응답과 일치 확인.
