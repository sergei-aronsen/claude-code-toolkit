# Phase 15: Council Audit-Review Integration — Research

**Researched:** 2026-04-25
**Domain:** Python orchestrator extension + Bash test scaffolding + Markdown command docs
**Confidence:** HIGH

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Extend `brain.py` with `--mode` flag via `argparse`. Preserve positional fallback
  for backward compat. Do NOT fork into a second script.
- **D-02:** New CLI: `python3 brain.py --mode audit-review --report <path>`. `--report` required
  when `--mode audit-review`.
- **D-03:** Verdict-slot mutation is in-place, grepping for the literal byte sequence
  `_pending — run /council audit-review_` (U+2014 em-dash). Use `sed` or Python; never
  re-emit the report from scratch.
- **D-04:** YAML frontmatter `council_pass:` mutated `pending` → `passed|failed|disputed`
  in-place by anchored regex `^council_pass:`. Key order preserved.
- **D-05:** New prompt at `scripts/council/prompts/audit-review.md`. Must contain "DO NOT
  reclassify severity" (caps), per-finding verdict table with columns
  `| ID | verdict | confidence | justification |`, and `## Missed findings` section.
- **D-06:** Prompt in English, references `components/severity-levels.md` by path, 100-180 lines.
- **D-07:** Prompt documents the verbatim code block layout from `components/audit-output-format.md`
  so backends cite tokens from the block, not imagined memory.
- **D-08:** Parallel dispatch via `concurrent.futures.ThreadPoolExecutor` or subprocess `&`.
  Claude's discretion on which is cleaner.
- **D-09:** Disagreement: `disputed` with `min(g_conf, c_conf)` and both justifications cited.
- **D-10:** Backend output bracketed by `<verdict-table>` ... `</verdict-table>` and
  `<missed-findings>` ... `</missed-findings>`. No fuzzy parsing.
- **D-11:** `/audit` Phase 5 invokes `/council audit-review` as a user command in conversation,
  not as a shell call.
- **D-12:** FALSE_POSITIVE → nudge to `/audit-skip` only. `/audit` NEVER auto-writes
  `audit-exceptions.md`.
- **D-13:** `disputed` → `(R)eal | (F)alse positive | (N)eeds more context` prompt. No default.
- **D-14:** Extend `commands/council.md` with `## Modes` section (≤ 60 net lines). File is
  currently 144 lines; target ≤ 210.
- **D-15:** New `scripts/tests/test-council-audit-review.sh` wired as Makefile Test 19.
  Asserts: (a) exits 0 with mocked backends, (b) verdict table written, (c) `council_pass:`
  mutated, (d) other sections byte-identical, (e) disagreement → `disputed`, (f) malformed
  output → `failed` + parse-error comment, (g) severity reclassification attempt rejected.
- **D-16:** Fixtures under `scripts/tests/fixtures/council/`: `audit-report.md` (3 findings),
  `stub-gemini.sh`, `stub-chatgpt.sh` emitting canned `<verdict-table>` blocks.
- **D-17:** No new `components/*.md` SOT. Prompt is owned by `brain.py`, not spliced into
  framework prompts (Phase 16 task).
- **D-18:** Phase 14 `components/audit-output-format.md` and `audit-fp-recheck.md` are
  read-only inputs for the Phase 15 prompt. Prompt must quote the byte-exact slot string
  and bullet labels.

### Claude's Discretion

- Exact wording of the prompt's intro paragraph, examples, and tone.
- `ThreadPoolExecutor` vs subprocess `&` for parallelism (pick cleaner Python).
- Whether stubs are Bash or Python (pick shorter/more readable).
- Exact filename for the prompt (`audit-review.md` vs `audit-review-prompt.md` vs
  `audit_review.md`). Consistency with existing `scripts/council/` wins.

### Deferred Ideas (OUT OF SCOPE)

