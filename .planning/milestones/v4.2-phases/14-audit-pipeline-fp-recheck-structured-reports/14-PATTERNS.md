# Phase 14: Audit Pipeline — FP Recheck + Structured Reports - Pattern Map

**Mapped:** 2026-04-25
**Files analyzed:** 6 (2 modified, 4 created)
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `commands/audit.md` | command/prompt | request-response (Claude runtime) | `commands/audit.md` (self — current 159-line state) | exact (extend in place) |
| `components/audit-fp-recheck.md` | component/prompt | request-response | `components/self-check-section.md` | role-match |
| `components/audit-output-format.md` | component/prompt | request-response | `components/report-format.md` | role-match |
| `scripts/tests/fixtures/audit/` | test fixture | batch | `scripts/tests/fixtures/` (existing dirs) | role-match |
| `scripts/tests/test-audit-pipeline.sh` | test | batch | `scripts/tests/test-setup-security-rtk.sh` | exact |
| `Makefile` | config | batch | `Makefile` lines 98-101 (test target body) | exact |

---

## Pattern Assignments

### `commands/audit.md` (command, request-response — MODIFY)

**Analog:** `commands/audit.md` itself (current state, lines 1-160)

**Current structure — safe splice points:**

The current file has 8 sections. The 6-phase workflow contract inserts best after `## Usage`
(line 36) and before `## Quick Checks` (line 39). The existing `## Audit Workflow` (lines
82-98) is REPLACED by the new 6-phase contract. `## Output Format` (lines 101-128) is
REPLACED by a pointer to `components/audit-output-format.md`.

**Usage section pattern** (lines 9-36 — keep structure, update type list):

```text
## Usage

/audit <type> [scope]

**Types:**

- `security` — Security vulnerabilities check
- `code-review` — Code quality review
- `performance` — Performance optimization check
- `deploy-checklist` — Pre-deployment checklist
- `mysql-performance` — MySQL query and schema performance
- `postgres-performance` — PostgreSQL query and schema performance
- `design-review` — Architecture and design review
- `full` — Run all 7 audits in sequence (each produces its own typed report)

**Aliases (backward compat):** `code` = `code-review`, `deploy` = `deploy-checklist`
```

**Framework detection table pattern** (lines 132-140 — keep verbatim):

```text
## Framework Detection

Automatically detect framework and use appropriate template:

| File | Framework | Template |
|------|-----------|----------|
| `artisan` | Laravel | templates/laravel/ |
| `next.config.*` | Next.js | templates/nextjs/ |
| `package.json` only | Node.js | templates/base/ |
| Other | Generic | templates/base/ |
```

**Related Commands pattern** (lines 154-160 — keep, append audit-skip and audit-restore):

```text
## Related Commands

- `/verify` — fast automated checks (build, types, lint, tests)
- `/deps audit` — focused dependency vulnerability scan
- `/perf` — detailed performance profiling
- `/deploy` — pre-deploy safety checks
- `/audit-skip` — suppress a confirmed false positive into the allowlist
- `/audit-restore` — remove an allowlist entry that turned out to be a real bug
```

---

### `components/audit-fp-recheck.md` (component, request-response — CREATE)

**Analog:** `components/self-check-section.md`

**Top-of-file description pattern** (self-check-section.md lines 1-3):

```markdown
# [Component Name]

[One-sentence description of what this component is for.]
```

**Section separator pattern** (self-check-section.md line 6):

```markdown
---
```

**Numbered-step list pattern** (self-check-section.md lines 9-12 — Reality Filter table
style). For audit-fp-recheck.md the 6 steps are an ordered list (MD029 style=ordered),
not a table, so use this sequential numbering style from commands/audit-skip.md lines 42-89:

```markdown
1. **Step name** — action description (constraint in parens).
2. **Step name** — action description.
```

**Checklist inside a fenced block pattern** (self-check-section.md lines 36-43):

```text
[ ] item one
[ ] item two
```

Use ` ```text ` fence (MD040 — language required; `text` for plain checklist content).

**Component closing — no trailing section**, file ends after last content block.

**Full structure to follow for `audit-fp-recheck.md`:**

```text
# [Title]

[One-sentence purpose]

---

## Procedure

[Brief intro sentence]

1. **[Step name]** — [action] ([constraint]).
2. **[Step name]** — [action] ([constraint]).
3. **[Step name]** — [action] ([constraint]).
4. **[Step name]** — [action] ([constraint]).
5. **[Step name]** — [action] ([constraint]).
6. **[Step name]** — [action] ([constraint]).

---

## Skipped (FP Recheck) Entry Format

[Intro sentence]

| path:line | rule | dropped_at_step | one_line_reason |
|---|---|---|---|
| [example] | [example] | 2 | [≤100 chars, code-grounded] |

---

## When a Finding Survives All Six Steps

