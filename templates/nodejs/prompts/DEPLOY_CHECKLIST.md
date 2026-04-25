# Deploy Checklist — Node.js Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive pre-deploy verification for a Node.js application. Act as a Senior DevOps Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for pre-deploy verification — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Build | `npm run build` | Success |
| 2 | Lint | `npx eslint src/` | No errors |
| 3 | Tests | `npm test` | Pass |
| 4 | TypeScript | `npx tsc --noEmit` | No errors |
| 5 | console.log | `grep -rn "console.log" src/` | Minimal |
| 6 | Env vars | All required variables | Set |

**If all 6 = OK → Ready to deploy!**

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# deploy-check.sh — run before deployment

set -e

echo "Pre-deploy Check for Node.js..."

# 1. Build
npm run build > /dev/null 2>&1 && echo "✅ Build" || { echo "❌ Build failed"; exit 1; }

# 2. Lint
npx eslint src/ > /dev/null 2>&1 && echo "✅ ESLint" || echo "🟡 ESLint has warnings"

# 3. Tests
npm test > /dev/null 2>&1 && echo "✅ Tests" || echo "🟡 Tests failed"

# 4. TypeScript
npx tsc --noEmit > /dev/null 2>&1 && echo "✅ TypeScript" || echo "🟡 TypeScript errors"

# 5. console.log check
CONSOLE=$(grep -rn "console.log" src/ --include="*.ts" --include="*.js" 2>/dev/null | wc -l)
[ "$CONSOLE" -lt 10 ] && echo "✅ console.log: $CONSOLE" || echo "🟡 console.log: $CONSOLE (too many)"

# 6. Debug code check
grep -rn "debugger" src/ --include="*.ts" --include="*.js" 2>/dev/null && echo "🟡 debugger found" || echo "✅ No debugger"

# 7. npm audit
npm audit --production > /dev/null 2>&1 && echo "✅ No vulnerabilities" || echo "🟡 npm audit warnings"

# 8. Check for required env vars
if [ -f ".env.example" ]; then
    MISSING=$(grep -v "^#" .env.example | grep -v "^$" | cut -d= -f1 | while read var; do
        [ -z "${!var}" ] && echo "$var"
    done)
    [ -z "$MISSING" ] && echo "✅ Env vars set" || echo "🟡 Missing env vars: $MISSING"
fi

echo ""
echo "Pre-deploy check complete!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Deployment target:**

