# Phase 15: Council Audit-Review Integration — Pattern Map

**Mapped:** 2026-04-25
**Files analyzed:** 9
**Analogs found:** 7 / 9 (2 new patterns: parallel dispatch, prompt template)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/council/brain.py` | orchestrator | request-response | `scripts/council/brain.py` itself (self-extension) | exact |
| `scripts/council/prompts/audit-review.md` | prompt-template | transform | `components/audit-fp-recheck.md` | role-match |
| `commands/audit.md` | doc | request-response | `commands/audit.md` itself (self-extension) | exact |
| `commands/council.md` | doc | request-response | `commands/council.md` itself (self-extension) | exact |
| `scripts/tests/test-council-audit-review.sh` | test | batch | `scripts/tests/test-audit-pipeline.sh` | exact |
| `scripts/tests/fixtures/council/audit-report.md` | fixture | — | `scripts/tests/fixtures/audit/allowlist-populated.md` + inline mock in `test-audit-pipeline.sh:341-409` | role-match |
| `scripts/tests/fixtures/council/stub-gemini.sh` | fixture/stub | — | none in codebase | no-analog |
| `scripts/tests/fixtures/council/stub-chatgpt.sh` | fixture/stub | — | none in codebase | no-analog |
| `Makefile` | build | — | `Makefile:106-109` (Test 18 wiring) | exact |

---

## Pattern Assignments

### `scripts/council/brain.py` (orchestrator, self-extension)

**Analog:** itself — `scripts/council/brain.py`

**Imports to add** (lines 22-29 are current imports; insert after line 29):

```python
import argparse
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
```

**Current `main()` entry point** (lines 445-452 — replace entirely):

```python
def main():
    if len(sys.argv) < 2:
        print("Usage: python3 brain.py \"Your implementation plan\"")
        print("       brain \"Your implementation plan\"")
        sys.exit(1)

    plan = sys.argv[1]
    validate_plan(plan)
    config = load_config()
```

**argparse migration pattern** (from RESEARCH.md §1 — no in-repo analog):

```python
def main():
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

    config = load_config()

    if args.mode == "audit-review":
        if not args.report:
            parser.error("--report is required with --mode audit-review")
        run_audit_review(args.report, config)
    else:
        validate_plan(args.plan)
        # ... existing validate-plan flow unchanged
```

**`run_command` pattern** (lines 196-215 — reuse unchanged for stub dispatch):

```python
def run_command(cmd_list, input_text=None, timeout=60):
    """Execute a command safely (no shell=True)."""
    try:
        process = subprocess.run(
            cmd_list,
            input=input_text,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=timeout
        )
        if process.returncode != 0:
            return f"Error (exit {process.returncode}): {process.stderr.strip()}"
        return process.stdout.strip()
    except subprocess.TimeoutExpired:
        return "Error: command timed out"
    except FileNotFoundError:
        return f"Error: command not found: {cmd_list[0]}"
    except Exception as e:
        return f"Error: {e}"
```

**Parallel dispatch pattern** (NEW — ThreadPoolExecutor; no in-repo analog):

```python
STUB_GEMINI = os.getenv("COUNCIL_STUB_GEMINI")
STUB_CHATGPT = os.getenv("COUNCIL_STUB_CHATGPT")

def dispatch_gemini(prompt, config):
    if STUB_GEMINI:
        return run_command([STUB_GEMINI])
    return ask_gemini(prompt, config)

def dispatch_chatgpt(prompt, config):
    if STUB_CHATGPT:
        return run_command([STUB_CHATGPT])
    return ask_chatgpt(prompt, config)

with ThreadPoolExecutor(max_workers=2) as executor:
    future_gemini = executor.submit(dispatch_gemini, prompt, config)
    future_chatgpt = executor.submit(dispatch_chatgpt, prompt, config)
    try:
        gemini_raw = future_gemini.result(timeout=90)
    except FuturesTimeoutError:
        gemini_raw = "Error: Gemini backend timed out after 90s"
    try:
        chatgpt_raw = future_chatgpt.result(timeout=90)
    except FuturesTimeoutError:
        chatgpt_raw = "Error: ChatGPT backend timed out after 90s"
