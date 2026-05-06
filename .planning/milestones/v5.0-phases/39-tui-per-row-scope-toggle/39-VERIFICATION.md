---
phase: 39-tui-per-row-scope-toggle
verified: 2026-05-05T20:30:00Z
status: passed
score: 14/14 must-haves verified
overrides_applied: 0
---

# Phase 39: TUI Per-Row Scope Toggle Verification Report

**Phase Goal:** Each MCP row in the integrations TUI carries its own `[U]/[P]/[L]` scope indicator immediately after the checkbox; per-row hotkey (`Tab`) cycles a single row's scope; global `s` keypress repurposed as "set ALL rows to scope X"; per-row state held in a Bash 3.2 `MCP_SELECTED_SCOPE[]` parallel array seeded from `default_scope`; dispatcher exports `TK_MCP_SCOPE` per-row before each `mcp_wizard_run` invocation.

**Verified:** 2026-05-05T20:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| #   | Truth (ROADMAP SC) | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Each MCP row renders `[U]`/`[P]`/`[L]` indicator after checkbox; active scope green under TTY+color; plain bracket form under `NO_COLOR` | VERIFIED | `mcp.sh:1336-1340` injects `${_scope_glyph} ` prefix into `TUI_LABELS`; `_mcp_render_scope_glyph` (mcp.sh:1179) wraps active bracket in `\033[0;32m`; `_c_scope_active` resolver (mcp.sh:1284) gates color on `[ -t 1 ] && [ -z "${NO_COLOR+x}" ]`. Runtime smoke confirms 20 rows all carry one of `[U]/[P]/[L]`. |
| 2 | Per-row hotkey cycles only highlighted row's scope (`U → P → L → U`); other rows unaffected; binding documented in TUI footer | VERIFIED | `mcp_cycle_row_scope` (mcp.sh:1111) mutates only `MCP_SELECTED_SCOPE[$_idx]`; tui.sh:439-466 dispatches `$'\t'` to `TUI_ROW_FN`; tui.sh:283-284 emits `· Tab row-scope` footer when `TUI_ROW_KEY`/`TUI_ROW_FN` set. Smoke: 3-cycle returns to start; sibling preserved byte-identical. |
| 3 | Global `s` cycles a global scope and assigns to every row in one stroke; banner reads `s: set all to <scope>` | VERIFIED | `mcp_toggle_scope` (mcp.sh:1014-1051) cycles `_MCP_SETALL_SCOPE` user→project→local→user, then `for ((_j=0; _j<_len; _j++)) MCP_SELECTED_SCOPE[$_j]="$_MCP_SETALL_SCOPE"`. Banner via `mcp_render_scope_header` (mcp.sh:982-1003) reads `Set all to: [U|P|L] · press s to cycle`. Phase 37 banner string `Scope: ◉` count = 0. Smoke: uniformity invariant = 1; `TUI_HEADER_TEXT` contains `Set all to:` after toggle. |
| 4 | Bash 3.2 `MCP_SELECTED_SCOPE[]` parallel array initialized from `default_scope` via `mcp_status_array`; no associative arrays | VERIFIED | `mcp.sh:1249` resets `MCP_SELECTED_SCOPE=()`; `mcp.sh:1339` pushes `MCP_SELECTED_SCOPE+=("$_row_scope")` inside `seen_idx` loop adjacent to `TUI_LABELS+=`. Runtime: `${#MCP_SELECTED_SCOPE[@]}=20` parallel to `${#TUI_LABELS[@]}=20`. Per-index value matches `MCP_DEFAULT_SCOPE[TUI_TO_MCP_IDX[j]]` for all 20 rows (verified context7=user, supabase=project, etc.). No `declare -A`, no `mapfile`, no `${var,,}` introduced. |
| 5 | install.sh dispatcher exports `TK_MCP_SCOPE` per row before `mcp_wizard_run`; `--mcp-scope` CLI flag still honored; `test-mcp-selector.sh` extended from PASS=21 with TUI-SCOPE-01..05 scenarios | VERIFIED | `install.sh:664-665` exports `TK_MCP_SCOPE="${MCP_SELECTED_SCOPE[$tui_i]:-user}"` BEFORE Phase 36-A reinstall block (line 667). CLI `--mcp-scope` preserved at line 117 (CLI parse) and line 501 (pre-loop default). Headless broadcast at install.sh:410-412 propagates `--mcp-scope` to every `MCP_SELECTED_SCOPE` slot. `test-mcp-selector.sh` runs PASS=36 (≥26 floor; +5 scenarios S9..S13). |

