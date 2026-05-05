---
phase: 37-project-secrets-library
verified: 2026-05-04T00:00:00Z
status: passed
score: 18/18 must-haves verified
must_haves_total: 18
must_haves_passed: 18
requirements_total: 7
requirements_passed: 7
overrides_applied: 0
---

# Phase 37: Project Secrets Library — Verification Report

**Phase Goal:** Ship a new `scripts/lib/project-secrets.sh` library that owns the project-scope secrets boundary end-to-end (writes `KEY=value` to `<project>/.env` mode 0600 with idempotent merge + collision prompt, guarantees `.env` is in `<project>/.gitignore`, renders `${VAR}` substitution form for `.mcp.json` env blocks, refuses any literal secret in `.mcp.json` env blocks, rejects shell-metacharacter values) together with hermetic test suite ≥18 assertions. Library is scope-agnostic.

**Verified:** 2026-05-04
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### ROADMAP Success Criteria (5 truths from gsd-tools)

| # | Success Criterion | Status | Evidence |
|---|------------------|--------|----------|
| 1 | Sourcing exposes callable functions and produces zero filesystem side effects | VERIFIED | Smoke test in `/tmp/phase37-spot.XXXXXX`: `ls -1A` returns 0 files after `source`; 4 public + 2 private functions present in `declare -F` |
| 2 | `write_env` creates `.env` mode 0600 with literal `KEY=value`; collision prompts `[y/N]` (Y replaces, N preserves) | VERIFIED | T1, T2, T3 (mode 0600 BSD+GNU dual-stat), T4 (N preserves), T5 (Y overwrites), T6 (mode 0600 after rewrite) — all 6 PASS |
| 3 | `ensure_gitignore` appends `.env\n` with leading comment; no-op when present; rejects `*.env` and `# .env`; creates if missing | VERIFIED | T13 (creates), T14+T14b (line + comment), T15 (idempotent — exactly one `.env` line), T16 (`*.env` false-negative), T17 (`# .env` false-negative) — all 5 PASS |
| 4 | Refusal of literal `.mcp.json` env values; rc=1 with exact stderr phrase; `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` works and warns | VERIFIED | T21 (literal rc=1), T21b (`refusing to write literal value into .mcp.json` exact phrase), T23 (bypass rc=0), T23b (`test seam only` warning) — all 4 PASS |
| 5 | Test suite ≥18 hermetic assertions covering all SEC-01..06 surfaces | VERIFIED | `=== Results: 42 passed, 0 failed ===` (well above 18 floor); hermetic via `mktemp -d /tmp/project-secrets.XXXXXX`; double-run-safe (RUN1+RUN2 both rc=0) |

