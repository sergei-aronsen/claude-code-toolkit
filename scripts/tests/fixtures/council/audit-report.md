---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 3
skipped_allowlist: 0
skipped_fp_recheck: 0
council_pass: pending
---

<!-- TEST FIXTURE — scripts/tests/fixtures/council/audit-report.md
     3-finding sample audit report for Council audit-review regression tests.
     Findings are DELIBERATELY designed to exercise three verdict outcomes:
       F-001: agreement REAL (SQL injection — obvious, both stubs agree)
       F-002: agreement FALSE_POSITIVE (eval gated by isBuildTime() — both stubs agree)
       F-003: disputed (innerHTML — stub-gemini=REAL, stub-chatgpt=FALSE_POSITIVE)
     Do NOT "fix" the vulnerable code patterns in the embedded code blocks.
     They are fixtures; they document intent via their leading comment lines. -->

# Security Audit — council-fixture-project

## Summary

| severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck |
|----------|----------------|-------------------------|--------------------------|
| HIGH | 2 | 0 | 0 |
| MEDIUM | 1 | 0 | 0 |

## Findings

### Finding F-001

- **ID:** F-001
- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/auth.ts:14
- **Claim:** User-supplied id is concatenated into a SQL string and passed to db.query without parameterized binding.

**Code:**

<!-- File: src/auth.ts Lines: 4-24 -->

```ts
// FIXTURE — deliberate SQL string concat for audit testing; do not "fix"
import express from "express";

const app = express();
const db = { query: (sql: string, params?: unknown[]) => sql };

// Deliberately-vulnerable route: user-supplied id flows into a
// string-concatenated SQL query without parameterization (SEC-SQL-INJECTION).
app.get("/users/:id", (req, res) => {
  const id = req.params.id;
  const sql = "SELECT * FROM users WHERE id=" + id;
  const result = db.query(sql);
  res.json({ data: result });
});

// Harmless health-check route.
app.get("/healthz", (_req, res) => {
  res.json({ status: "ok" });
});

export { app };
```

**Data flow:**

- `req.params.id` arrives from the Express route handler at `src/auth.ts:14`.
- Assigned to `id` with no sanitization or validation.
- Concatenated via `+` operator into the SQL string `"SELECT * FROM users WHERE id=" + id`.
- The constructed string is passed directly to `db.query(sql)` at `src/auth.ts:16`.
- No parameterized binding exists between HTTP origin and database sink.

**Why it is real:**

The literal `"SELECT * FROM users WHERE id=" + id` at `src/auth.ts:15` concatenates
`req.params.id` directly into the SQL string. No parameterized query or escaping step exists
between the route handler and `db.query`. The route is public (`app.get`), so any unauthenticated
request can supply a malicious id value and reach the sink.

**Suggested fix:**

```ts
const sql = "SELECT * FROM users WHERE id = ?";
db.query(sql, [id]);
```

### Finding F-002

- **ID:** F-002
- **Severity:** HIGH
- **Rule:** SEC-EVAL
- **Location:** scripts/build.js:42
- **Claim:** Dynamic code construction via Function constructor is called at scripts/build.js:42; guard isBuildTime() makes it unreachable at request time.

**Code:**

<!-- File: scripts/build.js Lines: 32-52 -->

```js
// FIXTURE — build-time-only dynamic eval; never reached at request time
function isBuildTime() {
  return process.env.BUILD === "1";
}

function generateConfig(spec) {
  if (isBuildTime()) {
    // Build-time codegen: spec is a literal from build-manifest.json (read at build time only).
    // SEC-EVAL: Function(spec) is intentional here — build-time only, unreachable at runtime.
    var fn = Function(spec); // noqa: S-eval
    return fn();
  }
  return JSON.parse(spec);
}

function getDefaults() {
  return { version: "1.0", env: process.env.NODE_ENV || "development" };
}

module.exports = { generateConfig, getDefaults };
```

**Data flow:**

- `spec` parameter flows from build script callers at build time only.
- All callers pass literals read from `build-manifest.json` at startup; no runtime user input flows here.
- `isBuildTime()` returns `true` only when `process.env.BUILD === "1"` — a condition set by the build runner, never by request handlers.
- At request time `isBuildTime()` is `false` and the `Function(spec)` branch is never entered.

**Why it is real:**

The `Function(spec)` constructor at `scripts/build.js:41` constructs and runs arbitrary JavaScript.
Although the `isBuildTime()` guard prevents runtime execution, the SEC-EVAL rule flags the pattern
as a candidate for review. The code comment and the `JSON.parse(spec)` fallback branch document
the intent. This finding is a false positive given the verified guard.

**Suggested fix:**

```js
// Replace dynamic code construction with a JSON-driven config interpreter:
function generateConfig(spec) {
  const config = JSON.parse(spec);
  return config;
}
```

### Finding F-003

- **ID:** F-003
- **Severity:** MEDIUM
- **Rule:** SEC-XSS
- **Location:** src/render.ts:88
- **Claim:** bio is assigned to innerHTML at src/render.ts:90 without an explicit sanitizeHtml call at the assignment site; upstream sanitization is documented by comment only.

**Code:**

<!-- File: src/render.ts Lines: 78-98 -->

```ts
// FIXTURE — disputed innerHTML assignment; sanitization is ambiguous (see F-003 in audit)
import { sanitizeHtml } from "./sanitize";

interface User {
  displayName: string;
  bio: string;
}

function renderUserCard(user: User): void {
  const header = document.createElement("h2");
  const bio = document.createElement("p");

  // displayName is explicitly sanitized before innerHTML assignment.
  const safeName = sanitizeHtml(user.displayName);
  header.innerHTML = safeName;

  // bio assignment: sanitizeHtml applied at API boundary per architecture doc.
  // However no explicit sanitizeHtml() call is present at this site.
  bio.innerHTML = user.bio; // SEC-XSS candidate
}

export { renderUserCard };
```

**Data flow:**

- `user.displayName`: flows from the API response → `sanitizeHtml(user.displayName)` → `safeName`
  → `header.innerHTML = safeName` (explicitly sanitized).
- `user.bio`: flows from the API response → `user.bio` → `bio.innerHTML = user.bio` (sanitization
  documented upstream via architecture comment; no explicit call at assignment site).

**Why it is real:**

The `header.innerHTML = safeName` assignment at `src/render.ts:92` is safe — `safeName` is the
explicit output of `sanitizeHtml()`. However, `bio.innerHTML = user.bio` at `src/render.ts:95`
assigns the raw `user.bio` string without a visible sanitizeHtml call at the assignment site. The
comment claims upstream sanitization but that claim is unverifiable from this file alone. The
ambiguity between explicit and implicit sanitization makes this a disputable finding.

**Suggested fix:**

```ts
// Option A — explicit sanitization at the assignment site:
bio.innerHTML = sanitizeHtml(user.bio);

// Option B — avoid innerHTML for text-only content:
header.textContent = user.displayName;
bio.textContent = user.bio;
```

## Skipped (allowlist)

_None — no `audit-exceptions.md` in this project_

## Skipped (FP recheck)

_None_

## Council verdict

_pending — run /council audit-review_
