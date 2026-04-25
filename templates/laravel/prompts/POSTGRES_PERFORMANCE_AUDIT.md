# PostgreSQL Performance Audit Guide

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

> Guide for PostgreSQL performance auditing

## Audit Philosophy

**DON'T:**

- Static code analysis for finding indexes (code doesn't know call frequency)
- Guessing "which indexes are needed" without data
- Adding indexes "just in case"

**DO:**

- Analysis through `pg_stat_statements` (real statistics)
- Finding queries with bad rows scanned / rows returned ratio
- Removing unused indexes
- Checking infrastructure metrics

---

## Preliminary Setup

### Enable pg_stat_statements

```sql
-- Check if extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';

-- If not — enable (requires restart)
-- postgresql.conf:
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.track = all

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

### Check Permissions

```sql
SELECT current_user, current_database();
-- Needs superuser or pg_read_all_stats for full access
```

---

## 1. Quick Health Check

```sql
SELECT
    'Connections' as metric,
    COUNT(*) || ' / ' || current_setting('max_connections') as value
FROM pg_stat_activity
UNION ALL
SELECT 'Active queries', COUNT(*)::text
FROM pg_stat_activity WHERE state = 'active'
UNION ALL
SELECT 'Database size', pg_size_pretty(pg_database_size(current_database()))
UNION ALL
SELECT 'Uptime', (NOW() - pg_postmaster_start_time())::text
UNION ALL
SELECT 'Deadlocks', deadlocks::text
FROM pg_stat_database WHERE datname = current_database();
```

---

## 2. Connection Health

```sql
SELECT
    current_setting('max_connections')::int as max_allowed,
    COUNT(*) as current_connections,
    COUNT(*) FILTER (WHERE state = 'active') as active,
    COUNT(*) FILTER (WHERE state = 'idle') as idle,
    COUNT(*) FILTER (WHERE state = 'idle in transaction') as idle_in_txn,
    ROUND(COUNT(*) * 100.0 / current_setting('max_connections')::int, 1) as usage_percent
FROM pg_stat_activity;
```

| Usage % | Status | Action |
| ------- | ------ | ------ |
| < 60% | OK | - |
| 60-80% | Warning | Plan increase or connection pooling |
| > 80% | Critical | Configure PgBouncer |

**Idle in transaction** > 5 — problem with unclosed transactions!

### Long Running Transactions

Any long transaction (even active) blocks VACUUM from cleaning dead tuples. One 24-hour transaction can double table sizes.

```sql
SELECT
    pid,
    usename,
    state,
    now() - xact_start as duration,
    LEFT(query, 80) as query
FROM pg_stat_activity
WHERE (now() - xact_start) > interval '5 minutes'
ORDER BY duration DESC;
```

**Rule:** No transactions longer than 10 minutes in production. Set `idle_in_transaction_session_timeout` as a safety net.

---

## 3. Shared Buffers & Cache Hit Ratio

```sql
SELECT
    current_setting('shared_buffers') as shared_buffers,
    pg_size_pretty(pg_database_size(current_database())) as db_size,
    ROUND(
        blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2
    ) as cache_hit_ratio
FROM pg_stat_database
WHERE datname = current_database();
```

**Cache hit ratio:**

| Ratio | Status | Action |
| ----- | ------ | ------ |
| > 99% | Excellent | OK |
| 95-99% | Good | Monitor |
| < 95% | Poor | Increase shared_buffers |

**Rule:** `shared_buffers = 25% RAM` (but not more than 8GB on Linux)

---

## 3.5 Write Health (Checkpoints & BgWriter)

PostgreSQL writes dirty pages via background processes. If settings are wrong, regular backends start writing to disk themselves, causing latency spikes.

```sql
SELECT
    checkpoints_timed,
    checkpoints_req,
    ROUND(checkpoint_write_time / 1000) as write_time_sec,
    ROUND(checkpoint_sync_time / 1000) as sync_time_sec,
    buffers_checkpoint,
    buffers_clean,
    buffers_backend
FROM pg_stat_bgwriter;
```

**Key indicators:**

| Metric | Problem | Fix |
| ------ | ------- | --- |
| `buffers_backend` high relative to `buffers_checkpoint + buffers_clean` | Backends forced to write to disk | Increase `bgwriter_lru_maxpages`, `bgwriter_lru_multiplier` |
| `checkpoints_req` > `checkpoints_timed` | WAL fills faster than timer | Increase `max_wal_size` |

---

## 3.6 Temp Files (Disk Spills)

When `work_mem` is too small for sorts/hashes, PostgreSQL writes temp files to disk — kills IO performance.

```sql
SELECT
    datname,
    temp_files,
    pg_size_pretty(temp_bytes) as temp_size
FROM pg_stat_database
WHERE datname = current_database();
```

**If `temp_files` grows rapidly** → increase `work_mem` or optimize queries with `ORDER BY` / `DISTINCT` / `GROUP BY`.

**Check per-query temp usage:**

```sql
SELECT
    LEFT(query, 80) as query,
    calls,
    ROUND(mean_exec_time::numeric, 2) as avg_ms,
    temp_blks_written
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
    AND temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 10;
```

---

## 4. Top Slow Queries (pg_stat_statements)

```sql
SELECT
    LEFT(query, 80) as query,
    calls,
    ROUND(total_exec_time::numeric / 1000, 2) as total_sec,
    ROUND((mean_exec_time)::numeric, 2) as avg_ms,
    rows as rows_returned,
    ROUND(rows::numeric / NULLIF(calls, 0), 0) as rows_per_call
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
ORDER BY total_exec_time DESC
LIMIT 15;
```

### Queries with bad plan (many rows scanned)

```sql
SELECT
    LEFT(query, 80) as query,
    calls,
    ROUND(mean_exec_time::numeric, 2) as avg_ms,
    rows,
    ROUND(shared_blks_read::numeric / NULLIF(calls, 0), 0) as blocks_per_call
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
    AND calls > 100
ORDER BY shared_blks_read DESC
LIMIT 15;
```

**blocks_per_call > 1000** — candidate for optimization.

---

## 5. Index Usage

### Unused Indexes

```sql
SELECT
    schemaname || '.' || relname as table,
    indexrelname as index,
    pg_size_pretty(pg_relation_size(indexrelid)) as size,
    idx_scan as scans
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelname NOT LIKE '%_pkey'
    AND indexrelname NOT LIKE '%_unique%'
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Important:** Check uptime! Statistics are reset on restart.

```sql
SELECT NOW() - pg_postmaster_start_time() as uptime;
```

### Tables without indexes (many seq scans)

```sql
SELECT
    schemaname || '.' || relname as table,
    seq_scan,
    seq_tup_read,
    idx_scan,
    CASE WHEN seq_scan > 0
        THEN ROUND(seq_tup_read::numeric / seq_scan, 0)
        ELSE 0
    END as avg_rows_per_seq_scan
FROM pg_stat_user_tables
WHERE seq_scan > 100
    AND seq_tup_read > 10000
ORDER BY seq_tup_read DESC
LIMIT 15;
```

**avg_rows_per_seq_scan > 1000** + frequent seq_scan — index needed.

---

## 6. N+1 Detection

```sql
SELECT
    LEFT(query, 100) as query,
    calls,
    ROUND(mean_exec_time::numeric, 3) as avg_ms,
    rows
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
    AND calls > 1000
    AND query ILIKE 'SELECT%'
    AND query ILIKE '%WHERE%id%=%'
ORDER BY calls DESC
LIMIT 15;
```

**N+1 Signs:**

- `calls` in thousands
- Simple `SELECT ... WHERE id = $1`
- `avg_ms` < 1ms

**Fix (Prisma):**

```typescript
// Bad
for (const user of users) {
  const posts = await prisma.post.findMany({ where: { userId: user.id } })
}

// Good
const usersWithPosts = await prisma.user.findMany({
  include: { posts: true }
})
```

**Fix (Laravel):**

```php
// Bad
foreach (User::all() as $user) {
    echo $user->posts->count(); // N+1!
}

// Good
foreach (User::with('posts')->get() as $user) {
    echo $user->posts->count();
}
```

---

## 7. Locks & Deadlocks

### Current Locks

```sql
SELECT
    blocked_locks.pid as blocked_pid,
    blocked_activity.usename as blocked_user,
    LEFT(blocked_activity.query, 60) as blocked_query,
    blocking_locks.pid as blocking_pid,
    blocking_activity.usename as blocking_user,
    LEFT(blocking_activity.query, 60) as blocking_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

### Deadlock History

```sql
SELECT deadlocks, conflicts
FROM pg_stat_database
WHERE datname = current_database();
```

---

## 8. Table Bloat (VACUUM)

```sql
SELECT
    schemaname || '.' || relname as table,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 1) as dead_pct,
    last_vacuum,
    last_autovacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 15;
