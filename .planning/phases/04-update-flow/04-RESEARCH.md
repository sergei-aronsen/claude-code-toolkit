# Phase 4: Update Flow - Research

**Researched:** 2026-04-18
**Domain:** POSIX shell / manifest-driven update refactor / drift detection / portable hashing and diffing
**Confidence:** HIGH (every load-bearing claim below was verified against the live repo or the jq 1.7 manual; the two `[ASSUMED]` items are flagged explicitly)

## Summary

Phase 4 turns `scripts/update-claude.sh` from a hand-maintained copy loop (29 `commands/` filenames literally written out at line 173) into a state-aware, manifest-driven refactor. Every one of the 13 user decisions (D-50..D-62) builds on Phase 2/3 primitives that are already on disk and already passing `make test` (Tests 1-8). The work consists almost entirely of **composing existing helpers** — `compute_skip_set`, `recommend_mode`, `acquire_lock`/`release_lock`, `write_state`, `read_state`, `sha256_file`, `backup_settings_once` — plus one new helper (`hash_file` wrapper is unnecessary because `lib/state.sh::sha256_file` already uses `python3 hashlib.sha256` and is platform-agnostic).

The two genuinely new pieces of work are (1) **computing three file-set diffs** (new / removed / modified) between `manifest.files.*` and `state.installed_files[]`, and (2) **deciding the control flow** for the five mutation paths (auto-install new, prompt-then-delete removed, prompt-then-overwrite modified, mode-switch transaction, no-op early-exit). Both are pure bash + jq + the python3 `json.load` idiom the repo already uses four times elsewhere. No new dependencies, no new library files beyond adding functions to the existing `scripts/lib/install.sh`.

The biggest structural win — beyond satisfying UPDATE-02 — is that **deleting lines 125-179 of `update-claude.sh` eliminates the BUG-07 class of drift**. The `Makefile:108-128` drift check against `update-claude.sh`'s commands loop becomes trivially green (nothing to drift against). Plan (b) per D-60 is therefore not just a refactor but a **load-bearing deletion**: the old hand-list is the bug.

**Primary recommendation:** Ship Phase 4 as three plans in dependency order (a) state-load + v3.x synthesis + mode-drift, (b) manifest-driven iteration + new/removed/modified handling, (c) backup + summary + no-op. Reuse `lib/state.sh::sha256_file` as the single hashing primitive — **do not** reintroduce a shell-level `shasum`/`sha256sum` fork. Put the new diff-compute function (`compute_file_diffs` or similar) in `scripts/lib/install.sh` next to `compute_skip_set` so Phase 5 (migration) can reuse it. Mirror Phase 3's `scripts/tests/test-modes.sh` / `test-dry-run.sh` / `test-safe-merge.sh` structure for the three new tests — same `report_pass`/`assert_eq` style, same fixture-manifest pattern, same scenario-per-function decomposition.

## Architectural Responsibility Map

Phase 4 is a **single-tier** refactor: it's all POSIX shell on the user's local machine. There is no client/server/API split. The "tiers" that matter here are the layers of the shell-library stack, which the mapping below captures.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| State I/O (load toolkit-install.json, atomic write) | `scripts/lib/state.sh` | — | Already owns `read_state` / `write_state` / `sha256_file` / `get_mtime`. Phase 4 must not duplicate; it calls these. |
| Mode computation (skip-set, recommendation) | `scripts/lib/install.sh` | — | Already owns `compute_skip_set` + `recommend_mode` + `MODES` array. Phase 4 reuses verbatim. |
| Concurrency (lock + stale recovery) | `scripts/lib/state.sh` | — | Already owns `acquire_lock` / `release_lock` with PID liveness + 1h-mtime stale recovery (Scenario D/E of test-state.sh). Phase 4 wraps update flow in the canonical `trap 'release_lock' EXIT; acquire_lock \|\| exit 1` pattern. |
| File-set diff (new / removed / modified) | `scripts/lib/install.sh` (NEW functions) | — | New logic. Belongs next to `compute_skip_set` so Phase 5 migration can reuse the same diff primitive against a different "expected" set. |
| V3.x state synthesis (filesystem scan) | `scripts/update-claude.sh` inline | `lib/install.sh` optional helper | One-shot adapter for pre-v4 users; does not belong in a reusable library unless Phase 5's migration script also needs it (it likely does — but defer that refactor to Phase 5 when the second consumer exists, per YAGNI). |
| Mutation dispatch (auto-install, prompt+delete, prompt+overwrite) | `scripts/update-claude.sh` | — | Control flow; script-specific. The primitives it calls (curl, cp, jq) are all bash built-in or already sourced. |
| Backup snapshot (`~/.claude-backup-<ts>-<pid>/`) | `scripts/update-claude.sh` inline | — | Single `cp -R` at run start; trivial enough to inline. Different layout from `lib/install.sh::backup_settings_once` (which is a **file** backup, not a **tree** backup) — don't conflate. |
| Post-run summary (4 grouped sections) | `scripts/update-claude.sh` inline | — | Accumulates counters during the mutation loop. Could factor into `lib/install.sh::print_summary_grouped` if the layout ends up identical to Phase 3's `print_dry_run_grouped`, but the labels differ (INSTALLED/UPDATED/SKIPPED/REMOVED vs INSTALL/SKIP/Total) so YAGNI applies. |
| User prompts (`[y/N]`, `[y/N/d]`) | `scripts/update-claude.sh` inline | — | Uses the same `read -r -p "..." choice < /dev/tty 2>/dev/null` idiom that `init-claude.sh` / `init-local.sh` / `setup-council.sh` already use. No new primitive needed. |

**Why this matters for Phase 4:** The temptation will be to put the diff-compute function in `update-claude.sh` because that's the only caller right now. Resist — Phase 5 MIGRATE-02 requires a three-way diff that is a strict superset of the same operation. Putting `compute_file_diffs` in `lib/install.sh` now means Phase 5 extends it rather than re-implementing it.

## User Constraints (from CONTEXT.md)

> Copied verbatim from `.planning/phases/04-update-flow/04-CONTEXT.md` — these are locked decisions the planner MUST honor.

### Locked Decisions

**State consumption + v3.x path (UPDATE-01)**

- **D-50:** `update-claude.sh` reads `~/.claude/toolkit-install.json` via `scripts/lib/state.sh::load_state` immediately after sourcing `detect.sh`. If the file is missing, synthesize state inline: (a) set `mode = recommend_mode(HAS_SP, HAS_GSD)`, (b) scan `~/.claude/` for files matching any path in `manifest.files.*` (treat present files as `installed_files`, compute their current hashes as `install_time_hash`), (c) set `install_time = "unknown"`, `toolkit_version = <current local>`, (d) write the synthesized file via `state.sh::save_state` before proceeding with the normal update flow. Print `First update after v3.x — synthesized install state from filesystem (mode=<X>).` No interactive confirmation required for the synthesis itself — it only describes what is already on disk.

- **D-51:** Mode drift detection runs after state load: compare `state.mode` to `recommend_mode(HAS_SP, HAS_GSD)`. On mismatch, print a two-line table (`Current: <mode>` / `Recommended: <mode> (based on detected SP+GSD)`) and prompt `Switch to <recommended>? [y/N]` via `< /dev/tty`. On `y`: run in-place switch per D-52. On `n` or no `/dev/tty`: log `Keeping current mode <mode> — duplicates may be installed/removed accordingly` and proceed in `state.mode`. `--offer-mode-switch=yes` forces the prompt's default answer for scripted flows; `--no-offer-mode-switch` suppresses the prompt entirely.

- **D-52:** Mode switch execution is **in-place, single transaction**. (a) compute `old_skip_set = compute_skip_set <state.mode>` and `new_skip_set = compute_skip_set <new_mode>`, (b) `files_to_remove = old_installed ∩ new_skip_set` (were installed under old mode, now conflict), (c) `files_to_add = all_manifest_files - new_skip_set - already_installed`, (d) remove the files_to_remove batch (still inside the standard backup created at start of run), (e) install files_to_add, (f) rewrite `toolkit-install.json` with new `mode` and updated `installed_files`. Whole transaction inside the same `~/.claude-backup-<ts>-<pid>/` snapshot. No delegation to `init-claude.sh --force`.

**Manifest-driven file iteration (UPDATE-02, UPDATE-03, UPDATE-04)**

- **D-53:** Install/update loop iterates `manifest.files.*` filtered by `compute_skip_set <mode>` (from `scripts/lib/install.sh`, sourced by `update-claude.sh` in the same mktemp+trap pattern as Phase 3 D-30). No per-bucket file lists in `update-claude.sh` code — all lists come from the manifest. Structural fix that prevents BUG-07-class drift: adding a file to `manifest.json` automatically makes `update-claude.sh` consider it.

- **D-54:** New-file detection: compute `new_files = (manifest.files.* - state.installed_files) - current_skip_set`. Auto-install all new_files silently (download + write + hash), append to `state.installed_files`, log to the `INSTALLED N` group. No interactive prompt. Files that WOULD be new but are filtered by skip-set go to the `SKIPPED P` group with reason `conflicts_with:<plugin>`.

- **D-55:** Removed-file detection: compute `removed_files = state.installed_files - manifest.files.*`. If `|removed_files| > 0`, print the list, then prompt `Delete <N> files removed from manifest? [y/N]` via `< /dev/tty`. On `y`: global backup is the recovery path (files are not re-copied — backup is whole-tree), delete each file, log to `REMOVED Q (backed up to <path>)`. On `n` or no `/dev/tty`: skip removal, log each file to `SKIPPED P` with reason `removal_declined`. `--prune=yes` pre-confirms; `--no-prune` suppresses removal entirely.

**Modified-file handling (additional safety)**

- **D-56:** For each file in `state.installed_files ∩ manifest.files.*`, compare on-disk hash to `state.installed_files[<path>].install_time_hash`. If they differ, prompt `File <path> modified locally. Overwrite? [y/N/d]` via `< /dev/tty`. `d` prints a unified diff of on-disk vs remote (from manifest fetch), then re-prompts. `y` overwrites (global backup covers recovery), `UPDATED M` group gets the file. `n` keeps local, adds to `SKIPPED P` with reason `locally_modified`. No `/dev/tty` fails closed to `n`. Hash algorithm: SHA-256.

**Backup layout (UPDATE-05)**

- **D-57:** Backup created ONCE at start of any mutating run, to `~/.claude-backup-$(date -u +%s)-$$/`, as a full `cp -R` of `~/.claude/`. Created BEFORE any filesystem mutation. Path printed once as `Backup created: <path>` and again in the `REMOVED Q (backed up to <path>)` summary line. If the run is a no-op (D-59), no backup is created. `$$` is the parent script PID so two concurrent updates don't collide within the same second. Backup pruning is explicit non-goal.

**Post-run summary (UPDATE-06)**

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

  Reasons in `SKIPPED` are exact reason tokens (`conflicts_with:<plugin>`, `locally_modified`, `removal_declined`, `user_declined`). Colors via the same ANSI auto-disable pattern as Phase 3 D-36 (`[ -t 1 ]`; `INSTALLED` green, `UPDATED` cyan, `SKIPPED` yellow, `REMOVED` red).

**No-op run (re-run idempotence)**

- **D-59:** After state load + detect + manifest fetch + diff compute, if (a) `state.mode` matches recommend_mode (no drift), (b) `new_files` is empty, (c) `removed_files` is empty, (d) no modified files detected, (e) `state.toolkit_version == manifest.version`, print `Already up-to-date. Nothing to do.` and exit 0. No backup created. No `install_time` rewritten. Matches `git pull` "Already up to date" UX.

**Process**

- **D-60:** Phase 4 ships across multiple plans. Planner split: (a) state loading + v3.x synthesis + mode-drift detect+switch (UPDATE-01), (b) manifest-driven iteration + new/removed/modified file handling (UPDATE-02/03/04/hash-check), (c) backup + summary + no-op detection (UPDATE-05/06 plus wiring). Three plans, executed in dependency order (a → b → c).

- **D-61:** Test harness extends `scripts/tests/` with `test-update-drift.sh` (mode-drift prompt + in-place switch), `test-update-diff.sh` (new/removed/modified with seeded state + fixture manifest), `test-update-summary.sh` (no-op output + full-run summary grouping). Wired into `make test` as Tests 9/10/11. Tests 6/7/8 from Phase 3 must remain green.

