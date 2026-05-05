# Phase 38: Wizard Dispatch Integration - Context

**Gathered:** 2026-05-05
**Status:** Ready for planning
**Mode:** Auto-resolved (decisions locked in REQUIREMENTS.md DISP-01..04 + TEST-02..03)

<domain>
## Phase Boundary

Teach `mcp_wizard_run` (`scripts/lib/mcp.sh:616`) to route per-MCP scope based on `TK_MCP_SCOPE`:

- `TK_MCP_SCOPE=project` — collect keys via existing v4.6 hidden-input prompt loop, write **real values** to `<project>/.env` via `project_secrets_write_env` (Phase 37 lib), ensure `.env` is in `.gitignore` once via `project_secrets_ensure_gitignore`, invoke `claude mcp add --scope project ...` with the env block rendered as `${VAR}` substitution form (NEVER literal values).
- `TK_MCP_SCOPE=user` (or `local`/unset) — preserve v4.6/v4.9 behavior verbatim (write to `~/.claude/mcp-config.env` via `mcp_secrets_set`, invoke `claude mcp add --scope <user|local>` with literal env values exported via `env KEY=V`). Zero regression.
- Defer-secrets path (`TK_MCP_DEFER_SECRETS=1`) extended for project scope: stubs land in `<project>/.env`, `.gitignore` guard runs, the deferred queue tuple grows from 3 fields (name, keys, install_args) to 4 fields (name, keys, install_args, scope) so the post-install summary can print scope-correct edit hints.
- Post-install summary printer in `scripts/install.sh` (line ~801) gains scope-aware blocks: project-scope MCPs print `→ Edit <project>/.env to fill values; ensure .env is in your .gitignore (we appended it).` user-scope MCPs preserve existing copy.

Defense-in-depth: `project_secrets_validate_mcp_env_block` (Phase 37 SEC-05) is called BEFORE every `claude mcp add` invocation in the project-scope branch — refuses literal values in the rendered env block.

Library is the single boundary: this phase owns the **dispatch** layer in `mcp.sh` and the **summary** layer in `install.sh`. The Phase 37 `project-secrets.sh` lib stays untouched.

</domain>

<decisions>
## Implementation Decisions

### Wizard scope routing (DISP-01, DISP-02)

- **D-01:** `mcp_wizard_run` reads `TK_MCP_SCOPE` (already does for the existing `--scope` arg) and branches at the env-var collection step:
  - `_scope == "project"` → project-scope branch (NEW — see D-02..D-08)
  - `_scope == "user"` or `_scope == "local"` or unset → existing flow (preserved verbatim)
