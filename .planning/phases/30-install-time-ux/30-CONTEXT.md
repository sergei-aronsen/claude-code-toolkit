# Phase 30: Install-time UX - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Phase 30 wires Phase 28 bridge primitives into the user-facing install entry points:

1. **`scripts/install.sh`** Components page (v4.6 unified TUI) gets 2 conditional rows: `gemini-bridge` + `codex-bridge`. Rows appear ONLY when the corresponding CLI binary is on PATH (probed via Phase 28 `is_gemini_installed` / `is_codex_installed`). Selection dispatches `bridge_create_global <target>` (writes under `~/.gemini/` or `~/.codex/`).
2. **`scripts/init-claude.sh`** and **`scripts/init-local.sh`** post-install (after `.claude/` populated): per-CLI prompt `Gemini CLI detected. Create GEMINI.md → CLAUDE.md bridge? [Y/n]` (default Y). Fail-closed N on no-TTY. Dispatches `bridge_create_project <target> <project_root>`.
3. **`--no-bridges`** flag + **`TK_NO_BRIDGES=1`** env var skip every bridge prompt unconditionally on all 3 entry points (mirrors `--no-bootstrap` / `TK_NO_BOOTSTRAP` symmetry from v4.4 BOOTSTRAP-01).
4. **`--bridges <comma-list>`** flag forces non-interactive bridge creation for named targets (`--bridges gemini,codex`). With `--fail-fast`: absent CLI exits 1. Without: warn + continue.

**Out of scope for Phase 30:** Phase 29 sync logic (already shipped). Manifest registration + version bump (Phase 31). docs/BRIDGES.md (Phase 31). CHANGELOG (Phase 31). Branding substitution (deferred BRIDGE-FUT-01).

</domain>

<decisions>
## Implementation Decisions

### TUI integration in install.sh (BRIDGE-UX-01)

- **Row construction:** AFTER `is_gemini_installed` / `is_codex_installed` probes run (already part of v4.6 detection layer), conditionally append to `TUI_LABELS` / `TUI_GROUPS` / `TUI_INSTALLED` / `TUI_DESCS` arrays. Pattern mirrors v4.6 RTK row (line ~573 of install.sh) — RTK row only appears when `IS_RTK=1`.
- **Labels:** `gemini-bridge`, `codex-bridge` (kebab-case to match `gemini-bridge` selection downstream in dispatch).
- **Group:** `Bridges` (new TUI group, sibling of `Bootstrap` / `Core` / `Optional`). Renders below `Optional`.
- **Description format:** `Gemini CLI bridge (CLAUDE.md → GEMINI.md) [detected: gemini@<version>]`. Codex variant analogous: `OpenAI Codex CLI bridge (CLAUDE.md → AGENTS.md) [detected: codex@<version>]`.
- **Default-checked:** since the CLI is installed, the row defaults to PRE-CHECKED in TUI_RESULTS (user opts out by unchecking). With `--yes`: included automatically.
- **Hidden when CLI absent:** if `is_gemini_installed` returns 1, the row is OMITTED from `TUI_LABELS` entirely — no greyed-out "[unavailable]" row. Cleaner UX, matches CLI-absent decision tree from CONTEXT.md "Detection" section in Phase 28.

### CLI version probe

- **Helper:** new `_bridge_cli_version <target>` in `scripts/lib/bridges.sh`. Body:
  ```bash
  case "$target" in
      gemini) gemini --version 2>/dev/null | head -1 || echo "" ;;
      codex)  codex --version 2>/dev/null | head -1 || echo "" ;;
  esac
  ```
- **Fail-soft:** empty string when probe fails. Caller (install.sh) shows `[detected: gemini]` (no version suffix) if empty, else `[detected: gemini@<version>]`.
- **Performance:** version probe runs ONCE per install at TUI render time (low-frequency). No caching needed beyond standard probe-once-per-install pattern.

### Dispatch integration (BRIDGE-UX-01)

