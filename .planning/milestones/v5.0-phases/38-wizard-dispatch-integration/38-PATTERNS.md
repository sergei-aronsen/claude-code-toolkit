# Phase 38: Wizard Dispatch Integration — Pattern Map

**Mapped:** 2026-05-05
**Files analyzed:** 3 modified (no new files)
**Analogs found:** 3 / 3 (100% — every modification has an exact in-repo analog)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `scripts/lib/mcp.sh::mcp_wizard_run` (lines 616-798) | library / wizard dispatcher | request-response with side-effecting writes | `scripts/lib/project-secrets.sh::project_secrets_write_env` (consumed) + `scripts/lib/mcp.sh::mcp_secrets_set` (line 511 — analogue write path) | **exact** — the project-scope branch is a parallel of the existing user-scope branch already in this same function |
| `scripts/install.sh` (lines 801-855 summary printer) | orchestrator / output-formatter | batch-read of TSV queue → conditional dispatch | `scripts/install.sh:801-855` itself (existing 3-field reader to extend in place) | **exact** — only adding a 4th field + a per-row `case "$d_scope"` branch |
| `scripts/tests/test-mcp-wizard.sh` (PASS=14 → ≥20) | hermetic shell-test | sequential assertions with mocked external CLI | `scripts/tests/test-mcp-wizard.sh` (T1-T6 harness) + `scripts/tests/test-project-secrets.sh:164-191` (PRE_HASH/POST_HASH negative-assertion idiom) | **exact** — same harness, additional test seam `TK_PROJECT_ROOT` |

## Pattern Assignments

### `scripts/lib/mcp.sh::mcp_wizard_run` (library, request-response with side-effecting writes)

**Analog (consumed lib):** `scripts/lib/project-secrets.sh` (Phase 37 — four functions)
**Analog (parallel write path to copy structure from):** `scripts/lib/mcp.sh::mcp_secrets_set` (mcp.sh:511-565)

#### Lazy sibling-source guard pattern (mcp.sh:65-75 — the canonical template)

The existing tui.sh source guard is the exact shape to copy for project-secrets.sh.

```bash
# Lazy-source tui.sh so tui_tty_read is available for the wizard prompts. The
# wizard runs under install.sh's `( … ) 2>"$stderr_tmp"` dispatch wrapper
# (install.sh:401-405), so any `read -p "..."` would write the prompt to a
# captured stderr stream and the user would see only a blinking cursor.
if ! command -v tui_tty_read >/dev/null 2>&1; then
    _MCP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
    if [[ -f "${_MCP_LIB_DIR}/tui.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_MCP_LIB_DIR}/tui.sh"
    fi
fi
```

**Apply for Phase 38:** add a parallel block right below the tui.sh block that lazy-sources `project-secrets.sh` via `command -v project_secrets_write_env >/dev/null 2>&1` guard. Use a separate `_MCP_LIB_DIR2` var (or reuse the existing one — it remains in scope; preferred) so the second source statement does not shadow the first cd resolution. Sibling resolution (same dir as `mcp.sh`) matches the project-secrets.sh `_PROJECT_SECRETS_LIB_DIR` (project-secrets.sh:35) idiom.

The reverse direction (project-secrets.sh sourcing mcp.sh) is already deployed at project-secrets.sh:34-40 — read it as the symmetry reference:

```bash
# Lazy-source mcp.sh so _mcp_validate_value (D-16) is available without
# duplicating the metacharacter regex.
if ! command -v _mcp_validate_value >/dev/null 2>&1; then
    _PROJECT_SECRETS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
    if [[ -f "${_PROJECT_SECRETS_LIB_DIR}/mcp.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_PROJECT_SECRETS_LIB_DIR}/mcp.sh"
    fi
fi
```

#### Scope dispatch pattern (already partially present at mcp.sh:674-679)

The existing scope handling already reads `TK_MCP_SCOPE` and validates it. The pattern to extend:

```bash
local _scope="${TK_MCP_SCOPE:-user}"
case "$_scope" in
    user|local|project) ;;
    *) _scope="user" ;;
esac
local scoped_args=( "--scope" "$_scope" "${install_args[@]}" )
```

