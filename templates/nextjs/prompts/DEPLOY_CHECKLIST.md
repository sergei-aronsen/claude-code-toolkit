# Deploy Checklist — Next.js Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

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
2. **Backup** — create DB backup
3. **Deploy** — execute deployment
4. **Verify** — check that it works
5. **Monitor** — watch metrics

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
