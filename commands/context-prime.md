# /context-prime — Load Project Context

## Purpose

Prime Claude with essential project context before starting work.

---

## Usage

```text
/context-prime [area]
```text

**Examples:**

- `/context-prime` — Full project context
- `/context-prime auth` — Authentication area
- `/context-prime api` — API endpoints
- `/context-prime database` — Database schema

---

## What Gets Loaded

### Full Prime (default)

1. `CLAUDE.md` — Project instructions
2. `README.md` — Project overview
3. `.env.example` — Environment structure
4. Database schema / migrations
5. Route definitions
6. Key configuration files

### Area-Specific

| Area | Files Loaded |
|------|-------------|
| `auth` | Auth controllers, middleware, policies, guards |
| `api` | API routes, controllers, resources |
| `database` | Migrations, models, factories |
| `frontend` | Components, pages, layouts |
| `tests` | Test structure, factories, helpers |

---

## Process

### Step 1: Read Core Files

```bash
# Always read first
cat CLAUDE.md
cat README.md
cat .env.example
```text

### Step 2: Understand Structure

```bash
# Laravel
php artisan route:list --compact
cat database/schema.sql  # if exists

# Next.js
ls -la app/
cat prisma/schema.prisma
```text

### Step 3: Load Area Context

```bash
# Based on requested area
find app/Http/Controllers -name "*.php" | head -20
find resources/js/Pages -name "*.vue" | head -20
```text

---

## Output Format

```markdown
## Project Context Loaded

### Project: [Name]
**Stack:** Laravel 11 + Vue 3 + MySQL
**Type:** SaaS Application

### Key Files Read
- ✅ CLAUDE.md
- ✅ README.md
- ✅ database/schema.sql

### Routes Summary
| Method | URI | Controller |
|--------|-----|------------|
| GET | /sites | SiteController@index |
| POST | /sites | SiteController@store |

### Models Summary
| Model | Key Relations |
|-------|--------------|
| Site | belongsTo User, hasMany Check |
| User | hasMany Site |

### Ready to Work On
I now understand:
- Project structure ✅
- Authentication flow ✅
- Database schema ✅
- Coding conventions ✅

What would you like me to help with?
```text

---

## When to Use

| Scenario | Action |
|----------|--------|
| Starting new session | `/context-prime` |
| Working on specific area | `/context-prime [area]` |
| Context seems stale | `/context-prime` |
| After switching branches | `/context-prime` |

---

## Tips

1. **Use at session start** — Fresh context prevents outdated assumptions
2. **Specify area** — More focused context for specific tasks
3. **Combine with /plan** — Prime first, then plan the task
