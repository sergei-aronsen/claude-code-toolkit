# Phase 14: Audit Pipeline — FP Recheck + Structured Reports - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Auto-generated (smart_discuss --auto, single-pass)

<domain>
## Phase Boundary

This phase rewires the **`/audit` orchestration** so every audit run:

1. **Reads** `.claude/rules/audit-exceptions.md` (created in Phase 13) at startup
   and drops matching findings.
2. **Re-validates** every surviving candidate finding against the actual code
   via a fixed 6-step FP recheck.
3. **Writes** a structured, parser-friendly report to
   `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md` with a fixed section schema.

The phase delivers the **pipeline contract** — Phase 15 plugs the Council into
the "Council verdict slot" produced here, Phase 16 propagates the SELF-CHECK +
OUTPUT FORMAT changes across 49 prompt files, Phase 17 wires the new
`commands/audit.md` and seed paths through `manifest.json` and CHANGELOG.

Out of scope here: Council orchestration (Phase 15), per-framework prompt
edits (Phase 16), manifest/installer changes (Phase 17). The artifacts this
phase ships must be consumable by those phases without further rewrites.

</domain>

<decisions>
## Implementation Decisions

### File Layout

- **D-01:** Extend `commands/audit.md` (currently 159 lines, simple dispatcher) with a
  6-phase workflow contract: (1) load context → (2) quick check → (3) deep analysis →
  (4) FP recheck → (5) structured report → (6) Council pass. Do **not** move logic into a
  Bash script — `audit.md` is interpreted by Claude at runtime, not executed by the shell.
  Extending the existing file preserves `manifest.json` paths and slash-command discovery.
- **D-02:** Create one new component: `components/audit-fp-recheck.md` — single source of
  truth for the 6-step recheck procedure. `commands/audit.md` references it; Phase 16
  copies it verbatim into the SELF-CHECK section of every framework prompt. One file, one
  edit point — no fan-out drift.
- **D-03:** Create one new component: `components/audit-output-format.md` — single source
  of truth for the structured report schema (Summary table → Findings → Skipped tables →
  Council verdict slot). Same fan-out discipline as D-02.
- **D-04:** Add `commands/audit.md` to `manifest.json` only if not already there (it is —
  per `manifest.json:files.commands`). The two new components live under
  `components/` and are NOT in the manifest (components are reference material that
  template authors compose; they do not ship into user `.claude/` dirs as standalone
  files). Phase 16 splices their content into prompt files; Phase 17 confirms manifest
  alignment.

### Allowlist Read (AUDIT-01)

