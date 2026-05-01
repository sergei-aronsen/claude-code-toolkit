---
quick_task: 260501-lrq
slug: fix-critical-install-bugs-in-scripts-ini
branch: fix/install-bugs-v4.8.1
status: complete
completed: 2026-05-01
commits: 7
files_modified:
  - scripts/init-claude.sh
  - scripts/lib/dispatch.sh
  - scripts/install.sh
  - scripts/lib/tui.sh
  - scripts/tests/test-install-tui.sh
  - README.md
files_created:
  - scripts/tests/test-init-download-fallback.sh
requirements_closed:
  - BUG-01-MANIFEST-PATH
  - BUG-02-SKILLS-MARKETPLACE-SKIP
  - BUG-03-DETECT2-SOURCING
  - BUG-04-COUNCIL-PROMPT-VISIBILITY
  - BUG-05-FAILURE-BANNER
  - REDESIGN-06-README-INSTALL-URL
  - REDESIGN-07-DISPATCH-COUNCIL
  - REDESIGN-08-TUI-COUNCIL-ROW
  - REDESIGN-09-TUI-RENDER-UPGRADE
  - TEST-10-TUI-RENDER-ASSERTIONS
  - TEST-11-DOWNLOAD-FALLBACK-SCENARIOS
---

# Quick Task 260501-lrq Summary

**One-liner:** Fixed five critical install-time bugs in scripts/init-claude.sh AND
redesigned install.sh's TUI to integrate Supreme Council as a first-class component,
with hermetic regression tests for both the download-fallback path and the new render
contract.

---

## Commits (7 total, in execution order)

| # | SHA | Subject |
|---|-----|---------|
| 1 | `24e623a` | fix(install): manifest path fallback, skills_marketplace skip, detect2 sourcing, council UX, failure banner |
| 2 | `7d2859d` | feat(dispatch): add dispatch_council() + 'council' entry in TK_DISPATCH_ORDER |
| 3 | `89d949b` | feat(install): add Council TUI row + dispatch path |
| 4 | `84f2197` | feat(tui): numbered rows + per-row inline descriptions + new footer |
| 5 | `6828220` | docs(readme): make install.sh the primary install URL; demote init-claude.sh |
| 6 | `c271e8b` | test(install): assert numbered TUI rows + per-row descriptions + new footer |
| 7 | `81ba552` | test(install): hermetic download fallback test (B1 + B2 verification) |

---

## Verification

```text
=== make check ===
make check: PASS (exit 0)

=== test-install-tui.sh ===
test-install-tui complete: PASS=51 FAIL=0

=== test-init-download-fallback.sh ===
PASS=8 FAIL=0

=== Commit count ===
7 (matches plan target)

=== Plan-required greps ===
grep -c skills_marketplace scripts/init-claude.sh        → 2  (jq filter + comment)
grep -c lib/detect2.sh    scripts/init-claude.sh         → 2  (download + error msg)
grep -c dispatch_council  scripts/lib/dispatch.sh        → 3  (header + comment + def)
grep -c council           scripts/install.sh             → 3+ (TUI row + dispatch case + IS_COUNCIL)
TK_DISPATCH_ORDER=                                       → "...statusline council gemini-bridge codex-bridge)"
grep -c "Enter to select" scripts/lib/tui.sh             → 2  (color + no-color)
```

---

## What Shipped per Task

### Task 1 (`24e623a`) — Five surgical bug fixes in `scripts/init-claude.sh`

- **B1 manifest path resolution.** `download_files()` now does framework-first → base-fallback (mirrors `download_extras` pattern at line ~534-545). Two-attempt curl with `[[ -s "$full_dest" ]]` zero-byte guard. The `scripts` and `libs` buckets keep their repo-root paths (special-cased via `case "$bucket"`). Failures increment `FAILED_COUNT` and append to `FAILED_PATHS`.
- **B2 skills_marketplace skip.** Filtered out at the jq stage via `select($b != "skills_marketplace")`. Comment block above the jq invocation explains why (entries are directories, not files — handled by `install.sh --skills` via `cp -R`).
- **B3 lib/detect2.sh source ordering.** New download-and-source block inserted after `lib/state.sh` and before `lib/bridges.sh`. Includes a `sed`-based patch that comments out `detect2.sh`'s internal `source ../detect.sh` line because that line resolves to `/detect.sh` when run from `/tmp` (under `set -e` it would abort the install). `detect.sh` is already loaded earlier in the same shell, so the inner re-source is unnecessary.
- **B4 visible Council prompt.** Three-line BLUE separator banner inserted before `read -r -p "Configure Supreme Council now?"`, separating the install spam from the actionable prompt.
- **B5 failure-aware closing banner.** New `FAILED_COUNT` / `FAILED_PATHS` globals declared at file scope (line 45-46). Closing banner branches: yellow ⚠ banner with failed-file list when `FAILED_COUNT > 0`, green ✅ otherwise. Includes a hint to retry with `TK_TOOLKIT_REF=<tag>`.

