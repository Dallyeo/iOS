# 네이티브 화면용 백엔드 API 요청 (V03~V08)

> 네이티브(iOS) 화면이 사용할 백엔드 엔드포인트 요청서입니다.
> 웹용 명세(`/regions`, `/courses`)와 동일한 규약을 따릅니다.
> **현재 LoFi 기준 초안이며, HiFi 확정 시 상세 필드가 추가될 수 있습니다.** (필드 추가는 비파괴적으로 — 기존 필드 유지)

---

## 배경 / 원칙

- TourAPI · T MAP 등 **공공 API는 앱에서 직접 호출하지 않습니다.**
  - 서비스키를 앱 번들에 넣으면 추출 가능 → 키 도용/쿼터 소진 위험
  - 따라서 **백엔드가 키를 쥐고 프록시**해서, 가공된 자체 엔드포인트로 내려주세요.
- 인증: 모든 요청 `Authorization: Bearer <token>` (네이티브가 OAuth 후 백엔드와 교환해 발급/보관)
- 인증 실패 시 `401` → 앱이 로그아웃 처리
- Content-Type: `application/json`
- 에러 응답: 웹과 동일 형식 `{ "code": "...", "message": "..." }`

---

## 공통 모델: `Place`

```json
{
  "id": "string",
  "name": "string",
  "category": "attraction | restaurant | convenience | toilet | pharmacy",
  "latitude": 35.9745,
  "longitude": 126.7180,
  "address": "전북특별자치도 군산시 ...",   // nullable
  "thumbnailUrl": "https://...",            // nullable
}
```

> `category` 값 목록은 협의 필요 (편의시설 세분화 범위 확정).
> 거리(예: "1.2km")는 **앱에서 현재 위치 기준으로 계산**하므로 응답에 불필요.

---

## 엔드포인트

### 1. `GET /places/search?keyword={k}&regionCode={code}`
장소 검색 (V04 검색 / V05 검색결과)

- 응답 `200`: `Place[]`
- 결과 없으면 `[]`
- 원천: TourAPI 키워드 검색

### 2. `GET /places/{id}`
장소 상세 (V05 카드 탭 / V06 위치정보)

- 응답 `200`: `Place` + 상세 필드
  ```json
  {
    "id": "...", "name": "신시 전망대", "category": "attraction",
    "latitude": 0, "longitude": 0,
    "address": "전북 군산시 초록동 5-123",
    "businessHours": "00:00-00:00",   // 영업 시작-종료 (Figma V06)
    "imageUrl": "https://..."          // 대표 이미지 1장 (Figma V06)
  }
  ```
- 에러 `404`: 장소 없음
- 원천: TourAPI detailCommon / detailIntro
- *HiFi 시 추가 가능성: 이미지 여러 장, 전화번호, 요일별 영업시간, 태그 등*

### 3. `GET /places/nearby?lat={lat}&lng={lng}&type={attraction|restaurant}`
현재 위치 주변 추천 관광지 / 음식점 (V03 지도뷰)

- 응답 `200`: `Place[]`
- 원천: TourAPI locationBasedList

### 4. `POST /routes/pedestrian`
보행자 경로 + 총 거리 (V07 경로수정)

- 요청:
  ```json
  { "points": [ { "lat": 35.97, "lng": 126.71 }, ... ] }
  ```
  (출발 → 경유… → 도착 순서)
- 응답 `200`:
  ```json
  { "polyline": [ { "lat": 35.97, "lng": 126.71 }, ... ], "distanceKm": 4.2 }
  ```
- 원천: T MAP 보행자 경로
- 비고: 앱은 받은 `polyline`을 카카오맵에 선으로 렌더링

### 5. `POST /places/along-route`
코스 경로 1km 이내 편의시설 / 관광지 (V08 코스확인)

- 요청:
  ```json
  { "polyline": [ { "lat": 0, "lng": 0 }, ... ], "radius": 1000, "types": ["attraction","restaurant","toilet","pharmacy"] }
  ```
- 응답 `200`: `Place[]`
- "경로 1km 이내" 필터는 **백엔드에서** 처리 (앱이 polyline 전달)
- 원천: TourAPI + 공공데이터(화장실/약국 등)

---

## 협의 필요 사항

- [ ] `category` 값 목록 확정 (편의시설 세분화 범위)
- [ ] `polyline` 형식: `[{lat,lng}]` vs encoded polyline 문자열
- [ ] 장소 상세 필드 범위 (HiFi 확정 후 보강)
- [ ] 준비된 엔드포인트 / 미준비 구분 (미준비분은 앱이 더미 데이터로 대체)
- [ ] 토큰 발급·교환 엔드포인트(`POST /auth/oauth/{provider}`)는 네이티브 ↔ 백엔드 별도 협의

---

## 화면 ↔ 엔드포인트 매핑

| 화면 | 사용 엔드포인트 |
|---|---|
| V03 지도뷰 | `GET /places/nearby` |
| V04 검색 / V05 검색결과 | `GET /places/search` |
| V05 카드 / V06 위치정보 | `GET /places/{id}` |
| V07 경로수정 | `POST /routes/pedestrian` |
| V08 코스확인 | `POST /places/along-route` |
