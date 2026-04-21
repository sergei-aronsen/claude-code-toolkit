# Phase 3: Install Flow - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire the Phase 2 primitives (`scripts/detect.sh`, `scripts/lib/state.sh`, `manifest.json` v2) into the user-facing install flow. End state:

1. `init-claude.sh` (and `init-local.sh`) detect SP/GSD via `detect.sh`, recommend an install mode, accept user override (`--mode <name>` or interactive prompt), filter `manifest.json` by the active mode's skip-list, install non-conflicting files, persist `toolkit-install.json` via `state.sh`.
2. `--dry-run` prints grouped per-file `[INSTALL]` / `[SKIP — conflicts_with:<plugin>]` preview without touching the filesystem.
3. `update-claude.sh` sources `detect.sh` (DETECT-05 second consumer; full update-flow logic is Phase 4 scope).
4. `setup-security.sh` refactored to safely merge into `~/.claude/settings.json`: atomic backup, python3-based JSON merge, TK-owned subtree strict (SAFETY-01..04).

In scope: DETECT-05 wiring (both init + update scripts), MODE-01..06 (4 modes + recommendation + override + jq skip-list + init-local parity + dry-run), SAFETY-01..04 (atomic merge, backup, hook collision policy, TK-owned subtree invariant).

Out of scope for this phase: full update-flow drift detection (Phase 4 UPDATE-01..06), migration (Phase 5 MIGRATE-01..06), docs (Phase 6 DOCS-01..08), release validation matrix (Phase 7 VALIDATE-01..02). Phase 3 wires `detect.sh` into `update-claude.sh` only enough to satisfy DETECT-05 — full update-flow logic is Phase 4.

</domain>

<decisions>
## Implementation Decisions

### DETECT-05 wiring (carried from Phase 2 gap closure)

- **D-30:** `init-claude.sh` and `init-local.sh` source `scripts/detect.sh` near the top of execution (after argument parsing, before any filesystem write). Local callers use `source "$(dirname "$0")/detect.sh"` per Phase 2 D-04. Remote `curl | bash` callers in `init-claude.sh` use the `DETECT_TMP=$(mktemp) && curl -sSL "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" && source "$DETECT_TMP" && trap 'rm -f "$DETECT_TMP"' EXIT` pattern per Phase 2 D-03.
- **D-31:** `update-claude.sh` sources `detect.sh` the same way as `init-claude.sh` (remote-aware). Phase 3 only wires the source call + exposes `HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION` to the rest of `update-claude.sh`. The actual mode-drift detection logic that consumes those variables is Phase 4 scope (UPDATE-01).

### Mode selection UX (MODE-02, MODE-03)

- **D-32:** Default install flow = interactive prompt with auto-recommendation. After `detect.sh` sources, `init-claude.sh` prints the detected state ("✓ superpowers detected (5.0.7)", "✓ get-shit-done detected (1.2.0)"), the recommended mode ("Recommended: complement-full"), and prompts `Install mode [1=standalone, 2=complement-sp, 3=complement-gsd, 4=complement-full] (default: 4):`. Reuses the existing `read -r -p "..." choice < /dev/tty 2>/dev/null` pattern at `init-claude.sh:84,430`.
- **D-33:** `--mode <name>` CLI flag bypasses the interactive prompt entirely and sets the mode silently. Required for scripted/CI installs and for `curl | bash` flows where stdin is unavailable. Valid values: `standalone`, `complement-sp`, `complement-gsd`, `complement-full`.
- **D-34:** If `--mode` is passed but conflicts with the auto-recommendation (e.g. SP+GSD detected → recommendation is `complement-full`, but `--mode standalone` was supplied): print `WARNING: SP+GSD detected but --mode standalone selected — duplicates will be installed`, then proceed with the user's choice. User-supplied flag = user intent wins. No `--force` required for the initial install (only required for mode change after install per D-43).

### Dry-run output format (MODE-06)