```

**`is_error_response` pattern** (lines 83-87 — reuse for backend failure detection):

```python
ERROR_PREFIXES = (
    "Error:",
    "Error (exit",
    "Gemini API error",
    "OpenAI API error",
)

def is_error_response(text):
    if not text:
        return True
    return any(text.startswith(p) for p in ERROR_PREFIXES)
```

**Atomic file write pattern** (lines 406-438 — `ask_chatgpt` tempfile pattern; adapt for report rewrite):

```python
import tempfile, os

with tempfile.NamedTemporaryFile(mode="w", delete=False,
        dir=Path(report_path).parent, suffix=".tmp",
        encoding="utf-8") as tmp:
    tmp.write(new_content)
    tmp_path = tmp.name
os.replace(tmp_path, report_path)   # atomic on POSIX same-filesystem
```

**Report save pattern** (lines 635-674 — analog for writing verdict output):

```python
scratchpad = Path.cwd() / ".claude" / "scratchpad"
scratchpad.mkdir(parents=True, exist_ok=True)
report_path = scratchpad / "council-report.md"
report_path.write_text(report, encoding="utf-8")
print(f"Report saved: {report_path}")
```

**Error handling pattern** (lines 583-595 — both-failed / one-failed guards):

```python
if skeptic_failed and pragmatist_failed:
    print("\n❌ Both reviewers failed — cannot render a verdict:")
    sys.exit(2)
if skeptic_failed:
    print(f"\n⚠️  Skeptic (Gemini) call failed: {gemini_verdict}")
    print("   Continuing with Pragmatist verdict only.")
```

**System prompt constant pattern** (lines 49-63 — define new AUDIT_REVIEW_GEMINI_SYSTEM and AUDIT_REVIEW_GPT_SYSTEM alongside existing GEMINI_SYSTEM / GPT_SYSTEM):

```python
GEMINI_SYSTEM = (
    "You are The Skeptic — a senior engineer who questions whether things "
    "should be built at all. ..."
)

GPT_SYSTEM = (
    "You are The Pragmatist — a battle-scarred production engineer. ..."
)
```

---

### `scripts/council/prompts/audit-review.md` (prompt-template, transform)

**Analog:** `components/audit-fp-recheck.md` (closest prompt-style document with byte-exact contract sections)

**Structure pattern** (from `audit-fp-recheck.md:1-49`):

```markdown
# <Title>

<one-line purpose statement>

Single source of truth for <what this governs>.

---

## <Section 1>

<prose + bullet-point constraints>

## <Section 2>

<table or ordered list with column-spec>

---

## Anti-Patterns

<do-NOT list with grounded reasons>
```

**Byte-exact contract strings to include** (from `components/audit-output-format.md` and Phase 14 D-07):

- `_pending — run /council audit-review_` — the slot placeholder (U+2014 em-dash, load-bearing)
- `| ID | verdict | confidence | justification |` — the per-finding verdict table header (COUNCIL-03)
- `<verdict-table>` / `</verdict-table>` — output wrapper markers (D-10)
- `<missed-findings>` / `</missed-findings>` — missed-findings markers (D-10)
- `DO NOT reclassify severity` — constraint phrase (COUNCIL-02, must appear in a CONSTRAINTS section)
- `**Severity:**`, `**Rule:**`, `**Location:**`, `**Claim:**`, `**Code:**` — finding bullet labels (D-18)
- `<!-- File: <path> Lines: <start>-<end> -->` — verbatim code block header format (D-07)

**Finding bullet label pattern** (from `test-audit-pipeline.sh:140` and `components/audit-output-format.md`):

```text
- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/auth.ts:14
- **Claim:** <one-line claim>

**Code:**

<!-- File: src/auth.ts Lines: 1-24 -->

```ts
...
```

**Data flow:**
**Why it is real:**
**Suggested fix:**
```

**Constraint section pattern** (from `components/audit-fp-recheck.md:9-18` — step-by-step with fail-fast):

```markdown
## Constraints

1. **DO NOT reclassify severity** — the auditor's `**Severity:**` value is fixed.
   If you disagree with the severity, add a comment under `## Severity disagreements (advisory)`.
   Never modify the finding table.
