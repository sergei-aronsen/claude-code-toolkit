# Phase 23: Installer Symmetry & Recovery - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning
**Mode:** `--auto --chain` (Claude auto-selected recommended defaults)

<domain>
## Phase Boundary

Two narrow polish gaps closed against shipped v4.3 / v4.4-in-progress behaviour:

1. **`--no-banner` symmetry** — `scripts/init-claude.sh` and `scripts/init-local.sh` learn the same `--no-banner` flag (and `NO_BANNER=1` env var) that `scripts/update-claude.sh` already honours. When set, the closing `To remove: bash <(curl …)` line is suppressed. Default (unset) reproduces v4.3 behaviour byte-for-byte.

2. **`--keep-state` partial-uninstall recovery** — `scripts/uninstall.sh` learns `--keep-state` (and `TK_UNINSTALL_KEEP_STATE=1` env var). When set, `~/.claude/toolkit-install.json` is preserved as the LAST step instead of deleted. A subsequent `uninstall.sh` run (with or without the flag) sees the state file, re-classifies still-present modified files, and re-presents the `[y/N/d]` prompt — i.e. is NOT a no-op.

Out of scope: bootstrap (Phase 21), lib registration (Phase 22), uninstall semantics rework, new state schema fields, banner copy redesign, selective uninstall.

</domain>

<decisions>
## Implementation Decisions

### BANNER-01 — `--no-banner` for `init-claude.sh` / `init-local.sh`

- **D-01 (BANNER-01):** Inline the existing `update-claude.sh` pattern verbatim into both installers. Concretely: `NO_BANNER=0` near the top of the script (next to other CLI defaults), `--no-banner) NO_BANNER=1; shift ;;` clause in the argparse `case` block, and an `if [[ $NO_BANNER -eq 0 ]]; then echo "To remove: …"; fi` gate around the existing banner echo. NO new shared library. Rationale: pattern is 4 lines per installer; `update-claude.sh:11,24,1009-1010` is the canonical reference; YAGNI on `scripts/lib/banner.sh` for a single literal string. Keeps the diff surgical and matches the project's "smallest viable change" preference (see PROJECT.md Key Decisions table — surgical-changes component cherry-picked from Karpathy plugin).

- **D-02 (BANNER-01):** Banner string is unchanged and remains byte-identical across all three installers (`init-claude.sh:930`, `init-local.sh:475`, `update-claude.sh:1010`). The single literal `To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)` is the contract surface enforced by `scripts/tests/test-install-banner.sh` (UN-07 D-09). Phase 23 must NOT alter the string — only its conditional emission.

- **D-03 (BANNER-01):** Argparse insertion site mirrors existing flag placement. In `init-claude.sh`, the new clause sits in the same `case $1 in … esac` block alongside `--dry-run`, `--no-council`, `--no-bootstrap`, `--mode`, `--force`, `--force-mode-change`. In `init-local.sh`, same shape — drop the clause next to its existing `--dry-run` / equivalent. Both installers MUST list `--no-banner` in their `--help` output and in their unknown-arg error string (the `Flags: …` line) for surface parity with `update-claude.sh`.

- **D-04 (BANNER-01):** `NO_BANNER=1` env var support comes for free via the standard pattern `NO_BANNER=${NO_BANNER:-0}` — but Phase 23 follows the literal `update-claude.sh:11` form (`NO_BANNER=0`) to keep behaviour byte-identical. Env-var precedence: explicit `NO_BANNER=1 init-claude.sh` exports the value into the script's environment, which the script reads via `${NO_BANNER:-0}` semantics if we adopt the env form, OR the script defaults to 0 and the user passes `--no-banner` to flip. We adopt the **flag-only** semantics in the argparse loop and let env-injection work via the shell-standard `NO_BANNER=1 bash init-claude.sh` form (caller exports, script reads default-zero variable). This is exactly what `update-claude.sh` does today — no special env parsing in the script body.

  **Net behavior:** `init-claude.sh --no-banner`, `init-local.sh --no-banner`, `NO_BANNER=1 init-claude.sh`, and `NO_BANNER=1 init-local.sh` all suppress the banner. `init-claude.sh` (no flag, no env) prints it. Symmetric with `update-claude.sh`.