### Task 2a (`7d2859d`) — `dispatch_council()` + `TK_DISPATCH_ORDER` extension

- Added `dispatch_council()` at end of `scripts/lib/dispatch.sh`, mirroring `dispatch_security()` verbatim (`--force`/`--dry-run`/`--yes` parsing, `TK_DISPATCH_OVERRIDE_COUNCIL` test seam under `TK_TEST=1`, `_dispatch_is_curl_pipe` routing to `setup-council.sh`).
- `TK_DISPATCH_ORDER` updated: `(superpowers gsd toolkit security rtk statusline council gemini-bridge codex-bridge)` — council inserted between statusline and the two bridges.
- Header doc-block updated to list `dispatch_council`.

### Task 2b (`89d949b`) — TUI council row + dispatch wiring in `scripts/install.sh`

- After the existing `TUI_DESCS` block, added council to all four TUI parallel arrays: `TUI_LABELS+=("council")`, `TUI_GROUPS+=("Optional")`, `TUI_INSTALLED+=("$IS_COUNCIL")`, `TUI_DESCS+=("Multi-AI plan review …")`.
- `IS_COUNCIL` probe is a single `[[ -f "$HOME/.claude/council/brain.py" ]]` check (per the established convention that non-trivial probes live in `detect2.sh` while one-stat checks stay inline).
- Re-probe loop case statement gets a `council)` branch using the same inline `-f brain.py` check.
- The `dispatch_${local_name}` expansion at line ~969 resolves to `dispatch_council` automatically — no further plumbing needed.

### Task 2c (`84f2197`) — `_tui_render` upgrade in `scripts/lib/tui.sh`

- Rewrote `_tui_render()` to emit numbered rows (format: two-space indent + `N. [box] label`, 1-indexed), per-row dimmed descriptions inline under every row (was previously focus-only at the screen bottom), bolded section headers with extra blank-line separation, and a new footer text: `Enter to select · ↑↓ navigate · Space toggle · Esc cancel`.
- Preserved every invariant: `TK_TUI_TTY_SRC` test seam, `_TUI_COLOR` gating, FOCUS_IDX arrow indicator, group transitions, Bash 3.2 portability (no associative arrays / namerefs / float reads).

### Task 3a (`6828220`) — README install URL switch

- `### Standalone install` heading renamed to `### Interactive install (recommended)` with the install URL switched from `init-claude.sh` to `install.sh`. Description updated to mention the TUI checklist + all components (Toolkit, Security, RTK, Statusline, Council, Bridges).
- `### Complement install` block updated to use `install.sh` URL with `--yes --mode complement-full`.
- New `### Direct install (scripted / CI)` section preserves backwards compatibility — `init-claude.sh` documented as the no-prompt fallback for non-interactive contexts.
- Markdownlint clean (MD040/MD031/MD032/MD026 all satisfied).

### Task 3b (`c271e8b`) — Extended `test-install-tui.sh` (+ tui.sh redirection bug fix)

- New `run_s_render_format` scenario asserts numbered prefix on rows 1+2, per-row descriptions inline, "Enter to select" footer present, "Esc cancel" footer mentioned, and old footer text absent.
- **Rule 1 bug fix discovered during test writing:** every `printf > "$tty_target"` in `_tui_render`, `_tui_enter_raw`, and `_tui_restore` was using truncate-redirect. Under real `/dev/tty` the truncate-vs-append distinction is invisible (both open the char device for write); under `TK_TUI_TTY_SRC=<regular file>` only the LAST printf survived — making the render contract impossible to assert. Converted all 10 `>` to `>>`. Behavior on `/dev/tty` is unchanged; behavior under file redirection now correctly accumulates output.
- Updated `S3_yes` to expect 7 components (council added in this milestone) and supplied `TK_DISPATCH_OVERRIDE_COUNCIL` mock so the new dispatcher is mocked identically to the other six.

### Task 3c (`81ba552`) — Hermetic `test-init-download-fallback.sh`

- New 179-line test file using `python3 -m http.server` to spin up a synthetic repo tree fixture.
- Four scenarios in one pass: S1 framework-first wins; S2 base-fallback succeeds when framework path missing; S3 both-missing produces no zero-byte file and increments FAILED_COUNT; S4 `skills_marketplace` bucket is filtered at the jq stage (proven via file-absence check + manifest fixture sanity check).
- Mirrors `assert_*` helpers + sandbox/EXIT-trap pattern from `test-install-tui.sh`. PASS=8 FAIL=0.

