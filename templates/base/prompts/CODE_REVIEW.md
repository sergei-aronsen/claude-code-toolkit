# Code Review — Base Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## GOAL

Act as a regression-focused production reviewer. Identify realistic
correctness, reliability, and business-logic defects introduced or exposed
by the diff.

The objective is NOT to maximize the number of findings. The objective is to
identify the highest-impact real issues with the lowest possible
false-positive rate. A single precise, high-confidence finding is more
valuable than 20 speculative comments.

Avoid academic or purely stylistic feedback. Security auditing is handled by
`SECURITY_AUDIT.md`; do not perform speculative security analysis here
unless the diff directly introduces correctness-breaking authorization,
unsafe state transitions, or destructive data exposure within the modified
execution flow.

### Read the change's intent before reviewing

A review without intent is a checklist exercise. Before flagging anything,
read every signal of WHY the change is being made:

- **PR title and body** — the author's framing of the problem, the chosen
  approach, and explicit non-goals.
- **Latest commit messages on the branch** — `git log --oneline
  origin/main..HEAD` shows the granularity of intent. Squash-merged
  branches lose this — fall back to the PR body.
- **Linked issue / ticket** — bug reports name the failure mode, feature
  requests name the constraint. The body of a referenced GitHub issue,
  Jira ticket, or Linear story is often more authoritative than the PR
  body for "why now".
- **Earlier review comments** (when re-reviewing a stacked or revised PR) —
  decisions already discussed are out of scope for re-litigation.
- **Existing `.claude/rules/audit-exceptions.md`** entries on the same
  files (`## SELF-CHECK` step 4 below). A finding the team explicitly
  decided to allow is not a regression.

A finding that ignores the stated intent — "this should be an event
instead of a synchronous call" when the PR body explicitly says "we
need synchronous semantics for this checkout step" — fails Gate 1
(adversarial self-review). Capture intent BEFORE running the rest of
the audit; do not retrofit it after the fact.

When the intent is genuinely unclear (e.g., a refactor PR with no body
and three unrelated changes), state the ambiguity in
`## Non-Blocking Observations` and lower confidence on every finding
that hinges on the unclear intent.

---

## PROJECT SPECIFICS — [Project Name]

Optional project-specific guidance. If this section is not filled in, ignore
it. Do not mention placeholder content in the final report. The bullets
below use HTML-comment placeholders (`<!-- fill in -->`) so the parser does
not confuse unfilled stub text for actual guidance — an empty bullet stays
empty in rendered markdown.

**Accepted decisions (no need to fix):**

- <!-- fill in: intentional architectural decisions, e.g. "service layer
  deliberately calls model::create instead of ORM ::save for batch path" -->

**Key files for review:**

- <!-- fill in: where business logic lives, e.g. `app/Services/**`,
  `src/domain/**`, `internal/<bounded-context>/**` -->
- <!-- fill in: where controllers/routes live, e.g. `app/Http/Controllers`,
  `src/app/**/route.ts`, `cmd/api/handlers/**` -->
- <!-- fill in: where UI components live, e.g. `src/components/**`,
  `resources/views/**` -->

**Project patterns:**

- <!-- fill in: established patterns, e.g. "Result<T,E> over thrown
  exceptions in service layer", "Eloquent observers for audit log",
  "tRPC procedures for client/server bridge" -->

---

## QUICK CHECK (5 minutes)

Report only checks that were actually performed. Do not infer
test/build/lint status from code inspection alone. The `Command` column
names the concrete invocation expected for that row; record the actual
command run in the report so a reader can reproduce the result.

| Check | Command (example) | Status |
| ----- | ----------------- | ------ |
| Syntax errors | `<lang-parser> <changed-files>` (e.g. `node --check`, `python -m py_compile`, `go vet ./...`, `php -l`) | Verified / Failed / Not verified / Not applicable |
| Linter | `<project lint task>` (e.g. `npm run lint`, `make lint`, `ruff check .`, `golangci-lint run`, `phpstan analyse`) | Verified / Failed / Not verified / Not applicable |
| Build | `<project build task>` (e.g. `npm run build`, `tsc --noEmit`, `go build ./...`, `cargo build`, `mvn -B compile`) | Verified / Failed / Not verified / Not applicable |
| Tests | `<project test task>` (e.g. `npm test`, `pytest -q`, `go test ./...`, `php artisan test`, `cargo test`) | Verified / Failed / Not verified / Not applicable |
| Debug code present | `git diff --diff-filter=A` plus `grep -nE 'console\\.log\|dd\\(\|var_dump\|pp\\(\|fmt\\.Println\|dbg!\\(\|debugger;'` over the diff | Verified / Failed / Not verified / Not applicable |

