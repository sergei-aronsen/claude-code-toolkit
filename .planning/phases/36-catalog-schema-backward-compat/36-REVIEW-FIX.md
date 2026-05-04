---
phase: 36-catalog-schema-backward-compat
fixed_at: 2026-05-04T00:00:00Z
review_path: .planning/phases/36-catalog-schema-backward-compat/36-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 36: Code Review Fix Report

**Fixed at:** 2026-05-04T00:00:00Z
**Source review:** `.planning/phases/36-catalog-schema-backward-compat/36-REVIEW.md`
**Iteration:** 1

**Summary:**

- Findings in scope: 3 (Critical: 0, Warning: 3)
- Fixed: 3
- Skipped: 0
- Info findings (5): out of scope per `fix_scope=critical_warning`

## Verification

- `make check` — PASS (markdownlint, shellcheck, validate-templates, version alignment, README translation drift, agents conflicts annotations, commands headings, integrations-catalog schema, markdownlint-config alignment, skills Desktop-safety audit). Validator reports `integrations-catalog.json validation PASSED (20 mcp entries checked across 10 categories)`.
- `make test` — PASS (48/48 tests, exit 0, 1476 lines, terminating with `All tests passed!`). All `FAIL: 0` footers seen are summary lines reporting zero failures, not actual failures. Test 48 (`test-catalog-scope-fallback.sh`) reports `PASS=9 FAIL=0`.

## Fixed Issues

### WR-01: `MCP_CATEGORY` silent-fallback `""` doubles as sentinel and value — invisible-entry hazard

**Files modified:** `scripts/lib/mcp.sh`
**Commit:** `50dfb77`
**Applied fix:** Changed the silent-fallback for the `category` field on line 138 from `// ""` to `// "dev-tools"`. Historical (v4.6 schema-v1) catalogs that lack the `category` field will now route orphaned entries into the existing `dev-tools` bucket so they render in the TUI instead of vanishing under the empty-string sentinel that fails to match any per-category header. This aligns the older `category` fallback with the SCOPE-03 pattern on line 169 (`default_scope // "user"`) — both now fall back to a *valid enum value* rather than a sentinel. Updated the inline comment to reflect the new contract.

### WR-02: Validator emits `default_scope`-missing diagnostic via the generic bulk-missing path — BC2.2 passes only by transitive substring match

**Files modified:** `scripts/validate-integrations-catalog.py`
**Commit:** `ef2bee2`
**Applied fix:** Removed `default_scope` from `REQUIRED_ENTRY_KEYS` and rewrote Check 11 to emit two distinct dedicated diagnostics:

- `: .default_scope is required (must be 'user' or 'project')` when the field is absent.
- `: .default_scope must be 'user' or 'project', got <repr>` when it is present but invalid.

Because `default_scope` no longer participates in the bulk-required-keys gate, Check 11's missing-field branch always fires on synthetic catalogs that omit the field — locking BC2.2's `grep -q "default_scope"` against a stable, dedicated message instead of piggy-backing on the bulk formatter's substring shape. Defense in depth: BC4.2's invalid-enum path is unchanged. Verified by running `test-catalog-scope-fallback.sh` (BC1–BC4: 9/9 PASS) and the full-catalog validator (`PASSED (20 mcp entries / 10 categories)`).

### WR-03: BC1.4 silent-stderr assertion swallows diagnostic content on failure

**Files modified:** `scripts/tests/test-catalog-scope-fallback.sh`
**Commit:** `5c50fcc`
**Applied fix:** Replaced the bare `assert_eq "0" "$stderr_size" ...` on the BC1.4 D-11 silent-contract assertion with an explicit `if`/`else` branch. On regression, the failure message now includes `stderr_size=$N, first-5-lines: ...` (newline-collapsed via `tr '\n' '|'` to keep the message single-line and readable). On success, the existing `assert_pass` is called unchanged. This is test hardening — BC1.4 still passes today, but a future regression's diagnostic text now reaches the operator without re-running the test by hand.

---

_Fixed: 2026-05-04T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
