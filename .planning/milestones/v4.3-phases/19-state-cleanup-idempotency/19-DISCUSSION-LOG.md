# Phase 19: State Cleanup + Idempotency — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 19-state-cleanup-idempotency
**Areas discussed:** Sentinel writers, State delete semantics, Idempotency detection signal, Empty global CLAUDE.md handling

---

## Sentinel writer scope

| Option | Description | Selected |
|--------|-------------|----------|
| Strip-only (Recommended) | Phase 19 only implements the reader; defer writer instrumentation to v4.4 | ✓ |
| Strip + writer | Also update setup-security.sh and init-claude.sh to wrap their additions in sentinels | |
| Strip + minimal writer (security only) | Only setup-security.sh wraps its block; init/update untouched | |

**User's choice:** "решай все сам" — Claude selected Strip-only.
**Notes:** UN-05 says "if present" → strip is graceful no-op when absent. KISS bias. Writer expansion captured in Deferred Ideas for v4.4.

---

## State delete semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Always delete (Recommended) | Delete `toolkit-install.json` at end of flow regardless of how many files user kept | ✓ |
| Conditional delete | Only delete if zero files were kept (all REMOVE branches taken) | |
| `--keep-state` flag | User opt-in to preserve state | |

**User's choice:** "решай все сам" — Claude selected Always delete.
**Notes:** Matches UN-06 idempotency contract (second run = no-op via missing state). `--keep-state` flag deferred per REQUIREMENTS.md Out of Scope.

---

## Idempotency detection signal

| Option | Description | Selected |
|--------|-------------|----------|
| State file missing only (Recommended) | `[[ -f "$STATE_FILE" ]]` — single canonical signal | ✓ |
| State + filesystem scan | Also scan `.claude/` for orphaned toolkit files | |
| State + sentinel block check | Also verify `~/.claude/CLAUDE.md` doesn't have TOOLKIT block | |

**User's choice:** "решай все сам" — Claude selected State file missing only.
**Notes:** State file is canonical. Filesystem scan adds false-positive surface (user-authored files in .claude/) without proportional safety win. Honor manual cleanup intent.

---

## Empty global CLAUDE.md handling

| Option | Description | Selected |
|--------|-------------|----------|
| Leave empty file (Recommended) | Strip block, leave empty/whitespace-only file on disk | ✓ |
| Delete if empty | Remove the file if nothing remains after strip | |
| Restore from backup | Replace with last backed-up version | |

**User's choice:** "решай все сам" — Claude selected Leave empty.
**Notes:** `~/.claude/CLAUDE.md` is shared with rtk, gsd, user-authored content. Toolkit only partially owns this file → least-destruction principle. Empty CLAUDE.md is harmless to Claude Code.

## Claude's Discretion

User explicitly delegated all four areas with `решай все сам`. Decisions reflect KISS/YAGNI bias and align with `REQUIREMENTS.md` Out of Scope list.

## Deferred Ideas

- Sentinel writer instrumentation in installers (v4.4)
- `--keep-state` flag (v4.4)
- Selective uninstall (`--only`, `--except`) (v4.5+)
- Filesystem-scan-based idempotency fallback (v4.4 if demand)
- Re-install / upgrade UX (v4.4+)
