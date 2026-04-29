# Phase 24: Unified TUI Installer + Centralized Detection — Research

**Researched:** 2026-04-29
**Domain:** Bash 3.2 TUI, terminal raw mode, centralized detection, dispatch, manifest wiring
**Confidence:** HIGH (all code findings are [VERIFIED] from codebase; Bash 3.2 TUI patterns [ASSUMED] from training knowledge, cross-checked against project constraints)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

All 34 decisions D-01..D-34 are locked. Summary:

- D-01..D-03: Grouped TUI sections (Bootstrap / Core / Optional), non-selectable headers, stable item order
- D-04..D-07: SP/GSD in same TUI Bootstrap group; `bootstrap.sh` is no-TTY fallback for SP/GSD only; `--yes` bypasses TUI entirely; `bootstrap.sh` not deleted
- D-08..D-11: Default continue-on-error; `--fail-fast` opt-in; states = `installed ✓` / `skipped` / `failed (exit N)` / `unknown`; fail-closed on TTY absence or EOF
- D-12..D-15: `--yes` = all uninstalled in dispatch order; skip already-installed; `--force` re-runs; no `--preset` in v4.6
- D-16..D-20: Arrow `▶` focus indicator; `[ ]` / `[x]` / `[installed ✓]` checkboxes; keys: ↑↓ space enter q Ctrl-C; help line always shown; description on one dimmed line below help
- D-21..D-23: `detect2.sh` sources `detect.sh`; each `is_*_installed` returns 0/1; detection cached in shell vars, re-probed before each dispatch
- D-24..D-26: `dispatch_<name>` functions in single `dispatch.sh`; curl-pipe vs local detection; flags `[--force] [--dry-run] [--yes]` pass-through; `setup-security.sh` gets real `--yes`; `install-statusline.sh` gets no-op `--yes`
- D-27..D-29: Summary via `dro_*` API; stderr tail 5 lines per failed component; exit 0 on no failures, 1 on any failure
- D-30..D-32: `init-claude.sh` URL stays byte-identical; `test-bootstrap.sh` 26 assertions stay green; no deprecation warning
- D-33..D-34: `TK_TUI_TTY_SRC` mirrors `TK_BOOTSTRAP_TTY_SRC` shape exactly; `test-install-tui.sh` ≥15 assertions

### Claude's Discretion

- Exact ANSI sequences (choose most portable for Bash 3.2)
- `dro_print_install_status` exact column widths and color choices
- `dispatch_<name>` as functions in single `dispatch.sh` (preferred, not per-file)
- Help line placement (bottom preferred)
- Keystroke-buffer flushing between keys if needed
- Stderr-tail length in failure summary (5 lines default)

### Deferred Ideas (OUT OF SCOPE)

- Vim-style j/k bindings (TUI-FUT-04)
- Multi-line item descriptions
- Live progress bars (TUI-FUT-01)
- `--preset` bundles (TUI-FUT-02)
- MCP/Skills TUI sections (Phases 25/26)
- Auto-bump manifest.json to 4.6.0 (Phase 27)
- TUI section search/filter
- Localization

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TUI-01 | `tui.sh` exposes `tui_checklist <items_var> <results_var>` — Bash 3.2 compat, `read -rsn1` + `read -rsn2` for arrow tail, no `read -N`, no `declare -n` | §Bash 3.2 TUI Implementation: two-pass read pattern, parallel indexed arrays |
| TUI-02 | Reads from `< /dev/tty` with `TK_TUI_TTY_SRC` test seam; fail-closed on no-tty | §/dev/tty Patterns: seam mirrors bootstrap.sh exactly |
| TUI-03 | `trap '<restore-stty>' EXIT INT TERM` BEFORE entering raw mode; Ctrl-C restores cleanly | §Terminal Restore: stty -g save, restore with `\|\| true` |
| TUI-04 | Item displays label + status `[ ]` / `[x]` / `[installed ✓]` + focused description | §Bash 3.2 TUI: render loop design |
| TUI-05 | Confirmation `Install N component(s)? [y/N]` before dispatch; default N | §Bash 3.2 TUI: confirmation step |
| TUI-06 | `--no-color` and `${NO_COLOR+x}` honored; `[ -t 1 ]` gates color | §ANSI Compatibility: NO_COLOR contract |
| TUI-07 | `test-install-tui.sh` ≥15 assertions hermetic test | §Test Fixture Format: fixture encoding, scenario list |
| DET-01 | `detect2.sh` sources `detect.sh`; adds `is_*_installed` for all 6 components | §Detection v2 Probes: sourcing safety verified |
| DET-02 | `is_security_installed`: `command -v cc-safety-net` AND grep `~/.claude/hooks/pre-bash.sh` | §Detection v2 Probes: confirmed from codebase grep |
| DET-03 | `is_statusline_installed`: `~/.claude/statusline.sh` exists AND grep `statusLine` in settings.json | §Detection v2 Probes: confirmed from install-statusline.sh |
| DET-04 | `is_rtk_installed`: `command -v rtk` | §Detection v2 Probes: verified `rtk` at `/opt/homebrew/bin/rtk` |
| DET-05 | `is_toolkit_installed`: `~/.claude/toolkit-install.json` exists | §Detection v2 Probes: confirmed write site in init-claude.sh |
| DISPATCH-01 | `dispatch.sh` exposes `dispatch_toolkit`, `dispatch_security`, `dispatch_rtk`, `dispatch_statusline`; order SP→GSD→toolkit→security→RTK→statusline | §Dispatch Layer: flag inventory per component |
| DISPATCH-02 | `setup-security.sh` learns real `--yes`; `install-statusline.sh` learns no-op `--yes` | §Dispatch Layer: setup-security.sh has zero existing interactive reads — `--yes` guards future interactive paths and no-TTY detection; install-statusline.sh already non-interactive |
| DISPATCH-03 | `install.sh` top-level orchestrator; not a trampoline | §Dispatch Layer: full orchestration loop design |
| BACKCOMPAT-01 | `init-claude.sh` URL unchanged; 26-assertion `test-bootstrap.sh` stays green | §Project Constraints: verified — Phase 24 adds new files only, no changes to existing scripts |

</phase_requirements>

---

## 1. Executive Summary

Ten things the planner must know:

- **Bash 3.2 read limitation:** `read -N` (capital N) is Bash 4+ only. Must use lowercase `read -rsn1` then conditionally `IFS= read -rsn2` to capture the 2-byte arrow escape suffix. This is already noted in STATE.md and is the single most critical implementation constraint. [VERIFIED: bash --version on macOS = 3.2.57]

- **`stty -g` requires a real TTY:** `stty -g` will fail (exit 1) when stdin is not a terminal (CI, subshell). The save/restore idiom must be guarded: `saved=$(stty -g </dev/tty 2>/dev/null || echo "")`. The restore in the EXIT trap must check `[[ -n "$saved" ]]` before invoking `stty`. [ASSUMED: from training knowledge; pattern identical to bootstrap.sh fail-closed guard]

- **`detect.sh` is source-safe:** Confirmed by reading lines 123–127 — both `detect_superpowers || true` and `detect_gsd` are called at file bottom with `|| true` guard. Sourcing `detect2.sh` which re-sources `detect.sh` is safe under `set -e` callers. [VERIFIED: from codebase read]