- **Server**: [IP/hostname]
- **Path**: [/opt/app or /var/www/app]
- **URL**: [https://...]
- **Process manager**: [PM2/systemd]
- **Runtime**: Node.js [20.x/22.x]

**Database:**

- **Type**: [PostgreSQL/MongoDB/MySQL/Redis]
- **Host**: [host]
- **Connection**: see `DATABASE_URL` in env

**Important files:**

- `.env` — environment variables
- `ecosystem.config.js` — PM2 configuration
- `docker-compose.yml` — Docker orchestration (if applicable)

---

## 0.3 DEPLOY TYPES

| Type | When | Checklist |
| ----- | ------- | --------- |
| Hotfix | Critical bug | Quick Check only |
| Minor | Small changes | Quick Check + section 1 |
| Feature | New functionality | Sections 0-8 |
| Major | Architectural changes | Full checklist |

---

## 1. PRE-DEPLOYMENT CODE CLEANUP

### 1.1 Debug Code Removal

```bash
grep -rn "console.log" src/ --include="*.ts" --include="*.js"
grep -rn "console.debug" src/ --include="*.ts" --include="*.js"
grep -rn "console.warn" src/ --include="*.ts" --include="*.js"
grep -rn "debugger" src/ --include="*.ts" --include="*.js"
```

- [ ] No unnecessary `console.log()` statements
- [ ] No `console.debug()` calls
- [ ] No `debugger` statements
- [ ] Logging uses structured logger (pino/winston) instead of console

### 1.2 TODO/FIXME

```bash
grep -rn "TODO\|FIXME\|HACK\|XXX" src/ --include="*.ts" --include="*.js"
```

- [ ] Critical TODOs resolved
- [ ] No blocking FIXMEs
- [ ] No HACK markers in production paths

### 1.3 Commented Code

- [ ] No commented out code blocks
- [ ] No old function versions left as comments
- [ ] No `// @ts-ignore` without justification

---

## 2. CODE QUALITY CHECKS

### 2.1 Build and TypeScript

```bash
# TypeScript strict check
npx tsc --noEmit

# Production build
npm run build
```

- [ ] `tsc --noEmit` passes with no errors
- [ ] `npm run build` completes without errors
- [ ] No implicit `any` types in new code
- [ ] No `@ts-ignore` or `@ts-expect-error` without comment

### 2.2 Linting

```bash
# ESLint check
npx eslint src/ --ext .ts,.js

# Prettier check (if configured)
npx prettier --check "src/**/*.{ts,js,json}"
```

- [ ] No ESLint errors
- [ ] Warnings reviewed and acceptable
- [ ] Code formatting consistent

### 2.3 Tests

```bash
# Jest
npx jest --coverage --forceExit

# Vitest
npx vitest run --coverage

# With minimum coverage threshold
npx jest --coverage --coverageThreshold='{"global":{"branches":80,"functions":80,"lines":80}}'
```

- [ ] All tests pass
- [ ] No skipped tests without reason
- [ ] Critical functionality covered
- [ ] Integration tests pass
- [ ] No flaky tests

---

## 3. DATABASE PREPARATION

### 3.1 Migrations

```bash
# Prisma
npx prisma migrate status
npx prisma migrate deploy

# TypeORM
npx typeorm migration:show
npx typeorm migration:run

# Knex
npx knex migrate:status
npx knex migrate:latest --env production

# Sequelize
npx sequelize-cli db:migrate:status
npx sequelize-cli db:migrate

# Drizzle
npx drizzle-kit push
npx drizzle-kit migrate
```

```typescript
// Good — safe migration
export async function up(knex: Knex): Promise<void> {
  await knex.schema.alterTable('users', (table) => {
    table.string('avatar_url').nullable();  // nullable for existing records
  });
}

// Dangerous — NOT NULL without default
export async function up(knex: Knex): Promise<void> {
  await knex.schema.alterTable('users', (table) => {
    table.string('role');  // Will fail for existing records!
  });
}
```

- [ ] All migrations have rollback (`down()` method)
- [ ] New NOT NULL columns have default or are nullable
- [ ] Indexes added for new foreign keys
- [ ] Migration dry run verified
- [ ] No destructive operations without data backup

### 3.2 Backup

```bash
# PostgreSQL
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > backup_$(date +%Y%m%d_%H%M%S).sql

# MongoDB
mongodump --uri="$MONGODB_URI" --out=backup_$(date +%Y%m%d_%H%M%S)

# MySQL
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME > backup_$(date +%Y%m%d_%H%M%S).sql
```

- [ ] Database backup created before migrations
- [ ] Backup verified for restorability
- [ ] Backup stored in a safe location

---

## 4. ENVIRONMENT CONFIGURATION

### 4.1 Production Environment Variables

```ini
# Required
NODE_ENV=production
PORT=3000

# Database
DATABASE_URL=postgresql://user:password@host:5432/db?sslmode=require
# or
MONGODB_URI=mongodb+srv://user:password@cluster/db

# Security
SESSION_SECRET=your-super-secret-key-min-64-chars
JWT_SECRET=your-jwt-secret-min-64-chars
CORS_ORIGIN=https://your-frontend.com

# Logging
LOG_LEVEL=info

# Redis (if used)
REDIS_URL=redis://host:6379

# API Keys
API_KEY=...
```

- [ ] `NODE_ENV=production`
- [ ] `PORT` configured correctly
- [ ] `DATABASE_URL` points to production database
- [ ] `SESSION_SECRET` / `JWT_SECRET` are strong (min 64 chars)
- [ ] `LOG_LEVEL` is `info` or `warn` (not `debug` or `trace`)
- [ ] `CORS_ORIGIN` is set to production domain
- [ ] All third-party API keys are production versions

### 4.2 Secrets Check

```bash
# Check for hardcoded secrets in code
grep -rn "password\s*=\s*['\"]" src/ --include="*.ts" --include="*.js"
grep -rn "secret\s*=\s*['\"]" src/ --include="*.ts" --include="*.js"
grep -rn "api_key\s*=\s*['\"]" src/ --include="*.ts" --include="*.js"
grep -rn "sk-\|pk_\|Bearer " src/ --include="*.ts" --include="*.js"

# Verify .env is in .gitignore
grep -q "\.env" .gitignore && echo "✅ .env in .gitignore" || echo "❌ .env NOT in .gitignore"
```

- [ ] No hardcoded passwords or API keys
- [ ] No secrets committed to git
- [ ] `.env` and `.env.local` in `.gitignore`
- [ ] Secrets managed via environment or vault

### 4.3 Environment Variables Comparison

```bash
# Compare .env.example with production env
diff <(grep -v "^#" .env.example | grep -v "^$" | cut -d= -f1 | sort) \
     <(grep -v "^#" .env.production | grep -v "^$" | cut -d= -f1 | sort)
```

- [ ] All variables from `.env.example` are set in production
- [ ] No development-only values in production config
- [ ] No leftover test/staging values

---

## 5. BUILD PROCESS

### 5.1 Clean Build

```bash
# Full clean build
rm -rf dist build node_modules
npm ci --production=false
npm run build

# Verify output
ls -la dist/
```

- [ ] `npm ci` installs without errors
- [ ] `npm run build` completes successfully
- [ ] Output directory (`dist/` or `build/`) is generated
- [ ] No build warnings for production code

### 5.2 Bundle Analysis

```bash
# Check built output size
du -sh dist/

# List largest files in output
find dist/ -type f -name "*.js" -exec ls -lS {} + | head -20

# Check for accidental dev dependencies in bundle
grep -r "devDependencies" dist/ 2>/dev/null || echo "✅ No dev references in dist"
```

- [ ] Output size is reasonable
- [ ] No source maps in production (unless intended)
- [ ] No development code in build output
- [ ] `node_modules` contains only production dependencies when using `npm ci --production`

---

## 6. SECURITY PRE-CHECK

### 6.1 Dependencies Audit

```bash
# npm audit
npm audit --production
npm audit --audit-level=high

# Check for outdated packages
npm outdated
```

- [ ] No critical vulnerabilities in production dependencies
- [ ] High-severity vulnerabilities reviewed
- [ ] No known vulnerable package versions

### 6.2 Security Headers

```typescript
// Express with helmet
import helmet from 'helmet';

app.use(helmet());
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
    styleSrc: ["'self'", "'unsafe-inline'"],
    imgSrc: ["'self'", "data:", "https:"],
  },
}));
app.use(helmet.hsts({ maxAge: 31536000, includeSubDomains: true }));

// Fastify with @fastify/helmet
import helmet from '@fastify/helmet';
await fastify.register(helmet);
```

- [ ] Helmet middleware enabled
- [ ] Content-Security-Policy configured
- [ ] HSTS enabled
- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options: DENY

### 6.3 API Security

```typescript
// Rate limiting — Express
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,                   // limit per window
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api/', limiter);

// CORS — Express
import cors from 'cors';

app.use(cors({
  origin: process.env.CORS_ORIGIN,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
}));
```

- [ ] Authentication middleware on protected routes
- [ ] Rate limiting configured on public endpoints
- [ ] CORS configured with explicit origin (no wildcard `*` in production)
- [ ] Input validation via Zod/Joi on all endpoints
- [ ] Request body size limits set
- [ ] SQL/NoSQL injection protection (ORM usage)
- [ ] No `eval()` or `Function()` with user input

---

## 7. DEPLOYMENT

### 7.1 PM2 Deployment

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'app',
    script: './dist/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
    max_memory_restart: '500M',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
  }],

  deploy: {
    production: {
      user: 'deploy',
      host: ['your-server.com'],
      ref: 'origin/main',
      repo: 'git@github.com:user/repo.git',
      path: '/opt/app',
      'pre-deploy-local': '',
      'post-deploy': 'npm ci && npm run build && pm2 reload ecosystem.config.js --env production',
      'pre-setup': '',
    },
  },
};
```

```bash
#!/bin/bash
# deploy-pm2.sh
set -e

