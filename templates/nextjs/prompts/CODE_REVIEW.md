# Code Review — Next.js Template

## Goal

Comprehensive code review of a Next.js application. Act as a Senior Tech Lead.

> **Warning: Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for conducting code review — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | TypeScript | `npm run build` | No type errors |
| 2 | Lint | `npm run lint` | No errors |
| 3 | Tests | `npm test` | Pass |
| 4 | console.log | `grep -rn "console.log" app/ components/ --include="*.tsx"` | Minimal |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# code-check.sh

echo "📝 Code Quality Check — Next.js..."

# 1. Build (includes TypeScript check)
npm run build > /dev/null 2>&1 && echo "✅ Build" || echo "❌ Build failed"

# 2. Lint
npm run lint > /dev/null 2>&1 && echo "✅ Lint" || echo "🟡 Lint has warnings"

# 3. console.log
CONSOLE=$(grep -rn "console.log" app/ components/ lib/ --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
[ "$CONSOLE" -lt 10 ] && echo "✅ console.log: $CONSOLE" || echo "🟡 console.log: $CONSOLE (too many)"

# 4. 'use client' count
USE_CLIENT=$(grep -rn "'use client'" app/ components/ --include="*.tsx" 2>/dev/null | wc -l)
echo "ℹ️  Client components: $USE_CLIENT files"

# 5. Large files (>300 lines)
LARGE_FILES=$(find app components lib -name "*.ts" -o -name "*.tsx" | xargs wc -l 2>/dev/null | awk '$1 > 300 {print $2}' | wc -l)
[ "$LARGE_FILES" -eq 0 ] && echo "✅ No large files" || echo "🟡 Large files: $LARGE_FILES files >300 lines"

# 6. TODO/FIXME
TODOS=$(grep -rn "TODO\|FIXME" app/ components/ lib/ --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
echo "ℹ️  TODO/FIXME: $TODOS comments"

echo "Done!"
```text

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Accepted decisions (no need to fix):**

- [Intentional architectural decisions]

**Key files for review:**

- `app/` — pages and API routes
- `components/` — UI components
- `lib/` — utilities and helpers

**Project patterns:**

- Server Components by default
- 'use client' only for interactivity
- Zod for validation
- API routes for mutations

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Bug, security issue, data loss | **BLOCKER** — fix now |
| HIGH | Serious logic issue | Fix before merge |
| MEDIUM | Code smell, maintainability | Fix in this PR |
| LOW | Style, nice-to-have | Can postpone |

---

## 1. SCOPE REVIEW

### 1.1 Define scope of review

```bash
git diff --name-only HEAD~5
git status --short
```text

- [ ] Which files are changed
- [ ] Which new files are created
- [ ] Relationship between changes

### 1.2 Categorization

- [ ] Pages (app/**/page.tsx)
- [ ] API Routes (app/api/**/route.ts)
- [ ] Components (components/*)
- [ ] Lib/Utils (lib/*)
- [ ] Config (next.config.ts, etc.)

---

## 2. ARCHITECTURE & STRUCTURE

### 2.1 Server Components vs Client Components

```tsx
// ❌ Bad — entire component client without necessity
'use client';

import { useState } from 'react';

export function ProjectPage({ projects }) {
  const [filter, setFilter] = useState('all');

  return (
    <div>
      <h1>Projects</h1>  {/* Static content */}
      <FilterButton onFilter={setFilter} />
      {projects.map(p => <ProjectCard key={p.id} project={p} />)}  {/* Static */}
    </div>
  );
}

// ✅ Good — minimal client boundary
// app/projects/page.tsx (Server Component)
export default async function ProjectsPage() {
  const projects = await getProjects();

  return (
    <div>
      <h1>Projects</h1>
      <ProjectFilters />  {/* Client Component */}
      <ProjectList projects={projects} />  {/* Server Component */}
    </div>
  );
}

// components/ProjectFilters.tsx
'use client';
export function ProjectFilters() {
  const [filter, setFilter] = useState('all');
  return <FilterButton onFilter={setFilter} />;
}
```text

- [ ] Client boundary as low as possible in tree
- [ ] 'use client' only where interactivity is really needed
- [ ] Data fetching in Server Components

### 2.2 API Route Structure

```typescript
// ❌ Bad — too much logic in route handler
// app/api/projects/route.ts
export async function POST(request: Request) {
  // 100 lines of business logic...
}

// ✅ Good — logic in separate files
// app/api/projects/route.ts
import { createProject } from '@/lib/services/projects';
import { CreateProjectSchema } from '@/lib/schemas/projects';

export async function POST(request: Request) {
  const body = await request.json();

  const parsed = CreateProjectSchema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const project = await createProject(parsed.data);
  return Response.json(project);
}
```text

- [ ] Route handlers are thin
- [ ] Business logic in lib/services/
- [ ] Schemas in lib/schemas/

### 2.3 File Structure

```text
app/
├── (auth)/
│   ├── login/
│   │   └── page.tsx
│   └── layout.tsx
├── dashboard/
│   └── page.tsx
├── api/
│   └── projects/
│       └── route.ts
├── layout.tsx
└── page.tsx

components/
├── ui/           # Reusable UI components
├── features/     # Feature-specific components
└── layouts/      # Layout components

lib/
├── services/     # Business logic
├── schemas/      # Zod schemas
├── db/           # Database utilities
└── utils/        # Helpers
```text

- [ ] Files in correct directories
- [ ] No God-components (> 300 lines)
- [ ] UI and business logic separated

---

## 3. CODE QUALITY

### 3.1 TypeScript

```typescript
// ❌ Bad — any, missing types
function process(data: any) {
  return data.something;
}

// ❌ Bad — implicit any in parameters
const handleClick = (e) => console.log(e);

// ✅ Good — full typing
interface ProcessInput {
  id: string;
  data: Record<string, unknown>;
}

function process(input: ProcessInput): ProcessResult {
  return { id: input.id, processed: true };
}

const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
  console.log(e.currentTarget.id);
};
```text

- [ ] No `any` without explicit need
- [ ] All functions typed
- [ ] Interfaces/types defined

### 3.2 Naming Conventions

```typescript
// ❌ Bad
const d = await fetchData();
const res = processStuff(d);

// ✅ Good
const projects = await fetchProjects();
const processedProjects = processProjects(projects);
```text

- [ ] **Variables** — nouns, camelCase: `projectList`, `userData`
- [ ] **Functions** — verbs, camelCase: `getProjects()`, `processData()`
- [ ] **Components** — PascalCase: `ProjectCard`, `UserProfile`
- [ ] **Boolean** — is/has/can/should: `isLoading`, `hasError`

### 3.3 Component Structure

```tsx
// ❌ Bad — everything mixed
'use client';

import { useState, useEffect } from 'react';

export function ProjectCard({ project }) {
  const [loading, setLoading] = useState(false);

  // 200 lines of logic and rendering
}

// ✅ Good — separation into parts
// hooks/useProjectActions.ts
export function useProjectActions(projectId: string) {
  const [loading, setLoading] = useState(false);

  const deleteProject = async () => {
    setLoading(true);
    // ...
  };

  return { loading, deleteProject };
}

// components/ProjectCard.tsx
'use client';

import { useProjectActions } from '@/hooks/useProjectActions';

interface ProjectCardProps {
  project: Project;
}

export function ProjectCard({ project }: ProjectCardProps) {
  const { loading, deleteProject } = useProjectActions(project.id);

  return (
    <div>
      <h3>{project.name}</h3>
      <button onClick={deleteProject} disabled={loading}>
        Delete
      </button>
    </div>
  );
}
```text

- [ ] Logic extracted to custom hooks
- [ ] Props typed via interface
- [ ] Components < 150 lines

### 3.4 DRY (Don't Repeat Yourself)

```typescript
// ❌ Bad — duplication
// components/ProjectCard.tsx
const formatDate = (date: Date) => date.toLocaleDateString('en-US');

// components/UserCard.tsx
const formatDate = (date: Date) => date.toLocaleDateString('en-US');

// ✅ Good — shared utilities
// lib/utils/date.ts
export function formatDate(date: Date, locale = 'en-US'): string {
  return date.toLocaleDateString(locale);
}

// Usage
import { formatDate } from '@/lib/utils/date';
```text

- [ ] No duplicated code
- [ ] Shared utilities in lib/utils/

---

## 4. REACT/NEXT.JS BEST PRACTICES

### 4.1 Data Fetching

```tsx
// ❌ Bad — useEffect for initial data
'use client';

export function ProjectList() {
  const [projects, setProjects] = useState([]);

  useEffect(() => {
    fetch('/api/projects').then(r => r.json()).then(setProjects);
  }, []);

  return <div>{projects.map(...)}</div>;
}

// ✅ Good — Server Component
// app/projects/page.tsx
export default async function ProjectsPage() {
  const projects = await getProjects();  // Direct DB query
  return <ProjectList projects={projects} />;
}
```text

- [ ] Data fetching in Server Components
- [ ] No useEffect for initial data loading
- [ ] API routes for mutations

### 4.2 Error Handling

```tsx
// ❌ Bad — no error handling
export async function POST(request: Request) {
  const data = await request.json();
  const result = await createProject(data);
  return Response.json(result);
}

// ✅ Good — full handling
export async function POST(request: Request) {
  try {
    const body = await request.json();

    const parsed = CreateProjectSchema.safeParse(body);
    if (!parsed.success) {
      return Response.json(
        { error: 'Validation failed', details: parsed.error.flatten() },
        { status: 400 }
      );
    }

    const result = await createProject(parsed.data);
    return Response.json(result, { status: 201 });

  } catch (error) {
    console.error('Create project error:', error);

    if (error instanceof UniqueConstraintError) {
      return Response.json(
        { error: 'Project already exists' },
        { status: 409 }
      );
    }

    return Response.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```text

- [ ] Try-catch in API routes
- [ ] Specific error responses
- [ ] Error logging

### 4.3 Loading & Error States

```tsx
// app/projects/loading.tsx
export default function Loading() {
  return <ProjectsSkeleton />;
}

// app/projects/error.tsx
'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error;
  reset: () => void;
}) {
  return (
    <div>
      <h2>Something went wrong!</h2>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```text

- [ ] loading.tsx for Suspense
- [ ] error.tsx for error boundaries
- [ ] Skeleton components for loading states

---

## 5. SECURITY & PERFORMANCE QUICK CHECK

### 5.1 Security

- [ ] API routes check auth
- [ ] Input validated via Zod
- [ ] No SQL injection (parameterized queries)
- [ ] No secrets in client-side code
- [ ] No dangerouslySetInnerHTML with user content

### 5.2 Performance

- [ ] Server Components used where possible
- [ ] Heavy components — dynamic import
- [ ] Images via next/image
- [ ] No N+1 queries

---

## 6. SELF-CHECK

**Before adding an issue to the report:**

| Question | If "no" → don't include |
| -------- | ------------------------- |
| Does it affect **functionality** or **maintainability**? | Cosmetics not critical |
| Will **fixing bring value**? | Refactoring for refactoring's sake — waste of time |
| Is it a **violation** of accepted patterns? | Check existing code |

**DO NOT include in report:**

| Seems like an issue | Why it might not be |
| ------------------- | --------------------- |
| "No comments" | TypeScript + good names = self-documenting |
| "Could be better" | Without specifics not actionable |
| "'use client' too much" | If interactivity needed — OK |

---

## 7. REPORT FORMAT

```markdown
# Code Review Report — [Project Name]
Date: [date]
Scope: [which files/commits reviewed]

## Summary

| Category | Issues | Critical |
|-----------|---------|-----------|
| Architecture | X | X |
| Code Quality | X | X |
| TypeScript | X | X |
| Security | X | X |
| Performance | X | X |

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|--------|----------|---------|
| 1 | route.ts | 45 | No auth check | Add getServerSession |

## Code Suggestions

### 1. Add auth check

```typescript
// Before (app/api/projects/route.ts:10-15)
export async function POST(request: Request) {
  const data = await request.json();
  // ...
}

// After
import { getServerSession } from 'next-auth';

export async function POST(request: Request) {
  const session = await getServerSession(authOptions);
  if (!session) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }
  const data = await request.json();
  // ...
}
```text

## Good Practices Found

- [What's good]

```text

---

## 8. ACTIONS

1. **Run Quick Check** — 5 minutes
2. **Define scope** — which files to review
3. **Go through categories** — Architecture, Code Quality, Security
4. **Self-check** — filter out false positives
5. **Prioritize** — Critical → Low
6. **Show fixes** — specific code before/after

Start code review. Show scope and summary first.
