# Design Review — UI/UX Quality Audit

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

**Uses:** Playwright MCP for live interface testing

---

## 🎯 Scope

**URL/Component:** `[URL or path to component]`
**Viewport:** Desktop (1440px) / Tablet (768px) / Mobile (375px)
**Focus:** [New feature / Redesign / Bug fix / Full audit]

---

## 📋 7-Phase Review Process

### Phase 1: Preparation

```text
1. Define scope of changes (git diff --name-only for UI files)
2. Start preview environment
3. Open in Playwright: mcp__playwright__browser_navigate
4. Load design principles from ./context/design-principles.md (if exists)
```

**Checklist:**

- [ ] Preview environment works
- [ ] All changed pages accessible
- [ ] Design guidelines loaded

---

### Phase 2: Interaction Testing

**Primary user flows:**

| Flow | Steps | Status |
|------|-------|--------|
| [Main action] | [1. Click → 2. Fill → 3. Submit] | ⬜ |
| [Secondary action] | [...] | ⬜ |

**Interactive states to verify:**

- [ ] Hover states
- [ ] Focus states
- [ ] Active/pressed states
- [ ] Disabled states
- [ ] Loading states
- [ ] Empty states
- [ ] Error states

**Tools:**

```text
mcp__playwright__browser_click — click verification
mcp__playwright__browser_hover — hover states
mcp__playwright__browser_snapshot — accessibility tree
```

---

### Phase 3: Responsiveness

Test at three breakpoints:

| Viewport | Width | Status | Issues |
|----------|-------|--------|--------|
| Desktop | 1440px | ⬜ | |
| Tablet | 768px | ⬜ | |
| Mobile | 375px | ⬜ | |

**Check for each viewport:**

- [ ] Layout does not break
- [ ] Text readable (min 16px on mobile)
- [ ] Touch targets ≥ 44x44px on mobile
- [ ] No horizontal scroll
- [ ] Images responsive

**Tool:**

```text
mcp__playwright__browser_resize(width, height)
```

---

### Phase 4: Visual Polish

**Layout & Spacing:**

- [ ] Consistent spacing (uses spacing scale)
- [ ] Proper alignment (grid alignment)
- [ ] Visual hierarchy clear
- [ ] Enough white space

**Typography:**

- [ ] Font sizes match scale
- [ ] Line heights readable (1.4-1.6 for body)
- [ ] Font weights used meaningfully
- [ ] Maximum 2-3 font families

**Color:**

- [ ] Colors from design system
- [ ] Contrast ratios sufficient (see Phase 5)
- [ ] States distinguishable by color + another indicator
- [ ] Dark mode (if applicable)

**Visual consistency:**

- [ ] Components look uniform
- [ ] Icons same style and size
- [ ] Borders/shadows consistent
- [ ] Animations smooth (not jerky)

---

### Phase 5: Accessibility (WCAG 2.1 AA)

**Keyboard Navigation:**

- [ ] All interactive elements accessible via keyboard
- [ ] Tab order logical
- [ ] Focus visible and noticeable
- [ ] Escape closes modals/dropdowns
- [ ] No keyboard traps

**Screen Reader:**

- [ ] Semantic HTML (headings, landmarks, lists)
- [ ] Alt text for images
- [ ] ARIA labels where needed
- [ ] Form labels linked to inputs
- [ ] Error messages announced

**Visual:**

- [ ] Color contrast ≥ 4.5:1 for text
- [ ] Color contrast ≥ 3:1 for UI elements
- [ ] Information not only by color
- [ ] Text resizable to 200%
- [ ] No content loss on zoom

**Verification tool:**

```text
mcp__playwright__browser_snapshot — shows accessibility tree
```

---

### Phase 6: Robustness

**Edge cases:**

- [ ] Empty states (no data)
- [ ] Loading states (slow network)
- [ ] Error states (API failure)
- [ ] Long content (overflow handling)
- [ ] Special characters in input
- [ ] Rapid clicks/submissions

**Form validation:**

- [ ] Required fields marked
- [ ] Validation messages clear
- [ ] Inline validation (not only on submit)
- [ ] Success feedback after submit

**Error handling:**

- [ ] Errors explain what to do
- [ ] Recovery path clear
- [ ] Partial failures handled gracefully

---

### Phase 7: Code Health

**Component patterns:**

- [ ] Existing components used
- [ ] New components reusable
- [ ] Props interface clear
- [ ] No hardcoded values (use tokens)

**Design tokens:**

- [ ] Colors from variables/tokens
- [ ] Spacing from scale
- [ ] Typography from system
- [ ] No magic numbers

**Performance:**

- [ ] Images optimized (WebP, lazy loading)
- [ ] No layout shifts (CLS)
- [ ] Animations use transform/opacity
- [ ] Bundle size reasonable