**Score:** 5/5 ROADMAP success criteria verified

### Plan-Level Must-Haves

| # | Plan | Truth | Status | Evidence |
| --- | --- | --- | --- | --- |
| 1 | 39-01 | Each MCP row label carries `[U]/[P]/[L]` after `[installed/checkbox]` prefix | VERIFIED | mcp.sh:1338-1339 prepends `${_scope_glyph}` before `${label}` (which already has unofficial `!` + display name). Order: `<arrow><checkbox> [U] [P] [L] !? <name>`. |
| 2 | 39-01 | `MCP_SELECTED_SCOPE[]` parallel array seeded from `MCP_DEFAULT_SCOPE` per TUI render index | VERIFIED | mcp.sh:1336-1339; runtime parallel-array invariant = 20==20; per-index value match for all rows. |
| 3 | 39-01 | Active scope glyph green (`\e[32m`) under TTY+color; plain under NO_COLOR | VERIFIED | `_c_scope_active=$'\033[0;32m'` (mcp.sh:1284-1289) gated on `[ -t 1 ] && [ -z "${NO_COLOR+x}" ]`; `_mcp_render_scope_glyph` (mcp.sh:1179-1196) wraps active bracket only. |
| 4 | 39-01 | `tui_checklist` dispatches Tab byte to `TUI_ROW_FN` with FOCUS_IDX in scope | VERIFIED | tui.sh:439-466 case-arm matches `$'\t')` BEFORE catch-all `*)` at line 467; invokes `"${TUI_ROW_FN}"`. FOCUS_IDX is dynamic-scope global. |
| 5 | 39-01 | Pressing Tab on focused row cycles only `MCP_SELECTED_SCOPE[$FOCUS_IDX]`; siblings untouched | VERIFIED | `mcp_cycle_row_scope` (mcp.sh:1111-1162) reads `_idx="${FOCUS_IDX:-0}"`, mutates only `MCP_SELECTED_SCOPE[$_idx]` and `TUI_LABELS[$_idx]`. Out-of-bounds (Submit row) returns silently. Test S10 asserts sibling preservation. |
| 6 | 39-01 | Footer hint reads `Tab row-scope · s set-all-scope` ≤80-col when both keys set | VERIFIED | tui.sh:283-284 builds `_row_hint=" · Tab row-scope"`; tui.sh:294 builds `_header_hint=" · ${TUI_HEADER_KEY} set-all-scope"`. Composed line ~95 chars including all conditional segments — fits standard 100-col. |
| 7 | 39-02 | Pressing global `s` writes next scope value into every `MCP_SELECTED_SCOPE` slot in one stroke | VERIFIED | mcp.sh:1014-1051 cycle + for-loop write. Smoke: pre-seeded `(user, local, project)` → all slots equal to `_MCP_SETALL_SCOPE` after one call. |
| 8 | 39-02 | Banner reads `Set all to: <U\|P\|L> · press s to cycle` (D-11) | VERIFIED | mcp.sh:996-1000: color form `\e[1mSet all to:\e[0m \e[1;32m${_glyph}\e[0m  \e[2m· press s to cycle\e[0m`; plain form `Set all to: ${_glyph}  · press s to cycle`. |
| 9 | 39-02 | Global cycle is `user → project → local → user` matching per-row Tab cycle | VERIFIED | mcp.sh:1017-1022 case block. Identical cycle order in `mcp_cycle_row_scope` (mcp.sh:1126-1131). |
| 10 | 39-02 | `install.sh` dispatcher exports `TK_MCP_SCOPE` per iteration BEFORE `mcp_wizard_run` | VERIFIED | install.sh:664-665 export inside dispatch loop; positioned at line 664 (BEFORE Phase 36-A reinstall block at line 667 and BEFORE wizard call). Single-writer invariant: `mcp_toggle_scope` does NOT export `TK_MCP_SCOPE` (verified — 0 matches inside function body). |
| 11 | 39-02 | Pre-loop `TK_MCP_SCOPE` export preserved for CLI `--mcp-scope`; overwritten per-iteration in TUI dispatcher | VERIFIED | install.sh:501 preserves `TK_MCP_SCOPE="${TK_MCP_SCOPE:-user}"; export`. install.sh:117 sets from `--mcp-scope` arg. install.sh:410-412 propagates to `MCP_SELECTED_SCOPE[]` slots in headless paths so per-row read at line 664 reflects CLI flag. |
| 12 | 39-02 | CLI-only rows do NOT trigger `TK_MCP_SCOPE` export; index parity ensures dispatcher never reads off the end of `MCP_SELECTED_SCOPE` | VERIFIED | Push site at mcp.sh:1339 is INSIDE `seen_idx` MCP loop — CLI-only entries never enter `MCP_NAMES` and so never push. Index parity invariant preserved (Plan 01). install.sh:664 fallback `${MCP_SELECTED_SCOPE[$tui_i]:-user}` is defensive only. |
| 13 | 39-03 | `test-mcp-selector.sh` PASS count grows from 21 (or 23 post-Plan-01) to ≥26 with 5 new TUI-SCOPE assertions | VERIFIED | Runtime: `Result: PASS=36 FAIL=0` (above ≥26 floor). 5 new run_s9..s13 functions defined and invoked. |
| 14 | 39-03 | Hermetic invariants D-21 met: `mktemp -d`, trap RETURN, no $HOME mutation, double-run safe, no new env-var seams (D-22) | VERIFIED | Each new fn uses `SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"` + `trap "rm -rf '${SANDBOX:?}'" RETURN`. S13 wraps install.sh in `HOME=$SANDBOX`. Double-run produces identical PASS counts (per Plan 03 SUMMARY). `grep -cE "TK_TUI_PHASE_39\|TK_MCP_SETALL\|TK_MCP_TEST_" scripts/tests/test-mcp-selector.sh` = 0 — no new seams. |

