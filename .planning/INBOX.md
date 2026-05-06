# Inbox — Captured ideas pending triage

Items here are raw captures from mid-workflow conversations. Triage to backlog (`/gsd-add-backlog`), to a phase scope, or to a new phase via `/gsd-insert-phase` / `/gsd-add-phase`.

---

## 2026-04-29 — Auto-update mechanism for skills + MCPs

**Captured during:** `/gsd-plan-phase 24` (Phase 24 — Unified TUI Installer)
**Source:** User request: "было бы классно ещё какой-то автоапдейт туда встроить, вот для таких штук"

### Problem

Skills and MCP servers update independently in their upstream repos. No toolkit-level mechanism today to pull those updates. Users currently must:

- **Plugin skills** — `claude plugin update <name>` (per-plugin, manual)
- **Local skill repos** — `cd ~/.claude/skills/<name> && git pull` (per-skill, manual)
- **MCP servers** — depends on transport: `npx/uvx @latest` auto-updates on CC restart; `npm update -g <pkg>` for global; rebuild for binaries
- **No "update everything" command** that fans out across all installed sources

### Proposed shape (for triage discussion)

**Scope candidates:**

1. **New phase 28: Auto-update orchestrator** — `scripts/update-skills-mcps.sh` that fans out:
   - For each plugin in `~/.claude/plugins/*` → `claude plugin update <name>` (or marketplace API)
   - For each git-tracked dir in `~/.claude/skills/*` → `git -C "$dir" pull --ff-only`
   - For each MCP in `~/.claude.json` `mcpServers{}` with `npx/uvx` transport → no-op (auto on restart) but emit advisory
   - For each MCP with pinned `npm` global → `npm update -g <pkg>`
   - Summary table via `dro_*` API matching Phase 24 install summary precedent

2. **Hook into Phase 25 (MCP Selector)** — add `--update` mode to `install-mcps.sh`
3. **Hook into Phase 26 (Skills Selector)** — add `--update` mode to `install-skills.sh`
4. **Single TUI page in `install.sh` v2** — "Update installed components" alongside "Install new"

### Open questions for triage

- Should auto-update run on a schedule (cron/launchd) or stay manual?
- Pin-vs-latest policy: opt-in only (user toggle in TUI) or opt-out by default?
- Notification UX when an update is available without applying it?
- Roll-back path if an update breaks (skill repo: `git reset --hard ORIG_HEAD`; plugin: re-install previous tag)?

### Recommended triage

- Defer until Phase 25 (MCP Selector) and Phase 26 (Skills Selector) ship — both will define the catalog format that update logic depends on
- Promote to **new Phase 28** under v4.5 milestone after Phase 26 closes (or v4.6 milestone if v4.5 closes first)

---

## 2026-04-29 — Add `huashu-design` skill to Phase 26 Skills Selector

**Captured during:** `/gsd-plan-phase 24`
**Source:** User request: "добавь в инсталлер еще 1 скилл npx skills add alchaincyf/huashu-design"

### What

Add `alchaincyf/huashu-design` to the Phase 26 Skills Selector catalog so users can install it via the toolkit TUI.

### Install command (verified shape from upstream)

```bash
npx skills add alchaincyf/huashu-design
```

This is the `claude-code-skills-marketplace` CLI (already used by other entries in the planned Phase 26 mirror). No new transport needed.

### Where it slots

- `templates/skills/huashu-design.json` (Phase 26 will define the manifest format)
- Add `is_huashu_design_installed` probe — `[ -d "$HOME/.claude/skills/huashu-design" ]` or marketplace API check
- Add `dispatch_huashu_design` — wrapper around `npx skills add alchaincyf/huashu-design`

### Recommended triage

- Add to Phase 26 CONTEXT.md `<decisions>` block when Phase 26 reaches `/gsd-discuss-phase`
- Source-of-truth for the skill list is Phase 26 — do not touch Phase 24 scope (TUI infra only, no per-skill catalog)

---

## 2026-05-06 — Phase B: Pocock CONTEXT.md doctrine + zoom-out + audit-depth

**Captured during:** Phase A completion (review.json + plan-md-anti-bloat + frontmatter component shipped, commits `07411fc..efac741`).
**Source:** Pocock skills audit (mattpocock/skills) + Warp `.agents/skills/` audit. Phase A landed Tier 1 picks; Phase B is the next batch.

### Scope (3 sub-items, ~700 LOC md, 1-2 days)

**B.1 — CONTEXT.md / ubiquitous-language doctrine (Pocock `grill-with-docs`)**

Domain glossary doctrine, distinct from existing operational `.claude/rules/project-context.md`.

Files to create:

- `components/ubiquitous-language.md` — doctrine + format + examples (~200 LOC)
- `templates/base/rules/context-md-format.md` — auto-load with `globs: ["**/*"]`, teaches agents how to read/write `CONTEXT.md` (~80 LOC)
- `commands/context.md` — `/context` slash command for grill-session targeting CONTEXT.md (~120 LOC)

Hooks into existing GSD:

- `/gsd-discuss-phase` — read `CONTEXT.md` (if exists), reconcile phase terms with glossary, update inline.
- `/gsd-plan-phase` — names in `PLAN.md` drawn from CONTEXT.md (mini-validator: grep task names vs glossary).
- `/gsd-new-project` — optionally seed `CONTEXT.md` from roadmap.

Source: `mattpocock/skills/skills/engineering/grill-with-docs/{SKILL.md,CONTEXT-FORMAT.md,ADR-FORMAT.md}`.

Architectural rule (locked in Phase A): touch only toolkit-owned files. CONTEXT.md hooks via auto-loaded rule files, not by editing `~/.claude/skills/gsd-*` or `~/.claude/agents/`.

**B.2 — `/zoom-out` slash command (Pocock `zoom-out`)**

Single-file copy. Trivial. Adds value only after B.1 ships (depends on `CONTEXT.md` glossary).

- `commands/zoom-out.md` (~30 LOC)
- Frontmatter: `disable-model-invocation: true` so agents only run on explicit user invoke.

Source: `mattpocock/skills/skills/engineering/zoom-out/SKILL.md`.

**B.3 — `/audit-depth` Ousterhout deep-modules audit (Pocock `improve-codebase-architecture`)**

3-phase audit (Explore → Present candidates → Grilling loop). No equivalent in toolkit (`simplify` is diff-level, `code-reviewer` is review-time, `/gsd-map-codebase` describes structure but doesn't propose refactors).

Files to create:

- `templates/base/prompts/audit-architecture-depth.md` — audit prompt with `QUICK CHECK` + `SELF-CHECK` headings (Makefile validator requirement) (~250 LOC)
- `templates/base/rules/architecture-language.md` — Ousterhout glossary (Module / Interface / Depth / Seam / Adapter / Leverage / Locality), `globs: ["**/*"]` (~120 LOC)
- `commands/audit-depth.md` — slash command (~80 LOC)

Source: `mattpocock/skills/skills/engineering/improve-codebase-architecture/{SKILL.md,LANGUAGE.md,DEEPENING.md,INTERFACE-DESIGN.md}`.

### Manifest entries needed

```text
files.commands: context.md, zoom-out.md, audit-depth.md
files.rules:    context-md-format.md, architecture-language.md
files.prompts:  audit-architecture-depth.md
inventory.components: ubiquitous-language.md
```

### Recommended triage

- Run B.1 first (B.2 depends on it; B.3 is independent).
- Use `/gsd-quick` per file rather than full GSD pipeline — markdown-only, no codebase scan needed.
- One `/council` call on the final B.1 doctrine draft (Gemini + GPT) to validate the philosophy before locking format.
- Each sub-item = atomic commit. Single PR or three small ones.

---

## 2026-05-06 — Phase C: diagnose-ci + feature-flag-lifecycle (optional)

**Captured during:** Same conversation as Phase B above.
**Source:** Warp `.agents/skills/` audit Tier 2 picks.

### Scope (2 sub-items, ~300 LOC md, ~1 day)

**C.1 — `/diagnose-ci` (Warp `diagnose-ci-failures`)**

7-step deterministic CI-failure analysis loop. Currently `/gsd-debug` is generic scientific-method; CI failures have specifics (parsing run logs, cross-platform results, flaky-vs-real).

Workflow:

1. `git branch --show-current` + `gh pr view` — confirm PR exists.
2. `gh pr view --json statusCheckRollup` — fetch all check states.
3. `gh run view <id> --log-failed` — pull only failed-step logs.
4. Categorize errors: formatting / linting / compile / test / platform-specific.
5. **Plan-first discipline** — emit a `create_plan`-style plan, never `Edit` directly.
6. Cross-reference `fix-errors` for resolution recipes.
7. Validation footer: `Found: 1 critical, 2 important, 3 suggestions`.

Files:

- `commands/diagnose-ci.md` (~150 LOC)

Alternative: a `/gsd-debug --ci` mode flag instead of a separate command — less surface area, but requires editing GSD upstream and conflicts with the "no upstream edits" rule. Prefer separate command.

Source: `warpdotdev/warp/.agents/skills/diagnose-ci-failures/SKILL.md`.

**C.2 — `components/feature-flag-lifecycle.md` (Warp `add-feature-flag` / `remove-feature-flag` / `promote-feature`)**

Framework-agnostic FF lifecycle component. Cite from `/gsd-plan-phase` for risky changes.

Phases: `add → preview → release → remove`, with checklists per phase, naming conventions, code-search recipes for ripping out a flag, anti-patterns ("don't gate per-call-site, gate at the feature surface").

Files:

- `components/feature-flag-lifecycle.md` (~150 LOC)

Source: `warpdotdev/warp/.agents/skills/{add-feature-flag,remove-feature-flag,promote-feature}/SKILL.md`.

### Recommended triage

- Lower priority than Phase B — drop entirely if budget tight.
- C.1 high-value when user is on a CI-heavy project; less so for solo doc work.
- C.2 high-value if Phase B `audit-depth` lands first (FF discipline complements deep-module discipline).

---
