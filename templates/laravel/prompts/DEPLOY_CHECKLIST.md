# Deploy Checklist — Laravel Template

## Goal

Comprehensive check before deploying a Laravel application. Act as a Senior DevOps Engineer.

> **⚠️ Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for pre-deploy checks — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | PHP Syntax | `php artisan --version` | No errors |
| 2 | Pint | `./vendor/bin/pint --test` | No changes |
| 3 | PHPStan | `./vendor/bin/phpstan analyse` | Level passed |
| 4 | Tests | `php artisan test` | Pass |
| 5 | Build | `npm run build` | Success |
| 6 | Migrations | `php artisan migrate --pretend` | Expected changes |

**If all 6 = OK → Ready to deploy!**

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# deploy-check.sh — run before deployment

set -e

echo "Pre-deploy Check for Laravel..."

# 1. PHP Artisan
php artisan --version > /dev/null 2>&1 && echo "✅ PHP Artisan" || { echo "❌ PHP Artisan"; exit 1; }

# 2. Pint
./vendor/bin/pint --test > /dev/null 2>&1 && echo "✅ Pint" || echo "🟡 Pint has changes"

# 3. PHPStan
./vendor/bin/phpstan analyse 2>&1 | grep -q "error" && echo "🟡 PHPStan errors" || echo "✅ PHPStan"

# 4. Tests
php artisan test --stop-on-failure > /dev/null 2>&1 && echo "✅ Tests" || echo "🟡 Tests failed"

# 5. NPM Build
npm run build > /dev/null 2>&1 && echo "✅ Build" || { echo "❌ Build"; exit 1; }

# 6. Debug code check
grep -rn "dd(" app/ routes/ | grep -v ".blade.php" && echo "🟡 dd() found" || echo "✅ No dd()"
grep -rn "dump(" app/ routes/ && echo "🟡 dump() found" || echo "✅ No dump()"

echo ""
echo "Ready to deploy!"
```text

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Deployment target:**

- **Server**: [IP/hostname]
- **Path**: [/path/to/app]
- **URL**: [https://...]
- **Process manager**: [PM2/Supervisor/systemd]

**Database:**

- **Name**: [db_name]
- **User**: [db_user]
- **Password**: see `.env` → `DB_PASSWORD`

**Important files:**

- `.env` — environment variables
- `/etc/supervisor/conf.d/...` — Supervisor config (if exists)

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
grep -rn "dd(" app/ resources/ routes/
grep -rn "dump(" app/ resources/ routes/
grep -rn "var_dump" app/ resources/
grep -rn "console.log" resources/js/
```text

- [ ] No `dd()`, `dump()`, `var_dump()`
- [ ] No `console.log()` in production
- [ ] No `Log::debug()` with sensitive data

### 1.2 Commented Code

- [ ] No commented out code
- [ ] No `// TODO: remove` blocks

### 1.3 Temporary Files

```bash
find . -name "*.bak" -o -name "*.tmp" -o -name "*.old"
```text

- [ ] No `.bak`, `.tmp`, `.old` files

---

## 2. CODE QUALITY CHECKS

### 2.1 Tests

```bash
php artisan test
php artisan test --coverage --min=80
```text

- [ ] All tests pass
- [ ] No skipped tests without reason
- [ ] Critical functionality covered

### 2.2 Static Analysis

```bash
./vendor/bin/phpstan analyse --memory-limit=2G
./vendor/bin/pint --test
```text

- [ ] PHPStan without errors
- [ ] Code style OK

### 2.3 Build

```bash
npm ci && npm run build
```text

- [ ] Build passes without errors

---

## 3. DATABASE PREPARATION

### 3.1 Migrations Review

```bash
php artisan migrate:status
php artisan migrate --pretend
php artisan migrate:rollback --pretend
```text

```php
// ✅ Good — safe changes
Schema::table('sites', function (Blueprint $table) {
    $table->string('new_column')->nullable();  // nullable for existing records
});

// ❌ Dangerous — NOT NULL without default
$table->string('required_column');  // Will break existing records!
```text

- [ ] All migrations have `down()` method
- [ ] New NOT NULL columns have default or nullable
- [ ] Indexes added for new foreign keys
- [ ] Rollback works

### 3.2 Seeders Check

```php
// ❌ CRITICAL — will delete production data!
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Site::truncate();  // NEVER in production!
    }
}

// ✅ Safe — environment check
if (app()->environment('production')) {
    $this->command->error('Cannot seed in production!');
    return;
}
```text

- [ ] Seeders don't run in production
- [ ] No `truncate()` without environment check

### 3.3 Backup

```bash
# Backup before migrations
mysqldump -u $DB_USERNAME -p$DB_PASSWORD $DB_DATABASE > backup_$(date +%Y%m%d_%H%M%S).sql
```text

- [ ] DB backup created before migrations
- [ ] Backup verified for restorability

---

## 4. ENVIRONMENT CONFIGURATION

### 4.1 Production .env

```ini
# REQUIRED settings
APP_NAME=[Name]
APP_ENV=production          # NOT local!
APP_DEBUG=false             # NOT true!
APP_URL=https://[domain]

LOG_LEVEL=error             # Not debug in production

CACHE_DRIVER=redis          # Not file in production
SESSION_DRIVER=redis        # Not file in production
QUEUE_CONNECTION=redis      # Not sync in production

SESSION_SECURE_COOKIE=true
```text

