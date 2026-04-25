# Phase 16: Template Propagation — 49 Prompt Files - Context

**Gathered:** 2026-04-26
**Status:** Ready for planning
**Mode:** Auto-generated (gsd-discuss-phase --auto, single pass)

<domain>
## Phase Boundary

This phase fans out the v4.2 audit pipeline contracts (the SOT components written in Phase 14 and the Council handoff cemented in Phase 15) across **all 49 framework audit prompt files** under `templates/{base,laravel,rails,nextjs,nodejs,python,go}/prompts/{SECURITY_AUDIT,CODE_REVIEW,PERFORMANCE_AUDIT,MYSQL_PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,DEPLOY_CHECKLIST,DESIGN_REVIEW}.md` (7 frameworks × 7 audit types = 49 files). Every prompt file ends Phase 16 with:

1. A top-of-file callout pointing readers (Claude executing the audit) to `.claude/rules/audit-exceptions.md` so the auditor knows the allowlist exists and is consulted before reporting findings.
2. The canonical 6-step FP-recheck SELF-CHECK section spliced verbatim from `components/audit-fp-recheck.md` — replaces or augments any pre-existing free-form `## SELF-CHECK` section.
3. The structured OUTPUT FORMAT section spliced verbatim from `components/audit-output-format.md` — adds the YAML frontmatter contract, fixed section order, 9-field finding entry schema, and the Council verdict slot.
4. A "Council Handoff" footer section pointing to `commands/audit.md` Phase 5 + `commands/council.md` audit-review mode so the auditor knows the run terminates with a Council pass.

The phase delivers two artefacts:

- **One Bash splice script** (`scripts/propagate-audit-pipeline-v42.sh`) — idempotent, deterministic; it walks the 49 files, detects already-spliced files, and inserts the four blocks at canonical insertion points. The script ships in the repo so future framework templates added in v4.3+ can reuse it.
- **Updated CI gate** (`make validate` + `.github/workflows/quality.yml`) — extends the existing audit-prompt validation loop to assert each updated prompt file contains the literal markers `Council handoff` and `1. **Read context**` (the first FP-recheck step label, byte-exact from `components/audit-fp-recheck.md`). Missing markers fail the build.

