---
phase: 01-pre-work-bug-fixes
plan: "07"
subsystem: manifest-drift
tags: [bug-fix, manifest, make-validate, drift-detection]
commits:
  - 2dc4c24 fix(01-07): add design.md to update-claude.sh loop + sort alphabetically
  - b7b29d2 fix(01-07): add manifest<->update-claude.sh drift check to make validate
---

# Plan 01-07 Summary — BUG-07

## Objective

Quick fix for BUG-07: add `design.md` to the hand-maintained `for file in ...` loop at `scripts/update-claude.sh:147` so `/design` reaches users on `update-claude.sh` runs. Add a drift-check to `make validate` so this class of bug cannot recur silently until Phase 4's UPDATE-02 structurally eliminates the hand-maintained loop.

## What was done

**scripts/update-claude.sh (line 147)**

Replaced the 29-entry hand-maintained loop with a 30-entry alphabetically-sorted list that includes `design.md`. Sorting alphabetically makes future drift visually obvious during code review.

Before: 29 entries, `design.md` missing, unsorted.
After: 30 entries, alphabetically sorted, matches `manifest.json` `files.commands`.

**Makefile (`validate:` target)**

Added a bidirectional drift check block after the existing version-alignment block (from plan 01-05):

- Extracts command filenames from `manifest.json` via `grep '"commands/' | sed`
- Extracts the commands loop line from `scripts/update-claude.sh` via `awk` after `mkdir -p "$CLAUDE_DIR/commands"` — targets the correct loop out of three `for file in *.md` loops in the file (agents, commands, rules)
- Runs two passes:
  1. For each entry in loop, assert it exists in manifest (catches typos)
  2. For each entry in manifest, assert it exists in loop (catches missing entries — the actual BUG-07 failure mode)
- Emits `✅ update-claude.sh commands match manifest.json` on success, or an itemized `❌` list + `Found N commands drift errors` + `exit 1` on drift

## Verification

- `make validate` → all green:

    ```text
    ✅ Version aligned: 3.0.0
    ✅ update-claude.sh commands match manifest.json
    ✅ All templates valid
    ```

- Negative smoke: temporarily removed `design.md` from the loop via `sed`, re-ran `make validate`:

    ```text
    ❌ manifest.json files.commands has 'design.md' missing from update-claude.sh loop
    Found 1 commands drift errors
    make: *** [validate] Error 1
    ```

    Restored via `git checkout`, confirmed green again.

## Key Files

**Modified:**

- `scripts/update-claude.sh` (line 147 — loop contents)
- `Makefile` (`validate:` target — drift-check block)

## Key Links

- BUG-07 requirement: D-23 (manifest as single source of truth until UPDATE-02)
- Upstream: plan 01-05's `make validate` version-alignment block now shares the same target
- Downstream: Phase 4 UPDATE-02 will structurally eliminate the hand-maintained loop; until then, `make validate` catches drift in CI

## Self-Check

- [x] `design.md` present in update-claude.sh loop
- [x] Loop alphabetically sorted (makes future drift visible)
- [x] Loop and manifest count match (30 == 30)
- [x] `make validate` green end-to-end
- [x] Negative smoke proves drift-check actually fails when drift exists
- [x] Atomic commits: 1 for loop fix, 1 for drift check
