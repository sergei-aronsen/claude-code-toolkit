# Claude Code Toolkit 설치와 사용법

> 제로에서 Claude Code 생산적 개발까지의 전체 경로를 한 곳에 정리.

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **한국어**

---

## 사전 요구사항

설치되어 있는지 확인:

- **Node.js** —— `node --version`(20.x 이상 권장)
- **Claude Code** —— `claude --version`
- **git** —— `.claude/`를 리포지토리에 커밋하려고
- **jq** —— 인스톨러가 `settings.json`을 머지하는 데 필요(`brew install jq` / `apt install jq`)

Claude Code가 아직 안 깔려있으면:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## 설치

프로젝트 폴더로 `cd` 한 다음 **일반 터미널**에서(Claude Code 내부 아님) 실행:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

인스톨러가 모든 컴포넌트가 든 TUI 체크리스트를 엽니다:

```text
[x] toolkit              ← toolkit 콘텐츠(프로젝트의 .claude/)
[x] security             ← 전역 security pack + cc-safety-net
[ ] rtk                  ← 장황한 dev 명령 출력 다시 쓰기(-60-90% 토큰)
[ ] statusline           ← 상태바에 세션/주간 사용량 표시
[ ] council              ← /council = Gemini + ChatGPT 플랜 검증
[ ] gemini-bridge        ← CLAUDE.md → GEMINI.md 자동 동기화
[ ] codex-bridge         ← CLAUDE.md → AGENTS.md 자동 동기화
[ ] mcp-servers (24)     ← 통합 TUI 체크리스트(Stripe, Sentry, dbhub, …)
[ ] skills (22)          ← marketplace skill(i18n, shadcn, stripe, …)
```

`스페이스`로 토글, `↑/↓`로 이동, `Enter`로 체크된 항목 설치.

인스톨러가 시그니처 파일로 프레임워크(Laravel, Next.js, Python, Go, …)를 감지하고 맞는 `CLAUDE.md` 템플릿을 깔아줍니다. `superpowers`와 `get-shit-done`이 이미 깔려있으면 toolkit은 그 플러그인들이 이미 제공하는 파일을 건너뛰고 toolkit 고유의 약 47개 기여만 설치합니다.

완료되면 로컬 HTML 페이지(`.claude/setup-guide.html`)가 열리고, 설치된 각 MCP의 단계별 설명(API 키 어디서 받는지, 어떤 env 변수 세팅하는지, 테스트 방법)이 나옵니다.

---

## 커밋하고 작업 시작

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code가 시작되면 자동으로 로드합니다:

1. 전역 `~/.claude/CLAUDE.md`(보안 규칙 —— 스크립트가 설치)
2. 프로젝트 `CLAUDE.md`(당신 스택에 맞춰진 것 —— 프로젝트 특이 사항을 추가 가능)
3. `.claude/commands/`의 모든 명령과 marketplace의 skill

---

## 유용한 명령

| 명령               | 기능                                                                           |
|--------------------|--------------------------------------------------------------------------------|
| `/update-toolkit`  | 최신 toolkit 콘텐츠 가져오기, `CLAUDE.md` 로컬 편집 보존.                      |
| `/update-deps`     | 의존성 대시보드(Layer 1/2/3 + MCP). 업데이트할 항목 선택.                      |
| `/council 플랜`    | 플랜을 Gemini + ChatGPT에 보내 독립 리뷰.                                      |
| `/learn`           | 현재 결정을 scoped rule로 저장해 미래 세션에서 사용.                           |
| `/audit security`  | 7가지 프레임워크 인식 감사 중 하나.                                           |
| `/debug 문제`      | 4단계 체계적 디버거.                                                          |
| `/setup-guide`     | 로컬 HTML 설정 가이드 재생성.                                                 |
| `/helpme`          | 전체 명령 치트시트.                                                           |

---

## 전체 흐름

```text
┌────────────────────────────────────────────────────────┐
│  설치(프로젝트당 1회)                                  │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → TUI 체크리스트 → 스페이스/Enter                      │
│                                                        │
│  결과:                                                 │
│   ~/.claude/CLAUDE.md       ← 보안 규칙                │
│   .claude/                  ← 명령, skill, agent       │
│   CLAUDE.md                 ← 스택에 맞는 템플릿       │
│   .claude/setup-guide.html  ← MCP API 설정 가이드      │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  일상 작업                                             │
│                                                        │
│  $ claude                                              │
│  > /plan 인증 추가                                     │
│  > /debug /api/users에서 500                           │
│  > /audit security                                     │
│  > /council 내 DB 마이그레이션 플랜                    │
└────────────────────────────────────────────────────────┘
```

---

## 업데이트

```bash
cd ~/Projects/my-app
# Claude Code 내에서:
> /update-toolkit   # toolkit 콘텐츠
> /update-deps      # 모든 의존성(체크박스 TUI)
```

`/update-deps`는 installed-vs-latest와 함께 전체 TUI 목록을 보여줍니다. 업데이트할 것을 고르고 나머지는 그대로 둡니다.

---

## Claude Desktop

Desktop 사용자는 marketplace로 설치:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

세 개의 서브 플러그인을 받습니다: `tk-skills`(22개 skill), `tk-commands`(29개 명령), `tk-framework-rules`(7개 CLAUDE.md 조각). 자세히: [docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md).

---

## 문제 해결

| 문제                                                | 해결                                                                                       |
|-----------------------------------------------------|--------------------------------------------------------------------------------------------|
| 설치 후 `cc-safety-net: command not found`          | `npm install -g cc-safety-net`, 그 다음 `bash <(curl …/scripts/install-hooks.sh)`          |
| RTK가 명령을 다시 쓰지 않음                         | `~/.claude/settings.json`은 **하나의 결합된** 훅이어야 하지, 둘로 나뉘면 안 됨             |
| Claude가 프로젝트 명령을 못 봄                      | `.claude/`가 있는 같은 폴더에서 `claude`를 재시작                                          |
| safety-net이 필요한 명령을 차단함                   | 일반 터미널에서 수동 실행(또는 일시적으로 `TK_NO_SAFETY=1`)                                |
| 인스톨러가 TUI에서 멈춤                             | `Ctrl-C`로 재시작; macOS `bash` 3.2에서 ↑/↓는 `--no-tui-fallback`이 필요할 수 있음          |
| `setup-guide.html`이 안 열림                        | `open .claude/setup-guide.html`(macOS) / `xdg-open`(Linux). 또는 `/setup-guide` 실행.      |
