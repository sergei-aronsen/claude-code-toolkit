# Performance Audit — Next.js Template

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

## 8. RUNTIME PERFORMANCE

### 8.1 React Performance

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

### 8.2 List Virtualization

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

### 8.3 Debounce & Throttle

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

---

## 9. SELF-CHECK

**Before adding an issue to the report:**

| Question | If "no" → exclude |
| -------- | ------------------------ |
| Does this affect **runtime**? | If only build time — not critical |
| Does **tree-shaking** not solve this? | Modern bundlers are smart |
| Do I have **measurable data**? | "Might be slow" ≠ problem |
| Will **fixing** have a noticeable effect? | < 5ms not needed |

**DO NOT include in the report:**

| Seems like a problem | Why it's not a problem |
| ------------------- | --------------------- |
| "Large package in node_modules" | Tree-shaking includes only what's used |
| "Many dependencies" | Bundle size matters, not node_modules |
| "Old library version" | If it works — not a performance issue |

---

## 10. REPORT FORMAT

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

## 11. ACTIONS

1. **Measure** — Web Vitals, bundle size, DB queries
2. **Prioritize** — impact on UX
3. **Pay special attention to**:
   - Server vs Client Components
   - Database queries (N+1, indexes)
   - Bundle size (dynamic imports)
4. **Optimize** — start with critical

Start the audit. Show metrics and summary.