- **D-62:** No PR split per cluster — Phase 4 ships as one PR after all plans complete. Conventional Commits: `feat(04-01): ...`, `feat(04-02): ...`, `feat(04-03): ...`. Hand-maintained file lists in `update-claude.sh:125-179` are removed in plan (b) — deletes the source of BUG-07-class drift. `Makefile:validate` already checks `update-claude.sh` commands against manifest — that check becomes trivially green once the lists are gone.

### Claude's Discretion

- Exact wording of the mode-drift prompt (D-51), the modified-file prompt (D-56), the removal prompt (D-55), and the no-op line (D-59). Tone should match existing `log_info`/`log_warning` usage in `update-claude.sh:49-52`.
- Diff command for the `d` option in D-56: `diff -u` vs `git diff --no-index` vs custom formatter. Any POSIX-available unified diff acceptable. Must respect "no GNU-only flags".
- Exact shape of `state.installed_files` entries for hash storage. Minimum fields: `path`, `install_time_hash`. Planner may add `installed_version`, `source_template`, or similar if useful.
- Whether `update-claude.sh` reads the remote manifest via curl | mktemp | source (like Phase 3) or downloads once to a tempfile (`mktemp`, `curl -sSL`, parse, `trap rm EXIT`). Either satisfies the constraint that no downloaded content touches `~/.claude/` until after validation.
- Whether the v3.x state synthesis (D-50) uses `sha256sum` (Linux) or `shasum -a 256` (macOS) — either is POSIX-portable via `command -v` detection pattern; planner picks.
- Whether `--prune` / `--no-prune` / `--offer-mode-switch` / `--no-offer-mode-switch` are implemented now (Phase 4) or parked (Phase 4.1). Minimum: the interactive default behavior MUST work; flags are convenience paths.
- Color palette exact bytes — reuse existing `RED/GREEN/YELLOW/BLUE/CYAN/NC` constants; add a new color only if justified.

### Deferred Ideas (OUT OF SCOPE)

- `--dry-run` on update flow (preview the four summary groups without mutating). Not blocking; could be added in Phase 4 if cheap, otherwise park for v4.1.
- Interactive diff viewer for modified-file prompt (scroll, side-by-side). MVP: single unified diff printed inline.
- Rollback command (`rollback-update.sh`) that targets a specific backup dir. Exists already as a separate command; re-evaluate its interaction with Phase 4's new backup path convention after plans land.

### Non-Goals for Phase 4 (from CONTEXT.md)

- Writing `scripts/migrate-to-complement.sh` — Phase 5 scope. Phase 4's v3.x synthesis (D-50) is a minimal in-place adapter, NOT a migration.
- Backup pruning / size warnings / `--clean-backups` flag — BACKUP-01/02 deferred to v4.1.
- Documentation updates (README, CLAUDE.md templates, CHANGELOG 4.0.0 entry) — Phase 6 scope.
- Full install matrix smoke test — Phase 7 scope.
- Plugin-list-based detection (`claude plugin list`) — DETECT-FUT-01 deferred to v4.1.
- Per-file versioning or semver on individual TK files — state tracks `install_time_hash` only; no versioning per-file.
- Auto-retry on curl failures mid-run — first-failure exits with restore-from-backup instructions. User re-runs.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPDATE-01 | `update-claude.sh` reads `toolkit-install.json` and re-runs detection; if the detected base set changed since install, prompts user to re-evaluate mode | D-50/D-51/D-52 in CONTEXT.md locked the entire flow. Primitives (`read_state`, `recommend_mode`, `compute_skip_set`, `write_state`) all exist in `lib/state.sh` + `lib/install.sh` (verified against both files). See §V3.x state synthesis algorithm below. |
| UPDATE-02 | Installed-file list iterated from `manifest.json` filtered by active mode (no hand-maintained list — fixes BUG-07 structurally) | `compute_skip_set` already produces a JSON array of skip paths; `manifest.files.*` iteration pattern is demonstrated working in `init-local.sh:255-281` (manifest-driven install loop). Phase 4 lifts and adapts. See §Manifest iteration pattern below. |
| UPDATE-03 | Files newly added to `manifest.json` since last install are detected and offered to the user (with mode-aware skip) | Set-difference via `jq -n --argjson a ... --argjson b ... '$a - $b'` is documented and tested (VERIFIED against jq 1.7.1). See §File-set diff computation. |
| UPDATE-04 | Files removed from `manifest.json` since last install are detected and offered for deletion (with backup, with confirmation) | Same jq set-difference primitive, swapped operand order. Prompt pattern identical to Phase 3 D-42 mode-change prompt (`read -r -p "..." < /dev/tty`). Global tree backup provides recovery; no per-file restore logic needed. |
| UPDATE-05 | Backup directories use timestamp + PID suffix (`~/.claude-backup-<unix-ts>-<pid>/`) so two updates in the same second do not collide | `$$` is the POSIX-standard parent PID variable. `date -u +%s` is the same pattern `backup_settings_once` uses in `lib/install.sh:66`. |
| UPDATE-06 | Post-update summary shows `INSTALLED N`, `UPDATED M`, `SKIPPED P (reason)`, `REMOVED Q (backed up to <path>)` | Parallel to Phase 3's `print_dry_run_grouped` (verified in `lib/install.sh:74-125`), but with different labels and accumulated counters from the mutation loop. Counter pattern (`INSTALLED_PATHS=()` array + `SKIPPED_PATHS+=("path:reason")`) is already used in `init-local.sh:253-281`. |

## Standard Stack

### Core

Everything Phase 4 needs is already installed in the repo. No new dependencies.

| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `bash` | 3.2+ (macOS) / 4.4+ (Linux) | Shell runtime | Already used by every script; `set -euo pipefail` + POSIX subset of features is the repo convention [VERIFIED: `scripts/update-claude.sh:6`, `scripts/lib/install.sh` invariant header] |
| `jq` | 1.7.1 (verified locally) | JSON parsing + array set operations | Already required by Phase 2 (DETECT-03 in `detect.sh:57-71`), Phase 3 (`compute_skip_set` in `lib/install.sh:35-57`); `a - b` on arrays computes set-difference [VERIFIED: jq 1.7 manual — `a - b` removes "all occurrences of the second array's elements from the first array"] |
| `python3` | 3.8+ | Atomic JSON writes, SHA-256 hashing | Already used in `lib/state.sh` (`write_state`, `sha256_file`), `lib/install.sh` (`merge_settings_python`, `merge_plugins_python`), `setup-security.sh` (Steps 3+4 merge). `hashlib.sha256` and `tempfile.mkstemp` + `os.replace` are stdlib [VERIFIED: `lib/state.sh:32-35` `sha256_file` already uses `python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())'`] |
| `curl` | system-provided | Fetch remote manifest + file downloads | Already in every install script; `curl -sSLf ... -o <tmp>` is the established pattern from Phase 3 D-30 [VERIFIED: `init-claude.sh:67-74`, `update-claude.sh:26-30`] |
| `diff` (POSIX) | system-provided (BSD on macOS, GNU on Linux) | Unified diff for D-56 `[y/N/d]` prompt | `diff -u old new` is POSIX — not a GNU extension. Exit code 0=same, 1=different, 2=error. No color flag used (both BSD and some older GNU diffs lack `--color=always`). Output goes to stdout [VERIFIED: `man diff` on macOS Darwin 25.3.0 shows "Apple diff (based on FreeBSD diff)"; the `-u` unified format is in POSIX.1-2008] |

### Supporting — already provided by prior phases

| Symbol | Source | Purpose | When to Use |
|---------|---------|---------|-------------|
| `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` | `scripts/detect.sh` (Phase 2) | Plugin detection | Read by D-51 mode-drift compare; update-claude.sh already sources detect.sh with soft-fail fallback at lines 26-43 [VERIFIED] |
| `MODES` array, `recommend_mode`, `compute_skip_set` | `scripts/lib/install.sh` (Phase 3) | Mode vocabulary + skip-set | Read by D-51 (recommend_mode), D-53/D-54 (compute_skip_set both for current and new mode in mode-switch transaction) [VERIFIED: `lib/install.sh:20-57`] |
| `backup_settings_once`, `TK_SETTINGS_BACKUP` | `scripts/lib/install.sh` (Phase 3) | One-shot settings.json backup | **NOT used by Phase 4.** Phase 4's backup is a **tree** backup (`cp -R ~/.claude/`), not a single-file backup. Keep separate. `backup_settings_once` would be used only if Phase 4 also mutates `settings.json` — which it does not per CONTEXT (no SAFETY work). |
| `read_state`, `write_state`, `acquire_lock`, `release_lock`, `sha256_file`, `get_mtime`, `iso8601_utc_now` | `scripts/lib/state.sh` (Phase 2) | State I/O + locking + hashing | Read: D-50 state load. Write: D-50 v3.x synthesis, D-52 mode-switch, D-54 auto-install append, D-56 overwrite. Lock: wrap the whole mutation flow. Hash: every file install + every on-disk hash comparison for D-56 [VERIFIED: `lib/state.sh:19-153`] |
| `STATE_FILE`, `LOCK_DIR` globals | `scripts/lib/state.sh` (Phase 2) | Canonical paths for state + lock | Default is `$HOME/.claude/toolkit-install.json` and `$HOME/.claude/.toolkit-install.lock`. `update-claude.sh` is a global-scope script (operates on `~/.claude/`, not `.claude/`), so defaults apply — **no reassignment needed** (unlike `init-local.sh:62` which overrides `STATE_FILE` for per-project state) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `python3 hashlib.sha256` (via `lib/state.sh::sha256_file`) | Shell-level `command -v sha256sum >/dev/null && sha256sum "$f" \| awk '{print $1}' \|\| shasum -a 256 "$f" \| awk '{print $1}'` | `sha256_file` already exists, already tested, already cross-platform (python3 hashlib is platform-agnostic). Adding a shell-level sha256 wrapper duplicates logic. **REJECT** — use `sha256_file`. [VERIFIED: `lib/state.sh:32-35`] |
| `diff -u` for D-56 `d` option | `git diff --no-index` or a python3 difflib.unified_diff | `git diff --no-index` is portable but assumes git is installed (it always is in a dev environment but the toolkit must not hard-require it for a non-git operation). `python3 -c 'import difflib; ...'` is fine but `diff -u` is simpler and already portable. **USE `diff -u`.** Exit code 1 on difference is expected — wrap in `\|\| true` or ignore exit code. |
| `jq` set-difference (`a - b`) | Shell arrays + `grep -Fvxf` | jq is already a hard dependency (Phase 2 DETECT-03). Shell-array-based set ops get awkward fast with paths containing spaces. `a - b` on jq arrays is O(n·m) but n is ~50 files; not a bottleneck. **USE jq.** [VERIFIED: jq 1.7.1 manual] |
| `python3 tempfile.mkstemp + os.replace` for state writes | Shell `mktemp + mv` | `lib/state.sh::write_state` already delegates to python3 for atomic writes. Reuse; don't reimplement. |
| Full `rsync -a` for tree backup | `cp -R` | rsync is not guaranteed on minimal Linux installs. `cp -R` is POSIX and already used at `update-claude.sh:112` [VERIFIED]. Switch to `cp -R` (preserves symlinks via `-R`, recursive). |

**Installation:** nothing new to install.

**Version verification (jq set-diff on arrays):**

```bash
$ jq --version
jq-1.7.1-apple

$ jq -n '{a:["x","y","z"], b:["y"]} | .a - .b'
[
  "x",
  "z"
]
```

Verified 2026-04-18 on the development host. jq 1.7 was released 2023-09-06; `a - b` on arrays has been stable for the project's entire lifetime [CITED: https://jqlang.org/manual/#set-operations].

## Architecture Patterns

### System Architecture Diagram — Phase 4 update flow

