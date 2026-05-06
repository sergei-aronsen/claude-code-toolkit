---
phase: 38-wizard-dispatch-integration
reviewed: 2026-05-05T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - scripts/lib/mcp.sh
  - scripts/install.sh
  - scripts/tests/test-mcp-wizard.sh
findings:
  blocker: 0
  high: 1
  medium: 3
  low: 2
  info: 2
  total: 8
status: findings
---

# Phase 38 — Wizard Dispatch Integration — Code Review

## Summary

Phase 38 dispatch layer **largely correct on secrets axis**: project-scope branches confine literal values to `<project>/.env`; only `${VAR}` substring reaches `claude argv`; defense-in-depth gate (`validate_mcp_env_block`) wired BEFORE `claude mcp add`; lazy-source re-entrancy sentinel (`_MCP_SOURCING_PROJECT_SECRETS`) correctly breaks mutual-source cycle; 4-tuple writer/reader contracts match exactly.

Findings:
- **HIGH-01**: comment/documentation request — load-bearing N² invariant in defer block needs inline comment
- **MED-01**: `install.sh:857,892` `set -- $_row` mutates script's positional params at top level — latent time-bomb
- **MED-02**: `tail -c 1` newline-detection mis-handles NUL-byte trailing — out of phase scope (pre-existing)
- **MED-03**: T12 function override leaks into parent shell namespace — fragile, subshell isolation recommended
- **LOW-01**: user-scope defer branch bypasses `^[A-Z_][A-Z0-9_]*$` key validation (defense-in-depth gap)
- **LOW-02**: rc-write path untested (pre-existing v4.9 code)
- **INFO-01**: comment drift `mcp.sh:749` references wrong line number
- **INFO-02**: T9 missing positive assertion that claude.argv WAS written under defer+project

## High

### HIGH-01: `mcp_wizard_run` project-scope defer branch reads `_project_secrets_load_env` PER KEY inside stub loop — load-bearing invariant needs inline comment

**File:** `scripts/lib/mcp.sh:782-793`

The load-per-iteration is **load-bearing**: future maintainer moving the call OUT of the loop ("optimization") would silently break "see your own previous stubs" semantics. User-scope sibling at line 796-809 has same pattern via `mcp_secrets_load`.

**Fix:** Add inline comment above line 788 documenting cycle-breaker invariant:

```bash
# Phase 38 (D-09): re-parse <project>/.env on every iteration so a stub
# we just appended is visible to the next iteration's collision check.
# DO NOT lift this load out of the loop — it is the cycle-breaker.
_project_secrets_load_env "$_proj_env"
```

## Medium

### MED-01: `install.sh:857` and `:892` use `set -- $_row` at script top-level — mutates script's $@ across iterations

**File:** `scripts/install.sh:853-868` (user block) and `:888-903` (project block)

Both deferred-summary blocks split tab-joined row via `set -- $_row` at top-level shell (NOT inside function). Permanently overwrites script's `$@`/`$1`/`$2`. Today install.sh does not re-read `$@` after this point so latent — but **time-bomb** for future feature flag check after summary or `exec "$@"` re-entry. Phase 38 cloned this pattern from v4.9 user-block into project-block, doubling surface.

**Fix:** Wrap `set --` inside `( … )` subshell — smallest diff:

```bash
(
    _IFS_SAVED2="$IFS"
    IFS=$'\t'
    # shellcheck disable=SC2086
    set -- $_row
    IFS="$_IFS_SAVED2"
    _row_keys="$2"
    IFS=','
    for _k in $_row_keys; do
        _k="${_k# }"
        [[ -z "$_k" ]] && continue
        printf '       %s=<your-key>\n' "$_k"
    done
)
```

Or use `printf '%s\n' "$_row" | awk -F'\t' '{print $2}'` and avoid `set --` entirely. Apply to BOTH user-block and project-block.

### MED-02: `project_secrets_ensure_gitignore` newline-detection mis-handles NUL-byte trailing — out of Phase 38 scope

**File:** `scripts/lib/project-secrets.sh:218-221`

`tail -c 1 | command-substitution` strips NUL bytes. Pathological case only (NUL in `.gitignore` is legal but rare). Pre-existing Phase 37 code; not regressed by Phase 38. Flagged for awareness only — fix in future phase if needed.

### MED-03: Test-12 (defense-in-depth) leaves rendered env block override reachable to parent shell

**File:** `scripts/tests/test-mcp-wizard.sh:493-519`

Test overrides `project_secrets_render_mcp_env_block` at top-level, then unsets and re-sources `project-secrets.sh` to restore. Correct today, but fragile: future call-graph addition could silently bypass gate test.