[Short sentence directing to ## Findings block]
```

---

### `components/audit-output-format.md` (component, request-response — CREATE)

**Analog:** `components/report-format.md`

**Top-level structure pattern** (report-format.md lines 1-10):

```markdown
# [Component Name]

[One-sentence description]

---

## [Primary Section]

[Intro sentence]

```[language]
[example content]
```
```

**Type-specific differences section pattern** (report-format.md lines 48-74 — use for the
7-slug mapping table):

```markdown
## Type Slug → Prompt File Map

| `/audit` argument | Report path | Prompt file |
|---|---|---|
| `security` | `.claude/audits/security-<timestamp>.md` | `SECURITY_AUDIT.md` |
```

**Fenced block language conventions** (from RESEARCH.md + .markdownlint.json):

- Report skeleton: ` ```text ` (MD040 satisfied, no syntax highlighting implied)
- YAML frontmatter example: ` ```yaml `
- Entry template: ` ```markdown `
- HTML range comments inside examples: use ` ```text ` wrapper (MD033 disabled, inline
  HTML is allowed in content; but inside a code block it renders literally)

**XML wrapper style** (preferred per D-03 "XML for parser stability"):

Use `<output_format>` XML wrapper around the report skeleton to signal parser-stable
contract to Phase 15. Pattern from commands/audit-skip.md — that file uses prose steps
with fenced bash blocks. For audit-output-format.md use:

```markdown
<output_format>

[report skeleton here as ```text block]

</output_format>
```

**Full structure to follow for `audit-output-format.md`:**

```text
# [Title]

[One-sentence description]

---

## Report Path

[path pattern + date command]

## YAML Frontmatter

[yaml example block]

## Section Order (Fixed)

[numbered list — sections 1-6 in D-13 order]

## Finding Entry Schema (### Finding F-NNN)

[numbered list — 9 fields in D-14 order]

## Verbatim Code Block Format (AUDIT-03)

[examples for normal and clamped cases]

## Extension → Language Fence Map

[table from RESEARCH.md]

## Full Report Skeleton

<output_format>
[```text block with complete report template]
</output_format>

## Council Verdict Slot

[literal slot string + Phase 15 note]
```

---

### `scripts/tests/fixtures/audit/` (test fixture directory — CREATE)

**Analog:** `scripts/tests/fixtures/` (existing flat fixture files + `sp-cache/` subdirectory)

**Fixture file pattern:** Plain flat files (no special format). Existing fixtures are JSON
files (`manifest-migrate-v2.json`, `manifest-update-v2.json`) and directories (`sp-cache/`).
The audit fixture follows the same sibling pattern:

```text
scripts/tests/fixtures/audit/
├── allowlist-populated.md      # a valid audit-exceptions.md with one real entry
├── allowlist-empty.md          # audit-exceptions.md with ## Entries heading but no entries
└── sample-project/
    ├── src/
    │   └── auth.ts             # ≥20-line TypeScript file; flagged finding at line 8
    └── lib/
        └── utils.py            # ≥15-line Python file; allowlist-suppressed finding at line 5
```

**`allowlist-populated.md` content must follow the exact heading format from audit-skip.md
lines 135-136** — heading is `### <path>:<line> — <rule>` with U+2014 em-dash, followed by
bullet list (`- **Date:**`, `- **Council:**`, `- **Reason:**`). Must also have the seeded
HTML-comment example block (as in `templates/base/rules/audit-exceptions.md`) to test the
comment-stripping path.

**`allowlist-empty.md` content:** YAML frontmatter + `## Entries` heading + no real entries
(verifies D-06 graceful-skip-when-empty path).

---

### `scripts/tests/test-audit-pipeline.sh` (test, batch — CREATE)

**Analog:** `scripts/tests/test-setup-security-rtk.sh` (closest match: same PASS/FAIL
counter idiom, `report_pass`/`report_fail` helpers, `SCRATCH` temp dir, `trap EXIT`)

**Shebang + header pattern** (test-setup-security-rtk.sh lines 1-7):

```bash
#!/bin/bash
# Claude Code Toolkit — test-audit-pipeline.sh
# [one-line description]
# Usage: bash scripts/tests/test-audit-pipeline.sh
# Exit: 0 = all pass, 1 = any fail
```

**set + REPO_ROOT pattern** (test-setup-security-rtk.sh lines 9-11):

```bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
```

**SCRATCH temp dir + trap pattern** (test-setup-security-rtk.sh lines 17-18):

```bash
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-audit-pipeline.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT
```

**PASS/FAIL counter + report helpers pattern** (test-setup-security-rtk.sh lines 20-22):

```bash
PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
```

**Results + exit pattern** (test-setup-security-rtk.sh lines 104-108):

```bash
echo ""
echo "Results: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

**Note:** `test-backup-lib.sh` uses a richer `assert_eq` / `assert_contains` helper style
(lines 22-50) which is also valid for the audit pipeline test. Use whichever is clearer
per assertion — the PASS/FAIL counter and exit pattern are mandatory; helper style is
discretionary.

**`assert_contains` pattern from test-backup-lib.sh** (lines 33-42) — use for grep-based
field presence assertions:

```bash
assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  PASS: ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL: ${msg}"
        echo "    expected to contain: ${needle}"
        echo "    actual: ${haystack}"
    fi
}
```

**Complete test structure for `test-audit-pipeline.sh`:**

```bash
#!/bin/bash
# Claude Code Toolkit — test-audit-pipeline.sh
# Validates audit pipeline fixtures: allowlist parser, FP schema, report path pattern.
# Usage: bash scripts/tests/test-audit-pipeline.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/scripts/tests/fixtures/audit"

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-audit-pipeline.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# [test scenarios here]

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

