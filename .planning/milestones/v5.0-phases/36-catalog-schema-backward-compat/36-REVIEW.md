---
phase: 36-catalog-schema-backward-compat
reviewed: 2026-05-04T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - scripts/lib/integrations-catalog.json
  - scripts/validate-integrations-catalog.py
  - scripts/lib/mcp.sh
  - scripts/tests/test-catalog-scope-fallback.sh
  - scripts/tests/test-integrations-catalog.sh
  - scripts/tests/test-integrations-foundation.sh
  - Makefile
findings:
  critical: 0
  warning: 3
  info: 5
  total: 8
status: issues_found
---

# Phase 36: Code Review Report

**Reviewed:** 2026-05-04T00:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 36 introduces the `default_scope` ∈ {`user`,`project`} field on every catalog MCP entry, the validator enum check (Check 11), the loader silent-fallback (`// "user"`), and a hermetic backward-compat test (`test-catalog-scope-fallback.sh`). The schema and validator additions are correct. The four backward-compat scenarios all run in isolated `mktemp -d` sandboxes with `trap RETURN` cleanup, no shared mutable state, and exercise both the present-field and missing-field paths. Bash 3.2 compatibility is preserved (no `mapfile`, no `declare -A`, no `${var,,}` — the only matches in the codebase are comment lines warning future contributors). The Makefile registers `test-catalog-scope-fallback` correctly with `.PHONY` and the orchestrator `test` target.

Three real issues and several info-level observations follow. The most consequential is **WR-01** (a contract regression on `MCP_CATEGORY` that landed silently when `default_scope` was added next to it — same fallback semantics, but the comment claims back-compat that the runtime quietly breaks). The catalog itself, the validator's enum check, and the new test are clean.

Cross-checks completed:
- Catalog JSON schema integrity — every one of 20 MCP entries carries `default_scope` ∈ {`user`,`project`} (verified via grep + visual scan).
- Validator enum check — Check 11 (lines 250–257) runs after the bulk-required-keys gate, so it never fires on a missing-field entry. See WR-02.
- Loader silent-fallback contract — `mcp.sh:169` uses `// "user"` matching the established `// ""` and `// false` patterns. Stderr-clean on missing field (BC1.4 verifies).
- Bash 3.2 — confirmed zero use of `mapfile`, `declare -A`, `${var,,}`, `${var^^}` outside comments.
- Test hermeticity — every scenario in all three test files allocates its own `mktemp -d /tmp/...` sandbox + `trap RETURN` cleanup. No shared globals between scenarios. `wc -c | tr -d ' '` is BSD/GNU portable.
- Makefile — `.PHONY` line covers all 30 targets defined in the file (manually cross-referenced).

## Critical Issues

_(none)_

## Warnings

### WR-01: `MCP_CATEGORY` silent-fallback `""` doubles as sentinel and value — invisible-entry hazard

**File:** `scripts/lib/mcp.sh:138`
**Issue:** Line 138 uses `.category // ""` to silent-fallback a missing `category` field to the empty string. Two downstream consumers compare against this empty string at line 939 (`"${MCP_CATEGORY[$i]:-}" == "$cat"`) and in `_mcp_category_display` at lines 201–223 (which short-circuits on empty input and returns `""`). If a future schema-v1 catalog ever ships an entry with no `category`, that entry is silently dropped from every TUI rendering pass — the per-category `seen_idx` collection at 938–942 never matches, no header is emitted for `""`, and the entry becomes invisible.

The CAT-03 validator now hard-requires `category` to be non-empty (line 184) AND a member of top-level `categories[]` (line 186), so the production catalog cannot ship an entry that triggers this. But the comment on line 136–137 *claims* back-compat with "v4.6 schema-v1 catalogs that lack the `category` field" — that back-compat is broken: such an entry would load without error but disappear from the UI. This is structurally identical to where Phase 36's `default_scope // "user"` lives (line 169), but the new code falls back to a *valid enum value* while the older code falls back to a sentinel.

**Fix:**

```bash
# Phase 34-01: category — hard-required by CAT-03 validator. Default kept
# for defensive runtime read of historical catalogs; routes orphaned entries
# into the existing "dev-tools" bucket so they render instead of vanishing.
MCP_CATEGORY+=("$(jq -r --arg n "$name" '.components.mcp[$n].category // "dev-tools"' "$catalog_path")")
```

Either apply this fallback (preferred — matches the SCOPE-03 pattern), or drop the back-compat claim from the comment block since the validator already rejects this shape.

### WR-02: Validator emits `default_scope`-missing diagnostic via the generic bulk-missing path — BC2.2 passes only by transitive substring match

**File:** `scripts/validate-integrations-catalog.py:166-171, 250-257`
**Issue:** When an entry lacks `default_scope`, the validator triggers the bulk "missing required keys" branch (line 169) and `continue`s past every per-field check (line 171), including Check 11 (the enum check at line 250). The stderr line therefore reads `components.mcp['noscope'] missing required keys: default_scope`. The Phase 36 contract test BC2.2 passes only because the field name appears as the missing key — the assertion is just `grep -q "default_scope" stderr` (test-catalog-scope-fallback.sh:151).