- **Order:** `gemini-bridge` and `codex-bridge` added to `TK_DISPATCH_ORDER` in `scripts/lib/dispatch.sh` AFTER `statusline` (last among Optional). Bridges are install-time-only; no skill/MCP-style downstream wiring.
- **Dispatch body:** new dispatch case in install.sh (or in a new `scripts/lib/bridges-dispatch.sh` library — picker decides). Calls `bridge_create_global gemini` / `bridge_create_global codex` respectively.
- **Output:** dispatch records `installed ✓` on success, `failed (exit $rc)` on failure. Stderr tail captured via existing `COMPONENT_STDERR_TAIL` array (install.sh:298) for the post-install summary (D-27 status path).

### init-claude.sh + init-local.sh post-install prompt (BRIDGE-UX-02)

- **New library function:** `bridge_install_prompts <project_root>` in `scripts/lib/bridges.sh`. Iterates targets `gemini`, `codex`. For each:
  ```bash
  is_<target>_installed || continue            # CLI absent → skip silently
  [[ "${TK_NO_BRIDGES:-}" == "1" ]] && return 0
  
  # --bridges <list> path: force-create without prompt
  if [[ -n "${BRIDGES_FORCE:-}" ]]; then
      _bridge_match "$target" "$BRIDGES_FORCE" && bridge_create_project "$target" "$project_root"
      continue
  fi
  
  # Interactive prompt
  read -r -p "$(_bridge_cli_label "$target") detected. Create $(_bridge_filename "$target") → CLAUDE.md bridge? [Y/n]: " choice < "${TK_BRIDGE_TTY_SRC:-/dev/tty}" 2>/dev/null || choice="N"
  case "${choice:-Y}" in
      n|N) ;;                           # explicit decline
      *) bridge_create_project "$target" "$project_root" ;;   # default Y
  esac
  ```
- **Default Y:** unlike Phase 29 drift prompt (default N), the install-time prompt is default Y. Rationale: user has CLI installed → likely wants the bridge. Drift is destructive; install is additive.
- **Fail-closed N on no-TTY:** if `read` fails (EOF / unreachable TTY), `choice` falls through to N branch. Matches BOOTSTRAP-01 invariant.
- **TTY source:** `${TK_BRIDGE_TTY_SRC:-/dev/tty}`. Same shape as `TK_BOOTSTRAP_TTY_SRC` (bootstrap.sh:43).
- **Wired into init-claude.sh:** AFTER `.claude/` populated, AFTER any `bootstrap_base_plugins` call, BEFORE final summary. New entry point block mirrors `bootstrap_base_plugins` invocation pattern (init-claude.sh:141).
- **Wired into init-local.sh:** same place (init-local.sh:157 region — after bootstrap, before summary).

### Flag plumbing (BRIDGE-UX-03 + BRIDGE-UX-04)

- **`--no-bridges`:** parsed in argv loop of init-claude.sh, init-local.sh, install.sh. Sets `NO_BRIDGES=true`. Library helper checks `${NO_BRIDGES:-false} == "true"` OR `${TK_NO_BRIDGES:-} == "1"` and returns 0 immediately.
- **`--bridges <list>`:** parsed similarly. Sets `BRIDGES_FORCE="$1"` (the comma-list arg). Library helper consumes via `_bridge_match <target> "$BRIDGES_FORCE"` (membership test).
- **`--fail-fast` interaction with `--bridges`:** if a target named in `--bridges` is NOT installed and `--fail-fast` is set, exit 1 with `Error: --bridges gemini specified but gemini CLI not detected (--fail-fast)`. Without `--fail-fast`: log warning, continue (skip the missing one).
- **Mutually exclusive:** `--no-bridges` and `--bridges X` together → exit 2 with `Error: --no-bridges and --bridges are mutually exclusive`. Mirrors v4.4 `--no-bootstrap` / `--bootstrap-only` precedent.
- **Help text update:** add `--no-bridges`, `--bridges <list>` rows to all 3 `usage()` / `--help` blocks.

### `--yes` default-set (BACKCOMPAT-01 invariant)

