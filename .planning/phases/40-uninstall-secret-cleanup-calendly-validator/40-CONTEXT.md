---
phase: 40-uninstall-secret-cleanup-calendly-validator
created: 2026-05-05T00:00:00Z
mode: auto-resolved
source: REQUIREMENTS.md success criteria + ROADMAP.md Phase 40 entry
requirements:
  - UN-SEC-01
  - UN-SEC-02
  - UN-SEC-03
  - UN-SEC-04
  - UN-SEC-05
  - INT-13
  - INT-14
  - TEST-05
  - TEST-06
---

# Phase 40 — Uninstall Secret Cleanup + Calendly + Validator — CONTEXT

## Goal

Close the secrets-leak gap on uninstall. Removing a single MCP triggers a `[y/N] also remove keys K1, K2 from ~/.claude/mcp-config.env?` prompt (default N, fail-closed N on no-TTY). Full toolkit uninstall asks once about the entire `mcp-config.env`. Project `.env` files are **never** touched. `--keep-state` (v4.4 KEEP-01) implies `--keep-secrets`. Add Calendly to the catalog as an official MCP. Explicitly NOT add a Google Workspace MCP — claude.ai's built-in Gmail/Calendar/Drive connectors cover that surface (decision logged). Catalog validator gains a SCOPE-01 assertion. Uninstall test suite extended.

## Locked decisions

### Section 1 — Uninstall secret cleanup (UN-SEC-01..05)

**D-01 (UN-SEC-01) — Single-MCP key cleanup helper signature & location.**
New helper `uninstall_prompt_mcp_keys <name> <key1> <key2>...` lives in `scripts/uninstall.sh` (NOT a new lib file — it's uninstall-only logic; sibling functions `prompt_modified_for_uninstall`, etc. all live in-script). Reads keys for the named MCP from `integrations-catalog.json`'s `env_var_keys` field. Prompts via `< /dev/tty` per UN-03 contract (mirrors `prompt_modified_for_uninstall:300+`). Default N. Fail-closed N on no-TTY (matches v4.3 UN-03 invariant).

**D-02 (UN-SEC-01) — Rewrite path for single-MCP cleanup.**
On Y: rewrite `~/.claude/mcp-config.env` excluding ONLY the named MCP's keys (other MCPs' entries preserved). Mode 0600 preserved before AND after rewrite (mirrors `mcp_secrets_set:525-526` and Phase 37 `project_secrets_write_env` 4-step write→mv→chmod pattern). Use `mktemp` + `mv` for atomic replace. Idempotent on repeat run (key already absent → no-op).

**D-03 (UN-SEC-01) — Source of key list per MCP.**
Read `env_var_keys` array from `integrations-catalog.json` for the named MCP (already present in catalog per Phase 36/38 schema). Defensive: if `env_var_keys` is empty/missing for an entry (e.g., OAuth-only MCP like Calendly), helper exits cleanly with no prompt (zero keys to remove). Use `jq` (already required dep per CLAUDE.md tech stack).

**D-04 (UN-SEC-02) — Call-site for `uninstall_prompt_mcp_keys`.**
Phase 40 wires the helper at the existing toolkit-driven `claude mcp remove <name>` invocation site(s) in `uninstall.sh`. Currently `uninstall.sh` does NOT call `claude mcp remove` at all (verified — `grep -ni mcp scripts/uninstall.sh` returns 0 matches). Decision: Phase 40 adds the FIRST `claude mcp remove` loop in uninstall.sh, iterating over MCPs that the user installed via toolkit (recovered from `~/.claude/toolkit-install.json` state if present, else recovered from `claude mcp list` parse). Per-MCP loop: `claude mcp remove <name> --scope user` first, then `uninstall_prompt_mcp_keys <name> <key1>...`. Skip silently when state file absent (graceful degradation per v4.4 LIB-01 D-09).

