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

## 0.1 SEVERITY THRESHOLDS (MySQL-Specific Calibration)

MySQL-specific severity rubric. The spliced FALSE-POSITIVE CONTROL
block below points `cross-reference ## SEVERITY THRESHOLDS` at this
section — keep the heading text byte-exact so the cross-reference
resolves locally. Numbers are SLO-grade defaults; override per
project when `.claude/rules/project-context.md` declares tighter or
looser operational targets.

| Signal | LOW | MEDIUM | HIGH | CRITICAL |
| ------ | --- | ------ | ---- | -------- |
| `events_statements_summary_by_digest` `avg_ms` (OLTP read path) | < 50 ms | 50-200 ms | 200-1000 ms | > 1000 ms |
| `events_statements_summary_by_digest` `avg_ms` (OLTP write path) | < 100 ms | 100-500 ms | 500-2000 ms | > 2000 ms |
| `scan_ratio` (`ROWS_EXAMINED / ROWS_SENT`, SELECT only) | 1-10 | 10-100 | 100-1000 | > 1000 |
| InnoDB buffer pool hit ratio (`1 - reads/read_requests`) | > 99% | 95-99% | 90-95% | < 90% |
| Connection saturation (`Threads_connected / max_connections`) | < 60% | 60-80% | 80-95% | > 95% |
| `Innodb_row_lock_time_avg` (ms) | < 10 | 10-100 | 100-1000 | > 1000 |
| Replication lag (`Seconds_Behind_Master` / `Seconds_Behind_Source`) | < 5 s | 5-30 s | 30-300 s | > 300 s |
| Table fragmentation (`DATA_FREE / DATA_LENGTH`) | < 10% | 10-30% | 30-50% | > 50% |
| Auto-increment usage (INT signed) | < 50% | 50-70% | 70-85% | > 85% |
| `Slow_queries` rate per minute | < 1 | 1-10 | 10-100 | > 100 |
| `Innodb_history_list_length` (undo log purge backlog) | < 1k | 1k-10k | 10k-1M | > 1M |
| Temp tables on disk (`Created_tmp_disk_tables / Created_tmp_tables`) | < 10% | 10-30% | 30-50% | > 50% |

A finding **cannot** be elevated above `MEDIUM` without one of: a
captured `performance_schema.events_statements_summary_by_digest`
row, an `EXPLAIN ANALYZE` plan (MySQL 8.0.18+), an `EXPLAIN
FORMAT=JSON` plan, a `SHOW ENGINE INNODB STATUS` snapshot, or a
slow-query-log entry. See `## 4.1 EXPLAIN ANALYZE Evidence Gate`
for the binding rule.

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

For full audit, the auditor needs **read access to `performance_schema`
and `information_schema`** — that is all. Do NOT run audits as
`debian-sys-maint`, `root`, or any account that holds `DROP`, `ALTER`,
or `SUPER`. A typo in an interactive session with that level of
privilege can drop a production table.

Provision a dedicated read-only audit user once:

```sql
CREATE USER 'audit_ro'@'%' IDENTIFIED BY 'use-a-strong-password';
GRANT SELECT, PROCESS, SHOW VIEW ON *.* TO 'audit_ro'@'%';
GRANT SELECT ON performance_schema.* TO 'audit_ro'@'%';
GRANT SELECT ON information_schema.* TO 'audit_ro'@'%';
GRANT SELECT ON sys.* TO 'audit_ro'@'%';
FLUSH PRIVILEGES;
```

Store its credentials with `mysql_config_editor set --login-path=audit_ro`
(see `## Automation` below) — never inline in audit scripts and never in
shell history via `mysql -p<password>`.

If `performance_schema` access is genuinely impossible and `debian-sys-maint`
is the only option, run audits in a `BEGIN; ... ROLLBACK;` wrapper so any
accidental write is undone, and never leave such a session open at a
`mysql>` prompt.

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

**Measure delta over 60 seconds to get MB/s.** Sample twice with a 60s
gap, compute the difference. Helper:

```bash
A=$(mysql -BNe "SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME='Innodb_os_log_written'")
sleep 60
B=$(mysql -BNe "SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME='Innodb_os_log_written'")
echo "$(( (B - A) / 1024 / 1024 / 60 )) MB/s"
```

**Rule:** Redo Log should hold at least 1 hour of writes — but the "1
hour" target is workload-dependent:

- **Steady OLTP**: 1 hour is the conventional baseline.
- **Bursty OLTP** (peak-hour spikes 4-10× steady-state write rate): size
  for 1 hour at *peak* write rate, not steady-state, so checkpoints do
  not back up during a burst.
- **Heavy OLTP / write-mostly**: 4-8 hours.
- **Analytics / OLAP** (mostly reads, periodic batch writes): 30 minutes
  at batch-write rate is usually enough.

