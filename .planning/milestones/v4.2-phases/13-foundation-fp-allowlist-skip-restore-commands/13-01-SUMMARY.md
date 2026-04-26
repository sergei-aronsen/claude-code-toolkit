---
phase: 13-foundation-fp-allowlist-skip-restore-commands
plan: 01
subsystem: rules
tags: [audit, allowlist, false-positive, markdownlint, rules, templates]

requires: []

provides:
  - "Seed template templates/base/rules/audit-exceptions.md with globs frontmatter for auto-load"
  - "Entry schema (### path:line — rule-id headings + Date/Council/Reason bullets) for /audit-skip and /audit-restore"
  - "HTML-commented example block showing schema without creating a real suppression entry"
  - "Prompt-injection defense paragraph in file body"

affects:
  - 13-02-audit-skip-command
  - 13-03-audit-restore-command
  - 13-04-installer-seeding
  - 14-audit-pipeline-integration

tech-stack:
  added: []
  patterns:
    - "Rule file frontmatter: description + globs list form (matching project-context.md precedent)"
    - "HTML comment for schema example: visible to users, invisible to parsers"
    - "Seed-not-in-manifest: mutable project-local files seeded inline by installers, not tracked in manifest.json"

key-files:
  created:
    - templates/base/rules/audit-exceptions.md
  modified: []

key-decisions:
  - "globs uses YAML list form (  - \"**/*\") not inline-array form, matching project-context.md precedent"
  - "Example entry lives inside HTML comment so it is invisible to /audit-skip duplicate detector and /audit parsers"
  - "File NOT registered in manifest.json per CD-01: seeded inline by installers (Plan 13-04)"
  - "Em-dash separator in headings is U+2014, not hyphen or en-dash, matching repo heading convention"
  - "Prompt-injection defense: explicit instruction to Claude to treat Reason fields as data, not directives"

patterns-established:
  - "Entry anchor pattern: ### <path>:<line> — <rule-id> (parseable by ^### .+:\\d+ — .+$ regex)"
  - "Bullet labels: **Date:** , **Council:** , **Reason:** (bold-cased, colon inside bold, trailing space)"
  - "Council enum: unreviewed | council_confirmed_fp | disputed (snake_case, vertical bars)"

requirements-completed:
  - EXC-03

duration: 4min
completed: 2026-04-25
---

# Phase 13 Plan 01: Audit Exceptions Seed Template Summary

**Markdownlint-clean seed file establishing the FP allowlist storage schema with auto-load globs frontmatter and HTML-commented entry example for /audit-skip and /audit-restore parsers**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-25T14:20:00Z
- **Completed:** 2026-04-25T14:21:13Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `templates/base/rules/audit-exceptions.md` with exact byte-level schema matching plan specification
- Verified markdownlint passes (exit 0, `make lint` clean)
- Confirmed file is absent from `manifest.json` per CD-01 decision

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the audit-exceptions.md seed template** - `b6e18b5` (feat)

**Plan metadata:** (pending — docs commit)

## Files Created/Modified

- `templates/base/rules/audit-exceptions.md` - FP allowlist seed template, auto-loaded via `globs: ["**/*"]`, establishes entry schema for Plans 13-02 and 13-03

## Byte-Level Decisions

| Decision | Value | Verification |
|---|---|---|
| Em-dash separator | U+2014 (`—`) | `grep -c $'—' file` returns 3 |
| globs form | YAML list (`  - "**/*"`) | `grep -q '^  - "\*\*/\*"$' file` passes |
| Bullet labels | `**Date:** `, `**Council:** `, `**Reason:** ` | grep checks all pass |
| Council enum | `unreviewed | council_confirmed_fp | disputed` | grep check passes |
| Example block | Inside `<!-- -->` HTML comment | Not a parseable entry |
| manifest.json | Not referenced | `grep -F 'audit-exceptions.md' manifest.json` exits 1 |

## Markdownlint Compliance

- `markdownlint templates/base/rules/audit-exceptions.md` → exit 0
- `make lint` → exit 0 (ShellCheck + markdownlint both pass)
- MD026 (no trailing punct on headings): satisfied — H1 has em-dash separator body, no colon/period
- MD031/MD032 (blank lines around code/lists): satisfied — blank lines before/after `## Entries` and comment block
- MD040 (fenced code language): satisfied — no fenced code blocks in file
- MD033 (inline HTML): disabled in `.markdownlint.json`, HTML comment allowed

## Decisions Made

- YAML list form for globs matches `project-context.md` precedent exactly
- Example entry placed inside HTML comment so `/audit-skip` duplicate detector does not see it
- File intentionally not added to `manifest.json` — it is mutable project state seeded by installers (Plan 13-04)
- Prompt-injection defense paragraph added per T-13-01 threat model mitigation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. `npx markdownlint-cli` failed (no `package.json`); used system `markdownlint` binary instead — same result, exit 0.

## Known Stubs

None — this is a seed template with no data stubs. The `## Entries` section is intentionally empty (real entries are appended by `/audit-skip` at runtime).

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced. The auto-load surface via `globs: ["**/*"]` was explicitly modeled in the plan's threat register (T-13-01) and mitigated by the prompt-injection defense paragraph.

## Next Phase Readiness

- Plan 13-02 (`/audit-skip`) can reference the heading anchor pattern `^### .+:\d+ — .+$` and bullet labels defined here
- Plan 13-03 (`/audit-restore`) can use the same triple match key and entry schema
- Plan 13-04 (installers) can copy the seed body verbatim into heredoc blocks in `init-claude.sh`, `init-local.sh`, and `update-claude.sh`
- Phase 14 (`/audit` consumer) has a confirmed empty-of-real-entries file to read from

---

*Phase: 13-foundation-fp-allowlist-skip-restore-commands*
*Completed: 2026-04-25*