2. **Cite tokens** — every `justification` field MUST reference concrete tokens visible
   in the embedded `<!-- File: ... Lines: ... -->` code block. Never paraphrase from memory.
3. **verdict values** — exactly one of: `REAL`, `FALSE_POSITIVE`, `NEEDS_MORE_CONTEXT`.
4. **confidence** — floating-point in `[0.0, 1.0]` (one decimal acceptable).
5. **justification** — ≤ 160 chars, grounded in code tokens.
```

**Severity reference pattern** (from `audit-fp-recheck.md:38` — reference by path, never redefine):

```markdown
## Severity Reference

See `components/severity-levels.md` for CRITICAL / HIGH / MEDIUM / LOW definitions.
The Council confirms `REAL` or `FALSE_POSITIVE` only — it does NOT change severity.
```

---

### `commands/audit.md` (doc, self-extension)

**Analog:** `commands/audit.md` itself (lines 192-206 — `## Council Handoff (Phase 15)` section)

**Current Phase 5 contract stub** (lines 165-170):

```markdown
### Phase 5 — Council Pass (Mandatory)

Implements **COUNCIL-01** handoff (full wiring lands in Phase 15).

After writing the report, invoke `/council audit-review --report <path-to-report>`.
The audit is reported as incomplete until the Council returns...
```

**Current Council Handoff section** (lines 192-194 — stub to expand ~15 lines):

```markdown
## Council Handoff (Phase 15)

Phase 5 of the workflow invokes `/council audit-review --report <path>`. Council is mandatory:
the audit run is reported as incomplete until the Council pass returns...
When Council marks a finding `FALSE_POSITIVE`, this command prints the verdict and prompts
the user to run `/audit-skip` to persist the exception (`/audit` never auto-writes the allowlist).
```

**FP nudge pattern to add** (D-12 behavior, based on Phase 13 `/audit-skip` UX convention):

```markdown
For each `FALSE_POSITIVE` verdict returned by Council, print:

```text
Council confirmed F-NNN as FALSE_POSITIVE.
To persist: /audit-skip <path>:<line> <rule> "<reason>"
```

`/audit` NEVER writes to `audit-exceptions.md` directly. `/audit-skip` is the only writer.
```

**Disputed resolution UX pattern to add** (D-13, mirrors `/audit-restore` `[y/N]` style):

```markdown
For each `disputed` verdict (Gemini and ChatGPT disagree), print the disagreement and prompt:

```text
F-NNN is disputed:
  Gemini: <g_verdict> (confidence <g_conf>) — <g_justification>
  ChatGPT: <c_verdict> (confidence <c_conf>) — <c_justification>

Choose: (R)eal — keep as a finding
        (F)alse positive — run /audit-skip
        (N)eeds more context — leave open in next audit
```

No default. The user must choose before the audit run is considered complete.
```

---

### `commands/council.md` (doc, self-extension)

**Analog:** `commands/council.md` itself (144 lines — extend with `## Modes` section)

**Current `## Usage` section** (lines 9-21 — insert `## Modes` immediately after):

```markdown
## Usage

```text
/council <feature description>
```

**Examples:**

- `/council add OAuth login with Google`
```

**`## Modes` section pattern** (modeled on existing `## When to Use` table structure, lines 25-35):

```markdown
## Modes

### validate-plan (default)

**Invocation:** `/council <feature description>`

**Produces:** Per-reviewer assessment (Problem Assessment, Simplicity Check, Concerns) and
a final consolidated verdict: `PROCEED / SIMPLIFY / RETHINK / SKIP`.

**When to use:** Before implementing any non-trivial feature or architectural change.

**Prompt:** Built into `brain.py` (`GEMINI_SYSTEM` / `GPT_SYSTEM` constants).

---

### audit-review

**Invocation:** `/council audit-review --report <path-to-audit-report>`

**Produces:** Per-finding verdict table (`REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT`),
a `## Missed findings` section, and in-place Council verdict slot rewrite in the report.

**When to use:** After every `/audit` run (Phase 5 of the audit workflow — mandatory).
The audit run is incomplete until Council returns.

