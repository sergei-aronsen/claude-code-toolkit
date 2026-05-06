---
name: cost-routing-discipline
description: Use when starting any new task to select the right GSD mode (fast/quick/plan-phase) and the right model tier (Haiku/Sonnet/Opus) for subagents — prevents 5-10× cost overpay on routine work
---

# Cost Routing Discipline

## Why this skill exists

Default Anthropic UI sends everything to Opus 4.7 + max effort. This is correct for architecture but 5-10× overpay for grep, file-search, and routine coding. Without discipline, monthly cost is $300-500 for a solo dev. With discipline, same work costs $50-100.

## When this skill activates

- Before invoking `/gsd-*` commands — match mode to task risk
- Before dispatching subagents — match model to task type
- When user describes a task — auto-route based on keywords

## Mode selection

```text
Task                                          Mode
─────────────────────────────────────────────────────────────
Trivial (typo, 1 line, doc update)         →  /gsd-fast
Small feature (<100 LOC, single concern)   →  /gsd-quick
Big feature (auth, payments, public API)   →  /gsd-plan-phase
Breaking change / migration                →  /gsd-plan-phase + /council
```

## Trigger keywords (force-route)

| Keyword | Auto-route to |
|---|---|
| "опечатка", "typo", "одна строчка" | `/gsd-fast` |
| "обновить доку", "doc update" | `/gsd-fast` |
| "добавить тест", "add test" | `/gsd-quick` |
| "новый endpoint", "new endpoint" | `/gsd-quick` (small) or `/gsd-plan-phase` (with auth) |
| "auth", "payments", "schema migration" | `/gsd-plan-phase` + `/council` (always) |

## Subagent model routing

When dispatching subagents (via better-model installed):

```text
Task type                              Model              Effort
──────────────────────────────────────────────────────────────────
Search / grep / pattern match        →  Haiku 4.5         low
Implementation / coding (1-2 files)  →  Sonnet 4.6        medium
Test writing                         →  Sonnet 4.6        medium
Single-file debug                    →  Sonnet 4.6        medium
Multi-file refactor (3+)             →  Opus 4.7          xhigh
Cross-file debug                     →  Opus 4.7          xhigh
Architecture design                  →  Opus 4.7          max
Security audit                       →  Opus 4.7          max
Code review                          →  Opus 4.7          xhigh (max overthinks)
Novel algorithm                      →  Opus 4.7          max
```

## Edit operations

If Serena MCP installed (look for `mcp__serena__*` tools):

- Use Serena's symbol-level operations (`replace_symbol_body`,
  `insert_before_symbol`, `insert_after_symbol`, `rename_symbol`) for
  refactoring — local LSP, no network round-trips, dramatically fewer
  tokens than full-file rewrites
- Use native Edit for plain-text single-line changes

Morph Fast Apply was removed in v6.1 (no public source repo for the SDK,
paid SaaS with no privacy guarantee). There is no plug-and-play
equivalent — native Edit covers ~95% of cases honestly.

## Discovery operations

```text
"find function/symbol/all callers of foo" →  Serena (mcp__serena__*)
"find code that does X" semantically       →  claude-context MCP (>100k LOC)
exact-string search                        →  ripgrep
small project (<10k LOC)                   →  ripgrep + Read
big project (>100k LOC) + frequent queries →  claude-context MCP
```

## Budget reality check

Track via Anthropic Console → Usage:

```text
≤ $100/mo   →  use any mode freely
$100-300/mo →  default to /gsd-quick for ~70% of work
$300-500/mo →  force /gsd-fast for trivial; /gsd-quick mid-tier
> $500/mo   →  STOP. Audit last week's transcripts. Likely retrying same task multiple times.
```

## Anti-patterns

- ❌ Using `/gsd-plan-phase` for typo fixes (waste $4 per typo)
- ❌ Sending grep tasks to Opus (waste 5× on each search)
- ❌ Using native Edit when Morph available (waste 10× on each edit)
- ❌ "Just one more iteration" — if cost >$10 on single task, root-cause why
- ❌ Avoiding `/gsd-plan-phase` on auth/payments to save money (wrong place to cheap out)

## When NOT to optimize

Pay full price for:

- Security-relevant changes (auth, crypto, file uploads)
- Payment processing
- Public API breaking changes
- Database migrations on prod data
- Multi-week features touching 10+ files

Cost discipline ≠ cheaping out on high-stakes work.

## Cross-references

- `components/cost-discipline.md` — full cost layer breakdown
- `components/external-tools-recommended.md` — Morph + better-model install
- `rules/cost-discipline.md` — auto-load trigger keywords
- `scripts/setup-cost-routing.sh` (PR 5) — better-model installer
