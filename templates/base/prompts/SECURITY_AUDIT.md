# Security Audit — Base Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive security audit of a web application. Act as a Senior Security Engineer / Penetration Tester.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for audits — works better with code analysis.

---

## PRINCIPLE: CONTEXT BEFORE VULNERABILITIES

**First understand the code, then look for bugs.**

Phase 1 (understanding) → Phase 2 (finding vulnerabilities) → Phase 3 (report)

**Rationalizations (DO NOT skip!):**

| Excuse | Why it's wrong | Action |
|-----------|-------------------|----------|
| "I get the gist" | Gist misses edge cases | Line-by-line analysis |
| "This function is simple" | Simple composes into complex bugs | Analyze anyway |
| "This is taking too long" | Rushed = hallucinated vulns | Slow is fast |
| "Small PR, quick review" | Heartbleed was 2 lines | Classify by RISK, not size |
| "Just a refactor" | Refactors break invariants | Analyze as HIGH until proven LOW |

---

## 📊 CODEBASE SIZE STRATEGY

| Size | Strategy | Approach |
|------|----------|----------|
| **SMALL** (<20 files) | DEEP | Read everything, full git blame |
| **MEDIUM** (20-200) | FOCUSED | 1-hop deps, priority files |
| **LARGE** (200+) | SURGICAL | Only critical paths |

---

## 🎯 RISK LEVEL TRIGGERS

| Risk | Triggers | Action |
|------|----------|--------|
| **HIGH** | Auth, crypto, external calls, validation removal, value transfer | Full analysis + adversarial |
| **MEDIUM** | Business logic, state changes, new public APIs | Standard analysis |
| **LOW** | Comments, tests, UI, logging | Surface scan |

**Red Flags (immediate escalation):**

- Removed code from "security" or "fix" commits
- Access control modifiers removed (`private` → `public`)
- Validation removed without replacement
- External calls added without checks

---

## 0. QUICK CHECK (5 minutes)

**Before full audit — go through these critical points:**

| # | Check | How to verify | Expected |
| --- | ------- | ------------- | ---------- |
| 1 | Debug mode disabled | Check production config | `false` in production |
| 2 | No hardcoded secrets in code | `grep -rn` for keys/passwords | All keys in env |
| 3 | No SQL injection patterns | Review query construction | Parameterized queries |
| 4 | Dependency audit | Run package audit | No critical vulnerabilities |
| 5 | Auth on sensitive endpoints | Review route middleware | All protected |
| 6 | .env public access | Verify `.env` is not web-accessible | Not accessible |
| 7 | Secret key | Verify app secret key is set and strong | >= 32 characters |
| 8 | Open redirect | `grep -rn "redirect.*request\|redirect.*params\|redirect.*url" src/` | Check validation |

If all checks pass → Basic security level OK.

### Auto-Check Script

```bash
#!/bin/bash
echo "=== Security Quick Check ==="

# 8. .env exposure
[ ! -f public/.env ] && echo "✅ .env: Not in public/" || echo "❌ .env: Exposed in public/!"

# 9. Open redirect patterns
REDIRECT=$(grep -rn "redirect.*req\.\|redirect.*params\.\|redirect.*url" src/ 2>/dev/null | grep -v "test\|spec")
[ -z "$REDIRECT" ] && echo "✅ Redirect: No open redirect patterns" || echo "🟡 Redirect: Found redirect patterns (verify validation)"

# 10. Command injection
CMD=$(grep -rn "exec(\|system(\|spawn(" src/ 2>/dev/null | grep -v "node_modules\|test\|spec")
[ -z "$CMD" ] && echo "✅ Commands: No dangerous exec/system" || echo "🟡 Commands: Found exec/system calls (verify input)"

# 11. Deserialization patterns
DESER=$(grep -rn "deserialize\|unserialize\|pickle\.load\|Marshal\.load\|yaml\.load\|eval(" src/ 2>/dev/null | grep -v "test\|spec\|node_modules")
[ -z "$DESER" ] && echo "✅ Deserialization: No unsafe patterns" || echo "🟡 Deserialization: Found patterns (verify input source)"

echo "Done!"
```

---

## 0.1 PROJECT SPECIFICS — [Project Name]

**Fill out before audit:**

**Already implemented:**

- [ ] Authentication mechanism: [which]
- [ ] Authorization: [policies/middleware/etc]
- [ ] Input validation: [where]
- [ ] CSRF protection: [how]

**Public endpoints (by design):**

- `/api/health` — health check
- `/webhooks/*` — webhooks (verify signature!)

**Known specifics:**

- [Project-specific notes]

---

## 0.2 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Exploitable vulnerability: SQLi, RCE, auth bypass | **BLOCKER** — fix immediately |
| HIGH | Serious vulnerability, requires auth or complex exploitation | Fix before deploy |
| MEDIUM | Potential vulnerability, low risk | Fix in next sprint |
| LOW | Best practice, defense in depth | Backlog |
| INFO | Information, no action required | — |

