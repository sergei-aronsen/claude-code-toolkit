---
phase: 30-install-time-ux
reviewed: 2026-04-29T21:30:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - scripts/lib/bridges.sh
  - scripts/lib/dispatch.sh
  - scripts/install.sh
  - scripts/init-claude.sh
  - scripts/init-local.sh
  - scripts/tests/test-bridges-install-ux.sh
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 30: Code Review Report

**Reviewed:** 2026-04-29T21:30:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 30 wires bridge install-time UX across three entry points (`install.sh`, `init-claude.sh`, `init-local.sh`). The implementation is architecturally sound and all 14 critical invariants verified cleanly:

- shellcheck `-S warning` clean across all 6 files
- No Bash 4+ patterns in executable code (comment-only mention of `mapfile` in `bridges.sh:140`)
- Sourced libs (`bridges.sh`, `dispatch.sh`) have no `set -euo pipefail`
- Executables all have `set -euo pipefail` on line 8–19
- Mutex (`--no-bridges` + `--bridges`) enforced correctly in all three entry points with the two-pass check (pre- and post-env-var coalesce)
- `--bridges` force path + `--fail-fast` exit-1 logic confirmed correct; fail-soft warn-continue also correct
- Fail-closed N on no-TTY confirmed via `read ... || choice="N"` pattern
- `TK_NO_BRIDGES=1` and `NO_BRIDGES=true` both short-circuit `bridge_install_prompts` at entry
- TUI rows correctly gated on `IS_GEM` / `IS_COD`; absent CLI omits row entirely
- `--yes` default-set includes bridge rows only when CLI detected
- `_bridge_cli_version` is fail-soft (empty string on probe failure)
- `--dry-run` correctly does NOT reach `bridge_create_global`: `download_files()` in `init-claude.sh` calls `exit 0` at line 502; `init-local.sh` exits at line 315; `install.sh` uses `:` (no-op) in the bridge dispatch block
- Target injection safety: `BRIDGES_FORCE` tokens flow only into `_bridge_match` (string equality) and the hardcoded `for target in gemini codex` loop; `bridge_create_project` validates via `_bridge_filename` case block
- `_bridge_match` empty-array safety: uses `"${tokens[@]+"${tokens[@]}"}"`  Bash 3.2 guard at lines 150 and 618

One warning-level bug found: silent failure suppression in the `--bridges` force path inside `bridge_install_prompts`. Two info-level items: (1) bridge dry-run in `install.sh` is silent (no `[+ INSTALL] would-run` print unlike other dispatchers), and (2) `_bridge_cli_version` version-probe timing runs at TUI-render time probing live CLIs, which is consistent with the established probe-once pattern but subtly differs from the rest of `detect2_cache`.

---

## Warnings

### WR-01: `--bridges` force path silently swallows `bridge_create_project` failures

**File:** `scripts/lib/bridges.sh:579`
**Issue:** In `bridge_install_prompts`, the `BRIDGES_FORCE` (non-interactive) path calls `bridge_create_project "$target" "$project_root" || true`. This suppresses all failure return codes (1 = missing source CLAUDE.md, 2 = mkdir/write blocked) with no warning printed to the user. A user running `--bridges gemini` in a directory without a `CLAUDE.md` will see no output and no error — the bridge silently does not get created.

The interactive path (lines 599–604) also uses `|| rc=$?; : "$rc"` which is equivalently silent, but that case has an explicit comment explaining "Non-fatal: a missing CLAUDE.md or write-blocked target should NOT abort the remaining install flow." The force path has no such comment and no user feedback.

**Fix:**
```bash
# bridges.sh:577-582 — add a warning when force-create silently fails
if [[ -n "${BRIDGES_FORCE:-}" ]]; then
    if _bridge_match "$target" "$BRIDGES_FORCE"; then
        local _bcp_rc=0
        bridge_create_project "$target" "$project_root" || _bcp_rc=$?
        if [[ $_bcp_rc -ne 0 ]]; then
            echo -e "${YELLOW}Warning:${NC} bridge_create_project $target failed (rc=$_bcp_rc) — is ${project_root}/CLAUDE.md present?" >&2
        fi
    fi
    continue
fi
```

---

## Info

### IN-01: Bridge dispatch in `install.sh` is silent under `--dry-run`

**File:** `scripts/install.sh:877-879`
**Issue:** The bridge dispatch shim uses `:` (no-op) for the dry-run path. Other dispatchers (e.g., `dispatch_superpowers`, `dispatch_statusline`) print `[+ INSTALL] <component> (would run: <command>)` via their own dry-run branches. The bridge dry-run produces no intermediate output — only the post-install summary row shows `would-install`. This is not a bug (the summary correctly reflects the status), but creates a minor inconsistency in dry-run verbosity visible to users.

**Fix:** Add an informational print for consistency:
```bash
# install.sh:877-879
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[+ INSTALL] ${local_name} (would run: bridge_create_global ${_bridge_target})"
    : # local_rc stays 0
fi
```

### IN-02: `TK_DISPATCH_ORDER` guard uses `[*]` expansion which could cause SC2199 in stricter shellcheck versions

**File:** `scripts/lib/dispatch.sh:55`
**Issue:** The guard `if [[ -z "${TK_DISPATCH_ORDER[*]:-}" ]]` uses `[*]` (glob-join) rather than checking array length. This is functionally correct for the "unset or empty" check but could produce a false-negative if `TK_DISPATCH_ORDER` were set to a single empty-string element `("")`. Under the current codebase this cannot occur (only this file sets `TK_DISPATCH_ORDER`), so it is a theoretical edge case, not an active bug. Current shellcheck passes clean.

**Fix:** The safer idiom is `[[ ${#TK_DISPATCH_ORDER[@]:-} -eq 0 ]]`, but this is a minor style point with no impact in practice.

---

_Reviewed: 2026-04-29T21:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---

## STATUS: issues_found

**Summary (2 lines):** All 14 critical invariants verified clean — Bash 3.2 portability, `set -euo pipefail` placement, mutex enforcement, fail-fast, fail-closed N, dry-run isolation, and injection safety all confirmed. One warning: the `--bridges` force path in `bridge_install_prompts` silently swallows `bridge_create_project` failures (`|| true`) with no user feedback; fixable by adding a warning on non-zero return.
