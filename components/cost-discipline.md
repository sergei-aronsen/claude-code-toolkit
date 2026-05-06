# Cost Discipline

> Toolkit + GSD + Superpowers can burn $200-500/month on Anthropic API if used naively. Intentional mode selection cuts that 5-10×.

## The cost layers

| Layer | When charged | Cost driver |
|---|---|---|
| Cold-start | Once per session | System prompt + always-loaded skills |
| Per-orchestrator | Each `/gsd-*` command | Workflow markdown loaded |
| Per-subagent dispatch | Each agent invocation | Agent prompt + tool definitions |
| Subagent fan-out | Each phase plan/execute | 4-10 subagents × file reads |
| Verification gates | Each phase | Multi-stage review (plan-checker, verifier, etc.) |

Most surprising: **subagent fan-out is the biggest cost,** not cold-start. A `/gsd-plan-phase` on a small phase = ~150-250k tokens.

## Mode selection by task size

```text
Trivial fix (typo, 1 line, doc update)     →  /gsd-fast       (~10-30k tokens, ~$0.50)
Small feature (<100 LOC, single concern)   →  /gsd-quick      (~50-100k tokens, ~$1.50)
Big feature (auth, payments, public API)   →  /gsd-plan-phase (~150-250k tokens, ~$4)
Breaking change / migration                →  /gsd-plan-phase + /council (~200-300k tokens, ~$6)
```

## Trigger keywords for force-routing

When you say...

| Keyword | Auto-routes to |
|---|---|
| "опечатка", "typo", "одна строчка" | `/gsd-fast` |
| "маленький фикс", "small fix" | `/gsd-fast` |
| "обновить доку", "doc update" | `/gsd-fast` |
| "поправить лог", "fix log" | `/gsd-quick` |
| "добавить тест", "add test" | `/gsd-quick` |
| "новый endpoint", "new endpoint" | `/gsd-quick` (small) or `/gsd-plan-phase` (with auth) |
| "auth", "payments", "billing", "schema migration" | `/gsd-plan-phase` + `/council` (always) |
| "breaking change", "public API change" | `/gsd-plan-phase` + `/council` (always) |

Toolkit `rules/cost-discipline.md` enforces these triggers via auto-load rule.

## Budget cap protocol

Set monthly budget. When approaching cap, switch tactics:

| Spend (Anthropic) | Action |
|---|---|
| ≤ $100/mo | Use any mode freely |
| $100-300/mo | Default to `/gsd-quick` for ~70% of work, `/gsd-plan-phase` only for high-stakes |
| $300-500/mo | Force `/gsd-fast` for all trivial work; `/gsd-quick` mid-tier; `/gsd-plan-phase` rare |
| > $500/mo | **STOP.** Review last week's transcripts. Likely retrying same task multiple times — root-cause why. |

Track via Anthropic Console → Usage. Toolkit `setup-cost-routing.sh` (PR 5) installs monthly review reminder.

## Subagent routing (Anthropic models)

Use better-model (PR 5 `setup-cost-routing.sh` installs):

```text
Search/grep              →  Haiku 4.5 + low effort       ($1/$5 per Mtok)
Implementation/coding    →  Sonnet 4.6 + medium effort   ($3/$15 per Mtok)
Multi-file refactor      →  Opus 4.7 + xhigh effort      ($5/$25 per Mtok)
Architecture/security    →  Opus 4.7 + max effort        ($5/$25 per Mtok)
```

Default Anthropic UI sends EVERYTHING to Opus = 5-10× overpay.

## Morph Fast Apply for edits

Edit operations through Morph MCP (`mcp__morph-fast-tools__edit_file`):

- ~5-10× cheaper than Claude rewriting full file
- ~10× faster
- Pay-per-use (no subscription)

For projects with frequent edits (GSD heavy users): saves $20-50/month easy.

## Reality check on cost

Before next session, check `/cost` baseline:

```text
/cost            (record N tokens at start)
... do work ...
/cost            (delta = real cost of session)
```

If single phase cost >100k tokens — review whether mode was right. /gsd-plan-phase on trivial task wastes money.

## When NOT to optimize cost

- Critical security review: pay full /gsd-plan-phase + /council
- Payment system change: pay full
- Public API breaking change: pay full
- Migration script affecting users: pay full

Cost discipline ≠ cheaping out on high-stakes work. It's about not paying premium for trivial work.

## Cross-references

- `components/external-tools-recommended.md` — Morph + better-model install
- `rules/cost-discipline.md` (PR 2) — auto-load trigger keywords
- `skills/cost-routing-discipline/SKILL.md` (PR 2) — discipline pattern
