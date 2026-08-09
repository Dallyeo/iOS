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
