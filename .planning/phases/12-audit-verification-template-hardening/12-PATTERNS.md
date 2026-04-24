# Phase 12: Audit Verification + Template Hardening - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 6 (1 new audit doc, 2 modified planning docs, 1 modified Makefile, 1 modified CI workflow, 1 optional new validation script)
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.planning/phases/12-audit-verification-template-hardening/12-AUDIT.md` | documentation / verdict table | batch (15 claims → REAL/PARTIAL/FALSE per row) | `.planning/milestones/v4.0-phases/02-foundation/02-VALIDATION.md` (per-task table) | role-match |
| `.planning/REQUIREMENTS.md` (add AUDIT-01..15 + HARDEN-A-NN rows) | config / traceability table | transform (append rows to existing table) | `.planning/REQUIREMENTS.md` existing traceability block (lines 63-79) | exact |
| `.planning/ROADMAP.md` (fill Phase 12 goal block) | documentation | single-section edit | `.planning/ROADMAP.md` existing Phase 8..11 blocks (lines 44-91) | exact |
| `Makefile` (add Wave A validation target) | build / task runner | batch (lint/assert) | `Makefile` `agent-collision-static` target (lines 200-215) | exact |
| `.github/workflows/quality.yml` (add Wave A CI step) | CI config | batch | `.github/workflows/quality.yml` `validate-templates` job (lines 37-68) | exact |
| `scripts/validate-commands.py` (Wave A — if HARDEN-A approved) | utility / validator | batch (glob → assert markers) | `scripts/validate-manifest.py` | exact |

---

## Pattern Assignments

### `12-AUDIT.md` (documentation, batch verdict table)

**Analog:** `.planning/milestones/v4.0-phases/02-foundation/02-VALIDATION.md`

The closest structural match is the per-task verification map in Phase 2 VALIDATION.md: a table with fixed columns, one row per claim, status column with controlled vocabulary. Phase 12 uses `REAL/PARTIAL/FALSE` instead of `pending/green/red`, and adds an Evidence column requiring `file:line` citations per D-02.

**Table header pattern** (02-VALIDATION.md lines 39-41 — adapt column names):

```markdown
| Claim # | Claim Summary | Status | Evidence | Action |
|---------|---------------|--------|----------|--------|
```

**Status vocabulary** (from CONTEXT.md D-04):

```text
REAL    — finding is confirmed, has concrete file:line evidence, promotes to HARDEN-A-NN
PARTIAL — partially mitigated, still has a gap; may promote depending on user gate
FALSE   — claim is contradicted by evidence; no fix work
```

**Evidence format** (D-02 requirement — repo-relative path + line or range):

```text
scripts/init-claude.sh:289-294   (line range)
manifest.json:67-74              (single-section reference)
"not found" — glob returned empty (for FALSE claims about missing files)
```

**Action vocabulary** (D-04 + D-07):

```text
→ HARDEN-A-NN   (Wave A: schema/validation theme)
→ HARDEN-B-NN   (Wave B: install safety — deferred v4.2+)
→ HARDEN-C-NN   (Wave C: provenance/metadata — deferred v4.2+)
→ No action     (FALSE verdict — recorded for traceability, no fix)
→ Document only (FALSE but worth noting in CONTRIBUTING.md)
```

**Full row example** (following 02-VALIDATION.md row structure):

```markdown
| AUDIT-08 | No dry-run installer mode | FALSE | `scripts/tests/test-dry-run.sh:1` exists; `--dry-run` implemented in `init-claude.sh` and `update-claude.sh` | → No action |
```

**Document header** (follow existing planning doc conventions):

```markdown
# Phase 12: Audit Verification — Verdict Table

**Verified:** 2026-04-24
**Source:** ChatGPT pass-3 audit (15 template-level claims)
**Method:** grep/glob proof + code read per claim; 3 parallel Explore agents (claims 1-5, 6-10, 11-15)

## Verdict Summary

| Status | Count |
|--------|-------|
| REAL | TBD |
| PARTIAL | TBD |
| FALSE | TBD |

