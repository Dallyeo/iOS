# `runCompleted` 브릿지 명세 (iOS → 웹)

러닝을 끝내면 iOS가 보내는 이벤트. 웹 결과화면(V10)이 이 값으로 그린다.

```js
window.DallYeoBridge.on('runCompleted', (data) => { ... })
```

---

## 1. 웹에서 해야 할 일

### 1-1. `saveResult` 호출 제거 ⚠️

**러닝 기록 저장은 앱이 한다.** 웹의 `saveResult`는 지워야 한다.

```js
// 지금 코드 — 제거 대상
async saveResult(e) { const t = await Ct.post("/runs", _9(e)); return { recordId: String(t.id) } }
```

이유:

- `POST /runs`가 **`multipart/form-data`로 바뀌었다.** JSON으로 보내면 서버가 500을 준다.
- **코스 이미지가 필수 파트**다. 누락하면 400. 그 이미지는 카카오맵 뷰 캡처라 iOS에서만 만들 수 있다.
- 현재 웹이 보내는 `polyline` / `averagePaceSeconds`는 스펙에서 **사라진 필드**다. 서버는 출발·도착 좌표 2점만 저장하고, 경로 그림은 앱이 올린 캡처가 대신한다.

지금은 웹의 저장이 실패해서 `"기록 저장에 실패했어요"` 토스트만 뜨지만, **웹이 스펙에 맞춰 성공하게 되면 기록이 두 개씩 쌓인다.**

### 1-2. 안내 문구는 웹이 그린다

저장 실패 안내를 네이티브 토스트로 띄우면 웹 결과화면과 두 겹으로 겹쳐서, 네이티브 토스트는 제거했다. `saved` / `saveFailReason`으로 분기해 웹에서 띄워 달라.

### 1-3. (선택) `recordId`로 조회 전환

`recordId`를 넘기므로 `GET /runs/{id}`로 다시 불러와도 된다. 브릿지로 받은 값은 웹뷰가 리로드되면 날아가지만 `recordId`는 남는다.

**단, 조회로는 못 가져오는 값이 두 개 있다:**

| 값 | `GET /runs/{id}`에 있나 |
|---|---|
| `newAchievements` | ❌ 필드 자체가 없음 — **저장 응답 전용** |
| `completionRate` | ❌ 서버가 계산하지 않음 |

`newAchievements`는 **처음 달성했을 때 딱 한 번만** 내려온다(재달성은 항상 `[]`, 실측 확인). 이 두 개만은 브릿지 값을 써야 한다.

---

## 2. 페이로드

### 2.1 항상 오는 값

| 키 | 타입 | 설명 |
|---|---|---|
| `runId` | `string` | 이벤트마다 새로 만드는 UUID. 서버 기록 id가 **아니다** |
| `distanceKm` | `number` | 이동 거리(km) |
| `durationSec` | `number` | 진행 시간(초) |
| `avgPaceSecPerKm` | `number` | 평균 페이스(초/km). 0이면 미측정 |
| `calories` | `number` | 소모 칼로리(추정) |
| `completionRate` | `number` | 완주율 `0.0`~`1.0`. **앱만 아는 값** |
| `routePolyline` | `{lat, lng}[]` | 실제 이동 궤적 전체 |
| `startedAt` | `string` | ISO8601(UTC). 카운트다운 끝나고 실제 시작한 시각 |
| `completedAt` | `string` | ISO8601(UTC). 종료 시각 |
| `saved` | `boolean` | 백엔드 저장 성공 여부 |

### 2.2 조건부로 오는 값

**키 자체가 빠진다.** `null` 비교가 아니라 존재 여부로 판단할 것.

| 키 | 타입 | 언제 오나 |
|---|---|---|
| `courseId` | `string` | 추천 코스를 달렸을 때. 직접 만든 경로면 없음 |
| `startPlaceName` | `string` | 코스에 출발지 이름이 있을 때 |
| `endPlaceName` | `string` | 코스에 도착지 이름이 있을 때 |
| `startLocation` | `{lat, lng}` | 좌표가 1개 이상일 때 |
| `endLocation` | `{lat, lng}` | 좌표가 1개 이상일 때 |
| `recordId` | `number` | **저장 성공 시만.** `GET /runs/{id}` 키 |
| `imageUrl` | `string` | 저장 성공 + 이미지 업로드 성공 시. **절대 URL** |
| `staticMapImageUrl` | `string` | `imageUrl`과 같은 값 (아래 참고) |
| `newAchievements` | `object[]` | 저장 성공 시만. 이번에 **처음 딴** 업적 |
| `saveFailReason` | `string` | 저장 실패 시만 |

