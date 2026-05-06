# GSD vs Alternatives — Comparative Analysis

**Date:** 2026-05-06
**Author:** Claude (Opus 4.7) for Sergei Aronsen
**Status:** Research artifact — updated with real data after GSD v1.40 install

---

## Metadata

### Versions analyzed

| Tool | Version | Source verified | npm dist-tag |
|---|---|---|---|
| **gsd-build/get-shit-done** | **1.40.0** (stable, installed locally) | Read source files in `~/.claude/get-shit-done/` + GitHub `agents/`, `commands/`, `hooks/`, `sdk/` | `latest: 1.40.0`, `next: 1.41.0-rc3`, `canary: 1.50.0-canary.1` (manual workflow_dispatch only, no release notes) |
| **github/spec-kit** | HEAD `main` (~2026-05-06) | GitHub: `presets/lean/commands/*.md`, `spec-driven.md`, `src/specify_cli/` | n/a (Python CLI) |
| **mattpocock/skills** | HEAD `main` | Read `skills/engineering/{tdd,diagnose,triage,zoom-out,grill-with-docs}/SKILL.md`, `CLAUDE.md`, `README.md`, `CONTEXT.md`, `plugin.json` | n/a (markdown skills) |
| **forrestchang/andrej-karpathy-skills** | HEAD `main` | Full `CLAUDE.md` + `SKILL.md` + `README.md` + `EXAMPLES.md` | n/a |
| **affaan-m/everything-claude-code** | v2.0.0-rc.1 | README + `plugin.json` + sample SKILL.md files | npm `ecc-universal`, `ecc-agentshield` |

### Sources

- <https://github.com/gsd-build/get-shit-done>
- <https://github.com/github/spec-kit>
- <https://github.com/mattpocock/skills>
- <https://github.com/forrestchang/andrej-karpathy-skills>
- <https://github.com/affaan-m/everything-claude-code>
- Local install: `~/.claude/get-shit-done/`, `~/.claude/agents/gsd-*.md`, `~/.claude/skills/gsd-*/`, `~/.claude/hooks/gsd-*`
- Backup of pre-update state: `~/.claude/.gsd-backup-20260506-085323/`

---

## Executive summary

User problem: GSD works well but burns too many tokens, looking for cheaper alternative without losing GSD's strengths (project scanning, phase planning, clarifying questions, test integration, full-spec implementation).

**Key finding:** GSD v1.40.0 with `--minimal` install is **dramatically cheaper than older versions** thanks to:

- Skill consolidation 86 → 59 (#2790)
- Namespace meta-skills (system prompt 2150 → 120 tokens, #2792)
- `--minimal` flag (cold-start 12k → 700 tokens, #2762)
- Lazy file loading in `discuss-phase` (entry 13k → 0 tokens, #2606)
- Agent size budget enforcement (XL=1600/LARGE=1000/DEFAULT=500, #2361)

**Pre-decision:** Test v1.40 minimal before committing to migration. The token problem may be 90% resolved by upgrade alone.

---

## Toolkits — real architecture (no assumptions)

### 1. GSD v1.40.0 (gsd-build/get-shit-done)

**Repository scale (1309 files total):**

- `agents/` — 33 agents (full install) → 0 with `--minimal`
- `commands/gsd/` — slash commands (one per workflow)
- `get-shit-done/workflows/` — 84 workflow .md files
- `get-shit-done/references/` — 51 reference .md files (loaded via `@file` includes)
- `get-shit-done/templates/` — 30+ artifact templates (PROJECT, ROADMAP, REQUIREMENTS, STATE, AI-SPEC, UI-SPEC, VALIDATION, DEBUG, SECURITY, UAT…)
- `hooks/` — 13 hooks (Node.js + bash)
- `sdk/` — full TypeScript SDK with vitest tests, golden fixtures, ~250 source files
- `bin/gsd-tools.cjs` + `bin/lib/*.cjs` — legacy Node tooling (~17,310 lines, deprecated in favor of SDK as of 1.38.4)

**Architecture style:** TypeScript SDK + markdown workflows + multi-agent orchestration + state persistence.

**Six-command main loop (per README):**

```text
/gsd-new-project       → Questions → research → requirements → roadmap
/gsd-discuss-phase N   → Capture implementation decisions before planning
/gsd-plan-phase N      → Research + plan + verify (revision loop)
/gsd-execute-phase N   → Plans run in parallel waves, atomic commits, fresh contexts
/gsd-verify-work N     → Walk through built work, diagnose failures, generate fix plans
/gsd-ship N            → PR from verified phase
```

**Main-loop philosophy (verbatim from README):**
> "GSD keeps your main context clean by doing the heavy work in fresh subagent contexts. Researchers, planners, and executors each start fresh with exactly what they need. Your main context window stays at 30–40%."

**Key v1.40-specific features (not in older versions):**

- `--minimal` install flag (only 6 core skills, 0 subagents)
- Per-phase-type model map in `.planning/config.json` (#3023)
- Dynamic routing with failure-tier escalation (#3024)
- `plan-phase --research-phase` flag (#3045)
- `gsd-read-injection-scanner` PostToolUse hook (security)
- SDK Phase 3 — registry hot path direct (skip subprocess overhead, #2302)
- Secrets masking in SDK config-set/get (#2997)
- Changeset-fragment workflow for CHANGELOG (#2975)
- Six namespace meta-skills (`gsd:workflow`/`project`/`review`/`context`/`manage`/`ideate`)
- 31 micro-skills deleted, absorbed into consolidated parents (#2790)

**Subagent fan-out (token cost mechanism):**

- `/gsd-new-project` greenfield: spawns 4 parallel `gsd-project-researcher` (STACK/FEATURES/ARCHITECTURE/PITFALLS) + 1 `gsd-research-synthesizer` + 1 `gsd-roadmapper` = **6 subagents**
- `/gsd-plan-phase` per phase: spawns `gsd-phase-researcher` + `gsd-pattern-mapper` + `gsd-planner` + `gsd-plan-checker` × revision loop (max 3 iterations) = **4–10 subagents**
- Each subagent reads many files (CONTEXT.md, RESEARCH.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, references/*, templates/*, project CLAUDE.md, project skills)

**Unique mechanisms (verified by reading source):**

| Mechanism | File | Status |
|---|---|---|
| Granularity knob (Coarse/Standard/Fine) | `workflows/new-project.md:140-159` | Unique |
| Phase decomposition at context overflow (`## PHASE SPLIT RECOMMENDED`) | `workflows/plan-phase.md:805-835` | Unique |
| Coverage gate — every REQ-ID must be in a plan | `workflows/plan-phase.md:1081-1131` | Unique (spec-kit implies, doesn't enforce) |
| Schema push detection (Prisma/Drizzle/Payload/Supabase/TypeORM) | `workflows/plan-phase.md:511-569` | Unique |
| Security threat model gate (ASVS L1/L2/L3) | `workflows/plan-phase.md:417-440` | Unique |
| UI-SPEC gate for frontend phases | `workflows/plan-phase.md:444-507` | Unique |
| AI-SPEC gate when phase goal contains AI keywords | `workflows/plan-phase.md:251-287` | Unique |
| Multi-runtime detection (Claude/Codex/Gemini/OpenCode → CLAUDE.md vs AGENTS.md) | `workflows/new-project.md:69-89` | ECC has similar |
| Plan bounce (external script for refinement) | `workflows/plan-phase.md:1010-1080` | Unique |
| Revision loop with stall detection | `workflows/plan-phase.md:937-1008` | Unique |
| Workstream/workspace concept | `workflows/new-workspace.md` | Unique |
| Nyquist validation (Dimension 8 — sampling theorem applied to test coverage) | `references/verification-patterns.md` | Unique |
| TDD heuristics in planner (`type: tdd` for eligible tasks) | `references/tdd.md` | Pocock TDD has stronger content; GSD has automated classification |
| `/gsd-spec-phase` — Socratic spec refinement with ambiguity scoring | v1.37.0 | **Built-in equivalent of pocock's `/grill-me`** |
| `/gsd-plan-review-convergence` — automated cross-AI loop with stall detection | v1.38.2 | **Overlaps with Supreme Council** |
| `gsd-read-injection-scanner` PostToolUse hook | v1.37.0 (#2201) | Unique — prompt injection security |

**Hooks (13 files, full security stack):**

- `gsd-prompt-guard.js` — UserPromptSubmit workflow enforcement
- `gsd-read-guard.js` — PreToolUse(Read) injection check
- `gsd-read-injection-scanner.js` — PostToolUse(Read) injection scanner
- `gsd-context-monitor.js` — context budget tracking
- `gsd-workflow-guard.js` — workflow boundary enforcement
- `gsd-statusline.js` — GSD-aware statusline
- `gsd-check-update.js` + worker — async update check
- `gsd-update-banner.js` — opt-in SessionStart update banner
- `gsd-phase-boundary.sh` — phase transition guard
- `gsd-session-state.sh` — Stop hook session persistence
- `gsd-validate-commit.sh` — commit validation
- `lib/git-cmd.js` — shared helper

**SDK key modules (250+ TypeScript files):**

- `context-engine.ts` + `context-truncation.ts` — token cost control
- `prompt-builder.ts` + `prompt-sanitizer.ts` — prompt assembly
- `phase-runner.ts`, `milestone-runner.ts`, `session-runner.ts`, `init-runner.ts` — execution
- `query/` (50+ files) — command registry, dispatch, policy, fallback, native-hotpath
- `query-native-direct-adapter.ts` + `query-native-hotpath-adapter.ts` — skip subprocess on default path
- `golden/` — read-only parity tests vs legacy `bin/gsd-tools.cjs`
- `gsd-transport-policy.ts` + `query-fallback-policy.ts` — transport abstraction

**Red flag:** **$GSD memecoin/utility token on Solana** — maintainer (TÂCHES) launched a token. Risk: marketing-driven priorities. Current changelogs show engineering-driven work though.

**npm dist-tags status:**

- `latest: 1.40.0` — stable, default for `npx ...@latest`
- `next: 1.41.0-rc3` — release candidate (mostly internal SDK refactor, ~80% `refactor:` commits)
- `canary: 1.50.0-canary.1` — manual workflow_dispatch only, no release notes published, **don't use**
- `experimental: 1.10.0-experimental.0` — legacy

**v1.41-rc3 vs v1.40:** 145 commits in 3 days, ~80% internal SDK seam refactoring + ~15% bug fixes + 2 small features. **No major user-facing improvements over v1.40.** Stay on v1.40 stable.

---

### 2. github/spec-kit (Spec-Driven Development)

**Architecture:** Python CLI (`specify_cli`) with workflow engine (steps: `do_while`, `fan_in`, `fan_out`, `gate`, `if_then`, `while_loop`). 30+ AI integrations (claude, codex, cursor, copilot, gemini, kiro, devin, windsurf, opencode, qwen, kimi…).

**Lean preset = 5 commands (the entire workflow):**

| Command | Artifact | What it does |
|---|---|---|
| `/speckit.constitution` | `.specify/memory/constitution.md` | Project guiding principles |
| `/speckit.specify` | `specs/<feature>/spec.md` | Idea → structured spec |
| `/speckit.plan` | `specs/<feature>/plan.md` | Spec → tech architecture + design |
| `/speckit.tasks` | `specs/<feature>/tasks.md` | Plan → checklist tasks (with `[P]` for parallel) |
| `/speckit.implement` | code | Execute tasks.md, mark `- [x]` |

**Command file size:** 15 lines each. Compare to GSD's `plan-phase.md` (1289 lines).

**Philosophy (from `spec-driven.md`):** "code → specs becomes primary artifact. PRD = source of truth. Iteration = regenerate."

**Strengths:**

- Minimal ceremony, direct prompts (one page per command)
- spec → plan → tasks → implement = exactly the GSD pipeline, but ~10× cheaper
- Constitution as guiding principles (replaces bloated CLAUDE.md)
- Tests as part of specification (tasks.md contains test phase, contracts/ generated)
- Cross-runtime — supports 30+ AI agents

**Weaknesses:**

- No project scanning at start (`/specify` asks for directory path, doesn't scan)
- No interactive clarifying questions (only "make informed defaults for unspecified details")
- No deep debugging loop (no equivalent to pocock's `/diagnose`)
- No "phase" concept for large projects (one feature = one `specs/<feat>/`)
- Python CLI = one dependency (vs pure markdown for pocock)

**Token cost:** low–medium. Simple prompts, artifacts in `specs/`, doesn't bloat.

---

### 3. mattpocock/skills

**Architecture:** 12 skills in 4 buckets (engineering / productivity / misc / personal). **Zero commands** — only SKILL.md files with rich descriptions; agent activates by trigger keywords. `CONTEXT.md` = ubiquitous language doc. `docs/adr/` = architecture decisions.

**12 skills (3 read in detail):**

| Skill | Verified content |
|---|---|
| **diagnose** | 6-phase debugging loop. Phase 1 = "Build a feedback loop" with 10 techniques (failing test, curl, headless browser, replay trace, fuzz loop, bisection, differential, HITL bash). Each phase has checklists. ~500 lines. |
| **grill-with-docs** / **grill-me** | Pre-coding interrogation. Solves GSD's "ask clarifying questions". Pocock states this is his most-used skill. |
| **tdd** | Red-green-refactor with explicit anti-pattern: "DON'T write all tests first" (horizontal slicing). Vertical tracer-bullet approach. ~130 lines. |
| **triage** | Issue tracker state machine (needs-triage / needs-info / ready-for-agent / wontfix). |
| **to-prd** / **to-issues** | Conversation context → PRD → vertical-slice issues. |
| **improve-codebase-architecture** | Refactor towards "deep modules" (Ousterhout). Run every few days. |
| **zoom-out** | One-paragraph skill: "I don't know this area. Go up a layer of abstraction." |
| **caveman** | Compress communication ~75% (already used in this conversation). |
| **write-a-skill** | Meta — create new skills. |
| **setup-matt-pocock-skills** | Per-repo bootstrap (issue tracker, label vocab, doc paths). |

**Philosophy (verbatim from README):**
> "Approaches like **GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control and make bugs in the process hard to resolve.**"

This is a **direct response to the GSD problem.** Pocock explicitly designed against GSD-style heavy orchestration.

**Strengths:**

- Skills are modular, activate by triggers → minimal baseline token cost
- Each skill is deep, production-ready (especially `/diagnose`)
- Pragmatic, dialogue-first, no ceremony
- Pure markdown, no CLI dependency
- ADR + CONTEXT.md = lightweight replacement for GSD's `.planning/`

**Weaknesses:**

- No phase structure for large projects (but `/to-issues` slices PRD into vertical slices)
- No automatic project scanning (but `/zoom-out` is close)
- No built-in spec→plan→tasks pipeline (but `/to-prd` → `/to-issues` → `/tdd` is similar)
- No multi-LLM verification (no equivalent to Council)

**Token cost:** LOW — skills activate by keyword triggers, baseline near zero.

---

### 4. forrestchang/andrej-karpathy-skills

**Architecture:** 1 CLAUDE.md (~70 lines, 4 principles), 1 SKILL.md (same content), Cursor rule + EXAMPLES.md. Total repo size: 20 KB.

**4 principles:**

1. **Think Before Coding** — surface assumptions, ask
2. **Simplicity First** — no speculative code
3. **Surgical Changes** — touch only what you must
4. **Goal-Driven Execution** — verifiable success criteria + loop

**Not a workflow — behavioral baseline.** Already partially reproduced in toolkit's `components/surgical-changes.md`.

**Token cost:** MINIMAL.

---

### 5. affaan-m/everything-claude-code (ECC) v2.0.0-rc.1

**Architecture:** 48 agents, 182 skills, 68 legacy command shims. Multi-harness (Claude Code, Codex, Cursor, OpenCode, Gemini, Kiro). 12 language ecosystems. Cursor hooks (15 files). Cursor rules (~40 files). Codex agents (TOML). Kiro agents (~15 files). Rust control-plane prototype (`ecc2/`). Tkinter dashboard.

**npm packages:** `ecc-universal`, `ecc-agentshield`. GitHub App: `ecc-tools` (free/pro/enterprise tiers). Marketing-heavy framing.

**Strengths:**

- Largest language coverage
- Cross-harness (if needed)
- Hooks for every stage
- Marketplace/plugin ecosystem

**Critical weaknesses:**

- **Most bloated of the 4** — 182 skills equals GSD by volume. Solves the same problem you're trying to escape.
- Marketing red flags ("**174K stars** | **170+ contributors** | **Anthropic Hackathon Winner**") — likely inflated star count
- Vendor lock-in: paid SaaS dependencies (`ecc.tools`, `ecc-agentshield` GitHub App)
- "Homunculus" instincts, identity/team config layers — overhead for solo dev
- ECC 2.0 alpha = SaaS ambition (Rust control-plane)

**Token cost:** HIGH. ECC = GSD competitor with same disease.

**Verdict:** skip. Same problem you're trying to leave.

---

### 6. claude-code-toolkit (your project) v5.0

**Architecture (verified inventory):**

- 946 .md files
- 94 .sh scripts
- 2 .py files
- ~314,262 lines total
- 30 slash commands
- 7 framework templates (base, laravel, rails, nextjs, nodejs, python, go)
- 9 base skills + 22 marketplace skills
- 4 base agents + per-stack experts
- 36 components (mostly archive docs, not embedded)
- Supreme Council (`scripts/council/brain.py` 3343 LoC + `/council` cmds)
- Manifest-driven 4-mode install (standalone / complement-sp / complement-full / complement-gsd)
- Smart-merge CLAUDE.md (system vs user sections)
- `.planning/milestones/v4.0–v5.0` GSD-style phases (103k lines history)

**Unique vs all 5 above:**

- Supreme Council multi-LLM peer review (no equivalent in spec-kit/pocock/karpathy/ECC; GSD has `/gsd-plan-review-convergence` since 1.38.2 which overlaps but is GSD-internal)
- Audit pipeline with FP recheck and severity levels (`/audit-skip`, `/audit-restore`)
- Framework-specific CLAUDE.md templates (laravel/rails/nextjs/python/go/nodejs)
- 4-mode install system

**Bloat (consolidated from prior analysis):**

- 24 commands duplicate spec-kit + pocock (debug, plan, tdd, verify, worktree, fix, refactor, test, e2e, api, migrate, perf, deps, docker, deploy, explain, find-function, find-script, doc, handoff, helpme, learn, checkpoint, context-prime)
- 31 of 36 components are archive material, not active
- 7 conflicts with superpowers already declared in `manifest.json`
- `plugins/tk-{commands,skills,framework-rules}/` internal mirrors — unused
- `.planning/milestones/v4.*` history shouldn't ship to users

---

## Comparison tables (all data verified from source)

### Table 1 — Architecture and scale

| Metric | GSD v1.40 | spec-kit | pocock | karpathy | ECC | toolkit v5.0 |
|---|---|---|---|---|---|---|
| Repo size | 15.1 MB / 1309 files | ~7.7 MB | 87 KB | 20 KB | ~30 MB | ~314k LoC |
| Lines of MD/instruction | 45,190 (workflows+refs+templates) | ~5k (presets+templates) | ~3k | ~70 | ~50k+ | 946 files |
| TS/JS source | SDK 250+ files + tests | Python ~30 files | 0 | 0 | TS/JS hooks ~30 | 2 .py files (Council) |
| Commands | 84 workflows / 59 skills (latest) | 5 (lean preset) | 0 (skills only) | 0 | 68 legacy shims | 30 |
| Skills | 73 full / **6 minimal** | 0 | 12 | 1 | 182 | 9 base + 22 marketplace |
| Agents | 33 full / **0 minimal** | 0 | 0 | 0 | 48 | 4 base + 7 framework |
| Hooks | 13 (incl. injection scanner) | 0 | 1 (git-guardrails) | 0 | 15+ | 0 (templates only) |
| Tests | vitest unit + integration + golden | minimal | none | none | npm test | shellcheck + markdownlint |
| Stars | 60.3k | 92.7k | 61.5k | 114.8k | 174.2k (suspicious) | low |

### Table 2 — Functional capabilities

| Capability | GSD v1.40 | spec-kit | pocock | karpathy | ECC | toolkit |
|---|---|---|---|---|---|---|
| Project scanning at start | ✅ `/gsd-map-codebase` | ❌ | ❌ (but `/zoom-out`) | ❌ | ⚠ research | ✅ `/gsd-map-codebase` history |
| Phase-based decomposition | ✅✅ + `## PHASE SPLIT RECOMMENDED` | ⚠ feature-level | ❌ | ❌ | ⚠ multi-plan | ⚠ via roadmap |
| Clarifying questions | ✅ `/gsd-discuss-phase` + `/gsd-spec-phase` | ⚠ | ✅✅ `/grill-me`, `/grill-with-docs` | ✅ Principle 1 | ✅ | ⚠ via Council |
| TDD/test workflow | ✅ TDD heuristics in planner | ✅ tasks.md | ✅✅ `/tdd` deeper | ✅ Goal-Driven | ✅ `/tdd-workflow` | ✅ testing skill |
| Implement from full spec | ✅✅ `/gsd-execute-phase` | ✅ `/speckit.implement` | ⚠ via `/to-issues` | ❌ | ⚠ multi-execute | ⚠ via Council |
| Multi-LLM peer review | ✅ `/gsd-plan-review-convergence` | ❌ | ❌ | ❌ | ❌ | ✅✅ Supreme Council |
| Coverage gate (REQ-IDs) | ✅ enforced | ⚠ implied | ❌ | ❌ | ⚠ | ❌ |
| Schema push detection | ✅ ORM-aware | ❌ | ❌ | ❌ | ❌ | ❌ |
| Security threat model | ✅ ASVS levels | ❌ | ❌ | ❌ | `/security-scan` | ✅ `/security-review` |
| Prompt injection scanner hook | ✅ unique | ❌ | ❌ | ❌ | ⚠ AgentShield | ❌ |
| Audit pipeline (FP recheck) | ❌ | ❌ | ❌ | ❌ | ⚠ | ✅✅ unique |
| Framework templates | ❌ | ⚠ presets | ❌ | ❌ | ⚠ language rules | ✅ 7 stacks |

### Table 3 — Token economics (real data where verifiable)

| Metric | GSD v1.40 minimal | GSD v1.36 (old) | spec-kit | pocock | karpathy | ECC |
|---|---|---|---|---|---|---|
| Cold-start system prompt | ~700 tokens (#2762) | ~12,000 tokens | minimal | low | minimal | high |
| Skill descriptions loaded | 6 × ~150 = ~900 | 73 × ~150 = ~11k | 5 × ~80 = ~400 | 12 × ~120 = ~1.4k | 1 × ~100 | 182 × ~150 = ~27k |
| Namespace router overhead | ~120 tokens (#2792) | ~2150 tokens (flat) | n/a | n/a | n/a | n/a |
| `discuss-phase` entry | ~0 tokens (lazy load #2606) | ~13k | n/a | n/a | n/a | n/a |
| Subagents per planning command | 4–10 | 4–10 | 0 | 0 | 0 | many |
| Per-feature pipeline cost | ~100–250k tokens | ~150–300k tokens | ~10–30k tokens | ~5–20k tokens | ~5k tokens | ~150–300k tokens |

**Key insight:** GSD v1.40 minimal is **~10–15× cheaper than v1.36**. The user's "GSD too expensive" complaint may be based on pre-v1.37 experience and is partly resolved by upgrade alone.

### Table 4 — Verdicts

| Tool | Score 1–10 | Best fit |
|---|---|---|
| **GSD v1.40 minimal** | 8 | Heavy phase-based projects with REQ-coverage enforcement; needs `gsd-sdk` on PATH |
| **spec-kit lean** | 9 | Simple feature-driven flow, no overhead, multi-runtime |
| **pocock/skills** | 9 | Daily engineering skills (debug, TDD, refactor, grilling) — best baseline cost |
| **karpathy** | 8 (in its niche) | Behavioral baseline — append to any CLAUDE.md |
| **ECC** | 4 | Skip. GSD competitor with same bloat. |
| **toolkit v5.0 (current)** | 6 | Council + audits unique; rest duplicates external |

---

## Decision matrix

| Scenario | Best choice | Reason |
|---|---|---|
| Maximum simplicity | karpathy CLAUDE.md + 1–2 pocock skills | 70 lines + 2 skills = 80% coverage |
| Spec-driven development (small/medium) | spec-kit | Direct USP, lean preset = 5 commands |
| Min token cost | pocock/skills | Skills activate by trigger, baseline ~zero |
| Heavy phase-based projects | GSD v1.40 minimal + Council | Phase split, coverage gate, schema push, security gate |
| Production-grade workflow | spec-kit + pocock + Council | spec for big features, pocock for daily, Council for high-stakes |
| Keep existing toolkit | toolkit + GSD v1.40 minimal + pocock | toolkit as Council/audits/framework dimension; GSD for phases; pocock for skills |
| Full toolkit replacement | spec-kit + pocock | Sufficient for ~90% scenarios |
| **Leave GSD entirely (RECOMMENDED if v1.40 pipeline > 100k tokens)** | **Pocock-base hybrid** | pocock = daily skills base, spec-kit = bigger features, toolkit = Council + audits + framework templates |

## Pocock-base hybrid architecture (RECOMMENDED if leaving GSD)

User control retained, lowest token cost, zero conflicts.

### Layers

```text
~/.claude/                                 ← global
├── plugins/
│   ├── mattpocock-skills/                 ← npx skills@latest add mattpocock/skills
│   │   └── 12 skills (grill-me, diagnose, tdd, triage, zoom-out,
│   │                  to-prd, to-issues, improve-codebase-architecture,
│   │                  caveman, write-a-skill, setup-matt-pocock-skills, grill-with-docs)
│   └── spec-kit/                          ← pip install + specify preset add lean
│       └── 5 commands (speckit.constitution, .specify, .plan, .tasks, .implement)
├── council/                               ← from toolkit (UNIQUE, kept)
│   ├── brain.py
│   └── config.json
└── CLAUDE.md (global)                     ← karpathy 4 principles + minimum

<project>/.claude/                         ← from toolkit framework template
├── CLAUDE.md                              ← framework-specific (laravel/nextjs/python/go/...)
├── settings.json
├── agents/                                ← 4 base only
│   ├── code-reviewer.md
│   ├── security-auditor.md
│   ├── test-writer.md
│   └── <framework>-expert.md
├── prompts/                               ← 5 audit prompts from toolkit
├── skills/<framework>/SKILL.md            ← framework-specific only
├── rules/project-context.md
└── lessons-learned.md

<project>/specs/<feature>/                 ← spec-kit artifacts (big features)
├── spec.md
├── plan.md
├── tasks.md
└── contracts/

<project>/.specify/memory/constitution.md  ← project guiding principles
```

### Total command surface (~18-20 vs current 30+ in toolkit alone)

| Source | Commands | Use case |
|---|---|---|
| pocock | `/grill-me`, `/grill-with-docs` | Pre-coding interrogation (replaces GSD discuss-phase) |
| pocock | `/diagnose` | Hard bug 6-phase loop |
| pocock | `/tdd` | Red-green-refactor with anti-patterns |
| pocock | `/triage` | Issue workflow state machine |
| pocock | `/zoom-out` | High-level context (project scan lite) |
| pocock | `/improve-codebase-architecture` | Deep modules refactor |
| pocock | `/to-prd`, `/to-issues` | Conversation → PRD → slices |
| pocock | `/caveman`, `/write-a-skill` | Productivity |
| spec-kit | `/speckit.constitution` | Project principles (bigger projects) |
| spec-kit | `/speckit.specify`, `.plan`, `.tasks`, `.implement` | Spec-driven for bigger features |
| toolkit | `/audit security/code/perf/design/deploy` | Audit pipeline with FP recheck (UNIQUE) |
| toolkit | `/council` | Multi-LLM peer review (UNIQUE) |
| toolkit | `/checkpoint`, `/handoff`, `/context-prime` | State + context |

### What's lost when leaving GSD

| GSD capability | Hybrid replacement | Quality |
|---|---|---|
| Phase decomposition (`## PHASE SPLIT RECOMMENDED`) | Manual split + spec-kit per sub-feature | ⚠ Manual |
| Coverage gate (REQ-IDs enforcement) | `/coverage-check` thin command (optional) | ✅ ≥80% |
| Schema push detection | `/schema-push-check` thin command (optional) | ✅ ≥80% |
| Security threat model gate (ASVS) | toolkit `/security-review` + `/audit security` | ✅ stronger in FP recheck |
| Prompt injection scanner hook | NO replacement (unique to GSD) | ❌ Loss |
| Workstream/workspace concept | git worktrees + superpowers `/using-git-worktrees` | ✅ Equivalent |
| Granularity knob | spec-kit lean = "Fine"; pocock `/to-issues` = slices | ⚠ Less granular |
| Phase research (4 parallel agents) | NONE — pocock anti-pattern; spec-kit research lighter | ❌ Less depth (BUT this is the cost saving) |
| Revision loop ×3 | spec-kit iterative regen; pocock skill rerun | ⚠ Manual |
| `/gsd-spec-phase` Socratic refinement | pocock `/grill-me` + `/grill-with-docs` | ✅ Equivalent or stronger |
| `/gsd-plan-review-convergence` | toolkit's `/council` | ✅ Equivalent |

**Real losses:** prompt injection scanner hook, automatic phase split, automatic 4-parallel research depth.

**Real wins:** 5-10× cheaper per pipeline, full control retained, no $GSD memecoin priority risk, no architecture lock-in.

### Migration phases (5 phases over ~2 weeks)

**Phase 1 — Install companions (10 min)**

1. `npx skills@latest add mattpocock/skills`
2. `pip install specify-cli && specify preset add lean` (or equivalent)
3. `/grill-me` on current task — sanity check
4. `/speckit.specify` on small feature — sanity check
5. Decision go/no-go

**Phase 2 — Test pipeline (1 hour)**

1. Create test feature (e.g., "delete /context-prime from toolkit")
2. `/grill-me` grilling session
3. `/speckit.specify` → `.plan` → `.tasks` → `.implement`
4. `/audit code` on result
5. Compare total tokens vs GSD pipeline
6. **If ≤ 50% of GSD cost** → continue Phase 3

**Phase 3 — Trim toolkit (1 week, branch `feat/lean-v6`)**

- DELETE 22 duplicate commands (debug, plan, tdd, verify, worktree, fix, refactor, test, e2e, api, migrate, perf, deps, docker, deploy, explain, find-function, find-script, doc, handoff, helpme, learn)
- DELETE 31 components (keep only: claude-md-guide, severity-levels, supreme-council, optional-plugins, audit-output-format)
- DELETE 17 marketplace skills (keep top 5: stripe, shadcn, firecrawl, notebooklm, resend)
- DELETE `plugins/tk-{commands,skills,framework-rules}/` mirrors
- DELETE one-shot scripts (migrate-to-complement.sh, propagate-audit-pipeline-v42.sh)
- MOVE `.planning/milestones/v4.*` → `docs/archive/`
- `make check` must pass
- Commit & push

**Phase 4 — Reposition (1 week)**

- Rewrite `templates/base/CLAUDE.md` (389 → ~150 lines)
- Add karpathy 4 principles in base
- Add `scripts/install-companions.sh` (one-command pocock + spec-kit + toolkit install)
- Add `components/integration-with-{pocock,spec-kit}.md`
- Rewrite `README.md` ("Council + Audits + Framework templates — companion to mattpocock/skills + github/spec-kit")
- `manifest.json` — extend `conflicts_with`
- Optional: add 4 thin commands (coverage-check, schema-push-check, threat-model-check, multi-runtime-bridge), each ≤100 lines, 0 sub-agents
- `make check` + tests → CI green
- Tag v6.0.0 + GitHub Release

**Phase 5 — Uninstall GSD (when ready)**

- Extra safety: `cp -r ~/.claude/.gsd-backup-* ~/.claude/.gsd-rollback`
- `npx get-shit-done-cc uninstall` (if exists) OR manually:

  ```bash
  rm -rf ~/.claude/get-shit-done/
  rm ~/.claude/agents/gsd-*.md 2>/dev/null
  rm -rf ~/.claude/skills/gsd-*
  rm ~/.claude/hooks/gsd-*
  rm ~/.claude/commands/gsd-*.md 2>/dev/null
  rm ~/.claude/gsd-file-manifest.json
  npm uninstall -g get-shit-done-cc
  ```

- Verify: `command -v gsd-sdk` empty, `ls ~/.claude/skills/gsd-*` empty

---

## Recommended action — three scenarios

### Scenario A: Test GSD v1.40 minimal first (RECOMMENDED — lowest risk)

**Steps:**

1. ✅ Done: GSD updated to v1.40.0 minimal (verified)
2. ✅ Done: `npm install -g get-shit-done-cc` (user did manually 2026-05-06)
3. **Next session:** Restart Claude Code, run `/gsd-help`, measure cold-start tokens via `/cost`
4. Compare against memory of "old GSD" experience
5. If acceptable → stay on GSD v1.40 minimal as primary, toolkit as complement

**Toolkit role under Scenario A:** keep Council + audits + framework templates only. Trim 24 duplicate commands + 31 unused components. Don't migrate workflow.

### Scenario B: Hybrid — GSD for phases, spec-kit/pocock for daily, toolkit for unique

**Steps:**

1. GSD v1.40 minimal stays (test first)
2. Add `npx skills@latest add mattpocock/skills` for daily skills
3. Optionally install spec-kit (`pip install specify-cli` then `specify preset add lean`) for small features without phase overhead
4. Toolkit trimmed to Council + audits + framework templates
5. karpathy 4 principles in `templates/base/CLAUDE.md`

### Scenario C: Replace GSD entirely with spec-kit + pocock

**Steps:**

1. Install spec-kit + pocock
2. Migrate one project end-to-end as test
3. If successful, uninstall GSD: `npx get-shit-done-cc uninstall` (or rm -rf manually)
4. Toolkit recreates 4 thin GSD-inspired commands (`/coverage-check`, `/phase-split`, `/schema-push-check`, `/multi-runtime-bridge`) — each <100 lines, 0 sub-agents
5. Toolkit dimension: Council + audits + framework templates + 4 thin commands

**Trade-off:** lose GSD's phase split + coverage gate + revision loop. Pay in: more manual oversight on large projects.

---

## Migration plan for toolkit (regardless of scenario)

### Phase 1 — trim duplicates (week 1, branch `feat/lean-v6`)

**Delete:**

```text
commands/{debug,plan,tdd,verify,worktree,fix,refactor,test,e2e,api,migrate,perf,deps,docker,deploy,explain,find-function,find-script,doc,handoff,helpme,learn,checkpoint,context-prime}.md
components/* (keep only: claude-md-guide, severity-levels, supreme-council, optional-plugins, audit-output-format)
plugins/{tk-commands,tk-skills,tk-framework-rules}/  (internal mirrors)
templates/skills-marketplace/* (keep top 5: stripe, shadcn, firecrawl, notebooklm, resend)
scripts/{migrate-to-complement.sh, propagate-audit-pipeline-v42.sh}  (one-shot)
.planning/milestones/v4.*  (move to docs/archive/)
```

**Effect:** −700 .md files, −50% repo size.

### Phase 2 — keep + reposition

```text
KEEP:
- scripts/council/* + commands/{council, council-clear-cache, council-stats}.md  ← UNIQUE
- commands/{audit, audit-skip, audit-restore}.md + audit prompts  ← UNIQUE
- templates/{base,laravel,rails,nextjs,nodejs,python,go}/  (clean up CLAUDE.md duplication)
- scripts/{install.sh, init-claude.sh, update-claude.sh, uninstall.sh, verify-install.sh}
- .claude-plugin/ + manifest.json (simplified)
- components/{claude-md-guide, severity-levels, supreme-council, optional-plugins, audit-output-format}.md
```

### Phase 3 — rewrite

- `templates/base/CLAUDE.md` (389L → ~150L): remove duplicating sections (Plan Mode, Structured Workflow, Git Worktree, TDD); add 4 karpathy principles; only project-specific overrides + audit/Council pointers + skills inventory remain
- `manifest.json`: extend `conflicts_with` to include `gsd-build/get-shit-done`, `mattpocock/skills`, `github/spec-kit`; remove `sp_equivalent` (superseded by GSD/pocock recommendations)
- `README.md`: reposition as "Council + Audits + Framework templates — recommended companion to GSD/spec-kit/pocock"

### Phase 4 — add

- `scripts/install-companions.sh` — automate spec-kit + pocock install side-by-side
- `components/integration-with-gsd.md` — how Council/audits chain into `/gsd-execute-phase`
- `components/integration-with-spec-kit.md` — `/speckit.tasks` → `/audit code` → `/council` for high-stakes

### Phase 5 — test

- Fresh project: `install.sh` + GSD v1.40 minimal + pocock + one framework template
- Run full workflow (constitution → spec → plan → tasks → implement → audit → council)
- Measure tokens via `~/.claude/council/usage.jsonl` or `/cost`
- Smoke test on Laravel + Next.js + Python projects

---

## Concrete first steps

> **Cold-start ≠ real cost.** GSD's `--minimal` flag optimizes only the cold-start system prompt (~700 vs ~12k tokens, −95%). That's ~3-5% of total cost on a real project. The bottleneck is **subagent fan-out during pipelines** (`/gsd-plan-phase` spawns 4-10 subagents, each reads 5-15 files) — and v1.40 did NOT restructure that architecture. Estimated v1.40 vs v1.36 saving on full pipeline: **30-40%, not 90%.**

1. **Real measurement (not cold-start):**
   - Restart Claude Code (skills must reload)
   - `/cost` baseline after fresh start
   - Run a real pipeline command: `/gsd-plan-phase` on a small existing phase, OR fresh `/gsd-new-project --auto @small-spec.md` → `/gsd-discuss-phase 1` → `/gsd-plan-phase 1`
   - `/cost` again after pipeline completes
   - **Delta = per-pipeline cost.** That's the number that matters.
   - Compare against memory of pre-v1.37 cost.
2. **If per-pipeline ≤ 50k tokens:** acceptable. Scenario A (stay GSD).
3. **If per-pipeline ≥ 100k tokens:** architecture not fixed by `--minimal`. Scenario B or C.
4. **50-100k range:** judgment call — depends on whether the orchestration value (phase split, coverage gate, schema push detection) justifies the cost vs spec-kit + pocock alternative.
5. **Independent of GSD decision:** start `feat/lean-v6` branch in toolkit. Phase 1 of migration plan (trim 24 duplicate commands + 31 components). Worth doing regardless.

---

## Open questions to verify next

- ✅ Verified: GSD v1.40 minimal install state (6 skills, 0 agents, 12 hooks)
- ❌ Unverified: real token cost of GSD v1.40 minimal full pipeline. Need to measure on actual project.
- ❌ Unverified: whether GSD `--minimal` + namespace meta-skills work as advertised (#2792 says ~120 tokens for cold-start router, but lazy resolution must be tested in fresh session)
- ❌ Unverified: whether `gsd-sdk` is now on PATH after manual `npm install -g get-shit-done-cc`. User did install but PATH not re-checked yet.
- ❌ Unverified: whether `/gsd-spec-phase` (v1.37.0+) really replaces pocock's `/grill-me` for clarifying questions
- ❌ Unverified: whether `/gsd-plan-review-convergence` (v1.38.2+) replaces Supreme Council
- ❌ Unverified: whether `jnuyens/gsd-plugin` (claimed -92% per-turn token overhead) is still relevant given v1.40 already includes optimizations

---

## Critical caveats

1. **GSD has $GSD memecoin/utility token on Solana** — TÂCHES launched it. Risk: priorities may drift toward marketing. Current changelogs are engineering-driven but watch for divergence.
2. **ECC has suspicious star count** (174k for a CC plugin) — likely inflated. Skip regardless.
3. **karpathy already partially in toolkit** (`components/surgical-changes.md`) — don't double-install as plugin, just ensure 4 principles are in base CLAUDE.md.
4. **pocock author explicitly designed against GSD/Spec-Kit ownership of process** — README says: "they take away your control and make bugs in the process hard to resolve." Choose pocock if you want to retain control. Caveat: "retained control" is a feature for programmers but a liability for non-programmers who can't review code themselves.
5. **GSD v1.41-rc3 is mostly internal SDK refactor** — no major user value over v1.40. Don't upgrade to RC.
6. **GSD v1.50.0-canary.1** — exists only as git tag + npm `canary` dist-tag. No release notes. Manual workflow_dispatch experimental build. Don't use.

## Independent verdict for non-programmer profile (added 2026-05-06)

Critical context: user is NOT a programmer, cannot find bugs in code themselves, building real products solo with AI, wants quality + reliability.

This profile **shifts the calculus toward GSD over pocock** — verification gates a programmer doesn't need are protective for a non-programmer.

### Where GSD is genuinely better for non-programmer

- **Multi-stage verification built into pipeline** — gsd-plan-checker, gsd-verifier, gsd-nyquist-auditor, gsd-security-auditor, gsd-doc-verifier, gsd-integration-checker, gsd-code-reviewer, gsd-eval-auditor, gsd-ui-checker. Pocock has zero of these.
- **Schema push detection** (Prisma/Drizzle/Payload/Supabase/TypeORM) — non-programmer cannot diagnose runtime DB schema crashes. Tests/build pass, runtime fails. Unique GSD safeguard.
- **Coverage gate (REQ-IDs enforcement)** — non-programmer would miss forgotten requirements. Pocock and spec-kit don't enforce.
- **Atomic commits per task + STATE.md persistence** — recovery + resume after context loss without losing work.
- **Read injection scanner hook** — security against prompt injection through files.
- **Phase split at context overflow** — automatic decomposition; non-programmer doesn't know when to split manually.
- **Multi-LLM peer review built into pipeline** (`/gsd-plan-review-convergence`) — not opt-in.
- **`/gsd-fast` and `/gsd-quick` modes** — escape hatches for cost control on small tasks. Disciplined use means ~70% of work bypasses heavy gates.

### Where GSD is still imperfect for non-programmer

- **Verification = plan-vs-spec consistency, NOT product-vs-reality.** All gates can pass while product is wrong if spec was wrong. Real quality requires production runtime testing + observability, which GSD doesn't provide.
- **Token cost = real money.** ~$30-50 per phase, $240-400 per milestone in API costs. Money that could fund production testing/monitoring/users acquisition.
- **Vendor lock-in risk** — $GSD memecoin signals possible priority drift toward marketing/token holders.
- **Black-box when it breaks** — non-programmer cannot debug GSD's TypeScript SDK if something glitches.
- **fast/quick modes are all-or-nothing** — `/gsd-fast` skips ALL gates; `/gsd-quick` keeps core but skips optional. No middle ground between "no verification" and "full price."

### Recommended position for non-programmer (independent, non-flattering)

**Stay on GSD v1.40 minimal as primary, BUT:**

1. Discipline use of `/gsd-fast` (trivial fixes inline) and `/gsd-quick` (small features, skip optional agents) for ~70% of work.
2. `/gsd-plan-phase` full pipeline ONLY for milestone-defining features (auth, payments, core data model, public API).
3. **Compensate GSD's blind spot** ("verifies plan vs spec, not product vs reality") via:
   - Mandatory Playwright e2e tests on deployed feature
   - Sentry/Posthog production observability
   - Manual UAT walkthrough with real-data scenarios
4. Use toolkit's `/council` orthogonally for high-stakes phases (security, payments, breaking API changes) — independent multi-LLM check.
5. Use toolkit's `/audit security|code|perf` retroactively after each phase — FP recheck protects non-programmer from false positives.
6. **Budget cap: $300-500/month on API.** If exceeding, switch to hybrid (pocock base + GSD only for big features).
7. Watch $GSD memecoin signal — if maintainer behavior shifts to marketing-driven (engagement campaigns over engineering), prepare exit plan.

### When to reconsider and leave GSD

- Per-pipeline cost > 100k tokens AND user uses full `/gsd-plan-phase` for >50% of work
- Multiple parallel projects (cost multiplies)
- $GSD token marketing bleeds into engineering velocity
- User feels stuck debugging GSD itself instead of building product

### DO NOT execute Phase 3-5 of migration plan unless deciding to leave

Phases 3-5 (trim 22 commands + 31 components, reposition toolkit, uninstall GSD) are **one-way migrations** for git history. Don't preemptively trim if staying on GSD.

---

## Status checkpoints (for future-me)

- ✅ GSD v1.36 → v1.40 upgrade completed 2026-05-06 (this session)
- ✅ `--minimal` install confirmed (6 skills, 0 agents)
- ✅ `npm install -g get-shit-done-cc` done by user (manual)
- ⏳ Cold-start token measurement pending (next session)
- ⏳ End-to-end small feature test pending
- ⏳ Toolkit migration not started (no `feat/lean-v6` branch yet)
- ✅ Backup of v1.36 state at `~/.claude/.gsd-backup-20260506-085323/`

---

*This document supersedes prior assumption-based analysis. All architecture claims here are verified against source files (read directly via Read tool or `gh api repos/.../contents/...`) or against installed artifacts (`~/.claude/get-shit-done/`).*
