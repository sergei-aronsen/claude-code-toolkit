---
phase: 25
plan: "02"
type: execute
wave: 2
depends_on:
  - "25-01"
files_modified:
  - scripts/lib/mcp.sh
autonomous: true
requirements:
  - MCP-04
  - MCP-SEC-01
  - MCP-SEC-02
tags: [bash, secrets, wizard, phase-25]

must_haves:
  truths:
    - "mcp_wizard_run <name> reads env_var_keys for the named MCP, prompts for each via read -rs (sensitive) or read -r (non-sensitive based on key naming heuristic), writes the values to ~/.claude/mcp-config.env, then invokes claude mcp add with the install_args"
    - "Secret keys are NEVER echoed to stdout/stderr after read; the wizard prints only the key name + 'received' confirmation"
    - "~/.claude/mcp-config.env is written with mode 0600 immediately after the printf-write (chmod 600 happens in the same function before next operation)"
    - "When a key already exists in mcp-config.env, the wizard prompts '[y/N] Overwrite KEY?' and defaults to N (preserves existing) per CONTEXT.md collision handling"
    - "Wizard reads input from < /dev/tty by default; honors TK_MCP_TTY_SRC env-var override (mirrors TK_TUI_TTY_SRC seam from Phase 24)"
    - "OAuth-only MCPs (requires_oauth=1, e.g. notion) skip the env-prompt step entirely; wizard prints 'OAuth flow handled by claude mcp add — follow CLI prompts' and dispatches directly"
    - "When claude CLI is absent, mcp_wizard_run prints fail-soft warning and returns 2 (mirrors is_mcp_installed contract from Plan 01)"
    - "Wizard exits with the underlying claude mcp add exit code (preserves dispatcher contract pattern from Phase 24 D-25)"
    - "mcp-config.env schema is KEY=value lines, no quotes, trailing newline per entry, no shell metacharacters in value (rejected with re-prompt)"
  artifacts:
    - path: "scripts/lib/mcp.sh"
      provides: "Adds mcp_wizard_run + secrets persistence (mcp_secrets_*)"
      contains: "mcp_wizard_run mcp_secrets_load mcp_secrets_set"
      min_lines: 200
  key_links:
    - from: "mcp_wizard_run"
      to: "~/.claude/mcp-config.env"
      via: "printf-append + chmod 600"
      pattern: "chmod 0?600"
    - from: "mcp_wizard_run"
      to: "claude mcp add"
      via: "exec with install_args + env vars from mcp-config.env"
      pattern: "claude.*mcp add"
    - from: "wizard prompt"
      to: "TK_MCP_TTY_SRC"
      via: "read -rsp ... < $tty_src"
      pattern: "TK_MCP_TTY_SRC"
---

<objective>
Extend `scripts/lib/mcp.sh` (created in Plan 01) with the per-MCP install wizard (`mcp_wizard_run`) and the secrets-persistence helpers (`mcp_secrets_load`, `mcp_secrets_set`). These three functions implement MCP-04 (wizard with hidden input + claude mcp add invocation), MCP-SEC-01 (mode 0600 on `~/.claude/mcp-config.env`), and MCP-SEC-02 (KEY=value schema with collision prompt).

Why split from Plan 01: catalog + detection are pure-read primitives; this plan handles user-facing prompts, file writes with mode bits, and shell-out to `claude mcp add`. Splitting keeps each plan ~50% context with one concern per plan.

Why no install.sh wiring here: Plan 03 wires `--mcps` flag, the second TUI page rendering, and `dispatch_mcps`. This plan delivers the helpers; Plan 03 calls them.

