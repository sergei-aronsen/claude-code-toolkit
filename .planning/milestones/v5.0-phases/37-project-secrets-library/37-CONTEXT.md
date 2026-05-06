# Phase 37: Project Secrets Library - Context

**Gathered:** 2026-05-04
**Status:** Ready for planning
**Mode:** Auto-resolved (decisions locked in REQUIREMENTS.md SEC-01..06 + TEST-01)

<domain>
## Phase Boundary

Ship a new `scripts/lib/project-secrets.sh` library that owns the project-scope secrets boundary end-to-end and ships together with its hermetic test suite. The library writes `KEY=value` to `<project>/.env` (mode 0600, idempotent merge with collision prompt), guarantees `.env` is in `<project>/.gitignore` (appends with leading comment if missing), renders `${VAR}` substitution form for `.mcp.json` env blocks, refuses any literal secret in `.mcp.json` env blocks (defense-in-depth), and rejects shell-metacharacter values. Library is scope-agnostic; its callers in Phase 38 will branch on scope. The lib is meaningless without its test surface — TEST-01 is the contract that locks the secrets boundary, so the lib and its tests ship in the same plan/commit.

</domain>

<decisions>
## Implementation Decisions

### Public API (SEC-01)
- **D-01:** Library exports exactly four functions:
  - `project_secrets_write_env <project_root> <KEY> <VALUE>`
  - `project_secrets_ensure_gitignore <project_root>`
  - `project_secrets_render_mcp_env_block <KEY...>`
  - `project_secrets_validate_mcp_env_block <json_string>` (SEC-05 enforcer; callable by both this lib and the wizard)
- **D-02:** Sourcing the library is a pure no-op (function definitions only). Read-only callers may `source` it for the validate helper without side effects.
- **D-03:** All public function names use the `project_secrets_*` prefix; private helpers use `_project_secrets_*` (mirrors `mcp_*` / `_mcp_*` convention in `scripts/lib/mcp.sh`).

### Env writer (SEC-02)
- **D-04:** Order of operations mirrors `mcp_secrets_set` (`scripts/lib/mcp.sh:511`):
  1. `mkdir -p <project_root>` (caller-supplied path; do not create paths above it)
  2. `touch <project_root>/.env`
  3. `chmod 0600 <project_root>/.env` BEFORE first write
  4. Load existing entries (re-use `mcp_secrets_load`-style line-parser, scoped to `.env`)
  5. On collision: prompt `[y/N] Overwrite KEY in <project>/.env?` via `tui_tty_read` with `TK_MCP_TTY_SRC` test seam (fail-closed N)
  6. On Y: rewrite file in place via `mktemp` + `mv`; preserve key order
  7. On N or absent collision: append-only
  8. `chmod 0600` again (idempotent — defends against umask widening on rewrite)
- **D-05:** Reuse the existing TTY contract from `mcp_secrets_set`: `TK_MCP_TTY_SRC` env var picks the TTY source; default `/dev/tty`; fail-closed N when the source cannot be read.
- **D-06:** `<project_root>` argument MUST be an absolute path or a path that exists. The library does not normalize via `realpath`/`readlink -f` (BSD vs GNU divergence). Caller is responsible for resolution.

### Gitignore guard (SEC-03)
- **D-07:** `project_secrets_ensure_gitignore` checks `<project_root>/.gitignore` for an exact `.env` line via `grep -Fxq '.env'` (exact-fixed-line — rejects `*.env`, `# .env`, `.env.local`).
- **D-08:** When absent: append a two-line block — first the comment `# claude-code-toolkit: never commit project-scope MCP secrets`, then `.env`. Includes a leading blank line if the file already has content and does not end in a blank line (avoids `MD-style` "no trailing blank" pollution).
- **D-09:** Creates `<project_root>/.gitignore` if missing (mode 0644). Idempotent on re-run — second invocation finds the line and is a no-op.

### MCP env block rendering (SEC-04)
- **D-10:** `project_secrets_render_mcp_env_block KEY1 KEY2 ...` echoes a JSON object string `{"KEY1":"${KEY1}","KEY2":"${KEY2}"}` to stdout. No trailing newline (caller pipes it directly into a JSON-aware tool).
- **D-11:** Empty arg list → echoes `{}` and returns 0.
- **D-12:** Each key is validated against `^[A-Z_][A-Z0-9_]*$` (matches `mcp_secrets_load` line 474 contract) before rendering. Invalid key → return 1 with `✗ project_secrets_render_mcp_env_block: invalid key '<k>'` to stderr.

