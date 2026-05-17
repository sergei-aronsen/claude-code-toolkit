# Design Review — UI/UX Quality Audit

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

**Uses:** Playwright MCP for live interface testing

---

## Goal

Act as a UI/UX design reviewer for the rendered interface. Identify realistic visual, interaction, responsiveness, and accessibility defects that affect users.

Scope is the live UI surface: layout, typography, spacing, color, contrast, motion, focus behavior, error states, empty states, loading states, viewport behavior, keyboard reachability, and screen-reader semantics.

Do not report software-architecture concerns here. Component reuse, bundle size, lazy-loading strategy, and design-system code organization belong to `CODE_REVIEW.md` or `PERFORMANCE_AUDIT.md`.

Prioritize evidence over finding count. A precise, reproducible finding with a screenshot or accessibility-tree citation is more valuable than several subjective observations. Lower confidence and severity when evidence is incomplete.

---

## Scope

**URL/Component:** `[URL or path to component]`
**Viewports:** Desktop 1440px / Tablet 768px / Mobile 375px
**Focus:** `[New feature / Redesign / Bug fix / Full audit]`

Review only the requested UI surface unless the issue clearly affects a shared pattern visible in that surface.

---

## 6-phase review process

### Phase 1: Preparation

1. Identify UI scope from the request and changed files where available
2. Start or verify the preview environment
3. Open the target URL or component in Playwright MCP
4. Load `./context/design-principles.md` if it exists
5. Consult `.claude/rules/audit-exceptions.md` before reporting findings

Use the Playwright MCP quick reference below for navigation, inspection, screenshots, viewport changes, and cleanup.

### Phase 2: Interaction testing

Exercise the primary user flows end to end. Include expected success paths and at least one realistic failure path for forms or submissions.

Verify interactive states where applicable:

- Hover
- Focus
- Active or pressed
- Disabled
- Loading
- Empty
- Error
- Success or confirmation

For SPA frameworks such as React, Vue, and Svelte, test state transitions, not only initial DOM render. Verify that UI state changes after clicks, form edits, route changes, async loading, validation failures, and recovery actions.

Use accessibility snapshots and screenshots to support findings. Do not report a missing state unless the state is reachable or reasonably required by the visible workflow.

### Phase 3: Responsiveness

Test at minimum:

| Viewport | Width |
|----------|-------|
| Desktop | 1440px |
| Tablet | 768px |
| Mobile | 375px |

Check each viewport for:

- Layout stability with no unintended overlap or clipping
- Readable text, with body text effectively at least 16px on mobile
- Touch targets at least 44x44px where practical
- No unintended horizontal scroll
- Responsive images and media
- Usable navigation and controls without hidden critical actions

### Phase 4: Visual polish

Assess visible quality against the product context and any project design guidance.

Check for:

- Clear visual hierarchy
- Consistent spacing and alignment
- Typography scale, line height, and weight consistency
- Color usage that supports meaning and state
- Components that look like part of the same system
- Icon style and sizing consistency
- Borders, shadows, and elevation used consistently
- Motion that is smooth, purposeful, and not disruptive
- Long content handling without unreadable truncation
- Overflow behavior that does not hide important content

Treat aesthetic preference as LOW severity unless it harms comprehension, trust, conversion, accessibility, or task completion.

### Phase 5: Accessibility

Evaluate WCAG 2.2 AA-relevant behavior from the rendered UI. WCAG 2.2
(ratified October 2023) supersedes WCAG 2.1 AA. Treat 2.1 AA as the
baseline and add the four new 2.2 AA success criteria below.

Check keyboard access:

- All interactive controls are reachable
- Tab order follows the visual and task flow
- Focus is visible and distinguishable
- Escape closes modal or transient UI where expected
- No keyboard traps

Check semantics and announcements:

- Headings, landmarks, lists, buttons, links, and form controls are semantic
- Images have useful alt text or are correctly decorative
- ARIA labels are present where visible text is absent
- Form labels are programmatically connected to inputs
- Validation and error messages are announced or discoverable

Check visual accessibility:

- Text contrast is at least 4.5:1
- UI component contrast is at least 3:1
- Information is not conveyed by color alone
- Content remains usable at 200% zoom where testable

Check **WCAG 2.2 new success criteria** (AA-conformant projects must
add these — 2.1 AA alone is insufficient as of October 2023):

- **2.4.11 Focus Not Obscured (Minimum) — AA.** When a control
  receives keyboard focus, it must not be entirely hidden by
  author-created sticky headers, footers, toasts, or modal scrims.
  Audit: keyboard-tab through the page with a sticky header / footer
  present and verify the focused control is at least partially
  visible. A common regression is focus landing behind a fixed
  cookie-consent banner or chat widget.
- **2.5.7 Dragging Movements — AA.** Any operation that uses a
  dragging movement (drag-and-drop reorder, slider thumb, map pan,
  signature pad) must provide a non-dragging alternative — keyboard
  arrows, up/down buttons, or a numeric input. Audit: identify every
  drag interaction; confirm a click / tap / keyboard alternative
  exists and reaches the same end state.
- **2.5.8 Target Size (Minimum) — AA.** Pointer targets must be at
  least 24×24 CSS pixels OR have ≥ 24px clear spacing around them.
  Exceptions: inline text links, browser-default UA controls,
  targets controlled by the user agent, and "essential" targets
  where 24px would change the meaning. Audit: measure dense control
  clusters (toolbars, icon strips, pagination, table-row actions);
  the most common violation is 16px icon buttons packed shoulder-to-
  shoulder.
- **3.3.8 Accessible Authentication (Minimum) — AA.** Authentication
  flows must not rely on a cognitive function test (memorizing a
  password, solving a puzzle, transcribing a code) as the sole step,
  UNLESS an alternative is offered: passkey / WebAuthn, OAuth
  delegation, password manager autofill (so the field accepts paste
  and is not blocked from autofill), email-magic-link, or a recovery
  code printable in advance. Audit: confirm `autocomplete="current-password"`
  / `autocomplete="one-time-code"` is set on auth fields, paste is
  not blocked, and at least one cognitive-function-free path exists
  to authenticate.

Check **system-preference & locale variants** (orthogonal to WCAG
SCs but required for accessible delivery):

- **`prefers-reduced-motion: reduce`.** Animations longer than 0.5s,
  parallax, auto-scrolling carousels, and decorative motion must
  honor this media query — either disable the animation or reduce
  duration to ≤ 0.5s with no parallax. Audit: enable "Reduce
  Motion" in the OS, reload, confirm motion is dampened.
- **`prefers-color-scheme: dark`.** When the design ships a dark
  mode, audit it as a first-class UI: contrast still ≥ 4.5:1 / 3:1,
  no white logos on light cards (mode-swap miss), no images that
  invert wrong (logos with hardcoded `#000` strokes), focus rings
  still visible against the dark background.
- **`forced-colors: active` (Windows High Contrast Mode).** Borders,
  focus rings, and decorative backgrounds may be stripped to system
  colors. Audit: enable Windows High Contrast, confirm interactive
  controls are still distinguishable (use `forced-color-adjust` with
  `Highlight` / `LinkText` / `ButtonText` system colors, don't rely
  on background-color alone).
- **RTL (right-to-left) locales.** For projects supporting Arabic /
  Hebrew / Persian / Urdu: layout direction (`dir="rtl"`), text
  alignment, icon mirroring (chevrons, back-arrows, progress
  indicators), and bidi text (mixed LTR digits inside RTL text)
  must all flip correctly. Audit: toggle `<html dir="rtl">` and
  confirm no visual regressions; check that ICU-formatted dates
  and numbers respect the locale.
- **Screen-reader announcement gates.** Dynamic content updates
  (toast notifications, validation results, async-loaded sections,
  step-change in a wizard) must reach assistive technology via
  `aria-live` regions, `role="status"` / `role="alert"`, or
  imperative `aria-live` announcements. Audit: trigger each dynamic
  change in VoiceOver / NVDA / TalkBack; confirm an announcement
  fires for each user-visible change. A silent toast = a missed
  user notification for screen-reader users.

