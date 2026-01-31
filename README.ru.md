# Claude Guides

Исчерпывающий набор инструкций для AI-assisted разработки с Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **Русский** | **[Español](README.es.md)** | **[Deutsch](README.de.md)** | **[Français](README.fr.md)** | **[中文](README.zh.md)** | **[日本語](README.ja.md)** | **[Português](README.pt.md)** | **[한국어](README.ko.md)**

> **Первый раз с Claude Code?** Прочитайте [пошаговый мануал по установке](howto/ru.md).

---

## Для кого это

**Solo-разработчики** которые строят продукты с [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Поддерживаемые стэки: **Laravel/PHP**, **Next.js**, **Node.js**, **Python**, **Go**, **Ruby on Rails**.

Без команды у тебя нет code review, нет кого спросить про архитектуру, некому проверить безопасность. Этот репозиторий закрывает эти gaps:

| Проблема | Решение |
|----------|---------|
| Claude каждый раз забывает правила | `CLAUDE.md` — инструкции которые он читает в начале сессии |
| Нет кого спросить | `/debug` — систематическая отладка вместо гадания |
| Нет code review | `/audit code` — Claude проверяет по чеклисту |
| Нет security review | `/audit security` — SQL injection, XSS, CSRF, auth |
| Забываешь проверить перед деплоем | `/verify` — build, types, lint, tests одной командой |

**Что внутри:** 24 команды, 7 аудитов, 23+ гайдов, templates для всех основных стэков.

---

## Быстрый старт

### Первая установка

Скажи Claude Code:

```text
Скачай инструкции из https://github.com/digitalplanetno/claude-code-toolkit
```

Или выполни в терминале:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

Скрипт автоматически определяет фреймворк (Laravel, Next.js) и копирует соответствующий шаблон.

### После установки / Обновление

Используй команду `/install` для переустановки или обновления:

```text
/install          # авто-определение фреймворка
/install laravel  # принудительно Laravel
/install nextjs   # принудительно Next.js
/install nodejs   # принудительно Node.js
/install python   # принудительно Python
/install go       # принудительно Go
/install rails    # принудительно Ruby on Rails
```

Или через терминал:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

---

## Killer Features

### 1. Self-Learning System

Claude учится на твоих коррекциях и накапливает знания о проекте.

**Два механизма:**

| Механизм | Что делает | Когда использовать |
|----------|------------|-------------------|
| `/learn` | Сохраняет **разовое** решение проблемы | Решил нетривиальную проблему, нашёл workaround |
| **Skill Accumulation** | Накапливает **повторяющиеся** паттерны | Claude заметил что его исправляют 2+ раз |

**Разница:**

```text
/learn  → "Как я решил проблему X"     (one-time fix)
skill   → "Как мы всегда делаем Y"     (project pattern)
```

**Пример /learn:**

```text
> /learn

Analyzing session...
Found: Prisma Serverless Connection Fix

Problem: Connection timeout in Vercel Edge Functions
Solution: Add ?connection_limit=1 to DATABASE_URL

Save to .claude/learned/prisma-serverless.md? → да
```

**Пример Skill Accumulation:**

```text
User: сделай endpoint для users
Claude: [делает endpoint]
User: нет, у нас Zod для валидации и AppError для ошибок

Claude: 💡 Заметил паттерн: endpoints используют Zod + AppError
        Сохранить как skill 'backend-endpoints'?
        Будет активироваться при: endpoint, api, route

User: да

[Следующий раз Claude сразу использует Zod + AppError]
```

### 2. Auto-Activation Hooks

**Проблема:** У тебя 10 skills, но ты забываешь их использовать.

**Решение:** Hook перехватывает промпт **ДО** отправки к Claude и рекомендует загрузить skill.

```text
User prompt → Hook анализирует → Scoring → Рекомендация
```

**Scoring система:**

| Триггер | Очки | Пример |
|---------|------|--------|
| keyword | +2 | "endpoint" в промпте |
| intentPattern | +4 | "создай.*endpoint" |
| pathPattern | +5 | Открыт файл `src/api/*` |

**Пример:**

```text
Prompt: "создай POST endpoint для регистрации"
File: src/api/auth.controller.ts

⚠️ SKILL RECOMMENDATIONS:
🟢 [HIGH] backend-dev (score: 13)
🟢 [HIGH] security-review (score: 12)

👉 Use Skill tool to load guidelines.
```

### 3. Memory Persistence

**Проблема:** MCP память хранится локально. Переехал на другой компьютер — память потеряна.

**Решение:** Экспорт в `.claude/memory/` → коммитится в git → доступно везде.

```text
.claude/memory/
├── knowledge-graph.json   # Связи между компонентами
├── project-context.md     # Контекст проекта
└── decisions-log.md       # Почему приняли решение X
```

**Workflow:**

```text
В начале сессии:    Проверь sync → Загрузи память из MCP
После изменений:    Экспортируй → Закоммить .claude/memory/
На новом компе:     Pull → Импортируй в MCP
```

### 4. Systematic Debugging (/debug)

**Iron Law:**

```text
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

**4 фазы:**

| Фаза | Что делать | Критерий выхода |
|------|------------|-----------------|
| **1. Root Cause** | Читай ошибки, воспроизведи, trace data flow | Понимаю ЧТО и ПОЧЕМУ |
| **2. Pattern** | Найди работающий пример, сравни | Нашёл отличия |
| **3. Hypothesis** | Сформулируй теорию, тестируй ОДНО изменение | Подтверждено |
| **4. Fix** | Напиши тест, исправь, verify | Тесты зелёные |

**Правило трёх fix'ов:**

```text
Если 3+ fix'а не сработали — STOP!
Это не баг. Это архитектурная проблема.
```

### 5. Structured Workflow

**Проблема:** Claude часто "сразу кодит" вместо того чтобы понять задачу.

**Решение:** 3 фазы с явными ограничениями:

| Фаза | Доступ | Что можно |
|------|--------|-----------|
| **RESEARCH** | Read-only | Glob, Grep, Read — понять контекст |
| **PLAN** | Scratchpad-only | Писать план в `.claude/scratchpad/` |
| **EXECUTE** | Full | Только после подтверждения плана |

```text
User: Добавь валидацию email

Claude: Phase 1: RESEARCH
        [Читает файлы, ищет паттерны]
        Нашёл: форма в RegisterForm.tsx, валидация через Zod

        Phase 2: PLAN
        [Создаёт план в .claude/scratchpad/current-task.md]
        План готов. Подтверди для начала.

User: ок

Claude: Phase 3: EXECUTE
        Step 1: Добавляю schema... ✅
        Step 2: Интегрирую в форму... ✅
        Step 3: Тесты... ✅
```

---

## Структура после установки

```text
твой-проект/
└── .claude/
    ├── CLAUDE.md              # Главные инструкции (адаптируй под проект)
    ├── settings.json          # Hooks, permissions
    ├── commands/              # Slash-команды
    │   ├── verify.md
    │   ├── debug.md
    │   └── ...
    ├── prompts/               # Аудиты
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Subagents
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Framework expertise
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # Рабочие заметки
    └── memory/                # Экспорт MCP памяти
```

---

## Что внутри

### Templates (7 вариантов)

| Template | Для чего | Особенности |
|----------|----------|-------------|
| `base/` | Любой проект | Универсальные правила |
| `laravel/` | Laravel + Vue/Inertia | Eloquent, migrations, Blade, Pint |
| `nextjs/` | Next.js + TypeScript | App Router, RSC, Tailwind |
| `nodejs/` | Node.js + Express/Fastify | Zod, Pino, async patterns |
| `python/` | Python + FastAPI/Django | Pydantic v2, SQLAlchemy 2.0 |
| `go/` | Go + Gin/Chi | Goroutines, table-driven tests |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord, Turbo, Stimulus, RSpec |

### Slash-команды (24 штуки)

| Команда | Описание |
|---------|----------|
| `/verify` | Проверка перед коммитом: build, types, lint, tests |
| `/debug [проблема]` | 4-фазная отладка: root cause → hypothesis → fix → verify |
| `/learn` | Сохранить решение проблемы в `.claude/learned/` |
| `/plan` | Создать план в scratchpad перед имплементацией |
| `/audit [type]` | Запустить аудит (security, performance, code, design, database) |
| `/test` | Написать тесты для модуля |
| `/refactor` | Рефакторинг с сохранением поведения |
| `/fix [issue]` | Исправить конкретную проблему |
| `/explain` | Объяснить как работает код |
| `/doc` | Сгенерировать документацию |
| `/context-prime` | Загрузить контекст проекта в начале сессии |
| `/checkpoint` | Сохранить прогресс в scratchpad |
| `/handoff` | Подготовить передачу задачи (summary + next steps) |
| `/worktree` | Управление git worktrees |
| `/install` | Установить claude-guides в проект |
| `/migrate` | Помощь с миграциями БД |
| `/find-function` | Найти функцию по имени/описанию |
| `/find-script` | Найти скрипт в package.json/composer.json |
| `/tdd` | Test-Driven Development workflow |
| `/docker` | Генерация Dockerfile и docker-compose |
| `/api` | Дизайн REST API, генерация OpenAPI |
| `/e2e` | Генерация E2E тестов с Playwright |
| `/perf` | Анализ производительности: N+1, bundle, memory |
| `/deps` | Аудит зависимостей: security, licenses, outdated |

### Аудиты (7 типов)

| Аудит | Файл | Что проверяет |
|-------|------|---------------|
| **Security** | `SECURITY_AUDIT.md` | SQL injection, XSS, CSRF, auth, secrets |
| **Performance** | `PERFORMANCE_AUDIT.md` | N+1, bundle size, caching, lazy loading |
| **Code Review** | `CODE_REVIEW.md` | Паттерны, читаемость, SOLID, DRY |
| **Design Review** | `DESIGN_REVIEW.md` | UI/UX, accessibility, responsive (Playwright MCP) |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema, индексы, slow queries |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements, bloat, connections |
| **Deploy** | `DEPLOY_CHECKLIST.md` | Чеклист перед деплоем |

### Компоненты (23+ гайдов)

| Компонент | Описание |
|-----------|----------|
| `structured-workflow.md` | 3-фазный подход: Research → Plan → Execute |
| `smoke-tests-guide.md` | Минимальные тесты для API (Laravel/Next.js/Node.js) |
| `hooks-auto-activation.md` | Автоактивация skills по контексту промпта |
| `skill-accumulation.md` | Self-learning: Claude накапливает знания о проекте |
| `modular-skills.md` | Progressive disclosure для больших guidelines |
| `spec-driven-development.md` | Спецификации перед кодом |
| `mcp-servers-guide.md` | Рекомендуемые MCP серверы |
| `memory-persistence.md` | Синхронизация MCP памяти с Git |
| `plan-mode-instructions.md` | Think levels: think → think hard → ultrathink |
| `git-worktrees-guide.md` | Параллельная работа над ветками |
| `devops-highload-checklist.md` | Чеклист для highload проектов |
| `api-health-monitoring.md` | Мониторинг API endpoints |
| `bootstrap-workflow.md` | Workflow для нового проекта |
| `github-actions-guide.md` | Шаблоны CI/CD workflows |
| `pre-commit-hooks.md` | Husky, lint-staged, pre-commit |
| `deployment-strategies.md` | Blue-green, canary, rolling updates |

---

## MCP серверы (рекомендуем!)

| Server | Назначение |
|--------|------------|
| `context7` | Документация библиотек |
| `playwright` | Browser automation, UI тестирование |
| `memory-bank` | Память между сессиями |
| `sequential-thinking` | Пошаговое решение задач |
| `memory` | Knowledge Graph (граф связей) |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
```

---

## Rate Limit Statusline (Claude Max / Pro)

Мониторинг лимитов API прямо в статусбаре Claude Code.

```text
25% | 5h:23% (2h57m) | 7d:80% (1d18h)
 │      │      │          │       │
 │      │      │          │       └─ время до сброса недельного лимита
 │      │      │          └─ недельное использование (7-дневное окно)
 │      │      └─ время до сброса сессии
 │      └─ использование сессии (5-часовое окно)
 └─ использование контекстного окна
```

**Цвета:** без цвета (<60%), жёлтый (60-79%), красный (80-89%), ярко-красный (90-100%)

**Требования:** macOS, `jq`, Claude Code с OAuth (подписка Max или Pro)

### Установка

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

Установщик проверяет зависимости, скачивает скрипты в `~/.claude/`, настраивает `settings.json` и запускает первичную проверку.

Подробности и кастомизация: [components/rate-limit-statusline.md](components/rate-limit-statusline.md).

---

## Примеры использования

### /verify — проверка перед коммитом

```text
> /verify

Запускаю проверки...
✅ Build: passed
✅ TypeScript: no errors
⚠️ ESLint: 2 warnings (unused imports)
✅ Tests: 23 passed

Рекомендация: исправить lint warnings перед коммитом.
```

### /debug — систематическая отладка

```text
> /debug API возвращает 500 на /api/users

Phase 1: ROOT CAUSE ANALYSIS
├── Читаю app/api/users/route.ts
├── Проверяю logs
└── Нашёл: prisma.user.findMany() без try/catch

Phase 2: HYPOTHESIS
└── Database connection timeout при холодном старте

Phase 3: FIX
└── Добавляю error handling + retry logic

Phase 4: VERIFY
└── Тестирую endpoint — работает
```

### /audit security — аудит безопасности

```text
> /audit security

SECURITY AUDIT REPORT
=====================

🔴 CRITICAL (1)
├── SQL Injection в UserController:45
└── Рекомендация: использовать prepared statements

🟡 MEDIUM (2)
├── Нет rate limiting на /api/login
└── CORS настроен как Access-Control-Allow-Origin: *

🟢 LOW (1)
└── Debug mode в .env.example
```

---

## Поддерживаемые фреймворки

| Framework | Template | Skills | Auto-detection |
|-----------|----------|--------|----------------|
| Laravel | ✅ Dedicated | ✅ | `artisan` file |
| Next.js | ✅ Dedicated | ✅ | `next.config.*` |
| Node.js | ✅ Dedicated | ✅ | `package.json` (без next.config) |
| Python | ✅ Dedicated | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ Dedicated | ✅ | `go.mod` |
| Ruby on Rails | ✅ Dedicated | ✅ | `bin/rails` / `config/application.rb` |
