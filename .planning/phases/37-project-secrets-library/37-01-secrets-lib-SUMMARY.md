---
phase: 37
plan: 01
subsystem: project-secrets
tags: [secrets, library, project-scope, mcp, sec-01, sec-02, sec-03, sec-04, sec-05, sec-06]
requires:
  - scripts/lib/mcp.sh::_mcp_validate_value
  - scripts/lib/tui.sh::tui_tty_read
provides:
  - scripts/lib/project-secrets.sh::project_secrets_write_env
  - scripts/lib/project-secrets.sh::project_secrets_ensure_gitignore
  - scripts/lib/project-secrets.sh::project_secrets_render_mcp_env_block
  - scripts/lib/project-secrets.sh::project_secrets_validate_mcp_env_block
affects:
  - phase 38 (mcp_wizard_run scope routing — primary consumer)
  - phase 40 (uninstall negative-contract — verifies project .env never opened)
tech-stack:
  added: []
  patterns:
    - "Source-safe library (no errexit, function definitions only)"
    - "Lazy `command -v` source guard for sibling lib reuse"
    - "Parallel arrays + linear index lookup (Bash 3.2 invariant)"
    - "mktemp + mv atomic rewrite with chmod-after defense"
    - "jq -nc --args for compact JSON object construction"
    - "grep -Fxq for exact-fixed-line POSIX-portable .gitignore match"
key-files:
  created:
    - scripts/lib/project-secrets.sh
  modified: []
decisions:
  - "Reused _mcp_validate_value from mcp.sh via lazy source guard (D-16) — single regex, both write paths share it"
  - "Reused TK_MCP_TTY_SRC seam (D-05) — no new TTY env-var coined"
  - "New test seam TK_PROJECT_SECRETS_ALLOW_LITERAL emits a loud YELLOW ⚠ warning on every honored use (D-15)"
  - "Private helpers use _PROJECT_SECRETS_KEYS[]/_PROJECT_SECRETS_VALUES[] arrays (D-03 namespace) — zero collision with MCP_SECRET_* in callers that source both libs"
  - "Audit L1 key guard ^[A-Z_][A-Z0-9_]*$ preserved verbatim from mcp.sh:474 in _project_secrets_load_env"
metrics:
  duration: ~12 minutes
  completed: 2026-05-05T16:05:03Z
  tasks_completed: 1
  files_created: 1
  files_modified: 0
  commits: 1
---

# Phase 37 Plan 01: Project Secrets Library Summary

**One-liner:** New source-safe library `scripts/lib/project-secrets.sh` ships four functions that own the project-scope secrets boundary — write `KEY=VALUE` to `<project>/.env` (mode 0600, idempotent merge with collision prompt), guarantee `.env` in `.gitignore`, render `${VAR}` substitution form for `.mcp.json`, and refuse literal secrets in `.mcp.json` env blocks (defense in depth).

## Output

Created exactly one file: `scripts/lib/project-secrets.sh` (286 lines). Sourcing produces zero filesystem side effects (function definitions only). All four public functions and two private helpers compile and shellcheck cleanly at `-S warning`.

## Public API Surface (4 functions)

| Function | REQ | Behavior |
|---|---|---|
| `project_secrets_write_env <root> <KEY> <VALUE>` | SEC-01, SEC-02, SEC-06 | 8-step order-of-operations from D-04. Reuses `_mcp_validate_value` for metacharacter rejection. Collision prompt via `tui_tty_read` + `TK_MCP_TTY_SRC` seam, fail-closed N. mktemp+mv rewrite with chmod 0600 before AND after. |
| `project_secrets_ensure_gitignore <root>` | SEC-03 | `grep -Fxq '.env'` exact-fixed-line check (D-07 — rejects `*.env`, `# .env`, `.env.local`). Creates `.gitignore` mode 0644 if absent (D-09). Leading-newline fix-up when content lacks trailing `\n` (D-08). Idempotent. |
| `project_secrets_render_mcp_env_block KEY1 KEY2 ...` | SEC-04 | Empty args → `{}` (D-11, no trailing newline). Each key validated `^[A-Z_][A-Z0-9_]*$` (D-12). Renders via `jq -nc --args`. |
| `project_secrets_validate_mcp_env_block <json>` | SEC-05 | Streams `jq -r '.[] | tostring'` into `while read` loop. Regex tests each value against `^\$\{[A-Z_][A-Z0-9_]*\}$` (D-13). Refusal stderr: `✗ refusing to write literal value into .mcp.json (use ${VAR} substitution)` (D-14). `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` bypass with loud warning (D-15). |

## Private Helpers (2)

- `_project_secrets_load_env <env_path>` — copy of `mcp_secrets_load` line parser populating `_PROJECT_SECRETS_KEYS[]`/`_PROJECT_SECRETS_VALUES[]`. Audit L1 key-guard `^[A-Z_][A-Z0-9_]*$` preserved verbatim.
- `_project_secrets_index <key>` — linear-scan index lookup, mirrors `_mcp_secrets_index`.

## Reused Contracts

- **`_mcp_validate_value` (mcp.sh:431)** — sourced via lazy guard `command -v _mcp_validate_value`. The metacharacter regex (`$`, backtick, backslash, double-quote, single-quote, newline) is NOT duplicated — single source of truth. A future regression in either codepath is caught by both `mcp_secrets_set` and `project_secrets_write_env` test surfaces.
- **`tui_tty_read` (tui.sh:481)** — picked up transitively via `mcp.sh`'s own lazy source guard (mcp.sh:69-75). Used for the `[y/N] Overwrite KEY in <root>/.env?` collision prompt.
- **`TK_MCP_TTY_SRC`** — REUSED per D-05; no new TTY seam coined. Tests in plan 37-02 mock the same env var that already mocks `mcp_secrets_set` collisions.