**Prompt:** `scripts/council/prompts/audit-review.md`
```

**markdownlint compliance pattern** (from `commands/council.md` — horizontal rules `---` between major sections, blank lines around code blocks and lists):

```markdown
---

## Section Title

Text paragraph.

```text
code block
```

- list item
```

---

### `scripts/tests/test-council-audit-review.sh` (test, batch)

**Analog:** `scripts/tests/test-audit-pipeline.sh` (494 lines — exact structural match)

**Header + scaffold pattern** (lines 1-26):

```bash
#!/bin/bash
# Claude Code Toolkit - test-council-audit-review.sh
# Validates Phase 15 council audit-review mode: verdict slot rewrite,
# council_pass frontmatter mutation, parallel dispatch, disagreement handling.
# Usage: bash scripts/tests/test-council-audit-review.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/scripts/tests/fixtures/council"
BRAIN="$REPO_ROOT/scripts/council/brain.py"

if [ ! -d "$FIXTURE_DIR" ]; then
    printf 'ERROR: fixture dir not found at %s\n' "$FIXTURE_DIR" >&2
    exit 1
fi

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-council-audit-review.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
report_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }
```

**Test group section divider pattern** (lines 28-29):

```bash
# =============================================================================
# Test Group N — <description>
# =============================================================================
```

**`grep -qF` literal-string assertion pattern** (lines 162-166 — em-dash byte-exact check):

```bash
if grep -qF '_pending — run /council audit-review_' "$MOCK_REPORT"; then
    report_pass "Council slot string byte-exact (D-15): present in mock report"
else
    report_fail "Council slot string byte-exact (D-15): not found in mock report"
fi
```

**Python em-dash byte-integrity check pattern** (lines 299-320):

```bash
if python3 -c "
import sys
data = open('$FIXTURE').read()
idx = data.find('—')
if idx == -1:
    print('FAIL: em-dash not found'); sys.exit(1)
" 2>/dev/null; then
    report_pass "Em-dash byte integrity: U+2014 present in fixture"
else
    report_fail "Em-dash byte integrity: NOT U+2014 in fixture"
fi
```

**Inline heredoc fixture pattern** (lines 341-409 — mock report written to scratch):

```bash
MOCK_REPORT="$SCRATCH/mock-report.md"
cat > "$MOCK_REPORT" << 'REPORT_EOF'
---
audit_type: security
...
council_pass: pending
---
...
## Council verdict

_pending — run /council audit-review_
REPORT_EOF
```

**Results footer pattern** (lines 487-493):

```bash
printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

**Key assertions to implement** (D-15 a–g mapped to test group structure):

```bash
# (a) exits 0 with mocked backends
COUNCIL_STUB_GEMINI="$FIXTURE_DIR/stub-gemini.sh" \
COUNCIL_STUB_CHATGPT="$FIXTURE_DIR/stub-chatgpt.sh" \
python3 "$BRAIN" --mode audit-review --report "$SCRATCH/report.md"
[ $? -eq 0 ] && report_pass "..." || report_fail "..."

# (b) verdict table written — check for table header row
if grep -qF '| ID | verdict | confidence | justification |' "$SCRATCH/report.md"; then
    report_pass "Verdict table header present after Council run"
else
    report_fail "Verdict table header missing"
fi

# (c) council_pass mutated from pending
if grep -qE '^council_pass: (passed|failed|disputed)$' "$SCRATCH/report.md"; then
    report_pass "council_pass: mutated from pending"
else
    report_fail "council_pass: still pending after Council run"
fi

# (d) other sections byte-identical (diff pre/post excluding council_pass + verdict slot)
# Compare relevant sections excluding the two mutation targets

# (f) malformed output -> failed + parse-error
COUNCIL_STUB_GEMINI="$FIXTURE_DIR/stub-malformed.sh" ...
[ $? -ne 0 ] && report_pass "Malformed output: exits non-zero" || report_fail "..."
grep -qF 'Council parse error' "$SCRATCH/report.md" && report_pass "..." || report_fail "..."

# (g) severity NOT reclassified — static check on prompt file
if grep -q 'DO NOT reclassify severity' "$REPO_ROOT/scripts/council/prompts/audit-review.md"; then
    report_pass "Prompt: 'DO NOT reclassify severity' constraint present"
else
    report_fail "Prompt: severity constraint missing"
fi
```