APP_DIR="/opt/app"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups"

cd $APP_DIR

echo "Starting deployment..."

# 1. Pull latest code
git pull origin main

# 2. Install production dependencies
npm ci

# 3. Build
npm run build

# 4. Run database migrations
npx prisma migrate deploy
# or: npx knex migrate:latest --env production
# or: npx typeorm migration:run

# 5. Reload PM2 (zero-downtime)
pm2 reload ecosystem.config.js --env production

echo "Deployment completed!"

# 6. Health check
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed! HTTP: $HTTP_CODE"
    exit 1
fi
```

- [ ] PM2 ecosystem file configured
- [ ] Cluster mode enabled for multi-core
- [ ] Memory limit set (`max_memory_restart`)
- [ ] Log rotation configured
- [ ] Zero-downtime reload used (`pm2 reload`, not `pm2 restart`)

### 7.2 Docker Deployment

```text
# Dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 appuser

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./

USER appuser

EXPOSE 3000

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/server.js"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://user:password@db:5432/app
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 512M

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=app
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d app"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

```bash
#!/bin/bash
# deploy-docker.sh
set -e

DATE=$(date +%Y%m%d_%H%M%S)

echo "Starting Docker deployment..."

# 1. Pull latest code
git pull origin main

# 2. Build new image
docker compose build --no-cache

# 3. Database backup
docker compose exec db pg_dump -U user app > "backup_${DATE}.sql"

# 4. Run migrations
docker compose run --rm app npx prisma migrate deploy

# 5. Rolling update
docker compose up -d --no-deps --build app

# 6. Health check
sleep 10
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed! Rolling back..."
    docker compose rollback
    exit 1
fi

# 7. Clean up old images
docker image prune -f

echo "Docker deployment completed!"
```

