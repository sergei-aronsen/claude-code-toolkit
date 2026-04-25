# Database Performance Audit Guide

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

> Universal guide for MySQL/MariaDB performance auditing

## Audit Philosophy

**DO NOT:**

- Static analysis of code to find indexes (code doesn't know call frequency)
- Guessing "which indexes are needed" without data
- Adding indexes "just in case"

**DO:**

- Analysis through `performance_schema` (real statistics)
- Finding queries with poor scan ratio
- Removing unused indexes
- Checking infrastructure metrics

---

## Statistics Access

### Check for sys schema

```sql
SHOW DATABASES LIKE 'sys';
```

**If sys exists** - use convenient views:

- `sys.statement_analysis`
- `sys.schema_unused_indexes`

**If no sys** - work directly with `performance_schema`:

- `performance_schema.events_statements_summary_by_digest`
- `performance_schema.table_io_waits_summary_by_index_usage`

### Check User Permissions

```sql
SHOW GRANTS;
```

For full audit need access to `performance_schema`. If not available - use `debian-sys-maint` (password in `/etc/mysql/debian.cnf`).

---

## 1. Quick Health Check

```sql
SELECT
    'Connections' as metric,
    CONCAT(
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Threads_connected'),
        ' / ', @@max_connections,
        ' (', ROUND((SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Max_used_connections') / @@max_connections * 100, 0), '% peak)'
    ) as value
UNION ALL SELECT 'Buffer Pool MB', ROUND(@@innodb_buffer_pool_size / 1024 / 1024)
UNION ALL SELECT 'Deadlocks', (SELECT VARIABLE_VALUE FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Innodb_deadlocks')
UNION ALL SELECT 'Uptime Days', ROUND((SELECT VARIABLE_VALUE FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Uptime') / 86400, 1);
```

---

## 2. Connection Health

```sql
SELECT
    @@max_connections as max_allowed,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Max_used_connections') as peak_used,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Threads_connected') as current_conn,
    CONCAT(ROUND(
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Max_used_connections') / @@max_connections * 100, 1
    ), '%') as peak_percent;
```

| Peak % | Status | Action |
| ------ | ------ | ------ |
| < 60% | OK | - |
| 60-80% | Warning | Plan increase |
| > 80% | Critical | Increase `max_connections` |

**Formula for workers:**

```text
max_connections >= (PHP-FPM workers) + (Queue workers) + (Cron jobs) + 20% buffer
```

---

## 3. Buffer Pool

```sql
SELECT
    ROUND(@@innodb_buffer_pool_size / 1024 / 1024) as buffer_pool_mb,
    (SELECT ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024)
     FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE()) as db_size_mb;
```

**Rule:** `buffer_pool >= db_size * 1.2`

**Config:**

```ini
# /etc/mysql/mysql.conf.d/mysqld.cnf
innodb_buffer_pool_size = 1536M          # Match DB size
innodb_buffer_pool_instances = 4          # For parallelism (1 per each GB)
```

---

## 3.5 Write Performance (Redo Log & IO Latency)

### Redo Log

If Redo Log is too small, MySQL flushes to disk aggressively ("furious flushing"), killing write performance.

```sql
-- Redo Log write intensity
SELECT
    ROUND(VARIABLE_VALUE / 1024 / 1024) as redo_written_mb
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Innodb_os_log_written';
```

**Measure delta over 60 seconds to get MB/s.**

**Rule:** Redo Log should hold at least 1 hour of writes.

**Config:**

```ini
# MySQL 8.0.30+
innodb_redo_log_capacity = 2G

# Before 8.0.30
innodb_log_file_size = 1G    # x2 files = 2GB total
```

### IO Latency

MySQL may be slow due to disk, not CPU. Check with `sys` schema:

```sql
-- Slowest files by IO latency
SELECT
    file,
    total_latency,
    avg_read_latency,
    avg_write_latency
FROM sys.io_global_by_file_by_latency
WHERE file LIKE '%/data/%'
LIMIT 5;
```

| Latency | Status | Action |
| ------- | ------ | ------ |
| < 5ms | Excellent (SSD) | - |
| 5-10ms | OK | Monitor |
| 10-20ms | Warning | Check disk |
| > 20ms | Critical | Disk bottleneck |

### Temp Tables on Disk

Complex queries (GROUP BY, UNION) create temp tables. If they don't fit in memory, they spill to disk.

```sql
SELECT
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Created_tmp_disk_tables') as disk_tmp_tables,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Created_tmp_tables') as total_tmp_tables;
```

**Rule:** `disk / total` > 10% → increase `tmp_table_size` / `max_heap_table_size` or optimize queries.

---

## 4. Top Heavy Queries (Full Table Scans)

```sql
SELECT
    LEFT(DIGEST_TEXT, 80) as query,
    COUNT_STAR as calls,
    ROUND(SUM_TIMER_WAIT / 1000000000000, 3) as total_sec,
    ROUND((SUM_TIMER_WAIT / COUNT_STAR) / 1000000000, 1) as avg_ms,
    SUM_ROWS_SENT as rows_sent,
    SUM_ROWS_EXAMINED as rows_scanned,
    ROUND(SUM_ROWS_EXAMINED / NULLIF(SUM_ROWS_SENT, 0), 0) as scan_ratio
FROM performance_schema.events_statements_summary_by_digest
WHERE SCHEMA_NAME = DATABASE()
    AND SUM_ROWS_EXAMINED > 1000
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 15;
```

**Interpreting scan_ratio:**

| Ratio | Meaning | Action |
| ----- | ------- | ------ |
| 1-10 | Excellent | OK |
| 10-100 | Acceptable | Monitor |
| 100-1000 | Poor | Add index |
| > 1000 | Critical | Fix ASAP |

**Typical solutions:**

- `WHERE column = ?` without index → `CREATE INDEX`
- `WHERE column IS NOT NULL` → caching
- `LIKE '%search%'` → Full-text search
- `ORDER BY` without index → Composite index
- `JSON_EXTRACT(col, '$.key')` in WHERE → Create Virtual Generated Column + Index

---

## 5. Unused Indexes

```sql
SELECT
    OBJECT_NAME as tbl,
    INDEX_NAME as idx
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = DATABASE()
    AND INDEX_NAME IS NOT NULL
    AND INDEX_NAME != 'PRIMARY'
    AND COUNT_READ = 0
ORDER BY OBJECT_NAME;
```

**Important:** Check uptime! Statistics are reset on restart.

```sql
SELECT ROUND(VARIABLE_VALUE / 86400, 1) as uptime_days
FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Uptime';
```

**Safe to delete (uptime > 7 days):**

- Single-column boolean indexes on rare filters
- Duplicate indexes
- Indexes on archived tables

**DO NOT delete:**

- `*_foreign` (FK constraints)
- PRIMARY, UNIQUE
- Indexes created < 7 days ago

---

## 6. N+1 Detection

```sql
SELECT
    LEFT(DIGEST_TEXT, 80) as query,
    COUNT_STAR as exec_count,
    ROUND((SUM_TIMER_WAIT / COUNT_STAR) / 1000000000, 2) as avg_ms
FROM performance_schema.events_statements_summary_by_digest
WHERE SCHEMA_NAME = DATABASE()
    AND COUNT_STAR > 100
    AND DIGEST_TEXT LIKE 'SELECT%'
ORDER BY COUNT_STAR DESC
LIMIT 15;
```

**N+1 Signs:**

- `exec_count` in thousands
- Simple `SELECT ... WHERE id = ?`
- `avg_ms` < 1ms

**Fix (Laravel):**

```php
// Bad
foreach (Site::all() as $site) {
    echo $site->lastCheck->status; // N+1!
}

// Good
foreach (Site::with('lastCheck')->get() as $site) {
    echo $site->lastCheck->status;
}
```

---

## 7. Deadlocks

```sql
SELECT VARIABLE_VALUE as total_deadlocks
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Innodb_deadlocks';
```

**If > 0:**

```sql
SHOW ENGINE INNODB STATUS\G
-- Section: LATEST DETECTED DEADLOCK
```

**Typical causes:**

- Parallel workers updating same record
- Transactions locking tables in different order
- Long-running transactions

---

## 8. Table Sizes

```sql
SELECT
    TABLE_NAME as tbl,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as total_mb,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) as data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) as index_mb,
    TABLE_ROWS as rows
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
LIMIT 10;
```

### Fragmentation (UUID v4 problem)

UUID v4 as primary key causes random inserts → heavy index fragmentation.

```sql
SELECT
    TABLE_NAME as tbl,
    ROUND(DATA_LENGTH / 1024 / 1024) as data_mb,
    ROUND(DATA_FREE / 1024 / 1024) as free_mb,
    ROUND(DATA_FREE / NULLIF(DATA_LENGTH, 0) * 100) as frag_pct
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
    AND DATA_FREE > 50 * 1024 * 1024
ORDER BY DATA_FREE DESC;
```

| frag_pct | Status | Action |
| -------- | ------ | ------ |
| < 10% | OK | - |
| 10-30% | Warning | Schedule `OPTIMIZE TABLE` |
| > 30% | Critical | Migrate to ULID/UUIDv7 or `OPTIMIZE TABLE` |

**Note:** `OPTIMIZE TABLE` locks the table. Run during maintenance windows.

**Problem signs:**

- `index_mb` > `data_mb` → too many indexes
- Table > 1GB → plan archiving/partitioning
- `jobs` table bloated → problem with workers
- High `frag_pct` → UUID v4 fragmentation or frequent deletes

---

## Stack Specifics

### Laravel

```php
// config/database.php - connection pooling
'options' => [
    PDO::ATTR_PERSISTENT => true,
],

// Telescope for catching N+1 in dev
// Debugbar for query profiling
```

### Next.js + Prisma

```typescript
// Prisma query logging
const prisma = new PrismaClient({
  log: ['query', 'info', 'warn', 'error'],
})

// Connection pooling via PgBouncer for PostgreSQL
```

### Queue Workers

**Connections formula:**

```text
workers * connections_per_worker + web_requests + buffer
```

**Laravel Horizon:** worker and queue monitoring

---

## Automation

### Bash script for cron

```bash
#!/bin/bash
# /usr/local/bin/mysql-health-check.sh

MYSQL_PWD=$(grep password /etc/mysql/debian.cnf | head -1 | cut -d'=' -f2 | tr -d ' ')
export MYSQL_PWD

mysql -u debian-sys-maint << 'SQL' | mail -s "MySQL Health $(date +%Y-%m-%d)" admin@example.com
SELECT 'Connections' as metric,
    CONCAT(@@max_connections, ' max, ',
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Max_used_connections'), ' peak') as value
UNION ALL
SELECT 'Deadlocks', (SELECT VARIABLE_VALUE FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Innodb_deadlocks')
UNION ALL
SELECT 'Slow queries (>1s)',
    (SELECT COUNT(*) FROM performance_schema.events_statements_summary_by_digest
     WHERE AVG_TIMER_WAIT > 1000000000000);
SQL
```

### Cron schedule

```cron
# Daily health check
0 9 * * * /usr/local/bin/mysql-health-check.sh

# Weekly full audit
0 9 * * 1 /usr/local/bin/mysql-full-audit.sh
```

---

## Audit Checklist

- [ ] `buffer_pool` >= DB size
- [ ] Connections peak < 80%
- [ ] No queries with scan_ratio > 1000
- [ ] Removed unused indexes (uptime > 7 days)
- [ ] Deadlocks = 0
- [ ] No tables > 1GB without archiving plan
- [ ] N+1 issues fixed
- [ ] Redo Log sized for 1+ hour of writes
- [ ] IO latency < 10ms (SSD)
- [ ] Disk temp tables < 10% of total
- [ ] No tables with > 30% fragmentation
- [ ] JSON columns used in WHERE have Virtual Column + Index

---

## Resources

- [MySQL Performance Schema](https://dev.mysql.com/doc/refman/8.0/en/performance-schema.html)
- [Percona Toolkit](https://www.percona.com/software/database-tools/percona-toolkit) - pt-query-digest
- [MySQLTuner](https://github.com/major/MySQLTuner-perl)

---

## 9. Migration Safety

Unsafe migrations on large tables (100k+ rows) can lock the table, blocking all operations.

### 9.1 Dangerous Patterns

```sql
-- ❌ May lock table depending on MySQL version and storage engine
ALTER TABLE large_table ADD COLUMN status VARCHAR(50) NOT NULL;

-- ✅ Safe — add with DEFAULT (instant in MySQL 8.0.12+ for InnoDB)
ALTER TABLE large_table ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'active';

-- ❌ Changes column type — copies entire table
ALTER TABLE large_table MODIFY COLUMN name VARCHAR(500);

-- ✅ For very large tables — use pt-online-schema-change or gh-ost
pt-online-schema-change --alter "ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'active'" D=mydb,t=large_table
```

### 9.2 Checklist

- [ ] `NOT NULL` columns added with `DEFAULT` value
- [ ] Column type changes avoided on tables with 100k+ rows (or use pt-osc/gh-ost)
- [ ] `ALGORITHM=INPLACE` or `ALGORITHM=INSTANT` used where possible
- [ ] Large data migrations run in batches, not single UPDATE
- [ ] Migrations tested on production-size dataset first
- [ ] For critical tables: use `pt-online-schema-change` or `gh-ost`

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

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
