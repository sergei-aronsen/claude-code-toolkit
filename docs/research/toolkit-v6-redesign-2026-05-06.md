# Toolkit v6.0 redesign — final plan (2026-05-06)

**Status:** Plan finalized. Pending execution. Generated through extended discussion 2026-05-06 across 7 conversation turns. Verified against installed GSD v1.40, Superpowers v5.1.0, Morph MCP, project sizes (lantern 144k, jobbhunter 53k, notebooklm-ultra 305k LOC).

---

## Vision

Toolkit v6.0 = **overlay layer on top of GSD + Superpowers + external tools**, NOT replacement. Pure complement: zero duplication with base plugins.

Three-layer architecture:

```text
┌────────────────────────────────────────────────────────────┐
│  TOOLKIT v6.0 (overlay, gap-filler, MCP installer)         │
│  • /council, /audit + FP-recheck, /learn, /vendor-audit    │
│  • Framework templates (Laravel/Rails/Python/Go overlays)  │
│  • Production observability + reality-check skills         │
│  • Cost discipline rules + setup-cost-routing.sh           │
│  • MCP wizard (catalog: Morph + claude-context + better-m) │
│  • Bridge hooks (gsd ↔ superpowers ↔ toolkit)              │
│  • Multi-lang cheatsheets (9 lang)                         │
├────────────────────────────────────────────────────────────┤
│  Plugins (auto-detected by toolkit installer)              │
│  • GSD v1.40 — heavy phase workflows                       │
│  • Superpowers v5.1 — discipline skills                    │
├────────────────────────────────────────────────────────────┤
│  External tools (installed via toolkit MCP wizard)         │
│  • Morph MCP — Fast Apply edits + warpgrep (always-on)     │
│  • better-model (npm) — model routing for subagents        │
│  • claude-context MCP — semantic search for >100k LOC      │
└────────────────────────────────────────────────────────────┘
```

---

## Why v6 = breaking change

v5.0 was standalone-or-complement (manifest detected GSD/SP, skipped 7 conflicts). v6 inverts: **assumes GSD + SP installed**. Without them — degraded mode (toolkit still works but recommends install).

Standalone install path drops to legacy. Migration via `scripts/migrate-v5-to-v6.sh`.

---

## Data driving the plan

### User profile (verified)

- Solo developer, NOT programmer (cannot review code)
- Building real products with AI
- Wants quality + reliability  
- Real projects: lantern (144k LOC), jobbhunter (53k LOC), notebooklm-ultra (305k LOC)
- Already has: GSD v1.40 minimal, Superpowers v5.1.0, Morph MCP (paid)

### GSD strengths matter for non-programmer

- Multi-stage verification gates (gsd-plan-checker, gsd-verifier, gsd-nyquist-auditor, gsd-security-auditor, gsd-doc-verifier, gsd-integration-checker, gsd-code-reviewer, gsd-eval-auditor, gsd-ui-checker)
- Schema push detection (Prisma/Drizzle/Payload/Supabase/TypeORM)
- Coverage gate (REQ-IDs)
- Atomic commits per task + STATE.md persistence
- Read injection scanner hook
- Multi-LLM peer review (`/gsd-plan-review-convergence`)
- `/gsd-fast` and `/gsd-quick` escape hatches

### GSD blind spot

Verifies plan-vs-spec consistency, NOT product-vs-reality. If spec is wrong, all gates pass and product is still wrong. Real quality requires production runtime testing + observability — toolkit fills this gap.

### Superpowers v5.1.0 skills (14, all installed)

| Skill | Purpose | Toolkit duplicate? |
|---|---|---|
| brainstorming | HARD-GATE design first | YES (plan-mode-instructions.md) |
| test-driven-development | IRON LAW: no code without failing test | YES (skills/testing/) |
| verification-before-completion | IRON LAW: no claim without fresh verify | NO (uniq concept) |
| systematic-debugging | scientific method | YES (skills/debugging/) |
| subagent-driven-development | discipline for subagent fan-out | NO |
| dispatching-parallel-agents | parallel orchestration | YES (orchestration-pattern.md) |
| executing-plans | plan execution discipline | YES (structured-workflow.md) |
| writing-plans | plan format spec | YES (structured-workflow.md) |
| using-git-worktrees | worktree discipline | YES (git-worktrees-guide.md) |
| requesting-code-review | review pattern | NO |
| receiving-code-review | review handling | NO |
| finishing-a-development-branch | branch hygiene + ship | NO |
| writing-skills | meta skill creation | NO |
| using-superpowers | meta routing | N/A |

### External tools verified

