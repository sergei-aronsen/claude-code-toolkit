# /refactor — Refactor Code

## Purpose

Improve code structure without changing functionality.

---

## Usage

```text
/refactor <target> [--type=extract|simplify|rename|pattern]
```

**Examples:**

- `/refactor UserController` — General refactoring
- `/refactor this function --type=extract` — Extract methods
- `/refactor OrderService --type=pattern` — Apply design pattern
- `/refactor --type=simplify` — Simplify complex code

---

## Refactoring Types

| Type | When to Use | Goal |
|------|-------------|------|
| Extract | Long methods, duplicated code | Smaller, reusable units |
| Simplify | Complex conditionals, deep nesting | Readable code |
| Rename | Unclear names | Self-documenting code |
| Pattern | Common problems | Proven solutions |

---

## Common Refactorings

### 1. Extract Method

**Before:** Long method with inline validation + calculation + save.
**After:** Three focused methods -- `validateOrder()`, `calculateTotal()`, and the orchestrating `processOrder()` that calls them sequentially.

### 2. Simplify Conditionals

**Before:** Deeply nested if/else checking premium status, order total, and item count.
**After:** Early returns for simple cases, flat structure. Non-premium handled first, then threshold checks.

---

## Refactoring Checklist

- [ ] Tests exist and pass before starting
- [ ] Understand what the code does
- [ ] Small steps -- commit after each change, run tests frequently
- [ ] No functionality changes -- only structure
- [ ] All tests still pass after completion

---

## Output Format

```markdown
## Refactoring: [target]

### Problem
[What's wrong with current code]

### Solution
[Approach] — Before/After code comparison

### Changes Summary
[List of extractions, simplifications, renames]

### Verification
Tests pass, functionality unchanged, code is cleaner
```

---

## Actions

1. Understand current code behavior
2. Identify code smells
3. Choose appropriate refactoring
4. Apply in small steps
5. Verify tests pass after each step
6. Show before/after comparison