- Web dashboard / TUI for browsing past Council verdicts.
- Caching Council verdicts to skip re-runs.
- Diff Council verdict over time.
- Full subcommand CLI refactor (`brain.py validate-plan ...` / `brain.py audit-review ...`).
- Auto-running Council against historical reports under `.claude/audits/`.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COUNCIL-01 | `/audit` MUST invoke `/council audit-review --report <path>` after writing the report; audit is incomplete until Council returns | `commands/audit.md` Phase 5 already documents the handoff contract (read); Phase 15 makes it operational |
| COUNCIL-02 | Council prompt explicitly forbids severity reclassification | D-05 `"DO NOT reclassify severity"` phrase in prompt; D-07 references `components/severity-levels.md` by path |
| COUNCIL-03 | Per-finding verdict table: `REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT`, confidence 0-1, one-line justification | D-05 table schema; D-10 `<verdict-table>` XML markers |
| COUNCIL-04 | `## Missed findings` section with location, rule, code excerpt, claim, suggested severity | D-05 section spec; D-10 `<missed-findings>` XML markers |
| COUNCIL-05 | FALSE_POSITIVE → prompt user to run `/audit-skip`; audit never auto-writes exceptions | D-12; `commands/audit-skip.md` is the only writer (Phase 13) |
| COUNCIL-06 | Gemini + ChatGPT in parallel; disagreements flagged as `disputed` without auto-resolution | D-08 parallelism; D-09 min-confidence merge |

</phase_requirements>

---

## Domain Overview

### What Council Is

