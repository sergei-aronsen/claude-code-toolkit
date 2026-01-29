# Deploy Checklist — Python Template

## Goal

Comprehensive pre-deploy verification for a Python application (Django / FastAPI / Flask). Act as a Senior DevOps Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for pre-deploy checks — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Tests | `pytest --tb=short` | All pass |
| 2 | Type check | `mypy src/` | No errors |
| 3 | Linter | `ruff check .` | No errors |
| 4 | Formatter | `ruff format --check .` | No changes |
| 5 | App check | `python manage.py check` (Django) or startup test | No errors |
| 6 | Static files | `python manage.py collectstatic --noinput` (Django) | Success |
| 7 | Migrations | `python manage.py showmigrations` or `alembic history` | All applied |

**If all 7 = OK -> Ready to deploy!**

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# deploy-check.sh — run before deployment

set -e

echo "Pre-deploy Check for Python..."

# 1. Tests
pytest --tb=short -q > /dev/null 2>&1 && echo "OK Tests" || { echo "FAIL Tests"; exit 1; }

# 2. Type check
mypy src/ --no-error-summary > /dev/null 2>&1 && echo "OK Mypy" || echo "WARN Mypy has errors"

# 3. Lint
ruff check . > /dev/null 2>&1 && echo "OK Ruff lint" || echo "WARN Ruff lint errors"

# 4. Format check
ruff format --check . > /dev/null 2>&1 && echo "OK Ruff format" || echo "WARN Ruff format changes needed"

# 5. Django checks (skip if not Django)
if [ -f "manage.py" ]; then
    python manage.py check --deploy > /dev/null 2>&1 && echo "OK Django check" || echo "WARN Django check issues"
    python manage.py showmigrations --list 2>&1 | grep -q "\[ \]" && echo "WARN Unapplied migrations" || echo "OK Migrations"
fi

# 6. Debug code check
grep -rn "breakpoint()" src/ app/ --include="*.py" 2>/dev/null && echo "WARN breakpoint() found" || echo "OK No breakpoint()"
grep -rn "pdb.set_trace()" src/ app/ --include="*.py" 2>/dev/null && echo "WARN pdb found" || echo "OK No pdb"
grep -rn "import ipdb" src/ app/ --include="*.py" 2>/dev/null && echo "WARN ipdb found" || echo "OK No ipdb"

# 7. Dependency audit
pip-audit > /dev/null 2>&1 && echo "OK No vulnerable packages" || echo "WARN Vulnerable packages found"

echo ""
echo "Pre-deploy check complete!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Deployment target:**

