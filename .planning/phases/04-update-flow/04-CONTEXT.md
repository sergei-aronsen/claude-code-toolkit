# Phase 4: Update Flow - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Refactor `scripts/update-claude.sh` to be state-aware, manifest-driven, mode-aware, and drift-surfacing. End state:

1. Reads `~/.claude/toolkit-install.json` via `scripts/lib/state.sh` on start; if absent (v3.x user), synthesizes state from filesystem scan + `recommend_mode(HAS_SP, HAS_GSD)` and writes the synthesized file before proceeding.
2. Sources `scripts/detect.sh` (already wired in Phase 3 D-31). If `install.mode != recommend_mode(HAS_SP, HAS_GSD)`, prompts the user to switch. On accept: in-place re-compute of skip-set, remove now-conflicting files, install new-required files, update `install.mode`.
3. Iterates file list from `manifest.json` filtered by `compute_skip_set <mode>` (sourced from `scripts/lib/install.sh` per Phase 3 D-44/D-45) — no hand-maintained lists in `update-claude.sh` (structural fix to BUG-07 class of drift; satisfies UPDATE-02).
4. Diffs current `manifest.json` vs `install_files[]` in `toolkit-install.json`: new files (after skip-set) auto-install; removed files trigger a single batch prompt `[y/N]` with backup before deletion.
5. Locally-modified TK files (filesystem hash ≠ `install_time_hash` from `toolkit-install.json`) trigger per-file prompt `[y/N/d]` (d = show unified diff, re-prompt).
6. Backup layout: full `~/.claude-backup-<unix-ts>-<pid>/` tree copied at start of any mutating run; no backup on no-op runs.
7. Post-run summary: four groups `INSTALLED N / UPDATED M / SKIPPED P (reason per file) / REMOVED Q (backed up to <path>)`. No-op runs print `Already up-to-date. Nothing to do.` and exit 0.

In scope: UPDATE-01..06. Out of scope: migration script (Phase 5 MIGRATE-01..06), documentation updates (Phase 6), release validation (Phase 7), backup pruning (BACKUP-01/02 deferred to v4.1).

</domain>

<decisions>
## Implementation Decisions

### State consumption + v3.x path (UPDATE-01)

- **D-50:** `update-claude.sh` reads `~/.claude/toolkit-install.json` via `scripts/lib/state.sh::load_state` immediately after sourcing `detect.sh`. If the file is missing, synthesize state inline: (a) set `mode = recommend_mode(HAS_SP, HAS_GSD)`, (b) scan `~/.claude/` for files matching any path in `manifest.files.*` (treat present files as `installed_files`, compute their current hashes as `install_time_hash`), (c) set `install_time = "unknown"`, `toolkit_version = <current local>`, (d) write the synthesized file via `state.sh::save_state` before proceeding with the normal update flow. Print `First update after v3.x — synthesized install state from filesystem (mode=<X>).` as an info line so the user sees what happened. No interactive confirmation required for the synthesis itself — it only describes what is already on disk.
- **D-51:** Mode drift detection runs after state load: compare `state.mode` to `recommend_mode(HAS_SP, HAS_GSD)`. On mismatch, print a two-line table (`Current: <mode>` / `Recommended: <mode> (based on detected SP+GSD)`) and prompt `Switch to <recommended>? [y/N]` via `< /dev/tty` (matches Phase 3 D-42 pattern). On `y`: run in-place switch per D-52. On `n` or no `/dev/tty`: log `Keeping current mode <mode> — duplicates may be installed/removed accordingly` and proceed in `state.mode`. `--offer-mode-switch=yes` forces the prompt's default answer for scripted flows; `--no-offer-mode-switch` suppresses the prompt entirely.
- **D-52:** Mode switch execution is **in-place, single transaction**. After the user accepts: (a) compute `old_skip_set = compute_skip_set <state.mode>` and `new_skip_set = compute_skip_set <new_mode>`, (b) `files_to_remove = old_installed ∩ new_skip_set` (were installed under old mode, now conflict), (c) `files_to_add = all_manifest_files - new_skip_set - already_installed`, (d) remove the files_to_remove batch (still inside the standard backup created at start of run), (e) install files_to_add, (f) rewrite `toolkit-install.json` with new `mode` and updated `installed_files`. The whole transaction runs inside the same `~/.claude-backup-<ts>-<pid>/` snapshot, so a failure anywhere is recoverable by restoring the backup. No delegation to `init-claude.sh --force` — keeps the switch logic in one place and avoids full teardown.

### Manifest-driven file iteration (UPDATE-02, UPDATE-03, UPDATE-04)

