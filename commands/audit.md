# /audit — Run Project Audit

## Purpose

Run a comprehensive audit of the project (security, performance, code review, or deploy checklist).

---

## Usage

```text
/audit <type> [scope]
```text

**Types:**

- `security` — Security vulnerabilities check
- `performance` — Performance optimization check
- `code` — Code quality review
- `deploy` — Pre-deployment checklist
- `full` — All audits combined

**Scope (optional):**

- File path or directory to focus on
- Default: entire project

**Examples:**

- `/audit security` — Full security audit
- `/audit performance app/Services/` — Performance audit of Services
- `/audit code app/Http/Controllers/` — Code review of Controllers
- `/audit deploy` — Pre-deployment checklist
- `/audit full` — Complete project audit

---

## Quick Checks

### Security (30 seconds)

```bash
# SQL Injection
grep -rn "\$request->.*->where.*raw\|DB::raw" app/ --include="*.php"

# XSS
grep -rn "{!!\|dangerouslySetInnerHTML" resources/ app/ --include="*.php" --include="*.tsx"

# Secrets in code
grep -rn "password\|secret\|key.*=.*['\"]" app/ lib/ src/ --include="*.php" --include="*.ts"
```text

### Performance (30 seconds)

```bash
# N+1 queries (Laravel)
grep -rn "->get().*foreach\|@foreach.*->load" app/ resources/ --include="*.php" --include="*.blade.php"

# Missing indexes
grep -rn "->where\|->whereHas" app/ --include="*.php" | head -20

# Bundle size (Next.js)
npm run build 2>&1 | grep -A 5 "First Load JS"
```text

### Code Quality (30 seconds)

```bash
# Debug code
grep -rn "dd(\|dump(\|console.log\|debugger" app/ src/ resources/

# TODO/FIXME
grep -rn "TODO\|FIXME" app/ src/ lib/

# Large files
find app src lib -name "*.php" -o -name "*.ts" -o -name "*.tsx" | xargs wc -l | sort -rn | head -10
```text

---

## Audit Workflow

### 1. Quick Check

Run automated checks (30 seconds to 2 minutes)

### 2. Deep Analysis

Review flagged items manually

### 3. Report

Generate findings with severity levels

### 4. Self-Check

Filter false positives (refer to SELF-CHECK section in templates)

---

## Output Format

```markdown
# [Type] Audit Report — [Project Name]
Date: [date]
Scope: [files/directories audited]

## Summary

| Category | Issues | Critical |
|----------|--------|----------|
| [Category] | X | X |

**Readiness:** XX% — [READY/ACCEPTABLE/NOT READY]

## CRITICAL Issues
[List with file:line, problem, solution]

## HIGH Issues
[List]

## MEDIUM Issues
[List]

## Recommendations
[Prioritized action items]
```text

---

## Framework Detection

Automatically detect framework and use appropriate template:

| File | Framework | Template |
|------|-----------|----------|
| `artisan` | Laravel | templates/laravel/ |
| `next.config.*` | Next.js | templates/nextjs/ |
| `package.json` only | Node.js | templates/base/ |
| Other | Generic | templates/base/ |

---

## Actions

1. Detect project framework
2. Run quick checks for the audit type
3. Analyze findings with appropriate template
4. Apply self-check filter (remove false positives)
5. Generate report with severity levels
