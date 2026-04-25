---
phase: 14-audit-pipeline-fp-recheck-structured-reports
plan: 02
status: complete
completed: 2026-04-25
self_check: PASSED
requirements:
  - AUDIT-03
  - AUDIT-04
  - AUDIT-05
key_files:
  created:
    - components/audit-output-format.md
  modified: []
commits:
  - $(git log --oneline -1 components/audit-output-format.md | awk '{print $1}')
---

# Plan 14-02 Summary — Audit Output Format Component (report schema SOT)

## What Was Done

Created `components/audit-output-format.md` (245 lines) — single source of truth for the structured audit report. Phase 16 splices this body verbatim into 49 framework prompt files (OUTPUT FORMAT section); Phase 15's `/council audit-review` parser reads the section headings and slot strings byte-exact.

## Must-Haves Verification

| Truth | Status | Evidence |
|-------|--------|----------|
| File exists with structured report schema | ✓ | 245 lines, all required H2 sections present |
| Report path pattern verbatim per D-12 | ✓ | `grep -F '.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md'` returns 1 hit |
| YAML frontmatter with all 7 fields | ✓ | All 7 keys (`audit_type`, `timestamp`, `commit_sha`, `total_findings`, `skipped_allowlist`, `skipped_fp_recheck`, `council_pass`) found 2x each |
| Fixed section order (D-13) documented | ✓ | All 5 H2 headings (`## Summary`, `## Findings`, `## Skipped (allowlist)`, `## Skipped (FP recheck)`, `## Council verdict`) present |
| 9 entry fields in D-14 order | ✓ | `grep -cE '^[0-9]+\. \*\*(ID\|Severity\|Rule\|Location\|Claim\|Code\|Data flow\|Why it is real\|Suggested fix)\*\*'` returns 9 |
| Verbatim code block layout + extension map | ✓ | `<!-- File:` header + `Range clamped to file bounds` + 19-row extension table + `_unknown_` → `text` fallback |
| Council slot string byte-exact | ✓ | `_pending — run /council audit-review_` (em-dash U+2014) appears 2x (slot section + Full Report Skeleton) |
| 7 canonical type slugs in slug map | ✓ | `grep -cE '^\| `?(security\|code-review\|...)'` returns 7 |
| markdownlint clean | ✓ | `markdownlint components/audit-output-format.md` exit 0 |

## Key Links

| From | To | Status |
|------|----|--------|
| Council verdict slot string | Phase 15 parser | ✓ — byte-exact `_pending — run /council audit-review_` documented as contract |
| Severity field | `components/severity-levels.md` | ✓ — referenced 3x, never redefined |
| Allowlist parser | `commands/audit-restore.md` post-13-05 fix | ✓ — `sed '/^<!--/,/^-->/d'` pattern documented for HTML-comment-safe walks |

## Acceptance Criteria

All 24 grep-based criteria pass. File is splice-friendly for Phase 16 (no project-specific paths beyond `.claude/audits/` and `audit-exceptions.md`; no toolkit-internal references; H1 only at the top, body uses H2/H3 cleanly).

## Deviations

- **Trimmed prose** during execution to keep file ≤ 250 lines (plan ceiling). The Skipped (allowlist) and Skipped (FP recheck) sections originally had inline fenced examples; consolidated those into the Full Report Skeleton (single source of truth for verbatim layout) and kept only schema + parser-rule prose in the dedicated sections. The byte-exact constraints for the Council slot were folded into a single dense paragraph instead of a bullet list. No content lost — every grep target still matches.

## Self-Check

PASSED — all 24 acceptance criteria pass; markdownlint clean; line count within plan bounds (245 ≤ 250); SQL-INJECTION example used throughout (no DOM-write APIs, per plan's explicit constraint).

## Lessons Learned

- The `_None — no` allowlist empty-state placeholder originally embedded a backtick-quoted `audit-exceptions.md` reference inside a backtick-quoted display string, triggering MD038 (spaces inside code spans). Resolved by describing the placeholder's structure in prose and showing the verbatim form only inside the Full Report Skeleton's outer `text` fence. Lesson: nested backtick quoting is a markdownlint trap — prefer one level of code-span nesting at most.
- The plan's `<output_format>` XML wrapper around the Full Report Skeleton is a parser-stability discretion (D-15 + 14-PATTERNS analog). The XML opens/closes at top-level (not inside another fence), and the inner skeleton uses a `text` fence so nested ` ``` ` markers in the example are illustrated with placeholder text like `[fenced code block here]` rather than literal nested fences (which would break MD040 detection).

## Ready For

- Plan 14-03 (`commands/audit.md`) can now reference this component as the source for the report schema.
- Plan 14-04 (test fixture + script) can grep for the byte-exact strings (`<!-- File:`, `_pending — run /council audit-review_`, the 7 H2 headings, the 7 frontmatter keys).
- Phase 16 splices this body verbatim into 49 prompt files.
- Phase 15 Council parser greps for `## Council verdict` + `_pending — run /council audit-review_` to locate the slot.
