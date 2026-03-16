# Начало работы с Claude Code Toolkit

> Полный гайд для новичков: от нуля до продуктивной разработки с Claude Code

**[English](en.md)** | **Русский** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Предусловия

Убедись, что установлены:

- **Node.js** (проверь: `node --version`)
- **Claude Code** (проверь: `claude --version`)

Если Claude Code ещё не установлен:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Два уровня установки

| Уровень | Что | Когда |
|---------|-----|-------|
| **Глобальный** | Security rules + хуки + плагины | Один раз на машину |
| **Проектный** | Команды, скиллы, шаблоны | Один раз на проект |

---

## Шаг 1: Глобальная настройка (один раз на машину)

Ставит security rules, комбинированный хук (safety-net + поддержка RTK) и официальные плагины Anthropic. Делается **один раз**, работает для **всех** проектов.

Открой обычный терминал (не Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

**Что произойдёт:**

- Создастся `~/.claude/CLAUDE.md` — глобальные правила безопасности. Claude Code читает этот файл **при каждом запуске в любом проекте**. Это инструкция: "никогда не делай SQL injection, не используй eval(), спрашивай перед опасными операциями"
- Установится `cc-safety-net` — блокирует деструктивные команды (`rm -rf /`, `git push --force` и т.д.)
- Настроится комбинированный хук в `~/.claude/settings.json` — safety-net и RTK (если установлен) последовательно, без конфликтов
- Включатся официальные плагины Anthropic — code-review, commit-commands, security-guidance, frontend-design

**Проверить что всё встало:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/verify-install.sh)
```

Всё. Глобальная часть готова. Это больше **никогда не нужно повторять**.

---

## Шаг 2: Создай свой проект

Например, Laravel-проект:

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

Или Next.js:

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

Или если проект уже есть — просто перейди в его папку:

```bash
cd ~/Projects/my-app
```

---

## Шаг 3: Установи toolkit в проект

**В обычном терминале** (не внутри Claude Code), из папки проекта, запусти:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Скрипт **автоматически определит** твой фреймворк (Laravel, Next.js, Python, Go и т.д.) и создаст:

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Инструкции для Claude (ПОД ТВОЙ ПРОЕКТ)
    ├── settings.json          ← Настройки, хуки
    ├── commands/              ← 24 слэш-команды
    │   ├── debug.md           ← /debug — системная отладка
    │   ├── plan.md            ← /plan — планирование перед кодом
    │   ├── verify.md          ← /verify — проверка перед коммитом
    │   ├── audit.md           ← /audit — аудит безопасности/перформанса
    │   ├── test.md            ← /test — написание тестов
    │   └── ...                ← ещё ~19 команд
    ├── prompts/               ← Шаблоны аудитов
    ├── agents/                ← Субагенты (code-reviewer, test-writer)
    ├── skills/                ← Экспертиза по фреймворку
    ├── cheatsheets/           ← Шпаргалки (9 языков)
    ├── memory/                ← Память между сессиями
    └── scratchpad/            ← Рабочие заметки
```

**Чтобы указать фреймворк явно:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) laravel
```

---

## Шаг 4: Настрой CLAUDE.md под свой проект

Это самый важный файл. Открой `.claude/CLAUDE.md` в редакторе и заполни:

```markdown
# My App — Claude Code Instructions

## Project Overview
**Framework:** Laravel 12
**Description:** Онлайн-магазин электроники

## Key Directories
app/Services/    — бизнес-логика
app/Models/      — модели Eloquent
resources/js/    — Vue компоненты

## Development Workflow
### Running Locally
composer serve    — запуск сервера
npm run dev       — фронтенд

### Testing
php artisan test

## Project-Specific Rules
1. Все контроллеры используют Form Requests
2. Деньги хранятся в копейках (integer)
3. API возвращает JSON через Resources
```

Claude **читает этот файл при каждом запуске** в этом проекте. Чем лучше заполнишь — тем умнее будет Claude.

---

## Шаг 5: Закоммить .claude в Git

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

Теперь конфигурация сохранена в репозитории. Клонируешь проект на другой компьютер — toolkit уже будет там.

---

## Шаг 6: Запусти Claude Code и работай

```bash
claude
```

Claude Code стартует и автоматически загружает:

1. **Глобальный** `~/.claude/CLAUDE.md` (security rules — из шага 1)
2. **Проектный** `.claude/CLAUDE.md` (твои инструкции — из шага 4)
3. Все команды из `.claude/commands/`

Теперь можешь работать:

```text
> Создай REST API для управления товарами: CRUD, пагинация, поиск
```

---

## Полезные команды внутри Claude Code

| Команда | Что делает |
|---------|------------|
| `/plan` | Сначала думает, потом кодит (Research → Plan → Execute) |
| `/debug проблема` | Системная отладка в 4 фазах |
| `/audit security` | Аудит безопасности |
| `/audit` | Код-ревью |
| `/verify` | Проверка перед коммитом (build + lint + tests) |
| `/test` | Написание тестов |
| `/learn` | Сохранить решение проблемы на будущее |
| `/helpme` | Шпаргалка по всем командам |

---

## Визуальная схема — весь путь

```text
┌─────────────────────────────────────────────────────┐
│  ОДИН РАЗ НА МАШИНУ (Шаг 1)                        │
│                                                     │
│  Terminal:                                          │
│  $ bash <(curl ... setup-security.sh)                │
│                                                     │
│  Результат:                                         │
│  ~/.claude/CLAUDE.md      ← security rules          │
│  ~/.claude/settings.json  ← комбинированный хук     │
│  ~/.claude/hooks/pre-bash.sh ← safety-net + RTK    │
│  cc-safety-net            ← npm package             │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  ДЛЯ КАЖДОГО ПРОЕКТА (Шаги 2-5)                    │
│                                                     │
│  Terminal:                                          │
│  $ cd ~/Projects/my-app                             │
│  $ bash <(curl ... init-claude.sh)                   │
│  $ # отредактируй .claude/CLAUDE.md                 │
│  $ git add .claude/ && git commit                   │
│                                                     │
│  Результат:                                         │
│  .claude/                 ← команды, скиллы,        │
│                              промпты, агенты        │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  РАБОТА (Шаг 6)                                     │
│                                                     │
│  $ claude                                           │
│  > /plan добавить авторизацию                       │
│  > /debug почему 500 на /api/users                  │
│  > /verify                                          │
│  > /audit security                                  │
└─────────────────────────────────────────────────────┘
```

---

## Обновление toolkit

Когда выходят новые команды или шаблоны:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh)
```

Или внутри Claude Code:

```text
> /install
```

---

## Решение проблем

| Проблема | Решение |
|----------|---------|
| `cc-safety-net: command not found` | Запусти `npm install -g cc-safety-net` |
| RTK не реврайтит команды | Убедись что в settings.json один комбинированный хук, не отдельные |
| Claude не видит toolkit | Проверь что `.claude/CLAUDE.md` есть в корне проекта |
| Команды не доступны | Перезапусти `init-claude.sh` или проверь папку `.claude/commands/` |
| safety-net блокирует нормальную команду | Выполни команду вручную в обычном терминале |
