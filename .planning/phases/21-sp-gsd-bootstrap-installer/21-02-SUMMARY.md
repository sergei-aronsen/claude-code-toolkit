---
phase: 21-sp-gsd-bootstrap-installer
plan: "02"
subsystem: bootstrap
tags: [bootstrap, init-claude, init-local, argparse, detect-resource, color-gate, shell]
dependency_graph:
  requires:
    - scripts/lib/bootstrap.sh (bootstrap_base_plugins entry point — plan 21-01)
    - scripts/lib/optional-plugins.sh (TK_SP_INSTALL_CMD, TK_GSD_INSTALL_CMD — plan 21-01)
  provides:
    - scripts/init-claude.sh (--no-bootstrap argparse + bootstrap.sh fetch/source + bootstrap_base_plugins call + detect.sh re-source)
    - scripts/init-local.sh (--no-bootstrap argparse + --help line + bootstrap.sh source + bootstrap_base_plugins call + detect.sh re-source + color re-gate)
  affects:
    - scripts/tests/test-bootstrap.sh (will source these installers — plan 21-03)
tech_stack:
  added: []
  patterns:
    - curl-fetch-to-tmpfile (init-claude.sh lib-source pattern — existing, extended with bootstrap.sh)
    - post-argparse bootstrap call (init-local.sh asymmetry from RESEARCH.md Pitfall 1)
    - detect.sh re-source after bootstrap (D-14 invariant)
    - color re-gate after detect.sh re-source (uninstall.sh lines 109-123 pattern — init-local.sh only)
key_files:
  created: []
  modified:
    - scripts/init-claude.sh
    - scripts/init-local.sh
decisions:
  - "init-claude.sh: NO_BOOTSTRAP default placed in post-argparse defaults block (line 62) alongside SKIP_COUNCIL/MODE/FORCE/FORCE_MODE_CHANGE — consistent pattern"
  - "init-local.sh: NO_BOOTSTRAP=false placed in the flags init block (line 83) alongside DRY_RUN/FRAMEWORK/MODE/FORCE/FORCE_MODE_CHANGE — consistent pattern"
  - "init-local.sh: lib/optional-plugins.sh sourced in early lib block BEFORE lib/bootstrap.sh — bootstrap.sh reads TK_SP_INSTALL_CMD/TK_GSD_INSTALL_CMD which are defined by optional-plugins.sh"
  - "Plan awk ordering verification (^done$) produces false negative for init-local.sh — the file has a second ^done$ at line 344 (from an install for-loop) which overwrites the awk variable; actual ordering is correct (argparse done=132, bootstrap=155, re-run=179)"
  - "Color re-gate in init-local.sh post-bootstrap block uses both [ -t 1 ] AND [ -z NO_COLOR+x ] checks — stricter than the original gate (which only checks [ -t 1 ]) to match the plan spec and uninstall.sh pattern"
metrics:
  duration: 8m
  completed: "2026-04-27T07:35:55Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 2
---

# Phase 21 Plan 02: Installer Wiring Summary

**One-liner:** Bootstrap entry point wired into both installers — `--no-bootstrap` flag parsed, `lib/bootstrap.sh` sourced, `bootstrap_base_plugins()` called pre-manifest, `detect.sh` re-sourced post-call; color re-gate applied in `init-local.sh`.

## What Was Built

### Task 1 — Wire bootstrap into `scripts/init-claude.sh`

Four coordinated edits to `scripts/init-claude.sh`:

**Argparse case branch** (line 41-44, before framework branch):

```bash
--no-bootstrap)
    NO_BOOTSTRAP=true
    shift
    ;;
```

**Post-argparse default** (line 62):

```bash
NO_BOOTSTRAP="${NO_BOOTSTRAP:-false}"
```

**Lib-source block** (lines 73-117):

