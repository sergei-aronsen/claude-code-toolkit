# Context Management Guide

Proactive context management for optimal Claude Code performance.

---

## TL;DR

- `/compact` at **80-83%** (don't wait for auto-compact at 90%+)
- `/clear` between **unrelated** tasks
- **Subagents** for exploration (preserves main context)
- Update `.claude/scratchpad/state.md` before `/clear` or session end

---

## Why Manual Management Matters

Claude Code has auto-compact, but:

> "Manual intervention is often more effective"
> "Waiting for auto-compact can lead to agent losing important context"

Auto-compact triggers at 75-92% — but quality degrades **non-linearly** in final 20% (80-100%).

---

## When to /compact

### Proactive (Recommended)

| Trigger | Action |
|---------|--------|
| Context at 80-83% | `/compact` immediately |
| Feature completed | `/compact` before starting next |
| PR approved/merged | `/compact` to clear review context |
| Logical breakpoint | `/compact` to preserve clean state |

### Context Zones

| Zone | Range | Action |
|------|-------|--------|
| Green | 0-60% | Optimal, work freely |
| Yellow | 60-80% | Good, plan next compact |
| Orange | 80-83% | `/compact` now (before auto-compact at ~85%) |
| Red | 85-90% | Auto-compact zone, quality degrading |
| Critical | 90%+ | `/clear` immediately |

### Custom Compaction

Tell Claude what to preserve:

```text
/compact Focus on API changes and test patterns
/compact Keep the authentication flow decisions
/compact Preserve error handling patterns
```

### Workflow Pattern

```text
Task 1 Complete → /compact → Task 2 → /compact → Task 3 → /compact
```

---

## When to /clear

### Use /clear for

| Scenario | Why |
|----------|-----|
| Switching to unrelated task | Old context is noise |
| After 2+ failed corrections | Context polluted with failed approaches |
| Claude "forgets" instructions | Context too cluttered |
| Starting fresh exploration | Clean slate needed |

### /clear vs /compact

| Command | Effect | Use When |
|---------|--------|----------|
| `/clear` | Wipes everything | Completely new task |
| `/compact` | Summarizes, keeps key info | Continuing related work |

---

## Subagent Delegation

Use subagents for research to **preserve main context**.

### Why Subagents

When Claude explores a codebase, it reads many files — all consuming your context. Subagents run in **separate context windows** and report back summaries.

### Pattern

```text
Use a subagent to investigate how authentication works.
Report back: key files, patterns used, gotchas.
```

```text
Use a subagent to review this code for security issues.
```

### When to Delegate

| Task | Use Subagent? |
|------|---------------|
| Codebase exploration | Yes |
| Research/investigation | Yes |
| Code review | Yes (fresh eyes) |
| Implementation | No (need accumulated context) |
| Debugging | No (need error history) |

---

## Session Persistence

### Before /clear or Session End

**MANDATORY:** Update `.claude/scratchpad/state.md` with current state.

```markdown
# .claude/scratchpad/state.md

## Current Status
- [ ] Active Task: Implementing OAuth flow
- [x] Recently Completed: Database migrations
- [x] Recently Completed: User model with relations

## Critical Context
- Using Passport.js because it has built-in refresh token support (don't refactor to JWT)
- Known bug in email validation module (deferred to next sprint)
- API rate limiting set to 100 req/min (load test showed 150 causes timeouts)

## Key Decisions
- Chose PostgreSQL over MySQL for JSON column support
- Using Redis for session storage (not in-memory)

## Next Steps for Next Session
1. Complete OAuth callback handler
2. Add tests for token refresh
3. Update API documentation
```

### Session Start

**FIRST ACTION:** Read `.claude/scratchpad/state.md`

```text
Read .claude/scratchpad/state.md and summarize current project state.
```

---

## Built-in Commands Reference

| Command | Purpose |
|---------|---------|
| `/compact` | Summarize conversation, keep key info |
| `/clear` | Wipe context completely |
| `/context` | View current context usage |
| `/cost` | Token usage statistics |
| `/doctor` | Session diagnostics |

---

## Warning Signs

### Context Degradation Symptoms

- Claude repeats questions already answered
- Claude "forgets" earlier decisions
- Responses become generic/less specific
- Claude makes mistakes on previously understood code

### Action

When you see these signs:

1. Check context usage (`/context`)
2. If 80-83%: `/compact`
3. If > 90% or symptoms persist: `/clear` + reload from `.claude/scratchpad/state.md`

---

## Add to CLAUDE.md

```markdown
## Context Management

### Proactive Compaction
- `/compact` at 80-83% context (don't wait for auto-compact at 90%+)
- `/compact` at logical breakpoints (feature done, PR merged)
- Quality degrades non-linearly above 80%

### Session Persistence
- Before `/clear` or session end: update `.claude/scratchpad/state.md`
- Session start: read `.claude/scratchpad/state.md` first
- Permanent project facts go in `.claude/rules/` (auto-loaded)

### Subagent Delegation
- Use subagents for exploration/research (preserves main context)
- Keep implementation in main session
```

---

## Quick Reference

```text
┌─────────────────────────────────────────────────────────┐
│  PROACTIVE CONTEXT MANAGEMENT                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ZONES:                                                 │
│  0-80%   →  Green/Yellow, work freely                   │
│  80-83%  →  Orange, /compact now                        │
│  85-90%  →  Red, auto-compact zone                      │
│  90%+    →  Critical, /clear immediately                │
│                                                         │
│  ACTIONS:                                               │
│  80-83% context  →  /compact                            │
│  Feature done    →  /compact                            │
│  Unrelated task  →  /clear (after updating state.md)     │
│  Research needed →  Use subagent                        │
│                                                         │
│  BEFORE /clear:   Update .claude/scratchpad/state.md              │
│  SESSION START:   Read .claude/scratchpad/state.md                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```
