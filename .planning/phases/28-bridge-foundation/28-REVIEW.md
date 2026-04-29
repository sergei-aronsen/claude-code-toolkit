---
phase: 28-bridge-foundation
reviewed: 2026-04-29T21:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - scripts/lib/detect2.sh
  - scripts/lib/bridges.sh
  - scripts/tests/test-bridges-foundation.sh
findings:
  critical: 0
  warning: 0
  info: 3
  total: 3
status: clean
---

# Phase 28: Code Review Report

**Reviewed:** 2026-04-29T21:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** clean

## Summary

Three Phase 28 files reviewed: `detect2.sh` (extended with two binary probes),
`bridges.sh` (249-line new library), and `test-bridges-foundation.sh` (270-line
smoke test). The invariant checklist from the brief was applied in full:

- Bash 3.2+ POSIX compat — clean: no `declare -A`, `declare -n`, `read -N`,
  `${var^^}`, `mapfile`, or `&>`.
- Sourced-lib invariant — clean: `bridges.sh` and `detect2.sh` have no
  `set -euo pipefail`; the test executable has it.
- Atomic state mutation — clean: `tempfile.mkstemp + os.replace` in Python block;
  no orphaned tempfiles in any exception path (verified by reading the Python
  exception paths at lines 136-180).
- Lock correctness — clean: `release_lock` and `LOCK_DIR` restore happen in all
  three exit paths of `_bridge_write_state_entry` (acquire failure, Python failure,
  success). One design tradeoff noted as INFO below.
- No raw user input to shell — clean: `target` is validated by a `case` statement
  before reaching state writer; `project_root` and all paths are properly quoted.
- SHA256 hashed after write completes — clean: `_bridge_write_file` returns before
  `sha256_file` is called; the `} > "$target_path"` redirect is fully closed.
- Idempotency — clean: Python dedup by `(target, scope, path)` triple replaces in-place.
- TK_BRIDGE_HOME seam — clean: covers write target, state file path, and lock dir.
- Banner byte-identical — clean: single `cat <<'BANNER'` heredoc in `_bridge_write_file`;
  content matches the locked banner from CONTEXT.md verbatim.
- shellcheck -S warning clean — verified via VERIFICATION.md; confirmed by reading
  code for known shellcheck warning patterns.

No CRITICAL or WARNING findings. Three INFO observations follow.

---

## Info

### IN-01: `dry-run-output.sh` sourced at module level with no call sites in Phase 28

**File:** `scripts/lib/bridges.sh:47`
**Issue:** `source "${_BRIDGES_LIB_DIR}/dry-run-output.sh"` is executed whenever
`bridges.sh` is sourced, but no `dro_*` function is called anywhere in
`bridges.sh` in Phase 28. The import is pre-wired for Phase 30's chezmoi-grade
`[+ INSTALL]` output, per CONTEXT.md. This is intentional but creates a hidden
dependency: any environment that sources `bridges.sh` must also have
`dry-run-output.sh` on the sibling path, or the `source` fails silently (or
with a bash error if `set -e` is active in the caller).
**Fix:** No action required for Phase 28. Phase 30 should add a guard comment
at the `source` line to make the pre-wiring explicit:

```bash
# Pre-wired for Phase 30 bridge output (BRIDGE-UX-01). dro_* not called in Phase 28.
source "${_BRIDGES_LIB_DIR}/dry-run-output.sh"
```

---

### IN-02: Empty SHA written to state on `sha256_file` failure — silent degradation path

**File:** `scripts/lib/bridges.sh:210-211` (and `242-243`)
**Issue:**

```bash
source_sha="$(sha256_file "$source" 2>/dev/null || echo '')"
bridge_sha="$(sha256_file "$target_path" 2>/dev/null || echo '')"
```

If `sha256_file` fails (requires all three fallbacks — `sha256sum`, `shasum`,
and `python3` — to be absent), the state entry receives `source_sha256: ""`
and `bridge_sha256: ""`. Phase 29's drift detection would then compare `""` to the
current file SHA, always seeing a mismatch, and unconditionally re-generate the
bridge. This is safe degradation behavior (overcautious re-sync rather than silent
stale data), but it is silent — no warning is emitted that SHA computation failed.
The environment where all three fallbacks fail is essentially Bash-only (no
Python, no coreutils), which is extremely unusual for a developer machine.
**Fix:** Emit a warning and propagate a non-zero return when either SHA resolves to
empty, rather than proceeding silently:

```bash
source_sha="$(sha256_file "$source" 2>/dev/null)" || {
    echo -e "${YELLOW}⚠${NC} sha256_file failed for $source — bridge SHA not recorded" >&2
    # Still register the bridge entry without SHA (Phase 29 will detect drift)
    source_sha=""
}
```

---

### IN-03: Design tradeoff — no EXIT trap for `release_lock`; potential intra-process stale lock on signal during Phase 30 multi-bridge install

**File:** `scripts/lib/bridges.sh:22-24, 183-184`
**Issue:** `_bridge_write_state_entry` acquires the lock via `acquire_lock`, does
work, then calls `release_lock` inline. It deliberately avoids registering a
`trap 'release_lock' EXIT` to prevent clobbering caller-registered traps (documented
in the header comment). This is a sound design for Phase 28, where at most one
bridge is created per invocation.

In Phase 30, the installer will call `bridge_create_project gemini` and
`bridge_create_project codex` sequentially within the same Bash process. If the
process receives SIGINT during the python3 execution window of the first call, and
the installer traps SIGINT and continues (a pattern used by some installers to
provide a "graceful cancel" path), the lock would remain held by the current PID.
The subsequent call to `acquire_lock` would see `LOCK_DIR` with the same `$$` in
the pid file, find the process alive via `kill -0 $$`, and return 1 after 3
retries — causing the second bridge not to be registered.

Self-check: Would the developer say "that's how it's supposed to work"? Yes for
Phase 28 scope; partly yes for Phase 30 (the design tradeoff is documented). The
scenario requires SIGINT-during-python3 AND the installer trapping and ignoring
that signal — unlikely but not impossible.
**Fix:** No action required for Phase 28. Phase 30 should register an EXIT trap
within the install-orchestrator function, separate from the library, to ensure
`release_lock` is called on any exit path:

```bash
# In install.sh Phase 30 orchestrator:
trap 'release_lock 2>/dev/null; true' EXIT
bridge_create_project gemini "$project_root"
bridge_create_project codex "$project_root"
```

---

## STATUS: clean

All three Phase 28 files pass the mandatory invariant checklist. No CRITICAL or
WARNING findings. The three INFO items are documentation suggestions and future-phase
considerations; none affects correctness in Phase 28 scope. The implementation is
sound: lock handling is correct, atomic state mutation is verified, SHA computation
ordering is correct, banner is byte-identical, and all Bash 3.2 compatibility
constraints are honored.

---

_Reviewed: 2026-04-29T21:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