---

### `scripts/tests/fixtures/council/audit-report.md` (fixture, —)

**Analog:** `scripts/tests/fixtures/audit/allowlist-populated.md` (YAML frontmatter pattern) + inline mock report in `test-audit-pipeline.sh:341-409` (finding entry structure)

**YAML frontmatter pattern** (from `test-audit-pipeline.sh:342-350`):

```markdown
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 3
skipped_allowlist: 0
skipped_fp_recheck: 0
council_pass: pending
---
```

**Finding entry pattern** (from `test-audit-pipeline.sh:362-408`):

```markdown
### Finding F-001

- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/auth.ts:14
- **Claim:** User-supplied id flows into a string-concatenated SQL query.

**Code:**

<!-- File: src/auth.ts Lines: 1-24 -->

```ts
const sql = "SELECT * FROM users WHERE id=" + id;
```

**Data flow:**

- `req.params.id` arrives from the HTTP route handler.
- Passed unchanged into `db.query()`.

**Why it is real:**

The literal string concatenation combines `req.params.id` directly into the SQL string.
No parameterized binding exists.

**Suggested fix:**

```ts
const sql = "SELECT * FROM users WHERE id=?";
db.query(sql, [id]);
```
```

**Council verdict slot pattern** (from `test-audit-pipeline.sh:406-408` and `components/audit-output-format.md`):

```markdown
## Council verdict

_pending — run /council audit-review_
```

**Fixture must contain 3 findings** (per D-16):

- F-001: obvious REAL (e.g. SQL injection with direct user input)
- F-002: obvious FALSE_POSITIVE (e.g. eval inside a build-time script)
- F-003: disputed (stub-gemini says REAL, stub-chatgpt says FALSE_POSITIVE)

---

### `scripts/tests/fixtures/council/stub-gemini.sh` (fixture/stub — no analog)

**No analog exists** in `scripts/tests/fixtures/` (only `audit/` subdirectory exists with `.md` fixtures; no stub scripts). This is a new pattern.

**Rationale for Bash stubs:** Consistent with the rest of the test suite (all tests are Bash). Shorter than Python equivalents. The env-var hook in `run_audit_review()` calls `run_command([STUB_PATH])` — same subprocess interface as the real Gemini CLI call.

**Pattern to follow** (from D-16 and RESEARCH.md §5):

```bash
#!/bin/bash
# stub-gemini.sh — deterministic Council audit-review output for tests.
# Emits canned <verdict-table> where F-001=REAL, F-002=FALSE_POSITIVE, F-003=REAL.
# Exit 0 always (simulates successful backend call).

cat << 'EOF'
<verdict-table>
| ID | verdict | confidence | justification |
|----|---------|------------|---------------|
| F-001 | REAL | 0.9 | SQL concatenation at auth.ts:14 with req.params.id flowing directly into db.query() |
| F-002 | FALSE_POSITIVE | 0.85 | eval at build.js:42 is guarded by isBuildTime(); never reached at request time |
| F-003 | REAL | 0.9 | innerHTML assignment at render.ts:88 receives unsanitized user.displayName |
</verdict-table>

<missed-findings>
(none)
</missed-findings>
EOF
```

**shellcheck compliance** (from Pitfall 7 in RESEARCH.md — must pass `make shellcheck`):

- Use `set -euo pipefail` at top
- Quote all variables
- Use `[[ ]]` for conditionals
- No unquoted expansions

---

### `scripts/tests/fixtures/council/stub-chatgpt.sh` (fixture/stub — no analog)

Same pattern as `stub-gemini.sh`. Key difference: F-003 verdict is `FALSE_POSITIVE` (creating the disagreement that results in `disputed`).

