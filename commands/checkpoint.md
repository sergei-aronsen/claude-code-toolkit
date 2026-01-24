# /checkpoint — Save Progress

## Purpose

Save current progress, decisions, and state to scratchpad for continuity.

---

## Usage

```text
/checkpoint [description]
```text

**Examples:**

- `/checkpoint completed user auth`
- `/checkpoint phase 1 done, starting phase 2`
- `/checkpoint blocked - need API credentials`

---

## What Gets Saved

1. **Progress** — What's completed, what's pending
2. **Current State** — Files modified, tests status
3. **Decisions** — Why certain approaches were chosen
4. **Blockers** — Issues preventing progress
5. **Next Steps** — What to do next

---

## Output Format

```markdown
# Checkpoint: [Description]
*Saved: [timestamp]*

## Progress
- [x] Phase 1: Database migration
- [x] Phase 2: Model and relationships
- [ ] Phase 3: Controller endpoints
- [ ] Phase 4: Frontend components

## Files Modified
| File | Changes |
|------|---------|
| `migrations/xxx.php` | Created sites table |
| `app/Models/Site.php` | Added relations |

## Tests Status
- ✅ 12 passing
- ❌ 0 failing
- ⏭️ 5 pending (for Phase 3)

## Decisions Made
1. Used UUIDs instead of auto-increment for security
2. Soft deletes enabled for audit trail

## Current Blockers
- None

## Next Steps
1. Create SiteController with CRUD
2. Add form validation
3. Write controller tests

## Resume Command
To continue from here:
\`\`\`
Read .claude/scratchpad/checkpoint-[slug].md and continue from Phase 3
\`\`\`
```text

---

## Saved Location

Checkpoints saved to: `.claude/scratchpad/checkpoint-[slug].md`

---

## When to Use

| Scenario | Action |
|----------|--------|
| Completing a phase | `/checkpoint phase N complete` |
| Before breaking | `/checkpoint stopping for today` |
| Hit a blocker | `/checkpoint blocked on X` |
| Major decision made | `/checkpoint decided to use X` |

---

## Resume Work

To continue after a checkpoint:

```text
Read .claude/scratchpad/checkpoint-[latest].md and continue where we left off
```text
