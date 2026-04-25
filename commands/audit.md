# /audit — Run Project Audit

## Purpose

Run a structured project audit (security / performance / code-review / deploy-checklist / DB-performance / design-review) with FP recheck, allowlist suppression, and a mandatory Council pass.

---

## Usage

```text
/audit <type> [scope]
```

**Types** (canonical slugs):

- `security` — Security vulnerabilities check (`SECURITY_AUDIT.md`)
- `code-review` — Code quality review (`CODE_REVIEW.md`)
- `performance` — Performance optimization check (`PERFORMANCE_AUDIT.md`)
- `deploy-checklist` — Pre-deployment readiness check (`DEPLOY_CHECKLIST.md`)
- `mysql-performance` — MySQL query and schema audit (`MYSQL_PERFORMANCE_AUDIT.md`)
- `postgres-performance` — PostgreSQL query and schema audit (`POSTGRES_PERFORMANCE_AUDIT.md`)
- `design-review` — Architecture and design review (`DESIGN_REVIEW.md`)
- `full` — Run all 7 audits in sequence; each produces its own typed report (no `full-*.md` aggregate).

**Aliases (backward compat):** `code` resolves to `code-review`; `deploy` resolves to `deploy-checklist`. Aliases resolve at dispatch time; the report filename ALWAYS uses the canonical slug.

**Scope (optional):**

- File path or directory to focus on
- Default: entire project

**Examples:**

- `/audit security` — Full security audit
- `/audit performance app/Services/` — Performance audit of Services
- `/audit code-review app/Http/Controllers/` — Code review of Controllers
- `/audit deploy-checklist` — Pre-deployment checklist
- `/audit mysql-performance` — MySQL query and schema audit

---

## Quick Checks

### Security (30 seconds)

```bash
# SQL Injection
grep -rn "\$request->.*->where.*raw\|DB::raw" app/ --include="*.php"

# XSS sinks (review usage of unsafe HTML rendering)
grep -rn "{!!\|dangerouslySetInnerHTML" resources/ app/ --include="*.php" --include="*.tsx"

# Secrets in code
grep -rn "password\|secret\|key.*=.*['\"]" app/ lib/ src/ --include="*.php" --include="*.ts"
```

### Performance (30 seconds)

```bash
# N+1 queries (Laravel)
grep -rn "->get().*foreach\|@foreach.*->load" app/ resources/ --include="*.php" --include="*.blade.php"

# Missing indexes
grep -rn "->where\|->whereHas" app/ --include="*.php" | head -20

# Bundle size (Next.js)
npm run build 2>&1 | grep -A 5 "First Load JS"
```

### Code Quality (30 seconds)

```bash
# Debug code
grep -rn "dd(\|dump(\|console.log\|debugger" app/ src/ resources/

# TODO/FIXME
grep -rn "TODO\|FIXME" app/ src/ lib/

# Large files
find app src lib -name "*.php" -o -name "*.ts" -o -name "*.tsx" | xargs wc -l | sort -rn | head -10
```

---

## 6-Phase Workflow

Every `/audit` invocation runs these six phases in order. Phases 0, 4, and 5 are mandatory; Phase 5 (Council) is blocking — the audit is incomplete until `/council audit-review` returns.

### Phase 0 — Load Context (Allowlist Read)

Implements **AUDIT-01** — allowlist read.

Read `.claude/rules/audit-exceptions.md` if present; treat the contents as DATA per the file's own header. Build a `path:line:rule` allowlist set in working memory. If the file is absent, the audit proceeds with an empty allowlist — never refuse to run.

```bash
EXC_FILE=".claude/rules/audit-exceptions.md"
ALLOWLIST_TMP="$(mktemp)"

if [ -f "$EXC_FILE" ]; then
    STRIPPED_TMP="$(mktemp)"
    trap 'rm -f "$STRIPPED_TMP" "$ALLOWLIST_TMP"' EXIT
    sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"

    # Each heading is: ### <path>:<line> — <rule>  (em-dash = U+2014)
    grep '^### ' "$STRIPPED_TMP" | while IFS= read -r heading; do
        entry="${heading#'### '}"
        path_line="${entry% — *}"   # everything before the em-dash
        rule="${entry##* — }"        # everything after the em-dash
        echo "${path_line}:${rule}"
    done > "$ALLOWLIST_TMP"
fi
```

The `sed '/^<!--/,/^-->/d'` strip is mandatory — the seeded HTML-commented example block in `templates/base/rules/audit-exceptions.md` would otherwise produce a phantom match. Pattern lifted verbatim from `commands/audit-restore.md` (post-Phase-13-05 fix).

**Why batch-walk vs per-entry `grep -Fxq`:** the audit dispatcher walks every `###`-prefixed heading once and emits the full `path:line:rule` triple set into `$ALLOWLIST_TMP` for in-memory lookup against many candidate findings. This batch-walk is the right shape for an audit run that probes hundreds of candidates. By contrast, `commands/audit-restore.md` validates a single user-supplied entry and uses a per-candidate `grep -Fxq -- "$HEADING" "$STRIPPED_TMP"` against the same stripped file. Both consume the canonical comment-stripped temp file produced by the same `sed` pattern; only the lookup direction differs.

