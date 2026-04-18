---
phase: 03-install-flow
reviewed: 2026-04-18T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - Makefile
  - scripts/init-claude.sh
  - scripts/init-local.sh
  - scripts/lib/install.sh
  - scripts/setup-security.sh
  - scripts/tests/fixtures/manifest-v2.json
  - scripts/tests/test-dry-run.sh
  - scripts/tests/test-modes.sh
  - scripts/tests/test-safe-merge.sh
  - scripts/update-claude.sh
findings:
  critical: 0
  warning: 5
  info: 7
  total: 12
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-04-18T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 3 (install flow) wires a new sourced library `scripts/lib/install.sh` into three callers (`init-claude.sh`, `init-local.sh`, `setup-security.sh`) and adds three integration tests. The overall design is sound: the library invariants are respected (zero stdout on source, no `errexit`/`pipefail` side effects, verified empirically with bash 3.2 on macOS), `_tk_owned`-marker partitioning in `merge_settings_python` correctly preserves foreign SP/GSD hooks, `backup_settings_once` is idempotent per-run, and `compute_skip_set` uses safe `jq --argjson` binding (no command injection). All Python `-c` one-liners pass shell values via `sys.argv` (not string interpolation), so JSON escaping and injection are correctly handled.

No Critical issues were found. Five Warnings relate to race/ordering in lock acquisition, unsafe `echo` of downloaded content, timestamp collisions in `.bak.<unix-ts>` filenames, and the absence of a `manifest_version` guard in `update-claude.sh` (likely a Phase 4 item). Seven Info items cover minor style, duplication between `init-claude.sh` and `init-local.sh`, and unused test-related variables.

The phase is in good shape; none of the warnings block merge, but WR-01 and WR-03 deserve follow-ups before v4 release.

## Warnings

### WR-01: `acquire_lock` called before `release_lock` EXIT trap is installed in `init-local.sh`

**File:** `scripts/init-local.sh:247-248`
**Issue:** `scripts/lib/state.sh:10-11` documents the invariant "Callers MUST register `trap 'release_lock' EXIT` BEFORE calling acquire_lock." `init-claude.sh:401-402` obeys this (trap first, then acquire). `init-local.sh` does the opposite:

```bash
acquire_lock || exit 1         # line 247 — lock directory created here
trap 'release_lock' EXIT       # line 248 — trap registered only AFTER lock exists
```

If the script receives SIGINT (Ctrl-C) or a `set -e` failure between lines 247 and 248 (narrow but real window — these are separate commands), the lock directory is left behind. The stale-lock reclaim in `acquire_lock` (PID liveness + 3600s mtime) will eventually clear it, but the next run within 1h will see a false "another install in progress" message for the recorded PID of the dead process.

Also note: if `acquire_lock` returns 1 (conflict), `|| exit 1` triggers — the trap is not yet armed, but no lock was acquired on this path, so that specific failure path is safe. The issue is only when `acquire_lock` succeeds and a signal fires before line 248.

**Fix:** Swap the order to match the invariant and `init-claude.sh`:

```bash
trap 'release_lock' EXIT
acquire_lock || exit 1
```

---

### WR-02: `.bak.$(date +%s)` timestamp collisions overwrite prior backups in same second

**File:** `scripts/lib/install.sh:66`, `scripts/init-claude.sh:123,131`, `scripts/init-local.sh:148,156`
**Issue:** Five separate call sites derive backup filenames from `$(date +%s)` (1-second resolution). `backup_settings_once` is guarded by the `TK_SETTINGS_BACKUP` sentinel so it cannot collide within a single run, but:

1. The mode-change backup in `init-claude.sh:123` vs. `131` is within the same `if/else` of the same run — if a user runs `--force --mode X --force-mode-change` twice in the same second (scripting / CI), the second run overwrites the first backup of `toolkit-install.json.bak.<ts>`.
2. `setup-security.sh` may re-run within the same second while `TK_SETTINGS_BACKUP` is a process-scoped global — a second invocation in the same second collides.

This is a low-exploitability data-loss risk (prior-run backup is clobbered), not a security issue. Given the test harness in `test-safe-merge.sh` explicitly expects `.bak.<unix-ts>` (scenario 8b), changing the format is a breaking contract change for the test.

**Fix:** Append a `mktemp`-style random suffix or the PID to guarantee uniqueness without breaking the numeric-timestamp assertion:

```bash
TK_SETTINGS_BACKUP="${settings_path}.bak.$(date +%s).$$"
# Update scripts/tests/test-safe-merge.sh:126 case pattern to:
"$settings".bak.[0-9]*.[0-9]*) report_pass ...
```

Or, switch to `mktemp` directly for collision-free semantics and keep `.bak.` prefix for discoverability.