- **D-05 (BANNER-01):** Test extension strategy — extend the existing `scripts/tests/test-install-banner.sh` with new source-grep assertions; do NOT create a new test file. The existing test already runs in milliseconds (no /tmp churn, no network) and shares the locked `BANNER=` constant. Adding 4 new assertions (NO_BANNER variable presence + `--no-banner` clause + gated echo, in each of the two installers) keeps the test count flat (one test file → 7 assertions instead of 3) and makes the contract change auditable in one place. Mirrors Phase 22 D-04 hermetic-test discipline.

  Concrete new assertions:
  - **A4:** `init-claude.sh` defines `NO_BANNER=0` (default zero, source-grep `^NO_BANNER=0`).
  - **A5:** `init-claude.sh` argparse contains `--no-banner) NO_BANNER=1` clause.
  - **A6:** `init-claude.sh` banner echo is gated by `if [[ \$NO_BANNER -eq 0 ]]`.
  - **A7:** Same three assertions for `init-local.sh` (A7a/A7b/A7c, OR a single combined assertion that all three patterns are present in `init-local.sh`).

  Total: existing 3 + new 4 = **7 assertions** in `test-install-banner.sh`. Test name unchanged.

- **D-06 (BANNER-01):** Help text wording — `--no-banner    suppress closing "To remove: …" banner` — matches the docstring style already used in `init-claude.sh:--help` for other flags. If `init-local.sh` lacks a `--help` block today, Phase 23 does NOT add one (out of scope — that is Phase 23.1 polish). Document only in the `Flags: …` error line.

### KEEP-01 — `--keep-state` for `scripts/uninstall.sh`

- **D-07 (KEEP-01):** Gate the existing `rm -f "$STATE_FILE"` call at `scripts/uninstall.sh:653` behind a `KEEP_STATE` boolean. When `KEEP_STATE=1`, replace the `rm` with a `log_info "State file preserved (--keep-state): $STATE_FILE"` line and skip the unlink entirely. Preserves the D-06 ordering invariant (state-delete is the LAST mutating step) — the gate sits at the same byte offset, just chooses between "delete" and "log + skip". No reordering of backup, snapshot, sentinel-strip, or base-plugin diff steps. UN-05 D-06 contract stays intact.

- **D-08 (KEEP-01):** Argparse — add `--keep-state) KEEP_STATE=1; shift ;;` to the existing `case` block in `uninstall.sh`. Default `KEEP_STATE=0`. Mirrors the `--dry-run) DRY_RUN=true; shift ;;` clause already present (UN-02 lineage). Help text: `--keep-state   preserve toolkit-install.json after run (recovery for partial-N uninstalls)`.

- **D-09 (KEEP-01):** Env var support — `TK_UNINSTALL_KEEP_STATE=1` flips `KEEP_STATE` to 1. Resolution order: CLI flag wins if present; otherwise the env var is consulted; otherwise default (delete state). Mirrors Phase 21 D-16 (`--no-bootstrap` / `TK_NO_BOOTSTRAP=1` precedence). Concrete shell pattern: `KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}` initialized at the top, then the argparse `--keep-state` clause overrides to `1`. Test seam already exists in test infrastructure.

- **D-10 (KEEP-01):** Backup invariant — `--keep-state` does NOT change backup behaviour. Backup directory `~/.claude-backup-pre-uninstall-<unix-ts>/` is still created (UN-04), `toolkit-install.json.snapshot` is still written inside it (UN-04 D-04), sentinel block is still stripped from `~/.claude/CLAUDE.md` (UN-05), base-plugin `diff -q` invariant still fires (UN-05 D-10). The ONLY behavioural delta is: the `rm -f "$STATE_FILE"` at line 653 is replaced with a `log_info` and an early return from the cleanup block. Everything else is byte-identical.

- **D-11 (KEEP-01):** Idempotency interaction — `uninstall.sh` line 389 already has `if [[ ! -f "$STATE_FILE" ]]; then log_success "Toolkit not installed; nothing to do."; exit 0; fi`. After a `--keep-state` run, the state file IS present, so this idempotency guard does NOT fire — the script proceeds to lock acquisition, backup, classification, prompt loop, etc. (KEEP-02 contract). This is the correct behaviour: re-running uninstall after a partial-N session must re-classify still-present modified files.

