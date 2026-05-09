# Security Audit — Base Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## GOAL

Act as an offensive security engineer reviewing a distributed SaaS system
for realistic, exploitable vulnerabilities. NOT a checklist auditor. NOT
an OWASP scanner. NOT a CIS benchmark.

The objective is the highest-impact real exploits at the lowest possible
false-positive rate. A single confirmed exploit chain is more valuable
than 20 speculative checklist findings. Think like an attacker who wants
money, account takeover, tenant compromise, or infrastructure cost
amplification.

Compliance theatre, deprecated headers, and OS-specific permission
specifics are out of scope unless they directly enable a concrete attack
path in this codebase.

---

## PROJECT SPECIFICS — [Project Name]

Optional project-specific context. If not filled in, ignore. Do not mention
placeholder content in the final report.

**Already implemented (do not re-flag):**

- Authentication mechanism: [which]
- Authorization model: [policies / middleware / row-level / ABAC / RBAC]
- Input validation layer: [where]
- CSRF protection: [how]
- Tenant isolation: [scoping mechanism]

**Public endpoints (by design — do not flag as missing-auth):**

- `/api/health`
- `/webhooks/*` — verify signature is enforced

**Known specifics:**

- [Project-specific notes — e.g., "JWT in httpOnly cookie, refresh in body"]

---

## CODEBASE SIZE & RISK STRATEGY

| Size | Strategy |
|------|----------|
| **SMALL** (<20 files) | Read everything; full data-flow trace per public route. |
| **MEDIUM** (20-200) | Priority files (auth, queries, fetchers, queue handlers, webhooks); 1-hop dependency expansion. |
| **LARGE** (200+) | Surgical: only critical paths from the Attack Surface Map. Skip pure utility code unless evidence ties it to a sink. |

**Risk-level triggers (escalate depth):**

| Risk | Triggers |
|------|----------|
| **HIGH** | Auth, crypto, signed URLs, webhooks, value transfer, validation removal, tenant-scope changes, AI/LLM tool execution |
| **MEDIUM** | New public APIs, business-logic state changes, queue handlers, file uploads, redirects |
| **LOW** | Comments, tests, UI-only, logging, refactors with no execution-path change |

**Red flags — immediate escalation:**

- Removed code from "security" or "fix" commits
- Access modifiers downgraded (`private` → `public`, middleware removed)
- Validation/sanitization removed without documented replacement
- New external HTTP/DB/queue calls added without checks
- New `eval` / `exec` / `unserialize` / dynamic dispatch
- `--no-verify` / `--insecure` / `verify=False` / `rejectUnauthorized: false`

---

## PHASE 0 — THREAT MODEL

Before searching for vulnerabilities, build a threat model from the code.
Skip this phase only on diffs of trivial scope (≤ 5 lines, no execution
boundary crossed).

Identify in the modified scope:

- **Trust boundaries** — where untrusted data crosses into trusted code
  (HTTP edge, webhook ingress, queue consumer, file parser, AI tool
  output, third-party SDK callback)
- **Attacker-controlled inputs** — request bodies, URL params, headers,
  cookies, file uploads, fetched URLs, queue payloads, prompt content,
  RAG retrieved context
- **Privilege boundaries** — anonymous → authenticated → tenant member →
  tenant admin → platform admin → background-job context
- **Persistence layers** — DB writes, object storage, cache, search index,
  vector store, queue, log sink
- **External integrations** — third-party APIs, webhooks (in/out), OAuth
  providers, payment processors, AI inference endpoints
- **Multi-tenant boundaries** — every query, cache key, storage path, job
  payload, search filter MUST carry tenant context

Output (in scratchpad, not the report): a brief sentence per dimension
naming the concrete code locations involved.

---

## PHASE 1 — ATTACK SURFACE MAP

List all reachable entry points in the scope:

- **Public endpoints** — unauthenticated routes, public APIs, status pages
- **Authenticated endpoints** — user-facing routes, internal API surface
- **Admin interfaces** — privileged routes, support tools, impersonation
- **Webhooks ingress** — signed and unsigned
- **File-upload endpoints** — direct upload, presigned URL grants
- **URL fetchers** — image proxy, OG-card scraper, RAG ingestion, OAuth
  callback URL handlers
