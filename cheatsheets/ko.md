# Claude Guides — 빠른 참조

## 명령어

| 명령어 | 기능 |
|--------|------|
| `/plan` | 코딩 전 구현 계획 생성 |
| `/debug` | 체계적 디버깅 (4단계) |
| `/verify` | 커밋 전 검사: 빌드, 타입, lint, 테스트 |
| `/audit` | 감사: 보안, 성능, 코드, 디자인, DB |
| `/test` | 모듈 테스트 작성 |
| `/tdd` | 테스트 주도 개발: 테스트 먼저, 코드 나중에 |
| `/fix` | 특정 문제 수정 |
| `/refactor` | 동작 변경 없이 구조 개선 |
| `/explain` | 코드 또는 아키텍처 작동 방식 설명 |
| `/doc` | 문서 생성 |
| `/learn` | 교훈을 `.claude/rules/lessons-learned.md`에 저장 (자동 로드) |
| `/context-prime` | 세션 시작 시 프로젝트 컨텍스트 로드 |
| `/checkpoint` | 스크래치패드에 진행 상황 저장 |
| `/handoff` | 요약 및 다음 단계와 함께 작업 인수인계 준비 |
| `/install` | 프로젝트에 claude-guides 설치 |
| `/worktree` | 병렬 브랜치를 위한 git worktrees 관리 |
| `/migrate` | 데이터베이스 마이그레이션 생성 또는 디버깅 |
| `/find-function` | 함수 또는 클래스 정의 검색 |
| `/find-script` | package.json, Makefile 등에서 스크립트 검색 |
| `/docker` | Dockerfile 및 docker-compose 생성 |
| `/api` | REST API 설계, OpenAPI 스펙 생성 |
| `/e2e` | Playwright로 E2E 테스트 생성 |
| `/perf` | 성능 분석: N+1, 번들, 메모리 |
| `/deps` | 의존성 감사: 보안, 라이선스, 구버전 |
| `/deploy` | 안전한 배포: 사전/사후 검증 포함 |
| `/fix-prod` | 프로덕션 핫픽스: 진단, 수정, 검증 |
| `/rollback-update` | 툴킷을 이전 버전으로 롤백 |
| `/council` | 멀티AI 리뷰: Gemini + ChatGPT 구현 전 검토 |

---

## 에이전트

심층 분석을 위한 에이전트:

| 에이전트 | 호출 방법 | 목적 |
|---------|----------|------|
| Code Reviewer | `/agent:code-reviewer` | 체크리스트 기반 코드 리뷰 |
| Test Writer | `/agent:test-writer` | TDD 접근법으로 테스트 생성 |
| Planner | `/agent:planner` | 작업을 단계별 계획으로 분할 |
| Security Auditor | `/agent:security-auditor` | 심층 보안 분석 |

---

## 감사

`/audit {유형}`으로 실행:

| 유형 | 검사 항목 |
|------|----------|
| `security` | SQL 인젝션, XSS, CSRF, 인증, 시크릿 |
| `performance` | N+1 쿼리, 캐싱, 지연 로딩, 번들 크기 |
| `code` | 패턴, 가독성, SOLID, DRY |
| `design` | UI/UX, 접근성, 반응형 |
| `mysql` | 인덱스, 느린 쿼리, performance_schema |
| `postgres` | pg_stat_statements, 블로트, 커넥션 |
| `deploy` | 배포 전 체크리스트 |

---

## 스킬

스킬은 컨텍스트에 따라 자동 활성화:

| 스킬 | 활성화 시점 |
|------|-----------|
| Database | 마이그레이션, 인덱스, 쿼리 |
| API Design | REST 엔드포인트, OpenAPI, 상태 코드 |
| Docker | 컨테이너, Dockerfile, Compose |
| Testing | 테스트, 목, 커버리지 |
| Tailwind | CSS 스타일링, 반응형 디자인 |
| Observability | 로깅, 메트릭, 트레이싱 |
| LLM Patterns | RAG, 임베딩, 스트리밍 |
| AI Models | 모델 선택, 가격, 컨텍스트 윈도우 |

---

## 워크플로우

### 3단계 (필수)

```text
RESEARCH (읽기 전용) --> PLAN (스크래치패드만) --> EXECUTE (전체 접근)
```

### 사고 수준

| 수준 | 사용 시점 |
|------|----------|
| `think` | 간단한 작업, 빠른 수정 |
| `think hard` | 다단계 기능, 리팩토링 |
| `ultrathink` | 아키텍처 결정, 복잡한 디버깅 |

---

## 시나리오 — 언제 무엇을 사용할까

### 버그를 발견했다

```text
/debug 버그 설명
```

Claude가 수정 전에 근본 원인을 조사합니다. 수정 후: `/verify`

### 코드 리뷰가 필요하다

```text
/audit code
```

전체 리뷰: `/audit security`, 그 다음 `/audit performance`

### 새 기능을 추가하고 싶다

```text
/plan 기능 설명
```

Claude가 스크래치패드에 계획을 생성합니다. 승인 후 실행. 그 다음: `/verify`

### 테스트를 작성해야 한다

```text
/tdd 모듈명
```

먼저 실패하는 테스트를 작성하고, 통과시키는 최소한의 코드를 작성합니다.

### 배포 전

```text
/verify
/audit security
/audit deploy
```

세 가지 모두 실행하여 프로덕션 전에 문제를 발견합니다.

### 새 세션 시작

```text
/context-prime
```

프로젝트 컨텍스트를 로드하여 Claude가 처음부터 코드베이스를 이해합니다.

### 다른 개발자에게 작업 인수인계

```text
/handoff
```

요약 생성: 완료된 작업, 현재 상태, 다음 단계.

### 안전하게 리팩토링

```text
/refactor 대상_코드
```

Claude가 동작을 유지하면서 리팩토링합니다. 항상 이후에 테스트를 실행합니다.

### 모르는 코드를 이해하고 싶다

```text
/explain path/to/file.ts
/explain 인증 흐름
```

### 데이터베이스 작업

```text
/migrate users 테이블 생성
/audit mysql
/audit postgres
```

### 성능 문제

```text
/perf
/audit performance
```

### 의존성 확인

```text
/deps
```

### REST API 필요

```text
/api users 엔드포인트 설계
```

### Docker 설정

```text
/docker
```

### E2E 테스트

```text
/e2e 사용자 등록 및 로그인
```

---

## MCP 서버

| 서버 | 목적 |
|------|------|
| context7 | 최신 라이브러리 문서 |
| playwright | 브라우저 자동화, UI 테스트, 스크린샷 |
| sequential-thinking | 단계별 문제 해결 |

---

## 빠른 팁

- 큰 기능 전에는 항상 `/plan` 사용 — 낭비되는 노력 방지
- 매 커밋 전에 `/verify` 실행 — 문제를 조기에 발견
- 어려운 문제 해결 후 `/learn` 사용 — 향후 세션을 위해 지식 저장
- 세션은 `/context-prime`으로 시작 — 컨텍스트가 있으면 Claude가 더 잘 작동
- 긴 작업에서는 `/checkpoint` 사용 — 세션이 끊겨도 진행 상황 보존
- `/debug`이 "그냥 고쳐보기"보다 나음 — 체계적 접근이 더 빠름