---

### `Makefile` (config — MODIFY: add Test 17)

**Analog:** Makefile lines 98-101 (existing Test 16 block in the `test:` target)

**Test invocation pattern** (Makefile lines 99-101 — verbatim structure):

```makefile
	@echo ""
	@echo "Test 16: full install matrix"
	@bash scripts/tests/test-matrix.sh
	@echo ""
```

**Test 17 addition — insert immediately before the final `@echo "All tests passed!"` line
(currently line 102):**

```makefile
	@echo "Test 17: audit pipeline fixture — allowlist match + FP schema"
	@bash scripts/tests/test-audit-pipeline.sh
	@echo ""
```

**Critical formatting:** Makefile recipe lines use a literal TAB character (not spaces).
Every `@echo` and `@bash` line must be indented with a TAB. The surrounding pattern from
existing tests confirms: one `@echo ""` blank separator before, one `@echo ""` after, then
the `@echo "All tests passed!"` closer.

**`.PHONY` line** (Makefile line 1): Add `test-audit-pipeline` to `.PHONY` only if a
standalone `test-audit-pipeline:` target is also added. If Test 17 is inline in `test:`,
no `.PHONY` change is needed.

---

## Shared Patterns

### Prompt-Level Directive Style (Markdown-as-Code)

**Source:** `commands/audit-skip.md`, `commands/audit-restore.md`
**Apply to:** `commands/audit.md` (extended), `components/audit-fp-recheck.md`,
`components/audit-output-format.md`

Pattern: Instructions to Claude are written as imperative prose or numbered steps, often
with `bash`-fenced blocks showing the _pattern_ Claude should follow at runtime (not shell
executed by the installer). The word "Step N —" is used for numbered process steps.

```markdown
### Step N — [Action Name]

[Prose describing what Claude must do]

```bash
# Pattern Claude follows at runtime using its own tools
...
```
```

### Markdownlint Compliance Guards

**Source:** `.markdownlint.json` (MD040, MD031, MD032, MD026, MD024 siblings_only, MD029)
**Apply to:** All 3 markdown deliverables

Rules that bite new authors:

- Every fenced block needs a language tag — use `text` for plain content, `bash` for shell,
  `yaml` for YAML, `markdown` for markdown examples.
- Blank line required BEFORE and AFTER every fenced block AND every list.
- No trailing punctuation on headings (`?`, `:`, `.`, `!` all forbidden).
- Ordered lists use sequential numbers (1. 2. 3. — not 1. 1. 1.).

### PASS/FAIL Test Counter

**Source:** `scripts/tests/test-setup-security-rtk.sh` lines 20-22 and 104-108
**Apply to:** `scripts/tests/test-audit-pipeline.sh`

```bash
PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
# ... tests ...
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then exit 1; fi
```

### Em-Dash Literal (U+2014)

**Source:** `commands/audit-skip.md` line 135 and 148
**Apply to:** `components/audit-fp-recheck.md` (Skipped table example), `commands/audit.md`
(Phase 0 allowlist-read instruction), `scripts/tests/fixtures/audit/allowlist-populated.md`

The heading format `### <path>:<line> — <rule>` uses the literal `—` character (U+2014),
not en-dash (U+2013) or hyphen-minus (U+002D). Do not HTML-encode it. The test script must
verify the byte with `od -c` or `python3 -c "import sys; [print(hex(ord(c))) for c in
open(f).read(400)]"` against the fixture file.

### HTML Comment Stripping Before Allowlist Match

**Source:** `commands/audit-restore.md` (post-Phase-13-05 fix — lines covering sed pattern)
**Apply to:** `commands/audit.md` Phase 0 prose, `scripts/tests/test-audit-pipeline.sh`

```bash
sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"
```

Must precede any `grep -Fxq "### ..."` match. The fixture `allowlist-populated.md` must
include the seeded HTML-comment example block to exercise this code path in tests.

---

## No Analog Found

All 6 files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `commands/`, `components/`, `scripts/tests/`, `Makefile`
**Files read:** `commands/audit.md`, `commands/audit-skip.md`, `commands/audit-restore.md`,
`components/severity-levels.md`, `components/self-check-section.md`,
`components/report-format.md`, `scripts/tests/test-setup-security-rtk.sh`,
`scripts/tests/test-backup-lib.sh`, `scripts/tests/test-update-dry-run.sh`, `Makefile`
**Pattern extraction date:** 2026-04-25