- [ ] Multi-stage Dockerfile (builder + runner)
- [ ] Non-root user in container
- [ ] Health check configured
- [ ] Memory limits set
- [ ] `.dockerignore` includes `node_modules`, `.env`, `.git`
- [ ] No secrets baked into the image

---

## 8. POST-DEPLOYMENT VERIFICATION

### 8.1 Smoke Tests

```bash
# Basic endpoint checks
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health
curl -s http://localhost:3000/health | jq .

# API response check
curl -s -H "Content-Type: application/json" http://localhost:3000/api/status | jq .
```

Check manually:

- [ ] Health endpoint returns 200
- [ ] API endpoints respond correctly
- [ ] Authentication flow works
- [ ] Main functionality works
- [ ] WebSocket connections (if used) are stable
- [ ] Background jobs/workers are running

### 8.2 Error Monitoring

```bash
# PM2 logs
pm2 logs --lines 50
pm2 logs --err --lines 50

# Application logs (pino/winston)
tail -f /opt/app/logs/app.log | npx pino-pretty
tail -f /opt/app/logs/error.log

# Docker logs
docker compose logs -f app --tail=50

# Check for errors
grep -i "error\|exception\|fatal\|unhandled" /opt/app/logs/app.log | tail -20
```

- [ ] No new errors in application logs
- [ ] No unhandled promise rejections
- [ ] No uncaught exceptions
- [ ] Error rate has not increased
- [ ] Memory usage is stable

### 8.3 Performance Check

```bash
# Response time check
curl -w "DNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" \
  -o /dev/null -s http://localhost:3000/health

# PM2 monitoring
pm2 monit

# Check Node.js process memory
pm2 info app | grep -E "memory|cpu|uptime"
```

- [ ] TTFB < 200ms for health endpoint
- [ ] API response time within acceptable range
- [ ] Memory usage is stable (no leaks)
- [ ] CPU usage is normal
- [ ] Event loop lag is minimal

---

## 9. ROLLBACK PLAN

### 9.1 PM2 Rollback

```bash
#!/bin/bash
# rollback-pm2.sh
set -e

cd /opt/app

echo "Starting PM2 rollback..."

# Rollback to previous commit
git log --oneline -5
git reset --hard HEAD~1

# Reinstall and rebuild
npm ci
npm run build

# Reload PM2
pm2 reload ecosystem.config.js --env production

echo "PM2 rollback completed!"

# Health check
sleep 5
curl -s http://localhost:3000/health | jq .
```

### 9.2 Docker Rollback

```bash
#!/bin/bash
# rollback-docker.sh
set -e

echo "Starting Docker rollback..."

# Option 1: Rollback to previous image
docker compose down
git reset --hard HEAD~1
docker compose build
docker compose up -d

# Option 2: Use tagged images
# docker compose pull app:previous
# docker compose up -d

echo "Docker rollback completed!"

# Health check
sleep 10
curl -s http://localhost:3000/health | jq .
```

### 9.3 Database Rollback

