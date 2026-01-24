# Acme Platform — Claude Code Instructions

## Project Overview

**Structure:** Turborepo monorepo
**Apps:** Web (Next.js), API (Node.js), Admin (Next.js), Mobile (React Native)
**Packages:** UI components, shared utils, config

---

## Monorepo Structure

```text
/
├── apps/
│   ├── web/           # Main web app (Next.js)
│   ├── api/           # Backend API (Express/Fastify)
│   ├── admin/         # Admin dashboard (Next.js)
│   └── mobile/        # Mobile app (React Native)
│
├── packages/
│   ├── ui/            # Shared UI components
│   ├── utils/         # Shared utilities
│   ├── config/        # Shared configs (ESLint, TS)
│   ├── database/      # Prisma schema and client
│   └── types/         # Shared TypeScript types
│
├── turbo.json         # Turborepo config
├── package.json       # Root package.json
└── pnpm-workspace.yaml
```text

---

## Working with Monorepo

### Key Concepts

- **Workspaces:** Each app/package is independent
- **Dependencies:** Use `workspace:*` for internal deps
- **Turborepo:** Caches builds, runs tasks in parallel

### Common Commands

```bash
# Install all dependencies
pnpm install

# Run all apps in dev mode
pnpm dev

# Run specific app
pnpm dev --filter=web
pnpm dev --filter=api

# Build all
pnpm build

# Build specific
pnpm build --filter=web

# Run tests
pnpm test
pnpm test --filter=api

# Add dependency to specific package
pnpm add lodash --filter=utils
pnpm add @acme/ui --filter=web  # Internal package
```text

---

## Architecture Decisions

### Shared Packages

- **@acme/ui** — React components (used by web, admin, mobile)
- **@acme/utils** — Pure functions (used everywhere)
- **@acme/database** — Prisma client (used by api, web SSR)
- **@acme/types** — TypeScript types (used everywhere)
- **@acme/config** — ESLint, TypeScript configs

### API Communication

- **Web ↔ API:** REST + React Query
- **Admin ↔ API:** REST + React Query
- **Mobile ↔ API:** REST + React Query
- **Real-time:** WebSocket server in API

### Deployment

- **Web:** Vercel
- **Admin:** Vercel
- **API:** Railway/Render
- **Mobile:** App Store / Play Store

---

## Development Workflow

### Running Locally

```bash
pnpm install
cp apps/web/.env.example apps/web/.env.local
cp apps/api/.env.example apps/api/.env
pnpm db:push
pnpm dev
```text

### Testing

```bash
pnpm test              # All tests
pnpm test --filter=api # API tests only
pnpm test:e2e          # E2E tests
```text

### Building

```bash
pnpm build             # Build all (uses Turborepo cache)
pnpm build --filter=web
```text

---

## Project-Specific Rules

### Cross-Package Rules

1. **No circular deps** — packages/ never import from apps/
2. **Explicit exports** — Each package has explicit exports in package.json
3. **Version sync** — All packages use same versions of shared deps

### Code Location

| Code Type | Location |
|-----------|----------|
| UI Components | `packages/ui/` |
| Business Logic | `apps/*/src/services/` |
| API Routes | `apps/api/src/routes/` |
| Database | `packages/database/` |
| Types | `packages/types/` |

### When to Create Package

Create a new package when code is:

- Used by 2+ apps
- Generic enough to be standalone
- Stable API (not changing frequently)

---

## Available Prompts

Run audits per-app or for the entire monorepo:

### Per-App Audits

```bash
cd apps/web && claude  # Web app audit
cd apps/api && claude  # API audit
```text

### Monorepo-Wide

- **Security:** Check all apps for auth, validation
- **Performance:** Check build times, bundle sizes
- **Code Review:** Check cross-package dependencies
- **Deploy:** Per-app deploy checklists

---

## Environment Variables

### apps/web/.env.local

```ini
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXTAUTH_SECRET=...
```text

### apps/api/.env

```ini
DATABASE_URL=postgresql://...
JWT_SECRET=...
REDIS_URL=...
```text

### apps/admin/.env.local

```ini
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXTAUTH_SECRET=...
```text

---

## Contacts

- **Maintainer:** Platform Team
- **Web:** @frontend-team
- **API:** @backend-team
- **Mobile:** @mobile-team