Status labels:

- **Verified** — command was actually executed and passed.
- **Failed** — command was executed and failed.
- **Not verified** — command was not run.
- **Not applicable** — check does not apply to this diff.

Never claim verification of build, tests, linting, type checking,
migrations, or runtime behavior unless the relevant command was actually
executed in the session.

### Where Quick Check Appears in the Report

Render the Quick Check table as the FIRST sub-block inside `## Summary`,
above the severity table. Use an H3 (`### Quick Check`) to introduce it
so the severity table immediately below remains the dominant Summary
artifact. Omit the Quick Check sub-block entirely only when every row
would be `Not applicable` (the diff is documentation-only or otherwise
not runnable). The Council parser anchors on `## Summary` and the
severity-table column header, so the Quick Check H3 above the table does
not affect parsing.

---

## SEVERITY AND CONFIDENCE

Severity and confidence are orthogonal axes. Both are required on every
HIGH or CRITICAL finding.

**Severity** — use the canonical labels and Severity Ceiling Table in
`components/audit-severity-anchor.md` (CRITICAL / HIGH / MEDIUM / LOW;
`components/severity-levels.md` is the short reference card cited by
the spliced output-format Summary table, not a second labels source).
INFO is NOT a reportable finding severity; informational observations
belong in the auditor's scratchpad, never in `## Findings`. Do NOT
redefine severity in the report. Re-rate using the actual failure
scenario, not the rule label. Do not inflate.

**Confidence** — auditor-judged certainty in the finding's reachability:

| Level | Description |
| ------- | ---------- |
| HIGH | Directly observable in code with a clear execution path. |
| MEDIUM | Strong evidence exists, some assumptions are inferred. |
| LOW | Weak signal or incomplete evidence. |

Avoid reporting LOW-confidence findings unless impact could be severe AND
the uncertainty is explicitly stated.

---

## DIFF AWARENESS

Assume unchanged code is stable unless the diff introduces or exposes a
failure path. Review depth decreases rapidly outside the changed execution
paths. Do not perform broad repository audits unrelated to the diff.

Treat newly introduced issues as higher priority than pre-existing code
quality problems. Do not aggressively report legacy issues unless:

- the current change worsens them
- the change directly touches the affected area
- the issue creates immediate risk

---

## SCOPE, PRIORITIES, AND APPROACH

Identify the actual execution paths affected by the diff. Focus depth on:

- modified logic
- affected call chains
- changed state transitions and async flows
- changed persistence or API boundaries

Prioritize findings in this order:

1. Correctness bugs
2. Invalid state transitions or data consistency risks
3. Concurrency / async issues
4. Architecture-related correctness or reliability risks
5. Operational maintainability risks with measurable support or reliability cost

Performance issues belong to `PERFORMANCE_AUDIT.md` (cache,
queries, payload size, p95 latency budgets) and the per-stack DB-perf
prompts (`MYSQL_PERFORMANCE_AUDIT.md`, `POSTGRES_PERFORMANCE_AUDIT.md`).
A correctness bug that **happens to** manifest as slowness (e.g., a
loop that re-enters on every request, an off-by-one that triggers a
table-scan) belongs here; a tuning regression that is otherwise
correct belongs in the perf audit.

Before reporting any finding: understand the intent of the change, trace
affected execution paths, validate assumptions against actual code, and
estimate realistic production impact.

---

## EVIDENCE RULES

Do not assume hidden consumers, undocumented integrations, future scaling
requirements, external dependencies, or implicit contracts unless directly
evidenced in the reviewed code or diff.

Only report an issue if:

- the execution path is observable in code
- the execution flow is concrete
- the claim references actual tokens from source
- the issue is realistically reachable

Never speculate about missing code, assumed runtime behavior, hypothetical
future usage, or external integrations not present in the diff.

---

## BUSINESS LOGIC VALIDATION

Check the directly affected execution flow for:

- **Inverted conditions** — e.g. `if (!isPaid) { grantAccess(); }` where
  the boolean was negated in the diff and the surrounding code still
  reads the un-negated form.
- **Missing edge cases** — e.g. paginator handles `page=1..N` but not
  `page=0`, `page=-1`, `page=NaN`, or an empty result set.
- **Invalid state transitions** — e.g. an order can move from `paid` to
  `pending` because the new handler does not validate the source state
  against the allowed-transitions table.