---

## 1. INJECTION ATTACKS

### 1.1 SQL Injection

- [ ] All queries use parameterization
- [ ] No user input concatenation in SQL
- [ ] Dynamic column/table names through whitelist

### 1.2 Command Injection

- [ ] No direct execution of user commands
- [ ] Whitelist of allowed commands
- [ ] Arguments are sanitized

### 1.3 XSS (Cross-Site Scripting)

- [ ] User input is escaped on output
- [ ] No unsafe HTML rendering without sanitization
- [ ] CSP headers configured

---

## 2. AUTHENTICATION

### 2.1 Password Security

- [ ] Passwords are hashed (bcrypt/argon2)
- [ ] Minimum 10 rounds for bcrypt
- [ ] No plain text passwords

### 2.2 Session Security

- [ ] Secure cookies in production
- [ ] HttpOnly cookies
- [ ] SameSite policy

### 2.3 Rate Limiting

- [ ] Login endpoint has rate limiting
- [ ] Password reset has rate limiting
- [ ] API endpoints have rate limiting

---

## 3. AUTHORIZATION

### 3.1 Access Control

- [ ] All protected routes require auth
- [ ] Ownership check on update/delete
- [ ] No IDOR (Insecure Direct Object Reference)

### 3.2 Role-Based Access

- [ ] Roles checked on server-side
- [ ] Admin routes additionally protected
- [ ] No privilege escalation

---

## 4. DATA PROTECTION

### 4.1 Sensitive Data

- [ ] Secrets only in env, not in code
- [ ] Debug mode disabled in production
- [ ] Passwords/keys not logged

### 4.2 Error Handling

- [ ] User doesn't see stack traces
- [ ] User doesn't see SQL errors
- [ ] Detailed errors only in logs

### 4.3 HTTPS

- [ ] HTTPS required in production
- [ ] HTTP redirects to HTTPS
- [ ] HSTS header

---

## 5. FILE HANDLING

### 5.1 File Upload

- [ ] File type validated (not just extension)
- [ ] File size limited
- [ ] Filename generated (not user-provided)

### 5.2 Path Traversal

- [ ] No `../` in user paths
- [ ] Paths are sanitized
- [ ] Check that path is in allowed directory

### 5.3 Session Timeout

Sessions that never expire increase the window for session hijacking.

- [ ] Session timeout is configured (recommended: 15-30 minutes for sensitive apps)
- [ ] Idle session timeout is configured
- [ ] Session is invalidated on logout

---

## 6. API SECURITY

### 6.1 CORS

- [ ] `allowed_origins` — specific domains, not `*`
- [ ] Credentials configured properly

### 6.2 Rate Limiting

- [ ] All API endpoints have rate limiting
- [ ] Rate limit by user, not just by IP

### 6.3 Response Filtering

- [ ] Sensitive fields not returned
- [ ] API Resources/DTOs used

---

## 7. DEPENDENCIES

### 7.1 Audit

- [ ] Package manager audit without critical/high
- [ ] Dependencies updated

---

## 8. SECURITY HEADERS

- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options: DENY or SAMEORIGIN
- [ ] X-XSS-Protection: 1; mode=block
- [ ] Referrer-Policy: strict-origin-when-cross-origin
- [ ] Content-Security-Policy (if applicable)

### 8.1 HSTS (HTTP Strict Transport Security)

Without HSTS, users can be downgraded from HTTPS to HTTP via man-in-the-middle.

```text
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

- [ ] HSTS header is set in production
- [ ] `max-age` >= 31536000 (1 year)
- [ ] `includeSubDomains` is set if subdomains also use HTTPS

---

## 9. SHARP EDGES (API Footguns)

**"Pit of success":** Secure usage should be the path of least resistance.

### 9.1 Dangerous Defaults

- [ ] What happens with `timeout=0`? `max_attempts=0`? `key=""`?
- [ ] Default values are safe?
- [ ] Empty/null values don't disable security?

```php
// Dangerous: 0 can mean "infinite" or "disabled"
function verify_otp($code, $lifetime = 300) {
    if ($lifetime == 0) return true; // OOPS
}
```

### 9.2 Silent Failures

- [ ] Security functions throw exceptions, not return false?
- [ ] No empty catch blocks for security operations?
- [ ] Verification doesn't "succeed" on malformed input?

```php
// Silent bypass
function verify_signature($sig, $data, $key) {
    if (!$key) return true; // No key = skip verification?!
}
```

### 9.3 Secret Key Validation

Application secret key must be strong and unique per environment.

- [ ] Secret key is at least 32 characters
- [ ] Secret key is not a default value (`secret`, `changeme`, `password`)
- [ ] Secret key is different across environments (dev/staging/production)
- [ ] Secret key is loaded from environment variable, not hardcoded

### 9.4 .env Public Access

`.env` files accessible via web expose all secrets.

- [ ] `.env` is not in web-accessible directory (public/, static/, www/)
- [ ] Web server blocks access to dotfiles (`.env`, `.git/`)
- [ ] Verify: `curl -s https://yoursite.com/.env` returns 403/404