- **OAuth flows** — login, account linking, token refresh, scope grants
- **Queue consumers** — what triggers them, what payloads they trust
- **Scheduled jobs** — cron handlers, batch processors
- **AI/LLM integrations** — prompt assembly sites, tool execution sites,
  RAG retrieval, agent loops

For each entry point: does the data immediately cross into a sink that
matters (DB query, shell exec, fetch, write, eval, model call)? If yes,
that path is a P1 target for Phase 2.

---

## ATTACKER MODEL

Severity is meaningless without naming the actor. For every finding,
classify the required attacker as one of:

| Class | Capability |
|-------|------------|
| **Unauthenticated** | Internet anyone with curl. |
| **Authenticated user** | Valid account on the platform. |
| **Tenant admin** | Privileged within a single tenant. |
| **Compromised third-party** | Forged webhook sender, malicious OAuth provider, hostile SDK update. |
| **Internal operator** | Engineer / support agent with admin tools. |
| **Adversarial AI input** | Untrusted prompt content, RAG-poisoned retrieval, tool-call output reflected back. |

The lower the required class, the higher the realistic severity. An
"unauthenticated" SQL injection on a public route is CRITICAL; the same
sink behind tenant-admin + MFA is HIGH at most.

---

## 0. QUICK CHECK (entry-point scan, NOT grep checklist)

Use grep ONLY as entry-point discovery. Never report a grep match without
execution-path verification. The point is to surface candidate sinks for
Phase 2 deep analysis.