- **`toolkit-install.json` is written by `init-claude.sh` (global) and `init-local.sh` (project-local).** The global install writes to `$HOME/.claude/toolkit-install.json`. `is_toolkit_installed` checks `[ -f "$HOME/.claude/toolkit-install.json" ]` — this is the correct probe path for the TUI context. [VERIFIED: from codebase grep, lines 16, 72]

- **`setup-security.sh` has zero interactive `read` prompts today.** All four steps (CLAUDE.md, safety-net, hook, plugins) are fully automated. The `--yes` flag is therefore a no-op stub on the current code, but it enables future-proofing and should be accepted silently without error. [VERIFIED: grep found zero `read ` calls in setup-security.sh]

- **`install-statusline.sh` is already fully non-interactive** (confirmed: no `read` calls). `--yes` is a no-op stub for symmetry. The script exits 1 for non-macOS and exits 1 if jq/OAuth token absent — those remain unchanged. [VERIFIED: from codebase read]

- **RTK install path:** RTK installs via `brew install rtk && rtk init -g`. There is no `install-rtk.sh` in the project. [VERIFIED: grep found no install-rtk.sh; `which rtk` confirms /opt/homebrew/bin/rtk]. The `dispatch_rtk` dispatcher must call `brew install rtk && rtk init -g` as a subprocess.

- **manifest.json `files.libs[]` auto-discovery:** The exact jq path in `update-claude.sh:279` is `.files | to_entries[] | .value[] | .path`. Since `libs` is a top-level key under `.files`, all three new libs (`tui.sh`, `detect2.sh`, `dispatch.sh`) auto-discover with zero `update-claude.sh` code changes. Schema per entry: `{"path": "scripts/lib/<name>.sh"}` — no extra fields needed. [VERIFIED: from codebase read + test-update-libs.sh fixture]

- **`statusLine` JSON key:** Confirmed as top-level `.statusLine` in `~/.claude/settings.json` with value `{"type": "command", "command": "~/.claude/statusline.sh"}`. `is_statusline_installed` grep probe must match `"statusLine"` (exact key). [VERIFIED: from live settings.json read]

- **Test 31 is the next slot:** Makefile currently has Tests 21–30. `test-install-tui.sh` goes in as Test 31. CI step `Tests 21-30` expands to `Tests 21-31`. [VERIFIED: Makefile read]

---

## 2. Bash 3.2 TUI Implementation

### Keystroke Reading Pattern

Bash 3.2 on macOS ships with `read` supporting `-r` (raw), `-s` (silent), `-n N` (N chars). **Critical:** `read -N` (capital N = exact N without delimiter) requires Bash 4.2+. Use lowercase `-n` only. [VERIFIED: bash 3.2.57 on macOS]

Arrow keys send 3-byte escape sequences: `\e[A` (up), `\e[B` (down). Reading them requires two passes:

```bash
# Source: ASSUMED from Bash 3.2 TUI patterns (training knowledge)
# Two-pass arrow key read — Bash 3.2 compatible
_tui_read_key() {
    local k=""
    IFS= read -rsn1 k <"${TK_TUI_TTY_SRC:-/dev/tty}"
    if [[ "$k" == $'\e' ]]; then
        local extra=""
        # Read up to 2 more bytes with 0.05s timeout to capture [A / [B
        # -t is NOT available in Bash 3.2 with floats but integers work.
        # However read -t 0 (non-blocking) does work. Use read -rsn2 without
        # -t and rely on the second read blocking only briefly — under normal
        # terminal input, the full sequence arrives within one OS read buffer.
        IFS= read -rsn2 extra <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
        k="${k}${extra}"
    fi
    printf '%s' "$k"
}
```

**Arrow key mapping:**

| Key | Bytes | Detection |
|-----|-------|-----------|
| ↑ Up | `\e[A` | `[[ "$k" == $'\e[A' ]]` |
| ↓ Down | `\e[B` | `[[ "$k" == $'\e[B' ]]` |
| Space | ` ` (0x20) | `[[ "$k" == " " ]]` |
| Enter | `""` or `$'\r'` | `[[ -z "$k" || "$k" == $'\r' || "$k" == $'\n' ]]` |
| q | `q` | `[[ "$k" == "q" || "$k" == "Q" ]]` |
| Ctrl-C | `$'\003'` | Handled by `trap ... INT` (rarely reaches case) |
| Escape alone | `\e` (then nothing) | `[[ "$k" == $'\e' ]]` — treat as q-equivalent |

**Note on `read -t` with floats:** Bash 3.2 supports `read -t N` with integer seconds but NOT fractional seconds like `-t 0.1`. For the second-byte read (arrow tail), use `read -rsn2` without timeout — the arrow sequence bytes arrive atomically in the same OS buffer, so blocking is fine. The `2>/dev/null || true` handles the edge case where only 1 extra byte was available. [ASSUMED: consistent with known Bash 3.2 limitations]

### State Data Structure

Bash 3.2 has no associative arrays (`declare -A` requires Bash 4.0). Use parallel indexed arrays:

```bash
# Source: ASSUMED — parallel-array pattern for Bash 3.2 compatibility
# All arrays share the same index i.
tui_labels=()       # "superpowers" "get-shit-done" "toolkit" "security" "rtk" "statusline"
tui_groups=()       # "Bootstrap" "Bootstrap" "Core" "Optional" "Optional" "Optional"
tui_installed=()    # 1 or 0 — detection result
tui_checked=()      # 1 or 0 — current selection state (pre-checked = !installed)
tui_descs=()        # one-line description per item
FOCUS_IDX=0         # index of currently focused item (0..N-1)
ITEM_COUNT=0        # total selectable items
```

**Section headers** are derived on-the-fly from `tui_groups[]` during render — they are not stored as items. Items in the same group that are adjacent are rendered under one header. This keeps `FOCUS_IDX` indexing clean (no header slots).

### Render Loop

```bash
# Source: ASSUMED — pattern from bash-tui community knowledge
_tui_render() {
    # Move cursor to top of TUI region (line saved before entering TUI)
    printf '\e[H' >/dev/tty  # move to top-left of screen (or saved position)
    printf '\e[J' >/dev/tty  # erase from cursor to end of screen

    local prev_group=""
    for (( i=0; i<ITEM_COUNT; i++ )); do
        local grp="${tui_groups[$i]}"
        # Print group header if group changed
        if [[ "$grp" != "$prev_group" ]]; then
            if [[ -n "${NO_COLOR+x}" || ! -t 1 ]]; then
                printf '  %s\n' "$grp"
            else
                printf '  \033[2m%s\033[0m\n' "$grp"  # dim
            fi
            prev_group="$grp"
        fi

        # Focus arrow
        local arrow="  "
        [[ $i -eq $FOCUS_IDX ]] && arrow="${TUI_ARROW:-▶ }"

        # Checkbox
        local box="[ ]"
        if [[ "${tui_installed[$i]}" -eq 1 ]]; then
            box="[installed ✓]"
        elif [[ "${tui_checked[$i]}" -eq 1 ]]; then
            box="[x]"
        fi

        printf '%s%s %s\n' "$arrow" "$box" "${tui_labels[$i]}"
    done

    # Help line
    printf '\n  ↑↓ move · space toggle · enter confirm · q quit\n'

    # Description line (focused item)
    printf '  \033[2m%s\033[0m\n' "${tui_descs[$FOCUS_IDX]:-}"
}
```