Underprovisioning the redo log forces MySQL into a "furious flushing"
mode where every write competes with checkpoint IO. Symptom: write p95
spikes during peak hours but `Innodb_buffer_pool_reads` and slow-query
log show no obvious cause.

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
| < 0.5ms | Excellent (NVMe / local SSD) | - |
| 0.5-5ms | Good (cloud SSD: gp3, io2, Premium SSD) | - |
| 5-10ms | OK (network-attached, baseline EBS) | Monitor |
| 10-20ms | Warning | Check disk / IOPS provisioning |
| > 20ms | Critical | Disk bottleneck (HDD, throttled EBS, noisy neighbour) |

> **Storage class matters.** Direct-attached NVMe achieves 0.1-0.5ms;
> cloud SSDs (AWS gp3, Azure Premium SSD, GCP pd-ssd) typically 0.5-2ms;
> network-attached storage and burstable / non-provisioned EBS commonly
> 5-15ms even when "healthy". A "5ms = Excellent" threshold hides real
> NVMe regressions. Calibrate against your actual storage class — record
> the storage type in `## PROJECT SPECIFICS` so future audits compare
> against the right baseline.

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

`scan_ratio = ROWS_EXAMINED / ROWS_SENT`. The ratio is meaningful only
for `SELECT` statements where `ROWS_SENT` is the result-set size.
`INSERT`, `UPDATE`, and `DELETE` send 0 rows back to the client, so the
NULLIF guard above prevents a divide-by-zero but the resulting ratio is
not interpretable for DML — read it as a SELECT-only signal.

| Ratio (SELECT only) | Meaning | Action |
| ----- | ------- | ------ |
| 1-10 | Excellent | OK |
| 10-100 | Acceptable | Monitor |
| 100-1000 | Poor | Add index |
| > 1000 | Critical | Fix ASAP |

For DML, separately watch `SUM_ROWS_AFFECTED / COUNT_STAR` (rows
modified per call) and `AVG_TIMER_WAIT` (per-call wall clock). A
`DELETE` examining 1M rows to delete 100 is a real problem, but it
shows up in `ROWS_EXAMINED` not `scan_ratio`.

**Typical solutions:**

- `WHERE column = ?` without index → `CREATE INDEX`
- `WHERE column IS NOT NULL` → caching
- `LIKE '%search%'` → Full-text search
- `ORDER BY` without index → Composite index
- `JSON_EXTRACT(col, '$.key')` in WHERE → Create Virtual Generated Column + Index

### 4.1 EXPLAIN ANALYZE Evidence Gate (F-002)

Every HIGH or CRITICAL slow-query finding MUST cite a captured plan
in the `Why it is real` field. A query the auditor merely
**suspects** is slow does not survive Gate 2 (`## SELF-CHECK` step 2
— Trace data flow). Acceptable evidence kinds for slow-query
HIGH/CRITICAL:

1. `EXPLAIN ANALYZE` output (MySQL 8.0.18+, preferred) — measures
   actual rows and timing instead of just planner estimates.
2. `EXPLAIN FORMAT=JSON` plan (any MySQL 5.6+, when 8.0.18 not
   available) — includes `cost_info`, `used_columns`,
   `attached_condition`, `used_key_parts`.
3. `performance_schema.events_statements_summary_by_digest` row
   with `COUNT_STAR`, `SUM_TIMER_WAIT`, `SUM_ROWS_EXAMINED`,
   `SUM_ROWS_SENT`.
4. `slow_query_log` line (when `long_query_time` is configured and
   the query has been observed in production).
5. `SHOW ENGINE INNODB STATUS` excerpt showing the matching
   transaction stuck on row locks.

A finding without one of (1)-(5) is downgraded to MEDIUM or moved
to Non-Blocking Observations.

```sql
-- Preferred: EXPLAIN ANALYZE on 8.0.18+
EXPLAIN ANALYZE
SELECT /* the query under audit */;

-- Fallback: EXPLAIN FORMAT=JSON (any 5.6+)
EXPLAIN FORMAT=JSON
SELECT /* the query under audit */;
```

**Estimate vs actual divergence.** `EXPLAIN ANALYZE` prints both
estimated and actual rows per loop. When the ratio is > 100× or
< 0.01× the optimizer has stale statistics — run
`ANALYZE TABLE <table>` and re-capture before deciding finding
severity.

**`EXPLAIN ANALYZE` caveat.** Unlike `EXPLAIN`, `ANALYZE` **executes**
the query. Do not run against destructive `UPDATE` / `DELETE` /
`INSERT` statements in production audit context — use `EXPLAIN
FORMAT=JSON` for DML, and validate the plan from the
`events_statements_summary_by_digest` row + `slow_query_log`
instead.

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