- **D-05:** Phase 0 of `/audit` workflow: `read .claude/rules/audit-exceptions.md` if it
  exists. Parse `### <path>:<line> — <rule-id>` headings into a set of `path:line:rule`
  triples. Match candidate findings against this set; matching findings are removed from
  the main report and listed in a `## Skipped (allowlist)` table with columns: ID,
  path:line, rule, council_status (parsed from the entry's `**Council:**` bullet).
- **D-06:** When `audit-exceptions.md` is absent, the table renders as
  `## Skipped (allowlist)\n\n_None — no `audit-exceptions.md` in this project_` and the
  audit proceeds with no skips. Never refuse to run because the allowlist is missing.
- **D-07:** Match key is byte-exact: same em-dash (U+2014), same path, same line number,
  same rule-id. No fuzzy matching, no path normalization, no case folding. The
  allowlist's authority depends on the user being able to copy-paste a known triple and
  trust the match. (Mirrors Phase 13 D-06 duplicate-key strictness.)

### 6-Step FP Recheck (AUDIT-02)

- **D-08:** The recheck is a **prompt-level checklist**, not a runtime script. Each
  candidate finding goes through six numbered steps; the auditor (Claude executing the
  prompt) must produce a `## SELF-CHECK` block per finding before the finding can be
  reported. The six steps in fixed order:
  1. **Read context** — open the source file, load ±20 lines around `path:line`.
  2. **Trace data flow** — follow input from origin to the flagged sink, name each hop.
  3. **Check execution context** — identify whether the code runs in test/prod/worker/SW/build.
  4. **Cross-reference exceptions** — re-read `audit-exceptions.md` for related entries
     (same file, neighbouring lines) that change the threat surface.
  5. **Apply platform-constraint rule** — flag patterns required by the platform (MV3
     can't use dynamic importScripts, OAuth client_id must be in manifest, etc.).
  6. **Severity sanity check** — re-rate severity using the actual exploit scenario, not
     the rule label.
- **D-09:** Findings dropped at any step land in `## Skipped (FP recheck)` with columns:
  path:line, rule, dropped_at_step (1-6), one_line_reason. The reason MUST be ≤ 100 chars
  and grounded in the code, never "looks fine" or "trusted code".
- **D-10:** Findings that survive all six steps proceed to `## Findings`. Each gets the
  full entry schema (D-12).

### Verbatim Code Block (AUDIT-03)

- **D-11:** Every reported finding includes a fenced code block with:
  - **Language fence** matching the source extension (`.ts` → ` ```ts`, `.sh` → ` ```bash`,
    `.py` → ` ```python`, etc. — fall back to `text` for unknown extensions).
  - **Range comment header** as the first line *above* the fence:
    `<!-- File: <path> Lines: <start>-<end> -->`.
  - **±10 lines** around `path:line` (so a flagged line 42 produces lines 32–52). Clamp
    to file bounds; if file has 8 lines and finding is on line 5, render lines 1–8 with a
    note `<!-- Range clamped to file bounds (1-8) -->`.
  - **Verbatim** — copied byte-for-byte from the file. No ellipses, no redaction, no
    "for brevity" cuts. Council reasons from the actual code.

### Report Schema (AUDIT-04)

- **D-12:** Audit report path: `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md` where:
  - `<type>` is the audit type slug (`security`, `performance`, `code-review`,
    `deploy-checklist`, `mysql-performance`, `postgres-performance`, `design-review`).
  - Timestamp is local time, 24-hour, format `2026-04-25-1730`.
  - `.claude/audits/` is auto-created (`mkdir -p`) on first write. Add to `.gitignore`?
    **No** — audit reports are valuable artifacts; let the user decide what to commit.
- **D-13:** Fixed section order in the report (parser-friendly — Phase 15 Council reads
  this verbatim):
  1. **YAML frontmatter** — `audit_type`, `timestamp`, `commit_sha`, `total_findings`,
     `skipped_allowlist`, `skipped_fp_recheck`, `council_pass: pending`.
  2. `## Summary` — table with columns: severity, count_reported, count_skipped_allowlist,
     count_skipped_fp_recheck.
  3. `## Findings` — one `### Finding F-NNN` per surviving finding, full entry schema.
  4. `## Skipped (allowlist)` — table per D-05.
  5. `## Skipped (FP recheck)` — table per D-09.
  6. `## Council verdict` — placeholder block: `_pending — run /council audit-review_`
     (Phase 15 fills this slot with the per-finding verdict table).
- **D-14:** Each finding entry (`### Finding F-NNN`) has these required fields in order:
  - **ID:** `F-001` … `F-NNN` (zero-padded to 3 digits, sequential per report).
  - **Severity:** `CRITICAL | HIGH | MEDIUM | LOW`.
  - **Rule:** rule-id matching the auditor's rule-set (e.g. `SEC-XSS`, `PERF-N+1`).
  - **Location:** `<path>:<start>-<end>` for the range, or `<path>:<line>` for a point.
  - **Claim:** one-sentence statement of the alleged issue.
  - **Code:** verbatim block per D-11.
  - **Data flow:** narrative tracing input → flagged sink (markdown bullets, ≤ 6 hops).
  - **Why it is real:** 2–4 sentences referencing concrete tokens in the code block.
  - **Suggested fix:** code-shaped suggestion (diff-style or replacement snippet).

### Council Verdict Slot (handoff to Phase 15)

- **D-15:** Phase 14 ships the `## Council verdict` placeholder block. The actual Council
  invocation (`/council audit-review --report <path>`) is wired by Phase 15 (COUNCIL-01).
  The slot's exact text is `_pending — run /council audit-review_` — Phase 15 replaces
  this string with the verdict table. Don't reformat the slot here; Phase 15 depends on
  the literal string.

### Markdownlint Compliance

- **D-16:** Every markdown deliverable in this phase passes `npx markdownlint-cli`. The
  schema examples in `audit-output-format.md` use language tags on every fenced block
  (`text` for the report skeleton, `markdown` for entry templates). Section headings
  carry no trailing punctuation (MD026).

### Tests / Validation

- **D-17:** Add a regression fixture under `tests/fixtures/audit/` (or extend an existing
  fixtures dir if `make test` already has one): a tiny project tree with one allowlisted
  finding and one FP-recheck-droppable finding. The fixture is exercised by a new
  `make test-audit-pipeline` target that runs `bash -c '<audit invocation>'` against the
  fixture and asserts the report file path matches the timestamp pattern, the Skipped
  tables list the expected entries, and the Findings count is correct.
- **D-18:** No new external test runner — reuse the project's existing `make test` /
  shellcheck infrastructure. Heavy framework-level testing is out of scope (this is a
  prompt-driven pipeline, not a binary).

### Claude's Discretion

The planner has discretion on:

- The exact wording of each of the six SELF-CHECK steps in `audit-fp-recheck.md` (must
  preserve the numbered order and the dropped-at-step reporting rule, but bullet wording
  is up to the planner).
- Whether to template the report frontmatter and fenced examples in
  `audit-output-format.md` as a single `<output_format>` XML block or as a flat markdown
  example. Prefer XML for parser stability if uncertain.
- The exact fixture file count for D-17 — minimum one allowlist case, one FP-recheck
  case; can add more if it tightens the regression coverage.
- Whether to add a small Python or shell helper for parsing the report YAML frontmatter
  in tests (no new pip dependencies; stick to `awk`/`yq` if `yq` is already in CI).

</decisions>

<canonical_refs>
## Canonical References

Downstream agents (researcher, planner, executor) MUST read these before acting.

### Phase 13 artifacts (the input this phase consumes)

- `templates/base/rules/audit-exceptions.md` — seed schema (heading anchor, bullet
  format) the allowlist matcher in D-05/D-07 reads.
- `commands/audit-skip.md` — establishes the exact-triple match key (path:line + rule)
  reused for D-07.
- `commands/audit-restore.md` — same match key plus the HTML-comment-safety pattern
  (post-Phase-13-05); Phase 14's report parser must also be comment-aware if it walks
  `audit-exceptions.md` for council_status.

### Existing toolkit files

- `commands/audit.md` — the file Phase 14 extends (current 159 lines). Existing usage:
  audit type selection, prompt routing.
- `templates/base/prompts/SECURITY_AUDIT.md` — current audit prompt format. Phase 16
  copies the new SELF-CHECK + OUTPUT FORMAT into this and 48 sibling prompt files.
- `manifest.json` `files.commands` — confirms `audit.md` is already listed; D-04 holds.
- `.markdownlint.json` — lint rules every new markdown file must satisfy (MD040 / MD031 /
  MD032 / MD026, plus repo-specific MD024.siblings_only and MD029.style=ordered).
- `Makefile` — `make check` and `make test` are the local quality gates; D-17 adds one
  target here.
- `.github/workflows/quality.yml` — CI mirror; new validation must pass on
  `ubuntu-latest`.

### Standards

- `.planning/REQUIREMENTS.md` — AUDIT-01..AUDIT-05 verbatim acceptance criteria.
- `.planning/ROADMAP.md` Phase 14 section — the 5 success criteria are the must-haves.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`commands/audit.md`** — the file we extend. Existing 6 audit types (`security`,
  `code-review`, `performance`, `deploy-checklist`, `mysql-performance`,
  `postgres-performance`, `design-review`).
- **`commands/audit-skip.md` / `commands/audit-restore.md`** — establish the
  `path:line:rule` triple as the canonical FP key. Phase 14 reuses this exact key for
  allowlist matching.
- **`templates/base/rules/audit-exceptions.md`** — the seed file Phase 14 reads. Already
  ships with `globs: ["**/*"]`, `## Entries` H2, and an HTML-commented example block.
- **`components/severity-levels.md`** (if exists — verify in scout) — severity rubric
  reused by D-14's Severity field.

### Established Patterns

- **Markdown-as-code** — `commands/*.md` are the runtime; no Bash compilation step. The
  audit pipeline lives in prompts, not scripts. Phase 14's "implementation" is mostly
  authoring `commands/audit.md` and two `components/*.md` files.
- **One source of truth, fan-out via Phase 16** — Phase 14 owns the canonical SELF-CHECK
  and OUTPUT FORMAT components; Phase 16 propagates them. No copy-pasted prompt logic.
- **Markdownlint as gate** — every shipped `.md` file must pass `make check`. CI
  enforces.
- **Conventional Commits** — `feat(14-XX): ...`, `docs(14-XX): ...` per Phase 13's
  established commit style.

### Integration Points

- `commands/audit.md` already in `manifest.json` (no manifest change needed for
  extension).
- New `components/audit-fp-recheck.md` and `components/audit-output-format.md` live
  outside the manifest (consumed by Phase 16 prompt edits).
- `.claude/audits/` is a runtime-created directory, not part of the toolkit ship; no
  installer change needed.
- Phase 15 (`/council audit-review`) reads the report's YAML frontmatter and the
  `## Findings` block — D-13 / D-14 lock the schema Phase 15 depends on.

</code_context>

<specifics>
## Specific Ideas

- The 6-step FP recheck order is from REQUIREMENTS.md AUDIT-02 verbatim. Do not reorder.
- The report path pattern `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md` is from AUDIT-04
  verbatim. The 4-digit time is HHMM (no separator), local time.
- The Council verdict slot text `_pending — run /council audit-review_` is the literal
  handoff string — Phase 15 will grep for this exact byte sequence.
- The 6 audit types in `commands/audit.md` (`security`, `code-review`, `performance`,
  `deploy-checklist`, `mysql-performance`, `postgres-performance`, `design-review`) are
  the slug source for `<type>` in D-12. Match the existing slugs byte-for-byte.

</specifics>

<deferred>
## Deferred Ideas

- **Auto-write Council verdicts back to `audit-exceptions.md`** — explicitly forbidden by
  COUNCIL-05 (Phase 15). User must invoke `/audit-skip` manually.
- **Sentry/Linear ticket creation per CONFIRMED finding** — out of v4.2 scope per
  REQUIREMENTS.md "Future Requirements".
- **Migrating prior audit reports to the new schema** — explicitly out of scope per
  REQUIREMENTS.md "Out of Scope".
- **`--no-council` flag** — explicitly forbidden in v4.2 per COUNCIL-01.
- **Severity reclassification by Council** — explicitly forbidden by COUNCIL-02.
- **Wave B/C hardening from v4.1 audit (compat matrix, merge strategy, version pinning,
  collision detection policy, provenance metadata)** — separate milestone per
  REQUIREMENTS.md.

</deferred>

---

*Phase: 14-audit-pipeline-fp-recheck-structured-reports*
*Context gathered: 2026-04-25 via smart_discuss --auto (locked decisions derived from REQUIREMENTS.md AUDIT-01..05 + ROADMAP success criteria)*
