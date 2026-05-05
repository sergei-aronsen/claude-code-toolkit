---
gsd_state_version: 1.0
milestone: v5.0
milestone_name: Per-MCP Scope + Project Secrets Boundary
status: verifying
last_updated: "2026-05-05T18:10:50.292Z"
last_activity: 2026-05-05
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 7
  completed_plans: 7
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-04)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** Phase 38 — Wizard Dispatch Integration

## Current Position

Phase: 38 (Wizard Dispatch Integration) — EXECUTING
Plan: 3 of 3
Status: Phase complete — ready for verification
Last activity: 2026-05-05

Progress: [░░░░░░░░░░░░░░░░░░░░] 0/6 phases (0%)

## Plan Count Estimate

| Phase | Plans (est.) | Notes |
|-------|--------------|-------|
| 36. Catalog Schema + Backward Compat | 2 | Small foundation phase: 1 plan = catalog + validator + loader fallback together (SCOPE-01..03 ship in one commit to avoid the schema-without-fallback window); 1 plan = sensible-defaults assignments per the SCOPE-02 grid. |
| 37. Project Secrets Library | 4 | 1 = lib skeleton + `project_secrets_write_env` (SEC-01/02/06); 1 = `project_secrets_ensure_gitignore` (SEC-03); 1 = `project_secrets_render_mcp_env_block` + literal-refusal validator (SEC-04/05); 1 = `test-project-secrets.sh` ≥18 assertions (TEST-01). |
| 38. Wizard Dispatch Integration | 4 | 1 = `mcp_wizard_run` scope-routing branch (DISP-01/02); 1 = defer-secrets path extension + 4-tuple queue (DISP-03); 1 = post-install summary printer (DISP-04); 1 = `test-mcp-wizard.sh` + `test-mcp-secrets.sh` extensions (TEST-02/03). |
| 39. TUI Per-Row Scope Toggle | 4 | 1 = per-row indicator render + `MCP_SELECTED_SCOPE[]` array (TUI-SCOPE-01/04); 1 = single-row hotkey + global `s` repurpose + banner update (TUI-SCOPE-02/03); 1 = dispatcher per-row export (TUI-SCOPE-05); 1 = `test-mcp-selector.sh` extension (TEST-04). |
| 40. Uninstall Secret Cleanup + Calendly + Validator | 5 | 1 = `uninstall_prompt_mcp_keys` + per-MCP plumbing (UN-SEC-01/02); 1 = full-toolkit `mcp-config.env` prompt + ordering (UN-SEC-03); 1 = project-`.env`-never-touched contract + `--keep-state` implies `--keep-secrets` (UN-SEC-04/05); 1 = Calendly catalog entry + Google Workspace decision log (INT-13/14) + validator SCOPE-01 assertion (TEST-06); 1 = `test-uninstall-state-cleanup.sh` extension (TEST-05). |
| 41. Distribution + Docs | 3 | 1 = manifest 5.0.0 + `project-secrets.sh` registration + 3 plugin.json bumps + version-align (DIST-01/02); 1 = CHANGELOG `[5.0.0]` consolidated entry (DIST-03); 1 = `docs/INTEGRATIONS.md` Per-MCP Scope section + INSTALL.md flag rows + UNINSTALL.md secret-cleanup section (DOCS-01/02/03). |

**Total: 22 plans across 6 phases.** Standard granularity, ~3.7 plans/phase, mirrors v4.6 / v4.8 / v4.9 cadence.

## Accumulated Context

### Decisions (carry-over relevant for v5.0)

Full log in PROJECT.md Key Decisions table. Recent highlights still relevant:

- **Phase 25 (v4.6) MCP catalog foundation:** `scripts/lib/mcp-catalog.json` (renamed `integrations-catalog.json` in v4.9) + `scripts/lib/mcp.sh` + TUI is the foundation. v5.0 extends, does not rewrite.
- **Phase 37 (v4.9 follow-up, commit fc000d5) global scope toggle:** `TK_MCP_SCOPE` env var + TUI header `s` keypress flip user/local. v5.0 makes this per-row; the global toggle becomes "set all" shortcut.
- **MCP-SEC-01/02 (v4.6):** `~/.claude/mcp-config.env` mode 0600 enforcement. Carries forward verbatim for user-scope secrets.
- **v4.3 UN-03 `[y/N/d]` prompt contract:** read from `< /dev/tty`, fail-closed `N` on no-TTY. Reuse for new uninstall secret-cleanup prompts.
- **v4.4 KEEP-01:** `uninstall.sh --keep-state` (and `TK_UNINSTALL_KEEP_STATE=1`) preserves state file. v5.0 extends: `--keep-state` implies `--keep-secrets` (UN-SEC-05).
- **Bash 3.2 compatibility:** no `declare -A`, no `read -N`, no float `-t`, no `declare -n`. Inherited.
- **`unofficial` badge contract (v4.9 TUI-03):** yellow `!` glyph + explicit confirmation prompt. Calendly is **official** (no badge).
- **claude.ai built-in connectors (Gmail/Calendar/Drive):** out of toolkit catalog scope — Anthropic owns that surface. Decided 2026-05-04 not to add a community Google Workspace MCP that would duplicate it. Logged in PROJECT.md, scheduled for CHANGELOG `[5.0.0]` via INT-14.