```bash
# Prisma (caution — may lose data)
npx prisma migrate reset

# TypeORM
npx typeorm migration:revert

# Knex
npx knex migrate:rollback --env production

# Sequelize
npx sequelize-cli db:migrate:undo

# Restore from backup — PostgreSQL
psql -h $DB_HOST -U $DB_USER -d $DB_NAME < backup_YYYYMMDD_HHMMSS.sql

# Restore from backup — MongoDB
mongorestore --uri="$MONGODB_URI" backup_YYYYMMDD_HHMMSS/

# Restore from backup — MySQL
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME < backup_YYYYMMDD_HHMMSS.sql
```

### 9.4 Rollback Triggers

Roll back immediately if:

- Error rate > 5% after deploy
- Health endpoint returns non-200
- Critical API endpoints fail
- Unhandled exceptions in logs
- Memory usage grows continuously (leak)
- Database connection errors
- Response time degraded > 50%

---

## 10. SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

## Procedure

For every candidate finding, execute these six steps in order. Produce a `## SELF-CHECK` block per finding (in your scratchpad — not the final report) before deciding whether to report or drop it. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow user input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look exploitable in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the threat surface (e.g. an upstream sanitizer documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, etc.), the finding is a design trade-off, not a vulnerability. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual exploit scenario, not the rule label. A theoretical XSS sink behind 3 unlikely preconditions and no PII is not CRITICAL. If you cannot describe a concrete attack path the user would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

## Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `lib/utils.py:5` | `SEC-EVAL` | 5 | `eval is required by build-time codegen; never reached at runtime` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

## When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

## Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not exploit-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op (record `cross-ref skipped: no allowlist file present`) but the step itself MUST be acknowledged in the SELF-CHECK trace.

---

## 11. REPORT FORMAT

```markdown
# Deploy Checklist Report — [Project Name]
Date: [date]
Version: [git commit hash]
Node.js: [version]
Runtime: [PM2/Docker]

## Summary

| Step | Status |
|------|--------|
| Build & TypeScript | pass/fail |
| ESLint | pass/fail |
| Tests | pass/fail |
| npm audit | pass/fail |
| Env vars | pass/fail |
| Database | pass/fail |
| Security | pass/fail |
| Deploy | pass/fail |
| Smoke tests | pass/fail |

**Readiness**: XX% — [READY/ACCEPTABLE/NOT READY]

## Blockers
- [If any]

## Warnings
- [If any]

## Post-Deploy
- [ ] Monitor logs for 24h
- [ ] Check error rate
- [ ] Verify memory usage stability
- [ ] Confirm background jobs running
```

---

## 12. ACTIONS

## 11. OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->

## Report Path

```text
.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md
```

- `<type>` is one of the 7 canonical slugs documented in the next section. Backward-compat aliases resolve to a canonical slug at dispatch time.
- Timestamp is local time, generated with `date '+%Y-%m-%d-%H%M'` (24-hour, no separator between hour and minute).
- The audit creates the directory with `mkdir -p .claude/audits` on first write.
- The toolkit does NOT auto-add `.claude/audits/` to `.gitignore` — let the user decide which audit reports to commit.

---

## Type Slug to Prompt File Map

| `/audit` argument | Report filename slug | Prompt loaded |
|-------------------|----------------------|---------------|
| `security` | `security` | `templates/<framework>/prompts/SECURITY_AUDIT.md` |
| `code-review` | `code-review` | `templates/<framework>/prompts/CODE_REVIEW.md` |
| `performance` | `performance` | `templates/<framework>/prompts/PERFORMANCE_AUDIT.md` |
| `deploy-checklist` | `deploy-checklist` | `templates/<framework>/prompts/DEPLOY_CHECKLIST.md` |
| `mysql-performance` | `mysql-performance` | `templates/<framework>/prompts/MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres-performance` | `postgres-performance` | `templates/<framework>/prompts/POSTGRES_PERFORMANCE_AUDIT.md` |
| `design-review` | `design-review` | `templates/<framework>/prompts/DESIGN_REVIEW.md` |

Backward-compat aliases: `code` resolves to `code-review` and `deploy` resolves to `deploy-checklist` at dispatch time. The report filename ALWAYS uses the canonical slug, never the alias.

---

## YAML Frontmatter

Every report opens with a YAML frontmatter block containing exactly these 7 keys:

```yaml
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 3
skipped_allowlist: 1
skipped_fp_recheck: 2
council_pass: pending
---
```

