# /helpme — Quick Reference Cheatsheet

## Purpose

Display a compact cheatsheet with all available commands, agents, audits, skills, and usage scenarios in the specified language.

---

## Usage

```text
/helpme
/helpme {lang}
```

**Supported languages:** `en`, `ru`, `es`, `de`, `fr`, `zh`, `ja`, `pt`, `ko`

**Examples:**

- `/helpme` — English cheatsheet (default)
- `/helpme ru` — Русская шпаргалка
- `/helpme es` — Guia rapida en espanol
- `/helpme de` — Deutsche Kurzreferenz

---

## Actions

1. Parse the language argument (default: `en`)
2. Validate the language code against supported list: `en`, `ru`, `es`, `de`, `fr`, `zh`, `ja`, `pt`, `ko`
3. Read `cheatsheets/{lang}.md` (from the toolkit repo, installed to `.claude/commands/`)
4. If file not found — fallback to `cheatsheets/en.md`
5. Display the full content of the cheatsheet to the user
6. Do NOT add anything — just output the cheatsheet content as-is
