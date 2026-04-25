# Performance Audit — Next.js Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

## Goal

Comprehensive performance audit of a Next.js application. Act as a Senior Performance Engineer.

> **⚠️ Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for audits — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Build | `npm run build` | Success, no warnings |
| 2 | Bundle size | Check build output | First Load JS < 200KB |
| 3 | SELECT * | `grep -rn "SELECT \*" lib/ app/ --include="*.ts"` | Minimal |
| 4 | N+1 queries | `grep -rn "for.*await.*query" lib/ app/` | Empty |
| 5 | Dynamic imports | `grep -rn "dynamic(" app/ components/` | Present for heavy components |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# performance-check.sh

echo "⚡ Performance Quick Check — Next.js..."

# 1. Build test
npm run build > /tmp/build.log 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Build: Success"
    BUNDLE=$(grep "First Load JS" /tmp/build.log | head -1)
    echo "   $BUNDLE"
else
    echo "❌ Build: Failed"
fi

# 2. SELECT * queries
SELECT_STAR=$(grep -rn "SELECT \*" lib/ app/ --include="*.ts" 2>/dev/null | wc -l)
[ "$SELECT_STAR" -eq 0 ] && echo "✅ SQL: No SELECT *" || echo "🟡 SQL: Found $SELECT_STAR SELECT * queries"

# 3. N+1 patterns
N_PLUS_1=$(grep -rn "for.*await.*query\|\.map.*await.*query" lib/ app/ --include="*.ts" 2>/dev/null | wc -l)
[ "$N_PLUS_1" -eq 0 ] && echo "✅ N+1: No patterns" || echo "❌ N+1: Found $N_PLUS_1 potential N+1"

# 4. Dynamic imports
DYNAMIC=$(grep -rn "dynamic(" app/ components/ --include="*.tsx" 2>/dev/null | wc -l)
[ "$DYNAMIC" -gt 0 ] && echo "✅ Dynamic: $DYNAMIC dynamic imports" || echo "🟡 Dynamic: No dynamic imports"

# 5. Client components count
USE_CLIENT=$(grep -rn "'use client'" app/ components/ --include="*.tsx" 2>/dev/null | wc -l)
echo "ℹ️  Client components: $USE_CLIENT files"

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**What is already optimized:**

- [ ] Bundle analyzer — `@next/bundle-analyzer`
- [ ] Database connection pooling
- [ ] Streaming responses
- [ ] Dynamic imports

**Command for bundle analysis:**

```bash
ANALYZE=true npm run build
```

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| 🔴 CRITICAL | > 50% degradation, N+1 on main pages | Fix immediately |
| 🟠 HIGH | 20-50% degradation | Fix before deploy |
| 🟡 MEDIUM | 5-20% degradation | Next sprint |
| 🔵 LOW | < 5% improvement | Backlog |

---

## 1. NEXT.JS CORE WEB VITALS

### 1.1 Measuring Metrics

```typescript
// app/layout.tsx
'use client';

import { useReportWebVitals } from 'next/web-vitals';

export function WebVitalsReporter() {
  useReportWebVitals((metric) => {
    console.log(metric);
  });
  return null;
}

// Target values:
// LCP (Largest Contentful Paint): < 2.5s
// FID (First Input Delay): < 100ms
// CLS (Cumulative Layout Shift): < 0.1
// TTFB (Time to First Byte): < 800ms
// INP (Interaction to Next Paint): < 200ms
```

- [ ] LCP < 2.5s
- [ ] FID < 100ms
- [ ] CLS < 0.1
- [ ] TTFB < 800ms
- [ ] INP < 200ms

### 1.2 Build Analysis

```bash
npm run build
ANALYZE=true npm run build
```

- [ ] Bundle analyzer configured
- [ ] Main bundle < 200KB (gzipped)
- [ ] No library duplication
- [ ] Tree shaking works

---

## 2. SERVER COMPONENTS VS CLIENT COMPONENTS

### 2.1 'use client' Audit

```bash
grep -rn "'use client'" app/ components/ --include="*.tsx"
```

```tsx
// ❌ Bad — entire component client without necessity
'use client';

import { useState } from 'react';

export function ProjectList({ projects }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div>
      {/* Lots of static content */}
      <h1>Projects</h1>
      <p>Long description...</p>

      {/* Only this is interactive */}
      <button onClick={() => setExpanded(!expanded)}>Toggle</button>

      {/* List — static */}
      {projects.map(p => <ProjectCard key={p.id} project={p} />)}
    </div>
  );
}

// ✅ Good — separation
// app/projects/page.tsx (Server Component)
export default async function ProjectsPage() {
  const projects = await getProjects();  // Server-side fetch

  return (
    <div>
      <h1>Projects</h1>
      <p>Long description...</p>

      <ExpandableSection>  {/* Only this is client */}
        <div>Details</div>
      </ExpandableSection>

      {projects.map(p => <ProjectCard key={p.id} project={p} />)}
    </div>
  );
}

// components/ExpandableSection.tsx
'use client';

export function ExpandableSection({ children }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <>
      <button onClick={() => setExpanded(!expanded)}>Toggle</button>
      {expanded && children}
    </>
  );
}
```