Use the accessibility tree as primary evidence for semantic findings.
Measurement-based findings (contrast ratios, target size in px, WCAG
SC numbers) cite the computed value in the finding's `Why it is real`
field — for measurement evidence the schema accepts the computed
number (e.g., `Contrast: 3.8:1 at #6c7280 on #ffffff`) in lieu of
"concrete tokens visible in the Code block".

### Phase 6: Robustness

Probe realistic edge cases that affect user experience:

- Empty data
- Slow loading
- API or submission failure
- Long names, labels, messages, and table content
- Special characters in inputs
- Rapid clicks or repeated submissions
- Narrow viewport plus long content
- Missing optional media or metadata

For forms, verify required-field indication, validation timing, message clarity, double-submit protection, and success feedback.

For errors, verify that the message explains what happened and offers a clear recovery path.

---

## Playwright MCP quick reference

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
mcp__playwright__browser_snapshot()
mcp__playwright__browser_take_screenshot(filename)
mcp__playwright__browser_console_messages()

# Viewport
mcp__playwright__browser_resize(width, height)

# Tabs
mcp__playwright__browser_tabs(action: "list" | "new" | "close" | "select")

# Cleanup
mcp__playwright__browser_close()
```

Always close the shared browser profile when done.

---

## Issue triage matrix

Use these design labels for triage while reviewing. Emit SOT severities in the structured report.

| Design label | Criteria | SOT severity | Action |
|--------------|----------|--------------|--------|
| **[Blocker]** | Blocks task completion, causes data loss, or creates a severe accessibility failure | CRITICAL | Must fix before merge |
| **[High]** | Significant UX failure, major visual regression, or WCAG violation | HIGH | Should fix before merge |
| **[Medium]** | Minor inconsistency, recoverable workflow issue, or edge case defect | MEDIUM | Can fix in follow-up |
| **[Nitpick]** | Cosmetic polish with limited user impact | LOW | Optional |

The standard rubric is in `components/severity-levels.md`; do not redefine it.

---

## Uncertainty discipline

Report only findings grounded in rendered UI evidence, accessibility-tree evidence, or directly inspected source context. If evidence is incomplete, reduce severity and confidence or move the observation to `## Skipped (FP recheck)` with the concrete reason.

Do not present assumptions as facts. Do not use hedged wording to inflate weak findings; either identify the concrete user impact or drop the finding.

---

## CATEGORY ENUM (Audit-Type Override)

The shared finding schema (see `components/audit-output-format.md`) lists a broad `Category` enum spanning all audit types. For DESIGN_REVIEW, restrict `**Category:**` to the ui-design-review-specific values below. Security / performance / code-review categories from the shared enum MUST NOT appear in this audit's findings.

Allowed `Category` values for ui-design-review findings:

- `UX Defect` *(user-visible interaction failure, broken affordance)*
- `Visual Regression` *(unintended visual change vs prior baseline / Figma)*
- `Layout/Responsive` *(reflow, overflow, breakpoint failure)*
- `Accessibility` *(WCAG-graded a11y defect with concrete user impact)*
- `Interaction Contract` *(loading, focus, error, empty state missing or broken)*
- `Content/Copy` *(misleading label, missing microcopy, untranslated string)*
- `Design System` *(token / pattern violation with concrete inconsistency cost)*
- `Cross-Device` *(touch target, hover-only affordance, viewport-specific bug)*
- `Performance-Perceived` *(jank, layout shift, blocking spinner; pair with PERFORMANCE_AUDIT.md if measurable)*

If a candidate finding does not fit any of these categories, it is either out of scope for this audit (route to CODE_REVIEW.md / PERFORMANCE_AUDIT.md / SECURITY_AUDIT.md) or the category needs to be added to this list deliberately — never silently fall back to a code-review category.

---

## FALSE-POSITIVE CONTROL
<!-- v42-splice: fp-control-gates -->

