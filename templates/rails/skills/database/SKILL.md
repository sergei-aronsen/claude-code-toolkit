# Database Skill

> Load this skill when working with databases, migrations, queries, or data modeling.

---

## Rule

**DATABASE CHANGES MUST BE SAFE AND REVERSIBLE!**

- Always test migrations on staging
- Never delete data without backup
- Index queries, not tables

---

## Migration Best Practices

### Safe Migration Checklist

- [ ] Migration is reversible (has `down` method)
- [ ] No data loss
- [ ] No long locks on production tables
- [ ] Tested on copy of production data
- [ ] Backward compatible with current code

### Dangerous Operations

| Operation | Risk | Safe Alternative |
|-----------|------|------------------|
| Drop column | Data loss | Add new column, migrate, then drop |
| Rename column | Breaks code | Add alias, dual-write, then rename |
| Add NOT NULL | Fails on existing nulls | Add nullable, backfill, then add constraint |
| Change type | Data corruption | Add new column, migrate data |

### Migration Patterns

#### Adding Column Safely

```sql
-- Step 1: Add nullable column
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- Step 2: Backfill data (in batches)
UPDATE users SET phone = 'unknown' WHERE phone IS NULL LIMIT 1000;

-- Step 3: Add NOT NULL constraint (after all data filled)
ALTER TABLE users ALTER COLUMN phone SET NOT NULL;
```

#### Zero-Downtime Column Rename

```sql
-- Step 1: Add new column
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);

-- Step 2: Dual-write in application (write to both columns)

-- Step 3: Backfill existing data
UPDATE users SET full_name = name WHERE full_name IS NULL;

-- Step 4: Switch reads to new column

-- Step 5: Stop writing to old column

-- Step 6: Drop old column (separate migration, later)
ALTER TABLE users DROP COLUMN name;
```

---

## Index Strategies

### When to Add Index

| Query Pattern | Index Type |
|---------------|------------|
| `WHERE status = ?` | Single column |
| `WHERE user_id = ? AND status = ?` | Composite (user_id, status) |
| `WHERE email LIKE 'john%'` | Single column (prefix only) |
| `ORDER BY created_at DESC` | Single column DESC |
| `WHERE status = ? ORDER BY created_at` | Composite (status, created_at) |

### Index Rules

1. **Order matters** in composite indexes
2. **Leftmost prefix** rule
3. **Don't over-index** - indexes slow writes
4. **Cover queries** when possible

### Composite Index Order

```sql
-- Query: WHERE status = ? AND created_at > ?
-- Index should be: (status, created_at)

-- Query: WHERE user_id = ? ORDER BY created_at DESC
-- Index should be: (user_id, created_at DESC)
```

### Check Index Usage

```sql
-- PostgreSQL
EXPLAIN ANALYZE SELECT * FROM users WHERE status = 'active';

-- MySQL
EXPLAIN SELECT * FROM users WHERE status = 'active';
```

---

## N+1 Prevention

### The Problem

```python
# N+1 - BAD
users = User.all()
for user in users:
    print(user.posts.count())  # Query for each user!
```

### Solutions

#### Eager Loading

```python
# Django
users = User.objects.prefetch_related('posts').all()

# Laravel
$users = User::with('posts')->get();

# Prisma
const users = await prisma.user.findMany({
  include: { posts: true }
});
```

#### Batch Loading

```python
# Load IDs first, then batch fetch
user_ids = [u.id for u in users]
posts = Post.where(user_id__in=user_ids).all()
posts_by_user = groupby(posts, 'user_id')
```

### Detecting N+1

```python
# Django Debug Toolbar
# Laravel Debugbar
# Prisma: logging queries

# Manual: count queries per request
# If count >> 10 for simple page, investigate
```

---

## Transaction Patterns

### Basic Transaction