| Tool | Cost | When | Installed? |
|---|---|---|---|
| Morph MCP | Paid API per use | Always (Fast Apply edits + warpgrep) | YES (verified `~/.claude.json`) |
| better-model | Free npm | Always after toolkit/GSD/SP install | NO |
| claude-context MCP | $1-5 one-time embed + free queries | >100k LOC codebases (lantern, notebooklm-ultra) | NO |

---

## Toolkit v6 surface

### Commands: 33 → 6

**KILL (28):** debug, test, tdd, e2e, api, find-function, find-script, helpme, handoff, context-prime, design, perf, deps, docker, explain, fix, fix-prod, worktree, migrate, verify, plan, refactor, rollback-update, doc, deploy, checkpoint, audit-skip, audit-restore

**KEEP (5):** council, audit, learn, update-toolkit, audit-skip + audit-restore (paired with audit)

**ADD (1):** vendor-audit

### Components: 36 → 19

**KILL (9):** structured-workflow, plan-mode-instructions, bootstrap-workflow, orchestration-pattern, hooks-auto-activation, skills-system, spec-driven-development, optional-plugins, git-worktrees-guide

**KEEP (13):** claude-md-guide, markdown-lint-rules, supreme-council, audit-fp-recheck, audit-output-format, severity-levels, surgical-changes, security-hardening, memory-persistence, skill-frontmatter-discipline, plan-md-anti-bloat, mcp-servers-guide, report-format

**ADD (6):**

- production-observability.md (Sentry+Posthog+Playwright)
- cost-discipline.md (`/cost` budget + better-model)
- vendor-risk.md (quarterly dep review)
- domain-expert-simulation.md (non-programmer review proxy)
- large-codebase-search.md (claude-context when/when-not + self-hosted Milvus)
- external-tools-recommended.md (Morph + better-model + claude-context install matrix)

### Skills: 8 → 11

**KILL (2):** testing/, debugging/ (Superpowers covers via TDD + systematic-debugging)

**KEEP (6):** api-design, database, docker, llm-patterns, observability, council-integration

**ADD (5):**

- production-observability/
- reality-check/
- cost-routing-discipline/
- gsd-mode-selector/
- domain-expert-simulation/

### Templates: 7 → base + 4 overlays + global

**KILL (2):**

- nextjs/ (GSD skills-marketplace covers: next-best-practices, shadcn, tailwind, vercel-react, vercel-composition)
- nodejs/ (merge into base)

**DOWNGRADE to overlay (~5KB each):**

- laravel/ — Laravel idioms (Eloquent, Pint, Telescope, Octane, queues)
- rails/ — Rails idioms (ActiveRecord, RuboCop, Sidekiq)
- python/ — ruff, mypy, poetry, Django/FastAPI
- go/ — gofmt, golangci-lint, modules, generics

**KEEP:** base/ (skeleton), global/ (statusline + RTK + rate-limit-probe)

### Rules — add 3 auto-load

- rules/non-programmer-safeguards.md (globs ["**/*"]) — pre-ship ritual: domain expert sim, "what breaks for user", reality-check trigger
- rules/cost-discipline.md (globs ["**/*"]) — trigger keywords for force `/gsd-fast`/`/gsd-quick`
- rules/three-layer-bridge.md (globs ["**/*"]) — when GSD vs Superpowers vs Toolkit

### Hooks (NEW in templates/global/hooks/)

- post-gsd-phase-audit.sh — auto-trigger toolkit `/audit security && /audit code` after `/gsd-execute-phase`
- pre-gsd-plan-council.sh — auto-trigger `/council` for high-stakes phases (auth/payments/public-API/breaking)
- pre-ship-reality-check.sh — Playwright e2e + Sentry check before `/gsd-ship`
- cost-warning.sh — read `/cost` after each phase, warn if delta >50k tokens

### MCP catalog additions (scripts/lib/integrations-catalog.json)

- morph (recommended: true) — Fast Apply + warpgrep
- claude-context (recommended: false, security_warning) — vector DB semantic search

---

## Size comparison

```text
Before (v5.0):  ~651KB
- 33 commands  × ~5KB  ≈ 165KB
- 36 components × ~7KB  ≈ 252KB
- 7 templates  × ~30KB ≈ 210KB
- 8 skills     × ~3KB  ≈  24KB

After (v6.0):  ~259KB
- 6 commands   × ~5KB  ≈  30KB
- 19 components × ~7KB  ≈ 133KB
- base + 4 overlays + global = 55KB
- 11 skills    × ~3KB  ≈  33KB
- 4 hooks      × ~2KB  ≈   8KB

Reduction: -60%
Duplication with GSD/Superpowers: 0%
```

---

## Implementation plan — 7 PRs sequenced

