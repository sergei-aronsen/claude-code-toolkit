# Lantern SaaS — Claude Code Instructions

## 🎯 Project Overview

**Stack:** Laravel 11 + Vue 3 + Inertia.js + Tailwind CSS
**Type:** SaaS — Site analyzer and monitoring tool
**Database:** MySQL 8.0
**PHP:** 8.3 | **Node:** 20

---

## 🧠 WORKFLOW RULES

### Plan Mode — ALWAYS USE BEFORE CODING

1. **Activate Plan Mode** — `Shift+Tab` twice
2. **Research** the task and existing code
3. **Create plan** in `.claude/scratchpad/current-task.md`
4. **Wait for approval** before writing code

| Level | When |
| ------- | ------ |
| `think` | Simple changes |
| `think hard` | Medium complexity |
| `think harder` | Architecture decisions |
| `ultrathink` | Security, payments |

---

## 📁 Project Structure

```text
app/
├── Actions/           # CreateSite, RunCheck, etc.
├── Http/Controllers/  # Thin, delegate to Actions
├── Models/            # Site, Check, User, Team
├── Services/          # AnalyzerService, NotificationService
├── Jobs/              # ProcessCheck, SendAlert
└── Policies/          # SitePolicy, TeamPolicy

resources/js/
├── Pages/             # Inertia pages
├── Components/
│   ├── UI/            # Button, Modal, Card
│   └── Sites/         # SiteCard, CheckHistory
└── Composables/       # useSite, useTeam
```text

---

## ⚡ Commands

```bash
# Dev
npm run dev && php artisan serve

# Test
php artisan test
./vendor/bin/pint  # Format PHP

# Queue
php artisan queue:work
```text

---

## 🔒 Security Rules

```php
// ❌ NEVER
DB::raw("... $userInput ...");
protected $guarded = [];

// ✅ ALWAYS
$request->validated();
$this->authorize('update', $site);
```text

---

## 🤖 Agents

| Command | Purpose |
| --------- | --------- |
| `/agent:code-reviewer` | Code review |
| `/agent:test-writer` | TDD tests |
| `/agent:laravel-expert` | Laravel help |

---

## ⚠️ Project Notes

- Multi-tenant via Team model
- Rate limited to 100 checks/day per team
- Redis for queues and cache
