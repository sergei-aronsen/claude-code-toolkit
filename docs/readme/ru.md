# Claude Code Toolkit

Исчерпывающий набор инструкций для AI-assisted разработки с Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](../../README.md)** | **Русский** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

> Сначала прочитайте полный [пошаговый мануал по установке](../howto/ru.md).

---

## Для кого это

**Solo-разработчики**, создающие продукты с [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Поддерживаемые стеки: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 шаблонов** (basic, Laravel, Rails, Next.js, Node.js, Python, Go)

**29 slash-команд** | **7 аудитов** | **30 гайдов** | Смотрите [полный список команд, шаблонов, аудитов и компонентов](../features.md#slash-commands-29-total).

---

## Быстрый старт

### 1. Security Pack (глобально, один раз)

Включает многоуровневую защиту. Смотрите [components/security-hardening.md](../../components/security-hardening.md) для полного руководства.

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

### 2. Установка (для каждого проекта)

Скрипт автоматически определяет фреймворк и копирует соответствующий шаблон.

Выполните в терминале в папке проекта:

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Перезапустите Claude!** Для будущих обновлений используйте команду `/update-toolkit` для переустановки или обновления.

### 3. Rate Limit Statusline (Claude Max / Pro)

Показывает лимиты сессии/недели в статусбаре Claude Code. Подробнее: [components/rate-limit-statusline.md](../../components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

### 4. Supreme Council (мульти-AI ревью, опционально)

Gemini + ChatGPT проверяют ваши планы перед кодингом. Подробнее: [components/supreme-council.md](../../components/supreme-council.md)

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh | bash
```

---

## Killer Features

| Функция | Описание |
|---------|----------|
| **Self-Learning** | `/learn` сохраняет разовые решения; Skill Accumulation автоматически фиксирует повторяющиеся паттерны |
| **Auto-Activation Hooks** | Hook перехватывает промпты, оценивает контекст (ключевые слова, намерение, пути файлов), рекомендует подходящие skills |
| **Knowledge Persistence** | Факты проекта в `.claude/rules/` — автозагрузка каждой сессии, коммит в git, доступно на любом компьютере |
| **Systematic Debugging** | `/debug` применяет 4 фазы: root cause -> pattern -> hypothesis -> fix. Без угадывания |
| **Production Safety** | `/deploy` с пре/пост проверками, `/fix-prod` для хотфиксов, инкрементальные деплои |
| **Supreme Council** | `/council` отправляет планы в Gemini + ChatGPT для независимого ревью перед кодингом |
| **Structured Workflow** | 3 обязательные фазы: RESEARCH (только чтение) -> PLAN (scratchpad) -> EXECUTE (после подтверждения) |

Смотрите [подробные описания и примеры](../features.md).

---

## MCP-серверы (рекомендуем!)

| Сервер | Назначение |
|--------|------------|
| `context7` | Документация библиотек |
| `playwright` | Автоматизация браузера, UI-тестирование |
| `sequential-thinking` | Пошаговое решение задач |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

---

## Структура после установки

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Главные инструкции (адаптируйте под свой проект)
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
    ├── agents/                # Субагенты
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Экспертиза по фреймворкам
    │   └── [framework]/SKILL.md
    ├── scratchpad/            # Рабочие заметки
    └── memory/                # Экспорт MCP-памяти
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
