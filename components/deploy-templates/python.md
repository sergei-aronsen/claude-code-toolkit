# Deploy Templates — Python

Operational runbook templates for deploying a Python service (Django,
FastAPI, Flask): dependency install, static files, deploy scripts,
Celery inspection, Alembic rollback. Consumed via the base
`DEPLOY_CHECKLIST.md` → `Stack Specifics → Python` reference.

These are **templates**, not a checklist. The pre-deploy decision gates
(baseline metrics, auth/crypto, CSRF, post-deploy comparison, rollback
triggers, time boundaries) live in
`templates/base/prompts/DEPLOY_CHECKLIST.md` — consult that file first.

---

## Dependency Install

```bash
# pip + requirements.txt
pip install -r requirements/production.txt --no-cache-dir

# Poetry
poetry install --no-dev --no-interaction

# uv
uv sync --no-dev

# Verify no dev dependencies leaked into production
pip list | grep -iE "pytest|ipdb|debugpy|devtools" && echo "DEV LEAK" || echo "OK"
```

---

## Static Files (Django)

```bash
python manage.py collectstatic --noinput
python -c "from django.conf import settings; print(settings.STATIC_ROOT)"

# Verify serving (WhiteNoise / nginx / CDN)
python -c "from django.conf import settings; print('whitenoise' in str(settings.MIDDLEWARE))"
```

---

## Django Deploy Security Check

```bash
# Built-in checks: HSTS, SSL redirect, secure cookies, X-Frame-Options
python manage.py check --deploy
```

Covers `SECURE_HSTS_SECONDS`, `SECURE_SSL_REDIRECT`, `SESSION_COOKIE_SECURE`,
`CSRF_COOKIE_SECURE`, `X_FRAME_OPTIONS`, `SECURE_CONTENT_TYPE_NOSNIFF`,
`DEBUG = False`.

---

## Full Deploy Script (gunicorn + Celery)

```bash
#!/bin/bash
set -e

APP_DIR="/opt/app"
VENV_DIR="$APP_DIR/venv"
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
APP_USER="app"

cd "$APP_DIR"

# 1. Maintenance flag (consume via load balancer or middleware)
touch "$APP_DIR/maintenance.flag"

# 2. Backup database
source "$APP_DIR/.env"
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -F c -f "$BACKUP_DIR/db_$DATE.dump"

# 3. Pull latest code
sudo -u "$APP_USER" git pull origin main

# 4. Activate venv and install dependencies
source "$VENV_DIR/bin/activate"
pip install -r requirements.txt --no-cache-dir

# 5. Collect static (Django)
[ -f "manage.py" ] && python manage.py collectstatic --noinput

# 6. Run migrations
if [ -f "manage.py" ]; then
    python manage.py migrate --noinput
else
    alembic upgrade head
fi

# 7. Graceful gunicorn reload (no downtime)
kill -HUP $(cat /var/run/gunicorn.pid)
# Or: sudo systemctl reload gunicorn

# 8. Restart Celery workers (use TERM for graceful shutdown after current task)
sudo systemctl restart celery-worker
sudo systemctl restart celery-beat

# 9. Drop maintenance flag
rm -f "$APP_DIR/maintenance.flag"

# 10. Health check
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://your-domain.com/health/)
[ "$HTTP_CODE" -eq 200 ] || exit 1

# 11. Verify Celery is responding
celery -A config inspect ping > /dev/null 2>&1 || echo "WARN: Celery not responding"
```

---

## Docker Deploy Script

```bash
#!/bin/bash
set -e

IMAGE="registry.example.com/app"
TAG=$(git rev-parse --short HEAD)

docker build -t "$IMAGE:$TAG" -t "$IMAGE:latest" .
docker push "$IMAGE:$TAG"
docker push "$IMAGE:latest"

# Run migrations in a throwaway container
docker run --rm --env-file .env.production "$IMAGE:$TAG" \
    python manage.py migrate --noinput

# Collect static into shared volume
docker run --rm --env-file .env.production \
    -v static_volume:/app/staticfiles \
    "$IMAGE:$TAG" python manage.py collectstatic --noinput

docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d --remove-orphans

sleep 10
curl -sf https://your-domain.com/health/ > /dev/null || exit 1
```

---

## Post-Deploy Verification

Smoke tests:

```bash
curl -I https://your-domain.com/
curl -I https://your-domain.com/health/
curl -I https://your-domain.com/api/v1/status/
curl -I https://your-domain.com/admin/login/   # Django admin

# Response time
curl -w "DNS: %{time_namelookup}s | Connect: %{time_connect}s | TTFB: %{time_starttransfer}s | Total: %{time_total}s\n" \
  -o /dev/null -s https://your-domain.com/
```

Celery inspection:

```bash
celery -A config inspect ping       # workers alive?
celery -A config inspect active     # tasks in progress
celery -A config inspect reserved   # tasks queued
celery -A config inspect stats      # per-worker stats
```

Django-celery-results: failed task count:

```bash
python manage.py shell -c \
    "from django_celery_results.models import TaskResult; print(TaskResult.objects.filter(status='FAILURE').count())"
```

Sidekiq-style queue introspection (Celery + Redis):

```python
# inspect_queues.py
from celery import current_app
i = current_app.control.inspect()
print(i.reserved())  # queued tasks per worker
print(i.active())    # currently-running tasks per worker
```

Error log scan:

```bash
journalctl -u gunicorn --since "10 minutes ago" --no-pager | grep -iE "error|exception|traceback"
journalctl -u celery-worker --since "10 minutes ago" --no-pager | grep -iE "error|exception"
```

---

## Rollback Scripts

Quick rollback (`rollback.sh`):

```bash
#!/bin/bash
set -e

APP_DIR="/opt/app"
VENV_DIR="$APP_DIR/venv"

cd "$APP_DIR"

sudo systemctl stop gunicorn
sudo systemctl stop celery-worker celery-beat

# Revert code (1 commit)
git log --oneline -5
git reset --hard HEAD~1

# Reinstall in case deps changed
source "$VENV_DIR/bin/activate"
pip install -r requirements.txt --no-cache-dir

# Migrations rollback — pick the relevant one
# Django: python manage.py migrate [app_name] [previous_migration_number]
# Alembic: alembic downgrade -1

[ -f "manage.py" ] && python manage.py collectstatic --noinput

sudo systemctl start gunicorn
sudo systemctl start celery-worker celery-beat

sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://your-domain.com/health/)
[ "$HTTP_CODE" -eq 200 ] || exit 1
```

Database rollback:

```bash
# PostgreSQL full restore
pg_restore -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
    --clean --if-exists "$BACKUP_DIR/db_YYYYMMDD_HHMMSS.dump"

# MySQL full restore
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
    < "$BACKUP_DIR/db_YYYYMMDD_HHMMSS.sql"

# Django migration rollback (no full DB restore)
python manage.py migrate [app_name] [previous_migration_number]

# Alembic migration rollback (1 step)
alembic downgrade -1
```

---

## Python-Specific Rollback Triggers

Beyond the generic triggers in `base/prompts/DEPLOY_CHECKLIST.md §8.2`,
roll back immediately when:

- Celery worker crashes repeatedly (`celery -A config inspect ping`
  returns empty for > 1 min) — usually a missing migration or import
  error.
- Failed-task count climbing in `django_celery_results.TaskResult`
  (> 5 failures/min, sustained) — task signature changed or task body
  raises on production data.
- Gunicorn workers OOM-killed (check `dmesg | grep -i oom` or
  `journalctl -u gunicorn | grep -i killed`) — memory regression in
  the deployed code; rollback first, profile later.
