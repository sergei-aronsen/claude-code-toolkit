---
description: Auto-routes natural-language task descriptions to right GSD mode (fast/quick/plan-phase) based on trigger keywords; prevents 5-10× cost overpay on routine work
globs:
  - "**/*"
---

# Cost Discipline (Auto-Routing)

> Auto-loaded every session. Force-routes user requests to appropriate GSD mode based on language patterns.

## Trigger keyword → GSD mode

When user request contains these keywords, default to the corresponding mode:

### Force `/gsd-fast`

- "опечатка", "typo"
- "одна строчка", "single line"
- "поправь точку с запятой", "missing semicolon"
- "обнови README", "update doc"
- "поменяй текст в [file]", "change text in [file]"
- "переименуй переменную", "rename variable"

### Force `/gsd-quick`

- "добавь тест", "add test"
- "поправь баг" (single file), "fix bug"
- "добавь endpoint", "add endpoint"
- "обнови валидацию", "update validation"
- "добавь логирование", "add logging"
- "исправь форматирование", "fix formatting"

### Force `/gsd-plan-phase` + `/council` (red flags)

ANY of these keywords → escalate to full pipeline + external review:

- "auth", "authentication", "authorization"
- "login", "password", "session", "token"
- "payment", "billing", "subscription", "stripe", "paypal"
- "refund", "chargeback"
- "schema migration", "alter table", "drop table"
- "database migration"
- "breaking change", "backward incompatible"
- "public API change", "API v2"
- "encryption", "encrypt", "decrypt", "hash password"
- "secret", "API key", "credential"
- "production hotfix" (urgent + irreversible = highest stakes)

### Force `/gsd-plan-phase` (no council needed)

- "рефакторинг 3+ файлов", "refactor 3+ files"
- "новая фича", "new feature" (without auth/payments keyword)
- "переделать архитектуру", "redesign architecture"
- "интеграция [service]", "integrate [service]"

## Override grammar

User can override defaults:

- "только быстро" / "just quick" → forces `/gsd-fast`
- "сделай нормально" / "do it properly" → forces `/gsd-plan-phase`
- "without council" / "skip council" → omits `/council` step
- "with council" / "и council" → adds `/council` regardless of mode

Respect override — user knows their stakes.

## Anti-pattern detection

Flag and reject these requests:

- "просто запусти gsd-plan-phase для опечатки" — wasteful, suggest `/gsd-fast`
- "пропусти council для auth changes" — UNSAFE, refuse and explain
- "skip tests because it's small" — unsafe, refuse

## Subagent model hints (with better-model installed)

When dispatching subagents, include hints in subagent prompt:

- For search/grep: prepend "Use Haiku, low effort"
- For coding: prepend "Use Sonnet, medium effort"
- For architecture/security: prepend "Use Opus, max effort"

better-model auto-injects these into agent frontmatter, but override is sometimes needed.

## Edit tool hint

If Serena MCP installed (look for `mcp__serena__*` tools):

- Prefer Serena's symbol-level edits for refactors (rename, move,
  replace symbol body) — local LSP, no network round-trips, no token
  cost beyond the agent itself
- Use native Edit for single-line text changes and non-symbolic edits

Morph Fast Apply was removed in v6.1 (closed-source SDK piping code to
paid SaaS). There is no plug-and-play equivalent — native Edit covers
~95% of cases honestly.

## Search tool hint

```text
< 10k LOC                          →  ripgrep + Read
"find all callers of foo"          →  Serena (mcp__serena__*)
"find code that handles auth"      →  claude-context MCP (if installed)
exact-string searches              →  ripgrep
> 100k LOC + frequent queries      →  claude-context MCP
```

## Budget alerts

If user spends >$300/month on Anthropic API:

- Audit: how many `/gsd-plan-phase` invocations? Were all justified?
- Suggest: 70% via `/gsd-quick`, 20% via `/gsd-fast`, 10% via `/gsd-plan-phase` is healthy ratio for solo dev

If >$500/month:

- HARD STOP. Review last 7 days of conversations.
- Likely retrying same task multiple times → root-cause why.

## Cross-references

- `components/cost-discipline.md` — cost layer breakdown
- `skills/cost-routing-discipline/SKILL.md` — routing discipline
- `skills/gsd-mode-selector/SKILL.md` — mode selection
- `commands/vendor-audit.md` — quarterly model + tool review
