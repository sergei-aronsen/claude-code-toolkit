# Deploy Templates — Rails

Operational runbook templates for deploying a Ruby on Rails service:
bundle install, asset compilation, deploy script (Puma + Sidekiq +
Nginx), rollback. Consumed via the base `DEPLOY_CHECKLIST.md` →
`Stack Specifics → Rails` reference.

These are **templates**, not a checklist. The pre-deploy decision gates
(baseline metrics, auth/crypto, CSRF, post-deploy comparison, rollback
triggers, time boundaries) live in
`templates/base/prompts/DEPLOY_CHECKLIST.md` — consult that file first.

---

## Bundle (Production)

```bash
bundle config set --local deployment true
bundle config set --local without development:test
bundle install --jobs 4
```

`Gemfile.lock` must be committed.

---

## Asset Compilation

```bash
RAILS_ENV=production SECRET_KEY_BASE=dummy rails assets:precompile
RAILS_ENV=production rails assets:clean
```

`SECRET_KEY_BASE=dummy` lets `assets:precompile` run even when the
production secret isn't on the build host (the compiled assets don't
depend on it). The real secret is read at runtime from credentials or
ENV.

---

## File Permissions

```bash
chmod -R 755 log tmp storage
chown -R deploy:deploy log tmp storage
chmod 600 config/master.key
chmod 600 config/credentials/production.key
```

- `log/`, `tmp/`, `storage/` — 755, owned by deploy user.
- Key files — 600, restricted.
- Active Storage `storage/` must be writable by the Rails process.

---

## Full Deploy Script (Puma + Sidekiq + Nginx)

```bash
#!/bin/bash
set -e

APP_DIR="/var/www/app"
SHARED_DIR="$APP_DIR/shared"
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

cd "$APP_DIR/current"

# 1. Maintenance page
cp public/maintenance.html public/system/maintenance.html

# 2. Backup database
source_db_url=$(rails runner "puts ENV['DATABASE_URL']" 2>/dev/null || echo "")
[ -n "$source_db_url" ] && pg_dump "$source_db_url" > "$BACKUP_DIR/db_$DATE.sql"

# 3. Pull latest code
git fetch origin main
git reset --hard origin/main

# 4. Install dependencies (production only)
bundle config set --local deployment true
bundle config set --local without development:test
bundle install --jobs 4

# 5. Compile assets
RAILS_ENV=production rails assets:precompile

# 6. Run migrations
RAILS_ENV=production rails db:migrate

# 7. Clear caches
RAILS_ENV=production rails tmp:clear
RAILS_ENV=production rails log:clear

# 8. Restart Puma — prefer phased-restart (zero downtime for workers)
if systemctl is-active --quiet puma; then
    sudo systemctl restart puma
elif [ -f tmp/pids/server.pid ]; then
    bundle exec pumactl -P tmp/pids/server.pid phased-restart
fi

# 9. Restart Sidekiq (SIGTERM = graceful shutdown after current job)
if systemctl is-active --quiet sidekiq; then
    sudo systemctl restart sidekiq
fi

# 10. Reload Nginx (one-shot config reload, no client drop)
sudo nginx -t && sudo systemctl reload nginx

# 11. Drop maintenance page
rm -f public/system/maintenance.html

# 12. Health check
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://example.com/health)
[ "$HTTP_CODE" -eq 200 ] || exit 1
```

---

## Capistrano Alternative

If using Capistrano:

```bash
cap production deploy           # standard deploy
cap production deploy:rollback  # roll back to previous release
```

Capistrano's `deploy:rollback` swaps the `current` symlink back to the
previous release directory under `releases/` — fast and atomic, no git
operations needed.

---

## Post-Deploy Verification

Smoke tests:

```bash
curl -I https://example.com
curl -I https://example.com/health
curl -I https://example.com/users/sign_in
curl -s https://example.com/health | python3 -m json.tool
```

Sidekiq introspection:

```bash
# Failed job count
rails runner "puts Sidekiq::Stats.new.failed"

# Retry queue size
rails runner "puts Sidekiq::RetrySet.new.size"

# Queue sizes per queue
rails runner "puts Sidekiq::Queue.all.map { |q| [q.name, q.size] }"

# Active workers count
rails runner "puts Sidekiq::ProcessSet.new.size"
```

Action Cable verification (if used):

```bash
# WebSocket handshake test (requires wscat: npm install -g wscat)
wscat -c wss://example.com/cable
```

Error log scan:

```bash
tail -f log/production.log
grep -iE "error|exception|fatal" log/production.log | tail -20
```

---

## Rollback Script

```bash
#!/bin/bash
set -e

APP_DIR="/var/www/app"
cd "$APP_DIR/current"

# Option A: Capistrano (preferred if used)
# cap production deploy:rollback
# exit 0

# Option B: Git-based rollback
cp public/maintenance.html public/system/maintenance.html

git log --oneline -5     # confirm target commit
git reset --hard HEAD~1  # roll back 1 commit

bundle config set --local deployment true
bundle config set --local without development:test
bundle install --jobs 4

RAILS_ENV=production rails assets:precompile

# Migration rollback (optional — only if last deploy ran a migration)
# RAILS_ENV=production rails db:rollback STEP=1

# Full DB restore (last resort)
# psql $DATABASE_URL < /opt/backups/db_YYYYMMDD_HHMMSS.sql

sudo systemctl restart puma
sudo systemctl restart sidekiq

rm -f public/system/maintenance.html
```

---

## Rails-Specific Rollback Triggers

Beyond the generic triggers in `base/prompts/DEPLOY_CHECKLIST.md §8.2`,
roll back immediately when:

- Sidekiq retry queue climbing (`Sidekiq::RetrySet.new.size` > baseline
  × 5 for > 5 min) — job signature changed or job raises on production
  data.
- Failed job count from `Sidekiq::Stats.new.failed` jumps by > 100
  within 5 min of deploy — usually a class rename or missing
  ActiveRecord column.
- Puma workers being OOM-killed (`dmesg | grep -i oom`, or
  `journalctl -u puma | grep -i killed`) — memory regression.
- Action Cable connections fail (handshake 4xx/5xx) — typically a
  routes regression or an `ActionCable.allowed_request_origins`
  misconfiguration.