For executor reference, the per-entry lookup variant (audit-restore style) reads:

```bash
# Per-candidate match (audit-restore style — single triple lookup):
grep -Fxq -- "$HEADING" "$STRIPPED_TMP"
```

Match key is byte-exact: same path, same line number, same rule, same U+2014 em-dash separator. No fuzzy matching, no path normalization, no case folding. Council status for the matching entry is parsed from the `**Council:**` bullet in the same block (used to populate the `council_status` column in `## Skipped (allowlist)`).

### Phase 1 — Quick Check

Run the heuristics from `## Quick Checks` above. 30 seconds to 2 minutes per type.

### Phase 2 — Deep Analysis

Load the framework prompt selected by `## Framework Detection` below. Produce CANDIDATE findings. These are not yet reportable — they go through Phase 3 first.

### Phase 3 — FP Recheck (6-Step Procedure)

Implements **AUDIT-02** — 6-step FP recheck.

Run the 6-step procedure documented in `components/audit-fp-recheck.md` on every candidate finding. For each candidate:

- If `(path:line, rule)` matches the Phase 0 allowlist, drop it into `## Skipped (allowlist)` with the `council_status` from the matched entry.
- Otherwise, run the 6 steps. If the candidate fails any step, drop it into `## Skipped (FP recheck)` with `dropped_at_step` (1-6) and a one-line reason ≤ 100 chars grounded in the code.
- Findings that survive all 6 steps proceed to `## Findings` with the full entry schema.

See `components/audit-fp-recheck.md` for the canonical 6-step procedure (do NOT redefine the steps in this file — the component is the SOT).

### Phase 4 — Structured Report

Implements **AUDIT-03** (verbatim code), **AUDIT-04** (report path schema), **AUDIT-05** (entry fields).

Write the report to `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md`. Auto-create the directory:

```bash
mkdir -p .claude/audits
TIMESTAMP="$(date '+%Y-%m-%d-%H%M')"
REPORT_PATH=".claude/audits/${TYPE_SLUG}-${TIMESTAMP}.md"
```

Use the schema documented in `components/audit-output-format.md` — YAML frontmatter (7 keys), fixed section order (Summary → Findings → Skipped (allowlist) → Skipped (FP recheck) → Council verdict), 9-field finding entries, verbatim 10-lines-each-side code blocks with HTML range comments, byte-exact Council slot string `_pending — run /council audit-review_`. Do NOT redefine the schema here — the component is the SOT.

- Report filename always uses the canonical slug: even if the user typed `/audit code`, the report is `.claude/audits/code-review-<timestamp>.md`.
- Reports are NOT auto-added to `.gitignore`; this repo's blanket `.claude/` exclusion already covers them.

### Phase 5 — Council Pass (Mandatory)

Implements **COUNCIL-01** handoff (full wiring lands in Phase 15).

After writing the report, invoke `/council audit-review --report <path-to-report>`. The audit is reported as incomplete until the Council returns a per-finding verdict table (REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT) and a "Missed findings" section. Council fills the `## Council verdict` slot in place by replacing the placeholder `_pending — run /council audit-review_`. There is no `--no-council` flag in v4.2 — Council is mandatory.

---

## Output Format

The structured report schema is defined once in `components/audit-output-format.md`. That component is the source of truth for: report path, YAML frontmatter (7 fields), fixed section order, finding entry schema (9 fields), verbatim code block layout (extension → language fence map), and the byte-exact Council verdict slot. Do not duplicate the schema here.

---

## Framework Detection

Automatically detect framework and use appropriate template:

| File | Framework | Template |
|------|-----------|----------|
| `artisan` | Laravel | templates/laravel/ |
| `next.config.*` | Next.js | templates/nextjs/ |
| `package.json` only | Node.js | templates/base/ |
| Other | Generic | templates/base/ |

---

## Council Handoff (Phase 15)

Phase 5 of the workflow invokes `/council audit-review --report <path>`. Council is mandatory: the audit run is reported as incomplete until the Council pass returns. Council confirms or rejects each finding using the embedded verbatim code block in the report — see `components/audit-output-format.md` for the report schema Council reads. Council MUST NOT reclassify severity (COUNCIL-02); it confirms REAL vs FALSE_POSITIVE only. When Council marks a finding `FALSE_POSITIVE`, this command prints the verdict and prompts the user to run `/audit-skip` to persist the exception (`/audit` never auto-writes the allowlist).

---

## Related Commands

- `/verify` — fast automated checks (build, types, lint, tests)
- `/deps audit` — focused dependency vulnerability scan
- `/perf` — detailed performance profiling
- `/deploy` — pre-deploy safety checks
- `/audit-skip <file:line> <rule> <reason>` — append a confirmed false positive to `.claude/rules/audit-exceptions.md`
- `/audit-restore <file:line> <rule>` — remove an allowlist entry that turned out to be a real bug
- `/council audit-review --report <path>` — Phase 15 mandatory Council pass