## Claim Verdicts

| Claim # | Claim Summary | Status | Evidence | Action |
|---------|---------------|--------|----------|--------|
```

**Markdownlint constraints** (from CLAUDE.md project conventions — all new markdown MUST pass):

- MD040: every fenced code block must declare a language (`bash`, `text`, `python`, `json`, `markdown`)
- MD031/MD032: blank lines before and after fenced blocks and lists
- MD026: no trailing punctuation in headings
- Table rows: pipe-aligned, no trailing spaces

---

### `.planning/REQUIREMENTS.md` — add AUDIT-01..15 and HARDEN-A-NN rows

**Analog:** `.planning/REQUIREMENTS.md` existing content (lines 1-79)

**New section to insert** after the `## UX Polish` section (before `## Future Requirements`):

```markdown
### Audit Verification

Traceability records for all 15 ChatGPT pass-3 template-level claims. Each
claim gets a REQ-ID regardless of verdict. FALSE verdicts are closed immediately;
REAL/PARTIAL verdicts that pass the user gate become HARDEN-A-NN requirements.

- [ ] **AUDIT-01**: [claim summary] — Status: REAL/PARTIAL/FALSE
...
- [ ] **AUDIT-15**: [claim summary] — Status: REAL/PARTIAL/FALSE

### Wave A Hardening (schema/validation theme)

HARDEN-A-NN requirements are populated only after the user gate in Plan 12.1
approves the corresponding REAL/PARTIAL Wave-A findings.

- [ ] **HARDEN-A-01**: [description]
```

**Traceability table rows to append** (lines 65-79 of REQUIREMENTS.md show the exact format):

```markdown
| AUDIT-01 | Phase 12 | Closed - FALSE |
| AUDIT-02 | Phase 12 | Closed - FALSE |
| AUDIT-03 | Phase 12 | REAL |
...
| AUDIT-15 | Phase 12 | Closed - FALSE |
| HARDEN-A-01 | Phase 12 | Planned |
```

**Status vocabulary for traceability table** (extends existing `Planned` convention):

```text
Planned          — HARDEN-A-NN approved and queued for Plan 12.2
REAL             — verdict row, fix pending user gate
Closed - FALSE   — verdict row, no fix work, paper trail only
Closed - PARTIAL — verdict row where gap is real but below v4.1 fix threshold
```

**Coverage line to update** (REQUIREMENTS.md line 79):

```markdown
**Coverage:** 11 / 11 requirements mapped to phases ✓
```

Becomes (example with 15 AUDIT rows + 3 HARDEN-A rows):

```markdown
**Coverage:** 29 / 29 requirements mapped to phases ✓
```

---

### `.planning/ROADMAP.md` — fill Phase 12 goal block

**Analog:** `.planning/ROADMAP.md` Phase 8 block (lines 44-55) — exact structural match

**Current Phase 12 block** (lines 104-113):

```markdown
### Phase 12: Audit Verification + Template Hardening

**Goal:** [To be planned]
**Requirements**: TBD
**Depends on:** Phase 11
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 12 to break down)
```

**Target pattern** (copy Phase 8 shape, lines 44-55):

```markdown
### Phase 12: Audit Verification + Template Hardening

**Goal**: Verify all 15 ChatGPT pass-3 template-level audit claims against
actual code; implement Wave A (schema/validation) REAL findings approved at
user gate; create full AUDIT-NN + HARDEN-A-NN REQ traceability
**Depends on**: Phase 11
**Requirements**: AUDIT-01..AUDIT-15, HARDEN-A-NN (count TBD after gate)
**Success Criteria** (what must be TRUE):

1. `12-AUDIT.md` exists with 15-row verdict table; every row has Status +
   Evidence (file:line) + Action; no row is blank or prose-only
2. REQUIREMENTS.md carries AUDIT-01..AUDIT-15 rows with correct statuses;
   FALSE rows are closed; REAL/PARTIAL rows have HARDEN wave assignment
3. HARDEN-A-NN REQs (user-approved subset) are implemented and wired into
   `make check`; CI passes
4. Wave B and Wave C REQs are defined in AUDIT.md but NOT entered in
   REQUIREMENTS.md until promoted in v4.2+
```

