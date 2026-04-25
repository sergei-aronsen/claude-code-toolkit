# Phase 15: Council Audit-Review Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 15-council-audit-review-integration
**Mode:** auto (single-pass, recommended-default selection per gray area)
**Areas discussed:** Council Orchestrator Surface, Audit-Review Prompt Contract, Backend Parallelism + Disagreement Handling, /audit Handoff + FALSE_POSITIVE UX, commands/council.md Documentation, Regression Test Coverage, Component / SOT Discipline

---

## Council Orchestrator Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Extend brain.py with `--mode` flag (argparse), positional fallback for back-compat | One script, shared config + helpers, hybrid CLI | ✓ |
| Fork into separate `brain-audit-review.py` | Cleaner separation, but duplicates 600+ lines of helpers/config-loading | |
| Keep positional-only (`brain.py audit-review <path>`) without argparse | Minimal change, but harder to add future modes | |

**User's choice:** Extend brain.py with `--mode` (recommended default — D-01)
**Notes:** Reuses load_config / run_command / read_files / ask_gemini / ask_chatgpt without duplication. Backward compatibility preserved by treating an existing path positional with no `--mode` flag as `validate-plan`.

---

## Audit-Review Prompt Contract

| Option | Description | Selected |
|--------|-------------|----------|
| New `scripts/council/prompts/audit-review.md` referenced by brain.py | Splice-friendly, version-controllable, lint-able | ✓ |
| Inline prompt as Python string in brain.py | One file, less indirection, but harder to edit / lint | |
| Reuse the Phase 14 `components/audit-fp-recheck.md` body | Misuses the SOT; component is for prompt fan-out, not Council | |

**User's choice:** New prompt file under scripts/council/prompts/ (recommended default — D-05)
**Notes:** Prompt is owned by brain.py and is NOT spliced into 49 framework prompts. Length target 100-180 lines. Encodes COUNCIL-02 (severity reclass forbidden), COUNCIL-03 (verdict table format), COUNCIL-04 (missed findings).

---

## Backend Parallelism + Disagreement Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing parallel-dispatch pattern with verified concurrency (ThreadPoolExecutor) | Preserves brain.py's current shape; deterministic timeout per backend | ✓ |
| Add a third backend (e.g., Claude itself) for tie-breaking | Out of scope for v4.2; complicates config and cost | |
| Sequential dispatch with quick-exit on first agreement | Reduces latency in common case but breaks the "two independent verdicts" guarantee that disputed-detection relies on | |

**User's choice:** Parallel dispatch with explicit `disputed` marking on disagreement (recommended default — D-08, D-09)
**Notes:** Wall-clock target ≤ 90s for 5-finding report. Per-finding disagreement → `disputed` with `min(g_conf, c_conf)` and both backends' justifications cited.

---

## /audit Handoff + FALSE_POSITIVE UX

| Option | Description | Selected |
|--------|-------------|----------|
| Council nudges the user to run /audit-skip; never auto-writes the allowlist | COUNCIL-05 explicit; aligns with Phase 13 "user owns the allowlist" principle | ✓ |
| Auto-write to allowlist on Council FALSE_POSITIVE with `Council:` field set to `council_confirmed_fp` | Saves a step but violates COUNCIL-05 + REQUIREMENTS.md "Out of Scope" item | |
| Print verdict only; no nudge | Less helpful UX; user has to remember the /audit-skip syntax | |

**User's choice:** Print verdict + nudge user to run /audit-skip (recommended default — D-12)
**Notes:** For `disputed` rows, /audit prompts `(R)eal | (F)alse positive | (N)eeds more context` — single-key, no default, explicit answer required.

---

## commands/council.md Documentation

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing commands/council.md with a new `## Modes` section | One file, one slash command, two modes documented side-by-side | ✓ |
| Create a new commands/council-audit-review.md | More files, more discoverability surface, but splits the slash command | |

**User's choice:** Extend existing file (recommended default — D-14)
**Notes:** Net add ≤ 60 lines. markdownlint-clean. Documents validate-plan (existing) and audit-review (new) with invocation syntax, output schema, and prompt-file pointer.

---

## Regression Test Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| New `scripts/tests/test-council-audit-review.sh` with stubbed backends | Deterministic, no API key needed in CI, asserts all 6 contract dimensions | ✓ |
| Skip a regression test for v4.2; rely on manual smoke tests | Faster ship but breaks Phase 14's "every contract has a test" pattern | |
| Hit live Gemini / ChatGPT in CI | Network-dependent, billable, flaky | |

**User's choice:** Stubbed-backend regression test wired as Makefile Test 19 (recommended default — D-15)
**Notes:** Stubs under `scripts/tests/fixtures/council/`. Asserts: dispatch, verdict slot rewrite, frontmatter mutation, byte-identity of unchanged sections, disputed handling, malformed output handling, severity-reclass rejection.

---

## Component / SOT Discipline

| Option | Description | Selected |
|--------|-------------|----------|
| Audit-review prompt lives at scripts/council/prompts/audit-review.md (NOT a component) | Keeps Phase 16 fan-out (49 prompt files) cleanly separate from Phase 15's backend asset | ✓ |
| Audit-review prompt as a new components/audit-review-prompt.md | Confuses Phase 16 (which splices ALL components/* into 49 prompt files) | |

**User's choice:** Backend prompt under scripts/council/prompts/ (recommended default — D-17)
**Notes:** Phase 16 framework prompts only mention `/council audit-review` by name; they do NOT splice the audit-review prompt body. Components/ stays Phase 16-fan-out territory; scripts/council/prompts/ stays Phase 15 backend territory.

---

## Claude's Discretion

- Exact wording of the audit-review prompt's intro paragraph and tone (constraint: clear about severity-reclass prohibition)
- Concurrency primitive (`concurrent.futures.ThreadPoolExecutor` vs subprocess `&`) — pick whichever produces cleaner Python
- Stub language (Bash vs Python) — pick whichever is shorter
- Exact filename casing (audit-review.md vs audit_review.md) — match existing scripts/council/ conventions

## Deferred Ideas

- Web dashboard / TUI for past verdicts (v4.3 if usage justifies)
- Caching Council verdicts across runs (no user demand yet)
- "Diff verdict over time" feature (defer)
- Subcommanded CLI refactor (`brain.py validate-plan` / `brain.py audit-review`) — `--mode` is sufficient for v4.2
- Auto-running Council against historical `.claude/audits/` reports (out of scope)
