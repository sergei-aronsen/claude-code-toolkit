---
phase: 27-marketplace-publishing-claude-desktop-reach
plan: "04"
subsystem: docs
tags: [markdown, manifest, changelog, desktop, marketplace, desk-01, mkt-04, version-bump]

requires:
  - phase: 27-01-marketplace-surface
    provides: .claude-plugin/marketplace.json + plugins/tk-{skills,commands,framework-rules} trees
  - phase: 27-02-validators-and-make-wiring
    provides: scripts/validate-marketplace.sh + scripts/validate-skills-desktop.sh + make check wiring
  - phase: 27-03-install-sh-desktop-routing
    provides: --skills-only flag + DESK-03 auto-routing in scripts/install.sh

provides:
  - docs/CLAUDE_DESKTOP.md: 4-column capability matrix (DESK-01)
  - README.md marketplace install subsection with both /plugin and claude CLI forms (MKT-04)
  - docs/INSTALL.md marketplace section + Claude Desktop users subsection + --skills-only flag docs
  - manifest.json version 4.6.0 (final v4.6 milestone bump)
  - manifest.json files.scripts[] registering validate-marketplace.sh + validate-skills-desktop.sh
  - CHANGELOG.md [4.6.0] entry consolidating Phase 24-27 deliverables (8 Added + 3 Changed)

affects:
  - future phases reading manifest.json (version now 4.6.0)
  - users discovering toolkit via marketplace or docs

tech-stack:
  added: []
  patterns:
    - "Marketplace install docs pattern: document both /plugin slash-command and claude CLI forms"
    - "CHANGELOG consolidation pattern: one [X.Y.Z] entry per milestone (mirrors v4.4 approach)"

key-files:
  created:
    - docs/CLAUDE_DESKTOP.md
  modified:
    - README.md
    - docs/INSTALL.md
    - manifest.json
    - CHANGELOG.md

key-decisions:
  - "README marketplace section includes both /plugin slash-command form and claude CLI form (plan's acceptance criteria required the CLI form)"
  - "manifest.json files.scripts[] sorted alphabetically: install.sh, uninstall.sh, validate-marketplace.sh, validate-skills-desktop.sh"
  - ".claude-plugin/marketplace.json and plugins/ trees NOT added to manifest.json — they are repo-side metadata, not user-installable files"
  - "CHANGELOG [4.6.0] uses >= symbol instead of ≥ unicode to avoid any encoding issues in CI grep"

patterns-established:
  - "Capability matrix docs pattern: 4-column table (Capability x Desktop Code Tab x Desktop Chat Tab x Code Terminal) with available/unavailable verdicts"

requirements-completed: [DESK-01, MKT-04]

version_align_result: "✅ Version aligned: 4.6.0"
make_check_result: "exit 0 — All checks passed!"

duration: 12min
completed: 2026-04-29
---

# Phase 27 Plan 04: Docs, Manifest, and CHANGELOG Summary

**`docs/CLAUDE_DESKTOP.md` capability matrix + marketplace install sections in README/INSTALL.md + manifest bumped 4.4.0 → 4.6.0 + CHANGELOG [4.6.0] consolidating Phase 24-27 — v4.6 milestone content-complete**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-29T15:00:00Z
- **Completed:** 2026-04-29T15:12:00Z
- **Tasks:** 2
- **Files modified:** 5 (1 created + 4 modified)

## Accomplishments

- Created `docs/CLAUDE_DESKTOP.md` (94 lines, under 1-minute read target): 4-column capability matrix covering skills, slash commands, MCPs, statusline, security pack, and framework rules; explains why Chat tab and remote sessions block plugins; install instructions for both Desktop (marketplace) and terminal (curl-bash) paths
- Updated `README.md` with "Install via marketplace" subsection including both the `/plugin` slash-command form and the `claude plugin marketplace add` CLI form, plus link to CLAUDE_DESKTOP.md
- Updated `docs/INSTALL.md` with "Install via marketplace" section (sub-plugin table), "Claude Desktop users" subsection, and "--skills-only flag" subsection documenting the auto-routing banner
- Bumped `manifest.json` from 4.4.0 to 4.6.0, updated timestamp to 2026-04-29, added `scripts/validate-marketplace.sh` and `scripts/validate-skills-desktop.sh` to `files.scripts[]` (alphabetical order)
- Added CHANGELOG `[4.6.0] - 2026-04-29` entry with 8 Added bullets covering TUI installer, MCP catalog, skills mirror, plugin marketplace, validators, Desktop routing, capability matrix, and marketplace docs — plus 3 Changed bullets

## Task Commits

1. **Task 1: CLAUDE_DESKTOP.md + README + INSTALL.md** - `79b211a` (docs)
2. **Task 2: manifest.json bump + CHANGELOG [4.6.0]** - `2515df6` (chore)

**Plan metadata:** (created below as final commit)

## Files Created/Modified