- With `--yes`, install.sh synthesizes a default-set of selections (line ~595 region). Bridges are INCLUDED in the default-set when their CLI is detected. So `bash install.sh --yes` on a system with gemini installed creates the global GEMINI.md bridge.
- This does NOT affect init-claude.sh / init-local.sh under `--yes` — those scripts don't have `--yes` (they have `--force`). Project-local bridges still need either `--bridges gemini,codex` or `bridge_install_prompts` interactive flow to fire.

### Code organization

- **`scripts/lib/bridges.sh`** gains 4 new helpers (all internal except `bridge_install_prompts`):
  - `bridge_install_prompts <project_root>` — orchestrator for init-claude.sh / init-local.sh post-install
  - `_bridge_cli_version <target>` — version probe
  - `_bridge_cli_label <target>` — `Gemini CLI` / `OpenAI Codex CLI` for prompt strings
  - `_bridge_match <target> <comma-list>` — membership test for `--bridges` flag
- **`scripts/lib/dispatch.sh`** gains 2 new entries in `TK_DISPATCH_ORDER` array.
- **`scripts/install.sh`** gains conditional `TUI_LABELS` extension + 2 dispatch cases.
- **`scripts/init-claude.sh`** + **`scripts/init-local.sh`** gain argv parsing + `bridge_install_prompts` call.

### Test seams

- `TK_BRIDGE_TTY_SRC` — replaces `/dev/tty` for prompt input. Tests inject answers via here-doc.
- `TK_BRIDGE_HOME` — already used by Phase 28 hermetic test for state file isolation.
- `TK_DETECT_OVERRIDE_GEMINI` / `TK_DETECT_OVERRIDE_CODEX` — already part of v4.6 detect2 cache layer (override probe results in tests). Reused.
- New: `scripts/tests/test-bridges-install-ux.sh` ≥10 scenarios:
  1. install.sh + TK_DETECT_OVERRIDE_GEMINI=1: `gemini-bridge` row appears in TUI
  2. install.sh + TK_DETECT_OVERRIDE_GEMINI=0: row absent
  3. install.sh --yes with gemini detected: global bridge created
  4. install.sh --no-bridges --yes: zero bridges created
  5. init-claude.sh post-install: TK_BRIDGE_TTY_SRC injects "Y" → bridge created
  6. init-claude.sh post-install: TK_BRIDGE_TTY_SRC injects "n" → no bridge
  7. init-claude.sh + TK_NO_BRIDGES=1: prompts skipped silently
  8. init-claude.sh --bridges gemini: forced create, no prompt
  9. init-claude.sh --bridges gemini --fail-fast (gemini absent): exit 1
  10. init-claude.sh --bridges gemini (gemini absent, no fail-fast): warn + continue
  11. init-claude.sh --no-bridges + --bridges gemini: exit 2 (mutex)
  12. BACKCOMPAT-01: test-bootstrap PASS=26, test-install-tui PASS=43, test-bridges-foundation PASS=5, test-bridges-sync PASS=25 unchanged

### init-claude.sh URL byte-identical (BACKCOMPAT-01)

- The `bash <(curl -sSL .../init-claude.sh)` URL must remain byte-identical. New flags are PARSED but if absent, behavior reverts to v4.6: bootstrap → install toolkit → exit. The only NEW default-flow change is the post-install bridge prompt (interactive) which is fail-closed N on no-TTY. Under `bash <(curl ...)` (no TTY by default), bridges are NEVER created without an explicit `--bridges` flag.
- This explicit no-TTY-no-bridges contract is the v4.6 BACKCOMPAT-01 invariant extended.

### Claude's Discretion