---

### WR-03: `setup-security.sh` uses `echo` for untrusted-length downloaded content

**File:** `scripts/setup-security.sh:70,79,88,92,95,100,103,105,110`
**Issue:** `SECURITY_CONTENT` is captured from `curl` and then passed through many stages of `echo "$SECURITY_CONTENT" | grep ...`, `echo "$SECURITY_CONTENT" > "$CLAUDE_MD"`, etc. Problems:

1. `echo` behavior with backslash escapes and leading `-e` / `-n` is implementation-defined (bash `echo` vs `/bin/echo` vs `printf`). If a future template file starts with `-n` or contains `\b`, it silently produces wrong output.
2. Command-substitution strips trailing newlines — re-emitting via `echo` adds exactly one, which may silently drop multiple trailing newlines that matter for markdown parity.
3. `SECTIONS=$(echo "$SECURITY_CONTENT" | grep -n '^## [0-9]\+\.')` — if the download quietly truncates (network stall), the section-by-section merge will think entire sections are "missing" and re-append them, causing duplication on `CLAUDE.md`.

Today the content is TK-controlled markdown so this is not exploitable, but the pattern is brittle.

**Fix:** (a) Replace `echo "$VAR"` with `printf '%s\n' "$VAR"` throughout this function. (b) Validate the download succeeded with a sentinel such as the `MARKER` string before writing:

```bash
if ! printf '%s' "$SECURITY_CONTENT" | grep -q "$MARKER"; then
    echo -e "  ${RED}✗${NC} Downloaded security template is missing the expected marker — aborting merge"
    exit 1
fi
```

---

### WR-04: `update-claude.sh` missing `manifest_version=2` guard

**File:** `scripts/update-claude.sh:92-101`
**Issue:** `init-claude.sh:89-93` and `init-local.sh:65-69` hard-fail if `manifest.json` has `manifest_version != 2`. `update-claude.sh` parses only `"version"` (the product version) with a fragile `grep | cut`:

```bash
REMOTE_VERSION=$(echo "$MANIFEST" | grep -o '"version": "[^"]*"' | head -1 | cut -d'"' -f4)
```

Without the schema guard, a future `manifest_version=3` rollout that renames or restructures `files.*` would cause `update-claude.sh` to silently skip entries (every `curl ... || log_warning "Skipped"` is non-fatal) and then write a bogus `.toolkit-version` pointing at the new version. Users running `update-claude.sh` during a v4→v5 migration would get a half-installed state.

The source comment on line 22 ("Phase 4 (UPDATE-01) will branch on them") suggests this is acknowledged. Flagged here so it is not forgotten.

**Fix:** Add the same v2 guard near line 98 before proceeding:

```bash
MANIFEST_VER=$(echo "$MANIFEST" | jq -r '.manifest_version' 2>/dev/null || echo "")
if [[ "$MANIFEST_VER" != "2" ]]; then
    log_error "manifest.json has manifest_version=${MANIFEST_VER:-unknown}; this updater expects v2"
    exit 1
fi
```

---

### WR-05: `download_extras` uses `curl -sSL` without `-f`, masking 404s

**File:** `scripts/init-claude.sh:366-374`
**Issue:** The main `download_files` loop correctly uses `curl -sSLf` (line 421) so an HTTP 404 is a failure. But the extras loop (line 366) uses only `curl -sSL` without `-f`:

```bash
if curl -sSL "$full_url" -o "$full_dest" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $dest"
```

Without `-f`, curl writes the literal HTML "404 Not Found" body into `$full_dest` and returns 0. The user then sees a `✓` next to e.g. `cheatsheets/zh.md` but the file contains GitHub's error page. The fallback branch (`base_src=...`) also uses no `-f` (line 372), so a typo in a framework name silently writes HTML to `CLAUDE.md`.

**Fix:** Add `-f` to both curls and fail fast:

```bash
if curl -sSLf "$full_url" -o "$full_dest" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $dest"
else
    base_src="${src/templates\/$FRAMEWORK/templates\/base}"
    if ! curl -sSLf "$REPO_URL/$base_src" -o "$full_dest" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} $dest (not available — will use in-repo default)"
        rm -f "$full_dest"   # don't leave a corrupt file behind
    fi
fi
```

---

## Info

### IN-01: Framework detection logic duplicated across three scripts with ordering drift

**File:** `scripts/init-claude.sh:143-159`, `scripts/init-local.sh:173-189`, `scripts/update-claude.sh:54-70`
**Issue:** Three copies of `detect_framework()` exist. They disagree on ordering:

- `init-claude.sh` and `update-claude.sh`: rails detected before nextjs; `init-claude.sh` also probes `setup.py`.
- `init-local.sh`: nextjs detected before rails; no `setup.py` probe.

