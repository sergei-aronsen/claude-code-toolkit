# Deploy Checklist — Base Template

## Goal

Comprehensive pre-deployment check. Act as a Senior DevOps Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for pre-deployment checks — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Expected |
| --- | ------- | ---------- |
| 1 | Build | Success |
| 2 | Tests | Pass |
| 3 | Linter | No errors |
| 4 | Debug code | Removed |
| 5 | Migrations | Reviewed |
| 6 | Env vars | Set |

**If all 6 = OK → Ready to deploy!**

---

## 0.1 PROJECT SPECIFICS — [Project Name]

**Deployment target:**

- **Server**: [IP/hostname]
- **Path**: [/path/to/app]
- **URL**: [https://...]
- **Process manager**: [PM2/Supervisor/systemd]

**Database:**

- **Host**: [host]
- **Name**: [db_name]

**Important files:**

- `.env` — environment variables
- [Other important files]

---

## 0.2 DEPLOY TYPES

| Type | When | Checklist |
| ----- | ------- | --------- |
| Hotfix | Critical bug | Quick Check only |
| Minor | Small changes | Quick Check + section 1 |
| Feature | New functionality | Sections 0-6 |
| Major | Architectural changes | Full checklist |

---

## 1. CODE CLEANUP

### 1.1 Debug Code

- [ ] No console.log / dd() / dump()
- [ ] No debugger statements
- [ ] No TODO/FIXME in critical code

### 1.2 Commented Code

- [ ] No commented out code
- [ ] No backup blocks

### 1.3 Temporary Files

- [ ] No .bak, .tmp, .old files

---

## 2. CODE QUALITY

### 2.1 Tests

- [ ] All tests pass
- [ ] No skipped tests without reason
- [ ] Critical functionality covered

### 2.2 Linting

- [ ] Code passes linter
- [ ] No errors (warnings OK)

### 2.3 Build

- [ ] Build passes without errors
- [ ] Assets built and minified

---

## 3. DATABASE

### 3.1 Migrations

- [ ] Migrations have rollback
- [ ] NOT NULL columns have default
- [ ] Indexes added
- [ ] Dry run verified

### 3.2 Backup

- [ ] Backup created before migrations
- [ ] Backup verified for recoverability

### 3.3 Seeders

- [ ] Seeders DO NOT run in production
- [ ] No truncate without env check

---

## 4. ENVIRONMENT

### 4.1 Production Config

- [ ] APP_ENV=production
- [ ] DEBUG=false
- [ ] LOG_LEVEL not debug
- [ ] HTTPS required

### 4.2 Secrets

- [ ] All API keys — production versions
- [ ] Passwords strong and unique
- [ ] No secrets in code

### 4.3 Cache Config

- [ ] Cache driver configured (not file)
- [ ] Session driver configured
- [ ] Queue driver configured

---

## 5. SECURITY

### 5.1 Files

- [ ] .env not accessible via web
- [ ] .git not accessible via web
- [ ] Logs not accessible via web

### 5.2 Permissions

- [ ] Correct directory permissions
- [ ] Owner correct (www-data/nginx)

### 5.3 Dependencies

- [ ] No critical vulnerabilities
- [ ] Dependencies updated

---

## 6. DEPLOYMENT

### 6.1 Pre-Deploy

```bash
# 1. Maintenance mode
# 2. Backup database
# 3. Pull code
# 4. Install dependencies
```text

### 6.2 Deploy

```bash
# 5. Run migrations
# 6. Clear caches
# 7. Rebuild caches
# 8. Restart workers
```text

### 6.3 Post-Deploy

```bash
# 9. Verify site works
# 10. Check logs for errors
# 11. Disable maintenance
```text

---

## 7. VERIFICATION

### 7.1 Smoke Tests

- [ ] Homepage loads
- [ ] Login works
- [ ] Core functionality works

### 7.2 Monitoring

- [ ] No new errors in logs
- [ ] Error rate did not increase
- [ ] Response time normal

---

## 8. ROLLBACK PLAN

### 8.1 Readiness

- [ ] Rollback script ready
- [ ] Database backup available
- [ ] Know commit hash for rollback

### 8.2 Triggers

Rollback if:

- Error rate > 5%
- Critical functionality not working
- Database corruption

---

## 9. SELF-CHECK

**DO NOT block deploy because of:**

| Seems like blocker | Why not a blocker |
| ------------------ | ------------------ |
| "Linter warnings" | If code works — OK |
| "Deprecated package" | If it works — update later |
| "No tests" | If functionality works — OK |
| "console.log in code" | Does not affect users |

**Readiness gradation:**

```text
READY (95-100%) — Deploy now
ACCEPTABLE (70-94%) — Deploy possible
NOT READY (<70%) — Block
```text

---

## 10. REPORT FORMAT

```markdown
# Deploy Checklist Report — [Project]
Date: [date]
Version: [commit hash]

## Summary

| Step | Status |
|------|--------|
| Pre-checks | ✅/❌ |
| Backup | ✅/❌ |
| Deploy | ✅/❌ |
| Verify | ✅/❌ |

**Readiness**: XX% — [READY/ACCEPTABLE/NOT READY]

## Blockers
- [If any]

## Warnings
- [If any]

## Post-Deploy
- [ ] Monitor for 24h
- [ ] Check queues
```text

---

## 11. ACTIONS

1. **Check** — go through checklist
2. **Backup** — create backup
3. **Deploy** — execute deployment
4. **Verify** — check that it works
5. **Monitor** — watch the logs

Answer: "OK: Ready to deploy (XX%)" or "FAIL: Issues: [list]"
