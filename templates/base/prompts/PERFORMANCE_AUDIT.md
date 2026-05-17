# Performance Audit — Base Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive performance audit of a web application. Act as a Senior Performance Engineer.

---

## QUICK CHECK (5 minutes)

| # | Check | Target |
| --- | ------- | -------- |
| 1 | Homepage TTFB | < 800ms (CWV) |
| 2 | Bundle size (gzipped) | < 500KB |
| 3 | No N+1 queries | 0 |
| 4 | Database indexes | All FKs indexed |
| 5 | Caching enabled | Yes |
| 6 | INP at p75 | < 200ms |
| 7 | LCP at p75 | < 2.5s |
| 8 | CLS at p75 | < 0.1 |
| 9 | RSC client-boundary leak (App Router projects) | No `'use client'` at layout level |
| 10 | Edge route streaming (Edge / Workers projects) | `ReadableStream` response, not buffered |

---

## 0.1 PROJECT SPECIFICS — [Project Name]

**Current metrics:**

- Homepage load time: [X]ms
- Bundle size: [X]KB
- Database queries per page: [X]

**Already optimized:**

- [ ] Caching: [what is cached]
- [ ] CDN: [is it used]
- [ ] Lazy loading: [where]

---

## 0.2 SEVERITY THRESHOLDS (Performance-Specific Calibration)

The severity rubric levels (CRITICAL / HIGH / MEDIUM / LOW) are defined in
`components/severity-levels.md` — do not redefine. The table below specifies
the latency-based thresholds at which each level applies for performance
findings; the rubric labels themselves are unchanged.

| Level | Latency threshold | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Blocks operation, > 5s end-to-end | **BLOCKER** |
| HIGH | Noticeable slowdown, > 2s p95 | Fix before deploy |
| MEDIUM | Improvable, > 1s p95 | Next sprint |
| LOW | Micro-optimization, < 1s | Backlog |

**Threshold definitions (calibration footnotes):**

- `p95` is computed over a trailing 5-minute window of production traffic,
  outliers > 3σ excluded. If only synthetic / load-test data is available,
  state that explicitly in the finding's evidence — synthetic p95 is not
  the same as production p95.
- `end-to-end` includes the full request lifecycle (network ingress →
  app handler → DB → cache → external HTTP → render → egress), not just
  the slowest single hop.
- Thresholds assume **single-tenant baseline workload**. Multi-tenant
  systems should add a 20-50% overhead per concurrent tenant before
  comparing against the table.
- **Cold-start latency** (first request after a process restart, Lambda
  / serverless warm-up, JIT compile) is excluded from the table. Cold-start
  finding only when cold-start exceeds a project-documented baseline
  (record the baseline in `## PROJECT SPECIFICS` if relevant).

---

## 1. DATABASE PERFORMANCE

### 1.1 N+1 Queries

```text
Bad: 1 query + N queries for related data
Good: 1-2 queries with eager loading
```

- [ ] No N+1 patterns
- [ ] Eager loading is used
- [ ] Joins instead of multiple queries

### 1.2 Query Optimization

- [ ] Indexes on frequently used columns
- [ ] Indexes on foreign keys
- [ ] No SELECT * where not needed

### 1.3 Slow Queries

- [ ] No queries > 100ms
- [ ] EXPLAIN for complex queries
- [ ] Pagination for large datasets

### 1.4 ORM Lifecycle Events

ORM events (before/after delete, update, create) can silently trigger N+1 during bulk operations.

```text
Bad:  on_delete hook iterates related records with individual queries
Good: on_delete hook uses bulk query or DB-level cascade
```

- [ ] Delete/update hooks do not use per-record iteration
- [ ] Create/update hooks do not make synchronous external API calls
- [ ] Bulk operations bypass or batch-process lifecycle events

### 1.5 Complex Query Patterns (Subqueries)

Chaining multiple subquery conditions (e.g. `EXISTS (SELECT ...)`) can cause exponential query complexity even with proper indexes.

