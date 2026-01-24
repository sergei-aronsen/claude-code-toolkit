# Severity Levels

Standard severity levels for audits and code review.

## Level Table

| Level | Emoji | Description | Action |
| ----- | ----- | ----------- | ------ |
| CRITICAL | [red] | Exploitable vulnerability, data loss, RCE | **BLOCKER** — fix immediately |
| HIGH | [orange] | Serious issue, requires auth or complex exploitation | Fix before merge/deploy |
| MEDIUM | [yellow] | Potential issue, low risk | Fix in next sprint |
| LOW | [blue] | Best practice, defense in depth | Backlog |
| INFO | [white] | Information, no action required | — |

## When to Use

### CRITICAL

- SQL Injection without auth
- Remote Code Execution
- Authentication bypass
- Sensitive data exposure (passwords, API keys)
- Data corruption/loss

### HIGH

- SQL Injection with auth required
- XSS in authenticated area
- CSRF on critical operations
- Missing authorization checks
- Insecure file upload

### MEDIUM

- Information disclosure (versions, stack traces)
- Missing rate limiting
- Weak password policy
- Clickjacking potential
- Missing security headers

### LOW

- Missing HSTS
- Verbose error messages (non-sensitive)
- Outdated dependencies (no CVE)
- Code style issues
- Documentation gaps

### INFO

- Informational findings
- Design decisions
- Recommendations for future
