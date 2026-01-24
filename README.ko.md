# Claude Guides

Claude Code를 활용한 AI 기반 개발을 위한 종합 가이드입니다.

[![Quality Check](https://github.com/digitalplanetno/claude-guides/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-guides/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](README.ru.md)** | **[Español](README.es.md)** | **[Deutsch](README.de.md)** | **[Français](README.fr.md)** | **[中文](README.zh.md)** | **[日本語](README.ja.md)** | **[Português](README.pt.md)** | **한국어**

---

## 대상 사용자

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)로 제품을 만드는 **솔로 개발자**.

지원 스택: **Laravel/PHP**, **Next.js**, **Node.js**, **Python**, **Go**, **Ruby on Rails**.

팀이 없으면 코드 리뷰도 없고, 아키텍처에 대해 물어볼 사람도 없고, 보안을 확인해 줄 사람도 없습니다. 이 저장소가 이러한 공백을 메웁니다:

| 문제 | 해결책 |
|---------|----------|
| Claude가 매번 규칙을 잊어버림 | `CLAUDE.md` — 세션 시작 시 읽는 지침 |
| 물어볼 사람이 없음 | `/debug` — 추측 대신 체계적인 디버깅 |
| 코드 리뷰가 없음 | `/audit code` — Claude가 체크리스트에 따라 검토 |
| 보안 리뷰가 없음 | `/audit security` — SQL 인젝션, XSS, CSRF, 인증 |
| 배포 전 확인을 잊어버림 | `/verify` — 빌드, 타입, 린트, 테스트를 한 번에 |

**포함 내용:** 24개 명령어, 7개 감사, 23개 이상의 가이드, 모든 주요 스택용 템플릿.

---

## 빠른 시작

### 첫 설치

Claude Code에게 말하세요:

```text
Download instructions from https://github.com/digitalplanetno/claude-guides
```

또는 터미널에서 실행:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-guides/main/scripts/init-claude.sh | bash
```

스크립트가 자동으로 프레임워크(Laravel, Next.js)를 감지하고 적절한 템플릿을 복사합니다.

### 설치 후

재설치 또는 업데이트시 `/install` 명령어를 사용하세요:

```text
/install          # 프레임워크 자동 감지
/install laravel  # Laravel 강제
/install nextjs   # Next.js 강제
/install nodejs   # Node.js 강제
/install python   # Python 강제
/install go       # Go 강제
/install rails    # Ruby on Rails 강제
```

### 업데이트

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-guides/main/scripts/update-claude.sh | bash
```

---

## 핵심 기능

### 1. 자가 학습 시스템

Claude가 여러분의 수정 사항을 학습하고 프로젝트 지식을 축적합니다.

**두 가지 메커니즘:**

| 메커니즘 | 기능 | 사용 시점 |
|-----------|--------------|-------------|
| `/learn` | **일회성** 문제 해결 저장 | 복잡한 문제 해결, 우회 방법 발견 시 |
| **스킬 축적** | **반복적인** 패턴 축적 | Claude가 2회 이상 수정된 것을 인지했을 때 |

**차이점:**

```text
/learn  → "문제 X를 어떻게 해결했는지"     (일회성 수정)
skill   → "Y를 항상 어떻게 하는지"         (프로젝트 패턴)
```

**/learn 예시:**

```text
> /learn

세션 분석 중...
발견: Prisma Serverless 연결 수정

문제: Vercel Edge Functions에서 연결 타임아웃
해결: DATABASE_URL에 ?connection_limit=1 추가

.claude/learned/prisma-serverless.md에 저장하시겠습니까? → yes
```

**스킬 축적 예시:**

```text
User: 사용자용 엔드포인트 생성해줘
Claude: [엔드포인트 생성]
User: 아니, 우리는 유효성 검사에 Zod를 쓰고 에러에는 AppError를 써

Claude: 패턴 감지: 엔드포인트는 Zod + AppError 사용
        'backend-endpoints' 스킬로 저장할까요?
        다음에서 활성화됨: endpoint, api, route

User: yes

[다음번에 Claude가 바로 Zod + AppError를 사용함]
```

### 2. 자동 활성화 훅

**문제:** 10개의 스킬이 있지만 사용하는 것을 잊어버립니다.

**해결책:** 훅이 Claude에게 보내기 **전에** 프롬프트를 가로채서 스킬 로드를 권장합니다.

```text
사용자 프롬프트 → 훅 분석 → 점수화 → 권장
```

**점수 시스템:**

| 트리거 | 점수 | 예시 |
|---------|--------|---------|
| keyword | +2 | 프롬프트에 "endpoint" |
| intentPattern | +4 | "create.*endpoint" |
| pathPattern | +5 | `src/api/*` 파일 열림 |

**예시:**

```text
프롬프트: "회원가입용 POST 엔드포인트 생성"
파일: src/api/auth.controller.ts

스킬 권장:
[HIGH] backend-dev (점수: 13)
[HIGH] security-review (점수: 12)

Skill 도구를 사용하여 가이드라인을 로드하세요.
```

### 3. 메모리 지속성

**문제:** MCP 메모리가 로컬에 저장됩니다. 다른 컴퓨터로 이동하면 메모리가 손실됩니다.

**해결책:** `.claude/memory/`로 내보내기 → git에 커밋 → 어디서나 사용 가능.

```text
.claude/memory/
├── knowledge-graph.json   # 컴포넌트 관계
├── project-context.md     # 프로젝트 컨텍스트
└── decisions-log.md       # 왜 결정 X를 내렸는지
```

**워크플로:**

```text
세션 시작 시:    동기화 확인 → MCP에서 메모리 로드
변경 후:       내보내기 → .claude/memory/ 커밋
새 컴퓨터에서:  Pull → MCP로 가져오기
```

### 4. 체계적인 디버깅 (/debug)

**철칙:**

```text
근본 원인 조사 없이는 수정 금지
```

**4단계:**

| 단계 | 수행 작업 | 종료 기준 |
|-------|------------|---------------|
| **1. 근본 원인** | 오류 읽기, 재현, 데이터 흐름 추적 | 무엇과 왜를 이해 |
| **2. 패턴** | 작동하는 예시 찾기, 비교 | 차이점 발견 |
| **3. 가설** | 이론 수립, 하나의 변경 테스트 | 확인됨 |
| **4. 수정** | 테스트 작성, 수정, 검증 | 테스트 통과 |

**세 번 수정 규칙:**

```text
3번 이상 수정해도 안 되면 — 멈춰라!
이건 버그가 아니다. 아키텍처 문제다.
```

### 5. 구조화된 워크플로

**문제:** Claude가 종종 작업을 이해하기 전에 "바로 코딩"합니다.

**해결책:** 명시적 제한이 있는 3단계:

| 단계 | 접근 권한 | 허용 작업 |
|-------|--------|----------------|
| **조사** | 읽기 전용 | Glob, Grep, Read — 컨텍스트 이해 |
| **계획** | 스크래치패드만 | `.claude/scratchpad/`에 계획 작성 |
| **실행** | 전체 | 계획 확인 후에만 |

```text
User: 이메일 유효성 검사 추가

Claude: 1단계: 조사
        [파일 읽기, 패턴 검색]
        발견: RegisterForm.tsx의 폼, Zod로 유효성 검사

        2단계: 계획
        [.claude/scratchpad/current-task.md에 계획 생성]
        계획 완료. 진행하시겠습니까?

User: ok

Claude: 3단계: 실행
        단계 1: 스키마 추가 중...
        단계 2: 폼에 통합 중...
        단계 3: 테스트...
```

---

## 설치 후 구조

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # 메인 지침 (프로젝트에 맞게 수정)
    ├── settings.json          # 훅, 권한
    ├── commands/              # 슬래시 명령어
    │   ├── verify.md
    │   ├── debug.md
    │   └── ...
    ├── prompts/               # 감사
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # 서브에이전트
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # 프레임워크 전문성
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # 작업 노트
    └── memory/                # MCP 메모리 내보내기
```

---

## 포함 내용

### 템플릿 (7가지 옵션)

| 템플릿 | 용도 | 특징 |
|----------|----------|----------|
| `base/` | 모든 프로젝트 | 범용 규칙 |
| `laravel/` | Laravel + Vue/Inertia | Eloquent, 마이그레이션, Blade, Pint |
| `nextjs/` | Next.js + TypeScript | App Router, RSC, Tailwind |
| `nodejs/` | Node.js + Express/Fastify | REST API, 미들웨어, JWT |
| `python/` | Python + FastAPI/Django | 타입 힌트, Pydantic, 비동기 |
| `go/` | Go + Gin/Echo | 모듈, 인터페이스, 동시성 |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord, Turbo, Stimulus, RSpec |

### 슬래시 명령어 (총 24개)

| 명령어 | 설명 |
|---------|-------------|
| `/verify` | 커밋 전 확인: 빌드, 타입, 린트, 테스트 |
| `/debug [problem]` | 4단계 디버깅: 근본 원인 → 가설 → 수정 → 검증 |
| `/learn` | `.claude/learned/`에 문제 해결 저장 |
| `/plan` | 구현 전 스크래치패드에 계획 생성 |
| `/audit [type]` | 감사 실행 (보안, 성능, 코드, 디자인, 데이터베이스) |
| `/test` | 모듈용 테스트 작성 |
| `/refactor` | 동작 유지하며 리팩토링 |
| `/fix [issue]` | 특정 이슈 수정 |
| `/explain` | 코드 작동 방식 설명 |
| `/doc` | 문서 생성 |
| `/context-prime` | 세션 시작 시 프로젝트 컨텍스트 로드 |
| `/checkpoint` | 스크래치패드에 진행 상황 저장 |
| `/handoff` | 작업 인수인계 준비 (요약 + 다음 단계) |
| `/worktree` | Git worktrees 관리 |
| `/install` | 프로젝트에 claude-guides 설치 |
| `/migrate` | 데이터베이스 마이그레이션 지원 |
| `/find-function` | 이름/설명으로 함수 찾기 |
| `/find-script` | package.json/composer.json에서 스크립트 찾기 |
| `/tdd` | 테스트 주도 개발 워크플로 |
| `/docker` | Docker 컨테이너 및 Compose 관리 |
| `/api` | API 엔드포인트 생성 및 문서화 |
| `/e2e` | E2E 테스트 작성 및 실행 |
| `/perf` | 성능 프로파일링 및 최적화 |
| `/deps` | 의존성 분석 및 업데이트 |

### 감사 (7가지 유형)

| 감사 | 파일 | 확인 내용 |
|-------|------|----------------|
| **보안** | `SECURITY_AUDIT.md` | SQL 인젝션, XSS, CSRF, 인증, 시크릿 |
| **성능** | `PERFORMANCE_AUDIT.md` | N+1, 번들 크기, 캐싱, 지연 로딩 |
| **코드 리뷰** | `CODE_REVIEW.md` | 패턴, 가독성, SOLID, DRY |
| **디자인 리뷰** | `DESIGN_REVIEW.md` | UI/UX, 접근성, 반응형 (Playwright MCP) |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema, 인덱스, 느린 쿼리 |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements, bloat, 연결 |
| **배포** | `DEPLOY_CHECKLIST.md` | 배포 전 체크리스트 |

### 컴포넌트 (23개 이상의 가이드)

| 컴포넌트 | 설명 |
|-----------|-------------|
| `structured-workflow.md` | 3단계 접근법: 조사 → 계획 → 실행 |
| `smoke-tests-guide.md` | 최소 API 테스트 (Laravel/Next.js/Node.js) |
| `hooks-auto-activation.md` | 프롬프트 컨텍스트에 따른 스킬 자동 활성화 |
| `skill-accumulation.md` | 자가 학습: Claude가 프로젝트 지식 축적 |
| `modular-skills.md` | 대규모 가이드라인을 위한 점진적 공개 |
| `spec-driven-development.md` | 코드 전 명세서 |
| `mcp-servers-guide.md` | 권장 MCP 서버 |
| `memory-persistence.md` | MCP 메모리와 Git 동기화 |
| `plan-mode-instructions.md` | 생각 레벨: think → think hard → ultrathink |
| `git-worktrees-guide.md` | 브랜치에서 병렬 작업 |
| `devops-highload-checklist.md` | 고부하 프로젝트 체크리스트 |
| `api-health-monitoring.md` | API 엔드포인트 모니터링 |
| `bootstrap-workflow.md` | 새 프로젝트 워크플로 |
| `github-actions-guide.md` | GitHub Actions CI/CD 설정 |
| `pre-commit-hooks.md` | pre-commit 훅 설정 및 관리 |
| `deployment-strategies.md` | 배포 전략 (Blue-Green, Canary 등) |

---

## MCP 서버 (권장!)

| 서버 | 용도 |
|--------|---------|
| `context7` | 라이브러리 문서 |
| `playwright` | 브라우저 자동화, UI 테스트 |
| `memory-bank` | 세션 간 메모리 |
| `sequential-thinking` | 단계별 문제 해결 |
| `memory` | 지식 그래프 (관계 그래프) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
```

---

## 사용 예시

### /verify — 커밋 전 확인

```text
> /verify

확인 실행 중...
빌드: 통과
TypeScript: 오류 없음
ESLint: 2개 경고 (미사용 import)
테스트: 23개 통과

권장: 커밋 전에 린트 경고를 수정하세요.
```

### /debug — 체계적인 디버깅

```text
> /debug API가 /api/users에서 500 반환

1단계: 근본 원인 분석
├── app/api/users/route.ts 읽기
├── 로그 확인
└── 발견: try/catch 없는 prisma.user.findMany()

2단계: 가설
└── 콜드 스타트 시 데이터베이스 연결 타임아웃

3단계: 수정
└── 에러 핸들링 + 재시도 로직 추가

4단계: 검증
└── 엔드포인트 테스트 — 작동
```

### /audit security — 보안 감사

```text
> /audit security

보안 감사 보고서
=====================

CRITICAL (1)
├── UserController:45에서 SQL 인젝션
└── 권장: prepared statements 사용

MEDIUM (2)
├── /api/login에 rate limiting 없음
└── CORS가 Access-Control-Allow-Origin: *로 설정됨

LOW (1)
└── .env.example에서 디버그 모드
```

---

## 지원 프레임워크

| 프레임워크 | 템플릿 | 스킬 | 자동 감지 |
|-----------|----------|--------|----------------|
| Laravel | 전용 | 있음 | `artisan` 파일 |
| Next.js | 전용 | 있음 | `next.config.*` |
| Node.js | 전용 | 있음 | `package.json` (next.config 없이) |
| Python | 전용 | 있음 | `pyproject.toml` / `requirements.txt` |
| Go | 전용 | 있음 | `go.mod` |
| Ruby on Rails | 전용 | 있음 | `bin/rails` / `config/application.rb` |
