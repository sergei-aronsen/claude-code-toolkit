# Phase 15: Council Audit-Review Integration - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning
**Mode:** Auto-generated (gsd-discuss-phase --auto, single pass)

<domain>
## Phase Boundary

This phase wires the Supreme Council into the audit pipeline as a **mandatory terminating step**. Every `/audit` run produced by Phase 14 ends with `/council audit-review --report <path>` invoking `scripts/council/brain.py` against the structured report; Council confirms or rejects each finding using the embedded verbatim code block, surfaces real issues the auditor missed, and writes its verdict back into the report's `## Council verdict` slot. The phase delivers six artefacts:

1. A new `audit-review` mode in `scripts/council/brain.py` (CLI flag `--mode audit-review --report <path>`) that loads the structured report, runs Gemini + ChatGPT in parallel against the audit-review prompt, and rewrites the `## Council verdict` slot in place.
2. A new `commands/council.md` subcommand section documenting `/council audit-review --report <path>` for end users.
3. A new `prompts/audit-review.md` (or equivalent) — the Council prompt template that explicitly forbids severity reclassification (COUNCIL-02), demands the per-finding verdict table format (COUNCIL-03), and asks for missed-findings reasoning (COUNCIL-04).
4. The `/audit` -> `/council audit-review` handoff in `commands/audit.md` (Phase 5 of the workflow contract documented in Phase 14) becomes runtime-enforced — the audit run is reported as incomplete until Council returns.
5. The `FALSE_POSITIVE -> prompt-user-to-run-/audit-skip` ergonomic path in `/audit` (COUNCIL-05) — no auto-writes to the allowlist.
6. A regression test under `scripts/tests/` that asserts (a) the audit-review mode dispatches to both backends in parallel, (b) the per-finding verdict table format is honoured byte-for-byte by the prompt's expected output schema, (c) disagreements (one REAL, one FALSE_POSITIVE) surface as `disputed`, (d) the verdict slot is overwritten in place with no other report mutations, (e) severity is never reclassified.

Out of scope for this phase: the per-framework prompt files (Phase 16 — they reference `/council audit-review` only conceptually here), the manifest/installer changes (Phase 17), and any UI/dashboard for browsing past Council verdicts (deferred — see `<deferred>` below).

</domain>

<decisions>
## Implementation Decisions

### Council Orchestrator Surface

- **D-01:** Extend `scripts/council/brain.py` with a `--mode` flag (`validate-plan` is the implicit default for backward compatibility; `audit-review` is the new mode). Do NOT fork into a second script. Reasons: shared code (`run_command`, `read_files`, `ask_gemini`, `ask_chatgpt`), shared config (`~/.claude/council/config.json` already loaded, no duplication), shared error handling. Use `argparse` (stdlib) — replaces the current `sys.argv[1]` positional. Backward compatibility: when first positional arg is a path that exists and `--mode` is absent, default to `validate-plan` (existing behaviour preserved).
- **D-02:** New CLI surface: `python3 brain.py --mode audit-review --report <path-to-audit-report>`. The `--report` flag is required when `--mode audit-review`. The orchestrator reads the report file, extracts each `### Finding F-NNN` block (using the byte-exact bullet labels from `components/audit-output-format.md`), passes the report content + the audit-review prompt to both backends in parallel, and writes the collated verdict back to the `## Council verdict` slot.
- **D-03:** Council's verdict-slot mutation is **in-place**, replacing the byte-exact placeholder `_pending — run /council audit-review_` (Phase 14 contract — D-15 in 14-CONTEXT.md). Use `sed` or Python in-place rewrite; never re-emit the report from scratch (other sections must not drift). Locate the slot by greppingstandalone for `## Council verdict\n\n_pending — run /council audit-review_` (em-dash U+2014 — load-bearing per Phase 14 D-07).
- **D-04:** Council also mutates the YAML frontmatter `council_pass:` key from `pending` to one of `passed`, `failed`, `disputed`. Mapping: all REAL = `passed`; ≥1 FALSE_POSITIVE with auditor agreement (will be marked for `/audit-skip`) = `failed`; ≥1 disagreement between backends = `disputed`. The frontmatter rewrite is also in-place (find the key by anchored regex `^council_pass:`); preserve key order.

### Audit-Review Prompt Contract (COUNCIL-02, COUNCIL-03, COUNCIL-04)

