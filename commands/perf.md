# /perf — Performance Analysis

## Purpose

Analyze and optimize application performance: N+1 queries, bundle size, memory leaks.

---

## Usage

```text
/perf [area] [options]
```

**Areas:**

- `/perf db` — Database query analysis
- `/perf bundle` — Frontend bundle analysis
- `/perf memory` — Memory leak detection
- `/perf api` — API response time analysis
- `/perf all` — Full performance audit

---

## Examples

```text
/perf db                        # Analyze N+1 queries
/perf bundle                    # Analyze JS bundle size
/perf memory                    # Check for memory leaks
/perf api /api/users            # Profile specific endpoint
```

---

## Database Performance

### For `/perf db`

```markdown
## Database Performance Report

### N+1 Query Detection

| Location | Query | Count | Impact |
|----------|-------|-------|--------|
| `UserController:45` | `SELECT * FROM posts WHERE user_id = ?` | 100x | HIGH |
| `OrderService:78` | `SELECT * FROM products WHERE id = ?` | 50x | MEDIUM |

Fix pattern: eager loading (`with()` / `include`) instead of lazy loading loops.

### Missing Indexes

Table with Column | Query columns. Generates `CREATE INDEX` statements.

### Slow Queries (>100ms)

Table with Query | Time | Location.
```

---

## Bundle Analysis

### For `/perf bundle`

```markdown
## Bundle Analysis Report

### Bundle Sizes

| Bundle | Size | Gzipped |
|--------|------|---------|
| main.js | 450 KB | 145 KB |
| vendor.js | 890 KB | 280 KB |
| Total | 1.34 MB | 425 KB |

### Large Dependencies

| Package | Size | % of Bundle |
|---------|------|-------------|
| lodash | 72 KB | 5.4% |
| moment | 66 KB | 4.9% |
| chart.js | 180 KB | 13.4% |

Recommendations: lighter alternatives (lodash→lodash-es, moment→date-fns), dynamic imports for heavy libs, tree-shaking fixes.
```

---

## Memory Analysis

### For `/perf memory`

```markdown
## Memory Analysis Report

### Potential Memory Leaks

| Type | Location | Severity |
|------|----------|----------|
| Event listener not removed | `useEffect` in Dashboard.tsx | HIGH |
| Timer not cleared | `setInterval` in Poller.ts | MEDIUM |
| Subscription not unsubscribed | `useStore` in Header.tsx | MEDIUM |

Fix pattern: always return cleanup from `useEffect` — `removeEventListener`, `clearInterval`, unsubscribe.

Profile with `node --inspect` + Chrome DevTools Performance tab.
```

---

## API Performance

### For `/perf api`

```markdown
## API Performance Report

### Endpoint Analysis

| Endpoint | Avg Time | P95 | P99 |
|----------|----------|-----|-----|
| GET /api/users | 45ms | 120ms | 350ms |
| GET /api/posts | 230ms | 890ms | 2.1s |
| POST /api/orders | 180ms | 450ms | 1.2s |

### Slow Endpoints

For slow endpoints: identify bottlenecks (N+1, no pagination, full fields), provide fix with pagination + field selection + eager loading.

### Caching Opportunities

Table with Endpoint | TTL | Strategy (cache-aside, invalidation, long-term).
```

---

## Performance Checklist

| Area | Check |
|------|-------|
| Database | No N+1, proper indexes, query caching |
| API | Pagination, field selection, response caching |
| Frontend | Code splitting, lazy loading, tree shaking |
| Images | Compression, lazy loading, WebP/AVIF |
| Memory | Cleanup subscriptions, event listeners, timers |

---

## Commands

```bash
# Bundle analysis
npx webpack-bundle-analyzer stats.json
npx vite-bundle-visualizer

# Database
EXPLAIN ANALYZE SELECT ...;

# Node.js profiling
node --prof app.js
node --prof-process isolate-*.log > profile.txt

# Lighthouse
npx lighthouse https://example.com --output=json
```

---

## Actions

1. Identify performance area to analyze
2. Run appropriate profiling/analysis
3. Identify bottlenecks with metrics
4. Provide specific code fixes
5. Estimate improvement impact