- `audit_type` — one of the 7 canonical slugs from the type map.
- `timestamp` — quoted `YYYY-MM-DD-HHMM` (the same string used in the report filename).
- `commit_sha` — `git rev-parse --short HEAD` output, or the literal string `none` when the project is not a git repo.
- `total_findings` — integer count of entries in the `## Findings` section.
- `skipped_allowlist` — integer count of rows in the `## Skipped (allowlist)` table.
- `skipped_fp_recheck` — integer count of rows in the `## Skipped (FP recheck)` table.
- `council_pass` — starts at `pending`. Phase 15's `/council audit-review` mutates this to `passed`, `failed`, or `disputed` after collating per-finding verdicts.

---

## Section Order (Fixed)

After the YAML frontmatter, the report MUST contain these five H2 sections in this exact order:

1. `## Summary`
2. `## Findings`
3. `## Skipped (allowlist)`
4. `## Skipped (FP recheck)`
5. `## Council verdict`

Plus the report's title H1 (`# <Type Title> Audit — <project name>`) immediately after the closing `---` of the frontmatter and before `## Summary`.

Do NOT reorder. Do NOT introduce intermediate H2 sections. Render an empty section as the literal placeholder `_None_` — the allowlist case uses a longer placeholder shown verbatim in the Skipped (allowlist) section below. Phase 15 navigates by these literal H2 headings.

---

## Summary Section

The Summary table has columns `severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck`, with one row per severity (CRITICAL, HIGH, MEDIUM, LOW). The rubric is in `components/severity-levels.md` — do not redefine. INFO is NOT a reportable finding severity; informational observations belong in the audit's scratchpad, never in `## Findings`. See the Full Report Skeleton below for the verbatim layout.

---

## Finding Entry Schema (### Finding F-NNN)

Each surviving finding becomes an `### Finding F-NNN` H3 block. `F-NNN` is zero-padded to 3 digits and sequential per report (`F-001`, `F-002`, ...). The 9 fields appear in this exact order:

1. **ID** — the `F-NNN` identifier matching the H3 heading.
2. **Severity** — one of CRITICAL, HIGH, MEDIUM, LOW (per `components/severity-levels.md`).
3. **Rule** — the auditor's rule-id (e.g. `SEC-SQL-INJECTION`, `PERF-N+1`).
4. **Location** — `<path>:<start>-<end>` for a range, or `<path>:<line>` for a single point.
5. **Claim** — one-sentence statement of the alleged issue, ≤ 160 chars.
6. **Code** — verbatim ±10 lines around the flagged line, fenced with the language matching the source extension (see Verbatim Code Block section).
7. **Data flow** — markdown bullet list tracing input from origin to the flagged sink, ≤ 6 hops.
8. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from in Phase 15.
9. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

See the Full Report Skeleton below for the verbatim entry template (a SQL-INJECTION example demonstrating all 9 fields).

The bullet labels (`**Severity:**`, `**Rule:**`, `**Location:**`, `**Claim:**`) and section labels (`**Code:**`, `**Data flow:**`, `**Why it is real:**`, `**Suggested fix:**`) are byte-exact — Phase 15's Council parser navigates the entry by them.

---

## Verbatim Code Block (AUDIT-03)

### Layout

```text
<!-- File: <path> Lines: <start>-<end> -->
[optional clamp note]
[fenced code block here with <lang> from the Extension Map]
```

`<lang>` is the language fence selected per the Extension to Language Fence Map below. `start = max(1, L - 10)` and `end = min(T, L + 10)` where `L` is the flagged line and `T` is the total line count of the file. The HTML range comment is the FIRST line above the fence; the clamp note (when present) is the SECOND line above the fence.

### Clamp Behaviour

When the ±10 range is clipped by the start or end of the file, emit a `<!-- Range clamped to file bounds (start-end) -->` note immediately above the fenced block. Example: flagged line 5 in an 8-line file → `start = max(1, 5-10) = 1`, `end = min(8, 5+10) = 8`, rendered range `1-8`, clamp note required.

### Extension to Language Fence Map