- [ ] No more than 2 nested subquery conditions per query
- [ ] Subqueries replaced with JOINs where possible (especially for sorting/filtering)
- [ ] No subquery conditions inside loops or polling endpoints

---

## 2. CACHING

### 2.1 Application Cache

- [ ] Frequently read data is cached
- [ ] Cache invalidation is configured
- [ ] TTL is reasonable

### 2.2 HTTP Cache

- [ ] Static assets have cache headers
- [ ] ETags or Last-Modified
- [ ] CDN for static files

### 2.3 Query Cache

- [ ] Heavy queries are cached
- [ ] Cache key includes parameters

---

## 3. FRONTEND PERFORMANCE

### 3.1 Bundle Size

- [ ] JavaScript < 500KB gzipped
- [ ] CSS < 100KB gzipped
- [ ] Code splitting is used

### 3.2 Loading Strategy

- [ ] Critical CSS inline
- [ ] Non-critical CSS lazy
- [ ] JavaScript defer/async

### 3.3 Images

- [ ] Optimized (WebP, AVIF)
- [ ] Lazy loading
- [ ] Proper sizes (srcset)

### 3.4 Core Web Vitals

Google deprecated **FID (First Input Delay)** in favor of **INP
(Interaction to Next Paint)** in March 2024. INP is the canonical
responsiveness CWV since then; FID still appears in legacy dashboards
and pre-2024 budgets but should no longer be the threshold the audit
gates on.

- [ ] **LCP** (Largest Contentful Paint) < 2.5s at the 75th percentile
- [ ] **INP** (Interaction to Next Paint) < 200ms at the 75th
      percentile — measures responsiveness across the **entire
      session**, not just the first interaction. Common regressions:
      long-running click handlers, synchronous state updates that
      block paint, third-party scripts running in the main interaction
      task. The "good" / "needs improvement" / "poor" thresholds are
      200ms / 500ms.
- [ ] **CLS** (Cumulative Layout Shift) < 0.1 at the 75th percentile
- [ ] **TTFB** (Time to First Byte) < 800ms — included because INP
      regressions often have a TTFB root cause on streaming SSR.
- [ ] **FID** legacy: report only when consumer dashboard / CI gate
      still requires it; otherwise INP supersedes (do NOT report
      both as separate findings — they measure the same axis).

Measurement provenance: a finding citing CWV must say **how** the
number was obtained (RUM via web-vitals.js / Chrome UX Report (CrUX) /
PageSpeed Insights field data / synthetic Lighthouse run). Synthetic
Lighthouse and field RUM are not interchangeable — synthetic INP is
particularly unreliable because it has no user interactions to
measure.

### 3.5 Polling and Repeated Requests

Frequent frontend polling (setInterval, usePoll) can overwhelm the backend if endpoints are not optimized.

- [ ] Endpoints called at intervals < 30s respond in < 50ms
- [ ] Polling endpoints use cache or in-memory storage, not heavy DB aggregations
- [ ] Polling intervals are reasonable (no sub-second polling for non-critical data)

### 3.6 Animation Performance

Animations that mutate layout-triggering properties force the browser to
re-run layout / paint on every frame and produce jank on lower-end
devices. Restrict animations to GPU-accelerated properties.

- [ ] Animations use `transform` and `opacity` (GPU-accelerated, no layout reflow)
- [ ] No animations on `width`, `height`, `top`, `left`, `margin`, `padding` (trigger layout) unless wrapped in `will-change` with measured benefit
- [ ] No animations on `box-shadow`, `filter`, `backdrop-filter` on long lists (paint cost scales with element count)
- [ ] `prefers-reduced-motion` media query honored for accessibility

### 3.7 React Server Components & App Router (Next.js 13+, Remix v2+)

RSC and the App Router introduced new perf primitives — and new
failure modes the auditor must learn to read. Findings here are real
only when the project is on Next.js App Router (the file convention
`app/page.tsx`, not `pages/`) or an equivalent RSC-aware framework.

