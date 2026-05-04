---
gsd_state_version: 1.0
milestone: v5.0
milestone_name: Per-MCP Scope + Project Secrets Boundary
status: defining_requirements
last_updated: "2026-05-04T00:00:00.000Z"
last_activity: "2026-05-04 — v5.0 milestone started; REQUIREMENTS + ROADMAP next"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-04)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** v5.0 Per-MCP Scope + Project Secrets Boundary — granular per-row scope control + safe project-scope secrets handling

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-05-04 — v5.0 milestone started

## Accumulated Context

### Decisions (carry-over relevant for v5.0)

Full log in PROJECT.md Key Decisions table. Recent highlights still relevant:

- **Phase 25 (v4.6) MCP catalog foundation:** `scripts/lib/mcp-catalog.json` (renamed `integrations-catalog.json` in v4.9) + `scripts/lib/mcp.sh` + TUI is the foundation. v5.0 extends, does not rewrite.
- **Phase 37 (v4.9 follow-up, commit fc000d5) global scope toggle:** `TK_MCP_SCOPE` env var + TUI header `s` keypress flip user/local. v5.0 makes this per-row; the global toggle becomes "set all" shortcut.
- **MCP-SEC-01/02 (v4.6):** `~/.claude/mcp-config.env` mode 0600 enforcement. Carries forward verbatim for user-scope secrets.
- **v4.3 UN-03 `[y/N/d]` prompt contract:** read from `< /dev/tty`, fail-closed `N` on no-TTY. Reuse for new uninstall secret-cleanup prompts.
- **Bash 3.2 compatibility:** no `declare -A`, no `read -N`, no float `-t`, no `declare -n`. Inherited.
- **`unofficial` badge contract (v4.9 TUI-03):** yellow `!` glyph + explicit confirmation prompt. Calendly is **official** (no badge).
- **claude.ai built-in connectors (Gmail/Calendar/Drive):** out of toolkit catalog scope — Anthropic owns that surface. Decided 2026-05-04 not to add a community Google Workspace MCP that would duplicate it.

### Key v5.0 Constraints