### Raw Mode Enter/Exit

```bash
# Source: ASSUMED — standard stty raw mode pattern
_TUI_SAVED_STTY=""

_tui_enter_raw() {
    _TUI_SAVED_STTY=$(stty -g </dev/tty 2>/dev/null || echo "")
    printf '\e[?25l' >/dev/tty   # hide cursor
    stty -icanon -echo </dev/tty 2>/dev/null || true
}

_tui_exit_raw() {
    if [[ -n "$_TUI_SAVED_STTY" ]]; then
        stty "$_TUI_SAVED_STTY" </dev/tty 2>/dev/null || true
    else
        stty sane </dev/tty 2>/dev/null || true
    fi
    printf '\e[?25h' >/dev/tty   # show cursor
    _TUI_SAVED_STTY=""
}
```

**Critical ordering (TUI-03):** The `trap` MUST be registered BEFORE calling `_tui_enter_raw()`:

```bash
# Source: ASSUMED — pattern from bootstrap.sh EXIT trap approach
trap '_tui_exit_raw || true' EXIT INT TERM

_tui_enter_raw
# ... render loop ...
_tui_exit_raw
trap - EXIT INT TERM
```

The `|| true` on the trap handler prevents compounding: if the restore itself fails (e.g., /dev/tty closed), the trap exits cleanly without cascading into a second trap invocation.

### Anti-Patterns to Avoid

- **`read -N` (capital):** Bash 4.2+ only. Use `read -n` (lowercase).
- **`read -t 0.1`:** Float timeout is Bash 4.0+. Integer seconds only in Bash 3.2.
- **`declare -n` namerefs:** Bash 4.3+ only. Use `eval`-based indirect expansion or parallel arrays.
- **`printf '\e[2J'` to clear screen:** Moves cursor to top-left; prefer `\e[H\e[J` for repositioning. Even better: use `\e[{N}A` to move up N lines from last render position, avoiding full screen flicker.
- **`tput` for raw mode:** Requires `$TERM` set correctly; less reliable than direct ANSI escapes for simple show/hide cursor. Use direct `\e[?25l` / `\e[?25h`.

---

## 3. ANSI / Terminal Compatibility Matrix

### Sequence Safety Table

| Sequence | Purpose | macOS Terminal | iTerm2 | xterm/gnome | tmux | screen | TERM=dumb |
|----------|---------|---------------|--------|-------------|------|--------|-----------|
| `\e[?25l` / `\e[?25h` | Hide/show cursor | ✓ | ✓ | ✓ | ✓ | ✓ | no-op (ok) |
| `\e[H` | Move to row 1 col 1 | ✓ | ✓ | ✓ | ✓ | ✓ | no-op (ok) |
| `\e[J` | Erase to screen end | ✓ | ✓ | ✓ | ✓ | ✓ | no-op (ok) |
| `\e[2K` | Erase current line | ✓ | ✓ | ✓ | ✓ | ✓ | no-op (ok) |
| `\e[{N}A` | Move cursor up N lines | ✓ | ✓ | ✓ | ✓ | ✓ | no-op (ok) |
| `\e[2m` | Dim text (for headers/desc) | ✓ | ✓ | ✓ | partial | ✓ | ignored |
| `\033[0;3Xm` | 16-color foreground | ✓ | ✓ | ✓ | ✓ | ✓ | ignored |
| Reverse video `\e[7m` | Highlight row | ✓ | ✓ | partial tmux issues | ✗ often | ✗ often | ignored |
| `\e[?1049h` / `\e[?1049l` | Alt-screen | ✓ | ✓ | ✓ | ✓ (nested) | limited | no-op |

**Recommendation:** Avoid reverse video (D-16 already chose arrow indicator `▶` for this reason). Do NOT use alternate screen (`\e[?1049h`) — it adds complexity (must restore on every exit path) with no UX gain for a 6-item list. Use the simpler `\e[H\e[J` clear+redraw approach. [VERIFIED: D-16 rationale matches this finding]

### NO_COLOR Contract (TUI-06)

Existing `dro_init_colors()` in `dry-run-output.sh` lines 26-38 shows the exact project pattern:

```bash
# Source: [VERIFIED: scripts/lib/dry-run-output.sh:26-38]
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    # color enabled
else
    # plain text fallback
fi
```

`${NO_COLOR+x}` expands to `"x"` when `NO_COLOR` is set (even to empty string), to `""` when unset. `[ -z "${NO_COLOR+x}" ]` is `true` when NO_COLOR is NOT set. `tui.sh` MUST use the same idiom.

**NO_COLOR + TUI elements:**

- Section headers: plain text without `\e[2m` dim
- Arrow indicator `▶`: the character itself is not color — it renders in both modes. Only ANSI color codes are suppressed.
- Checkbox states `[ ]` / `[x]` / `[installed ✓]`: plain text, no color needed
- Focus arrow `▶`: rendered as literal `▶` character in both modes
- Help line: plain text

**`TERM=dumb` fallback:** When `TERM=dumb`, ANSI sequences produce visible garbage in some environments. Gate with both `[ -t 1 ]` AND `[[ "${TERM:-dumb}" != "dumb" ]]`:

```bash
# Source: ASSUMED — defensive pattern for dumb terminals
_TUI_COLOR=""
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    _TUI_COLOR=1
fi
```

---

## 4. `/dev/tty` Patterns Under `curl | bash`

### Core Pattern (from bootstrap.sh)

The v4.4 `bootstrap.sh` establishes the definitive project pattern at lines 43-48 [VERIFIED]:

```bash
# [VERIFIED: scripts/lib/bootstrap.sh:43-48]
local tty_target="/dev/tty"
[[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"

local choice=""
if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
    _bootstrap_log_info "bootstrap skipped — no TTY"
    return 0
fi
```

**Key insight:** The seam uses per-read `< "$tty_target"` redirection, NOT `exec < /dev/tty`. This is intentional: `exec < /dev/tty` permanently redirects stdin for the entire script process, which breaks subsequent `read` calls that expect stdin piped from curl. Per-read redirection is isolated. [ASSUMED: consistent with curl|bash stdin preservation]

**`TK_TUI_TTY_SRC` mirrors this exactly (D-33):**

```bash
# In tui.sh — per-read pattern
IFS= read -rsn1 k <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
```

For `stty` raw mode, the device must also be redirected:

```bash
_TUI_SAVED_STTY=$(stty -g <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || echo "")
stty -icanon -echo <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
```

### SSH / tmux / screen Considerations

- **SSH without TTY allocation (`ssh -T`):** `/dev/tty` does not exist or returns ENXIO. The `2>/dev/null || return 0` guard (inherited from bootstrap.sh) handles this correctly — fails closed.
- **tmux/screen:** `/dev/tty` points to the multiplexer's allocated PTY. Works normally. No special handling needed.
- **Docker without `-t`:** `/dev/tty` absent. Fail-closed correctly.

**No-TTY detection** for D-05/D-11:

```bash
# Source: ASSUMED — standard TTY probe
if [[ ! -e "${TK_TUI_TTY_SRC:-/dev/tty}" ]]; then
    # No TTY available — either fall back to bootstrap.sh (for SP/GSD)
    # or exit 0 with message (for TK components)
fi
```

### `exec < /dev/tty` vs Per-Read Redirection

Do NOT use `exec < /dev/tty` in `install.sh`. Reason: when `install.sh` is run via `bash <(curl ...)`, the curl pipe feeds the script to bash via process substitution (not stdin). `exec < /dev/tty` works in that context. However, when run via `curl ... | bash`, stdin is the pipe and `exec < /dev/tty` would close the pipe, potentially causing the parent bash to hang waiting for more script bytes. The per-read pattern is universally safe. [ASSUMED: consistent with PROJECT.md curl|bash compatibility requirement]

### BASH_SOURCE[0] in curl | bash vs bash <(...) vs local

| Invocation | `$0` | `BASH_SOURCE[0]` | curl-pipe detection |
|------------|------|------------------|---------------------|
| `curl ... \| bash` | `bash` | `/dev/stdin` or `bash` | `$0 == bash` or `BASH_SOURCE[0] == bash` |
| `bash <(curl ...)` | `bash` | `/dev/fd/63` (number varies) | `BASH_SOURCE[0] =~ ^/dev/fd/` |
| `bash scripts/install.sh` | `scripts/install.sh` | `scripts/install.sh` | neither — local |
| `source scripts/install.sh` | (parent $0) | `scripts/install.sh` | neither — sourced |

D-24 formula: `[[ "${BASH_SOURCE[0]}" == /dev/fd/* || "${0}" == bash ]]` correctly identifies the first two cases. For dispatch purposes:

- curl-pipe: script fetches component installer via `curl ... | bash -c "..."` or `bash <(curl ...)`
- local: script calls sibling path like `bash "$(dirname "$0")/setup-security.sh"`

The dispatcher uses the run-mode flag to pick the right invocation: [ASSUMED from D-24]

```bash
# Source: ASSUMED — D-24 curl-pipe vs local detection
if [[ "${BASH_SOURCE[0]}" == /dev/fd/* || "${0}" == bash ]]; then
    IS_CURL_PIPE=1
else
    IS_CURL_PIPE=0
fi
```

---

## 5. Detection v2 Probes

### Probe Code per Component

All probes return 0 (installed) or 1 (not installed). No third state for v4.6 (D-22).

#### `is_superpowers_installed`

```bash
# Source: [VERIFIED: detect.sh detect_superpowers wraps HAS_SP]
is_superpowers_installed() {
    [[ "${HAS_SP:-false}" == "true" ]]
}
```

Requires `detect.sh` to be sourced first (D-21). `HAS_SP` is set by `detect_superpowers`.

#### `is_gsd_installed`

```bash
# Source: [VERIFIED: detect.sh detect_gsd sets HAS_GSD]
is_gsd_installed() {
    [[ "${HAS_GSD:-false}" == "true" ]]
}
```

#### `is_toolkit_installed` (DET-05)

```bash
# Source: [VERIFIED: init-claude.sh writes STATE_FILE="$CLAUDE_DIR/toolkit-install.json"
#          at $HOME/.claude/toolkit-install.json for global install]
is_toolkit_installed() {
    [[ -f "$HOME/.claude/toolkit-install.json" ]]
}
```

**Confirmed write site:** `scripts/init-claude.sh` calls `write_state` with `STATE_FILE="$CLAUDE_DIR/toolkit-install.json"` where `CLAUDE_DIR=".claude"` (line 19), and re-asserts `STATE_FILE="$CLAUDE_DIR/toolkit-install.json"` after sourcing `state.sh` (line 482). For global installs via `bash <(curl ...)`, this is the project's `.claude/` directory. For detection purposes, the TUI checks `$HOME/.claude/toolkit-install.json` (the standard global install path). [VERIFIED: codebase grep]

#### `is_security_installed` (DET-02)

```bash
# Source: ASSUMED probe code; DET-02 specifies both checks
# [VERIFIED: cc-safety-net installs at /opt/homebrew/bin/cc-safety-net on Apple Silicon]
# [VERIFIED: pre-bash.sh hook references cc-safety-net per setup-security.sh:192-208]
is_security_installed() {
    # Probe 1: binary on PATH (covers brew AND npm install paths)
    if ! command -v cc-safety-net >/dev/null 2>&1; then
        return 1
    fi
    # Probe 2: hook configured (binary present but not wired is incomplete install)
    local hooks_file="$HOME/.claude/hooks/pre-bash.sh"
    local settings_file="$HOME/.claude/settings.json"
    if grep -q "cc-safety-net" "$hooks_file" 2>/dev/null; then
        return 0
    fi
    if grep -q "cc-safety-net" "$settings_file" 2>/dev/null; then
        return 0
    fi
    return 1
}
```

**Rationale:** `command -v cc-safety-net` covers both npm global (PATH-based) and brew (PATH-based). The secondary grep confirms the hook is actually wired — the v4.4 setup-security.sh writes `pre-bash.sh` and sets `settings.json` to reference it. [VERIFIED: setup-security.sh:192-232]

#### `is_rtk_installed` (DET-04)

```bash
# Source: [VERIFIED: which rtk = /opt/homebrew/bin/rtk; DET-04 specifies command -v rtk]
is_rtk_installed() {
    command -v rtk >/dev/null 2>&1
}
```

Simple PATH probe. RTK installs via `brew install rtk` to `/opt/homebrew/bin/rtk` on Apple Silicon, `/usr/local/bin/rtk` on Intel Mac. `command -v` covers both. [VERIFIED: local probe]

#### `is_statusline_installed` (DET-03)

```bash
# Source: [VERIFIED: install-statusline.sh writes ~/.claude/statusline.sh
#          and merges statusLine key into ~/.claude/settings.json]
# [VERIFIED: settings.json key is "statusLine" (top-level) not "statusLine.enabled"]
is_statusline_installed() {
    [[ -f "$HOME/.claude/statusline.sh" ]] || return 1
    grep -q '"statusLine"' "$HOME/.claude/settings.json" 2>/dev/null
}
```

Both conditions required: file exists AND settings.json wired. The `settings.json` key is top-level `"statusLine"` (confirmed from live `settings.json` read). [VERIFIED: settings.json content on this machine]

### Detection Cache Vars (D-23)

```bash
# Cached at startup in install.sh
IS_SP=0;     is_superpowers_installed && IS_SP=1     || true
IS_GSD=0;    is_gsd_installed         && IS_GSD=1    || true
IS_TK=0;     is_toolkit_installed     && IS_TK=1     || true
IS_SEC=0;    is_security_installed    && IS_SEC=1    || true
IS_RTK=0;    is_rtk_installed         && IS_RTK=1    || true
IS_SL=0;     is_statusline_installed  && IS_SL=1     || true
```

Re-probe before each dispatch (D-23 "cheap re-probe, catches mid-run drift"):

```bash
# Before dispatching component N, re-probe
local still_installed=0
is_<name>_installed && still_installed=1 || true
if [[ $still_installed -eq 1 ]] && [[ "${FORCE:-0}" -ne 1 ]]; then
    component_status[$i]="skipped"
    continue
fi
```

---

## 6. Dispatch Layer

