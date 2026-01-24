---
name: Next.js Expert
description: Deep expertise in Next.js - App Router, Server Components, SSR/ISR, optimization
---

# Next.js Expert Skill

This skill provides deep Next.js 14+ expertise including App Router patterns, Server/Client components, caching strategies, and performance optimization.

---

## 🎯 Server vs Client Components

### Decision Guide

| Feature Needed | Use |
| ---------------- | ----- |
| Fetch data | Server |
| Access DB directly | Server |
| useState, useEffect | Client |
| onClick, onChange | Client |
| Browser APIs (localStorage) | Client |
| Static content | Server |

### Pattern: Composition

```tsx
// page.tsx (Server) - Fetches data
export default async function Page() {
  const data = await getData();
  return <InteractiveList initialData={data} />;
}

// interactive-list.tsx (Client) - Handles interaction
'use client';
export function InteractiveList({ initialData }) {
  const [items, setItems] = useState(initialData);
  // ...
}
```text

---

## 📡 Data Fetching

### Server Components (Preferred)

```tsx
// Direct DB access - no API needed
export default async function DashboardPage() {
  const stats = await prisma.stats.findFirst();
  return <Dashboard stats={stats} />;
}
```text

### Server Actions

```typescript
// lib/actions.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

export async function createPost(formData: FormData) {
  const session = await auth();
  if (!session) throw new Error('Unauthorized');

  await prisma.post.create({
    data: {
      title: formData.get('title') as string,
      authorId: session.user.id,
    },
  });

  revalidatePath('/posts');
  redirect('/posts');
}
```text

### SWR for Client-Side

```tsx
'use client';
import useSWR from 'swr';

export function LiveStats() {
  const { data, error, isLoading } = useSWR('/api/stats', fetcher, {
    refreshInterval: 5000,
  });

  if (isLoading) return <Skeleton />;
  if (error) return <Error />;
  return <Stats data={data} />;
}
```text

---

## 🗄️ Caching Strategies

### Route Segment Config

```typescript
// Static (build time)
export const dynamic = 'force-static';

// Dynamic (every request)
export const dynamic = 'force-dynamic';

// ISR (time-based)
export const revalidate = 3600; // seconds

// No store
export const fetchCache = 'force-no-store';
```text

### On-Demand Revalidation

```typescript
// In Server Action
import { revalidatePath, revalidateTag } from 'next/cache';

// By path
revalidatePath('/products');
revalidatePath('/products/[id]', 'page');

// By tag
revalidateTag('products');

// Tag in fetch
fetch(url, { next: { tags: ['products'] } });
```text

### Cache Hierarchy

1. **Request Memoization** — Same request in render pass
2. **Data Cache** — fetch() results cached
3. **Full Route Cache** — Static/ISR pages
4. **Router Cache** — Client-side cache (30s dynamic, 5min static)

---

## ⚡ Performance

### Dynamic Imports

```tsx
import dynamic from 'next/dynamic';

// Component-level splitting
const HeavyEditor = dynamic(() => import('./editor'), {
  loading: () => <EditorSkeleton />,
  ssr: false, // Client-only
});

// Named export
const Chart = dynamic(
  () => import('./charts').then(mod => mod.LineChart)
);
```text

### Image Optimization

```tsx
import Image from 'next/image';

<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority // LCP image
  placeholder="blur"
  blurDataURL={blurData}
/>
```text

### Suspense Streaming

```tsx
import { Suspense } from 'react';

export default function Page() {
  return (
    <>
      <Header />
      <Suspense fallback={<MainSkeleton />}>
        <MainContent />
      </Suspense>
      <Suspense fallback={<SidebarSkeleton />}>
        <Sidebar />
      </Suspense>
    </>
  );
}
```text

### Parallel Data Fetching

```tsx
export default async function Page() {
  // ❌ Sequential
  const posts = await getPosts();
  const comments = await getComments();

  // ✅ Parallel
  const [posts, comments] = await Promise.all([
    getPosts(),
    getComments(),
  ]);
}
```text

---

## 🔐 Security

### Environment Variables

```bash
# Server-only (default)
DATABASE_URL=...
API_SECRET=...

# Exposed to browser
NEXT_PUBLIC_APP_URL=...
```text

### API Route Auth

```typescript
// app/api/posts/route.ts
export async function POST(request: Request) {
  const session = await auth();
  if (!session) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }
  // ...
}
```text

### Input Validation

```typescript
import { z } from 'zod';

const CreatePostSchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().max(10000),
});

export async function createPost(formData: FormData) {
  const validated = CreatePostSchema.parse({
    title: formData.get('title'),
    content: formData.get('content'),
  });
  // ...
}
```text

---

## 🧪 Testing

### Component Testing (Vitest)

```typescript
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';

describe('Button', () => {
  it('renders with text', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button')).toHaveTextContent('Click me');
  });
});
```text

### Server Action Testing

```typescript
import { createPost } from '@/lib/actions';
import { vi } from 'vitest';

vi.mock('@/lib/auth', () => ({
  auth: vi.fn(() => Promise.resolve({ user: { id: '1' } })),
}));

it('creates post', async () => {
  const formData = new FormData();
  formData.set('title', 'Test');
  
  await createPost(formData);
  
  expect(prisma.post.create).toHaveBeenCalled();
});
```text

---

## 📁 File Conventions

```text
app/
├── page.tsx          # Route UI
├── layout.tsx        # Shared layout
├── loading.tsx       # Loading UI
├── error.tsx         # Error boundary
├── not-found.tsx     # 404 page
├── route.ts          # API endpoint
├── template.tsx      # Re-mount on nav
├── default.tsx       # Parallel route fallback
└── [slug]/           # Dynamic segment
    └── page.tsx
```text
