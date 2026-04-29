---
phase: 28-bridge-foundation
verified: 2026-04-29T20:30:00Z
status: passed
score: 5/5
overrides_applied: 0
re_verification: false
gaps: []
human_verification: []
---

# Phase 28: Bridge Foundation — Verification Report

**Phase Goal:** Toolkit detects Gemini CLI and OpenAI Codex CLI presence, and ships a
`bridges.sh` library that produces a plain-copy bridge file (`GEMINI.md` / `AGENTS.md`)
with a canonical auto-generated header and registers each bridge in
`~/.claude/toolkit-install.json` with both source-SHA256 and bridge-SHA256.

**Verified:** 2026-04-29T20:30:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1 | `is_gemini_installed` / `is_codex_installed` return 0/1 binary, fail-soft when CLI absent | VERIFIED | `bash -c 'source detect2.sh; is_gemini_installed; echo "gem=$?"'` → `gem=0`. `bash -c 'source detect2.sh; is_codex_installed; echo "cod=$?"'` → `cod=0`. S1 in smoke test confirms no stderr. Probe bodies use `command -v <cli> >/dev/null 2>&1` (lines 47, 54 of detect2.sh). |
| SC2 | `bridge_create_project gemini` writes `GEMINI.md` with byte-identical header + verbatim content; re-run yields same content | VERIFIED | S2 in smoke test: `GEMINI.md` exists, `head -1` == `<!--`, verbatim source content present. S5 confirms SHA256 unchanged on re-run. Banner is single `cat <<'BANNER'` heredoc at bridges.sh line 91 — byte-identical by construction. |
| SC3 | `bridge_create_global codex` writes `~/.codex/AGENTS.md` (creates dir if missing); never modifies `~/.claude/CLAUDE.md` | VERIFIED | Manual sandbox test: `bridge_create_global codex` with `TK_BRIDGE_HOME` override → `exit=0`, `agents_exists=y`, `first_line=<!--`, `CLAUDE.md` untouched. `_bridge_global_dir` maps `codex → $home/.codex` (line 77). `bridge_create_global` uses `${home}/.claude/CLAUDE.md` as source only (line 232). |
| SC4 | After bridge creation, `toolkit-install.json` has `bridges[]` entry with all required fields | VERIFIED | S4 smoke test validates full schema: `target`, `scope`, `path` ending in `/GEMINI.md`, `source_sha256` 64-hex, `bridge_sha256` 64-hex, `user_owned=false`. Python inline block in `_bridge_write_state_entry` (bridges.sh lines 130-181) writes atomically via `tempfile.mkstemp + os.replace`. |
| SC5 | New detection probes coexist with existing 6 v4.6 binary probes; `test-install-tui.sh` PASS=43 unchanged | VERIFIED | `bash scripts/tests/test-install-tui.sh` → `test-install-tui complete: PASS=43 FAIL=0`. `bash scripts/tests/test-bootstrap.sh` → `Bootstrap test complete: PASS=26 FAIL=0`. |

**Score:** 5/5 truths verified

---

### Deferred Items

None. All items in scope for Phase 28 were delivered.

Items explicitly deferred to later phases (from REQUIREMENTS.md):

| Item | Addressed In |
|------|-------------|
| BRIDGE-SYNC-01/02/03 (update-claude.sh sync + --break-bridge) | Phase 29 |
| BRIDGE-UN-01/02 (uninstall integration) | Phase 29 |
| BRIDGE-UX-01/02/03/04 (install TUI + prompts + flags) | Phase 30 |
| BRIDGE-DIST-01/02, BRIDGE-TEST-01, BRIDGE-DOCS-01/02 (distribution + tests + docs) | Phase 31 |
| `manifest.json` update to register `scripts/lib/bridges.sh` in `files.libs[]` | Phase 31 (BRIDGE-DIST-01) |

---

### REQ-ID Coverage

