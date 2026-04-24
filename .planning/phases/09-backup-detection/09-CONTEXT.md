# Phase 9: Backup & Detection - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning
**Mode:** `--auto` (all gray areas selected; recommended defaults applied)

<domain>
## Phase Boundary

Phase 9 ships two operator-ergonomics upgrades layered on the existing v4.0
install infrastructure. No install-mode changes, no breaking changes. Four
scoped deliverables split across two themes:

### Theme A — Backup hygiene (BACKUP-01, BACKUP-02)

1. **BACKUP-01 — `--clean-backups` flag.** `scripts/update-claude.sh
   --clean-backups` lists every backup dir under `~/` matching the toolkit's
   actual naming patterns, prints size + age per dir, prompts `[y/N]`, and
   removes on confirm. `--keep N` preserves N most recent.
2. **BACKUP-02 — threshold warning.** Every script that creates a new backup
   dir checks total backup count and prints a non-fatal one-line warning when
   count > 10, pointing users to `update-claude.sh --clean-backups`.

### Theme B — Detection enhancements (DETECT-06, DETECT-07)

3. **DETECT-06 — `claude plugin list` cross-check.** `scripts/detect.sh`
   parses `claude plugin list --json` when the CLI is available. For
   superpowers: if filesystem says present but CLI reports disabled, CLI wins.
   Filesystem remains primary whenever CLI absent or errors. GSD is NOT a
   Claude Code plugin (never appears in `claude plugin list`) — DETECT-06
   applies to SP only; GSD detection unchanged.
4. **DETECT-07 — version-skew warning.** `update-claude.sh` compares the SP /
   GSD versions captured in `~/.claude/toolkit-install.json` at last install
   against current detection. If either version differs, emit a one-line
   `⚠ Base plugin version changed: superpowers 5.0.7 → 5.1.0 — review install
   matrix` warning. Non-fatal.

**In scope:** backup cleanup CLI + threshold warning, `claude plugin list`
integration as CLI cross-check, SP/GSD version-skew detection inside
`update-claude.sh`.

**Out of scope:** Upstream GSD CLI issues (Phase 10), chezmoi-grade styled
`--dry-run` output (Phase 11), relocating existing backup dirs, auto-cleanup
without user confirmation, version-skew warning on `init-claude.sh`.

</domain>

<decisions>
## Implementation Decisions

### BACKUP-01 — `--clean-backups` flag

- **D-01:** Backup dir discovery patterns = **two sibling-of-`.claude`
  patterns the code actually creates today**:
  - `~/.claude-backup-<epoch>-<pid>` (from `update-claude.sh:457`)
  - `~/.claude-backup-pre-migrate-<epoch>` (from `migrate-to-complement.sh:270`)

  REQUIREMENTS.md phrases the target as `~/.claude/.toolkit-backup-*` — that
  path is never produced by any script. Rather than relocate existing user
  backups (risky, irreversible), Phase 9 aligns spec language to code reality:
  the `--clean-backups` implementation scans both real patterns, and Plan 9.x
  patches REQUIREMENTS.md + any docs that reference the phantom
  `.toolkit-backup-*` name.

- **D-02:** `--keep N` sort order = **descending by the epoch suffix in the
  directory name**, not `stat -c %Y` or `stat -f %m`. The dir names already
  carry monotonic UTC timestamps (`date -u +%s`), so parsing the name is:
  (a) stable across macOS BSD / GNU, (b) cheap (no stat syscall per dir),
  (c) immune to filesystem mtime tampering. `N` most recent by parsed epoch
  are preserved; the rest fall into the cleanup prompt queue. Dirs whose
  names don't match either pattern are silently ignored (never auto-removed).

- **D-03:** Confirmation flow = **per-dir `[y/N]` prompt**. Matches the
  `migrate-to-complement.sh` UX precedent (per-file confirmation + full
  backup) documented in PROJECT.md Key Decisions. Batch-list-then-confirm is
  rejected — higher blast radius for a miskey. Reads stdin via `< /dev/tty`
  when attached so `curl | bash` stays safe (mirrors the `setup-council.sh`
  gotcha already logged in `.planning/codebase/CONCERNS.md`).