- **D-53:** Install/update loop iterates `manifest.files.*` filtered by `compute_skip_set <mode>` (from `scripts/lib/install.sh`, sourced by `update-claude.sh` in the same mktemp+trap pattern as Phase 3 D-30). No per-bucket file lists in `update-claude.sh` code — all lists come from the manifest. This is the structural fix that prevents BUG-07-class drift: adding a file to `manifest.json` automatically makes `update-claude.sh` consider it. Validated by the existing `make validate` drift check (Phase 2 MANIFEST-04) + a new update-specific test (see D-57).
- **D-54:** New-file detection: compute `new_files = (manifest.files.* - state.installed_files) - current_skip_set`. Auto-install all new_files silently (download + write + hash), append to `state.installed_files`, log to the `INSTALLED N` group of the summary. No interactive prompt — manifest additions are curated upstream, user opted-in to updates by running the script. Files that WOULD be new but are filtered by skip-set go to the `SKIPPED P` group with reason `conflicts_with:<plugin>`.
- **D-55:** Removed-file detection: compute `removed_files = state.installed_files - manifest.files.*`. If `|removed_files| > 0`, print the list (one file per line), then prompt `Delete <N> files removed from manifest? [y/N]` via `< /dev/tty`. On `y`: the global backup already taken at start of run is the recovery path (files are not re-copied — backup is whole-tree), delete each file, log to `REMOVED Q (backed up to <path>)`. On `n` or no `/dev/tty`: skip removal, log each file to `SKIPPED P` with reason `removal_declined`. `--prune=yes` pre-confirms the prompt; `--no-prune` suppresses removal entirely.

### Modified-file handling (additional safety)

- **D-56:** For each file in `state.installed_files ∩ manifest.files.*` (files both installed and still in manifest), compare on-disk hash to `state.installed_files[<path>].install_time_hash`. If they differ, the user has locally modified the file. Prompt `File <path> modified locally. Overwrite? [y/N/d]` via `< /dev/tty`. `d` prints a unified diff of on-disk vs remote (from manifest fetch), then re-prompts. `y` overwrites (global backup covers recovery), `UPDATED M` group gets the file. `n` keeps local, adds to `SKIPPED P` with reason `locally_modified`. No `/dev/tty` fails closed to `n`. Hash algorithm: SHA-256 (matches Phase 1 STATE-04 if already chosen there; otherwise lock SHA-256 for Phase 4).

### Backup layout (UPDATE-05)

- **D-57:** Backup is created ONCE at the start of any mutating run, to `~/.claude-backup-$(date -u +%s)-$$/`, as a full `cp -R` of `~/.claude/`. Created BEFORE any filesystem mutation (install, remove, overwrite, state rewrite). Path is printed once as `Backup created: <path>` and again in the `REMOVED Q (backed up to <path>)` line of the summary (same path — single snapshot). If the run is determined to be a no-op (see D-59), no backup is created. `$$` is the parent script PID so two concurrent updates (separate shells) don't collide even within the same second. Backup pruning / size warnings are explicit non-goals for Phase 4 (BACKUP-01/02 deferred to v4.1 per PROJECT.md Out of Scope).

### Post-run summary (UPDATE-06)

- **D-58:** Summary format is four grouped sections, printed once at the end of any mutating run:
  ```
  Update Summary
  ──────────────
  INSTALLED N
    <path> (new in manifest)
    ...
  UPDATED M
    <path> (remote hash changed)
    ...
  SKIPPED P
    <path> (conflicts_with:superpowers)
    <path> (locally_modified)
    <path> (removal_declined)
    ...
  REMOVED Q (backed up to ~/.claude-backup-<ts>-<pid>/)
    <path>
    ...
  ```
  Reasons in `SKIPPED` are the exact reason token (`conflicts_with:<plugin>`, `locally_modified`, `removal_declined`, `user_declined`, …). Colors via the same ANSI auto-disable pattern as Phase 3 D-36 (`[ -t 1 ]` detection; `INSTALLED` green, `UPDATED` cyan, `SKIPPED` yellow, `REMOVED` red).

### No-op run (re-run idempotence)

- **D-59:** After state load + detect + manifest fetch + diff compute, if (a) `state.mode` matches recommend_mode (no drift), (b) `new_files` is empty, (c) `removed_files` is empty, (d) no modified files detected, (e) `state.toolkit_version == manifest.version`, print `Already up-to-date. Nothing to do.` and exit 0. No backup is created. No `install_time` is rewritten. This matches the `git pull` "Already up to date" UX. Callers scripting around this output can rely on exit 0 + single-line output.

### Process

- **D-60:** Phase 4 ships across multiple plans. Suggested planner split: (a) state loading + v3.x synthesis + mode-drift detect+switch (UPDATE-01 logic block), (b) manifest-driven iteration + new/removed/modified file handling (UPDATE-02/03/04/hash-check), (c) backup + summary + no-op detection (UPDATE-05/06 plus wiring). Three plans, executed in dependency order (a → b → c). Plan (a) introduces the state-load code path that plans (b) and (c) assume exists.
- **D-61:** Test harness extends `scripts/tests/` with `test-update-drift.sh` (mode-drift prompt + in-place switch assertions), `test-update-diff.sh` (new/removed/modified file flows with seeded `toolkit-install.json` + fixture manifest), `test-update-summary.sh` (no-op output assertion + full-run summary grouping). All three wired into `make test` as Tests 9/10/11. Test 6/7/8 from Phase 3 must remain green.
- **D-62:** No PR split per cluster — Phase 4 ships as one PR after all plans complete. Conventional Commits: `feat(04-01): ...`, `feat(04-02): ...`, `feat(04-03): ...`. The hand-maintained file lists in `update-claude.sh:125-179` are removed in plan (b) — this deletes the source of BUG-07-class drift. `Makefile:validate` already checks `update-claude.sh` commands against manifest (Phase 1 BUG-07 fix) — that check becomes trivially green once the lists are gone.