```

**dead_pct > 20%** — needs VACUUM.

> **Note:** High dead tuples also bloat indexes. Standard `VACUUM` does not always reclaim index space efficiently. Consider `REINDEX INDEX CONCURRENTLY` for bloated indexes.

```sql
-- Manual vacuum
VACUUM ANALYZE table_name;

-- Aggressive (frees disk space)
VACUUM FULL table_name; -- LOCKS TABLE!

-- Rebuild bloated index without locking
REINDEX INDEX CONCURRENTLY index_name;
```

---

## 9. Table Sizes

```sql
SELECT
    schemaname || '.' || relname as table,
    pg_size_pretty(pg_total_relation_size(relid)) as total_size,
    pg_size_pretty(pg_relation_size(relid)) as data_size,
    pg_size_pretty(pg_indexes_size(relid)) as index_size,
    n_live_tup as rows
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 15;
```

---

## 10. Sequence Exhaustion

`SERIAL` (int4) columns max out at ~2.1 billion. When exhausted, inserts fail silently. Check proactively.

```sql
SELECT
    sequencename as sequence,
    last_value,
    (2147483647 - last_value) as remaining,
    ROUND((last_value / 2147483647.0) * 100, 1) as percent_used
FROM pg_sequences
WHERE data_type = 'integer'
ORDER BY percent_used DESC
LIMIT 5;
```

| percent_used | Status | Action |
| ------------ | ------ | ------ |
| < 50% | OK | - |
| 50-80% | Warning | Plan migration to `BIGINT` |
| > 80% | Critical | Migrate to `BIGINT` ASAP |

---

## Stack Specifics

### Next.js + Prisma

```typescript
// Prisma query logging
const prisma = new PrismaClient({
  log: ['query', 'info', 'warn', 'error'],
})