### Observable Truths (PLAN frontmatter merged with ROADMAP)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Sourcing produces zero filesystem side effects (function definitions only) | VERIFIED | Smoke test: 0 files in `mktemp -d` after source |
| 2 | After sourcing, four functions exist (write_env, ensure_gitignore, render, validate) | VERIFIED | `declare -F` shows 4 `project_secrets_*` + 2 `_project_secrets_*` helpers |
| 3 | `write_env <root> KEY value` creates `<root>/.env` mode 0600 with literal `KEY=value` | VERIFIED | T1, T2, T3 PASS |
| 4 | Collision prompts via `TK_MCP_TTY_SRC` and fail-closes N | VERIFIED | T4 (N preserves) + lib code line 155 reads `${TK_MCP_TTY_SRC:-/dev/tty}`; lib falls back to `choice="N"` if `tui_tty_read` fails (line 158) |
| 5 | `ensure_gitignore` appends comment + `.env` when absent; no-op when present (exact `^.env$` match) | VERIFIED | T13–T17 all PASS; lib uses `grep -Fxq '.env'` (exact-fixed-line) |
| 6 | `render KEY1 KEY2` echoes `{"KEY1":"${KEY1}","KEY2":"${KEY2}"}` no trailing newline | VERIFIED | T18 (`{}` for empty), T19 (exact two-key form) PASS; smoke test confirms |
| 7 | `validate` returns rc=1 on literal, rc=0 on `${VAR}`, bypassed by `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` with warning | VERIFIED | T21, T21b, T22, T23, T23b all PASS |
| 8 | `write_env` rejects values with `$`, backtick, backslash, double-quote, single-quote, newline via shared `_mcp_validate_value` | VERIFIED | T7..T12 (6 distinct rc-rejections via DOLLAR/BTICK/BSLASH/DQUOTE/SQUOTE/NL keys); T7b..T11b paired stderr phrase asserts; lib uses `_mcp_validate_value` (lazy source from `mcp.sh`) |
| 9 | `test-project-secrets.sh` exists and runs via `bash` | VERIFIED | File exists 305 lines; `bash scripts/tests/test-project-secrets.sh` exits 0 |
| 10 | Test exits 0 with `=== Results: N passed, 0 failed ===` and N ≥ 18 | VERIFIED | Final line: `=== Results: 42 passed, 0 failed ===` (42 ≥ 18) |
| 11 | Test exercises 0600 mode (BSD+GNU stat dual-check) on first write AND after collision rewrite | VERIFIED | T3 (first-write) + T6 (rewrite-path) both via `mode_is_0600()` helper using `stat -f %Mp%Lp` then `stat -c %a` fallback |
| 12 | Test exercises collision N preserves AND collision Y overwrites via `TK_MCP_TTY_SRC` | VERIFIED | T4 (`<(printf 'N\n')`) + T5 (`<(printf 'y\n')`) both PASS |
| 13 | Test exercises SEC-06 metacharacter rejection (≥6 assertions for `$`, backtick, backslash, dquote, squote, newline) | VERIFIED | 6 distinct rc-rejection asserts (T7..T12) + 5 stderr-phrase asserts (T7b..T11b) = 11 metacharacter assertions; grep returns 9 metachar/reject matches |
| 14 | Test exercises gitignore append + idempotent no-op + false-negative on `*.env` + on `# .env` | VERIFIED | T13–T17 cover create, line+comment, idempotent, `*.env` false-negative, `# .env` false-negative |
| 15 | Test exercises render: empty→`{}` (no \n), two keys→exact form, invalid key→rc=1 | VERIFIED | T18, T19, T20 all PASS |
| 16 | Test exercises validate: literal→rc=1+stderr, `${VAR}`→rc=0, `TK_PROJECT_SECRETS_ALLOW_LITERAL=1`→rc=0+warning | VERIFIED | T21, T21b, T22, T23, T23b all PASS |
| 17 | `make test` runs the new test row and passes | VERIFIED | `make test-project-secrets` exits 0 with 42/0 result |
| 18 | CI quality.yml orphan-triage step invokes `test-project-secrets.sh` and step name range updated | VERIFIED | Line 146 reads `Tests 35-49 — orphan triage + Phase 37 project secrets library …`; line 157 invokes `bash scripts/tests/test-project-secrets.sh`; YAML parses cleanly via `python3 yaml.safe_load` |

