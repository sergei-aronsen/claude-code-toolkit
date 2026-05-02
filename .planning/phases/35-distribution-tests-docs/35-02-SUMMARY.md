---
phase: 35
plan: 35-02
title: Three hermetic test suites + Makefile/CI wiring
req_ids: [TEST-01, TEST-02, TEST-03, TEST-04]
status: complete
completed: 2026-05-02
---

# Phase 35-02 Summary: Three new test suites + Makefile/CI wiring

## One-liner

Shipped three new hermetic test suites (`test-integrations-catalog.sh`, `test-cli-installer.sh`, `test-integrations-tui.sh`) locking the v4.9 contract surface; wired them into `Makefile` (Tests 45-47 + standalone targets) and `.github/workflows/quality.yml` (Tests 21-47 step).

## Tests delivered

### TEST-01 — `scripts/tests/test-integrations-catalog.sh`

Hermetic schema-only validation; no shell-out to claude/brew/npm/network. **PASS=14** (≥10 floor).

Assertions cover:

- A1: catalog file exists at canonical path
- A2: parses as valid JSON
- A3: `schema_version == 2`
- A4: `categories[]` is the canonical 10-list in CATEGORIES_ORDER
- A5: `components.mcp` has exactly 20 entries
- A6: every MCP entry has all required keys
- A7: every MCP entry's `category` is in `categories[]`
- A8: `components.cli` has exactly 8 entries
- A9: every CLI entry has `detect_cmd` + `install.darwin` + `install.linux` + `post_install_hint`
- A10: unofficial set equals exactly `{notebooklm, telegram}`
- A11: `sequential-thinking` is gone (DROP-01 regression guard)
- A12: no `sudo` token in any install string (CLI-04 D-17 invariant)
- A13: every MCP entry's `name` self-references its key
- A14: every MCP `install_args` is a non-empty list of strings

### TEST-02 — `scripts/tests/test-cli-installer.sh`

Hermetic primitives test using `TK_CLI_UNAME` + `TK_CLI_BREW_BIN` seams. **PASS=24** (≥8 floor).

Assertions cover:

- A1-A2: `cli_detect` happy / not-found paths
- A3: `cli_detect` empty-arg rejection (rc=1 + stderr)
- A4-A5: `cli_install` Darwin/Linux dispatch (only the matching cmd runs)
- A6: unsupported platform `FreeBSD` → rc=2 + stderr
- A7: brew-prefixed darwin_cmd + brew absent → rc=3 + brew-not-found hint
- A8: brew-prefixed darwin_cmd + brew present (PATH stub) → rc=0 with brew_cmd executed
- A9: `cli_post_install_hint` writes to stderr only, stdout empty, contains "Next:"
- A10: `cli_post_install_hint` empty-arg silent no-op (rc=0)
- A11: `cli_install` empty args → rc=1 + usage-line stderr
- A12: no executable `sudo` token in `cli-installer.sh` source (line-level grep ignoring comments)

### TEST-03 — `scripts/tests/test-integrations-tui.sh`

Hermetic TUI redesign coverage using `TK_MCP_CLAUDE_BIN`, `TK_MCP_CONFIG_HOME`, `TK_MCP_CATALOG_PATH`, `TK_INTEGRATIONS_TTY_SRC` seams + a mock claude script that emits `<name>    stdio    URL` rows so the regex match in `is_mcp_installed` resolves correctly. **PASS=36** (≥15 floor).

Assertions cover:

