---
phase: 02-foundation
plan: "01"
subsystem: plugin-detection
tags: [detect, shell, testing, makefile]
dependency_graph:
  requires: []
  provides: [scripts/detect.sh, scripts/tests/test-detect.sh]
  affects: [Makefile, Phase-3-install-flow]
tech_stack:
  added: []
  patterns:
    - "Sourced detection library — no set -euo pipefail in sourced files"
    - "jq has() for boolean key presence — avoids // operator treating false as null"
    - "find -mindepth 1 -maxdepth 1 instead of ls | grep for shellcheck compliance"
    - "detect_superpowers || true at bottom of detect.sh to survive set -e callers"
key_files:
  created:
    - scripts/detect.sh
    - scripts/tests/test-detect.sh
  modified:
    - Makefile
key_decisions:
  - "jq // operator treats false as null; switched to has() for key presence check in enabledPlugins"
  - "detect_superpowers returns 1 on absent SP; bottom-level call uses || true so sourcing into set -e context does not abort caller"
  - "find -type d instead of ls | grep to pass shellcheck SC2010"
  - "eval-deferred setup_cmd strings use # shellcheck disable=SC2016 (intentional single-quote delayed expansion)"
metrics:
  duration: "~5 minutes"
  completed_date: "2026-04-17"
  tasks_completed: 3
  files_changed: 3
requirements_satisfied: [DETECT-01, DETECT-02, DETECT-03, DETECT-04, DETECT-05]
---

# Phase 02 Plan 01: detect.sh Plugin Detection Library Summary

**One-liner:** Filesystem-based superpowers/GSD detection library via sourced shell script with jq `has()` stale-cache suppression and five-case POSIX test harness.

## What Was Built

`scripts/detect.sh` is a sourced shell library that exports four variables after probing the filesystem:

| Variable | Type | Value |
|----------|------|-------|
| `HAS_SP` | string | `"true"` or `"false"` |
| `HAS_GSD` | string | `"true"` or `"false"` |
| `SP_VERSION` | string | semver from subdir name, or `""` |
| `GSD_VERSION` | string | from VERSION file, or `""` |

`scripts/tests/test-detect.sh` is a five-case POSIX test harness that sources detect.sh under synthetic HOME directories to verify all detection paths.

`Makefile` extended with Test 4 step that runs the harness under `make test`.

## Detection Logic

### detect_superpowers (DETECT-01, DETECT-03)

1. Check `$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/` exists
2. Find highest semver versioned subdir (non-hidden) via `find -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1`
3. If `settings.json` exists and `jq` is available: check `enabledPlugins["superpowers@claude-plugins-official"]` using `has()` — value `false` suppresses detection (stale-cache)
4. Missing `enabledPlugins` key (older Claude Code) passes through as SP present

### detect_gsd (DETECT-02)

Filesystem only — `$HOME/.claude/get-shit-done/` exists AND `bin/gsd-tools.cjs` present. No `settings.json` check (GSD is not a Claude Code plugin).

## Key Contracts

- **No `set -euo pipefail`** — sourced files must not alter caller error mode (Pitfall 1)
- **Zero stdout during sourcing** — callers decide what to print (D-05)
- **`detect_superpowers || true`** at bottom of file — return 1 (SP absent) does not abort `set -e` callers
- **`enabledPlugins` check only in `detect_superpowers`** — never in `detect_gsd` (Pitfall 2)
- **Full-path `mktemp` form** — `mktemp -d "${TMPDIR:-/tmp}/test-detect.XXXXXX"` (Pitfall 3)

## Test Coverage

Five cases run via `bash scripts/tests/test-detect.sh` and `make test`:

| Case | Setup | Expected HAS_SP | Expected HAS_GSD |
|------|-------|-----------------|------------------|
| neither | empty `~/.claude` | false | false |
| SP only | cache dir + enabledPlugins=true | true | false |
| GSD only | bin/gsd-tools.cjs + VERSION | false | true |
| both | SP + GSD setup | true | true |
| SP stale-cache disabled | cache dir + enabledPlugins=false | false | false |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] jq `//` operator treats boolean `false` as alternative value**

- **Found during:** Task 2 (test harness case 5 failing)
- **Issue:** `jq -r '.enabledPlugins["superpowers@claude-plugins-official"] // "missing"'` returns `"missing"` when the JSON value is boolean `false`, because jq's `//` (alternative operator) substitutes for both `null` AND `false`. The stale-cache case always reported `enabled=missing` and passed through.
- **Fix:** Switched to `if (.enabledPlugins | has("superpowers@claude-plugins-official")) then ... | tostring else "missing" end` — distinguishes key-absent (`missing`) from key-present-false (`false`).
- **Files modified:** `scripts/detect.sh`
- **Commit:** `dc16626`

**2. [Rule 1 - Bug] detect_superpowers returns 1 aborts set -e test harness**

- **Found during:** Task 2 (test harness Case 1 — harness exited silently)
- **Issue:** `detect_superpowers` at bottom of detect.sh returns 1 when SP absent. Sourcing detect.sh into a `set -euo pipefail` context (the test harness) causes the harness to abort immediately after the first sourcing.
- **Fix:** Changed `detect_superpowers` to `detect_superpowers || true` at the bottom of detect.sh. The return 1 signals the absence of SP to function-level callers; `|| true` prevents it from propagating to the `set -e` sourcing context.
- **Files modified:** `scripts/detect.sh`
- **Commit:** `dc16626`

**3. [Rule 2 - Missing] shellcheck SC2016 on eval-deferred setup_cmd strings**

- **Found during:** Task 3 verification (`make check`)
- **Issue:** `make shellcheck` runs without `-S warning`, catching SC2016 (info) on single-quoted strings with `$SCRATCH` that are intentionally eval-deferred.
- **Fix:** Added `# shellcheck disable=SC2016` before each `run_case` call with single-quoted setup_cmd.
- **Files modified:** `scripts/tests/test-detect.sh`
- **Commit:** `efcb513`

## Known Stubs

None — the exported variables (`HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION`) are fully populated with real filesystem data. Phase 3 will consume them.

## Threat Flags

None — no new network endpoints, auth paths, file writes, or trust boundary changes. detect.sh reads filesystem only (user-owned paths).

## Commits

| Hash | Message |
|------|---------|
| `88069dc` | feat(02-01): create scripts/detect.sh plugin detection library (DETECT-01..05) |
| `dc16626` | feat(02-01): add five-case test harness and fix jq stale-cache detection |
| `0bd835b` | feat(02-01): extend Makefile test target with detect.sh harness (Test 4) |
| `efcb513` | fix(02-01): suppress SC2016 on intentional eval-deferred setup_cmd strings |

## Self-Check: PASSED

All files verified present. All commits verified in git log.

| Check | Result |
|-------|--------|
| scripts/detect.sh exists | PASSED |
| scripts/tests/test-detect.sh exists | PASSED |
| Commit 88069dc exists | PASSED |
| Commit dc16626 exists | PASSED |
| Commit 0bd835b exists | PASSED |
| Commit efcb513 exists | PASSED |