### Claude's Discretion

- Exact wording of the mode-drift prompt (D-51), the modified-file prompt (D-56), the removal prompt (D-55), and the no-op line (D-59). Tone should match existing log_info/log_warning usage in `update-claude.sh:49-52`.
- Diff command for the `d` option in D-56: `diff -u` vs `git diff --no-index` vs custom formatter. Any POSIX-available unified diff acceptable. Must respect the "no GNU-only flags" constraint from PROJECT.md.
- Exact shape of `state.installed_files` entries for hash storage. Minimum fields: `path`, `install_time_hash`. Planner may add `installed_version`, `source_template`, or similar if useful.
- Whether `update-claude.sh` reads the remote manifest via curl | mktemp | source (like Phase 3) or downloads once to a tempfile (`mktemp`, `curl -sSL`, parse, `trap rm EXIT`). Either satisfies the constraint that no downloaded content touches `~/.claude/` until after validation.
- Whether the v3.x state synthesis (D-50) uses `sha256sum` (Linux) or `shasum -a 256` (macOS) — either is POSIX-portable via `command -v` detection pattern; planner picks.
- Whether `--prune` / `--no-prune` / `--offer-mode-switch` / `--no-offer-mode-switch` are implemented now (Phase 4) or parked (Phase 4.1). Minimum: the interactive default behavior MUST work; flags are convenience paths.
- Color palette exact bytes — reuse existing `RED/GREEN/YELLOW/BLUE/CYAN/NC` constants; add a new color only if justified.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `scripts/update-claude.sh` — the file being refactored (current hand-maintained file lists at lines 125-179, backup at line 111, no state consumer yet)
- `scripts/lib/state.sh` — Phase 2 atomic state I/O (`load_state`, `save_state`, `acquire_lock`, `release_lock`)
- `scripts/lib/install.sh` — Phase 3 shared helpers (`MODES`, `recommend_mode`, `compute_skip_set`, `backup_settings_once`, `print_dry_run_grouped`, `merge_settings_python`, `merge_plugins_python`)
- `scripts/detect.sh` — Phase 2 detection (`HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION`)
- `scripts/init-claude.sh` — Phase 3 reference for mode-change prompt semantics (D-42 at the mode-switch code region; reuse pattern, don't re-source script)
- `manifest.json` — Phase 2 v2 schema (`manifest_version: 2`, `files.*[].conflicts_with`)
- `scripts/tests/test-modes.sh`, `test-dry-run.sh`, `test-safe-merge.sh` — Phase 3 test patterns to mirror (fixture manifest, `TK_TEST_INJECT_FAILURE` pattern, `assert_eq` helper)
- `.planning/REQUIREMENTS.md` — UPDATE-01..06 authoritative text
- `.planning/phases/03-install-flow/03-CONTEXT.md` — Phase 3 decisions the Phase 4 code reuses (D-31, D-36, D-42, D-44, D-45, D-47)
- `.planning/PROJECT.md` — "destructive action requires [y/N] + backup" invariant; "Out of Scope" list (BACKUP-01/02 deferred)

</canonical_refs>

<non_goals>
## Non-Goals for Phase 4

- Writing `scripts/migrate-to-complement.sh` — Phase 5 scope. Phase 4's v3.x synthesis (D-50) is a minimal in-place adapter, NOT a migration.
- Backup pruning / size warnings / `--clean-backups` flag — BACKUP-01/02 deferred to v4.1.
- Documentation updates (README, CLAUDE.md templates, CHANGELOG 4.0.0 entry) — Phase 6 scope.
- Full install matrix smoke test — Phase 7 scope.
- Plugin-list-based detection (`claude plugin list`) — DETECT-FUT-01 deferred to v4.1.
- Per-file versioning or semver on individual TK files — state tracks `install_time_hash` only; no versioning per-file.
- Auto-retry on curl failures mid-run — first-failure exits with restore-from-backup instructions. User re-runs.

</non_goals>

<deferred_ideas>
## Deferred Ideas (surfaced during discussion, not in Phase 4 scope)

- `--dry-run` on update flow (preview the four summary groups without mutating). Not blocking; could be added in Phase 4 if cheap, otherwise park for v4.1.
- Interactive diff viewer for modified-file prompt (scroll, side-by-side). MVP: single unified diff printed inline.
- Rollback command (`rollback-update.sh`) that targets a specific backup dir. Exists already as a separate command; re-evaluate its interaction with Phase 4's new backup path convention after plans land.

</deferred_ideas>
