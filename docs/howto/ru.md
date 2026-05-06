# Установка и работа с Claude Code Toolkit

> Полный путь от нуля до продуктивной разработки с Claude Code в одном месте.

**[English](en.md)** | **Русский** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Предусловия

Убедись, что установлены:

- **Node.js** — `node --version` (рекомендуется 20.x или новее)
- **Claude Code** — `claude --version`
- **git** — для коммита `.claude/` в репозиторий
- **jq** — нужен установщику для merge `settings.json` (`brew install jq` / `apt install jq`)

Если Claude Code ещё не установлен:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Установка

Зайди в папку проекта в **обычном терминале** (не внутри Claude Code) и запусти:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

Установщик откроет TUI-чеклист со всеми компонентами:

```text
[x] toolkit              ← контент toolkit (.claude/ в проекте)
[x] security             ← глобальный security pack + cc-safety-net
[ ] rtk                  ← переписывание dev-команд (-60-90% токенов)
[ ] statusline           ← session/weekly usage в статусбаре
[ ] council              ← /council = Gemini + ChatGPT валидация планов
[ ] gemini-bridge        ← авто-sync CLAUDE.md → GEMINI.md
[ ] codex-bridge         ← авто-sync CLAUDE.md → AGENTS.md
[ ] mcp-servers (24)     ← TUI-чеклист интеграций (Stripe, Sentry, dbhub, …)
[ ] skills (22)          ← marketplace-скиллы (i18n, shadcn, stripe, …)
```

`Space` — переключить, `↑/↓` — двигаться, `Enter` — поставить отмеченное.

Установщик сам определит фреймворк (Laravel, Next.js, Python, Go и т.д.) по характерным файлам и поставит подходящий шаблон `CLAUDE.md`. Если уже стоят `superpowers` и `get-shit-done` — toolkit пропустит файлы, которые те плагины уже предоставляют, и поставит только ~47 уникальных вкладов.

В конце откроется локальная HTML-страница `.claude/setup-guide.html` с пошаговыми инструкциями для каждого установленного MCP (получить API-ключ, поставить env-переменную, протестировать).

---

## Закоммить и работать

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code стартует и автоматически загружает:

1. Глобальный `~/.claude/CLAUDE.md` (security-правила — поставлены установщиком)
2. Проектный `CLAUDE.md` (под твой стек — поставлен установщиком, можно дописать project-specific детали)
3. Все команды из `.claude/commands/` и скиллы из marketplace

---

## Полезные команды

| Команда            | Что делает                                                                  |
|--------------------|-----------------------------------------------------------------------------|
| `/update-toolkit`  | Подтянуть свежий контент toolkit, сохраняя локальные правки `CLAUDE.md`.    |
| `/update-deps`     | Дашборд зависимостей (Layer 1/2/3 + MCP). Выбрать, что обновлять.           |
| `/council план`    | Отправить план в Gemini + ChatGPT для независимого ревью.                   |
| `/learn`           | Сохранить решение как scoped rule для будущих сессий.                       |
| `/audit security`  | Один из 7 framework-aware аудитов.                                          |
| `/debug проблема`  | 4-фазный систематический дебаггер.                                          |
| `/setup-guide`     | Перегенерировать локальную HTML-инструкцию по настройке.                    |
| `/helpme`          | Полная шпаргалка по командам.                                               |

---

## Визуальная схема

```text
┌────────────────────────────────────────────────────────┐
│  УСТАНОВКА (один раз на проект)                        │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → TUI-чеклист → Space/Enter                           │
│                                                        │
│  Результат:                                            │
│   ~/.claude/CLAUDE.md       ← security rules           │
│   .claude/                  ← команды, скиллы, agents  │
│   CLAUDE.md                 ← шаблон под стек          │
│   .claude/setup-guide.html  ← инструкция для MCP-API   │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  ЕЖЕДНЕВНАЯ РАБОТА                                     │
│                                                        │
│  $ claude                                              │
│  > /plan добавить авторизацию                          │
│  > /debug 500 на /api/users                            │
│  > /audit security                                     │
│  > /council мой план миграции БД                       │
└────────────────────────────────────────────────────────┘
```

---

## Обновление

```bash
cd ~/Projects/my-app
# Внутри Claude Code:
> /update-toolkit   # контент toolkit
> /update-deps      # все зависимости (TUI с галочками)
```

Полный TUI-список с installed-vs-latest показывает `/update-deps`. Можно выбрать конкретные компоненты, остальные не трогать.

---

## Claude Desktop

Для Desktop-пользователей установка через marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Получишь три суб-плагина: `tk-skills` (22 скилла), `tk-commands` (29 команд), `tk-framework-rules` (7 фрагментов CLAUDE.md). Подробности — [docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md).

---

## Решение проблем

| Проблема                                          | Решение                                                                                   |
|---------------------------------------------------|-------------------------------------------------------------------------------------------|
| `cc-safety-net: command not found` после установки | `npm install -g cc-safety-net`, затем `bash <(curl …/scripts/install-hooks.sh)`           |
| RTK не реврайтит команды                          | В `~/.claude/settings.json` должен быть **один комбинированный** хук, не два отдельных     |
| Claude не видит проектные команды                 | Перезапусти `claude` из той же папки, где лежит `.claude/`                                |
| safety-net блокирует нужную команду               | Выполни её руками в обычном терминале (или временно `TK_NO_SAFETY=1`)                     |
| Установщик завис в TUI                            | `Ctrl-C`, перезапусти; на macOS `bash` 3.2 ↑/↓ требуют `--no-tui-fallback`                |
| Не открывается setup-guide.html                   | `open .claude/setup-guide.html` (macOS) / `xdg-open` (Linux). Или вызови `/setup-guide`.  |