- **Per-MCP scope, not global:** every MCP row in the TUI carries its own scope indicator `[U]`/`[P]`/`[L]`; user can mix scopes in one install pass. Global header toggle becomes "set all" convenience.
- **Defaults baked into catalog:** `default_scope` field on each MCP. Personal-tooling MCPs default `user`; per-app infra MCPs default `project`. Defaults override-able by user before commit.
- **Secrets boundary is non-negotiable:** literal secrets must NEVER land in `.mcp.json` (it lives in the repo). Project-scope writes `${VAR}` substitution form into `.mcp.json` and the real value into `<project>/.env` (mode 0600). Defense-in-depth: a validator in the writer refuses any literal value in a `.mcp.json` env block.
- **`.gitignore` guard:** project-scope writer ensures `.env` is in `<project>/.gitignore` before writing the file. Idempotent — appends only if absent.
- **Uninstall prompts secret cleanup:** removing one MCP triggers `[y/N] also remove keys K1, K2 from mcp-config.env?` (default N — preserve, user may reinstall). Full toolkit uninstall asks once about the whole `mcp-config.env`. Project `.env` files are **never** touched by toolkit (they belong to the user's project).
- **Backward compat:** absence of `default_scope` in a catalog entry → silent fallback to `user`. No migration prompt. Pre-v5.0 secrets in `mcp-config.env` stay where they are.
- **Catalog growth this milestone is small:** add Calendly only. Google Workspace deliberately deferred (claude.ai connectors cover it).

### Carry-overs from v4.9 (still deferred, not v5.0 scope)

- 8 HUMAN-UAT items from v4.6 (live PTY + external CLI) — run when convenient.
- 5 advisory code-review WR findings in Phase 24.
- `--no-council` flag for `/audit` — keep deferred.
- Sentinel writer instrumentation in `setup-security.sh` / `init-claude.sh` (Phase 19 D-01).
- Selective uninstall (`--only commands/`, `--except council/`).
- Branding substitution layer (BRIDGE-FUT-01).
- Cursor `.cursorrules` / Aider `CONVENTIONS.md` bridges (BRIDGE-FUT-03/04).
- Council Rework parallel track items.
- Permanently locked out: Docker-per-cell isolation, agent-cut release tags.

### Roadmap Evolution

- 2026-04-21: v4.0 shipped
- 2026-04-25: v4.1 shipped
- 2026-04-26: v4.2 + v4.3 shipped
- 2026-04-27: v4.4 shipped
- 2026-04-29: v4.6 + v4.7 + v4.8 all shipped
- 2026-05-02: v4.9 shipped (Integrations Catalog)
- 2026-05-04: v5.0 milestone started — Per-MCP Scope + Project Secrets Boundary

### Pending Todos

- Define REQUIREMENTS.md with REQ-IDs covering: catalog `default_scope` field (SCOPE-*), TUI per-row scope toggle (TUI-*), project secrets writer lib (SEC-*), wizard dispatch update (DISP-*), uninstall secret cleanup (UN-*), Calendly catalog entry (INT-*), tests (TEST-*), docs (DOCS-*).
- Create ROADMAP.md decomposing into phases (continuing numbering from 35 → 36+).
- Run `/gsd-plan-phase 36` to begin executing the milestone.

### Blockers/Concerns

None. v4.9 catalog + TUI foundation is solid; v5.0 is incremental on top of it.

### Quick Tasks Completed (recent)

| # | Description | Date | Commit |
|---|-------------|------|--------|
| 260501-lrq | Fix critical install bugs + Council in TUI dispatch + TUI render upgrade + 2 hermetic test suites | 2026-05-01 | 81ba552 |
| 260430-go5 | PR #15 — 18 audit findings closed + 1 Gemini dead-code | 2026-04-30 | 21 commits |

## Deferred Items

Carry-overs available for next milestone scoping (unchanged from v4.9 close):

| Category | Item | Status |
|----------|------|--------|
| Locked out | Docker-per-cell isolation | Permanently out (POSIX invariant) |
| Locked out | Auto-cut `git tag` from phase execution | Permanently out (CLAUDE.md "never push main") |
| Future | `--preset minimal\|full\|dev` | TUI-FUT-04 — revisit after 19-entry catalog in production |
| Future | TUI search/filter input | TUI-FUT-05 — only useful at >30 entries |
| Future | Catalog auto-sync with upstream MCP registry | CAT-FUT-01 — blocked on no upstream registry yet |
| Future | User-extensible local catalog | CAT-FUT-02 — solo-dev rarely adds custom entries |
| Future | Windows support via WSL/chocolatey | CLI-FUT-01 — out of scope per POSIX invariant |
| Future | CLI version pinning | CLI-FUT-02 — KISS, vendors handle update channels |
| Future | Mailgun MCP, Discord MCP, GitHub Issues MCP | INT-FUT-01/03/04 |
| Future | Google Workspace MCP wrapper | INT-FUT-05 — claude.ai built-in connectors cover it |
| Future | Cursor `.cursorrules` / Aider `CONVENTIONS.md` | BRIDGE-FUT-03/04 (carry-over from v4.8) |
| Deferred | Branding substitution layer for bridge files | BRIDGE-FUT-01 |
| Deferred | Per-CLI tone overlay snippets | BRIDGE-FUT-02 |
| Deferred | `update-claude.sh --bridges-only` mode | BRIDGE-FUT-05 |
| Parallel track | Council Rework | concurrent session |

## Session Continuity

Last session: 2026-05-02T11:30:00.000Z (v4.9 ship)
Started: v5.0 Per-MCP Scope + Project Secrets Boundary
Resume file: None

**Next steps:**

1. ▶ Generate REQUIREMENTS.md with REQ-IDs.
2. ▶ Spawn `gsd-roadmapper` to produce ROADMAP.md continuing phase numbering from 35.
3. ▶ Run `/gsd-plan-phase 36` to begin executing the milestone.