| REQ-ID | Description | Status | Evidence |
|--------|-------------|--------|----------|
| BRIDGE-DET-01 | `is_gemini_installed` — `command -v gemini` returns 0/1, fail-soft | COVERED | detect2.sh line 53-55; smoke test S1 |
| BRIDGE-DET-02 | `is_codex_installed` — `command -v codex`, same semantics | COVERED | detect2.sh line 46-48; smoke test S1 |
| BRIDGE-DET-03 | Both probes in `detect2.sh` alongside existing 6; `detect2_cache` populates IS_COD/IS_GEM | COVERED | detect2.sh lines 100-109; test-install-tui PASS=43 |
| BRIDGE-GEN-01 | `bridge_create_project <target>` writes `GEMINI.md` or `AGENTS.md`; idempotent | COVERED | bridges.sh lines 191-217; smoke tests S2, S3, S5 |
| BRIDGE-GEN-02 | `bridge_create_global <target>` writes under `~/.gemini/` or `~/.codex/`; never touches source | COVERED | bridges.sh lines 223-249; manual sandbox test; `mkdir -p` at `_bridge_write_file` line 89 |
| BRIDGE-GEN-03 | Banner byte-identical across all bridges; at top, separated by one blank line | COVERED | Single `cat <<'BANNER'` heredoc in `_bridge_write_file` (bridges.sh lines 91-97); `echo ""` at line 98; smoke test S2/S3 verify `head -1 == <!--` |
| BRIDGE-GEN-04 | `bridges[]` entry with all required fields + de-dup + atomic write + `user_owned: false` | COVERED | `_bridge_write_state_entry` (bridges.sh lines 113-186); Python inline block de-dups by `(target, scope, path)` triple; smoke test S4 (schema validation) + S5 (dedup: count stays at 1) |

