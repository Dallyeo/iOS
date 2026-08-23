# 코드 생성 계획 — 인증 백엔드 실연동 (RemoteAuthBackend)

브랜치: `feat/auth` · 작성: 2026-08-23 · 상태: **코드 생성 완료 (실기기 검증 대기)**

## 배경

`StubAuthBackend`(목 세션 발급)로만 배선되어 있던 인증 플로우에 BE 실제 엔드포인트를 연결한다.
BE 스펙 확정본(§5 인증) 수령: `POST /auth/login/{provider}` · `POST /auth/refresh` · `POST /auth/logout`.

## 스펙 ↔ 기존 결정 차이 (반영 필요)

| 항목 | 기존 코드/결정 | BE 스펙 | 조치 |
|---|---|---|---|
| 카카오 전송 토큰 | OIDC `id_token` 으로 통일(2026-07-20 결정) | `authorizationCode` = **카카오 access token** | id_token 결정 폐기, `credential.accessToken` 전송 |
| 애플 전송 토큰 | `id_token`(identityToken) | `authorizationCode` = identity token(JWT) | 변경 없음 (`credential.idToken`) |
| userId 타입 | `String` | `user.id` = **Int** | `String(user.id)` 로 변환 |
| 로그아웃 | 로컬 Keychain clear only | `POST /auth/logout` 🔒 (204) | 서버 호출 추가 (실패해도 로컬은 clear) |
| 토큰 갱신 | 미구현 (만료 시 세션 삭제) | `POST /auth/refresh` (회전) | 만료 시 자동 갱신 후 실패 시에만 삭제 |
| 필드 `onboardingRequired` | FE 브릿지 규격에 없음 | 로그인 응답에 포함 | resolve.data 최상위에 함께 전달(추가 필드, 하위호환) — 사용자 승인 |

## 파일 단위 계획

### 1. 네트워킹 (POST 지원)
- [x] `Shared/Networking/DallyeoAPIClient.swift` — 수정
  - `post<Body: Encodable, T: Decodable>(_ path:body:bearer:as:)` 추가 (APIResponse 언래핑 동일)
  - `postNoContent(_ path:body:bearer:)` 추가 — 204/빈 바디 허용 (로그아웃용)
  - 공통 요청 빌더 추출(`makeRequest`), `Authorization: Bearer` 헤더 지원
  - `APIClientError`에 `.unauthorized` 추가 (401 전용 — 세션 파기 분기용)

### 2. DTO
- [x] `Shared/Networking/DTO/AuthDTO.swift` — 신규
  - `AuthLoginRequest { authorizationCode }`
  - `AuthRefreshRequest { refreshToken }`
  - `AuthTokenDTO { accessToken, refreshToken, tokenType, accessTokenExpiresIn, onboardingRequired?, user? }`
    (refresh 응답엔 `onboardingRequired`/`user` 없음 → optional)
  - `AuthUserDTO { id: Int, nickname?, gender?, height?, weight?, profileImageUrl? }`

### 3. 엔드포인트 정의
- [x] `Shared/Networking/DallyeoAPI.swift` — 수정
  - `login(provider:authorizationCode:)` → `POST /auth/login/{provider}`
  - `refresh(refreshToken:)` → `POST /auth/refresh`
  - `logout(accessToken:)` → `POST /auth/logout` (204)

### 4. 세션 모델
- [x] `Domain/Models/AppSession.swift` — 수정
  - `onboardingRequired: Bool?`, `profileImageUrl: String?` 추가 (모두 optional → 기존 Keychain 저장분 디코딩 호환)

### 5. 인증 백엔드 실구현
- [x] `Features/Auth/AuthBackend.swift` — 수정
  - 프로토콜에 `refresh(refreshToken:)`, `logout(accessToken:)` 추가
  - `StubAuthBackend`는 no-op 구현 유지 (오프라인 플로우 검증용)
- [x] `Features/Auth/RemoteAuthBackend.swift` — 신규
  - provider별 전송 토큰 선택: kakao=`accessToken`, apple=`idToken` (없으면 `AuthError.failed("missing_token")`)
  - `AuthTokenDTO` → `AppSession` 매핑 (`expiresAt = now + accessTokenExpiresIn`)
  - 401 → `AuthError.failed("unauthorized")`, 그 외 → 메시지 매핑

### 6. 오케스트레이션
- [x] `Features/Auth/AuthService.swift` — 수정
  - 기본 backend를 `RemoteAuthBackend()` 로 교체
  - `var currentSession` → `func currentSession() async -> AppSession?`
    (만료 시 refreshToken으로 갱신 → 성공하면 저장·반환 / 실패하면 clear·nil)
  - `logout()` → `async` : 서버 무효화 호출 후 로컬 clear (서버 실패해도 clear 진행)

### 7. 브릿지
- [x] `Features/WebContainer/Bridge/DallYeoBridge.swift` — 수정
  - `handleGetCurrentSession` → `async` (자동 갱신 반영)
  - `sessionData`에 `onboardingRequired` 포함
  - 갱신 실패로 세션이 사라지면 `sessionChanged(unauthenticated)` emit

### 8. 검증
- [x] 빌드 — `xcodebuild ... build` BUILD SUCCEEDED (신규/수정 파일 경고 0)
- [x] 실기기 카카오 로그인 → 성공 (1차 실패 원인 `onOpenURL` 부재, 수정 후 정상)
- [ ] 앱 재실행 자동로그인(getCurrentSession) 확인
- [x] 로그아웃 — `POST /auth/logout` 호출 확인
- [ ] 애플 로그인 — **백엔드 차단 중** (401, 서버 Apple client_id 확인 필요)

## 구현 중 추가된 사항

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 설정 때문에 값 타입들이 MainActor로 추론됨.
  `AppSession`, `AuthBackend`/`StubAuthBackend`/`RemoteAuthBackend`, Auth DTO 4종에 `nonisolated` 명시
  (Swift 6 언어 모드에서 에러가 될 경고 제거).
- `getCurrentSession` 이 nil을 반환할 때(갱신 실패로 세션 파기 포함) `sessionChanged(unauthenticated)` 도 함께 emit.

## 비고
- `nonce` 는 계속 보류 (BE 스펙에 nonce 항목 없음).
- `gender/height/weight` 는 온보딩(웹) 담당이라 세션에 저장하지 않음.