- [ ] Is client-side interactivity really needed?
- [ ] Can the interactive part be extracted to a separate component?
- [ ] Is Server Component + Client island pattern used?

### 2.2 Data Fetching Location

```tsx
// ❌ Bad — fetch on client
'use client';

export function ProjectList() {
  const [projects, setProjects] = useState([]);

  useEffect(() => {
    fetch('/api/projects').then(r => r.json()).then(setProjects);
  }, []);

  return <div>{projects.map(...)}</div>;
}

// ✅ Good — fetch on server
// app/projects/page.tsx (Server Component)
export default async function ProjectsPage() {
  const projects = await db.query('SELECT * FROM projects');
  return <ProjectList projects={projects} />;
}
```

- [ ] Data fetching in Server Components where possible
- [ ] No `useEffect` for initial data fetching
- [ ] API routes only for mutations

---

## 3. DATABASE PERFORMANCE

### 3.1 Query Optimization

```typescript
// ❌ Bad — SELECT *
const projects = await query('SELECT * FROM projects');

// ❌ Bad — N+1 queries
const projects = await query('SELECT * FROM projects');
for (const project of projects) {
  const files = await query('SELECT * FROM files WHERE project_id = ?', [project.id]);
  project.files = files;  // N queries!
}

// ✅ Good — only needed fields
const projects = await query(
  'SELECT id, name, created_at FROM projects WHERE user_id = ?',
  [userId]
);

// ✅ Good — JOIN instead of N+1
const projectsWithFiles = await query(`
  SELECT
    p.id, p.name,
    f.id as file_id, f.name as file_name
  FROM projects p
  LEFT JOIN files f ON f.project_id = p.id
  WHERE p.user_id = ?
`, [userId]);
```

- [ ] No `SELECT *` for large tables
- [ ] No N+1 queries
- [ ] JOINs used where needed

### 3.2 Indexes

```sql
-- ✅ Good — indexes on frequently used fields
CREATE TABLE projects (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    status ENUM('active', 'archived') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_user_status (user_id, status)
);
```

- [ ] Foreign keys have indexes
- [ ] Fields in WHERE have indexes
- [ ] Composite indexes for frequent combinations

### 3.3 Connection Management

```typescript
// ✅ Connection pooling
import mysql from 'mysql2/promise';

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  enableKeepAlive: true,
});
```

- [ ] Connection pooling is used
- [ ] `connectionLimit` configured

### 3.4 Query Patterns

```typescript
// ❌ Bad — waterfall
const user = await query('SELECT * FROM users WHERE id = ?', [userId]);
const projects = await query('SELECT * FROM projects WHERE user_id = ?', [userId]);
const settings = await query('SELECT * FROM settings WHERE user_id = ?', [userId]);

// ✅ Good — Promise.all for independent queries
const [user, projects, settings] = await Promise.all([
  query('SELECT id, name FROM users WHERE id = ?', [userId]),
  query('SELECT id, name FROM projects WHERE user_id = ?', [userId]),
  query('SELECT * FROM settings WHERE user_id = ?', [userId]),
]);
```

- [ ] Independent queries through Promise.all
- [ ] No waterfall queries

### 3.5 ORM Lifecycle Events (Prisma Middleware)

ORM middleware and hooks can silently trigger N+1 during bulk operations.

```typescript
// ❌ N+1 in Prisma middleware — deletes one by one
prisma.$use(async (params, next) => {
  if (params.action === 'delete' && params.model === 'Project') {
    const files = await prisma.file.findMany({
      where: { projectId: params.args.where.id },
    });
    for (const file of files) {
      await prisma.file.delete({ where: { id: file.id } }); // N queries!
    }
  }
  return next(params);
});

// ✅ Use onDelete: Cascade in schema.prisma
// model File {
//   project   Project @relation(fields: [projectId], references: [id], onDelete: Cascade)
// }
```

- [ ] No per-record iteration in Prisma middleware
- [ ] Use `onDelete: Cascade` in schema for related record cleanup
- [ ] Middleware does not make synchronous external API calls