**Progress table row** to add after line 102:

```markdown
| 12. Audit Verification + Template Hardening | v4.1 | 0/2 | Not started | - |
```

---

### `Makefile` — add Wave A validation target (conditional on HARDEN-A approval)

**Analog:** `Makefile` `agent-collision-static` target (lines 200-215) — pure shell, no Python, `jq`-driven

If Wave A produces a `commands/` markdown linting target (AUDIT-12 PARTIAL finding — commands lack required section enforcement), the new Makefile target pattern copies `agent-collision-static` structure:

**New target pattern** (adapt from `agent-collision-static` lines 200-215):

```makefile
# Validate commands/*.md carry required sections (HARDEN-A-NN — Wave A).
# Greps each command file for ## Purpose, ## Usage headings.
validate-commands:
	@echo "Validating commands/*.md for required sections..."
	@ERRORS=0; \
	for f in commands/*.md; do \
		[ "$$f" = "commands/README.md" ] && continue; \
		if ! grep -q "^## Purpose" "$$f" 2>/dev/null; then \
			echo "❌ Missing ## Purpose: $$f"; ERRORS=$$((ERRORS+1)); \
		fi; \
		if ! grep -q "^## Usage" "$$f" 2>/dev/null; then \
			echo "❌ Missing ## Usage: $$f"; ERRORS=$$((ERRORS+1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then exit 1; fi; \
	echo "✅ All commands carry required sections"
```

**Hook into `check` target** (Makefile line 17 — exact pattern from Phase 7):

```makefile
# BEFORE (current):
check: lint validate validate-base-plugins version-align translation-drift agent-collision-static

# AFTER (Wave A addition):
check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands
```

**`.PHONY` extension** (Makefile line 1):

```makefile
.PHONY: help check lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands clean install
```

**Alternative: Python validator** (if HARDEN-A promotes `scripts/validate-commands.py`):
Use `validate` target's Python invocation pattern (Makefile lines 138-140):

```makefile
	@echo "Validating commands/*.md schema..."
	@python3 scripts/validate-commands.py
	@echo "✅ Commands schema valid"
```

Note: only add `validate-commands` if AUDIT-12 verdict is REAL or PARTIAL and user approves at gate. The exact target name and assertions depend on the verdict. Do NOT add it speculatively.

---

### `.github/workflows/quality.yml` — add Wave A CI step

**Analog:** `.github/workflows/quality.yml` `validate-templates` job (lines 37-68)

CI mirrors `make check` targets. Any new Makefile target added in Wave A gets a corresponding CI step in the `validate-templates` job (or a new job if it needs a different runner).

**Pattern for inline shell step** (copy `validate-templates` job, lines 42-67):

```yaml
      - name: Validate commands required sections
        run: |
          echo "Checking commands/*.md for required sections..."
          ERRORS=0

          for f in commands/*.md; do
            [ "$f" = "commands/README.md" ] && continue
            if ! grep -q "^## Purpose" "$f"; then
              echo "❌ Missing ## Purpose: $f"
              ERRORS=$((ERRORS + 1))
            fi
            if ! grep -q "^## Usage" "$f"; then
              echo "❌ Missing ## Usage: $f"
              ERRORS=$((ERRORS + 1))
            fi
          done

          if [ $ERRORS -gt 0 ]; then
            echo "Found $ERRORS errors"
            exit 1
          fi
          echo "✅ All commands valid"
```

**Alternative: `make validate-commands` call** (simpler, follows same-job pattern):

```yaml
      - name: Validate commands
        run: make validate-commands
```

The `make` invocation is cleaner and avoids duplicating the logic. Prefer it unless the job needs standalone Python (then add `python3` step).

**Job-level permissions** (quality.yml line 9 — do not change):