- A1: `mcp_status_array` populates `TUI_GROUP_NAMES[]` in canonical category order, title-cased
- A2: unofficial labels render with `[!]` glyph under NO_COLOR; official labels do not
- A3: `TUI_LABELS[]` / `TUI_GROUPS[]` / `MCP_NAMES[]` are all length 20 (parallel arrays)
- A4: mocked `claude mcp list` output flows into `MCP_STATUS[]` and `TUI_INSTALLED[]`
- A5-A8: `unofficial_confirm` ALWAYS_YES bypass, TTY-y, TTY-empty (fail-closed N), TTY-n
- A9: `--mcp-only --cli-only` mutex → rc=2 + stderr "mutually exclusive"
- A10: `--integrations --yes --dry-run` exits 0 with no deprecation note
- A11: `--mcps --yes --dry-run` exits 0 AND prints deprecation note (CAT-04)
- A12: "Integrations Install Summary" banner renders under dry-run
- A13: summary header carries Entry / MCP / CLI / Notes columns
- A14: total line carries `Installed: N MCPs, M CLIs · Skipped: X · Failed: Y`
- A15: zero-entry categories silently skipped (uses small fixture catalog)
- A16: `--mcp-only` skips CLI dispatch (summary CLI cell carries `mcp-only`)
- A17: `--cli-only` skips MCP dispatch (summary MCP cell carries `cli-only`)

### TEST-04 — Makefile + CI wiring

- `Makefile`:
  - Added `test-integrations-catalog`, `test-cli-installer`, `test-integrations-tui` to `.PHONY`.
  - Added Tests 45-47 lines to the master `test` target.
  - Added 3 standalone targets (mirroring the precedent for Tests 31-33, 44).
- `.github/workflows/quality.yml`:
  - Renamed step `Tests 21-44` → `Tests 21-47`, expanded the description string to include `TEST-01..03`.
  - Appended 3 new `bash scripts/tests/test-*.sh` invocations after `test-integrations-foundation.sh`.

## Verification (final 7-test sweep)

```text
test-mcp-selector.sh                    PASS=21 FAIL=0   (baseline preserved)
test-bootstrap.sh                       PASS=26 FAIL=0   (baseline preserved)
test-install-tui.sh                     PASS=52 FAIL=0   (Phase 34 expanded baseline preserved)
test-integrations-foundation.sh         PASS=32 FAIL=0   (Phase 32 baseline preserved)
test-integrations-catalog.sh            PASS=14 FAIL=0   (NEW; floor 10)
test-cli-installer.sh                   PASS=24 FAIL=0   (NEW; floor 8)
test-integrations-tui.sh                PASS=36 FAIL=0   (NEW; floor 15)
make check                              rc=0
shellcheck -S warning <new tests>       rc=0
```

Baseline note: `test-install-tui.sh` is at PASS=52 not PASS=43 — Phase 34's TUI redesign added new assertions; current baseline is preserved at 52.

## Acceptance criteria

- [x] 3 new tests pass with floors met
- [x] All 4 baselines green
- [x] Makefile + CI wired
- [x] `make check` rc=0

## Deviations

### Auto-fixed Issues

**1. [Rule 1 - Bug] Mock `claude mcp list` row format mismatch**

- **Found during:** TEST-03 first run — A4 assertion failed (`MCP_STATUS=absent` instead of `installed`).
- **Issue:** Initial mock used `printf '%s: stdio command\n' "$n"` but `is_mcp_installed` (mcp.sh:547) matches the regex `^<name>([[:space:]]|$)` — a colon does not match `[[:space:]]`.
- **Fix:** Changed mock to emit `printf '%s    stdio    https://example.local\n' "$n"` so the first whitespace-separated token is the name (matches the real `claude mcp list` output format).
- **Files modified:** `scripts/tests/test-integrations-tui.sh`
- **Commit:** captured in this plan's commit.

## Files changed

- `scripts/tests/test-integrations-catalog.sh` (NEW, +207 lines)
- `scripts/tests/test-cli-installer.sh` (NEW, +197 lines)
- `scripts/tests/test-integrations-tui.sh` (NEW, +349 lines)
- `Makefile` (+15 lines: 4 phony targets, 3 test-block lines, 3 standalone targets)
- `.github/workflows/quality.yml` (+3 lines, step name updated)

## Commit

`test(35-02): hermetic test suites for v4.9 contract`

## Self-Check: PASSED

- All 4 baselines green (21 / 26 / 52 / 32)
- All 3 new tests green (14 / 24 / 36 — floors 10 / 8 / 15)
- `make check` rc=0
- shellcheck rc=0 on new tests
