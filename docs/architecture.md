# Toolkit Architecture (v6.0)

This document explains the three-layer model TK adopts in v6.0. If you are using TK without GSD or Superpowers, you can ignore this — TK still works standalone — but you'll get more out of it once both base plugins are installed.

## Layer diagram

```text
┌─────────────────────────────────────────────────────────┐
│  Layer 1 — Toolkit (this repo)                          │
│  Overlay on the two base plugins.                       │
│                                                         │
│  • CLAUDE.md framework templates (laravel/rails/...)    │
│  • Audit prompts (CODE_REVIEW, SECURITY_AUDIT, ...)     │
│  • Skills: cost-routing, reality-check, council-*,      │
│    domain-expert-simulation, gsd-mode-selector,         │
│    production-observability, ...                        │
│  • Rules: cost-discipline, three-layer-bridge,          │
│    non-programmer-safeguards                            │
│  • Hooks: pre-gsd-plan-council, post-gsd-phase-audit,   │
│    pre-ship-reality-check, cost-warning                 │
│  • Supreme Council (multi-AI plan validator)            │
│  • Bridges: GEMINI.md / AGENTS.md sync from CLAUDE.md   │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │ depends on (soft)
                          │
┌─────────────────────────┴───────────────────────────────┐
│  Layer 2 — Base plugins (Anthropic ecosystem)           │
│                                                         │
│  • superpowers (obra) — discipline skills:              │
│      brainstorming, TDD, verification-before-completion │
│      systematic-debugging, subagent-driven-development, │
│      dispatching-parallel-agents, executing-plans,      │
│      writing-plans, using-git-worktrees,                │
│      requesting/receiving-code-review,                  │
│      finishing-a-development-branch, writing-skills     │
│                                                         │
│  • get-shit-done (gsd-build) — phase workflow:          │
│      /gsd-fast, /gsd-quick, /gsd-plan-phase,            │
│      /gsd-execute-phase, /gsd-debug, /gsd-ship,         │
│      /gsd-secure-phase, /gsd-audit-review               │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │ optionally augmented by
                          │
┌─────────────────────────┴───────────────────────────────┐
│  Layer 3 — External tools (paid / opt-in)               │
│                                                         │
│  • morph-fast-tools — Fast Apply diffs +                │
│    warpgrep_codebase_search (token-efficient edits)     │
│  • claude-context — vector-DB code search via Milvus    │
│    + OpenAI/Voyage embeddings (100k+ LOC codebases)     │
│  • better-model — model routing (Sonnet 60% / Opus      │
│    architecture / Haiku trivial); installed via         │
│    scripts/setup-cost-routing.sh                        │
│  • Sentry / Posthog / Playwright — production           │
│    observability (reality-check skill prerequisite)     │
└─────────────────────────────────────────────────────────┘
```

## Why layers

Three reasons drove the v6.0 redesign:

1. **No re-implementation.** GSD already covers the phase workflow. Superpowers already covers TDD, debugging, and worktree discipline. v5.x had its own `/plan` command, its own `testing` skill, its own `/debug` — and they conflicted with the base plugins (`code-reviewer` agent collision, identical skill triggers). PR 1 of v6.0 deleted 28k lines of duplication. The remainder is a true overlay.

2. **Vendor risk control.** Each base plugin or external tool can disengage, change license, or get acquired. Layered architecture means TK can swap any layer-2 plugin or layer-3 tool without rewriting layer 1. `/vendor-audit` runs quarterly to surface drift early.

3. **Cost discipline.** Each layer has different cost characteristics. Layer 1 (TK) is free + local. Layer 2 (plugins) is free but consumes tokens. Layer 3 (Morph, claude-context, better-model) costs real money but pays back via reduced token spend. The cost-routing skill lives in layer 1 because it's the routing decision, not the engine.

## How layers compose at runtime

| Phase | Layer | Component |
|---|---|---|
| User types `/gsd-plan-phase add OAuth` | 2 (GSD) | parses `/gsd-plan-phase` slash command |
| TK hook fires | 1 (TK) | `tk-pre-gsd-plan-council.sh` detects "OAuth" → suggests `/council` |
| Plan generated | 2 (SP) | `writing-plans` skill activates |
| `/council` runs | 1 (TK) | multi-AI plan validation (Gemini + ChatGPT) |
| Execute phase | 2 (GSD) | `/gsd-execute-phase` + `executing-plans` skill |
| Edits applied | 3 (Morph) | `mcp__morph-fast-tools__edit_file` (token-efficient) |
| Phase finishes | 1 (TK) | `tk-post-gsd-phase-audit.sh` suggests `/audit security && /audit code` |
| `/gsd-ship` invoked | 1 (TK) | `tk-pre-ship-reality-check.sh` reminds Playwright + Sentry |

Each layer can be replaced independently. If GSD breaks tomorrow, swap to pure SP + `/gsd-plan-phase`-equivalent slash command derived from SP `writing-plans` skill. If Morph rate-limits, fall back to native Edit. If TK hooks misfire, `export TK_HOOKS_DISABLE=1`.

## Standalone mode

TK still installs without SP or GSD. In standalone mode:

- All layer-1 content installs normally
- Hooks still register (they fail-open if they detect non-GSD context)
- Cost-routing still works (it's CLAUDE.md text, not plugin glue)
- Reality-check still works (it's a skill, not a hook)
- Supreme Council still works (it's a separate Python orchestrator)

The degraded experience is the absence of the GSD phase workflow and SP discipline skills — TK does not re-implement them.

## See also

- `components/three-layer-bridge.md` — when each layer activates
- `components/external-tools-recommended.md` — install matrix per project size
- `components/vendor-risk.md` — dependency review methodology
- `docs/non-programmer-mode.md` — recommended setup for non-programmer profile
- `.planning/v6.0-REQUIREMENTS.md` — REQ V6-01..07
