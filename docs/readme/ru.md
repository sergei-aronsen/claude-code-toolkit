# Claude Code Toolkit

Исчерпывающий набор инструкций для разработки с AI-ассистентом Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **Русский** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Сначала прочитайте полный [пошаговый мануал по установке](../howto/ru.md).

---

## Для кого это

**Solo-разработчики**, создающие продукты с [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Поддерживаемые стеки: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**30 slash-команд** | **7 аудитов** | **29 гайдов** | Смотрите [полный список команд, шаблонов, аудитов и компонентов](../features.md#slash-commands-30-total).

---

## Быстрый старт

### 1. Глобальная настройка (один раз)

#### a) Security Pack

Многоуровневая защита. Полное руководство — в [components/security-hardening.md](../../components/security-hardening.md).

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Оптимизатор токенов (рекомендуется)

[RTK](https://github.com/rtk-ai/rtk) сокращает потребление токенов на 60-90% на dev-командах (`git status`, `cargo test` и др.).

```bash
brew install rtk
rtk init -g
```

> **Примечание:** Если RTK и cc-safety-net зарегистрированы как отдельные хуки, их результаты конфликтуют.
> Security Pack (шаг 1a) уже настраивает объединённый хук `pre-bash.sh`, который запускает оба последовательно.
> Подробности — в [components/security-hardening.md](../../components/security-hardening.md).

#### c) Rate Limit Statusline (Claude Max / Pro, опционально)

Показывает лимиты сессии/недели в статусбаре Claude Code. Подробнее: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

---

## v6.1 Трёхслойная архитектура

Toolkit v6.1 позиционирует себя как **тонкий overlay** поверх плагинной экосистемы Anthropic
плюс опциональные внешние инструменты. Полная диаграмма — в
[docs/architecture.md](../architecture.md). Для solo-фаундеров и непрограммистов-продуктовиков
смотрите [docs/non-programmer-mode.md](../non-programmer-mode.md) — рекомендованная
конфигурация advisory-хуков, маршрутизации стоимости и reality-check перед шипом.

В v6.1 убран `morph-fast-tools` (закрытый SDK, платный SaaS без публичной политики
конфиденциальности) в пользу [oraios/serena](https://github.com/oraios/serena) — символьный
поиск и редактирование кода через LSP, MIT, работает локально. Дефолтный Layer-3 стек: Serena (символьно),
ripgrep (текстово), claude-context (семантический векторный поиск) и better-model
(маршрутизация стоимости). v6.1 также авто-вшивает `install-hooks.sh` и
`setup-cost-routing.sh` в `init-claude.sh` — отдельный ручной запуск больше не нужен.

---

## Режимы установки

TK автоматически определяет, установлены ли `superpowers` (obra) и `get-shit-done` (gsd-build),
и выбирает один из четырёх режимов: `standalone`, `complement-sp`, `complement-gsd` или
`complement-full`. Каждый шаблон фреймворка документирует требуемые базовые плагины в секции
`## Required Base Plugins` — смотрите, например, [templates/base/CLAUDE.md](../../templates/base/CLAUDE.md).
Полная матрица установки из 12 ячеек и пошаговое руководство — в [docs/INSTALL.md](../INSTALL.md).

### Интерактивная установка (рекомендуется)

Унифицированный установщик показывает TUI-чеклист со всеми компонентами (Toolkit, Security,
RTK, Statusline, Council, Bridges) и позволяет включить каждый отдельно. Запускайте
в обычном терминале (**не** внутри Claude Code) в папке проекта:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

Затем запустите Claude Code в папке проекта. Для будущих обновлений используйте `/update-toolkit`.

### Дополняющая установка (complement)

У Вас установлен один или оба плагина — `superpowers` (obra) и `get-shit-done` (gsd-build).
Установщик автоматически их обнаруживает и пропускает 7 файлов, дублирующих функциональность
SP, сохраняя ~47 уникальных вкладов TK (Council, шаблоны CLAUDE.md по фреймворкам, библиотека
компонентов, cheatsheets, framework-specific skills). Используйте ту же команду установки —
TK сам выберет режим `complement-*`. Чтобы переопределить, передайте `--mode standalone`
(или другое имя режима):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --yes --mode complement-full
```

> **Поведение режимов сегодня.** В `manifest.json` сейчас задокументированы 7 пересечений с SP
> и 0 с GSD. `complement-sp` и `complement-full` пропускают одни и те же 7 файлов;
> `complement-gsd` не пропускает ничего — то есть функционально эквивалентен `standalone`,
> пока GSD-специфичные конфликты не каталогизированы. UX из 4 режимов сохраняется, чтобы
> manifest мог инкрементально помечать GSD-пересечения без переписывания установщика.

### Прямая установка (скриптовая / CI)

Для неинтерактивных контекстов по-прежнему поддерживается `init-claude.sh` — ставит только
toolkit (без промптов Security / Statusline / Council):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

### Установка через marketplace

Для пользователей Claude Desktop тулкит доступен как plugin marketplace. Из вкладки Code
в Desktop используйте slash-команду:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Или из терминала с CLI `claude`:

```bash
claude plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Получите три суб-плагина:

- `tk-skills` — 22 курированных skills (совместимо с Desktop)
- `tk-commands` — 29 slash-команд (только terminal Code)
- `tk-framework-rules` — 7 фрагментов CLAUDE.md по фреймворкам (только terminal Code)

Установка через marketplace **эквивалентна** curl-bash-установке для пользователей
terminal Code. Для пользователей Desktop marketplace — **единственный** путь установки.
Полная матрица возможностей — в [docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md).

### Обновление с v3.x

Пользователям v3.x, установившим SP или GSD после TK, следует запустить
`scripts/migrate-to-complement.sh` — он удалит дубликаты файлов с подтверждением для
каждого и полным резервным копированием перед миграцией. Полная матрица из 12 ячеек
и пошаговое руководство — в [docs/INSTALL.md](../INSTALL.md).

> **Важно:** Шаблон проекта предназначен только для `project/.claude/CLAUDE.md`. Не копируйте
> его в `~/.claude/CLAUDE.md` — этот файл должен содержать только глобальные правила
> безопасности и личные настройки (не более 50 строк). Подробнее — в
> [components/claude-md-guide.md](../../components/claude-md-guide.md).

---

## Killer-фичи

| Фича | Описание |
|------|----------|
| **Self-Learning** | `/learn` сохраняет решения как файлы правил с `globs:` — автозагрузка только для релевантных файлов |
| **Auto-Activation Hooks** | Хук перехватывает промпты, оценивает контекст (ключевые слова, намерение, пути файлов), рекомендует подходящие skills |
| **Knowledge Persistence** | Факты проекта в `.claude/rules/` — автозагрузка каждой сессии, коммит в git, доступно на любом компьютере |
| **Systematic Debugging** | `/debug` применяет 4 фазы: root cause → pattern → hypothesis → fix. Без угадывания |
| **Production Safety** | `/deploy` с пре/пост проверками, `/fix-prod` для хотфиксов, инкрементальные деплои, безопасность воркеров |
| **Supreme Council** | `/council` (глобально) отправляет планы в Gemini + ChatGPT для независимого ревью с persona overlays, content-hash кешем, cost-gate, OpenRouter-фолбэком, ru-локалью и `--format json` выводом. Полный референс: [`docs/COUNCIL.md`](../COUNCIL.md) |
| **Structured Workflow** | 3 обязательные фазы: RESEARCH (только чтение) → PLAN (scratchpad) → EXECUTE (после подтверждения) |
| **Multi-CLI Bridges** | Авто-синхронизация `CLAUDE.md` с `GEMINI.md` Gemini CLI и `AGENTS.md` OpenAI Codex. Детектирует drift, отключается через `--no-bridges`. См. [docs/BRIDGES.md](../BRIDGES.md) |
| **Integrations Catalog** | `--integrations` открывает TUI на 21 MCP-сервер + 8 companion-CLI в 10 категориях (Backend, Payments, Workspace, Project Management и др.). Поштучная установка через `--mcp-only` / `--cli-only`. См. [docs/INTEGRATIONS.md](../INTEGRATIONS.md) |
| **Per-MCP Scope (v5.0)** | Per-row scope-переключатель в TUI интеграций: `[U]` user / `[P]` project / `[L]` local. Project-scope пишет секреты в `<project>/.env` (mode 0600) с авто-`.gitignore`-защитой; `.mcp.json` несёт только `${VAR}`-подстановку. `--mcp-scope=<scope>` для неинтерактивного форс-сета. См. [docs/INTEGRATIONS.md → Per-MCP scope](../INTEGRATIONS.md#per-mcp-scope) |

См. [подробные описания и примеры](../features.md).

---

## MCP-серверы (рекомендуем!)

### Глобально (все проекты)

| Сервер | Назначение |
|--------|------------|
| `context7` | Документация библиотек |
| `playwright` | Автоматизация браузера, UI-тестирование |
| `sequential-thinking` | Пошаговое решение задач |
| `sentry` | Мониторинг ошибок и расследование инцидентов |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### Для каждого проекта (учётные данные)

| Сервер | Назначение |
|--------|------------|
| `dbhub` | Универсальный доступ к БД (PostgreSQL, MySQL, MariaDB, SQL Server, SQLite) |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **Безопасность:** Всегда используйте **пользователя БД только для чтения** — не полагайтесь на флаг `--readonly` в DBHub ([известные обходы](https://github.com/bytebase/dbhub/issues/271)). Серверы для конкретного проекта размещаются в `.claude/settings.local.json` (в .gitignore, безопасно для учётных данных). Полная информация — в [mcp-servers-guide.md](../../components/mcp-servers-guide.md).

---

## Структура после установки

Файлы, помеченные †, конфликтуют с `superpowers` — пропускаются в режимах `complement-sp`
и `complement-full`.

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Главные инструкции (адаптируйте под свой проект)
    ├── settings.json          # Hooks, permissions
    ├── commands/              # Slash-команды
    │   ├── verify.md          # † пропускается в complement-sp/full
    │   ├── debug.md           # † пропускается в complement-sp/full
    │   └── ...
    ├── prompts/               # Аудиты
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Субагенты
    │   ├── code-reviewer.md   # † пропускается в complement-sp/full
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Экспертиза по фреймворкам
    │   └── [framework]/SKILL.md
    ├── rules/                 # Автозагружаемые факты проекта
    └── scratchpad/            # Рабочие заметки
```

---

## Поддерживаемые фреймворки

| Фреймворк | Шаблон | Skills | Автоопределение |
|-----------|--------|--------|-----------------|
| Laravel | ✅ | ✅ | Файл `artisan` |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (без next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## Компоненты

Переиспользуемые секции Markdown для составления собственных файлов `CLAUDE.md`. Компоненты —
ассеты в корне репозитория. Они **не** устанавливаются в `.claude/`; обращайтесь к ним
по абсолютному GitHub-URL.

**Паттерн оркестрации.** Плагин Superpowers предоставляет skills `dispatching-parallel-agents`
и `subagent-driven-development`, реализующие дизайн «лёгкий оркестратор + полнофункциональные
субагенты». В v6.0 standalone-компонент тулкита помечен как deprecated в пользу skills плагина.