Every candidate finding passes through three gates in this order. A
finding that fails any gate is dropped (record the drop step and reason
in `## Skipped (FP recheck)`); a finding that survives all three is
promoted to `## Findings`.

```text
1. Adversarial self-review  → intent check  (per finding, mandatory for HIGH / CRITICAL)
2. 6-step FP recheck        → procedure check  (per finding, every severity — see SELF-CHECK below)
3. Calibration              → severity + confidence sanity, anti-padding (per report)
```

The order is fixed: adversarial review first (cheap, kills bad
hypotheses), procedure recheck second (expensive, requires reading
±20 lines and tracing data flow), calibration third (applies to the
surviving set as a whole).

### Gate 1 — Adversarial self-review (intent check)

For every HIGH or CRITICAL finding, attempt to disprove it before
reporting. Search explicitly for:

- Upstream sanitization / validation that defangs the input
- Framework guarantees that block the path (escaping, ORM bindings,
  CSRF middleware, transaction isolation)
- Impossible execution paths (dead code, environment-gated branches,
  feature flags off in production, code never imported / called)
- Privilege constraints that prevent the required actor class from
  reaching the sink
- Environmental limitations (the function exists but is never wired
  into a route, command, scheduled job, or webhook)

A finding survives Gate 1 only if the failure mode (security:
exploitability; performance: realistic latency hit; code-review:
reachable regression) remains plausible after adversarial review.
Document in your scratchpad which counter-evidence you considered and
why it failed.

### Gate 2 — 6-step FP recheck (procedure check)

The 6-step procedure is defined in `## SELF-CHECK` of the audit prompt
(propagated from `components/audit-fp-recheck.md`). Each step has a
fail-fast condition; drops are recorded in `## Skipped (FP recheck)`
with the step number and a one-line reason citing concrete tokens from
the source.

### Gate 3 — Calibration (severity + confidence sanity, anti-padding)

After Gates 1 and 2, apply these rules to the surviving set. The
calibration discipline itself is canonicalized in
`components/audit-uncertainty-discipline.md` — apply that SOT in full
here; the rules below are pure cross-references that point its outputs
at the per-audit rubric anchors.

- **Confidence + severity calibration.** Apply UNCERTAINTY DISCIPLINE
  per `components/audit-uncertainty-discipline.md` (lower confidence,
  lower severity, then move to Non-Blocking Observations or drop). Then
  re-rate severity using the Severity Ceiling Table in
  `components/audit-severity-anchor.md` against the realistic
  preconditions. For SECURITY: cross-multiply with
  `## DATA CLASSIFICATION`. For PERFORMANCE: cross-reference
  `## SEVERITY THRESHOLDS`. For CODE_REVIEW: cross-reference
  `## SEVERITY AND CONFIDENCE`.
- **No padding.** Five weak speculative MEDIUMs are worse than one
  verified CRITICAL with a working failure scenario. The weasel-word
  ban (`could potentially`, `might allow`, `in theory`) and the
  hidden-assumptions ban are defined in
  `components/audit-uncertainty-discipline.md` `## Anti-Patterns`. Do
  not restate them inline — apply the SOT.

<!-- v42-splice: rubric-anchors -->

**Audit rubric anchors** (canonical sources of truth — do not redefine inline):

- `components/audit-severity-anchor.md` — CRITICAL / HIGH / MEDIUM / LOW labels + Severity Ceiling Table.
- `components/audit-uncertainty-discipline.md` — UNCERTAINTY DISCIPLINE (lower confidence / severity, anti-padding).
- `components/audit-fp-control-gates.md` — three-gate FALSE-POSITIVE CONTROL wrapper (Adversarial → 6-step recheck → Calibration). Gate 2 procedure is `## SELF-CHECK` below.

## SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

### Procedure

