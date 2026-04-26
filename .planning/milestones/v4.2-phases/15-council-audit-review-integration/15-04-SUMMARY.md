---
phase: 15-council-audit-review-integration
plan: "04"
subsystem: council-orchestrator
tags: [brain.py, argparse, ThreadPoolExecutor, audit-review, in-place-rewrite]
requirements: [COUNCIL-01, COUNCIL-02, COUNCIL-03, COUNCIL-04, COUNCIL-06]
dependency_graph:
  requires:
    - "15-01"
    - "15-02"
  provides:
    - "scripts/council/brain.py --mode audit-review runtime contract"
    - "run_audit_review() entry point"
    - "argparse dispatcher with backward-compat positional fallback"
  affects:
    - "commands/council.md (invokes brain.py --mode audit-review)"
    - "scripts/tests/test-council-audit-review.sh (uses COUNCIL_STUB_* env vars)"
tech_stack:
  added:
    - "argparse (stdlib) — replaces raw sys.argv[1] in main()"
    - "concurrent.futures.ThreadPoolExecutor(max_workers=2) — parallel Gemini+ChatGPT dispatch"
    - "FuturesTimeoutError alias — avoids collision with built-in TimeoutError"
  patterns:
    - "extract_block(): re.search with re.DOTALL for bracketed XML-like markers"
    - "parse_verdict_table(): tolerant pipe-split markdown table parser"
    - "resolve_council_status(): per-finding agreement/disagreement logic with min-confidence disputed rows"
    - "atomic_write_text(): tempfile.NamedTemporaryFile + os.replace POSIX atomicity"
    - "rewrite_report(): byte-exact str.replace for Council slot + re.MULTILINE sub for frontmatter"
    - "COUNCIL_STUB_GEMINI/CHATGPT env vars: test-friendly backend bypass in dispatch wrappers"
key_files:
  modified:
    - scripts/council/brain.py
decisions:
  - "Extracted _run_validate_plan(plan, config) from main() to preserve the v3.0.0 validate-plan body byte-identically while freeing main() for argparse dispatch"
  - "Used vp_report_path name for the validate-plan scratchpad path to avoid variable shadowing with run_audit_review's report_path parameter"
  - "Smoke test uses in-project scratch dir (.tmp-council-smoke/) because validate_file_path() rejects paths outside cwd — consistent with existing security policy"
metrics:
  duration: "6 minutes"
  completed: "2026-04-25T20:29:06Z"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 1
  lines_added: 472
  lines_final: 1150
---

# Phase 15 Plan 04: Council audit-review orchestrator in brain.py Summary

Extended `scripts/council/brain.py` (678 → 1150 lines) with `--mode audit-review` parallel dispatch, in-place report rewrite, and frontmatter mutation — delivering the COUNCIL-01 through COUNCIL-06 runtime contract.

## What Was Built

### Task 1 — Imports, constants, 5 stateless helpers (commit `4eabf0f`)

Added to `brain.py`:

- **2 new imports:** `argparse`, `concurrent.futures.ThreadPoolExecutor + FuturesTimeoutError`
- **3 new constants:** `AUDIT_REVIEW_GEMINI_SYSTEM`, `AUDIT_REVIEW_GPT_SYSTEM`, `COUNCIL_SLOT_PLACEHOLDER` (em-dash U+2014 verified), `COUNCIL_VERDICT_HEADER`
- **5 new helpers:**
  - `extract_block(text, tag)` — `re.search` with `re.DOTALL` for `<tag>...</tag>` extraction
  - `parse_verdict_table(block_text)` — tolerant pipe-split parser returning `{F-NNN: {verdict, confidence, justification}}`
  - `resolve_council_status(verdicts_g, verdicts_c)` — per-finding agreement/disagreement, `disputed` = `min(g_conf, c_conf)`, returns `(status, rows)`
  - `atomic_write_text(path, content)` — `tempfile + os.replace` POSIX atomicity
  - `rewrite_report(report_path, status, verdict_text, missed_text)` — byte-exact `str.replace` for Council slot + `re.MULTILINE re.sub` for `council_pass:` frontmatter

### Task 2 — Dispatch wrappers + run_audit_review() (commit `abbf28e`)