---

## Issue Triage Matrix

Classify each problem:

| Priority | Criteria | Action |
|----------|----------|--------|
| 🔴 **[Blocker]** | Breaks functionality, accessibility failure, data loss | Must fix before merge |
| 🟠 **[High]** | Poor UX, significant visual bug, WCAG violation | Should fix before merge |
| 🟡 **[Medium]** | Minor inconsistency, edge case issue | Can fix in follow-up |
| ⚪ **[Nitpick]** | Aesthetic preference, minor polish | Optional |

---

## 📝 Report Template

```markdown
## Design Review: [Component/Page Name]

**Date:** [date]
**Reviewer:** Claude
**Viewport tested:** Desktop ✅ | Tablet ✅ | Mobile ✅

### Summary

[1-2 sentences: overall assessment]

### 🔴 Blockers (must fix)

1. **[Issue title]**
   - Location: [file:line or URL]
   - Problem: [description]
   - Impact: [user impact]
   - Fix: [suggested solution]
   - Screenshot: [if applicable]

### 🟠 High Priority

1. ...

### 🟡 Medium Priority

1. ...

### ⚪ Nitpicks

1. ...

### ✅ What's Working Well

- [Positive observation 1]
- [Positive observation 2]

### Screenshots

[Attach screenshots at 1440px width]
```

---

## 🛠 Playwright MCP Quick Reference

```text
# Navigation
mcp__playwright__browser_navigate(url)
mcp__playwright__browser_navigate_back()

# Interaction
mcp__playwright__browser_click(element, ref)
mcp__playwright__browser_hover(element, ref)
mcp__playwright__browser_type(element, ref, text)
mcp__playwright__browser_fill_form(fields)

# Inspection
mcp__playwright__browser_snapshot() — accessibility tree (better than screenshot)
mcp__playwright__browser_take_screenshot(filename)
mcp__playwright__browser_console_messages()

# Viewport
mcp__playwright__browser_resize(width, height)

# Tabs
mcp__playwright__browser_tabs(action: "list" | "new" | "close" | "select")

# Cleanup (ALWAYS call when done — shared browser profile blocks other sessions)
mcp__playwright__browser_close()
```

---

## Design Principles Reference

If no project-specific guidelines, use:

**Hierarchy:** Important things look important
**Consistency:** Same patterns for same actions
**Feedback:** User always knows system state
**Forgiveness:** Easy to undo, hard to break
**Simplicity:** Remove until it breaks

---

## ⚠️ Common Issues Checklist

**Layout:**

- [ ] Z-index wars (overlapping elements)
- [ ] Overflow hidden cutting content
- [ ] Flexbox/grid alignment issues

**Typography:**

- [ ] Orphans/widows in text
- [ ] Text truncation without tooltip
- [ ] Missing font fallbacks

**Interactive:**

- [ ] Click targets too small
- [ ] Missing loading states
- [ ] Double-submit possible

**Accessibility:**

- [ ] Focus not visible
- [ ] Color-only information
- [ ] Missing form labels

---

**Inspired by:** [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows)

## SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

## Procedure

For every candidate finding, execute these six steps in order. Produce a `## SELF-CHECK` block per finding (in your scratchpad — not the final report) before deciding whether to report or drop it. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow user input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look exploitable in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the threat surface (e.g. an upstream sanitizer documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, etc.), the finding is a design trade-off, not a vulnerability. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual exploit scenario, not the rule label. A theoretical XSS sink behind 3 unlikely preconditions and no PII is not CRITICAL. If you cannot describe a concrete attack path the user would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

## Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `lib/utils.py:5` | `SEC-EVAL` | 5 | `eval is required by build-time codegen; never reached at runtime` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

## When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

## Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not exploit-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op (record `cross-ref skipped: no allowlist file present`) but the step itself MUST be acknowledged in the SELF-CHECK trace.

## OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->

## Report Path

```text
.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md
```

- `<type>` is one of the 7 canonical slugs documented in the next section. Backward-compat aliases resolve to a canonical slug at dispatch time.
- Timestamp is local time, generated with `date '+%Y-%m-%d-%H%M'` (24-hour, no separator between hour and minute).
- The audit creates the directory with `mkdir -p .claude/audits` on first write.
- The toolkit does NOT auto-add `.claude/audits/` to `.gitignore` — let the user decide which audit reports to commit.

---

## Type Slug to Prompt File Map