Supreme Council (`scripts/council/brain.py`, 678 lines) is a multi-AI validation orchestrator.
Current single mode: `validate-plan` — sends an implementation plan to Gemini (The Skeptic) and
ChatGPT (The Pragmatist) in **series** (Pragmatist prompt embeds the Skeptic's response).
Verdicts: `PROCEED | SIMPLIFY | RETHINK | SKIP`. Report saved to `.claude/scratchpad/council-report.md`.

Phase 15 adds a second mode, `audit-review`, that:

1. Reads a structured audit report (Phase 14 format per `components/audit-output-format.md`).
2. Sends the report + a new prompt template to Gemini and ChatGPT **in parallel** (not series —
   no cross-dependency between backend calls for this mode).
3. Collates per-finding verdicts: `REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT`.
4. Resolves disagreements as `disputed`.
5. Rewrites two in-place mutation targets in the report file:
   - `## Council verdict` slot (replaces placeholder with verdict table).
   - `council_pass:` YAML frontmatter key (mutates `pending` → `passed|failed|disputed`).

### What Changes in brain.py

`main()` currently at line 446 uses raw `sys.argv[1]` as the plan text. Phase 15 replaces this
with `argparse` while preserving backward compat: if `--mode` is absent and `sys.argv[1]` looks
like a path-or-text string, default to `validate-plan` flow.

Two new functions are needed:

- `run_audit_review(report_path, config)` — the new mode's orchestration logic.
- Helper to parse `<verdict-table>` / `<missed-findings>` blocks from raw backend output.
- Helper to rewrite the verdict slot and frontmatter in place.

Existing shared functions (`load_config`, `run_command`, `ask_gemini`, `ask_chatgpt`,
`read_files`, `get_validated_paths`) are **reused without modification**.

---

## Existing Patterns

### 1. Argument Handling — `main()` (brain.py:446-452)

Current code (lines 446-452):

```python
def main():
    if len(sys.argv) < 2:
        print("Usage: python3 brain.py \"Your implementation plan\"")
        sys.exit(1)

    plan = sys.argv[1]
    validate_plan(plan)
```

**Migration target:** Replace with `argparse` block. Backward-compat: detect if invoked as
`brain.py "<plan text>"` (no `--mode` flag) and route to `validate_plan` mode. Pattern:

```python
import argparse

parser = argparse.ArgumentParser(prog="brain")
parser.add_argument("--mode", choices=["validate-plan", "audit-review"],
                    default=None)
parser.add_argument("--report", help="Path to audit report (audit-review mode)")
parser.add_argument("plan", nargs="?", help="Implementation plan (validate-plan mode)")
args = parser.parse_args()

# Backward compat: positional plan text with no --mode = validate-plan
if args.mode is None:
    if args.plan:
        args.mode = "validate-plan"
    else:
        parser.print_help()
        sys.exit(1)

if args.mode == "audit-review":
    if not args.report:
        parser.error("--report is required with --mode audit-review")
    run_audit_review(args.report, config)
else:
    validate_plan(args.plan)
    # ... existing validate-plan flow
```

### 2. Parallel Dispatch — `concurrent.futures.ThreadPoolExecutor`

Current flow (lines 527-576): Gemini then ChatGPT called sequentially. For `audit-review`,
both backends receive the same prompt (no cross-dependency), so true parallelism is clean:

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

with ThreadPoolExecutor(max_workers=2) as executor:
    future_gemini = executor.submit(ask_gemini, prompt, config)
    future_chatgpt = executor.submit(ask_chatgpt, prompt, config)
    gemini_raw = future_gemini.result(timeout=90)
    chatgpt_raw = future_chatgpt.result(timeout=90)
```

`ThreadPoolExecutor` is stdlib (Python 3.2+, confirmed available at Python 3.14.4).
Timeout handling: `future.result(timeout=90)` raises `concurrent.futures.TimeoutError`;
catch it and set that backend's result to a `"Error: timeout"` string — same pattern
as `run_command`'s existing `subprocess.TimeoutExpired` handling (line 211).

Subprocess `&` alternative requires `communicate()` + poll loop — more code, less readable.
Recommendation: **use `ThreadPoolExecutor`**.

### 3. In-Place File Rewrite Pattern

**Sed-based slot rewrite** (referenced in D-03, analogous to `commands/audit-restore.md`
which uses `sed '/^<!--/,/^-->/d'`):

Python's `str.replace()` on file contents is simpler and avoids sed's multiline quoting:

```python
content = Path(report_path).read_text(encoding="utf-8")
SLOT = "_pending — run /council audit-review_"
if SLOT not in content:
    # malformed — slot already replaced or missing
    ...
new_section = "## Council verdict\n\n" + verdict_table_text
content = content.replace("## Council verdict\n\n" + SLOT, new_section)
Path(report_path).write_text(content, encoding="utf-8")
```

**YAML frontmatter mutation** — find `^council_pass: pending` line, replace value only:

```python
import re
content = re.sub(r'^council_pass: pending$', f'council_pass: {status}',
                 content, count=1, flags=re.MULTILINE)
```

`count=1` and `re.MULTILINE` ensures only the first occurrence (frontmatter) is replaced,
never a stray occurrence in the body.

**Atomicity:** The current `ask_chatgpt` uses `tempfile.NamedTemporaryFile` + `os.unlink`
(lines 406-438). For the report rewrite, Python `write_text()` is not atomic. Use the
`mktemp` + `os.replace()` pattern to be consistent with the repo's audit-skip atomicity
(`cat file tmp > new_tmp && mv new_tmp file`):

```python
import tempfile, os
with tempfile.NamedTemporaryFile(mode="w", delete=False,
        dir=Path(report_path).parent, suffix=".tmp",
        encoding="utf-8") as tmp:
    tmp.write(new_content)
    tmp_path = tmp.name
os.replace(tmp_path, report_path)
```

`os.replace()` is atomic on POSIX (same filesystem) and available Python 3.3+.

### 4. Backend Output Parsing — XML Markers (D-10)

Each backend must emit:

```text
<verdict-table>
| ID | verdict | confidence | justification |
|-----|---------|------------|---------------|
| F-001 | REAL | 0.9 | ... |
</verdict-table>

<missed-findings>
(none) or table rows
</missed-findings>
```

Extract with a simple regex, not an XML parser (output is plain text, not valid XML):

```python
import re

def extract_block(text, tag):
    """Extract content between <tag> and </tag> markers."""
    pattern = rf'<{tag}>(.*?)</{tag}>'
    m = re.search(pattern, text, re.DOTALL)
    if m:
        return m.group(1).strip()
    return None  # malformed — caller marks run as failed
```

Malformed output (no marker): set `council_pass: failed`, write one-line parse-error comment
to the verdict slot, exit non-zero. This is the only case where `brain.py` exits non-zero.

### 5. Test Scaffold — `test-audit-pipeline.sh` Idiom

`scripts/tests/test-audit-pipeline.sh` (448 lines) establishes the project's regression test
pattern. Reuse verbatim for `test-council-audit-review.sh`:

```bash
#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/scripts/tests/fixtures/council"
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-council-audit-review.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
report_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }
```

Fixture stubs (`stub-gemini.sh`, `stub-chatgpt.sh`): brain.py calls `ask_gemini` /
`ask_chatgpt` Python functions, not shell commands directly. Stubs must be **Python-callable**
or the test must override the `ask_gemini` / `ask_chatgpt` dispatch inside brain.py.

**Recommended stub approach:** Environment variable injection. Add to `run_audit_review()`:

```python
# Test hook: COUNCIL_STUB_GEMINI / COUNCIL_STUB_CHATGPT env vars override backend dispatch.
# Values: path to a script that emits canned verdict-table output on stdout.
import os
STUB_GEMINI = os.getenv("COUNCIL_STUB_GEMINI")
STUB_CHATGPT = os.getenv("COUNCIL_STUB_CHATGPT")
```

Then in the parallel dispatch section:

```python
if STUB_GEMINI:
    gemini_raw = run_command([STUB_GEMINI])