```python
# Python/SQLAlchemy
with session.begin():
    user = User(email='test@example.com')
    session.add(user)
    session.add(Profile(user=user))
    # Auto-commit or rollback
```

```typescript
// Prisma
await prisma.$transaction([
  prisma.user.create({ data: userData }),
  prisma.profile.create({ data: profileData }),
]);

// Or interactive
await prisma.$transaction(async (tx) => {
  const user = await tx.user.create({ data: userData });
  await tx.profile.create({ data: { userId: user.id } });
});
```

### Isolation Levels

| Level | Dirty Read | Non-Repeatable | Phantom |
|-------|------------|----------------|---------|
| READ UNCOMMITTED | Yes | Yes | Yes |
| READ COMMITTED | No | Yes | Yes |
| REPEATABLE READ | No | No | Yes |
| SERIALIZABLE | No | No | No |

**Default:** READ COMMITTED (PostgreSQL), REPEATABLE READ (MySQL)

---

## Connection Pooling

### Why Pool

- Creating connections is expensive
- Databases have connection limits
- Pool reuses connections efficiently

### Configuration

```text
# Recommended settings
min_connections: 2
max_connections: 10
idle_timeout: 30s
connection_timeout: 5s
```

### Pool Size Formula

```text
connections = (core_count * 2) + effective_spindle_count
```

For SSD: `connections = cores * 2 + 1`

### Framework Examples

```javascript
// Prisma
datasource db {
  url = env("DATABASE_URL")
  connectionLimit = 10
}

// Node.js pg
const pool = new Pool({
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});
```

---

## Query Optimization

### EXPLAIN Output

```sql
-- PostgreSQL
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM users WHERE email = 'test@example.com';

-- Look for:
-- - Seq Scan (bad for large tables)
-- - Index Scan (good)
-- - Nested Loop (check if efficient)
-- - Sort (might need index)
```

### Common Optimizations

| Problem | Solution |
|---------|----------|
| Seq Scan on large table | Add index |
| Sort operation | Add index with ORDER BY columns |
| High buffer reads | Increase work_mem |
| Nested Loop with many rows | Consider JOIN strategy |

### Query Tips

```sql
-- Use LIMIT for pagination
SELECT * FROM users ORDER BY id LIMIT 20 OFFSET 100;

-- Use EXISTS instead of IN for large sets
SELECT * FROM users WHERE EXISTS (
  SELECT 1 FROM orders WHERE orders.user_id = users.id
);

-- Avoid SELECT * in production
SELECT id, name, email FROM users;

-- Use covering indexes
CREATE INDEX idx_users_status_email ON users(status) INCLUDE (email);
```

---

## Backup Strategies

### Backup Types

| Type | Speed | Size | Recovery |
|------|-------|------|----------|
| Full | Slow | Large | Fast |
| Incremental | Fast | Small | Medium |
| Differential | Medium | Medium | Medium |

### Backup Schedule

```text
Daily:    Full backup
Hourly:   Incremental backup
Realtime: WAL archiving (PostgreSQL) / Binlog (MySQL)
```

### Test Restores

```bash
# Regular restore testing is CRITICAL
# Monthly: Full restore to test environment
# Verify data integrity after restore
```

---

## Schema Design Tips

### Naming Conventions

```sql
-- Tables: plural, snake_case
users, order_items, user_profiles

-- Columns: snake_case
created_at, updated_at, user_id

-- Indexes: idx_table_columns
idx_users_email, idx_orders_user_id_status

-- Foreign keys: fk_table_reference
fk_orders_user_id
```

### Common Patterns

```sql
-- Soft deletes
deleted_at TIMESTAMP NULL

-- Timestamps
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

-- UUID primary keys
id UUID DEFAULT gen_random_uuid() PRIMARY KEY
```

---

## When to Use This Skill

- Writing database migrations
- Optimizing slow queries
- Designing database schema
- Fixing N+1 queries
- Setting up connection pooling
- Planning backup strategy
