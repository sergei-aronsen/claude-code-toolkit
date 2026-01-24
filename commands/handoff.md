# /handoff — Prepare Task Handoff

## Purpose

Create comprehensive handoff documentation for another developer or AI session.

---

## Usage

```text
/handoff [task name]
```text

**Examples:**

- `/handoff OAuth implementation`
- `/handoff bug fix #123`
- `/handoff refactoring project`

---

## What Gets Documented

1. **Context** — What the task is about
2. **Progress** — What's done, what's remaining
3. **Key Decisions** — Why things were done certain ways
4. **Gotchas** — Things that tripped you up
5. **Next Steps** — Clear instructions for continuing

---

## Output Format

```markdown
# Handoff: [Task Name]
*Created: [timestamp]*

## Context
**Task:** [Brief description]
**Started:** [date]
**Status:** [In Progress / Blocked / Ready for Review]

## Summary
[2-3 sentences explaining what this task is about and current state]

## Progress

### Completed ✅
1. Created database migration for sites table
2. Added Site model with relationships
3. Implemented SiteController CRUD operations
4. Added form validation via StoreSiteRequest

### Remaining 🔄
1. Frontend components (Vue)
2. Tests for edge cases
3. Documentation

## Files Changed
| File | Changes | Status |
|------|---------|--------|
| `migrations/xxx_sites.php` | New table | ✅ Done |
| `app/Models/Site.php` | New model | ✅ Done |
| `app/Http/Controllers/SiteController.php` | CRUD | ✅ Done |
| `resources/js/Pages/Sites/Index.vue` | List view | 🔄 TODO |

## Key Decisions

### 1. UUIDs for IDs
**Why:** Security - prevents enumeration attacks
**Impact:** Need to update foreign keys accordingly

### 2. Soft Deletes
**Why:** Audit trail and recovery capability
**Impact:** Add `withTrashed()` when querying all records

## Gotchas ⚠️

1. **Migration order matters** — Run users before sites
2. **Cache invalidation** — Clear after updating site
3. **Policy registration** — Don't forget AuthServiceProvider

## Environment Notes
- Requires Redis for caching
- Uses Laravel Telescope (dev only)
- Queue worker needed for notifications

## How to Continue

### Quick Start
\`\`\`bash
git checkout feature/sites
php artisan migrate
npm run dev
\`\`\`

### Next Steps
1. Read `app/Http/Controllers/SiteController.php` to understand API
2. Create Vue components in `resources/js/Pages/Sites/`
3. Add tests in `tests/Feature/SiteTest.php`

### Related Files to Read
- `CLAUDE.md` — Project conventions
- `app/Policies/SitePolicy.php` — Authorization rules
- `routes/web.php` — Route definitions

## Questions to Resolve
- [ ] Should we add API endpoints too?
- [ ] Pagination: 10 or 20 items per page?

## Contacts
- **Original dev:** [Name]
- **Slack:** #project-channel
```text

---

## Saved Location

Handoffs saved to: `.claude/scratchpad/handoff-[task-slug].md`

---

## When to Use

| Scenario | Action |
|----------|--------|
| End of day | `/handoff current task` |
| Passing to teammate | `/handoff for-[name]` |
| Context limit reached | `/handoff continuation` |
| Going on vacation | `/handoff full-project` |
