# V08 코스확인뷰 코드 생성 계획

기준: Figma `565:523` (V08_코스확인 모달 경유5) + 변형 `565:604`~`565:692`
BE: `GET /courses/{id}` (polyline 실측 확인 완료)

---

## A. Figma HiFi 실측값

### 화면 구조
| 요소 | 값 |
|---|---|
| 화면 배경 | `#F3F3F3` (Gray/200) |
| 바텀시트 | top 328, h 546, bg `#FAFAFA`, radius 8, shadow `0 -4px 2px rgba(0,0,0,0.05)`, pt 10 / pb 100 |
| grabber | 50×5, `#DFDFDF` (Gray/300), radius 8 |
| 흰 카드 | h 420, bg `#FFFFFF`, px 27 / py 25 |
| 러닝 시작 버튼 | **카드 밖**, left 16 / top 783, 370×59, bg `#13C674`, radius 8 |

### 카드 내부
| 요소 | 값 |
|---|---|
| 거리 텍스트 | Pretendard **Bold 22** / lh 26, `#5E5E5E`, **왼쪽** |
| 수정 칩 | 55×26, bg `#C6F3DF` (Primary/200), radius 24, 텍스트 Pretendard Medium 15 / lh 20 / tracking −0.3, `#13C674`, **오른쪽** |
| 구분선 | h **3**, `#72D794` (Primary/500), radius 3 |
| 지점 리스트 | 2열 — 번호열 26 / gap 15 / 이름열 200, 행 h 26, 행간 gap 20 |
| 출발지·도착지 | Pretendard **SemiBold 17** / lh 22, `#585858` — 번호열 **비움**, 레이블 텍스트 **없음** |
| 경유지 | Pretendard **Medium 15** / lh 20 / tracking −0.3, `#929292` — 번호열에 원형 번호 마커(1~5) |

### 현재 코드와 다른 점 (전부 수정 대상)
1. 거리/수정 칩 **좌우가 반대** (현재: 수정 왼쪽·거리 오른쪽)
2. 수정 칩이 현재는 **외곽선 캡슐** → 연녹 채움 pill
3. 구분선 h 2 → **3**, 색 primary → **primary500**
4. `"출발지 - 이름"` 레이블 형식 → **이름만** 표시
5. `"• 경유지 N 이름"` → **원형 번호 마커 + 이름**
6. 러닝 버튼이 카드 **안** → 카드 **밖 하단**
7. 바텀시트 컨테이너(grabber·`#FAFAFA` 배경) 자체가 없음
8. 폰트가 전부 `.system` → **Pretendard**

---

## B. 디자인시스템 토큰 불일치 (선행 수정)

| 토큰 | 현재 코드 | Figma | 조치 |
|---|---|---|---|
| `primary500` | `#8AD68C` | `#72D794` | 값 교체 |
| `gray300` | `#CCCCCC` | `#DFDFDF` | grabber용 `gray300` 복원 + 썸네일용 별도 토큰 분리 |
| `#585858` | 없음 | 지점명 텍스트 | 신규 토큰 추가 |
| `#929292` | 없음 | 경유지 텍스트 | 신규 토큰 추가 |

> `gray300`은 이전 커밋에서 썸네일 플레이스홀더용으로 `#CCCCCC`로 의도적 변경된 이력이 있음.
> 되돌리면 기존 화면에 영향 → **기존 값 유지하고 `gray300Line`(#DFDFDF)을 새로 추가**하는 쪽으로 진행.

---

## C. BE 연동 설계

### 실측 확인된 사실
- `CourseDetail.polyline` 10/10 코스 정상, `cumulativeMeters`·`waypointAnchors` 무결성 검증 통과
- `/places/along-route` **404 (미구현)** → 코스 근방 장소는 앱에서 직접 구성
- `/places/nearby` **30건 하드캡**(거리순), `limit`/`size` 무시 → 폴리라인 다중 샘플링 + 중복제거 필요
- 편의시설 카테고리 **부재** → MVP1에서 관광지(`TOUR`,`CULTURE`)·음식점(`RESTAURANT`,`CAFE`)만

### 발견된 버그 (선행 수정)
`CourseDTO.swift`의 `region` 필드가 `RegionDTO`(객체)로 선언돼 있으나
실제 응답은 `"region":"JEONJU"` **문자열** → **현재 코드로는 디코딩 실패**.
`String`으로 교체 필요.

### V08 진입 경로 2가지
| 경로 | 소스 | 경로선 | 총거리 |
|---|---|---|---|
| V07에서 만든 코스 | `RouteDraft` | T MAP polyline (V07이 이미 보유) | T MAP 실거리 |
| 메인뷰 추천 코스 | `courseId` | BE `CourseDetail.polyline` | `totalMeters` |

→ `CourseConfirmViewModel`이 두 소스를 모두 받도록 이니셜라이저 분리.

---

## D. 변경 파일 목록

### 선행 수정
- [ ] `Shared/DesignSystem/AppColor.swift` — `primary500` `#8AD68C`→`#72D794`, `gray300Line`(#DFDFDF)·`gray560`(#585858)·`gray460`(#929292) 추가
- [ ] `Shared/Networking/DTO/CourseDTO.swift` — `region: RegionDTO` → `String` (디코딩 버그)

### V08 신규/수정
- [ ] `Domain/Models/RunCourse.swift` — **신규**. V08/V09 공용 코스 모델 (polyline·누적거리·지점명·총거리). 두 진입 경로를 하나로 통일
- [ ] `Shared/Networking/DallyeoAPI.swift` — `courseDetail(id:)` 반환을 `RunCourse`로 매핑하는 변환 추가
- [ ] `Features/CourseConfirm/ViewModel/CourseConfirmViewModel.swift` — 이니셜라이저 2종(draft / courseId), BE 로드, 근방 장소 샘플링 조회, 로딩·에러 상태
- [ ] `Features/CourseConfirm/View/CourseConfirmView.swift` — HiFi 전면 반영 (A절 실측값), `routePolyline`·`markers` 지도 전달
- [ ] `Features/CourseConfirm/View/CourseSummaryCard.swift` — **신규**. 카드 분리 (거리/수정칩/구분선/지점리스트)
- [ ] `Features/CourseConfirm/View/WaypointNumberBadge.swift` — **신규**. 원형 번호 마커(1~5)
- [ ] `ContentView.swift` — `AppRoute.courseConfirm`에 코스 소스 전달

### 검증
- [ ] 시뮬레이터 빌드 + 실행, Figma 대비 픽셀 실측 (거리/칩/구분선/행간/버튼 위치)
- [ ] 경유지 0·1·3·5개 각 변형 확인 (`565:604`~`565:692`)

---

## E. 이번 계획에서 제외

| 항목 | 사유 |
|---|---|
| 편의시설 마커 | BE 카테고리 부재 (사용자 승인) |
| 코스 근방 1km 전체 커버 | `/places/nearby` 30건 캡. 샘플링으로 근사, 완전 커버는 BE `/places/along-route` 대기 |
| 러닝 시작 3초 카운트다운 | V09 범위 |
| 지역칩 `/regions` 연동 | V03 범위 |
