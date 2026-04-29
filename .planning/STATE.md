---
gsd_state_version: 1.0
milestone: v4.5
milestone_name: Install Flow UX & Desktop Reach
status: verifying
stopped_at: Completed 24-05-manifest-and-docs-PLAN.md
last_updated: "2026-04-29T11:40:17.914Z"
last_activity: 2026-04-29
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 5
  completed_plans: 5
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-29)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** Phase 24 — unified-tui-installer-centralized-detection

## Current Position

```
Phase 24 [ ] Phase 25 [ ] Phase 26 [ ] Phase 27 [ ]
  0%                                                100%
|-------------------------------------------------------|
```

Phase: 25
Plan: Not started
Status: Phase complete — ready for verification
Last activity: 2026-04-29

## Plan Count Estimate

| Phase | Estimated Plans | Rationale |
|-------|-----------------|-----------|
| 24 — Unified TUI Installer + Centralized Detection | 5 | `detect2.sh` (1) + `tui.sh` core (1) + `dispatch.sh` + `--yes` flag rollout (1) + `install.sh` orchestrator (1) + hermetic test + manifest wiring (1) |
| 25 — MCP Selector | 4 | MCP catalog + `templates/mcps/` structure (1) + `is_mcp_installed` + TUI page (1) + per-MCP wizard + secrets handling (1) + hermetic test + `docs/MCP-SETUP.md` (1) |
| 26 — Skills Selector | 3 | Skills mirror + license audit + `docs/SKILLS-MIRROR.md` (1) + `is_skill_installed` + TUI page + copy dispatch (1) + hermetic test + manifest wiring (1) |
| 27 — Marketplace Publishing + Desktop Reach | 4 | `marketplace.json` + `plugin.json` trio (1) + `validate-marketplace` + `make check` wiring (1) + `docs/CLAUDE_DESKTOP.md` + `validate-skills-desktop.sh` (1) + `--skills-only` Desktop routing + README/INSTALL.md (1) |

**Total estimated plans: 16**

## Performance Metrics

**v4.4 totals (2026-04-27, 1 day):**

- Phases: 3 (21–23)
- Plans: 8
- Tasks: 19
- REQ-IDs: 9 (BOOTSTRAP-01..04, LIB-01/02, BANNER-01, KEEP-01/02)
- New tests: 4 test files, 52 assertions
- CI: Tests 21-30 green

**v4.3 totals (2026-04-26, single day):**

- Phases: 3 (18–20)
- Plans: 10
- Tasks: 12
- Commits: 50+ (`v4.2.0 → v4.3.0`)
- Diff: 129 files changed (+11307 / −307)
- New tests: 7 uninstall-suite files, 67 assertions
- New CI gate: quality.yml mirrors full uninstall suite

**v4.2 totals (2026-04-25 → 2026-04-26):**

- Phases: 5 (13–17)
- Plans: 22
- Tasks: 23
- Commits: 82 (`v4.1.1 → v4.2.0`)
- Diff: 207 files changed (+39997 / −18884)

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions table. Recent v4.4 highlights:

- `NO_BANNER=${NO_BANNER:-0}` env-form (not `NO_BANNER=0`) — allows caller-exported env to be honoured; `NO_BANNER=0` assignment would clobber caller env silently
- `files.libs[]` in manifest.json auto-discovered by existing `update-claude.sh` jq path with zero code changes (D-07 zero-special-casing invariant)
- Phase 21 + Phase 22 consolidated into single `[4.4.0]` CHANGELOG entry — Phase 21 was never separately released before Phase 22 landed
- `--keep-state` gate at D-06 LAST-step position — preserves all UN-01..UN-08 invariants (backup → strip → file-delete → state-delete ordering unchanged)
- [Phase 24]: D-21: detect2.sh sources detect.sh — SP/GSD logic not duplicated
- [Phase 24]: D-22: binary 0/1 return from every is_*_installed probe
- [Phase 24]: D-23: detect2_cache helper for D-23 mid-run drift recheck pattern
- [Phase 24]: Comment text in tui.sh header paraphrases forbidden Bash 3.2 patterns to avoid grep false-positives in acceptance criteria
- [Phase 24]: TK_TUI_TTY_SRC seam mirrors TK_BOOTSTRAP_TTY_SRC exactly — per-read redirection inside each function, not global exec redirect
- [Phase 24]: D-24: curl-pipe detection via BASH_SOURCE[0]==/dev/fd/* or $0==bash
- [Phase 24]: D-25: dispatcher contract: each accepts --force/--dry-run/--yes, returns exit code unchanged
- [Phase 24]: D-26: setup-security.sh --yes active (future read guards); install-statusline.sh --yes no-op
- [Phase 24]: run_cleanup uses if/then not && to prevent empty-array condition from setting EXIT trap exit code
- [Phase 24]: S9 uses non-existent TTY path not /dev/null to trigger D-05 fork (/dev/null is readable)
- [Phase 24]: Test seam overrides use real bash scripts (_NOOP_SCRIPT) not ':' builtin
- [Phase 24]: D-31: install.sh flags documented alongside (not replacing) init-claude.sh flags in INSTALL.md
- [Phase 24]: Manifest version NOT bumped to 4.5.0 in Phase 24 — deferred to Phase 27 distribution phase per CONTEXT.md Deferred Ideas
- [Phase 24]: libs[] entries sorted alphabetically; scripts[] is order-preserving (install.sh appended after uninstall.sh)

### Key v4.5 Constraints (from research)

- TUI must use `read -rsn1` (lowercase n) not `read -N` — `read -N` is Bash 4+ only; macOS ships Bash 3.2.57
- No `declare -n` namerefs in TUI — Bash 4.3+ only; multi-component state passes via space-separated strings or eval-based indirect expansion
- Arrow key detection: two-pass `read -rsn1 k; if [[ "$k" == $'\e' ]]; then IFS= read -rsn2 extra; fi`
- `stty -g` save + `trap restore EXIT INT TERM` MUST be set BEFORE entering raw mode — prevents blind-typing terminal after Ctrl-C
- `TK_TUI_TTY_SRC` test seam mirrors `TK_BOOTSTRAP_TTY_SRC` pattern from v4.4
- `command -v cc-safety-net` for security detection (NOT npm-path scan) — covers both brew and npm install paths
- `is_mcp_installed` must fail-soft when `claude` CLI absent (warn, not error)
- `~/.claude/mcp-config.env` mode 0600 mandatory — never print keys to stdout; `read -rs` for sensitive input
- Marketplace schema: validate with `claude plugin validate .` before publishing; CI smoke gated behind `TK_HAS_CLAUDE_CLI=1`
- BOOTSTRAP-01..04 invariant: 26-assertion `test-bootstrap.sh` must stay green throughout Phase 24

### Roadmap Evolution

- 2026-04-21: v4.0 shipped (Phases 1–7 + 6.1)
- 2026-04-25: v4.1 shipped (Phases 8–12); v4.2 roadmap created (Phases 13–17, 22 REQ-IDs)
- 2026-04-26: v4.2 shipped — tagged `v4.2.0` + GitHub Release published
- 2026-04-26: Phase 19 (state-cleanup-idempotency) verified PASSED — UN-05 + UN-06 complete
- 2026-04-26: Phase 20 (distribution-tests) verified PASSED — UN-07 + UN-08 complete; v4.3 milestone ready for tag
- 2026-04-27: v4.4 roadmap created — 3 phases (21–23), 9 REQ-IDs, 100% coverage
- 2026-04-27: v4.4 shipped — 8/8 plans, 19 tasks, 9/9 REQ-IDs validated; archive at `.planning/milestones/v4.4-{ROADMAP,REQUIREMENTS}.md`; awaiting `v4.4.0` tag on main HEAD
- 2026-04-29: v4.5 milestone scoped — Install Flow UX & Desktop Reach; 4 phases (24–27), 36 REQ-IDs
- 2026-04-29: v4.5 roadmap created — Phase 24 (Unified TUI Installer + Centralized Detection), Phase 25 (MCP Selector), Phase 26 (Skills Selector), Phase 27 (Marketplace Publishing + Claude Desktop Reach)

### Pending Todos

None.

### Blockers/Concerns

None.

## Deferred Items

Carry-overs available for next milestone scoping:

| Category | Item | Status |
|----------|------|--------|
| Locked out | Docker-per-cell isolation | Permanently out (conflicts with POSIX invariant) |
| Locked out | Auto-cut `git tag` from phase execution | Permanently out (CLAUDE.md "never push main") |
| Closed | HARDEN-C-04 — uninstall script | Done in v4.3 (`scripts/uninstall.sh`, UN-01..UN-08) |
| Closed | AUDIT-10 collision detection | Done — already covered by idempotent install + SHA256 manifest diff (closed 2026-04-26) |
| Closed | AUDIT-12 command markdown linting | Done by HARDEN-A-01 (`scripts/validate-commands.py`) |
| Closed | AUDIT-14 uninstall semantics | Done by v4.3 Uninstall (closed 2026-04-26) |
| Closed | AUDIT-15 provenance metadata | Done — already covered by `~/.claude/toolkit-install.json` (closed 2026-04-26) |
| WONTFIX | AUDIT-02 compat matrix | KISS — install-time picks 1 framework, no overlay scenario (closed 2026-04-26) |
| WONTFIX | AUDIT-04 merge-strategy | KISS — no multi-template overlay; per-file fallback in installers is sufficient (closed 2026-04-26) |
| WONTFIX | AUDIT-06 template version pinning | Already covered — `manifest.json` `version` + `~/.claude/.toolkit-version` + smart-update diff (closed 2026-04-26) |
| Closed | DETECT-FUT-01 CLI detection | Done by DETECT-06 in v4.1 Phase 9 (`claude plugin list --json` cross-check) |
| WONTFIX | Council `audit-review` → Sentry/Linear ticket creation | User direction 2026-04-27: Sentry reserved for error monitoring; project tracking lives in a separate system |
| Deferred to v4.6 | `--no-council` flag for `/audit` | Mandatory pass in v4.2; revisit if friction emerges |
| In v4.5 Phase 25 | MCP rotate-to-secret-manager recipe | `docs/MCP-SETUP.md` documents plaintext-on-disk + rotation recipe (TUI-FUT-01 deferred) |
| Future | `--preset minimal\|full\|dev` | TUI-FUT-02 — no demand surfaced; v4.6+ |
| Future | Grouped sections in TUI (Essentials / Optional) | TUI-FUT-03 — should-have, may land in Phase 24 if plan capacity allows |
| Future | MCP catalog auto-sync with upstream registry | MCP-FUT-02 — v4.6+ |
| Future | Marketplace signing/integrity | MKT-FUT-01 — no Anthropic spec for it yet |
| Phase 24 P01 | 15m | 3 tasks | 2 files |
| Phase 24 P02 | 6 | 3 tasks | 1 files |
| Phase 24 P03 | 4min | 4 tasks | 3 files |
| Phase 24 P04 | 180 | 3 tasks | 5 files |
| Phase 24 P05 | 10 | 3 tasks | 2 files |

## Session Continuity

Last session: 2026-04-29T11:26:43.432Z
Stopped at: Completed 24-05-manifest-and-docs-PLAN.md
Resume file: None

**To start v4.5 implementation:**

- `/gsd-plan-phase 24` — plan Phase 24 (Unified TUI Installer + Centralized Detection)
