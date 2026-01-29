# Security Audit — Base Template

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

---

## 11. SELF-CHECK

**Before adding vulnerability to report:**

| Question | If "no" → reconsider severity |
| -------- | ---------------------------------- |
| Is this **exploitable** in real conditions? | Theoretical ≠ real threat |
| Is there an **attack path** for attacker? | Internal-only ≠ CRITICAL |
| **What damage** on successful attack? | Public data leak ≠ password leak |
| Is **auth** required for exploitation? | Auth-required lowers severity |

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