**D-05 (UN-SEC-03) — Full-toolkit `mcp-config.env` cleanup prompt.**
Single prompt at the end of the MCP loop: `[y/N] also remove ~/.claude/mcp-config.env (X keys for Y MCPs)?` where X = total key count remaining, Y = total MCP count remaining (computed by counting `MCP_*` blocks via `mcp_secrets_load` then summing). Default N. Fail-closed N on no-TTY. On Y: `rm -f ~/.claude/mcp-config.env` BEFORE the LAST-step `STATE_FILE` removal (UN-05 D-06 ordering preserved; STATE_FILE remains LAST). Skip the prompt entirely when `mcp-config.env` does not exist.

**D-06 (UN-SEC-04) — Project `.env` negative invariant.**
Hard contract: `uninstall.sh` NEVER opens any `.env` file outside `~/.claude/`. Implementation is the absence of any `find` / `fopen` / `read -r` call against `<project>/.env` or `**/.env` paths. Verified by hermetic test (D-12 below) using filesystem fingerprint diff (mtime + sha256 snapshot of any `*.env` under sandbox `$HOME` excluding `~/.claude/` BEFORE uninstall and AFTER — must be byte-identical).

**D-07 (UN-SEC-05) — `--keep-state` implies `--keep-secrets`.**
Existing `--keep-state` flag (v4.4 KEEP-01) gates state-file removal at `uninstall.sh:824+`. Phase 40 extends the same gate to ALL secret removal paths: `uninstall_prompt_mcp_keys` and the full `mcp-config.env` prompt are SKIPPED entirely when `KEEP_STATE=1`. Same env-var contract: `TK_UNINSTALL_KEEP_STATE=1` triggers the same skip. No new `--keep-secrets` flag in v5.0 (defer to a future explicit override; YAGNI per CLAUDE.md). `--help` text updated to document the implication; `docs/INSTALL.md` (or new `docs/UNINSTALL.md` per Phase 41 D-3) carries the full contract.

**D-08 — Dry-run integration.**
Existing `--dry-run` mode (v4.3) prints "would remove" lines without filesystem writes. Phase 40 extends: under `--dry-run`, `uninstall_prompt_mcp_keys` and the full-toolkit prompt SKIP the prompt and SKIP the rewrite/rm. They print `[dry-run] would prompt: also remove keys K1, K2 from mcp-config.env?` and `[dry-run] would prompt: also remove ~/.claude/mcp-config.env?` instead. No prompts under dry-run (matches v4.3 dry-run contract — zero side effects, no TTY interaction).

### Section 2 — Calendly catalog entry + Google Workspace decision (INT-13/14)

**D-09 (INT-13) — Calendly catalog entry shape.**
Insert `calendly` entry alpha-ordered in `integrations-catalog.json` (between `aws-cost-explorer` and `cloudflare` based on existing alpha-ordering convention — verify at planning). Fields:

- `name: "calendly"`
- `display_name: "Calendly"`
- `category: "workspace"` (reuses existing category — no new `scheduling` category needed; planning confirms by checking if any other workspace-category entries exist, else uses workspace as the pragmatic fit)
- `unofficial: false` (Calendly publishes the MCP server officially at `developer.calendly.com/calendly-mcp-server`)
- `default_scope: "user"` (personal scheduling tool, used across projects — matches Slack / Linear / Jira default-scope rationale from Phase 36)
- `requires_oauth: true` (Calendly MCP uses OAuth per official docs)
- `env_var_keys: []` (OAuth-only — no API key prompts; the helper at D-03 cleanly handles the empty array)
- `install_args` populated per the official MCP server spec: planning agent fetches `https://developer.calendly.com/calendly-mcp-server` to extract the canonical `npx`/`node` invocation and the OAuth callback URL. Catalog entry mirrors the same schema as existing OAuth MCPs (e.g., Notion, Slack — find the closest analogue at planning time and copy the shape).
- CLI block omitted (no companion CLI for Calendly).
- `description` and `home_url` per existing entry conventions.

**D-10 (INT-14) — Google Workspace explicit non-add.**
NO `google-workspace` (or any `gmail`/`google-drive`/`google-calendar`) entry added. Decision logged in TWO places per requirement:

1. `.planning/PROJECT.md` Key Decisions table (already logged 2026-05-04 per CONTEXT carry-over from Phase 38 — verify and reference at planning).
2. `CHANGELOG.md` v5.0.0 entry (deferred to Phase 41 DIST-03; cross-reference at planning so Phase 41 picks it up).

