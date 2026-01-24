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

### Recommendations

#### Fix N+1 in UserController

**Before:**
\`\`\`php
$users = User::all();
foreach ($users as $user) {
    $posts = $user->posts; // N queries!
}
\`\`\`

**After:**
\`\`\`php
$users = User::with('posts')->get(); // 2 queries total
\`\`\`

### Missing Indexes

| Table | Column | Query |
|-------|--------|-------|
| orders | user_id | `WHERE user_id = ?` |
| posts | status | `WHERE status = 'published'` |

### Suggested Indexes

\`\`\`sql
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_posts_status ON posts(status);
\`\`\`

### Slow Queries (>100ms)

| Query | Time | Location |
|-------|------|----------|
| `SELECT * FROM logs WHERE...` | 2.3s | LogService:34 |
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

### Recommendations

1. **Replace lodash with lodash-es**
   \`\`\`bash
   npm remove lodash
   npm install lodash-es
   \`\`\`

2. **Replace moment with date-fns**
   \`\`\`bash
   npm remove moment
   npm install date-fns
   # Saves ~60KB
   \`\`\`

3. **Dynamic import for chart.js**
   \`\`\`typescript
   // Before
   import Chart from 'chart.js';

   // After
   const Chart = await import('chart.js');
   \`\`\`

### Tree Shaking Issues

| Import | Problem |
|--------|---------|
| `import * as utils from './utils'` | Import only what you need |
| `import { Button } from 'ui-library'` | Check if library is tree-shakeable |
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

### Fixes

#### Dashboard.tsx (Line 45)

**Before:**
\`\`\`tsx
useEffect(() => {
  window.addEventListener('resize', handleResize);
}, []);
\`\`\`

**After:**
\`\`\`tsx
useEffect(() => {
  window.addEventListener('resize', handleResize);
  return () => window.removeEventListener('resize', handleResize);
}, []);
\`\`\`

#### Poller.ts (Line 23)

**Before:**
\`\`\`typescript
const interval = setInterval(fetchData, 5000);
\`\`\`

**After:**
\`\`\`typescript
const interval = setInterval(fetchData, 5000);
// In cleanup
return () => clearInterval(interval);
\`\`\`

### Memory Profiling Commands

\`\`\`bash
# Node.js heap snapshot
node --inspect app.js
# Open chrome://inspect

# Chrome DevTools
# Performance tab → Record → Memory
\`\`\`
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

#### GET /api/posts (230ms avg)

**Bottlenecks:**
1. N+1 query for author info
2. No pagination
3. Full text fields loaded

**Recommendations:**
\`\`\`typescript
// Add pagination
const posts = await prisma.post.findMany({
  take: 20,
  skip: page * 20,
  include: { author: { select: { id: true, name: true } } },
  select: { id: true, title: true, excerpt: true, createdAt: true }
});
\`\`\`

### Caching Opportunities

| Endpoint | TTL | Strategy |
|----------|-----|----------|
| /api/users/:id | 5min | Cache-aside |
| /api/posts | 1min | Cache with invalidation |
| /api/config | 1hour | Long-term cache |
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