| PR | Branch | Risk | Mode | Est tokens | Est cost (Sonnet) |
|---|---|---|---|---|---|
| 1 | feat/v6-trim-duplicates | LOW (pure deletes) | `/gsd-fast` per group | ~30k | ~$0.50 |
| 2 | feat/v6-additions | MED (new content) | `/gsd-quick` per group | ~80k | ~$1.50 |
| 3 | feat/v6-bridge-hooks | HIGH (security bash) | `/gsd-plan-phase` + `/council` | ~200k | ~$4 |
| 4 | feat/v6-templates-overlay | HIGH (breaking restructure) | `/gsd-plan-phase` + `/council` | ~200k | ~$4 |
| 5 | feat/v6-external-tools | MED (installer changes) | `/gsd-plan-phase` | ~150k | ~$3 |
| 6 | docs/v6-overlay-architecture | LOW (markdown) | `/gsd-fast` | ~30k | ~$0.50 |
| 7 | feat/v6-release | HIGH (CI + version + tag) | `/gsd-plan-phase` + `/council` | ~200k | ~$4 |

**Total:** ~890k tokens, ~$17 Sonnet 4.6 / ~$60 Opus 4.7. Wall-clock 6-10 hours with checkpoints.

### PR 1 — Trim duplicates (LOW risk)

Pure deletions. No semantic risk. `make check` validates.

DELETE 28 commands, 9 components, 2 skills, 2 templates (nextjs, nodejs).
UPDATE manifest.json (remove deleted entries).

Mode: `/gsd-fast` per group of files (4-5 invocations of fast for clean deletes).

### PR 2 — Additions (MED risk)

NEW content: 1 command (vendor-audit), 6 components, 5 skills, 3 rules.

Each new file is independent — can be parallel. But quality matters (skill frontmatter, audit output format, etc.).

Mode: `/gsd-quick` per group. Skip optional ai-integration agents (no AI runtime here).

### PR 3 — Bridge hooks (HIGH risk)

4 bash hooks calling external tools, security-relevant (auto-triggers /audit, /council, Playwright). Bash injection risk. SQL-injection-equivalent for shell.

Mode: `/gsd-plan-phase` (full pipeline including security audit) + `/council` for plan review (Gemini + GPT external review for shell injection vectors).

### PR 4 — Templates overlay (HIGH risk)

