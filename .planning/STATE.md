---
gsd_state_version: 1.0
milestone: v4.7
milestone_name: Multi-CLI Bridge
status: executing
stopped_at: Completed 31-02-PLAN.md
last_updated: "2026-04-29T21:22:54.674Z"
last_activity: 2026-04-29
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 12
  completed_plans: 12
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-29)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** v4.7 Multi-CLI Bridge — Phase 30 (Install-time UX) — All 3 plans complete

## Current Position

```text
Phase 28 [x] Phase 29 [x] Phase 30 [x] Phase 31 [ ]
  75%                                               100%
|---------------------------------------|-----------|---|
```

Phase: 30
Plan: 03 complete (Phase 30 fully complete; Phase 31 Distribution+Tests+Docs next)
Status: In progress — Phase 30 all plans complete
Last activity: 2026-04-29

## Plan Count Estimate

| Phase | Estimated Plans | Rationale |
|-------|-----------------|-----------|
| 28 — Bridge Foundation | 3 | `detect2.sh` extension + `bridge_create_*` API (1) + header banner + state schema (`bridges[]`) (1) + hermetic sanity test for plain-copy + idempotency (1) |
| 29 — Sync & Uninstall Integration | 3 | `update-claude.sh` bridge sync loop with `[y/N/d]` (1) + `--break-bridge` / `--restore-bridge` + ORPHANED handling (1) + `uninstall.sh` REMOVE_LIST + `--keep-state` parity (1) |
| 30 — Install-time UX | 3 | `install.sh` Components page rows + per-CLI version probe (1) + `init-claude.sh` + `init-local.sh` post-install prompt + `TK_BRIDGE_TTY_SRC` (1) + `--no-bridges` / `TK_NO_BRIDGES` / `--bridges <list>` flag rollout (1) |
| 31 — Distribution + Tests + Docs | 3 | `manifest.json` 4.7.0 + `files.libs[]` registration (1) + `test-bridges.sh` ≥15 assertions + Makefile + CI wiring (1) + `docs/BRIDGES.md` + `docs/INSTALL.md` flag rows + README + `CHANGELOG.md [4.7.0]` (1) |

**Total estimated plans: 12**

## Performance Metrics

**v4.6 totals (2026-04-29, 1 day):**

- Phases: 4 (24–27)
- Plans: 17
- Tasks: 42
- REQ-IDs: 36 (TUI-01..07, DET-01..05, DISPATCH-01..03, BACKCOMPAT-01, MCP-01..05, MCP-SEC-01/02, SKILL-01..05, MKT-01..04, DESK-01..04)
- New tests: 5 hermetic suites (PASS=104+: test-install-tui 43, test-mcp-selector 21, test-install-skills 15, test-update-libs 15, test-bootstrap 26 unchanged)
- CI: Tests 21-33 + DESK-02/04 + MKT-03 jobs

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

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions table. Recent v4.6 highlights still relevant for v4.7:

