# Deploy Checklist — Node.js Template

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

## 10. SELF-CHECK

**DO NOT block deploy because of:**

| Seems like a blocker | Why it is not a blocker |
| ------------------ | ------------------ |
| "ESLint warnings" | If build passes and code works — OK |
| "Deprecated package" | If it works — update later |
| "console.log in code" | Not critical for users |
| "No 100% test coverage" | If critical paths are covered — OK |
| "npm audit low/moderate" | Low/moderate are not blockers |
| "TypeScript strict warnings" | If build passes — OK |
| "Bundle slightly larger" | If within 2x of previous — acceptable |
| "Missing JSDoc comments" | Documentation is not a deploy blocker |

**Readiness levels:**

```text
READY (95-100%) — Deploy now
   - Build passes
   - Tests pass
   - No critical security issues
   - Environment configured

ACCEPTABLE (70-94%) — Deploy possible
   - Minor warnings present
   - Non-critical tests skipped
   - Low/moderate audit findings

NOT READY (<70%) — Block
   - Build fails
   - Critical tests fail
   - High/critical vulnerabilities
   - Missing required env vars
   - Database migration errors
```

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

1. **Check** — go through the checklist
2. **Backup** — create database backup
3. **Deploy** — execute deployment script
4. **Verify** — run smoke tests and check logs
5. **Monitor** — watch metrics for 24 hours

Reply: "OK: Ready to deploy (XX%)" or "FAIL: Issues: [list]"
