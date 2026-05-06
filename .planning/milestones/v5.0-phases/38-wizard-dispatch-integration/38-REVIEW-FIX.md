---
phase: 38-wizard-dispatch-integration
fixed: 2026-05-05
findings_addressed: 6
findings_deferred: 2
review_path: .planning/phases/38-wizard-dispatch-integration/38-REVIEW.md
iteration: 1
status: all_fixed
---

# Phase 38 — Wizard Dispatch Integration — Code Review Fix Report

**Fixed at:** 2026-05-05
**Source review:** `.planning/phases/38-wizard-dispatch-integration/38-REVIEW.md`
**Iteration:** 1

## Summary

- Findings in scope: 6 (HIGH-01 + MED-01 + MED-03 + LOW-01 + INFO-01 + INFO-02)
- Findings deferred: 2 (MED-02 + LOW-02 — pre-existing pre-Phase-38 code, out of scope)
- Fixed: 6
- Skipped: 0

**Test deltas:**

- `scripts/tests/test-mcp-wizard.sh`: 52 PASS → 53 PASS (+1 from INFO-02 positive assertion)
- `scripts/tests/test-mcp-secrets.sh`: 11 PASS (unchanged)
- `scripts/tests/test-project-secrets.sh`: 42 PASS (unchanged)
- Wizard test suite verified idempotent (twice in a row, same exit 0 / 53 PASS)
- `make shellcheck`: clean
- `make check`: green (exit 0)

---

## Fixed Issues

### MED-01: `install.sh:857` and `:892` use `set -- $_row` at script top-level

**File modified:** `scripts/install.sh`
**Original location:** `scripts/install.sh:853-868` (user block) + `:888-903` (project block)
**Commit:** `480be76`

**Applied fix:** Wrapped the `set -- $_row` body inside a `( ... )` subshell in BOTH the user-block (now lines 858-873) and the project-block (now lines 897-912). Mutation of `$@`/`$1`/`$2` is now contained per row; the script's top-level positional params survive the summary loops untouched. Removed the redundant `_IFS_SAVED2`/`_k` cleanup (subshell exit reclaims them); only `_row` cleanup retained at the top level. Inline comments cite the MED-01 finding with the latent-time-bomb rationale.

**Test added:** None — existing T11 (DISP-04) covers the summary printer's behavioural contract. Subshell change is a containment refactor with no observable output difference.

---

### MED-03: T12 function override leaks into parent shell namespace

**File modified:** `scripts/tests/test-mcp-wizard.sh`
**Original location:** `scripts/tests/test-mcp-wizard.sh:493-519`
**Commit:** `6b46c6d`

**Applied fix:** Wrapped the `project_secrets_render_mcp_env_block` override + the `mcp_wizard_run` call in a single subshell, so the function override cannot leak. Dropped the fragile `unset -f` + re-source dance (lines 517-519 of the pre-fix file) — subshell exit guarantees the real lib's render function is the one any downstream test re-uses. Stderr capture form changed from `ERR=$( ... ) || DEF_RC=$?` to `ERR=$( ( ... ) ) || DEF_RC=$?` to wrap the override + call inside the subshell while keeping the same exit-code propagation.

**Test added:** None — T12 already exercises the contract; the change is a containment refactor.

---

### LOW-01: user-scope defer branch bypasses key-shape validation

**File modified:** `scripts/lib/mcp.sh`
**Original location:** `scripts/lib/mcp.sh:796-809`
**Commit:** `e553a61`

**Applied fix:** Added a defensive `^[A-Z_][A-Z0-9_]*$` shape check to the user-scope defer stub loop, mirroring the audit L1 guard in `mcp_secrets_load` (mcp.sh:496) and the parse-time filter in `_project_secrets_load_env` that the project-scope sibling gets for free. Curated catalog keys all match this shape, so today's behaviour is unchanged; defense-in-depth gap closed for any future catalog typo or schema drift.

**Test added:** None — change is pure defense-in-depth on a code path whose positive contract is already exercised by T10 (defer+user 4-tuple back-compat). Adding a negative test would require synthesising a malformed catalog entry (out of phase scope).

---

### HIGH-01: load-bearing invariant in defer block needs inline comment