### Defense-in-depth literal-secret refusal (SEC-05)
- **D-13:** `project_secrets_validate_mcp_env_block <json_string>` parses the input via `jq -r '.[] | tostring'` and rejects any value that does not match the regex `^\$\{[A-Z_][A-Z0-9_]*\}$`.
- **D-14:** Refusal returns rc=1 with `✗ refusing to write literal value into .mcp.json (use ${VAR} substitution)` to stderr. Phase 38 wizard will call this helper before passing the env block to `claude mcp add` (or, when Claude CLI writes `.mcp.json`, on a post-write verification of the file).
- **D-15:** Test seam `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` bypasses the regex check and emits a one-line warning `⚠ project_secrets: literal value allowed via TK_PROJECT_SECRETS_ALLOW_LITERAL — test seam only` to stderr. Documented in code comment as test-only.

### Metacharacter rejection (SEC-06)
- **D-16:** Reuse `_mcp_validate_value` from `scripts/lib/mcp.sh` rather than duplicating the regex. Source mcp.sh at the top of `project-secrets.sh` (the file already lives in `scripts/lib/` and is `source`-safe).
- **D-17:** Rejected on the same set: `$`, backtick, backslash, double-quote, single-quote, newline. `project_secrets_write_env` returns 1 with `✗ project_secrets_write_env: value for <KEY> contains shell metacharacters — refusing to write` to stderr on rejection.

### Test contract (TEST-01)
- **D-18:** New test file: `scripts/tests/test-project-secrets.sh`. Hermetic + idempotent + double-run-safe (mirrors v4.6 test conventions). PASS floor ≥ 18.
- **D-19:** Test seams: `TK_MCP_TTY_SRC` for collision-prompt branches; `TK_PROJECT_SECRETS_ALLOW_LITERAL` for the SEC-05 bypass test.
- **D-20:** Synthetic project root via `mktemp -d`. No real `$HOME` mutation. Cleanup trap removes temp dirs on exit.
- **D-21:** Wired into `Makefile` test target list and `.github/workflows/quality.yml` `Tests 21-XX` step (extends the existing range; planning decides exact number based on current test count).

### Claude's Discretion
- Internal helper naming for the env-file line-rewriter (re-use `mcp_secrets_*` shape if helpful, or roll a private `_project_secrets_load_env` parser).
- Whether `project_secrets_render_mcp_env_block` accepts repeated keys (probably yes — `jq` will collapse duplicates anyway). Document in the function header.
- jq-vs-printf for the JSON object rendering (jq is the canonical project pattern; verify no escaping pitfalls for the literal `${...}` substring before committing).
- Commit shape: single atomic commit `feat(37): scripts/lib/project-secrets.sh + test-project-secrets.sh + Makefile/CI wiring` OR a 2-commit split `feat(lib)` + `test(suite)` — planner picks whichever passes `make check` cleanly at every commit.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §"Project secrets writer" — SEC-01..SEC-06 acceptance criteria
- `.planning/REQUIREMENTS.md` §"Tests" — TEST-01 ≥18-assertion hermetic test contract
- `.planning/REQUIREMENTS.md` Traceability table — confirms SEC-01..06 + TEST-01 are owned by Phase 37

### Existing code (read before editing)
- `scripts/lib/mcp.sh` — model implementation: `_mcp_validate_value` (line 431), `mcp_secrets_set` collision flow (line 511), `mcp_secrets_load` line-parser (line 448). REUSE `_mcp_validate_value` per D-16.
- `scripts/lib/tui.sh::tui_tty_read` — TTY prompt helper used by `mcp_secrets_set`; reuse for collision prompt per D-05.
- `scripts/tests/test-mcp-secrets.sh` (current PASS=11) — closest hermetic test analog. Pattern source for SEC-02/SEC-06 assertions.
- `scripts/tests/test-mcp-wizard.sh` (current PASS=14) — `TK_MCP_TTY_SRC` test seam usage.
- `Makefile` — test target wiring; mirror existing `test-mcp-*` row.
- `.github/workflows/quality.yml` — `Tests 21-30` step (currently). Extend the range cap.