**Fix:** Wrap override in subshell — guarantees override cannot leak:

```bash
DEF_RC=0
ERR=$( (
    project_secrets_render_mcp_env_block() {
        printf '{"CONTEXT7_API_KEY":"plain-literal-not-substitution"}'
        return 0
    }
    TK_MCP_SCOPE=project TK_PROJECT_ROOT="$PROJECT" \
    TK_MCP_TTY_SRC="$SANDBOX/tty.fix.poison" \
    mcp_wizard_run context7 2>&1 1>/dev/null
) ) || DEF_RC=$?
```

Subshell form removes `unset -f` + re-source dance at line 517-519.

## Low

### LOW-01: `mcp_wizard_run` user-scope defer block at `mcp.sh:803-808` — appends bare `KEY=` without key-shape validation

**File:** `scripts/lib/mcp.sh:796-809`

User-scope defer branch appends `printf '%s=\n' "$_stub_key"` directly, **bypassing** `mcp_secrets_set`'s validation pipeline. `_stub_key` from curated catalog (audit L1 enforced at load), so safe in practice. Project-scope sibling at line 782-793 gets defense-in-depth via `_project_secrets_load_env`'s parse-time filter.

**Fix:** Add defensive shape check:

```bash
for _stub_key in "${_stub_keys[@]}"; do
    [[ -z "$_stub_key" ]] && continue
    # Defense in depth — match audit L1 guard in mcp_secrets_load.
    if [[ ! "$_stub_key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
        continue
    fi
    mcp_secrets_load
    ...
```

### LOW-02: `_shell_rc` write at `install.sh:843-846` untested by Phase 38 harness

**File:** `scripts/install.sh:826-848`

test-mcp-wizard.sh:425 explicitly does `unset ZSH_VERSION BASH_VERSION SHELL` to neutralise rc-write branch. Pre-existing v4.9 code, but harness blanket workaround is brittle. Out of Phase 38 scope; flagged for awareness.

## Info

### INFO-01: Comment drift on `mcp.sh:749` — references plan 38-02 instead of file location

**File:** `scripts/lib/mcp.sh:746-751`

Comment says `install.sh reader at install.sh:833`. Actual reader at `install.sh:809`. Line 833 is bash detection branch.

**Fix:**

```bash
# install.sh reader at install.sh:809 ships the matching 4-field reader in
# plan 38-02 in the same wave so there is never a schema-without-reader window.
```

### INFO-02: T9 (DISP-03) missing positive assertion that claude.argv WAS written

**File:** `scripts/tests/test-mcp-wizard.sh:340-381`

T9 verifies queue tuple, blank stub, gitignore guard, rc=3 — but does NOT assert `claude.argv` written (defer-secrets DOES invoke `claude mcp add` with no env). `rm -f` at line 381 assumes argv file exists but never asserted. Future regression making defer branch skip `claude mcp add` entirely would still pass T9.

**Fix:** Add one assertion before cleanup:

```bash
# rc=3 contract: claude WAS invoked (registration happened, just no env binding).
if [[ -f "$SANDBOX/claude.argv" ]]; then
    assert_pass "T9 (DISP-03): claude mcp add WAS invoked under defer+project (rc=3 means registered)"
else
    assert_fail "T9 (DISP-03): claude mcp add WAS invoked under defer+project (rc=3 means registered)" \
                "claude.argv missing — defer branch skipped registration"
fi
```

Mirror of T12 "claude must NOT be invoked" assertion.

---

## Verification of phase 38 critical invariants

| Invariant | Status |
|-----------|--------|
| Project-scope: literal value never reaches claude argv | **PASS** |
| User-scope: byte-identical to v4.6/v4.9 | **PASS** |
| Lazy-source re-entrancy sentinel | **PASS** |
| 4-tuple writer/reader format match | **PASS** |
| claude argv form `-e KEY=${KEY}` substitution | **PASS** |
| Path traversal: `${TK_PROJECT_ROOT:-$(pwd)}` bounded | **PASS** |
| Bash 3.2 compat | **PASS** |
| Test hermeticity (TK_MCP_CLAUDE_BIN fake) | **PASS** |
| Defense-in-depth at `validate_mcp_env_block` | **PASS** |
| Defer-secrets project branch: stubs in `<project>/.env` mode 0600 | **PASS** |

---

**Recommendation to merge:** Address MED-01 (real time-bomb), MED-03 (test fragility), LOW-01 (defense-in-depth gap), INFO-01 (comment drift), INFO-02 (positive assertion gap) in a single fix pass. HIGH-01 = inline comment add. MED-02 + LOW-02 deferred to future phases (pre-existing pre-Phase-38 code).