- **D-05:** Create `scripts/council/prompts/audit-review.md` (new directory) — the prompt template the orchestrator interpolates into Gemini and ChatGPT requests. The prompt MUST contain (byte-exact, non-negotiable):
  1. The phrase **"DO NOT reclassify severity"** in capitals at the top of the constraints section. Severity is the auditor's verdict; the Council confirms or rejects REAL/FALSE_POSITIVE only. This is the literal enforcement of COUNCIL-02.
  2. A request for the per-finding verdict table with byte-exact columns `| ID | verdict | confidence | justification |`. `verdict` ∈ {`REAL`, `FALSE_POSITIVE`, `NEEDS_MORE_CONTEXT`}. `confidence` ∈ `[0.0, 1.0]` floating-point (one decimal acceptable). `justification` ≤ 160 chars, references concrete tokens from the embedded code block. This is the literal enforcement of COUNCIL-03.
  3. A request for a `## Missed findings` section listing real issues visible in the embedded verbatim code blocks that the auditor did not report — each row needs `location`, `rule`, `code excerpt` (≤ 5 lines), `claim`, `suggested severity` (CRITICAL/HIGH/MEDIUM/LOW). Auditor accepts or rejects in a follow-up — never auto-merged. This is the literal enforcement of COUNCIL-04.
- **D-06:** Prompt is written in English (consistent with Phase 14 components). It does NOT redefine severity rubric — it references `components/severity-levels.md` by path. Length target: 100-180 lines (heavy on byte-exact format examples; light on prose).
- **D-07:** The prompt explicitly documents the embedded verbatim code block layout from `components/audit-output-format.md` (the `<!-- File: <path> Lines: <start>-<end> -->` header + language fence + ±10 lines) so backends know what they are reading. The Council MUST cite tokens from that block in justifications — never paraphrase the file from imagined memory.

### Backend Parallelism + Disagreement Handling (COUNCIL-06)

- **D-08:** Reuse the existing parallel-dispatch pattern in `brain.py` (`ask_gemini` + `ask_chatgpt` invoked in sequence today; Phase 15 keeps that flow but verifies parallelism via subprocess `&` or `concurrent.futures.ThreadPoolExecutor`). Total wall-clock target: ≤ 90 seconds for a 5-finding report on a healthy network. If a backend times out (config-default 60s), the orchestrator emits a partial verdict marked `unavailable` for that backend's column and proceeds — never blocks indefinitely.
- **D-09:** Per-finding disagreement resolution: for each finding ID, compare `gemini_verdict` and `chatgpt_verdict`. If both agree → that's the verdict. If they disagree (one REAL, one FALSE_POSITIVE; or NEEDS_MORE_CONTEXT vs anything else) → the consolidated row is marked `disputed` with confidence `min(g_conf, c_conf)` and the justification field cites both backends ("Gemini: <g>; ChatGPT: <c>"). The user sees the disagreement; no auto-resolution. This is the literal enforcement of COUNCIL-06.
- **D-10:** Backend output parsing: each backend MUST emit its verdict block bracketed by literal markers `<verdict-table>` ... `</verdict-table>` and `<missed-findings>` ... `</missed-findings>`. The orchestrator extracts these markers verbatim — no fuzzy parsing, no JSON gymnastics. If a backend returns malformed output (no `<verdict-table>` marker), the orchestrator marks the run `failed` with a one-line "Council parse error" comment in the verdict slot and exits non-zero so `/audit` surfaces the failure.

### `/audit` Handoff + FALSE_POSITIVE UX (COUNCIL-01, COUNCIL-05)

- **D-11:** `commands/audit.md` Phase 5 (Council Pass) contract — `/audit` invokes `/council audit-review --report <path>` AS A USER COMMAND in the conversation (not as a shell call). The audit run prints `Running Council audit-review against <path>...` then waits for the Council's structured response. There is no `--no-council` flag in v4.2 (REQUIREMENTS.md COUNCIL-01 explicit).
- **D-12:** After Council returns, `/audit` parses the verdict table. For each row where `verdict == FALSE_POSITIVE` (and auditor agrees), `/audit` prints a structured nudge: `Council confirmed F-NNN as FALSE_POSITIVE. To persist: /audit-skip <path>:<line> <rule> "<reason>"`. The user MUST run `/audit-skip` themselves — `/audit` NEVER mutates `audit-exceptions.md` directly. This is the literal enforcement of COUNCIL-05 (Phase 13 `/audit-skip` is the only writer; Phase 15 only nudges).
- **D-13:** For `disputed` rows, `/audit` prints the disagreement and asks the user to choose: `(R)eal — keep as a finding`, `(F)alse positive — run /audit-skip`, or `(N)eeds more context — leave open in next audit`. No default; the user must answer.

### `commands/council.md` Documentation

- **D-14:** Extend `commands/council.md` with a new `## Modes` section documenting `validate-plan` (existing) and `audit-review` (new). Each mode has: invocation syntax, what it produces, when to use, link to the prompt file. Length addition: ≤ 60 lines net (the file is currently 144 lines; target ≤ 210). markdownlint-clean.