- **D-35:** `--dry-run` output is grouped by manifest bucket (Commands, Agents, Skills, Rules, Templates) with a totals footer. Within each group, one line per file: `[INSTALL] commands/plan.md` or `[SKIP — conflicts_with:superpowers] commands/debug.md`. Footer: `Total: 42 install, 7 skip (6 SP duplicates, 1 GSD duplicate)`. Exit 0 without touching filesystem (matches Phase 1 existing `--dry-run` semantics in `init-local.sh`).
- **D-36:** ANSI colors enabled by default. Auto-disable with `[ -t 1 ]` check — when stdout is not a terminal (piped to `grep`/`tee`/file), strip color codes. `[INSTALL]` is `${GREEN}`, `[SKIP — ...]` is `${YELLOW}`. Reuses existing color constant block at top of every install script. No column padding / table alignment — newline-separated lines that survive 80-column terminals.

### settings.json safe merge (SAFETY-01..04)

- **D-37:** `setup-security.sh` (and any TK script that mutates `~/.claude/settings.json`) refactors to a single `python3` block that: (a) reads existing settings via `json.load`, (b) merges only TK-owned keys, (c) writes to `mktemp -t settings.XXXXXX` then `mv` over the final path. Atomic-mv pattern from Phase 1 D-12 / Phase 2 D-20 (`scripts/setup-security.sh:202-237` already has the python3 idiom — extend, don't rewrite).
- **D-38:** TK-owned subtree is **strict** per SAFETY-04: TK only ever writes to (a) `permissions.deny` entries TK authored, (b) `hooks.PreToolUse[*]` entries TK authored, (c) TK's own `env` block. Every other key in `settings.json` is read-only to TK — never created, never updated, never deleted. The invariant is documented in `setup-security.sh` header and tested by a round-trip test (write known foreign keys, run TK merge, assert foreign keys unchanged).
- **D-39:** Hook collision policy = **append both**. If TK wants to add a hook with `matcher: "Bash"` and an SP/GSD hook with `matcher: "Bash"` already exists, the merge appends a second array entry rather than overwriting. Both hooks fire in array order (Claude Code's documented hook semantics). Preserves SP/GSD behavior; adds TK behavior. User may see two visually-similar hook entries — that's the correct visible state.
- **D-40:** Backup timing = **one atomic backup per install run before first mutation**. `cp ~/.claude/settings.json ~/.claude/settings.json.bak.$(date -u +%s)` runs ONCE at the start of the merge function, only if `settings.json` exists. Subsequent writes within the same run do not re-backup. On any failure mid-merge, restore by `cp ~/.claude/settings.json.bak.<ts> ~/.claude/settings.json` then exit non-zero. Matches SAFETY-03. Backup pruning is explicit non-goal (BACKUP-01/02 deferred to v4.1 per PROJECT.md Out of Scope).

### Re-run + mode change behavior

- **D-41:** Second `init-claude.sh` run when `~/.claude/toolkit-install.json` already exists → **delegate to update-claude.sh**. `init-claude.sh` checks for the state file early (after `detect.sh` sources but before mode prompt); if present, prints `Install already present at ~/.claude/. Use 'update-claude.sh' to refresh or 'init-claude.sh --force' to reinstall.` and exits 0. Clean separation: `init` = first-run, `update` = subsequent. `--force` flag bypasses the check (full re-install with state-file backup).
- **D-42:** Mode-change semantics: when `--mode <X>` is passed and `toolkit-install.json` records mode `<Y>` (X ≠ Y), prompt interactively `Switching <Y> → <X> will rewrite the install. Backup current state and proceed? [y/N]` (matches existing `< /dev/tty` pattern at `init-claude.sh:430`). On `y`: backup old `toolkit-install.json` to `.bak.<unix-ts>`, proceed with new mode. On `n`: exit 0 without changes. Under `curl | bash` (no `/dev/tty`): the prompt fails closed (treated as `n`) — user must pass `--force-mode-change` to bypass the prompt entirely.
- **D-43:** `init-local.sh` writes per-project state at `.claude/toolkit-install.json` (project-scoped, NOT global). Detection runs fresh per project (sources `detect.sh` from the script's own directory each time). Different projects can have different modes — useful for monorepo setups where one sub-project uses SP and another doesn't. The per-project state file uses the same schema as `~/.claude/toolkit-install.json` per Phase 2 D-19.

### Skip-list computation (MODE-04)

- **D-44:** Skip-list is computed at install time by a single `jq` filter over the loaded `manifest.json`. Pseudo-expression: `.files | to_entries | map(.value[] | select((.conflicts_with // []) | any(. == $active_skip))) | flatten | map(.path)`. The `$active_skip` set per mode: `standalone` → `[]`, `complement-sp` → `["superpowers"]`, `complement-gsd` → `["get-shit-done"]`, `complement-full` → `["superpowers", "get-shit-done"]`. Single source of truth: the manifest. No parallel skip-list arrays in shell scripts (this is the structural fix to BUG-07-class drift).
- **D-45:** Mode → skip-set mapping lives in a single helper function (`compute_skip_set <mode>`) sourced from `scripts/lib/install.sh` (NEW shared library) so `init-claude.sh`, `init-local.sh`, and Phase 4's `update-claude.sh` all use the same logic. `scripts/lib/install.sh` exports `MODES`, `compute_skip_set`, `print_dry_run_grouped` (the dry-run formatter — also shared).

### Process

- **D-46:** Phase 3 ships across multiple plans. Suggested cluster split for the planner: (a) DETECT-05 wiring + lib/install.sh skeleton (small, foundational), (b) MODE-01..06 (mode selection, --mode flag, dry-run, jq filter, init-local parity), (c) SAFETY-01..04 (settings.json safe merge, backup, TK-owned subtree). Three plans, executed in dependency order (a → b → c).
- **D-47:** Test harness extends Phase 2's `scripts/tests/` directory. New harnesses: `test-modes.sh` (asserts each of 4 modes computes correct skip-set against a fixture manifest), `test-dry-run.sh` (asserts dry-run output format + zero filesystem touches), `test-safe-merge.sh` (asserts python3 merge preserves foreign keys, backs up, restores on simulated failure). All wired into `make test` as Tests 6/7/8.
- **D-48:** No PRs split per cluster — Phase 3 ships as one PR after all plans complete. Conventional Commits: `feat(03-01): ...`, `feat(03-02): ...`, `feat(03-03): ...`. Three feat commits + per-task atomic commits within each.

### Claude's Discretion

- Exact wording of warning strings (D-34 mismatch, D-42 mode change prompt, D-39 hook collision warning if any).
- Exact filename of the shared library: `scripts/lib/install.sh` proposed but planner may choose a different bucket if it makes the install/update split cleaner.
- Exact `jq` expression syntax for D-44 — any expression that produces the correct skip-list path array is acceptable.
- TK-owned hook identification mechanism — D-38 says "TK authored" but the exact marker (e.g. a `_tk_owned: true` JSON field, a matcher prefix convention, a heuristic on hook command content) is left to the planner. Constraint: the marker must survive a python3 round-trip and be invisible to Claude Code's hook execution semantics.
- Whether `init-local.sh` reuses `init-claude.sh`'s mode-selection prompt verbatim or has its own simpler flow (e.g. project-scope installs may not need the recommendation explanation).
- Whether a new top-level `scripts/lib/` directory is created in Phase 3 or whether `install.sh` lands at `scripts/install-lib.sh` (root). `lib/` is preferred (matches `scripts/lib/state.sh` from Phase 2 D-19) but planner may flatten if there's a reason.
- Exact unit format of timestamps in `toolkit-install.json` `installed_at` field — Phase 2 D-22 already locked ISO-8601 UTC seconds; not a Phase 3 decision.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` §"Plugin Detection" — DETECT-05 (moved from Phase 2 per Phase 2 verifier gap 2).
- `.planning/REQUIREMENTS.md` §"Install Modes" — MODE-01..06 specifications (source of truth).
- `.planning/REQUIREMENTS.md` §"Settings Safe Merge" — SAFETY-01..04 specifications.
- `.planning/ROADMAP.md` §"Phase 3: Install Flow" — phase goal + success criteria 1–5.
- `.planning/PROJECT.md` §"Constraints" — BSD compatibility, `curl | bash` safety, `< /dev/tty` invariant for stdin reads, no Node/Python runtime dependency for install scripts (python3 is allowed per Phase 1 D-05 since it's a documented dep).
- `.planning/PROJECT.md` §"Out of Scope" — auto-installing SP/GSD, migrating without consent, splitting Council, backup pruning.
- `.planning/PROJECT.md` §"Context → Confirmed conflicts with SP/GSD" — the 7 confirmed conflicts that the skip-list filter must handle correctly.

### Prior phase context (carry-forward — load all)

- `.planning/phases/01-pre-work-bug-fixes/01-CONTEXT.md` §"Implementation Decisions → BUG-05" — python3 settings.json merge + unix-timestamp backup pattern (foundational shape for D-37 / D-40).
- `.planning/phases/01-pre-work-bug-fixes/01-CONTEXT.md` §"Implementation Decisions → BUG-04" — `< /dev/tty` guard idiom (used in D-32 prompt + D-42 mode-change prompt).
- `.planning/phases/02-foundation/02-CONTEXT.md` §"Implementation Decisions → D-03/D-04" — local vs remote `detect.sh` source mechanics (D-30 reuses verbatim).
- `.planning/phases/02-foundation/02-CONTEXT.md` §"Implementation Decisions → D-12/D-18" — manifest v2 object shape + closed `conflicts_with` vocabulary (D-44 skip-list filter consumes this).
- `.planning/phases/02-foundation/02-CONTEXT.md` §"Implementation Decisions → D-19/D-20/D-22" — `toolkit-install.json` schema + atomic write + ISO-8601 UTC timestamps (D-43 per-project state reuses).
- `.planning/phases/02-foundation/02-CONTEXT.md` §"Code Context → Reusable Assets" — the python3 / jq / color-constant patterns Phase 3 reuses without re-deciding.

### Phase 2 deliverables (now consumed by Phase 3)

- `scripts/detect.sh` — sourced by `init-claude.sh` (D-30), `init-local.sh` (D-30), `update-claude.sh` (D-31). Exports `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION`.
- `scripts/lib/state.sh` — sourced by both init scripts to call `write_state` (atomic JSON write per Phase 2 D-20) and `acquire_lock` / `release_lock` (mkdir-based per Phase 2 D-08). Phase 3 must use these primitives — no separate write/lock implementation.
- `scripts/validate-manifest.py` — Phase 3 must keep `make validate` green; any new file added to manifest must satisfy Check 6 (drift detection added in Phase 2 gap-closure commit `5fb6f28`).
- `manifest.json` — v2 schema, 7 entries with `conflicts_with: ["superpowers"]`. Phase 3 reads this with `jq` (D-44) to compute the skip-list. No schema changes in Phase 3 (additions allowed; new files added to manifest if any new TK-only files emerge during Phase 3).

### Files to create or extend

- `scripts/init-claude.sh` — EXTEND. Source `detect.sh` (D-30), parse `--mode`/`--force`/`--force-mode-change` flags, run interactive mode prompt (D-32), apply skip-list filter (D-44 via shared `compute_skip_set`), write state via `state.sh` (Phase 2 D-19), pass `--dry-run` through to grouped output (D-35).
- `scripts/init-local.sh` — EXTEND. Same flow as `init-claude.sh` but per-project state at `.claude/toolkit-install.json` (D-43). Re-detects per project.
- `scripts/update-claude.sh` — MINIMAL EXTEND. Source `detect.sh` only — full update-flow drift logic is Phase 4. Phase 3 just makes the variables available so Phase 4 can consume them (D-31).
- `scripts/setup-security.sh` — REFACTOR. Replace existing settings.json mutation block with python3 atomic merge (D-37), one-time backup (D-40), TK-owned subtree strict invariant (D-38), append-both hook policy (D-39).
- `scripts/lib/install.sh` — NEW. Shared helpers: `compute_skip_set <mode>`, `print_dry_run_grouped <files_to_install> <files_to_skip>`, mode validator. Sourced by both init scripts and Phase 4's `update-claude.sh`.
- `scripts/tests/test-modes.sh` — NEW. Asserts each of 4 modes produces the correct skip-set against a fixture manifest. Wired into `make test` as Test 6.
- `scripts/tests/test-dry-run.sh` — NEW. Asserts grouped output format + zero filesystem touches. Wired as Test 7.
- `scripts/tests/test-safe-merge.sh` — NEW. Asserts python3 merge preserves foreign keys, creates backup, restores on simulated failure. Wired as Test 8.
- `Makefile` — EXTEND `test` target with Tests 6/7/8.

### Existing patterns to mirror

- `scripts/init-claude.sh:84` — `read -r -p "..." choice < /dev/tty 2>/dev/null` for interactive choice prompts (D-32, D-42).
- `scripts/init-claude.sh:430` — `read -r -p "...? [Y/n]: " configure < /dev/tty 2>/dev/null` for [Y/n] confirmation prompts.
- `scripts/setup-security.sh:202-237` — existing python3 `json.load` / `json.dump` block (template for D-37).
- `scripts/install-statusline.sh:104` — `cp "$file" "$file.bak.$(date +%s)"` backup pattern (template for D-40).
- `scripts/install-statusline.sh:31-40` — `jq` usage on settings.json (template for D-44 manifest filter).
- All existing `scripts/*.sh` open with `#!/bin/bash` + `set -euo pipefail` + ANSI color constants (`RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC`) per `.planning/codebase/CONVENTIONS.md`. New `scripts/lib/install.sh` is **sourced** (not executed) and follows the Phase 2 `scripts/lib/state.sh` invariant: NO `set -euo pipefail` inside a sourced library, zero stdout during sourcing.

### Background analysis

- `.planning/codebase/STRUCTURE.md` — manifest layout, current install script flow.
- `.planning/codebase/CONVENTIONS.md` §"Code Style — Shell Scripts" — header, function naming, error handling.
- `.planning/codebase/CONCERNS.md` — historical drift list informing why MODE-04 must use a single source of truth (the manifest).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/init-claude.sh:20-30` — existing `--dry-run` flag parsing skeleton. Phase 3 extends with `--mode`, `--force`, `--force-mode-change`.
- `scripts/init-claude.sh:84` and `:430` — `read -r -p "..." choice < /dev/tty 2>/dev/null` pattern. Reused verbatim for D-32 mode prompt and D-42 mode-change prompt.
- `scripts/setup-security.sh:202-237` — python3 `json.load` / `json.dump` block. Foundational for D-37 atomic merge — extend with TK-owned subtree filter, atomic mv, backup logic.
- `scripts/install-statusline.sh:31-40` — `jq` usage. Same `jq` is used in D-44 manifest filtering — no new dependency.
- `scripts/lib/state.sh` (Phase 2) — `write_state`, `acquire_lock`, `release_lock` exported functions. Phase 3 sources and calls these directly; no re-implementation.
- Color constants block (`RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC`) repeated at top of every install script — reused by `scripts/lib/install.sh`'s dry-run formatter.

### Established Patterns

- `#!/bin/bash` + `set -euo pipefail` + ANSI color constants at top of every executable script.
- Sourced library files (Phase 2 D-19 / `scripts/lib/state.sh`): NO `set -euo pipefail`, zero stdout during sourcing, function names in `snake_case`. `scripts/lib/install.sh` follows this invariant.
- `< /dev/tty 2>/dev/null` guard on every `read -r -p` to survive `curl | bash` flows.
- python3 for JSON manipulation (Phase 1 D-12, Phase 2 D-20). Phase 3 reuses for SAFETY-01..04 atomic merge.
- Conventional Commits: one commit per task, branch per phase, never push to main.
- `manifest.json` is hand-edited and diff-reviewed — Phase 3 may add new files (e.g. `scripts/lib/install.sh`, the three test harnesses) but every addition lands in `manifest.json` in the same PR (or `make validate` Check 6 will fail).

### Integration Points

- `make test` runs all test harnesses — Phase 3 adds Tests 6/7/8 to this target.
- `make validate` runs `scripts/validate-manifest.py` — Phase 3 must keep this green (any new file added under `commands/` or `templates/base/skills/` requires manifest entry per Check 6).
- `make shellcheck` runs over `scripts/` — `scripts/lib/install.sh` and the three new test harnesses must pass shellcheck severity warning (matches Phase 2 enforcement).
- `~/.claude/settings.json` — primary write target for SAFETY-01..04. The TK-owned subtree (D-38) must survive co-existence with SP and GSD's hook entries.
- `~/.claude/toolkit-install.json` — written by `init-claude.sh` via `state.sh write_state`. Per-project equivalent at `.claude/toolkit-install.json` (D-43).

### Files NOT Touched in Phase 3

- `manifest.json` — schema unchanged. Only additions for new Phase 3 files (lib/install.sh, test harnesses).
- `templates/*/` — Phase 3 does not edit template contents. Skip-list filtering happens at install time, not authoring time.
- `scripts/install-statusline.sh`, `scripts/setup-council.sh` — no changes (they don't manipulate `settings.json` in the SAFETY-04 sense; they have their own scoped writes).
- `CHANGELOG.md` — Phase 6 owns this.

</code_context>

<specifics>
## Specific Ideas

- "Single source of truth: the manifest." MODE-04 skip-list MUST be derived from `manifest.json` `conflicts_with` annotations. No parallel skip-list arrays in shell. This is the structural fix to the BUG-07 class of drift.
- "User-supplied flag wins" (D-34). When `--mode` conflicts with the auto-recommendation, warn but proceed. Don't block.
- "Append both for hook collisions" (D-39). Never silently overwrite an SP/GSD hook. Both fire in array order. Two visible entries is the correct state.
- "Strict TK-owned subtree" (D-38). The settings.json invariant is the smallest possible surface: TK only ever writes to keys/entries TK created. Every other byte is read-only.
- "init = first-run, update = subsequent" (D-41). Re-running `init-claude.sh` over an existing install delegates to `update-claude.sh`. Clean separation. `--force` bypasses for intentional re-installs.
- "Per-project state for init-local.sh" (D-43). `.claude/toolkit-install.json` is project-scoped. Detection re-runs per project. Different projects can run different modes.
- "scripts/lib/install.sh is sourced, not executed" — same invariant as Phase 2's `scripts/lib/state.sh`. No `set -euo pipefail`, zero stdout during source.
- "Three plans, one PR" (D-46/D-48). Plan split: (a) DETECT-05 wiring + lib skeleton, (b) MODE-01..06 user-facing flow, (c) SAFETY-01..04 settings merge.

</specifics>

<deferred>
## Deferred Ideas

- Full update-flow drift detection (re-evaluate mode if base set changed since install, prompt user) — UPDATE-01..06, **Phase 4**.
- Migration script for v3.x users (`scripts/migrate-to-complement.sh`) — MIGRATE-01..06, **Phase 5**.
- Backup pruning (clean old `settings.json.bak.<ts>` files, warn over threshold) — BACKUP-01/02, **v4.1** per PROJECT.md Out of Scope.
- Timeout auto-accept (`Install in 10s, any key for menu`) — considered and rejected for Phase 3 in favor of simpler interactive prompt + `--mode` flag duality. Could revisit in v4.1.
- Configurable TK-owned subtree via `manifest.json` `owned_settings_keys: [...]` — rejected for Phase 3 in favor of strict per-SAFETY-04 invariant. Adds schema surface; not needed yet.
- TK-owned hook identification via JSON marker (`_tk_owned: true`) — left to planner discretion (D-38). Could be a marker field, a matcher prefix convention, or a content-fingerprint heuristic. Decision deferred to planner.
- `init-claude.sh` sharing the mode-prompt UX with `init-local.sh` verbatim vs init-local using a simpler project-scoped prompt — left to planner discretion.
- Styled diff for dry-run (per-file change preview, not just install/skip) — explicitly v4.1 per PROJECT.md Out of Scope.

</deferred>

---

*Phase: 03-install-flow*
*Context gathered: 2026-04-18*
