# Code Review — Base Template

## Goal

Comprehensive code review of a web application. Act as a Senior Tech Lead.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for code review — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Expected |
| --- | ------- | ---------- |
| 1 | Syntax errors | None |
| 2 | Linter passes | No errors |
| 3 | Build succeeds | Success |
| 4 | Tests pass | All green |
| 5 | No debug code | No dd/dump/console.log |

---

## 0.1 PROJECT SPECIFICS — [Project Name]

**Accepted decisions (no need to fix):**

- [Intentional architectural decisions]

**Key files for review:**

- [Where business logic is]
- [Where controllers/routes are]
- [Where UI components are]

**Project patterns:**

- [Which patterns are used]

---

## 0.2 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Bug, security issue, data loss | **BLOCKER** — fix now |
| HIGH | Serious logic problem | Fix before merge |
| MEDIUM | Code smell, maintainability | Fix in this PR |
| LOW | Style, nice-to-have | Can defer |

---

## 1. SCOPE REVIEW

### 1.1 Define scope

- [ ] Which files are changed
- [ ] Which files are created
- [ ] Relationship between changes

### 1.2 Categorization

- [ ] Business logic changes
- [ ] UI changes
- [ ] Database changes
- [ ] Config changes

---

## 2. ARCHITECTURE & STRUCTURE

### 2.1 Single Responsibility

```text
Bad: Controller 300+ lines with all logic
Good: Controller coordinates, Service contains logic
```

- [ ] Files < 300 lines
- [ ] Methods < 20 lines
- [ ] One class/component — one responsibility

### 2.2 Dependency Injection

- [ ] Dependencies are injected, not created inside
- [ ] No static service calls

### 2.3 Proper Placement

- [ ] Files in correct directories
- [ ] No God-classes
- [ ] Logic in correct layer

---

## 3. CODE QUALITY

### 3.1 Naming

- [ ] Variables — nouns, camelCase
- [ ] Methods — verbs, camelCase
- [ ] Boolean — is/has/can/should prefix

### 3.2 Complexity

- [ ] Nesting < 3 levels
- [ ] Early returns are used
- [ ] Complex logic split into methods

### 3.3 DRY

- [ ] No copy-paste code
- [ ] Common logic extracted

### 3.4 Type Safety

- [ ] Types specified
- [ ] Nullable explicitly marked

---

## 4. ERROR HANDLING

### 4.1 Exceptions

- [ ] Specific exception types
- [ ] Logging with context
- [ ] No empty catch blocks

### 4.2 User-Facing

- [ ] Clear messages to user
- [ ] Technical details only in logs

---

## 5. DOCUMENTATION

### 5.1 Code Comments

- [ ] Public methods documented
- [ ] Comments explain "why", not "what"
- [ ] No commented-out code

### 5.2 Project Docs

- [ ] README updated if needed
- [ ] INDEX updated if needed

---

## 6. SECURITY & PERFORMANCE

### 6.1 Security Quick Check

- [ ] No SQL injection
- [ ] No XSS
- [ ] Authorization checked
- [ ] No debug code in production

### 6.2 Performance Quick Check

- [ ] No N+1 queries
- [ ] Pagination for lists
- [ ] Heavy operations async

---

## 7. SELF-CHECK

**DO NOT include in report:**

| Seems like a problem | Why it may not be |
| ------------------- | --------------------- |
| "No comments" | Code is self-documenting |
| "Long file" | If logically connected — OK |
| "Old code style" | If it works — not a problem |
| "Could be better" | Without specifics not actionable |

**Checklist:**

```text
Is this a REAL problem, not personal preference
Is there a SPECIFIC fix suggestion
Fix will NOT BREAK functionality
This is NOT an intentional design decision
```

---

## 8. REPORT FORMAT

```markdown
# Code Review Report — [Project]
Date: [date]
Scope: [files/commits]

## Summary

| Category | Issues | Critical |
|-----------|---------|-----------|
| Architecture | X | X |
| Code Quality | X | X |
| Security | X | X |
| Performance | X | X |

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|--------|----------|---------|
| 1 | file.ext | 45 | [Description] | [Solution] |

## Code Suggestions

### 1. [Title]
```language
// Before
[code]

// After
[code]
```

## Good Practices Found

- [What's good]

```text

---

## 9. ACTIONS

1. **Quick Check** — basic checks
2. **Define scope** — what to check
3. **Go through categories** — Architecture → Performance
4. **Self-check** — filter false positives
5. **Show fixes** — specific code before/after

Start review. Show scope and summary first.