- **Race conditions** — e.g. read-modify-write on a counter without a
  row lock or atomic increment; two requests both see `count=4`, both
  write `count=5`.
- **Partial updates** — e.g. a service writes to two tables without a
  transaction; if the second write fails, the first is left committed
  and the entity is inconsistent.
- **Transactional inconsistencies** — e.g. an event is published to a
  message bus before the DB transaction commits; the consumer reads a
  row that does not yet exist (or never will, if the txn rolls back).
- **Stale cache flows** — e.g. a write path updates the DB but the
  cache invalidation step is conditional on a flag that is `false` in
  production; readers see the old value indefinitely.
- **Async ordering issues** — e.g. two `await`s assume FIFO completion
  but the underlying queue is unordered, or a `Promise.all` is treated
  as ordered when the consumer indexes by position.

Prioritize logic correctness over style.

---

## ARCHITECTURE AND CONSISTENCY

Reuse, design tokens, and named constants are correctness concerns when
the project already has the conventions established. Flag findings only
when concrete duplication or maintenance cost is evident in the diff —
not on speculation.

Check:

- **Component reuse.** A new component in the diff that re-implements a
  capability already covered by an existing component (visible via grep
  for the same primitive — button, modal, table row, form field). Treat
  as a finding only when the duplication is non-trivial (>30 LOC of
  parallel logic) and the existing component is reachable from the new
  call site without invasive refactor.
- **Design tokens.** Hardcoded color literals, pixel spacing, or font
  declarations when the project ships a token system (CSS variables,
  Tailwind theme, design-tokens package). Flag when the diff bypasses
  the system in a place where token usage is the established pattern.
- **Magic numbers.** Numeric literals in business logic, layout sizing,
  timeout values, retry counts, or threshold checks without a named
  constant. Flag when the value carries semantic meaning the reader
  must reverse-engineer from context.

Findings here must pass the LOW-VALUE REVIEW FILTER below: skip purely
stylistic preferences, premature abstractions, and refactors without
measurable maintenance benefit.

---

## MODERN-STACK CATEGORIES

The 2024-2026 mainstream stack adds failure modes the original
`BUSINESS LOGIC VALIDATION` list does not name. Audit each of the
following when the diff touches the corresponding surface. These are
**correctness** categories, not style; flag only when a real execution
path reaches the failure mode.

### Async / await pitfalls (every async-capable language)

- **Unawaited promise.** A diff calls an `async` function and discards
  the returned promise (`asyncFn()` instead of `await asyncFn()`). The
  caller proceeds, the inner work runs detached, and exceptions become
  unhandled rejections. Visible in TS/JS, Python (`asyncio.create_task`
  without `await`), .NET (`Task` discarded), Swift (`Task { }` without
  `await Task.value`).
- **Fire-and-forget that hits user data.** Fire-and-forget is fine for
  best-effort telemetry; it is **not** fine when the side effect is
  user-visible (database write, audit log, email). Audit every
  unawaited async call site against this rule.
- **Sequential `await` chain instead of `Promise.all` / `gather`.**
  Two independent awaits in sequence (`const a = await fetchA(); const
  b = await fetchB();`) double latency unnecessarily. Flag only when
  the two values do not depend on each other.
- **`await` inside a `forEach`.** JavaScript / TS only: `arr.forEach(async x => await op(x))` does not wait — the loop returns before `op` finishes. Use `for...of` or `Promise.all(arr.map(...))`.
- **Cancellation propagation.** Python `asyncio` and Go `context` both
  propagate cancellation through the call chain; a function that
  swallows `CancelledError` / ignores `ctx.Done()` becomes uncancellable
  and leaks goroutines / tasks. See dedicated subsections below.

### React Server Components & client boundary (App Router / Remix v2+)

For projects on Next.js App Router (`app/` directory) or RSC-aware
frameworks:

- **`'use client'` at a high-level layout** pulls every nested
  component into the client bundle. Audit the highest `'use client'`
  file in any tree the diff touches.
- **Server-only data in a Client Component.** Passing a server-only
  object (DB row, file handle, env var) through a Client Component
  prop serializes it via React's flight wire — secrets leak to the
  client. Audit prop types crossing the boundary.
- **`async` Client Component.** Client Components cannot be async in
  React 19+ stable; a diff that introduces `'use client'` on an
  `async` function is a hard error at runtime.
- **Server-action input validation.** A `'use server'` function
  receives data from the **client**. Validate every input (type, size,
  shape, authorization) — server actions are not magic-trusted.
  Treat them like POST endpoints.
