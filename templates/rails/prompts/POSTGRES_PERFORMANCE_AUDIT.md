# PostgreSQL Performance Audit Guide

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

### 11.2 Rails-Specific

```ruby
# ❌ Dangerous on large tables
class AddStatusToSites < ActiveRecord::Migration[7.1]
  def change
    add_column :sites, :status, :string, null: false # Locks table!
    add_index :sites, :status # Blocks writes!
  end
end

# ✅ Safe — use strong_migrations gem + disable_ddl_transaction!
class AddStatusToSites < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :sites, :status, :string
    add_index :sites, :status, algorithm: :concurrently
    # Backfill in batches, then add NOT NULL constraint
  end
end
```

### 11.3 Checklist

- [ ] `NOT NULL` columns added with `DEFAULT` value (instant in PG 11+)
- [ ] Indexes created with `algorithm: :concurrently` + `disable_ddl_transaction!`
- [ ] Use `strong_migrations` gem for automatic safety checks
- [ ] No `DROP COLUMN` on large tables without prior assessment
- [ ] `ALTER TYPE` avoided on large tables (rewrites entire table)
- [ ] Lock timeout set: `SET lock_timeout = '5s'`
- [ ] Migrations tested on production-size dataset first