A Next.js-inside-Rails monorepo (unusual but possible for hybrid apps) will therefore be detected as different frameworks depending on which entrypoint the user runs. The Phase 3 change did not introduce these duplicates, but they should be consolidated into `scripts/lib/detect-framework.sh` (or folded into `detect.sh`) since every consumer now sources a lib directory anyway.

**Fix:** Extract into `scripts/lib/detect-framework.sh`, source from all three callers, delete duplicates.

---

### IN-02: `SKIP_COUNCIL` / `MODE` / `FORCE` / `FORCE_MODE_CHANGE` default coalescing diverges between init scripts

**File:** `scripts/init-claude.sh:53-56` vs. `scripts/init-local.sh:72-76`
**Issue:** `init-claude.sh` uses `VAR="${VAR:-default}"` after the argparse loop so `--no-council` can set the variable inside the loop and the post-loop line is a no-op. `init-local.sh` hard-initialises them before the loop. Both work, but the mixed patterns make grepping for the source of truth harder. Picking one style removes cognitive load.

**Fix:** Standardise on hard-initialisation before the argparse loop (the `init-local.sh` pattern — more explicit).

---

### IN-03: `compute_skip_set` / `print_dry_run_grouped` duplicate the mode→skip-list mapping

**File:** `scripts/lib/install.sh:38-46` and `scripts/lib/install.sh:86-94`
**Issue:** Both functions repeat the same `case "$mode" in standalone|complement-sp|...` block. A fifth mode added in the future has to be added in two places (and in `MODES=(...)` on line 20). Low-severity code smell; extract a helper like `_mode_to_skip_json` returning the JSON literal.

**Fix:** Introduce a private helper; or since `print_dry_run_grouped` already has access to `compute_skip_set`, have the dry-run path call it and reuse the result.

---

### IN-04: Nine-call `jq` loop in `print_dry_run_grouped` is O(n) fork per file

**File:** `scripts/lib/install.sh:101-113`
**Issue:** Each manifest entry spawns four `jq` subprocesses (bucket, path, skip, reason). For a 30-file manifest this is ~120 forks just for dry-run output. Not a correctness issue and explicitly out of v1 scope per the review guidelines, but noting it because switching the outer `jq -c` filter to emit TSV (`@tsv`) and splitting with `IFS=$'\t' read -r` would eliminate the inner forks entirely.

**Fix:** Change the outer filter to `| @tsv`; parse with `while IFS=$'\t' read -r bucket path skip reason; do ...`.

---

### IN-05: `test-modes.sh` asserts exact skip count without logging which paths

**File:** `scripts/tests/test-modes.sh:26-35`
**Issue:** `assert_skip_count complement-sp 7` verifies the count but if the fixture is updated to add a new `"superpowers"`-conflicting entry, the test fails with "expected 7, got 8" and no hint which entry caused the drift. Good tests print the diff.

**Fix:** On failure, also emit `jq -r '.[]' <<< "$out"` so the author sees exactly which paths are in the skip list.

---

### IN-06: Fixture manifest marked `"version": "test"` while the guard checks `manifest_version`

**File:** `scripts/tests/fixtures/manifest-v2.json:3`
**Issue:** The fixture correctly sets `manifest_version: 2` (line 2) but leaves `"version": "test"`. The `validate-manifest.py` called from `Makefile:131` may or may not allow that. If the schema validator requires `version` to be semver, `make check` would fail before `test-modes.sh` runs. Looks like this has not yet surfaced because `test-modes.sh` does not go through the schema validator — it sources `install.sh` and calls `compute_skip_set` directly, bypassing Makefile-level validation.

**Fix:** Either update the fixture to `"version": "0.0.0-test"` (semver-shaped) or confirm `validate-manifest.py` tolerates arbitrary strings.

---

### IN-07: `select_mode` prints `recommended` before `echo ""`, but the choice prompt does not echo `recommended` next to options

**File:** `scripts/init-claude.sh:213-228`
**Issue:** The user sees:

```
  Recommended: complement-full
  1) standalone  2) complement-sp  3) complement-gsd  4) complement-full

  Install mode (default: complement-full):
```

Under `curl | bash` the `read` fails and `MODE` silently defaults to the recommendation. For TTY users the UX is fine. But if a user enters `"4"` (the number corresponding to the recommendation) they are mapped to `complement-full` via the `case` statement rather than via the default branch — both paths produce the same mode. Minor cosmetic note: if the recommendation changes, the "default" text changes too; no correctness issue.

**Fix:** None required. Note if telemetry shows users are confused.

---

---

_Reviewed: 2026-04-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