### Key v5.0 Constraints

- **Per-MCP scope, not global:** every MCP row in the TUI carries its own scope indicator `[U]`/`[P]`/`[L]`; user can mix scopes in one install pass. Global header toggle becomes "set all" convenience.
- **Defaults baked into catalog:** `default_scope` field on each MCP. Personal-tooling MCPs default `user`; per-app infra MCPs default `project`. Defaults override-able by user before commit.
- **Secrets boundary is non-negotiable:** literal secrets must NEVER land in `.mcp.json` (it lives in the repo). Project-scope writes `${VAR}` substitution form into `.mcp.json` and the real value into `<project>/.env` (mode 0600). Defense-in-depth: a validator in the writer refuses any literal value in a `.mcp.json` env block.
- **`.gitignore` guard:** project-scope writer ensures `.env` is in `<project>/.gitignore` before writing the file. Idempotent — appends only if absent.
- **Uninstall prompts secret cleanup:** removing one MCP triggers `[y/N] also remove keys K1, K2 from mcp-config.env?` (default N — preserve, user may reinstall). Full toolkit uninstall asks once about the whole `mcp-config.env`. Project `.env` files are **never** touched by toolkit (they belong to the user's project).
- **Backward compat:** absence of `default_scope` in a catalog entry → silent fallback to `user`. No migration prompt. Pre-v5.0 secrets in `mcp-config.env` stay where they are. Schema field + loader fallback ship in the same Phase 36 commit so there's never a window where the catalog has the field but `mcp_catalog_load` doesn't tolerate its absence.
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
- 2026-05-04: v5.0 milestone started — Per-MCP Scope + Project Secrets Boundary; REQUIREMENTS + ROADMAP locked

### Pending Todos

- ▶ Run `/gsd-plan-phase 36` to begin executing Phase 36 (Catalog Schema + Backward Compat).
- After Phase 36 closes: `/gsd-plan-phase 37` (Project Secrets Library) — depends on 36's `default_scope` semantics.
- After Phase 37 closes: `/gsd-plan-phase 38` (Wizard Dispatch Integration) — depends on 37's `project-secrets.sh` API.
- After Phase 38 closes: `/gsd-plan-phase 39` (TUI Per-Row Scope Toggle) — depends on 36 + 38; can run in parallel with Phase 40 if desired (no shared files).
- After Phase 39 + 40 close: `/gsd-plan-phase 41` (Distribution + Docs) — final close phase.

### Blockers/Concerns

None. v4.9 catalog + TUI foundation is solid; v5.0 is incremental on top of it. SCOPE-03 backward-compat fallback is co-located with SCOPE-01/02 schema landing in Phase 36 to eliminate the only sequencing risk.

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
| Future | Google Workspace MCP wrapper | INT-FUT-05 — claude.ai built-in connectors cover it (locked in v5.0 INT-14) |
| Future | Per-MCP scope env-var override (`TK_MCP_SCOPE_supabase=user`) | SCOPE-FUT-01 — defer until friction surfaces |
| Future | TUI `--preset minimal\|full\|dev` with per-preset scope assignments | SCOPE-FUT-02 |
| Future | macOS Keychain / Linux libsecret integration for secrets | SEC-FUT-01 — out of scope for v5.0 (platform-specific dependency surface) |
| Future | 1Password / Vault secret manager detection | SEC-FUT-02 |
| Future | Cursor `.cursorrules` / Aider `CONVENTIONS.md` | BRIDGE-FUT-03/04 (carry-over from v4.8) |
| Deferred | Branding substitution layer for bridge files | BRIDGE-FUT-01 |
| Deferred | Per-CLI tone overlay snippets | BRIDGE-FUT-02 |
| Deferred | `update-claude.sh --bridges-only` mode | BRIDGE-FUT-05 |
| Parallel track | Council Rework | concurrent session |

## Session Continuity

Last session: 2026-05-05T18:10:46.245Z
Started: v5.0 Per-MCP Scope + Project Secrets Boundary
Resume file: None

**Next steps:**

1. ▶ Run `/gsd-plan-phase 36` to begin Phase 36 (Catalog Schema + Backward Compat) — 2 plans, ships SCOPE-01..03 together.
2. After Phase 36 closes, advance through 37 → 38 → 39 → 40 → 41 in order. Phase 39 and Phase 40 may run in parallel after Phase 38 closes (no shared files).
3. Phase 41 is the close phase — manifest 5.0.0 + version-align + CHANGELOG + docs.