### 9.5 File Permissions

Incorrect file permissions expose sensitive data or allow unauthorized modification.

- [ ] Configuration files are not world-readable (`chmod 640` or stricter)
- [ ] Log directory is not world-writable
- [ ] Upload directory does not allow script execution
- [ ] `.env` file permissions: `600` or `640`

### 9.6 Configuration Cliffs

- [ ] One wrong config doesn't break all security?
- [ ] Typos in config values validated?
- [ ] Dangerous setting combinations checked?

```yaml
# Typo silently accepted
verify_ssl: fasle  # Should be "false", but accepted as truthy?
```

### 9.7 Stringly-Typed Security

- [ ] Permissions not strings ("read,write,admin")?
- [ ] Roles are enum, not arbitrary strings?
- [ ] URLs not built by concatenation?

---

## 10. INJECTION ATTACKS

### 10.1 Open Redirection

Redirecting users to unvalidated URLs enables phishing attacks.

```text
# ❌ Dangerous — redirect to user-supplied URL
redirect(request.params.url)
redirect(request.query.returnUrl)

# ✅ Safe — whitelist or relative-only
# Validate URL is relative or belongs to allowed domain
```

- [ ] No redirects using raw user input
- [ ] Redirect URLs are validated against a whitelist or restricted to relative paths
- [ ] External URLs require explicit allow-list

### 10.2 Host Injection

If the application trusts the HTTP Host header without validation, attackers can inject malicious hosts for password reset links, cache poisoning, etc.

- [ ] Application validates or restricts allowed Host values
- [ ] Password reset and email links use a configured base URL, not the Host header
- [ ] Web server or proxy normalizes the Host header

### 10.3 Unsafe Deserialization

Deserializing untrusted data can lead to remote code execution.

```text
# ❌ Dangerous — deserializing user-controlled data
deserialize(user_input)
load(user_data)

# ✅ Safe — use data-only formats
JSON.parse(user_input)  # No code execution
```

- [ ] No deserialization of untrusted input (user data, cookies, queue payloads)
- [ ] If deserialization is needed, use safe formats (JSON, MessagePack)
- [ ] Deserialization libraries are updated to latest versions

### 10.4 Dangerous Functions

Some built-in functions allow arbitrary code execution and should never receive user input.

- [ ] No `eval()` or equivalent with user input
- [ ] No dynamic code execution (`exec`, `system`, `spawn`) with user-controlled arguments
- [ ] If shell commands are needed, arguments are escaped/whitelisted
- [ ] No dynamic method/function calls based on user input

### 10.5 SSRF (Server-Side Request Forgery)

If the application fetches URLs provided by users, attackers can target internal services, cloud metadata endpoints, or private networks.

```text
# ❌ Dangerous — fetching user-provided URL without validation
fetch(userUrl)
httpClient.get(userUrl)

# ✅ Safe — validate URL before fetching
# Check protocol (http/https only)
# Block internal IPs (127.0.0.1, 10.*, 172.16.*, 192.168.*, 169.254.169.254)
# Set request timeouts
```

- [ ] URLs from user input are validated before fetching
- [ ] Internal/private IP ranges are blocked (127.0.0.1, 10.*, 172.16-31.*, 192.168.*)
- [ ] Only http/https protocols allowed
- [ ] Cloud metadata endpoints blocked (169.254.169.254, fd00:ec2::254)
- [ ] Request timeouts are set

---

## 11. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

---

## 12. REPORT FORMAT

Create file `.claude/reports/SECURITY_AUDIT_[DATE].md`:

```markdown
# Security Audit Report — [Project Name]
Date: [date]
Auditor: Claude (Senior Security Engineer)

## Executive Summary

| Severity | Count | Status |
|----------|-------|--------|
| Critical | X | X fixed |
| High | X | X fixed |
| Medium | X | X fixed |
| Low | X | - |

**Overall Risk Level**: [Critical/High/Medium/Low]

## Critical Vulnerabilities
[Details...]

## High Severity Issues
[Details...]

## Security Controls in Place
[What's already good...]

## Remediation Checklist
[What to fix...]
```

---

## 13. ACTIONS

## 14. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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

1. **Define strategy** — SMALL/MEDIUM/LARGE codebase
2. **Quick Check** — go through 5 critical points
3. **Context** — understand architecture BEFORE finding bugs
4. **Scan** — go through all sections by Risk Level
5. **Sharp Edges** — check API footguns
6. **Classify** — Critical → Low
7. **Self-check** — filter false positives
8. **Document** — file, line, code
9. **Fix** — suggest specific fix

Start audit. First Quick Check, then Executive Summary.

---

*Inspired by [Trail of Bits Security Skills](https://github.com/trailofbits/skills)*

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