// Connection pooling via PgBouncer
// DATABASE_URL="postgresql://user:pass@pgbouncer:6432/db?pgbouncer=true"
```

### Laravel

```php
// config/database.php
'pgsql' => [
    'driver' => 'pgsql',
    'host' => env('DB_HOST', '127.0.0.1'),
    'port' => env('DB_PORT', '5432'),
    // ...
    'options' => [
        PDO::ATTR_PERSISTENT => true, // Connection pooling
    ],
],

// Query logging
DB::listen(function ($query) {
    Log::info($query->sql, $query->bindings, $query->time);
});
```

---

## PostgreSQL Configuration

```ini
# postgresql.conf — main parameters

# Memory
shared_buffers = 2GB              # 25% RAM, max 8GB
effective_cache_size = 6GB        # 75% RAM
work_mem = 64MB                   # For sorts/joins
maintenance_work_mem = 512MB      # For VACUUM, CREATE INDEX

# Connections
max_connections = 200
# Use PgBouncer for >100 connections

# WAL
wal_buffers = 64MB
checkpoint_completion_target = 0.9

# Query planner
random_page_cost = 1.1            # For SSD (default 4.0 for HDD)
effective_io_concurrency = 200    # For SSD
```

---

## Audit Checklist

- [ ] Cache hit ratio > 95%
- [ ] Connections usage < 80%
- [ ] No queries with > 1000 blocks_per_call
- [ ] No unused indexes (uptime > 7 days)
- [ ] Dead tuples < 20% on all tables
- [ ] No active locks/deadlocks
- [ ] N+1 issues fixed
- [ ] `buffers_backend` low relative to checkpoint/clean buffers
- [ ] `checkpoints_req` < `checkpoints_timed`
- [ ] No excessive temp files (check `work_mem`)
- [ ] No transactions running > 10 minutes
- [ ] No integer sequences > 80% exhausted
- [ ] pg_stat_statements enabled

---

## Resources

- [PostgreSQL Statistics Collector](https://www.postgresql.org/docs/current/monitoring-stats.html)
- [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html)
- [PgBouncer](https://www.pgbouncer.org/)
- [pgBadger](https://pgbadger.darold.net/) — log analyzer

---

## 11. Migration Safety

Unsafe migrations on large tables can lock the table for minutes, blocking all reads and writes.

### 11.1 Dangerous Patterns

```sql
-- ❌ Locks table until all rows are updated (PG < 11)
ALTER TABLE large_table ADD COLUMN status TEXT NOT NULL;

-- ✅ Safe — add nullable first, backfill, then add constraint
ALTER TABLE large_table ADD COLUMN status TEXT;
UPDATE large_table SET status = 'active' WHERE status IS NULL;
ALTER TABLE large_table ALTER COLUMN status SET NOT NULL;

-- ❌ Blocks writes during index build
CREATE INDEX idx_users_email ON users(email);

-- ✅ Safe — concurrent index (does not block writes)
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
```

### 11.2 Laravel-Specific

```php
// ❌ Dangerous on large tables
Schema::table('sites', function (Blueprint $table) {
    $table->string('status')->nullable(false); // Locks table!
    $table->index('status'); // Blocks writes!
});

// ✅ Safe — use raw SQL for large tables
DB::statement('ALTER TABLE sites ADD COLUMN status VARCHAR(255)');
DB::statement('CREATE INDEX CONCURRENTLY idx_sites_status ON sites(status)');
// Then backfill in batches
```

### 11.3 Checklist

- [ ] `NOT NULL` columns added with `DEFAULT` value (instant in PG 11+)
- [ ] Indexes created with `CONCURRENTLY` (use raw SQL in Laravel)
- [ ] No `DROP COLUMN` on large tables without prior assessment
- [ ] `ALTER TYPE` avoided on large tables (rewrites entire table)
- [ ] Lock timeout set: `SET lock_timeout = '5s'`
- [ ] Migrations tested on production-size dataset first

## 12. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 13. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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