- **D-04:** Per-dir prompt shows three facts:
  1. Directory name (`~/.claude-backup-1713974400-12345`)
  2. Size from `du -sh` (human-readable)
  3. Age from epoch diff (`2 days ago` / `5 hours ago`), computed from the
     parsed timestamp, not `stat`. Format: `14d 3h`, `5h 12m`, `<1m`.

- **D-05:** `--dry-run` composition — `--clean-backups --dry-run` prints the
  list with sizes + ages and the `[would remove]` / `[would keep]` tag per
  dir, runs zero prompts, deletes nothing. Exits 0. This is a new flag
  combination in v4.1; no existing behavior inherits `--dry-run` semantics
  for cleanup.

- **D-06:** Exit codes:
  - 0 = no backup dirs found OR user approved/declined every prompt cleanly
  - 1 = `find` / `rm` failure mid-cleanup (partial state reported)
  - 2 = `--keep` value negative or non-numeric (argument error)

- **D-07:** Empty-set behavior = print one line `No toolkit backup
  directories found under $HOME.` and exit 0. No error, no prompt.

### BACKUP-02 — threshold warning

- **D-08:** Threshold count scope = **combined across both patterns**
  (`.claude-backup-*` + `.claude-backup-pre-migrate-*`). One number, matching
  how the user perceives accumulated backups. Separating by pattern would
  leak internal naming.

- **D-09:** Threshold value = **> 10**, per REQUIREMENTS.md BACKUP-02. Kept
  as a magic number (not a config flag) in v4.1 to avoid scope creep. If
  future phases need tunability, promote to a `$TK_BACKUP_WARN_THRESHOLD`
  env var (deferred).

- **D-10:** Emission surface = **centralized helper `warn_if_too_many_backups()`
  in `scripts/lib/backup.sh` (NEW)**, sourced by every script that creates a
  backup dir: `update-claude.sh`, `migrate-to-complement.sh`, and
  `setup-security.sh` (if / when the Phase 6 safe-merge path produces a
  backup sibling). Centralization avoids drift between 3 copy-pasted warnings.

  Rationale for new lib file vs extending `scripts/lib/install.sh`: the
  install lib is 300+ lines of mode-recommendation / skip-list logic.
  Backup housekeeping is a clean orthogonal concern. Keeps blame readable.

- **D-11:** Warning text = **single line, non-fatal, colored `YELLOW ⚠`**,
  matching existing `log_warning()` style:
  ```
  ⚠ 12 toolkit backup dirs under $HOME — run `update-claude.sh --clean-backups` to prune
  ```
  Emitted AFTER the backup dir is successfully created, so the script's
  primary mission isn't blocked by the warning path. Exit status of the
  creating script is unaffected.

- **D-12:** Count implementation = single `find "$HOME" -maxdepth 1 -type d
  \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) |
  wc -l`. `-maxdepth 1` prevents scanning deep user trees. Works on macOS
  BSD `find` and GNU `find` identically.

### DETECT-06 — `claude plugin list` cross-check

- **D-13:** Scope = **superpowers only**. Confirmed via live CLI probe:
  `claude plugin list --json` emits entries with `id`, `version`, `enabled`,
  `installPath` fields. SP appears as
  `id: "superpowers@claude-plugins-official"`. GSD does NOT appear — it is
  not a Claude Code plugin, it's a standalone CLI in `~/.claude/get-shit-done/`.
  DETECT-06 therefore augments `detect_superpowers()` only;
  `detect_gsd()` stays filesystem-only and this fact gets one comment line
  in `detect.sh` explaining why.

- **D-14:** CLI detection location = **extend `detect_superpowers()` in
  `scripts/detect.sh`**, not a new sibling function. The existing function
  already has a 3-step FS + settings.json chain (lines 32–77); CLI check
  becomes step 4 inserted AFTER the settings.json enabled check, BEFORE the
  final HAS_SP=true assignment.

- **D-15:** CLI availability probe = `command -v claude &>/dev/null`. If
  absent → skip CLI path, FS result wins. No fallback message (silent).