CRITICAL secrets contract (MCP-SEC-01):
- File `~/.claude/mcp-config.env` MUST be created with mode 0600 BEFORE any KEY=value line is written. Order of operations: `touch` → `chmod 600` → `printf >> file`. Never the reverse.
- Re-running the wizard MUST NOT widen permissions. `chmod 0600` after every write is idempotent and safe.
- Shell metacharacter guard: values containing `$`, backtick, `\`, newline, or quote characters are REJECTED with a re-prompt. Storing an unescaped `$` would cause the value to expand when sourced.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/25-mcp-selector/25-CONTEXT.md
@.planning/phases/25-mcp-selector/25-01-mcp-catalog-and-loader-SUMMARY.md
@scripts/lib/mcp.sh
@scripts/lib/mcp-catalog.json
@scripts/lib/tui.sh
@scripts/lib/dispatch.sh
@scripts/lib/bootstrap.sh

<interfaces>
<!-- From Plan 01 — these MUST already exist when this plan starts -->

```bash
# scripts/lib/mcp.sh exposes (Plan 01):
mcp_catalog_load          # populates MCP_NAMES MCP_DISPLAY MCP_ENV_KEYS MCP_INSTALL_ARGS MCP_DESCS MCP_OAUTH
mcp_catalog_names         # alpha-sorted names one per line
is_mcp_installed <name>   # returns 0/1/2
TK_MCP_CLAUDE_BIN         # test seam (claude binary override)
TK_MCP_CATALOG_PATH       # test seam (catalog JSON override)
```

<!-- New test seams introduced by this plan -->

```bash
TK_MCP_TTY_SRC            # override /dev/tty source for wizard read prompts (mirrors TK_TUI_TTY_SRC)
TK_MCP_CONFIG_HOME        # override $HOME for mcp-config.env path resolution (mirrors HOME override pattern)
```

<!-- mcp-config.env file schema (MCP-SEC-02) -->

```text
# ~/.claude/mcp-config.env
# Mode: 0600 (owner-only readable)
# Format: KEY=value, one per line, no quotes, trailing newline
# Loaded by `claude mcp add` via env-var plumbing in mcp_wizard_run.
CONTEXT7_API_KEY=ctx7_live_abc123
SENTRY_AUTH_TOKEN=sntrys_xxx
OPENROUTER_API_KEY=sk-or-v1-...
```

<!-- Reference: bootstrap.sh tty source pattern -->

From scripts/lib/bootstrap.sh:42-48:
```bash
local tty_src="${TK_BOOTSTRAP_TTY_SRC:-/dev/tty}"
local prompt_response
read -r -p "Install superpowers? [y/N] " prompt_response < "$tty_src" 2>/dev/null || prompt_response="N"
```

This plan mirrors that pattern exactly with `TK_MCP_TTY_SRC` instead of `TK_BOOTSTRAP_TTY_SRC`.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add mcp_secrets_load + mcp_secrets_set to scripts/lib/mcp.sh</name>
  <files>scripts/lib/mcp.sh</files>
  <read_first>
    - scripts/lib/mcp.sh (existing Plan 01 functions — append after them, do not modify them)
    - scripts/lib/bootstrap.sh:42-48 (tty source pattern)
    - .planning/phases/25-mcp-selector/25-CONTEXT.md (collision handling decision)
  </read_first>
  <behavior>
    - mcp_secrets_load with no existing file returns 0 and produces empty MCP_SECRETS associative-equivalent (parallel arrays MCP_SECRET_KEYS MCP_SECRET_VALUES, both length 0)
    - mcp_secrets_load on a file with 3 entries populates length-3 parallel arrays
    - mcp_secrets_set FOO bar with no existing file creates ~/.claude/mcp-config.env with mode 0600 and FOO=bar line + trailing newline
    - mcp_secrets_set FOO baz with existing FOO=bar prompts "[y/N] Overwrite FOO?" via TK_MCP_TTY_SRC; default N preserves "FOO=bar"
    - mcp_secrets_set FOO baz with existing FOO=bar and "y" answer overwrites to "FOO=baz" (single line, no duplicate)
    - File mode is exactly 0600 after every set call (verified via `stat -f %Mp%Lp` on macOS or `stat -c %a` on Linux)
    - Values containing $, backtick, newline are rejected with a stderr message and return 1
    - mcp_secrets_load reads from ${TK_MCP_CONFIG_HOME:-$HOME}/.claude/mcp-config.env
  </behavior>
  <action>
APPEND to `scripts/lib/mcp.sh` (do not modify Plan 01 functions). Add this section after `is_mcp_installed`:

```bash
# ─────────────────────────────────────────────────
# Secrets persistence — ~/.claude/mcp-config.env (MCP-SEC-01, MCP-SEC-02)
# ─────────────────────────────────────────────────

