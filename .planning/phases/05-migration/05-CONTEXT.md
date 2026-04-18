# Phase 5: Migration - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship `scripts/migrate-to-complement.sh` — a standalone, one-time, interactive migration script for existing v3.x users who have `superpowers` and/or `get-shit-done` installed alongside the toolkit's shipped duplicates. End state:

1. Script enumerates every v3.x duplicate (paths in `manifest.files.*` whose `conflicts_with` intersects `recommend_mode(HAS_SP, HAS_GSD)`'s skip-set) that physically exists in `~/.claude/`.
2. For each duplicate, prints a three-column diff summary: **TK template hash** (from remote manifest fetch) vs **current on-disk hash** vs **SP/GSD equivalent hash** (from `~/.claude/plugins/cache/.../superpowers/<ver>/<same-basename>` or GSD equivalent).
3. For each duplicate, prompts `[y/N/d]` with default `N` (see D-74). If the file is locally modified per two-signal detection (D-73), prints an extra warning before the prompt.
4. Before any removal, takes ONE full `cp -R ~/.claude/` backup to `~/.claude-backup-pre-migrate-<unix-ts>/` and prints the path on screen (MIGRATE-04).
5. After the per-file loop, rewrites `~/.claude/toolkit-install.json` to record the new `recommend_mode(HAS_SP, HAS_GSD)` mode, updated `installed_files[]`, and entries for files the user declined (with `reason: kept_by_user`).
6. If invoked when already migrated (two-signal AND per D-78), prints one line `Already migrated to <mode>. Nothing to do.` and exits 0.
7. `scripts/update-claude.sh` is extended: when triple-AND signal D-77 holds, it emits an informational hint recommending the user run `migrate-to-complement.sh`. No auto-invoke.
8. Retrofit: `scripts/update-claude.sh`'s Phase 4 D-50 v3.x synthesis path is extended to write `synthesized_from_filesystem: true` in the state file; state schema bumps `version: 1` → `version: 2`.

In scope: MIGRATE-01..06, plus two small retrofits (state schema v2, update-claude.sh hint). Out of scope: migration-script documentation in README (Phase 6 DOCS-01..04), per-release backup pruning (BACKUP-01/02 deferred to v4.1), release validation matrix (Phase 7 VALIDATE-01..04), auto-invoke from update-claude.sh (explicitly excluded by MIGRATE-01 "one-time, isolated from routine update path").

</domain>

<decisions>
## Implementation Decisions

### Three-way diff mechanics (MIGRATE-02)

- **D-70:** **TK template hash source = remote manifest fetch.** `migrate-to-complement.sh` mirrors Phase 4's `update-claude.sh` pattern (`scripts/update-claude.sh:43-66`): `curl -sSLf $REPO_URL/<path> -o $TMP_FILE` then `sha256_file` (from `scripts/lib/state.sh`) per duplicate. 7 additional HTTP requests for the confirmed SP duplicate set — acceptable for a one-time interactive script. No manifest schema change, no CI-driven hash generation, no drift risk. If the remote fetch fails for a given duplicate: print `⚠ Could not fetch TK template for <path> — skipping diff column`, continue with two-column diff (D-72 fallback shape).
- **D-71:** **SP/GSD equivalent path mapping = same basename.** `commands/debug.md` in TK maps to `~/.claude/plugins/cache/claude-plugins-official/superpowers/<SP_VERSION>/commands/debug.md` (same relative path under the plugin root). Confirmed against live SP 5.0.7 layout via the same dev-machine grep that fed Phase 2 D-15. No manifest schema addition (no `sp_equivalent:` field), no N+1 find calls. Planner MUST re-verify the mapping by reading the live SP/GSD directory layout during plan-phase research; if the mapping fails for any of the 7 confirmed duplicates, switch to explicit-field shape and log the deviation.
- **D-72:** **SP/GSD path unreadable → 2-column diff + marker, continue prompt.** When `HAS_SP=true` (or `HAS_GSD=true`) but the expected plugin-cache path does not exist: print the three-column header, show `TK template` and `on-disk` hashes, and render the third column as `— (SP file not found at <expected-path>)`. The per-file `[y/N/d]` prompt still fires — user has enough info to decide from TK-template-vs-on-disk. Graceful degrade; no hard abort. Logged as a warning so user can re-install SP if they want the full 3-way view.

### User-modification detection (MIGRATE-03)

- **D-73:** **Two-signal user-mod detection.** A file is flagged as "locally modified" (triggering D-74's extra warning + `[y/N/d]` default `N`) if EITHER: (a) `current_on_disk_hash != state.installed_files[<path>].sha256` (Phase 2 STATE-04 install-time hash), OR (b) `current_on_disk_hash != TK_template_hash` (Phase 5 D-70 remote fetch). Either signal triggers the warning. Covers the Phase 4 D-50 synthesis edge case where signal (a) is defeated by `install_time_hash == current_hash` (both taken from disk at synthesis time) — signal (b) catches "user modified the file BEFORE v3.x→v4.0 upgrade ran synthesis."
- **D-74:** **Prompt shape = `[y/N/d]`, default `N` when flagged.** For clean (unmodified) files: `[y/N]` default `N` (destructive action default-denies per PROJECT.md invariant). For flagged (D-73) files: `[y/N/d]` default `N`, with `d` = print `diff -u` of `on-disk vs TK_template`, then re-prompt. Matches Phase 4 D-56 `[y/N/d]` shape verbatim (same diff semantics, same re-prompt loop). No `/dev/tty` fails closed to `N`. No `[y/N/d/s]` skip-and-keep-alone mode (deferred).
- **D-75:** **State schema v2 — `synthesized_from_filesystem` marker.** `scripts/lib/state.sh`'s `write_state` is extended to accept an optional 8th argument (or equivalent keyword) that sets `state.synthesized_from_filesystem: true`. `state.version` bumps `1` → `2`. Phase 4's `update-claude.sh` D-50 synthesis path is retrofitted to pass `true`; normal Phase 3 install writes omit it (or emit `false`). Phase 5 reads this field to know that signal (a) from D-73 is unreliable for a given state file. Backwards-compat: v1 state files (no field) are treated as `synthesized_from_filesystem: false` by default reader — NO auto-migration of old state files.

### Orchestration (MIGRATE-01)

- **D-76:** **Strict standalone script + update-claude.sh hint.** `scripts/migrate-to-complement.sh` is the ONLY entry point for destructive migration action — MIGRATE-01 "destructive, one-time, isolated from routine update path" invariant preserved. `scripts/update-claude.sh` does NOT auto-invoke migrate. Instead, `update-claude.sh` (after its existing state-load + detect block at lines ~43-100) emits a SINGLE-LINE informational hint when the D-77 triple-AND signal holds: `ℹ Legacy duplicates detected (SP/GSD installed, TK mode=standalone). Run: ./scripts/migrate-to-complement.sh`. Hint prints once per run, in CYAN, non-blocking — normal update flow continues.
- **D-77:** **Detection signal for the hint = triple AND.** Three conditions must ALL be true for `update-claude.sh` to emit the hint: (a) `state.mode == "standalone"`, (b) `HAS_SP == "true" || HAS_GSD == "true"`, (c) at least one path exists in `compute_skip_set(recommend_mode(HAS_SP, HAS_GSD), manifest.json) ∩ { actual files on disk under ~/.claude/ }`. Condition (c) = "at least one manifest duplicate physically exists in the user's install." Handles the "user manually deleted duplicates but didn't migrate state" case (condition c fails → no hint) — correct, since there is nothing destructive to do.

### Idempotence (MIGRATE-06)

- **D-78:** **"Already migrated" marker = two-signal AND.** `migrate-to-complement.sh` exits early with `Already migrated to <mode>. Nothing to do.` + exit 0 when BOTH: (a) `state.mode != "standalone"`, (b) `compute_skip_set(state.mode, manifest.json) ∩ { actual files on disk }` is empty. Self-healing: if the user manually rolls back `toolkit-install.json` but duplicates are already gone, condition (b) catches it. If the user manually re-creates a duplicate but state says `complement-sp`, condition (b) fails → script re-runs the full flow. No separate `migrated_at` timestamp field — the two existing signals are sufficient; avoids another schema bump.
- **D-79:** **Partial migration mode = `recommend_mode(HAS_SP, HAS_GSD)`.** If the user accepts some duplicates for removal but declines others, the final state still records `mode = recommend_mode(HAS_SP, HAS_GSD)` (e.g., `complement-sp`). Declined files go into `state.skipped_files[]` with `reason: "kept_by_user"`. Next `migrate-to-complement.sh` run detects the remaining duplicates via the D-78 signal (b), re-prompts ONLY for the still-present ones. The `state.mode != standalone` signal alone would make the "try again" run feel like it's in the wrong mode — adding the filesystem-intersection check makes the behavior correct even in partial-migration states.

### Process

- **D-80:** Suggested plan cluster split for the planner (3 plans, dependency order a → b → c):
  - **05-01** — state schema v2 bump (`synthesized_from_filesystem`) + `update-claude.sh` D-50 synthesis retrofit + `update-claude.sh` migrate-hint emission (D-75 + D-76 hint path + D-77). Foundational: plans b and c assume state v2 exists.
  - **05-02** — `migrate-to-complement.sh` core: three-way diff (D-70/D-71/D-72) + two-signal user-mod detection (D-73) + per-file prompt loop (D-74) + full backup (MIGRATE-04).
  - **05-03** — state rewrite (MIGRATE-05) + idempotence check (D-78/D-79) + partial-migration handling + integration of `acquire_lock`/`release_lock` from `state.sh`.
- **D-81:** Test harness extends `scripts/tests/` with three new harnesses (wired into `make test` as Tests 12/13/14, after Phase 4's Tests 9/10/11):
  - `test-migrate-diff.sh` — 3-way diff output against fixture state + fixture manifest + fixture SP cache; signal-(a) vs signal-(b) user-mod detection.
  - `test-migrate-flow.sh` — full flow with `TK_TEST_INJECT_*` pattern (mirrors Phase 3 D-37 test seam); simulates accept-all, decline-all, partial.
  - `test-migrate-idempotent.sh` — second-run emits `Already migrated …` + exit 0; manual-rollback scenario exercises the filesystem-intersection self-heal.
- **D-82:** One PR for the phase. Conventional Commits: `feat(05-01): ...`, `feat(05-02): ...`, `feat(05-03): ...`. Each plan commits atomically per task per prior-phase discipline. Branch: `feature/phase-5-migration`. Never push to `main`.

### Claude's Discretion

- Exact flag surface for `migrate-to-complement.sh`: `--yes` (bypass per-file prompts — NOT `--force`; destructive), `--dry-run` (print would-remove list + exit 0), `--verbose` (expand `Already migrated …` line to include kept-file list), `--no-backup` (MUST fail hard — backup is invariant per PROJECT.md Constraints). Minimum viable: interactive-only default; flags are convenience.
- Exact post-migration summary format — reuse Phase 4 D-58 4-group shape. Suggested groups: `MIGRATED N` (files removed), `KEPT P (reason per file)` (user-declined), `BACKED UP Q files to <path>` (single-path summary), `MODE <old> → <new>`. Planner picks final wording.
- Exact diff command for `[y/N/d]` `d` option — `diff -u` (POSIX-portable, matches Phase 4 D-56 direction). Planner may choose `git diff --no-index --no-color` if a git repo is handy, but the default must survive without `git`.
- Exact warning text for the D-73 two-signal "locally modified" case — any clear wording that distinguishes "modified since install" (signal a) from "modified vs upstream" (signal b). Could print both signal states for transparency.
- Exact hint wording emitted by `update-claude.sh` per D-76 — any single-line CYAN informational message pointing at `./scripts/migrate-to-complement.sh`.
- Whether `migrate-to-complement.sh` fetches the remote manifest itself via `curl` or reuses the tempfile already downloaded by `update-claude.sh` when invoked from the same session — reuse is a small optimization, not required.
- Whether `--force-mode=<mode>` is accepted to bypass `recommend_mode` — likely NO for MVP (keeps decision simple), but planner may add it if the research surface calls for it.
- Exact field name for the Phase 5 state schema v2 addition — `synthesized_from_filesystem: true` is the proposed name; any JSON-safe alternative is acceptable as long as Phase 4 D-50 write path and Phase 5 read path agree.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` §"Migration" — MIGRATE-01..06 authoritative text (source of truth for this phase).
- `.planning/ROADMAP.md` §"Phase 5: Migration" — phase goal + success criteria 1–5 (e.g., three-column hash summary, pre-migrate backup path printed, idempotent re-run).
- `.planning/PROJECT.md` §"Constraints" — "never delete user files without confirmation; every destructive action prompts"; "filesystem-only detection". Backup-before-mutate invariant.
- `.planning/PROJECT.md` §"Out of Scope" — "auto-installing SP/GSD"; "migrating users without consent"; "backwards-compat shims". Auto-invoke from `update-claude.sh` is OUT OF SCOPE (D-76).
- `.planning/PROJECT.md` §"Context → Confirmed conflicts with SP/GSD" — 7 SP duplicates + 0 GSD confirmed in `manifest.json` after Phase 2 (the actual set Phase 5 must handle).

### Prior phase context (carry-forward — load all)

- `.planning/phases/01-pre-work-bug-fixes/01-CONTEXT.md` §"Implementation Decisions → BUG-04" — `< /dev/tty` guard idiom for every `read -r -p` (D-74 prompts reuse verbatim).
- `.planning/phases/02-foundation/02-CONTEXT.md` §"Implementation Decisions → D-06" — python3 SHA256 wrapper (Phase 5 `sha256_file` call sites).
- `.planning/phases/02-foundation/02-CONTEXT.md` §"Implementation Decisions → D-19/D-20/D-21/D-22" — `toolkit-install.json` schema + atomic write + schema version field + ISO-8601 timestamps (D-75 schema v2 bump builds on this).
- `.planning/phases/02-foundation/02-CONTEXT.md` §"Implementation Decisions → D-08..D-11" — `mkdir`-based lock with stale recovery (Phase 5 `migrate-to-complement.sh` MUST acquire the lock for the duration of its run).
- `.planning/phases/03-install-flow/03-CONTEXT.md` §"Implementation Decisions → D-42" — mode-change interactive prompt pattern (shape for D-74 prompts).
- `.planning/phases/03-install-flow/03-CONTEXT.md` §"Implementation Decisions → D-44/D-45" — jq skip-list filter + `compute_skip_set` location (D-77/D-78 signals call this).
- `.planning/phases/04-update-flow/04-CONTEXT.md` §"Implementation Decisions → D-50" — v3.x state synthesis path (Phase 5 D-75 retrofits this function to write `synthesized_from_filesystem: true`).
- `.planning/phases/04-update-flow/04-CONTEXT.md` §"Implementation Decisions → D-56" — `[y/N/d]` prompt with `d` option (D-74 reuses shape and `diff -u` direction).
- `.planning/phases/04-update-flow/04-CONTEXT.md` §"Implementation Decisions → D-57/D-58/D-59" — full-tree backup layout + 4-group post-run summary + no-op line (Phase 5 adapts for pre-migrate backup + MIGRATED/KEPT/BACKED UP summary + D-78 no-op line).
- `.planning/phases/04-update-flow/04-CONTEXT.md` §"Non-Goals" — Phase 4's v3.x synthesis is NOT a migration; Phase 5 is the full migration. Clarifies the division-of-labor this context codifies.

### Phase 2/3/4 deliverables (now consumed by Phase 5)

- `scripts/detect.sh` — sourced by `migrate-to-complement.sh` at the top (same pattern as `update-claude.sh:43-66`). Exports `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION`.
- `scripts/lib/state.sh` — sourced by `migrate-to-complement.sh`: `read_state`, `write_state` (extended for v2 per D-75), `sha256_file`, `acquire_lock` / `release_lock`. Lock acquired for the entire migrate run.
- `scripts/lib/install.sh` — sourced: `recommend_mode`, `compute_skip_set` (both D-77 and D-78 compute skip-sets), `compute_file_diffs_obj` may be reused for duplicate enumeration.
- `scripts/update-claude.sh` — EXTENDED (not reimplemented). Two retrofits: (a) D-50 synthesis path writes `synthesized_from_filesystem: true`, (b) after state load + detect, emit migrate hint if D-77 triple AND holds.
- `manifest.json` — v2 schema, 7 `conflicts_with` annotations. Phase 5 reads via `jq` to enumerate duplicates. Fetched remotely via `curl` to `mktemp` for TK template hashing per D-70.
- `scripts/validate-manifest.py` — Phase 5 must keep `make validate` green; any new script added to manifest must satisfy Check 6.
- `scripts/tests/` — Phase 5 adds Tests 12/13/14 (see D-81). Tests 1..11 must remain green.

### Files to create or extend

- `scripts/migrate-to-complement.sh` — NEW. Standalone script implementing MIGRATE-01..06 per decisions above. Sources `detect.sh`, `lib/state.sh`, `lib/install.sh`. Runs under `scripts/lib/state.sh::acquire_lock` for the whole execution.
- `scripts/lib/state.sh` — EXTEND. `write_state` accepts the new `synthesized_from_filesystem` flag; bump `state.version` to `2`; keep backwards-compat read path for v1 state (treat missing field as `false`).
- `scripts/update-claude.sh` — EXTEND. (a) D-50 synthesis path calls `write_state` with the new flag set to `true`. (b) After state load + detect (existing block around lines 43-100), compute D-77 triple AND; emit single-line CYAN hint if true.
- `scripts/tests/test-migrate-diff.sh` — NEW. 3-way diff + user-mod detection (D-81).
- `scripts/tests/test-migrate-flow.sh` — NEW. Full flow with `TK_TEST_INJECT_*` seams (D-81).
- `scripts/tests/test-migrate-idempotent.sh` — NEW. Second-run + self-heal (D-81).
- `Makefile` — EXTEND `test` target with Tests 12/13/14.
- `manifest.json` — ADD entries for `scripts/migrate-to-complement.sh` and the three new test harnesses so `make validate` Check 6 stays green. (Tests are under `scripts/tests/` which is not currently a manifest bucket — planner decides whether to add a `files.scripts[]` bucket or simply reference by path; matches Phase 3's handling of its own three new test harnesses.)

### Existing patterns to mirror

- `scripts/update-claude.sh:43-66` — `curl|mktemp|source` pattern for `detect.sh` + `trap 'rm -f $TMP_FILES' EXIT` (mirror for migrate's remote TK template fetches per D-70).
- `scripts/update-claude.sh:69-80` — library fetch pattern for `lib/install.sh` + `lib/state.sh` (mirror verbatim in `migrate-to-complement.sh`).
- `scripts/update-claude.sh:83-96` — remote manifest fetch + schema version check (`manifest_version == 2`) — MIRROR in migrate.
- `scripts/init-claude.sh:84,430` — `read -r -p "..." choice < /dev/tty 2>/dev/null` for `[y/N/d]` prompts per D-74.
- `scripts/setup-security.sh:202-237` — python3 `json.load` / `json.dump` atomic-mv idiom (reused via `write_state`).
- `scripts/lib/state.sh:114-148` — `acquire_lock` with PID liveness + 1-hour mtime stale recovery; `migrate-to-complement.sh` calls this at start.
- All existing `scripts/*.sh` open with `#!/bin/bash` + `set -euo pipefail` + ANSI color constants per `.planning/codebase/CONVENTIONS.md`. `migrate-to-complement.sh` follows suit.
- Sourced library invariant (Phase 2/3/4): `scripts/lib/*.sh` have NO `set -euo pipefail`, zero stdout during sourcing, functions in snake_case. `migrate-to-complement.sh` is EXECUTED (not sourced) — full `set -euo pipefail`.

### Background analysis

- `.planning/codebase/STRUCTURE.md` — current script inventory.
- `.planning/codebase/CONVENTIONS.md` §"Code Style — Shell Scripts" — header comments, function naming, error handling.
- `.planning/codebase/CONCERNS.md` — historical drift list (why every Phase 5 code path reads `manifest.json` as source of truth, no parallel skip-lists).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/lib/state.sh` — `read_state`, `write_state`, `sha256_file`, `iso8601_utc_now`, `get_mtime`, `acquire_lock`, `release_lock`. Phase 5 calls every one of these. `write_state` needs the one-arg extension for D-75 but the signature shape is already `mode, has_sp, sp_ver, has_gsd, gsd_ver, installed_csv, skipped_csv` — adding `synthesized_from_filesystem` as an 8th positional or via env var is a small extension.
- `scripts/lib/install.sh` — `recommend_mode` (D-77/D-78/D-79 all invoke), `compute_skip_set` (both D-77 and D-78 conditions call this), `compute_file_diffs_obj` (may be reused to enumerate duplicates; or Phase 5 writes a narrower helper `compute_duplicates_fs <mode> <manifest>`).
- `scripts/update-claude.sh:43-99` — the reference implementation of "curl remote detect.sh + curl remote lib/install.sh + curl remote lib/state.sh + curl remote manifest into mktemp, trap cleanup on EXIT." `migrate-to-complement.sh` mirrors this entire block.
- `scripts/install-statusline.sh:104` — `cp "$file" "$file.bak.$(date +%s)"` pattern (mirror for MIGRATE-04 backup path: `~/.claude-backup-pre-migrate-<unix-ts>/`).
- `python3 >= 3.8` is already verified via `scripts/setup-council.sh:36-50` — hashlib + json + subprocess additions introduce no new dependency.
- `jq` is already a runtime dependency (`scripts/install-statusline.sh:31-40`, `scripts/lib/install.sh`) — Phase 5 reuses without adding.

### Established Patterns

- `#!/bin/bash` + `set -euo pipefail` + ANSI color constants at top of every executable script. `migrate-to-complement.sh` follows.
- Sourced libraries (`lib/state.sh`, `lib/install.sh`) — NO `set -euo pipefail`, zero stdout during sourcing, snake_case functions. Phase 5 sources them; any new helper added to a library file respects this invariant.
- `< /dev/tty 2>/dev/null` guard on every interactive `read` — mandatory for `curl | bash` survival. Fails closed to the safe answer (default `N` per D-74).
- python3 for JSON manipulation — used everywhere since Phase 1 D-12; Phase 5 extends the same paths. No new JSON tooling.
- Conventional Commits: one commit per task, branch per phase, never push to main. Phase 5 ships as `feature/phase-5-migration`.
- `manifest.json` is hand-edited and PR-reviewed — Phase 5's additions (migrate script + 3 test harnesses) land in `manifest.json` in the same PR or `make validate` Check 6 fails.
- `TK_TEST_INJECT_*` env-var test seams — established in Phase 3 (`merge_settings_python` uses `TK_TEST_INJECT_FAILURE`) and Phase 4 (various `TK_UPDATE_*` overrides). Phase 5 adds `TK_MIGRATE_TEST_*` seams for the three new harnesses.

### Integration Points

- `~/.claude/toolkit-install.json` — primary write target for MIGRATE-05 state rewrite. Schema bumps to v2 per D-75.
- `~/.claude/.toolkit-install.lock` — acquired by `migrate-to-complement.sh` for its entire run to serialize against any concurrent `init-claude.sh`/`update-claude.sh`. Lock uses the existing `acquire_lock` / `release_lock` helpers (Phase 2 D-08..D-11).
- `~/.claude-backup-pre-migrate-<unix-ts>/` — pre-migrate full-tree backup path (MIGRATE-04). Distinct from Phase 4 D-57's `~/.claude-backup-<unix-ts>-<pid>/` naming so the two backup kinds are visually separable when a user lists `~/`.
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/<SP_VERSION>/` — read-only source for SP equivalent hashes (D-71). Phase 5 never writes here.
- `~/.claude/get-shit-done/` — read-only source for GSD equivalents (applies when/if any `conflicts_with: ["get-shit-done"]` entries are added to the manifest; currently 0 per manifest scan).
- `manifest.json` (remote) — fetched via `curl` to `mktemp` at start of `migrate-to-complement.sh`; used for: (a) duplicate enumeration (conflicts_with intersection), (b) per-file TK template content fetch for D-70 hashes.
- `scripts/update-claude.sh` — Phase 5 retrofits two touch-points only: D-50 synthesis path (one-line extension to `write_state` call) and D-77 hint emission (single-line message after state load + detect block). No core logic changes.

### Files NOT Touched in Phase 5

- `scripts/init-claude.sh` — zero changes. Migration is post-install; `init-claude.sh` writes the initial state via `write_state(..., synthesized_from_filesystem=false)` (or omits the field; default behavior).
- `scripts/setup-security.sh`, `scripts/setup-council.sh`, `scripts/install-statusline.sh`, `scripts/verify-install.sh` — zero changes.
- `manifest.json` schema — stays v2. Phase 5 does NOT add a `sp_equivalent:` per-file field (D-71 same-basename decision).
- All `templates/*/` — zero edits. Migration operates on installed files, not template sources.
- `README.md`, `CHANGELOG.md`, documentation — Phase 6 DOCS-01..08 owns user-facing positioning of the migration story.

</code_context>

<specifics>
## Specific Ideas

- "Standalone + hint, never auto-invoke." MIGRATE-01's "destructive, one-time, isolated from routine update path" invariant is absolute. `update-claude.sh` hints at migration but does not run it.
- "Two-signal user-mod detection defeats the synthesis edge case." Phase 4 D-50 records on-disk hash as `install_time_hash` for v3.x users — a single-signal check (current vs install_time) would always pass. Signal (b) (current vs TK template) closes the hole.
- "Same-basename mapping is a research obligation." D-71 commits to same-basename for the confirmed 7 SP duplicates, but the planner MUST re-verify against live SP layout during plan-phase research — if the mapping is wrong for ANY file, switch to explicit `sp_equivalent:` field in manifest. This is deliberately load-bearing verification.
- "Full backup before any destructive action." MIGRATE-04's `~/.claude-backup-pre-migrate-<unix-ts>/` is non-negotiable. No `--no-backup` flag. If backup fails (disk full, permissions), migrate aborts before removing a single file.
- "Self-healing idempotence." D-78's filesystem-intersection check is the load-bearing signal — it makes manual state rollback recoverable and partial-migration re-runs safe. Without it, `state.mode != standalone` alone would hide user-visible inconsistency.
- "Three plans, one PR." Same discipline as Phases 2/3/4. Plan (a) bumps state v2 + retrofits update-claude.sh; plan (b) ships migrate-to-complement.sh core; plan (c) finalizes state rewrite + idempotence.
- "Prompt default is N for destructive ops." Matches PROJECT.md Constraints ("never delete user files without confirmation; every destructive action prompts"). `/dev/tty`-absent shell fails closed to N.
- "Same-basename assumption is tested, not assumed." Test 13 (`test-migrate-flow.sh`) seeds a fixture SP cache at the expected path layout; if the assumption breaks in a future SP release, the test fails loudly and flags the manifest schema extension.

</specifics>

<deferred>
## Deferred Ideas

- `[y/N/d/s]` prompt shape where `s` = "skip, keep file, move to `~/.claude/custom/` so it survives future updates" — considered, rejected for Phase 5 (scope + UX complexity). Candidate for v4.1 if user feedback surfaces the need.
- Auto-invoke migrate from `update-claude.sh` — explicitly excluded by MIGRATE-01 "isolated from routine update path" invariant. Not deferred, never implemented.
- Auto-cleanup of `~/.claude-backup-pre-migrate-<unix-ts>/` after N days — BACKUP-01/02 v4.1.
- Interactive side-by-side diff viewer for `d` option — v4.1; current: unified `diff -u` piped to pager if present, else inline.
- `--force-mode=<mode>` flag to override `recommend_mode` — rejected for MVP; user who wants a non-recommended mode can run `init-claude.sh --mode <X> --force` after migrate (Phase 3 D-42 path).
- Migration script documentation in `README.md` + `CHANGELOG.md` 4.0.0 entry — Phase 6 DOCS-01..04.
- `sp_equivalent:` / `gsd_equivalent:` explicit fields in manifest — D-71 defers these to a conditional escape hatch; only added if plan-phase research surfaces a basename mismatch.
- Release validation matrix smoke-tests for migration — Phase 7 VALIDATE-01..04.
- Pre-migrate backup rotation policy — out of scope (BACKUP-01/02 v4.1).
- Telemetry / migration analytics — not a toolkit concern; never on the roadmap.

</deferred>

---

*Phase: 05-migration*
*Context gathered: 2026-04-18*