- **D-12 (KEEP-01):** Banner gate (`update-claude.sh` `NO_BANNER` analogue) is OUT OF SCOPE for `uninstall.sh`. The "To remove" banner is printed by INSTALLERS pointing at `uninstall.sh`; `uninstall.sh` itself does not print it. Phase 23 BANNER-01 covers the three install scripts only.

### KEEP-02 — Hermetic test for `--keep-state`

- **D-13 (KEEP-02):** New test file `scripts/tests/test-uninstall-keep-state.sh`. Spec-literal name (matches REQUIREMENTS.md KEEP-02 verbatim and ROADMAP.md success criterion 5). Mirrors the shape of `scripts/tests/test-uninstall-idempotency.sh` (Phase 19) — sandbox `$HOME` via `TK_UNINSTALL_HOME`, file-source seam via `TK_UNINSTALL_FILE_SRC`, TTY-from-stdin seam via `TK_UNINSTALL_TTY_FROM_STDIN=1` (Phase 18 patterns).

- **D-14 (KEEP-02):** Four required assertions per spec (REQUIREMENTS.md KEEP-02 + ROADMAP.md SC 5):
  - **A1:** After `init-local.sh` install + `uninstall.sh --keep-state` run answering `N` to every modified prompt, `~/.claude/toolkit-install.json` exists on disk.
  - **A2:** A second `uninstall.sh` invocation (no `--keep-state`) is NOT a no-op — it does NOT exit at line 389. The script proceeds to backup + classification + prompt loop. Asserted via output marker (e.g. `Created backup directory:` or `Found N modified files`).
  - **A3:** The MODIFIED-files list on the second invocation is non-empty — i.e. the still-present modified files from session 1 are re-classified correctly.
  - **A4:** Base-plugin invariant (`diff -q` on sorted `find` output of superpowers + get-shit-done trees, UN-05 D-10) still passes after the second invocation, regardless of which branch the user takes for each modified file.

- **D-15 (KEEP-02):** Optional fifth assertion (recommended): **A5** asserts a third invocation with `--keep-state` again leaves the state file in place. Demonstrates idempotency of the flag itself (back-to-back keep-state runs do not corrupt state). Plan author may add or skip per scope budget.

- **D-16 (KEEP-02):** Test scenarios — minimum 2 scenarios, recommended 3:
  - **S1 (mandatory):** `init-local.sh` clean install → `uninstall.sh --keep-state` answer `N` to every `[y/N/d]` modified prompt → assert A1+A2+A3+A4 on a second `uninstall.sh` (no flag) run.
  - **S2 (mandatory):** `init-local.sh` clean install → `uninstall.sh --keep-state` answer `y` to every prompt → assert A1 only (state preserved even on full-y branch). Second invocation is a no-op-equivalent: state file present, no modified files, exit 0 cleanly.
  - **S3 (recommended):** `TK_UNINSTALL_KEEP_STATE=1 uninstall.sh` (env-only, no flag) → asserts D-09 env-var precedence path. Single A1-style assertion.

- **D-17 (KEEP-02):** CI wiring — add `bash scripts/tests/test-uninstall-keep-state.sh` to `Makefile` (Test 30) and `.github/workflows/quality.yml` `validate-templates` job step `Tests 21-29` → `Tests 21-30`. Mirrors Phase 22 D-06 wiring exactly. PHONY target `test-uninstall-keep-state` for standalone local invocation. Same shellcheck-clean discipline as the existing 29 tests.

### Distribution + Release

- **D-18 (cross-cut):** Manifest version stays at `4.4.0` — Phase 22 already bumped it. Phase 23 is feature-only on top of the same release. CHANGELOG.md `[4.4.0]` `Added` section gets three new bullets (BANNER-01 + KEEP-01 + KEEP-02), appended to the existing Phase 21 + 22 entries. Single `[4.4.0]` release entry consolidates all three v4.4 phases. `make version-align` (Makefile:225) stays green — no manifest mutation, no new version row.