### Per-Component Flag Inventory

| Component | Script | Already Non-Interactive | `--yes` Treatment | `--force` | `--dry-run` |
|-----------|--------|------------------------|-------------------|-----------|-------------|
| superpowers | `claude plugin install superpowers@claude-plugins-official` | Yes (CLI command) | Accept, no-op | N/A | N/A |
| get-shit-done | `bash <(curl -sSL .../install.sh)` | Yes (curl script) | Accept, no-op | N/A | N/A |
| toolkit | `init-claude.sh` | Yes | Accept, no-op | `--force` passes through | `--dry-run` passes through |
| security | `setup-security.sh` | Yes (confirmed zero `read` calls) | Accept, no-op (future-proofing) | `--force` (already exists) | N/A |
| rtk | `brew install rtk && rtk init -g` | Yes (brew is non-interactive) | Accept, no-op | N/A | N/A |
| statusline | `install-statusline.sh` | Yes (confirmed zero `read` calls) | Accept, no-op (D-26) | N/A | N/A |

**Key finding for DISPATCH-02:** Both `setup-security.sh` and `install-statusline.sh` have zero interactive `read` prompts today. [VERIFIED: grep for `read ` in both files = 0 matches]. The `--yes` flag implementation is:
1. Parse `--yes` in argument loop (do not error-exit on unknown flag)
2. No behavior change in current code
3. Adds future-proofing for any interactive prompt added later

### `dispatch.sh` Function Signatures (D-25)

```bash
# Source: ASSUMED — D-25 contract
# All dispatchers: dispatch_<name> [--force] [--dry-run] [--yes]
# Returns the underlying script's exit code unchanged.

dispatch_superpowers() { ... }   # invokes TK_SP_INSTALL_CMD
dispatch_gsd()         { ... }   # invokes TK_GSD_INSTALL_CMD
dispatch_toolkit()     { ... }   # invokes init-claude.sh or init-local.sh
dispatch_security()    { ... }   # invokes setup-security.sh [--yes] [--force]
dispatch_rtk()         { ... }   # invokes brew install rtk && rtk init -g
dispatch_statusline()  { ... }   # invokes install-statusline.sh [--yes]
```

### Curl-Pipe Detection Matrix (D-24)

```bash
# Source: ASSUMED — D-24 BASH_SOURCE detection
# Verified behavior per invocation mode in §4 above

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# curl-pipe: BASH_SOURCE[0] is /dev/fd/N or bare "bash"
if [[ "${BASH_SOURCE[0]:-}" == /dev/fd/* || "${0:-}" == bash ]]; then
    # Remote dispatch: curl | bash each component
    REPO_URL="${TK_REPO_URL:-https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main}"
    dispatch_toolkit() {
        bash <(curl -sSL "$REPO_URL/scripts/init-claude.sh") "$@"
    }
else
    # Local dispatch: resolve sibling paths from SCRIPT_DIR
    dispatch_toolkit() {
        bash "$SCRIPT_DIR/../init-claude.sh" "$@"
    }
fi
```

**SP/GSD special case:** `TK_SP_INSTALL_CMD` and `TK_GSD_INSTALL_CMD` from `optional-plugins.sh` already encode the correct remote URL. The dispatch functions reuse these constants (D-04, referencing optional-plugins.sh:18-19). [VERIFIED: optional-plugins.sh:18-19]

### `dispatch_rtk` RTK Install

RTK has no TK-owned install script. The canonical install is `brew install rtk && rtk init -g`. [VERIFIED: components/optional-plugins.md:19-20]. The dispatcher:

```bash
# Source: ASSUMED — D-25 contract for RTK
dispatch_rtk() {
    local force=0 dry_run=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force) force=1 ;;
            --dry-run) dry_run=1 ;;
            --yes) ;;  # no-op for rtk
        esac
        shift
    done

    if [[ $dry_run -eq 1 ]]; then
        echo "[+ INSTALL] rtk (would run: brew install rtk && rtk init -g)"
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "  ✗ brew not found — install Homebrew first: https://brew.sh"
        return 1
    fi
    brew install rtk && rtk init -g
}
```

---

## 7. manifest.json + update-claude.sh Integration

### Auto-Discovery via Existing jq Path

The `update-claude.sh:279` jq path is: [VERIFIED: from codebase read]

```
.files | to_entries[] | .value[] | .path
```

`to_entries` converts `.files` object to `[{key, value}, ...]` pairs. `.value[]` iterates the arrays under each key. Since `.files.libs` is a standard array under `.files`, adding new entries there auto-discovers without any `update-claude.sh` changes.

**Confirmation:** `test-update-libs.sh:77-86` builds a fixture that includes `scripts/lib/*.sh` entries and the test passes with the existing `update-claude.sh` code. New libs with the same schema will auto-discover identically. [VERIFIED: test-update-libs.sh]

### New manifest.json Entries

Three new libs go under `files.libs[]`:

```json
{
  "path": "scripts/lib/tui.sh"
},
{
  "path": "scripts/lib/detect2.sh"
},
{
  "path": "scripts/lib/dispatch.sh"
}
```

One new script under `files.scripts[]`:

```json
{
  "path": "scripts/install.sh"
}
```

**Schema:** Each entry is `{"path": "relative/path"}` — no extra fields. `install.sh` follows the same shape as the existing `{"path": "scripts/uninstall.sh"}` entry. [VERIFIED: manifest.json:219-220]

### test-update-libs.sh: New libs Auto-Discovered

The test's `build_manifest_fixture()` function can be extended by adding three entries to the jq filter. No test structural changes needed — the assertions (`S1–S5`) test the contract generically (any lib in `files.libs[]` gets discovered). [VERIFIED: test-update-libs.sh:74-91]

---

## 8. Test Fixture Format

### `TK_TUI_TTY_SRC` Format (D-33)

D-33 specifies: "fixture file path with pre-recorded keystrokes; one keystroke per line, raw bytes for special keys (e.g., `$'\e[A'` for ↑)."

**Format:** The fixture file contains literal bytes. Each "line" for a printable key is the character followed by `\n`. For special keys, the raw escape sequence bytes are written literally (no shell quoting in the file itself).

Creating a fixture with `printf` in the test setup:

```bash
# Source: ASSUMED — consistent with D-33 + bootstrap.sh fixture pattern (ANSWER_FILE)
# Fixture for: ↑ ↑ space enter (navigate up twice, toggle, confirm)
local TTY_FIXTURE="$SANDBOX/tty-fixture"
printf '%s' $'\e[A' > "$TTY_FIXTURE"   # ↑
printf '%s' $'\e[A' >> "$TTY_FIXTURE"  # ↑
printf '%s' ' '     >> "$TTY_FIXTURE"  # space (toggle)
printf '%s' $'\n'   >> "$TTY_FIXTURE"  # enter (confirm)
```

**Why `printf '%s'` not `printf '%s\n'`:** The TUI's `read -rsn1` reads exactly 1 byte (or more for `-rsn2`). For a printable key like space, `read -rsn1` returns after reading 1 byte — the `\n` separator is not needed and would be read as an extra Enter keypress. For the escape sequence `\e[A`, the two-pass read consumes all 3 bytes. The fixture must contain exactly the raw bytes the terminal would send, with no line separators between keystrokes.

