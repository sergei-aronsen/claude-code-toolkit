# Deploy Checklist — Rails Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive pre-deploy verification for a Ruby on Rails application. Act as a Senior DevOps Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for pre-deploy checks — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Rails Boot | `rails runner "puts Rails.version"` | No errors |
| 2 | RuboCop | `bundle exec rubocop` | No offenses |
| 3 | Brakeman | `bundle exec brakeman -q` | No warnings |
| 4 | Tests | `bundle exec rspec` or `rails test` | Pass |
| 5 | Assets | `rails assets:precompile` | Success |
| 6 | Migrations | `rails db:migrate:status` | All up |
| 7 | Bundle Audit | `bundle audit check --update` | No vulnerabilities |

**If all 7 = OK --> Ready to deploy!**

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# deploy-check.sh — run before deployment

set -e

echo "Pre-deploy Check for Rails..."

# 1. Rails Boot
rails runner "puts Rails.version" > /dev/null 2>&1 && echo "OK: Rails Boot" || { echo "FAIL: Rails Boot"; exit 1; }

# 2. RuboCop
bundle exec rubocop --format simple > /dev/null 2>&1 && echo "OK: RuboCop" || echo "WARN: RuboCop offenses"

# 3. Brakeman
bundle exec brakeman -q --no-pager 2>&1 | grep -q "No warnings found" && echo "OK: Brakeman" || echo "WARN: Brakeman warnings"

# 4. Tests
bundle exec rspec --format progress > /dev/null 2>&1 && echo "OK: Tests" || echo "WARN: Tests failed"

# 5. Asset Compilation
RAILS_ENV=production SECRET_KEY_BASE=dummy rails assets:precompile > /dev/null 2>&1 && echo "OK: Assets" || { echo "FAIL: Assets"; exit 1; }

# 6. Debug code check
grep -rn "binding\.pry\|byebug\|debugger" app/ lib/ | grep -v "node_modules" && echo "WARN: debug statements found" || echo "OK: No debug statements"
grep -rn "puts \|pp " app/ lib/ | grep -v "node_modules" && echo "WARN: puts/pp found" || echo "OK: No puts/pp"

# 7. Bundle Audit
bundle audit check --update > /dev/null 2>&1 && echo "OK: Bundle Audit" || echo "WARN: Vulnerable gems"

echo ""
echo "Pre-deploy check complete!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Deployment target:**