**All 7 Phase 28 REQ-IDs: COVERED**

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/lib/detect2.sh` | Exists, contains `is_gemini_installed` + `is_codex_installed` + IS_COD/IS_GEM in detect2_cache | VERIFIED | 110 lines; commit 66a5b95 |
| `scripts/lib/bridges.sh` | New library, ~249 lines, all public + helper functions implemented | VERIFIED | Exactly 249 lines; commit 67581c1 |
| `scripts/tests/test-bridges-foundation.sh` | 5-scenario smoke test, PASS=5 FAIL=0 | VERIFIED | 270 lines; commit 06fdb16; PASS=5 FAIL=0 confirmed |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `detect2.sh:is_codex_installed` | `command -v codex` | single-line probe body | WIRED | Line 47: `command -v codex >/dev/null 2>&1` |
| `detect2.sh:is_gemini_installed` | `command -v gemini` | single-line probe body | WIRED | Line 54: `command -v gemini >/dev/null 2>&1` |
| `detect2_cache` | `is_codex_installed` + `is_gemini_installed` | `IS_COD=0; is_codex_installed && IS_COD=1 || true` | WIRED | Lines 107-109; export includes `IS_COD IS_GEM` |
| `bridges.sh:_bridge_write_file` | banner heredoc | `cat <<'BANNER'` single-quoted | WIRED | Lines 91-97; single-quoted delimiter prevents variable expansion |
| `bridges.sh:bridge_create_project` | `_bridge_write_state_entry` | called after file write, SHA computed post-write | WIRED | Lines 210-214; Pitfall 4 (redirect closed before hash) correctly handled |
| `bridges.sh:_bridge_write_state_entry` | `acquire_lock` / `release_lock` from `state.sh` | sourced at top of bridges.sh | WIRED | state.sh sourced line 45; acquire_lock at line 124, release_lock at line 183 |
| `bridges.sh:_bridge_write_state_entry` | `toolkit-install.json` atomic update | `python3` inline + `tempfile.mkstemp + os.replace` | WIRED | Lines 130-181; de-dup by `(target, scope, path)` triple |
| `bridges.sh:TK_BRIDGE_HOME` | global write target + state file + lock dir | `${TK_BRIDGE_HOME:-$HOME}` via `_bridge_home()` | WIRED | Lines 55, 117-122; smoke test S2-S5 exercise this seam |

---

### Data-Flow Trace (Level 4)

Bridge generation writes files; it is not a component rendering dynamic data from a store.
Data flows verified via direct function invocation in the smoke test:

| Step | Source | Transform | Destination | Verified |
|------|--------|-----------|-------------|---------|
| Source read | `<project>/CLAUDE.md` | verbatim copy | `GEMINI.md` / `AGENTS.md` | S2, S3, S5 — grep finds source text in bridge file |
| SHA computation | `sha256_file(source)` | after `_bridge_write_file` returns | `source_sha256` in bridges[] | S4 — 64-hex validated |
| SHA computation | `sha256_file(target_path)` | after write | `bridge_sha256` in bridges[] | S4 — 64-hex validated |
| State update | new bridges[] entry | atomic python3 tempfile patch | `toolkit-install.json` | S4 full schema check; S5 count stays at 1 on re-run |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Detection probes return binary 0/1, no stderr | `bash scripts/tests/test-bridges-foundation.sh` (S1) | PASS=1 for S1 | PASS |
| `bridge_create_project gemini` writes GEMINI.md with banner | S2 smoke test | PASS | PASS |
| `bridge_create_project codex` writes AGENTS.md (not CODEX.md) | S3 smoke test | PASS | PASS |
| bridges[] schema correct | S4 smoke test (Python schema validator) | PASS | PASS |
| Idempotent re-run + sandbox isolation | S5 smoke test | PASS | PASS |
| Full suite | `bash scripts/tests/test-bridges-foundation.sh` | PASS=5 FAIL=0 | PASS |
| BACKCOMPAT: test-bootstrap | `bash scripts/tests/test-bootstrap.sh` | PASS=26 FAIL=0 | PASS |
| BACKCOMPAT: test-install-tui | `bash scripts/tests/test-install-tui.sh` | PASS=43 FAIL=0 | PASS |
| shellcheck (all 3 files) | `shellcheck -S warning bridges.sh detect2.sh test-bridges-foundation.sh` | exit 0 | PASS |
| No set -euo pipefail in sourced libs | `grep -c "set -euo pipefail" bridges.sh detect2.sh` | 0 + 0 | PASS |
| No Bash 4+ patterns | `grep -nE 'declare -A\|declare -n\|read -N\|mapfile' ...` | CLEAN | PASS |
| `bridge_create_global gemini` (manual sandbox) | `TK_BRIDGE_HOME=$sandbox bridge_create_global gemini` | exit=0, file_exists=y, first_line=`<!--` | PASS |
| `bridge_create_global codex` (manual sandbox) | `TK_BRIDGE_HOME=$sandbox bridge_create_global codex` | exit=0, AGENTS.md=y, CLAUDE.md untouched | PASS |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | No TODO/FIXME/placeholder/stub patterns found |

Scanned `scripts/lib/bridges.sh`, `scripts/lib/detect2.sh`,
`scripts/tests/test-bridges-foundation.sh` for:

- `TODO|FIXME|XXX|HACK|PLACEHOLDER` — none
- `placeholder|not yet implemented` — none
- `return null|return \{\}|return \[\]` — none (Bash, not JS)
- `set -euo pipefail` in sourced libs — absent (correct)
- Bash 4+ forbidden patterns — clean

---

### Human Verification Required

None. All must-haves are verified programmatically. `bridge_create_global` was
verified via a hermetic sandbox invocation rather than a canned smoke test scenario
(S1-S5 test only `bridge_create_project`); the function logic is symmetric and the
manual test confirmed correct behavior.

---

### Gaps Summary

No gaps. All 5 ROADMAP success criteria are verified. All 7 Phase 28 REQ-IDs are
covered. Three artifacts exist, are substantive, and are wired. All behavioral
spot-checks pass. Backcompat baselines (PASS=26 and PASS=43) are unchanged.

---

## VERIFICATION PASSED

All Phase 28 deliverables confirmed:

1. `scripts/lib/detect2.sh` extended with `is_codex_installed` + `is_gemini_installed`
   in alphabetical position; `detect2_cache` exports `IS_COD` and `IS_GEM`.
2. `scripts/lib/bridges.sh` (249 lines) ships `bridge_create_project` +
   `bridge_create_global` with byte-identical banner, atomic state registration,
   TK_BRIDGE_HOME test seam, and Bash 3.2 compatibility.
3. `scripts/tests/test-bridges-foundation.sh` (270 lines) exercises 5 scenarios
   (detection, project gemini, project codex, schema, idempotency + isolation)
   with PASS=5 FAIL=0.
4. All three backcompat suites pass at their pre-Phase-28 baselines.
5. shellcheck warning-level clean on all three Phase 28 files.

---

_Verified: 2026-04-29T20:30:00Z_
_Verifier: Claude (gsd-verifier)_
