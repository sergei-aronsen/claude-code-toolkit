# Database Performance Audit Guide

> Universal MySQL/MariaDB performance audit guide

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

## Access to Statistics

### Check sys schema presence

```sql
SHOW DATABASES LIKE 'sys';
```

**If sys exists** - use convenient views:

- `sys.statement_analysis`
- `sys.schema_unused_indexes`

**If no sys** - work directly with `performance_schema`:

- `performance_schema.events_statements_summary_by_digest`
- `performance_schema.table_io_waits_summary_by_index_usage`

### Check user permissions

```sql
SHOW GRANTS;
```

For full audit you need access to `performance_schema`. If not available - use `debian-sys-maint` (password in `/etc/mysql/debian.cnf`).

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
innodb_buffer_pool_instances = 4          # For parallelism (1 per GB)
```

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

**Important:** Check uptime! Statistics reset on restart.

```sql
SELECT ROUND(VARIABLE_VALUE / 86400, 1) as uptime_days
FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Uptime';
```

**Safe to remove (uptime > 7 days):**

- Single-column boolean indexes on rare filters
- Duplicate indexes
- Indexes on archive tables

**DO NOT remove:**

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

- Parallel workers update same record
- Transactions lock tables in different order
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

**Problem signs:**

- `index_mb` > `data_mb` → too many indexes
- Table > 1GB → plan archiving/partitioning
- `jobs` table bloated → worker problem

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
- [ ] N+1 problems fixed

---

## Resources

- [MySQL Performance Schema](https://dev.mysql.com/doc/refman/8.0/en/performance-schema.html)
- [Percona Toolkit](https://www.percona.com/software/database-tools/percona-toolkit) - pt-query-digest
- [MySQLTuner](https://github.com/major/MySQLTuner-perl)