### 3.6 Complex Query Patterns (Nested Filters)

Deeply nested `where` conditions with relations generate heavy subqueries.

```typescript
// ❌ Heavy — multiple nested relation filters
const projects = await prisma.project.findMany({
  where: {
    user: { isActive: true },
    files: { some: { type: 'component' } },
    deployments: { none: { status: 'failed' } },
  },
});

// ✅ Better — split into indexed queries or use raw SQL for complex filters
const activeUserIds = await prisma.user.findMany({
  where: { isActive: true },
  select: { id: true },
});
const projects = await prisma.project.findMany({
  where: { userId: { in: activeUserIds.map(u => u.id) } },
});
```

- [ ] No more than 2 nested relation filters per query
- [ ] Complex filters split into simpler indexed queries
- [ ] No nested relation filters inside polling endpoints

---

## 4. AI API OPTIMIZATION (if used)

### 4.1 Streaming Responses

```typescript
// ❌ Bad — waiting for full response
export async function POST(request: Request) {
  const { prompt } = await request.json();

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250929',
    messages: [{ role: 'user', content: prompt }],
  });

  return Response.json({ content: response.content });
}

// ✅ Good — streaming
import { streamText } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';

export async function POST(request: Request) {
  const { prompt } = await request.json();

  const result = await streamText({
    model: anthropic('claude-sonnet-4-5-20250929'),
    prompt,
  });

  return result.toDataStreamResponse();
}
```

- [ ] AI responses use streaming
- [ ] UI shows progressive output

### 4.2 Model Selection

```typescript
// ✅ Right model for the task
function selectModel(task: string): string {
  switch (task) {
    case 'simple-edit':
      return 'claude-haiku-4-5-20251001';  // Cheap
    case 'code-generation':
      return 'claude-sonnet-4-5-20250929';  // Balance
    case 'complex-analysis':
      return 'claude-opus-4-5-20251101';  // Smart
    default:
      return 'claude-sonnet-4-5-20250929';
  }
}
```

- [ ] Haiku for simple tasks
- [ ] Sonnet for most tasks
- [ ] Opus only for complex tasks

### 4.3 Caching AI Responses

```typescript
// ✅ Caching for identical requests
import { createHash } from 'crypto';

const responseCache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

function getCacheKey(prompt: string, model: string): string {
  return createHash('sha256').update(`${model}:${prompt}`).digest('hex');
}

export async function POST(request: Request) {
  const { prompt, model } = await request.json();

  const cacheKey = getCacheKey(prompt, model);
  const cached = responseCache.get(cacheKey);

  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return Response.json({ content: cached.response, cached: true });
  }

  const response = await generateCode(prompt, model);

  responseCache.set(cacheKey, {
    response,
    timestamp: Date.now(),
  });

  return Response.json({ content: response });
}
```

- [ ] Identical requests are cached
- [ ] TTL for cache

---

## 5. IMAGE & ASSET OPTIMIZATION

### 5.1 Next.js Image Component

```tsx
// ❌ Bad — regular img
<img src="/hero.png" alt="Hero" />

// ✅ Good — next/image
import Image from 'next/image';

<Image
  src="/hero.png"
  alt="Hero"
  width={800}
  height={600}
  priority  // For above-the-fold
/>

<Image
  src="https://example.com/image.jpg"
  alt="External"
  width={400}
  height={300}
  loading="lazy"  // For below-the-fold
/>
```

- [ ] All images via `next/image`
- [ ] `priority` for above-the-fold images
- [ ] `loading="lazy"` for below-the-fold
- [ ] remotePatterns configured for external images

### 5.2 Font Optimization

```tsx
// ❌ Bad — external fonts
<link href="https://fonts.googleapis.com/..." rel="stylesheet" />

// ✅ Good — next/font
import { Inter } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
});

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={inter.variable}>
      <body>{children}</body>
    </html>
  );
}
```

- [ ] Fonts via `next/font`
- [ ] `display: 'swap'` for FOUT

---

## 6. BUNDLE OPTIMIZATION

### 6.1 Dynamic Imports

```tsx
// ❌ Bad — everything in main bundle
import { CodeMirror } from '@uiw/react-codemirror';
import { HeavyChart } from './HeavyChart';

// ✅ Good — dynamic imports
import dynamic from 'next/dynamic';

const CodeMirror = dynamic(
  () => import('@uiw/react-codemirror').then(mod => mod.default),
  {
    loading: () => <div>Loading editor...</div>,
    ssr: false
  }
);

const HeavyChart = dynamic(
  () => import('./HeavyChart'),
  { loading: () => <ChartSkeleton /> }
);
```