- Phase 24 lib foundation (`scripts/lib/{tui.sh, detect2.sh, dispatch.sh}`) is the integration point for v4.7 — bridges become new dispatchable components, not duplicate machinery.
- BACKCOMPAT-01 invariant from v4.6: `init-claude.sh` URL stays byte-identical with all v4.4 flags + bridge prompts must skip-by-default in `--yes` / no-TTY paths.
- v4.4 LIB-01 D-07 jq path (`.files | to_entries[] | .value[] | .path`) auto-discovers any new `files.libs[]` entry — `bridges.sh` adds zero new code to `update-claude.sh`.
- v4.3 UN-03 `[y/N/d]` prompt contract: read from `< /dev/tty`, fail-closed `N` on no-TTY, `d` shows diff and re-prompts. Reuse verbatim for bridge drift detection.
- v4.4 BOOTSTRAP-01 `TK_BOOTSTRAP_TTY_SRC` test seam pattern → mirror as `TK_BRIDGE_TTY_SRC` for hermetic testing of bridge prompts.
- v4.4 KEEP-01/02 `--keep-state` semantics already cover bridges via the same toolkit-install.json lifecycle — no special case for `bridges[]`.
- Plain-copy over symlink decision: chosen because users may want CLI-specific edits; drift handled via SHA256 + `[y/N/d]`, not by abandoning copy semantics. (PROJECT.md "Key context".)
- Bash 3.2 compatibility: no `declare -A`, no `read -N` (Bash 4+), no float `-t`, no `declare -n` namerefs. Already-shipped Phase 24 invariants; bridges.sh inherits them.
- [Phase 28]: Both new probes inserted before is_gsd_installed (codex < gemini < gsd lex order)
- [Phase 28]: detect2_cache IS_COD/IS_GEM appended after IS_SL; export line extended
- [Phase 28-bridge-foundation]: write_state NOT reused for bridges[] patch — full-document overwrite would clobber installed_files[]; custom python3 tempfile+os.replace block used instead
- [Phase 28-bridge-foundation]: Codex bridge filename locked as AGENTS.md (not CODEX.md) per OpenAI standard
- [Phase 28]: Source libs at top level in test scripts, not inside scenario functions, to avoid Bash RETURN-trap pitfall where source fires RETURN trap on completion
- [Phase 28]: Use EXIT trap with _SANDBOXES array for hermetic test cleanup instead of per-scenario RETURN traps
- [Phase 29-01]: write_state bridges_json default '[]' means preserve-on-disk (not wipe-to-empty); non-default JSON overrides disk (used by update-claude.sh)
- [Phase 29-01]: bridge_prompt_drift fails closed — EOF / empty / unknown input returns 1 (keep); only explicit y/Y returns 0 (overwrite)
- [Phase 29-01]: TK_BRIDGE_TTY_SRC test seam mirrors TK_UNINSTALL_TTY_FROM_STDIN; /dev/tty is production default
- [Phase 29]: sync_bridges called in both is_update_noop branch and after print_update_summary to handle CLAUDE.md edits that bypass manifest hash diff
- [Phase 29]: bridges.sh sibling-source guarded by write_state presence check to survive tmpfile sourcing in update-claude.sh
- [Phase 29-sync-uninstall-integration]: classify_bridge_file bypasses is_protected_path; REMOVE_LIST loop has bridge bypass; self-deadlock guard in all bridge state helpers
- [Phase 30-install-time-ux]: bridge_install_prompts defaults Y at install-time (additive UX); dispatch cases deferred to install.sh (Plan 30-02); _bridge_match uses IFS-split for Bash 3.2 portability
- [Phase 30-install-time-ux]: Bridge dispatch shim inlined in install.sh (not separate lib) — fewer files
- [Phase 30-install-time-ux]: All TUI/dispatch loops use array-length-driven C-style for-loops (BACKCOMPAT-01)
- [Phase 31]: Aggregator wraps 3 child suites via for-loop rather than rewriting into monolith — mirrors v4.4 test-update-libs.sh pattern

### Key v4.7 Constraints (from REQUIREMENTS.md + PROJECT.md milestone scoping)

