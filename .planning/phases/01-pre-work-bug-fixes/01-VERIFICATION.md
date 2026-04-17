---
phase: 01-pre-work-bug-fixes
verified: 2026-04-17T00:00:00Z
verification_type: goal-backward
status: passed
requirements_verified:
  total: 7
  passed: 7
  failed: 0
gaps: 0
---

# Phase 01: Pre-work Bug Fixes — Verification Report

**Phase Goal:** All known v3.x bugs that would silently corrupt complement-mode logic are eliminated before new code lands.

**Verified:** 2026-04-17
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Verification Table

| BUG | Requirement | Evidence Command | Expected | Actual | Result |
|-----|-------------|-----------------|----------|--------|--------|
| BUG-01 | `head -n -1` replaced with POSIX `sed '$d'` in update-claude.sh smart-merge | `grep -c "head -n -1" scripts/update-claude.sh` | 0 | 0 | PASS |
| BUG-01 | `sed '$d'` present in all 4 extraction pipelines | `grep -c "sed '\$d'" scripts/update-claude.sh` | 4 | 4 | PASS |
| BUG-02 | Every interactive `read` has `< /dev/tty 2>/dev/null` | `grep -c "read.*< /dev/tty" scripts/setup-council.sh` | ≥3 | 4 | PASS |
| BUG-02 | Early non-interactive guard present | `grep -n "\! -r /dev/tty" scripts/setup-council.sh` | line 24 | line 24 | PASS |
| BUG-03 | `python3 json.dumps` applied in setup-council.sh (3 keys) | `grep -c "python3.*json.dumps" scripts/setup-council.sh` | 3 | 3 | PASS |
| BUG-03 | `python3 json.dumps` applied in init-claude.sh (3 keys) | `grep -c "python3.*json.dumps" scripts/init-claude.sh` | 3 | 3 | PASS |
| BUG-03 | config.json heredoc uses `*_JSON` vars (not raw key values) | grep heredoc vars | present | GEMINI_MODE_JSON, GEMINI_KEY_JSON, OPENAI_KEY_JSON confirmed | PASS |
| BUG-04 | No executable `sudo apt-get` in setup-council.sh | `grep -n "^[[:space:]]*sudo apt-get" scripts/setup-council.sh` | 0 lines | 0 lines | PASS |
| BUG-04 | No `apt-get.*2>/dev/null` (errors now visible) | `grep -c "apt-get.*2>/dev/null" scripts/setup-council.sh` | 0 | 0 | PASS |
| BUG-04 | Advisory string "Run: sudo apt-get install tree" present exactly once | `grep -c "sudo apt-get install tree" scripts/setup-council.sh` | 1 | 1 (in echo) | PASS |
| BUG-05 | 3 timestamped backup creations before python3 merge | `grep -n "SETTINGS_BACKUP.*bak.*date" scripts/setup-security.sh` | 3 sites | lines 203, 317, 359 | PASS |
| BUG-05 | 3 restore paths on python3 failure | `grep -n "cp.*SETTINGS_BACKUP.*SETTINGS_JSON" scripts/setup-security.sh` | 3 sites | lines 245, 347, 384 | PASS |
| BUG-06 | No hardcoded `VERSION="2.0.0"` in init-local.sh | `grep "VERSION=.*[0-9]" scripts/init-local.sh` | 0 matches | 0 matches | PASS |
| BUG-06 | Runtime manifest.json read present | `grep "manifest\.json" scripts/init-local.sh` | jq/.version line | lines 16-22 | PASS |
| BUG-06 | `init-local.sh --version` matches manifest.json | `bash scripts/init-local.sh --version` | `3.0.0` | `claude-code-toolkit v3.0.0 (local)` | PASS |
| BUG-06 | CHANGELOG `[Unreleased]` `### Fixed` lists all 7 BUGs | head of CHANGELOG.md | BUG-01..BUG-07 listed | all 7 present | PASS |
| BUG-06 | `make validate` manifest ↔ CHANGELOG version check present | `grep "MANIFEST_VER\|CHANGELOG_VER" Makefile` | alignment check | lines 86-92 | PASS |
| BUG-07 | `design.md` present in update-claude.sh commands loop | `grep "design\.md" scripts/update-claude.sh` | present | line 147 | PASS |
| BUG-07 | Loop count matches manifest commands count (30 each) | count commands in both | equal | 30 == 30 | PASS |
| BUG-07 | Makefile drift check error string present | `grep "manifest.json files.commands has" Makefile` | present | line 105 | PASS |

---

## Quality Gates

