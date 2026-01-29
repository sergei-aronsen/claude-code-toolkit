# Performance Audit — Base Template

## Goal

Comprehensive performance audit of a web application. Act as a Senior Performance Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for audits — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Target |
| --- | ------- | -------- |
| 1 | Homepage TTFB | < 500ms |
| 2 | Bundle size (gzipped) | < 500KB |
| 3 | No N+1 queries | 0 |
| 4 | Database indexes | All FKs indexed |
| 5 | Caching enabled | Yes |

---

## 0.1 PROJECT SPECIFICS — [Project Name]

**Current metrics:**

- Homepage load time: [X]ms
- Bundle size: [X]KB
- Database queries per page: [X]

**Already optimized:**

- [ ] Caching: [what is cached]
- [ ] CDN: [is it used]
- [ ] Lazy loading: [where]

---

## 0.2 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Blocks work, > 5s load time | **BLOCKER** |
| HIGH | Noticeable slowdown, > 2s | Fix before deploy |
| MEDIUM | Can improve, > 1s | Next sprint |
| LOW | Micro-optimization | Backlog |

---

## 1. DATABASE PERFORMANCE

### 1.1 N+1 Queries

```text
❌ Bad: 1 query + N queries for related data
✅ Good: 1-2 queries with eager loading
```text

- [ ] No N+1 patterns
- [ ] Eager loading used
- [ ] Joins instead of multiple queries

### 1.2 Query Optimization

- [ ] Indexes on frequently used columns
- [ ] Indexes on foreign keys
- [ ] No SELECT * where not needed

### 1.3 Slow Queries

- [ ] No queries > 100ms
- [ ] EXPLAIN for complex queries
- [ ] Pagination for large datasets

### 1.4 ORM Hooks (GORM/Ent)

ORM hooks (BeforeDelete, AfterCreate) can silently trigger N+1 during bulk operations.

```go
// ❌ N+1 in hook — deletes one by one
func (s *Site) BeforeDelete(tx *gorm.DB) error {
    var checks []Check
    tx.Where("site_id = ?", s.ID).Find(&checks)
    for _, c := range checks {
        tx.Delete(&c) // N queries!
    }
    return nil
}

// ✅ Bulk delete — single query
func (s *Site) BeforeDelete(tx *gorm.DB) error {
    return tx.Where("site_id = ?", s.ID).Delete(&Check{}).Error
}
```

- [ ] Delete/update hooks do not use per-record iteration
- [ ] Hooks do not make synchronous external HTTP calls
- [ ] Use DB-level cascades (`ON DELETE CASCADE`) where possible

### 1.5 Complex Query Patterns (Subqueries)

Chaining multiple subquery conditions can cause exponential query complexity even with proper indexes.

```go
// ❌ Heavy — multiple subqueries
db.Where("id IN (?)", db.Table("checks").Select("site_id").Where("status = ?", "alive")).
   Where("user_id IN (?)", db.Table("users").Select("id").Where("active = ?", true)).
   Find(&sites)

// ✅ Better — explicit JOIN
db.Joins("JOIN checks ON checks.site_id = sites.id").
   Where("checks.status = ?", "alive").
   Find(&sites)
```

- [ ] No more than 2 nested subquery conditions per query
- [ ] Subqueries replaced with JOINs where possible
- [ ] No subquery conditions inside loops or polling endpoints

---

## 2. CACHING

### 2.1 Application Cache

- [ ] Frequently read data cached
- [ ] Cache invalidation configured
- [ ] TTL reasonable

### 2.2 HTTP Cache

- [ ] Static assets have cache headers
- [ ] ETags or Last-Modified
- [ ] CDN for static files

### 2.3 Query Cache

- [ ] Heavy queries cached
- [ ] Cache key includes parameters

---

## 3. FRONTEND PERFORMANCE

### 3.1 Bundle Size

- [ ] JavaScript < 500KB gzipped
- [ ] CSS < 100KB gzipped
- [ ] Code splitting used

### 3.2 Loading Strategy

- [ ] Critical CSS inline
- [ ] Non-critical CSS lazy
- [ ] JavaScript defer/async

### 3.3 Images

- [ ] Optimized (WebP, AVIF)
- [ ] Lazy loading
- [ ] Proper sizes (srcset)

### 3.4 Core Web Vitals

- [ ] LCP < 2.5s
- [ ] FID < 100ms
- [ ] CLS < 0.1

### 3.5 Polling and Repeated Requests

Frequent frontend polling can overwhelm the backend if endpoints are not optimized.

- [ ] Endpoints called at intervals < 30s respond in < 50ms
- [ ] Polling endpoints use cache (Redis/in-memory), not heavy DB aggregations
- [ ] Polling intervals are reasonable (no sub-second polling for non-critical data)
- [ ] Consider WebSockets/SSE for real-time data instead of polling

---

## 4. API PERFORMANCE

### 4.1 Response Time

- [ ] API endpoints < 500ms
- [ ] No blocking operations in handlers

### 4.2 Payload Size

- [ ] Pagination for lists
- [ ] Only needed fields in response
- [ ] Gzip compression

### 4.3 Rate Limiting

- [ ] Protection from abuse
- [ ] Graceful degradation

---

## 5. BACKGROUND JOBS

### 5.1 Queue Usage

- [ ] Heavy operations in queue
- [ ] Email sending async
- [ ] File processing async

### 5.2 Job Configuration

- [ ] Timeout configured
- [ ] Retry policy
- [ ] Failed job handling

### 5.3 Queue Payload Size