> **performance_schema reset caveats:** `events_statements_summary_by_digest`
> and other `performance_schema` summary tables reset on:
> (1) MySQL restart, (2) `TRUNCATE TABLE performance_schema.<table>`,
> (3) some `performance_schema_*` config changes. The "uptime > 7 days"
> rule is necessary but not sufficient — also confirm no operator has
> truncated the digest table since the last restart. If `COUNT_STAR` for
> well-known frequently-called queries is suspiciously low, the digest
> table has been recycled; defer the audit until 7 days of fresh
> statistics accumulate.
>
> Also check `performance_schema_max_digest_length` (default 1024
> characters): long queries truncated to the same prefix get merged into
> one digest row, silently inflating `COUNT_STAR` for the survivor. If
> long parameterized queries are common, raise to 4096+ in `my.cnf`.

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

### 6.1 Unbounded `get()` and Result-Set Materialization (F-024)

Laravel `Model::all()` and `Builder::get()` without an explicit
`limit()` / chunking materialize the entire result set into PHP
memory. The query itself looks innocent (`SELECT * FROM <table>`)
and runs fast on a small table, then OOMs the worker the day a
batch import grows the table 50×.

```php
// Bad — materializes every row, blows up at scale
User::where('status', 'active')->get();
Order::all();
$rows = DB::table('events')->where('created_at', '>', $cutoff)->get();

// Good — paginate, chunk, or cursor
User::where('status', 'active')->paginate(50);

Order::chunk(500, function ($orders) {
    // process each batch
});

foreach (DB::table('events')->where(...)->cursor() as $event) {
    // lazy generator, one row at a time
}
```

**Audit signal** — search the diff for `->get()`, `->all()`,
`::all()`, `->pluck(` without a preceding `->limit(` /
`->paginate(` / `->chunk(` / `->cursor(` and verify the underlying
table has an enforced upper bound on `WHERE` matches. A `get()` on
a soft-deleted-rows scope or a multi-tenant query without
`tenant_id` filter is always a finding.

The same pattern shows up in other ORMs: Active Record
`Model.find_each` / `.in_batches` instead of `.all`; Django
`QuerySet.iterator(chunk_size=N)` instead of `list(qs)`; SQLAlchemy
`session.execute(...).yield_per(N)` instead of `.scalars().all()`;
Prisma `findMany({take, cursor})` paged loop instead of unbounded
`findMany`.

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

## 8.1 Covering Index and Leftmost-Prefix Rules

A **covering index** contains every column the query reads — the
optimizer can satisfy the query from the index alone and skip the
table read (`Using index` in `EXPLAIN`). A composite index follows
the **leftmost-prefix rule**: an index on `(a, b, c)` serves
`WHERE a=…`, `WHERE a=… AND b=…`, `WHERE a=… AND b=… AND c=…` —
but NOT `WHERE b=…` or `WHERE c=…` alone.

```sql
-- Find queries that could be covered (high rows_examined,
-- few columns in SELECT)
SELECT
    LEFT(DIGEST_TEXT, 80) as query,
    COUNT_STAR as calls,
    ROUND(SUM_ROWS_EXAMINED / NULLIF(COUNT_STAR, 0), 0) as rows_per_call
FROM performance_schema.events_statements_summary_by_digest
WHERE SCHEMA_NAME = DATABASE()
    AND DIGEST_TEXT LIKE 'SELECT%'
    AND SUM_ROWS_EXAMINED > 10000
ORDER BY rows_per_call DESC
LIMIT 15;
```

For each candidate, run `EXPLAIN FORMAT=JSON` and check:

- `using_index: true` → already covered.
- `using_index: false` AND the `SELECT` returns ≤ 4 columns →
  candidate for a covering composite index.

**Leftmost-prefix detection (skipped index columns):**

```sql
-- EXPLAIN shows the actual key_len used vs the index's full length;
-- a partial match means later columns are unused.
EXPLAIN FORMAT=JSON
SELECT /* the query */ \G
-- Look for `used_key_parts` in the JSON.
```

Typical mistake: index `(a, b, c)` but the query is `WHERE b=? AND
c=?` — index unused, full scan. Fix by either reordering the index
to `(b, c, a)` (if `a` predicate is rare) or adding a second index
`(b, c)`.

**Index merge** (MySQL 5.6+) can union two single-column indexes
but is usually slower than a properly-ordered composite — flag
`Using union(idx_a,idx_b)` in `EXPLAIN` as a redesign signal.

---

## 8.2 INSTANT vs INPLACE DDL Matrix (MySQL 8.0+)

MySQL 8.0 added `ALGORITHM=INSTANT` for many `ALTER TABLE`
operations. Knowing the difference between `INSTANT`, `INPLACE`,
and `COPY` saves hours of downtime on large tables.