```yaml
permissions:
  contents: read
```

**SHA-pinned action pattern** (quality.yml lines 17, 28, 41 — never use tag-only):

```yaml
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
```

---

### `scripts/validate-commands.py` (Wave A, if promoted by HARDEN-A)

**Analog:** `scripts/validate-manifest.py` (lines 1-232) — exact role match

`validate-manifest.py` is the single best analog: Python 3, no pip dependencies, `sys.exit(0/1)`, `fail()` function printing to `stderr`, accumulates `errors` counter, explicit `REPO_ROOT` resolution via `os.path`.

**Header + constants pattern** (validate-manifest.py lines 1-46):

```python
#!/usr/bin/env python3
"""validate-commands.py — Validate commands/*.md carry required sections.

Exit 0 on pass. Exit 1 with stderr messages on any failure.

Checks performed:
  1. Every commands/*.md (except README.md) has a ## Purpose heading
  2. Every commands/*.md has a ## Usage heading
  3. Every fenced code block in commands/*.md declares a language (MD040)
"""

import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
COMMANDS_DIR = os.path.join(REPO_ROOT, "commands")

REQUIRED_HEADINGS = ["## Purpose", "## Usage"]
```

**`fail()` helper** (validate-manifest.py lines 58-59 — copy verbatim):

```python
def fail(message):
    print("ERROR: " + message, file=sys.stderr)
```

**Main loop pattern** (validate-manifest.py lines 62-226 — adapt for file iteration):

```python
def main():
    errors = 0

    if not os.path.isdir(COMMANDS_DIR):
        fail("commands/ directory not found at: " + COMMANDS_DIR)
        sys.exit(1)

    for name in sorted(os.listdir(COMMANDS_DIR)):
        if not name.endswith(".md") or name == "README.md":
            continue
        path = os.path.join(COMMANDS_DIR, name)
        with open(path, "r", encoding="utf-8") as fh:
            content = fh.read()
        for heading in REQUIRED_HEADINGS:
            if heading not in content:
                fail(name + ': missing required heading "' + heading + '"')
                errors += 1

    if errors > 0:
        print(
            "commands validation FAILED (" + str(errors) + " error(s))",
            file=sys.stderr,
        )
        sys.exit(1)

    print("commands validation PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

Note: The exact required headings depend on AUDIT-12 verdict and user gate. The above is a template pattern, not a final spec.

---

## Shared Patterns

### Planning document header block

**Source:** `.planning/REQUIREMENTS.md` lines 1-3, `.planning/ROADMAP.md` lines 1-3
**Apply to:** `12-AUDIT.md`

```markdown
# Phase 12: [Title]