**Score:** 18/18 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/lib/project-secrets.sh` | 4 public functions + 2 private helpers, source-safe, no errexit at top, ≥250 lines | VERIFIED | Exists, 316 lines; `set -e/-u` absent at top; `command -v _mcp_validate_value` lazy guard present; all 4 public function definitions present; shellcheck `-S warning` clean |
| `scripts/tests/test-project-secrets.sh` | ≥18-assertion hermetic test, 0 failures, double-run-safe | VERIFIED | Exists, 305 lines; `mktemp -d /tmp/project-secrets.XXXXXX` present; `trap 'rm -rf "$SANDBOX"' EXIT INT TERM` (LOW-02 bonus fix); 42 PASS / 0 FAIL; double-run safe (RUN1 + RUN2 both rc=0) |
| `Makefile` | Test 49 row + standalone target + .PHONY entry | VERIFIED | Line 1 `.PHONY:` includes `test-project-secrets`; line 227 has `Test 49: project secrets library (Phase 37 / SEC-01..06, TEST-01)`; line 273 has standalone `test-project-secrets:` target; total 49 test rows (was 48, +1 new) |
| `.github/workflows/quality.yml` | CI step name range bumped + invocation in run block | VERIFIED | Line 146 step name updated to `Tests 35-49 — orphan triage + Phase 37 …`; line 157 invokes `bash scripts/tests/test-project-secrets.sh`; YAML structurally valid |
| `manifest.json` | `files.libs[]` entry alpha-ordered between `optional-plugins.sh` and `skills.sh` | VERIFIED | Line 266 `{"path": "scripts/lib/project-secrets.sh"}` between `optional-plugins.sh` (l.263) and `skills.sh` (l.269) — correct alpha order |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `scripts/lib/project-secrets.sh` | `scripts/lib/mcp.sh::_mcp_validate_value` | lazy source guard `command -v _mcp_validate_value` | WIRED | Line 34 `if ! command -v _mcp_validate_value …`; line 38 sources `mcp.sh`; T7..T12 prove the wired call rejects all 6 metacharacters |
| `project_secrets_write_env` | `tui.sh::tui_tty_read` | transitive lazy source via `mcp.sh` | WIRED | Line 157 calls `tui_tty_read choice "[y/N] Overwrite ${key} in …" 0 "$tty_src"`; T4 (N) and T5 (Y) prove the seam works through `TK_MCP_TTY_SRC` |
| `project_secrets_validate_mcp_env_block` | stderr refusal contract | `echo … >&2` | WIRED | Line 310 emits `✗ refusing to write literal value into .mcp.json (use ${VAR} substitution)`; T21b matches phrase verbatim |
| `scripts/tests/test-project-secrets.sh` | `scripts/lib/project-secrets.sh` | source from REPO_ROOT | WIRED | Line 74: `source "${REPO_ROOT}/scripts/lib/project-secrets.sh"` |
| `Makefile` (test target) | `scripts/tests/test-project-secrets.sh` | bash invocation | WIRED | Line 228 `@bash scripts/tests/test-project-secrets.sh` (Test 49 row); line 274 standalone target |
| `.github/workflows/quality.yml` (Tests 35-49 step) | `scripts/tests/test-project-secrets.sh` | bash invocation in `run:` block | WIRED | Line 157 `bash scripts/tests/test-project-secrets.sh` |

### Data-Flow Trace (Level 4)

Library/test artifacts — no dynamic data rendering. Data flows through:

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `project_secrets_write_env` | `_PROJECT_SECRETS_KEYS[]`/`_PROJECT_SECRETS_VALUES[]` | `_project_secrets_load_env "$cfg"` reads `<root>/.env` | Yes — T2/T4/T5 prove KEY=VALUE round-trips through arrays | FLOWING |
| `project_secrets_render_mcp_env_block` | jq output | `jq -nc --args 'reduce $ARGS.positional[] …' -- "$@"` | Yes — T19 confirms exact `{"FOO":"${FOO}","BAR":"${BAR}"}` form | FLOWING |
| `project_secrets_validate_mcp_env_block` | `rendered` (jq stdout) | `printf '%s' "$json" \| jq -r '.[] \| tostring'` | Yes — T22 (rc=0) and T21 (rc=1) prove regex check on real jq output | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Test suite passes | `bash scripts/tests/test-project-secrets.sh` | exit 0 | PASS |
| Test is double-run safe | Two consecutive runs back-to-back | both exit 0 | PASS |
| Lib passes shellcheck | `shellcheck -S warning scripts/lib/project-secrets.sh scripts/tests/test-project-secrets.sh` | exit 0 | PASS |
| Project shellcheck gate | `make shellcheck` | `✅ ShellCheck passed` | PASS |
| Standalone make target | `make test-project-secrets` | exit 0, 42 PASS / 0 FAIL | PASS |
| YAML structurally valid | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` | exit 0 | PASS |
| Sourcing produces 0 side effects | `cd $(mktemp -d) && bash -c 'source …; ls -1A \| wc -l'` | 0 | PASS |
| 4 public functions defined after source | `declare -F \| grep -cE "^declare -f project_secrets_"` | 4 | PASS |
| Render empty | `project_secrets_render_mcp_env_block` | `{}` | PASS |
| Render two keys | `project_secrets_render_mcp_env_block FOO BAR` | `{"FOO":"${FOO}","BAR":"${BAR}"}` | PASS |
| Validate accepts `${VAR}` | `project_secrets_validate_mcp_env_block '{"K":"${K}"}'` | rc=0 | PASS |
| Validate refuses literal | `project_secrets_validate_mcp_env_block '{"K":"literal"}'` | rc=1 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SEC-01 | 37-01 | New library exposes callable functions; source produces no side effects | SATISFIED | Lib exists with 4 public functions (D-01 D-02); 0-side-effect smoke test passes; REQUIREMENTS.md traceability table marks complete (commit 0b0544f) |
| SEC-02 | 37-01 | `write_env` creates `.env` mode 0600 with literal KEY=VALUE; idempotent merge with collision prompt | SATISFIED | T1, T2, T3, T4, T5, T6 — all PASS. 8-step order-of-operations from D-04 enforced (touch → chmod 0600 → load → collision-or-append → chmod 0600) |
| SEC-03 | 37-01 | `ensure_gitignore` exact `^.env$` match; appends with comment; no false-positives on `*.env`/`# .env` | SATISFIED | T13, T14, T14b, T15, T16, T17 — all PASS. Lib uses `grep -Fxq '.env'` (exact-fixed-line) |
| SEC-04 | 37-01 | `render` produces JSON `{"K1":"${K1}",…}` form for `.mcp.json` env block | SATISFIED | T18 (`{}`), T19 (exact two-key form), T20 (invalid-key rc=1) — all PASS. Lib uses `jq -nc --args` |
| SEC-05 | 37-01 | Defense-in-depth refusal of literal `.mcp.json` env values; exact stderr phrase; `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` warns | SATISFIED | T21, T21b (exact phrase), T22, T23, T23b (warning phrase), T24 (MED-01 fix — malformed JSON fails closed) — all PASS |
| SEC-06 | 37-01 | `write_env` rejects shell-metacharacter values via shared `_mcp_validate_value` | SATISFIED | T7..T12 (6 distinct keys: DOLLAR, BTICK, BSLASH, DQUOTE, SQUOTE, NL) + T7b..T11b (5 paired stderr phrases) — all PASS. Lib reuses `_mcp_validate_value` via lazy source guard (D-16) — single regex source of truth shared with `mcp_secrets_set` |
| TEST-01 | 37-02 | New test file `scripts/tests/test-project-secrets.sh` ≥18 assertions, hermetic, idempotent | SATISFIED | 42 PASS / 0 FAIL (well above 18 floor); hermetic via `mktemp -d /tmp/project-secrets.XXXXXX`; double-run safe; trap covers EXIT INT TERM (LOW-02 bonus); CI wired via Tests 35-49 step; Makefile wired via Test 49 row + standalone target |

