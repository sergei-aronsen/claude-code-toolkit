# Phase 28: Bridge Foundation - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Phase 28 delivers the **detection + generation foundation** for v4.7 Multi-CLI Bridge:

1. Extends `scripts/lib/detect2.sh` (v4.6 Phase 24 lib) with two new binary probes — `is_gemini_installed` and `is_codex_installed` — each `command -v` based, fail-soft when CLI absent.
2. Ships a new `scripts/lib/bridges.sh` library that exposes `bridge_create_project <target>` and `bridge_create_global <target>` (target = `gemini` | `codex`). Each writes a plain copy of `CLAUDE.md` (or `~/.claude/CLAUDE.md`) to the target's conventional filename (`GEMINI.md` for Gemini CLI; `AGENTS.md` for OpenAI Codex CLI), prepending a byte-identical auto-generated header banner.
3. Registers each created bridge in `~/.claude/toolkit-install.json` under a new `bridges[]` array with `{target, path, scope, source_sha256, bridge_sha256, user_owned: false}` schema. Tracking enables the drift detection that Phase 29 will consume.

**Out of scope for Phase 28:** install-time UX wiring (Phase 30), update sync logic (Phase 29), uninstall removal (Phase 29), distribution/tests/docs (Phase 31).

</domain>

<decisions>
## Implementation Decisions

### Detection (BRIDGE-DET-01..03)

- **Probe pattern:** identical to v4.6 Phase 24 `is_*_installed` siblings (`is_toolkit_installed`, `is_security_installed`, etc.) — single-purpose function returning 0/1, no 3-state.
- **Primary signal:** `command -v gemini` / `command -v codex` (binary on PATH).
- **Soft cross-check:** filesystem dir presence (`[ -d ~/.gemini/ ]` / `[ -d ~/.codex/ ]`). Used only as confirmation that user has the CLI configured locally; CLI-PATH wins on conflict (mirrors v4.1 DETECT-06 invariant).
- **Fail-soft:** absent CLI returns 1 (not-installed). No errors, no warnings. Downstream (Phase 30) decides what to do with negative detection.
- **Registration:** add probes to existing `detect2.sh` file under same `is_*_installed` block. Alphabetize (codex before gemini before existing entries by lex order).

### Bridge generation (BRIDGE-GEN-01..04)

- **New library:** `scripts/lib/bridges.sh` — separate file (not extending an existing lib) because the API surface is distinct (project + global write APIs, header banner generation, state schema mutation) and the v4.4 `files.libs[]` auto-discovery pattern (LIB-01 D-07 jq path) makes adding new libs zero-cost for `update-claude.sh`.
- **API shape:** `bridge_create_project <target> [project_root]` and `bridge_create_global <target>`. Both return 0 on success, 1 on missing source, 2 on user-permission denied (mkdir/write blocked). Project variant defaults `project_root` to `$PWD` if omitted.
- **Source resolution:** project = `<project_root>/CLAUDE.md` (existing v4.0 contract), global = `~/.claude/CLAUDE.md`. NEVER touch the canonical source.
- **Target paths:**
  - Gemini project: `<project_root>/GEMINI.md`
  - Gemini global: `~/.gemini/GEMINI.md` (with `mkdir -p ~/.gemini/` first)
  - Codex project: `<project_root>/AGENTS.md`
  - Codex global: `~/.codex/AGENTS.md` (with `mkdir -p ~/.codex/` first)
- **`AGENTS.md` for Codex (not `CODEX.md`):** documented in BRIDGE-DOCS-01 as design decision. OpenAI Codex CLI reads `AGENTS.md` per the OpenAI standard. To prevent re-discussion later, this is locked as a top-level domain fact.
- **Header banner:** byte-identical across all bridges (BRIDGE-GEN-03 quoted block). HTML comment, separated from copied content by exactly one blank line. Banner content fixed in v4.7; future versions would extend rather than rewrite.
- **Header generation:** inline `cat <<'EOF'` heredoc inside `bridges.sh`. No external template file (over-engineering for 6-line block).
- **Idempotency:** re-running `bridge_create_project gemini` overwrites `GEMINI.md` with same content if source unchanged. SHA256 of resulting file deterministic when source SHA256 stable.

### State tracking (BRIDGE-GEN-04)

- **Schema location:** new top-level `bridges[]` array in `~/.claude/toolkit-install.json`. Sibling to existing `installed_files[]`, `mode`, `detected`, etc.
- **Per-entry fields:**

  ```json
  {
    "target": "gemini" | "codex",
    "path": "<absolute path to bridge file>",
    "scope": "project" | "global",
    "source_sha256": "<sha256 of CLAUDE.md at write time>",
    "bridge_sha256": "<sha256 of the bridge file we just wrote>",
    "user_owned": false
  }
  ```

- **Atomic update:** use existing `_state_lock` + `_atomic_json_write` helpers from `scripts/lib/state.sh` (v4.0 STATE-04). No new locking primitives.
- **De-dup:** if a bridge for the same `(target, scope, path)` triple exists, replace in-place (update SHAs) rather than appending duplicate.
- **`user_owned: false` default:** flipped to `true` only by Phase 29's `--break-bridge` flag. Phase 28 never writes `true`.

### Code organization

- `bridges.sh` sources `scripts/lib/state.sh` (for atomic JSON helpers), `scripts/lib/dry-run-output.sh` (for `[+ INSTALL] / [~ UPDATE] / [- SKIP]` chezmoi-grade output), and reads `scripts/lib/detect2.sh` for the new `is_*_installed` probes. No new external dependencies.
- All scripts use Bash 3.2+ POSIX-compatible style: no `declare -A` (associative arrays), no `read -N` (Bash 4+), no `${var^^}` uppercase expansion, no `declare -n` namerefs. Mirrors v4.6 Phase 24 invariants.
- `set -euo pipefail` at top of `bridges.sh`. Function-scoped `local` for all variables.

