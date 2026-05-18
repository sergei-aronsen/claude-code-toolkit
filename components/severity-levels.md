# Severity Levels

Short reference card for audit report Summary tables.

**This file is the table reference cited by the spliced output-format
Summary blocks (`templates/base/prompts/*.md` `## OUTPUT FORMAT`), not
a second labels source.** The canonical labels + Severity Ceiling
Table live in `components/audit-severity-anchor.md` (Wave-3 CODE_REVIEW
F-005 reconcile, v6.32.0). When in doubt about how to label a finding,
go to the anchor; this card just lists the four reportable levels for
output formatting.

## Level Table

| Level | Emoji | Description | Action |
| ----- | ----- | ----------- | ------ |
| CRITICAL | [red] | Exploitable vulnerability, data loss, RCE | **BLOCKER** — fix immediately |
| HIGH | [orange] | Serious issue, requires auth or complex exploitation | Fix before merge/deploy |
| MEDIUM | [yellow] | Potential issue, low risk | Fix in next sprint |
| LOW | [blue] | Best practice, defense in depth | Backlog |

INFO is NOT a reportable finding severity. Informational
observations belong in the audit report's `## Summary` prose or in
follow-up audits — never in `## Findings`. See
`components/audit-output-format.md` for the canonical rule.

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