## Test Seams

| Seam | Disposition | Purpose |
|------|-------------|---------|
| `TK_MCP_TTY_SRC` | **Reused** (D-05) | TTY source for collision prompt — single seam contract across the toolkit. |
| `TK_PROJECT_SECRETS_ALLOW_LITERAL` | **New** (D-15) | Bypass SEC-05 literal refusal in tests. Documented as test-only in code comment. Loud `⚠ test seam only` warning on every honored use. |

Note: `TK_MCP_CONFIG_HOME` is **not** referenced by this lib — project root is passed explicitly per D-06. Setting it in tests would mask a regression where the lib accidentally writes outside `<project>/.env`.

## Verification Performed

All 15 task-level automated checks (`<verify><automated>` block from plan) passed:

1. Four public functions defined at top level ✓
2. Two private helpers defined ✓
3. `command -v _mcp_validate_value` lazy-source guard present ✓
4. No `set -e`/`set -u` at top (sourced-lib invariant) ✓
5. SEC-05 exact phrase `refusing to write literal value into .mcp.json` ✓
6. SEC-06 phrase `shell metacharacters` ✓
7. SEC-03 gitignore comment phrase ✓
8. `TK_PROJECT_SECRETS_ALLOW_LITERAL` test seam present ✓
9. `TK_MCP_TTY_SRC` reused (no new seam) ✓
10. `shellcheck -S warning` clean ✓
11. Sourcing produces no filesystem side effects ✓

Manual smoke tests (from `<verification>` block):

- `project_secrets_render_mcp_env_block` (no args) → `{}` ✓
- `project_secrets_render_mcp_env_block FOO BAR` → `{"FOO":"${FOO}","BAR":"${BAR}"}` ✓
- `project_secrets_validate_mcp_env_block '{"K":"${K}"}'` → rc=0 ✓
- `project_secrets_validate_mcp_env_block '{"K":"literal"}'` → rc=1 ✓

Additional functional smoke tests:

- `$` value rejected with correct stderr message ✓
- Backtick value rejected ✓
- Happy-path `KEY=VALUE` lands in `.env` ✓
- New `.env` is mode 0600 (BSD `stat -f` + GNU `stat -c` dual-check) ✓
- `.gitignore` gets `.env` line + comment ✓
- Idempotent: second `project_secrets_ensure_gitignore` call is a no-op (line appears exactly once) ✓
- D-07 invariant: pre-seeded `*.env` does NOT match — lib still appends `.env` ✓
- D-07 invariant: pre-seeded `# .env` (comment) does NOT match — lib still appends `.env` ✓
- D-08 invariant: file without trailing newline gets a `\n` before the block ✓
- `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` bypass returns rc=0 with `test seam only` warning ✓
- Invalid key (lowercase) in render → rc=1 with `invalid key` stderr message ✓

`make shellcheck` quality gate: green.

## Threat Model Mitigations

| Threat ID | Status | Mitigation |
|---|---|---|
| T-37-01 (literal secret in `.mcp.json`) | mitigated | `project_secrets_validate_mcp_env_block` regex-tests every JSON value; rc=1 + stderr refusal on any non-`${VAR}` form. |
| T-37-02 (`.env` committed to repo) | mitigated | `project_secrets_ensure_gitignore` enforces `^.env$` exact match before any `.env` write; idempotent on re-run. |
| T-37-03 (shell metacharacters in `.env`) | mitigated | `project_secrets_write_env` reuses `_mcp_validate_value` (D-16) — single regex shared with `mcp_secrets_set`. |
| T-37-04 (world-readable `.env`) | mitigated | `chmod 0600` applied BEFORE first byte (step 3) AND AFTER any rewrite (step 7). |
| T-37-05 (test seam abuse) | mitigated | `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` emits loud `⚠ test seam only` warning to stderr on every honored use. |
| T-37-06 (`_PROJECT_SECRETS_*` array collision) | mitigated | Private namespace prefix `_PROJECT_SECRETS_*` (D-03); no overlap with `MCP_SECRET_*` arrays in callers that source both libs. |

## Deviations from Plan

None — plan executed exactly as written. Locked decisions D-01 through D-17 honored verbatim. All exact-phrase stderr contracts (D-13, D-14, D-15, D-17) match the strings the plan-37-02 test suite will grep for.

## Deferred Items

- **Plan 37-02:** hermetic test suite (`scripts/tests/test-project-secrets.sh`, ≥18 PASS), Makefile wiring (`Test 49`), CI quality.yml range bump (Tests 35-43 → 35-49). Tests for SEC-01..06 contracts ship there.
- **Phase 41 / DIST-01:** `manifest.json` `files.libs[]` insertion at alpha order between `optional-plugins.sh` and `skills.sh` (per PATTERNS.md §`manifest.json` and ROADMAP DIST-01). Not Phase 37's job.

## Self-Check: PASSED

- File `scripts/lib/project-secrets.sh` exists (286 lines).
- Commit will be created in the next step (commit hash recorded after).

## Threat Flags

None. The new surface is contained to a single sourced library exposing four functions; no new network endpoints, no new auth paths, no new file access patterns outside the documented `<project>/.env` and `<project>/.gitignore` writes.