**Coverage:** 7/7 requirement IDs satisfied (SEC-01..06 + TEST-01).

No orphaned requirements: REQUIREMENTS.md Phase-37 row mapping (lines 128-133, 145) covers exactly the 7 IDs declared in the plan frontmatters.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | All scanned files (lib + test + Makefile + quality.yml + manifest.json) clean of TODO/FIXME/PLACEHOLDER/stub-return patterns. The `# shellcheck disable=SC2034` markers on color guards and array initializers are intentional and match the established `mcp.sh` convention (see CLAUDE.md anti-pattern learning rule §5). |

The only `return null/return [] ` style patterns found were:
- Lib line 56 `return 0` for empty/absent file (correct: load is a no-op when nothing to read)
- Lib line 92 `return 0` after echoing index (correct contract)
- Lib line 244 `return 0` after `printf '{}'` (correct: empty arg list → empty JSON)

All are legitimate function returns, not stubs.

### Human Verification Required

(none) — All success criteria are programmatically verifiable: file mode bits, exact stderr phrases, JSON output strings, function rc values, hermetic file presence/absence checks. The library has zero UI surface and no real-time/external-service interactions. No human eyeballs needed.

---

## Gaps Summary

No gaps. Phase 37 ships a complete, tested, CI-wired secrets boundary library:

1. **Library file** (`scripts/lib/project-secrets.sh`, 316 lines): 4 public functions + 2 private helpers; source-safe (no errexit); reuses `_mcp_validate_value` via lazy source (D-16 — single regex source of truth); 8-step write-env order-of-operations with idempotent merge + collision prompt + chmod 0600 before/after; `grep -Fxq '.env'` exact-fixed-line gitignore guard; `jq -nc --args` JSON renderer; defense-in-depth literal refusal with `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` test seam.
2. **Test suite** (`scripts/tests/test-project-secrets.sh`, 305 lines): 42 hermetic assertions (well above 18 floor) covering all SEC-01..06 surfaces — file mode, collision branches, all 6 metacharacters, all 3 KEY-shape rejections (HIGH-01 fix), gitignore false-negatives, render/validate exact forms, malformed JSON fail-closed (MED-01 fix), test-seam warning. Double-run safe; trap EXIT INT TERM (LOW-02 fix).
3. **Makefile wiring**: Test 49 row + standalone `test-project-secrets:` target + `.PHONY` entry. `make test-project-secrets` runs in isolation in <2s.
4. **CI wiring**: orphan-triage step renamed `Tests 35-43` → `Tests 35-49 — orphan triage + Phase 37 …` and the test invocation appended to the `run:` block.
5. **Manifest entry**: `scripts/lib/project-secrets.sh` registered in `files.libs[]` alpha-ordered between `optional-plugins.sh` and `skills.sh` — `update-claude.sh` will auto-distribute via the v4.4 LIB-01 D-07 jq path.

The two review findings in scope (HIGH-01 KEY-shape validation, MED-01 malformed-JSON fail-closed) were fixed and locked by 11 additional regression assertions (raising PASS from 31 to 42). Three LOW/INFO items deferred per `37-REVIEW-FIX.md` — none affect goal achievement.

**Quality gates:** `make shellcheck` green; `bash scripts/tests/test-project-secrets.sh` 42/0; double-run rc=0; YAML parses; manifest alpha-order valid.

**Downstream readiness:** Phase 38 (`mcp_wizard_run` scope routing) can call all 4 public functions; the regression net is in CI on every PR. Phase 40 (uninstall negative-contract) can grep for `project_secrets_*` to assert none of those names appear in any uninstall code path. Phase 41 (DIST-01) still owns the version bump + CHANGELOG entry, but the manifest insert it had scheduled is already done (auto-fixed wave-1 deviation in plan 37-02).

---

_Verified: 2026-05-04_
_Verifier: Claude (gsd-verifier)_