else:
    gemini_raw = ask_gemini(prompt, config)
```

The Bash test sets `COUNCIL_STUB_GEMINI=scripts/tests/fixtures/council/stub-gemini.sh`
and `COUNCIL_STUB_CHATGPT=...` before invoking `python3 brain.py --mode audit-review ...`.
This is simpler than monkey-patching Python functions and keeps stubs in Bash (shorter,
more readable) consistent with the rest of the test suite.

### 6. Makefile Test Wiring (Test 19)

Makefile `test:` target ends at line 109 (`echo "All tests passed!"`). Test 19 inserts
before the final echo:

```makefile
@echo ""
@echo "Test 19: council audit-review — verdict slot rewrite + parallel dispatch"
@bash scripts/tests/test-council-audit-review.sh
@echo ""
```

Current test 18 is at Makefile lines 106-108:

```text
@echo "Test 18: audit pipeline fixture — allowlist match + FP schema"
@bash scripts/tests/test-audit-pipeline.sh
@echo ""
```

---

## Validation Architecture

### Invariants to Assert (maps to D-15 a–g)

| Assertion | Test Mechanism | File Modified |
|-----------|---------------|---------------|
| (a) exits 0 with mocked backends | `python3 brain.py --mode audit-review --report fixture.md` → `$?` | `test-council-audit-review.sh` |
| (b) `## Council verdict` slot rewritten with verdict table | `grep -qF '<verdict-table>' REPORT` or check table header row present | same |
| (c) `council_pass:` mutated from `pending` | `grep -E '^council_pass: (passed|failed|disputed)$'` | same |
| (d) other sections byte-identical | `diff <(sed '/^council_pass:/d' PRE) <(sed '/^council_pass:/d' POST)` after also blanking out verdict slot | same |
| (e) disagreement (one REAL, one FP) → `disputed` | two separate stubs + check `council_pass: disputed` and `disputed` in verdict table | same |
| (f) malformed output → `failed` + parse-error | stub emitting no `<verdict-table>` marker → `$? != 0` + grep for parse-error in slot | same |
| (g) severity not reclassified | stub that emits a verdict table changing severity value; assert auditor's original severity unchanged | same |