- **D-19 (cross-cut):** No new `manifest.json` `files.scripts[]` or `files.libs[]` entries. `init-claude.sh` and `init-local.sh` are NOT in `files.scripts[]` (they are install entry points, not toolkit-installed files — they live in `~/.claude/` only when copied by the user, never managed by `update-claude.sh`). `uninstall.sh` IS in `files.scripts[]` (Phase 20 UN-07) and stays a single registered entry. Phase 23 modifies the file in place; smart-update will pick up the new flag handling on the next user `update-claude.sh` run via existing SHA-diff logic. Zero manifest churn.

### Claude's Discretion

- Exact log-line phrasing in D-07 (`State file preserved (--keep-state): $STATE_FILE`) — planner / executor may tune to match `log_info` cadence in `lib/install.sh` (e.g. include the leading `ℹ` glyph or not).
- Whether D-15 fifth assertion (A5) ships in Phase 23 or is deferred — planner picks based on test-suite runtime budget. Recommended: include for completeness; cost is one extra `uninstall.sh` invocation in the sandbox, milliseconds.
- Whether D-16 S3 (env-var-only scenario) ships in Phase 23 or only S1/S2 — same call. Recommended: include S3 to lock the D-09 precedence contract end-to-end.
- Order of clauses inside the `case` block (`--keep-state` before / after `--dry-run`) — alphabetical preferred, matches existing convention in `update-claude.sh`.
- Whether to update `docs/INSTALL.md` to document `--no-banner` and `--keep-state` — recommended, low-risk; planner may bundle into Plan 1 or split. PROJECT.md "Bring them up to parity" milestone goal already implies surface-level docs.
- TAB vs space in new Makefile target — TAB (Make requirement, established convention).

### Folded Todos

None — `gsd-tools todo match-phase 23` returned zero matches.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 23 spec
- `.planning/REQUIREMENTS.md` § "`--no-banner` Symmetry" — BANNER-01 acceptance criteria
- `.planning/REQUIREMENTS.md` § "`--keep-state` Partial-Uninstall Recovery" — KEEP-01, KEEP-02 acceptance criteria
- `.planning/ROADMAP.md` § "Phase 23: Installer Symmetry & Recovery" — five success criteria
- `.planning/PROJECT.md` § "Current Milestone: v4.4 Bootstrap & Polish" — `--no-banner` symmetry + `--keep-state` recovery framing

### Existing toolkit code that Phase 23 modifies
- `scripts/init-claude.sh:930` — banner echo to gate (BANNER-01)
- `scripts/init-claude.sh` argparse `case` block (around line where `--no-bootstrap` was added, Phase 21) — `--no-banner` insertion site
- `scripts/init-local.sh:475` — banner echo to gate (BANNER-01)
- `scripts/init-local.sh` argparse `case` block — `--no-banner` insertion site
- `scripts/update-claude.sh:11` — `NO_BANNER=0` default reference (D-01)
- `scripts/update-claude.sh:24` — `--no-banner) NO_BANNER=1` clause reference (D-01)
- `scripts/update-claude.sh:1009-1010` — `if [[ $NO_BANNER -eq 0 ]]; then echo "To remove: …"; fi` gate reference (D-01)
- `scripts/uninstall.sh:649-656` — `rm -f "$STATE_FILE"` block to gate (KEEP-01 D-07)
- `scripts/uninstall.sh:389` — idempotency guard whose semantics remain unchanged (KEEP-01 D-11)

### Existing patterns + precedents
- `scripts/update-claude.sh` `--no-banner` flag wiring (UN-07 D-09) — canonical pattern for D-01 / D-04
- `scripts/uninstall.sh` `--dry-run` flag wiring (UN-02) — closest argparse analog for `--keep-state`
- `scripts/uninstall.sh` `prompt_modified_for_uninstall()` — `< /dev/tty` fail-closed pattern; KEEP-02 test relies on `TK_UNINSTALL_TTY_FROM_STDIN=1` seam already used by Phase 18-20 tests
- Phase 21 D-16 (`scripts/init-claude.sh` / `init-local.sh` `--no-bootstrap` + `TK_NO_BOOTSTRAP=1`) — env/CLI precedence template for D-09
- Phase 22 D-04 (`scripts/tests/test-update-libs.sh` 5-scenario hermetic shape) — closest analog for D-13 / D-16 test architecture