- **`<Suspense>` boundary placement.** A single top-level `<Suspense>`
  around the whole route defeats streaming. Each independent data
  dependency wants its own boundary.

### TypeScript strict regressions

- **`any` introduced where the surrounding code was typed.** A `: any`
  parameter, an `as any` cast, an explicit `// @ts-ignore` /
  `// @ts-expect-error` — flag when the surrounding module is otherwise
  strict-typed. `any` is a regression-spreading agent: every callsite
  loses inference downstream.
- **`as unknown as X` double-cast.** Almost always hides a real type
  error. Audit the underlying mismatch; the double-cast is a
  diagnostic, not a fix.
- **`strict: false` toggled or strictness lowered in `tsconfig.json`.**
  Including `strictNullChecks: false`, `noImplicitAny: false`,
  `exactOptionalPropertyTypes: false`. Lowering strictness in
  `tsconfig.json` is a project-wide regression — flag CRITICAL.
- **Non-null assertion in business logic.** `value!.field` in a
  user-data path silently turns "undefined" into a runtime crash.
  Acceptable in test fixtures; not in production code paths.

### Go context propagation

- **`context.Background()` instead of caller's ctx.** Spawning a
  goroutine with `context.Background()` cuts the cancellation chain.
  The caller's request can complete (or be cancelled) but the
  background work runs on. Pass the caller's `ctx` unless the work
  must outlive the request.
- **Missing `ctx.Err()` check in long-running loops.** A `for`/`select`
  that does not check `ctx.Done()` cannot be cancelled.
- **Timeout without `defer cancel()`.** `ctx, cancel := context.WithTimeout(...)` without a `defer cancel()` leaks the timer until the
  parent ctx fires.

### Python async cancellation

- **Bare `except Exception` swallows `asyncio.CancelledError`** in
  Python ≤ 3.7; from 3.8+ `CancelledError` derives from
  `BaseException`, but legacy code that explicitly catches `Exception`
  still risks swallowing cancellation in old projects. Audit every
  `except Exception` inside a coroutine — re-raise `CancelledError`.
- **`asyncio.create_task` without keeping a reference.** The task is
  garbage-collected mid-execution. Always assign the return value to
  a name or a collection.
- **Blocking IO in an async function.** `requests.get`, `time.sleep`,
  synchronous DB drivers — block the event loop for every concurrent
  request. Switch to `httpx` / `asyncio.sleep` / async drivers.

### LLM-in-app safety (when the app itself calls an LLM)

- **Prompt assembled by string concatenation of user data.** Use a
  template with explicit placeholders and validation; never
  `f"You are a helpful assistant. The user said: {user_input}"`
  without sandwiching (system instructions before AND after the
  user-data block).
- **Tool authorization missing.** An LLM function-call/tool-use loop
  that lets the model invoke `delete_user(id)` with the model's chosen
  `id` is account-takeover-by-LLM. Every tool call goes through the
  same authorization layer as a direct user request.
- **No output validation.** The model can emit any string; if the app
  parses that string as JSON / SQL / shell, validate the parse.
  Hallucinated JSON keys are a real prod failure mode, not a
  hypothetical.
- **Cost / token budget.** A new LLM call in a request path without a
  hard token cap is a denial-of-wallet vector — one prompt-injection
  loop can spend a month's budget in an hour. Flag missing
  `max_tokens` and missing per-request cost ceiling.

### Supply-chain dependency checks

- **New dependency in the diff.** Verify by exact byte match against
  the canonical registry (`npm`, `PyPI`, `crates.io`, `RubyGems`,
  `Packagist`, `pkg.go.dev`). Run `npm view <pkg> time`,
  `pip index versions <pkg>` to confirm age > 30 days, maintainer is
  not a one-package account, and the package is not slopsquatted
  (an LLM-hallucinated name shaped `<canonical>-{helper,utils,wrapper}`).
  See `SECURITY_AUDIT.md` `### Dependency Risk` for the full
  slopsquatting checklist.
- **Lockfile churn.** `package-lock.json` / `pnpm-lock.yaml` /
  `Cargo.lock` / `go.sum` / `poetry.lock` changes the diff did not
  request — flag for review (transitive escalation, dependency
  confusion, or an unrelated drift commit hiding in the PR).
- **`postinstall` / `preinstall` script.** Any new dependency that
  runs code at install time is a supply-chain risk surface.

### Retry / timeout / circuit-breaker