### Test Fixture Structure

`scripts/tests/fixtures/council/audit-report.md` must contain:

- Valid YAML frontmatter with `council_pass: pending`
- `## Council verdict\n\n_pending — run /council audit-review_` (byte-exact U+2014)
- 3 findings: F-001 (obvious REAL), F-002 (obvious FALSE_POSITIVE), F-003 (disputed)
- Verbatim code blocks with `<!-- File: ... Lines: ... -->` headers

Two stub scripts:

```text
stub-gemini.sh  — emits canned <verdict-table> where F-001=REAL, F-002=FALSE_POSITIVE,
                   F-003=REAL (confidence 0.9)
stub-chatgpt.sh — emits canned <verdict-table> where F-001=REAL, F-002=FALSE_POSITIVE,
                   F-003=FALSE_POSITIVE (confidence 0.7)
→ F-003 disagreement = disputed, confidence min(0.9, 0.7) = 0.7
```

For severity-reclassification test (assertion g), a third stub (`stub-severity-reclass.sh`)
attempts to change `HIGH → MEDIUM` in the verdict table. The test asserts the original
finding's `**Severity:** HIGH` bullet is unchanged after the rewrite.

Note: severity reclassification rejection does NOT mean brain.py strips or modifies the
verdict table. The constraint is enforced by the prompt (D-05) and the test validates the
prompt's presence (the prompt file contains "DO NOT reclassify severity"). The test for (g)
can be a static check: `grep -q "DO NOT reclassify severity" prompts/audit-review.md`.

---

## Implementation Approach

### Artifact 1 — `scripts/council/brain.py` (modify, D-01/02/03/04/08/09/10)

**Step 1:** Add `import argparse` and `from concurrent.futures import ThreadPoolExecutor`
at the top (lines 1-30, after existing imports).

**Step 2:** Define system prompt constants for `audit-review` mode (analogous to
`GEMINI_SYSTEM` / `GPT_SYSTEM` at lines 49-63). These are used only in `run_audit_review()`.

**Step 3:** Add helper `extract_block(text, tag)` (see pattern above, ~8 lines).

**Step 4:** Add `rewrite_report(report_path, verdict_table, missed_findings, status)`:
reads report, mutates `council_pass:` via `re.sub`, replaces verdict slot via `str.replace`,
writes atomically via `os.replace()`.

**Step 5:** Add `run_audit_review(report_path, config)`:
- Validate report path (`get_validated_paths` reuse).
- Read report content (`read_files` or `Path.read_text`).
- Load prompt from `scripts/council/prompts/audit-review.md` (resolve relative to `brain.py`).
- Interpolate report content into prompt.
- Dispatch Gemini + ChatGPT in parallel via `ThreadPoolExecutor`.
- Handle timeouts: mark unavailable backend as `"Error: timeout"`.
- Parse `<verdict-table>` and `<missed-findings>` from each backend.
- Malformed output: call `rewrite_report(..., status="failed")`, print error, exit 1.
- Resolve per-finding verdicts (agree/disagree → disputed).
- Determine `council_pass` status: all REAL → `passed`; ≥1 FP agreed → `failed`; ≥1 disputed → `disputed`.
- Call `rewrite_report(...)`.
- Print collated verdict table to stdout.

**Step 6:** Refactor `main()` to use `argparse` with backward-compat positional fallback
(see pattern in Existing Patterns §1). `load_config()` called before branching to either mode.

**Step 7:** Add env-var stub hooks `COUNCIL_STUB_GEMINI` / `COUNCIL_STUB_CHATGPT` in
`run_audit_review()` (test-only; guarded by env var check).

### Artifact 2 — `scripts/council/prompts/audit-review.md` (new, D-05/06/07)