| `/audit` argument | Report filename slug | Prompt loaded |
|-------------------|----------------------|---------------|
| `security` | `security` | `templates/<framework>/prompts/SECURITY_AUDIT.md` |
| `code-review` | `code-review` | `templates/<framework>/prompts/CODE_REVIEW.md` |
| `performance` | `performance` | `templates/<framework>/prompts/PERFORMANCE_AUDIT.md` |
| `deploy-checklist` | `deploy-checklist` | `templates/<framework>/prompts/DEPLOY_CHECKLIST.md` |
| `mysql-performance` | `mysql-performance` | `templates/<framework>/prompts/MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres-performance` | `postgres-performance` | `templates/<framework>/prompts/POSTGRES_PERFORMANCE_AUDIT.md` |
| `design-review` | `design-review` | `templates/<framework>/prompts/DESIGN_REVIEW.md` |

Backward-compat aliases: `code` resolves to `code-review` and `deploy` resolves to `deploy-checklist` at dispatch time. The report filename ALWAYS uses the canonical slug, never the alias.

---

## YAML Frontmatter

Every report opens with a YAML frontmatter block containing exactly these 7 keys:

```yaml
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 3
skipped_allowlist: 1
skipped_fp_recheck: 2
council_pass: pending
---
```

- `audit_type` — one of the 7 canonical slugs from the type map.
- `timestamp` — quoted `YYYY-MM-DD-HHMM` (the same string used in the report filename).
- `commit_sha` — `git rev-parse --short HEAD` output, or the literal string `none` when the project is not a git repo.
- `total_findings` — integer count of entries in the `## Findings` section.
- `skipped_allowlist` — integer count of rows in the `## Skipped (allowlist)` table.
- `skipped_fp_recheck` — integer count of rows in the `## Skipped (FP recheck)` table.
- `council_pass` — starts at `pending`. Phase 15's `/council audit-review` mutates this to `passed`, `failed`, or `disputed` after collating per-finding verdicts.

---

## Section Order (Fixed)

After the YAML frontmatter, the report MUST contain these five H2 sections in this exact order:

1. `## Summary`
2. `## Findings`
3. `## Skipped (allowlist)`
4. `## Skipped (FP recheck)`
5. `## Council verdict`

Plus the report's title H1 (`# <Type Title> Audit — <project name>`) immediately after the closing `---` of the frontmatter and before `## Summary`.

Do NOT reorder. Do NOT introduce intermediate H2 sections. Render an empty section as the literal placeholder `_None_` — the allowlist case uses a longer placeholder shown verbatim in the Skipped (allowlist) section below. Phase 15 navigates by these literal H2 headings.

---

## Summary Section

The Summary table has columns `severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck`, with one row per severity (CRITICAL, HIGH, MEDIUM, LOW). The rubric is in `components/severity-levels.md` — do not redefine. INFO is NOT a reportable finding severity; informational observations belong in the audit's scratchpad, never in `## Findings`. See the Full Report Skeleton below for the verbatim layout.

---

## Finding Entry Schema (### Finding F-NNN)

Each surviving finding becomes an `### Finding F-NNN` H3 block. `F-NNN` is zero-padded to 3 digits and sequential per report (`F-001`, `F-002`, ...). The 9 fields appear in this exact order:

1. **ID** — the `F-NNN` identifier matching the H3 heading.
2. **Severity** — one of CRITICAL, HIGH, MEDIUM, LOW (per `components/severity-levels.md`).
3. **Rule** — the auditor's rule-id (e.g. `SEC-SQL-INJECTION`, `PERF-N+1`).
4. **Location** — `<path>:<start>-<end>` for a range, or `<path>:<line>` for a single point.
5. **Claim** — one-sentence statement of the alleged issue, ≤ 160 chars.
6. **Code** — verbatim ±10 lines around the flagged line, fenced with the language matching the source extension (see Verbatim Code Block section).
7. **Data flow** — markdown bullet list tracing input from origin to the flagged sink, ≤ 6 hops.
8. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from in Phase 15.
9. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

See the Full Report Skeleton below for the verbatim entry template (a SQL-INJECTION example demonstrating all 9 fields).

The bullet labels (`**Severity:**`, `**Rule:**`, `**Location:**`, `**Claim:**`) and section labels (`**Code:**`, `**Data flow:**`, `**Why it is real:**`, `**Suggested fix:**`) are byte-exact — Phase 15's Council parser navigates the entry by them.

---

## Verbatim Code Block (AUDIT-03)

### Layout

```text
<!-- File: <path> Lines: <start>-<end> -->
[optional clamp note]
[fenced code block here with <lang> from the Extension Map]
```

`<lang>` is the language fence selected per the Extension to Language Fence Map below. `start = max(1, L - 10)` and `end = min(T, L + 10)` where `L` is the flagged line and `T` is the total line count of the file. The HTML range comment is the FIRST line above the fence; the clamp note (when present) is the SECOND line above the fence.