- **Server**: [IP/hostname]
- **Path**: [/opt/app or /var/www/app]
- **URL**: [https://...]
- **Process manager**: [systemd / Supervisor]
- **WSGI/ASGI server**: [gunicorn / uvicorn / daphne]

**Database:**

- **Type**: [PostgreSQL / MySQL / SQLite]
- **Host**: [host]
- **Name**: [db_name]
- **Connection**: see `DATABASE_URL` in `.env`

**Background tasks:**

- **Celery broker**: [Redis / RabbitMQ]
- **Celery beat**: [yes / no]
- **Other workers**: [list]

**Important files:**

- `.env` — environment variables
- `requirements.txt` / `pyproject.toml` — dependencies
- `/etc/supervisor/conf.d/[app].conf` — Supervisor config (if used)
- `/etc/systemd/system/[app].service` — systemd unit (if used)

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
# Python debug statements
grep -rn "print(" src/ app/ --include="*.py" | grep -v "# noqa" | grep -v "__str__" | grep -v "logging"
grep -rn "breakpoint()" src/ app/ --include="*.py"
grep -rn "pdb.set_trace()" src/ app/ --include="*.py"
grep -rn "import pdb" src/ app/ --include="*.py"
grep -rn "import ipdb" src/ app/ --include="*.py"
grep -rn "ipdb.set_trace()" src/ app/ --include="*.py"
grep -rn "ic(" src/ app/ --include="*.py"
grep -rn "import icecream" src/ app/ --include="*.py"
grep -rn "DEBUG\s*=\s*True" src/ app/ config/ --include="*.py" | grep -v "settings/local"
```

- [ ] No stray `print()` statements (use `logging` instead)
- [ ] No `breakpoint()` calls
- [ ] No `pdb.set_trace()` or `ipdb.set_trace()`
- [ ] No `icecream` / `ic()` calls
- [ ] No `DEBUG = True` in production settings

### 1.2 TODO/FIXME

```bash
grep -rn "TODO\|FIXME\|HACK\|XXX" src/ app/ --include="*.py"
```

- [ ] Critical TODOs resolved
- [ ] No blocking FIXMEs
- [ ] No HACK markers in critical paths

### 1.3 Commented Code

- [ ] No commented-out code blocks
- [ ] No old function versions left in comments
- [ ] No `# type: ignore` without explanation

---

## 2. CODE QUALITY CHECKS

### 2.1 Tests

```bash
# Run full test suite
pytest -v --tb=short

# With coverage
pytest --cov=src --cov-report=term-missing --cov-fail-under=80

# Run only unit tests (fast)
pytest tests/unit/ -v

# Run integration tests
pytest tests/integration/ -v

# Django-specific
python manage.py test --verbosity=2
```

- [ ] All tests pass
- [ ] No skipped tests without `@pytest.mark.skip(reason="...")`
- [ ] Coverage >= 80% for critical modules
- [ ] Integration tests pass against staging DB

### 2.2 Static Analysis

```bash
# Type checking
mypy src/ --strict
mypy src/ --show-error-codes

# Linting
ruff check .
ruff check . --select=ALL  # extended rules

# Code formatting
ruff format --check .
black --check .
isort --check-only .

# Security-focused linting
bandit -r src/ -ll
```

- [ ] `mypy` passes without errors (or only known exclusions)
- [ ] `ruff check` clean (no errors)
- [ ] Code formatted with `ruff format` or `black` + `isort`
- [ ] `bandit` shows no high-severity issues

### 2.3 Build / Application Startup

```bash
# Django
python manage.py check
python manage.py check --deploy

# FastAPI — verify app loads
python -c "from src.main import app; print('App loaded OK')"

# Flask — verify app factory
python -c "from src.app import create_app; app = create_app(); print('App loaded OK')"

# General — verify imports
python -c "import src; print('Package imports OK')"
```

- [ ] Application starts without import errors
- [ ] Django `check --deploy` passes (or known warnings documented)
- [ ] No circular imports

---

## 3. DATABASE PREPARATION

### 3.1 Migrations

**Django:**

```bash
# Review migration status
python manage.py showmigrations

# Preview SQL that will run
python manage.py sqlmigrate [app_name] [migration_number]

# Dry run
python manage.py migrate --plan

# Check for missing migrations
python manage.py makemigrations --check --dry-run
```

**Alembic (FastAPI / Flask):**

```bash
# Check current revision
alembic current

# Show pending migrations
alembic history --indicate-current

# Preview upgrade SQL
alembic upgrade head --sql

# Check for autogenerate differences
alembic check
```

```python
# Good — safe migration with nullable column
# Django
from django.db import migrations, models

class Migration(migrations.Migration):
    operations = [
        migrations.AddField(
            model_name="user",
            name="phone",
            field=models.CharField(max_length=20, null=True, blank=True),
        ),
    ]

# Bad — NOT NULL without default will break existing rows
migrations.AddField(
    model_name="user",
    name="phone",
    field=models.CharField(max_length=20),  # Will fail on existing data!
)
```

```python
# Good — Alembic with rollback support
def upgrade() -> None:
    op.add_column("users", sa.Column("phone", sa.String(20), nullable=True))

def downgrade() -> None:
    op.drop_column("users", "phone")
```

- [ ] All migrations have `downgrade()` / reverse operations
- [ ] New NOT NULL columns have `default` or `nullable=True`
- [ ] Indexes added for new foreign keys and frequently queried columns
- [ ] No destructive operations without explicit confirmation
- [ ] `makemigrations --check` reports no missing migrations

### 3.2 Seeders Check

```python
# Bad — will delete production data!
class Command(BaseCommand):
    def handle(self, *args, **options):
        User.objects.all().delete()  # NEVER in production!

# Good — environment guard
class Command(BaseCommand):
    def handle(self, *args, **options):
        if not settings.DEBUG:
            self.stderr.write("Cannot seed in production!")
            return
```

- [ ] Seeders DO NOT run in production
- [ ] No `.delete()` / `truncate()` without environment check
- [ ] Fixtures are not loaded automatically

### 3.3 Backup

```bash
# PostgreSQL backup
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME -F c -f "backup_$(date +%Y%m%d_%H%M%S).dump"

# MySQL backup
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME > "backup_$(date +%Y%m%d_%H%M%S).sql"

# SQLite backup (if applicable)
cp db.sqlite3 "db_backup_$(date +%Y%m%d_%H%M%S).sqlite3"

# Verify backup
pg_restore --list "backup_*.dump" | head -20
```

- [ ] Database backup created before migrations
- [ ] Backup verified for restorability
- [ ] Backup stored in a safe location (not on the same server)

---

## 4. ENVIRONMENT CONFIGURATION

### 4.1 Production Environment

**Django settings:**

```ini
# .env — REQUIRED production settings
DJANGO_SETTINGS_MODULE=config.settings.production
DEBUG=False
SECRET_KEY=<strong-random-key-min-50-chars>
ALLOWED_HOSTS=your-domain.com,www.your-domain.com
CSRF_TRUSTED_ORIGINS=https://your-domain.com

DATABASE_URL=postgres://user:password@host:5432/dbname
REDIS_URL=redis://localhost:6379/0

# Email
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.provider.com

# Logging
LOG_LEVEL=WARNING

# Security
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
SECURE_HSTS_SECONDS=31536000
```

**FastAPI / Flask settings:**

```ini
# .env — REQUIRED production settings
APP_ENV=production
DEBUG=False
SECRET_KEY=<strong-random-key-min-50-chars>
DATABASE_URL=postgres://user:password@host:5432/dbname
REDIS_URL=redis://localhost:6379/0
CORS_ORIGINS=https://your-domain.com
LOG_LEVEL=WARNING
WORKERS=4
```

- [ ] `DEBUG=False` (CRITICAL)
- [ ] `SECRET_KEY` is strong and unique (not default)
- [ ] `ALLOWED_HOSTS` / `CORS_ORIGINS` set correctly
- [ ] `DATABASE_URL` points to production database
- [ ] `LOG_LEVEL` is `WARNING` or `ERROR` (not `DEBUG`)
- [ ] SSL/HTTPS settings enabled
- [ ] Session and CSRF cookies set to secure
- [ ] Email backend configured (not console backend)

### 4.2 Secrets Check

```bash
# Check for hardcoded secrets in source code
grep -rn "password\s*=" src/ app/ --include="*.py" | grep -v "test" | grep -v "#"
grep -rn "secret_key\s*=" src/ app/ config/ --include="*.py" | grep -v "os.environ\|os.getenv\|settings\."
grep -rn "sk-\|pk-\|api_key\s*=" src/ app/ --include="*.py"
grep -rn "BEGIN RSA PRIVATE KEY\|BEGIN PRIVATE KEY" src/ app/ --include="*.py"

# Verify .env is not tracked by git
git ls-files --error-unmatch .env 2>/dev/null && echo "DANGER: .env is tracked!" || echo "OK .env not tracked"

# Verify .gitignore includes sensitive patterns
grep -q "\.env" .gitignore && echo "OK .env in gitignore" || echo "WARN .env not in gitignore"
grep -q "\.pem" .gitignore && echo "OK .pem in gitignore" || echo "WARN .pem not in gitignore"
```

- [ ] No hardcoded passwords or API keys
- [ ] `SECRET_KEY` loaded from environment variable
- [ ] `.env` is in `.gitignore`
- [ ] No private keys committed to repository
- [ ] All secrets managed via environment variables or vault

---

## 5. BUILD PROCESS

### 5.1 Dependencies

```bash
# pip + requirements.txt
pip install -r requirements.txt --no-deps --dry-run
pip install -r requirements/production.txt

# Poetry
poetry install --no-dev --no-interaction
poetry export -f requirements.txt --without-hashes -o requirements.txt

# uv
uv sync --no-dev
uv pip compile pyproject.toml -o requirements.txt

# Verify no dev dependencies leak into production
pip list | grep -iE "pytest|ipdb|debug|devtools"
```

- [ ] Production dependencies install cleanly
- [ ] No dev-only packages in production (`pytest`, `ipdb`, `debugpy`, etc.)
- [ ] `requirements.txt` or lock file is up-to-date
- [ ] Python version matches production (check `python --version`)

### 5.2 Static Files (Django)

```bash
# Collect static files
python manage.py collectstatic --noinput

# Verify static files directory
ls -la staticfiles/ || ls -la static/

# Check STATIC_ROOT is set
python -c "from django.conf import settings; print(settings.STATIC_ROOT)"

# Verify whitenoise or nginx serves statics
python -c "from django.conf import settings; print('whitenoise' in str(settings.MIDDLEWARE))"
```

- [ ] `collectstatic` runs without errors
- [ ] `STATIC_ROOT` is configured
- [ ] Static file serving is configured (whitenoise / nginx / CDN)
- [ ] Media files directory has correct permissions

### 5.3 Docker Build (if applicable)

```bash
# Build production image
docker build -t app:latest --target production .

# Test the image
docker run --rm app:latest python -c "import src; print('OK')"

# Check image size
docker images app:latest --format "{{.Size}}"
```

- [ ] Docker image builds successfully
- [ ] Image uses multi-stage build (no dev dependencies in final image)
- [ ] Non-root user configured in Dockerfile
- [ ] Health check defined

---

## 6. SECURITY PRE-CHECK

### 6.1 Sensitive Files

```bash
# Files that must NOT be accessible via web
ls -la .env .env.* 2>/dev/null
ls -la *.pem *.key 2>/dev/null
ls -la settings_local.py local_settings.py 2>/dev/null

# Verify .gitignore covers sensitive files
cat .gitignore | grep -E "\.env|\.pem|\.key|__pycache__|\.pyc|local_settings"
```

- [ ] `.env` not accessible via web
- [ ] `.git/` not accessible via web
- [ ] No `*.pem` / `*.key` files in repository
- [ ] No `settings_local.py` or `local_settings.py` committed
- [ ] `__pycache__` and `*.pyc` in `.gitignore`

### 6.2 Dependencies Audit

```bash
# pip-audit (recommended)
pip-audit

# safety (alternative)
safety check

# Check for known vulnerabilities in requirements
pip-audit -r requirements.txt

# Bandit — Python security linter
bandit -r src/ -ll --format json
```

- [ ] `pip-audit` or `safety check` — no critical/high vulnerabilities
- [ ] `bandit` — no high-severity findings
- [ ] Dependencies are reasonably up-to-date

### 6.3 Django Security Checklist

```bash
# Django's built-in security checker
python manage.py check --deploy

# Expected output covers:
# - SECURE_HSTS_SECONDS
# - SECURE_SSL_REDIRECT
# - SESSION_COOKIE_SECURE
# - CSRF_COOKIE_SECURE
# - SECURE_BROWSER_XSS_FILTER
# - X_FRAME_OPTIONS
# - SECURE_CONTENT_TYPE_NOSNIFF
# - DEBUG = False
```

**FastAPI / Flask security:**

```python
# Verify CORS is restricted
# Bad
app.add_middleware(CORSMiddleware, allow_origins=["*"])

# Good
app.add_middleware(CORSMiddleware, allow_origins=["https://your-domain.com"])
```

- [ ] `manage.py check --deploy` passes (Django)
- [ ] CORS not set to `*` in production
- [ ] Rate limiting configured (slowapi / django-ratelimit)
- [ ] HTTPS enforced
- [ ] Security headers set (X-Frame-Options, Content-Type-Options, HSTS)

### 6.4 File Permissions

```bash
# Application directory
chmod -R 750 /opt/app/
chown -R app:app /opt/app/

# Sensitive files
chmod 600 /opt/app/.env
chmod 600 /opt/app/*.pem 2>/dev/null

# Log directory
chmod 755 /var/log/app/
chown app:app /var/log/app/

# Media/upload directory (Django)
chmod 755 /opt/app/media/
chown app:www-data /opt/app/media/
```

- [ ] Application directory owned by application user (not root)
- [ ] `.env` file readable only by application user (600)
- [ ] Log directory writable by application user
- [ ] Media/upload directory has correct ownership

---

## 7. DEPLOYMENT COMMANDS

### 7.1 Full Deploy Script

```bash
#!/bin/bash
set -e

APP_DIR="/opt/app"
VENV_DIR="$APP_DIR/venv"
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
APP_USER="app"

echo "=== Deployment started at $(date) ==="

cd "$APP_DIR"

# 1. Maintenance mode (optional — use load balancer or maintenance page)
touch "$APP_DIR/maintenance.flag"

# 2. Backup database
source "$APP_DIR/.env"
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -F c -f "$BACKUP_DIR/db_$DATE.dump"
echo "Database backup: $BACKUP_DIR/db_$DATE.dump"

# 3. Pull latest code
sudo -u "$APP_USER" git pull origin main

# 4. Activate virtual environment
source "$VENV_DIR/bin/activate"

# 5. Install dependencies
pip install -r requirements.txt --no-cache-dir

# 6. Collect static files (Django)
if [ -f "manage.py" ]; then
    python manage.py collectstatic --noinput
fi

# 7. Run database migrations
if [ -f "manage.py" ]; then
    python manage.py migrate --noinput
else
    alembic upgrade head
fi

# 8. Restart application server
sudo systemctl restart gunicorn
# OR for uvicorn:
# sudo systemctl restart uvicorn
# OR for Supervisor:
# sudo supervisorctl restart app

# 9. Restart Celery workers (if used)
sudo systemctl restart celery-worker
sudo systemctl restart celery-beat
# OR for Supervisor:
# sudo supervisorctl restart celery-worker celery-beat

# 10. Remove maintenance flag
rm -f "$APP_DIR/maintenance.flag"

echo "=== Deployment completed at $(date) ==="

# 11. Health check
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://your-domain.com/health/)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Health check passed (HTTP $HTTP_CODE)"
else
    echo "ALERT: Health check failed (HTTP $HTTP_CODE)"
    exit 1
fi

# 12. Verify Celery is processing
if command -v celery &> /dev/null; then
    celery -A config inspect ping > /dev/null 2>&1 && echo "Celery workers responding" || echo "WARN: Celery not responding"
fi
```

### 7.2 Docker Deploy Script

```bash
#!/bin/bash
set -e

IMAGE="registry.example.com/app"
TAG=$(git rev-parse --short HEAD)

echo "=== Docker deployment: $IMAGE:$TAG ==="

# 1. Build and push
docker build -t "$IMAGE:$TAG" -t "$IMAGE:latest" .
docker push "$IMAGE:$TAG"
docker push "$IMAGE:latest"

# 2. Run migrations
docker run --rm --env-file .env.production "$IMAGE:$TAG" python manage.py migrate --noinput

# 3. Collect static files
docker run --rm --env-file .env.production -v static_volume:/app/staticfiles "$IMAGE:$TAG" python manage.py collectstatic --noinput

# 4. Deploy with docker compose
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d --remove-orphans

# 5. Health check
sleep 10
curl -sf https://your-domain.com/health/ > /dev/null && echo "Health check passed" || echo "ALERT: Health check failed"

echo "=== Docker deployment complete ==="
```

---

## 8. POST-DEPLOYMENT VERIFICATION

### 8.1 Smoke Tests

```bash
# Basic endpoint checks
curl -I https://your-domain.com/
curl -I https://your-domain.com/health/
curl -I https://your-domain.com/api/v1/status/
curl -I https://your-domain.com/admin/login/  # Django admin

# API response check
curl -s https://your-domain.com/api/v1/status/ | python -m json.tool

# SSL certificate check
echo | openssl s_client -connect your-domain.com:443 2>/dev/null | openssl x509 -noout -dates

# Response time check
curl -w "DNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" \
     -o /dev/null -s https://your-domain.com/
```

Check manually:

- [ ] Homepage / API root loads
- [ ] Authentication works (login / token endpoint)
- [ ] Admin panel accessible (Django)
- [ ] API endpoints respond correctly
- [ ] Background tasks are processing (Celery)
- [ ] WebSocket connections work (if applicable)

### 8.2 Error Monitoring

```bash
# Application logs
journalctl -u gunicorn --since "10 minutes ago" --no-pager | grep -iE "error|exception|traceback"
# OR
tail -100 /var/log/app/error.log

# Gunicorn / uvicorn access log
tail -50 /var/log/app/access.log

# Celery logs
journalctl -u celery-worker --since "10 minutes ago" --no-pager | grep -iE "error|exception"

# Celery task status
celery -A config inspect active
celery -A config inspect reserved
celery -A config inspect stats

# Django failed tasks (django-celery-results)
python manage.py shell -c "from django_celery_results.models import TaskResult; print(TaskResult.objects.filter(status='FAILURE').count())"

# Check Sentry for new issues (if configured)
# Visit: https://sentry.io/organizations/[org]/issues/?query=is:unresolved+firstSeen:-1h
```

- [ ] No new errors in application logs
- [ ] No new exceptions in Sentry / error tracker
- [ ] Celery workers are alive and processing
- [ ] No failed Celery tasks since deployment
- [ ] Response times are normal
- [ ] Error rate has not increased

---

## 9. ROLLBACK PLAN

### 9.1 Quick Rollback

```bash
#!/bin/bash
set -e

APP_DIR="/opt/app"
VENV_DIR="$APP_DIR/venv"

echo "=== ROLLBACK STARTED ==="

cd "$APP_DIR"

# 1. Stop application
sudo systemctl stop gunicorn
sudo systemctl stop celery-worker celery-beat

# 2. Rollback code
git log --oneline -5  # show recent commits
git reset --hard HEAD~1

# 3. Reinstall dependencies (in case they changed)
source "$VENV_DIR/bin/activate"
pip install -r requirements.txt --no-cache-dir

# 4. Rollback migrations (if needed)
# Django:
# python manage.py migrate [app_name] [previous_migration_number]
# Alembic:
# alembic downgrade -1

# 5. Collect static files
if [ -f "manage.py" ]; then
    python manage.py collectstatic --noinput
fi

# 6. Restart services
sudo systemctl start gunicorn
sudo systemctl start celery-worker celery-beat

echo "=== ROLLBACK COMPLETED ==="

# 7. Health check
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://your-domain.com/health/)
echo "Health check: HTTP $HTTP_CODE"
```

### 9.2 Database Rollback

```bash
# Restore PostgreSQL from backup
pg_restore -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" --clean --if-exists "$BACKUP_DIR/db_YYYYMMDD_HHMMSS.dump"

# Restore MySQL from backup
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$BACKUP_DIR/db_YYYYMMDD_HHMMSS.sql"

# Django migration rollback (without full DB restore)
python manage.py migrate [app_name] [previous_migration_number]

# Alembic migration rollback
alembic downgrade -1
```

### 9.3 Rollback Triggers

Rollback immediately if:

- Error rate > 5% after deployment
- Critical functionality is broken (auth, payments, core API)
- Database corruption or data loss
- Celery workers crash repeatedly
- Memory or CPU usage spikes abnormally
- Health check endpoint fails

---

## 10. SELF-CHECK

**DO NOT block deploy because of:**

| Seems like a blocker | Why it is not a blocker |
| -------------------- | ---------------------- |
| "Mypy warnings on third-party stubs" | Type stubs are imperfect — if code works, OK |
| "Ruff warnings (not errors)" | Warnings are advisory, not blocking |
| "Deprecated package" | If it works — update in next sprint |
| "Coverage below 80%" | If critical paths are tested — OK |
| "print() in management commands" | Management commands may use print legitimately |
| "No type hints in tests" | Test code has lower typing requirements |
| "TODO in non-critical code" | Track in issue tracker, not a deploy blocker |

**Readiness levels:**

```text
READY (95-100%) — Deploy now
   - All tests pass
   - No security blockers
   - Migrations reviewed
   - DEBUG=False confirmed

ACCEPTABLE (70-94%) — Deploy possible
   - Has warnings but not errors
   - Minor issues can be fixed after deploy
   - Non-critical TODOs remain

NOT READY (<70%) — Block deployment
   - Tests fail
   - Security vulnerabilities (critical/high)
   - DEBUG=True in production
   - Missing database migrations
   - Application fails to start
```

---

## 11. REPORT FORMAT

```markdown
# Deploy Checklist Report — [Project Name]
Date: [date]
Version: [git commit hash]
Python: [python version]
Framework: [Django X.Y / FastAPI X.Y / Flask X.Y]

## Summary

| Step | Status |
|------|--------|
| Tests | OK/FAIL |
| Type check | OK/FAIL |
| Lint | OK/FAIL |
| Security audit | OK/FAIL |
| Migrations | OK/FAIL |
| Env config | OK/FAIL |
| Dependencies | OK/FAIL |
| Backup | OK/FAIL |
| Deploy | OK/FAIL |
| Smoke tests | OK/FAIL |

**Readiness**: XX% — [READY/ACCEPTABLE/NOT READY]

## Blockers

- [If any]

## Warnings

- [If any]

## Post-Deploy

- [ ] Monitor logs for 24h
- [ ] Check Celery task queue
- [ ] Verify error rate in Sentry
- [ ] Check response times
```

---

## 12. ACTIONS

1. **Check** -- go through the checklist section by section
2. **Backup** -- create database backup and verify restorability
3. **Deploy** -- execute the deployment script
4. **Verify** -- run smoke tests and check monitoring
5. **Monitor** -- watch logs, error rates, and Celery status for 24 hours

Reply: "OK: Ready to deploy (XX%)" or "FAIL: Issues: [list]"