**[Label]:** [date]
**Status:** [state]
```

### Traceability table 3-column format

**Source:** `.planning/REQUIREMENTS.md` lines 65-77
**Apply to:** new AUDIT-01..15 and HARDEN-A-NN rows in REQUIREMENTS.md

```markdown
| REQ-ID | Phase | Status |
|--------|-------|--------|
| AUDIT-01 | Phase 12 | Closed - FALSE |
| HARDEN-A-01 | Phase 12 | Planned |
```

The table already exists — append rows, do not recreate the header.

### Makefile ERRORS accumulator pattern

**Source:** `Makefile` `validate-base-plugins` target (lines 143-149), `agent-collision-static` (lines 203-215), `translation-drift` (lines 177-197)
**Apply to:** any new `validate-commands` or similar Wave A Makefile target

```makefile
	@ERRORS=0; \
	for f in ...; do \
		if ! grep -q "pattern" "$$f" 2>/dev/null; then \
			echo "❌ message: $$f"; ERRORS=$$((ERRORS+1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then exit 1; fi; \
	echo "✅ All items valid"
```

Critical syntax notes:
- `$$f` not `$f` inside Makefile recipe (double-dollar escapes Make expansion)
- `$$((ERRORS+1))` for arithmetic
- Each logical line ends with ` \` (space-backslash)
- Each recipe line starts with a tab character (not spaces)

### Python validator structure

**Source:** `scripts/validate-manifest.py` lines 1-232
**Apply to:** any new `scripts/validate-*.py` Wave A script

Key conventions from the analog:
- `#!/usr/bin/env python3` shebang, no pip imports
- `SCRIPT_DIR` / `REPO_ROOT` resolved via `os.path.abspath(__file__)` + `os.path.dirname`
- `fail(message)` prints to `sys.stderr`, does NOT exit immediately — allows error accumulation
- Accumulate `errors` counter, `sys.exit(1)` only at the end
- Final success: `print("X validation PASSED"); sys.exit(0)`

### CI job shell step structure

**Source:** `.github/workflows/quality.yml` `validate-templates` job steps (lines 42-68)
**Apply to:** any Wave A CI step

```yaml
      - name: [Description]
        run: |
          echo "[Checking...]"
          ERRORS=0

          [loop or check]

          if [ $ERRORS -gt 0 ]; then
            echo "Found $ERRORS errors"
            exit 1
          fi
          echo "✅ [Passed]"
```

### SHA-pinned `actions/checkout`

**Source:** `.github/workflows/quality.yml` lines 17, 28, 41
**Apply to:** any new job added to quality.yml

```yaml
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
```

Never use `@v4` tag alone — must pin to full SHA per CI/CD security rules in CLAUDE.md.

### Markdownlint compliance for new .md files

**Source:** `.markdownlint.json` + CLAUDE.md Markdown Formatting section
**Apply to:** `12-AUDIT.md`

Rules enforced by CI (markdownlint job):
- MD040: fenced code blocks must declare language — use `bash`, `text`, `python`, `json`, `markdown`, `yaml`
- MD031: blank line before and after every fenced code block
- MD032: blank line before and after every list
- MD026: no trailing `?`, `:`, `.`, `!` in headings
- MD024: duplicate headings allowed only across different parents (siblings_only=true)

---

## No Analog Found

All 6 file categories have close analogs in the codebase. No entries in this section.

The `12-AUDIT.md` verdict table is the only structurally novel artifact — but the column format (`Claim | Status | Evidence | Action`) maps cleanly to the per-task rows in `02-VALIDATION.md` and the output format declared in `project_next_session_audit.md`.

---

## Key Constraints for Planner

1. **Wave A is conditional.** `Makefile`, `quality.yml`, and `scripts/validate-commands.py` changes only happen if HARDEN-A-NN REQs are approved at the user gate between Plan 12.1 and Plan 12.2. Plan 12.1 must not implement them speculatively.

2. **POSIX-bash invariant.** Any Wave A validation added to `Makefile` must use POSIX-compatible Bash 3.2+ (`[[ ]]` not available in plain `sh`, but the repo uses `#!/bin/bash` headers — `[[ ]]` is fine). No Node/Python runtime dependency for shell targets; Python only for `scripts/validate-*.py` invocations already established in `validate` target.

3. **`validate-manifest.py` already covers AUDIT-01.** The claim "no plugin.schema.json validation" must be tested against `scripts/validate-manifest.py` checks 1-6 before asserting REAL. The plan must grep for `plugin.schema.json` vs what the script actually validates (manifest v2 structure, `conflicts_with` vocabulary, path existence, drift). Likely PARTIAL or FALSE.

4. **Parallel Explore agents for verification.** D-09 mandates 3 parallel Haiku agents, 5 claims each. The planner should structure Plan 12.1 actions to spawn these agents and collect structured evidence tables, not run sequential verification in main thread.

5. **FALSE rows still need REQ-ID rows.** REQUIREMENTS.md must receive 15 AUDIT-NN rows regardless of verdict. The planner should not skip FALSE rows in the traceability table.

---

## Metadata

**Analog search scope:** `.planning/`, `scripts/`, `Makefile`, `.github/workflows/`, `scripts/tests/`
**Files scanned:** 12
**Pattern extraction date:** 2026-04-24
