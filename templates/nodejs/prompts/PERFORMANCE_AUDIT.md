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

**What is already optimized:**

- [ ] Caching: [what is cached]
- [ ] CDN: [whether used]
- [ ] Lazy loading: [where]

---

## 0.2 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Blocks operation, > 5s load time | **BLOCKER** |
| HIGH | Noticeable slowdown, > 2s | Fix before deploy |
| MEDIUM | Can be improved, > 1s | Next sprint |
| LOW | Micro-optimization | Backlog |

---

## 1. DATABASE PERFORMANCE

### 1.1 N+1 Queries

```text
Bad: 1 query + N queries for related data
Good: 1-2 queries with eager loading
```text

- [ ] No N+1 patterns
- [ ] Eager loading is used
- [ ] Joins instead of multiple queries

### 1.2 Query Optimization

- [ ] Indexes on frequently used columns
- [ ] Indexes on foreign keys
- [ ] No SELECT * where not needed

### 1.3 Slow Queries

- [ ] No queries > 100ms
- [ ] EXPLAIN for complex queries
- [ ] Pagination for large datasets

### 1.4 ORM Lifecycle Events

ORM hooks and middleware (Prisma middleware, Sequelize hooks, TypeORM subscribers) can silently trigger N+1 during bulk operations.

```typescript
// ❌ N+1 in hook — deletes one by one
beforeDestroy: async (project) => {
  const files = await File.findAll({ where: { projectId: project.id } });
  for (const file of files) {
    await file.destroy(); // N queries!
  }
}

// ✅ Bulk delete
beforeDestroy: async (project) => {
  await File.destroy({ where: { projectId: project.id } }); // 1 query
}
```

- [ ] Delete/update hooks do not use per-record iteration
- [ ] Hooks do not make synchronous external API calls
- [ ] Use DB-level cascades where possible

### 1.5 Complex Query Patterns (Subqueries)

Chaining multiple subquery conditions can cause exponential query complexity even with proper indexes.

- [ ] No more than 2 nested subquery conditions per query
- [ ] Subqueries replaced with JOINs where possible
- [ ] No subquery conditions inside loops or polling endpoints

---

## 2. CACHING

### 2.1 Application Cache

- [ ] Frequently read data is cached
- [ ] Cache invalidation is configured
- [ ] TTL is reasonable

### 2.2 HTTP Cache

- [ ] Static assets have cache headers
- [ ] ETags or Last-Modified
- [ ] CDN for static files

### 2.3 Query Cache

- [ ] Heavy queries are cached
- [ ] Cache key includes parameters

---

## 3. FRONTEND PERFORMANCE

### 3.1 Bundle Size

- [ ] JavaScript < 500KB gzipped
- [ ] CSS < 100KB gzipped
- [ ] Code splitting is used

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
- [ ] Polling endpoints use cache or in-memory storage, not heavy DB aggregations
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

Data passed to background jobs (Bull, BullMQ, Agenda) is serialized into Redis/DB. Large payloads waste memory and slow queue processing.

```typescript
// ❌ Raw HTML/file content in job data
await queue.add('process', { siteId: site.id, html: htmlContent });

// ✅ Store data externally, pass only a reference
await redis.setex(`site_html:${site.id}`, 300, htmlContent);
await queue.add('process', { siteId: site.id });
```

- [ ] Job data does not contain raw HTML, file content, or Base64 strings
- [ ] Large data is stored in Redis/S3, job receives only a key or ID
- [ ] Failed jobs are not bloated with oversized payloads

---

## 6. INFRASTRUCTURE

### 6.1 Server

- [ ] Sufficient RAM
- [ ] CPU not overloaded
- [ ] Disk I/O is normal

### 6.2 Database

- [ ] Connection pooling
- [ ] Read replicas (if needed)
- [ ] Query monitoring

### 6.3 Production Readiness

Development settings in production degrade performance significantly.

```bash
# Check NODE_ENV
echo $NODE_ENV  # Must be "production"

# Check for debug packages in dependencies
grep -E "nodemon|ts-node-dev|debug" package.json | grep -v devDependencies
```

- [ ] `NODE_ENV=production` in production
- [ ] No development-only packages in production dependencies (move to devDependencies)
- [ ] No `console.log` / `console.debug` in production code (use Pino/Winston)
- [ ] Source maps not served to clients
- [ ] Process manager used (PM2, Docker) — not `node server.js` directly

**Cache/Session/Queue Drivers:**

| Component | Bad (Dev) | Good (Prod) |
|-----------|-----------|-------------|
| Cache | In-memory | Redis / Memcached |
| Sessions | MemoryStore | Redis (connect-redis) |
| Queue | Sync (inline) | BullMQ / Bee-Queue / SQS |
| Logging | console.log | Pino / Winston → aggregator |

- [ ] Express `MemoryStore` is NOT used in production (leaks memory, no persistence)
- [ ] Cache backend survives restarts (Redis, not in-process Map)
- [ ] Background jobs use a proper queue (BullMQ), not inline execution

### 6.4 Redis Health

If using Redis (ioredis/redis) for cache/sessions/queues, monitor its health.

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
- [ ] Connection pooling configured (ioredis default is fine)

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
| TTFB | Xms | <500ms | pass/fail |
| Bundle | XKB | <500KB | pass/fail |
| LCP | Xs | <2.5s | pass/fail |

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

Start the audit. Show current metrics and summary.