If a contributor ever tweaks the bulk-missing format to elide individual field names (e.g. `missing required keys: <count>`), BC2.2 silently regresses without test failure. The contract test thinks it's locking the missing-field diagnostic, but it's actually piggy-backing on an unrelated formatter.

**Fix (preferred — emit a dedicated diagnostic regardless of the bulk-missing path):**

```python
# Check 11: default_scope must be 'user' or 'project' (Phase 36 / SCOPE-01).
# Emit a dedicated diagnostic even when the field is absent so contract test
# BC2.2 can match without depending on the bulk "missing required keys"
# format. Defense in depth — the bulk-missing block above already lists it.
default_scope = entry.get("default_scope")
if default_scope is None:
    fail(location + ": .default_scope is required (must be 'user' or 'project')")
    errors += 1
elif default_scope not in ("user", "project"):
    fail(
        location + ": .default_scope must be 'user' or 'project', got "
        + repr(default_scope)
    )
    errors += 1
```

Move this block before the `continue` on line 171 (or remove the `continue` entirely — the per-field checks below already tolerate missing keys via `entry.get()`).

### WR-03: BC1.4 silent-stderr assertion swallows diagnostic content on failure

**File:** `scripts/tests/test-catalog-scope-fallback.sh:104-107`
**Issue:** BC1 asserts `stderr_size == 0`. If the loader regresses and writes to stderr, the failure message reads `expected='0' actual='N'` — the actual diagnostic text never reaches the operator. Phase 36 D-11 silent-fallback is a load-bearing contract, so a regression here is high-stakes; capturing the first few lines of stderr into the failure message would make the diagnosis a one-read fix.

This is test hardening, not a runtime defect — BC1 passes today.

**Fix:**

```bash
local stderr_size stderr_excerpt=""
stderr_size=$(wc -c < "$stderr_tmp" | tr -d ' ')
if [[ "$stderr_size" = "0" ]]; then
    assert_pass "BC1.4: loader emits no stderr on missing default_scope (D-11 silent)"
else
    stderr_excerpt=$(head -5 "$stderr_tmp")
    assert_fail "BC1.4: loader emits no stderr on missing default_scope (D-11 silent)" \
        "stderr_size=$stderr_size, excerpt: $stderr_excerpt"
fi
```

## Info

### IN-01: `Makefile:1` `.PHONY` line is unsorted — alphabetizing eases drift detection

**File:** `Makefile:1`
**Issue:** All 30 phony targets are correctly listed (verified via grep — no missing entries), but the order is "insertion order of historic addition." Adding `test-catalog-scope-fallback` at the end follows the established pattern. Alphabetizing the list (or grouping by domain: lint / test / validate) would let `git diff` highlight order-vs-content changes. Not a defect — code-quality observation only.

### IN-02: Validator `sys.exit(1 if errors == 0 else 1)` is a no-op conditional

**File:** `scripts/validate-integrations-catalog.py:138, 143`
**Issue:** Both lines compute `1 if errors == 0 else 1`, which always evaluates to `1`. The likely intent was `sys.exit(1)` directly, or `sys.exit(1 if errors == 0 else errors)` if the author wanted the count. Functionally correct (always exits 1 on this branch), but the conditional is dead code.

**Fix:**

```python
fail('"components" must be an object')
sys.exit(1)
```

Apply on both line 138 and line 143.

### IN-03: `mcp.sh:127, 141` — boolean-to-int conversion spawns 2 jq processes per entry

**File:** `scripts/lib/mcp.sh:127, 141`
**Issue:** Each entry in `MCP_OAUTH` and `MCP_UNOFFICIAL` spawns a fresh `jq` subprocess and pipes the literal string `"true"`/`"false"` through bash for comparison. With 20 catalog entries × ~6 jq invocations per entry inside `mcp_catalog_load`, the loader currently runs ~120 jq subshells per call. This is performance, which the brief excludes from v1 scope — flagging as info only.

A single `jq -c '.components.mcp | to_entries | sort_by(.key) | .[] | [.key, .value.display_name, .value.requires_oauth, ...]'` invocation could populate every parallel array from one process. Worth bookmarking for a future loader refactor.

### IN-04: `test-catalog-scope-fallback.sh:88` heredoc-embedded `bash -c` doubles every escape

**File:** `scripts/tests/test-catalog-scope-fallback.sh:88-94`
**Issue:** The `TK_MCP_CATALOG_PATH=... bash -c "..."` form requires escaping `$` and `"` twice for the inner shell. It works today, but the same logic written as a heredoc-fed inline script (e.g. `bash <<'OUTER' ... OUTER` with single-quoted delimiter to suppress expansion) reads cleaner and avoids a class of escape bugs that hits maintainers six months later. Not a defect.

### IN-05: `test-integrations-foundation.sh` claims ">=10 PASS" but never enforces a floor

**File:** `scripts/tests/test-integrations-foundation.sh:6, 495-496`
**Issue:** The end-of-file gate is `[[ "$FAIL" -eq 0 ]]`. If a future refactor removes scenarios S6–S15 by accident, PASS could legitimately drop below 10 and the test still exits 0. The contract claim in the header is informational only.

**Fix (if the >=10 floor is meaningful):**

```bash
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] && [[ "$PASS" -ge 10 ]]
```

---

_Reviewed: 2026-05-04T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