```
                 User runs:
                 bash <(curl ... update-claude.sh)
                        │
                        ▼
                 ┌──────────────────┐
                 │ 1. parse flags   │  (--prune, --offer-mode-switch,
                 │    --dry-run?    │   --no-prune, --no-offer-mode-switch)
                 └─────────┬────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │ 2. source        │  ← mktemp + curl + trap pattern
                 │    detect.sh     │    (reuse Phase 3 D-31 — already wired)
                 │    lib/install.sh│
                 │    lib/state.sh  │
                 └─────────┬────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │ 3. fetch remote  │  ← curl -sSLf manifest.json > $MANIFEST_TMP
                 │    manifest.json │    (no filesystem write to ~/.claude/ yet)
                 └─────────┬────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │ 4. read_state or │  ← if STATE_FILE missing → synthesize_state
                 │    synthesize    │    per D-50 (scan ~/.claude/, hash files)
                 │    (v3.x path)   │    write synthesized state BEFORE proceeding
                 └─────────┬────────┘
                           │
                           ▼
                 ┌──────────────────────────────────────┐
                 │ 5. compute diffs (pure, read-only)   │
                 │                                      │
                 │  recommended_mode = recommend_mode() │
                 │  mode_drift = state.mode != recommended
                 │                                      │
                 │  manifest_paths = jq '[.files[][].path]'
                 │  installed_paths = jq '[.installed_files[].path]'
                 │  current_skip_set = compute_skip_set(state.mode)
                 │                                      │
                 │  new_files = (manifest - installed) - skip_set     # D-54
                 │  removed_files = installed - manifest              # D-55
                 │  candidate_modified = installed ∩ manifest         # D-56
                 │  modified_files = [f for f in candidate           │
                 │                     if on_disk_hash(f) != state_hash(f)]
                 └─────────┬────────────────────────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │ 6. no-op check   │  ← if no drift AND empty new/removed/modified
                 │    (D-59)        │    AND state.version == manifest.version
                 │                  │    → print "Already up-to-date." exit 0
                 │                  │    (NO backup, NO state rewrite)
                 └─────────┬────────┘
                           │ (otherwise)
                           ▼
                 ┌──────────────────┐
                 │ 7. acquire_lock  │  ← trap 'release_lock' EXIT first
                 │                  │    then acquire_lock || exit 1
                 └─────────┬────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │ 8. tree backup   │  ← cp -R ~/.claude/ ~/.claude-backup-$(date -u +%s)-$$/
                 │    ONCE (D-57)   │    print "Backup created: <path>"
                 └─────────┬────────┘
                           │
                           ▼
                 ┌──────────────────────────────────────┐
                 │ 9. mutation dispatch (ordered)       │
                 │                                      │
                 │  IF mode_drift AND user accepts:     │
                 │    execute_mode_switch()             │  ← D-52
                 │    (updates skip_set, then continues)│
                 │                                      │
                 │  FOR f IN new_files:                 │
                 │    download(f); hash(f); state +=   │  ← D-54, INSTALLED
                 │                                      │
                 │  IF removed_files AND user accepts:  │
                 │    FOR f: rm f; state -= f          │  ← D-55, REMOVED
                 │                                      │
                 │  FOR f IN modified_files:            │
                 │    prompt [y/N/d]                    │  ← D-56, UPDATED/SKIPPED
                 │    d → diff -u (local, remote)       │
                 │    y → overwrite, rehash             │
                 │    n → skip                          │
                 └─────────┬────────────────────────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │ 10. write_state  │  ← atomic via python3 tempfile+os.replace
                 │     (updated     │    (uses lib/state.sh::write_state)
                 │     mode+files)  │
                 └─────────┬────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │ 11. print summary│  ← D-58 four grouped sections
                 │     INSTALLED N  │    INSTALLED green, UPDATED cyan,
                 │     UPDATED M    │    SKIPPED yellow, REMOVED red
                 │     SKIPPED P    │    ANSI auto-disable via [ -t 1 ]
                 │     REMOVED Q    │
                 └─────────┬────────┘
                           │
                           ▼
                 ┌──────────────────┐
                 │ 12. release_lock │  ← trap fires on EXIT (already registered)
                 │     cleanup tmp  │
                 └──────────────────┘
```

Key properties of this flow:

- **Steps 1-6 are read-only.** No file in `~/.claude/` is touched until step 8. The no-op path (step 6 early exit) is completely free of mutation.
- **Step 4 state synthesis writes `toolkit-install.json`**, which is a first-time-v3.x-upgrader specific path. Synthesis does not require a backup of `~/.claude/` (there was no prior state to back up), but D-50 says "write the synthesized file via `state.sh::save_state` before proceeding with the normal update flow" — which is a state-only write, not a TK-file write. Planner should confirm this read-only-until-step-8 invariant is preserved when synthesizing.
- **Step 7 lock acquisition happens after no-op check**. Rationale: the lock prevents concurrent mutation; a no-op doesn't mutate, so locking it would gratuitously serialize parallel `update-claude.sh` invocations. Alternative: always lock (safer but trivially slower) — planner discretion.
- **Step 8 is the only place `cp -R` runs on the whole `~/.claude/` tree.** Never do it twice; never do it conditionally after other mutations.
- **Step 9 mutation order matters.** Mode-switch first (because it shifts `skip_set`, which changes what counts as new_files). Then new/removed/modified. This order also means the INSTALLED/REMOVED counters account for mode-switch-driven changes.
- **Step 10 is the single write_state call.** State updates DURING mutation accumulate in shell arrays; only at the end do they flush to disk atomically.

### Recommended Script Structure (scripts/update-claude.sh shape after Phase 4)

```bash
#!/bin/bash
set -euo pipefail

# Colors (existing block preserved)
# ...

# ════════════════════════════════════════════════════════
# Flag parsing — --prune, --no-prune, --offer-mode-switch=yes/no
# (Claude's discretion per CONTEXT.md — implement now or park for v4.1)
# ════════════════════════════════════════════════════════
PRUNE_MODE=interactive   # interactive / yes / no
OFFER_MODE_SWITCH=interactive   # interactive / yes / no
# ...parse flags...

# ════════════════════════════════════════════════════════
# Source libraries (detect.sh wiring is already at lines 19-44; extend
# with lib/install.sh + lib/state.sh downloads in the same trap)
# ════════════════════════════════════════════════════════
# ...source detect.sh (existing)...
# NEW: source lib/install.sh (for compute_skip_set, MODES, recommend_mode)
# NEW: source lib/state.sh (for read_state, write_state, acquire_lock, sha256_file)

# ════════════════════════════════════════════════════════
# Fetch remote manifest
# ════════════════════════════════════════════════════════
MANIFEST_TMP=$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")
# append to existing trap
curl -sSLf "$MANIFEST_URL" -o "$MANIFEST_TMP" || { log_error "manifest fetch failed"; exit 1; }
MANIFEST_VER=$(jq -r '.manifest_version' "$MANIFEST_TMP")
[[ "$MANIFEST_VER" == "2" ]] || { log_error "manifest_version != 2"; exit 1; }
REMOTE_TOOLKIT_VERSION=$(jq -r '.version' "$MANIFEST_TMP")

# ════════════════════════════════════════════════════════
# Load or synthesize state (D-50)
# ════════════════════════════════════════════════════════
if [[ ! -f "$STATE_FILE" ]]; then
    synthesize_v3_state "$MANIFEST_TMP"   # NEW function — see §V3.x state synthesis
fi
STATE_JSON=$(read_state) || { log_error "state unreadable"; exit 1; }
STATE_MODE=$(jq -r '.mode' <<<"$STATE_JSON")
STATE_VERSION=$(jq -r '.version // .toolkit_version // "unknown"' <<<"$STATE_JSON")

# ════════════════════════════════════════════════════════
# Compute diffs (pure, read-only)
# ════════════════════════════════════════════════════════
RECOMMENDED=$(recommend_mode)
MODE_DRIFT=$([[ "$STATE_MODE" != "$RECOMMENDED" ]] && echo true || echo false)
# NEW function compute_file_diffs outputs 3 JSON arrays (new/removed/modified_candidates)
compute_file_diffs "$STATE_JSON" "$MANIFEST_TMP" "$STATE_MODE"
# ...modified_files filtered by actual hash comparison...

# ════════════════════════════════════════════════════════
# No-op check (D-59)
# ════════════════════════════════════════════════════════
if ! $MODE_DRIFT \
   && [[ "$(jq length <<<"$NEW_FILES")" -eq 0 ]] \
   && [[ "$(jq length <<<"$REMOVED_FILES")" -eq 0 ]] \
   && [[ "$(jq length <<<"$MODIFIED_FILES")" -eq 0 ]] \
   && [[ "$STATE_VERSION" == "$REMOTE_TOOLKIT_VERSION" ]]; then
    echo "Already up-to-date. Nothing to do."
    exit 0
fi

# ════════════════════════════════════════════════════════
# Mutation — acquire lock + backup + dispatch
# ════════════════════════════════════════════════════════
trap 'release_lock' EXIT
acquire_lock || exit 1

BACKUP_DIR="$HOME/.claude-backup-$(date -u +%s)-$$"
cp -R "$HOME/.claude" "$BACKUP_DIR"
log_info "Backup created: $BACKUP_DIR"

# ...mutation dispatch (mode_switch? new_files? removed_files? modified_files?)...
# ...accumulate INSTALLED_PATHS/UPDATED_PATHS/SKIPPED_PATHS/REMOVED_PATHS arrays...

# ════════════════════════════════════════════════════════
# Persist state + print summary
# ════════════════════════════════════════════════════════
write_state "$ACTIVE_MODE" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" \
            "$INSTALLED_CSV" "$SKIPPED_CSV"

print_update_summary   # NEW function — 4 grouped sections
```

### Pattern 1: Fetch + parse remote manifest without touching `~/.claude/`

**What:** Download the manifest to a tempfile, parse it there, use the parsed data to drive decisions, only afterwards mutate `~/.claude/`.

**When to use:** Always for update flow; matches Phase 3 `init-claude.sh` which fetches `manifest.json` via mktemp+curl at lines 83-94 [VERIFIED].

**Example:**

```bash
# Source: scripts/init-claude.sh:83-94 (verified 2026-04-18)
MANIFEST_TMP=$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")
trap 'rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$MANIFEST_TMP"' EXIT
if ! curl -sSLf "$REPO_URL/manifest.json" -o "$MANIFEST_TMP"; then
    echo -e "${RED}✗${NC} Failed to download manifest.json — aborting"
    exit 1
fi
MANIFEST_VER=$(jq -r '.manifest_version' "$MANIFEST_TMP" 2>/dev/null || echo "")
if [[ "$MANIFEST_VER" != "2" ]]; then
    echo -e "${RED}✗${NC} manifest.json has manifest_version=${MANIFEST_VER:-unknown}; this installer expects v2"
    exit 1
fi
MANIFEST_FILE="$MANIFEST_TMP"
```

Phase 4 **extends** this pattern to `update-claude.sh`. The existing `update-claude.sh:94-98` does a looser `curl -sSL | grep -o` parse of the version — Phase 4 replaces this with the jq-based hard-fail pattern.

### Pattern 2: Manifest-driven install loop

**What:** Use a single `jq` invocation to emit a JSON stream per manifest entry with `{bucket, path, skip, reason}`, then `while IFS= read -r` loop to process each. Process substitution `< <(...)` keeps the loop in the parent shell so counters survive.

**When to use:** Any iteration over `manifest.files.*`. Phase 4 reuses this verbatim for new_files download + modified_files overwrite.

**Example:**

```bash
# Source: scripts/init-local.sh:253-281 (verified 2026-04-18)
INSTALLED_PATHS=()
SKIPPED_PATHS=()
while IFS= read -r entry; do
    path=$(jq -r '.path' <<< "$entry")
    bucket=$(jq -r '.bucket' <<< "$entry")
    skip=$(jq -r '.skip' <<< "$entry")
    reason=$(jq -r '.reason' <<< "$entry")
    if [[ "$skip" == "true" ]]; then
        echo -e "  ${YELLOW}--${NC} $bucket/$path (skipped: conflicts_with:$reason)"
        SKIPPED_PATHS+=("$bucket/$path:conflicts_with:$reason")
        continue
    fi
    # ...install logic...
done < <(jq -c --argjson skip "$SKIP_LIST_JSON" '
    .files | to_entries[] |
    .key as $b | .value[] |
    { bucket: $b, path: .path,
      skip: ((.conflicts_with // []) as $cw |
             ($skip | any(. as $s | $cw | contains([$s])))),
      reason: ((.conflicts_with // []) | join(",")) }
' "$MANIFEST_FILE")
```

