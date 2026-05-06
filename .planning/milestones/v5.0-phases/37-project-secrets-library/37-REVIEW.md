---
phase: 37-project-secrets-library
reviewed: 2026-05-04T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - scripts/lib/project-secrets.sh
  - scripts/tests/test-project-secrets.sh
  - Makefile
  - .github/workflows/quality.yml
  - manifest.json
findings:
  blocker: 0
  high: 1
  medium: 1
  low: 3
  info: 2
  total: 7
status: findings
---

# Phase 37 — Project Secrets Library — Code Review

**Reviewed:** 2026-05-04
**Depth:** standard (with security focus)
**Files reviewed:** 5
**Status:** findings (1 HIGH, 1 MEDIUM, 3 LOW, 2 INFO)

## Files Reviewed

- `scripts/lib/project-secrets.sh`
- `scripts/tests/test-project-secrets.sh`
- `Makefile` (Test 49 + standalone target additions)
- `.github/workflows/quality.yml` (Tests 35-49 step rename + test invocation)
- `manifest.json` (`files.libs[]` entry)

## Summary

Library implements Phase 37 contract correctly under the explicit assumption that callers pass already-validated keys. All 31 hermetic tests pass, shellcheck clean at `-S warning`, mode 0600 enforced before AND after rewrite under every umask tested (000, 022, 077), `${VAR}` regex exact, SEC-05/06 stderr phrases match test contract verbatim. Test hermeticity solid (no `$HOME` mutation, double-run-safe, no /tmp leaks).

Two real defects test suite does not cover:

1. **HIGH-01:** `project_secrets_write_env` does not validate KEY argument shape. Asymmetry: load-time parser drops invalid keys, but write path accepts them — silent duplicates accumulate, newline-injection in KEY produces multi-line append.
2. **MED-01:** `project_secrets_validate_mcp_env_block` returns rc=0 on malformed JSON because `jq -r ... 2>/dev/null` swallows parse error and empty stdout = zero loop iterations. Defense-in-depth fails open.

---

## HIGH

### HIGH-01 — KEY argument is not validated; lowercase / shell-meta / newline-injected keys silently write to .env and break idempotency

**File:** `scripts/lib/project-secrets.sh:116-178` (function `project_secrets_write_env`), lines 124-127 (only emptiness checked) and line 173 (`printf '%s=%s\n' "$key" "$value"`).

**Issue:**
The function validates only that `$key` is non-empty. The line-parser at lines 76-78 enforces `^[A-Z_][A-Z0-9_]*$` and silently drops violators on read. So a write of an invalid-shape key:

1. **Always misses the collision check** — `_project_secrets_index` is computed from load output (which discarded the invalid key), so it returns 1 (not found), and the code falls through to append branch — even if the key was already present in the file. Multiple writes of the same lowercase/bad key produce duplicates that grow without bound:

   ```text
   project_secrets_write_env "$SAND" lowerkey v1
   project_secrets_write_env "$SAND" lowerkey v2
   project_secrets_write_env "$SAND" lowerkey v3
   $ cat $SAND/.env
   lowerkey=v1
   lowerkey=v2
   lowerkey=v3
   ```

2. **Allows newline injection via the KEY parameter.** A KEY argument containing `\n` produces a multi-line append, second physical line looks like fresh `KEY=VALUE` record:

   ```text
   project_secrets_write_env "$SAND" "$(printf 'K1\nINJECTED=evil')" v1
   $ cat $SAND/.env
   K1=
   INJECTED=evil
   ```

   The parser will pick `INJECTED` up on next load. If caller is Phase 38 wizard pulling key-name from catalog, this is bounded by catalog. If caller is ever a CLI flag, prompt input, or another lib that received the key from a less-trusted source, this becomes secret-line forgery.

3. **Allows shell metacharacters in the key** (`BAD;KEY=value` written verbatim). Future code that ever does `export "$key=$value"` or shells out with `--header "$key:$value"` would be vulnerable.

The library's own private parser already enforces the rule at line 76-78. The asymmetry — value validated, key not — is unsafe.

**Fix:** Validate `$key` at the same boundary as `$value`, before any filesystem touch:

```bash
if [[ -z "$key" ]]; then
    echo -e "${RED}✗${NC} project_secrets_write_env: missing KEY argument" >&2
    return 1
fi
# Defense in depth: refuse keys whose shape would be silently dropped on
# re-read by _project_secrets_load_env (line 76-78 audit L1 guard).
# Also blocks newline injection (printf '%s=%s\n' "$key" splits across lines
# when $key contains '\n') and shell-meta injection.
if [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
    echo -e "${RED}✗${NC} project_secrets_write_env: invalid KEY '${key}' (must match ^[A-Z_][A-Z0-9_]*\$)" >&2
    return 1
fi
```

Also add three test cases mirroring T7..T12: lowercase key rejected, leading-digit key rejected, newline-in-key rejected.

---

## MEDIUM

### MED-01 — `project_secrets_validate_mcp_env_block` returns rc=0 (success) on malformed JSON because jq stderr is suppressed

**File:** `scripts/lib/project-secrets.sh:284`

**Issue:**
The function streams JSON values via `printf '%s' "$json" | jq -r '.[] | tostring' 2>/dev/null` into a `while IFS= read -r v` loop. When `$json` is not parseable JSON, jq writes error to stderr (suppressed) and exits non-zero with no stdout. The while-read loop iterates zero times, falls through to `return 0`. **Defense in depth fails open on malformed input.**