| Operation | 8.0+ Algorithm | Locks Table? | Downtime |
| --------- | -------------- | ------------ | -------- |
| `ADD COLUMN … DEFAULT …` (at end) | `INSTANT` | No | < 1 s |
| `ADD COLUMN` (any position 8.0.29+) | `INSTANT` | No | < 1 s |
| `DROP COLUMN` (8.0.29+) | `INSTANT` | No | < 1 s |
| `RENAME COLUMN` | `INSTANT` | No | < 1 s |
| `ADD INDEX` (secondary) | `INPLACE` | No (online) | minutes |
| `DROP INDEX` (secondary) | `INPLACE` | No (online) | seconds |
| `ADD COLUMN … AUTO_INCREMENT` | `COPY` | Yes | hours |
| `CHANGE COLUMN` (type change) | `COPY` | Yes | hours |
| `OPTIMIZE TABLE` | `INPLACE` (5.6+) | No (online) | hours |
| `ADD FOREIGN KEY` | `INPLACE` | No, but locks writes | minutes |

Always specify the algorithm explicitly so a fallback to `COPY`
fails the migration loudly instead of silently locking the table:

```sql
ALTER TABLE users
  ADD COLUMN last_login_at TIMESTAMP NULL,
  ALGORITHM=INSTANT, LOCK=NONE;
```

If the operation is not INSTANT-eligible the statement errors with
`ALGORITHM=INSTANT is not supported for this operation` — the
migration author then chooses INPLACE with explicit lock policy or
schedules a maintenance window.

**INSTANT add column limit (8.0.29+):** at most 64 INSTANT-added
columns per table before a table rebuild is required. Track usage
via `information_schema.INNODB_TABLES.INSTANT_COLS`.

---

## 8.3 Replication Lag Queries

Lagged replicas serve stale reads, break read-your-writes, and
block failover. Monitor lag explicitly — `SHOW REPLICA STATUS` is
the canonical source.

```sql
-- 8.0.22+: REPLICA, older: SLAVE
SHOW REPLICA STATUS \G
-- Look for:
--   Seconds_Behind_Source (NULL if not running)
--   Retrieved_Gtid_Set vs Executed_Gtid_Set (GTID gap = pending events)
--   Last_IO_Error / Last_SQL_Error
--   Replica_IO_Running / Replica_SQL_Running (both should be 'Yes')
```

```sql
-- GTID gap detection (multi-source / chain replication)
SELECT
    @@gtid_executed AS executed,
    @@gtid_purged   AS purged;
```

| `Seconds_Behind_Source` | Status | Action |
| ----------------------- | ------ | ------ |
| 0-5 | OK | - |
| 5-30 | Warning | Investigate hot writes on source |
| 30-300 | HIGH | Replica falling behind; failover blocked |
| > 300 OR NULL | CRITICAL | Replication broken — inspect `Last_*_Error` |

**Common causes of lag:**

- Single-threaded SQL applier on a multi-threaded source workload —
  enable parallel replication: `replica_parallel_workers = 4-16`,
  `replica_parallel_type = LOGICAL_CLOCK`.
- Long-running query on source that takes minutes to replay.
- A large `ALTER TABLE` running on the replica in serial mode.
- Disk-write saturation on the replica.

```sql
-- Parallel applier status
SHOW REPLICA STATUS \G
-- Look for: Replica_Parallel_Workers, Replica_SQL_Running_State
```

---

## 8.4 slow_query_log Integration

The slow query log is the audit's primary production observation
channel. Without it, the auditor relies on `events_statements_summary_by_digest`
snapshots which lose per-execution context (exact bind values,
client host, user).

```sql
-- Enable (runtime, persists until restart)
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1.0;          -- 1 second
SET GLOBAL log_queries_not_using_indexes = 'ON';
SET GLOBAL log_slow_admin_statements = 'OFF';

-- Persist across restart: add to my.cnf:
-- [mysqld]
-- slow_query_log = 1
-- slow_query_log_file = /var/log/mysql/slow.log
-- long_query_time = 1.0
-- log_queries_not_using_indexes = 1
```

**Audit checks:**

- `slow_query_log = ON` AND `long_query_time` ≤ 1.0 on production.
  A 10-second threshold misses 95% of OLTP slowness.
- `log_output = FILE` (not `TABLE`) — table logging serializes
  through a single InnoDB table and itself becomes a bottleneck.
- Log file rotated (logrotate or `mysqladmin flush-logs`) and
  parsed via `mysqldumpslow -s t -t 20 /var/log/mysql/slow.log` or
  `pt-query-digest` for grouping.
- `log_slow_replica_statements = ON` on replicas — catches queries
  the source executed fast but the replica replays slowly.