### Test infrastructure
- `scripts/tests/test-install-banner.sh` — extend with 4 new assertions (D-05); existing source-grep + locked `BANNER=` constant
- `scripts/tests/test-uninstall-idempotency.sh` (Phase 19) — closest shape analog for new `test-uninstall-keep-state.sh` (D-13)
- `scripts/tests/test-uninstall.sh` (Phase 20 round-trip) — `TK_UNINSTALL_HOME` / `TK_UNINSTALL_FILE_SRC` / `TK_UNINSTALL_TTY_FROM_STDIN=1` seam reference
- `Makefile` Test 29 block — closest analog for new Test 30 wiring (D-17)
- `.github/workflows/quality.yml` `validate-templates` job step `Tests 21-29` — extend to `Tests 21-30`

### Distribution
- `manifest.json` `version: "4.4.0"` (Phase 22) — no bump in Phase 23 (D-18)
- `CHANGELOG.md` `## [4.4.0]` Added section (Phase 22 created) — append BANNER-01 + KEEP-01 + KEEP-02 bullets
- `docs/INSTALL.md` — `--no-banner` / `--keep-state` flag documentation (Claude's Discretion: include in plan)

### Prior CONTEXT
- `.planning/phases/21-sp-gsd-bootstrap-installer/21-CONTEXT.md` D-16/D-17 — env/CLI precedence + byte-quiet opt-out idiom carried into D-09
- `.planning/phases/22-smart-update-coverage-for-scripts-lib-sh/22-CONTEXT.md` D-06 — CI mirror pattern carried into D-17

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/update-claude.sh` `NO_BANNER` flag wiring (lines 11, 24, 1009-1010) — the single canonical reference for D-01. Copy verbatim into both init scripts at byte-equivalent insertion points.
- `scripts/uninstall.sh` argparse `case` block — already handles `--dry-run`; `--keep-state` slots in identically.
- `scripts/uninstall.sh` line 653 (`rm -f "$STATE_FILE"`) — single mutating site for KEEP-01. Wrap with `if [[ $KEEP_STATE -eq 0 ]]; then rm -f …; else log_info …; fi`.
- `scripts/tests/test-install-banner.sh` — already source-greps banner lines; extend with 4 new assertions reusing the existing `check_banner` / `assert_pass` / `assert_fail` helpers and the locked `BANNER=` constant.
- `scripts/tests/test-uninstall-idempotency.sh` shape — sandbox HOME, env-var seams, scenario sub-functions, PASS/FAIL counter — KEEP-02 test mirrors this layout.
- `TK_UNINSTALL_HOME`, `TK_UNINSTALL_FILE_SRC`, `TK_UNINSTALL_TTY_FROM_STDIN`, `LOCK_DIR` test seams — already wired into `uninstall.sh:125-129`. Reused as-is by D-13.

### Established Patterns

- **Banner contract:** Single literal `To remove: bash <(curl -sSL …/scripts/uninstall.sh)` line, byte-identical across the three install scripts. Phase 23 must NOT alter the string.
- **NO_BANNER conditional shape:** `if [[ $NO_BANNER -eq 0 ]]; then echo "…"; fi` (update-claude.sh:1009). Mirror in init scripts exactly.
- **State-delete LAST invariant (UN-05 D-06):** Even with `--keep-state`, the gate sits at the SAME byte offset as the existing `rm -f "$STATE_FILE"` — no reordering of backup, snapshot, sentinel-strip, base-plugin diff. Only the leaf branch changes.
- **CLI/env precedence (Phase 21 D-16):** Flag wins if present; env consulted otherwise; default applies last. Apply to KEEP-01 and BANNER-01 (env-injection works via shell-standard `VAR=1 script.sh` form for BANNER, no in-script env-parse needed).
- **Hermetic test discipline (Phase 18-22):** Sandbox `$HOME` under `/tmp`, env-var seams for I/O redirection, PASS/FAIL counter, exit non-zero on any assertion failure, shellcheck-clean.
- **CI mirror pattern (Phase 20-22):** Every new test file gets a `bash scripts/tests/test-X.sh` line in `.github/workflows/quality.yml` `validate-templates` job step name.

### Integration Points

- `scripts/init-claude.sh` — argparse + banner gate (2 inserts, ~6 lines added).
- `scripts/init-local.sh` — argparse + banner gate (2 inserts, ~6 lines added).
- `scripts/uninstall.sh` — argparse + KEEP_STATE init + state-delete gate (3 inserts, ~8 lines added).
- `scripts/tests/test-install-banner.sh` — 4 new assertions (~20 lines, reusing existing helpers).
- `scripts/tests/test-uninstall-keep-state.sh` — new file, ~150-200 lines (mirrors `test-uninstall-idempotency.sh` skeleton).
- `Makefile` — Test 30 block + PHONY target (`test-uninstall-keep-state`); rename Test 29 step name where present (purely cosmetic if running both).
- `.github/workflows/quality.yml` `Tests 21-29` step → `Tests 21-30` + appended `bash scripts/tests/test-uninstall-keep-state.sh`.
- `CHANGELOG.md` `[4.4.0]` Added section — append three bullets (BANNER-01 + KEEP-01 + KEEP-02).
- `docs/INSTALL.md` Installer Flags section — append `--no-banner`, `--keep-state` rows (recommended, planner discretion per Claude's Discretion D).

</code_context>

<specifics>
## Specific Ideas

- **Surgical-changes invariant** (PROJECT.md Key Decision, surgical-changes component): Phase 23 is the canonical small-diff phase. BANNER-01 = ~12 lines across 2 files. KEEP-01 = ~10 lines across 1 file. Every helper / abstraction adds risk to a low-risk change set. Resist the urge to factor `NO_BANNER` into a shared lib.
- **Banner string is locked** — `test-install-banner.sh` enforces it as a contract. Touching the URL or wording breaks the test on purpose. Phase 23 only adds a conditional around the existing echo.
- **`--keep-state` is a recovery flag, not a permanent state** — the user direction (per D-05 carry-over from Phase 19) is "let users re-run uninstall after a partial-N session". It is NOT a "soft uninstall" feature. Default behaviour (delete state LAST) stays the recommended path.
- **Test naming follows the spec literally** — `test-install-banner.sh` (extended, not renamed) and `test-uninstall-keep-state.sh` (new). Both names appear verbatim in REQUIREMENTS.md acceptance criteria; downstream verifiers grep for them.
- **No `migrate-to-complement.sh` change** — `--no-banner` is for INSTALL paths; migrate already does its own banner-less output via a different code path. Out of scope.

</specifics>

<deferred>
## Deferred Ideas

- **`--no-banner` for `uninstall.sh`** — `uninstall.sh` currently does NOT print the "To remove" banner (it IS the remove tool). If a future ask emerges to suppress its post-uninstall summary, that is a new flag (`--quiet` or `--summary-only`), not a `--no-banner`. Defer to v4.5+ if user demand surfaces.
- **`--keep-state` env-only invocation in production scripts** — D-09 supports `TK_UNINSTALL_KEEP_STATE=1`, but no installed tooling is expected to set it. Reserved for test seams + advanced users. Document as recovery option only, not a recommended default.
- **State-file format migration on `--keep-state` re-runs** — if `~/.claude/toolkit-install.json` schema bumps in v4.5+, a `--keep-state` re-run could see an old-schema file. Out of scope for Phase 23; covered by existing `synthesize_v3_state()` lineage in `update-claude.sh:256-269` (which Phase 22 already exercises).
- **Help-block bootstrap for `init-local.sh`** — D-06 explicitly defers a `--help` block to a future polish phase. Phase 23 limits docs to the `Flags: …` error string + `docs/INSTALL.md`.
- **`--no-banner` for `setup-security.sh` / `install-statusline.sh`** — those scripts do not currently print the "To remove" banner. Out of scope.

</deferred>

---

*Phase: 23-installer-symmetry-recovery*
*Context gathered: 2026-04-27 (auto-selected via --auto --chain)*
</content>
</invoke>