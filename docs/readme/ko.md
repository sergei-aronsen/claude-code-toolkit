# Claude Code Toolkit

Claude Code를 활용한 AI 기반 개발을 위한 종합 지침서입니다.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **한국어**

> 먼저 전체 [단계별 설치 가이드](../howto/ko.md)를 읽어주세요.

---

## 대상

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)로 제품을 만드는 **솔로 개발자**를 위한 툴킷입니다.

지원 스택: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**30개 슬래시 명령어** | **7개 감사** | **29개 가이드** | [명령어, 템플릿, 감사, 컴포넌트 전체 목록](../features.md#slash-commands-30-total) 보기.

---

## 빠른 시작

### 1. 전역 설정 (한 번만)

#### a) Security Pack

심층 방어 보안 설정입니다. 전체 가이드는 [components/security-hardening.md](../../components/security-hardening.md)를 참조하세요.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — 토큰 최적화 도구 (권장)

[RTK](https://github.com/rtk-ai/rtk)는 개발 명령어(`git status`, `cargo test` 등)의 토큰 소비를 60-90% 줄여줍니다.

```bash
brew install rtk
rtk init -g
```

> **참고:** RTK와 cc-safety-net이 별도의 훅인 경우 결과가 충돌합니다.
> Security Pack(단계 1a)은 이미 두 가지를 순차적으로 실행하는 통합 훅을 구성합니다.
> 자세한 내용은 [components/security-hardening.md](../../components/security-hardening.md)를 참조하세요.

#### c) Rate Limit Statusline (Claude Max / Pro, 선택 사항)

Claude Code 상태 표시줄에 세션/주간 제한을 표시합니다. 자세히: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

## 설치 모드

TK는 `superpowers`(obra)와 `get-shit-done`(gsd-build)이 설치되어 있는지 자동으로 감지하고
`standalone`, `complement-sp`, `complement-gsd`, `complement-full` 중 하나의 모드를 선택합니다.
각 프레임워크 템플릿은 `## Required Base Plugins`에 필요한 기본 플러그인을 문서화합니다 —
예: [templates/base/CLAUDE.md](../../templates/base/CLAUDE.md). 전체 12칸 설치 매트릭스와
단계별 안내는 [docs/INSTALL.md](../INSTALL.md)를 참조하세요.

### 독립 설치

`superpowers` 또는 `get-shit-done`이 설치되어 있지 않거나 명시적으로 사용하지 않기로 한 경우입니다.
TK는 전체 54개 파일을 설치합니다 — 완전한 기본 구성입니다. 일반 터미널(Claude Code 내부가 아닌!)에서
프로젝트 폴더로 이동하여 실행하세요:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

그 프로젝트 디렉토리에서 Claude Code를 시작하세요. 이후 업데이트는 `/update-toolkit`을 사용하세요.

### 보완 설치

`superpowers`(obra)와 `get-shit-done`(gsd-build) 중 하나 또는 둘 다 설치된 경우입니다. TK는
자동으로 감지하고 SP 기능과 중복되는 7개 파일을 건너뛰어 약 47개의 TK 고유 기여분
(Council, 프레임워크 CLAUDE.md 템플릿, 컴포넌트 라이브러리, cheatsheets, 프레임워크별 스킬)을 유지합니다.
동일한 설치 명령어를 사용하세요 — TK가 자동으로 `complement-*` 모드를 선택합니다.
재정의하려면 `--mode standalone`(또는 다른 모드 이름)을 전달하세요:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

### v3.x에서 업그레이드

TK 설치 후 SP 또는 GSD를 설치한 v3.x 사용자는 `scripts/migrate-to-complement.sh`를 실행하여
파일별 확인과 전체 사전 마이그레이션 백업으로 중복 파일을 제거해야 합니다. 전체 12칸 매트릭스와
단계별 안내는 [docs/INSTALL.md](../INSTALL.md)를 참조하세요.

> **중요:** 프로젝트 템플릿은 `project/.claude/CLAUDE.md` 전용입니다. `~/.claude/CLAUDE.md`에
> 복사하지 마세요 — 해당 파일에는 전역 보안 규칙과 개인 설정만 포함해야 합니다(50줄 미만).
> 자세한 내용은 [components/claude-md-guide.md](../../components/claude-md-guide.md)를 참조하세요.

---

## 핵심 기능

| 기능 | 설명 |
|------|------|
| **자기 학습** | `/learn`이 `globs:` 가 있는 규칙 파일로 해결책을 저장 — 관련 파일에만 자동 로드 |
| **자동 활성화 훅** | 훅이 프롬프트를 가로채서 컨텍스트(키워드, 의도, 파일 경로)를 점수화하고 관련 스킬을 추천 |
| **지식 지속성** | 프로젝트 정보를 `.claude/rules/`에 저장 — 매 세션 자동 로드, git에 커밋, 어떤 머신에서든 사용 가능 |
| **체계적인 디버깅** | `/debug`가 4단계를 강제합니다: 근본 원인 -> 패턴 -> 가설 -> 수정. 추측 없음 |
| **프로덕션 안전** | `/deploy`로 사전/사후 검사, `/fix-prod`로 핫픽스, 점진적 배포, worker 안전성 |
| **Supreme Council** | `/council`로 계획을 Gemini + ChatGPT에 전송하여 코딩 전 독립적 리뷰 수행 |
| **구조화된 워크플로** | 3가지 필수 단계: 조사(읽기 전용) -> 계획(스크래치패드) -> 실행(확인 후) |

[상세 설명 및 예시](../features.md) 보기.

---

## MCP 서버 (권장!)

### 전역 (모든 프로젝트)

| 서버 | 용도 |
|------|------|
| `context7` | 라이브러리 문서 |
| `playwright` | 브라우저 자동화, UI 테스트 |
| `sequential-thinking` | 단계별 문제 해결 |
| `sentry` | 에러 모니터링 및 이슈 조사 |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### 프로젝트별 (자격 증명)

| 서버 | 용도 |
|------|------|
| `dbhub` | 범용 데이터베이스 접근 (PostgreSQL, MySQL, MariaDB, SQL Server, SQLite) |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **보안:** 항상 **읽기 전용 데이터베이스 사용자**를 사용하세요 — DBHub의 앱 수준 `--readonly` 플래그에만 의존하지 마세요([알려진 우회 방법](https://github.com/bytebase/dbhub/issues/271)). 프로젝트별 서버는 `.claude/settings.local.json`(.gitignore 처리됨, 자격 증명에 안전)에 저장됩니다. 전체 세부 정보는 [mcp-servers-guide.md](../../components/mcp-servers-guide.md)를 참조하세요.

---

## 설치 후 구조

†로 표시된 파일은 `superpowers`와 충돌합니다 — `complement-sp` 및 `complement-full` 모드에서 생략됩니다.

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # 주요 지침 (프로젝트에 맞게 조정)
    ├── settings.json          # 후크, 권한
    ├── commands/              # 슬래시 명령어
    │   ├── verify.md          # † complement-sp/full에서 생략됨
    │   ├── debug.md           # † complement-sp/full에서 생략됨
    │   └── ...
    ├── prompts/               # 감사
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # 서브에이전트
    │   ├── code-reviewer.md   # † complement-sp/full에서 생략됨
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # 프레임워크 전문 지식
    │   └── [framework]/SKILL.md
    ├── rules/                 # 자동 로드되는 프로젝트 정보
    └── scratchpad/            # 작업 메모
```

---

## 지원되는 프레임워크

| 프레임워크 | 템플릿 | 스킬 | 자동 감지 |
|------------|--------|------|-----------|
| Laravel | ✅ | ✅ | `artisan` 파일 |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (next.config 없이) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## 컴포넌트

커스텀 `CLAUDE.md` 파일을 구성하기 위한 재사용 가능한 Markdown 섹션입니다. 컴포넌트는 저장소 루트
자산입니다 — `.claude/`에 설치되지 않습니다. 절대 GitHub URL로 참조하세요.

**오케스트레이션 패턴** — Council과 GSD 워크플로가 모두 사용하는 린 오케스트레이터 + 풍부한 서브에이전트
설계에 대해서는 [components/orchestration-pattern.md](../../components/orchestration-pattern.md)를 참조하세요.
커스텀 슬래시 명령어가 단일 컨텍스트 윈도우를 넘어 확장할 수 있도록 도와줍니다.