Every HIGH or CRITICAL slow-query finding citing the slow log MUST
include: timestamp, `Query_time`, `Lock_time`, `Rows_examined`,
`Rows_sent`. A `slow.log` excerpt without those fields is not
evidence.

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

// Connection pooling: use ProxySQL or MaxScale (PgBouncer is PostgreSQL-only)
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
#
# Credentials are read from a login-path stored once via:
#   sudo mysql_config_editor set --login-path=health_check \
#       --host=localhost --user=debian-sys-maint --password
# The login-path file (~/.mylogin.cnf) is obfuscated and chmod 600.
# Never export MYSQL_PWD — it leaks via /proc/<pid>/environ to any
# process running as the same user.

set -euo pipefail

mysql --login-path=health_check << 'SQL' | mail -s "MySQL Health $(date +%Y-%m-%d)" admin@example.com
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

---

## UNCERTAINTY DISCIPLINE

If evidence is incomplete: lower confidence, reduce severity, move the
observation into Non-Blocking Observations, and explicitly state the
uncertainty. Do not present assumptions as facts. Do not use weasel
words ("could potentially", "might allow", "in theory") to inflate
report length — either the finding is grounded or it isn't.

---

## CATEGORY ENUM (Audit-Type Override)

The shared finding schema (see `components/audit-output-format.md`) lists a broad `Category` enum spanning all audit types. For MYSQL_PERFORMANCE_AUDIT, restrict `**Category:**` to the MySQL-specific values below. Security / code-review / UX / application-layer perf categories from the shared enum MUST NOT appear in this audit's findings.

Allowed `Category` values for MySQL performance findings:

- `Query Plan` *(full table scan, filesort, temporary table, derived-table materialization)*
- `Index Coverage` *(missing index, wrong leading column, non-covering index, redundant index)*
- `Schema` *(data type bloat, charset/collation mismatch, normalization affecting hot reads)*
- `Locking` *(row/table lock contention, gap-lock interference, deadlock-prone access pattern)*
- `Transaction` *(long-running tx, isolation level wrong for workload, savepoint abuse)*
- `Replication/Replica Lag` *(replication-unfriendly DML, binlog format, replica-only read divergence)*
- `Connection Pool` *(exhaustion, undersized pool, sticky connection)*
- `InnoDB Buffer Pool` *(buffer-pool hit ratio, page churn, working set vs RAM)*
- `Statistics/Optimizer` *(stale stats, optimizer-trace flag, JOIN order regression)*
- `Cost Amplification` *(query repeated per row, N+1 in ORM, missing batching)*

Application-layer performance issues (CPU, GC, event loop blocking, in-process caching) belong in PERFORMANCE_AUDIT.md, not here. Postgres-specific findings belong in POSTGRES_PERFORMANCE_AUDIT.md.

If a candidate finding does not fit any of these categories, it is either out of scope for this audit or the category needs to be added to this list deliberately — never silently fall back to a code-review category.

---

## FALSE-POSITIVE CONTROL
<!-- v42-splice: fp-control-gates -->

Every candidate finding passes through three gates in this order. A
finding that fails any gate is dropped (record the drop step and reason
in `## Skipped (FP recheck)`); a finding that survives all three is
promoted to `## Findings`.

```text
1. Adversarial self-review  → intent check  (per finding, mandatory for HIGH / CRITICAL)
2. 6-step FP recheck        → procedure check  (per finding, every severity — see SELF-CHECK below)
3. Calibration              → severity + confidence sanity, anti-padding (per report)
```

The order is fixed: adversarial review first (cheap, kills bad
hypotheses), procedure recheck second (expensive, requires reading
±20 lines and tracing data flow), calibration third (applies to the
surviving set as a whole).

### Gate 1 — Adversarial self-review (intent check)

For every HIGH or CRITICAL finding, attempt to disprove it before
reporting. Search explicitly for:

- Upstream sanitization / validation that defangs the input
- Framework guarantees that block the path (escaping, ORM bindings,
  CSRF middleware, transaction isolation)
- Impossible execution paths (dead code, environment-gated branches,
  feature flags off in production, code never imported / called)
- Privilege constraints that prevent the required actor class from
  reaching the sink
- Environmental limitations (the function exists but is never wired
  into a route, command, scheduled job, or webhook)

A finding survives Gate 1 only if the failure mode (security:
exploitability; performance: realistic latency hit; code-review:
reachable regression) remains plausible after adversarial review.
Document in your scratchpad which counter-evidence you considered and
why it failed.

### Gate 2 — 6-step FP recheck (procedure check)

The 6-step procedure is defined in `## SELF-CHECK` of the audit prompt
(propagated from `components/audit-fp-recheck.md`). Each step has a
fail-fast condition; drops are recorded in `## Skipped (FP recheck)`
with the step number and a one-line reason citing concrete tokens from
the source.