New directory: `scripts/council/prompts/`. File: `audit-review.md`.

Required literal strings (byte-exact):

- `DO NOT reclassify severity` — in a CONSTRAINTS section near the top.
- `| ID | verdict | confidence | justification |` — the per-finding table header.
- `<verdict-table>` and `</verdict-table>` — output wrapper markers.
- `<missed-findings>` and `</missed-findings>` — missed-findings wrapper markers.
- `_pending — run /council audit-review_` — quoted in the prompt as the slot string to replace.
- `**Severity:**`, `**Rule:**`, `**Location:**`, `**Claim:**` — bullet label references so
  backends know how to navigate the report.

Structure (100-180 line target):

```text
# Council Audit-Review Prompt

## Your Role
## Constraints
  - DO NOT reclassify severity ...
  - Cite tokens from the embedded Code block in every justification ...
  - Verdict values: REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT
## Report Schema (what you are reading)
  - YAML frontmatter fields
  - Finding entry bullet labels
  - Verbatim code block format (<!-- File: ... Lines: ... --> header)
## Output Format
  ### Verdict Table
    <verdict-table> block with column spec
  ### Missed Findings
    <missed-findings> block with row spec
## Severity Reference
  See: components/severity-levels.md (CRITICAL/HIGH/MEDIUM/LOW definitions)
## Report to Review
{REPORT_CONTENT}
```

### Artifact 3 — `commands/audit.md` (no new edit needed for Phase 15)

`commands/audit.md` Phase 5 already has the full Council handoff contract (see `commands/audit.md`
lines 165-170 and the `## Council Handoff (Phase 15)` section at lines 191-195). D-11 says the
invocation is a user command in conversation — this is already documented. **No code change
needed** to `commands/audit.md` for Phase 15. The FALSE_POSITIVE nudge (D-12) and disputed
resolution (D-13) are behaviors of the Council orchestrator output that `/audit` interprets —
they are documented in `commands/audit.md` `## Council Handoff` section already.

If the planner disagrees, the only edit needed is adding the explicit FP-nudge and disputed-
resolution UX details to the `## Council Handoff` section (~10 lines).

### Artifact 4 — `commands/council.md` (extend, D-14)

Add `## Modes` section after the existing `## Usage` section (currently line 9). Target:

```markdown
## Modes

### validate-plan (default)

Invocation: `/council <feature description>`
...

### audit-review

Invocation: `/council audit-review --report <path-to-audit-report>`
Produces: Per-finding verdict table (REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT),
  a missed-findings section, and in-place Council verdict slot rewrite.
When to use: After every `/audit` run (Phase 5 of the audit workflow — mandatory).
Prompt: `scripts/council/prompts/audit-review.md`
```

Length addition ≤ 60 lines. Total ≤ 210 lines (from 144). Must pass markdownlint.

### Artifact 5 — `scripts/tests/test-council-audit-review.sh` (new, D-15)

Seven test groups mapping to D-15 assertions (a)–(g). See Validation Architecture above.

### Artifact 6 — `scripts/tests/fixtures/council/` (new, D-16)

Three files: `audit-report.md`, `stub-gemini.sh`, `stub-chatgpt.sh`.
Optional fourth: `stub-severity-reclass.sh` (for assertion g if implemented as runtime check).
Stubs are Bash scripts that `echo` canned `<verdict-table>` content to stdout.

---

## Risks and Pitfalls

### Pitfall 1 — Em-Dash Byte Sensitivity (CRITICAL)

The slot grep target `_pending — run /council audit-review_` uses U+2014 (em-dash `—`), not
hyphen-minus `-` (U+002D) or en-dash `–` (U+2013). Any text editor auto-correction or copy-
paste from a web browser can silently substitute the wrong character.

**Mitigation:**

