# Production Safety Guide

> Operational safety rules for production deployments, workers, and hotfixes.

---

## TL;DR

- **Deploy incrementally** — one logical change at a time, verify between deploys
- **Never batch-restart workers** — use rolling restarts
- **Diagnose before fixing** — root cause first, then minimal change
- **Verify after every deploy** — smoke tests, logs, worker status
- **Rollback fast** — if smoke test fails, rollback immediately

---

## Deployment Safety

### Pre-Deploy Checklist

Before every deployment:

```bash
# 1. Fetch latest (other sessions may have pushed)
git fetch origin main

# 2. Check for conflicts
git diff origin/main --stat

# 3. Merge latest
git merge origin/main
# If CONFLICT — STOP and resolve manually

# 4. Run tests
[test command]  # php artisan test / npm test / pytest

# 5. Check for uncommitted changes
git status
```

**If any step fails — DO NOT deploy.**

### Incremental Deploy Pattern

Deploy after each logical change, not in batches:

```text
Change 1 → Deploy → Verify → ✅
Change 2 → Deploy → Verify → ✅
Change 3 → Deploy → Verify → ✅
```

**NOT:**

```text
Change 1 + Change 2 + Change 3 → Deploy → 💥 Which one broke it?
```

Why: Batched deploys make it impossible to identify which change caused a failure. Cascading bugs are harder to untangle than isolated ones.

### Post-Deploy Verification

After every deployment, verify:

| Check | How | Fail Action |
|-------|-----|-------------|
| HTTP status | Hit 5 critical endpoints | Rollback |
| Error logs | Check last 60 seconds | Investigate |
| Workers | Verify processing, not stuck | Restart workers |
| Response time | Compare to pre-deploy | Investigate |
| Queue depth | Check for job buildup | Monitor |

```bash
# Example: Laravel
curl -s -o /dev/null -w "%{http_code}" https://app.example.com/
tail -20 storage/logs/laravel.log
php artisan queue:monitor redis:default

# Example: Node.js
curl -s -o /dev/null -w "%{http_code}" https://app.example.com/health
pm2 status
pm2 logs --lines 20
```

---

## Queue and Worker Safety

### Rule 1: Never Batch-Restart Workers

```text
❌  WRONG: Restart ALL workers at once
    → Active jobs fail, exceed retry limits
    → 21,000 failed jobs in one incident

✅  RIGHT: Rolling restart, one at a time
    → Each worker finishes current job before stopping
    → Zero job loss
```

### Rolling Restart Pattern

```bash
# Laravel: Graceful restart (finishes current job)
php artisan queue:restart

# Node.js / PM2: Graceful reload
pm2 reload app --update-env

# Docker: Rolling update
docker service update --update-parallelism 1 --update-delay 10s app
```

### Rule 2: Check Before Modifying Queues

Before any queue/worker change:

```bash
# How many active jobs?
# Laravel
php artisan queue:monitor redis:default,redis:high,redis:low

# What happens if workers restart?
# → Jobs mid-process will retry
# → Jobs at max retries will FAIL permanently
```

### Rule 3: Test Queue Changes on Small Subset

```text
1. Apply change to 1 worker
2. Monitor for 5 minutes
3. Check: jobs processing? No errors?
4. Only then apply to remaining workers
```

### Common Queue Disasters and Prevention

| Disaster | Cause | Prevention |
|----------|-------|------------|
| Mass job failures | Batch worker restart | Rolling restart |
| Queue stuck | Bad dedup logic | Test on subset first |
| Lost jobs | Worker killed mid-job | Graceful shutdown |
| Retry storm | Changed retry config | Check max_tries before changing |

---

## Rollback Decision Framework

### When to Rollback

Rollback immediately if:

- Error rate jumps above 5%
- Critical endpoint returns non-200
- Queue jobs failing in bulk
- Database errors in logs

### When to Hotfix

Hotfix (forward-fix) if:

- Issue is isolated to one component
- Fix is obvious and minimal (< 10 lines)
- Rollback would cause data issues (migration already ran)

### Rollback Procedure

```bash
# 1. Identify last good commit
git log --oneline -10

# 2. Deploy previous version
git checkout <last-good-commit>
# or: git revert HEAD

# 3. Clear caches
# Laravel: php artisan config:cache && php artisan route:cache
# Next.js: rm -rf .next && npm run build
# Node.js: pm2 restart app

# 4. Verify rollback worked
curl -s https://app.example.com/health
```

---

## File Targeting Safety

### Verify Before Editing

Before making changes, always confirm:

1. **Correct file variant** — projects often have V2/legacy variants (e.g., `Show.vue` vs `ShowV2.vue`)
2. **Correct branch/worktree** — check `git branch --show-current` and `pwd`
3. **Not already fixed upstream** — check `git log origin/main --oneline -5`

```text
❌  Edited Show.vue → but ShowV2.vue is the active version
❌  Fixed bug in worktree-1 → but same fix already merged from worktree-2
✅  Confirmed: ShowV2.vue is imported in router, worktree-1 is current, main has no related commits
```

### Verification Checklist

```bash
# What branch am I on?
git branch --show-current

# Am I in the right directory?
pwd

# Is there a V2/new variant of this file?
find . -name "*V2*" -o -name "*v2*" | head -10

# Has this been fixed upstream?
git log origin/main --oneline -5 --grep="fix"
```

---

## Bug Fix Approach

### Simplest Fix First

When fixing bugs, especially UI/layout issues:

1. **Try the simplest solution first** — remove unnecessary wrappers, delete extra CSS, simplify
2. **ONE change at a time** — don't combine multiple fixes
3. **Verify immediately** — check that fix works AND doesn't break anything else
4. **If first attempt fails — STOP** — re-analyze root cause instead of trying random approaches

```text
❌  WRONG approach:
    Try flex hack → fails
    Try min-height hack → fails
    Try overflow hack → fails
    User suggests: "just remove the scroll container"

✅  RIGHT approach:
    Analyze: what's the simplest change?
    → Remove unnecessary scroll container
    → Fixed in one attempt
```

### Rule of Three Attempts

```text
Fix attempt 1 → failed → re-analyze
Fix attempt 2 → failed → STOP
Fix attempt 3 → DO NOT attempt

3 failed fixes = you don't understand the root cause.
Go back to /debug Phase 1.
```

---

## Add to CLAUDE.md

```markdown
## Production Safety

### Deployment
- Deploy incrementally — one change at a time, verify between deploys
- Always fetch/merge latest before deploy
- Run tests before every deploy
- Verify after deploy: endpoints, logs, workers

### Workers and Queues
- NEVER restart all workers at once — use rolling restarts
- Check active job count before modifying queue config
- Test queue changes on small subset first

### Bug Fixes
- Try simplest solution first
- ONE change at a time, verify immediately
- If 2 attempts fail — stop and re-analyze root cause
- After fix, verify no regressions

### File Targeting
- Before editing, confirm correct file variant (V2, legacy, etc.)
- Confirm correct branch/worktree
- Check if already fixed upstream

Full guide: `components/production-safety.md`
```