### Gate 3 — Calibration (severity + confidence sanity, anti-padding)

After Gates 1 and 2, apply these rules to the surviving set. The
calibration discipline itself is canonicalized in
`components/audit-uncertainty-discipline.md` — apply that SOT in full
here; the rules below are pure cross-references that point its outputs
at the per-audit rubric anchors.

- **Confidence + severity calibration.** Apply UNCERTAINTY DISCIPLINE
  per `components/audit-uncertainty-discipline.md` (lower confidence,
  lower severity, then move to Non-Blocking Observations or drop). Then
  re-rate severity using the Severity Ceiling Table in
  `components/audit-severity-anchor.md` against the realistic
  preconditions. For SECURITY: cross-multiply with
  `## DATA CLASSIFICATION`. For PERFORMANCE: cross-reference
  `## SEVERITY THRESHOLDS`. For CODE_REVIEW: cross-reference
  `## SEVERITY AND CONFIDENCE`.
- **No padding.** Five weak speculative MEDIUMs are worse than one
  verified CRITICAL with a working failure scenario. The weasel-word
  ban (`could potentially`, `might allow`, `in theory`) and the
  hidden-assumptions ban are defined in
  `components/audit-uncertainty-discipline.md` `## Anti-Patterns`. Do
  not restate them inline — apply the SOT.

<!-- v42-splice: rubric-anchors -->

**Audit rubric anchors** (canonical sources of truth — do not redefine inline):

- `components/audit-severity-anchor.md` — CRITICAL / HIGH / MEDIUM / LOW labels + Severity Ceiling Table.
- `components/audit-uncertainty-discipline.md` — UNCERTAINTY DISCIPLINE (lower confidence / severity, anti-padding).
- `components/audit-fp-control-gates.md` — three-gate FALSE-POSITIVE CONTROL wrapper (Adversarial → 6-step recheck → Calibration). Gate 2 procedure is `## SELF-CHECK` below.

## 10. SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

### Procedure