- `docs/CLAUDE_DESKTOP.md` — New: 4-column Desktop capability matrix, marketplace install instructions, curl-bash install path, skills-only auto-route explanation, limitations section (94 lines)
- `README.md` — Added "Install via marketplace" subsection after "### Complement install": /plugin slash-command + claude CLI forms, sub-plugin list, link to CLAUDE_DESKTOP.md
- `docs/INSTALL.md` — Added "Install via marketplace" section (sub-plugin table + install command + equivalence note), "Claude Desktop users" subsection (link to CLAUDE_DESKTOP.md), "--skills-only flag" subsection (explicit flag + auto-routing banner example)
- `manifest.json` — version 4.4.0 → 4.6.0, updated 2026-04-27 → 2026-04-29, scripts array: added validate-marketplace.sh + validate-skills-desktop.sh (alphabetical after uninstall.sh)
- `CHANGELOG.md` — New [4.6.0] - 2026-04-29 section at top (before [4.4.0])

## manifest.json files.scripts[] — Final State

Added entries sorted alphabetically:

```json
[
  { "path": "scripts/install.sh" },
  { "path": "scripts/uninstall.sh" },
  { "path": "scripts/validate-marketplace.sh" },
  { "path": "scripts/validate-skills-desktop.sh" }
]
```

`validate-marketplace.sh` and `validate-skills-desktop.sh` land after the existing entries, in `v*` alphabetical position. `.claude-plugin/marketplace.json` and the `plugins/` sub-plugin trees are intentionally NOT in manifest.json — they are repo-side marketplace metadata, not user-installable files distributed via curl-bash.

## Version Alignment

```text
make version-align output:
Checking version alignment (manifest.json <-> CHANGELOG.md <-> init-local.sh)...
✅ Version aligned: 4.6.0
```

`init-local.sh --version` derives from `manifest.json` at runtime (line 18: `VERSION=$(jq -r '.version' "$MANIFEST_FILE")`), so no script edits were needed to complete the alignment.

## Decisions Made

- **Both install command forms in README:** The plan acceptance criteria required `grep -q "claude plugin marketplace add" README.md`, but the plan's template showed only the `/plugin` slash-command form. Added both forms (slash-command in a `text` block + CLI form in a `bash` block) to satisfy both the user experience (Desktop users use the slash-command) and the acceptance criterion.
- **Alphabetical scripts order:** Reordered existing `install.sh` / `uninstall.sh` entries to true alphabetical order (`i` before `u`) while adding the new `v*` entries, keeping the array consistent.
- **>= instead of ≥ in CHANGELOG:** Used ASCII `>=` rather than Unicode `≥` in the CHANGELOG bullet for the validator threshold to avoid potential grep/CI encoding issues.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added CLI form of marketplace install command to README**

- **Found during:** Task 1 verification (`grep -q "claude plugin marketplace add" README.md` failed)
- **Issue:** Plan template Step B showed only `/plugin marketplace add sergei-aronsen/claude-code-toolkit` (slash-command form), but the acceptance criteria explicitly required the string `claude plugin marketplace add` to appear in README.md
- **Fix:** Added a second code block with the `claude` CLI form alongside the slash-command form
- **Files modified:** README.md
- **Verification:** `grep -q "claude plugin marketplace add" README.md` exits 0
- **Committed in:** 79b211a (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing content to satisfy documented acceptance criteria)
**Impact on plan:** Minor additive fix. The CLI form is genuinely useful for terminal users; adding it improves the docs.

## Issues Encountered

None — all checks passed on first run after fixes.

## v4.6 Milestone Status

**Content-complete.** All four plans in Phase 27 are shipped:

| Plan | Name | Key Delivery |
|------|------|-------------|
| 27-01 | Marketplace Surface | .claude-plugin/marketplace.json + 3 sub-plugins |
| 27-02 | Validators + Make Wiring | validate-marketplace.sh + validate-skills-desktop.sh + CI |
| 27-03 | install.sh Desktop Routing | --skills-only + DESK-03 auto-routing |
| 27-04 | Docs + Manifest + CHANGELOG | CLAUDE_DESKTOP.md + marketplace docs + v4.6.0 bump |

The only remaining step is the maintainer manual task: `git tag v4.6.0` (per CLAUDE.md "never push directly to main").

## Known Stubs

None — all documentation references real implemented functionality from Plans 27-01..03.

## Threat Flags

None — this plan adds only documentation and version metadata. No new network endpoints, auth paths, file access patterns, or schema changes.

## Next Phase Readiness

- v4.6 milestone is content-complete; maintainer tags `v4.6.0` to ship
- Phase 27 branch ready to merge to main after PR review
- `docs/CLAUDE_DESKTOP.md` serves as the canonical reference for all future Desktop-capability documentation

## Self-Check

### Files exist

- `docs/CLAUDE_DESKTOP.md` — created (yes)
- `README.md` — modified with marketplace section (yes)
- `docs/INSTALL.md` — modified with marketplace + skills-only sections (yes)
- `manifest.json` — version 4.6.0, updated 2026-04-29, 4 scripts entries (yes)
- `CHANGELOG.md` — [4.6.0] - 2026-04-29 at top (yes)

### Commits exist

- 79b211a: docs(27): add CLAUDE_DESKTOP.md capability matrix + marketplace install sections
- 2515df6: chore(27): bump manifest 4.4.0 → 4.6.0, register validators, consolidate v4.6 CHANGELOG

## Self-Check: PASSED

---
*Phase: 27-marketplace-publishing-claude-desktop-reach*
*Completed: 2026-04-29*