- **D-16:** CLI parse command = `claude plugin list --json 2>/dev/null | jq
  -r '.[] | select(.id == "superpowers@claude-plugins-official") | .enabled'`.
  Expected values: `true`, `false`, or empty (plugin not registered at all).
  - `true` → CLI confirms enabled, proceed with HAS_SP=true
  - `false` → CLI says disabled, override FS → HAS_SP=false, SP_VERSION=""
  - empty → CLI doesn't know about SP, fall back to FS truth (don't override)

- **D-17:** CLI error handling:
  - `claude plugin list --json` non-zero exit → soft-fail, FS wins
  - jq parse error / non-JSON output → soft-fail, FS wins
  - Timeout: **no explicit timeout in v4.1**. CLI call is already fast
    (<200ms on live probe); adding BSD/GNU-safe timeout logic is disproportionate.
    Deferred until a real hang is reported.

- **D-18:** Version precedence when CLI available and reports enabled =
  **CLI version wins** over the `sort -V | tail -1` filesystem dir scan.
  CLI version is authoritative (what Claude Code actually loaded);
  FS version is heuristic (dir name can lag). When CLI absent, FS heuristic
  stays as today.

- **D-19:** `settings.json` check (line 57–71 today) stays as a SECOND
  independent verification path, not replaced. Order:
  1. Filesystem dir exists? (line 34)
  2. Has at least one versioned subdir? (line 43)
  3. `settings.json` doesn't disable it? (line 57)
  4. **NEW:** `claude plugin list --json` doesn't disable it? (D-16)

  Any layer returning "disabled" short-circuits to HAS_SP=false. Defense
  in depth — each signal is independently imperfect, consensus is robust.

- **D-20:** No new `CLAUDE_PLUGIN_LIST_CHECK` env var per REQUIREMENTS
  phrasing — the CLI check is automatic when `claude` is on PATH. Making
  it opt-in adds a test-seam burden with no real-world use case. Test
  harness bypass = set `HAS_SP` + `HAS_GSD` before sourcing (existing seam
  at `update-claude.sh:52`).

### DETECT-07 — version-skew warning

- **D-21:** Skew detection scope = **both SP and GSD**. State schema already
  carries `superpowers.version` and `gsd.version` in
  `~/.claude/toolkit-install.json` (per `scripts/lib/state.sh:91–92`). Both
  are compared against the current `SP_VERSION` / `GSD_VERSION` exported by
  `detect.sh`. One unified skew check, not SP-only.

- **D-22:** Emission surface = **`update-claude.sh` only**, per REQUIREMENTS
  phrasing ("On `update-claude.sh` run"). Not added to `init-claude.sh`
  (first install, no prior version to compare) or `migrate-to-complement.sh`
  (migration is a one-shot, separate concern).

- **D-23:** Emission position = **AFTER read_state + detection, BEFORE
  prompts or the 4-group summary**. Gives the user the skew signal early so
  they can abort if unexpected. One line per changed plugin:
  ```
  ⚠ Base plugin version changed: superpowers 5.0.7 → 5.1.0 — review install matrix
  ⚠ Base plugin version changed: get-shit-done 1.2.0 → 1.3.0 — review install matrix
  ```
  Emitted only when stored version is non-empty AND differs from current.
  Empty stored version (first-ever install via pre-v4.1 toolkit) → silent.

- **D-24:** Skew is **non-fatal, informational only**. No prompt, no exit.
  Update flow continues exactly as today. Mirrors the BACKUP-02 soft-warn
  pattern.

- **D-25:** No graded severity between major / minor / patch bumps — any
  version string mismatch fires the warning. Users reading semver have the
  context to weigh it; toolkit shouldn't infer.

- **D-26:** Skew check implementation = pure shell + jq against `$STATE_FILE`:
  ```bash
  stored_sp=$(jq -r '.plugins.superpowers.version // ""' "$STATE_FILE" 2>/dev/null || echo "")
  stored_gsd=$(jq -r '.plugins.gsd.version // ""' "$STATE_FILE" 2>/dev/null || echo "")
  ```
  Added as a new helper `warn_version_skew()` in `scripts/lib/install.sh`
  (already carries mode-change / detection-drift helpers — thematic fit).