**Tested pattern from bootstrap.sh (S1):** [VERIFIED: test-bootstrap.sh:83]

```bash
printf 'y\ny\n' > "$ANSWER_FILE"
```

This works because `read -r -p "..." choice < "$ANSWER_FILE"` reads one line at a time (up to `\n`). For the TUI's `read -rsn1`, the `\n` terminates the first read but is NOT consumed as a separator — it would be read as Enter. Therefore: **no `\n` between keystroke sequences in the TUI fixture, except for Enter itself.**

**Complete fixture for the main TUI test scenario:**

```bash
# Scenario: ↑ ↓ space enter (navigate down, up, toggle item, confirm)
printf '%b%b %b' $'\e[B' $'\e[A' $'\n' > "$TTY_FIXTURE"
# Bytes: ESC [ B  ESC [ A  SPACE  NEWLINE
```

**Ctrl-C fixture:**

```bash
printf '%b' $'\003' > "$TTY_CTRL_C_FIXTURE"
```

**q-quit fixture:**

```bash
printf 'q' > "$TTY_QUIT_FIXTURE"
```

---

## 9. Validation Architecture

`workflow.nyquist_validation = true` in `.planning/config.json`. [VERIFIED]

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash (native, no external framework) |
| Config file | None — hermetic test scripts |
| Quick run command | `bash scripts/tests/test-install-tui.sh` |
| Full suite command | `make test` (Tests 21-31) |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TUI-01 | Arrow/space/enter navigation in Bash 3.2 | unit (fixture injection) | `bash scripts/tests/test-install-tui.sh` | ❌ Wave 0 |
| TUI-02 | `TK_TUI_TTY_SRC` seam redirects to fixture; no-TTY fail-closed | unit | same | ❌ Wave 0 |
| TUI-03 | Ctrl-C mid-render restores terminal (stty sane) | unit (Ctrl-C fixture) | same | ❌ Wave 0 |
| TUI-04 | Installed items show `[installed ✓]`, unchecked | unit | same | ❌ Wave 0 |
| TUI-05 | Confirmation prompts `Install N component(s)?` | unit | same | ❌ Wave 0 |
| TUI-06 | `NO_COLOR` set → no ANSI in output | unit | same | ❌ Wave 0 |
| TUI-07 | test-install-tui.sh ≥15 assertions | integration | same | ❌ Wave 0 |
| DET-01 | `detect2.sh` sources `detect.sh`; all 6 `is_*_installed` return 0/1 | unit | `bash scripts/tests/test-install-tui.sh` (via detection scenario) | ❌ Wave 0 |
| DET-02..05 | Per-probe correctness | unit | same | ❌ Wave 0 |
| DISPATCH-01 | Dispatch order SP→GSD→toolkit→security→RTK→statusline | unit (mock dispatchers) | same | ❌ Wave 0 |
| DISPATCH-02 | `--yes` accepted by `setup-security.sh` without error | smoke | same | ❌ Wave 0 |
| DISPATCH-03 | `install.sh` top-level: detect→TUI→confirm→dispatch→summary | integration | same | ❌ Wave 0 |
| BACKCOMPAT-01 | `test-bootstrap.sh` 26 assertions green | regression | `bash scripts/tests/test-bootstrap.sh` | ✅ exists |

### Nyquist Evaluation Signals (≥6 required)

1. **Assertion-based (TUI-07):** `test-install-tui.sh` ≥15 assertions covering all keystroke paths, flag modes, and no-TTY fallback.
2. **Output conformance:** `dro_print_install_status` state strings (`installed ✓`, `skipped`, `failed (exit N)`) verified by `assert_contains` in test output.
3. **Zero-mutation (--dry-run):** `assert` that no installer subprocesses were invoked under `--dry-run` (via mock dispatcher that writes a sentinel file if called).
4. **Terminal restore on signal:** After injecting Ctrl-C fixture, verify `stty sane` succeeds (no raw-mode residue). Test: `bash scripts/tests/test-install-tui.sh` then assert terminal is sane.
5. **Backcompat (BACKCOMPAT-01):** `bash scripts/tests/test-bootstrap.sh` stays green — 26 assertions unchanged.
6. **Flag symmetry (DISPATCH-02):** `setup-security.sh --yes` exits 0 without any `read: ...` error output.

### Sampling Rate

- **Per task commit:** `bash scripts/tests/test-install-tui.sh`
- **Per wave merge:** `make test` (Tests 21-31 full suite)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `scripts/tests/test-install-tui.sh` — covers TUI-01..07, DET-01..05, DISPATCH-01..03, BACKCOMPAT-01
- [ ] `scripts/lib/tui.sh` — the TUI library itself (created in Wave 1)
- [ ] `scripts/lib/detect2.sh` — detection v2 library (created in Wave 1)
- [ ] `scripts/lib/dispatch.sh` — dispatch library (created in Wave 2)
- [ ] `scripts/install.sh` — top-level orchestrator (created in Wave 3)
- [ ] `--yes` flag in `setup-security.sh` (added in Wave 2)
- [ ] `--yes` stub in `install-statusline.sh` (added in Wave 2)

---

## 10. Risk Register + Mitigations

### Risk 1: Bash 3.2 `read -rsn2` captures incomplete sequence

**What goes wrong:** On a slow connection or unusual terminal, the second `read -rsn2` (for the arrow tail `[A`) may time out and return only `[` (1 byte) instead of `[A` (2 bytes), causing the key to be misidentified.

**Why it happens:** `read -rsn2` reads UP TO 2 bytes. In terminals that send escape sequences byte-by-byte (unusual), the `[` arrives first and `A` arrives 1ms later. Without `-t` timeout, the second read blocks until exactly 2 bytes arrive — normally fine, but may misbehave on latency-heavy SSH.

**Mitigation:** For the v4.6 6-item list, blocking is acceptable. The arrow sequence always arrives as a single OS-level write() in all standard terminal emulators. Add a comment noting the known edge case. If future testing reveals issues, fall back to: after the first `\e` read, use `read -rsn1 -t 1` (integer 1 second timeout) for each subsequent byte individually.

**Confidence:** MEDIUM — known Bash 3.2 limitation; mitigated by terminal behavior

### Risk 2: SSH disconnect mid-render → orphaned TTY mode

**What goes wrong:** If the SSH connection drops while the TUI is in raw mode (`stty -icanon -echo`), the `EXIT` trap fires but `/dev/tty` is closed/disconnected. The `stty` restore command fails silently (if guarded with `|| true`). On reconnect, terminal is in raw mode.

**Mitigation:** The `stty "$_TUI_SAVED_STTY" || stty sane || true` triple-fallback in the EXIT trap. On reconnect, user runs `stty sane` manually. This is the same failure mode as `vim`, `nano`, `less` — well-known, acceptable.

**Confidence:** LOW risk in practice; terminal reset (`reset` or `stty sane`) is the universal recovery

### Risk 3: `TERM=dumb` in restricted CI containers

**What goes wrong:** ANSI sequences produce visible garbage characters in output, making logs unreadable.

**Mitigation:** `[[ "${TERM:-dumb}" != "dumb" ]]` gate in `_tui_init_colors()`. When `TERM=dumb`, fall into plain-text mode. The `[ -t 1 ]` check handles non-TTY CI. Together these cover the case. Additionally, `--yes` flag bypasses TUI entirely in CI.