### Regression Test Coverage

- **D-15:** New test: `scripts/tests/test-council-audit-review.sh`. Mirrors the structure of `scripts/tests/test-audit-pipeline.sh` (PASS=0/FAIL=0 counter idiom). Asserts: (a) `brain.py --mode audit-review --report fixture.md` exits 0 with both backends mocked (use stub Gemini/ChatGPT scripts in `scripts/tests/fixtures/council/`); (b) the `## Council verdict` slot is rewritten with a verdict table; (c) `council_pass:` frontmatter mutates from `pending` to `passed|failed|disputed`; (d) other sections of the report are byte-identical pre/post; (e) disagreement test (one stub returns REAL, the other FALSE_POSITIVE) surfaces as `disputed`; (f) malformed backend output → `failed` + Council parse error message; (g) severity reclassification attempt by stubs is rejected (auditor's severity preserved). Wire as Test 19 in `Makefile` (Test 17 = CLAUDE.md.new flow per upstream merge; Test 18 = audit pipeline per Phase 14).
- **D-16:** Fixtures under `scripts/tests/fixtures/council/`: a sample `audit-report.md` (3 findings — 1 obvious REAL, 1 obvious FALSE_POSITIVE, 1 disputed), two stub backend scripts (`stub-gemini.sh`, `stub-chatgpt.sh`) that emit canned verdict tables. Stubs read finding IDs from stdin/args and emit the bracketed `<verdict-table>` blocks with predetermined verdicts so the test is deterministic.

### Component / SOT Discipline

- **D-17:** No new `components/*.md` SOT in this phase. The audit-review prompt at `scripts/council/prompts/audit-review.md` is owned by `brain.py`; it is NOT spliced into 49 framework prompts (those framework prompts only reference `/council audit-review` by name, in Phase 16). Keep prompts/ separate from components/ to avoid Phase 16 fan-out confusion.
- **D-18:** Phase 14's `components/audit-output-format.md` and `components/audit-fp-recheck.md` are referenced (read-only) by `prompts/audit-review.md` for the schema contract. The Phase 15 prompt MUST quote the byte-exact slot string `_pending — run /council audit-review_` and the bullet labels (`**Severity:**`, `**Rule:**`, `**Location:**`, `**Claim:**`, `**Code:**`, etc.) so the backends know what they are reading.

### Claude's Discretion

- The exact wording of the audit-review prompt's intro paragraph, examples, and tone — the user trusts Claude to phrase the constraint clearly.
- Whether to use `concurrent.futures.ThreadPoolExecutor` vs subprocess `&` for parallelism (D-08) — pick whichever produces cleaner Python.
- Whether the regression test stubs are Bash or Python — pick whichever is shorter and more readable.
- The exact filename for the audit-review prompt (`prompts/audit-review.md` vs `prompts/audit-review-prompt.md` vs `prompts/audit_review.md`). Consistency with the existing `scripts/council/` directory wins.

### Folded Todos

None — no pending todos matched the council-audit-review scope at session start.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 15 Roadmap + Requirements

- `.planning/ROADMAP.md` §"Phase 15: Council Audit-Review Integration" — phase goal, 6 success criteria
- `.planning/REQUIREMENTS.md` §"Council Audit-Review Integration" — COUNCIL-01..06 (lines 34-39)
- `.planning/REQUIREMENTS.md` §"Out of Scope" — explicitly forbidden directions (severity reclass, auto-skip writes, --no-council flag)

### Phase 14 Contracts (read-only inputs)

- `components/audit-output-format.md` — structured report schema, byte-exact Council slot string, frontmatter keys, finding entry bullet labels
- `components/audit-fp-recheck.md` — 6-step procedure (referenced for context only; Council does NOT re-run the recheck)
- `commands/audit.md` Phase 5 — handoff contract, no `--no-council` flag, alias for `audit code` → `code-review`

### Phase 13 Surface (read-only inputs)

- `commands/audit-skip.md` — the user-facing entry point that COUNCIL-05 nudges towards
- `templates/base/rules/audit-exceptions.md` — the seed file the FP-prompted-skip flow appends to
- `commands/audit-restore.md` — symmetric op for cases where Council says REAL but auditor disagrees on a previously-skipped finding

### Council Infrastructure (modify targets)

- `scripts/council/brain.py` — current orchestrator (678 lines, no `--mode` flag yet)
- `scripts/council/config.json.template` — config schema (model selection, timeouts, API keys via env)
- `scripts/council/README.md` — user-facing docs for the orchestrator
- `commands/council.md` — slash-command surface (currently 144 lines, single `validate-plan` mode)

### Test Patterns

- `scripts/tests/test-audit-pipeline.sh` — closest analog (PASS/FAIL counter idiom, mktemp scratch, trap cleanup, regression-fixture pattern)
- `scripts/tests/test-setup-security-rtk.sh` — analog cited by Phase 14 plan-patterns
- `Makefile:99-105` — current `test:` tail (Tests 16-18 already wired; Phase 15 lands as Test 19)

### Severity Rubric (read-only)

- `components/severity-levels.md` — CRITICAL/HIGH/MEDIUM/LOW definitions; the Council prompt references this by path, never redefines

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/council/brain.py:load_config()` — reads `~/.claude/council/config.json`, no change needed for audit-review (timeouts, model IDs, API keys all reused).
- `scripts/council/brain.py:run_command()` — generic subprocess wrapper with timeout. Reuse for both `ask_gemini_cli` and `ask_chatgpt`.
- `scripts/council/brain.py:ask_gemini` / `ask_chatgpt` — backend dispatch functions. The audit-review mode wraps the existing audit prompt; no refactor needed.
- `scripts/council/brain.py:get_validated_paths` / `read_files` — file-reading helpers; reused for reading the audit report safely.
- `scripts/tests/test-audit-pipeline.sh` — full reusable test scaffold (PASS=0/FAIL=0, mktemp + trap, report_pass/report_fail).

### Established Patterns

- **Sliced workflow contracts.** Phase 14 made `commands/audit.md` reference `components/*.md` as SOT; Phase 15 follows the same discipline (`commands/council.md` references `scripts/council/prompts/audit-review.md`).
- **Byte-exact contract strings.** Em-dash U+2014 is load-bearing across Phases 13/14; Phase 15 inherits this — every grep target uses `grep -F` on literal strings, never `grep -E` with patterns.
- **Stubbed-backend regression tests.** `test-audit-pipeline.sh` uses inline mock reports; Phase 15 extends with stub-backend scripts (deterministic Gemini/ChatGPT output) under `scripts/tests/fixtures/council/`.
- **In-place file mutation via sed/awk.** `commands/audit-restore.md` uses `sed '/^<!--/,/^-->/d'` to strip comments; Phase 15 uses similar sed pattern to locate-and-replace the verdict slot.

### Integration Points

- `commands/audit.md` Phase 5 — the runtime handoff site. Phase 15 makes this section operational (Phase 14 wrote the contract; Phase 15 ships the consumer).
- `scripts/council/brain.py` `main()` — argparse entry point. Phase 15 inserts `--mode` dispatch before plan validation.
- `manifest.json:files.commands` — `audit.md` and `council.md` already listed; new prompt file at `scripts/council/prompts/audit-review.md` is NOT a command (it's a backend asset) — Phase 17 decides whether to ship it under a new manifest section.

</code_context>

<specifics>
## Specific Ideas

- The verdict slot rewrite MUST preserve a trailing newline after the table — Phase 14's report skeleton ends `## Council verdict\n\n_pending — run /council audit-review_\n` and downstream tooling (parsers, future v4.3 dashboards) may rely on that newline.
- The audit-review prompt's "DO NOT reclassify severity" enforcement should also include a positive directive: "If you disagree with the auditor's severity, add a comment under `## Severity disagreements (advisory)` — never modify the table." This makes the constraint actionable instead of purely prohibitive.
- The disagreement-resolution UX (D-13) should mirror Phase 13's `/audit-restore` `[y/N]` prompt style — single-character keys, explicit prompt, no defaults.

</specifics>

<deferred>
## Deferred Ideas

- A web dashboard or TUI for browsing past Council verdicts across audit reports — out of scope for v4.2; revisit in v4.3 if usage justifies it.
- Caching Council verdicts so re-running `/audit` against an unchanged report skips backend calls — premature optimization until users complain about latency. Defer.
- A "diff Council verdict over time" feature (track flips from REAL to FALSE_POSITIVE across runs) — interesting but no user has asked. Defer.
- Replacing brain.py's positional argparse with a fully subcommanded CLI (`brain.py validate-plan ...` / `brain.py audit-review ...`) — D-01's hybrid (`--mode` flag + positional fallback) is sufficient for v4.2. Subcommand refactor is a v4.3 cleanup if `--mode` proliferates.
- Auto-running Council against historical reports under `.claude/audits/` to backfill verdicts — out of scope; only new audits invoke Council.

### Reviewed Todos (not folded)

None — no todos matched at session start.

</deferred>

---

*Phase: 15-council-audit-review-integration*
*Context gathered: 2026-04-25*
