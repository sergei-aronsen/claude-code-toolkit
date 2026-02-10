# Report Format

Standard report format for audits. All reports follow the same base structure with type-specific sections.

---

## Generic Report Template

```markdown
# [Report Type] — [Project Name]
Date: [date]
[Additional metadata — see type-specific fields below]

## Summary

[Summary table — format varies by type]

---

## Issues by Severity

### CRITICAL
| # | Location | Issue | Solution | Status |
|---|----------|-------|----------|--------|
| 1 | file:line | [Description] | [Solution] | Fixed/Pending |

### HIGH
[Same table format]

### MEDIUM / LOW
[Brief list]

---

## Checklist

### Immediate (24h)
- [ ] [Critical items]

### Short-term (1 week)
- [ ] [Important items]

### Long-term (1 month)
- [ ] [Improvements]
```

---

## Type-Specific Differences

### Security Audit

- **Metadata:** `Auditor: Claude (Senior Security Engineer)`
- **Summary table columns:** Severity | Count | Status
- **Add field per issue:** `CVSS Score`, `Impact`, `Proof of Concept`
- **Extra section:** "Security Controls in Place" (checklist of existing and recommended controls)
- **Overall Risk Level:** Critical / High / Medium / Low

### Code Review

- **Metadata:** `Scope: [files/commits reviewed]`
- **Summary table columns:** Category (Architecture, Code Quality, Security, Performance) | Issues | Critical
- **Extra section:** "Good Practices Found" (what was done well)
- **Extra section:** "Code Suggestions" with before/after code snippets

### Deploy Checklist

- **Metadata:** `Version: [git hash]`, `Deployed by: [who]`
- **Summary table columns:** Step (Pre-checks, Backup, Deploy, Migrations, Build, Cache, Verification) | Status | Duration
- **Extra section:** "Readiness Score" (XX% - READY / ACCEPTABLE / NOT READY)
- **Extra section:** "Changes Deployed" (Features, Fixes, Migrations)
- **Extra section:** "Verification Results" (Homepage loads, Login works, Error rate)
- **Post-Deploy Tasks:** Monitor error rate 24h, check queues, notify stakeholders