Data passed to background workers (Asynq, Machinery, custom goroutine pools) is serialized into Redis/DB. Large payloads waste memory and slow processing.

```go
// ❌ Raw HTML in task payload
task := asynq.NewTask("process_site", []byte(htmlContent))

// ✅ Store data externally, pass only a reference
rdb.Set(ctx, fmt.Sprintf("site_html:%d", siteID), htmlContent, 5*time.Minute)
payload, _ := json.Marshal(map[string]int{"site_id": siteID})
task := asynq.NewTask("process_site", payload)
```

- [ ] Task payloads do not contain raw HTML, file content, or binary data
- [ ] Large data is stored in Redis/S3, task receives only a key or ID
- [ ] Monitor Redis memory usage for payload bloat

### 5.4 Job Idempotency

Jobs may be retried on failure. A non-idempotent job can corrupt data when executed more than once.

```go
// ❌ Dangerous — not idempotent
func (w *Worker) ProcessTask(ctx context.Context, task Task) error {
    site, _ := w.repo.FindByID(ctx, task.SiteID)
    site.Views++ // Double-counted on retry!
    return w.repo.Save(ctx, site)
}

// ✅ Safe — idempotent with state check
func (w *Worker) ProcessTask(ctx context.Context, task Task) error {
    site, _ := w.repo.FindByID(ctx, task.SiteID)
    if site.Status == "processed" {
        return nil // Already done
    }
    return w.repo.UpdateInTx(ctx, func(tx *sql.Tx) error {
        _, err := tx.ExecContext(ctx,
            "UPDATE sites SET status = 'processed' WHERE id = $1 AND status != 'processed'",
            task.SiteID)
        return err
    })
}
```

- [ ] Jobs produce the same result when executed multiple times
- [ ] State-changing jobs check current state before modifying
- [ ] External API calls use idempotency keys where supported
- [ ] Database operations use transactions or unique constraints to prevent duplicates

---

## 6. INFRASTRUCTURE

### 6.1 Server

- [ ] Enough RAM
- [ ] CPU not overloaded
- [ ] Disk I/O normal

### 6.2 Database

- [ ] Connection pooling
- [ ] Read replicas (if needed)
- [ ] Query monitoring

### 6.3 Production Readiness

Debug settings in production degrade performance.

```bash
# Check for debug flags
grep -rn "log\.SetFlags\|log\.SetOutput\|debug\|pprof" . --include="*.go" | grep -v "test\|vendor\|_test.go"
```

- [ ] Debug/verbose logging disabled in production (use structured logger: zerolog, zap)
- [ ] `net/http/pprof` endpoint not exposed publicly (restrict to internal network)
- [ ] Race detector not enabled in production binary (`-race` flag)
- [ ] Build with optimizations (`go build` without `-gcflags="-N -l"`)
- [ ] `GOMAXPROCS` set appropriately for container environment

**Cache/Session/Queue Patterns:**

| Component | Bad (Dev) | Good (Prod) |
|-----------|-----------|-------------|
| Cache | In-memory map | Redis (go-redis) |
| Sessions | In-memory | Redis / Database |
| Queue | Channel (in-process) | Redis / NATS / RabbitMQ |
| Logging | fmt.Println | zerolog / zap to aggregator |

- [ ] Cache survives restarts (not in-process `sync.Map` for persistent data)
- [ ] Session store is persistent (Redis, not in-memory map)
- [ ] Background jobs use proper queue, not just goroutines (which die on restart)

### 6.4 Redis Health

If using Redis (go-redis) for cache/sessions/queues, monitor its health.

```bash
redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses|evicted_keys"
redis-cli INFO memory | grep used_memory_human
redis-cli CONFIG GET maxmemory-policy
```

**Hit Ratio:** `hits / (hits + misses)` — should be > 90%.

| Metric | OK | Warning | Critical |
|--------|----|---------|----------|
| Hit ratio | > 90% | 70-90% | < 70% |
| Evicted keys | 0 | Growing slowly | Growing fast |
| Memory usage | < 80% maxmemory | 80-90% | > 90% |

- [ ] Redis hit ratio > 90%
- [ ] `maxmemory-policy` is set (recommended: `allkeys-lru` for cache, `noeviction` for queues)
- [ ] No excessive evictions
- [ ] Connection pool size configured (`PoolSize` in go-redis)

---

## 7. MONITORING

- [ ] APM tool configured
- [ ] Slow query logging
- [ ] Error rate tracking
- [ ] Uptime monitoring

---

## 8. SELF-CHECK

**DO NOT optimize:**

- Code that rarely executes
- Microseconds on hot path
- Premature optimization

**Focus on:**

- Frequent operations
- User-facing performance
- Database bottlenecks

---

## 9. REPORT FORMAT

```markdown
# Performance Audit Report — [Project]
Date: [date]

## Summary

| Metric | Current | Target | Status |
|---------|---------|------|--------|
| TTFB | Xms | <500ms | ✅/❌ |
| Bundle | XKB | <500KB | ✅/❌ |
| LCP | Xs | <2.5s | ✅/❌ |

**Overall Score**: X/10

## Critical Issues
[Details...]

## Recommendations
[What to improve...]

## Quick Wins
[Quick improvements...]
```text

---

## 10. ACTIONS

1. **Measure** — current metrics
2. **Profile** — find bottlenecks
3. **Prioritize** — impact vs effort
4. **Fix** — start with quick wins
5. **Measure again** — confirm improvement

Start audit. Show current metrics and summary.