```text
$ project_secrets_validate_mcp_env_block "garbage"
$ echo $?
0    # ← should be 1; "garbage" is not a valid env block
```

The exact-phrase test T21b passes because the test always feeds well-formed JSON. The fail-open path has no test coverage.

**Fix:** Capture jq's exit status, refuse on jq failure:

```bash
local v
local rendered
if ! rendered=$(printf '%s' "$json" | jq -r '.[] | tostring' 2>&1); then
    echo -e "${RED}✗${NC} project_secrets_validate_mcp_env_block: invalid JSON: ${rendered}" >&2
    return 1
fi
while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    if [[ ! "$v" =~ ^\$\{[A-Z_][A-Z0-9_]*\}$ ]]; then
        ...
    fi
done <<< "$rendered"
```

Add test asserting `project_secrets_validate_mcp_env_block "garbage"` returns rc=1.

---

## LOW

### LOW-01 — Lazy source guard fallback emits misleading error when sibling mcp.sh is unreachable

**File:** `scripts/lib/project-secrets.sh:34-40, 128-131`

When `command -v _mcp_validate_value` returns false AND sibling `mcp.sh` cannot be sourced (orphaned install, broken distribution, file permissions), lib silently continues. First call to `_mcp_validate_value` fails with bash "command not found" (rc=127), making `! _mcp_validate_value "$value"` true, returning 1 with `value for KEY contains shell metacharacters — refusing to write`. **Behavior is safe (fail-closed: nothing written), but message is incorrect** — there were no metacharacters; validator was missing.

**Fix:** Either hard-fail at source time when `mcp.sh` unreachable AND `_mcp_validate_value` undefined, or emit distinct error:

```bash
if ! command -v _mcp_validate_value >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} project_secrets_write_env: _mcp_validate_value unavailable (mcp.sh failed to source)" >&2
    return 1
fi
```

---

### LOW-02 — Test cleanup trap covers EXIT only; SIGINT/SIGTERM leave /tmp/project-secrets.* directories behind

**File:** `scripts/tests/test-project-secrets.sh:65`

`trap 'rm -rf "$SANDBOX"' EXIT` does not cover INT or TERM. A developer pressing Ctrl-C mid-test (or CI sending SIGTERM on timeout) leaves orphaned `/tmp/project-secrets.XXXXXX` containing fake `.env` files. Files have mode 0600 so leak risk bounded, but accumulate on shared CI runners.

**Fix:**

```bash
trap 'rm -rf "$SANDBOX"' EXIT INT TERM
```

---

### LOW-03 — `project_secrets_render_mcp_env_block` does not deduplicate keys; documented "duplicates collapse" depends on jq version

**File:** `scripts/lib/project-secrets.sh:228-249`, comment line 224.

Implementation passes all keys (including duplicates) into `jq --args ... reduce $ARGS.positional[]`. JSON object construction does collapse duplicate keys at parse time, but order of duplicate-collapse is implementation-defined. Works today, contract-aware, but worth defensive dedup or explicit test.

---

## INFO

### INFO-01 — `_project_secrets_load_env` silently drops malformed lines from `.env`

**File:** `scripts/lib/project-secrets.sh:51-82`

Line-parser correct — comments, blanks, missing `=`, bad-shape keys all dropped. Matches `mcp_secrets_load` (D-16 reuse). Combined with HIGH-01 means developer hand-editing `.env` to add `lowerkey=foo` sees nothing happen on next read. Consider `TK_PROJECT_SECRETS_DEBUG=1` warn-on-drop seam.

### INFO-02 — `chmod 0600` invoked on mktemp output AFTER mv, not before write

**File:** `scripts/lib/project-secrets.sh:153-164`

Rewrite branch: `mktemp` (mode 0600 on macOS, varies on Linux with umask) → write → `mv` → `chmod 0600`. Tiny window where `tmp` may have wider mode. `mv` is atomic on same filesystem, `chmod` follows immediately, exposure ≤1 ms. Documenting the assumption ("mktemp creates 0600, mv preserves it, chmod is defensive") clearer than silence.

---

## Out-of-Scope Observations (not findings)

- **Bash 3.2 compat:** Verified clean. No `mapfile`, no `${var,,}`/`${var^^}`, no associative arrays, no `realpath -f`. Parameter expansion patterns at lines 67-69 POSIX-portable.
- **Stderr message exact phrases:** All four required phrases match test contract.
- **JSON injection via render:** Keys validated against `^[A-Z_][A-Z0-9_]*$` (line 237) BEFORE entering jq. jq's `--args` injection-safe.
- **TOCTOU between touch and chmod:** Theoretically present, bounded ≤1 ms. Same model as `mcp_secrets_set:525-526`.
- **Test reused TK_MCP_TTY_SRC seam:** Confirmed.
- **Tests use distinct keys per metacharacter rejection:** Correct.
- **Manifest entry placement:** Alpha-ordered between `optional-plugins.sh` and `skills.sh`.
- **Double-run safety:** Tests run twice back-to-back, both rc=0.

---

**Recommendation to merge:** Address HIGH-01 before Phase 38 builds on this lib. MED-01 should be fixed in same patch — both add ~10 lines total. LOW-01..03 can ship as follow-up.
