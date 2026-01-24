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

| # | Check | Expected |
| --- | ------- | ---------- |
| 1 | Debug mode disabled | `false` in production |
| 2 | No hardcoded secrets in code | All keys in env |
| 3 | No SQL injection patterns | Parameterized queries |
| 4 | Dependency audit | No critical vulnerabilities |
| 5 | Auth on sensitive endpoints | All protected |

If all 5 = pass → Basic security level OK.

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

### 9.3 Configuration Cliffs

- [ ] One wrong config doesn't break all security?
- [ ] Typos in config values validated?
- [ ] Dangerous setting combinations checked?

```yaml
# Typo silently accepted
verify_ssl: fasle  # Should be "false", but accepted as truthy?
```

### 9.4 Stringly-Typed Security

- [ ] Permissions not strings ("read,write,admin")?
- [ ] Roles are enum, not arbitrary strings?
- [ ] URLs not built by concatenation?

---

## 10. SELF-CHECK

**Before adding vulnerability to report:**

| Question | If "no" → reconsider severity |
| -------- | ---------------------------------- |
| Is this **exploitable** in real conditions? | Theoretical ≠ real threat |
| Is there an **attack path** for attacker? | Internal-only ≠ CRITICAL |
| **What damage** on successful attack? | Public data leak ≠ password leak |
| Is **auth** required for exploitation? | Auth-required lowers severity |

---

## 11. REPORT FORMAT

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

## 12. ACTIONS

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