**Don't:** Use a pipe (`jq ... | while read`) — the loop runs in a subshell and counter updates are lost. Always use `< <(...)` process substitution.

### Pattern 3: File-set diff via jq array subtraction

**What:** Use jq's built-in `a - b` operator on arrays — it returns elements in `a` not present in `b`, which is exactly set-difference.

**When to use:** D-54 new_files, D-55 removed_files, D-52 mode-switch `files_to_add` / `files_to_remove`.

**Example:**

```bash
# Verified 2026-04-18 against jq 1.7.1 on this host.
# manifest_paths = JSON array of all paths in manifest.files.*
manifest_paths=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$MANIFEST_TMP")

# installed_paths = JSON array of all paths in state.installed_files[]
installed_paths=$(jq -c '[.installed_files[].path]' <<<"$STATE_JSON")

# skip_paths = JSON array (already computed by compute_skip_set)
skip_paths=$(compute_skip_set "$STATE_MODE" "$MANIFEST_TMP")

# New files: in manifest, not in installed, not skipped
new_files=$(jq -n --argjson m "$manifest_paths" \
                  --argjson i "$installed_paths" \
                  --argjson s "$skip_paths" \
                  '($m - $i) - $s')

# Removed files: in installed, not in manifest
removed_files=$(jq -n --argjson i "$installed_paths" \
                      --argjson m "$manifest_paths" \
                      '$i - $m')

# Modified candidates: in both installed and manifest (intersection)
# jq has no direct intersection operator per jqlang.org/manual/; use a - (a - b) as the identity
# or simpler: map+select — both documented
modified_candidates=$(jq -n --argjson i "$installed_paths" \
                            --argjson m "$manifest_paths" \
                            '[$i[] | select(. as $x | $m | index($x) != null)]')
```

