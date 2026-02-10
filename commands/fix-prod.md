# /fix-prod — Production Hotfix Workflow

## Purpose

Structured workflow for fixing production issues: diagnose first, minimal change, verify fix.

---

## Usage

```text
/fix-prod <problem description>
```

**Examples:**

- `/fix-prod 500 errors on dashboard page`
- `/fix-prod queue jobs failing with timeout`
- `/fix-prod users can't login after deploy`

---

## Iron Rules

```text
1. DIAGNOSE before touching code
2. MINIMAL change — fix only the broken thing
3. VERIFY the fix doesn't break anything else
4. NEVER use destructive git commands on production branch
```

---

## Phase 1: Diagnose (DO NOT SKIP)

### 1.1 Gather Evidence

```bash
# Check recent deploys
git log --oneline -5

# Check error logs (last 50 lines, filter for errors)
# Adapt path for your framework: storage/logs/, pm2 logs, /var/log/app/
tail -50 <error-log-path> | grep -i "error\|exception\|fatal"

# Check system resources
df -h && free -m
```

### 1.2 Identify Scope

Answer these questions before proceeding:

- [ ] **What changed?** Recent deploy, config change, data change, external service?
- [ ] **When did it start?** After deploy? Gradually? Suddenly?
- [ ] **What's affected?** All users or specific? All pages or specific?
- [ ] **Is it getting worse?** Stable error rate or increasing?

### 1.3 Check if Rollback is Better

| Situation | Action |
|-----------|--------|
| Issue started after deploy + affects many users | **Rollback** |
| Issue is in one feature + fix is obvious | **Hotfix** |
| Issue is unclear + getting worse | **Rollback first**, then investigate |
| Issue is data-related (not code) | **Hotfix** (rollback won't help) |

---

## Phase 2: Fix

### 2.1 Minimal Change Rule

```text
✅ DO: Change the minimum needed to fix the issue
❌ DON'T: Refactor while fixing
❌ DON'T: Add features while fixing
❌ DON'T: Fix multiple bugs in one commit
❌ DON'T: Change code formatting
```

### 2.2 Fix Workflow

```bash
# 1. Create hotfix branch
git checkout -b hotfix/description main

# 2. Make the minimal fix
# [edit files]

# 3. Test locally
[test command]

# 4. Commit with clear message
git add <specific-files>
git commit -m "fix: [what was fixed and why]"
```

### 2.3 Test the Fix

Run relevant tests for the changed code, then run the full suite to check for regressions.

---

## Phase 3: Deploy Fix

### 3.1 Deploy Hotfix

```bash
# Merge to main
git checkout main
git merge hotfix/description

# Deploy (use /deploy hotfix for guided deploy)
```

### 3.2 Verify Fix in Production

Verify: original issue is resolved, no new errors in logs, related features still work.

---

## Phase 4: Monitor

### 4.1 Immediate (0-5 minutes)

- [ ] Error that was happening has stopped
- [ ] No new errors in logs
- [ ] Affected endpoints return 200

### 4.2 Short-term (5-30 minutes)

- [ ] Error rate is back to normal
- [ ] No queue job failures
- [ ] Response times normal

### 4.3 Document

After fix is verified:

```text
Use /learn to save the solution pattern
```

---

## Output Format

```markdown
# Production Fix Report

## Issue
**Problem:** [description]
**Started:** [when]
**Affected:** [what/who]

## Diagnosis
**Root Cause:** [what caused it]
**Evidence:** [logs, errors, traces]

## Fix
**Change:** [what was changed]
**Files:** [list of modified files]
**Commit:** [hash]

## Verification
**Original issue:** [RESOLVED]
**Regressions:** [NONE / list]
**Monitoring:** [status after 15 min]
```

---

## Common Production Issues

| Symptom | First Check | Likely Cause |
|---------|-------------|--------------|
| 500 errors after deploy | `git log -1`, error log | Code bug in latest commit |
| Slow responses | DB queries, memory | Missing index, memory leak |
| Queue jobs failing | Worker status, retry count | Worker crash, bad job data |
| Login broken | Session/cache config | Cache stale, config not cleared |
| Missing data | Recent migration | Migration issue |
| CORS errors | Nginx/app config | Config not updated |

---

## Integration

- After fix, use `/verify` to run full verification
- Use `/learn` to save the fix pattern for future reference
- If fix was complex, use `/handoff` to document for team
- For deep investigation, start with `/debug`