| Gate | Command | Result | Status |
|------|---------|--------|--------|
| ShellCheck | `make shellcheck` | "ShellCheck passed" | PASS |
| Template validation | `make validate` | "All templates valid" | PASS |
| Version alignment | `make validate` (embedded check) | "Version aligned: 3.0.0" | PASS |
| Commands drift check | `make validate` (embedded check) | "update-claude.sh commands match manifest.json" | PASS |

---

## SUMMARY.md Coverage

All 7 plans have corresponding SUMMARY.md files confirmed present:

- 01-01-SUMMARY.md (BUG-01: POSIX sed)
- 01-02-SUMMARY.md (BUG-02: /dev/tty guards)
- 01-03-SUMMARY.md (BUG-05: settings.json backup)
- 01-04-SUMMARY.md (BUG-03: JSON-escape API keys)
- 01-05-SUMMARY.md (BUG-06: version alignment)
- 01-06-SUMMARY.md (BUG-04: no-sudo advisory)
- 01-07-SUMMARY.md (BUG-07: manifest drift check)

---

## Git Commits

Phase 1 fix commits confirmed in git log (all on main after merge):

- `fix(01-01)`: replace GNU head -n -1 with POSIX sed $d (BUG-01)
- `fix(01-02)`: add early non-interactive guard (BUG-02)
- `fix(01-02)`: add /dev/tty guards to all interactive read calls (BUG-02)
- `fix(01-03)`: backup settings.json before each python3 mutation (BUG-05)
- `fix(01-04)`: JSON-escape API keys via python3 json.dumps in setup-council.sh (BUG-03)
- `fix(01-04)`: JSON-escape API keys via python3 json.dumps in init-claude.sh (BUG-03)
- `fix(01-05)`: read VERSION from manifest.json at runtime in init-local.sh (BUG-06)
- `fix(01-05)`: extend make validate with manifest ↔ CHANGELOG version-alignment check (BUG-06)
- `fix(01-06)`: replace sudo apt-get with advisory flow in setup-council.sh (BUG-04)
- `fix(01-07)`: add design.md to update-claude.sh loop + sort alphabetically (BUG-07)
- `fix(01-07)`: add manifest<->update-claude.sh drift check to make validate (BUG-07)

All 7 BUGs represented, 11 fix commits total.

---

## Gaps

None. All 7 bug requirements verified.

---

## Code Review Cross-Reference

The code review (01-REVIEW.md) found 3 warnings and 2 info items. None block goal achievement:

- **WR-01** (BUG-04 both branches identical) — misleading prompt UX, dead else-branch. Not a correctness failure: `sudo` is never invoked, which is the BUG-04 goal. The advisory message is printed.
- **WR-02** (non-atomic write without trap) — BUG-05 goal is "backup exists before mutation and restore fires on non-zero exit." Both conditions are met. The SIGKILL edge case is a hardening opportunity, not a BUG-05 requirement.
- **WR-03** (unquoted `$COUNCIL_DIR` in python3 -c) — low-exploitability correctness edge case. Not a BUG-03 requirement.
- **IN-01, IN-02** — informational only.

All three warnings are post-phase hardening candidates, not Phase 1 goal blockers.

---

## Conclusion

Phase 1 goal is **achieved**. All seven v3.x bugs (BUG-01 through BUG-07) are eliminated in the on-disk code:

1. `update-claude.sh` smart-merge is POSIX-portable (`sed '$d'` in all 4 extraction pipelines; zero `head -n -1` occurrences).
2. `setup-council.sh` completes cleanly under `curl | bash`: the early `/dev/tty`-unreadable guard exits before the banner, and all 4 interactive `read` calls carry `< /dev/tty 2>/dev/null`.
3. API keys with `"`, `\`, or newlines are JSON-escaped via `python3 json.dumps` in both `setup-council.sh` and `init-claude.sh` (3 escapes per file, heredoc uses pre-escaped `*_JSON` variables).
4. `setup-council.sh` never invokes `sudo`: the advisory string "Run: sudo apt-get install tree" is printed inside `echo -e` only; `grep -n "^[[:space:]]*sudo apt-get"` returns zero matches.
5. `setup-security.sh` creates a timestamped backup before every one of its 3 python3 mutation sites, and restores from backup on non-zero exit.
6. `init-local.sh` reads version from `manifest.json` at runtime (no hardcoded constant); `make validate` enforces manifest ↔ CHANGELOG alignment; all three sources report `3.0.0`.
7. `design.md` is in the `update-claude.sh` commands loop and manifest (30 commands each); `make validate` detects future drift in both directions.

`make shellcheck` and `make validate` both pass clean. Phase 2 can proceed on a solid baseline.

---

_Verified: 2026-04-17_
_Verifier: Claude (gsd-verifier)_