- Bridge file conventions: Gemini CLI → `GEMINI.md`, OpenAI Codex CLI → `AGENTS.md` (NOT `CODEX.md` — `AGENTS.md` is the OpenAI standard, called out explicitly in BRIDGE-DOCS-01 to prevent re-discussion).
- Detection strategy: `command -v gemini` / `command -v codex` (binary on PATH, primary) + `[ -d ~/.gemini/ ]` / `[ -d ~/.codex/ ]` (filesystem soft-confirm). CLI-PATH wins on conflict.
- Fail-soft on CLI absence: no error, no warning — just skip the bridge offer. Users without these CLIs see nothing in TUI / no prompts.
- Header banner is byte-identical across all bridges (BRIDGE-GEN-03 quoted block) — plain `<!-- ... -->` HTML comment, separated from copied content by exactly one blank line.
- `bridges[]` JSON schema: `{ target, path, scope: "project"|"global", source_sha256, bridge_sha256, user_owned: false }`. `user_owned` is the `--break-bridge` / `--restore-bridge` toggle.
- Council Rework Sub-Phases 2-11 run on a parallel session under `phases/24-council-globalize/PLAN.md` (its own internal numbering). Do NOT allocate v4.7 phase numbers to it; v4.7 numbering is 28-31 strictly.
- Phase numbering: v4.7 starts at Phase 28 (continues from v4.6 final Phase 27); Phase 24 is reserved historically for v4.6 + the parallel Council Rework track and is NOT reused here.
- Manifest version bump 4.6.0 → 4.7.0 deferred to Phase 31 distribution per Phase 24 D-31 pattern (don't bump until docs/changelog phase).
- CHANGELOG `[4.7.0]` consolidated single block per v4.4/v4.6 convention (one entry covers all 18 BRIDGE-* REQ-IDs).

### Carry-overs from v4.6 (still deferred, not v4.7 scope)

- 8 HUMAN-UAT items from v4.6 (live PTY + external CLI) — run when convenient; do not block v4.7 ship.
- 5 advisory code-review WR findings in Phase 24 (`tui.sh` seam-bypass + EXIT-trap clobber + `dispatch.sh` `eval` env-var injection — low real-world risk).
- `--no-council` flag for `/audit` — keep deferred.
- Sentinel writer instrumentation in `setup-security.sh` / `init-claude.sh` (Phase 19 D-01 — reader side already shipped in v4.3).
- Selective uninstall (`--only commands/`, `--except council/`) — combinatorial test surface, only revisit on real demand.
- Branding substitution layer (BRIDGE-FUT-01) — deferred to v4.8 if friction surfaces.
- Council Rework Sub-Phases 2-11 — independent track on parallel session.
- Permanently locked out: Docker-per-cell isolation, agent-cut release tags.

### Roadmap Evolution

- 2026-04-21: v4.0 shipped (Phases 1–7 + 6.1)
- 2026-04-25: v4.1 shipped (Phases 8–12); v4.2 roadmap created
- 2026-04-26: v4.2 shipped — tagged `v4.2.0`
- 2026-04-26: v4.3 shipped — tagged `v4.3.0`
- 2026-04-27: v4.4 shipped — tagged `v4.4.0`
- 2026-04-29: v4.6 shipped — tagged `v4.6.0`; archive at `.planning/milestones/v4.6-{ROADMAP,REQUIREMENTS}.md`
- 2026-04-29: v4.7 milestone scoped — Multi-CLI Bridge; 18 REQ-IDs across 6 categories
- 2026-04-29: v4.7 roadmap created — 4 phases (28-31), 100% coverage:
  - Phase 28: Bridge Foundation (BRIDGE-DET-01..03 + BRIDGE-GEN-01..04, 7 REQ-IDs)
  - Phase 29: Sync & Uninstall Integration (BRIDGE-SYNC-01..03 + BRIDGE-UN-01..02, 5 REQ-IDs)
  - Phase 30: Install-time UX (BRIDGE-UX-01..04, 4 REQ-IDs)
  - Phase 31: Distribution + Tests + Docs (BRIDGE-DIST-01..02 + BRIDGE-TEST-01 + BRIDGE-DOCS-01..02, 5 REQ-IDs)

### Pending Todos

None at roadmap-ready stage. Phase planning kicks off via `/gsd-plan-phase 28`.

### Blockers/Concerns

None. Phase 28 is unblocked — Phase 24 lib foundation already shipped in v4.6.

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
| Deferred | `--no-council` flag for `/audit` | Mandatory pass in v4.2; revisit if friction emerges |
| Closed | MCP rotate-to-secret-manager recipe | `docs/MCP-SETUP.md` documents plaintext-on-disk + rotation recipe (TUI-FUT-01 deferred) |
| Future | `--preset minimal\|full\|dev` | TUI-FUT-02 — no demand surfaced |
| Future | Grouped sections in TUI (Essentials / Optional) | TUI-FUT-03 |
| Future | MCP catalog auto-sync with upstream registry | MCP-FUT-02 |
| Future | Marketplace signing/integrity | MKT-FUT-01 — no Anthropic spec yet |
| Deferred to v4.8 | Branding substitution layer for bridge files | BRIDGE-FUT-01 — plain copy first; revisit if friction |
| Deferred to v4.8 | Per-CLI tone overlay snippets | BRIDGE-FUT-02 — `templates/bridges/<name>-overlay.md` |
| Deferred | Cursor `.cursorrules` support | BRIDGE-FUT-03 — different file format |
| Deferred | Aider `CONVENTIONS.md` support | BRIDGE-FUT-04 |
| Deferred | `update-claude.sh --bridges-only` mode | BRIDGE-FUT-05 — edge utility |
| Parallel track | Council Rework Sub-Phases 2-11 | `phases/24-council-globalize/PLAN.md`; concurrent session |
| Phase 28 P01 | 10m | 2 tasks | 1 files |
| Phase 28-bridge-foundation P02 | 20 | 4 tasks | 1 files |
| Phase 28 P03 | 26m | 2 tasks | 1 files |
| Phase 29-01 | ~25m | 3 tasks | 4 files |
| Phase 29 P02 | 35 | 2 tasks | 2 files |
| Phase 29-sync-uninstall-integration P03 | 50 | 2 tasks | 4 files |
| Phase 30-install-time-ux P01 | 12 | 4 tasks | 2 files |
| Phase 30-install-time-ux P02 | 30 | 4 tasks | 1 files |
| Phase 30-install-time-ux P03 | 45 | 4 tasks | 4 files |
| Phase 31 P02 | 5 | 2 tasks | 2 files |

## Session Continuity

Last session: 2026-04-29T21:22:54.671Z
Stopped at: Completed 31-02-PLAN.md
Resume file: None

**Next steps:**

- Phase 31 (Distribution + Tests + Docs) — closes v4.7 milestone with manifest 4.7.0 bump, test wiring to CI, docs/BRIDGES.md, CHANGELOG entry