No code change in Phase 40 for INT-14 (negative requirement). Validator may optionally assert NO entry has `name` matching `^google-(workspace|drive|gmail|calendar)$` — defense-in-depth, planning's call.

### Section 3 — Validator + tests (TEST-05, TEST-06)

**D-11 (TEST-06) — Validator SCOPE-01 assertion.**
`scripts/validate-integrations-catalog.py` (294 lines pre-existing) enforces that every MCP entry MUST carry `default_scope` field with value in `{"user", "project"}` (validator narrows the runtime catalog enum — `local` is a wizard-runtime choice only, not a catalog-default). Assertion runs alongside existing schema checks; failure exits non-zero with line-pointer to the offending entry. No new file. The TEST-06 row in REQUIREMENTS.md is already marked `[x]` — Phase 36 landed the validator implementation. Phase 40 adds the regression test in `test-integrations-catalog.sh`, NOT a re-implementation of validator code.

**D-12 (TEST-05) — Test file extension scope.**
Extend `scripts/tests/test-uninstall-state-cleanup.sh` (249 lines pre-existing) — NOT a sibling new file. Same hermetic pattern: `mktemp -d` sandbox, no `$HOME` mutation, double-run-safe, `trap 'rm -rf "$SANDBOX"' EXIT INT TERM`. Add scenarios:

- **UN-SEC-01-Y**: single-MCP keys cleanup, user answers Y → `mcp-config.env` rewritten with named MCP's keys absent, other MCPs' keys preserved, mode still 0600.
- **UN-SEC-01-N**: single-MCP keys cleanup, user answers N (default) → `mcp-config.env` byte-identical before and after.
- **UN-SEC-03-Y**: full-toolkit prompt, user answers Y → `mcp-config.env` removed, STATE_FILE still removed AFTER (ordering check).
- **UN-SEC-03-N**: full-toolkit prompt, user answers N (default) → `mcp-config.env` byte-identical, STATE_FILE removed (toolkit gone, secrets preserved).
- **UN-SEC-04**: filesystem fingerprint of all `*.env` files outside `~/.claude/` is byte-identical before/after uninstall (under `--dry-run` and live).
- **UN-SEC-05**: `--keep-state` flag → `mcp-config.env` byte-identical, `STATE_FILE` byte-identical, no prompts surfaced (assert no `[y/N]` substring in stdout).

**D-13 — Test seam for prompts.**
Reuse v4.3 `TK_UNINSTALL_TTY_SRC` test seam (override `< /dev/tty` to a fixture file containing pre-canned `y` / `N` answers). Phase 40 does NOT introduce a new seam. Planning verifies the seam name by grepping `uninstall.sh` for the existing override pattern.

**D-14 (TEST-06) — Catalog test extension.**
`scripts/tests/test-integrations-catalog.sh` (314 lines pre-existing, PASS≥10) gains:

- SCOPE-01 assertion: validator catches entry missing `default_scope` (negative case via mutated copy).
- Calendly assertion: positive — `calendly` entry has expected shape (`unofficial=false`, `default_scope="user"`, `requires_oauth=true`, `env_var_keys=[]`).
- Google Workspace negative: no entry with `name` matching the `^google-` pattern (per D-10 defense-in-depth).

PASS floor moves from ≥10 to ≥13.

### Section 4 — Cross-cutting

**D-15 — Plan count.**
ROADMAP.md says 5 plans. Locked breakdown:

- **40-01**: `uninstall_prompt_mcp_keys` helper + per-MCP plumbing (UN-SEC-01, UN-SEC-02). Adds the first `claude mcp remove` loop in uninstall.sh.
- **40-02**: full-toolkit `mcp-config.env` prompt + ordering (UN-SEC-03). Lands AFTER 40-01 because the prompt count surfaces from the same loop.
- **40-03**: project-`.env`-never-touched contract + `--keep-state` implies `--keep-secrets` (UN-SEC-04, UN-SEC-05). Mostly documentation + `--help` update + dry-run gate.
- **40-04**: Calendly catalog entry + Google Workspace decision-log cross-references (INT-13, INT-14) + validator SCOPE-01 assertion (TEST-06). One small commit covers all three because they touch only catalog/validator files.
- **40-05**: `test-uninstall-state-cleanup.sh` extension (TEST-05). Lands LAST so all behavior under test is already implemented.

