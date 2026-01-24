# /verify — Run Verification Checks

## Purpose

Quick automated verification before PR or commit: build, types, lint, tests.

---

## Usage

```text
/verify [mode]
```

**Modes:**

- `quick` — Build + types only (fast)
- `full` — All checks (default)
- `pre-commit` — Checks for commit
- `pre-pr` — Full checks + security scan

**Examples:**

- `/verify` — Full verification
- `/verify quick` — Quick verification
- `/verify pre-pr` — Before creating PR

---

## Verification Phases

### Phase 1: Build Check

```bash
# Node.js / Next.js
npm run build 2>&1 | tail -20
# or
pnpm build 2>&1 | tail -20

# Laravel
php artisan config:cache
php artisan route:cache
```

**If build fails — STOP and fix before continuing.**

### Phase 2: Type Check

```bash
# TypeScript
npx tsc --noEmit 2>&1 | head -30

# PHP (with PHPStan)
./vendor/bin/phpstan analyse --memory-limit=512M 2>&1 | head -30
```

### Phase 3: Lint Check

```bash
# JavaScript/TypeScript
npm run lint 2>&1 | head -30

# PHP
./vendor/bin/pint --test 2>&1 | head -30
```

### Phase 4: Test Suite

```bash
# Node.js
npm run test -- --coverage 2>&1 | tail -50

# Laravel
php artisan test --coverage 2>&1 | tail -50
```

**Target coverage:** 80% minimum

### Phase 5: Security Scan (pre-pr only)

```bash
# Check for secrets
grep -rn "sk-\|api_key\|password.*=" src/ app/ --include="*.ts" --include="*.php" 2>/dev/null | head -10

# Check for console.log / dd()
grep -rn "console\.log\|dd(" src/ app/ --include="*.ts" --include="*.tsx" --include="*.php" 2>/dev/null | head -10
```

### Phase 6: Git Status

```bash
git status --short
git diff --stat HEAD~1
```

---

## Output Format

```text
VERIFICATION REPORT
===================

Build:     [PASS/FAIL]
Types:     [PASS/FAIL] (X errors)
Lint:      [PASS/FAIL] (X warnings)
Tests:     [PASS/FAIL] (X/Y passed, Z% coverage)
Security:  [PASS/FAIL] (X issues)
Git:       [X files changed]

─────────────────────
Overall:   [READY/NOT READY] for PR

Issues to Fix:
1. [Issue description + file:line]
2. [Issue description + file:line]
```

---

## Difference from /audit

| Aspect | /verify | /audit |
|--------|---------|--------|
| What it does | Runs commands | Claude analyzes code |
| Speed | Fast (bash) | Slow (reads files) |
| Depth | Pass/fail | Finds logical errors |
| When | Before each PR | On request, for review |

**Use both:**

1. `/verify` — before commit (does everything build?)
2. `/audit` — before merge (is code quality good?)

---

## When to Run

| Situation | Command |
|-----------|---------|
| Finished a feature | `/verify` |
| Before commit | `/verify pre-commit` |
| Before creating PR | `/verify pre-pr` |
| After refactoring | `/verify` |
| Want deep analysis | `/audit code` |

---

## Framework Detection

Automatically detects commands:

| File | Framework | Build | Test |
|------|-----------|-------|------|
| `artisan` | Laravel | `config:cache` | `php artisan test` |
| `next.config.*` | Next.js | `npm run build` | `npm test` |
| `package.json` | Node.js | `npm run build` | `npm test` |

---

## Actions

1. Detect project framework
2. Run checks according to mode
3. Collect results from each phase
4. Generate report in the format above
5. Specify concrete issues to fix