[VERIFIED: jq 1.7 manual — subtraction on arrays is documented set-difference.]
[CITED: https://jqlang.org/manual/#set-operations]

### Pattern 4: On-disk hash comparison for modified-file detection

**What:** For each file in `state.installed_files ∩ manifest.files.*`, compare the current on-disk SHA-256 against the `install_time_hash` recorded in state. `lib/state.sh::sha256_file` handles both sides (both are file paths).

**When to use:** D-56 modified-file prompt. Must run for every intersection file — there's no shortcut except D-59 version-equality (which only skips when the manifest version is unchanged; within the same version, individual files could still differ if the user edited them).

**Example:**

```bash
# For each modified_candidate, check whether the on-disk hash differs from the stored one.
MODIFIED_FILES=()
while IFS= read -r path; do
    on_disk_hash=$(sha256_file "$HOME/.claude/$path" 2>/dev/null || echo "MISSING")
    stored_hash=$(jq -r --arg p "$path" \
                       '.installed_files[] | select(.path == $p) | .sha256 // .install_time_hash // ""' \
                       <<<"$STATE_JSON")
    if [[ "$on_disk_hash" != "$stored_hash" ]] && [[ -n "$stored_hash" ]]; then
        MODIFIED_FILES+=("$path")
    fi
done < <(jq -r '.[]' <<<"$modified_candidates")
```

**Note on schema ambiguity:** Phase 2 `write_state` uses field name `sha256` (`lib/state.sh:66`), but CONTEXT.md D-50/D-56 refer to `install_time_hash`. Planner must pick one and keep it consistent. Recommendation: keep the `sha256` field name that `lib/state.sh` already writes (do not rename; Phase 2 tests assert this field name). Update CONTEXT language to match when the planner documents the chosen schema. Document this convergence explicitly in the plan.

### Pattern 5: V3.x state synthesis (D-50)

**What:** Iterate `manifest.files.*` paths, check whether each is present on disk at `~/.claude/<path>`, hash it if present, emit a synthetic `installed_files[]` array. No network calls; purely filesystem scan.

**When to use:** Exactly once, when `$STATE_FILE` does not exist on first `update-claude.sh` run after upgrading from v3.x.

**Example:**

```bash
synthesize_v3_state() {
    local manifest_file="$1"
    local mode
    mode=$(recommend_mode)

    local installed_csv=""
    local skipped_csv=""

    # Iterate every path in manifest.files.*
    while IFS= read -r path; do
        if [[ -f "$HOME/.claude/$path" ]]; then
            # Present on disk — will be hashed by write_state
            if [[ -n "$installed_csv" ]]; then
                installed_csv+=","
            fi
            installed_csv+="$HOME/.claude/$path"
            # Note: write_state internally calls sha256() on each path; we pass absolute paths
            # so write_state hashes the real file, not a relative path in cwd.
        fi
    done < <(jq -r '.files | to_entries[] | .value[] | .path' "$manifest_file")

    log_info "First update after v3.x — synthesized install state from filesystem (mode=$mode)."
    write_state "$mode" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" \
                "$installed_csv" "$skipped_csv"
}
```

**Edge cases (must handle):**

1. `~/.claude/` exists but has NO matching files (corrupted install) → write state with empty `installed_files[]`; update flow will treat everything as `new_files`. Log a visible warning.
2. User has symlinks inside `~/.claude/` pointing outside — `[[ -f "$path" ]]` follows symlinks by default (BSD + GNU), so the hash will be of the target. Acceptable — user put the symlink there.
3. macOS case-insensitive filesystems (`HFS+` default, `APFS` configurable) — `commands/Plan.md` and `commands/plan.md` are the same file. Manifest paths are all lowercase, so the `[[ -f "$HOME/.claude/$path" ]]` check is correct on both filesystem types. [VERIFIED: Darwin 25.3.0 — APFS case-insensitive by default.]
4. **`write_state` hashing behavior:** verified at `lib/state.sh:65-69` — when the path in `installed_csv` is absolute AND the file exists, it hashes and records; when it doesn't exist, it records with empty hash. Passing absolute paths (as above) is the correct usage.
5. **CSV limitation on paths with commas:** `lib/state.sh::write_state` splits `installed_csv` on `,`. Manifest paths never contain commas (verified by inspecting all 29 `commands/*.md` + all other entries), so this is safe. But document the limitation as a constraint: any future manifest entry with a comma in the path will break this CSV. Consider switching to newline separator in a future refactor (not Phase 4).

### Pattern 6: Unified diff for the `[y/N/d]` prompt (D-56)

**What:** `diff -u <local> <remote>` produces POSIX-standard unified diff output. Exit code 0=same, 1=different (expected), 2=error. Never use GNU `--color=always` flag — it's not in BSD diff.

**When to use:** User presses `d` at the modified-file prompt. Print the diff, then re-prompt.

**Example:**

```bash
prompt_modified_file() {
    local path="$1"
    local local_file="$HOME/.claude/$path"
    # Download remote file to tempfile for diff
    local remote_tmp
    remote_tmp=$(mktemp "${TMPDIR:-/tmp}/remote.XXXXXX")
    # shellcheck disable=SC2317  # actually reachable; shellcheck false positive in nested function
    if ! curl -sSLf "$REPO_URL/$path" -o "$remote_tmp"; then
        log_warning "Could not fetch remote $path for diff; skipping"
        rm -f "$remote_tmp"
        return 1
    fi

    while :; do
        local choice=""
        if ! read -r -p "File $path modified locally. Overwrite? [y/N/d]: " choice < /dev/tty 2>/dev/null; then
            choice="N"  # fail closed
        fi
        case "${choice:-N}" in
            y|Y)  cp "$remote_tmp" "$local_file"; rm -f "$remote_tmp"; return 0 ;;
            d|D)  diff -u "$local_file" "$remote_tmp" || true ;;  # exit 1 on diff is expected
            *)    rm -f "$remote_tmp"; return 2 ;;  # treated as "skip / locally_modified"
        esac
    done
}
```

**On-screen colorization of diff:** If desired, pipe through a shell-level colorizer (`while read line; do case "$line" in '+'*) echo "\$GREEN\$line\$NC" ;; '-'*) echo "\$RED\$line\$NC" ;; *) echo "\$line" ;; esac; done`). Claude's discretion per CONTEXT — keep simple inline diff for Phase 4 MVP; park styled diff for v4.1.

### Pattern 7: Per-file lock wrapping

**What:** Every Phase 4 mutation path (mode-switch, install new, delete removed, overwrite modified) runs inside ONE `acquire_lock ... release_lock` window. The canonical pattern from `lib/state.sh` header comment is:

```bash
trap 'release_lock' EXIT
acquire_lock || exit 1
# ... all mutations ...
# release_lock will fire from EXIT trap
```

[VERIFIED: `scripts/lib/state.sh:11` — "Callers MUST register `trap 'release_lock' EXIT` BEFORE calling acquire_lock."]

### Anti-Patterns to Avoid

- **Rebuilding a hand-maintained file list in `update-claude.sh`**: The whole point of D-53 is to kill this. Any line that literally writes `for file in agents/code-reviewer.md agents/planner.md ...` is a reintroduction of BUG-07. Test coverage: `Makefile:108-128` already greps for the pattern; the check becomes vacuous once the list is gone, but accidentally re-adding it will still be visible in diff review.
- **Backing up twice.** `cp -R ~/.claude/ ~/.claude-backup-...` MUST happen exactly once per mutating run. A common bug shape is "back up once in the outer script, back up again inside the mode-switch function." Don't. Use a shell sentinel (`TK_UPDATE_BACKUP=""` → set by the first backup, subsequent calls skip).
- **Restoring selectively from backup.** Recovery is whole-tree — `cp -R "$BACKUP_DIR" "$HOME/.claude"` (with user confirmation). Don't try to restore individual files; that's a rabbit hole (the backup is a snapshot, so you either trust it fully or not at all).
- **Mutating state BEFORE the tree backup.** The backup must cover every file mutation. Write-state happens LAST (step 10), but `write_state` writes `toolkit-install.json` INSIDE `~/.claude/` — which the backup captured at step 8. So a failure during write_state is recoverable: the backup still has the old state.
- **Prompting inside a subshell.** `read ... < /dev/tty` inside `jq ... | while read` fails silently because the subshell doesn't see /dev/tty in pipelines. Always use `< <(...)` process substitution for loops that prompt.
- **`set -e` + `diff`**. `diff` returns exit code 1 when files differ — which is the expected case. Under `set -e`, this aborts the script. Wrap every diff call with `|| true` or capture the exit code: `diff -u a b || true`.
- **Fetching individual files multiple times**. If both the modified-file-diff path AND the overwrite path need the remote content, download once to a tempfile and reuse. Caches are not needed at this scale (<100 files) but duplicate downloads are noticeable UX.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hand-maintained file iteration list | For-loops literal `for f in commands/x.md commands/y.md ...` | `jq` over `manifest.files.*` with `compute_skip_set` filter (Pattern 2) | The ENTIRE POINT of Phase 4 per UPDATE-02 and D-53. Hand-lists drift (BUG-07). Manifest is single source of truth. |
| Atomic JSON write | Open fd + write + fsync yourself | `lib/state.sh::write_state` which uses `tempfile.mkstemp + os.replace` | Already correct, already tested. Kill-9 durability proven by `test-state.sh` Scenario B. |
| Concurrent run locking | `flock` (Linux-only), `lockfile` (util-linux) | `lib/state.sh::acquire_lock` (POSIX mkdir-based with PID-liveness + mtime TTL stale recovery) | Already POSIX-portable. Already has stale-lock recovery (Scenarios D/E of `test-state.sh`). Adding a second lock mechanism is duplicate complexity for no gain. |
| SHA-256 hashing | `shasum -a 256` vs `sha256sum` dual-detection shell wrapper | `lib/state.sh::sha256_file` (uses `python3 hashlib.sha256`) | Already platform-agnostic. `python3` is already a hard dependency (merge_settings_python etc.). Shell wrapper adds BSD/GNU branching for no benefit over the python3 path. |
| ISO-8601 UTC timestamp | `date -u +"%Y-%m-%dT%H:%M:%SZ"` inline everywhere | `lib/state.sh::iso8601_utc_now` | Already exists. Consistency across logs. |
| Set difference / intersection | Shell arrays + `grep -Fvxf` + sort-unique gymnastics | jq `a - b` (difference), `map(select(index_in(b)))` (intersection) | Already a hard dependency. `a - b` is in the jq manual (VERIFIED). Shell arrays break on paths with spaces; JSON doesn't. |
| Tree backup / recovery | `rsync -a` | `cp -R` | rsync is not guaranteed on minimal Linux installs. `cp -R` is POSIX. Matches existing `update-claude.sh:112`. |
| Interactive prompt under `curl \| bash` | Custom stdin handling | `read -r -p "..." var < /dev/tty 2>/dev/null` | Already used in `init-claude.sh:126, 151, 178, 219`, `setup-council.sh`, etc. Falls closed when `/dev/tty` unavailable. |
| Version compare for D-59 toolkit_version equality | semver parser | String equality `[[ "$state_version" == "$remote_version" ]]` | Toolkit versions are single-bumper (3.0.0 → 4.0.0). Full semver comparison is overkill. String equality suffices because if the remote version changed at all, we want to proceed (even for 3.0.1 → 3.0.2). |

**Key insight:** The repo has done the platform-portability homework. Phase 4's job is to **compose** `detect.sh`, `compute_skip_set`, `acquire_lock`, `read_state`, `write_state`, `sha256_file` — not to rebuild any of their functionality. The test suite already covers the primitives; Phase 4 tests only the orchestration.

## Runtime State Inventory

> Phase 4 is a refactor of `update-claude.sh` AND introduces a new filesystem scan (D-50 v3.x synthesis). Both trigger the runtime-state-inventory requirement from the GSD research protocol.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| **Stored data** | `~/.claude/toolkit-install.json` — written by Phase 3 installers; read by Phase 4 on every run; written at end of every mutating Phase 4 run. Schema is Phase 2 D-19 (v1, with `version`, `mode`, `detected.{superpowers,gsd}.{present,version}`, `installed_files[{path,sha256,installed_at}]`, `skipped_files[{path,reason}]`, `installed_at`). [VERIFIED: `lib/state.sh:85-95`] | **Code consumer change, no data migration.** Phase 4 **reads** existing state from Phase 3 installs untouched. Phase 4 **synthesizes** new state for v3.x upgraders (D-50). No field rename; `sha256` field in existing state maps to D-50's `install_time_hash` concept — keep the field name. |
| | `~/.claude-backup-<timestamp>/` — v3.x backup path format `scripts/update-claude.sh:111` uses `+%Y%m%d-%H%M%S`. Phase 4 switches to `$(date -u +%s)-$$` (unix-ts + PID). Old-format backups continue to exist from prior v3.x runs; Phase 4 does not touch them. | **No migration needed.** BACKUP-01/02 (cleanup) is deferred to v4.1. Phase 4 simply writes new-format backups alongside old ones. `rollback-update.sh` (mentioned in CONTEXT Deferred Ideas) needs audit but is not in Phase 4 scope. |
| **Live service config** | None. The toolkit has no external services (no n8n, no API gateway, no CI configuration owned by the toolkit). | **None — verified by grep for service-name patterns in `scripts/` and `manifest.json`. No hits.** |
| **OS-registered state** | None. No launchd / systemd / Task Scheduler integration. `install-statusline.sh` writes to `~/.claude/statusline.sh` but that's a file, not an OS registration. | **None — verified by inspecting `scripts/` for `launchctl`, `systemctl`, `schtasks` — no hits.** |
| **Secrets and env vars** | `setup-council.sh` manages `GEMINI_API_KEY` / `OPENAI_API_KEY` in `~/.claude/council/config.json`. Phase 4 does NOT touch this file. | **None — Phase 4 does not mutate council config. No env var rename.** |
| **Build artifacts / installed packages** | None. Toolkit has no compiled artifacts; all files are shipped verbatim. | **None — verified by inspecting repo for `dist/`, `build/`, `*.egg-info`, `node_modules` in distribution surface (only dev-time `node_modules` exists for `markdownlint-cli`, which is not shipped).** |

**The canonical question (from research protocol):** *After every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?*

Phase 4 is not a rename. It's a refactor. The only runtime state that matters is `~/.claude/toolkit-install.json`, which Phase 4 both reads and rewrites using the same schema Phase 2 defined. There is no drift between the repo and runtime state; the schema is versioned (`"version": 1` in the JSON) and Phase 4 keeps it at v1.

## Common Pitfalls

### Pitfall 1: Shell counters lost to pipe subshell

**What goes wrong:** `jq ... | while read entry; do ((count++)); done; echo "$count"` always prints 0.
**Why it happens:** The pipe spawns a subshell for the `while` loop. `count++` happens inside the subshell; the parent's `$count` is unchanged.
**How to avoid:** Always use process substitution: `while read entry; do ...; done < <(jq ...)`. Already the pattern used at `init-local.sh:255-281` [VERIFIED].
**Warning signs:** "My INSTALLED counter is always 0" during tests.

### Pitfall 2: `set -e` + `diff` abort

**What goes wrong:** `diff -u local remote` returns exit code 1 when files differ. Under `set -euo pipefail`, this aborts the script.
**Why it happens:** Exit 1 is the expected "diff found differences" signal in diff's interface.
**How to avoid:** Suffix with `|| true` or `|| rc=$?; (( rc == 2 )) && fail`. Prefer the simpler `diff -u a b || true` unless explicit error detection is needed.
**Warning signs:** Script exits silently at the `d` branch of the modified-file prompt.

### Pitfall 3: Reading `/dev/tty` from inside a subshell

**What goes wrong:** `jq ... | while read path; do read -r -p "..." ans < /dev/tty; done` fails — under `curl | bash` the whole pipeline inherits a non-tty stdin, and `/dev/tty` inside the subshell may not resolve.
**Why it happens:** Subshell inherits stdin but loses some terminal control references. The failure mode is that the read just succeeds with an empty answer, which silently defaults to N — confusing the user.
**How to avoid:** Use process substitution `< <(...)` for loops that prompt. Explicitly `|| fail_closed` every tty read.
**Warning signs:** User presses `y` but the script behaves as if they pressed `N`.

### Pitfall 4: BSD `cp -R` preserves symlinks, GNU `cp -R` too (but watch `cp -r`)

**What goes wrong:** `cp -r` (lowercase) has different symlink semantics on BSD vs GNU. `cp -R` (uppercase) is POSIX and behaves the same.
**Why it happens:** Legacy `cp -r` is not in POSIX; BSD and GNU differ on how it handles device nodes and symlinks.
**How to avoid:** Always use `cp -R`. Already how `update-claude.sh:112` does it today [VERIFIED].
**Warning signs:** Backup doesn't include some files, or symlinks become files (or vice versa).

### Pitfall 5: Concurrent Phase 4 runs racing on `toolkit-install.json`

**What goes wrong:** Two `update-claude.sh` invocations at the same time → both read the same state, both compute the same diffs, both write new state. One overwrites the other's write.
**Why it happens:** If the lock is acquired AFTER diff compute (which I recommended above for no-op fastness), two processes can both race through steps 1-6 before either hits step 7. After step 6, both find non-no-op and proceed. Step 7 serializes them — the second will block for up to ~3 retries × ~1 second = 3 seconds; if the first is slower than that, the second fails with "Another install is in progress."
**How to avoid:** The lock IS the serialization. The failure mode is graceful (RED message + return 1). Document in a user-facing warning: "Concurrent updates are not supported; try again after the first completes." Planner discretion: acquire lock earlier (before no-op check) if you'd rather serialize all runs.
**Warning signs:** Two `~/.claude/toolkit-install.json` files (the atomic write means we never see a partial file, but we might see the "wrong" winning version).

### Pitfall 6: D-57 `$$` captures the SUBSHELL pid, not the parent

**What goes wrong:** Inside a function or a subshell, `$$` can return the parent shell PID — which IS what we want — but inside `$(...)` command substitution, `$$` is STILL the parent's PID in bash. Easy to get confused.
**Why it happens:** POSIX spec says `$$` expands to the shell's PID "of the invoking shell," which is the parent script in command substitution contexts.
**How to avoid:** Test once: `echo "parent=$$, subshell=$(echo $$)"` — both should be the same. They are, in bash. (In zsh, they differ — but the script is `#!/bin/bash`, so safe.) No special handling needed.
**Warning signs:** Backup directories with unexpected PID suffixes. Quick sanity check during Phase 4 development.

### Pitfall 7: No-op detection false negatives

**What goes wrong:** D-59 says "no-op" requires all FIVE conditions. If any one is false (e.g., `new_files` is empty but `modified_files` has 1 entry), it's NOT a no-op. Accidentally shortening the check (e.g., only comparing `state.toolkit_version == manifest.version`) will skip real updates.
**Why it happens:** It's tempting to treat "same version" as "nothing to do" because most updates are version-driven. But users can modify files locally, or re-run after manually adding/removing files — all of which require the full diff.
**How to avoid:** Check all 5 conditions explicitly. Test 11 (test-update-summary.sh per D-61) MUST include a "user added a file locally, same toolkit version" scenario.
**Warning signs:** User reports "I edited a file and the next update didn't prompt me about it."

### Pitfall 8: Partial update interrupted by SIGINT

**What goes wrong:** User hits Ctrl-C during mutation dispatch (step 9). Half the files are updated, the rest aren't. `toolkit-install.json` still shows the pre-run state (write happens last at step 10).
**Why it happens:** Default SIGINT handling in bash terminates the script without running cleanup. The EXIT trap (`release_lock`) fires, but the state file is NOT updated.
**How to avoid:** On next run, Phase 4 will re-read pre-run state, re-compute diffs, and find the same new/removed/modified files minus those already processed. The diff logic is idempotent — hashing a file already overwritten gives the NEW hash, which matches the remote, so it's no longer "modified." Safe by design. Add a trap on SIGINT that prints "Interrupted — re-run update-claude.sh to complete. Backup available at: $BACKUP_DIR" before exiting.
**Warning signs:** User reports "I hit Ctrl-C and now I'm not sure what was updated." Answer: the backup has the pre-run state; re-run update-claude.sh to finish.

### Pitfall 9: Manifest fetch failure mid-run

**What goes wrong:** Initial `curl -sSLf manifest.json` succeeds (step 3), but subsequent file downloads (step 9) fail (network drops between fetch and install).
**Why it happens:** The remote server can go down, or the user loses connectivity mid-run.
**How to avoid:** Each file download is wrapped with `|| fail`. On failure: DON'T restore the partial updates; print the backup path and instruct the user to recover manually if needed. (Per CONTEXT Non-Goals: "Auto-retry on curl failures mid-run — first-failure exits with restore-from-backup instructions. User re-runs.")
**Warning signs:** Many "(Skipped: $file — download failed)" lines from v3.x update-claude.sh. Phase 4 must be stricter — fail the whole run, not silently continue.

### Pitfall 10: Corrupted `toolkit-install.json` (user edited it, or killed a prior run)

**What goes wrong:** `read_state` fails (python3 `json.load` raises) or the JSON parses but is missing required fields.
**Why it happens:** User poked the file; previous run died BEFORE atomic replace (not likely with python3 pattern but possible if the python3 process itself crashed); disk full during write.
**How to avoid:** `read_state` already returns 1 on corrupt JSON. Phase 4: wrap in `STATE_JSON=$(read_state) || { log_warning "state file unreadable — treating as v3.x and synthesizing"; synthesize_v3_state; STATE_JSON=$(read_state); }`. Fallback to synthesis is the safest recovery path.
**Warning signs:** Error messages like `python3: json.decoder.JSONDecodeError: ...`. Catch these and reroute to synthesis.

### Pitfall 11: Hash mismatch on a file that should have been untouched (D-56 false positive)

**What goes wrong:** User hasn't touched `commands/plan.md`, but Phase 4 prompts "File modified locally."
**Why it happens:** (a) Phase 3 installed the file with trailing whitespace or CRLF that got normalized on some filesystem (unlikely on macOS/Linux). (b) Newline differences between remote GitHub raw content and installed content. (c) `state.sha256` was empty because the file wasn't yet on disk when `write_state` ran (`lib/state.sh:65-69` handles this by storing empty string — a subsequent `"" != actual_hash` compare trips the modified branch falsely).
**How to avoid:** In the modified-file detection (Pattern 4 above), SKIP the check when `stored_hash` is empty — treat as "unknown install-time state, do not prompt." Log once at INFO level: "Some files had no install-time hash recorded; these will be auto-refreshed if new in the manifest." This is a real edge case with Phase 3's state synthesis during a partial install.
**Warning signs:** User sees unexpected "File X modified locally" prompts immediately after a fresh install.

### Pitfall 12: `$HOME/.claude/.toolkit-install.lock` directory collision with `init-claude.sh`

**What goes wrong:** User runs `init-claude.sh --force` (which acquires the global lock) and `update-claude.sh` concurrently.
**Why it happens:** Both scripts use the same `$LOCK_DIR` global from `lib/state.sh:17`. This is by design — they cannot mutate `~/.claude/` at the same time. The LATER one blocks 3 retries and exits.
**How to avoid:** The lock is correct as-is. Document the error message in the README if users report it. Not a Phase 4 bug.
**Warning signs:** "Another install is in progress (PID X). Exiting." — expected behavior.

## Code Examples

Verified patterns from the repo; these are the exact shapes Phase 4 tasks should adopt.

### Loading state + handling missing-file case

```bash
# scripts/update-claude.sh (Phase 4 shape)
# Source: adapts lib/state.sh::read_state (verified 2026-04-18)

# State may be missing (v3.x user) or corrupt (disk, user edit).
# Both cases route through v3.x synthesis.
if ! STATE_JSON=$(read_state 2>/dev/null); then
    if [[ -f "$STATE_FILE" ]]; then
        log_warning "state file unreadable — treating as v3.x and re-synthesizing from disk"
        cp "$STATE_FILE" "$STATE_FILE.bak.$(date -u +%s)"   # preserve corrupt for debug
    else
        log_info "First update after v3.x — synthesized install state from filesystem"
    fi
    synthesize_v3_state "$MANIFEST_TMP"
    STATE_JSON=$(read_state) || { log_error "synthesis failed — abort"; exit 1; }
fi

STATE_MODE=$(jq -r '.mode' <<<"$STATE_JSON")
STATE_VERSION=$(jq -r '.version // .toolkit_version // "unknown"' <<<"$STATE_JSON")
```

### Compute the three diffs in one function

```bash
# scripts/lib/install.sh (NEW function for Phase 4)
# Outputs three JSON arrays on stdout, separated by a single newline.
# Caller parses with: read -r new_files; read -r removed; read -r modified_candidates
compute_file_diffs() {
    local state_json="$1"
    local manifest_path="$2"
    local mode="$3"

    local manifest_paths installed_paths skip_paths
    manifest_paths=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$manifest_path")
    installed_paths=$(jq -c '[.installed_files[].path]' <<<"$state_json")
    skip_paths=$(compute_skip_set "$mode" "$manifest_path")

    # New: in manifest, not installed, not skipped
    jq -nc --argjson m "$manifest_paths" --argjson i "$installed_paths" --argjson s "$skip_paths" \
         '($m - $i) - $s'

    # Removed: in installed, not in manifest
    jq -nc --argjson i "$installed_paths" --argjson m "$manifest_paths" \
         '$i - $m'

    # Modified candidates: intersection (installed AND manifest)
    jq -nc --argjson i "$installed_paths" --argjson m "$manifest_paths" \
         '[$i[] | select(. as $x | $m | index($x) != null)]'
}

# Usage:
# mapfile -t diffs < <(compute_file_diffs "$STATE_JSON" "$MANIFEST_TMP" "$STATE_MODE")
# NEW_FILES="${diffs[0]}"
# REMOVED_FILES="${diffs[1]}"
# MODIFIED_CANDIDATES="${diffs[2]}"
```

**Note:** `mapfile` is bash ≥4.0 (not available in macOS default bash 3.2). Alternative for bash 3.2 compatibility:

```bash
NEW_FILES=$(compute_file_diffs "$STATE_JSON" "$MANIFEST_TMP" "$STATE_MODE" | head -1)
REMOVED_FILES=$(compute_file_diffs "$STATE_JSON" "$MANIFEST_TMP" "$STATE_MODE" | sed -n 2p)
MODIFIED_CANDIDATES=$(compute_file_diffs "$STATE_JSON" "$MANIFEST_TMP" "$STATE_MODE" | sed -n 3p)
```

Or (more efficient, single call): use a wrapper that emits JSON object with all three arrays, parse with jq:

```bash
# Preferred: emit single JSON object
compute_file_diffs_obj() {
    local state_json="$1" manifest_path="$2" mode="$3"
    local mp ip sp
    mp=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$manifest_path")
    ip=$(jq -c '[.installed_files[].path]' <<<"$state_json")
    sp=$(compute_skip_set "$mode" "$manifest_path")
    jq -nc --argjson m "$mp" --argjson i "$ip" --argjson s "$sp" \
         '{ new: (($m - $i) - $s), removed: ($i - $m), modified_candidates: [$i[] | select(. as $x | $m | index($x) != null)] }'
}

DIFFS=$(compute_file_diffs_obj "$STATE_JSON" "$MANIFEST_TMP" "$STATE_MODE")
NEW_FILES=$(jq -c '.new' <<<"$DIFFS")
REMOVED_FILES=$(jq -c '.removed' <<<"$DIFFS")
MODIFIED_CANDIDATES=$(jq -c '.modified_candidates' <<<"$DIFFS")
```

**Recommendation:** Use the single-object form. Fewer lines, bash 3.2 safe, one fewer jq invocation per get.

### Mode-switch transaction (D-52)

```bash
# scripts/update-claude.sh (Phase 4 shape)
execute_mode_switch() {
    local new_mode="$1"
    local old_mode="$STATE_MODE"

    log_info "Switching mode: $old_mode -> $new_mode"

    local old_skip_set new_skip_set installed_paths
    old_skip_set=$(compute_skip_set "$old_mode" "$MANIFEST_TMP")
    new_skip_set=$(compute_skip_set "$new_mode" "$MANIFEST_TMP")
    installed_paths=$(jq -c '[.installed_files[].path]' <<<"$STATE_JSON")

    # files_to_remove: were installed under old mode, now conflict under new mode
    local to_remove
    to_remove=$(jq -nc --argjson i "$installed_paths" --argjson s "$new_skip_set" \
                      '[$i[] | select(. as $x | $s | index($x) != null)]')

    # files_to_add: in manifest, not in new skip_set, not already installed
    local manifest_paths to_add
    manifest_paths=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$MANIFEST_TMP")
    to_add=$(jq -nc --argjson m "$manifest_paths" \
                    --argjson i "$installed_paths" \
                    --argjson s "$new_skip_set" \
                    '($m - $i) - $s')

    # Backup is already taken at step 8 — mode switch is inside the same snapshot
    while IFS= read -r path; do
        rm -f "$HOME/.claude/$path"
        REMOVED_PATHS+=("$path (mode-switch:$old_mode->$new_mode)")
    done < <(jq -r '.[]' <<<"$to_remove")

    while IFS= read -r path; do
        install_file "$path"   # download + write + hash, append to INSTALLED_PATHS
    done < <(jq -r '.[]' <<<"$to_add")

    STATE_MODE="$new_mode"  # propagate to final write_state
}
```

### Summary print (D-58)

```bash
# scripts/update-claude.sh (Phase 4 shape)
print_update_summary() {
    local _GREEN _YELLOW _CYAN _RED _NC
    if [ -t 1 ]; then
        _GREEN='\033[0;32m' _YELLOW='\033[1;33m' _CYAN='\033[0;36m' _RED='\033[0;31m' _NC='\033[0m'
    fi

    echo ""
    echo "Update Summary"
    echo "──────────────"
    printf '%b%s %d%b\n' "$_GREEN" "INSTALLED" "${#INSTALLED_PATHS[@]}" "$_NC"
    for p in "${INSTALLED_PATHS[@]}"; do printf '  %s\n' "$p"; done

    printf '%b%s %d%b\n' "$_CYAN" "UPDATED" "${#UPDATED_PATHS[@]}" "$_NC"
    for p in "${UPDATED_PATHS[@]}"; do printf '  %s\n' "$p"; done

    printf '%b%s %d%b\n' "$_YELLOW" "SKIPPED" "${#SKIPPED_PATHS[@]}" "$_NC"
    for p in "${SKIPPED_PATHS[@]}"; do printf '  %s\n' "$p"; done

    if [[ ${#REMOVED_PATHS[@]} -gt 0 ]]; then
        printf '%b%s %d (backed up to %s)%b\n' "$_RED" "REMOVED" "${#REMOVED_PATHS[@]}" "$BACKUP_DIR" "$_NC"
        for p in "${REMOVED_PATHS[@]}"; do printf '  %s\n' "$p"; done
    else
        printf '%bREMOVED 0%b\n' "$_RED" "$_NC"
    fi
}
```

**Note on arrays under `set -u`:** `${#EMPTY_ARRAY[@]}` works under `set -u` in bash ≥4.2. On bash 3.2 (macOS), use `${#EMPTY_ARRAY[@]:-0}` defensively, or initialize arrays at top of script: `INSTALLED_PATHS=() UPDATED_PATHS=() SKIPPED_PATHS=() REMOVED_PATHS=()`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-maintained file-lists in `update-claude.sh:125-179` | `compute_skip_set` + `jq` over `manifest.files.*` | Phase 3 introduced `lib/install.sh`; Phase 4 completes the migration by deleting the hand-lists | BUG-07-class drift disappears. `Makefile:108-128` drift check becomes vacuously green. |
| Non-atomic JSON merge in `setup-security.sh` (overwrote foreign hooks) | `merge_settings_python` with `_tk_owned` marker + `tempfile.mkstemp + os.replace` | Phase 3 Plan 3 (2026-04-18) | SP/GSD hooks preserved. Foundational for the append-both hook policy. |
| `~/.claude-backup-$(date +%Y%m%d-%H%M%S)` | `~/.claude-backup-$(date -u +%s)-$$` | Phase 4 D-57 | No naming collision on same-second concurrent updates (fixed by UPDATE-05). |
| GNU `head -n -1` in smart-merge of CLAUDE.md | POSIX `sed ${d}` | Phase 1 BUG-01 (2026-04-17) | macOS BSD compatibility; no silent truncation. |
| `curl -sSL ... \| grep -o '"version"'` version parse | `jq -r '.manifest_version'` with hard-fail | Phase 3 D-01 manifest-version guard | Stops old v1-schema scripts from running against v2 manifest. |
| Destructive `entry.get('matcher') != 'Bash'` filter in setup-security.sh | Append-both via `_tk_owned` partition | Phase 3 Plan 3 (2026-04-18) | SAFETY-02 violation eliminated. |

**Deprecated / outdated inside `update-claude.sh` that Phase 4 will replace:**

- Lines 100-101: `REMOTE_VERSION=$(echo "$MANIFEST" | grep -o '"version": "[^"]*"' | head -1 | cut -d'"' -f4)` → replace with `REMOTE_TOOLKIT_VERSION=$(jq -r '.version' "$MANIFEST_TMP")`. Safer + consistent with Phase 3.
- Line 111: `BACKUP_DIR=".claude-backup-$(date +%Y%m%d-%H%M%S)"` → replace with `BACKUP_DIR="$HOME/.claude-backup-$(date -u +%s)-$$"`. Absolute path (the working directory may not be `$HOME`) + UNIX-ts + PID.
- Line 112: `cp -r "$CLAUDE_DIR" "$BACKUP_DIR"` → keep `cp -R` (capital R, POSIX). Path becomes `~/.claude` instead of `.claude`.
- Lines 125-179: All the hand-maintained for-loops → delete; replaced with manifest-driven `while read entry < <(jq -c ...)` loop.
- Lines 186-283 (smart-merge CLAUDE.md): **keep as-is for Phase 4.** CLAUDE.md smart-merge is not in UPDATE-01..06 scope; it's a user-sections-preservation feature that works. Phase 4 doesn't touch it.

## Assumptions Log

> Every factual claim above that was based on training knowledge rather than verification in this session is tagged `[ASSUMED]`. This table surfaces them for the planner and discuss-phase to confirm.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `$$` in bash refers to the parent script PID (not subshell) in command substitution contexts, making `~/.claude-backup-<ts>-$$/` safe to compute inside `$(...)` | Pitfall 6 | Backup dir names could collide between concurrent processes if `$$` is captured wrong. **MITIGATION:** Trivially verifiable with `echo "parent=$$, inner=$(echo $$)"` during Phase 4 dev — add to test-update-summary.sh as a self-check. This is a very well-known bash behavior; confidence is high, but verification is one-line cheap. |
| A2 | bash 3.2 (macOS default) supports `< <(...)` process substitution | Pattern 2, Pattern 4 | Process-substitution idiom would fail on older macOS shells. **MITIGATION:** Phase 2/3 test harnesses already use `< <(...)` (verified in `test-state.sh`, `test-dry-run.sh`, `test-safe-merge.sh`) and pass CI. Low risk. |

All other claims in this research were either VERIFIED (against Context7 / jq manual / the repo itself) or CITED (with URL) — no user confirmation needed beyond these two.

## Open Questions

These surfaced during research and need planner attention (or were intentionally left to Claude's Discretion by CONTEXT.md).

1. **Should `write_state` be extended to accept an `--install-time` parameter to carry over the original v3.x install timestamp ("unknown" per D-50) vs. always using `iso8601_utc_now()`?**
   - What we know: `lib/state.sh::write_state` currently uses `now` for both the top-level `installed_at` AND each per-file `installed_at`.
   - What's unclear: On a mode-switch (D-52), we want the top-level `installed_at` to stay at the ORIGINAL install time, while individual newly-installed files get the current `installed_at`.
   - Recommendation: Planner extends `write_state` signature in Plan 04-01 to accept an optional `install_time` argument (default to `iso8601_utc_now`). Or, keep `write_state` as-is and accept that the top-level `installed_at` rolls forward on every update — which is actually what today's users would expect ("last updated at" rather than "first installed at"). **Minor**; planner discretion.

2. **Should the schema add a top-level `toolkit_version` field?**
   - What we know: D-59 requires `state.toolkit_version == manifest.version` for no-op. Today's schema has no such field — it has `.version: 1` (schema version, not toolkit version).
   - What's unclear: Where does we persist the toolkit version? Can we reuse the existing schema or do we need a new field?
   - Recommendation: Add `toolkit_version` as a new TOP-LEVEL field alongside `version` (the schema version). Phase 3 installers (init-claude.sh and init-local.sh) already have `VERSION` in scope — extend `write_state` to accept it as an 8th parameter and store `"toolkit_version": "$version"` in the output. D-59's comparison becomes `jq -r '.toolkit_version' <<<"$STATE_JSON" == $(jq -r '.version' "$MANIFEST_TMP")`. Backward compatible via `// ""` default.

3. **Should `--dry-run` be implemented for Phase 4?**
   - What we know: CONTEXT Deferred Ideas says "Not blocking; could be added in Phase 4 if cheap, otherwise park for v4.1."
   - What's unclear: Is it cheap?
   - Recommendation: Yes — it's cheap. The entire "compute diffs" path (steps 1-6 in the diagram) is read-only. Add `--dry-run` to step-6-output the planned action set (same 4 groups, but labeled "Would INSTALL / Would UPDATE / ..."). Exits 0 without locking or backing up. Total cost: ~20 extra lines of if-branching at end of step 6. Approach mirrors Phase 3 `print_dry_run_grouped`.

4. **Does the `rollback-update.sh` command already exist, and what backup path convention does it assume?**
   - What we know: CONTEXT Deferred Ideas mentions it as an existing command; `commands/rollback-update.md` is in the manifest.
   - What's unclear: The command's exact behavior — does it glob for backup dirs with the old format `<YYYYMMDD>-<HHMMSS>` or the new format `<unix-ts>-<pid>`?
   - Recommendation: Planner reads `commands/rollback-update.md` in Plan 04-03 and decides whether to update it OR leave it for a separate plan. If the command hard-codes the old format, Phase 4 backups won't be findable by rollback. **This is a real breaking concern** — surfacing explicitly.

5. **What's the behavior on a file that exists in `state.installed_files` but NOT on disk (user `rm`'d it outside the toolkit)?**
   - What we know: D-54 new_files logic filters by `manifest - installed`, so a deleted-by-user file IS still in `state.installed_files` and will NOT be treated as new.
   - What's unclear: Should Phase 4 detect this (on-disk absent ≠ state says installed) and auto-reinstall? Or leave it to the user to manually recover?
   - Recommendation: Auto-reinstall. It's a common user story ("I accidentally deleted `commands/plan.md`, how do I get it back?") and the answer "run update-claude.sh" is clean. Add a 6th case to the mutation dispatch: `reinstall_missing = [f for f in state.installed_files if not (on_disk(f) or f in current_skip_set)]`. Auto-install with log line `Reinstalled: $path (missing on disk)`. Zero user prompting. This is a mild overreach of UPDATE-01..06 but user-value-positive. Planner discretion.

## Environment Availability

Phase 4 requires no new tools beyond what Phase 2/3 already mandates. Verified availability on the development host (Darwin 25.3.0):

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `bash` | All scripts | ✓ | 3.2+ macOS / 4+ Linux | — |
| `jq` | Phase 3/4 manifest parsing + set-diff | ✓ | 1.7.1 (apple) | none — hard-fail per Phase 2/3 pattern |
| `python3` | `lib/state.sh` atomic writes + SHA-256 | ✓ | 3.8+ required by existing scripts | none — hard-fail |
| `curl` | Remote manifest + file downloads | ✓ | system | none — hard-fail |
| `diff` | D-56 `d` option (unified diff) | ✓ | Apple diff (BSD-derived) / GNU on Linux | none — POSIX standard, always available |
| `shasum` OR `sha256sum` | Not used directly; `lib/state.sh::sha256_file` uses python3 | ✓ (both) | — | python3 hashlib is the actual primitive |
| `cp` with `-R` flag | Tree backup (D-57) | ✓ | POSIX | none — hard-fail |
| `mktemp` with `"${TMPDIR:-/tmp}/XXXX"` pattern | Temp files for manifest fetch, remote-file diff | ✓ | POSIX (BSD + GNU) | none |

**No missing dependencies. No fallbacks required. Phase 4 executes entirely on the v3.x-compatible baseline.**

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Bash scripts in `scripts/tests/*.sh`, orchestrated by `Makefile:test` target |
| Config file | None (tests are self-contained; each sources `scripts/lib/install.sh` or `scripts/lib/state.sh` directly) |
| Quick run command | `bash scripts/tests/test-update-drift.sh` (one test file) |
| Full suite command | `make test` (Tests 1-11 after Phase 4 lands Tests 9/10/11) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UPDATE-01 | state.json read on start; v3.x synthesis writes synthesized state; mode-drift prompt appears on state.mode != recommend_mode | unit + integration | `bash scripts/tests/test-update-drift.sh` | ❌ Wave 0 (D-61 creates it) |
| UPDATE-02 | update-claude.sh reads manifest.files.* + skip-set; no hand-maintained lists | structural | `grep -c 'for file in agents/' scripts/update-claude.sh` → 0 | Implicit in `make validate` once D-62 delete lands |
| UPDATE-03 | New-file detection + auto-install with skip-filter applied | integration | `bash scripts/tests/test-update-diff.sh` (scenario "new") | ❌ Wave 0 (D-61 creates it) |
| UPDATE-04 | Removed-file detection + [y/N] prompt + delete into backup | integration | `bash scripts/tests/test-update-diff.sh` (scenario "removed") | ❌ Wave 0 |
| UPDATE-05 | Backup path = `~/.claude-backup-<unix-ts>-<pid>/`, no collision under same-second concurrent runs | integration | `bash scripts/tests/test-update-summary.sh` (collision scenario: 2 parallel runs) | ❌ Wave 0 |
| UPDATE-06 | Summary with INSTALLED/UPDATED/SKIPPED/REMOVED groups; no-op exits 0 with one-line message | integration | `bash scripts/tests/test-update-summary.sh` (no-op + full-run scenarios) | ❌ Wave 0 |
| D-56 hash check | Modified file detected via SHA-256 mismatch → prompt [y/N/d] | unit | `bash scripts/tests/test-update-diff.sh` (scenario "modified") | ❌ Wave 0 |
| D-59 no-op | 5-condition check exits 0 without backup | integration | `bash scripts/tests/test-update-summary.sh` (scenario "noop-version-match") | ❌ Wave 0 |
| D-50 synthesis | Missing state file → filesystem scan → write synthesized state | unit | `bash scripts/tests/test-update-drift.sh` (scenario "v3x-upgrade") | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bash scripts/tests/test-update-drift.sh` (or whichever test file the task touches) — runs in <5s
- **Per wave merge:** `make test` — runs Tests 1-11 in under 30s
- **Phase gate:** `make check` (shellcheck + markdownlint + test + validate) green before `/gsd-verify-work`; `make test` Tests 1-8 (prior phases) MUST stay green

### Wave 0 Gaps

Phase 4 Plan (b) or a dedicated test-scaffolding task should create these before any production code lands (TDD cadence per Phase 3 Plan 3 precedent):

- [ ] `scripts/tests/test-update-drift.sh` — covers D-50 (v3.x synthesis), D-51 (mode-drift prompt), D-52 (mode-switch transaction including old_installed ∩ new_skip_set removal logic). Scenarios: (a) v3x-upgrade-path, (b) mode-drift-accept (user says y), (c) mode-drift-decline (user says n), (d) mode-drift-curlbash (no /dev/tty), (e) mode-switch-transaction-integrity (backup exists, correct files removed, correct files added).
- [ ] `scripts/tests/test-update-diff.sh` — covers D-53 (manifest iteration), D-54 (new-file detection), D-55 (removed-file with [y/N] prompt), D-56 (modified file with [y/N/d]). Scenarios: (a) new-file-auto-install, (b) new-file-filtered-by-skip-set, (c) removed-file-accept (y), (d) removed-file-decline (n), (e) modified-file-overwrite (y), (f) modified-file-keep (n), (g) modified-file-diff (d). REQUIRES seeded `toolkit-install.json` + fixture manifest with known added/removed files.
- [ ] `scripts/tests/test-update-summary.sh` — covers D-57 (backup path format), D-58 (summary grouping + colors), D-59 (no-op). Scenarios: (a) no-op-exits-0-no-backup, (b) full-run-summary-all-four-groups-present, (c) backup-path-format-matches-regex, (d) same-second-concurrent-runs-no-collision, (e) noop-via-version-match-empty-diffs.
- [ ] `scripts/tests/fixtures/update-fixture.sh` (optional helper) — emits the seeded `toolkit-install.json` + the fixture `manifest-update.json` used by Tests 10/11. Mirrors `scripts/tests/fixtures/manifest-v2.json` pattern from Phase 3.
- [ ] `Makefile` — add Tests 9/10/11 invocations between Test 8 and the final "All tests passed!" line (D-61).

**Test fixture pattern (per CONTEXT question 6):**

```
scripts/tests/fixtures/
├── manifest-v2.json           # Phase 3 fixture — keep unchanged
├── manifest-update-v2.json    # NEW for Phase 4: "manifest AFTER an update" fixture with
│                              #   2 new entries, 1 removed entry, 1 modified (hash-bumped) entry
│                              #   relative to toolkit-install-seeded.json
└── toolkit-install-seeded.json # NEW for Phase 4: pre-seeded state matching manifest-v2.json
                                #   with known install_time_hashes (use SHA-256 of known content)
```

Scenarios use this pair to trigger each diff case deterministically.

## Security Domain

> Included per GSD research protocol. `security_enforcement` is not explicitly false in `.planning/config.json`, so default enabled applies.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth boundary — script runs as the user who invoked it, user's own filesystem. |
| V3 Session Management | no | No sessions — stateless per invocation. |
| V4 Access Control | no | No multi-user access. All access mediated by filesystem permissions, which Phase 4 does not change. |
| V5 Input Validation | yes | `--mode` flag validated against `MODES` array (verified in Phase 3 `init-claude.sh:97-106`); Phase 4 extends with `--prune` / `--offer-mode-switch` value validation. Mode-drift prompt reads user input via `read -r -p ... < /dev/tty` — validated by `case` statement in caller. |
| V6 Cryptography | yes (narrow) | SHA-256 for install-time hash comparison — `lib/state.sh::sha256_file` uses `python3 hashlib.sha256` (FIPS-cleared, SHA-256 is collision-resistant for this use case). Hashes are used as integrity checks, not as authentication or key material — so the bar is integrity (any difference trips) not crypto-grade secrecy. |
| V11 Business Logic | yes | D-52 mode-switch transaction must be atomic from the user's perspective — either the old mode state is on disk, or the new mode state. The global tree backup is the recovery mechanism. V11.1.2 "process high-value operations in a logical order" → acquire_lock → backup → mutate → write_state → release_lock. |
| V14 Configuration | yes | The `~/.claude/settings.json` invariant from Phase 3 SAFETY-04 MUST NOT be violated by Phase 4. Phase 4 does NOT write to settings.json — verify in testing that `update-claude.sh` never calls `merge_settings_python` or touches `$HOME/.claude/settings.json`. |

### Known Threat Patterns for Phase 4

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| **Symlink attack on backup path** — attacker pre-creates `~/.claude-backup-<unix-ts>-<pid>` as a symlink to a sensitive directory before Phase 4 creates it | Tampering | `cp -R` on POSIX follows symlinks for the source but for the destination it creates a new directory if the target is a symlink pointing to a non-existent path (BSD+GNU differ slightly). **MITIGATION:** Use `mkdir` with `mkdir "$BACKUP_DIR"` BEFORE `cp -R "$HOME/.claude/"* "$BACKUP_DIR/"`. If `mkdir` fails (dir exists), error out and pick a new suffix (this is where the PID suffix is load-bearing — same-second collision is detectable). Never use `cp -R ~/.claude/ $BACKUP_DIR/` with trailing slash behaviors that differ BSD vs GNU. |
| **TOCTOU on state file between read and write** | Tampering | Atomic write via `tempfile.mkstemp + os.replace` (already in `lib/state.sh`). Lock held via `acquire_lock` for the duration of mutation. Window between read_state at step 4 and write_state at step 10 is protected by the lock. |
| **Manifest served from compromised raw.githubusercontent.com** — attacker MITMs the HTTPS fetch and delivers a malicious manifest | Spoofing, Elevation of Privilege | **Explicit non-goal per Phase 2 discussion.** TK assumes GitHub raw CDN is authoritative. HTTPS with system trust store is the only mitigation. Adding checksum verification would require a separate trusted distribution channel — out of scope. |
| **Injection via filename containing shell metacharacters** — attacker crafts a manifest with `path: "commands/foo; rm -rf ~"` | Tampering, Elevation of Privilege | **MITIGATION:** All paths from jq are handled as shell variables with double-quoting (`"$HOME/.claude/$path"`), never `eval`'d or exec'd. `curl -o "$dest"` is a file argument, not a command — safe. `diff -u "$a" "$b"` — safe. `rm -f "$HOME/.claude/$path"` — safe. Verify by `make shellcheck` (SC2086 catches unquoted expansions). |
| **Disk full during atomic write** — `write_state` fills disk mid-write | DoS | `tempfile.mkstemp` + `os.replace` semantics: temp file fails to fully write → `os.replace` never fires → original state file intact. `write_state` propagates the exception; caller sees non-zero return and should restore from backup. |
| **Corrupted `toolkit-install.json` causing infinite synthesis loop** — each synthesis fails, each failure triggers another synthesis | DoS | Explicit one-shot synthesis: if synthesis fails, hard-exit (don't loop). Covered in Pitfall 10. |
| **User-modified file prompts reveal internal structure to a shoulder-surfer** — `diff -u` output of a secret-containing file leaks | Information Disclosure | TK files are public by definition (they're installed from a public repo). No TK-managed file should ever contain secrets. `settings.json` is the one file that can contain secrets (env vars via TK-unmanaged block), and Phase 4 does NOT touch it. Low risk; no mitigation needed. |

**Summary: Phase 4 is a narrow refactor. The only cryptographic surface is SHA-256 for integrity (not secrecy); the only threats worth mitigating are backup-symlink and atomic-write TOCTOU, both addressed by existing patterns.**

## Project Constraints (from CLAUDE.md)

The user's global and project CLAUDE.md plus `.planning/PROJECT.md` constrain Phase 4. The planner must honor every item below.

### From `.planning/PROJECT.md` §Constraints

- **Tech stack**: Markdown + POSIX shell (bash, macOS BSD + GNU Linux). **No Node/Python runtime dependency for install scripts.** Phase 4 clarification: python3 is already a documented dep (per Phase 1 D-05 and Phase 3 D-37), used for JSON manipulation. Continue using it for `merge_*_python` + `sha256_file` + `write_state`. No NEW python3 scripts beyond existing primitives.
- **Compatibility**: must work under `curl ... | bash` → every interactive `read` uses `< /dev/tty 2>/dev/null`. macOS BSD `head`/`sed`/`tail` (no GNU-only flags). **Phase 4 MUST NOT introduce GNU-only flags — verified with `make shellcheck`.**
- **Safety**: never delete user files without confirmation; every destructive action prompts. Phase 4 inherits this — D-55 removal prompt, D-56 modified-file prompt both honor it.
- **Quality gate**: `make check` must pass on every PR. Phase 4's task commits each must pass it individually (per TDD cadence from Phase 3 Plan 3). CI-enforced via `.github/workflows/quality.yml`.
- **Commits**: Conventional Commits `feat(04-01): ...`, `feat(04-02): ...`, `feat(04-03): ...` per D-62. Branch name `feature/phase-4-update-flow` (or similar). Never push directly to `main`.

### From project `CLAUDE.md` (./CLAUDE.md)

- **Markdown lint (MD040/MD031/MD032/MD026):** All RESEARCH.md / PLAN.md / SUMMARY.md produced by Phase 4 must pass `markdownlint`. Code blocks need language tags (`bash`, `text`), blank lines around blocks and lists, no trailing punctuation in headings.
- **Shell lint (`shellcheck` at warning level):** Every new script must pass `make shellcheck`. Common traps: `SC2034` on forward-ref variables (add `# shellcheck disable=SC2034` with comment per Phase 3 precedent); `SC2153` on "MODES may not be assigned" (add `# shellcheck disable=SC2153  # MODES is defined in lib/install.sh`).
- **File naming:** kebab-case for test harnesses (`test-update-drift.sh`, not `testUpdateDrift.sh`). Consistent with `test-modes.sh`, `test-dry-run.sh`, `test-safe-merge.sh`.
- **Conventional Commits:** `feat(04-01):` prefix. No `chore:`, no `wip:`, no breaking-change footer unless explicitly agreed (breaking change IS expected for the deletion of hand-lists, but it's a structural change with no user-visible API break, so `feat:` is correct).

### From user global `~/.claude/CLAUDE.md`

- **KISS:** simplest working solution. Don't add `--prune-older-than-N-days` or `--auto-retry-on-curl-failure` — park for v4.1.
- **YAGNI:** No `--dry-run` **unless** it's cheap (it is per Open Question #3; planner discretion).
- **3-Fix Rule:** If the mutation dispatch gets tangled and takes 3 attempts to get right, stop and refactor to a cleaner dispatch table. Don't force-fit complexity.
- **Prefer editing existing files over creating new ones:** `compute_file_diffs` goes INSIDE `scripts/lib/install.sh`, not a new file. `synthesize_v3_state` is an inline function in `update-claude.sh`, not a new library file. The only NEW files are the three test harnesses + (optionally) a test fixture helper.
- **Security forbidden patterns:** No `eval`, no `exec`, no unquoted `$var` expansions in shell. No hardcoded paths that could be escape-sequences (use `$HOME/.claude/...` not hardcoded `/Users/...`).
- **Doubt Protocol:** If the planner considers adding ANY of {exec call, shell expansion of user input, new network endpoint, JSON parsing via `sed` or `awk` instead of jq}, stop and surface to user.

## Sources

### Primary (HIGH confidence)

- **`scripts/lib/state.sh`** — inspected 2026-04-18. Function signatures + atomic write protocol + lock pattern confirmed. [VERIFIED against file contents line-by-line.]
- **`scripts/lib/install.sh`** — inspected 2026-04-18. `MODES`, `recommend_mode`, `compute_skip_set`, `backup_settings_once`, `merge_settings_python`, `merge_plugins_python` all confirmed present and tested.
- **`scripts/update-claude.sh`** (current HEAD on `main`) — inspected 2026-04-18. Hand-list at lines 125-179 (agents / prompts / skills / commands / rules sections), backup at line 111, detect.sh soft-fail wiring at lines 19-44 all verified as described in CONTEXT.
- **`scripts/init-claude.sh`** — inspected 2026-04-18 (lines 1-330). Flag parsing, manifest-version guard, re-run delegation, mode-change prompt, manifest-driven install loop all confirmed as the pattern Phase 4 inherits.
- **`scripts/init-local.sh`** — inspected 2026-04-18 (lines 1-280). Per-project STATE_FILE override, manifest-driven install loop, acquire_lock/release_lock wrapping all confirmed.
- **`scripts/detect.sh`** — inspected 2026-04-18. Exports `HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION`; `detect_superpowers || true` guard confirmed.
- **`scripts/tests/test-modes.sh` / `test-dry-run.sh` / `test-safe-merge.sh`** — inspected 2026-04-18. Test structure (scenario-per-function + `assert_eq` + `reset_scratch` + `report_pass`/`report_fail`) confirmed as the pattern for Phase 4's three new tests.
- **`manifest.json`** — inspected 2026-04-18. Manifest v2 schema confirmed. 7 SP-conflict entries + 0 GSD-conflict entries in the production manifest.
- **`scripts/tests/fixtures/manifest-v2.json`** — inspected 2026-04-18. Fixture has 7 SP-conflict + 1 GSD-conflict for deterministic 0/7/1/8 skip counts.
- **`Makefile`** — inspected 2026-04-18. Test target runs Tests 1-8; validate target has the BUG-07 drift check at lines 108-128 that becomes vacuously green after D-62 deletion.
- **`.planning/phases/04-update-flow/04-CONTEXT.md`** — fully read. All 13 decisions (D-50..D-62) copied verbatim into the User Constraints section.
- **`.planning/phases/03-install-flow/03-*-SUMMARY.md`** — fully read. Phase 3 completion state + primitives confirmed.
- **`.planning/phases/02-foundation/02-03-SUMMARY.md`** — fully read. State library primitives (write_state, acquire_lock, sha256_file) confirmed.

### Secondary (MEDIUM confidence — verified with official source)

- **jq 1.7 manual, Set Operations** — `a - b` on arrays is documented set-difference [CITED: https://jqlang.org/manual/#set-operations, fetched 2026-04-18]. Cross-checked: `jq -n '["x","y","z"] - ["y"]'` on local jq 1.7.1 returns `["x","z"]` as expected.
- **POSIX `diff -u`** — unified diff is in POSIX.1-2008; no GNU-only dependency [VERIFIED locally: `man diff` on Darwin 25.3.0 shows Apple diff BSD-derived; `-u` works, `--color=always` is GNU-only and NOT used by Phase 4].
- **bash `$$` semantics** — expands to parent script PID in command substitution contexts [standard bash behavior; flagged as A1 assumption for one-line verification].

### Tertiary (LOW confidence — training-only, flagged for validation)

- None. Every load-bearing claim was verified against the repo or against the jq manual.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — every tool is already installed and already used elsewhere in the repo; no new dependencies.
- Architecture: HIGH — flow diagram derives from Phase 3's init flow (directly analogous); all primitives exist.
- Pitfalls: HIGH — 12 pitfalls listed, each either verified against shell-behavior standards or against existing repo usage patterns.
- Security: HIGH — narrow surface; main threat (symlink on backup dir) is mitigable with `mkdir` ordering.
- Validation: MEDIUM — test file shapes are clear but the seeded-state fixture design needs concrete scenario listing in the plan (three tests, ~10 scenarios total). Planner should confirm scenario count in Wave 0.

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — the repo's primitives are stable; only regressions to Phase 2/3 state would invalidate the research)

---

*Phase: 04-update-flow*
*Research completed: 2026-04-18*
