---
phase: 37-project-secrets-library
fixed: 2026-05-04T00:00:00Z
review_path: .planning/phases/37-project-secrets-library/37-REVIEW.md
iteration: 1
findings_in_scope: 2
findings_addressed: 2
findings_deferred: 5
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 37 — Project Secrets Library — Review Fix Report

**Fixed at:** 2026-05-04
**Source review:** `.planning/phases/37-project-secrets-library/37-REVIEW.md`
**Iteration:** 1
**Test floor:** 31 → 42 (+11 assertions)

**Summary:**

- Findings in scope: 2 (1 HIGH + 1 MEDIUM)
- Fixed: 2
- Skipped: 0
- Deferred (out of scope): 5 (3 LOW + 2 INFO)
- Bonus bundled: 1 (LOW-02 — 1-line trap signal coverage)

`make check` green. `bash scripts/tests/test-project-secrets.sh` green twice in a row (idempotent + double-run-safe per D-20). shellcheck `-S warning` clean.

---

## Fixed Issues

### HIGH-01 — KEY argument is not validated; lowercase / shell-meta / newline-injected keys silently write to .env and break idempotency

**Original location:** `scripts/lib/project-secrets.sh:116-178` (function `project_secrets_write_env`)
**Files modified:** `scripts/lib/project-secrets.sh`, `scripts/tests/test-project-secrets.sh`
**Commit:** `6b73b3d` — `fix(37): SEC-01 enforce KEY shape on project_secrets_write_env (HIGH-01)`

**Fix applied:**
Added `^[A-Z_][A-Z0-9_]*$` regex validation immediately after the empty-key guard and BEFORE `_mcp_validate_value "$value"` (so the rejection happens at the same boundary as value validation, before any filesystem touch). Locked stderr phrase: `✗ project_secrets_write_env: invalid KEY '<key>' (must match ^[A-Z_][A-Z0-9_]*$)` — dollar in regex escaped to prevent bash expansion. Inline comment ties the fix to the symmetric load-time guard at `_project_secrets_load_env:76-78`.

**Tests added (+9 assertions, mirror T7..T12 pattern):**

- T12a — lowercase key rejected (rc=1) + `invalid KEY` stderr phrase + no-mutation guard via `shasum` before/after
- T12b — leading-digit key rejected (rc=1) + stderr phrase + no-mutation guard
- T12c — newline-in-key rejected (rc=1) + stderr phrase + no-mutation guard

The no-mutation assertion is the key regression contract: it proves `.env` contents are byte-identical across the rejection path, which directly defeats the original silent-duplicate accumulation bug AND the newline-injection forgery (`K1\nINJECTED=evil` → second physical line forges a fresh `KEY=VALUE` record on next load).

---

### MED-01 — `project_secrets_validate_mcp_env_block` returns rc=0 (success) on malformed JSON because jq stderr is suppressed

**Original location:** `scripts/lib/project-secrets.sh:284`
**Files modified:** `scripts/lib/project-secrets.sh`, `scripts/tests/test-project-secrets.sh`
**Commit:** `c130997` — `fix(37): SEC-05 fail-closed on malformed JSON in validate_mcp_env_block (MED-01)`

**Fix applied:**
Refactored the value-iteration block to capture jq's combined stderr+stdout into a `rendered` variable in two stages:

1. Run jq once: `rendered="$(printf '%s' "$json" | jq -r '.[] | tostring' 2>&1)"`
2. Branch on exit status: `if !` → emit `✗ project_secrets_validate_mcp_env_block: invalid JSON: ${rendered}` and return 1
3. Empty-rendered short-circuit (handles `[]` / `{}` correctly without the `<<< ""` empty-line edge case)
4. Iterate values via `<<< "$rendered"` herestring (Bash 3.2 portable, no process substitution)

Defense-in-depth now fails closed on malformed input — the previous `2>/dev/null` + zero-loop-iteration path that fell through to `return 0` is gone.

**Tests added (+2 assertions):**

- T24 — `project_secrets_validate_mcp_env_block "garbage"` returns rc=1
- T24-stderr — refusal stderr contains `invalid JSON`

---

## Bonus Bundled

### LOW-02 — Test cleanup trap covers EXIT only; SIGINT/SIGTERM leave /tmp/project-secrets.* directories behind

**Original location:** `scripts/tests/test-project-secrets.sh:65`
**Bundled into commit:** `c130997` (MED-01 commit)

**Rationale:** 1-character addition (`EXIT` → `EXIT INT TERM`), zero risk, zero code review surface, and it lives in the same test file as MED-01. Bundling avoids a single-character third commit while still being independently revertable via `git revert -p`.

**Fix applied:** `trap 'rm -rf "$SANDBOX"' EXIT INT TERM` — Ctrl-C and CI SIGTERM no longer leak sandbox directories on shared runners.

---

## Deferred Issues

### LOW-01 — Lazy source guard fallback emits misleading error when sibling mcp.sh is unreachable

**Reason:** Out of scope for Phase 37 fix-pass. The behavior is fail-closed (refusal, not silent corruption); only the error message is misleading. Not a security defect — defer to Phase 38 follow-up where the wizard actually exercises the source-failure path under broken-distribution conditions. Fix is pure ergonomics and risks adding a new error path that would need its own test contract.

### LOW-03 — `project_secrets_render_mcp_env_block` does not deduplicate keys

**Reason:** Out of scope. Documented behavior matches today's jq runtime (last-wins on duplicate object keys per jq parser), and the lib's only caller (Phase 38 wizard) draws keys from the catalog where duplicates would already be a catalog defect. Deferring per the reviewer's "worth defensive dedup or explicit test" note — the test gap is the real risk, not the missing dedup itself, and that test belongs alongside Phase 38's catalog-driven invocation.

### INFO-01 — `_project_secrets_load_env` silently drops malformed lines from `.env`

**Reason:** Out of scope. The drop-on-load behavior is intentional (matches `mcp_secrets_load` per D-16) and HIGH-01's fix now eliminates the asymmetry that made it observable from the toolkit's own write path. Reviewer's `TK_PROJECT_SECRETS_DEBUG=1` warn-on-drop seam is a feature request, not a defect.

### INFO-02 — `chmod 0600` invoked on mktemp output AFTER mv, not before write

**Reason:** Out of scope. Reviewer accepted the bound (≤1 ms exposure window), confirmed `mktemp` creates 0600 on macOS and the umask defaults are tested (D-04 step 7). This is a documentation request, not a defect — the model matches `mcp_secrets_set:525-526` and the existing test suite already verifies mode 0600 under umask 000/022/077. No code change warranted.

---

## Verification

**Test suite (Phase 37 / TEST-01):**

```text
=== Results: 42 passed, 0 failed ===
```

PASS floor raised: 31 → 42 (+11 assertions). Verified twice in a row (idempotent + double-run-safe per D-20).

**Quality gate (`make check`):** green. Includes `shellcheck -S warning`, markdownlint, manifest validation, version alignment, prompt pipeline markers, agent collision static check.

**Bash 3.2 compat:** verified — no `mapfile`, no `${var,,}`, no associative arrays, no process substitution in MED-01 fix (`<<<` herestring instead).

**Stderr phrase contracts:**

- HIGH-01: `✗ project_secrets_write_env: invalid KEY '<key>' (must match ^[A-Z_][A-Z0-9_]*$)` — matches T12a/b/c grep contract `invalid KEY`
- MED-01: `✗ project_secrets_validate_mcp_env_block: invalid JSON: <jq error>` — matches T24-stderr grep contract `invalid JSON`

---

_Fixed: 2026-05-04_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
