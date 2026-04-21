---
phase: 01-pre-work-bug-fixes
plan: "05"
subsystem: version-alignment
tags: [bug-fix, versioning, changelog, makefile, shell]
dependency_graph:
  requires: []
  provides: [BUG-06-version-alignment]
  affects: [scripts/init-local.sh, CHANGELOG.md, Makefile]
tech_stack:
  added: []
  patterns: [jq-with-sed-fallback, makefile-version-gate]
key_files:
  created: []
  modified:
    - scripts/init-local.sh
    - CHANGELOG.md
    - Makefile
decisions:
  - "Read VERSION from manifest.json at runtime (jq + sed fallback + unknown default) rather than a hardcoded string constant"
  - "make validate version check uses grep+sed only (no jq dependency in Makefile context)"
  - "CHANGELOG.md [Unreleased] section uses full file-path + symptom descriptions per bullet (more useful than short form)"
metrics:
  duration_minutes: 12
  completed_date: "2026-04-17"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 3
---

# Phase 01 Plan 05: Version Alignment (BUG-06) Summary

**One-liner:** Runtime manifest.json version read in init-local.sh, populated CHANGELOG [Unreleased] block, and make validate manifest-CHANGELOG alignment gate.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace hardcoded VERSION in init-local.sh | 04e0618 | scripts/init-local.sh |
| 2 | Add [Unreleased] ### Fixed block to CHANGELOG.md | 183901a | CHANGELOG.md |
| 3 | Extend make validate with version-alignment check | ce3070a | Makefile |

## Changes Made

### Task 1 — scripts/init-local.sh

Removed line 11 (`VERSION="2.0.0"`) and inserted a manifest-reading block after `GUIDES_DIR`:

```bash
# BUG-06: single source of truth — manifest.json
MANIFEST_FILE="$GUIDES_DIR/manifest.json"
if command -v jq &>/dev/null && [[ -f "$MANIFEST_FILE" ]]; then
    VERSION=$(jq -r '.version' "$MANIFEST_FILE")
elif [[ -f "$MANIFEST_FILE" ]]; then
    VERSION=$(grep -m1 '"version"' "$MANIFEST_FILE" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
else
    VERSION="unknown"
fi
```

`bash scripts/init-local.sh --version` now prints `claude-code-toolkit v3.0.0 (local)` sourced from manifest.json.

### Task 2 — CHANGELOG.md

Replaced the empty `[Unreleased]` section (lines 8-9) with a populated `### Fixed` block:

```markdown
## [Unreleased]

### Fixed

- BUG-01: Replace GNU-only `head -n -1` with POSIX `sed '$d'` in `scripts/update-claude.sh` ...
- BUG-02: Add `< /dev/tty` guards to all interactive `read` calls in `scripts/setup-council.sh` ...
- BUG-03: JSON-escape API key values via `python3 json.dumps` before heredoc write ...
- BUG-04: Remove silent `sudo apt-get` for `tree` install in `scripts/setup-council.sh` ...
- BUG-05: Timestamped backup of `~/.claude/settings.json` before every mutation ...
- BUG-06: Read toolkit version from `manifest.json` at runtime in `scripts/init-local.sh` ...
- BUG-07: Add `design.md` (and any other manifest-drifted commands) to `scripts/update-claude.sh` ...
```

### Task 3 — Makefile

Inserted version-alignment assertion inside `validate:` target before the final `@echo "All templates valid"`:

```makefile
@MANIFEST_VER=$$(grep -m1 '"version"' manifest.json | sed 's/.*"version": *"\([^"]*\)".*/\1/'); \
    CHANGELOG_VER=$$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/'); \
    if [ "$$MANIFEST_VER" != "$$CHANGELOG_VER" ]; then \
        echo "Version mismatch: manifest.json=$$MANIFEST_VER, CHANGELOG.md=$$CHANGELOG_VER"; \
        exit 1; \
    fi; \
    echo "Version aligned: $$MANIFEST_VER"
```

## make validate Output

```text
Validating templates...
Version aligned: 3.0.0
All templates valid
```

## Verification Results

- `bash scripts/init-local.sh --version` → `claude-code-toolkit v3.0.0 (local)`
- `shellcheck scripts/init-local.sh` → exit 0
- `markdownlint CHANGELOG.md` → exit 0 (no violations)
- `make validate` → prints `Version aligned: 3.0.0` and `All templates valid`, exits 0
- `make check` → all checks pass (shellcheck + markdownlint + validate)

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. BUG-06 does not introduce new trust boundaries or network endpoints.

## Self-Check: PASSED

- scripts/init-local.sh exists and contains `jq -r '.version' "$MANIFEST_FILE"`: confirmed
- CHANGELOG.md contains `### Fixed` with BUG-01 through BUG-07: confirmed
- Makefile contains `MANIFEST_VER=` and `Version aligned`: confirmed
- Commits 04e0618, 183901a, ce3070a all exist in git log: confirmed
