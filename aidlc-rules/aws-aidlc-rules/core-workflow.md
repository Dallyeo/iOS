# 우선순위: 이 워크플로우는 모든 기본 워크플로우를 대체합니다
# 소프트웨어 개발 요청이 있을 때는 반드시 이 워크플로우를 먼저 따르세요

## 적응형 워크플로우 원칙
**워크플로우는 작업에 맞게 적응합니다. 그 반대가 아닙니다.**

AI 모델은 다음 기준으로 필요한 단계를 지능적으로 판단합니다:
1. 사용자의 요청 의도와 명확성
2. 기존 코드베이스 상태
3. 변경 범위와 복잡도
4. 위험도 및 영향 범위

---

# 인셉션 단계 (INCEPTION PHASE)

**목적**: 무엇을(WHAT), 왜(WHY) 만드는지 결정

## 워크스페이스 감지 (항상 실행)

1. `aidlc-docs/aidlc-state.md` 존재 여부 확인 — 있으면 이전 진행 상황 재개
2. 기존 코드 스캔하여 그린필드/브라운필드 판단
3. `aidlc-docs/aidlc-state.md` 생성 (없는 경우)
4. 결과를 `aidlc-docs/audit.md`에 기록 후 자동으로 다음 단계 진행

## 리버스 엔지니어링 (조건부 — 브라운필드)

기존 코드베이스가 있고 분석 산출물이 없을 때 실행:
1. `aidlc-docs/audit.md`에 시작 기록
2. 아키텍처, 코드 구조, 의존성 분석 및 문서화
3. **명시적 승인 대기** 후 다음 단계 진행

## 요구사항 분석 (항상 실행)

복잡도에 따라 깊이 조정 (단순 → 의도 분석만 / 복잡 → 상세 요구사항):
1. `aidlc-docs/audit.md`에 사용자 원문 요청 기록
2. 불명확한 부분은 `aidlc-docs/inception/requirements/requirements-questions.md`에 질문 작성 (채팅에 직접 질문 금지)
3. 요구사항 문서를 `aidlc-docs/inception/requirements/requirements.md`에 생성
4. **명시적 승인 대기**

## 유저 스토리 (조건부)

새 사용자 직면 기능이나 복잡한 비즈니스 로직일 때 실행. 단순 버그 수정·리팩토링은 건너뜀:
1. `aidlc-docs/audit.md`에 기록
2. 스토리 계획 → 사용자 승인 → 스토리 생성 (`aidlc-docs/inception/user-stories/`)
3. **명시적 승인 대기**

## 워크플로우 계획 (항상 실행)

1. 이전 인셉션 산출물 로딩
2. 구현 단계에서 실행할 스테이지 목록 결정
3. 작업 유닛 분해 결정
4. 계획을 `aidlc-docs/inception/plans/workflow-plan.md`에 작성
5. **명시적 승인 대기**

## 애플리케이션 설계 (조건부)

새 컴포넌트·서비스 레이어 설계가 필요할 때 실행. 기존 경계 내 변경은 건너뜀:
1. `aidlc-docs/audit.md`에 기록
2. MVVM 구조 기반으로 컴포넌트 및 인터페이스 설계
3. `aidlc-docs/inception/application-design/`에 산출물 생성
4. **명시적 승인 대기**

## 유닛 생성 (조건부)

복수 화면·모듈을 동시에 구현할 때 실행. 단일 유닛은 건너뜀:
1. `aidlc-docs/audit.md`에 기록
2. 작업 유닛 분해 및 의존성 정의
3. `aidlc-docs/inception/plans/unit-of-work.md`에 유닛 계획 작성
4. **명시적 승인 대기**

---

# 구현 단계 (CONSTRUCTION PHASE)

**목적**: 어떻게(HOW) 만들지 결정. 각 유닛을 완전히 완료한 후 다음 유닛으로 진행.

## 기능 설계 (조건부, 유닛별)

새 데이터 모델·복잡한 비즈니스 로직이 있을 때 실행:
1. `aidlc-docs/audit.md`에 기록
2. 데이터 모델, 비즈니스 로직, 예외 처리 설계
3. `aidlc-docs/construction/{unit-name}/functional-design/`에 산출물 생성
4. **승인 후 다음 스테이지 진행**

## NFR 요구사항 (조건부, 유닛별)

성능·보안·확장성 요구사항이 있을 때 실행:
1. `aidlc-docs/audit.md`에 기록
2. 성능, 보안, 안정성 요구사항 정의
3. `aidlc-docs/construction/{unit-name}/nfr-requirements/`에 산출물 생성
4. **승인 후 다음 스테이지 진행**

## NFR 설계 (조건부, 유닛별)

NFR 요구사항 스테이지 실행 시에만 실행:
1. `aidlc-docs/audit.md`에 기록
2. NFR 패턴을 실제 설계에 반영
3. `aidlc-docs/construction/{unit-name}/nfr-design/`에 산출물 생성
4. **승인 후 다음 스테이지 진행**

## 인프라 설계 (조건부, 유닛별)

새 SDK 통합·빌드 설정 변경·배포 파이프라인 구성이 필요할 때 실행:
1. `aidlc-docs/audit.md`에 기록
2. SPM 패키지, Info.plist 변경, 빌드 설정 정의
3. `aidlc-docs/construction/{unit-name}/infrastructure-design/`에 산출물 생성
4. **승인 후 다음 스테이지 진행**

## 코드 생성 (항상 실행, 유닛별)

**Part 1 — 계획**:
1. `aidlc-docs/audit.md`에 기록
2. 생성할 파일 목록과 순서를 체크박스 형식으로 `aidlc-docs/construction/plans/{unit-name}-code-generation-plan.md`에 작성
3. **승인 대기**

**Part 2 — 생성**:
1. 계획 파일을 읽고 미완료 단계부터 순서대로 실행
2. 각 단계 완료 즉시 계획 파일의 해당 체크박스를 `[x]`로 표시
3. 코드는 항상 `Dallyeo/` 하위에 생성 (`aidlc-docs/` 내 절대 금지)
4. 브라운필드: 기존 파일 수정 (복사본 생성 금지)
5. **승인 후 다음 유닛 또는 빌드 및 테스트로 진행**

## 빌드 및 테스트 (항상 실행)

모든 유닛 코드 생성 완료 후:
1. `aidlc-docs/audit.md`에 기록
2. `aidlc-docs/construction/build-and-test/`에 빌드 지침, 테스트 지침, 수동 체크리스트 작성
3. **승인 대기**

---

# 운영 단계 (OPERATIONS PHASE)

향후 배포·모니터링 워크플로우를 위한 플레이스홀더. 현재 미구현.

---

## 핵심 원칙

- **적응형 실행**: 가치를 더하는 단계만 실행
- **사용자 통제**: 단계 포함/제외 요청 가능
- **감사 추적**: 모든 사용자 입력 원문을 타임스탬프와 함께 `aidlc-docs/audit.md`에 기록. 절대 요약하지 말 것. 항상 추가(append)하고 덮어쓰기 금지
- **계획 체크박스**: 계획 파일의 각 단계는 완료된 동일한 상호작용에서 즉시 `[x]`로 표시
- **질문은 파일로**: 명확화 질문은 채팅에 직접 작성하지 말고 `aidlc-docs/` 하위 파일에 작성
- **코드 위치**: 애플리케이션 코드는 `Dallyeo/` 전용. `aidlc-docs/`는 문서 전용