**Score:** 14/14 plan-level must-haves verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/lib/mcp.sh` | MCP_SELECTED_SCOPE[] population in mcp_status_array, scope-glyph injection, mcp_cycle_row_scope, mcp_toggle_scope (3-state set-all), mcp_render_scope_header banner copy | VERIFIED | All present: `MCP_SELECTED_SCOPE` (28 refs), `_MCP_SETALL_SCOPE` (12 refs), `mcp_cycle_row_scope` defined at line 1111, `_mcp_render_scope_glyph` at line 1179, `_c_scope_active` color resolver at 1284-1289, `Set all to:` (4 refs), `press s to cycle` (3 refs), `\033[0;32m` (multiple refs); `Scope: ◉` (Phase 37 retired) = 0 refs |
| `scripts/lib/tui.sh` | Tab hotkey dispatcher via `TUI_ROW_KEY` + `TUI_ROW_FN` globals + footer hint extension | VERIFIED | `TUI_ROW_KEY` 4 refs, `TUI_ROW_FN` 4 refs, `$'\t')` arm at line 439 BEFORE `*)` at line 467, `Tab row-scope` 1 ref (footer), `set-all-scope` 1 ref (header copy) |
| `scripts/install.sh` | TUI launch wiring (TUI_ROW_KEY/FN bindings + unset on cancel/success), per-row TK_MCP_SCOPE export from MCP_SELECTED_SCOPE in dispatch loop | VERIFIED | install.sh:528 `TUI_ROW_KEY=$'\t'`, install.sh:530 `TUI_ROW_FN="mcp_cycle_row_scope"`, both included in `unset` lists at lines 533, 538. Per-row export at line 664 (single occurrence), positioned BEFORE reinstall block at line 667. Pre-loop TK_MCP_SCOPE preserved at line 501 for CLI flag. Headless broadcast at lines 410-412 covers `--yes` + `--mcp-scope` paths. |
| `scripts/tests/test-mcp-selector.sh` | ≥5 new assertions (TUI-SCOPE-01..05) extending PASS=21 baseline; scope-trace.log capture for TUI-SCOPE-05 | VERIFIED | 5 new run_s9..s13 functions defined (lines 418, 468, 521, 568, 610) + 5 invocations (lines 700-704). 10 references to `TUI-SCOPE-0[1-5]` (5 fn-doc + 5 echo). 3 `scope-trace` references in S13. PASS=36 ≥26 floor. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `mcp_status_array` seen_idx loop | `MCP_SELECTED_SCOPE[]` | `MCP_SELECTED_SCOPE+=("$_row_scope")` at mcp.sh:1339 | WIRED | Adjacent to `TUI_LABELS+=` push (mcp.sh:1340-ish). Index parity invariant preserved. |
| `mcp_status_array` seen_idx loop | `TUI_LABELS` scope glyph injection | `label="${_scope_glyph} ${label}"` at mcp.sh:1338 | WIRED | Glyph prefix injected before `TUI_LABELS+=` push. Verified runtime: 20/20 rows carry bracket glyph. |
| `tui_checklist` case-match | `mcp_cycle_row_scope` (caller-supplied via `TUI_ROW_FN`) | `$'\t')` arm dispatch with `FOCUS_IDX` in dynamic scope | WIRED | tui.sh:439-466. install.sh:530 binds `TUI_ROW_FN="mcp_cycle_row_scope"` at TUI launch. |
| `_tui_render` footer | `Tab row-scope` hint string | `_row_hint` builder gated on `TUI_ROW_KEY`+`TUI_ROW_FN` | WIRED | tui.sh:283-284, composed into `_frame` at line 296/298 (color/plain branches). |
| tui.sh case-match catch-all (TUI_HEADER_FN dispatch) | `mcp_toggle_scope` (repurposed) | `TUI_HEADER_KEY=s` wired by install.sh | WIRED | install.sh:514 `TUI_HEADER_KEY="s"`, install.sh:516 `TUI_HEADER_FN="mcp_toggle_scope"`. tui.sh:467-481 `*)` arm dispatches via `TUI_HEADER_FN`. |
| `mcp_toggle_scope` (repurposed) | for-loop write to every `MCP_SELECTED_SCOPE` slot | module-local `_MCP_SETALL_SCOPE` cycles user/project/local | WIRED | mcp.sh:1034-1037 `for ((_j=0; _j<_len; _j++)) MCP_SELECTED_SCOPE[$_j]="$_MCP_SETALL_SCOPE"`. |
| `install.sh` dispatch loop | `mcp_wizard_run` via per-iteration `TK_MCP_SCOPE` export | `TK_MCP_SCOPE="${MCP_SELECTED_SCOPE[$tui_i]:-user}"; export` at install.sh:664-665 | WIRED | Position: BEFORE Phase 36-A reinstall block (line 667) AND BEFORE wizard call inside subshell — drives both paths. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `TUI_LABELS` (rendered glyph) | `_row_scope` | `MCP_DEFAULT_SCOPE[$i]` from `mcp_catalog_load` reading catalog `default_scope` field | Yes — runtime shows 20 distinct values from JSON catalog (3 user + 17 project mix verified) | FLOWING |
| `MCP_SELECTED_SCOPE[]` | `_row_scope` | Same source as above; pushed in lockstep with `TUI_LABELS` | Yes — runtime parity 20==20 with values matching `MCP_DEFAULT_SCOPE[TUI_TO_MCP_IDX[j]]` | FLOWING |
| `TUI_HEADER_TEXT` (banner) | `_MCP_SETALL_SCOPE` | Module-local file-scope init (mcp.sh:62), seeded by install.sh:507 from `TK_MCP_SCOPE`, mutated by `mcp_toggle_scope` cycle | Yes — smoke verified `Set all to:` substring present after toggle; bracket follows scope state | FLOWING |
| `TK_MCP_SCOPE` (env to wizard) | `MCP_SELECTED_SCOPE[$tui_i]` | Per-iteration read in dispatch loop (install.sh:664) from array populated by `mcp_status_array` and mutated by Tab/`s` | Yes — Phase 38 verification confirms wizard reads env fresh per call; install.sh single-writer invariant in TUI hot path | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Parallel-array invariant after catalog load | `bash -c 'source scripts/lib/mcp.sh; mcp_catalog_load; mcp_status_array; echo $((${#TUI_LABELS[@]}==${#MCP_SELECTED_SCOPE[@]}))'` | `1` (20==20) | PASS |
| `mcp_cycle_row_scope` 3-cycle returns to start | source + FOCUS_IDX=0 + 3 calls | start=user → after1=project → after3=user | PASS |
| `mcp_cycle_row_scope` siblings preserved | sibling fingerprint before/after | byte-identical | PASS |
| `mcp_toggle_scope` uniformity invariant | pre-seed mixed; toggle; check all slots equal `_MCP_SETALL_SCOPE` | uniformity=1 | PASS |
| `mcp_toggle_scope` banner update | check `TUI_HEADER_TEXT` contains `Set all to:` | YES | PASS |
| `mcp_toggle_scope` does NOT export `TK_MCP_SCOPE` (D-18) | `awk '/^mcp_toggle_scope.*\{/,/^\}/' \| grep -c "export TK_MCP_SCOPE"` | 0 | PASS |
| Phase 37 banner copy retired | `grep -c "Scope: ◉" scripts/lib/mcp.sh` | 0 | PASS |
| `test-mcp-selector.sh` baseline + extension | full run | PASS=36 FAIL=0 | PASS |
| `test-mcp-wizard.sh` baseline | full run | PASS=53 FAIL=0 | PASS |
| `test-mcp-secrets.sh` baseline | full run | PASS=11 FAIL=0 | PASS |
| `test-project-secrets.sh` baseline | full run | PASS=42 FAIL=0 | PASS |
| `make shellcheck` | full run | exit 0, "ShellCheck passed" | PASS |
| `bash -n scripts/lib/mcp.sh` | syntax check | exit 0 | PASS |
| `bash -n scripts/lib/tui.sh` | syntax check | exit 0 | PASS |
| `bash -n scripts/install.sh` | syntax check | exit 0 | PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TUI-SCOPE-01 | 39-01 | Per-row `[U]/[P]/[L]` glyph with green active under color, plain under NO_COLOR | SATISFIED | `_mcp_render_scope_glyph` + `_c_scope_active` resolver; runtime smoke confirms 20/20 rows carry glyph; test S9 asserts context7=`[U]`, supabase=`[P]` |
| TUI-SCOPE-02 | 39-01, 39-02 | Per-row hotkey cycles only highlighted row's scope U→P→L→U; binding documented in footer | SATISFIED | `mcp_cycle_row_scope` + Tab dispatch arm; footer hint `Tab row-scope`; test S10 asserts single-row mutation + 3-cycle invariant |
| TUI-SCOPE-03 | 39-02 | Global `s` cycles + writes every row in one stroke; banner reads `Set all to: <bracket> · press s to cycle` | SATISFIED | `mcp_toggle_scope` 3-state set-all; `mcp_render_scope_header` updated copy; test S11 asserts uniformity + banner |
| TUI-SCOPE-04 | 39-01 | Bash 3.2 `MCP_SELECTED_SCOPE[]` parallel array initialized from `default_scope`; no associative arrays / mapfile / `${var,,}` | SATISFIED | mcp.sh:1339 push inside seen_idx loop; runtime parity 20==20; per-index match for all rows; no banned constructs introduced; test S12 asserts parity + per-index match |
| TUI-SCOPE-05 | 39-02 | Dispatcher reads `MCP_SELECTED_SCOPE[$i]` per row and exports `TK_MCP_SCOPE` per `mcp_wizard_run` invocation; `--mcp-scope` CLI flag honored as non-interactive force-set | SATISFIED | install.sh:664 single-writer per-row export; CLI `--mcp-scope` preserved at install.sh:117 + headless broadcast at install.sh:410-412; test S13 asserts dispatcher iterates context7+supabase rows end-to-end |
| TEST-04 | 39-03 | Extend `test-mcp-selector.sh` (PASS=21 baseline) with 5 scenarios for TUI-SCOPE-01..05 | SATISFIED | 5 new run_s9..s13 functions added; PASS=36 (>=26 floor); hermetic D-21 invariants met; D-22 zero new seams verified |

**No orphaned requirements.** ROADMAP maps TUI-SCOPE-01..05 + TEST-04 to Phase 39; all are claimed by 39-01..03 plans and verified satisfied.

### Anti-Patterns Found

No anti-patterns found in modified files.

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| _none_ | _none_ | _none_ | _none_ | _none_ |

`grep -nE "TODO\|FIXME\|XXX\|HACK\|PLACEHOLDER" scripts/lib/mcp.sh scripts/lib/tui.sh scripts/install.sh scripts/tests/test-mcp-selector.sh` returned only mktemp template literals (e.g., `"${cfg}.XXXXXX"`, `"/tmp/detect-XXXXXX"`) which are legitimate `mktemp` placeholders, not stub markers.

### Human Verification Required

None. All success criteria are verifiable programmatically through unit/integration tests and behavioral smoke checks. The TUI rendering path is exercised end-to-end through:

- Test S9 (per-row indicator render correctness against catalog `default_scope`)
- Test S10 (Tab single-row mutation + sibling preservation)
- Test S11 (set-all uniformity + banner update)
- Test S12 (parallel-array parity + per-index value match)
- Test S13 (end-to-end dispatcher invocation via mock claude with `TK_MCP_PRE_SELECTED`)

The visual color/NO_COLOR rendering is asserted at the ANSI-byte level by inspecting the literal escape sequences emitted into `TUI_LABELS` / `TUI_HEADER_TEXT` — no human-eye review required for correctness, though a manual smoke run remains valuable as a final quality check (not blocking).

### Gaps Summary

No gaps. All 5 ROADMAP success criteria, all 14 plan-level must-haves, all 6 requirements (TUI-SCOPE-01..05 + TEST-04), all key links, and all behavioral spot-checks pass.

The phase achieved its goal: per-row scope routing through the integrations TUI is end-to-end functional. A user can launch `scripts/install.sh --mcps`, see each MCP row's default scope as a green-highlighted bracket among `[U] [P] [L]`, press `Tab` to flip a single row's scope, press `s` to set-all in one stroke, and each `mcp_wizard_run` invocation receives the row-correct `TK_MCP_SCOPE`. The Phase 38 wizard contract (`TK_MCP_SCOPE=project` → `.env`, `TK_MCP_SCOPE=user|local` → `mcp-config.env`) flows unchanged. Three iterations of code review + fix loop closed all 7 findings (HIGH-01, HIGH-02, MED-01, MED-02, MED-03, LOW-03, INFO-02) before this verification ran. Baselines green:

- `make shellcheck` → ShellCheck passed
- `test-mcp-selector.sh` → PASS=36 FAIL=0 (≥26 floor; baseline was 21, then 23 after Plan 01)
- `test-mcp-wizard.sh` → PASS=53 FAIL=0
- `test-mcp-secrets.sh` → PASS=11 FAIL=0
- `test-project-secrets.sh` → PASS=42 FAIL=0

Phase 39 is ready for milestone v5.0 completion (Phase 41 distribution + docs).

---

_Verified: 2026-05-05T20:30:00Z_
_Verifier: Claude (gsd-verifier)_