Breaking restructure of how `init-claude.sh` and `init-local.sh` work. Existing v5 users will break if migration not handled. Coverage gate matters here (every framework's idioms must be preserved post-overlay).

Mode: `/gsd-plan-phase` + `/council` for migration script review.

### PR 5 — External tools (MED risk)

`scripts/setup-cost-routing.sh` (better-model wrapper) + integrations-catalog.json additions (Morph + claude-context). Security warning text matters for claude-context.

Mode: `/gsd-plan-phase` (no council needed — narrower scope).

### PR 6 — Documentation (LOW risk)

README architecture section, docs/architecture-v6.md, docs/non-programmer-mode.md, CHANGELOG entry.

Mode: `/gsd-fast` for each doc file separately.

### PR 7 — Release (HIGH risk)

manifest.json 5.0.0 → 6.0.0, Makefile updates, CI workflow updates, migration script (`scripts/migrate-v5-to-v6.sh`), tag v6.0.0, GitHub Release notes.

Migration script is one-way for users. Must be tested against synthetic v5 install.

Mode: `/gsd-plan-phase` + `/council` for migration script + release notes review.

---

## Implementation strategy options

| Approach | Cost | Quality | Time | Best for |
|---|---|---|---|---|
| Full GSD pipeline all PRs | $15-30 Sonnet / $60-100 Opus | Maximum | 7-14 hours | Mission-critical, regulated |
| Mixed (this plan) | $10-20 Sonnet / $40-80 Opus | High | 6-10 hours | **RECOMMENDED — solo + non-programmer** |
| Just /gsd-quick all | $5-10 Sonnet | Medium | 4-6 hours | Pure markdown projects |
| Superpowers + manual | $3-5 Sonnet | Variable | 3-5 hours | Trivial fixes |

Recommended: **Mixed.** Match mode to risk. Spend GSD heavyweight where it counts (PR 3, 4, 7).

---

## Order of execution

```text
PR 1 (trim) → PR 2 (additions) → PR 3 (hooks) → PR 4 (templates) → PR 5 (external) → PR 6 (docs) → PR 7 (release)
```

Sequential, NOT parallel:

- PR 2 depends on PR 1 (kill before add to avoid conflicts)
- PR 3 hooks reference components from PR 2
- PR 4 templates overlay references base updates
- PR 5 installer changes assume PR 4's structure
- PR 6 docs describe final state
- PR 7 release cuts after all merged

Each PR: branch from main → execute → `make check` → `/audit code` → PR → review → merge → next.

Estimated wall-clock 1-2 days if dedicated, 1 week part-time.

---

## Critical caveats

### v6 vendor risk

If GSD pivots toward $GSD memecoin marketing or Superpowers maintainer (Jesse Vincent / fsck) goes inactive — toolkit gracefully degrades:

- Without GSD: `/audit`, `/council`, `/learn`, `/vendor-audit` work. Recommended manual workflow via Superpowers brainstorming + writing-plans.
- Without Superpowers: GSD covers most discipline. Toolkit `/audit` + `/council` for verification.
- Without both: standalone mode (toolkit ships base templates as v5 did).

### Migration script safety

`scripts/migrate-v5-to-v6.sh`:

- Backup `~/.claude/.toolkit-backup-v5-<timestamp>/` (compressed, 50MB max)
- Reversible: `migrate-v5-to-v6.sh --rollback` restores from backup
- Detect: GSD installed? SP installed? Both? Neither? → 4 different post-migration messages
- DRY-RUN flag: `--dry-run` shows what would change

### Smart-merge for CLAUDE.md

User's project CLAUDE.md may have customizations. Migration must preserve user-managed sections (existing v5 logic in `update-claude.sh:179-266`). Test fixture with custom sections required in CI.

### Better-model order

Better-model `init` injects `model:`/`effort:` frontmatter into existing agents/skills. Install order matters:

1. GSD plugin (creates ~/.claude/agents/gsd-*.md if full mode)
2. Superpowers plugin (creates ~/.claude/skills/*/SKILL.md)
3. Toolkit (creates project .claude/agents/, .claude/skills/)
4. Morph MCP (creates MCP entry, no frontmatter target)
5. better-model init (injects into all above)
6. claude-context MCP (optional, separate from frontmatter)

`scripts/setup-cost-routing.sh` enforces this order via prerequisites check.

### claude-context security for sensitive code

For lantern + notebooklm-ultra:

- DO NOT use Zilliz Cloud free tier (shared metadata)
- DO use self-hosted Milvus locally (Docker Compose, ~5 min setup)
- DO consider Voyage AI or Ollama for embedding instead of OpenAI (verify claude-context support)

`components/large-codebase-search.md` includes docker-compose snippet.

---

## Decision matrix for daily work post-v6

| Task | Tool | Why |
|---|---|---|
| Trivial fix (typo, 1 line) | `/gsd-fast` + Morph Fast Apply | Cheapest, no agents |
| Small feature (<100 LOC) | `/gsd-quick` + Morph Fast Apply | Skip optional agents |
| Big feature (auth, payments) | `/gsd-plan-phase` + toolkit `/council` | Full pipeline + external review |
| Bug investigation | Superpowers `systematic-debugging` skill | Scientific method |
| TDD for new feature | Superpowers `test-driven-development` skill | IRON LAW |
| Brainstorm new idea | Superpowers `brainstorming` skill | HARD-GATE design |
| Multi-file refactor (3+) | `/gsd-plan-phase`, better-model auto-routes Opus xhigh | Right model for task |
| Code search small project | Morph warpgrep | No index needed |
| Code search lantern/notebooklm | claude-context MCP | Persistent index, free queries |
| Edits any project | Morph Fast Apply via mcp__morph-fast-tools__edit_file | 5-10x cheaper than native Edit |
| Security-sensitive change | toolkit `/audit security` + `/council` after `/gsd-secure-phase` | Triple layer |
| Pre-ship reality check | toolkit reality-check skill | GSD blind spot fill |
| Quarterly review | toolkit `/vendor-audit` | Catch GSD/SP/external drift early |

---

## Success criteria for v6

- [ ] Toolkit size reduced 60% (651KB → 259KB)
- [ ] Zero file conflicts with GSD or Superpowers (verified via manifest detection)
- [ ] All 7 PRs merged, `make check` green on each
- [ ] Migration script tested against synthetic v5 install (CI)
- [ ] `/vendor-audit` command runs successfully on first quarterly check
- [ ] User reports: real per-pipeline cost ≤50k tokens for `/gsd-quick` flows on small phase
- [ ] User reports: production observability captures regression in test deploy
- [ ] User reports: claude-context indexes notebooklm-ultra successfully (305k LOC, ~$3 one-time)

---

## Next session priorities (if interrupted)

1. Confirm execution mode: full GSD / mixed / superpowers-only
2. Start PR 1 (trim duplicates) — lowest risk, fast win
3. Run `/gsd-new-milestone v6.0` to create proper roadmap if going full GSD route
4. Generate `.planning/v6.0-REQUIREMENTS.md` + `v6.0-ROADMAP.md` artifacts

---

**Plan version:** 1.0  
**Created:** 2026-05-06  
**Generated through:** 7-turn discussion with verified data (GSD source code, Superpowers v5.1 plugin, Morph MCP config, project sizes)