| Extension(s) | Fence |
|--------------|-------|
| `.ts`, `.tsx` | `ts` (or `tsx` for JSX-bearing files) |
| `.js`, `.jsx`, `.mjs`, `.cjs` | `js` |
| `.py` | `python` |
| `.sh`, `.bash`, `.zsh` | `bash` |
| `.rb` | `ruby` |
| `.go` | `go` |
| `.php` | `php` |
| `.md` | `markdown` |
| `.yml`, `.yaml` | `yaml` |
| `.json` | `json` |
| `.toml` | `toml` |
| `.html`, `.htm` | `html` |
| `.css`, `.scss`, `.sass` | `css` |
| `.sql` | `sql` |
| `.rs` | `rust` |
| `.java` | `java` |
| `.kt`, `.kts` | `kotlin` |
| `.swift` | `swift` |
| *unknown* | `text` |

The code block MUST be verbatim — no ellipses, no redaction, no `// ... rest of function` cuts. Council reasons from the actual code, not a paraphrase.

---

## Skipped (allowlist) Section

Columns: `ID | path:line | rule | council_status`. Empty-state placeholder is the literal string `_None — no` followed by a backtick-quoted `audit-exceptions.md` reference and `in this project_`. The verbatim layout is in the Full Report Skeleton below.

`council_status` is parsed from the matching entry's `**Council:**` bullet inside `audit-exceptions.md`. Allowed values: `unreviewed`, `council_confirmed_fp`, `disputed`. Use `sed '/^<!--/,/^-->/d'` (per `commands/audit-restore.md` post-13-05 fix) to strip HTML comment blocks before walking entries — the seed file ships with an HTML-commented example heading that would otherwise produce false matches. The `F-A001`..`F-ANNN` numbering is independent of `F-NNN` for surviving findings.

---

## Skipped (FP recheck) Section

Columns: `path:line | rule | dropped_at_step | one_line_reason`. Empty-state placeholder: `_None_`. The verbatim layout is in the Full Report Skeleton below.

`dropped_at_step` MUST be an integer in 1-6 matching the FP-recheck step where the finding was dropped (see `components/audit-fp-recheck.md`). `one_line_reason` MUST be ≤ 100 chars and reference concrete tokens visible in the source — never `looks fine`, `trusted code`, or `out of scope`.

---

## Council Verdict Slot (handoff to Phase 15)

The audit writes this section as a literal placeholder. Phase 15's `/council audit-review` mutates it in place after collating Gemini + ChatGPT verdicts.

```markdown
## Council verdict

_pending — run /council audit-review_
```

Byte-exact constraints: U+2014 em-dash (literal `—`, not hyphen-minus, not en-dash); single-underscore italic (`_..._`), no asterisks; no backticks, no bold, no code fence, no trailing whitespace. DO NOT REFORMAT — Phase 15 greps for this exact byte sequence to locate the slot before rewriting it.

---

## Full Report Skeleton

<output_format>

```text
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 1
skipped_allowlist: 1
skipped_fp_recheck: 1
council_pass: pending
---

# Security Audit — claude-code-toolkit

## Summary

| severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck |
|----------|----------------|-------------------------|--------------------------|
| HIGH | 1 | 1 | 1 |

## Findings

### Finding F-001

- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/users.ts:42
- **Claim:** User-supplied id flows into a string-concatenated SQL query without parameterization.

**Code:**

[fenced code block here — verbatim ±10 lines around src/users.ts:42, ts language fence]

**Data flow:**

- `req.params.id` arrives from the HTTP route handler.
- Passed unchanged into `db.query()`.
- No parameterized binding between origin and sink.

**Why it is real:**

The literal `db.query("SELECT * FROM users WHERE id=" + req.params.id)` concatenates an Express request parameter directly into the SQL string. The route is public, so an attacker can supply a malicious id and reach the sink unauthenticated.

**Suggested fix:**

[fenced code block here — replacement using parameterized query]

## Skipped (allowlist)

| ID | path:line | rule | council_status |
|----|-----------|------|----------------|
| F-A001 | lib/utils.py:5 | SEC-EVAL | unreviewed |

## Skipped (FP recheck)

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| src/legacy.js:14 | SEC-EVAL | 3 | eval guarded by isBuildTime(); never reached at runtime |

## Council verdict

_pending — run /council audit-review_
```

</output_format>

1. **Check** — go through the checklist
2. **Backup** — create database backup
3. **Deploy** — execute deployment script
4. **Verify** — run smoke tests and check logs
5. **Monitor** — watch metrics for 24 hours

Reply: "OK: Ready to deploy (XX%)" or "FAIL: Issues: [list]"

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