### Clamp Behaviour

When the ±10 range is clipped by the start or end of the file, emit a `<!-- Range clamped to file bounds (start-end) -->` note immediately above the fenced block. Example: flagged line 5 in an 8-line file → `start = max(1, 5-10) = 1`, `end = min(8, 5+10) = 8`, rendered range `1-8`, clamp note required.

### Extension to Language Fence Map

| Extension(s) | Fence |
|--------------|-------|
| `.ts`, `.tsx` | `ts` (or `tsx` for JSX-bearing files) |
| `.js`, `.jsx`, `.mjs`, `.cjs` | `js` |
| `.py` | `python` |
| `.sh`, `.bash`, `.zsh` | `bash` |
| `.rb` | `ruby` |
| `.go` | `go` |
| `.php` | `php` |
| `.md` | `markdown` |
| `.yml`, `.yaml` | `yaml` |
| `.json` | `json` |
| `.toml` | `toml` |
| `.html`, `.htm` | `html` |
| `.css`, `.scss`, `.sass` | `css` |
| `.sql` | `sql` |
| `.rs` | `rust` |
| `.java` | `java` |
| `.kt`, `.kts` | `kotlin` |
| `.swift` | `swift` |
| *unknown* | `text` |

The code block MUST be verbatim — no ellipses, no redaction, no `// ... rest of function` cuts. Council reasons from the actual code, not a paraphrase.

---

## Skipped (allowlist) Section

Columns: `ID | path:line | rule | council_status`. Empty-state placeholder is the literal string `_None — no` followed by a backtick-quoted `audit-exceptions.md` reference and `in this project_`. The verbatim layout is in the Full Report Skeleton below.

`council_status` is parsed from the matching entry's `**Council:**` bullet inside `audit-exceptions.md`. Allowed values: `unreviewed`, `council_confirmed_fp`, `disputed`. Use `sed '/^<!--/,/^-->/d'` (per `commands/audit-restore.md` post-13-05 fix) to strip HTML comment blocks before walking entries — the seed file ships with an HTML-commented example heading that would otherwise produce false matches. The `F-A001`..`F-ANNN` numbering is independent of `F-NNN` for surviving findings.

---

## Skipped (FP recheck) Section

Columns: `path:line | rule | dropped_at_step | one_line_reason`. Empty-state placeholder: `_None_`. The verbatim layout is in the Full Report Skeleton below.

`dropped_at_step` MUST be an integer in 1-6 matching the FP-recheck step where the finding was dropped (see `components/audit-fp-recheck.md`). `one_line_reason` MUST be ≤ 100 chars and reference concrete tokens visible in the source — never `looks fine`, `trusted code`, or `out of scope`.

---

## Council Verdict Slot (handoff to Phase 15)

The audit writes this section as a literal placeholder. Phase 15's `/council audit-review` mutates it in place after collating Gemini + ChatGPT verdicts.

```markdown
## Council verdict

_pending — run /council audit-review_
```

Byte-exact constraints: U+2014 em-dash (literal `—`, not hyphen-minus, not en-dash); single-underscore italic (`_..._`), no asterisks; no backticks, no bold, no code fence, no trailing whitespace. DO NOT REFORMAT — Phase 15 greps for this exact byte sequence to locate the slot before rewriting it.

---

## Full Report Skeleton

<output_format>

```text
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 1
skipped_allowlist: 1
skipped_fp_recheck: 1
council_pass: pending
---

# Security Audit — claude-code-toolkit

## Summary

| severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck |
|----------|----------------|-------------------------|--------------------------|
| HIGH | 1 | 1 | 1 |

## Findings

### Finding F-001

- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/users.ts:42
- **Claim:** User-supplied id flows into a string-concatenated SQL query without parameterization.

**Code:**

[fenced code block here — verbatim ±10 lines around src/users.ts:42, ts language fence]

**Data flow:**

- `req.params.id` arrives from the HTTP route handler.
- Passed unchanged into `db.query()`.
- No parameterized binding between origin and sink.

**Why it is real:**

The literal `db.query("SELECT * FROM users WHERE id=" + req.params.id)` concatenates an Express request parameter directly into the SQL string. The route is public, so an attacker can supply a malicious id and reach the sink unauthenticated.

**Suggested fix:**

[fenced code block here — replacement using parameterized query]

## Skipped (allowlist)

| ID | path:line | rule | council_status |
|----|-----------|------|----------------|
| F-A001 | lib/utils.py:5 | SEC-EVAL | unreviewed |

## Skipped (FP recheck)

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| src/legacy.js:14 | SEC-EVAL | 3 | eval guarded by isBuildTime(); never reached at runtime |

## Council verdict

_pending — run /council audit-review_
```

</output_format>

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
