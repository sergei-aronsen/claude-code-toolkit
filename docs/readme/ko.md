# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.4.0-blue.svg)](../../CHANGELOG.md)

**[English](../../README.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **한국어**

---

## 이게 무엇인지

[**Superpowers**](https://github.com/obra/superpowers)(브레인스토밍, 서브에이전트, TDD, 디버깅)와 [**Get Shit Done**](https://github.com/gsd-build/get-shit-done)(Spec → Plan → Execute) 위에 얹는 얇은 오버레이로, 솔로 개발자에게 그 플러그인들이 남기는 빈틈을 채웁니다.

**대상:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code)로 진짜 제품을 출시하는 솔로 파운더와 1인 엔지니어링 팀.

**지원하는 스택:** Laravel · Rails · Next.js · Node.js · Python · Go.

## 어떤 빈틈을 채우는가

| 빈틈                                  | toolkit이 더하는 것                                                                                                                              |
|---------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| **멀티 AI 플랜 검증**                 | `/council` —— 당신의 플랜을 Gemini와 ChatGPT에 동시에 보내 독립 리뷰. CLI(`gemini`, `codex`) 또는 직접 API 키로 동작. Persona 오버레이, 해시 캐시, 비용 게이트, ru 로케일. |
| **프레임워크 컨텍스트**               | 7개 `CLAUDE.md` 템플릿(base + 6 스택), `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json`로 자동 감지.                       |
| **프로덕션 안전망**                   | `cc-safety-net`이 파괴적인 명령(`rm -rf /`, `git reset --hard` 등)을 PreToolUse에서 차단 —— 난독화돼도. 인스톨러에 내장.                          |
| **토큰 비용 통제**                    | RTK가 장황한 dev 명령 출력(`git status`, 테스트 러너)을 다시 써서 60-90% 토큰 절약. `cc-safety-net`과 결합 훅.                                   |
| **Cost routing**                      | `better-model`이 단순 작업을 더 싼 모델로 라우팅. 자동 설치되며 인스톨 라이프사이클에 통합.                                                       |
| **심볼 인식 코드 검색**               | [Serena](https://github.com/oraios/serena)(LSP, MIT, 로컬) + ripgrep + claude-context(시맨틱 벡터). 기본 Layer-3 검색 스택.                       |
| **Multi-CLI 브릿지**                  | `CLAUDE.md`를 `GEMINI.md`(Gemini CLI)와 `AGENTS.md`(OpenAI Codex)에 자동 동기화. 매 설치마다 드리프트 감지.                                       |
| **통합 카탈로그**                     | TUI 인스톨러가 24개 MCP 서버 + 8개 동반 CLI를 10개 카테고리(Backend / Payments / Workspace / Project Management / …)에서 제공. 행마다 scope 선택. |
| **한도 가시성(Pro/Max)**              | 스테이터스라인이 세션/주간 사용량을 보여줌 —— 벽에 부딪히기 전에 보임.                                                                          |
| **의존성 대시보드(v6.2)**             | `/update-deps` —— 추적 중인 모든 의존성(Layer 1/2/3)을 installed-vs-latest와 함께 늘어놓는 대화형 TUI. 무엇을 업데이트할지 직접 선택.            |
| **설치 후 가이드(v6.3)**              | 로컬 HTML 페이지(`.claude/setup-guide.html`) 생성 —— 설치된 MCP의 API 키 워크스루와 컴포넌트 설정만 표시.                                        |

핵심 가치는 큐레이션. 모든 것은 TUI 체크박스로 옵트인 —— 강제하는 것은 없음.

## 설치

명령 하나. 프로젝트 폴더 안의 **일반 터미널**에서 실행(Claude Code 안이 아님):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

인스톨러가 TUI 체크리스트(Toolkit, Security, RTK, Statusline, Council, Bridges, Integrations)를 보여주고, `superpowers`와 `get-shit-done`이 이미 깔려있는지 감지합니다. 깔려있다면 그 플러그인들이 이미 제공하는 파일을 건너뛰고 toolkit 고유의 약 47개 기여만 설치합니다.

Claude Desktop 사용자 —— marketplace로 설치:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

전체 단계별 가이드: [docs/howto/ko.md](../howto/ko.md).

## 설치 후

| 명령               | 기능                                                                           |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | 최신 toolkit 콘텐츠를 `.claude/`로 가져오면서 로컬 수정 보존.                  |
| `/update-deps`     | 의존성 대시보드(Layer 1/2/3 + MCP)를 열어 업데이트할 항목 선택.                |
| `/council`         | 플랜을 Gemini + ChatGPT에 보내 독립 리뷰.                                      |
| `/learn`           | 현재 결정을 scoped rule로 저장해 미래 세션에서 사용.                           |
| `/audit`           | 7가지 프레임워크 인식 감사(security, performance 등) 중 하나 실행.            |
| `/debug`           | 4단계 체계적 디버거: root-cause → pattern → hypothesis → fix.                  |
| `/setup-guide`     | 설치된 MCP/컴포넌트용 로컬 HTML 설정 가이드 재생성.                            |

전체 명령 목록: [docs/features.md](../features.md).

## 아키텍처

Toolkit v6.2는 **얇은 오버레이**이며 3층으로 구성됩니다:

- **Layer 1** —— toolkit 콘텐츠(템플릿, slash 명령, 컴포넌트, skill, 에이전트)
- **Layer 2** —— 무료 베이스 플러그인(Superpowers, Get Shit Done, ru-text)
- **Layer 3** —— 선택적 외부 도구(cc-safety-net, RTK, Serena, claude-context, better-model)

전체 다이어그램: [docs/architecture.md](../architecture.md).
솔로 파운더 / 비개발자용: [docs/non-programmer-mode.md](../non-programmer-mode.md).

## MCP 서버 카탈로그

`--integrations` 플래그(또는 첫 설치 후 `/integrations`)가 24개 서버를 10개 카테고리로 보여주는 TUI 체크리스트를 엽니다. 프로젝트에 필요한 것만 고르면 됩니다.

| 카테고리                | 서버                                                                                  |
|-------------------------|---------------------------------------------------------------------------------------|
| **docs-research**       | `context7` · `firecrawl` · `notebooklm`                                               |
| **backend**             | `aws-cloudwatch-logs` · `aws-cost-explorer` · `cloudflare` · `dbhub` · `supabase`     |
| **payments**            | `stripe`                                                                              |
| **email**               | `resend` · `mailgun`                                                                  |
| **workspace**           | `calendly` · `notion`                                                                 |
| **project-management**  | `jira` · `linear` · `youtrack`                                                        |
| **communication**       | `slack` · `telegram`                                                                  |
| **design**              | `figma`                                                                               |
| **dev-tools**           | `magic` · `openrouter` · `serena` · `claude-context` · `playwright`                   |
| **monitoring**          | `sentry` · `datadog` · `posthog`                                                      |

각 서버는 행마다 scope를 선택해 설치(`[U]` user / `[P]` project / `[L]` local). project scope는 자격 증명을 `<project>/.env`(mode 0600)에 쓰고 `.gitignore`를 자동 추가; `.mcp.json`은 `${VAR}` 치환 형태만 보유. 자세히: [docs/INTEGRATIONS.md](../INTEGRATIONS.md).

## 라이선스

MIT —— [LICENSE](../../LICENSE) 참조.