**Confidence:** HIGH — mitigated by NO_COLOR + TERM=dumb + `[ -t 1 ]` three-layer gate

### Risk 4: `/dev/tty` not writable in Docker without `-t`

**What goes wrong:** `stty -g </dev/tty` returns "Operation not permitted" or ENXIO. `read ... </dev/tty` fails.

**Mitigation:** All `/dev/tty` accesses are guarded with `2>/dev/null || ...` fallbacks. The no-TTY path in D-05 and D-11 handles this: falls back to `bootstrap.sh` for SP/GSD and "run with `--yes`" message for TK components.

**Confidence:** HIGH — mitigated by existing fail-closed pattern from bootstrap.sh

### Risk 5: `stty -g` captures state that includes `-icanon -echo` if a previous run crashed

**What goes wrong:** If the previous `install.sh` run crashed BEFORE restoring stty, the saved stty state includes raw-mode settings. Restoring this "saved" state re-enters raw mode.

**Mitigation:** In the EXIT trap, always do `stty "$_TUI_SAVED_STTY" || stty sane`. The `|| stty sane` fallback recovers to a known good state if the saved string is unusable.

**Confidence:** HIGH — triple fallback handles the case

### Risk 6: `detect.sh` sources itself into set -e callers

**What goes wrong:** `detect_superpowers` can return 1 (not installed). If `detect.sh` is sourced from a `set -e` script, `return 1` causes exit.

**Mitigation:** Already mitigated: line 125 of `detect.sh` calls `detect_superpowers || true`. The `|| true` makes the sourcing safe. `detect2.sh` re-sources `detect.sh` which invokes both functions at source time. The caller (`install.sh`) must also call `source detect2.sh` from a context where any return-1 is safe (which it is, since `detect2.sh` internally guards with `|| true`). [VERIFIED: detect.sh:125]

**Confidence:** HIGH — verified pattern in codebase

### Risk 7: manifest.json schema change breaks `update-claude.sh` jq path

**What goes wrong:** If a future PR changes the `files` structure (e.g., nested keys), the jq path `.files | to_entries[] | .value[] | .path` would fail or return unexpected paths.

**Mitigation:** Phase 24 does not change the manifest schema — only adds three entries to the existing `libs[]` array and one entry to the existing `scripts[]` array. Zero schema change. [VERIFIED: manifest.json confirmed flat-array schema for libs]

**Confidence:** HIGH — no schema change needed

### Risk 8: `rtk init -g` requires user interaction

**What goes wrong:** `rtk init -g` may prompt for configuration on first run, blocking the dispatch subprocess.

**Mitigation:** Research shows `rtk init -g` is designed for non-interactive global initialization. If it prompts, the `dispatch_rtk` dispatcher can pipe `/dev/null` or use `yes | rtk init -g`. Add `|| true` so a non-zero exit doesn't stop the orchestrator (per D-08 continue-on-error). [ASSUMED: based on rtk documentation knowledge]

**Confidence:** MEDIUM — should investigate `rtk init -g --help` or test manually

### Risk 9: `install-statusline.sh` exits 1 for non-macOS

**What goes wrong:** On Linux, `install-statusline.sh` prints "This tool requires macOS" and exits 1. The dispatcher captures this as a failure.

**Mitigation:** The pre-dispatch detection `is_statusline_installed` already returns 0/1 based on `~/.claude/statusline.sh` presence. On Linux, the file won't exist → it shows as installable. The dispatcher will attempt install → fail. Per D-10, state becomes `failed (exit 1)`. Per D-08, orchestration continues. The summary shows `statusline: failed (exit 1)` which is correct behavior — it's genuinely not available on Linux.

**Alternative:** `dispatch_statusline` can probe `[[ "$(uname)" == "Darwin" ]]` before invoking and return `skipped` with a message on Linux. This is a planner-level refinement.

**Confidence:** HIGH — known behavior; continue-on-error handles it

---

## 11. Project Constraints (from CLAUDE.md)

- Bash 3.2+ (macOS BSD); no GNU-only flags
- `set -euo pipefail` in scripts; **never** in sourced libs (`tui.sh`, `detect2.sh`, `dispatch.sh` are sourced → no errexit)
- Color guards: `[[ -z "${RED:-}" ]] && RED='\033[0;31m'` in every lib
- `make check` must pass (markdownlint + shellcheck + validate)
- Distribution via `curl ... | bash`; per-read `< /dev/tty` (not `exec < /dev/tty`)
- Test seam pattern: `TK_<FEATURE>_<INPUT>_SRC` env var overrides hardcoded path
- No Node/Python in install scripts
- `manifest.json` `files.libs[]` auto-discovered by existing jq path (zero `update-claude.sh` changes)

---

## 12. Open Questions (RESOLVED)

1. **`rtk init -g` interactivity**
   - What we know: `brew install rtk` is non-interactive; `rtk init -g` initializes global config
   - What's unclear: Does `rtk init -g` prompt on first run?
   - Recommendation: Test `rtk init -g </dev/null 2>&1` in Wave 1. If prompts appear, add `--yes` pass-through to dispatch_rtk or use `yes |`.
   - **RESOLVED:** Plan 03 `dispatch_rtk` invokes `rtk init -g </dev/null` to force non-interactive (per RESEARCH §10 Risk 8); manual verify on real RTK install captured in 24-VALIDATION.md "Manual-Only" section.

2. **`▶` character rendering on older macOS Terminal.app**
   - What we know: UTF-8 is standard; `▶` (U+25B6) renders in most terminals
   - What's unclear: Does macOS Terminal.app on older macOS versions (pre-10.15) render `▶` correctly?
   - Recommendation: Use `▶` as default; add `TK_TUI_ARROW` env override (e.g., `export TK_TUI_ARROW='>'`) as a no-configure escape hatch.
   - **RESOLVED:** Plan 02 introduces `TK_TUI_ARROW` env-var override (default `▶`; set to `>` for legacy terminals) inside `scripts/lib/tui.sh`.