**Apply for Phase 38 (D-01, D-02):** keep this case statement intact. Below it (or in the env-var collection branches at mcp.sh:752 and mcp.sh:695), branch on `$_scope == "project"` to switch the persistence destination. Resolve `project_root` using:

```bash
local _project_root="${TK_PROJECT_ROOT:-$(pwd)}"
```

**Bash 3.2 invariant:** the `case` statement (already in use here) is the substitute for an associative-array scope→hint map. Do NOT introduce `declare -A`.

#### Env-var collection loop (mcp.sh:752-790 — the v4.6 MCP-04 contract — UNCHANGED)

This is the 3-attempt hidden-input loop. The CONTRACT is preserved verbatim. Only `mcp_secrets_set` (line 782) is the persistence call to swap.

```bash
elif [[ -n "$env_keys_csv" ]]; then
    local IFS_SAVED2="$IFS"
    IFS=';'
    # shellcheck disable=SC2206
    local env_keys=( $env_keys_csv )
    IFS="$IFS_SAVED2"
    local env_key
    for env_key in "${env_keys[@]}"; do
        [[ -z "$env_key" ]] && continue
        local collected_value=""
        local attempts=0
        while [[ -z "$collected_value" && "$attempts" -lt 3 ]]; do
            if ! tui_tty_read collected_value "${env_key}: " 1 "$tty_src"; then
                collected_value=""
            fi
            attempts=$((attempts + 1))
            if [[ -z "$collected_value" ]]; then
                echo -e "${YELLOW}!${NC} ${env_key} cannot be empty (attempt ${attempts}/3)" >&2
            fi
        done
        if [[ -z "$collected_value" ]]; then
            echo -e "${RED}✗${NC} mcp_wizard_run: missing required key ${env_key} after 3 attempts" >&2
            return 1
        fi
        # Persist to mcp-config.env (handles 0600 + collision prompt).
        if ! mcp_secrets_set "$env_key" "$collected_value"; then
            return 1
        fi
        # Queue for export to child process only (scoped via `env` below).
        exported_env+=("${env_key}=${collected_value}")
        # Overwrite local copy immediately — never let it linger as a named var.
        collected_value=""
    done
fi
```

**Apply for Phase 38 (D-05, D-06, D-07, D-08):**

- The TTY prompt loop, attempt-counter, masking, and 3-attempt cap stay byte-identical.
- Project-scope branch swaps line 782 (`mcp_secrets_set "$env_key" "$collected_value"`) for `project_secrets_write_env "$_project_root" "$env_key" "$collected_value"`.
- Project-scope branch must call `project_secrets_ensure_gitignore "$_project_root"` ONCE before entering the loop (gate behind a local sentinel `local _gi_done=0` so it fires only on the first key, even though the lib itself is idempotent — saves one `grep -Fxq` per subsequent key).
- Project-scope branch does NOT populate `exported_env+=( … )` — the `env KEY=V` exec wrapper at line 793 is user-scope ONLY. Real values stay in `<project>/.env`.
- After the loop, project-scope branch calls `project_secrets_render_mcp_env_block "${env_keys[@]}"` and pipes the result through `project_secrets_validate_mcp_env_block "$_block"` BEFORE invoking `claude mcp add` — the defense-in-depth contract from D-06.

#### Defer-secrets stub-write pattern (mcp.sh:712-735) — the v4.9 reference

