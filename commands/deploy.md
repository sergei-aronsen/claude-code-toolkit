# /deploy — Safe Deployment Workflow

## Purpose

Guided deployment with safety checks, verification, and rollback plan.

---

## Usage

```text
/deploy [environment]
```

**Environments:**

- `production` — full safety checks (default)
- `staging` — lighter checks
- `hotfix` — emergency deploy (skip non-critical checks)

**Examples:**

- `/deploy` — deploy to production
- `/deploy staging` — deploy to staging
- `/deploy hotfix` — emergency hotfix deploy

---

## Iron Rules

```text
1. NEVER deploy without running tests first
2. NEVER batch-restart all workers
3. ALWAYS verify after deploy
4. ALWAYS have a rollback plan
```

---

## Phase 1: Pre-Deploy Checks

### 1.1 Git State

```bash
# Check for uncommitted changes
git status

# Fetch latest from remote
git fetch origin main

# Check if behind
git log HEAD..origin/main --oneline
```

**If uncommitted changes exist — commit or stash first.**
**If behind remote — merge before deploying.**

### 1.2 Conflict Check

```bash
# Dry-run merge to check for conflicts
git merge origin/main --no-commit --no-ff
git merge --abort  # Reset after check
```

**If conflicts — resolve BEFORE deploying. DO NOT use `git reset --hard`.**

### 1.3 Tests

```bash
# Laravel
php artisan test

# Next.js / Node.js
npm test

# Python
pytest

# Go
go test ./...
```

**If tests fail — STOP. Fix tests before deploying.**

### 1.4 Build

```bash
# Laravel
npm run build

# Next.js
npm run build

# Python
# no build step usually

# Go
go build ./...
```

---

## Phase 2: Deploy

### 2.1 Framework-Specific Deploy

**Laravel:**

```bash
ssh production 'cd /app && \
  git pull origin main && \
  composer install --no-dev --optimize-autoloader && \
  php artisan migrate --force && \
  php artisan config:cache && \
  php artisan route:cache && \
  php artisan view:cache && \
  php artisan queue:restart'
```

**Next.js:**

```bash
ssh production 'cd /app && \
  git pull origin main && \
  npm ci --production && \
  npm run build && \
  pm2 reload next-app'
```

**Node.js:**

```bash
ssh production 'cd /app && \
  git pull origin main && \
  npm ci --production && \
  pm2 reload app'
```

**Python:**

```bash
ssh production 'cd /app && \
  git pull origin main && \
  pip install -r requirements.txt && \
  python manage.py migrate && \
  supervisorctl restart app'
```

**Go:**

```bash
ssh production 'cd /app && \
  git pull origin main && \
  go build -o app . && \
  systemctl restart app'
```

### 2.2 Worker Restart (SAFETY!)

```text
⚠️  NEVER restart all workers at once!
```

```bash
# Laravel: Graceful restart (finishes current job, then restarts)
php artisan queue:restart

# PM2: Rolling reload
pm2 reload app --update-env

# Supervisor: Restart one at a time
supervisorctl restart worker:worker_00
# Wait 10 seconds
supervisorctl restart worker:worker_01
```

---

## Phase 3: Post-Deploy Verification

### 3.1 Smoke Tests

```bash
# Check critical endpoints (adjust URLs)
for url in \
  "https://app.example.com/" \
  "https://app.example.com/api/health" \
  "https://app.example.com/dashboard" \
  "https://app.example.com/login"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  echo "$url → $STATUS"
done
```

**All must return 200. If any returns 500 — investigate immediately.**

### 3.2 Log Check

```bash
# Laravel
tail -30 storage/logs/laravel.log | grep -i "error\|exception"

# Next.js / Node.js
pm2 logs --lines 30 --err

# Python
tail -30 /var/log/app/error.log

# Systemd
journalctl -u app --since "1 minute ago" --no-pager
```

### 3.3 Worker Status

```bash
# Laravel
php artisan queue:monitor redis:default

# PM2
pm2 status

# Supervisor
supervisorctl status
```

---

## Phase 4: Rollback Decision

### If Verification Passes

```text
✅ Deploy successful
- All endpoints return 200
- No errors in logs
- Workers processing normally

→ Monitor for 15 minutes, then done
```

### If Verification Fails

```text
❌ Deploy failed — decide:

Option A: ROLLBACK (recommended if unsure)
  git revert HEAD
  [redeploy]

Option B: HOTFIX (only if fix is obvious and < 10 lines)
  [fix] → [deploy] → [verify again]

Option C: INVESTIGATE (if issue is unclear)
  [check logs] → [diagnose] → [decide A or B]
```

**⚠️ DO NOT proceed without user approval on rollback decision.**

---

## Output Format

```text
DEPLOY REPORT
=============

Environment: [production/staging]
Branch:      [branch name]
Commit:      [hash]

Phase 1: Pre-Deploy
  Git status:   [CLEAN/DIRTY]
  Up to date:   [YES/BEHIND by N commits]
  Conflicts:    [NONE/LIST]
  Tests:        [PASS/FAIL]
  Build:        [PASS/FAIL]

Phase 2: Deploy
  Code pulled:  [OK/FAIL]
  Migrations:   [OK/NONE/FAIL]
  Cache:        [CLEARED]
  Workers:      [RESTARTED (rolling)]

Phase 3: Verification
  Endpoints:    [ALL 200 / FAILURES: list]
  Errors:       [NONE / COUNT]
  Workers:      [RUNNING / ISSUES]

─────────────────────
Result: [SUCCESS / NEEDS ATTENTION / ROLLBACK NEEDED]
```

---

## Quick Reference

| Phase | Actions | Fail Action |
|-------|---------|-------------|
| **1. Pre-Deploy** | Git check, tests, build | Fix before deploying |
| **2. Deploy** | Pull, migrate, cache, workers | Check logs |
| **3. Verify** | Endpoints, logs, workers | Rollback or hotfix |
| **4. Decision** | Monitor or rollback | Ask user |

---

## Integration

- Before deploy, run `/verify pre-pr` for full checks
- After failed deploy, use `/fix-prod` for hotfix workflow
- Use `/debug` if deploy issue root cause is unclear
- Use `deploy checklist` audit for comprehensive pre-deploy review
- For Docker-based deploys, see `/docker` for image configuration
- For dependency vulnerabilities before deploy, run `/deps audit`