- `dispatch_audit_review_gemini(prompt, config)` — honors `COUNCIL_STUB_GEMINI` env var
- `dispatch_audit_review_chatgpt(prompt, config)` — honors `COUNCIL_STUB_CHATGPT` env var
- `run_audit_review(report_path_str, config) -> int` — full orchestration:
  1. Validates report path (cwd-anchored)
  2. Verifies `COUNCIL_SLOT_PLACEHOLDER` present (rejects already-reviewed reports)
  3. Loads `Path(__file__).resolve().parent / "prompts" / "audit-review.md"`, substitutes `{REPORT_CONTENT}`
  4. `ThreadPoolExecutor(max_workers=2)` parallel dispatch with 90s `future.result(timeout=90)`
  5. `extract_block()` for `<verdict-table>` and `<missed-findings>` from each backend
  6. Malformed-output guard: both missing → `council_pass: failed`, exit 1
  7. `parse_verdict_table()` + `resolve_council_status()` → `(status, rows)`
  8. Builds verdict markdown table with byte-exact `COUNCIL_VERDICT_HEADER`
  9. `rewrite_report()` atomic in-place rewrite
  10. Prints collated verdict to stdout; returns 0

### Task 3 — argparse refactor with backward-compat positional fallback (commit `ca91627`)

- Extracted `_run_validate_plan(plan, config)` — byte-identical body of the old `main()` validate-plan flow
- New `main()` argparse dispatcher: `--mode {validate-plan,audit-review}`, `--report`, positional `plan`
- Backward compat: `brain "<plan text>"` (no `--mode`) routes to `_run_validate_plan` unchanged
- Missing `--report` with `--mode audit-review` → `parser.error()`, exit 2

## Verification Results

```
python3 -c "import ast; ast.parse(open('scripts/council/brain.py').read())"  # OK
python3 scripts/council/brain.py --help                                       # shows both modes
python3 scripts/council/brain.py --mode audit-review                          # exit 2, error message
# Smoke test (stubs inside project):
COUNCIL_STUB_GEMINI=.../stub-gemini.sh COUNCIL_STUB_CHATGPT=.../stub-chatgpt.sh \
  python3 brain.py --mode audit-review --report .tmp-council-smoke/report.md  # exit 0
# council_pass: disputed (F-003 disagreement REAL vs FALSE_POSITIVE -> min(0.9,0.7)=0.7)
# | ID | verdict | confidence | justification | table written
make check   # shellcheck + markdownlint + validate: ALL PASSED
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Smoke test path validation**

- **Found during:** Task 3 verification
- **Issue:** The plan's smoke test used `mktemp -d` (a `/var/folders/...` path on macOS), which `validate_file_path()` correctly rejects as outside-project. Not a bug in brain.py — expected security behavior.
- **Fix:** Used `mktemp -d "$PWD/.tmp-council-smoke-XXXXX"` (inside project) for the smoke test.
- **Files modified:** None (test-only adjustment)
- **Commit:** N/A (no code change needed)

**2. [Rule 1 - Bug] Variable name shadowing in _run_validate_plan**

- **Found during:** Task 3
- **Issue:** The old `main()` used `report_path` for the scratchpad Council report file; after extraction to `_run_validate_plan`, this name shadowed the `report_path` parameter in `run_audit_review` (different scope, but confusing). Also `vp_report_path.write_text(...)` referenced an undefined name after the initial rename attempt left the assignment still using `report_path`.
- **Fix:** Renamed the scratchpad path variable to `vp_report_path` consistently in `_run_validate_plan`.
- **Files modified:** `scripts/council/brain.py`
- **Commit:** `ca91627`

## Requirements Satisfied

- **COUNCIL-01:** `python3 brain.py --mode audit-review --report <path>` is the runtime entry point
- **COUNCIL-02:** `brain.py` never modifies any `**Severity:**` bullet — only rewrites `## Council verdict` slot and `council_pass:` frontmatter key
- **COUNCIL-03:** `extract_block` + `parse_verdict_table` extract per-finding verdict table; byte-exact `COUNCIL_VERDICT_HEADER` used
- **COUNCIL-04:** `extract_block` extracts `<missed-findings>` block; `## Missed findings` H2 written with content or `(none)`
- **COUNCIL-06:** `ThreadPoolExecutor(max_workers=2)` parallel dispatch; `resolve_council_status` resolves disagreements as `disputed` with `confidence min(g_conf, c_conf)`

## Known Stubs

None — all data paths are wired. The `COUNCIL_STUB_GEMINI`/`COUNCIL_STUB_CHATGPT` env vars are test infrastructure, not production stubs.

## Self-Check

- `scripts/council/brain.py` exists: FOUND
- Commit `4eabf0f` exists: FOUND (Task 1)
- Commit `abbf28e` exists: FOUND (Task 2)
- Commit `ca91627` exists: FOUND (Task 3)
- `make check` passes: PASSED
- Smoke test `council_pass: disputed`: PASSED

## Self-Check: PASSED
