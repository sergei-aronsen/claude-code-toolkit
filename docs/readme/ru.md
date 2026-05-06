# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.2.0-blue.svg)](../../CHANGELOG.md)

**[English](../../README.md)** | **Русский** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Что это

Тонкий overlay поверх [**Superpowers**](https://github.com/obra/superpowers) (брейншторм, сабагенты, TDD, дебаг) и [**Get Shit Done**](https://github.com/gsd-build/get-shit-done) (Spec → Plan → Execute), который закрывает гэпы, остающиеся после этих плагинов для solo-продуктовиков.

**Для:** solo-фаундеров и one-person engineering teams, которые шипят реальные продукты с [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

**Поддерживаемые стеки:** Laravel · Rails · Next.js · Node.js · Python · Go.

## Какие гэпы закрывает

| Гэп                                  | Что добавляет toolkit                                                                                                                              |
|--------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| **Multi-AI валидация планов**        | `/council` — отправляет план в Gemini и ChatGPT параллельно для независимого ревью. Работает через CLI (`gemini`, `codex`) или прямые API-ключи. Persona overlays, кеш по хешу, cost gate, ru locale. |
| **Контекст под фреймворк**           | 7 готовых шаблонов `CLAUDE.md` (base + 6 стеков), авто-определение по `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json`.    |
| **Production safety net**            | `cc-safety-net` блокирует деструктивные команды (`rm -rf /`, `git reset --hard` и т.п.) на PreToolUse — даже через обфускацию. Вшит в установщик.  |
| **Контроль расхода токенов**         | RTK переписывает многословный вывод dev-команд (`git status`, тест-раннеры) — экономия 60-90% токенов. Объединённый хук с `cc-safety-net`.         |
| **Cost routing**                     | `better-model` маршрутизирует простые задачи на дешёвые модели. Авто-устанавливается и интегрируется в lifecycle.                                  |
| **Symbol-aware поиск кода**          | [Serena](https://github.com/oraios/serena) (LSP, MIT, локально) + ripgrep + claude-context (семантический вектор). Дефолтный Layer-3 поиск.        |
| **Multi-CLI bridges**                | Авто-синхронизация `CLAUDE.md` в `GEMINI.md` (Gemini CLI) и `AGENTS.md` (OpenAI Codex). Drift-detection при каждой установке.                      |
| **Каталог интеграций**               | TUI-установщик для 23 MCP-серверов + 8 companion CLI в 10 категориях (Backend / Payments / Workspace / Project Management / …). Скоуп per-row.     |
| **Видимость лимитов (Pro/Max)**      | Statusline показывает session/weekly usage — видно, когда упрёшься в стену.                                                                        |
| **Дашборд зависимостей (v6.2)**      | `/update-deps` — интерактивный TUI со всеми отслеживаемыми зависимостями (Layer 1/2/3) и сравнением installed-vs-latest. Вы выбираете, что обновлять. |

Главная ценность — кураторство. Всё опционально через TUI-чекбоксы при установке — ничего не навязывается.

## Установка

Одна команда. Запускайте в папке проекта в обычном терминале (**не** внутри Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

Установщик показывает TUI-чеклист (Toolkit, Security, RTK, Statusline, Council, Bridges, Integrations) и сам определяет, установлены ли уже `superpowers` и `get-shit-done` — если да, пропускает файлы, которые те плагины уже предоставляют, и ставит только ~47 уникальных вкладов toolkit.

Для пользователей Claude Desktop — установка через marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Полный пошаговый мануал (со скриншотами): [docs/howto/ru.md](../howto/ru.md).

## После установки

| Команда            | Что делает                                                                  |
|--------------------|-----------------------------------------------------------------------------|
| `/update-toolkit`  | Подтянуть свежий контент toolkit в `.claude/`, сохраняя локальные правки.   |
| `/update-deps`     | Открыть дашборд зависимостей (Layer 1/2/3 + MCP). Выбрать, что обновлять.   |
| `/council`         | Отправить план в Gemini + ChatGPT для независимого ревью.                   |
| `/learn`           | Сохранить текущее решение как scoped rule для будущих сессий.               |
| `/audit`           | Запустить один из 7 framework-aware аудитов (security, performance и т.д.). |
| `/debug`           | 4-фазный систематический дебаггер: root-cause → pattern → hypothesis → fix. |

Полный список команд: [docs/features.md](../features.md).

## Архитектура

Toolkit v6.2 — это **тонкий overlay**, организованный в три слоя:

- **Layer 1** — контент toolkit (шаблоны, slash-команды, компоненты, скилы, агенты)
- **Layer 2** — бесплатные базовые плагины (Superpowers, Get Shit Done, ru-text)
- **Layer 3** — опциональные внешние инструменты (cc-safety-net, RTK, Serena, claude-context, better-model)

Полная диаграмма: [docs/architecture.md](../architecture.md).
Для solo-фаундеров и непрограммистов-продуктовиков: [docs/non-programmer-mode.md](../non-programmer-mode.md).

## Каталог MCP-серверов

Установщик `--integrations` (или `/integrations` после первой установки) показывает TUI-чеклист с 24 серверами в 10 категориях. Берёте только то, что нужно проекту — остальное не трогается.

| Категория              | Серверы                                                                                |
|------------------------|----------------------------------------------------------------------------------------|
| **docs-research**      | `context7` · `firecrawl` · `notebooklm`                                                |
| **backend**            | `aws-cloudwatch-logs` · `aws-cost-explorer` · `cloudflare` · `dbhub` · `supabase`      |
| **payments**           | `stripe`                                                                               |
| **email**              | `resend`                                                                               |
| **workspace**          | `calendly` · `notion`                                                                  |
| **project-management** | `jira` · `linear` · `youtrack`                                                         |
| **communication**      | `slack` · `telegram`                                                                   |
| **design**             | `figma`                                                                                |
| **dev-tools**          | `magic` · `openrouter` · `serena` · `claude-context` · `playwright`                    |
| **monitoring**         | `sentry`                                                                               |

Каждый сервер устанавливается с per-row выбором scope (`[U]` user / `[P]` project / `[L]` local). Project-scope пишет credentials в `<project>/.env` (mode 0600) с auto-`.gitignore`; `.mcp.json` несёт только `${VAR}` подстановки. Подробнее — [docs/INTEGRATIONS.md](../INTEGRATIONS.md).

## Лицензия

MIT — см. [LICENSE](../../LICENSE).
