# Analytics Dashboard — Claude Code Instructions

## 🎯 Project Overview

**Stack:** Next.js 15 + TypeScript + Tailwind + Prisma
**Type:** Analytics Dashboard
**Database:** PostgreSQL 15
**Node:** 20 | **Package Manager:** pnpm

---

## 🧠 WORKFLOW RULES

### Plan Mode — ALWAYS USE BEFORE CODING

1. **Activate Plan Mode** — `Shift+Tab` twice
2. **Create plan** in `.claude/scratchpad/`
3. **Wait for approval** before coding

---

## 📁 Structure

```text
app/
├── (auth)/            # Login, register
├── (dashboard)/       # Protected routes
│   ├── layout.tsx
│   └── analytics/
└── api/               # API routes

lib/
├── actions/           # Server Actions
├── db/prisma.ts       # Prisma client
└── validations/       # Zod schemas
```text

---

## ⚡ Commands

```bash
pnpm dev               # Dev server
pnpm test              # Tests
pnpm prisma studio     # DB GUI
```text

---

## 🔒 Security

```typescript
// ❌ NEVER expose secrets
'use client'
const key = process.env.API_KEY; // Exposed!

// ✅ Server-only
const key = process.env.API_KEY; // Safe in Server Component
```text

---

## 🤖 Agents

| Command | Purpose |
|---------|---------|
| `/agent:code-reviewer` | Code review |
| `/agent:nextjs-expert` | Next.js help |