- **Server**: [IP/hostname]
- **Path**: [/var/www/app or /home/deploy/app]
- **URL**: [https://...]
- **Deploy tool**: [Capistrano/Kamal/custom]
- **Process manager**: [systemd/Puma/Passenger]

**Database:**

- **Engine**: [PostgreSQL/MySQL]
- **Name**: [db_name]
- **User**: [db_user]
- **Password**: see credentials or ENV `DATABASE_URL`

**Important files:**

- `config/credentials/production.yml.enc` — encrypted credentials
- `config/master.key` — decryption key (never committed)
- `config/puma.rb` — Puma configuration
- `Procfile` — process declarations

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
grep -rn "binding\.pry" app/ lib/ config/ spec/
grep -rn "byebug" app/ lib/ config/ spec/
grep -rn "debugger" app/ lib/ config/ spec/
grep -rn "puts " app/ lib/ | grep -v "\.keep"
grep -rn "pp " app/ lib/
grep -rn "Rails\.logger\.debug" app/ lib/
grep -rn "console\.log" app/assets/ app/javascript/
```

- [ ] No `binding.pry` statements
- [ ] No `byebug` statements
- [ ] No `debugger` calls
- [ ] No stray `puts` or `pp` in application code
- [ ] No `Rails.logger.debug` with sensitive data
- [ ] No `console.log()` in production JavaScript

### 1.2 Commented Code

- [ ] No commented-out code blocks
- [ ] No `# TODO: remove` blocks
- [ ] No `# FIXME` left unaddressed

### 1.3 Temporary Files

```bash
find . -name "*.bak" -o -name "*.tmp" -o -name "*.old" -o -name "*.orig"
find . -name "*.swp" -o -name "*~"
```

- [ ] No `.bak`, `.tmp`, `.old`, `.orig` files
- [ ] No editor swap files

---

## 2. CODE QUALITY CHECKS

### 2.1 Tests

```bash
bundle exec rspec
# or
rails test

# With coverage
COVERAGE=true bundle exec rspec
```

- [ ] All tests pass
- [ ] No skipped tests without reason
- [ ] Critical functionality covered
- [ ] No pending examples left without explanation

### 2.2 Static Analysis

```bash
bundle exec rubocop
bundle exec brakeman -q --no-pager
```

- [ ] RuboCop without offenses (or only approved exceptions)
- [ ] Brakeman without high/critical warnings
- [ ] No new security warnings introduced

### 2.3 Build

```bash
RAILS_ENV=production SECRET_KEY_BASE=dummy rails assets:precompile
```

- [ ] Asset compilation passes without errors
- [ ] No missing asset references

---

## 3. DATABASE PREPARATION

### 3.1 Migrations Review

```bash
rails db:migrate:status
rails db:migrate
rails db:rollback && rails db:migrate
```

```ruby
# Good — safe changes
class AddBioToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :bio, :text, default: nil  # nullable for existing records
  end
end

# Dangerous — NOT NULL without default on existing table
class AddStatusToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :status, :string, null: false  # Will fail on existing rows!
  end
end

# Safe pattern for NOT NULL columns
class AddStatusToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :status, :string, default: "active"
    change_column_null :users, :status, false
  end

  def down
    remove_column :users, :status
  end
end
```

- [ ] All migrations have reversible `change` or explicit `up`/`down`
- [ ] New NOT NULL columns have a default value
- [ ] Indexes added for new foreign keys
- [ ] Rollback works (`rails db:rollback STEP=N`)
- [ ] No destructive operations without safety checks
- [ ] Large table migrations use `disable_ddl_transaction!` if needed

### 3.2 Seeders Check

```ruby
# CRITICAL — will delete production data!
class SeedUsers
  User.destroy_all  # NEVER in production!
end

# Safe — environment check
unless Rails.env.production?
  User.find_or_create_by!(email: "admin@example.com") do |user|
    user.name = "Admin"
    user.password = "password"
  end
end
```

- [ ] Seeds don't run destructive operations in production
- [ ] No `destroy_all` or `delete_all` without `Rails.env.production?` guard
- [ ] Seed data uses `find_or_create_by` to be idempotent

### 3.3 Backup

```bash
# PostgreSQL backup before migrations
pg_dump -U $DB_USER -h $DB_HOST $DB_NAME > backup_$(date +%Y%m%d_%H%M%S).sql

# MySQL backup before migrations
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > backup_$(date +%Y%m%d_%H%M%S).sql
```

- [ ] DB backup created before migrations
- [ ] Backup verified for restorability
- [ ] Backup stored in a safe location

---

## 4. ENVIRONMENT CONFIGURATION

### 4.1 Production Environment

```ini
# REQUIRED environment variables
RAILS_ENV=production
SECRET_KEY_BASE=[generated-secret]
DATABASE_URL=postgres://user:pass@host:5432/dbname
RAILS_LOG_LEVEL=warn
RAILS_SERVE_STATIC_FILES=true
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2

# Redis (if using Sidekiq/Action Cable)
REDIS_URL=redis://localhost:6379/0

# Mail
SMTP_ADDRESS=[smtp-host]
SMTP_PORT=587
```

- [ ] `RAILS_ENV=production`
- [ ] `SECRET_KEY_BASE` is set and unique
- [ ] `DATABASE_URL` points to production database
- [ ] `RAILS_LOG_LEVEL` is not `debug`
- [ ] `REDIS_URL` is set (if using Sidekiq/Action Cable)
- [ ] All third-party API keys are set

### 4.2 Credentials Check

```bash
# View production credentials
EDITOR=cat rails credentials:show --environment production

# Verify credentials are accessible
rails runner "puts Rails.application.credentials.secret_key_base.present?"

# Ensure master key exists
test -f config/credentials/production.key && echo "Production key exists" || echo "MISSING production key!"
```

- [ ] Production credentials file is encrypted and accessible
- [ ] `config/master.key` or `config/credentials/production.key` is present on server
- [ ] No plaintext secrets in source code
- [ ] No secrets committed to version control

---

## 5. BUILD PROCESS

### 5.1 Bundle Production

```bash
bundle config set --local deployment true
bundle config set --local without development:test
bundle install
```

- [ ] `bundle install` with production config succeeds
- [ ] No missing native extension dependencies
- [ ] `Gemfile.lock` is committed and up to date

### 5.2 Asset Compilation

```bash
RAILS_ENV=production SECRET_KEY_BASE=dummy rails assets:precompile
RAILS_ENV=production rails assets:clean
```

- [ ] `assets:precompile` succeeds in production mode
- [ ] Compiled assets have fingerprinted filenames
- [ ] JavaScript bundles are minified
- [ ] CSS is compiled and minified
- [ ] No missing image or font references

---

## 6. SECURITY PRE-CHECK

### 6.1 Sensitive Files

- [ ] `.env` files not accessible via web
- [ ] `config/master.key` not committed to git
- [ ] `.git/` directory not accessible via web
- [ ] `log/` directory not accessible via web
- [ ] `tmp/` directory not accessible via web
- [ ] `config/credentials/*.key` not in repository

### 6.2 File Permissions

```bash
chmod -R 755 log tmp storage
chown -R deploy:deploy log tmp storage
chmod 600 config/master.key
chmod 600 config/credentials/production.key
```

- [ ] `log/` — 755, owned by deploy user
- [ ] `tmp/` — 755, owned by deploy user
- [ ] `storage/` — 755, owned by deploy user (Active Storage)
- [ ] Key files — 600, restricted access

### 6.3 Dependencies Audit

```bash
bundle audit check --update
bundle exec brakeman -q --no-pager
```

- [ ] `bundle audit` — no critical/high vulnerabilities
- [ ] `brakeman` — no critical/high security warnings
- [ ] All gems are from trusted sources (rubygems.org)

---

## 7. DEPLOYMENT COMMANDS

### 7.1 Full Deploy Script

```bash
#!/bin/bash
set -e

APP_DIR="/var/www/[app]"
SHARED_DIR="$APP_DIR/shared"
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

cd $APP_DIR/current

# 1. Enable maintenance mode
cp public/maintenance.html public/system/maintenance.html
echo "Maintenance mode enabled"

# 2. Backup database
source_db_url=$(rails runner "puts ENV['DATABASE_URL']" 2>/dev/null || echo "")
if [ -n "$source_db_url" ]; then
  pg_dump "$source_db_url" > "$BACKUP_DIR/db_$DATE.sql"
  echo "Database backup created"
fi

# 3. Pull latest code
git fetch origin main
git reset --hard origin/main

# 4. Install Ruby dependencies
bundle config set --local deployment true
bundle config set --local without development:test
bundle install --jobs 4

# 5. Compile assets
RAILS_ENV=production rails assets:precompile

# 6. Run database migrations
RAILS_ENV=production rails db:migrate

# 7. Clear Rails cache
RAILS_ENV=production rails tmp:clear
RAILS_ENV=production rails log:clear

# 8. Restart Puma
if systemctl is-active --quiet puma; then
  sudo systemctl restart puma
  echo "Puma restarted via systemd"
elif [ -f tmp/pids/server.pid ]; then
  bundle exec pumactl -P tmp/pids/server.pid phased-restart
  echo "Puma phased-restart complete"
fi

# 9. Restart Sidekiq (if used)
if systemctl is-active --quiet sidekiq; then
  sudo systemctl restart sidekiq
  echo "Sidekiq restarted"
fi

# 10. Reload Nginx
sudo nginx -t && sudo systemctl reload nginx
echo "Nginx reloaded"

# 11. Disable maintenance mode
rm -f public/system/maintenance.html
echo "Maintenance mode disabled"

echo "Deployment completed at $(date)!"

# 12. Health check
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://[domain]/health)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Health check passed!"
else
    echo "Health check failed! HTTP: $HTTP_CODE"
    exit 1
fi
```

---

## 8. POST-DEPLOYMENT VERIFICATION

### 8.1 Smoke Tests

```bash
curl -I https://[domain]
curl -I https://[domain]/health
curl -I https://[domain]/users/sign_in
curl -s https://[domain]/health | python3 -m json.tool
```

- [ ] Homepage loads (HTTP 200)
- [ ] Health check endpoint responds
- [ ] Login page renders
- [ ] Main functionality works
- [ ] Background jobs are processing
- [ ] Action Cable connections work (if used)

### 8.2 Error Monitoring

```bash
# Check production logs
tail -f log/production.log
grep -i "error\|exception\|fatal" log/production.log | tail -20

# Check Sidekiq (if used)
# Visit /sidekiq dashboard or:
rails runner "puts Sidekiq::Stats.new.failed"
rails runner "puts Sidekiq::RetrySet.new.size"

# Check Active Job queue
rails runner "puts Sidekiq::Queue.all.map { |q| [q.name, q.size] }"
```

- [ ] No new errors in production log
- [ ] No failed Sidekiq jobs
- [ ] Error rate did not increase
- [ ] Response times are normal
- [ ] Memory usage is stable

---

## 9. ROLLBACK PLAN

### 9.1 Quick Rollback

```bash
#!/bin/bash
set -e

APP_DIR="/var/www/[app]"

cd $APP_DIR/current

# Option A: Capistrano rollback
# cap production deploy:rollback

# Option B: Git-based rollback
cp public/maintenance.html public/system/maintenance.html

git log --oneline -5  # Identify target commit
git reset --hard HEAD~1

bundle config set --local deployment true
bundle config set --local without development:test
bundle install --jobs 4

RAILS_ENV=production rails assets:precompile

# Rollback migrations if needed
# RAILS_ENV=production rails db:rollback STEP=1

# Restore database if needed
# psql $DATABASE_URL < /opt/backups/db_YYYYMMDD_HHMMSS.sql

# Restart services
sudo systemctl restart puma
sudo systemctl restart sidekiq  # if used

rm -f public/system/maintenance.html

echo "Rollback completed!"
```

### 9.2 Rollback Triggers

Rollback if:

- Error rate > 5% after deploy
- Critical functionality does not work
- Database corruption detected
- Response times degraded by more than 50%
- Memory leaks or runaway processes

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
Rails: [rails version]
Ruby: [ruby version]

## Summary

| Step | Status |
|------|--------|
| Pre-checks | OK/FAIL |
| Backup | OK/FAIL |
| Deploy | OK/FAIL |
| Verify | OK/FAIL |

**Readiness**: XX% — [READY/ACCEPTABLE/NOT READY]

## Blockers

- [If any]

## Warnings

- [If any]

## Post-Deploy

- [ ] Monitor logs for 24h
- [ ] Check Sidekiq dashboard
- [ ] Verify background jobs complete
- [ ] Check error tracking (Sentry/Honeybadger/Rollbar)
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

1. **Check** — go through checklist
2. **Backup** — create database backup
3. **Deploy** — execute deployment
4. **Verify** — confirm everything works
5. **Monitor** — watch logs and error tracking

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