- [ ] CodeMirror / Monaco Editor — dynamic import
- [ ] Chart libraries — dynamic import
- [ ] Modal windows — dynamic import

### 6.2 Tree Shaking

```typescript
// ❌ Bad — importing entire library
import * as _ from 'lodash';
_.map(arr, fn);

// ✅ Good — named imports
import map from 'lodash/map';
// or lodash-es
import { map } from 'lodash-es';

// For icons
import { Home, Settings, User } from 'lucide-react';
```

- [ ] No `import *` for tree-shakeable libraries
- [ ] `lodash-es` instead of `lodash`
- [ ] Named imports for icons

### 6.3 Code Splitting

```typescript
// next.config.ts
const nextConfig = {
  experimental: {
    optimizePackageImports: [
      'lucide-react',
      '@radix-ui/react-icons',
      'lodash-es',
      'framer-motion',
    ],
  },
};
```

- [ ] `optimizePackageImports` configured

---

## 7. CACHING STRATEGY

### 7.1 Next.js Caching

```typescript
// app/api/projects/route.ts

// ❌ Bad — no caching
export async function GET() {
  const projects = await getProjects();
  return Response.json(projects);
}

// ✅ Good — with caching
export async function GET() {
  const projects = await getProjects();

  return Response.json(projects, {
    headers: {
      'Cache-Control': 'private, max-age=60, stale-while-revalidate=300',
    },
  });
}
```

```typescript
// Server Components with revalidation
async function getProjects() {
  const res = await fetch('https://api.example.com/projects', {
    next: {
      revalidate: 60,  // ISR
      tags: ['projects'],
    },
  });
  return res.json();
}
```

- [ ] API routes have Cache-Control headers
- [ ] ISR for semi-static data

---

## 8. PRODUCTION INFRASTRUCTURE

### 8.1 Production Readiness

Development settings in production degrade performance significantly.

```bash
# Check NODE_ENV
echo $NODE_ENV  # Must be "production"

# Check for debug packages in production
grep -E "console\.(log|debug)" src/ app/ -rn --include="*.ts" --include="*.tsx" | grep -v "test\|spec" | head -20
```

- [ ] `NODE_ENV=production` in production
- [ ] No `console.log` / `console.debug` in production code (use proper logger)
- [ ] No development-only packages in production bundle (React DevTools, debug, etc.)
- [ ] Source maps not served to clients (or uploaded to error tracker only)

**Cache/Session/Queue Drivers:**

| Component | Bad (Dev) | Good (Prod) |
|-----------|-----------|-------------|
| Cache | In-memory | Redis / Memcached |
| Sessions | In-memory / JWT only | Redis-backed sessions |
| Queue | Sync (inline) | Redis / BullMQ / SQS |
| Logging | console.log | Structured (Pino/Winston → aggregator) |

