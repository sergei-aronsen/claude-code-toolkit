---
description: Defines when to use GSD vs Superpowers vs Toolkit overlay — three-layer architecture, no overlap, clear handoffs between layers
globs:
  - "**/*"
---

# Three-Layer Bridge

> Auto-loaded every session. Tells you which layer to invoke for which task. Prevents calling toolkit for things GSD already does (and vice versa).

## The three layers

```text
LAYER 3: TOOLKIT (overlay)
  • /council                 — multi-LLM external review (Gemini + GPT API)
  • /audit + FP-recheck      — code audit with false-positive filter
  • /learn                   — scoped rules writer
  • /vendor-audit            — quarterly external dep review
  • Framework templates      — Laravel/Rails/Python/Go idioms
  • Production observability — Sentry/Posthog/Playwright integration
  • Cost discipline          — mode selection + budget caps

LAYER 2: SUPERPOWERS (Claude Code plugin, obra)
  • brainstorming            — design-first, hard-gate before code
  • test-driven-development  — IRON LAW: no code without failing test
  • verification-before-completion — IRON LAW: no claims without fresh verify
  • systematic-debugging     — scientific method
  • subagent-driven-development — discipline for fan-out
  • dispatching-parallel-agents — parallel orchestration
  • writing-plans + executing-plans
  • using-git-worktrees
  • requesting-code-review + receiving-code-review
  • finishing-a-development-branch

LAYER 1: GSD (Claude Code plugin, gsd-build)
  • /gsd-fast                — trivial fixes, no agents
  • /gsd-quick               — small features, skip optional agents
  • /gsd-plan-phase          — full pipeline with multi-stage verify
  • /gsd-execute-phase       — wave-based parallel execution
  • /gsd-secure-phase        — security audit gates
  • /gsd-debug               — debug session manager
  • /gsd-ship + /gsd-undo    — release + rollback
  • Schema push detection
  • Read injection scanner
  • Coverage gate (REQ-IDs)
```

## Decision tree: which layer for which task

```text
Task                                                Layer
──────────────────────────────────────────────────────────────────
Trivial fix (typo)                                →  GSD (/gsd-fast)
Small feature                                     →  GSD (/gsd-quick)
Big feature (auth, payments, public API)          →  GSD (/gsd-plan-phase) + Toolkit (/council)
Bug investigation                                 →  Superpowers (systematic-debugging)
TDD discipline (write test first)                 →  Superpowers (test-driven-development)
Brainstorm new idea before coding                 →  Superpowers (brainstorming)
Multi-file refactor                               →  GSD (/gsd-plan-phase) + better-model auto-routes Opus
Code search small project                         →  Morph warpgrep
Code search lantern/notebooklm (>100k LOC)        →  claude-context MCP
Edits any project                                 →  Morph Fast Apply via MCP
Security-sensitive change                         →  GSD (/gsd-secure-phase) + Toolkit (/audit security + /council)
Pre-ship reality check                            →  Toolkit (skill: reality-check)
Domain expert second opinion                      →  Toolkit (skill: domain-expert-simulation)
Quarterly external dep review                     →  Toolkit (/vendor-audit)
Production observability setup                    →  Toolkit (skill: production-observability)
Save scoped rule from debugging session           →  Toolkit (/learn)
Verify-before-completion claim                    →  Superpowers (verification-before-completion)
```

## Handoffs between layers

### GSD → Toolkit

After `/gsd-execute-phase` completes (PR 3 hook auto-triggers):

- Toolkit `/audit security` — FP-recheck for code-level issues
- Toolkit `/audit code` — same with code style focus
- For high-stakes: Toolkit `/council` — external Gemini+GPT review

### GSD → Superpowers

GSD's discuss-phase invokes Superpowers `brainstorming` skill internally for design exploration. Don't double-invoke.

After `/gsd-execute-phase`:

- Superpowers `verification-before-completion` MUST run before claiming success
- Don't trust GSD's verifier alone — Superpowers gate is stricter (IRON LAW)

### Superpowers → Toolkit

Superpowers `finishing-a-development-branch` ends with merge decision. Toolkit `reality-check` skill runs AFTER merge to verify product behavior in production.

## Anti-patterns

❌ Using toolkit `/debug` instead of Superpowers `systematic-debugging` (toolkit removed it in v6.0)
❌ Using toolkit `/test` instead of Superpowers `test-driven-development`
❌ Using GSD's verifier as substitute for Superpowers verification-before-completion (different scopes)
❌ Skipping toolkit `/council` on auth/payments because GSD already verified plan
❌ Calling claude-context MCP for codebase <50k LOC (use ripgrep)

## Multi-layer ritual for high-stakes phases

For auth, payments, breaking API:

```text
1. Superpowers brainstorming     (design exploration, hard-gate)
2. GSD /gsd-plan-phase           (formal plan + checker + REQ-IDs)
3. Toolkit /council              (Gemini + GPT external review)
4. GSD /gsd-execute-phase        (atomic commits per task)
5. Superpowers verification      (IRON LAW: fresh verify)
6. Toolkit /audit security       (FP-recheck)
7. GSD /gsd-secure-phase         (final security gate)
8. GSD /gsd-ship                 (with toolkit pre-ship-reality-check hook)
9. Toolkit reality-check skill   (post-ship verification)
```

This is full pipeline. Cost: ~$10-20 Sonnet, ~3 hours wall-clock. Used only for high-stakes — see `rules/cost-discipline.md` for trigger keywords.

## Layer detection

If a layer isn't installed:

- Without GSD: Toolkit gracefully degrades. `/audit` + `/council` work. Recommend installing GSD via `claude plugin install get-shit-done@gsd-build`.
- Without Superpowers: GSD covers most discipline. Recommend installing via `claude plugin install superpowers@claude-plugins-official`.
- Without both: Toolkit standalone (legacy v5 behavior). v6 features still work but require manual workflow.

## Cross-references

- `components/external-tools-recommended.md` — install order across layers
- `rules/cost-discipline.md` — cost-aware mode selection within layers
- `rules/non-programmer-safeguards.md` — pre-ship ritual across layers