- [ ] **Client-component boundary leak.** A `'use client'` directive
      at the top of a high-level layout component pulls every nested
      component into the client bundle. Audit the highest-level
      `'use client'` files: each one defines the boundary. A
      `'use client'` in `app/layout.tsx` defeats RSC entirely.
- [ ] **Server-action waterfall.** Sequential `await` chains in a
      Server Component (`const a = await fetchA(); const b = await
      fetchB();`) serialize work that could parallelize with
      `Promise.all` or with `<Suspense>` boundaries that stream
      independently.
- [ ] **`<Suspense>` placement.** A single top-level `<Suspense>`
      around the whole page defeats streaming — the user sees nothing
      until the slowest fetch completes. Each independent data
      dependency should have its own `<Suspense>` boundary so each
      streams in independently.
- [ ] **Streaming SSR + dynamic = 'force-dynamic'.** Setting
      `export const dynamic = 'force-dynamic'` disables every layer of
      caching (PPR, ISR, Data Cache, Full Route Cache) for the entire
      route. Audit for blanket `dynamic = 'force-dynamic'` on routes
      that don't actually need request-time evaluation.
- [ ] **Data Cache (`fetch` revalidation).** Next.js extends `fetch`
      with `next: { revalidate: <s>, tags: [...] }`. A bare `fetch()`
      in a Server Component caches **forever by default** (until
      Next 15's opt-in change); audit for stale-data risks. A
      `cache: 'no-store'` on every fetch defeats the Data Cache —
      audit for whether it's intentional or a copy-paste from a
      tutorial.
- [ ] **Partial Pre-Rendering (PPR).** When enabled
      (`experimental.ppr` in `next.config.js`), routes are split into
      a static shell + dynamic holes. A finding citing PPR must
      identify which holes are dynamic and confirm each dynamic
      boundary has its own `<Suspense>` fallback — otherwise the
      shell waits on the dynamic data.
- [ ] **`<Image>` / `<Script>` / `<Font>` discipline.**
      `next/image` without `priority` on above-the-fold LCP image
      delays LCP by one render cycle. `next/script` with default
      `strategy="afterInteractive"` blocks INP if the script is large.
      `next/font` loads as a system fallback unless the route
      pre-renders the font file — audit for FOIT/FOUT on dynamic
      routes.
- [ ] **Server-component bundle.** Server Components ship zero JS to
      the client — but the **client component's** import graph still
      ships. A Server Component that imports a Client Component
      transitively pulls every dependency of that Client Component
      into the bundle. Audit the import graph at the boundary
      (`'use client'` files), not at the entry.

### 3.8 Edge Runtime & Cold-Start Methodology

Edge functions (Cloudflare Workers, Vercel Edge, Deno Deploy, AWS
Lambda@Edge, Fastly Compute) trade peak performance for global
distribution. The cold-start profile is **different** from Node /
container deploys — distinct from the "Cold-start latency excluded"
footnote in `## 0.2 SEVERITY THRESHOLDS`.

- [ ] **V8 isolate cold start.** Cloudflare Workers and Vercel Edge
      run on V8 isolates: cold start is typically < 5ms (no container
      boot, no language runtime warmup). A finding citing > 50ms
      cold start on V8 isolates indicates a **code-level** problem
      (heavy top-level imports, sync IO at module load, dynamic
      `import()` resolution).
- [ ] **Lambda@Edge / Node-on-Edge cold start.** AWS Lambda@Edge runs
      Node containers — cold-start budget 200ms-1s depending on
      bundle size. Audit bundle size at the Edge function boundary;
      every `node_modules` dependency adds boot time.
- [ ] **Geographic distribution profile.** Edge functions execute at
      the PoP nearest the user. A finding citing edge latency must
      cite which PoP (e.g., `cf-ray` header for Cloudflare, `x-vercel-id`
      for Vercel) and which region originated the request. Edge
      latency varies 5x across regions.
- [ ] **KV / D1 / R2 / Durable Object hot-path access.** Cloudflare
      KV reads are eventually-consistent and may take 50-100ms on
      first access in a region. D1 is regional — a request in a
      far-from-primary region pays the round-trip. Audit for
      cross-region hot-path access to KV/D1.
- [ ] **Streaming response.** Edge functions support streaming via
      `Response` with a `ReadableStream` body. A non-streaming Edge
      response forces the function to buffer the full payload in
      memory before sending — defeats the latency advantage.
- [ ] **Workers AI / Vercel AI SDK latency.** When a route invokes an
      LLM on Edge, the LLM call dominates total latency. Audit for
      whether the route streams tokens back to the client (preserves
      TTFB) vs. waits for completion (TTFB = full LLM latency).
- [ ] **Compatibility flags / runtime quirks.** Cloudflare Workers
      lacks some Node APIs (`fs`, `net`, parts of `crypto`); Vercel
      Edge runs a subset of Web APIs. A finding alleging "this won't
      work on Edge" must cite the specific missing API + a
      reproducible failure path, not just a Node-API name.

---

## 4. API PERFORMANCE

### 4.1 Response Time

- [ ] API endpoints < 500ms
- [ ] No blocking operations in handlers

### 4.2 Payload Size

- [ ] Pagination for lists
- [ ] Only needed fields in response
- [ ] Gzip compression

### 4.3 Rate Limiting

- [ ] Protection from abuse
- [ ] Graceful degradation

---

## 5. BACKGROUND JOBS

### 5.1 Queue Usage

- [ ] Heavy operations in queue
- [ ] Email sending async
- [ ] File processing async

### 5.2 Job Configuration

- [ ] Timeout configured
- [ ] Retry policy
- [ ] Failed job handling

### 5.3 Queue Payload Size

Data passed to background jobs is serialized and stored in the queue backend (Redis, DB, etc.). Large payloads waste memory and slow down queue processing.

```text
Bad:  Passing raw HTML, file content, or Base64 blobs as job arguments
Good: Passing a reference (ID, cache key, file path) and loading data inside the job
```

- [ ] Job constructors do not accept raw text/HTML/binary data
- [ ] Large data is stored in cache or filesystem, job receives only a reference
- [ ] Failed jobs table is not bloated with oversized payloads

### 5.4 Job Idempotency

Jobs may be retried on failure. A non-idempotent job can corrupt data when executed more than once.

```text
Bad:  IncrementCounter job adds +1 each run → double-counted on retry
Good: SetCounter job sets absolute value → safe to retry

Bad:  SendEmail job sends on each run → duplicate emails on retry
Good: SendEmail job checks "already_sent" flag before sending
```

- [ ] Jobs produce the same result when executed multiple times
- [ ] State-changing jobs check current state before modifying
- [ ] External API calls use idempotency keys where supported
- [ ] Database operations use transactions or unique constraints to prevent duplicates

---

## 6. INFRASTRUCTURE

### 6.1 Server

- [ ] Enough RAM
- [ ] CPU not overloaded
- [ ] Disk I/O is normal

### 6.2 Database

- [ ] Connection pooling
- [ ] Read replicas (if needed)
- [ ] Query monitoring

### 6.3 Production Readiness

Debug tools and development settings in production degrade performance significantly.

- [ ] Debug mode is disabled in production
- [ ] No development-only tools in production dependencies
- [ ] Logging level is `warn` or `error`, not `debug` or `trace`
- [ ] Source maps are not served to clients in production

**Cache/Session/Queue Drivers:**

| Component | Bad (Dev) | Good (Prod) |
|-----------|-----------|-------------|
| Cache | File / Memory | Redis / Memcached |
| Sessions | File | Redis / Database |
| Queue | Sync | Redis / RabbitMQ / SQS |
| Logging | Single file | Aggregated (ELK, Datadog) |

- [ ] Cache backend is not file-based in production
- [ ] Session backend is not file-based in production
- [ ] Queue is not synchronous in production

### 6.4 Redis Health

If using Redis for cache/sessions/queues, monitor its health.

```bash
redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses|evicted_keys"
redis-cli INFO memory | grep used_memory_human
redis-cli CONFIG GET maxmemory-policy
```

**Hit Ratio:** `hits / (hits + misses)` — should be > 90%.

| Metric | OK | Warning | Critical |
|--------|----|---------|----------|
| Hit ratio | > 90% | 70-90% | < 70% |
| Evicted keys | 0 | Growing slowly | Growing fast |
| Memory usage | < 80% maxmemory | 80-90% | > 90% |

**Severity mapping.** The OK / Warning / Critical labels above are
**cache-health diagnostic bands**, not the canonical CRITICAL / HIGH /
MEDIUM / LOW severity rubric in `## 0.2 SEVERITY THRESHOLDS`. A Redis
finding cites the band as evidence (e.g., `Hit ratio 65%, Critical
band`), then maps it to canonical severity via the latency impact it
causes downstream:

- Critical band (e.g., < 70% hit ratio) that produces > 5s end-to-end
  on a reachable user path → **CRITICAL** in canonical severity.
- Critical band that produces > 2s p95 on a reachable user path →
  **HIGH**.
- Critical band with no measurable user-path latency impact (e.g.,
  background-only cache warming on a non-blocking job) → **LOW** or
  drop entirely (cache misconfiguration is real but not blocking
  without a downstream symptom).

Cross-reference the Severity Ceiling Table in
`components/audit-severity-anchor.md` when escalating a cache-band
finding past its default canonical mapping.

- [ ] Redis hit ratio > 90%
- [ ] `maxmemory-policy` is set (recommended: `allkeys-lru` for cache, `noeviction` for queues)
- [ ] No excessive evictions

---

## 7. MONITORING

- [ ] APM tool configured
- [ ] Slow query logging
- [ ] Error rate tracking
- [ ] Uptime monitoring

---

## UNCERTAINTY DISCIPLINE

If evidence is incomplete: lower confidence, reduce severity, move the
observation into Non-Blocking Observations, and explicitly state the
uncertainty. Do not present assumptions as facts. Do not use weasel
words ("could potentially", "might allow", "in theory") to inflate
report length — either the finding is grounded or it isn't.

---

## CATEGORY ENUM (Audit-Type Override)

The shared finding schema (see `components/audit-output-format.md`) lists a broad `Category` enum spanning all audit types. For PERFORMANCE_AUDIT, restrict `**Category:**` to the performance-specific values below. Security / code-review / UX categories from the shared enum MUST NOT appear in this audit's findings.

Allowed `Category` values for performance findings:

- `Algorithmic Complexity` *(O(n²)/O(n³) where O(n) or O(n log n) is feasible)*
- `Memory` *(leak, excessive allocation, GC pressure, retained references)*
- `CPU` *(hot path, sync work blocking event loop / request thread)*
- `I/O` *(excessive syscalls, blocking disk reads on request path)*
- `Network/Latency` *(serial RTTs, payload bloat, missing batching)*
- `Caching` *(missing cache, stampede, incorrect invalidation, hit-ratio collapse)*
- `Concurrency` *(lock contention, missed parallelism, serialization bottleneck)*
- `Resource Exhaustion` *(file handles, sockets, connections, threads — DoS-adjacent vectors route to SECURITY_AUDIT.md if user-triggerable)*
- `Cost Amplification` *(LLM token explosion, egress cost, autoscale runaway)*
- `Startup/Cold-Start` *(boot path latency, lazy-load failure)*

If a candidate finding does not fit any of these categories, it is either out of scope for this audit (route to CODE_REVIEW.md / SECURITY_AUDIT.md / MYSQL_PERFORMANCE_AUDIT.md / POSTGRES_PERFORMANCE_AUDIT.md) or the category needs to be added to this list deliberately — never silently fall back to a code-review category.

Database-specific performance findings (query plan, index, locking, replication) belong in MYSQL_PERFORMANCE_AUDIT.md / POSTGRES_PERFORMANCE_AUDIT.md, not here.

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

## 8. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 9. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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
code-review, Performance for performance, Reliability for design-review),
and `Rule` namespace. The schema (field order, byte-exact bullet labels,
section order, Council slot string) is identical across all 7 audit
types.

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