### Cross-cutting

- **D-27:** New files created by this phase:
  - `scripts/lib/backup.sh` (BACKUP-02 helper lib)
  - Optionally: `scripts/tests/test-clean-backups.sh` (BACKUP-01 coverage)
  - Optionally: `scripts/tests/test-detect-cli.sh` (DETECT-06 coverage)
  No new manifest entries — these are dev-only scripts, not shipped to
  `.claude/`.

- **D-28:** Files modified:
  - `scripts/update-claude.sh` — `--clean-backups` dispatch + version-skew
    warning call
  - `scripts/detect.sh` — CLI cross-check in `detect_superpowers()`
  - `scripts/migrate-to-complement.sh` — source backup lib + threshold call
  - `scripts/setup-security.sh` — source backup lib + threshold call (if
    it creates a backup dir; verify in Plan 9.x)
  - `scripts/lib/install.sh` — `warn_version_skew()` helper added
  - `.planning/REQUIREMENTS.md` — BACKUP-01 wording fix (`.toolkit-backup-*`
    → actual code patterns)

- **D-29:** Test strategy = **bats where the Phase 8 shared lib fits**,
  bash-only otherwise:
  - BACKUP-01 `--clean-backups` behavior → new bats file
    `scripts/tests/matrix/clean-backups.bats` using `helpers.bash`
    sandboxing (14th matrix cell candidate — decide in Plan 9.x whether to
    register it in the cell-parity gate or keep it standalone).
  - DETECT-06 CLI cross-check → bash unit test stubbing `claude` on PATH.
  - DETECT-07 skew → bash unit test stubbing state.json with old versions.
  No bats for detect.sh (already covered indirectly by the 13-cell matrix).

- **D-30:** Branch naming = per-REQ pattern from Phase 8:
  `feature/backup-01-clean-backups`, `feature/backup-02-threshold-warning`,
  `feature/detect-06-cli-crosscheck`, `feature/detect-07-version-skew`.
  Each REQ → one PR. Keeps review bite-sized.

- **D-31:** Conventional Commit scopes: `feat(backup-01):`,
  `feat(backup-02):`, `feat(detect-06):`, `feat(detect-07):`.

- **D-32:** `make check` wiring — no new top-level check target in Phase 9.
  BACKUP-01 + DETECT-06 + DETECT-07 are runtime behaviors, not lints.
  Coverage comes via existing `test-init-script` / `test-matrix-bats` jobs
  picking up the new test files (D-29). Avoids bloating the 7-target check
  chain further.

### Claude's Discretion

- Exact bats vs bash test split within BACKUP-01 — Plan 9.x picks based on
  how clean the existing `helpers.bash` sandboxing fits the backup-dir
  discovery path.
- Whether `scripts/lib/backup.sh` grows a `list_backup_dirs()` helper or
  keeps listing logic inline in `update-claude.sh --clean-backups` — Claude
  picks at implementation time based on reuse across migrate / security.
- Whether the BACKUP-02 warning emits before or after the "backup created
  at X" log line — Claude decides based on visual grouping of the summary
  block; both are correct.
- Exact format of age strings (`14d 3h` vs `14d` vs `2w 3d`) — Claude picks
  a single consistent format during BACKUP-01 implementation.
- Whether to ship Plan 9.x as one multi-REQ plan or four per-REQ plans —
  Plan author decides during `/gsd-plan-phase`. Four small plans likely
  wins for review velocity; one bundle wins if files overlap heavily.

### Folded Todos