- **Outbound HTTP call without an explicit timeout.** Library
  defaults are usually `None` (block forever); a stuck dependency
  takes the whole worker. Flag every `fetch` / `requests.get` /
  `httpx.get` / `axios.get` / `http.Client{}` without a timeout in a
  request-handling path.
- **Retry without backoff.** A retry loop with no exponential
  backoff and no jitter amplifies any downstream incident into a
  thundering herd.
- **Retry on non-idempotent verb.** Auto-retry of a POST without an
  idempotency key results in duplicate writes. Audit retry policies
  per-verb.
- **No circuit-breaker on a hot dependency.** When a downstream
  saturates, retries make it worse. Flag a hot dependency in the diff
  with no breaker (e.g., `opossum`, Hystrix, gobreaker, `tenacity`
  `retry_if_*` predicate).

### i18n string extraction

When the project ships a translation system (next-intl, react-intl,
i18next, gettext, Phrase, Lokalise):

- **Hardcoded user-visible string in the diff.** A raw `"Save"` /
  `"Welcome back"` / `"Error: something went wrong"` in JSX / template
  / Python view, when the surrounding code uses `t("save")`.
- **String concatenation across translatable units.** Expressions
  shaped like `"You have " <plus> count <plus> " messages"` break
  pluralization and word-order in RTL / agglutinative languages. Use
  `t("messages.count", { count })` with the system's plural / ordinal
  rules.
- **Locale-unaware date / number formatting.** `new Date().toString()`
  / Python `str(d)` produces English-locale output regardless of the
  user's locale. Use `Intl.DateTimeFormat` / `babel.dates` / framework
  i18n date helper.
- **RTL-broken layout assumption.** `paddingLeft`, `marginLeft`,
  fixed-direction icons in a project that supports Arabic / Hebrew /
  Persian. Use logical properties (`paddingInlineStart`,
  `marginInlineStart`) and bidi-aware icons.

A finding under any of these is real only when the failure mode is
observable on a reachable code path in the diff. "This async function
exists" is not a finding; "this async function is awaited in one
caller and discarded in another, the discarded caller is the
checkout-confirmation handler" is.

---

## LOW-VALUE REVIEW FILTER

Do not generate findings merely because a review category exists. Every
finding must justify realistic impact AND why resolving the issue is worth
the cost.

Do not request:

- additional tests without identifying a concrete uncovered risk
- documentation updates without missing operationally important behavior
- stronger typing unless type weakness creates realistic defects
- abstractions unless duplication or coupling creates measurable maintenance cost

Do not report:

- purely stylistic preferences
- naming alternatives without semantic benefit
- framework preference debates
- speculative micro-optimizations
- comments without measurable impact
- premature abstractions
- unnecessary architectural generalization
- refactors without measurable benefit

**Concrete examples — DROP vs KEEP:**

| Finding | Verdict | Why |
| ------- | ------- | --- |
| "Rename `usr` → `user` for clarity" | DROP | Stylistic; no semantic benefit |
| "Extract this 12-line block into a helper" | DROP | Premature abstraction; no duplication |
| "Add JSDoc to this private function" | DROP | No operationally important behavior missing |
| "Use `Array.from` instead of spread" | DROP | Framework preference; no measurable impact |
| "Could use `Map` for slightly faster lookup" | DROP | Speculative micro-optimization on a non-hot path |
| "Missing test for the null-input branch" | KEEP | Concrete uncovered risk (null deref in prod) |
| "This regex backtracks O(2^n) on `aaaa…aX`" | KEEP | ReDoS — measurable defect, exploitable |
| "Auth check missing on `/admin/delete-user`" | KEEP | Concrete authorization gap; reachable |
| "Type `any` here hides a real union" | KEEP | Type weakness produces realistic defect at call site |
| "Three near-identical 40-line blocks above" | KEEP | Duplication has measurable maintenance cost |

The pattern: a finding **KEEPS** when it names (a) a concrete defect or
risk, (b) a reachable code path, AND (c) a cost that beats the cost of
fixing it. A finding **DROPS** when any of the three is missing.

---

## UNCERTAINTY DISCIPLINE

If evidence is incomplete: lower confidence, reduce severity, move the
observation into Non-Blocking Observations, and explicitly state the
uncertainty. Do not present assumptions as facts. Do not use weasel
words ("could potentially", "might allow", "in theory") to inflate
report length — either the finding is grounded or it isn't.

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

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from during `/council audit-review`.

---

### Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not failure-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Emitting the internal recheck trace into the report (a `## SELF-CHECK` block per finding inside `## Findings`, a "step 1: …, step 2: …" walkthrough next to each finding, etc.) — the recheck is internal-only. Report ONLY the outcome: a row in `## Skipped (FP recheck)` if dropped, an entry in `## Findings` if survived.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op internally (a `cross-ref skipped: no allowlist file present` acknowledgement) but the step itself MUST be performed.

## OUTPUT FORMAT (Structured Report Schema)
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
- `council_pass` — starts at `pending`. The `/council audit-review` pass mutates this to `passed`, `failed`, or `disputed` after collating per-finding verdicts.

---

### Section Order (Fixed)

After the YAML frontmatter, the report MUST contain these five H2 sections in this exact order:

1. `## Summary`
2. `## Findings`
3. `## Skipped (allowlist)`
4. `## Skipped (FP recheck)`
5. `## Council verdict`

Plus the report's title H1 (`# <Type Title> Audit — <project name>`) immediately after the closing `---` of the frontmatter and before `## Summary`.

Do NOT reorder. Do NOT introduce intermediate H2 sections. Render an empty section as the literal placeholder `_None_` — the allowlist case uses a longer placeholder shown verbatim in the Skipped (allowlist) section below. The Council pass navigates by these literal H2 headings.

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
10. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from during `/council audit-review`.
11. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

Field omission rules (the omission key is **Severity**, never Confidence):

- **Severity = CRITICAL / HIGH** — all 11 fields required.
- **Severity = MEDIUM** — MAY omit Data flow and Suggested fix when they add no value. Confidence remains required (default `Confidence: MEDIUM` if not stated).
- **Severity = LOW** — MAY collapse to ID + Severity + Confidence + Location + Claim + one-line evidence (the Code / Data flow / Why it is real / Suggested fix sections may be merged into the Claim).

Note: omission rules apply per **Severity**. A LOW-severity finding with HIGH confidence may collapse; a HIGH-severity finding with LOW confidence MUST keep all 11 fields (LOW confidence requires the uncertainty be explicit, which lives in `Why it is real`).

See the Full Report Skeleton below for the verbatim entry template (a SQL-INJECTION example demonstrating all required fields).

The bullet labels (`**Severity:**`, `**Confidence:**`, `**Category:**`, `**Rule:**`, `**Location:**`, `**Claim:**`) and section labels (`**Code:**`, `**Data flow:**`, `**Why it is real:**`, `**Suggested fix:**`) are byte-exact — the Council parser navigates the entry by them.

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

A report that ships literal `[fenced code block here ...]` text is malformed; the Council pass will treat it as a broken finding.

---

### Skipped (allowlist) Section

Columns: `ID | path:line | rule | council_status`. Empty-state placeholder is the literal string `_None — no` followed by a backtick-quoted `audit-exceptions.md` reference and `in this project_`. The verbatim layout is in the Full Report Skeleton below.

`council_status` is parsed from the matching entry's `**Council:**` bullet inside `audit-exceptions.md`. Allowed values: `unreviewed`, `council_confirmed_fp`, `disputed`. Use `sed '/^<!--/,/^-->/d'` (per `commands/audit-restore.md` post-13-05 fix) to strip HTML comment blocks before walking entries — the seed file ships with an HTML-commented example heading that would otherwise produce false matches. The `F-A001`..`F-ANNN` numbering is independent of `F-NNN` for surviving findings.

---

### Skipped (FP recheck) Section

Columns: `path:line | rule | dropped_at_step | one_line_reason`. Empty-state placeholder: `_None_`. The verbatim layout is in the Full Report Skeleton below.

`dropped_at_step` MUST be an integer in 1-6 matching the FP-recheck step where the finding was dropped (see `components/audit-fp-recheck.md`). `one_line_reason` MUST be ≤ 100 chars and reference concrete tokens visible in the source — never `looks fine`, `trusted code`, or `out of scope`.

---

### Council Verdict Slot (Council Handoff)

The audit writes this section as a literal placeholder. The `/council audit-review` pass mutates it in place after collating Gemini + ChatGPT verdicts.

```markdown
## Council verdict

_pending — run /council audit-review_
```

Byte-exact constraints: U+2014 em-dash (literal `—`, not hyphen-minus, not en-dash); single-underscore italic (`_..._`), no asterisks; no backticks, no bold, no code fence, no trailing whitespace. DO NOT REFORMAT — the Council pass greps for this exact byte sequence to locate the slot before rewriting it.

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