### Project conventions
- `.planning/codebase/CONVENTIONS.md` — bash style, hermetic test patterns, `set -euo pipefail` invariant
- `.planning/codebase/STACK.md` — Bash 3.2 compat, BSD vs GNU caveats (no `realpath -f`, no `mapfile`, no associative arrays)
- `.planning/PROJECT.md` — toolkit non-negotiables (POSIX shell, idempotent installs, never delete user files without confirmation)
- `CLAUDE.md` (project root) — quality gate (`make check`), Conventional Commits

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_mcp_validate_value` (`scripts/lib/mcp.sh:431`) — exact metacharacter rule. Reuse via `source` per D-16, do NOT duplicate.
- `tui_tty_read` (`scripts/lib/tui.sh`) — prompt helper with `TK_MCP_TTY_SRC` seam. Reuse for collision flow per D-05.
- `mcp_secrets_set` (`scripts/lib/mcp.sh:511`) — order-of-operations template (touch → chmod 0600 → load → prompt-on-collision → mktemp+mv rewrite → chmod 0600 again).
- `mcp_secrets_load` (`scripts/lib/mcp.sh:448`) — line parser pattern (skip `#`-comment + blank, require `KEY=value`, validate key shape via `^[A-Z_][A-Z0-9_]*$`).

### Established Patterns
- Library files at `scripts/lib/*.sh` are `source`-safe — no side effects at load time, only function definitions.
- Hermetic tests use `mktemp -d`, no `$HOME` mutation, trap-cleanup, idempotent + double-run-safe.
- TTY prompts use `TK_MCP_TTY_SRC` seam → `/dev/tty` default → fail-closed N.
- File-mode invariant: `chmod 0600` before any write AND after any rewrite (defends umask widening).
- JSON outputs use `jq` (project canonical) — match prevailing form rather than rolling printf-based JSON.

### Integration Points
- Phase 38 (`mcp_wizard_run`) is the primary consumer: calls `project_secrets_write_env` per key, `project_secrets_ensure_gitignore` once before the first write, `project_secrets_render_mcp_env_block` for `claude mcp add ... env`, and `project_secrets_validate_mcp_env_block` as defense-in-depth before/after CLI invocation.
- Phase 40 (uninstall UN-SEC-04) verifies the **negative** contract: project `.env` files are never opened by `uninstall.sh`. The library's existence does not change uninstall behavior.
- Phase 41 docs (DOCS-01) document the lib's contract surface in `docs/INTEGRATIONS.md`.

</code_context>

<specifics>
## Specific Ideas

- "The library lands together with its hermetic test suite" — explicit invariant from ROADMAP.md goal. SEC-01..06 and TEST-01 ship in the same phase; planner may split into 2 commits if it keeps `make check` green at each commit, but they cannot ship in different phases.
- Reusing `_mcp_validate_value` (D-16) over duplicating the regex is the correct boundary: SEC-06 explicitly says "Reuses or refactors the existing helper to share the rule."
- Silent fallbacks deliberately avoided in this phase — every refusal (literal secret, metacharacter, invalid key) emits a red `✗` line to stderr. The lib is the secrets boundary; loud refusal is the contract.
- The `${VAR}` substitution form is a Claude Code convention — `claude` resolves the var from the environment at MCP launch when reading `.mcp.json`. The lib produces this form; Phase 38 wires it into `claude mcp add`.

</specifics>

<deferred>
## Deferred Ideas

- Wizard scope routing on `TK_MCP_SCOPE=project` (DISP-01..04) — Phase 38.
- TUI per-row scope toggle (TUI-SCOPE-01..05) — Phase 39.
- Calendly catalog entry (INT-13) — Phase 40.
- Uninstall negative-contract test that proves no project `.env` is opened (UN-SEC-04) — Phase 40.
- Documentation updates (INTEGRATIONS.md, INSTALL.md, UNINSTALL.md) — Phase 41.
- CHANGELOG `[5.0.0]` consolidated entry — Phase 41.
- Manifest version bump to `5.0.0` (DIST-01..02) — Phase 41.

</deferred>

---

*Phase: 37-project-secrets-library*
*Context gathered: 2026-05-04*