- Internal helper names (`_bridge_cli_version`, `_bridge_cli_label`, `_bridge_match`) are recommendations.
- Whether to extract a separate `scripts/lib/bridges-dispatch.sh` for the install.sh dispatch cases vs inlining in install.sh — picker decides. Recommend inline for v4.7 (fewer files); refactor in v4.8 if dispatch surface grows.
- Exact TUI group label `Bridges` vs `Multi-CLI Bridges` — picker decides. Stay terse: `Bridges`.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/lib/bootstrap.sh::bootstrap_base_plugins` (v4.4 BOOTSTRAP-01) — TEMPLATE for `bridge_install_prompts`. `TK_BOOTSTRAP_TTY_SRC` pattern at line 43, `TK_NO_BOOTSTRAP` short-circuit at line 70.
- `scripts/install.sh:573` (`TUI_LABELS=(...)`) — INSERTION POINT for conditional bridge rows. RTK row pattern (line 573 includes "rtk" only because IS_RTK is preset; bridges follow same shape).
- `scripts/install.sh:298` (`COMPONENT_STDERR_TAIL`) — error tail capture pattern, reused for bridge dispatch.
- `scripts/lib/tui.sh::tui_checklist` — consumes TUI_LABELS / TUI_GROUPS / TUI_INSTALLED / TUI_DESCS. No code change needed; just extend the input arrays.
- `scripts/lib/dispatch.sh::TK_DISPATCH_ORDER` — append `gemini-bridge`, `codex-bridge` after `statusline`.
- `scripts/init-claude.sh:138-141` — `bootstrap_base_plugins` invocation block. New `bridge_install_prompts` block goes right after (before final summary).
- `scripts/init-local.sh:152-157` — analogous block.
- `scripts/lib/bridges.sh::bridge_create_project` (Phase 28) — invoked by `bridge_install_prompts`.
- `scripts/lib/bridges.sh::bridge_create_global` (Phase 28) — invoked by install.sh dispatch cases.
- `scripts/lib/detect2.sh::is_gemini_installed / is_codex_installed` (Phase 28) — invoked at TUI render + at prompt time.

### Established Patterns

- All flag parsing: `while [[ $# -gt 0 ]]` + `case`. Add `--no-bridges` and `--bridges <list>` as new cases.
- Mutual-exclusion check: scan parsed flags after argv loop, exit 2 with usage error if conflict.
- `read -r -p "..." choice < "${VAR:-/dev/tty}" 2>/dev/null || choice="N"` — no-TTY-fail-closed pattern.
- Conditional TUI row: array append guarded by `[[ $IS_<TARGET> -eq 1 ]] && TUI_LABELS+=("...")` etc.
- `--yes` default-set: synthesize TUI_RESULTS preselected; bridges included when probe positive.

### Integration Points

- Phase 31 will register `scripts/lib/bridges.sh` in manifest.json `files.libs[]`. Until then, bridges.sh is downloaded by curl-based installers via the same loop as other libs (see install.sh `LIB_*_TMP=$(mktemp...)` pattern around line 280-300).
- Phase 31 will document `--no-bridges` / `--bridges` flags in `docs/INSTALL.md`. Phase 30 only ships the flag parsing; docs follow.

</code_context>

<specifics>
## Specific Ideas

- **Default-checked under TUI but default-Y under prompt** is intentional: TUI is bulk-select (uncheck to skip), prompt is per-CLI confirm. Both bias toward "yes" because the user already has the CLI.
- **install.sh creates GLOBAL bridges only.** Project-local bridges come from init-claude.sh / init-local.sh post-install. Reason: install.sh is the global toolkit installer; project bridges depend on `<project_root>/CLAUDE.md` which the global installer may not see.
- **--bridges flag is comma-separated** to match `--bootstrap=gsd,sp` precedent; tokens trimmed of whitespace; unknown tokens warn + skip.

</specifics>

<deferred>
## Deferred Ideas

- **Bridge selection persistence:** record `--bridges <list>` selection in toolkit-install.json so `update-claude.sh` knows which bridges the user wanted at install time. Defer to v4.8 — Phase 29 sync handles this implicitly via existing `bridges[]` registry.
- **Per-project `--bridges` config file:** `.claude/bridges.conf` overriding global selection. Defer to v4.8 if multi-project users emerge.
- **Auto-bridge on `claude` start:** detect new project, prompt to bridge. Out of v4.7 scope (claude-side concern).
- **Bridge marketplace metadata:** publish bridge files via marketplace.json. Defer.
- **Branding substitution layer (BRIDGE-FUT-01):** still deferred to v4.8.

</deferred>