- [ ] `APP_ENV=production`
- [ ] `APP_DEBUG=false`
- [ ] `APP_URL` — correct URL with HTTPS
- [ ] `LOG_LEVEL` — not `debug`
- [ ] `CACHE_DRIVER` — redis (not file)
- [ ] `SESSION_DRIVER` — redis (not file)
- [ ] `QUEUE_CONNECTION` — redis (not sync)

### 4.2 Config Cache Compatibility

```bash
# Find env() outside config/
grep -rn "env(" app/ routes/ resources/ --include="*.php" | grep -v "config/"
```text

- [ ] No `env()` calls outside `config/` directory
- [ ] `php artisan config:cache` works

---

## 5. BUILD PROCESS

### 5.1 Composer Production

```bash
composer install --no-dev --optimize-autoloader --no-interaction
```text

- [ ] `composer install --no-dev` successful
- [ ] No missing dependencies

### 5.2 NPM Production Build

```bash
rm -rf node_modules
npm ci
npm run build
```text

- [ ] `npm ci` successful
- [ ] `npm run build` successful
- [ ] Bundle size reasonable (< 500KB gzipped)

---

## 6. SECURITY PRE-CHECK

### 6.1 Sensitive Files

- [ ] `.env` not accessible via web
- [ ] `.git/` not accessible via web
- [ ] `storage/logs/` not accessible via web

### 6.2 File Permissions

```bash
chmod -R 755 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
```text

- [ ] `storage/` — 755, owner www-data
- [ ] `bootstrap/cache/` — 755, owner www-data

### 6.3 Dependencies Audit

```bash
composer audit
npm audit
```text

- [ ] `composer audit` — no critical/high vulnerabilities
- [ ] `npm audit` — no critical/high vulnerabilities

---

## 7. DEPLOYMENT COMMANDS

### 7.1 Full Deploy Script

```bash
#!/bin/bash
set -e

APP_DIR="/var/www/[app]"
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

cd $APP_DIR

# 1. Maintenance mode
php artisan down --secret="deploy-$DATE"

# 2. Backup database
source .env
mysqldump -u $DB_USERNAME -p$DB_PASSWORD $DB_DATABASE > "$BACKUP_DIR/db_$DATE.sql"

# 3. Pull code
git pull origin main

# 4. Install PHP dependencies
composer install --no-dev --optimize-autoloader --no-interaction

# 5. Build assets
npm ci && npm run build

# 6. Run migrations
php artisan migrate --force

# 7. Clear and cache
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

# 8. Restart queues
php artisan queue:restart
supervisorctl restart [worker-name]:  # if using Supervisor

# 9. Permissions
chown -R www-data:www-data storage bootstrap/cache
chmod -R 755 storage bootstrap/cache

# 10. Disable maintenance
php artisan up

echo "Deployment completed!"

# 11. Health check
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://[domain])
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Health check passed!"
else
    echo "Health check failed! HTTP: $HTTP_CODE"
    exit 1
fi
```text

---

## 8. POST-DEPLOYMENT VERIFICATION

### 8.1 Smoke Tests

```bash
curl -I https://[domain]
curl -I https://[domain]/login
curl -I https://[domain]/api/health
```text

- [ ] Homepage loads
- [ ] Login works
- [ ] Dashboard displays
- [ ] Main functionality works
- [ ] Queues are processing

### 8.2 Error Monitoring

```bash
tail -f storage/logs/laravel.log
grep -i "error\|exception\|fatal" storage/logs/laravel.log | tail -20
php artisan queue:failed
```text

- [ ] No new errors in logs
- [ ] No failed jobs
- [ ] Error rate didn't increase

---

## 9. ROLLBACK PLAN

### 9.1 Quick Rollback

```bash
#!/bin/bash
set -e

cd /var/www/[app]

php artisan down
git reset --hard HEAD~1

# Restore database if needed
# source .env
# mysql -u $DB_USERNAME -p$DB_PASSWORD $DB_DATABASE < /opt/backups/db_YYYYMMDD_HHMMSS.sql

composer install --no-dev --optimize-autoloader
npm ci && npm run build

php artisan config:cache
php artisan route:cache
php artisan view:cache

php artisan queue:restart
php artisan up

echo "Rollback completed!"
```text

### 9.2 Rollback Triggers

Rollback if:

- Error rate > 5% after deploy
- Critical functionality doesn't work
- Database corruption

---

## 10. SELF-CHECK

**DO NOT block deploy because of:**

| Seems like blocker | Why not a blocker |
| ------------------ | ------------------ |
| "PHPStan warnings" | If code works — OK |
| "Deprecated package" | If works — update later |
| "No tests" | If functionality works — OK |
| "console.log in code" | Doesn't affect users |
| "Pint shows changes" | Code style is not a blocker |

**Readiness levels:**

```text
READY (95-100%) — Deploy now
ACCEPTABLE (70-94%) — Deploy possible
NOT READY (<70%) — Block
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

## 12. ACTIONS

1. **Check** — go through checklist
2. **Backup** — create backup
3. **Deploy** — execute deployment
4. **Verify** — check that it works
5. **Monitor** — watch logs

Reply: "OK: Ready to deploy (XX%)" or "FAIL: Issues: [list]"