This block writes a placeholder `KEY=` line directly via `printf` (skipping `mcp_secrets_set`'s collision prompt because absence is guaranteed by the `_mcp_secrets_index … >/dev/null` guard).

```bash
local IFS_SAVED2="$IFS"
IFS=';'
# shellcheck disable=SC2206
local _stub_keys=( $env_keys_csv )
IFS="$IFS_SAVED2"
local _stub_key
for _stub_key in "${_stub_keys[@]}"; do
    [[ -z "$_stub_key" ]] && continue
    # Only stub if absent — never overwrite an existing value.
    mcp_secrets_load
    if ! _mcp_secrets_index "$_stub_key" >/dev/null 2>&1; then
        # Append a placeholder entry directly (skip mcp_secrets_set's
        # interactive collision prompt — guaranteed absent here).
        local _env_path
        _env_path="$(_mcp_config_path)"
        mkdir -p "$(dirname "$_env_path")" 2>/dev/null || true
        printf '%s=\n' "$_stub_key" >> "$_env_path" 2>/dev/null || true
        chmod 0600 "$_env_path" 2>/dev/null || true
    fi
done
```

**Apply for Phase 38 (D-09):** project-scope mirror — replace the lib helpers but keep the same shape:

- `_mcp_config_path` → `${_project_root%/}/.env`
- `mcp_secrets_load` → `_project_secrets_load_env "$_env_path"` (private helper exposed by Phase 37 lib at project-secrets.sh:51)
- `_mcp_secrets_index` → `_project_secrets_index` (project-secrets.sh:86)
- The literal `printf '%s=\n' "$_stub_key" >> "$_env_path"` line stays byte-identical (D-09 final paragraph) — empty placeholder value is the same on both scopes.
- Call `project_secrets_ensure_gitignore "$_project_root"` ONCE before the for loop in this branch too.

#### Deferred queue tuple write (mcp.sh:707-711) — the 3→4 field migration

```bash
local _deferred_keys="${env_keys_csv//;/, }"
if [[ -n "${TK_MCP_DEFERRED_QUEUE:-}" ]]; then
    printf '%s\t%s\t%s\n' "$name" "$_deferred_keys" "${install_args[*]}" \
        >> "$TK_MCP_DEFERRED_QUEUE" 2>/dev/null || true
fi
```

**Apply for Phase 38 (D-10):** grow to 4 fields by appending `$_scope`:

```bash
printf '%s\t%s\t%s\t%s\n' "$name" "$_deferred_keys" "${install_args[*]}" "$_scope" \
    >> "$TK_MCP_DEFERRED_QUEUE" 2>/dev/null || true
```

**Critical commit invariant (D-10, specifics block):** the printf format-string change AND the install.sh reader update (next section) MUST land in the SAME commit. The queue file is per-run mktemp (no on-disk persistence), but in-flight install runs must not see a 4-field write next to a 3-field read.

#### Defense-in-depth pre-claude validation (D-06 — the project-scope contract)

Before any `claude mcp add` invocation in the project-scope branch:

```bash
local _env_block
_env_block="$(project_secrets_render_mcp_env_block "${env_keys[@]}")" || return 1
if ! project_secrets_validate_mcp_env_block "$_env_block"; then
    # validate prints `✗ refusing to write literal value into .mcp.json (use ${VAR} substitution)` to stderr
    return 1
fi
# Only now is it safe to invoke claude — the JSON has been verified to contain only ${VAR} forms.
"$claude_bin" mcp add "${scoped_args[@]}" --env-from-json "$_env_block"
```

The exact CLI surface (`--env-from-json` vs repeated `--env KEY=${KEY}`) is **Claude's discretion** per CONTEXT.md decisions — planner verifies against `claude mcp add --help`. Whichever form is chosen, the contract is "no literal value reaches `.mcp.json`."

#### Stderr-message contract (mcp.sh stylistic invariant — applies to all new error paths)

```bash
echo -e "${RED}✗${NC} mcp_wizard_run: missing MCP name argument" >&2          # red ✗ for refusals (mcp.sh:629)
echo -e "${YELLOW}!${NC} ${env_key} cannot be empty (attempt ${attempts}/3)" >&2  # yellow ! for non-fatal (mcp.sh:774)
```

**Apply for Phase 38:** any new project-scope error path uses red `✗` for refusals, yellow `!` for warnings. The exact-phrase contract matters for grep-based test assertions.

---

### `scripts/install.sh` (orchestrator, batch-read TSV → conditional dispatch)

**Analog:** itself — `scripts/install.sh:801-855` (the 3-field tuple reader to extend)

#### Current 3-field reader (install.sh:833-844)

```bash
while IFS=$'\t' read -r d_name d_keys _; do
    [[ -z "$d_name" ]] && continue
    _IFS_SAVED2="$IFS"
    IFS=','
    for _k in $d_keys; do
        _k="${_k# }"
        [[ -z "$_k" ]] && continue
        printf '       %s=<your-key>\n' "$_k"
    done
    IFS="$_IFS_SAVED2"
done < "$TK_MCP_DEFERRED_QUEUE"
```

**Apply for Phase 38 (D-13, D-14):** extend to read 4 fields and dispatch by `d_scope`:

```bash
while IFS=$'\t' read -r d_name d_keys d_args d_scope; do
    [[ -z "$d_name" ]] && continue
    # Back-compat fallback — if a row has only 3 fields, treat scope as `user`
    # (D-10 covers the in-flight transition; this guards against any pre-v5.0
    # producer landing in the queue).
    [[ -z "${d_scope:-}" ]] && d_scope="user"
    case "$d_scope" in
        project)
            # Append to the project-scope summary buffer (printed in its own block)
            ;;
        user|local|*)
            # Append to the user-scope summary buffer (existing copy)
            ;;
    esac
done < "$TK_MCP_DEFERRED_QUEUE"
```

#### Two-block dispatch when both scopes coexist (D-16)

The CONTEXT.md D-16 contract says: when BOTH scopes present in the same run, print `User-scope MCPs:` block followed by `Project-scope MCPs:` block. Each lists only its own rows.

The simplest Bash 3.2-compat implementation: two parallel arrays populated during the read loop, then printed in two passes after the loop closes.

```bash
local -a _user_rows=()
local -a _project_rows=()
while IFS=$'\t' read -r d_name d_keys d_args d_scope; do
    [[ -z "$d_name" ]] && continue
    [[ -z "${d_scope:-}" ]] && d_scope="user"
    case "$d_scope" in
        project) _project_rows+=("${d_name}"$'\t'"${d_keys}") ;;
        *)       _user_rows+=("${d_name}"$'\t'"${d_keys}") ;;
    esac
done < "$TK_MCP_DEFERRED_QUEUE"

# Pass 1: user-scope block (existing copy preserved verbatim)
if [[ "${#_user_rows[@]}" -gt 0 ]]; then
    echo "User-scope MCPs registered without API keys:"
    # … existing copy from install.sh:830-853 (Open ~/.claude/mcp-config.env, shell rc auto-source, etc.)
fi

# Pass 2: project-scope block (NEW copy from D-14)
if [[ "${#_project_rows[@]}" -gt 0 ]]; then
    echo "Project-scope MCPs need API keys finished:"
    echo "  1) Open <project>/.env (already stubbed; mode 0600) and fill in:"
    for _row in "${_project_rows[@]}"; do
        # … print KEY=<your-key> lines per row
    done
    echo "  2) <project>/.gitignore already includes .env (toolkit added it)."
    echo "  3) Reload shell env from the project dir (or restart claude) and the MCP picks up the keys."
fi
```

**Bash 3.2 invariant:** `local -a` works in 3.2 (NOT `declare -A`). The `+=` array append is 3.1+. The `${#arr[@]}` length check is portable.

**D-15 invariant:** the project-scope summary path does NOT touch `~/.zshrc` / `~/.bash_profile`. The shell-rc auto-source block at install.sh:806-828 is user-scope ONLY.

#### TK_MCP_DEFERRED_QUEUE setup (install.sh:487-501) — UNCHANGED

```bash
export TK_MCP_DEFER_SECRETS="${TK_MCP_DEFER_SECRETS:-1}"
if [[ -z "${TK_MCP_DEFERRED_QUEUE:-}" ]]; then
    TK_MCP_DEFERRED_QUEUE=$(mktemp "${TMPDIR:-/tmp}/tk-mcp-deferred.XXXXXX") || TK_MCP_DEFERRED_QUEUE=""
    [[ -n "$TK_MCP_DEFERRED_QUEUE" ]] && CLEANUP_PATHS+=("$TK_MCP_DEFERRED_QUEUE")
    export TK_MCP_DEFERRED_QUEUE
fi
```

**Apply for Phase 38:** no change — the queue's setup, CLEANUP_PATHS registration, and `mktemp` shape are all unchanged. Only the per-row write format and the per-row read format change (in the two paired sites).

---

### `scripts/tests/test-mcp-wizard.sh` (hermetic shell-test, sequential assertions)

**Analog (harness):** `scripts/tests/test-mcp-wizard.sh:1-72` (existing PASS=14 harness with mock claude binary)
**Analog (negative-assertion via filesystem hash):** `scripts/tests/test-project-secrets.sh:161-191` (PRE_HASH/POST_HASH idiom)

#### Existing harness (test-mcp-wizard.sh:50-72)

```bash
SANDBOX="$(mktemp -d /tmp/mcp-wizard.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"
mkdir -p "$SANDBOX/.claude"

# Build a mock claude binary that records argv + env to a file.
cat > "$SANDBOX/claude" <<'MOCK'
#!/bin/bash
printf 'argv:' > "$SANDBOX/claude.argv"
for a in "$@"; do printf ' %s' "$a"; done >> "$SANDBOX/claude.argv"
printf '\n' >> "$SANDBOX/claude.argv"
printf 'env:CTX=%s\n' "${CONTEXT7_API_KEY:-}" >> "$SANDBOX/claude.argv"
printf 'env:SENTRY=%s\n' "${SENTRY_AUTH_TOKEN:-}" >> "$SANDBOX/claude.argv"
exit 0
MOCK
sed -i.bak "s|\\\$SANDBOX|${SANDBOX}|g" "$SANDBOX/claude"
chmod +x "$SANDBOX/claude"
export TK_MCP_CLAUDE_BIN="$SANDBOX/claude"

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/mcp.sh"
mcp_catalog_load
```

**Apply for Phase 38 (D-19, D-20):**

- Reuse this exact harness — extend in place, do NOT fork a new test file. The PASS counter grows from 14 to ~20.
- Add `PROJECT="$SANDBOX/myproj"; mkdir -p "$PROJECT"; export TK_PROJECT_ROOT="$PROJECT"` for the new TK_PROJECT_ROOT seam.
- Extend the mock claude binary to capture `--scope` distinctly AND the env block separately (a tracking line `printf 'scope:%s\n' "$found_scope" >> "$SANDBOX/claude.argv"`) so DISP-01/02 negative-presence assertions ("user-scope has no `${VAR}` form" / inverse) are programmatic. The current mock already captures `argv:` and `env:` lines — extend with a small parser at the top of the heredoc.

#### Existing assert helpers — UNCHANGED

```bash
assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
    fi
}
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_fail "$label" "pattern unexpectedly found: $pattern"
    else
        assert_pass "$label"
    fi
}
```

**Apply for Phase 38:** these handle the positive ("`${CONTEXT7_API_KEY}` form appears in argv") and negative ("literal `secret_xyz` does NOT appear in argv") DISP-01/02 contracts.

#### Filesystem-fingerprint negative-assertion idiom (test-project-secrets.sh:164-180)

For "`mcp-config.env` UNTOUCHED in project-scope flow" / inverse — the fingerprint pattern:

```bash
PRE_HASH="$(shasum "$PROJECT/.env" | awk '{print $1}')"
# … perform the call that should NOT touch the file …
POST_HASH="$(shasum "$PROJECT/.env" | awk '{print $1}')"
assert_eq "$PRE_HASH" "$POST_HASH" "Tname-no-mutation: file did not change"
```

**Apply for Phase 38 (D-17, DISP-01/02 negative contracts):**

- DISP-01 negative: snapshot `mcp-config.env` (or `ls -la` of `~/.claude/`) BEFORE the project-scope wizard call → POST hash equal → assert `mcp-config.env UNTOUCHED in project-scope flow`.
- DISP-02 negative: snapshot `<project>/.env` (or its non-existence) BEFORE the user-scope call → POST identical → assert `<project>/.env UNTOUCHED in user-scope flow`.

**Edge case:** when the file does not exist, `shasum` of a missing file errors. Wrap with `[ -f "$f" ] && shasum "$f" || echo "MISSING"` so the missing-vs-present transition is also caught.

#### Cross-platform 0600 mode check (test-project-secrets.sh:52-60)

```bash
mode_is_0600() {
    local f="$1"
    if stat -f %Mp%Lp "$f" 2>/dev/null | grep -q "^0600$"; then
        echo "1"; return 0
    elif [ "$(stat -c %a "$f" 2>/dev/null)" = "600" ]; then
        echo "1"; return 0
    fi
    echo "0"
}
```

**Apply for Phase 38:** copy this helper verbatim to test-mcp-wizard.sh (or `source` test-project-secrets.sh's helper section if a shared helper file is extracted — Claude's discretion). DISP-01 happy path: `assert_eq "1" "$(mode_is_0600 "$PROJECT/.env")" "DISP-01: project .env mode is 0600"`.

#### TTY fixture pattern (test-mcp-wizard.sh:136-137)

```bash
printf 'test_secret_ctx7\n' > "$SANDBOX/tty.fix"
TK_MCP_TTY_SRC="$SANDBOX/tty.fix" mcp_wizard_run context7
```

**Apply for Phase 38:** for the project-scope DISP-01 happy-path test, write the secret to a tty.fix file and pass `TK_MCP_TTY_SRC` AND `TK_MCP_SCOPE=project` AND `TK_PROJECT_ROOT=$PROJECT` together. The fixture works identically for both scopes — only the destination of the secret value differs.

#### Defer-secrets queue assertion pattern (DISP-03)

The deferred queue is a TSV file at `$TK_MCP_DEFERRED_QUEUE`. Test pattern:

```bash
QUEUE="$(mktemp "$SANDBOX/queue.XXXXXX")"
TK_MCP_DEFERRED_QUEUE="$QUEUE" \
TK_MCP_DEFER_SECRETS=1 \
TK_MCP_SCOPE=project \
TK_PROJECT_ROOT="$PROJECT" \
    mcp_wizard_run context7
# 4-field tuple assertion
LINE="$(head -n 1 "$QUEUE")"
FIELDS_COUNT="$(awk -F'\t' '{print NF; exit}' "$QUEUE")"
assert_eq "4" "$FIELDS_COUNT" "DISP-03: queue tuple has 4 tab-separated fields"
SCOPE_FIELD="$(awk -F'\t' '{print $4; exit}' "$QUEUE")"
assert_eq "project" "$SCOPE_FIELD" "DISP-03: 4th field is scope=project"
# Stub assertion in project .env
grep -q "^CONTEXT7_API_KEY=$" "$PROJECT/.env" \
    && assert_pass "DISP-03: blank stub in project .env" \
    || assert_fail "DISP-03: blank stub in project .env" "$(cat "$PROJECT/.env")"
```

#### Defense-in-depth assertion pattern (D-17 fourth bullet)

The Phase 37 lib already covers the `validate_mcp_env_block` rc=1 + stderr contract. The Phase 38 test exercises the WIZARD CALL SITE — the wizard must abort BEFORE calling claude when a literal value is somehow injected.

```bash
# Mock the render function to return a poisoned block
project_secrets_render_mcp_env_block() { printf '{"K":"literal-leak"}'; return 0; }
rm -f "$SANDBOX/claude.argv"
ERR="$(TK_MCP_SCOPE=project TK_PROJECT_ROOT="$PROJECT" \
       TK_MCP_TTY_SRC="$SANDBOX/tty.fix" \
       mcp_wizard_run context7 2>&1 1>/dev/null)" && rc=0 || rc=$?
assert_eq "1" "$rc" "Defense-in-depth: wizard returns rc=1 on literal leak"
assert_contains "refusing to write literal value" "$ERR" "Defense-in-depth: stderr message present"
if [[ -f "$SANDBOX/claude.argv" ]]; then
    assert_fail "Defense-in-depth: claude was NOT invoked" "claude.argv exists — wizard called claude despite literal leak"
else
    assert_pass "Defense-in-depth: claude was NOT invoked"
fi
# Restore the real function for downstream tests
unset -f project_secrets_render_mcp_env_block
```

**Bash 3.2 compat note:** `unset -f` works in 3.2. The `rc=$?` capture-after-`$( … )`-with-`||` idiom is the same pattern used at test-project-secrets.sh:167-169.

---

## Shared Patterns

### Lazy sibling-source guard (cross-cutting — applies to mcp.sh)

**Source:** `scripts/lib/mcp.sh:65-75` (tui.sh source guard) AND `scripts/lib/project-secrets.sh:34-40` (mcp.sh source guard)
**Apply to:** Phase 38 mcp_wizard_run gains a third lazy-source guard for project-secrets.sh, mirroring the two existing guards.

```bash
if ! command -v project_secrets_write_env >/dev/null 2>&1; then
    _MCP_LIB_DIR="${_MCP_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)}"
    if [[ -f "${_MCP_LIB_DIR}/project-secrets.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_MCP_LIB_DIR}/project-secrets.sh"
    fi
fi
```

### Stderr-message contract (cross-cutting — applies to mcp.sh + install.sh)

**Source:** `scripts/lib/mcp.sh:629, 648, 774, 778, 519` (the existing color+glyph pattern)
**Apply to:** every new error/warning message in Phase 38 follows the established contract:

| Severity | Glyph | Color | Use case |
|----------|-------|-------|----------|
| Refusal / hard error | `✗` | `${RED}` | rc=1 paths (defense-in-depth refusal, missing arg, validation failure) |
| Non-fatal warning | `!` | `${YELLOW}` | retry-able input (empty key on attempt N), missing optional |
| Test-seam bypass | `⚠` | `${YELLOW}` | TK_PROJECT_SECRETS_ALLOW_LITERAL — ALREADY in project-secrets.sh, no Phase 38 surface |

The exact phrases form grep contracts for the test suite — never paraphrase a stderr message that a test already greps for.

### Bash 3.2 macOS BSD invariants (cross-cutting — applies to all three files)

**Source:** stack constraints (CLAUDE.md) + project-secrets.sh:287 jq stderr-capture comment + install.sh:481+ defer block
**Apply to:** every new construct in Phase 38 must avoid:

| Forbidden | Substitute |
|-----------|-----------|
| `declare -A` (associative array) | parallel arrays + linear `_index` lookup; OR a `case` statement for small enums |
| `mapfile` / `readarray` | `while IFS= read -r line; do … done < file` |
| `${var,,}` lowercasing | `tr '[:upper:]' '[:lower:]'` |
| GNU-only `stat -c %a` (alone) | dual-check `stat -f %Mp%Lp` (BSD) → `stat -c %a` (GNU) |
| `sed -i ''` form differences | always pair with `.bak` and `rm -f file.bak`, OR `sed > tmp && mv` |
| `local -a arr=()` empty-init in some 3.2 corners | `local arr; arr=()` two-step (only if shellcheck flags) |

The defer-secrets stub-write block (mcp.sh:716-735) is the canonical reference for the parallel-array idiom under Bash 3.2.

### Test seam discipline (cross-cutting — applies to test file)

**Source:** mcp.sh:34-38 (existing TK_MCP_* seams) + Phase 37 SUMMARY (D-15 TK_PROJECT_SECRETS_ALLOW_LITERAL added with loud warning)
**Apply to:** Phase 38 introduces ONE new seam — `TK_PROJECT_ROOT` — and reuses three existing seams:

| Seam | Disposition | Purpose |
|------|-------------|---------|
| `TK_MCP_TTY_SRC` | reused | TTY source for hidden-input prompts |
| `TK_MCP_CLAUDE_BIN` | reused | mock claude binary |
| `TK_MCP_DEFERRED_QUEUE` | reused | per-run mktemp queue file path |
| `TK_PROJECT_ROOT` | **NEW** | overrides `pwd` for project-scope dispatch — MUST be absolute path (test seam doc must say so) |

Document `TK_PROJECT_ROOT` in `scripts/lib/mcp.sh` header comment block (around line 38) alongside the existing seams. Do NOT add to project-secrets.sh — that lib takes the project_root as an explicit positional arg per Phase 37 D-06; it has no env-var seam.

## No Analog Found

None. Every modification in Phase 38 has an exact in-repo precedent. The "new" project-scope branch is a structural mirror of the existing user-scope branch in the same function, consuming a Phase 37 lib whose API was designed specifically for this consumer.

## Metadata

**Analog search scope:**
- `scripts/lib/mcp.sh` (full file — 850+ lines; focus 1-100, 420-800)
- `scripts/lib/project-secrets.sh` (full file — 316 lines)
- `scripts/install.sh` (lines 1-60, 480-540, 795-860)
- `scripts/tests/test-mcp-wizard.sh` (full file — 186 lines)
- `scripts/tests/test-project-secrets.sh` (lines 1-80, 155-235)
- `.planning/phases/38-wizard-dispatch-integration/38-CONTEXT.md` (full)
- `.planning/REQUIREMENTS.md` (DISP-01..04 + TEST-02..03 + traceability)
- `.planning/phases/37-project-secrets-library/37-01-secrets-lib-SUMMARY.md` (full — Phase 37 API surface)

**Files scanned:** 8

**Pattern extraction date:** 2026-05-05