- Added `LIB_BOOTSTRAP_TMP=$(mktemp ...)` after `LIB_OPTIONAL_PLUGINS_TMP` mktemp
- Updated first `trap` to include `$LIB_BOOTSTRAP_TMP`
- Curl-fetches `scripts/lib/bootstrap.sh` into `$LIB_BOOTSTRAP_TMP` (hard-fail on download error)
- Sources `$LIB_BOOTSTRAP_TMP` with `# shellcheck source=/dev/null`
- Bootstrap call block (lines 107-117): guarded on `NO_BOOTSTRAP` and `TK_NO_BOOTSTRAP`; calls `bootstrap_base_plugins`; re-sources `$DETECT_TMP` (second source — D-14)
- Updated second `trap` (manifest trap) to also include `$LIB_BOOTSTRAP_TMP`

**Unknown-arg catch-all** (line 52): Now lists `--no-bootstrap` in the flag echo printed on unrecognized arguments, satisfying D-18 for `init-claude.sh` (which has no dedicated `--help` flag).

**Bootstrap call site position:**
- Argparse: lines 24-56
- Lib sources: lines 69-105 (detect, install, dry-run-output, optional-plugins, bootstrap)
- Bootstrap call: lines 107-117 (AFTER all libs, BEFORE manifest guard at line 119)
- Manifest guard: line 122+

### Task 2 — Wire bootstrap into `scripts/init-local.sh`

Four coordinated edits to `scripts/init-local.sh`:

**Early lib-source block addition** (lines 40-42):

```bash
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/optional-plugins.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/bootstrap.sh"
```

`init-local.sh` did not previously source `lib/optional-plugins.sh` — this is a new dependency added in plan 21-02 (required because `bootstrap.sh` reads `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` from it).

**Flags initialization** (line 83):

```bash
NO_BOOTSTRAP=false
```

**Argparse case branch** (line 99-102, after `--force-mode-change`, before `--version`):

```bash
--no-bootstrap)
    NO_BOOTSTRAP=true
    shift
    ;;
```

**`--help` block** (lines 109, 113):

- Usage line updated: `init-local.sh [--dry-run] [--mode <name>] [--force] [--force-mode-change] [--no-bootstrap] [framework]`
- Options block: `--no-bootstrap        Skip the SP/GSD install prompts (env: TK_NO_BOOTSTRAP=1)`

**Bootstrap call site** (lines 146-176, after mode validation fi, before re-run delegation):

```bash
if [[ "${NO_BOOTSTRAP:-false}" != "true" && "${TK_NO_BOOTSTRAP:-}" != "1" ]]; then
    bootstrap_base_plugins
    source "$SCRIPT_DIR/detect.sh"          # second source — D-14
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
        RED=$'\033[0;31m'; GREEN=...; ...   # color re-gate (Pitfall 2)
    else
        RED=''; GREEN=''; ...
    fi
fi
```

**init-local.sh asymmetry handled:** libs sourced at lines 31-42 (before argparse at 81-132); bootstrap call at line 155 (after argparse done at 132 and mode validation fi at 144, before re-run delegation at 179).

**Two `if [ -t 1 ]` color gates confirmed:**
1. Original gate: line 47 (after initial lib sources)
2. Post-bootstrap re-gate: line 159 (after detect.sh re-source)

## Verification Results

### Lint Gates

```text
PASS: bash -n scripts/init-claude.sh
PASS: shellcheck -S warning scripts/init-claude.sh
PASS: bash -n scripts/init-local.sh
PASS: shellcheck -S warning scripts/init-local.sh
PASS: make check (shellcheck + markdownlint + validate + all quality gates)
```

### Smoke Tests

```text
smoke A PASS — init-claude.sh --no-bootstrap: flag parsed, no "Unknown argument" error
smoke B PASS — init-local.sh --no-bootstrap --dry-run: zero "bootstrap" output (D-17 byte-quiet)
smoke C PASS — init-local.sh --help: Usage line lists --no-bootstrap AND Options block describes it
```

### Acceptance Criteria Status

#### Task 1 (init-claude.sh)

