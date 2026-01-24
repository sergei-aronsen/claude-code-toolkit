# Report Format

Standard report format for audits.

---

## Security Audit Report

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
| Info | X | - |

**Overall Risk Level**: [Critical/High/Medium/Low]

---

## Critical Vulnerabilities

### CRIT-001: [Title]
**Location**: `path/to/file.ext:XX`
**CVSS Score**: X.X (if applicable)
**Description**: [Vulnerability description]
**Impact**: [What damage can be done]
**Proof of Concept**: [How to reproduce]
**Remediation**: [How to fix]
**Status**: Fixed / Pending

---

## High Severity Issues
[Similar format]

## Medium Severity Issues
[Similar format]

## Low Severity Issues
[Brief list]

## Informational
[Brief list]

---

## Security Controls in Place

- [x] [What is already implemented]
- [x] [What is already implemented]
- [ ] [What is recommended to add]

---

## Remediation Checklist

### Immediate (24h)
- [ ] [Critical fixes]

### Short-term (1 week)
- [ ] [Important fixes]

### Long-term (1 month)
- [ ] [Improvements]
```

---

## Code Review Report

```markdown
# Code Review Report — [Project Name]
Date: [date]
Scope: [which files/commits were reviewed]

## Summary

| Category | Issues | Critical |
|----------|--------|----------|
| Architecture | X | X |
| Code Quality | X | X |
| [Framework] | X | X |
| Security | X | X |
| Performance | X | X |

---

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|------|-------|----------|
| 1 | file.ext | 45 | [Description] | [Solution] |

## HIGH Priority
[Similar format]

## MEDIUM Priority
[Similar format]

---

## Good Practices Found

- [What was done well]

---

## Code Suggestions

### 1. [Change name]

```language
// Before (path/to/file.ext:XX-YY)
[old code]

// After
[new code]
```

---

## Checklist for Author

- [ ] Fix critical issues
- [ ] Update documentation
- [ ] Run tests

```text

---

## Deploy Checklist Report

```markdown
# Deploy Checklist Report — [Project Name]
Date: [date]
Version: [git commit hash]
Deployed by: [who]

## Summary

| Step | Status | Duration |
|------|--------|----------|
| Pre-checks | Pass/Fail | X min |
| Backup | Pass/Fail | X min |
| Code deploy | Pass/Fail | X min |
| Migrations | Pass/Fail | X min |
| Build | Pass/Fail | X min |
| Cache | Pass/Fail | X min |
| Verification | Pass/Fail | X min |
| **Total** | **Pass/Fail** | **X min** |

## Readiness Score

**Score**: XX% — [READY / ACCEPTABLE / NOT READY]

### Blockers
- [If any]

### Warnings
- [If any]

### Passed
- [List of passed checks]

---

## Changes Deployed

### Features
- [New features]

### Fixes
- [Bug fixes]

### Migrations
- [Database migrations]

---

## Verification Results

| Check | Result |
|-------|--------|
| Homepage loads | Pass/Fail |
| Login works | Pass/Fail |
| Core functionality | Pass/Fail |
| Error rate | X% |

---

## Post-Deploy Tasks

- [ ] Monitor error rate for 24h
- [ ] Check queue processing
- [ ] Notify stakeholders
```