For every candidate finding, execute these six steps in order BEFORE deciding whether to report or drop it. The step-by-step reasoning is an internal trace — perform it mentally per finding and do NOT emit the trace itself into the report. The only artifacts the report contains are: (a) `## Skipped (FP recheck)` rows for drops, with `dropped_at_step` and a one-line reason; and (b) `## Findings` entries for survivors. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look problematic in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script; an `if (!isPaid)` inverted-flag guard inside a unit-test mock).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the failure surface (e.g. an upstream sanitizer or invariant documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform or framework (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, a transactional boundary the ORM enforces, etc.), the finding is a design trade-off, not a defect. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual failure scenario, not the rule label. A theoretical sink behind 3 unlikely preconditions and no realistic blast radius is not CRITICAL. If you cannot describe a concrete failure path that a user or the business would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

### Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `src/orders.ts:88` | `LOG-INVERTED-COND` | 3 | `!isPaid guard runs inside the test-only mock at fixtures/orders.mock.ts:14; production path uses isPaid` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

### When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

### Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not failure-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Emitting the internal recheck trace into the report (a `## SELF-CHECK` block per finding inside `## Findings`, a "step 1: …, step 2: …" walkthrough next to each finding, etc.) — the recheck is internal-only. Report ONLY the outcome: a row in `## Skipped (FP recheck)` if dropped, an entry in `## Findings` if survived.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op internally (a `cross-ref skipped: no allowlist file present` acknowledgement) but the step itself MUST be performed.

## OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->

### Report Path

```text
.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md
```

- `<type>` is one of the 7 canonical slugs documented in the next section. Backward-compat aliases resolve to a canonical slug at dispatch time.
- Timestamp is local time, generated with `date '+%Y-%m-%d-%H%M'` (24-hour, no separator between hour and minute).
- The audit creates the directory with `mkdir -p .claude/audits` on first write.
- The toolkit does NOT auto-add `.claude/audits/` to `.gitignore` — let the user decide which audit reports to commit.

---

### Type Slug to Prompt File Map

| `/audit` argument | Report filename slug | Prompt loaded |
|-------------------|----------------------|---------------|
| `security` | `security` | `templates/<framework>/prompts/SECURITY_AUDIT.md` |
| `code-review` | `code-review` | `templates/<framework>/prompts/CODE_REVIEW.md` |
| `performance` | `performance` | `templates/<framework>/prompts/PERFORMANCE_AUDIT.md` |
| `deploy-checklist` | `deploy-checklist` | `templates/<framework>/prompts/DEPLOY_CHECKLIST.md` |
| `mysql-performance` | `mysql-performance` | `templates/<framework>/prompts/MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres-performance` | `postgres-performance` | `templates/<framework>/prompts/POSTGRES_PERFORMANCE_AUDIT.md` |
| `ui-design-review` | `ui-design-review` | `templates/<framework>/prompts/DESIGN_REVIEW.md` |

Backward-compat aliases: `code` resolves to `code-review`, `deploy` resolves to `deploy-checklist`, and `design-review` resolves to `ui-design-review` at dispatch time (slug renamed in v6.30.0 to clarify the file's UI-only scope — the prompt file keeps its historical name `DESIGN_REVIEW.md` for splice stability). The report filename ALWAYS uses the canonical slug, never the alias.

---

### YAML Frontmatter

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

### Section Order (Fixed)

After the YAML frontmatter, the report MUST contain these five H2 sections in this exact order:

1. `## Summary`
2. `## Findings`
3. `## Skipped (allowlist)`
4. `## Skipped (FP recheck)`
5. `## Council verdict`

Plus the report's title H1 (`# <Type Title> Audit — <project name>`) immediately after the closing `---` of the frontmatter and before `## Summary`.

Do NOT reorder. Do NOT introduce intermediate H2 sections. Render an empty section as the literal placeholder `_None_` — the allowlist case uses a longer placeholder shown verbatim in the Skipped (allowlist) section below. Phase 15 navigates by these literal H2 headings.

---

### Summary Section

The Summary table has columns `severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck` and MUST contain exactly four rows in this order: CRITICAL, HIGH, MEDIUM, LOW. Render zeros (`0`) in any cell whose count is zero — do NOT omit rows for severities with no findings, and do NOT collapse `0`s to blank cells. The rubric is in `components/severity-levels.md` — do not redefine. INFO is NOT a reportable finding severity; informational observations are NEVER emitted (neither in `## Findings` nor in `## Summary` nor anywhere else in the report). See the Full Report Skeleton below for the verbatim layout.

---

### Finding Entry Schema (### Finding F-NNN)

Each surviving finding becomes an `### Finding F-NNN` H3 block. `F-NNN` is zero-padded to 3 digits and sequential per report (`F-001`, `F-002`, ...).

The entry has 11 fields rendered in two presentation styles:

- **Bullet-label fields (1–7):** rendered as `**<Label>:**` bullets immediately under the H3, in the order shown below.
- **Section-block fields (8–11):** rendered as `**<Label>:**` paragraph headings, each followed by its block (code fence, list, prose, or diff).

The fields appear in this exact order:

1. **ID** — the `F-NNN` identifier matching the H3 heading.
2. **Severity** — one of CRITICAL, HIGH, MEDIUM, LOW (per `components/severity-levels.md`).
3. **Confidence** — one of HIGH, MEDIUM, LOW. HIGH = directly observable in code with a clear execution path; MEDIUM = strong evidence with some inferred assumptions; LOW = weak signal or incomplete evidence. LOW-confidence findings MUST explicitly state the uncertainty in `Why it is real`. (Note: Confidence and Severity share the tokens HIGH/MEDIUM/LOW; the bullet label disambiguates — never write a bare `HIGH` without its `**Severity:**` or `**Confidence:**` label.)
4. **Category** — one of: Correctness, Business Logic, Reliability, Concurrency, Performance, Operational Reliability, Operational Maintainability Risk, API Contract, Data Integrity, Security, Data Exposure. (Audit-type prompts MAY restrict this enum further — see the prompt's own `## Category` constraint, if any.)
5. **Rule** — the auditor's rule-id (e.g. `SEC-SQL-INJECTION`, `PERF-N+1`, `LOG-INVERTED-COND`, `DATA-PARTIAL-UPDATE`).
6. **Location** — `<path>:<start>-<end>` for a range, or `<path>:<line>` for a single point.
7. **Claim** — one-sentence statement of the alleged issue, ≤ 160 chars.
8. **Code** — verbatim ±10 lines around the flagged line, fenced with the language matching the source extension (see Verbatim Code Block section).
9. **Data flow** — markdown bullet list tracing input from origin to the flagged sink, ≤ 6 hops.
10. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from in Phase 15.
11. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

Field omission rules (the omission key is **Severity**, never Confidence):

- **Severity = CRITICAL / HIGH** — all 11 fields required.
- **Severity = MEDIUM** — MAY omit Data flow and Suggested fix when they add no value. Confidence remains required (default `Confidence: MEDIUM` if not stated).
- **Severity = LOW** — MAY collapse to ID + Severity + Confidence + Location + Claim + one-line evidence (the Code / Data flow / Why it is real / Suggested fix sections may be merged into the Claim).

Note: omission rules apply per **Severity**. A LOW-severity finding with HIGH confidence may collapse; a HIGH-severity finding with LOW confidence MUST keep all 11 fields (LOW confidence requires the uncertainty be explicit, which lives in `Why it is real`).

See the Full Report Skeleton below for the verbatim entry template (a SQL-INJECTION example demonstrating all required fields).

The bullet labels (`**Severity:**`, `**Confidence:**`, `**Category:**`, `**Rule:**`, `**Location:**`, `**Claim:**`) and section labels (`**Code:**`, `**Data flow:**`, `**Why it is real:**`, `**Suggested fix:**`) are byte-exact — Phase 15's Council parser navigates the entry by them.

---

### Verbatim Code Block (AUDIT-03)

#### Layout

```text
<!-- File: <path> Lines: <start>-<end> -->
[optional clamp note]
[fenced code block here with <lang> from the Extension Map]
```

`<lang>` is the language fence selected per the Extension to Language Fence Map below. `start = max(1, L - 10)` and `end = min(T, L + 10)` where `L` is the flagged line and `T` is the total line count of the file. The HTML range comment is the FIRST line above the fence; the clamp note (when present) is the SECOND line above the fence.

#### Clamp Behaviour

When the ±10 range is clipped by the start or end of the file, emit a `<!-- Range clamped to file bounds (start-end) -->` note immediately above the fenced block. Example: flagged line 5 in an 8-line file → `start = max(1, 5-10) = 1`, `end = min(8, 5+10) = 8`, rendered range `1-8`, clamp note required.

#### Extension to Language Fence Map

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

#### No Literal Placeholders

The skeleton uses square-bracketed placeholders such as `[fenced code block here — verbatim ±10 lines around src/users.ts:42, ts language fence]` and `[optional clamp note]` to DESCRIBE what to inject. These descriptions MUST NOT appear in the final report. When emitting an actual finding:

- Replace `[fenced code block here — verbatim ±10 lines around <path>:<line>, <lang> language fence]` with the real fenced code block at the resolved path, line range, and language fence.
- Replace `[fenced code block here — replacement using parameterized query]` (and similar `Suggested fix` placeholders) with the actual fenced replacement snippet.
- Omit `[optional clamp note]` entirely when the ±10 window does not hit file bounds; emit the `<!-- Range clamped to file bounds (start-end) -->` line verbatim when it does.

A report that ships literal `[fenced code block here ...]` text is malformed; Phase 15 will treat it as a broken finding.

---

### Skipped (allowlist) Section

Columns: `ID | path:line | rule | council_status`. Empty-state placeholder is the literal string `_None — no` followed by a backtick-quoted `audit-exceptions.md` reference and `in this project_`. The verbatim layout is in the Full Report Skeleton below.

`council_status` is parsed from the matching entry's `**Council:**` bullet inside `audit-exceptions.md`. Allowed values: `unreviewed`, `council_confirmed_fp`, `disputed`. Use `sed '/^<!--/,/^-->/d'` (per `commands/audit-restore.md` post-13-05 fix) to strip HTML comment blocks before walking entries — the seed file ships with an HTML-commented example heading that would otherwise produce false matches. The `F-A001`..`F-ANNN` numbering is independent of `F-NNN` for surviving findings.

---

### Skipped (FP recheck) Section

Columns: `path:line | rule | dropped_at_step | one_line_reason`. Empty-state placeholder: `_None_`. The verbatim layout is in the Full Report Skeleton below.

`dropped_at_step` MUST be an integer in 1-6 matching the FP-recheck step where the finding was dropped (see `components/audit-fp-recheck.md`). `one_line_reason` MUST be ≤ 100 chars and reference concrete tokens visible in the source — never `looks fine`, `trusted code`, or `out of scope`.

---

### Council Verdict Slot (handoff to Phase 15)

The audit writes this section as a literal placeholder. Phase 15's `/council audit-review` mutates it in place after collating Gemini + ChatGPT verdicts.

```markdown
## Council verdict

_pending — run /council audit-review_
```

Byte-exact constraints: U+2014 em-dash (literal `—`, not hyphen-minus, not en-dash); single-underscore italic (`_..._`), no asterisks; no backticks, no bold, no code fence, no trailing whitespace. DO NOT REFORMAT — Phase 15 greps for this exact byte sequence to locate the slot before rewriting it.

---

### Full Report Skeleton

The skeleton below uses a SECURITY finding (SQL injection) as the
illustrative example. For other audit types substitute the appropriate
`audit_type`, H1 title, finding `Category` (e.g. Correctness for
code-review, Performance for performance, UX Defect for ui-design-review),
and `Rule` namespace. The schema (field order, byte-exact bullet labels,
section order, Council slot string) is identical across all 7 audit
types. Each prompt MAY restrict `Category` to its own enum — when in
doubt, defer to the per-prompt enum, not this generic example.

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
| CRITICAL | 0 | 0 | 0 |
| HIGH | 1 | 1 | 1 |
| MEDIUM | 0 | 0 | 0 |
| LOW | 0 | 0 | 0 |

## Findings

### Finding F-001

- **Severity:** HIGH
- **Confidence:** HIGH
- **Category:** Security
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
