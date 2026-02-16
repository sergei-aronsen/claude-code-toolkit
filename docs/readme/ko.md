# Claude Toolkit

Claude Code를 활용한 AI 기반 개발을 위한 종합 지침서입니다.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **한국어**

> 먼저 [단계별 설치 가이드](../howto/ko.md)를 읽어보세요.

---

## 대상 사용자

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)로 제품을 만드는 **솔로 개발자**.

지원 스택: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7가지 템플릿** (basic, Laravel, Rails, Next.js, Node.js, Python, Go)

**27개 슬래시 명령어** | **7개 감사** | **24개 이상의 가이드** | [명령어, 템플릿, 감사, 컴포넌트 전체 목록](../features.md#slash-commands-27-total) 보기.

---

## 빠른 시작

### 1. Security Pack (전역, 한 번만)

심층 방어 보안 설정을 포함합니다. 전체 가이드는 [components/security-hardening.md](../../components/security-hardening.md)를 참조하세요.

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

### 2. 설치 (프로젝트별)

스크립트가 자동으로 프레임워크를 감지하고 적절한 템플릿을 복사합니다.

프로젝트 폴더의 터미널에서 실행하세요:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Claude를 재시작하세요!** 이후 업데이트는 `/update-toolkit` 명령어를 사용하여 재설치 또는 업데이트하세요.

### 3. Rate Limit Statusline (Claude Max / Pro)

Claude Code 상태 표시줄에 세션/주간 제한을 표시합니다. 자세히: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

### 4. Supreme Council (멀티 AI 리뷰, 선택 사항)

Gemini + ChatGPT가 코딩 전에 계획을 리뷰합니다. 자세히: [components/supreme-council.md](../../components/supreme-council.md)

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-council.sh | bash
```

---

## 핵심 기능

| 기능 | 설명 |
|---------|-------------|
| **자가 학습** | `/learn`으로 일회성 해결책을 저장하고, 스킬 축적이 반복 패턴을 자동으로 캡처합니다 |
| **자동 활성화 훅** | 훅이 프롬프트를 가로채서 컨텍스트(키워드, 의도, 파일 경로)를 점수화하고 관련 스킬을 추천합니다 |
| **메모리 지속성** | MCP 메모리를 `.claude/memory/`로 내보내서 git에 커밋하면 어떤 머신에서든 사용 가능합니다 |
| **체계적인 디버깅** | `/debug`가 4단계를 강제합니다: 근본 원인 -> 패턴 -> 가설 -> 수정. 추측 없음 |
| **프로덕션 안전** | `/deploy`로 사전/사후 검사, `/fix-prod`로 핫픽스, 점진적 배포 |
| **Supreme Council** | `/council`로 계획을 Gemini + ChatGPT에 전송하여 코딩 전 독립적 리뷰 수행 |
| **구조화된 워크플로** | 3가지 필수 단계: 조사(읽기 전용) -> 계획(스크래치패드) -> 실행(확인 후) |

[상세 설명 및 예시](../features.md) 보기.

---

## MCP 서버 (권장!)

| 서버 | 용도 |
|--------|---------|
| `context7` | 라이브러리 문서 |
| `playwright` | 브라우저 자동화, UI 테스트 |
| `memory-bank` | 세션 간 메모리 |
| `sequential-thinking` | 단계별 문제 해결 |
| `memory` | Knowledge Graph (관계 그래프) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add memory-bank -- npx -y @allpepper/memory-bank-mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
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

## 지원 프레임워크

| 프레임워크 | 템플릿 | 스킬 | 자동 감지 |
|-----------|----------|--------|----------------|
| Laravel | ✅ | ✅ | `artisan` 파일 |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (next.config 없이) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
