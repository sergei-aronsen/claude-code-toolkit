# Performance Audit — Base Template

## Objective

Comprehensive performance audit of a web application. Act as a Senior Performance Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for conducting audits — better at code analysis.

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
| CRITICAL | Blocks functionality, > 5s load time | **BLOCKER** |
| HIGH | Noticeable slowdown, > 2s | Fix before deploy |
| MEDIUM | Can be improved, > 1s | Next sprint |
| LOW | Micro-optimization | Backlog |

---

## 1. DATABASE PERFORMANCE

### 1.1 N+1 Queries

```text
Bad: 1 query + N queries for related data
Good: 1-2 queries with eager loading
```

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

SQLAlchemy events and Django signals can silently trigger N+1 during bulk operations.

```python
# ❌ N+1 in Django signal — deletes one by one
@receiver(pre_delete, sender=Site)
def delete_related(sender, instance, **kwargs):
    for check in instance.checks.all():
        check.delete()  # N queries!

# ✅ Bulk delete
@receiver(pre_delete, sender=Site)
def delete_related(sender, instance, **kwargs):
    instance.checks.all().delete()  # 1 query

# ✅ Or use on_delete=CASCADE in model definition
checks = models.ForeignKey(Site, on_delete=models.CASCADE)
```

```python
# SQLAlchemy — use cascade in relationship
checks = relationship("Check", cascade="all, delete-orphan")
```

- [ ] Delete/update signals do not use per-record iteration
- [ ] Signals do not make synchronous external API calls
- [ ] Use DB-level cascades or ORM cascade options where possible

### 1.5 Complex Query Patterns (Subqueries)

Chaining multiple subquery conditions can cause exponential query complexity even with proper indexes.

```python
# ❌ Heavy — multiple .filter() with subqueries
Site.objects.filter(
    checks__status='alive',
    user__is_active=True,
).exclude(labels__isnull=False)

# ✅ Better — use select_related/prefetch or raw JOIN
Site.objects.select_related('user').filter(
    user__is_active=True,
).only('id', 'url', 'user__id')
```

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
- [ ] Polling endpoints use cache (Redis/memcached), not heavy DB aggregations
- [ ] Polling intervals are reasonable (no sub-second polling for non-critical data)
- [ ] Consider WebSockets/SSE (channels, socket.io) for real-time data

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

- [ ] Timeout is configured
- [ ] Retry policy
- [ ] Failed job handling

### 5.3 Queue Payload Size

Data passed to Celery/RQ/Dramatiq tasks is serialized (pickle/JSON). Large payloads waste broker memory and slow processing.

```python
# ❌ Raw HTML/file content in task args
process_site.delay(site_id=site.id, html=html_content)

# ✅ Store data externally, pass only a reference
cache.set(f"site_html:{site.id}", html_content, timeout=300)
process_site.delay(site_id=site.id)
```

- [ ] Task arguments do not contain raw HTML, file content, or binary data
- [ ] Large data is stored in Redis/S3, task receives only a key or ID
- [ ] Monitor broker memory usage for payload bloat

---

## 6. INFRASTRUCTURE

### 6.1 Server

- [ ] Enough RAM
- [ ] CPU not overloaded
- [ ] Disk I/O is normal

### 6.2 Database

- [ ] Connection pooling
- [ ] Read replicas (if needed)
- [ ] Query monitoring

---

## 7. MONITORING

- [ ] APM tool is configured
- [ ] Slow query logging
- [ ] Error rate tracking
- [ ] Uptime monitoring

---

## 8. SELF-CHECK

**DO NOT optimize:**

- Code that rarely executes
- Microseconds on hot paths
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
```

---

## 10. ACTIONS

1. **Measure** — current metrics
2. **Profile** — find bottlenecks
3. **Prioritize** — impact vs effort
4. **Fix** — start with quick wins
5. **Measure again** — confirm improvement

Start the audit. Show current metrics and summary.
