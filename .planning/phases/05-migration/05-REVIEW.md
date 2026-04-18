---
phase: 05-migration
reviewed: 2026-04-18T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - Makefile
  - manifest.json
  - scripts/lib/state.sh
  - scripts/migrate-to-complement.sh
  - scripts/tests/fixtures/manifest-migrate-v2.json
  - scripts/tests/test-migrate-diff.sh
  - scripts/tests/test-migrate-flow.sh
  - scripts/tests/test-migrate-idempotent.sh
  - scripts/tests/test-update-drift.sh
  - scripts/update-claude.sh
findings:
  critical: 0
  warning: 2
  info: 5
  total: 7
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-04-18
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 5 (`migrate-to-complement.sh` + `test-migrate-*.sh` harnesses + supporting
`update-claude.sh` drift/hint hooks + `state.sh` lock primitives + fixture manifest)
is a high-quality delivery. The destructive migration contract is implemented
defensively and matches the PLAN/RESEARCH decisions:

- **D-74 backup-before-rm invariant** — `cp -R "$CLAUDE_DIR" "$BACKUP_DIR"`
  runs BEFORE any `rm -f` in the per-file loop and exits 1 with partial-backup
  cleanup if the `cp` fails. `--no-backup` is hard-rejected at the flag parser
  (`migrate-to-complement.sh:29-32`).
- **D-77 migrate hint** — `update-claude.sh:296-308` emits the CYAN hint under
  the triple-AND (`STATE_MODE=standalone` AND `HAS_SP||HAS_GSD=true` AND
  filesystem-intersection non-empty), read-only, and suppresses when no
  intersection. Tests cover both branches.
- **D-78 idempotence early-exit** — Two-signal AND (state.mode != standalone
  AND skip-set ∩ filesystem empty) at `migrate-to-complement.sh:193-205`.
  Self-healing branch (state rolled back to standalone with files already gone)
  correctly falls through to Plan 05-02's no-duplicates exit.
- **D-79 post-migration mode rewrite** — Always `recommend_mode()` regardless of
  partial/full acceptance (`migrate-to-complement.sh:385`); `synth_flag=false`
  is passed explicitly (`:389`), distinguishing production writes from v3.x
  synthesis.
- **Lock-before-mutation** — `acquire_lock` at `:264` precedes backup, which
  precedes any `rm -f`. EXIT trap registered at `:67` (before any fetch) with
  `release_lock 2>/dev/null || true` guard for the pre-source window.
- **Atomic state write** — `state.sh::write_state` uses `tempfile + os.replace`
  and clears the temp on exception (`:101-112`).
- **Path-traversal defense** — `resolve_sp_path` rejects `../`, `./`, and
  absolute paths in `sp_equivalent` (`migrate-to-complement.sh:151-154`).
- **jq/JSON correctness** — All jq invocations are parameterized via
  `--arg`/`--argjson`; no string interpolation into jq expressions.

Two warning-level issues (brittle env-var contract in the test seam and missing
path-traversal defense for non-`sp_equivalent` manifest paths) and five
informational items (naming, parser consistency, minor duplication) remain.

## Warnings

### WR-01: Test seam drops `SP_VERSION`/`GSD_VERSION` leaving them unset under `set -u`

**File:** `scripts/migrate-to-complement.sh:70-82`
**Issue:** When the caller exports `HAS_SP` and `HAS_GSD` (line 70 test seam
branch), the script does NOT set `SP_VERSION` or `GSD_VERSION`. Contract relies
on callers ALSO setting both version vars. Production path via `detect.sh`
(lines 72-74) always exports all four, so this is safe for `curl | bash`. But
any future caller (CI harness, third-party wrapper, or a typo in a future test)
that sets `HAS_SP=true` without `SP_VERSION` will trip `set -u` at line 155
(`[[ -z "$SP_VERSION" ]]`) with a cryptic "unbound variable" error rather than
the intended empty-string behavior.

The `curl`-failure branch (lines 75-81) correctly initializes both versions to
`""`, but the test-seam branch at lines 70-71 does not — the `:` no-op
short-circuits the fallback init.

**Fix:** Normalize version vars unconditionally after the HAS_SP/HAS_GSD block:
```bash
if [[ -n "${HAS_SP+x}" && -n "${HAS_GSD+x}" ]]; then
    :
elif curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" 2>/dev/null; then
    source "$DETECT_TMP"
else
    log_warning "Could not fetch detect.sh — plugin detection unavailable"
    HAS_SP=false
    HAS_GSD=false
fi
# Normalize version vars — defensive default regardless of which branch ran
SP_VERSION="${SP_VERSION:-}"
GSD_VERSION="${GSD_VERSION:-}"
```

### WR-02: `rel` paths from manifest enter `rm -f`/`[[ -f ]]` without path-traversal validation

**File:** `scripts/migrate-to-complement.sh:212`, `:316`, `:329`, `:370`, `:372`
**Issue:** `resolve_sp_path` defensively rejects `../`, `./`, and absolute paths
in the `sp_equivalent` value (`:151-154`). The same defense is NOT applied to
the `path` field coming from `manifest.files.*[].path`, which is used directly
in `$CLAUDE_DIR/$rel` for:
- `[[ -f "$CLAUDE_DIR/$rel" ]]` at lines 212, 370
- `rm -f "$local_path"` at lines 316, 329 (where `local_path="$CLAUDE_DIR/$rel"`)
- `FINAL_INSTALLED_CSV` builder at line 372