```bash
#!/bin/bash
# stub-chatgpt.sh — deterministic Council audit-review output for tests.
# Emits canned <verdict-table> where F-001=REAL, F-002=FALSE_POSITIVE, F-003=FALSE_POSITIVE.
# F-003 disagrees with stub-gemini.sh (REAL) -> disputed, confidence min(0.9, 0.7) = 0.7.

cat << 'EOF'
<verdict-table>
| ID | verdict | confidence | justification |
|----|---------|------------|---------------|
| F-001 | REAL | 0.95 | req.params.id directly concatenated into SQL at auth.ts:14 confirms injection path |
| F-002 | FALSE_POSITIVE | 0.88 | isBuildTime() guard at build.js:40 makes eval unreachable at runtime |
| F-003 | FALSE_POSITIVE | 0.7 | user.displayName is escaped by sanitizeHtml() at render.ts:85 before innerHTML |
</verdict-table>

<missed-findings>
(none)
</missed-findings>
EOF
```

---

### `Makefile` (build, Test 19 wiring)

**Analog:** `Makefile:106-108` (Test 18 wiring — exact pattern to copy)

**Current Test 18 block** (lines 106-108):

```makefile
@echo "Test 18: audit pipeline fixture — allowlist match + FP schema"
@bash scripts/tests/test-audit-pipeline.sh
@echo ""
```

**Test 19 insertion** (insert before line 109 `@echo "All tests passed!"`):

```makefile
@echo "Test 19: council audit-review — verdict slot rewrite + parallel dispatch"
@bash scripts/tests/test-council-audit-review.sh
@echo ""
```

---

## Shared Patterns

### Em-Dash Byte-Exact (U+2014) — Apply to All Files

**Source:** `scripts/tests/test-audit-pipeline.sh` (lines 162-166, 299-320) and `components/audit-output-format.md`

**Apply to:** `audit-report.md` fixture, `brain.py` slot-rewrite string constant, `audit-review.md` prompt quoted example

```bash
# Bash: use grep -F (fixed-string) never grep -E for the slot string
grep -qF '_pending — run /council audit-review_' "$FILE"
```

```python
# Python: use Unicode escape in the string constant, never type the character directly
COUNCIL_SLOT = "_pending — run /council audit-review_"
```

### shellcheck Compliance — Apply to All New .sh Files

**Source:** `scripts/tests/test-audit-pipeline.sh` (lines 1-8)

**Apply to:** `test-council-audit-review.sh`, `stub-gemini.sh`, `stub-chatgpt.sh`

```bash
#!/bin/bash
set -euo pipefail
# All variables quoted: "$VAR" not $VAR
# Double-bracket conditionals: [[ ]] not [ ]
# No unquoted expansions in grep/awk patterns
```

### markdownlint Compliance — Apply to All New .md Files

**Source:** `commands/council.md` (144 lines — passes CI markdownlint)

**Apply to:** `scripts/council/prompts/audit-review.md`, `commands/council.md` additions, `commands/audit.md` additions

Key rules (from `.markdownlint.json`):
- MD040: every fenced code block declares a language (use `text` for plain text)
- MD031: blank line before and after every fenced code block
- MD032: blank line before and after every list
- MD026: no trailing punctuation in headings

### Error Output Pattern — Apply to brain.py

**Source:** `brain.py:583-595` (reviewer-failure handling)

**Apply to:** `run_audit_review()` backend-failure and parse-error branches

```python
print(f"\n❌ Council parse error: {backend_name} returned no <verdict-table> marker")
# ... set council_pass = "failed", write one-line parse-error to slot, sys.exit(1)
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `scripts/tests/fixtures/council/stub-gemini.sh` | fixture/stub | — | No stub scripts exist anywhere under `scripts/tests/fixtures/`; only `.md` fixtures exist. Pattern established fresh from RESEARCH.md §5 env-var hook design. |
| `scripts/tests/fixtures/council/stub-chatgpt.sh` | fixture/stub | — | Same as above. |

---

## Metadata

**Analog search scope:** `scripts/`, `components/`, `commands/`, `Makefile`
**Files scanned:** `brain.py` (678 lines), `test-audit-pipeline.sh` (494 lines), `allowlist-populated.md`, `council.md` (144 lines), `audit.md` (206 lines), `audit-fp-recheck.md` (49 lines), `Makefile` (246 lines)
**Pattern extraction date:** 2026-04-25