**D-16 — Bash 3.2 / macOS BSD compat.**
Standard project invariants apply: no `mapfile`, no `${var,,}`, no `realpath -f`, no `declare -A`, no `read -N`. Uses parallel arrays where associative would be nice. `mktemp` BSD-style template at end (`-t prefix.XXXXXX` or `-d` form already used in tests).

**D-17 — Dependency on prior phases.**
Phase 36 SCOPE-01 schema must be present in the catalog (was — Phase 36 closed). Phase 37 `project-secrets.sh` API exists (was — Phase 37 closed). Phase 38 wizard writes the `env_var_keys` we are about to clean up (was — Phase 38 closed). Phase 39 per-row scope is unrelated to uninstall path (no shared files). All dependencies satisfied.

**D-18 — `make check` baseline.**
Phase 40 must keep ALL existing tests green:

- `make shellcheck`
- `bash scripts/tests/test-mcp-selector.sh` (PASS=36)
- `bash scripts/tests/test-mcp-wizard.sh` (PASS=53)
- `bash scripts/tests/test-mcp-secrets.sh` (PASS=11)
- `bash scripts/tests/test-project-secrets.sh` (PASS=42)
- `bash scripts/tests/test-uninstall-state-cleanup.sh` (current PASS — re-verify at plan time, then floor moves up by 6 new scenarios from D-12)
- `bash scripts/tests/test-integrations-catalog.sh` (PASS≥10 → ≥13 per D-14)

**D-19 — `--help` text updates.**
`uninstall.sh --help` (lines ~31-48 today) gains:

- `--keep-state` flag documentation extended to mention "implies --keep-secrets" (UN-SEC-05 per D-07).
- New section "Secret cleanup" explaining the per-MCP `[y/N]` prompt and the full-toolkit `[y/N]` prompt (UN-SEC-01/03 per D-01/D-05).

**D-20 — Doc updates deferred to Phase 41.**
`docs/INSTALL.md` and `docs/UNINSTALL.md` updates are Phase 41 (DOCS-01..03) scope, NOT Phase 40. Phase 40 only updates `--help` (in-script user-facing text) and the locked decisions in this CONTEXT.md. CHANGELOG entry is also Phase 41.

## Open questions

None. All gray areas resolved from REQUIREMENTS.md + ROADMAP.md + existing code base reads.

## Out of scope (deferred)

- New `--keep-secrets` independent flag (deferred to v5.1 if friction surfaces; YAGNI for v5.0).
- Per-MCP uninstall command (e.g., `uninstall.sh --mcp=context7`) — deferred; the helper is reusable when that feature lands but the CLI surface is not in v5.0.
- Google Workspace MCP — explicitly locked out (INT-14, also locked in v4.9 INT-FUT-05).
- macOS Keychain / Linux libsecret integration — locked out for v5.0 (SEC-FUT-01).
- 1Password / Vault detection — locked out for v5.0 (SEC-FUT-02).

## References

- ROADMAP.md Phase 40 entry (success criteria 1-5)
- REQUIREMENTS.md UN-SEC-01..05, INT-13, INT-14, TEST-05, TEST-06
- Phase 36 CONTEXT (SCOPE-01 schema)
- Phase 37 CONTEXT + library (`project-secrets.sh` 4-function API)
- Phase 38 CONTEXT (wizard `env_var_keys` writer contract)
- v4.3 UN-03 prompt pattern (`uninstall.sh:300+ prompt_modified_for_uninstall`)
- v4.3 UN-05 D-06 ordering invariant (STATE_FILE removal LAST)
- v4.4 KEEP-01 `--keep-state` gate (`uninstall.sh:824+`)
- `developer.calendly.com/calendly-mcp-server` (Calendly MCP official docs — to be fetched at planning for D-09 install_args canonical shape)