**File modified:** `scripts/lib/mcp.sh`
**Original location:** `scripts/lib/mcp.sh:782-793`
**Commit:** `a7da36b`

**Applied fix:** Added an inline comment above the per-iteration `_project_secrets_load_env "$_proj_env"` call documenting that the load-per-iteration is **load-bearing** — it is the cycle-breaker that preserves "see your own previous stubs" semantics within a single wizard run. Comment explicitly says "DO NOT lift this load out of the loop" so a future maintainer attempting an "optimization" cannot silently break the invariant. Mentions the user-scope sibling (now ~line 813) which has the same load-per-iteration pattern via `mcp_secrets_load`.

**Test added:** None — pure documentation change.

---

### INFO-01: comment drift on `mcp.sh:749`

**File modified:** `scripts/lib/mcp.sh`
**Original location:** `scripts/lib/mcp.sh:746-751`
**Commit:** `a7da36b` (grouped with HIGH-01)

**Applied fix:** Updated the comment to reference `install.sh:809` (the actual 4-field reader location) instead of `install.sh:833` (which is the bash detection branch).

**Test added:** None — pure documentation fix.

---

### INFO-02: T9 missing positive assertion that `claude.argv` was written

**File modified:** `scripts/tests/test-mcp-wizard.sh`
**Original location:** `scripts/tests/test-mcp-wizard.sh:340-381`
**Commit:** `bdfab01`

**Applied fix:** Added a positive assertion before T9's cleanup that `$SANDBOX/claude.argv` exists, with a comment citing the rc=3 contract: `claude mcp add` IS invoked under defer+project (registration happens, just no env binding). Mirror of T12's "claude must NOT be invoked" assertion. Closes the regression hole where a future change making the defer branch skip `claude mcp add` entirely would still pass T9 (the `rm -f` at line 381 assumed argv existence but never asserted it). Wizard test suite PASS count goes from 52 to 53.

**Test added:** Yes — single new positive assertion in T9 (DISP-03). Verified PASS=53 after fix.

---

## Deferred Issues

### MED-02: `project_secrets_ensure_gitignore` newline-detection mis-handles NUL-byte trailing

**File:** `scripts/lib/project-secrets.sh:218-221`
**Reason:** Pre-existing Phase 37 code; not regressed by Phase 38. `tail -c 1 | command-substitution` strips NUL bytes — pathological case only (NUL in `.gitignore` is legal but rare). Out of Phase 38 scope per the review's recommendation; flagged for awareness in a future phase if needed.

---

### LOW-02: `_shell_rc` write at `install.sh:843-846` untested by Phase 38 harness

**File:** `scripts/install.sh:826-848`
**Reason:** Pre-existing v4.9 code; the test harness blanket workaround (`unset ZSH_VERSION BASH_VERSION SHELL` at test-mcp-wizard.sh:425) neutralises the rc-write branch. Touching it would expand Phase 38's test surface beyond its stated scope. Out of Phase 38 scope per the review's recommendation; flagged for awareness in a future phase.

---

## Commit Manifest

| # | Commit | Subject |
|---|--------|---------|
| 1 | `480be76` | fix(38): MED-01 wrap install.sh summary set-- in subshell (positional-param leak) |
| 2 | `6b46c6d` | fix(38): MED-03 isolate T12 function override in subshell (test-mcp-wizard.sh) |
| 3 | `e553a61` | fix(38): LOW-01 add ^[A-Z_][A-Z0-9_]*$ shape check to user-scope defer stub branch |
| 4 | `a7da36b` | chore(38): HIGH-01 + INFO-01 inline comments — load-bearing invariant + line number drift |
| 5 | `bdfab01` | test(38): INFO-02 positive assertion that claude.argv created under defer+project (T9 mirror of T12) |

---

## Verification Run

```text
bash scripts/tests/test-mcp-wizard.sh         → 53 passed, 0 failed (was 52)
bash scripts/tests/test-mcp-wizard.sh (rerun) → 53 passed, 0 failed (idempotent)
bash scripts/tests/test-mcp-secrets.sh        → 11 passed, 0 failed (unchanged)
bash scripts/tests/test-project-secrets.sh    → 42 passed, 0 failed (unchanged)
make shellcheck                               → clean
make check                                    → exit 0 (green)
```

---

_Fixed: 2026-05-05_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