- **D-02:** Project-scope branch resolves `project_root` in this order:
  1. `${TK_PROJECT_ROOT:-}` (test seam — hermetic tests pass an absolute mktemp path)
  2. `pwd` (caller's CWD when wizard runs from `install.sh` inside a project)
- **D-03:** Project-scope branch sources `scripts/lib/project-secrets.sh` lazily via `command -v project_secrets_write_env` guard (mirrors mcp.sh's existing `_mcp_validate_value` lazy-source pattern). Sibling-file resolution: same dir as `mcp.sh` per project convention.
- **D-04:** Project-scope branch calls `project_secrets_ensure_gitignore "$project_root"` ONCE before the first `project_secrets_write_env` call. Idempotent — second invocation is a no-op (Phase 37 D-09).
- **D-05:** Project-scope branch collects each env-var via the existing 3-attempt hidden-input loop at `mcp.sh:759-789` (UNCHANGED — this is the v4.6 MCP-04 contract). Only the persistence destination changes:
  - User-scope: `mcp_secrets_set "$env_key" "$collected_value"` (writes to `~/.claude/mcp-config.env`)
  - Project-scope: `project_secrets_write_env "$project_root" "$env_key" "$collected_value"` (writes to `<project>/.env`)
- **D-06:** Project-scope branch builds the env block as a JSON object via `project_secrets_render_mcp_env_block "${env_keys[@]}"` (returns `{"K1":"${K1}","K2":"${K2}"}`). Validates via `project_secrets_validate_mcp_env_block` BEFORE invoking claude. Refusal returns rc=1 immediately — defense-in-depth catch.
- **D-07:** Project-scope `claude mcp add` invocation: `claude mcp add --scope project <install_args> --env-from-json "$env_block"` OR (if claude CLI doesn't accept the `--env-from-json` form) — wizard falls back to passing each `${VAR}` substitution as repeated `--env KEY=${KEY}` args. Planner verifies the exact CLI surface against `claude mcp add --help` output before committing the form. The literal values are NEVER passed to claude — that is the contract.
- **D-08:** Project-scope branch does NOT use the user-scope `env KEY=V claude mcp add ...` exec wrapper. Real values stay in `<project>/.env`; only the `${VAR}` references reach the `.mcp.json` claude writes.

### Defer-secrets extension (DISP-03)

- **D-09:** Defer-secrets path (`TK_MCP_DEFER_SECRETS=1`) gains a scope branch matching the non-deferred logic. When `_scope == "project"`:
  - Stub entries land in `<project>/.env` (NOT `~/.claude/mcp-config.env`)
  - `project_secrets_ensure_gitignore` runs once before the first stub write
  - Stubs use `printf '%s=\n' "$_stub_key"` for empty placeholder values (mirrors mcp.sh:732 user-scope behavior)
- **D-10:** Deferred queue tuple grows from 3 to 4 fields. New format: `name\tkeys\tinstall_args\tscope`. Existing 3-field consumers in `install.sh` (line 833) MUST be updated to read the 4th field; missing-scope rows fall back to `user` (back-compat for any pre-v5.0 rows, though queue is per-run mktemp so no real persistence concern).
- **D-11:** The `"$claude_bin" mcp add "${scoped_args[@]}"` registration call inside the defer branch (mcp.sh:743) preserves existing semantics — `claude mcp add` still runs with no env block when secrets are deferred. The only change is WHERE the stub goes (project `.env` vs `mcp-config.env`).
- **D-12:** Return code semantics unchanged: rc=3 = registered-without-env (still distinct from rc=0/2). Caller `install.sh` reads the 4-field tuple and routes the summary block.

### Post-install summary printer (DISP-04)

- **D-13:** `install.sh:801-870` summary block extended to handle project-scope rows. The 4-field tuple read at line 833 becomes:
  ```bash
  while IFS=$'\t' read -r d_name d_keys d_args d_scope; do
  ```
- **D-14:** Per-row dispatch by `d_scope`:
  - `user` (default) → existing copy (`Open ~/.claude/mcp-config.env ...`)
  - `project` → new copy block:
    ```text
    Some project-scope MCPs need API keys finished:
      1) Open <project>/.env (already stubbed; mode 0600) and fill in:
         KEY=<your-key>
      2) <project>/.gitignore already includes .env (toolkit added it).
      3) Reload shell env from the project dir (or restart claude) and the MCP picks up the keys.
    ```
- **D-15:** Project-scope summary path does NOT touch the user's shell rc (no `~/.zshrc` modification). Project `.env` is sourced from the project directory by claude (or by the user's direnv/project tooling) — toolkit does not own that loading boundary.
- **D-16:** When BOTH scopes are present in the same install run, summary prints a `User-scope MCPs:` block followed by a `Project-scope MCPs:` block. Each block lists only its own rows.

### Tests (TEST-02, TEST-03)

- **D-17:** Extend `scripts/tests/test-mcp-wizard.sh` (current PASS=14) by ≥6 assertions:
  - DISP-01 happy path: `TK_MCP_SCOPE=project TK_PROJECT_ROOT=$mktemp_dir mcp_wizard_run <name>` → keys land in `<project>/.env` (mode 0600), `.gitignore` updated, `.mcp.json` env block uses `${VAR}` form (or claude CLI args carry `${VAR}`), `mcp-config.env` UNTOUCHED (negative assertion via filesystem fingerprint).
  - DISP-02 no regression: `TK_MCP_SCOPE=user mcp_wizard_run <name>` → keys land in `mcp-config.env`, `<project>/.env` UNTOUCHED.
  - DISP-03 defer-secrets project: `TK_MCP_SCOPE=project TK_MCP_DEFER_SECRETS=1 mcp_wizard_run <name>` → blank stubs in `<project>/.env`, queue tuple has 4 fields, scope == `project`.
  - Defense-in-depth: project-scope flow with literal value injected into env block via mocking → wizard returns rc=1 with `refusing to write literal value` stderr (already covered by Phase 37 lib, but exercise the wizard call site here).
- **D-18:** TEST-03 SEC-06 shared-validator scenarios: `_mcp_validate_value` already shared between mcp.sh + project-secrets.sh (Phase 37 D-16 reuse). Verify `test-mcp-secrets.sh` (PASS=11) still green. NO refactor needed — phase 37 closed the shared boundary. Mark TEST-03 as "shared validator boundary preserved; no new file changes" in summary.
- **D-19:** Test seams: `TK_MCP_TTY_SRC` (existing — collision prompts), `TK_MCP_CLAUDE_BIN` (existing — fakes claude binary), `TK_PROJECT_ROOT` (NEW — overrides `pwd` for project-scope dispatch). All hermetic via `mktemp -d`.
- **D-20:** Mocking the claude binary: continue using the existing `TK_MCP_CLAUDE_BIN=/path/to/fake-claude` pattern. The fake script captures `--scope`, `--env`, install_args into a tracking file the test reads back. Mirrors v4.6 test-mcp-wizard.sh harness.

### Claude's Discretion

- Exact claude CLI surface for project-scope env block (`--env KEY=${KEY}` repeated vs `--env-from-json` vs heredoc) — planner picks based on `claude mcp add --help` output. The contract is "no literal value reaches `.mcp.json`"; the form is implementation detail.
- Whether the project-scope branch gets a new helper function (`_mcp_wizard_project_scope_run`) or inlines the new logic into `mcp_wizard_run` — reviewer's call. Keep `mcp_wizard_run` under ~250 LOC; if the inlined branch pushes past, extract.
- Where the 4-tuple migration lands — bump the tuple in mcp.sh writer + install.sh reader in the same plan/commit (no schema-without-reader window, mirror Phase 36 D-10 backward-compat invariant).
- Test file split: extend `test-mcp-wizard.sh` (preferred — same harness) vs new `test-mcp-wizard-scope.sh`. Default: extend, drop only if assertions exceed 30 (current would land ~20).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §"Wizard dispatch update" — DISP-01..04 acceptance criteria
- `.planning/REQUIREMENTS.md` §"Tests" — TEST-02 (test-mcp-wizard.sh extension), TEST-03 (test-mcp-secrets.sh boundary preservation)

### Existing code (read before editing)
- `scripts/lib/mcp.sh` — `mcp_wizard_run` at line 616 (the function to extend); existing `TK_MCP_SCOPE` argv path at line 674; defer-secrets path at line 695
- `scripts/lib/project-secrets.sh` — Phase 37 lib; the four functions consumed: `project_secrets_write_env`, `project_secrets_ensure_gitignore`, `project_secrets_render_mcp_env_block`, `project_secrets_validate_mcp_env_block`
- `scripts/install.sh:487-501` — TK_MCP_DEFERRED_QUEUE setup
- `scripts/install.sh:801-870` — post-install summary printer (the 4-tuple consumer)
- `scripts/tests/test-mcp-wizard.sh` (PASS=14) — extension target for TEST-02
- `scripts/tests/test-mcp-secrets.sh` (PASS=11) — must stay green per TEST-03

### Project conventions
- `.planning/codebase/CONVENTIONS.md` — bash style, hermetic test patterns
- `.planning/codebase/STACK.md` — Bash 3.2 compat invariants
- `.planning/PROJECT.md` — toolkit non-negotiables
- `CLAUDE.md` — quality gate, commit conventions

### Phase 37 outputs (consumed by this phase)
- `.planning/phases/37-project-secrets-library/37-01-secrets-lib-SUMMARY.md` — exact function signatures, stderr phrases, return codes
- `.planning/phases/37-project-secrets-library/37-02-test-contract-SUMMARY.md` — test seam patterns to mirror
- `.planning/phases/37-project-secrets-library/37-VERIFICATION.md` — confirms Phase 37 boundary is locked

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (Phase 37 + earlier)
- `project_secrets_write_env` (`scripts/lib/project-secrets.sh:116`) — writes `KEY=value` to `<project>/.env` mode 0600 with idempotent merge + collision prompt
- `project_secrets_ensure_gitignore` (`scripts/lib/project-secrets.sh:188`) — `.env` line guard, idempotent
- `project_secrets_render_mcp_env_block` (`scripts/lib/project-secrets.sh:228`) — JSON `${VAR}` form
- `project_secrets_validate_mcp_env_block` (`scripts/lib/project-secrets.sh:268`) — defense-in-depth literal refusal (rc=1 on parse error per Phase 37 MED-01 fix)
- `mcp_secrets_set` (`scripts/lib/mcp.sh:511`) — user-scope writer, UNCHANGED
- `tui_tty_read` (`scripts/lib/tui.sh`) — TTY prompt with TK_MCP_TTY_SRC seam
- `_mcp_validate_value` (`scripts/lib/mcp.sh:431`) — shared across both libs (Phase 37 D-16)

### Established Patterns
- Lazy `command -v <fn> >/dev/null 2>&1 || source <sibling>` for cross-lib reuse without load-time side effects
- Test seams: env vars prefixed `TK_MCP_*` for the wizard, `TK_PROJECT_*` reserved for project-scope work
- Hermetic test scaffold: `mktemp -d`, trap cleanup, fake claude binary via `TK_MCP_CLAUDE_BIN`
- Stderr message contract: red `✗` for refusals, yellow `!` for non-fatal warnings — exact phrases form the test grep contracts

### Integration Points
- Phase 39 (TUI per-row scope toggle) consumes `TK_MCP_SCOPE` per-row export — depends on this phase's wizard contract being scope-aware. The TUI dispatcher will export `TK_MCP_SCOPE` per row before invoking `mcp_wizard_run`, exercising the branch this phase ships.
- Phase 40 (uninstall secret cleanup) reads the keys catalog (`integrations-catalog.json env_var_keys`) to know what to prompt-remove. The wizard does not change that catalog surface.
- Phase 41 (distribution) does not modify mcp.sh; it only bumps manifest.json + plugin.json + CHANGELOG.

</code_context>

<specifics>
## Specific Ideas

- Project-scope is the riskier branch — every byte that reaches `.mcp.json` MUST be a `${VAR}` reference, never a literal. The wizard MUST `validate_mcp_env_block` before any `claude mcp add` call in this branch. Even if the validate step is redundant with the lib's own SEC-05 check during render, the second check at the call site is the defense-in-depth contract.
- The defer-secrets queue tuple growing from 3 fields to 4 must land in the SAME commit as the install.sh reader update — no schema-without-reader window. The queue file is per-run mktemp so there is no on-disk persistence to migrate, but in-flight install runs must not see a 4-field write next to a 3-field read.
- Test fakes for the claude binary should record `--scope` and the env block separately so DISP-01/02 negative-presence assertions ("user-scope `${VAR}` form NEVER appears in args" and inverse) are programmatic, not heuristic.
- Bash 3.2 invariants apply (no associative arrays for the scope→hint map; case statement is the substitute).

</specifics>

<deferred>
## Deferred Ideas

- TUI per-row scope toggle (TUI-SCOPE-01..05) — Phase 39
- Uninstall secret-cleanup prompts (UN-SEC-01..05) + Calendly + validator SCOPE-01 assertion — Phase 40
- Documentation updates (INTEGRATIONS.md Per-MCP Scope section, INSTALL.md flag rows for any new CLI flags) — Phase 41
- CHANGELOG `[5.0.0]` consolidated entry — Phase 41
- `--mcp-scope=user|project` non-interactive force CLI flag — out of scope unless DISP-01 unfolds to require it (the per-call `TK_MCP_SCOPE` env var honored on the CLI is sufficient for now). Document as Future REQ if it surfaces in planning.
- `SCOPE-FUT-01` per-MCP env-var override (`TK_MCP_SCOPE_supabase=user`) — REQUIREMENTS.md Future, defer until friction surfaces.

</deferred>

---

*Phase: 38-wizard-dispatch-integration*
*Context gathered: 2026-05-05*