Exploitability is low in practice: `manifest.json` is fetched over HTTPS from
`raw.githubusercontent.com/sergei-aronsen/...` and is a toolkit-owned artifact.
A malicious manifest with `"path": "../../../.bashrc"` would let migrate `rm -f`
the user's `.bashrc` — but this requires compromising the repo or MITM the
cURL. Still, symmetric defense with `resolve_sp_path` is cheap and removes the
"manifest is trusted" assumption.

**Fix:** Apply the same traversal check at the point manifest paths are
enumerated. Either short-circuit the duplicate-enumeration loop:
```bash
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    # Reject path traversal and absolute paths (symmetric with resolve_sp_path)
    if [[ "$rel" == *"/../"* || "$rel" == *"/./"* || "$rel" == /* || "$rel" == ..* ]]; then
        log_warning "Rejected suspicious manifest path: $rel"
        continue
    fi
    if [[ -f "$CLAUDE_DIR/$rel" ]]; then
        DUPLICATES+=("$rel")
    fi
done < <(jq -r '.[]' <<<"$SKIP_SET_JSON")
```
Or validate at manifest-load time against a single regex
(`^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*$`) and fail fast if any entry violates it.
The same defense should be added to `update-claude.sh` where the same `rel`
values flow into `rm -f "$CLAUDE_DIR/$rel"` (`update-claude.sh:534`).

## Info

### IN-01: `BACKUP_DIR` uses `$HOME`, not `$(dirname "$CLAUDE_DIR")`

**File:** `scripts/migrate-to-complement.sh:267`
**Issue:** `BACKUP_DIR="$HOME/.claude-backup-pre-migrate-$(date -u +%s)"`. Under
the `TK_MIGRATE_HOME` test seam, `CLAUDE_DIR` is redirected to `$TK_MIGRATE_HOME/.claude`
but `BACKUP_DIR` still uses `$HOME`. Tests correctly work around this by
explicitly also setting `HOME="$SCR"` (e.g.
`test-migrate-flow.sh:103,156,204,342`), which makes the test contract awkward:
callers must remember to override both variables together.

Symmetry with `update-claude.sh:456` (which uses `"$(dirname "$CLAUDE_DIR")/.claude-backup-$(date -u +%s)-$$"`)
would be cleaner.

**Fix:** Derive the backup location from `CLAUDE_DIR` instead of `HOME`:
```bash
BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-pre-migrate-$(date -u +%s)"
```
The `$$` suffix in `update-claude.sh:456` also prevents collisions when two
processes start within the same second (unlikely with the lock, but harmless).

### IN-02: `Makefile` validates `manifest.json` version via `grep`/`sed` instead of `jq`

**File:** `Makefile:119-121`
**Issue:** The version-alignment check uses:
```make
MANIFEST_VER=$$(grep -m1 '"version"' manifest.json | sed 's/.*"version": *"\([^"]*\)".*/\1/')
```
This works today because `"manifest_version"` does not contain the literal
substring `"version"` (the `v` is preceded by `_`, not `"`), but the regex is
fragile: any future field named e.g. `"version_policy"` or a reformat that puts
`"version"` on a different line would break it silently.

The rest of the codebase uses `jq` for JSON parsing.

**Fix:** Replace with `jq` for consistency and robustness:
```make
@MANIFEST_VER=$$(jq -r '.version' manifest.json); \
    CHANGELOG_VER=$$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/'); \
    if [ "$$MANIFEST_VER" != "$$CHANGELOG_VER" ]; then \
        ...
```

### IN-03: `local_switch_decision` variable is not actually `local` (at top level)

**File:** `scripts/update-claude.sh:375,377,378,381,385`
**Issue:** Variable name begins with `local_` but is declared at the top level
of the script (line 375), not inside a function. The `local` keyword is not
used (and cannot be used there). The `local_` prefix is misleading — a reader
might grep for `local local_switch_decision` expecting a function-scoped var.

**Fix:** Rename to a neutral name. The same applies to `local_prune_decision`
at line 519. Suggested:
```bash
switch_decision="N"
...
prune_decision="N"
```

### IN-04: Duplicate `install_status=1` branch in `update-claude.sh:471-484`

**File:** `scripts/update-claude.sh:471-484`
**Issue:** The `TK_UPDATE_FILE_SRC` test-seam branch already sets
`install_status=1` as the pre-loop default; the explicit `install_status=1` at
line 477 (inside the `else` clause) is redundant. Minor, but the parallel
structure reads cleaner if both branches only set `install_status` on success:
```bash
install_status=1
if [[ -n "${TK_UPDATE_FILE_SRC:-}" ]]; then
    if [[ -f "$TK_UPDATE_FILE_SRC/$rel" ]]; then
        cp "$TK_UPDATE_FILE_SRC/$rel" "$dest" && install_status=0
    fi
else
    curl -sSLf "$REPO_URL/$rel" -o "$dest" 2>/dev/null && install_status=0
fi
```

### IN-05: `migrate-to-complement.sh` help output uses `sed -n '3,18p'` hardcoded range

**File:** `scripts/migrate-to-complement.sh:34`
**Issue:** `sed -n '3,18p' "${BASH_SOURCE[0]}"` hardcodes line numbers. Any
future edit that moves the header block (e.g. inserting a shebang-line comment)
silently shifts the help output. This is a minor maintainability trap.

**Fix:** Either parse the contiguous `#`-comment block at the top
programmatically (from first `#` line up to the first blank-or-non-`#` line), or
add a marker comment pair:
```bash
# ---8<--- HELP START
# Claude Code Toolkit — ...
# ...usage...
# ---8<--- HELP END
```
and extract with `sed -n '/HELP START/,/HELP END/{/HELP START\|HELP END/!p}'`.

---

_Reviewed: 2026-04-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