- In Python: use the Unicode escape `—` in the literal string, never type the character.
- In the test: verify the fixture file's em-dash byte with `python3 -c "open('fixture.md').read().find('—')"` (identical to the existing `test-audit-pipeline.sh` Test Group 6 pattern at lines 299-320).
- In the prompt file: use the literal `—` character only in the quoted example; the instruction must say "U+2014 em-dash" explicitly.

### Pitfall 2 — `str.replace()` vs Python `re.sub()` for Slot Rewrite

`str.replace()` on the slot string is fine for the body rewrite because the slot string is
unique and byte-exact. However, `## Council verdict\n\n_pending...` assumes the exact newline
sequence. Audit reports are written by Claude Code (macOS/Linux) — LF only, no CRLF. Still:

**Mitigation:** Strip trailing whitespace from the located slot line before comparing.
Read the report with `encoding="utf-8"` (already the pattern in `read_files()` at line 269).

### Pitfall 3 — `council_pass:` Mutation Hits Wrong Occurrence

If the report body mentions `council_pass:` in a code block or quote, the `re.sub` with
`re.MULTILINE` and `count=1` will hit the frontmatter first only if the frontmatter appears
before the body. YAML frontmatter always starts at byte 0 and ends before the `---` closing
line. This is safe. But add `count=1` to be explicit.

### Pitfall 4 — `ThreadPoolExecutor.result(timeout=90)` Exception Type

`future.result(timeout=N)` raises `concurrent.futures.TimeoutError` (NOT `subprocess.TimeoutExpired`).
Must import and catch separately:

```python
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
...
try:
    gemini_raw = future_gemini.result(timeout=90)
except FuturesTimeoutError:
    gemini_raw = "Error: Gemini backend timed out after 90s"
```

Aliasing avoids collision with the built-in `TimeoutError`.

### Pitfall 5 — `argparse` Breaks Existing `brain` Alias

The installed `brain` alias (set by `init-claude.sh:533-553`) calls
`python3 ~/.claude/council/brain.py "$@"` — passing the plan as a quoted positional.
With argparse, `brain "My plan"` becomes `args.plan = "My plan"` and `args.mode = None`.
The backward-compat path sets `args.mode = "validate-plan"` and proceeds. **Safe.**

But: `brain` alias with no arguments currently prints "Usage: python3 brain.py ..." and
exits 1. After argparse, `parser.print_help()` + `sys.exit(1)` gives the same behavior.
The help text will change but behavior is equivalent.

### Pitfall 6 — Stubs Must Emit Deterministic Output Without API Keys

The CI environment has no `GEMINI_API_KEY` or `OPENAI_API_KEY`. The stub env-var hook
(Pitfall-avoiding design from §Existing Patterns §5) means `brain.py --mode audit-review`
in CI uses the stubs and never calls real backends. `load_config()` (lines 123-178) still
validates that config keys exist in structure, but the `_gemini_available` / `_openai_available`
flags guard the actual calls. Stub env vars bypass the availability checks entirely — add a
short-circuit before the availability check in `run_audit_review()`.

### Pitfall 7 — Makefile `test:` Target Requires `shellcheck` to Pass on New Script

`make shellcheck` runs `find scripts templates/global -name '*.sh'` (Makefile line 35).
`test-council-audit-review.sh` and stub scripts are under `scripts/` and will be linted.
Common shellcheck issues in test scripts: unquoted variables, `[[ ]]` without `set -e`,
using `$?` after piped commands. The existing `test-audit-pipeline.sh` passes shellcheck —
follow its patterns exactly.

---

## Open Questions (RESOLVED)

1. **Prompt location: relative to `brain.py` or config path?**
   - D-05 says `scripts/council/prompts/audit-review.md` (repo path).
   - When installed, `brain.py` lives at `~/.claude/council/brain.py`. The prompts directory
     needs to be installed alongside it, or `brain.py` resolves the path relative to itself
     (`Path(__file__).parent / "prompts" / "audit-review.md"`).
   - **Recommendation:** `Path(__file__).parent / "prompts" / "audit-review.md"` — works
     both in the repo (`scripts/council/`) and when installed (`~/.claude/council/`).
   - **Planner must decide:** whether `scripts/council/prompts/` is added to the
     `setup-council.sh` install list (Phase 17 scope) or is carried into the prompt inline.
   - For Phase 15 (local repo use), `Path(__file__).parent` resolves correctly from
     `scripts/council/brain.py`.

