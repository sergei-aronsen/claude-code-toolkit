# Deploy Checklist — Next.js Template

## Goal

Comprehensive pre-deploy verification for a Next.js application. Act as a Senior DevOps Engineer.

> **Warning: Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for pre-deploy verification — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Build | `npm run build` | Success |
| 2 | Lint | `npm run lint` | No errors |
| 3 | Tests | `npm test` | Pass |
| 4 | TypeScript | Checked during build | No errors |
| 5 | console.log | `grep -rn "console.log" app/` | Minimal |
| 6 | Env vars | All required variables | Set |

**If all 6 = OK → Ready to deploy!**

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# deploy-check.sh

set -e

echo "Pre-deploy Check for Next.js..."

# 1. Build
npm run build > /dev/null 2>&1 && echo "✅ Build" || { echo "❌ Build failed"; exit 1; }

# 2. Lint
npm run lint > /dev/null 2>&1 && echo "✅ Lint" || echo "🟡 Lint has warnings"

# 3. Tests (if exists)
if npm run test --if-present > /dev/null 2>&1; then
    echo "✅ Tests"
else
    echo "🟡 Tests failed or not configured"
fi

# 4. console.log check
CONSOLE=$(grep -rn "console.log" app/ components/ lib/ --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
[ "$CONSOLE" -lt 10 ] && echo "✅ console.log: $CONSOLE" || echo "🟡 console.log: $CONSOLE (too many)"

# 5. Check for required env vars
if [ -f ".env.example" ]; then
    MISSING=$(grep -v "^#" .env.example | cut -d= -f1 | while read var; do
        [ -z "${!var}" ] && echo "$var"
    done)
    [ -z "$MISSING" ] && echo "✅ Env vars set" || echo "🟡 Missing env vars: $MISSING"
fi

echo ""
echo "Ready to deploy!"
```text

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Deployment target:**

- **Platform**: [Vercel / Server / Docker]
- **URL**: [https://...]
- **Region**: [eu-central-1 / etc]

**Database:**

- **Type**: [MySQL / PostgreSQL / SQLite]
- **Host**: [host]
- **Connection**: see `DATABASE_URL` in env

**Important variables:**

- `DATABASE_URL` — database connection
- `NEXTAUTH_SECRET` — secret for auth
- `NEXTAUTH_URL` — application URL

---

## 0.3 DEPLOY TYPES

| Type | When | Checklist |
| ----- | ------- | --------- |
| Hotfix | Critical bug | Quick Check only |
| Minor | Small changes | Quick Check + section 1 |
| Feature | New functionality | Sections 0-6 |
| Major | Architectural changes | Full checklist |

---

## 1. PRE-DEPLOYMENT CODE CLEANUP

### 1.1 Debug Code Removal

```bash
grep -rn "console.log" app/ components/ lib/ --include="*.ts" --include="*.tsx"
grep -rn "console.error" app/ components/ lib/ --include="*.ts" --include="*.tsx"
grep -rn "debugger" app/ components/ lib/ --include="*.ts" --include="*.tsx"
```text

- [ ] No unnecessary `console.log()`
- [ ] No `debugger` statements
- [ ] No test data in code

### 1.2 TODO/FIXME

```bash
grep -rn "TODO\|FIXME" app/ components/ lib/ --include="*.ts" --include="*.tsx"
```text

- [ ] Critical TODOs resolved
- [ ] No blocking FIXMEs

### 1.3 Commented Code

- [ ] No commented out code
- [ ] No old function versions

---

## 2. CODE QUALITY CHECKS

### 2.1 Build & TypeScript

```bash
npm run build
```text

- [ ] Build passes without errors
- [ ] No TypeScript errors
- [ ] Bundle size is normal (< 200KB First Load)

### 2.2 Linting

```bash
npm run lint
```text

- [ ] No ESLint errors
- [ ] Warnings reviewed

### 2.3 Tests

```bash
npm test
```text

- [ ] All tests pass
- [ ] Critical functionality covered

---

## 3. DATABASE PREPARATION

### 3.1 Migrations

```bash
# Prisma
npx prisma migrate status
npx prisma migrate deploy

# Drizzle
npx drizzle-kit push

# Raw SQL
# Check pending migrations
```text

- [ ] All migrations applied
- [ ] No pending migrations
- [ ] Schema in sync

### 3.2 Backup

```bash
# MySQL
mysqldump -u USER -p DATABASE > backup_$(date +%Y%m%d).sql

# PostgreSQL
pg_dump DATABASE > backup_$(date +%Y%m%d).sql
```text

- [ ] Backup created before migrations
- [ ] Backup verified for restorability

---

## 4. ENVIRONMENT CONFIGURATION

### 4.1 Production Environment Variables

```ini
# Required
NODE_ENV=production
NEXTAUTH_URL=https://your-domain.com
NEXTAUTH_SECRET=your-super-secret-key-min-32-chars

# Database
DATABASE_URL=mysql://user:password@host:3306/db

# API Keys (on server, not in NEXT_PUBLIC_)
ANTHROPIC_API_KEY=sk-...
```text

- [ ] `NODE_ENV=production`
- [ ] `NEXTAUTH_URL` — correct production URL
- [ ] `NEXTAUTH_SECRET` — strong key (min 32 chars)
- [ ] Database URL is correct

### 4.2 Secrets Check

```bash
# Check for secrets in code
grep -rn "sk-\|password=\|secret=" app/ lib/ components/ --include="*.ts" --include="*.tsx"

# Check that secrets are not in NEXT_PUBLIC_
grep -rn "NEXT_PUBLIC_.*KEY\|NEXT_PUBLIC_.*SECRET" .env*
```text

- [ ] No hardcoded secrets
- [ ] API keys not in `NEXT_PUBLIC_`
- [ ] `.env.local` in `.gitignore`

### 4.3 Environment Variables Comparison

```bash
# Compare .env.example with production
diff .env.example .env.production
```text

- [ ] All variables from `.env.example` are set
- [ ] No development values in production

---

## 5. BUILD PROCESS

### 5.1 Clean Build

```bash
rm -rf .next node_modules
npm ci
npm run build
```text

- [ ] `npm ci` successful
- [ ] `npm run build` successful
- [ ] No warnings during build

### 5.2 Bundle Analysis

```bash
# If bundle analyzer is configured
ANALYZE=true npm run build

# Check size
ls -la .next/static/chunks/
```text

- [ ] Main bundle < 200KB (gzipped)
- [ ] No library duplication
- [ ] Heavy packages are split

---

## 6. SECURITY PRE-CHECK

### 6.1 Dependencies Audit

```bash
npm audit
npm audit --production
```text

- [ ] No critical vulnerabilities
- [ ] High vulnerabilities reviewed

### 6.2 Security Headers

```typescript
// next.config.ts
const nextConfig = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-XSS-Protection', value: '1; mode=block' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};
```text

- [ ] Security headers configured
- [ ] HTTPS required

### 6.3 API Security

- [ ] All protected API routes check auth
- [ ] Rate limiting on expensive endpoints
- [ ] Input validation via Zod

---

## 7. DEPLOYMENT

### 7.1 Vercel Deployment

```bash
# Via CLI
vercel --prod

# Or via Git push
git push origin main
```text

- [ ] Vercel project configured
- [ ] Environment variables in Vercel dashboard
- [ ] Production branch = main

### 7.2 Server Deployment

```bash
#!/bin/bash
# deploy.sh

set -e

APP_DIR="/opt/app"
DATE=$(date +%Y%m%d_%H%M%S)

cd $APP_DIR

# 1. Pull code
git pull origin main

# 2. Install dependencies
npm ci

# 3. Build
npm run build

# 4. Database migrations
npx prisma migrate deploy

# 5. Restart application
pm2 restart app || pm2 start npm --name "app" -- start

echo "Deployment completed!"

# 6. Health check
sleep 5
curl -s https://your-domain.com/api/health | grep -q "ok" && echo "✅ Health check passed" || echo "❌ Health check failed"
```text

---

## 8. POST-DEPLOYMENT VERIFICATION

### 8.1 Smoke Tests

```bash
# Basic checks
curl -I https://your-domain.com
curl -I https://your-domain.com/api/health
```text

Check manually:

- [ ] Homepage loads
- [ ] Login works
- [ ] Main functionality works
- [ ] API endpoints respond

### 8.2 Error Monitoring

- [ ] Vercel logs clean
- [ ] No 500 errors
- [ ] Error rate hasn't increased

### 8.3 Performance Check

```bash
# Lighthouse
npx lighthouse https://your-domain.com --view

# TTFB check
curl -w "TTFB: %{time_starttransfer}s\n" -o /dev/null -s https://your-domain.com
```text

- [ ] LCP < 2.5s
- [ ] TTFB < 800ms
- [ ] No noticeable slowdown

---

## 9. ROLLBACK PLAN

### 9.1 Vercel Rollback

```bash
# Via UI: Deployments → Select previous → Promote to Production

# Via CLI
vercel rollback
```text

### 9.2 Server Rollback

```bash
#!/bin/bash
# rollback.sh

cd /opt/app

# Rollback to previous commit
git reset --hard HEAD~1

# Rebuild
npm ci
npm run build

# Restart
pm2 restart app
```text

### 9.3 Database Rollback

```bash
# Prisma
npx prisma migrate reset  # CAUTION! Deletes data

# Restore from backup
mysql -u USER -p DATABASE < backup_YYYYMMDD.sql
```text

### 9.4 Rollback Triggers

Rollback if:

- Error rate > 5%
- Critical functionality doesn't work
- Performance degraded > 50%

---

## 10. SELF-CHECK

**DO NOT block deploy because of:**

| Seems like a blocker | Why it's not a blocker |
| ------------------ | ------------------ |
| "ESLint warnings" | If build passes — OK |
| "Deprecated package" | If it works — update later |
| "console.log in code" | Not critical |
| "No tests" | If functionality works — OK |
| "Large bundle" | If < 500KB — acceptable |

**Readiness levels:**

```text
READY (95-100%) — Deploy now
   - Build passes
   - Critical functionality works
   - No security blockers

ACCEPTABLE (70-94%) — Deploy possible
   - Has warnings but not errors
   - Minor issues can be fixed after

NOT READY (<70%) — Block
   - Build fails
   - Security vulnerabilities
   - Critical functionality broken
```text

---

## 11. REPORT FORMAT

```markdown
# Deploy Checklist Report — [Project Name]
Date: [date]
Version: [git commit hash]

## Summary

| Step | Status |
|------|--------|
| Build | ✅/❌ |
| Tests | ✅/❌ |
| Env vars | ✅/❌ |
| Security | ✅/❌ |
| Deploy | ✅/❌ |
| Verify | ✅/❌ |

**Readiness**: XX% — [READY/ACCEPTABLE/NOT READY]

## Blockers
- [If any]

## Warnings
- [If any]

## Post-Deploy
- [ ] Monitor for 24h
- [ ] Check error rate
- [ ] Verify performance
```text

---

## 12. ACTIONS

1. **Check** — go through checklist
2. **Backup** — create DB backup
3. **Deploy** — execute deployment
4. **Verify** — check that it works
5. **Monitor** — watch metrics

Reply: "OK: Ready to deploy (XX%)" or "FAIL: Issues: [list]"