For every candidate finding, execute these six steps in order BEFORE deciding whether to report or drop it. The step-by-step reasoning is an internal trace — perform it mentally per finding and do NOT emit the trace itself into the report. The only artifacts the report contains are: (a) `## Skipped (FP recheck)` rows for drops, with `dropped_at_step` and a one-line reason; and (b) `## Findings` entries for survivors. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look problematic in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script; an `if (!isPaid)` inverted-flag guard inside a unit-test mock).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the failure surface (e.g. an upstream sanitizer or invariant documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform or framework (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, a transactional boundary the ORM enforces, etc.), the finding is a design trade-off, not a defect. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual failure scenario, not the rule label. A theoretical sink behind 3 unlikely preconditions and no realistic blast radius is not CRITICAL. If you cannot describe a concrete failure path that a user or the business would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

### Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `src/orders.ts:88` | `LOG-INVERTED-COND` | 3 | `!isPaid guard runs inside the test-only mock at fixtures/orders.mock.ts:14; production path uses isPaid` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

### When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

### Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not failure-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Emitting the internal recheck trace into the report (a `## SELF-CHECK` block per finding inside `## Findings`, a "step 1: …, step 2: …" walkthrough next to each finding, etc.) — the recheck is internal-only. Report ONLY the outcome: a row in `## Skipped (FP recheck)` if dropped, an entry in `## Findings` if survived.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op internally (a `cross-ref skipped: no allowlist file present` acknowledgement) but the step itself MUST be performed.

## 11. OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->

### Report Path

```text
.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md
```

- `<type>` is one of the 7 canonical slugs documented in the next section. Backward-compat aliases resolve to a canonical slug at dispatch time.
- Timestamp is local time, generated with `date '+%Y-%m-%d-%H%M'` (24-hour, no separator between hour and minute).
- The audit creates the directory with `mkdir -p .claude/audits` on first write.
- The toolkit does NOT auto-add `.claude/audits/` to `.gitignore` — let the user decide which audit reports to commit.

---

### Type Slug to Prompt File Map

| `/audit` argument | Report filename slug | Prompt loaded |
|-------------------|----------------------|---------------|
| `security` | `security` | `templates/<framework>/prompts/SECURITY_AUDIT.md` |
| `code-review` | `code-review` | `templates/<framework>/prompts/CODE_REVIEW.md` |
| `performance` | `performance` | `templates/<framework>/prompts/PERFORMANCE_AUDIT.md` |
| `deploy-checklist` | `deploy-checklist` | `templates/<framework>/prompts/DEPLOY_CHECKLIST.md` |
| `mysql-performance` | `mysql-performance` | `templates/<framework>/prompts/MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres-performance` | `postgres-performance` | `templates/<framework>/prompts/POSTGRES_PERFORMANCE_AUDIT.md` |
| `ui-design-review` | `ui-design-review` | `templates/<framework>/prompts/DESIGN_REVIEW.md` |

Backward-compat aliases: `code` resolves to `code-review`, `deploy` resolves to `deploy-checklist`, and `design-review` resolves to `ui-design-review` at dispatch time (slug renamed in v6.30.0 to clarify the file's UI-only scope — the prompt file keeps its historical name `DESIGN_REVIEW.md` for splice stability). The report filename ALWAYS uses the canonical slug, never the alias.

---

### YAML Frontmatter

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

### Section Order (Fixed)

After the YAML frontmatter, the report MUST contain these five H2 sections in this exact order:

1. `## Summary`
2. `## Findings`
3. `## Skipped (allowlist)`
4. `## Skipped (FP recheck)`
5. `## Council verdict`

Plus the report's title H1 (`# <Type Title> Audit — <project name>`) immediately after the closing `---` of the frontmatter and before `## Summary`.

Do NOT reorder. Do NOT introduce intermediate H2 sections. Render an empty section as the literal placeholder `_None_` — the allowlist case uses a longer placeholder shown verbatim in the Skipped (allowlist) section below. Phase 15 navigates by these literal H2 headings.

---

### Summary Section

The Summary table has columns `severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck` and MUST contain exactly four rows in this order: CRITICAL, HIGH, MEDIUM, LOW. Render zeros (`0`) in any cell whose count is zero — do NOT omit rows for severities with no findings, and do NOT collapse `0`s to blank cells. The rubric is in `components/severity-levels.md` — do not redefine. INFO is NOT a reportable finding severity; informational observations are NEVER emitted (neither in `## Findings` nor in `## Summary` nor anywhere else in the report). See the Full Report Skeleton below for the verbatim layout.

---

### Finding Entry Schema (### Finding F-NNN)

Each surviving finding becomes an `### Finding F-NNN` H3 block. `F-NNN` is zero-padded to 3 digits and sequential per report (`F-001`, `F-002`, ...).

The entry has 11 fields rendered in two presentation styles:

- **Bullet-label fields (1–7):** rendered as `**<Label>:**` bullets immediately under the H3, in the order shown below.
- **Section-block fields (8–11):** rendered as `**<Label>:**` paragraph headings, each followed by its block (code fence, list, prose, or diff).

The fields appear in this exact order:

1. **ID** — the `F-NNN` identifier matching the H3 heading.
2. **Severity** — one of CRITICAL, HIGH, MEDIUM, LOW (per `components/severity-levels.md`).
3. **Confidence** — one of HIGH, MEDIUM, LOW. HIGH = directly observable in code with a clear execution path; MEDIUM = strong evidence with some inferred assumptions; LOW = weak signal or incomplete evidence. LOW-confidence findings MUST explicitly state the uncertainty in `Why it is real`. (Note: Confidence and Severity share the tokens HIGH/MEDIUM/LOW; the bullet label disambiguates — never write a bare `HIGH` without its `**Severity:**` or `**Confidence:**` label.)
4. **Category** — one of: Correctness, Business Logic, Reliability, Concurrency, Performance, Operational Reliability, Operational Maintainability Risk, API Contract, Data Integrity, Security, Data Exposure. (Audit-type prompts MAY restrict this enum further — see the prompt's own `## Category` constraint, if any.)
5. **Rule** — the auditor's rule-id (e.g. `SEC-SQL-INJECTION`, `PERF-N+1`, `LOG-INVERTED-COND`, `DATA-PARTIAL-UPDATE`).
6. **Location** — `<path>:<start>-<end>` for a range, or `<path>:<line>` for a single point.
7. **Claim** — one-sentence statement of the alleged issue, ≤ 160 chars.
8. **Code** — verbatim ±10 lines around the flagged line, fenced with the language matching the source extension (see Verbatim Code Block section).
9. **Data flow** — markdown bullet list tracing input from origin to the flagged sink, ≤ 6 hops.
10. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from in Phase 15.
11. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

Field omission rules (the omission key is **Severity**, never Confidence):

- **Severity = CRITICAL / HIGH** — all 11 fields required.
- **Severity = MEDIUM** — MAY omit Data flow and Suggested fix when they add no value. Confidence remains required (default `Confidence: MEDIUM` if not stated).
- **Severity = LOW** — MAY collapse to ID + Severity + Confidence + Location + Claim + one-line evidence (the Code / Data flow / Why it is real / Suggested fix sections may be merged into the Claim).

Note: omission rules apply per **Severity**. A LOW-severity finding with HIGH confidence may collapse; a HIGH-severity finding with LOW confidence MUST keep all 11 fields (LOW confidence requires the uncertainty be explicit, which lives in `Why it is real`).

See the Full Report Skeleton below for the verbatim entry template (a SQL-INJECTION example demonstrating all required fields).

The bullet labels (`**Severity:**`, `**Confidence:**`, `**Category:**`, `**Rule:**`, `**Location:**`, `**Claim:**`) and section labels (`**Code:**`, `**Data flow:**`, `**Why it is real:**`, `**Suggested fix:**`) are byte-exact — Phase 15's Council parser navigates the entry by them.

---

### Verbatim Code Block (AUDIT-03)

#### Layout

```text
<!-- File: <path> Lines: <start>-<end> -->
[optional clamp note]
[fenced code block here with <lang> from the Extension Map]
```

`<lang>` is the language fence selected per the Extension to Language Fence Map below. `start = max(1, L - 10)` and `end = min(T, L + 10)` where `L` is the flagged line and `T` is the total line count of the file. The HTML range comment is the FIRST line above the fence; the clamp note (when present) is the SECOND line above the fence.

#### Clamp Behaviour

When the ±10 range is clipped by the start or end of the file, emit a `<!-- Range clamped to file bounds (start-end) -->` note immediately above the fenced block. Example: flagged line 5 in an 8-line file → `start = max(1, 5-10) = 1`, `end = min(8, 5+10) = 8`, rendered range `1-8`, clamp note required.

#### Extension to Language Fence Map

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

#### No Literal Placeholders

The skeleton uses square-bracketed placeholders such as `[fenced code block here — verbatim ±10 lines around src/users.ts:42, ts language fence]` and `[optional clamp note]` to DESCRIBE what to inject. These descriptions MUST NOT appear in the final report. When emitting an actual finding:

- Replace `[fenced code block here — verbatim ±10 lines around <path>:<line>, <lang> language fence]` with the real fenced code block at the resolved path, line range, and language fence.
- Replace `[fenced code block here — replacement using parameterized query]` (and similar `Suggested fix` placeholders) with the actual fenced replacement snippet.
- Omit `[optional clamp note]` entirely when the ±10 window does not hit file bounds; emit the `<!-- Range clamped to file bounds (start-end) -->` line verbatim when it does.

A report that ships literal `[fenced code block here ...]` text is malformed; Phase 15 will treat it as a broken finding.

---

### Skipped (allowlist) Section

Columns: `ID | path:line | rule | council_status`. Empty-state placeholder is the literal string `_None — no` followed by a backtick-quoted `audit-exceptions.md` reference and `in this project_`. The verbatim layout is in the Full Report Skeleton below.

`council_status` is parsed from the matching entry's `**Council:**` bullet inside `audit-exceptions.md`. Allowed values: `unreviewed`, `council_confirmed_fp`, `disputed`. Use `sed '/^<!--/,/^-->/d'` (per `commands/audit-restore.md` post-13-05 fix) to strip HTML comment blocks before walking entries — the seed file ships with an HTML-commented example heading that would otherwise produce false matches. The `F-A001`..`F-ANNN` numbering is independent of `F-NNN` for surviving findings.

---

### Skipped (FP recheck) Section

Columns: `path:line | rule | dropped_at_step | one_line_reason`. Empty-state placeholder: `_None_`. The verbatim layout is in the Full Report Skeleton below.

`dropped_at_step` MUST be an integer in 1-6 matching the FP-recheck step where the finding was dropped (see `components/audit-fp-recheck.md`). `one_line_reason` MUST be ≤ 100 chars and reference concrete tokens visible in the source — never `looks fine`, `trusted code`, or `out of scope`.

---

### Council Verdict Slot (handoff to Phase 15)

The audit writes this section as a literal placeholder. Phase 15's `/council audit-review` mutates it in place after collating Gemini + ChatGPT verdicts.

```markdown
## Council verdict

_pending — run /council audit-review_
```

Byte-exact constraints: U+2014 em-dash (literal `—`, not hyphen-minus, not en-dash); single-underscore italic (`_..._`), no asterisks; no backticks, no bold, no code fence, no trailing whitespace. DO NOT REFORMAT — Phase 15 greps for this exact byte sequence to locate the slot before rewriting it.

---

### Full Report Skeleton

The skeleton below uses a SECURITY finding (SQL injection) as the
illustrative example. For other audit types substitute the appropriate
`audit_type`, H1 title, finding `Category` (e.g. Correctness for
code-review, Performance for performance, Reliability for design-review),
and `Rule` namespace. The schema (field order, byte-exact bullet labels,
section order, Council slot string) is identical across all 7 audit
types.

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
| CRITICAL | 0 | 0 | 0 |
| HIGH | 1 | 1 | 1 |
| MEDIUM | 0 | 0 | 0 |
| LOW | 0 | 0 | 0 |

## Findings

### Finding F-001

- **Severity:** HIGH
- **Confidence:** HIGH
- **Category:** Security
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
