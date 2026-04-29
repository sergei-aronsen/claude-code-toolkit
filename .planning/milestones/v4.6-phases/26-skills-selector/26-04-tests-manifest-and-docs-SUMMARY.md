---
phase: 26
plan: "04"
subsystem: skills-selector
tags: [tests, manifest, docs, ci, makefile]
dependency_graph:
  requires: ["26-01", "26-02", "26-03"]
  provides: ["SKILL-04", "SKILL-05"]
  affects: ["manifest.json", "Makefile", ".github/workflows/quality.yml", "docs/SKILLS-MIRROR.md", "docs/INSTALL.md"]
tech_stack:
  added: []
  patterns: ["hermetic-test-sandbox", "mktemp+trap-RETURN", "TK_SKILLS_HOME-seam", "manifest-driven-update"]
key_files:
  created:
    - scripts/tests/test-install-skills.sh
    - docs/SKILLS-MIRROR.md
  modified:
    - manifest.json
    - Makefile
    - .github/workflows/quality.yml
    - docs/INSTALL.md
decisions:
  - "sync-skills-mirror.sh NOT added to manifest.json — it is a maintainer-only tool, not shipped via curl|bash"
  - "Upstream URLs set to https://skills.sh/<name> placeholders — real URLs filled on first re-sync"
  - "Bare URLs in SKILLS-MIRROR.md table wrapped in angle brackets to satisfy MD034"
metrics:
  duration: "~20 min"
  completed: "2026-04-29"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 4
---

# Phase 26 Plan 04: Tests, Manifest, and Docs Summary

**One-liner:** Hermetic 15-assertion test (SKILL-04), manifest registration of 22 marketplace skills (SKILL-05), Makefile Test 33 + CI Tests 21-33 wiring, and SKILLS-MIRROR.md + INSTALL.md --skills docs.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Hermetic test suite (≥12 assertions) | `1891c5f` | scripts/tests/test-install-skills.sh |
| 2 | Manifest + Makefile + CI wiring | `2884d9e` | manifest.json, Makefile, .github/workflows/quality.yml |
| 3 | SKILLS-MIRROR.md + INSTALL.md --skills subsection | `6f86a18` | docs/SKILLS-MIRROR.md, docs/INSTALL.md |

## Assertion count

Final: **PASS=15 FAIL=0** (target was ≥12 — delivered 15).

Scenarios:

- S1 catalog_correctness: 3 assertions (22 entries, alpha first, alpha last)
- S2 detection_two_state: 2 assertions (installed=0, absent=1)
- S3 skills_install_basic: 3 assertions (rc=0, dir exists, SKILL.md copied)
- S4 idempotency_no_force: 2 assertions (rc=2, sentinel preserved)
- S5 force_overwrite: 2 assertions (rc=0, stale file destroyed)
- S6 install_sh_dry_run: 3 assertions (exit 0, 22 would-install rows, zero mutations)

## manifest.json diff summary

Added 23 new entries total:

- `files.libs[]`: +1 entry (`scripts/lib/skills.sh`) — alphabetically between optional-plugins.sh and state.sh
- `files.skills_marketplace[]`: +22 entries (all templates/skills-marketplace/<name> dirs, alphabetical)

Decision: `scripts/sync-skills-mirror.sh` was NOT added to manifest. It is a
maintainer-only re-sync tool (invoked from a local clone), not shipped via
`curl | bash` to end-users. Documented in SKILLS-MIRROR.md re-sync procedure.

## BACKCOMPAT invariant results

All four invariants green after Task 2 manifest + CI edits:

| Test | Result |
|------|--------|
| test-bootstrap.sh | PASS=26 FAIL=0 |
| test-install-tui.sh | PASS=38 FAIL=0 |
| test-mcp-selector.sh | PASS=21 FAIL=0 |
| test-update-libs.sh | PASS=15 FAIL=0 |

LIB-01 D-07 invariant confirmed: `update-claude.sh` auto-discovers
`files.skills_marketplace[]` via the existing `.files | to_entries[] | .value[] | .path`
jq path — zero new code required.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] MD034 bare URL in SKILLS-MIRROR.md table**

- **Found during:** Task 3 markdownlint run
- **Issue:** 22 table cells contained bare `https://skills.sh/...` URLs failing MD034
- **Fix:** Wrapped all 22 URLs in angle brackets (`<https://...>`)
- **Files modified:** docs/SKILLS-MIRROR.md
- **Commit:** `6f86a18` (fixed before commit, same task)

None beyond the above auto-fix.

## Known Stubs

- **Upstream URLs in SKILLS-MIRROR.md:** All 22 skill rows use `https://skills.sh/<name>`
  as placeholder URLs. These are honest placeholders — the actual skills.sh upstream URLs
  were not available in the planning context. The maintainer fills them in during the
  first real `sync-skills-mirror.sh` run and updates the table. This does not block the
  plan's goal (docs are complete and accurate for everything except the exact upstream URL).

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes
at trust boundaries introduced in this plan. Test files operate in sandbox tmpdir.
The manifest addition is read-only metadata.

## Self-Check: PASSED

Files exist:

- `scripts/tests/test-install-skills.sh` — FOUND
- `docs/SKILLS-MIRROR.md` — FOUND
- `docs/INSTALL.md` (modified) — FOUND
- `manifest.json` (modified) — FOUND
- `Makefile` (modified) — FOUND
- `.github/workflows/quality.yml` (modified) — FOUND

Commits exist:

- `1891c5f` — FOUND (test-install-skills.sh)
- `2884d9e` — FOUND (manifest + Makefile + CI)
- `6f86a18` — FOUND (docs)

Gate checks:

- `bash scripts/tests/test-install-skills.sh` → PASS=15 FAIL=0
- `bash scripts/tests/test-update-libs.sh` → PASS=15 FAIL=0
- `bash scripts/tests/test-bootstrap.sh` → PASS=26 FAIL=0
- `bash scripts/tests/test-install-tui.sh` → PASS=38 FAIL=0
- `bash scripts/tests/test-mcp-selector.sh` → PASS=21 FAIL=0
- `jq '.files.skills_marketplace | length' manifest.json` → 22
- `python3 scripts/validate-manifest.py` → PASSED
- `make test-install-skills` → PASS=15 FAIL=0
- `make check` → All checks passed
- `markdownlint docs/SKILLS-MIRROR.md docs/INSTALL.md` → 0 errors
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` → exit 0
