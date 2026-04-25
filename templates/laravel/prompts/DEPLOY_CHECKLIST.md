# Deploy Checklist — Laravel Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

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
2. **Backup** — create backup
3. **Deploy** — execute deployment
4. **Verify** — check that it works
5. **Monitor** — watch logs

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