No pending todos matched Phase 9 scope in the `gsd-tools todo match-phase`
probe (none registered for `09` in current milestone state).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` §"Phase 9: Backup & Detection" — goal, depends, 4 success criteria.
- `.planning/REQUIREMENTS.md` §"Backup Hygiene" (BACKUP-01, BACKUP-02) + §"Detection Enhancements" (DETECT-06, DETECT-07) — acceptance criteria.
- `.planning/PROJECT.md` §"Constraints" — POSIX-shell invariant, macOS BSD compat, `curl | bash` no-stdin assumption; §"Key Decisions" row on `setup-security.sh` safe JSON merge precedent for per-file confirmation UX.

### Backup infrastructure (BACKUP-01 / BACKUP-02 targets)
- `scripts/update-claude.sh:451–457` — current `.claude-backup-<ts>-<pid>` dir creation (sibling of `.claude`, NOT `.claude/.toolkit-backup-*`).
- `scripts/update-claude.sh:207–246` — `print_update_summary()` pattern; skew warning (D-23) and threshold warning (D-11) follow the same log cadence.
- `scripts/migrate-to-complement.sh:268–270` — `.claude-backup-pre-migrate-<ts>` dir creation (second pattern in scope).
- `scripts/tests/test-update-summary.sh:130, 247–279, 337` — existing assertions on the `.claude-backup-<unix-ts>-<pid>` format; regression guard.
- `scripts/tests/test-migrate-flow.sh:121, 286, 406–407` + `test-migrate-diff.sh:305` + `test-migrate-idempotent.sh:97` — tests covering the pre-migrate backup pattern.
- `scripts/setup-security.sh` — candidate third site for BACKUP-02 threshold hook (verify backup sibling exists in its flow during Plan 9.x).

### Detection infrastructure (DETECT-06 / DETECT-07 targets)
- `scripts/detect.sh:27–77` — `detect_superpowers()`: FS dir check + versioned subdir + `settings.json` `.enabledPlugins["superpowers@claude-plugins-official"]` gate. DETECT-06 inserts a 4th verification layer here.
- `scripts/detect.sh:79–89` — `detect_gsd()`: filesystem-only, deliberately. D-13 documents why DETECT-06 cannot apply.
- `scripts/lib/state.sh:44–92` — `write_state()`; schema carries `plugins.superpowers.{present,version}` and `plugins.gsd.{present,version}` — source of truth DETECT-07 compares against.
- `scripts/lib/install.sh` — where `warn_version_skew()` (D-26) lands; read to identify the existing helper cadence and emission style.
- `scripts/update-claude.sh:50–67` — detect.sh sourcing + test seam at `$HAS_SP`/`$HAS_GSD`; DETECT-07 skew check plugs in after `read_state` but before the 4-group summary.

### Quality gate wiring
- `Makefile:17` — `check` target; D-32 decides NO new target this phase.
- `.github/workflows/quality.yml:37–94` — `validate-templates` + `test-init-script` jobs; D-29 test files attach here without new jobs.
- `.planning/codebase/CONCERNS.md` §`curl | bash` stdin risk — D-03 references the `< /dev/tty` precedent.

### Prior-phase contexts (pattern continuity)
- `.planning/phases/08-release-quality/08-CONTEXT.md` — most recent CONTEXT.md; pattern reference for decision density, REQ-ID wiring, per-REQ branch discipline (D-30).
- `.planning/phases/12-audit-verification-template-hardening/12-CONTEXT.md` — HARDEN-A-01 pattern for "new check target wired into `make check` + CI" (inverse reference: D-32 deliberately does NOT follow it).

### External references (Context7 targets at research time)
- `claude plugin list --json` CLI — verified live shape: array of `{id, version, scope, enabled, installPath, installedAt, lastUpdated}`. SP id = `superpowers@claude-plugins-official`; GSD absent.
- `claude` CLI `help plugin` — confirm no breaking changes in `plugin list --json` output schema before landing DETECT-06. Planner/researcher should re-probe on implementation day.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets
- **`scripts/update-claude.sh:451–457` — backup dir creation.** The exact path
  pattern BACKUP-01 must scan. Format: `$(dirname "$CLAUDE_DIR")/.claude-backup-$(date -u +%s)-$$`.
- **`scripts/migrate-to-complement.sh:268–270` — second backup pattern.**
  `.claude-backup-pre-migrate-<epoch>`. Both patterns share the sibling-of-.claude
  placement (D-01).
- **`scripts/lib/state.sh:44–92`** — state schema with `plugins.superpowers.version`
  and `plugins.gsd.version` already populated. DETECT-07 consumes these
  without schema changes.
- **`scripts/detect.sh:57–71`** — jq pattern for `enabledPlugins` gating is
  near-identical shape to the `claude plugin list --json` `.enabled`
  interrogation. Copy the defensive `command -v jq` guard.
- **`scripts/setup-council.sh` `< /dev/tty` pattern** — precedent for
  `curl | bash`-safe prompts (referenced by D-03).
- **`scripts/validate-commands.py` + `Makefile:check` wiring** — Phase 12
  HARDEN-A-01 pattern for "new lint added to check chain". D-32 consciously
  deviates (no new check target this phase — runtime behavior, not lint).
- **Phase 8 `helpers.bash` + bats harness** (`scripts/tests/matrix/lib/helpers.bash`)
  — D-29 reuses `sandbox_setup` + `assert_eq` for BACKUP-01 coverage.

### Established patterns
- **`set -euo pipefail`** top of every shell script.
- **ANSI color + `log_info|success|warning|error`** helpers; D-11 and D-23
  warnings use the existing `log_warning` tone.
- **HARD-fail for missing libs, soft-fail for detection** (update-claude.sh:54–80).
  DETECT-06 CLI path is soft-fail (D-17); DETECT-07 state read is soft-fail.
- **Env var test seams** (`HAS_SP`, `HAS_GSD`, `TK_UPDATE_HOME`, `TK_UPDATE_LIB_DIR`,
  `TK_UPDATE_MANIFEST_OVERRIDE`) — BACKUP-01 + DETECT-06 tests follow the
  same seam pattern (D-20).
- **`date -u +%s`** for timestamp generation — D-02 parses the same format.
- **Conventional Commits per-REQ branch** — D-30 / D-31.

### Integration points
- **`scripts/detect.sh:detect_superpowers()` body** — CLI cross-check insertion
  between line 71 and line 73 (post-settings.json, pre-HAS_SP=true).
- **`scripts/update-claude.sh`** — new `--clean-backups` flag in the arg parser
  (lines 14–25) plus dispatch early in main flow (before lock acquisition
  at line 451, to keep cleanup outside the tree-backup mutation).
- **`scripts/update-claude.sh`** — `warn_version_skew()` invocation after
  `read_state` (locate site in Plan 9.x) and before summary.
- **`scripts/lib/backup.sh` (NEW)** — sourced by `update-claude.sh`,
  `migrate-to-complement.sh`, optionally `setup-security.sh`.

### Creative options
- **Backup lib composition.** If D-27's `scripts/lib/backup.sh` also exports
  a `list_backup_dirs()` helper, BACKUP-01 and BACKUP-02 both consume it
  (listing vs counting are one grep away). One file, two callers, zero
  duplication.
- **Future tunability hook.** D-09 keeps threshold as a magic `10`. If Phase
  10 or v4.2 adds a `--prune-threshold N` flag, the helper already localizes
  the constant — single-line config change.
- **Unified plugin-metadata probe.** DETECT-06 parses `claude plugin list
  --json` for SP. A future phase could extend the same parse to list ALL
  active Claude Code plugins for user-facing diagnostics. D-14 localizes
  the parse in `detect.sh`, so extension is mechanical.

### Constraints surfaced during scout
- **REQUIREMENTS.md phantom path** — `~/.claude/.toolkit-backup-*` never
  appears in shipped code (0 hits in `scripts/`). Phase 9 must patch the
  spec language (D-01), not the filesystem, to avoid orphaning existing
  user backups.
- **GSD is not a Claude plugin** — `claude plugin list --json` output on
  the live machine shows SP present, GSD absent. DETECT-06 applies to SP
  only; any spec reading "SP/GSD" in DETECT-06 must be interpreted as SP
  for the CLI branch, GSD for FS-only (D-13).
- **No BSD-safe `timeout` portability** — `timeout` exists on Linux, `gtimeout`
  requires coreutils on macOS. D-17 explicitly defers timeout because (a)
  CLI is fast, (b) adding `(command) &; sleep N; kill` shim for one call
  site is disproportionate.
- **`jq` already a hard dep** — (statusline, rate-limit probe, detect.sh);
  BACKUP-01 size sort and DETECT-06 JSON parse inherit the same requirement,
  no new platform burden.
- **macOS BSD `find -maxdepth 1`** — supported on both BSD and GNU; D-12
  count expression is portable.

</code_context>

<specifics>
## Specific Ideas

- REQUIREMENTS.md BACKUP-01 wording says `~/.claude/.toolkit-backup-*`.
  Actual on-disk pattern is `~/.claude-backup-*` (sibling). D-01 aligns spec
  to code — Plan 9.x submits a single-line REQUIREMENTS.md patch alongside
  the implementation PR for traceability.

- `claude plugin list --json` `enabled` field distinguishes three states via
  presence + boolean: `{enabled: true}`, `{enabled: false}`, or entry
  missing entirely. D-16 handles all three explicitly — no conflation
  between "disabled" and "never installed".

- State schema version field in `toolkit-install.json` is `"version": 2`
  (state-schema v2, not toolkit v4.1). DETECT-07 reads `plugins.superpowers.version`
  /  `plugins.gsd.version`, not the top-level `version` key. Researcher
  should disambiguate in RESEARCH.md.

- Phase 11 will add chezmoi-grade styled output across all `--dry-run` paths,
  including the BACKUP-01 `--clean-backups --dry-run` output (D-05). Phase 9
  ships plain ASCII; Phase 11 restyles without touching semantics.

- Test 16 of the existing matrix (`scripts/tests/matrix/translation-sync.bats`
  from Phase 8) is the model for a new non-install-cell bats file. BACKUP-01
  test (D-29) follows the same out-of-mode structural shape.

- The backup cleanup command is deliberately a flag on `update-claude.sh`,
  not a standalone `clean-backups.sh`. Keeps the surface area small
  (one user-visible script for housekeeping) and matches the precedent set
  by `--prune`, `--no-banner`, `--offer-mode-switch` (arg-driven modes on
  a single entry point).

</specifics>

<deferred>
## Deferred Ideas

- **Tunable backup threshold via env/flag** — D-09 keeps magic `10`. If
  anyone files a "my threshold is different" issue post-v4.1, promote to
  `$TK_BACKUP_WARN_THRESHOLD` or `--prune-threshold N`. v4.2+ territory.

- **Explicit timeout around `claude plugin list --json`** — D-17 skips it
  because the live call is <200ms. If CI or flaky-network reports a hang,
  add a portable `(cmd &; sleep N; kill)` shim in v4.2+.

- **Auto-cleanup without confirmation** — D-03 enforces per-dir prompt.
  `--force` / `--yes` flag is explicitly NOT in v4.1 scope; destructive
  without confirm contradicts PROJECT.md "every destructive action prompts"
  invariant.

- **Backup dir relocation** to `~/.claude/.toolkit-backup-*` to match the
  REQUIREMENTS phrasing — rejected (D-01). Breaks existing user backups,
  zero operational benefit.

- **Version-skew warning on `init-claude.sh`** — D-22 scopes skew to
  `update-claude.sh`. First install has no prior version; warning is
  definitionally moot there.

- **Graded semver severity** (major bump = red, patch bump = yellow) — D-25
  rejected. Toolkit doesn't parse semver; one-line warning is enough signal.

- **`claude plugin list` extended to list ALL Claude Code plugins** for
  diagnostics — out of Phase 9 scope. Natural v4.2 follow-up if detection
  UX grows.

- **Promote `scripts/lib/backup.sh` to ship in `.claude/`** — no. Remains
  dev-only (D-27). Users don't need the housekeeping helper; they get the
  flag on `update-claude.sh`.

- **Removing bash `validate-release.sh` now that Phase 8 bats port exists**
  — Phase 8 deferred to v4.2+; mentioned here only because a Phase 9
  implementer might be tempted while refactoring `scripts/lib/`. Don't.

- **Reviewed Todos (not folded):** none — no pending todos matched this
  phase's scope.

</deferred>

---

*Phase: 09-backup-detection*
*Context gathered: 2026-04-24*