### 2.3 `newAchievements` 항목

```ts
{
  code: string            // 도장 매칭 키 (예: "GUNSAN_SEONYUDO")
  name: string
  category?: string       // "GUNSAN" | "JEONJU" | "COMMON"
  sortOrder?: number
  description?: string
  iconOnUrl?: string      // 획득(컬러). 절대 URL
  iconOffUrl?: string     // 미획득(흑백). 절대 URL
  unlocked?: boolean
  unlockedAt?: string
}
```

- 한 번에 **여러 개** 올 수 있다(실측 최대 7개). 길이 1로 가정하지 말 것.

### 2.4 `saveFailReason`

| 값 | 의미 | 제안 문구 |
|---|---|---|
| `notSignedIn` | 게스트. `POST /runs`가 토큰을 요구 | "로그인하면 러닝 기록이 저장돼요" |
| `notEnoughData` | 거리·시간이 0이라 아예 안 보냄 | (아래 "미해결" 참고) |
| `noSnapshot` | 지도 캡처 실패. 이미지가 필수라 시도 불가 | "기록 이미지를 만들지 못했어요" |
| `network` | 요청 실패(서버 오류 포함) | "잠시 후 다시 시도해 주세요" |

---

## 3. 이미지 URL 주의사항

**이름이 두 개다.** 웹은 `staticMapImageUrl`로 읽는데 서버가 주는 필드명은 `imageUrl`이라, 어느 쪽으로 정리되든 화면이 뜨도록 **앱이 두 이름 다 싣는다.** 정리는 편한 쪽으로 하면 된다.

**절대 URL로 보낸다.** 서버는 `/uploads/runs/….jpg` 같은 서버 기준 경로를 주는데, 웹은 다른 도메인에서 뜨므로 그대로 쓰면 웹 도메인 기준으로 풀려 404가 난다. 그래서 앱이 앞에 API base URL을 붙여서 넘긴다. 도장 아이콘(`iconOnUrl` / `iconOffUrl`)도 동일.

```
https://dallyeo.cloud/uploads/runs/232616e6-b222-4371-bcfb-293b387f891e.jpg
```

---

## 4. 예시

```json
{
  "runId": "3F2A6C1E-...",
  "courseId": "gunsan-seonyudo-beach-run",
  "distanceKm": 0.62,
  "durationSec": 103,
  "avgPaceSecPerKm": 166,
  "calories": 21,
  "completionRate": 0.12,
  "routePolyline": [{ "lat": 35.8077, "lng": 126.4107 }, "..."],
  "startedAt": "2026-09-13T15:27:20Z",
  "completedAt": "2026-09-13T15:29:03Z",
  "startPlaceName": "옥돌해변",
  "endPlaceName": "몽돌해변",
  "startLocation": { "lat": 35.8077, "lng": 126.4107 },
  "endLocation": { "lat": 35.8181, "lng": 126.4126 },
  "saved": true,
  "recordId": 9,
  "imageUrl": "https://dallyeo.cloud/uploads/runs/8ebdbcbd-....jpg",
  "staticMapImageUrl": "https://dallyeo.cloud/uploads/runs/8ebdbcbd-....jpg",
  "newAchievements": []
}
```

---

## 5. 아직 정해지지 않은 것

**시작하자마자 끝냈을 때(거리 0).** 지금은 결과화면이 `0.00km` + 회색 지도로 뜬다. 저장은 서버가 `distanceMeters ≤ 0`을 400으로 막아서 앱이 아예 보내지 않는다(`saveFailReason: "notEnoughData"`).

iOS 쪽 제안은 **이 경우 `runCompleted` 대신 `runCancelled`를 보내서 결과화면을 아예 띄우지 않는 것**이다. 사용자가 방금 "러닝을 그만두시겠어요? → 확인"을 누른 것이고, 저장할 것도 보여줄 지도도 없기 때문이다. Figma에는 이 상태가 정의돼 있지 않아 기획 확인이 필요하다.

참고로 웹 번들에 `runCancelled` 핸들러가 없어서, 지금 이벤트를 보내면 웹은 아무 반응을 안 한다 — 결과화면으로 안 넘어가고 원래 화면에 머문다. 그게 의도한 동작이라면 웹 작업은 필요 없다.