# _mcp_config_path — resolve ~/.claude/mcp-config.env honoring TK_MCP_CONFIG_HOME test seam.
_mcp_config_path() {
    echo "${TK_MCP_CONFIG_HOME:-$HOME}/.claude/mcp-config.env"
}

# _mcp_validate_value — reject values with shell metacharacters that would expand when sourced.
# Rejected: $, backtick, backslash, newline, double quote, single quote.
# Returns 0 if safe, 1 if rejected (caller re-prompts).
_mcp_validate_value() {
    local v="$1"
    if [[ "$v" == *'$'* || "$v" == *'`'* || "$v" == *'\\'* || "$v" == *'"'* || "$v" == *"'"* ]]; then
        return 1
    fi
    # Reject newline (printf %s\n appends one; embedded newline would split records).
    if [[ "$v" == *$'\n'* ]]; then
        return 1
    fi
    return 0
}

# mcp_secrets_load — populate parallel arrays MCP_SECRET_KEYS[] MCP_SECRET_VALUES[] from
# ~/.claude/mcp-config.env. Empty file → both arrays length 0. Comments (#-prefix) and
# blank lines skipped. Lines without '=' skipped silently.
mcp_secrets_load() {
    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    local cfg
    cfg="$(_mcp_config_path)"
    if [[ ! -f "$cfg" ]]; then
        return 0
    fi
    local line key value
    while IFS= read -r line; do
        # Skip comments and blanks.
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        # Require KEY=value form.
        [[ "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        # Trim leading/trailing whitespace from key.
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        [[ -z "$key" ]] && continue
        MCP_SECRET_KEYS+=("$key")
        MCP_SECRET_VALUES+=("$value")
    done < "$cfg"
}

# _mcp_secrets_index — echo the index of $1 in MCP_SECRET_KEYS, or empty string if absent.
_mcp_secrets_index() {
    local target="$1"
    local i
    for ((i=0; i<${#MCP_SECRET_KEYS[@]}; i++)); do
        if [[ "${MCP_SECRET_KEYS[$i]}" == "$target" ]]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# mcp_secrets_set <KEY> <VALUE> — append or overwrite KEY=VALUE in mcp-config.env.
# Side effects (in order, MCP-SEC-01):
#   1. mkdir -p ~/.claude
#   2. touch mcp-config.env (creates if absent)
#   3. chmod 0600 mcp-config.env (idempotent)
#   4. Read existing entries via mcp_secrets_load
#   5. If KEY already present:
#        prompt "[y/N] Overwrite KEY?" via < ${TK_MCP_TTY_SRC:-/dev/tty}
#        default N → return 0, no write
#        y/Y → rewrite the file with the new value substituted (line-by-line awk-free approach)
#   6. If KEY absent: append "KEY=VALUE\n" to file
#   7. chmod 0600 again (idempotent — defends against umask widening on rewrite)
# Returns:
#   0 on success (write or no-op),
#   1 on validation failure or write error.
mcp_secrets_set() {
    local key="$1"
    local value="$2"
    if [[ -z "$key" ]]; then
        echo -e "${RED}✗${NC} mcp_secrets_set: missing KEY argument" >&2
        return 1
    fi
    if ! _mcp_validate_value "$value"; then
        echo -e "${RED}✗${NC} mcp_secrets_set: value contains shell metacharacters (\$, backtick, backslash, quote, newline) — refusing to write" >&2
        return 1
    fi
    local cfg
    cfg="$(_mcp_config_path)"
    mkdir -p "$(dirname "$cfg")" || return 1
    touch "$cfg" || return 1
    chmod 0600 "$cfg" || return 1
    mcp_secrets_load
    local idx
    if idx=$(_mcp_secrets_index "$key"); then
        # Collision — prompt.
        local tty_src="${TK_MCP_TTY_SRC:-/dev/tty}"
        local choice
        if ! read -r -p "[y/N] Overwrite ${key}? " choice < "$tty_src" 2>/dev/null; then
            choice="N"
        fi
        case "${choice:-N}" in
            y|Y)
                # Rewrite file replacing the matching line.
                local tmp
                tmp="$(mktemp "${cfg}.XXXXXX")" || return 1
                local i
                for ((i=0; i<${#MCP_SECRET_KEYS[@]}; i++)); do
                    if [[ "$i" -eq "$idx" ]]; then
                        printf '%s=%s\n' "$key" "$value" >> "$tmp"
                    else
                        printf '%s=%s\n' "${MCP_SECRET_KEYS[$i]}" "${MCP_SECRET_VALUES[$i]}" >> "$tmp"
                    fi
                done
                mv "$tmp" "$cfg" || { rm -f "$tmp"; return 1; }
                chmod 0600 "$cfg" || return 1
                ;;
            *)
                # Default N — keep existing, no-op.
                return 0
                ;;
        esac
    else
        # Append new entry.
        printf '%s=%s\n' "$key" "$value" >> "$cfg" || return 1
        chmod 0600 "$cfg" || return 1
    fi
    return 0
}
```

CRITICAL — no echoing of `$value` after a `read -rs`. The validation rejection message says only "value contains shell metacharacters" — never the value itself. The collision prompt says only the KEY name, never the value.

shellcheck must pass `-S warning`. If shellcheck flags `MCP_SECRET_KEYS`/`MCP_SECRET_VALUES` as unused, add `# shellcheck disable=SC2034` at the function declarations — Plan 03 (install.sh) consumes them.
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/lib/mcp.sh && bash -c '
set -euo pipefail
SANDBOX=$(mktemp -d /tmp/mcp-secrets.XXXXXX)
trap "rm -rf $SANDBOX" EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"
mkdir -p "$SANDBOX/.claude"
source scripts/lib/mcp.sh

# Test 1: load empty
mcp_secrets_load
[[ ${#MCP_SECRET_KEYS[@]} -eq 0 ]] || { echo "FAIL: empty load"; exit 1; }

# Test 2: set + load roundtrip
mcp_secrets_set FOO bar
mcp_secrets_load
[[ ${#MCP_SECRET_KEYS[@]} -eq 1 && "${MCP_SECRET_KEYS[0]}" == "FOO" && "${MCP_SECRET_VALUES[0]}" == "bar" ]] || { echo "FAIL: set/load"; exit 1; }

# Test 3: file mode 0600 (cross-platform)
if stat -f %Mp%Lp "$SANDBOX/.claude/mcp-config.env" 2>/dev/null | grep -q "^0600$"; then
    : # macOS form
elif [[ "$(stat -c %a "$SANDBOX/.claude/mcp-config.env" 2>/dev/null)" == "600" ]]; then
    : # Linux form
else
    echo "FAIL: mode not 0600"; exit 1
fi

# Test 4: validation rejects $ in value
if mcp_secrets_set BAD "value\$injection" 2>/dev/null; then
    echo "FAIL: should have rejected \$ in value"; exit 1
fi

# Test 5: collision prompt — answer N keeps existing
TK_MCP_TTY_SRC=<(echo N) mcp_secrets_set FOO new_value
mcp_secrets_load
[[ "${MCP_SECRET_VALUES[0]}" == "bar" ]] || { echo "FAIL: collision N should preserve"; exit 1; }

# Test 6: collision prompt — answer y overwrites
TK_MCP_TTY_SRC=<(echo y) mcp_secrets_set FOO updated
mcp_secrets_load
[[ "${MCP_SECRET_VALUES[0]}" == "updated" ]] || { echo "FAIL: collision y should overwrite"; exit 1; }

echo OK
'</automated>
  </verify>
  <done>scripts/lib/mcp.sh contains mcp_secrets_load + mcp_secrets_set + helpers; all 6 inline test assertions above pass; shellcheck -S warning is clean; file mode is 0600 after every write.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add mcp_wizard_run to scripts/lib/mcp.sh</name>
  <files>scripts/lib/mcp.sh</files>
  <read_first>
    - scripts/lib/mcp.sh (existing functions from Plan 01 + Task 1 of this plan)
    - scripts/lib/dispatch.sh:71-99 (dispatch_superpowers contract — wizard mirrors --force/--dry-run/--yes flags)
    - .planning/phases/25-mcp-selector/25-CONTEXT.md (CLI-absent fail-soft; OAuth-only skip; failure marking)
  </read_first>
  <behavior>
    - mcp_wizard_run sequential-thinking (zero-config, zero env_var_keys) prompts no env vars and invokes claude mcp add with the install_args
    - mcp_wizard_run notion (requires_oauth=1) skips env-var prompts entirely, prints "OAuth flow handled by claude mcp add — follow CLI prompts", and invokes claude mcp add
    - mcp_wizard_run context7 with one env_var_key prompts "CONTEXT7_API_KEY: " via read -rsp from TK_MCP_TTY_SRC and persists via mcp_secrets_set, then invokes claude mcp add with the env var exported
    - When TK_MCP_CLAUDE_BIN is set, the wizard invokes that binary instead of `claude` (test seam from Plan 01)
    - When claude binary is absent (no TK_MCP_CLAUDE_BIN, no `claude` on PATH), wizard prints fail-soft warning and returns 2
    - Wizard exits with the exact return code of the underlying claude mcp add invocation (0 on success, propagates on failure)
    - --dry-run flag prints "[+ INSTALL] mcp <name> (would run: <claude mcp add ...>)" and returns 0 with NO file writes and NO claude invocation
    - When the env-prompt receives empty input (just enter), wizard re-prompts up to 3 times before returning 1 with "missing required key" message
    - Hidden input: read -rsp followed by single newline echo; the value is NEVER printed back to stdout/stderr after capture
  </behavior>
  <action>
APPEND to `scripts/lib/mcp.sh` after the secrets functions from Task 1:

```bash
# ─────────────────────────────────────────────────
# Per-MCP install wizard (MCP-04)
# ─────────────────────────────────────────────────

# _mcp_resolve_claude_bin — return path to claude binary honoring TK_MCP_CLAUDE_BIN test seam.
# Echoes the path on stdout; returns 1 if no binary found.
_mcp_resolve_claude_bin() {
    if [[ -n "${TK_MCP_CLAUDE_BIN:-}" ]]; then
        echo "$TK_MCP_CLAUDE_BIN"
        return 0
    fi
    if command -v claude >/dev/null 2>&1; then
        echo "claude"
        return 0
    fi
    return 1
}

# _mcp_lookup_index — given an MCP name, echo its index in MCP_NAMES; non-zero on miss.
# Requires mcp_catalog_load to have populated the arrays.
_mcp_lookup_index() {
    local target="$1"
    local i
    for ((i=0; i<${#MCP_NAMES[@]}; i++)); do
        if [[ "${MCP_NAMES[$i]}" == "$target" ]]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# mcp_wizard_run <name> [--dry-run] — drive the per-MCP install flow.
#   1. Resolve catalog index for <name>; error if not in the 9 curated entries.
#   2. Check claude CLI presence (test seam aware); if absent → return 2 with fail-soft warning.
#   3. If requires_oauth=1: skip env-prompt step, print OAuth notice.
#   4. Otherwise for each env_var_key in MCP_ENV_KEYS[idx] (semicolon-split):
#        prompt with read -rsp via TK_MCP_TTY_SRC,
#        retry up to 3 times on empty input,
#        persist via mcp_secrets_set (which handles collision prompt + 0600).
#   5. If --dry-run: print "[+ INSTALL] mcp <name> (would run: <claude mcp add ...>)" and return 0.
#   6. Otherwise invoke `claude mcp add <install_args>` with the env vars exported into its environment.
#      Return the exact exit code of that invocation.
mcp_wizard_run() {
    local name=""
    local dry_run=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=1 ;;
            -*)        echo -e "${YELLOW}!${NC} mcp_wizard_run: ignoring unknown flag $1" >&2 ;;
            *)         [[ -z "$name" ]] && name="$1" ;;
        esac
        shift
    done

    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} mcp_wizard_run: missing MCP name argument" >&2
        return 1
    fi

    # Ensure catalog is loaded.
    if [[ "${#MCP_NAMES[@]}" -eq 0 ]]; then
        mcp_catalog_load || return 1
    fi

    local idx
    if ! idx=$(_mcp_lookup_index "$name"); then
        echo -e "${RED}✗${NC} mcp_wizard_run: '$name' not in curated catalog" >&2
        return 1
    fi

    local claude_bin
    if ! claude_bin=$(_mcp_resolve_claude_bin); then
        if [[ -z "${_MCP_CLI_WARNED:-}" ]]; then
            echo -e "${YELLOW}!${NC} claude CLI not found — cannot install MCPs from here. See docs/MCP-SETUP.md" >&2
            _MCP_CLI_WARNED=1
        fi
        return 2
    fi

    local oauth="${MCP_OAUTH[$idx]}"
    local env_keys_csv="${MCP_ENV_KEYS[$idx]}"
    local install_args_packed="${MCP_INSTALL_ARGS[$idx]}"

    # Reconstruct install_args[] from the unit-separator-joined string written by mcp_catalog_load.
    # Plan 01 used $'\037' as the delimiter to survive spaces inside individual args.
    local IFS_SAVED="$IFS"
    IFS=$'\037'
    # shellcheck disable=SC2206
    local install_args=( $install_args_packed )
    IFS="$IFS_SAVED"

    local tty_src="${TK_MCP_TTY_SRC:-/dev/tty}"

    # Step: collect env vars (skipped for OAuth-only MCPs).
    local exported_env=()
    if [[ "$oauth" -eq 1 ]]; then
        echo "OAuth flow handled by claude mcp add — follow CLI prompts."
    elif [[ -n "$env_keys_csv" ]]; then
        local IFS_SAVED2="$IFS"
        IFS=';'
        # shellcheck disable=SC2206
        local env_keys=( $env_keys_csv )
        IFS="$IFS_SAVED2"
        local key
        for key in "${env_keys[@]}"; do
            [[ -z "$key" ]] && continue
            local value=""
            local attempts=0
            while [[ -z "$value" && "$attempts" -lt 3 ]]; do
                if ! read -rsp "${key}: " value < "$tty_src" 2>/dev/null; then
                    value=""
                fi
                # Newline after hidden input so the terminal doesn't keep the
                # cursor on the prompt line.
                printf '\n' >&2
                attempts=$((attempts + 1))
                if [[ -z "$value" ]]; then
                    echo -e "${YELLOW}!${NC} ${key} cannot be empty (attempt ${attempts}/3)" >&2
                fi
            done
            if [[ -z "$value" ]]; then
                echo -e "${RED}✗${NC} mcp_wizard_run: missing required key ${key} after 3 attempts" >&2
                return 1
            fi
            if ! mcp_secrets_set "$key" "$value"; then
                # mcp_secrets_set already printed the error.
                return 1
            fi
            # Mark for export to claude mcp add invocation environment.
            # Pack as KEY=VALUE for use with `env KEY=VALUE ... claude mcp add`.
            exported_env+=("${key}=${value}")
            # Clear the local for hygiene (no echo, no log).
            value=""
        done
    fi

    # Step: dry-run early-out.
    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] mcp ${name} (would run: ${claude_bin} mcp add ${install_args[*]})"
        return 0
    fi

    # Step: invoke claude mcp add with env vars plumbed in. Use `env` to scope the
    # exports to the child process only — DO NOT export into the calling shell.
    if [[ "${#exported_env[@]}" -gt 0 ]]; then
        env "${exported_env[@]}" "$claude_bin" mcp add "${install_args[@]}"
    else
        "$claude_bin" mcp add "${install_args[@]}"
    fi
}
```

CRITICAL hidden-input contract:
- `read -rsp` MUST be used (not `read -rp`); the `s` flag suppresses terminal echo.
- After capture, the value is used only inside `mcp_secrets_set` (which writes to 0600 file) and the `exported_env` array (passed to `env`). The value is NEVER printed via echo, printf %s, or `>&2`.
- The inline test in `<verify>` below confirms via grep that the captured value never appears in stdout/stderr.

shellcheck must pass `-S warning`. The `# shellcheck disable=SC2206` directive on the `read -a` style splits is required because we deliberately rely on word-splitting after IFS reassignment.
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/lib/mcp.sh && bash -c '
set -euo pipefail
SANDBOX=$(mktemp -d /tmp/mcp-wizard.XXXXXX)
trap "rm -rf $SANDBOX" EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"
mkdir -p "$SANDBOX/.claude"

# Mock claude binary that records its argv to a file.
cat > "$SANDBOX/claude" <<MOCK
#!/bin/bash
echo "argv:" "\$@" > "$SANDBOX/claude.argv"
echo "env:CTX=\${CONTEXT7_API_KEY:-}" >> "$SANDBOX/claude.argv"
exit 0
MOCK
chmod +x "$SANDBOX/claude"
export TK_MCP_CLAUDE_BIN="$SANDBOX/claude"

source scripts/lib/mcp.sh
mcp_catalog_load

# Test 1: dry-run with sequential-thinking (zero-config) — no claude invocation, exit 0
OUTPUT=$(mcp_wizard_run sequential-thinking --dry-run 2>&1)
if [[ -f "$SANDBOX/claude.argv" ]]; then echo "FAIL: dry-run invoked claude"; exit 1; fi
echo "$OUTPUT" | grep -q "would run" || { echo "FAIL: dry-run output missing"; exit 1; }

# Test 2: zero-config invocation populates argv
mcp_wizard_run sequential-thinking
[[ -f "$SANDBOX/claude.argv" ]] || { echo "FAIL: claude not invoked"; exit 1; }
grep -q "argv: mcp add sequential-thinking" "$SANDBOX/claude.argv" || { echo "FAIL: argv mismatch"; cat "$SANDBOX/claude.argv"; exit 1; }
rm -f "$SANDBOX/claude.argv"

# Test 3: keyed MCP — provide value via TTY fixture, verify claude saw the env var
echo "test_secret_xyz" > "$SANDBOX/tty.fix"
TK_MCP_TTY_SRC="$SANDBOX/tty.fix" mcp_wizard_run context7
grep -q "env:CTX=test_secret_xyz" "$SANDBOX/claude.argv" || { echo "FAIL: env var not plumbed"; cat "$SANDBOX/claude.argv"; exit 1; }
# And the secret persisted to mcp-config.env
grep -q "^CONTEXT7_API_KEY=test_secret_xyz$" "$SANDBOX/.claude/mcp-config.env" || { echo "FAIL: secret not persisted"; exit 1; }
# And the file mode is 0600
if stat -f %Mp%Lp "$SANDBOX/.claude/mcp-config.env" 2>/dev/null | grep -q "^0600$"; then :;
elif [[ "$(stat -c %a "$SANDBOX/.claude/mcp-config.env" 2>/dev/null)" == "600" ]]; then :;
else echo "FAIL: mode not 0600 after wizard"; exit 1; fi

# Test 4: secret value MUST NOT leak to stdout/stderr (hidden input contract)
echo "leaked_secret_zzz" > "$SANDBOX/tty.fix2"
rm -f "$SANDBOX/.claude/mcp-config.env"
OUTPUT=$(TK_MCP_TTY_SRC="$SANDBOX/tty.fix2" mcp_wizard_run context7 2>&1) || true
if echo "$OUTPUT" | grep -q "leaked_secret_zzz"; then
    echo "FAIL: secret value appeared in wizard stdout/stderr — hidden-input contract broken"
    exit 1
fi

# Test 5: OAuth-only MCP (notion) skips env prompts
rm -f "$SANDBOX/claude.argv"
mcp_wizard_run notion
grep -q "argv: mcp add notion" "$SANDBOX/claude.argv" || { echo "FAIL: notion not invoked"; exit 1; }

# Test 6: CLI absent → return 2 (fail-soft per MCP-02)
unset TK_MCP_CLAUDE_BIN
rc=0
PATH=/usr/bin:/bin mcp_wizard_run sequential-thinking 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || { echo "FAIL: expected rc=2 with no CLI, got $rc"; exit 1; }

echo OK
'</automated>
  </verify>
  <done>scripts/lib/mcp.sh contains mcp_wizard_run that handles zero-config, keyed, OAuth-only, dry-run, and CLI-absent paths; all 6 verification tests above pass; shellcheck -S warning clean; file mode 0600 invariant preserved across wizard runs; secret values never appear in stdout/stderr.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user→TTY→wizard | API keys flow from user keystrokes into wizard process memory |
| wizard→mcp-config.env | Secrets persisted to disk in plaintext |
| mcp-config.env→claude mcp add | Env vars plumbed from disk file into child process environment |
| catalog JSON→install_args | Static JSON data flows into argv of `claude mcp add` (no user input here) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-25-01 | Information Disclosure | mcp-config.env file | mitigate | `chmod 0600` enforced before AND after every write; verified by automated stat-mode test in Task 1 verify block |
| T-25-02 | Information Disclosure | wizard prompt + capture | mitigate | `read -rsp` (s flag = no echo); collision prompt prints KEY only, never VALUE; secret never echoed back; verified by Task 2 Test 4 grep-leak assertion |
| T-25-03 | Tampering | mcp-config.env value injection | mitigate | `_mcp_validate_value` rejects `$`, backtick, backslash, quote, newline before write — prevents shell expansion when other tools source the file (note: `claude mcp add` does NOT source it, but rotation-recipe in docs/MCP-SETUP.md may) |
| T-25-04 | Information Disclosure | shell history | accept | `read -rsp` doesn't add to history; user can still `cat ~/.claude/mcp-config.env` if they choose. Documented as plaintext-on-disk caveat in docs/MCP-SETUP.md (Plan 04) |
| T-25-05 | Spoofing | claude binary substitution | accept | `TK_MCP_CLAUDE_BIN` is intentional test seam; production resolves via `command -v claude` which is PATH-trust per OS convention. No additional sig-check warranted |
| T-25-06 | Repudiation | wizard audit log | accept | Solo-developer tool — no audit log requirement. Each wizard run is interactive; "did the user do X" is answered by file mtime |
| T-25-07 | Denial of Service | empty-input retry loop | mitigate | Hard 3-attempt cap (Task 2 retry counter); after 3 empty inputs the wizard returns 1 with explanatory message — no infinite loop possible |
</threat_model>

<verification>
- `shellcheck -S warning scripts/lib/mcp.sh` → 0 warnings
- `bash -c 'set -euo pipefail; source scripts/lib/mcp.sh; mcp_catalog_load && mcp_secrets_load && echo OK'` → prints OK
- File mode of `~/.claude/mcp-config.env` after every wizard write is exactly `0600`
- Secret values do NOT appear in wizard stdout/stderr (grep test in Task 2 verify block)
- All 6 inline test assertions in Task 1 verify block pass
- All 6 inline test assertions in Task 2 verify block pass
</verification>

<success_criteria>
1. `scripts/lib/mcp.sh` gains `mcp_secrets_load`, `mcp_secrets_set`, `mcp_wizard_run`, plus the underscore-prefixed helpers.
2. MCP-SEC-01: `~/.claude/mcp-config.env` is created mode 0600 and re-chmod'd 0600 after every write.
3. MCP-SEC-02: KEY=value schema, collision prompt with default-N, shell-metacharacter rejection.
4. MCP-04: wizard handles zero-config / keyed / OAuth-only / dry-run / CLI-absent paths per behaviors above.
5. Hidden-input contract: secret values NEVER appear in stdout/stderr — verified by grep-leak assertion.
6. Wizard exit code propagates `claude mcp add` exit code unchanged.
7. shellcheck -S warning is clean across the new code.
</success_criteria>

<output>
After completion, create `.planning/phases/25-mcp-selector/25-02-wizard-and-secrets-SUMMARY.md` documenting:
- Final size of mcp.sh (cumulative line count)
- Whether any package names from Plan 01 catalog needed correction (e.g., if upstream package name had drifted)
- The exact set of test seams introduced (TK_MCP_TTY_SRC, TK_MCP_CONFIG_HOME) and how they relate to existing Phase 24 seams (TK_TUI_TTY_SRC, TK_BOOTSTRAP_TTY_SRC)
- Decisions made during implementation (e.g., whether the 3-attempt retry feels right)
</output>