| # | Entry-point pattern | What to verify next |
|---|---------------------|---------------------|
| 1 | Raw SQL string concatenation / template literals in queries | Trace input origin → confirm no parameterization upstream |
| 2 | Direct DOM injection sinks (`innerHTML`, React's `dangerouslySetInnerHTML`, `{!! !!}`, `v-html`, `[innerHTML]`) | Trace the value; check framework escaping |
| 3 | `exec` / `system` / `spawn` / `shell_exec` / `subprocess.run(shell=True)` | Trace argument origin; check if user-influenced |
| 4 | Deserialization (`unserialize`, `pickle.loads`, `Marshal.load`, `yaml.load` unsafe) | Trace input source; if user-controlled = CRITICAL candidate |
| 5 | URL fetchers (`fetch`, `requests.get`, `httpClient.get`) on user input | Check SSRF guards (scheme, internal-IP block, metadata block) |
| 6 | `redirect(...)` on user input | Check allowlist / relative-only enforcement |
| 7 | Webhook handlers | Check signature verification + timestamp + replay protection |
| 8 | Auth middleware on routes that mutate state | Confirm coverage of every state-changing route |
| 9 | Hardcoded secrets / `password.*=.*['"]` / API key patterns | Check git history; rotate if real |
| 10 | `--insecure` / `verify=False` / `rejectUnauthorized: false` / TLS bypass | Confirm intent; flag if production code |
| 11 | Tenant-scoped queries missing `tenant_id` | Check every list / get / delete / update |
| 12 | LLM tool execution / dynamic prompt assembly | Check prompt injection boundary; check tool authorization |

**Absent from this list (intentionally):** specific bcrypt round counts,
OS-specific chmod values, HSTS max-age arithmetic, deprecated headers
like `X-XSS-Protection` (covered explicitly in the Transport / Headers
section below). These are compliance theatre, not exploits.

---

## DEEP EXPLOIT ANALYSIS

The following modules are not a checklist. Treat each as a reasoning
prompt: does this codebase have a problem in this area, and can I describe
a concrete attack path for a named attacker class?

### Authentication & Session Lifecycle

Audit the full lifecycle, not just login:

- Login, logout, password reset, MFA enrollment + bypass paths
- Session refresh, token rotation, refresh token reuse detection
- Invitation / signup flows (account-takeover via invite forgery)
- Organization switching (auth context desync — old tenant cached, new
  tenant accessed)
- Impersonation / admin override (audit log, scope, expiry)
- "Remember me" tokens, magic links, recovery codes
- OAuth flows: state parameter validation, PKCE, redirect-URI validation,
  scope creep, token replay, account-linking takeover

Look specifically for **auth desynchronization** — paths where the
identity in one layer (HTTP session) diverges from another (background
job, cache, search index, websocket connection).

### Authorization (UI / API / job / cache parity)

Authorization MUST be enforced server-side at every layer:

- Route guards on every state-changing endpoint
- Object ownership verified on read AND write (IDOR / BOLA)
- Background jobs check authorization on the data they touch (not just
  "this job exists")
- Cache keys include tenant + user identity (or are tenant-scoped via
  separate namespaces)
- Search indexes filter by tenant + readable-by-user before returning
- Exports / bulk operations check authorization per row, not per request
- Admin features have separate guards from regular auth, not just a role
  string compared in one place
- Authorization checks are **deny-by-default**, not allow-by-default

A single ungated layer breaks the whole model. Enumerate every layer.

### Multi-Tenant Isolation

For SaaS, this is the highest-blast-radius concern:

- Every query carries `tenant_id` (or equivalent) in the WHERE clause
- Background jobs propagate tenant context from the job payload, not from
  global state
- Cache keys include tenant identity; eviction is scoped
- Object storage paths are tenant-prefixed and signed-URL-scoped
- Search indexes are tenant-partitioned OR every query filters
- Webhooks include tenant identity in signed payload, not just header
- Cross-tenant references (parent org / shared template) explicitly
  verified, not implicit

A single missing `tenant_id` filter on a list endpoint = tenant-data
exfiltration = CRITICAL.

### Injection Sinks

For each of these sinks, verify execution-path safety, not just the
framework default:

- **SQL** — parameterized; raw escapes used only with explicit allowlists
- **Command / shell** — `execFile` / array form, never `shell: true` with
  user input; arguments escaped if shell needed
- **XSS** — output context-aware escaping; raw-HTML sinks
  (`innerHTML`, React `dangerouslySetInnerHTML`, Vue `v-html`, Angular
  `[innerHTML]`, Blade `{!! !!}`) only with documented sanitization
- **SSTI** (server-side template injection) — never compile templates
  from user input
- **Deserialization** — only safe formats (JSON, MessagePack); never
  `pickle`/`unserialize`/`yaml.load` on user data
- **Dynamic dispatch** — `eval`, dynamic-code constructors, dynamic
  method calls, reflection on user-controlled names

### File Handling, Path Traversal, Object Storage

- File type validated by magic bytes, not just extension
- File size limited (request-level + storage-level)
- Filename randomized (UUID); never use user-provided name
- Path operations use safe-join / `os.path.realpath` + ancestor check
- Uploads go to private bucket / non-web-rooted directory
- Signed URLs expire (short-lived) and are tenant-scoped
- Bucket listing disabled
- CDN does NOT cache authenticated responses (authenticated = `Cache-Control: private`)
- User-controlled headers (`Vary`, `Cookie`) cannot poison cache key

### Webhook Security (in)

- Signature verification uses constant-time comparison
- Timestamp validated (reject replays older than ~5 min)
- Failed verification terminates execution before any side effect
- Endpoint rate-limited per-source
- Idempotency key honored (same event ID → no double-execution)
- Webhook handlers do NOT trust the payload's claimed identity beyond the
  signed envelope

### Async / Queue / Job Security

- Job payloads validated before execution (treat as untrusted input)
- Tenant + user context included in payload; job authorizes against it
- Idempotency on retries (no duplicate side effects on at-least-once
  delivery)
- Dead-letter queue handles poisoned jobs without leaking data
- Delayed jobs cannot be enqueued with arbitrary delays by users (DoS via
  long queue accumulation)
- Job-execution errors do not leak stack traces / secrets to user-visible
  channels

### Cache / CDN

- Authenticated responses are NOT publicly cacheable (`Cache-Control:
  private` + correct `Vary`)
- Cache keys include auth + tenant + user identity for any
  user-personalized response
- Signed URLs expire
- User-controlled headers cannot poison cache behavior
- Cache invalidation triggered on auth-relevant data changes

### AI / LLM / RAG Security

- System prompt is protected from user override (sandwich pattern: system
  prompt → untrusted user content → system reminder)
- User-supplied content is treated as DATA, never instructions
- Retrieved RAG context is sanitized + provenance-tagged; cross-tenant
  RAG leakage prevented by index isolation
- LLM output is treated as untrusted input when fed back into tools or
  other LLMs
- Tool execution is authorized per-call (the agent cannot call tools the
  user lacks permission for)
- Secrets are EXCLUDED from embeddings and vector stores (one leaked
  embedding = persistent compromise)
- Cost / token caps per-user + per-tenant + globally
- Prompt-injection boundaries explicitly identified at each agent step

### Business Logic

The biggest blind spot of pattern-based audits. Look for:

- **Race conditions** — TOCTOU on quota / balance / idempotency-key
  checks; concurrent requests bypassing single-execution guards
- **Replay** — payment / state-change endpoints accepting the same
  request twice without idempotency keys
- **Quota bypass** — limits enforced in UI but not in API; per-request
  but not per-batch; per-endpoint but bypassable by parallel calls
- **State machine bypass** — workflow steps skipped via direct API call;
  invalid transitions accepted (e.g. `order.status = 'shipped'` without
  going through `paid`)
- **Privilege inheritance** — child resources inheriting parent ACLs
  unsafely; "share with team" granting more than expected
- **Idempotency missing** — retried operations causing duplicate charges,
  duplicate emails, duplicate jobs
- **Workflow short-circuits** — "skip this step in dev" flags reachable
  in production; A/B test branches with weaker validation

### Economic Abuse

For AI-native and multi-tenant SaaS, often the dominant attack surface:

- AI inference cost amplification (recursive prompts, tool loops, large
  RAG retrieval) without per-user/tenant caps
- Token-amplification (one user prompt → many model calls without bound)
- Storage exhaustion (file upload DoS, log inflation, vector-store
  poisoning)
- Webhook spam (one event triggers many outbound calls)
- Email / SMS delivery flood (transactional email service used as
  spam-relay)
- Search-index amplification (one query → expensive index scan)
- Queue amplification (one job enqueues N jobs → N×M jobs)
- Free-tier resource abuse (signup automation, trial chaining)
- Billing desynchronization (usage recorded but not metered; metered but
  not charged)

### Crypto & Secrets

- Password hashing uses modern adaptive algorithm (argon2id / bcrypt /
  scrypt) with production-grade cost factors — do NOT bikeshed the
  specific number
- Token / nonce / session ID generation uses CSPRNG (`secrets`,
  `crypto.randomBytes`, `crypto.randomUUID`), never `Math.random` /
  `rand`
- Secret comparison is constant-time (`hash_equals`, `hmac.compare_digest`)
- Application secret keys are loaded from environment, distinct per
  environment, ≥ 32 bytes of entropy, not committed
- Encryption uses authenticated modes (GCM, ChaCha20-Poly1305); never ECB
- Signed URLs / tokens carry expiry; expiry is enforced on the read side

### Dependency Risk

- Lock files committed (`package-lock.json`, `composer.lock`,
  `poetry.lock`, `Cargo.lock`, `go.sum`)
- Known-CVE check (`npm audit`, `pip-audit`, `composer audit`, `govulncheck`)
- New packages: typosquatting check (compare letter-by-letter against the
  intended name)
- Post-install scripts inspected for new dependencies

### Transport, Headers, TLS

Compact, framework-aware. Modern frameworks set most of these by default
— flag ABSENCE only when the framework default is disabled:

- HTTPS required in production; HTTP redirects to HTTPS
- HSTS set with reasonable max-age + `includeSubDomains` (do NOT
  bikeshed the number)
- `Content-Security-Policy` set (or `default-src 'none'` for APIs)
- `X-Frame-Options: DENY` or `frame-ancestors` in CSP
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- CORS: explicit origin list (never `*` with credentials)

`X-XSS-Protection` is dead — do NOT report its absence.

### SSRF / Open Redirect / Host Injection

- URL fetchers validate scheme (https only), block private IPs (RFC1918,
  127.0.0.0/8, 169.254.0.0/16, cloud metadata 169.254.169.254 and
  fd00:ec2::254), enforce timeouts, and disable redirects to private
  ranges
- Redirect targets validated against allowlist or restricted to relative
  paths
- Password-reset / signup-confirmation links use a configured base URL,
  not the request `Host` header (or Host is validated)

---

## EXPLOIT CHAINS & BLAST RADIUS

Findings are not isolated. Before finalizing severity, check whether two
or more LOW/MEDIUM findings combine into a CRITICAL chain:

> Weak webhook signature + SSRF in fetcher + cloud-metadata reachable
> = unauthenticated RCE via stolen IAM credentials.
>
> Missing tenant filter on list endpoint + cache without tenant-scoped
> key = tenant-data exfiltration via cache hit on adjacent tenant's
> request.
>
> Prompt injection in RAG + LLM tool authorization missing + tool that
> reads other users' data = cross-user data exfil via crafted document.

For every HIGH/CRITICAL finding, write one sentence describing what
happens AFTER successful exploitation:

- What does the attacker gain?
- How far can it scale (one user / one tenant / all tenants)?
- Is automation feasible?
- Does it enable lateral movement to adjacent components?

---

## EXPLOIT PRECONDITIONS (severity calibration)

For every finding, explicitly identify:

- **Required attacker class** (from ATTACKER MODEL above)
- **Required privileges** (none / valid account / admin / etc.)
- **Required timing** (race window, expiry, business-hour dependency)
- **Required user interaction** (none / clicking link / accepting prompt)
- **Environmental assumptions** (default deployment / specific config /
  specific data state)
- **Dependency on external compromise** (required compromised third party,
  insider, or other vuln)

Severity MUST reflect the realistic preconditions, not the worst-case
imagined scenario. A bug requiring tenant-admin + race window + specific
DB state is HIGH at most, not CRITICAL.

---

## DATA CLASSIFICATION (severity multiplier)

Severity scales with the sensitivity of exposed data:

| Class | Examples | Severity floor when exposed |
|-------|----------|-----------------------------|
| **Secrets / credentials** | API keys, OAuth tokens, session cookies, signing secrets | CRITICAL |
| **Financial data** | Card data, bank account, balance, payout details | CRITICAL |
| **PII (regulated)** | SSN, government ID, health data, auth-relevant biometrics | HIGH |
| **PII (general)** | Name, email, address, phone | MEDIUM |
| **Tenant-private data** | Documents, messages, internal config | MEDIUM-HIGH (depends on volume + actor) |
| **Internal operational** | Logs, metrics, internal IDs | LOW-MEDIUM |
| **Public-by-design** | Profile bio, public posts | INFO (not a finding) |

---

## REALISTIC EXPLOITABILITY FILTER

Do NOT report vulnerabilities that require:

- Unrealistic attacker control (root on application server, physical
  access, cooperative MitM without prior compromise)
- Impossible timing (sub-microsecond races on systems with no observable
  jitter)
- Privileged infrastructure access already (if attacker has cloud
  console, they don't need this bug)
- Developer-only / debug-only environments not reachable in production
- Contrived edge cases with no realistic data state

DO prioritize:

- Remotely reachable paths (one curl command to PoC)
- Default deployments (works on a fresh install)
- Unauthenticated attack surface
- Financially exploitable flaws (chargeback, free service, bypass
  metering)
- Tenant-isolation failures
- Account-takeover paths

---

## FRAMEWORK GUARANTEES

Modern frameworks already secure many surfaces. Do NOT report
vulnerabilities already prevented by framework guarantees unless:

- The protection is explicitly bypassed in the diff
- A dangerous escape hatch is used (`raw`, React's
  `dangerouslySetInnerHTML`, Vue `v-html`, Angular `[innerHTML]`,
  `unsafe-*` directives)
- A framework default has been disabled

Examples to internalize before reporting:

- React / Vue / Svelte / Angular escape HTML in `{...}` / `{{...}}` by
  default — XSS only via the framework-specific raw-HTML escape
  (`dangerouslySetInnerHTML`, `v-html`, `[innerHTML]`, Svelte `{@html}`)
  or unescaped attribute injection in custom directives
- Prisma / Sequelize / SQLAlchemy / Eloquent parameterize by default —
  SQLi only via `.raw()` / `DB::raw` / `cursor.execute(f"...")` /
  `whereRaw` / `Sequel.lit` with user input
- Rails enables CSRF protection by default (`protect_from_forgery`);
  Laravel via `VerifyCsrfToken` middleware; Next.js server actions have
  built-in CSRF — flag only if disabled or excluded
- Next.js server components / server actions are not client-reachable —
  no need to flag "client could call this directly"
- Django / Rails / Laravel encode templates by default
- Express / Fastify / FastAPI: framework does NOT auto-CSRF; require
  middleware

If a framework guarantee is doing the work, **state the guarantee in the
finding's "Why it is real" or in the SELF-CHECK drop reason** — never
silently rely on it.

---

## DEFAULT DEPLOYMENT ASSUMPTION

Do NOT assume insecure infrastructure unless explicitly visible in code
or configuration. Avoid findings that depend on:

- Hypothetical reverse-proxy misconfiguration
- Imaginary CDN behavior
- Assumed cloud bucket exposure
- Unspecified deployment mistakes
- "What if someone left debug=True"

If the codebase shows debug=True hardcoded in production config: real
finding. If it's gated behind `if env == 'dev'`: not a finding.

---

## SOURCE-OF-TRUTH RULE

Every finding MUST be grounded in:

- Visible code (specific file:line tokens)
- Visible configuration (specific config file content)
- Observable execution flow (callable from a known entry point)

NEVER infer:

- Hidden routes
- Hidden middleware
- Undocumented behavior
- Configuration that "is probably set"
- Authorization "that probably exists somewhere"

If you cannot point to the code, you cannot report the finding.

---

## SECURITY RELEVANCE FILTER

Only report issues with one of:

- **Confidentiality** impact (data exposure)
- **Integrity** impact (unauthorized modification)
- **Availability** impact (DoS, resource exhaustion)
- **Authorization** impact (privilege escalation, scope bypass)
- Realistic abuse potential (economic, reputational, regulatory)

Do NOT report:

- Stylistic preferences (variable naming, file structure)
- Generic clean-code advice without security impact
- Theoretical concerns without exploitability
- Non-security maintainability issues (route to CODE_REVIEW.md, not here)
- Performance concerns without DoS angle (route to PERFORMANCE_AUDIT.md)

---

## QUALITY OVER QUANTITY

Do NOT maximize finding count. After identifying strong HIGH/CRITICAL
findings:

- Prioritize deeper exploit-chain analysis on those findings
- Validate exploitability against the embedded code
- Search for related attack chains across the codebase

Five weak speculative MEDIUMs are worse than one verified CRITICAL with a
working exploit description. If you cannot describe a concrete attack
path the user would care about, drop or downgrade.

---

## UNCERTAINTY DISCIPLINE

If exploitability cannot be confirmed from the embedded code:

- Lower confidence (HIGH → MEDIUM → LOW)
- Explicitly state the assumptions required
- Prefer omission over speculation

Do NOT present hypothetical vulnerabilities as confirmed. Do NOT use
weasel words ("could potentially", "might allow", "in theory") to inflate
report length — either the finding is grounded or it isn't.

---

## ADVERSARIAL SELF-REVIEW (mandatory for HIGH / CRITICAL)

For every HIGH or CRITICAL finding, attempt to disprove it before
reporting. Search explicitly for:

- Upstream sanitization that defangs the input
- Framework guarantees that block the path
- Impossible execution paths (dead code, environment-gated branches,
  feature flags off in production)
- Privilege constraints that prevent the required attacker class from
  reaching the sink
- Dead code that is never imported / called
- Environmental limitations (the function exists but is never wired into
  a route)

A finding survives only if exploitability remains plausible AFTER
adversarial review. Document in your scratchpad which counter-evidence
you considered and why it failed.

This is in addition to the 6-step FP recheck below — adversarial
self-review is the *intent* check; FP recheck is the *procedure* check.

---

## 1. SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

### Procedure

For every candidate finding, execute these six steps in order. Produce a `## SELF-CHECK` block per finding (in your scratchpad — not the final report) before deciding whether to report or drop it. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow user input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look exploitable in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the threat surface (e.g. an upstream sanitizer documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, etc.), the finding is a design trade-off, not a vulnerability. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual exploit scenario, not the rule label. A theoretical XSS sink behind 3 unlikely preconditions and no PII is not CRITICAL. If you cannot describe a concrete attack path the user would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

### Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `lib/utils.py:5` | `SEC-EVAL` | 5 | `eval is required by build-time codegen; never reached at runtime` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

### When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

### Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not exploit-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op (record `cross-ref skipped: no allowlist file present`) but the step itself MUST be acknowledged in the SELF-CHECK trace.

## 2. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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
| `design-review` | `design-review` | `templates/<framework>/prompts/DESIGN_REVIEW.md` |

Backward-compat aliases: `code` resolves to `code-review` and `deploy` resolves to `deploy-checklist` at dispatch time. The report filename ALWAYS uses the canonical slug, never the alias.

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

The Summary table has columns `severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck`, with one row per severity (CRITICAL, HIGH, MEDIUM, LOW). The rubric is in `components/severity-levels.md` — do not redefine. INFO is NOT a reportable finding severity; informational observations belong in the audit's scratchpad, never in `## Findings`. See the Full Report Skeleton below for the verbatim layout.

---

### Finding Entry Schema (### Finding F-NNN)

Each surviving finding becomes an `### Finding F-NNN` H3 block. `F-NNN` is zero-padded to 3 digits and sequential per report (`F-001`, `F-002`, ...). The 11 fields appear in this exact order:

1. **ID** — the `F-NNN` identifier matching the H3 heading.
2. **Severity** — one of CRITICAL, HIGH, MEDIUM, LOW (per `components/severity-levels.md`).
3. **Confidence** — one of HIGH, MEDIUM, LOW. HIGH = directly observable in code with a clear execution path; MEDIUM = strong evidence with some inferred assumptions; LOW = weak signal or incomplete evidence. LOW-confidence findings MUST explicitly state the uncertainty.
4. **Category** — one of: Correctness, Business Logic, Reliability, Concurrency, Performance, Operational Reliability, Operational Maintainability Risk, API Contract, Data Integrity, Security, Data Exposure.
5. **Rule** — the auditor's rule-id (e.g. `SEC-SQL-INJECTION`, `PERF-N+1`, `LOG-INVERTED-COND`, `DATA-PARTIAL-UPDATE`).
6. **Location** — `<path>:<start>-<end>` for a range, or `<path>:<line>` for a single point.
7. **Claim** — one-sentence statement of the alleged issue, ≤ 160 chars.
8. **Code** — verbatim ±10 lines around the flagged line, fenced with the language matching the source extension (see Verbatim Code Block section).
9. **Data flow** — markdown bullet list tracing input from origin to the flagged sink, ≤ 6 hops.
10. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from in Phase 15.
11. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

Field omission rules:

- **CRITICAL / HIGH** — all 11 fields required.
- **MEDIUM** — MAY omit Confidence, Data flow, and Suggested fix when they add no value.
- **LOW** — MAY collapse to ID + Severity + Confidence + Location + Claim + one-line evidence (the Code/Data flow/Why it is real/Suggested fix sections may be merged into the Claim).

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
| HIGH | 1 | 1 | 1 |

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