2. **`commands/audit.md` edit scope**
   - D-11 says Phase 5 "invokes `/council audit-review`" — already documented in `commands/audit.md`.
   - D-12 (FP nudge text) and D-13 (disputed UX text) are NOT yet in `commands/audit.md`.
   - The `## Council Handoff (Phase 15)` section (lines 191-195) is a stub. Phase 15 should
     fill in the FP-nudge and disputed-resolution behavior verbatim.
   - **Recommendation:** Add ~15 lines to `commands/audit.md` `## Council Handoff` section
     documenting the FP nudge and disputed prompt — this makes the contract explicit for users.

3. **Severity reclassification test (assertion g) — static or runtime?**
   - Option A (static): Assert `grep -q "DO NOT reclassify severity" prompts/audit-review.md`.
     Fast, reliable, no stub needed.
   - Option B (runtime): Create `stub-severity-reclass.sh` that emits a verdict table with
     changed severity values; assert original finding severity is unchanged in the report.
     This would test the runtime non-reclassification behavior.
   - **Recommendation:** Implement both. Static is cheap and direct. Runtime would only catch
     a bug in the rewrite logic (which doesn't touch severity at all) — low value, higher
     fixture complexity. Planner can decide if assertion (g) is purely static.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.8+ | `brain.py` | Yes | 3.14.4 | — |
| `concurrent.futures` | Parallel dispatch | Yes | stdlib | — |
| `argparse` | Mode flag | Yes | stdlib | — |
| `re` module | Slot rewrite | Yes | stdlib | — |
| `shellcheck` | `make shellcheck` on new .sh files | Assumed yes | — | `brew install shellcheck` |
| `markdownlint` | `make mdlint` on new .md files | Assumed yes | — | `npm install -g markdownlint-cli` |
| `GEMINI_API_KEY` / `OPENAI_API_KEY` | Live backend calls | Not required in CI | — | Stub env vars |

---

## Sources

### Primary (HIGH confidence — read in this session)

- `scripts/council/brain.py` (678 lines) — full source, all function signatures confirmed
- `components/audit-output-format.md` — full schema, slot string, frontmatter keys
- `commands/audit.md` — Phase 5 handoff contract, current state
- `scripts/tests/test-audit-pipeline.sh` (494 lines) — test idiom confirmed
- `Makefile` (246 lines) — Test 19 insertion point confirmed (line 109)
- `.planning/phases/15-council-audit-review-integration/15-CONTEXT.md` — all decisions

### Secondary (HIGH confidence — read in this session)

- `commands/council.md` (144 lines) — current structure confirmed, extension target
- `commands/audit-skip.md` — FP nudge target confirmed (COUNCIL-05 boundary)
- `scripts/council/config.json.template` — schema confirmed, no timeout key
- `scripts/council/README.md` — confirmed no mention of prompts/ subdir
- `.planning/REQUIREMENTS.md` — COUNCIL-01..06 text confirmed

---

## Metadata

**Confidence breakdown:**

- Domain overview: HIGH — brain.py fully read, current behavior confirmed
- Existing patterns: HIGH — all code excerpts from read source, not training data
- Implementation approach: HIGH — all patterns are derived from existing code in the repo
- Risks/pitfalls: HIGH — verified against actual code (line numbers cited)
- Open questions: MEDIUM — two are discretionary; one (prompt path) is a real constraint gap

**Research date:** 2026-04-25
**Valid until:** 2026-05-25 (stable Python stdlib; no external dependencies)
