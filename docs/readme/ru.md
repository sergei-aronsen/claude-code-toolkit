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

Многоуровневая защита. Смотрите [components/security-hardening.md](../../components/security-hardening.md) для полного руководства.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Оптимизатор токенов (рекомендуется)

[RTK](https://github.com/rtk-ai/rtk) сокращает потребление токенов на 60-90% на dev-командах (`git status`, `cargo test` и др.).

```bash
brew install rtk
rtk init -g
```

> **Примечание:** Если RTK и cc-safety-net — отдельные хуки, их результаты конфликтуют.
> Security Pack (шаг 1a) уже настраивает объединённый хук, который запускает оба последовательно.
> Смотрите [components/security-hardening.md](../../components/security-hardening.md) для деталей.

#### c) Rate Limit Statusline (Claude Max / Pro, опционально)

Показывает лимиты сессии/недели в статусбаре Claude Code. Подробнее: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

## Режимы установки

TK автоматически определяет, установлены ли `superpowers` (obra) и `get-shit-done` (gsd-build), и
выбирает один из четырёх режимов: `standalone`, `complement-sp`, `complement-gsd` или `complement-full`.
Каждый шаблон фреймворка документирует необходимые базовые плагины в `## Required Base Plugins` — смотрите,
например, [templates/base/CLAUDE.md](../../templates/base/CLAUDE.md). Полная матрица установки из 12 ячеек
и пошаговое руководство — в [docs/INSTALL.md](../INSTALL.md).

### Самостоятельная установка

У Вас не установлены `superpowers` и `get-shit-done` (или Вы сознательно от них отказались).
TK устанавливает все 54 файла — полный набор по умолчанию. Выполните в обычном терминале
(не внутри Claude Code!) в папке проекта:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Затем запустите Claude Code в папке проекта. Для будущих обновлений используйте `/update-toolkit`.

### Дополняющая установка

У Вас установлен один или оба плагина — `superpowers` (obra) и `get-shit-done` (gsd-build). TK
автоматически определяет их и пропускает 7 файлов, которые дублируют функциональность SP, сохраняя ~47
уникальных компонентов TK (Council, шаблоны CLAUDE.md по фреймворкам, библиотека компонентов,
cheatsheets, skills по фреймворкам). Используйте ту же команду установки — TK автоматически выберет
режим `complement-*`. Чтобы переопределить режим, передайте `--mode standalone` (или другое имя режима):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

### Обновление с v3.x

Пользователям v3.x, установившим SP или GSD после TK, следует запустить `scripts/migrate-to-complement.sh`,
чтобы удалить дубликаты файлов с подтверждением для каждого файла и полным резервным копированием
перед миграцией. Полная матрица из 12 ячеек и пошаговое руководство — в [docs/INSTALL.md](../INSTALL.md).

> **Важно:** Шаблон проекта предназначен только для `project/.claude/CLAUDE.md`. Не копируйте его
> в `~/.claude/CLAUDE.md` — этот файл должен содержать только глобальные правила безопасности и
> личные настройки (не более 50 строк). Смотрите [components/claude-md-guide.md](../../components/claude-md-guide.md)
> для деталей.

---

## Killer Features

| Функция | Описание |
|---------|----------|
| **Self-Learning** | `/learn` сохраняет решения как файлы правил с `globs:` — автозагрузка только для релевантных файлов |
| **Auto-Activation Hooks** | Хук перехватывает промпты, оценивает контекст (ключевые слова, намерение, пути файлов), рекомендует подходящие skills |
| **Knowledge Persistence** | Факты проекта в `.claude/rules/` — автозагрузка каждой сессии, коммит в git, доступно на любом компьютере |
| **Systematic Debugging** | `/debug` применяет 4 фазы: root cause → pattern → hypothesis → fix. Без угадывания |
| **Production Safety** | `/deploy` с пре/пост проверками, `/fix-prod` для хотфиксов, инкрементальные деплои, безопасность воркеров |
| **Supreme Council** | `/council` отправляет планы в Gemini + ChatGPT для независимого ревью перед кодингом |
| **Structured Workflow** | 3 обязательные фазы: RESEARCH (только чтение) → PLAN (scratchpad) → EXECUTE (после подтверждения) |

Смотрите [подробные описания и примеры](../features.md).

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
| `dbhub` | Универсальный доступ к базам данных (PostgreSQL, MySQL, MariaDB, SQL Server, SQLite) |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **Безопасность:** Всегда используйте **пользователя БД только для чтения** — не полагайтесь на флаг `--readonly` в DBHub ([известные обходы](https://github.com/bytebase/dbhub/issues/271)). Серверы для конкретного проекта размещаются в `.claude/settings.local.json` (в .gitignore, безопасно для учётных данных). Смотрите [mcp-servers-guide.md](../../components/mcp-servers-guide.md) для полной информации.

---

## Структура после установки

Файлы, помеченные †, конфликтуют с `superpowers` — пропускаются в режимах `complement-sp` и `complement-full`.

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Главные инструкции (адаптируйте под свой проект)
    ├── settings.json          # Hooks, permissions
    ├── commands/              # Slash-команды
    │   ├── verify.md          # † пропущено в complement-sp/full
    │   ├── debug.md           # † пропущено в complement-sp/full
    │   └── ...
    ├── prompts/               # Аудиты
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Субагенты
    │   ├── code-reviewer.md   # † пропущено в complement-sp/full
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
|-----------|--------|--------|----------------|
| Laravel | ✅ | ✅ | Файл `artisan` |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (без next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |

---

## Компоненты

Переиспользуемые секции Markdown для составления пользовательских файлов `CLAUDE.md`. Компоненты — это
активы в корне репозитория — они **не** устанавливаются в `.claude/`; обращайтесь к ним по абсолютному URL на GitHub.

**Паттерн оркестрации** — смотрите [components/orchestration-pattern.md](../../components/orchestration-pattern.md)
для описания архитектуры «лёгкий оркестратор + полнофункциональные субагенты», которую используют как Council,
так и рабочие процессы GSD. Помогает любой slash-команде масштабироваться за пределы одного контекстного окна.