Out of scope for this phase: the `manifest.json` distribution wiring (Phase 17 picks up new files), the `setup-council.sh` install path for the Phase 15 prompt under `scripts/council/prompts/` (Phase 17 also handles), and any prompt content edits beyond the four spliced blocks (Phase 17 won't touch prompt text either — Phase 16 is the only phase that mass-edits prompts in v4.2).

</domain>

<decisions>
## Implementation Decisions

### Splice Strategy

- **D-01:** Implement the fan-out as a single Bash script `scripts/propagate-audit-pipeline-v42.sh` rather than 49 hand edits. Reasons: (1) markdownlint compliance is easier to enforce when the inserted blocks are templated literals; (2) idempotency check (re-running the script must produce zero diffs on already-spliced files) is built-in; (3) future framework templates added in v4.3+ can be propagated by re-running the script.
- **D-02:** The script reads `components/audit-fp-recheck.md` and `components/audit-output-format.md` from disk at run time — never duplicates their bodies. This guarantees Phase 14's SOT discipline holds: when a future PR edits the SOT components, re-running `propagate-audit-pipeline-v42.sh` re-syncs the 49 prompts.
- **D-03:** The script processes one file at a time, in deterministic order (`find templates -path "*/prompts/*.md" | sort`). Each file is read fully into memory, the four blocks inserted at canonical insertion points, then atomically rewritten with `tempfile + mv`.
- **D-04:** The script lives in `scripts/` (not `scripts/tests/` or `components/`) because it is a one-shot-but-reusable maintenance operation, not a test runner and not a component. The README inside `scripts/` should mention what it does.

### Block Insertion Points (per file)

- **D-05:** **Top-of-file callout** — inserted as the first non-frontmatter line below the H1 title and any existing tagline paragraph. Format: a 2-3 line HTML comment block referencing `.claude/rules/audit-exceptions.md` so it is visible to humans reading raw Markdown but invisible in rendered output. This avoids visual clutter while keeping the cross-reference parseable for tooling. The Claude executing the prompt reads HTML comments — the callout reaches its intended audience.
- **D-06:** **6-step FP-recheck SELF-CHECK section** — inserted just before any existing `## NN. SELF-CHECK` heading in the file (replacing the section's body but preserving the heading number) OR appended above the file's "report format" section if no SELF-CHECK exists. The spliced body is the body of `components/audit-fp-recheck.md` (Procedure section + Skipped (FP recheck) Entry Format + Anti-Patterns), preserving its `1. **Read context**` ... `6. **Severity sanity check**` numbering byte-exact. Inserted under an H2 heading `## NN. SELF-CHECK (FP Recheck — 6-Step Procedure)` where `NN` is whatever number the prompt's existing section sequencing dictates (the script preserves the existing numeric prefix when it replaces an existing SELF-CHECK; otherwise it picks the next free integer).
- **D-07:** **Structured OUTPUT FORMAT section** — inserted at the bottom of the file, AFTER any existing "report format" or output template section. The spliced body is the body of `components/audit-output-format.md` from `## Report Path` through `## Full Report Skeleton` inclusive. Inserted under an H2 heading `## NN+1. OUTPUT FORMAT (Structured Report Schema — Phase 14)` so the section number sequences naturally. If a prompt already has a `## ФОРМАТ ОТЧЁТА` or `## OUTPUT FORMAT` section with custom content, the script appends the new structured schema BELOW the existing section without deleting it (preserves prior tribal knowledge per TEMPLATE-02).
- **D-08:** **"Council Handoff" footer** — inserted as the LAST H2 section of the file, after OUTPUT FORMAT. Format: 1-paragraph prose pointing to `commands/audit.md` Phase 5 (Council Pass mandatory) and `commands/council.md` `## Modes` section (audit-review mode). Quotes the byte-exact slot string `_pending — run /council audit-review_` (em-dash U+2014) so the auditor knows where its output gets handed off to.

### Idempotency

- **D-09:** Re-running the script on an already-spliced file MUST produce zero diff (`git diff` returns empty). Detection: each spliced block carries a sentinel comment line (e.g., `<!-- v42-splice: fp-recheck-section -->`) that the script grep-greps before inserting. If all four sentinels are present, the file is skipped with a `[skip] already-spliced` log line. If 1-3 sentinels present, the script aborts with a "partial-splice detected" error so a human can resolve manually (avoids data loss from re-inserting only some blocks).
- **D-10:** The script writes a one-line summary at the end: `Processed N files: M spliced, K already-spliced, P skipped (errors)`. Exit code: 0 on full success, 1 on any error.

### Language Preservation (TEMPLATE-02)

- **D-11:** No translation drift introduced. Codebase audit during context prep showed all 49 prompt files are currently English-language (Cyrillic check: 0 of 49). Spliced blocks (FP-recheck procedure, OUTPUT FORMAT, Council handoff prose, top-of-file callout) ship in English to match. If a future contributor authors a new prompt file in Russian (or another language) and runs the splice script, the spliced blocks remain English — those blocks are byte-exact contracts that Phase 14 + Phase 15 tooling reads, not localized prose. Contributors can localize the surrounding prompt text, but the four contract blocks stay English.
- **D-12:** TEMPLATE-02 enforcement: the script does NOT touch any line OUTSIDE the four insertion points. No regex search-and-replace across the whole file. Existing English prose stays English; existing Russian prose (none today, hypothetical future) stays Russian.

### CI Gate Extension (TEMPLATE-03)

- **D-13:** Extend `Makefile`'s `validate` target audit-prompt loop to assert both new markers per file: `Council handoff` (anchored: `grep -F 'Council handoff'`) and `1. **Read context**` (the first FP-recheck step label, byte-exact). The existing `QUICK CHECK` and `САМОПРОВЕРКА|SELF-CHECK` checks remain. Missing any of the four markers fails the build with the file path printed.
- **D-14:** Mirror the same checks in `.github/workflows/quality.yml` `validate-templates` job. The job already loops over `templates/**/prompts/`; just extend the grep set.
- **D-15:** Add a NEW Makefile test (Test 20 — preserves Test 17 CLAUDE.md.new + Test 18 audit pipeline + Test 19 Council audit-review numbering) that runs `propagate-audit-pipeline-v42.sh` against a copy of `templates/` in a scratch dir and asserts a re-run produces zero diff (idempotency contract D-09). Wires the script as a regression target.

### Component / SOT Discipline

- **D-16:** No new `components/*.md` SOT in this phase. Phase 16 consumes `audit-fp-recheck.md` and `audit-output-format.md` (Phase 14 SOTs) by reading them at script-run time; it does not create new components.
- **D-17:** The script references those components by relative path (`components/audit-fp-recheck.md` from repo root); if a contributor moves or renames them, the script fails fast with a clear error. The script is a downstream consumer of the SOT, never a duplicator.

### Claude's Discretion

- The exact wording of the top-of-file HTML callout (D-05) — keep it short (2-3 lines), reference `.claude/rules/audit-exceptions.md` by full relative path, and mention the auditor must consult before reporting.
- The exact wording of the Council handoff footer paragraph (D-08) — quote the byte-exact slot string and link to both `commands/audit.md` Phase 5 and `commands/council.md` `## Modes`.
- Whether the script uses `awk`, `sed`, or pure Bash for block insertion — pick whichever produces the shortest, clearest implementation that handles edge cases (existing sections, missing sections, partial files).
- Sentinel comment text format (D-09) — pick a parseable, namespaced format (e.g., `<!-- v42-splice: <block-name> -->`) but don't bikeshed.

### Folded Todos

None — no pending todos matched the template-propagation scope at session start.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 16 Roadmap + Requirements

- `.planning/ROADMAP.md` §"Phase 16: Template Propagation — 49 Prompt Files" — phase goal, success criteria
- `.planning/REQUIREMENTS.md` §"Template Propagation Across All 7 Frameworks" — TEMPLATE-01..03 (lines 41-43)

### Phase 14 SOTs (read-only inputs to splice)

- `components/audit-fp-recheck.md` — 6-step FP-recheck procedure; spliced verbatim into every prompt's SELF-CHECK section
- `components/audit-output-format.md` — structured report schema; spliced verbatim into every prompt's OUTPUT FORMAT section

### Phase 15 Wiring (read-only references for the Council handoff footer)

- `commands/audit.md` Phase 5 — handoff invocation site (`/council audit-review --report <path>`)
- `commands/council.md` `## Modes` — audit-review mode documentation
- `scripts/council/prompts/audit-review.md` — Council prompt SOT; the Council handoff footer references it indirectly via `commands/council.md`

### Phase 13 Surface (read-only reference for the top-of-file callout)

- `templates/base/rules/audit-exceptions.md` — the seed allowlist file the callout points to
- `commands/audit-skip.md`, `commands/audit-restore.md` — the user-facing maintenance commands; mentioned in the callout for the auditor's awareness

### Existing Prompt Files (modify targets — 49 total)

- `templates/{base,laravel,rails,nextjs,nodejs,python,go}/prompts/{SECURITY_AUDIT,CODE_REVIEW,PERFORMANCE_AUDIT,MYSQL_PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,DEPLOY_CHECKLIST,DESIGN_REVIEW}.md`
- All 49 are English-language as of 2026-04-26 (audit during context prep)

### Test + CI Gates (modify targets)

- `Makefile` `validate` target (extend audit-prompt grep set)
- `Makefile` `test` target (add Test 20 idempotency check)
- `.github/workflows/quality.yml` `validate-templates` job (mirror Makefile gates)

### Test Patterns

- `scripts/tests/test-audit-pipeline.sh` — analog (PASS/FAIL counter idiom for Test 20)
- `scripts/tests/test-council-audit-review.sh` — analog (mktemp scratch, deterministic stub patterns)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Makefile` `validate` target (lines 115-150) already loops over `templates/**/prompts/*.md` and greps for `QUICK CHECK` + `САМОПРОВЕРКА|SELF-CHECK`. Phase 16 extends this loop with two more grep checks; no refactor needed.
- `.github/workflows/quality.yml` `validate-templates` job mirrors the Makefile validate. Phase 16 mirrors the new gates there too — keeps CI and local in sync.
- `scripts/tests/test-audit-pipeline.sh` provides the PASS/FAIL counter, mktemp + trap, report_pass/report_fail scaffold the new Test 20 (idempotency check) reuses.

### Established Patterns

- **Splice-friendly components.** Phase 14 deliberately structured `audit-fp-recheck.md` and `audit-output-format.md` for verbatim splicing into 49 framework prompts. Their bodies have no project-specific paths (only `.claude/audits/`, `.claude/rules/audit-exceptions.md`), no toolkit-internal references, and one H1 only at the top. The Phase 16 script can copy from H2 onwards directly.
- **Sentinel-comment idempotency.** The Phase 13 `audit-exceptions.md` template uses HTML comment blocks for examples (`<!-- ... -->`); the Phase 16 splice script uses the same HTML comment shape for sentinels (`<!-- v42-splice: ... -->`) so existing tooling (markdownlint, the comment-stripping `sed` pattern from Phase 13-05) treats them consistently.
- **Atomic file rewrite.** The Phase 15 `brain.py` uses `tempfile + os.replace()` for atomic in-place file mutation. The Phase 16 splice script uses the equivalent shell pattern (`mv "$tmp" "$dest"` after a successful write to a temp file in the same directory) for the same reason — never leave a half-written prompt file.

### Integration Points

- `Makefile` `validate` target (lines 115-150) is the gate that asserts marker presence — extending the loop with two more `grep -F` checks is the integration point for D-13.
- `.github/workflows/quality.yml` `validate-templates` job (lines 43-68) mirrors the Makefile validate; same integration point for D-14.
- `Makefile` `test` target (line 109) — Test 20 inserts after Test 19 with the same `@echo "Test 20: ..."` + `@bash scripts/tests/test-template-propagation.sh` pattern.

</code_context>

<specifics>
## Specific Ideas

- The sentinel comment format should be namespaced under `v42-splice` (matching the v4.2 milestone) so future migrations (`v43-splice`, etc.) can be detected and migrated without confusion.
- The script's "partial-splice detected" error (D-09) should print which sentinels are present and which are missing so a human can resolve manually without running `git diff` on the whole file.
- The Test 20 idempotency check should run the splice script TWICE in a scratch dir and assert `diff -r run-1 run-2` is empty. Catches any accidental non-determinism in block insertion.
- The script should NOT touch `templates/global/` (no `prompts/` subdirectory there) and must explicitly skip it; the find pattern `templates/*/prompts/*.md` already excludes `global/` because it has no `prompts/`, but worth defending in code with an explicit skip list comment.

</specifics>

<deferred>
## Deferred Ideas

- Localizing the spliced contract blocks (FP-recheck procedure, OUTPUT FORMAT, Council handoff) into Russian / Spanish / Japanese matching the cheatsheets — out of scope for v4.2; Phase 16 keeps the contract blocks English-only because they're tooling-readable, not user-facing prose. Revisit in v4.3 if framework templates start getting localized.
- Auto-running the splice script in CI on every PR that touches `components/audit-*.md` — would be nice for consistency but adds CI complexity. Defer until contributors actually drift the SOTs.
- Generating per-framework custom Council handoff footers that reference framework-specific commands (e.g., `php artisan` for Laravel) — out of scope; the Council handoff is framework-agnostic by design (it's about the audit pipeline, not the framework).
- Replacing the existing prompt content (the audit prompts themselves) with a v4.2 rewrite — explicitly forbidden by REQUIREMENTS.md "Out of Scope": "Replacing the existing audit prompts wholesale — we extend SELF-CHECK + OUTPUT FORMAT, preserving prompt language and structure."
- A versioned splice script (`propagate-audit-pipeline-v43.sh`, etc.) for future migrations — premature; revisit when v4.3 adds new contract blocks.

### Reviewed Todos (not folded)

None.

</deferred>

---

*Phase: 16-template-propagation-49-prompt-files*
*Context gathered: 2026-04-26*
