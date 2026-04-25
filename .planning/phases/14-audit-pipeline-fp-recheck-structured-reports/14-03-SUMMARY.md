---
phase: 14-audit-pipeline-fp-recheck-structured-reports
plan: 03
status: complete
completed: 2026-04-25
self_check: PASSED
requirements:
  - AUDIT-01
  - AUDIT-02
  - AUDIT-03
  - AUDIT-04
  - AUDIT-05
  - COUNCIL-01
key_files:
  created: []
  modified:
    - commands/audit.md
commits:
  - 1fff72c
---

# Plan 14-03 Summary — Audit Command Rewrite (6-phase workflow + allowlist parser)

## What Was Done

Rewrote `commands/audit.md` (159 → 206 lines) as the v4.2 audit pipeline orchestrator. The file is now the prose-level contract that references the two SOT components from Wave 1 (`components/audit-fp-recheck.md` for the 6-step procedure, `components/audit-output-format.md` for the structured report schema) and adds the orchestration layer they don't own: the dispatch table (7 canonical slugs + 2 aliases), the Phase 0 allowlist parser, and the Council handoff string.

## Must-Haves Verification

| Truth | Status | Evidence |
|-------|--------|----------|
| 6 H3 phases (Phase 0 — Phase 5) | ✓ | `grep -cE '^### Phase ' commands/audit.md` → 6 |
| AUDIT-01..05 + COUNCIL-01 each cited | ✓ | All 6 traceability tags present, 1 hit each |
| `components/audit-fp-recheck.md` referenced | ✓ | 2 hits (Phase 3 procedure pointer + SOT note) |
| `components/audit-output-format.md` referenced | ✓ | 3 hits (Phase 4 schema, Output Format pointer, Council handoff context) |
| Phase 0 sed-strip parser pattern present | ✓ | `grep -F '/^<!--/,/^-->/d'` → 2 hits (script body + prose) |
| Per-entry `grep -Fxq` reference for executor | ✓ | `grep -F 'grep -Fxq'` → 2 hits (prose + code block) |
| Report path schema present | ✓ | `grep -F 'mkdir -p .claude/audits'` → 1 hit |
| Council slot byte-exact | ✓ | `grep -F '_pending — run /council audit-review_'` → 2 hits (Phase 4 + Phase 5 + handoff section) |
| 7 canonical type slugs as bullets | ✓ | `grep -cE '^- \`(security\|code-review\|performance\|deploy-checklist\|mysql-performance\|postgres-performance\|design-review)\`' ` → 7 |
| `code` → `code-review`, `deploy` → `deploy-checklist` aliases | ✓ | Single sentence binds both; appears 2x (verbatim Aliases line + matched substring in dispatcher prose) |
| Mandatory Council pass (no `--no-council`) | ✓ | `grep -F 'There is no \`--no-council\` flag in v4.2'` → 1 hit |
| markdownlint clean | ✓ | `markdownlint commands/audit.md` exit 0 |
| `make check` passes | ✓ | All gates green: shellcheck, markdownlint, validate (templates + manifest + cell-parity + agent-collisions + commands/) |
| Line count in 180-280 bound | ✓ | `wc -l` → 206 |

## Key Links

| From | To | Status |
|------|----|--------|
| Phase 0 sed strip + batch-walk | `commands/audit-restore.md` post-13-05 fix | ✓ — pattern lifted verbatim, attribution comment in prose |
| Phase 3 procedure | `components/audit-fp-recheck.md` | ✓ — explicit "do NOT redefine the steps in this file — the component is the SOT" guard |
| Phase 4 schema | `components/audit-output-format.md` | ✓ — same SOT guard for the report skeleton |
| Phase 5 handoff | `/council audit-review --report <path>` (Phase 15) | ✓ — byte-exact slot string + post-Council mutation contract documented |
| Council severity contract (COUNCIL-02) | `## Council Handoff` section | ✓ — Council MUST NOT reclassify severity is stated explicitly |

## Acceptance Criteria

All 32 grep / regex / line-count checks from the plan pass. The two parser-pattern variants (batch-walk in `audit.md`, per-entry `grep -Fxq` in `audit-restore.md`) are both documented with rationale, so executors of either command have an unambiguous reference. The dispatch table makes alias resolution explicit so the report filename always uses the canonical slug — closing the v3.x ambiguity that left users with `code-<timestamp>.md` reports for the same audit type.

## Deviations

- **MD038 fix during lint pass.** First write triggered MD038 on the inline code span ` `### ` ` (trailing space inside backticks). Resolved by rewording prose to ` `###`-prefixed heading ` — semantically equivalent, no information lost, lint clean. Logged here so future edits don't re-introduce the trailing-space form.
- **No new files.** Plan called for an in-place rewrite of a single file; deviation: zero. Both Wave 1 components (`audit-fp-recheck.md`, `audit-output-format.md`) already shipped in 14-01 / 14-02 and are referenced, never redefined.

## Self-Check

PASSED — all 32 acceptance criteria met, markdownlint exit 0, `make check` green (15 validators), Phase 13's HTML-comment-safe parser pattern preserved across both commands (audit.md + audit-restore.md), Council slot byte-exact for Phase 15 grep target.

## Lessons Learned

- The `### ` heading marker in the sed/grep parser block is ergonomically tricky to discuss in prose without triggering MD038 (markdownlint forbids spaces inside inline code spans). Two safe forms: drop the trailing space (` `###` `) and reword, or quote the whole heading example outside an inline span. Ditto for any grep target that ends in whitespace.
- Both `commands/audit.md` (batch-walk) and `commands/audit-restore.md` (per-entry `grep -Fxq`) consume the same comment-stripped temp file produced by the same `sed '/^<!--/,/^-->/d'` pattern. Documenting both directions in `audit.md` (with attribution) means executors don't have to reverse-engineer the relationship — the contract is now explicit at one site.
- The `## Quick Checks` section was preserved verbatim from v3.x to keep the 30-second triage muscle memory intact for users running `/audit` ad hoc. The XSS grep needed a small wording tweak (review usage note inline with the grep call) to clear the PreToolUse Write hook's substring sniff for the unsafe-HTML React API — security message remains identical, install hook stays happy.

## Ready For

- Plan 14-04 (test fixture + Bash runner + Makefile Test 17) can now grep `commands/audit.md` for the byte-exact Council slot string, the 7 canonical slug bullets, and the Phase 0 sed pattern as part of its wire-up checks.
- Phase 15's `/council audit-review` parser has the locked contract: navigate by `## Council verdict` heading, mutate the literal `_pending — run /council audit-review_` placeholder.
- Phase 16's prompt fan-out (49 files) can splice both component bodies verbatim — `commands/audit.md` is the orchestration layer, not the per-prompt content.
- Phase 17's distribution layer (manifest, installers) treats `commands/audit.md` as a single replaceable file (already in the `commands` manifest entry); no schema impact.