### Header banner content (locked)

```html
<!--
  Auto-generated from CLAUDE.md by claude-code-toolkit (v4.7+).
  Edit CLAUDE.md (canonical source). This file regenerates on update-claude.sh.
  To stop sync: run `update-claude.sh --break-bridge <name>`.
-->
```

Followed by exactly one blank line, then the verbatim CLAUDE.md content.

### Test seam

- `TK_BRIDGE_HOME` env var (defaults to `$HOME`) overrides global write target for hermetic testing. Mirrors `TK_MCP_CONFIG_HOME` from v4.6 Phase 25. Allows `bridge_create_global gemini` in tests to write under a sandboxed `$TK_BRIDGE_HOME/.gemini/` instead of real `$HOME/.gemini/`.

### Claude's Discretion

- Internal helper function names inside `bridges.sh` (e.g., `_bridge_target_path`, `_bridge_compute_sha256`, `_bridge_write_state_entry`).
- Exact `sha256sum` invocation form (use shasum -a 256 fallback for macOS BSD compat).
- Exact `cat <<'EOF'` quoting style for header heredoc (single-quoted to avoid variable expansion).
- Whether to expose `bridge_create_project` as a public API surface symbol or leave it library-internal — public is fine; sub-component dispatch uses it.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/lib/detect2.sh` (v4.6 Phase 24) — has 6 binary probes (`is_toolkit_installed`, `is_superpowers_installed`, `is_gsd_installed`, `is_security_installed`, `is_rtk_installed`, `is_statusline_installed`). Pattern: single-line `command -v <cli> >/dev/null 2>&1`. Direct extension target.
- `scripts/lib/state.sh` (v4.0 STATE-04) — exposes `_state_lock`, `_atomic_json_write`, `state_get`, `state_set` for `~/.claude/toolkit-install.json`. The `bridges[]` write path piggybacks on this.
- `scripts/lib/dry-run-output.sh` (v4.1 UX-01) — `dro_init_colors`, `dro_print_header`, `dro_print_file`, `dro_print_total` for chezmoi-grade `[+ INSTALL]` etc. output. Reused by bridge create logging.
- `scripts/lib/bootstrap.sh::bootstrap_base_plugins` (v4.4 BOOTSTRAP-01) — TK_BOOTSTRAP_TTY_SRC pattern is the template for `TK_BRIDGE_TTY_SRC` (Phase 30 use).
- `scripts/lib/mcp.sh::mcp_secrets_set` (v4.6 Phase 25) — chmod-after-write pattern is the template for any future `chmod 0644` on bridge files (current decision: no chmod, default umask).

### Established Patterns

- All `lib/*.sh` use `set -euo pipefail` at top + `local` for all function-scoped vars.
- All test seams via `TK_*` env vars with `${VAR:-default}` fallback. Examples: `TK_BOOTSTRAP_TTY_SRC`, `TK_TUI_TTY_SRC`, `TK_MCP_CONFIG_HOME`, `TK_DISPATCH_OVERRIDE_*`.
- Manifest `files.libs[]` auto-discovery via existing jq path `.files | to_entries[] | .value[] | .path` — adding `bridges.sh` to `files.libs[]` makes `update-claude.sh` ship it with zero new code (v4.4 LIB-01 D-07 invariant).
- SHA256 helpers — toolkit doesn't ship one universally; `scripts/uninstall.sh::classify_file` uses `shasum -a 256` (macOS BSD compat) inline. Bridges.sh inlines the same helper.
- Idempotent install pattern: check existence before write, overwrite on re-run, bypass via `--force` flag.

### Integration Points

- `scripts/install.sh` (Phase 30) will invoke `bridge_create_project` / `bridge_create_global` via dispatch; Phase 28 only ships the API.
- `scripts/update-claude.sh` (Phase 29) will iterate `bridges[]` via the same `state_get` accessor we add here.
- `scripts/uninstall.sh` (Phase 29) will read `bridges[]` paths into `REMOVE_LIST` for v4.3 SHA256 classification.
- `manifest.json::files.libs[]` (Phase 31) registers `scripts/lib/bridges.sh`.

</code_context>

<specifics>
## Specific Ideas

- The CONTEXT.md note about Codex reading `AGENTS.md` (NOT `CODEX.md`) is locked at the top-level domain layer — Phase 28 implements that decision; downstream phases inherit.
- v4.6 Phase 24 D-23 detect2 cache (`detect2_cache`) helper is NOT consumed by bridges in Phase 28 — bridges call `is_gemini_installed` / `is_codex_installed` directly because the call frequency is low (one-shot at install time, one-shot at update time). Cache is for repeated TUI-render polling.

</specifics>

<deferred>
## Deferred Ideas

- **Branding substitution layer** (BRIDGE-FUT-01): replace `Claude Code` → `Gemini CLI` etc. in copied content. Deferred to v4.8 if friction surfaces. Phase 28 ships plain copy.
- **Per-CLI tone overlay** (BRIDGE-FUT-02): small per-CLI snippets prepended to bridge content. Out of v4.7 scope.
- **Cursor `.cursorrules` support** (BRIDGE-FUT-03): different file format. Out of v4.7 scope.
- **Aider `CONVENTIONS.md` support** (BRIDGE-FUT-04): defer.
- **`update-claude.sh --bridges-only` mode** (BRIDGE-FUT-05): edge utility, out of v4.7 scope.

</deferred>
