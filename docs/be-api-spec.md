# BE API 스펙 (레포 코드에서 추출)

출처: https://github.com/Dallyeo/BE `src/main/java/com/ppip/dallyeo/`
※ 코드 기준 추출. **base URL(도메인)은 승환에게 확인 필요.**

## 공통 응답 포맷 `ApiResponse<T>`
```json
// 성공
{ "success": true, "data": { /* T */ } }
// 성공(빈 데이터)
{ "success": true }
// 실패
{ "success": false, "error": { /* ApiError */ } }
```
- null 필드는 생략(NON_NULL). 파싱 시 `data`/`error` optional 처리.

## 엔드포인트 (전부 인증 불필요)

### 지역
- `GET /regions` → `ApiResponse<[RegionResponse]>`
  - `RegionResponse { code: String, name: String }` 예: `{"code":"GUNSAN","name":"군산"}`

### 장소 (place)
- `GET /places/search?keyword={필수}&region=&category=` → `ApiResponse<[PlaceSummary]>`
- `GET /places?region={필수}&category=` → `ApiResponse<[PlaceSummary]>`
- `GET /places/nearby?lat={필수}&lng={필수}&radius=1000&category=` → `ApiResponse<[PlaceSummary]>`
- `GET /places/{id}` → `ApiResponse<PlaceDetail>`

```
PlaceSummary { id:String, name:String, category:CategoryType, latitude:Double,
               longitude:Double, address:String, thumbnailUrl:String,
               distanceMeters:Double? (nearby 전용) }
PlaceDetail  { id, name, category, latitude, longitude, address,
               businessHours:String, imageUrl:String, badges:[String] }
```
- `CategoryType` enum 값은 미확인(추정: ATTRACTION/RESTAURANT) → 승환 확인 필요.

### 코스 (course)
- `GET /courses?region=&distance=` → `ApiResponse<[CourseSummary]>` (잘못된 필터값 400, BR-U2-4)
- `GET /courses/{id}` → `ApiResponse<CourseDetail>`

```
CourseSummary { id:String, name:String, region:Region,
                distanceCategory:CourseDistance, totalMeters:Int, waypointCount:Int }
CourseDetail  { id, name, region, distanceCategory, totalMeters,
                polyline:[PolylinePoint], cumulativeMeters:[Int],
                waypointAnchors:[WaypointAnchor] }
PolylinePoint  { lat:Double, lng:Double }
WaypointAnchor { name:String, polylineIndex:Int }
```
- ⭐ CourseDetail에 **폴리라인 + 누적거리 + 경유지 앵커**가 이미 포함 → V08 코스확인의 경로 렌더링을 T MAP 없이 BE 데이터로 가능(PM 코스 한정).

## iOS 매핑 메모
- `PlaceSummary` ≈ 우리 `MapPlace` (거의 1:1). category/ thumbnailUrl/ distanceMeters 매핑.
- `PlaceDetail` → V06 위치정보(영업시간/이미지/배지 = 착한식당).
- `/places/nearby` → V03 추천 장소, `/places/search` → V04·V05 검색(카카오 대안).
- `CourseDetail.polyline` → V08 지도 경로선.

## 아직 없는 것 (BE 예정)
- 인증(카카오/애플/JWT), 온보딩 API
- 경로 "반경 검색"은 `/places/nearby`(점 기준)로 대체 — 경로 전체 기준(along-route)은 별도 필요시 요청