- [ ] Cache backend is not in-memory only in production (won't survive restart)
- [ ] Session store is persistent (not in-memory)
- [ ] Background jobs use a proper queue, not inline execution

### 8.2 Redis Health

If using Redis for cache/sessions/queues, monitor its health.

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

### 8.3 Job Idempotency

If using background jobs (BullMQ, Inngest, trigger.dev), jobs may be retried on failure. A non-idempotent job can corrupt data.

```typescript
// ❌ Dangerous — not idempotent
async function processOrder(job: Job) {
  const order = await prisma.order.findUnique({ where: { id: job.data.orderId } });
  await prisma.order.update({
    where: { id: order.id },
    data: { total: order.total + job.data.amount }, // Double-counted on retry!
  });
}

// ✅ Safe — idempotent with state check
async function processOrder(job: Job) {
  await prisma.order.updateMany({
    where: { id: job.data.orderId, status: { not: 'processed' } },
    data: { status: 'processed', total: job.data.amount },
  });
}

// BullMQ: use jobId for deduplication
await queue.add('process', { orderId: 123 }, {
  jobId: `process-order-${orderId}`,
});
```

- [ ] Jobs produce the same result when executed multiple times
- [ ] State-changing jobs check current state before modifying
- [ ] External API calls use idempotency keys where supported
- [ ] Database operations use transactions or unique constraints to prevent duplicates

---

## 9. RUNTIME PERFORMANCE

### 9.1 React Performance

```tsx
// ❌ Bad — unnecessary re-renders
function ProjectList({ projects, filter }) {
  const handleClick = (id) => console.log(id);  // New function every render
  const filtered = projects.filter(p => p.status === filter);  // Every render!

  return filtered.map(p => (
    <ProjectCard key={p.id} project={p} onClick={handleClick} />
  ));
}

// ✅ Good — memoization
import { useCallback, useMemo, memo } from 'react';

function ProjectList({ projects, filter }) {
  const handleClick = useCallback((id) => console.log(id), []);

  const filtered = useMemo(
    () => projects.filter(p => p.status === filter),
    [projects, filter]
  );

  return filtered.map(p => (
    <ProjectCard key={p.id} project={p} onClick={handleClick} />
  ));
}

const ProjectCard = memo(function ProjectCard({ project, onClick }) {
  return <div onClick={() => onClick(project.id)}>{project.name}</div>;
});
```

- [ ] useCallback for event handlers
- [ ] useMemo for expensive computations
- [ ] memo for components with objects/functions in props

### 9.2 List Virtualization

```tsx
// ❌ Bad — rendering all elements
function FileList({ files }) {
  return files.map(file => <FileItem key={file.id} file={file} />);
}

// ✅ Good — virtualization for > 100 items
import { useVirtualizer } from '@tanstack/react-virtual';

function FileList({ files }) {
  const parentRef = useRef(null);

  const virtualizer = useVirtualizer({
    count: files.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
  });

  return (
    <div ref={parentRef} style={{ height: '400px', overflow: 'auto' }}>
      <div style={{ height: virtualizer.getTotalSize() }}>
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div key={virtualItem.key} style={{ position: 'absolute', top: virtualItem.start }}>
            <FileItem file={files[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] Virtualization for lists > 100 items

### 9.3 Debounce & Throttle

```typescript
// ❌ Bad — request on every keystroke
function Search() {
  const [query, setQuery] = useState('');

  useEffect(() => {
    fetch(`/api/search?q=${query}`);  // Every character!
  }, [query]);
}

// ✅ Good — debounced
import { useDebounce } from 'usehooks-ts';

function Search() {
  const [query, setQuery] = useState('');
  const debouncedQuery = useDebounce(query, 300);

  useEffect(() => {
    if (debouncedQuery) {
      fetch(`/api/search?q=${debouncedQuery}`);
    }
  }, [debouncedQuery]);
}
```

- [ ] Search inputs debounced
- [ ] AI prompts debounced

### 9.4 Polling Analysis

Frequent polling from frontend can overwhelm API routes and database.

```bash
# Find polling patterns
grep -rn "setInterval\|refreshInterval\|refetchInterval\|usePoll" app/ components/ lib/ --include="*.ts" --include="*.tsx"
```

```typescript
// ❌ Heavy endpoint called every 5 seconds
useEffect(() => {
  const interval = setInterval(async () => {
    const stats = await fetch('/api/stats'); // Heavy DB query!
    setStats(await stats.json());
  }, 5000);
  return () => clearInterval(interval);
}, []);

// ✅ Cached endpoint with SWR
import useSWR from 'swr';

const { data } = useSWR('/api/stats', fetcher, {
  refreshInterval: 30000, // 30s is reasonable
  dedupingInterval: 10000,
});

// ✅ Backend: cache the response
export async function GET() {
  const stats = await getCachedStats(); // Redis/in-memory cache
  return Response.json(stats, {
    headers: { 'Cache-Control': 'private, max-age=10' },
  });
}
```

- [ ] Endpoints called at intervals < 30s respond in < 50ms
- [ ] Polling endpoints return cached data, not raw DB aggregations
- [ ] Consider Server-Sent Events for real-time data instead of polling

---

## 10. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

---

## 11. REPORT FORMAT

```markdown
# Performance Audit Report — [Project Name]
Date: [date]

## Core Web Vitals

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| LCP | Xs | < 2.5s | ✅/❌ |
| FID | Xms | < 100ms | ✅/❌ |
| CLS | X | < 0.1 | ✅/❌ |
| TTFB | Xms | < 800ms | ✅/❌ |

## Bundle Size

| Chunk | Size (gzip) | Status |
|-------|-------------|--------|
| Main | XKB | ✅/❌ |
| Vendor | XKB | ✅/❌ |

## 🔴 Critical Issues

| # | Issue | Location | Impact | Solution |
|---|-------|----------|--------|----------|
| 1 | N+1 queries | lib/db.ts | ~500ms | Add JOIN |

## Recommendations

1. Add virtualization to file list
2. Implement response caching
```

---

## 12. ACTIONS

## 11. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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

1. **Measure** — Web Vitals, bundle size, DB queries
2. **Prioritize** — impact on UX
3. **Pay special attention to**:
   - Server vs Client Components
   - Database queries (N+1, indexes)
   - Bundle size (dynamic imports)
4. **Optimize** — start with critical

Start the audit. Show metrics and summary.

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
