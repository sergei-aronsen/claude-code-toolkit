# Claude Code Toolkit 시작 가이드

> 완전 초보자 가이드: 제로에서 Claude Code를 활용한 생산적인 개발까지

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **한국어**

---

## 사전 요구사항

다음이 설치되어 있는지 확인하세요:

- **Node.js** (확인: `node --version`)
- **Claude Code** (확인: `claude --version`)

Claude Code가 아직 설치되지 않은 경우:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## 두 가지 설정 수준

| 수준 | 내용 | 시기 |
|------|------|------|
| **전역** | 보안 규칙 + safety-net | 머신당 한 번 |
| **프로젝트별** | 명령어, 스킬, 템플릿 | 프로젝트당 한 번 |

---

## 1단계: 전역 설정 (머신당 한 번)

보안 규칙과 safety-net 플러그인을 설치합니다. **한 번만** 수행하면 **모든** 프로젝트에서 작동합니다.

일반 터미널(Claude Code가 아닌)을 여세요:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

**수행되는 작업:**

- `~/.claude/CLAUDE.md`가 생성됩니다 — 전역 보안 규칙입니다. Claude Code는 **모든 프로젝트에서 실행할 때마다** 이 파일을 읽습니다. "SQL 인젝션을 절대 하지 마라, eval()을 사용하지 마라, 위험한 작업 전에 확인하라" 같은 지침입니다
- `cc-safety-net`이 설치됩니다 — 모든 bash 명령어를 가로채고 파괴적인 명령어(`rm -rf /`, `git push --force` 등)를 차단하는 플러그인입니다
- `~/.claude/settings.json`에 훅이 구성됩니다 — Claude Code와 safety-net 간의 연결입니다

**모든 것이 작동하는지 확인:**

```bash
cc-safety-net doctor
```

이것으로 전역 설정이 완료되었습니다. **이 작업을 다시 반복할 필요가 없습니다**.

---

## 2단계: 프로젝트 생성

예를 들어, Laravel 프로젝트:

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

또는 Next.js:

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

또는 이미 프로젝트가 있다면 — 해당 폴더로 이동하세요:

```bash
cd ~/Projects/my-app
```

---

## 3단계: 프로젝트에 Toolkit 설치

**프로젝트 폴더 내에서** 다음을 실행하세요:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

스크립트가 프레임워크(Laravel, Next.js, Python, Go 등)를 **자동으로 감지**하고 다음을 생성합니다:

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Claude를 위한 지침 (프로젝트용)
    ├── settings.json          ← 설정, 훅
    ├── commands/              ← 24개의 슬래시 명령어
    │   ├── debug.md           ← /debug — 체계적인 디버깅
    │   ├── plan.md            ← /plan — 코딩 전 계획 수립
    │   ├── verify.md          ← /verify — 커밋 전 검사
    │   ├── audit.md           ← /audit — 보안/성능 감사
    │   ├── test.md            ← /test — 테스트 작성
    │   └── ...                ← ~19개의 추가 명령어
    ├── prompts/               ← 감사 템플릿
    ├── agents/                ← 서브 에이전트 (code-reviewer, test-writer)
    ├── skills/                ← 프레임워크 전문 지식
    ├── cheatsheets/           ← 치트시트 (9개 언어)
    ├── memory/                ← 세션 간 메모리
    └── scratchpad/            ← 작업 노트
```

**프레임워크를 명시적으로 지정하려면:**

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash -s -- laravel
```

---

## 4단계: 프로젝트에 맞게 CLAUDE.md 구성

이것이 가장 중요한 파일입니다. 에디터에서 `.claude/CLAUDE.md`를 열고 내용을 채우세요:

```markdown
# My App — Claude Code Instructions

## Project Overview
**Framework:** Laravel 12
**Description:** Online electronics store

## Key Directories
app/Services/    — business logic
app/Models/      — Eloquent models
resources/js/    — Vue components

## Development Workflow
### Running Locally
composer serve    — start server
npm run dev       — frontend

### Testing
php artisan test

## Project-Specific Rules
1. All controllers use Form Requests
2. Money is stored in cents (integer)
3. API returns JSON via Resources
```

Claude는 이 프로젝트에서 **실행할 때마다 이 파일을 읽습니다**. 더 잘 작성할수록 — Claude가 더 똑똑해집니다.

---

## 5단계: .claude를 Git에 커밋

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

이제 구성이 저장소에 저장됩니다. 다른 머신에서 프로젝트를 클론하면 — 툴킷이 이미 포함되어 있습니다.

---

## 6단계: Claude Code 실행 및 작업

```bash
claude
```

Claude Code가 시작되면 자동으로 다음을 로드합니다:

1. **전역** `~/.claude/CLAUDE.md` (보안 규칙 — 1단계에서 설정)
2. **프로젝트** `.claude/CLAUDE.md` (프로젝트 지침 — 4단계에서 설정)
3. `.claude/commands/`의 모든 명령어

이제 작업을 시작할 수 있습니다:

```text
> Create a REST API for product management: CRUD, pagination, search
```

---

## Claude Code 내에서 유용한 명령어

| 명령어 | 기능 |
|--------|------|
| `/plan` | 먼저 생각하고, 그 다음 코딩 (조사 -> 계획 -> 실행) |
| `/debug problem` | 4단계 체계적 디버깅 |
| `/audit security` | 보안 감사 |
| `/audit` | 코드 리뷰 |
| `/verify` | 커밋 전 검사 (빌드 + 린트 + 테스트) |
| `/test` | 테스트 작성 |
| `/learn` | 나중에 참고할 수 있도록 문제 해결 방법 저장 |
| `/helpme` | 모든 명령어 치트시트 |

---

## 시각적 개요 - 전체 경로

```text
┌─────────────────────────────────────────────────────┐
│  ONCE PER MACHINE (Step 1)                          │
│                                                     │
│  Terminal:                                          │
│  $ curl ... setup-security.sh | bash                │
│                                                     │
│  Result:                                            │
│  ~/.claude/CLAUDE.md      ← security rules          │
│  ~/.claude/settings.json  ← safety-net hook         │
│  cc-safety-net            ← npm package             │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  FOR EACH PROJECT (Steps 2-5)                       │
│                                                     │
│  Terminal:                                          │
│  $ cd ~/Projects/my-app                             │
│  $ curl ... init-claude.sh | bash                   │
│  $ # edit .claude/CLAUDE.md                         │
│  $ git add .claude/ && git commit                   │
│                                                     │
│  Result:                                            │
│  .claude/                 ← commands, skills,       │
│                              prompts, agents        │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  WORK (Step 6)                                      │
│                                                     │
│  $ claude                                           │
│  > /plan add authentication                         │
│  > /debug why 500 on /api/users                     │
│  > /verify                                          │
│  > /audit security                                  │
└─────────────────────────────────────────────────────┘
```

---

## 툴킷 업데이트

새로운 명령어나 템플릿이 출시되면:

```bash
cd ~/Projects/my-app
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

또는 Claude Code 내에서:

```text
> /install
```

---

## 문제 해결

| 문제 | 해결 방법 |
|------|-----------|
| `cc-safety-net: command not found` | `npm install -g cc-safety-net` 실행 |
| Claude가 툴킷을 감지하지 못함 | 프로젝트 루트에 `.claude/CLAUDE.md`가 있는지 확인 |
| 명령어를 사용할 수 없음 | `init-claude.sh`를 다시 실행하거나 `.claude/commands/` 폴더 확인 |
| safety-net이 정상적인 명령어를 차단함 | Claude Code 외부의 터미널에서 해당 명령어를 수동으로 실행 |