| Check | Result |
|-------|--------|
| `bash -n` exits 0 | PASS |
| `shellcheck -S warning` exits 0 | PASS |
| `--no-bootstrap)` case: count = 1 | PASS |
| `NO_BOOTSTRAP="${NO_BOOTSTRAP:-false}"` default: count = 1 | PASS |
| `LIB_BOOTSTRAP_TMP=$(mktemp ...)`: count = 1 | PASS |
| `LIB_BOOTSTRAP_TMP` total references: count = 5 (mktemp + trap1 + curl + source + trap2) | PASS |
| curl-fetches `scripts/lib/bootstrap.sh` | PASS |
| sources `$LIB_BOOTSTRAP_TMP` | PASS |
| `bootstrap_base_plugins` called exactly once | PASS |
| `source "$DETECT_TMP"`: count = 2 (original + post-bootstrap) | PASS |
| Order: `bootstrap_base_plugins` before `MANIFEST_VER=$(jq` | PASS |
| Order: `source "$LIB_OPTIONAL_PLUGINS_TMP"` before `bootstrap_base_plugins` | PASS |
| `--no-bootstrap` listed in unknown-arg flag echo | PASS |
| Smoke: `--no-bootstrap` not "Unknown argument" | PASS |

#### Task 2 (init-local.sh)

| Check | Result |
|-------|--------|
| `bash -n` exits 0 | PASS |
| `shellcheck -S warning` exits 0 | PASS |
| sources `lib/optional-plugins.sh`: count = 1 (new dependency) | PASS |
| sources `lib/bootstrap.sh`: count = 1 | PASS |
| Source order: optional-plugins before bootstrap | PASS |
| `--no-bootstrap)` case: count = 1 | PASS |
| `--help` block lists `--no-bootstrap` | PASS |
| Usage line lists `--no-bootstrap` | PASS |
| `NO_BOOTSTRAP=false` default: count = 1 | PASS |
| `bootstrap_base_plugins` called exactly once | PASS |
| Order: argparse done (132) < bootstrap (155) < re-run delegation (179) | PASS (verified by line numbers; plan awk gives false negative due to second `done` at line 344) |
| `source "$SCRIPT_DIR/detect.sh"`: count = 2 | PASS |
| `if [ -t 1 ]` color gate: count = 2 | PASS |
| Smoke: `--no-bootstrap --dry-run` not "Unknown option" | PASS |
| Smoke: `--help` exits 0 and lists `--no-bootstrap` twice | PASS |

## Deviations from Plan

### Minor — Plan awk ordering check produces false negative for init-local.sh

The plan's acceptance criteria awk for `init-local.sh` uses `/^done$/` to find the end of the argparse while-loop. The file has a second `^done$` at line 344 (from the cheatsheets `for` loop in the install section). The awk accumulates `d=NR` for each match, so the final value is 344, which is greater than `bootstrap_base_plugins` at line 155 — causing the check to print FAIL even though the actual ordering is correct (132 < 155 < 179).

**Fix applied:** None needed — the invariant is correctly met. Ordering verified directly via `grep -n`. Documented here for the verifier.

### Minor — Color re-gate stricter than original gate

The original `init-local.sh` color gate at line 47 checks only `[ -t 1 ]`. The post-bootstrap re-gate at line 159 (from the plan spec and `uninstall.sh` pattern) checks `[ -t 1 ] && [ -z "${NO_COLOR+x}" ]`. This is intentionally stricter — `NO_COLOR` compliance is an improvement, not a regression. No behavior change in the common case.

No other deviations. Plan executed as written.

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired data flows introduced.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes beyond what the plan's `<threat_model>` documents.

- `init-claude.sh` curl-fetches `scripts/lib/bootstrap.sh` under the same HTTPS/GitHub-raw trust boundary as the existing 4 lib downloads (T-21-04 — accepted in plan threat model).
- `init-local.sh` uses local filesystem path — no new network surface.

## Self-Check: PASSED

All artifacts confirmed present and committed:

- `scripts/init-claude.sh` modified (commit 9a61e61) — contains `--no-bootstrap`, `LIB_BOOTSTRAP_TMP`, `bootstrap_base_plugins`, two `source "$DETECT_TMP"` lines
- `scripts/init-local.sh` modified (commit 3dfd05d) — contains `lib/optional-plugins.sh` source, `lib/bootstrap.sh` source, `--no-bootstrap)` case, `NO_BOOTSTRAP=false`, `bootstrap_base_plugins`, two `source "$SCRIPT_DIR/detect.sh"` lines, two `if [ -t 1 ]` gates
- All smoke tests A/B/C print PASS
- `make check` exits 0
- All must_haves.truths verified in acceptance criteria tables above