---

## Deviations from Plan

### Auto-fixed issues (Rule 1 bugs)

**1. `_tui_render` printf-truncate redirection bug (discovered in Task 3b)**

- **Found during:** Writing the `S_render_format` scenario in `test-install-tui.sh`.
- **Issue:** Every `printf > "$tty_target"` in `tui.sh` truncates the output file. Under `/dev/tty` (a char device) both `>` and `>>` open the device for writing identically — no observable difference. Under `TK_TUI_TTY_SRC=<regular file>` (the test seam) only the LAST printf's content survives, making it impossible for any test to assert what the renderer emitted.
- **Fix:** Converted all 10 `>` to `>>` in `_tui_render` + `_tui_enter_raw` + `_tui_restore`. Confirmed test passes (51/51 assertions). Folded into Task 3b commit `c271e8b` since it was a prerequisite for the test to run.
- **Files modified:** `scripts/lib/tui.sh`
- **Commit:** `c271e8b` (Task 3b)

**2. `S3_yes` test expectation updated for 7-component world**

- **Found during:** Verification after Task 2b/2c (running existing test-install-tui.sh).
- **Issue:** `S3_yes` hard-coded `Installed: 6` and provided 6 dispatcher mocks. Adding `council` as the 7th component caused the test to fail because (a) the assertion no longer matched, and (b) `dispatch_council` would attempt to invoke real `setup-council.sh` without a mock.
- **Fix:** Added `MOCK_COUNCIL` mock + `TK_DISPATCH_OVERRIDE_COUNCIL` env var + new "council dispatcher invoked" assertion + bumped expected count to 7. Folded into Task 3b commit `c271e8b`.
- **Files modified:** `scripts/tests/test-install-tui.sh`
- **Commit:** `c271e8b` (Task 3b)

### Plan-acknowledged contingencies handled

**B3 detect2.sh sourcing — inner `source ../detect.sh` patch**

The plan flagged this as a contingency: "If detect2.sh fails its internal `source ../detect.sh` because it's running from /tmp, guard by skipping the inner source when HAS_SP is already defined." Solution chosen: `sed` out the inner source line on the downloaded copy before sourcing it. `detect.sh` is already loaded into the current shell from line 169 of `init-claude.sh`, so the strip-and-source approach guarantees correctness without modifying the upstream `detect2.sh`.

### No deviations elsewhere

Plan otherwise executed exactly as written. No architectural changes (Rule 4) needed. No authentication gates encountered. No CLAUDE.md-driven adjustments needed (project conventions and security rules were honored throughout).

---

## Bash 3.2 / Shellcheck / Markdownlint Findings

- **Shellcheck (warning level):** All four shell-script files (`init-claude.sh`, `lib/dispatch.sh`, `lib/tui.sh`, `install.sh`) plus the new test pass `shellcheck -S warning` clean. One initial SC2034 in the new test (unused `bucket` variable) was fixed by removing the assignment with an explanatory comment.
- **Markdownlint:** README.md after edits passes `npx markdownlint-cli` clean (no MD040/MD031/MD032/MD026 violations).
- **Bash 3.2:** All shell edits use only Bash 3.2-compatible syntax — no associative arrays, no namerefs, no float `read -t`, no `mapfile`, no `${var,,}` lowercasing. The new `case "$bucket"` block in `init-claude.sh` and the inline `[[ -f ... ]]` checks in `install.sh` follow established project patterns.

## Threat Flags

None. The five fixes (B1-B5) reduce surface (no false success banner, no broken bridges due to missing helpers, visible Council prompt) and the `dispatch_council` addition mirrors the well-vetted `dispatch_security` shape (TK_TEST gate on env override, fail-closed on unknown flags, browser User-Agent on every curl).

## Self-Check: PASSED

- `scripts/init-claude.sh` — modified, contains all five fixes (verified via grep) — FOUND
- `scripts/lib/dispatch.sh` — modified, contains `dispatch_council` + updated `TK_DISPATCH_ORDER` — FOUND
- `scripts/install.sh` — modified, contains `IS_COUNCIL` probe + TUI row + dispatch case — FOUND
- `scripts/lib/tui.sh` — modified, contains numbered prefix + per-row descriptions + new footer + `>>` redirections — FOUND
- `scripts/tests/test-install-tui.sh` — modified, contains `run_s_render_format` + updated `S3_yes` — FOUND
- `scripts/tests/test-init-download-fallback.sh` — created, executable, exits 0 — FOUND
- `README.md` — modified, install.sh promoted to primary URL — FOUND
- 7 commits on `fix/install-bugs-v4.8.1` (24e623a..81ba552) — FOUND
- All 7 commit SHAs verified present in `git log --oneline` — FOUND