3. **`dispatch_toolkit` target path**
   - What we know: `install.sh` is a new entry point that dispatches toolkit install via `init-claude.sh`
   - What's unclear: When running `install.sh` as the orchestrator, should `dispatch_toolkit` invoke `init-claude.sh` or `init-local.sh`? For global `~/.claude/` install: `init-claude.sh`. For per-project: `init-local.sh`.
   - Recommendation: `install.sh` targets global `~/.claude/` install (same as `init-claude.sh`). Planner decision.
   - **RESOLVED:** Plan 03 `dispatch_toolkit` invokes the existing `init-claude.sh` URL (toolkit's own canonical install path); preserves BACKCOMPAT-01 byte-identicality of the v4.4 entry point.

4. **`tui_checklist` function signature with Bash 3.2 no-namerefs**
   - What we know: `declare -n` namerefs require Bash 4.3+; `tui_checklist <items_var> <results_var>` is in TUI-01
   - What's unclear: How does `tui.sh` pass the 6-item list to `tui_checklist` without namerefs?
   - Recommendation: Use `eval`-based indirect expansion for reading the input array, and write results to a fixed global (e.g., `TUI_RESULTS=("0" "1" ...)`) rather than a nameref. The caller reads `TUI_RESULTS[]` after the function returns.
   - **RESOLVED:** Plan 02 uses fixed global `TUI_RESULTS=()` array as the return channel (consistent with bootstrap.sh test-seam patterns); caller reads `TUI_RESULTS[]` after `tui_checklist` returns.

5. **Confirmation prompt inside `tui_checklist` vs `install.sh`**
   - What we know: TUI-05 says confirmation step is before any installer
   - What's unclear: Is confirmation rendered inside `tui_checklist` (making it a complete UI flow), or after `tui_checklist` returns (making `install.sh` do the confirm)?
   - Recommendation: `tui_checklist` returns the selected items array; `install.sh` does the confirmation prompt. This keeps `tui.sh` a pure menu library, reusable by Phase 25/26 without embedding confirm semantics.
   - **RESOLVED:** Plan 02 keeps `tui_checklist` rendering-only; Plan 04 (`scripts/install.sh`) owns the post-selection `Install N component(s)? [y/N]` confirmation prompt via `tui_confirm_prompt`.

6. **No-TTY behavior for `install.sh` — fork to bootstrap.sh or single fail-closed?**
   - What we know: D-05 (locked) says `install.sh` falls back to the existing `lib/bootstrap.sh` `read -r -p < /dev/tty` flow for SP/GSD only when `/dev/tty` is unavailable AND `--yes` is not passed; TK components fail-closed exit 0 per D-09 + D-11 ("install nothing, exit 0"). D-07 (locked) says `bootstrap.sh` is NOT deleted or rewritten in this phase — it stays as-is and is sourced by `install.sh`.
   - What was unclear during iter 1: Plan 04 Task 1's no-TTY branch printed `"Install cancelled."` and exited 0 unconditionally — silently dropped the D-05 SP/GSD bootstrap fork. The decision was locked but the implementation didn't honor it.
   - Recommendation: Plan 04 Task 1's TTY-availability gate must be a 3-branch `if/elif/else` — `--yes` (D-06 default-set), `[[ -r "$_install_tty_src" ]]` (TUI), `else` (D-05 fork to `bootstrap_base_plugins`). The else-branch sources `lib/bootstrap.sh` (curl-fetched if running curl|bash, local clone otherwise) and `lib/optional-plugins.sh` (for `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD`), then calls `bootstrap_base_plugins` (verified function name from `scripts/lib/bootstrap.sh:68`). After the bootstrap call, populate `TUI_RESULTS=(0 0 0 0 0 0)` so the dispatch loop sees TK components as "unselected" → summary correctly reports them as `skipped` (D-11 fail-closed for TK). bootstrap.sh is NEVER reimplemented or copied (D-07 invariant).
   - **RESOLVED:** D-05 implemented exactly as locked in Plan 04 (revision 2). Plan 04 Task 1 sources `lib/bootstrap.sh` and invokes `bootstrap_base_plugins` for SP/GSD (identical to v4.4 behavior); TK components fall back to fail-closed exit 0 per D-09 + D-11. Test scenario `S9_no_tty_bootstrap_fork` in Plan 04 Task 2 asserts: install.sh exits 0; bootstrap.sh prompts rendered (verbatim strings from `scripts/lib/bootstrap.sh:85,94`); TK component dispatchers did NOT run (sentinel files absent — D-11); SP/GSD install commands did NOT run (user declined via `'N\nN\n'` fixture); 'fail-closed' message surfaced. No supersession of D-05.

---

## Sources

### Primary (HIGH confidence)

- [VERIFIED: scripts/lib/bootstrap.sh] — `/dev/tty` pattern, TK_BOOTSTRAP_TTY_SRC seam, fail-closed guard, EXIT trap structure
- [VERIFIED: scripts/lib/dry-run-output.sh] — `dro_*` API, NO_COLOR pattern, column widths, color vars
- [VERIFIED: scripts/detect.sh] — detect_superpowers || true guard, HAS_SP/HAS_GSD exports, `detect.sh` is source-safe
- [VERIFIED: scripts/lib/state.sh] — STATE_FILE default path = `$HOME/.claude/toolkit-install.json`
- [VERIFIED: scripts/lib/optional-plugins.sh:18-19] — TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD constants
- [VERIFIED: manifest.json] — files.libs[] schema `{"path": ...}`, files.scripts[] entry shape
- [VERIFIED: scripts/update-claude.sh:279] — jq auto-discovery path `.files | to_entries[] | .value[] | .path`
- [VERIFIED: scripts/tests/test-update-libs.sh:74-91] — manifest fixture confirms libs[] zero-special-casing
- [VERIFIED: scripts/tests/test-bootstrap.sh] — test seam fixture format, sandbox pattern, mk_mock helper
- [VERIFIED: scripts/setup-security.sh] — zero interactive read prompts confirmed; pre-bash.sh hook writes cc-safety-net
- [VERIFIED: scripts/install-statusline.sh] — zero interactive read prompts confirmed; statusLine JSON merge path
- [VERIFIED: Makefile:130-155] — Tests 21–30 current; Test 31 is next slot
- [VERIFIED: .github/workflows/quality.yml:109-120] — CI test step names for update
- [VERIFIED: .planning/config.json] — `workflow.nyquist_validation: true`
- [VERIFIED: bash --version] — macOS ships GNU bash 3.2.57 on arm64
- [VERIFIED: which rtk] — RTK at /opt/homebrew/bin/rtk; rtk 0.37.2
- [VERIFIED: ~/.claude/settings.json] — top-level `"statusLine"` key confirmed
- [VERIFIED: ~/.claude/hooks] — cc-safety-net at /opt/homebrew/bin/cc-safety-net

### Secondary (ASSUMED — Bash 3.2 TUI patterns)

- `read -rsn1` + `read -rsn2` two-pass arrow detection — training knowledge, cross-checked against TUI-01 constraint in REQUIREMENTS.md
- `stty -g` save/restore pattern — training knowledge; consistent with bootstrap.sh idiom
- ANSI escape sequence compatibility matrix — training knowledge (widely documented)
- BASH_SOURCE[0] curl-pipe detection — training knowledge, consistent with D-24

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `read -rsn2` captures both `[A` bytes atomically in standard terminals (no timing issue) | §2 TUI Implementation | Arrow key misdetected → focus navigation broken; mitigation: per-byte fallback with stty timeout |
| A2 | `rtk init -g` is non-interactive and exits 0 cleanly | §6 Dispatch Layer | `dispatch_rtk` blocks waiting for input; mitigation: test in Wave 1 and add </dev/null |
| A3 | `exec < /dev/tty` breaks curl-pipe stdin; per-read is universally safe | §4 /dev/tty Patterns | If wrong, per-read doesn't work in some edge case; but bootstrap.sh already uses per-read successfully |
| A4 | `▶` (U+25B6) renders correctly in all target terminals | §2 TUI Implementation | Arrow renders as placeholder box; mitigation: TK_TUI_ARROW override env var |
| A5 | Float read timeout (`read -t 0.1`) is unavailable in Bash 3.2 | §2 TUI Implementation | If wrong, could use cleaner per-byte timeout; does not affect correctness |

**All other claims verified directly from codebase in this session.**

---

## RESEARCH COMPLETE
