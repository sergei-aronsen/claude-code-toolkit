# Phase 22: Smart-Update Coverage for `scripts/lib/*.sh` — Research

**Researched:** 2026-04-27
**Domain:** Bash shell, manifest-driven update loop, hermetic test design
**Confidence:** HIGH

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** New `files.libs[]` top-level array in `manifest.json` (not extending `files.scripts[]`).
  Rationale: semantic split between entry points and sourced helpers. Update loop already iterates
  `.files | to_entries[] | .value[] | .path` — zero code changes needed to `update-claude.sh`.

- **D-02:** Cover ALL SIX lib files: `backup.sh`, `bootstrap.sh`, `dry-run-output.sh`, `install.sh`,
  `optional-plugins.sh`, `state.sh`. Phase 21 added `bootstrap.sh` and `optional-plugins.sh` after
  the requirement text was written; treating all sourced libs as one unit closes the gap cleanly.

- **D-03:** Mirror source layout — `scripts/lib/X.sh` installs to `~/.claude/scripts/lib/X.sh`.
  `update-claude.sh:262` prepends `$CLAUDE_DIR/$path` literally; no path translation needed.

- **D-04:** Hermetic test `scripts/tests/test-update-libs.sh` (Test 29), five scenarios:
  S1 stale lib refreshed; S2 clean lib untouched; S3 fresh install (no `lib/` dir);
  S4 modified-file prompt path; S5 uninstall round-trip with all six libs in `[- REMOVE]` group.
  Uses `TK_UPDATE_HOME` seam (line 123). Must be shellcheck-clean, exit non-zero on failure.

- **D-05:** Bump `manifest.json` `4.3.0` → `4.4.0`. Add `## [4.4.0]` to `CHANGELOG.md` consolidating
  Phase 21 (BOOTSTRAP-01..04) + Phase 22 (LIB-01..02). `make version-align` enforces three-way match:
  manifest ↔ CHANGELOG top header ↔ `init-local.sh --version`.

- **D-06:** Wire `test-update-libs` as Makefile Test 29. Extend CI step from `Tests 21-28` to
  `Tests 21-29` by appending `bash scripts/tests/test-update-libs.sh` in `quality.yml`.

- **D-07:** No migration logic for pre-4.4.0 state files. The `if [[ -f "$CLAUDE_DIR/$path" ]]` guard
  at update-claude.sh:262 handles fresh-install paths. `synthesize_v3_state()` at line 256 iterates
  the same `.files | to_entries[]` path, so v3.x mid-flight users get lib files synthesized
  automatically. Zero special-casing.

- **D-08:** Lib files in `manifest.json` automatically extend `uninstall.sh` reach via STATE_JSON
  paths. No `is_protected_path` change needed. Test S5 verifies the uninstall coverage.

### Claude's Discretion

- Exact file ordering inside `files.libs[]` — alphabetical by basename.
- `description:` field per lib entry — omit (existing `files.scripts[]` does not include descriptions).
- TAB vs space indentation in new Makefile target — TAB (Make requirement, established convention).

### Deferred Ideas (OUT OF SCOPE)

- Per-lib description in dry-run output — post-v4.4 ideation.
- Changes to lib API or internals.
- Install-time changes to `init-claude.sh` / `init-local.sh`.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LIB-01 | Register all six `scripts/lib/*.sh` files in `manifest.json` under `files.libs[]`; `make check` (version-align + validate + shellcheck) stays green | manifest.json `files.scripts` array is the structural analog; `validate-manifest.py` Check 5 resolves paths via SOURCE_MAP fallback — `scripts/lib/*.sh` paths resolve directly to `scripts/lib/` in repo |
| LIB-02 | `update-claude.sh` iterates new manifest section; stale lib on disk is refreshed with same diff/backup/safe-write contract as top-level scripts; hermetic test proves it | update-claude.sh:266 `jq -r '.files | to_entries[] | .value[] | .path'` auto-discovers `files.libs[]`; `TK_UPDATE_HOME` + `TK_UPDATE_FILE_SRC` seams already present for hermetic testing |

</phase_requirements>

---

## 1. What This Phase Needs to Know

### The Gap Being Closed

`update-claude.sh` is fully manifest-driven. Its install loop (lines 679-707) and modified-file loop (lines 821-824) both operate over `NEW_FILES` and `MODIFIED_ACTUAL`, which are derived from `compute_file_diffs_obj()` in `lib/install.sh`. That function in turn reads:

```bash
jq -c '[.files | to_entries[] | .value[] | .path]' "$manifest_path"
```

This is the sole enumeration of "what files does the toolkit manage". Because `scripts/lib/*.sh` are not registered in `manifest.json`, they are invisible to the update loop, the diff engine, and `uninstall.sh`. A user on v4.2 whose `lib/install.sh` has drifted from HEAD has no recovery path except running the full init again.

Adding `files.libs[]` to `manifest.json` fixes this at the data layer. The code in `update-claude.sh` changes by zero lines.

### How `update-claude.sh` Consumes New Manifest Keys (VERIFIED)

`MANIFEST_FILES_JSON` at line 637 is:

```bash
MANIFEST_FILES_JSON=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$MANIFEST_TMP")
```

`to_entries[]` iterates every key in `.files` as a key-value pair. Adding `"libs": [...]` produces exactly the same JSON array elements as `"scripts": [...]`. No code changes to the update loop or diff engine are needed. [VERIFIED: scripts/update-claude.sh lines 637-638]

### How `synthesize_v3_state` Picks Up the New Key (VERIFIED)

`synthesize_v3_state()` at lines 257-268 uses the identical `jq` path:

```bash
while IFS= read -r path; do
    if [[ -f "$CLAUDE_DIR/$path" ]]; then
        ...
    fi
done < <(jq -r '.files | to_entries[] | .value[] | .path' "$manifest_file")
```

V3.x users who have the lib files on disk (because init installed them there) will get those paths synthesized into STATE_JSON. Users who do NOT have the lib files on disk (v3.x never installed them to `~/.claude/scripts/lib/`) hit the `if [[ -f "$CLAUDE_DIR/$path" ]]` guard and skip gracefully — the files simply appear as "new" on first post-4.4.0 update. [VERIFIED: scripts/update-claude.sh lines 257-268]

### Install Path for Lib Files (VERIFIED)

`update-claude.sh:679-707` (new files loop): `dest="$CLAUDE_DIR/$rel"` where `$rel` is the path string from manifest. For `"scripts/lib/backup.sh"`, dest resolves to `$CLAUDE_DIR/scripts/lib/backup.sh` = `~/.claude/scripts/lib/backup.sh`. This is the same layout that `scripts/uninstall.sh` already classifies (it reads STATE_JSON paths verbatim). [VERIFIED: scripts/update-claude.sh lines 679-707, D-03]

### `validate-manifest.py` Path Resolution (VERIFIED, CRITICAL)

`validate-manifest.py` Check 5 resolves install-destination paths to on-disk source paths via `SOURCE_MAP`. The current map covers `agents/`, `prompts/`, `skills/`, `rules/`, `commands/`. For paths NOT matching any prefix, the fallback at line 55 is:

```python
return os.path.join(REPO_ROOT, manifest_path)
```

So `"scripts/lib/backup.sh"` resolves to `$REPO_ROOT/scripts/lib/backup.sh`, which exists on disk. **No changes to `validate-manifest.py` are needed.** [VERIFIED: scripts/validate-manifest.py lines 48-55]

Check 6 (disk-to-manifest drift) only audits `commands/` and `templates/base/skills/` — lib files are not in scope there. Also safe. [VERIFIED: scripts/validate-manifest.py lines 199-217]

---

## 2. Existing Assets to Reuse

### Key Seams Already Present

| Seam | Location | Purpose |
|------|----------|---------|
| `TK_UPDATE_HOME` | update-claude.sh:122-124 | Redirects `$CLAUDE_DIR` to a temp sandbox |
| `TK_UPDATE_FILE_SRC` | update-claude.sh:686-698, 786-801 | Serves file content from local dir instead of curl |
| `TK_UPDATE_MANIFEST_OVERRIDE` | update-claude.sh:97-105 | Uses a local `manifest.json` fixture instead of fetching remote |
| `TK_UPDATE_LIB_DIR` | update-claude.sh:84-93 | Sources lib files from local path instead of remote curl |
| `TK_UNINSTALL_HOME` | uninstall.sh (inferred from test-uninstall.sh patterns) | Sandbox redirect for uninstall |
| `TK_UNINSTALL_LIB_DIR` | uninstall.sh | Sources lib files locally |
| `TK_UNINSTALL_TTY_FROM_STDIN=1` | uninstall.sh | Reads prompts from stdin instead of `/dev/tty` |

All five seams needed by the new test (Test 29) already exist. No new seam additions required.

### Closest Test Analogs

- **`scripts/tests/test-bootstrap.sh`** — five-scenario hermetic shape, env-var seams, `mk_mock` helper, `assert_eq / assert_contains / assert_not_contains`, PASS/FAIL counter, `set -euo pipefail`, function-per-scenario, `trap "rm -rf" RETURN` cleanup.
- **`scripts/tests/test-uninstall.sh`** — install→uninstall round-trip with real init-local.sh; proves S5 shape; uses `TK_UNINSTALL_HOME` and `TK_UNINSTALL_LIB_DIR`.

The new `test-update-libs.sh` should be a direct structural copy of `test-bootstrap.sh` (for S1-S4) plus `test-uninstall.sh`'s S1 pattern (for S5).

### Manifest Structural Analog

`files.scripts[]` at manifest.json lines 216-220 is the direct analog for the new `files.libs[]` section:

```json
"scripts": [
  {
    "path": "scripts/uninstall.sh"
  }
]
```

New section will follow identical structure with six entries, alphabetical by basename.

### write_state Contract (VERIFIED)

`lib/state.sh::write_state` takes an `installed_csv` argument of comma-separated absolute paths. It hashes each file via `sha256()` at write time. After a successful update, the new lib paths are appended to `FINAL_INSTALLED_CSV` in `update-claude.sh:934-946`. No extension to `write_state` is needed. [VERIFIED: scripts/lib/state.sh lines 60-138]

---

## 3. Pitfalls and Gotchas

### (a) JSON Ordering / jq Behavior on New Top-Level Key

`jq -c '[.files | to_entries[] | .value[] | .path]'` iterates keys in the order they appear in the JSON file. Adding `"libs"` after `"scripts"` means lib paths appear AFTER scripts paths in the enumeration. This is correct and desirable — existing installed paths remain at the same logical positions, new lib paths appear as a suffix. No ordering sensitivity in any comparison (`NEW_FILES`, `MODIFIED_CANDIDATES`, `REMOVED_FROM_MANIFEST` all operate as sets via jq set operations `-` and `index`). [VERIFIED: scripts/lib/install.sh compute_file_diffs_obj lines 287-297]

### (b) STATE_JSON Migration on First Post-4.4.0 Run

Users on 4.3.0 have a `toolkit-install.json` that does NOT list any `scripts/lib/*.sh` paths (because they were never registered). On first run of 4.4.0's `update-claude.sh`:

1. `compute_file_diffs_obj` returns the six lib paths in `new` (they are in manifest but not in `installed_files[]`)
2. The "new files" loop installs them with `mkdir -p "$(dirname "$dest")"` + copy
3. They are appended to `FINAL_INSTALLED_CSV` and stored in STATE_JSON

This is correct. No migration script needed. The `if [[ -f "$CLAUDE_DIR/$path" ]]` guard in `synthesize_v3_state` does NOT apply here (that's for v3.x users who never had STATE_JSON). 4.3.0 users already have STATE_JSON — they go through the normal `compute_file_diffs_obj` path. [VERIFIED: D-07, update-claude.sh:457-468]

### (c) `--no-banner` Interaction With New Test

`test-update-libs.sh` will invoke `update-claude.sh` as a subprocess. `update-claude.sh` prints the ASCII banner unless `--no-banner` is passed or `NO_BANNER=1` is set. The test driver should pass `--no-banner` to suppress banner noise in test output. This is consistent with how `test-bootstrap.sh` uses `--dry-run` to suppress writes — use the same pattern. Alternatively set `NO_BANNER=1` in the environment passed to the subprocess. Either approach works; `--no-banner` is cleaner (explicit, no env pollution).

### (d) `cell-parity.sh` Does Not Read `manifest.json`

`scripts/cell-parity.sh` reads from `validate-release.sh --list`, `docs/INSTALL.md`, and `docs/RELEASE-CHECKLIST.md`. It does NOT grep or parse `manifest.json`. Adding `files.libs[]` has zero impact on `make cell-parity`. [VERIFIED: scripts/cell-parity.sh]

### (e) `synthesize_v3_state` Race When `lib/` Dir Does Not Exist on Disk

`synthesize_v3_state` at line 262 checks `if [[ -f "$CLAUDE_DIR/$path" ]]` before including a path. If a user on a v3.x install (pre-4.0) never had `~/.claude/scripts/lib/` created (because init-local.sh created it in the project dir, not `~/.claude/`), the six lib paths will simply not appear in the synthesized state. This is safe — they appear as `new` on first update, the new-files loop creates `~/.claude/scripts/lib/` via `mkdir -p`, and they get installed. The only edge case is if `mkdir -p` fails (disk full, permissions). That would cause the copy to fail too, and the path ends up in `SKIPPED_PATHS` with reason `download_failed`. The summary shows the failure clearly. No special handling needed. [VERIFIED: update-claude.sh:679-707]

### (f) `make version-align` Triple-Check

The `version-align` Makefile target (lines 225-247) performs a three-way match:

1. `jq -r '.version' manifest.json` → `4.4.0`
2. `grep -m1 '^## \[[0-9]' CHANGELOG.md` → `## [4.4.0]`
3. `bash scripts/init-local.sh --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'` → `4.4.0`

The `init-local.sh` reads its version from `manifest.json` at runtime (per Phase 20 D-12), so the only actual files that must change for the version bump are `manifest.json` and `CHANGELOG.md`. Running `make version-align` after both edits will confirm alignment. This MUST be verified before committing — version misalignment fails `make check`. [VERIFIED: Makefile:225-247]

### (g) `optional-plugins.sh` and `bootstrap.sh` Are NEW in 4.4.0 — Missing-File Handling

Users running `update-claude.sh` for the first time after upgrading from 4.3.0 will not have `~/.claude/scripts/lib/bootstrap.sh` or `~/.claude/scripts/lib/optional-plugins.sh` on disk (they were added in Phase 21 but never registered in manifest). These paths will appear in `NEW_FILES` (not `MODIFIED_CANDIDATES`), and the new-files loop handles them via the `mkdir -p ... cp` path. The SHA comparison in `compute_modified_actual` is only reached for files in `MODIFIED_CANDIDATES` (which requires the path to be in BOTH manifest and installed_files[]).

Critically: the test `TK_UPDATE_FILE_SRC` seam must include all six lib files in its fixture directory. If any of the six are absent from `TK_UPDATE_FILE_SRC`, the seam treats them as "download failed" and adds them to `SKIPPED_PATHS`. The S3 scenario (fresh install, no `lib/` dir) is the primary proof that `bootstrap.sh` and `optional-plugins.sh` are handled correctly. [VERIFIED: update-claude.sh:686-699]

---

## 4. Validation Architecture (Nyquist)

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash `set -euo pipefail` + assertion helpers (existing pattern) |
| Config file | None — standalone shell script |
| Quick run command | `bash scripts/tests/test-update-libs.sh` |
| Full suite command | `make test` (runs all 29 tests) |

### Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIB-01 | `files.libs[]` in manifest; `make check` green | static + integration | `make check` | No — Wave 1 adds manifest entry |
| LIB-02 | Stale lib refreshed; SHA matches after update | hermetic integration | `bash scripts/tests/test-update-libs.sh` | No — Wave 2 creates test |

### Per-Scenario Coverage Requirements

| Scenario | Assertion Count | What Must Pass |
|----------|-----------------|----------------|
| S1 stale-refresh | 3 | exit 0, post-update SHA of `lib/backup.sh` == repo SHA, file was written |
| S2 clean-untouched | 3 | exit 0, mtime unchanged, no UPDATED line in output for that path |
| S3 fresh-install | 3 | exit 0, all six lib files present, SHA of each matches fixture |
| S4 modified-prompt | 3 | prompt fires (output contains "modified locally"), `N` answer keeps user copy |
| S5 uninstall round-trip | 3 | `--dry-run` output lists all 6 lib paths in REMOVE group; real uninstall removes lib dir |

Minimum 15 assertions total. PASS/FAIL counter must exit non-zero on any failure.

### Idempotency Requirement

Running `bash scripts/tests/test-update-libs.sh` a second time immediately after the first MUST produce the same result (all pass). Each scenario creates and destroys its own `SANDBOX` via `trap "rm -rf" RETURN`.

### Wave 0 Gaps

- [ ] `scripts/tests/test-update-libs.sh` — covers LIB-02 (does not exist yet)
- No new test infrastructure (assert helpers) needed — copy from `test-bootstrap.sh`
- No new framework install needed

---

## 5. Sequencing — Recommended Wave Structure

### Wave 1 — Data Layer (manifest + CHANGELOG)

**Files changed:** `manifest.json`, `CHANGELOG.md`

1. Add `"libs": [...]` array to `manifest.json` after `"scripts"` key, six entries alphabetically:
   `backup.sh`, `bootstrap.sh`, `dry-run-output.sh`, `install.sh`, `optional-plugins.sh`, `state.sh`
2. Bump `"version": "4.3.0"` → `"version": "4.4.0"` in `manifest.json`
3. Add `## [4.4.0]` section to top of `CHANGELOG.md` consolidating Phase 21 + Phase 22 entries
4. Verify: `make check` (specifically: `make version-align` + `python3 scripts/validate-manifest.py`)

No code changes. This wave is a pure data edit. The update loop starts picking up lib files immediately after this wave — no other changes required for LIB-02 to work functionally.

### Wave 2 — Test (hermetic test + Makefile + CI)

**Files changed:** `scripts/tests/test-update-libs.sh` (new), `Makefile`, `.github/workflows/quality.yml`

1. Create `scripts/tests/test-update-libs.sh` (five scenarios, per D-04)
2. Add Test 29 block to `Makefile` after the Test 28 block (TAB-indented)
3. Add `test-update-libs` to `.PHONY` line in Makefile
4. Extend CI step name `Tests 21-28` → `Tests 21-29` in `quality.yml`; append `bash scripts/tests/test-update-libs.sh`
5. Verify: `bash scripts/tests/test-update-libs.sh` passes; `make check` green; CI green

### Commit Strategy

Wave 1 and Wave 2 can be separate commits or one atomic commit. Since Wave 1's data changes make the behavior live and Wave 2 proves it, committing Wave 1 first produces a brief window where libs are updated but not tested. Prefer an atomic commit that includes both waves, or commit Wave 2 immediately after Wave 1 in the same PR.

---

## 6. Open Questions for Planner

### Q1 — Fixture SHA Source for S1 and S3

**What we know:** S1 asserts that a stale lib file on disk gets refreshed to match the repo version. The test uses `TK_UPDATE_FILE_SRC` to serve file content instead of curl. The SHA assertion must compare the post-update installed file against the fixture file in `TK_UPDATE_FILE_SRC`.

**What's unclear:** Should the fixture be: (a) a direct copy of `$REPO_ROOT/scripts/lib/`, or (b) a synthetic fixture in `$SANDBOX`?

**Recommendation:** Use `TK_UPDATE_FILE_SRC="$REPO_ROOT/scripts/lib"` pointing at the live repo. This avoids maintaining a separate fixture and means the SHA comparison is trivially `sha256("$SANDBOX/.claude/scripts/lib/backup.sh") == sha256("$REPO_ROOT/scripts/lib/backup.sh")`. The pattern is identical to how `test-update-diff.sh` uses `TK_UPDATE_FILE_SRC`.

But the manifest fixture (`TK_UPDATE_MANIFEST_OVERRIDE`) must point at a temp `manifest.json` that includes `files.libs[]`. Otherwise `update-claude.sh` fetches the REMOTE manifest (potentially 4.3.0 without the new section). The test must create a local manifest fixture that includes the `files.libs` array.

### Q2 — S4 TTY Seam for Modified-File Prompt

**What we know:** `update-claude.sh:804` reads from `/dev/tty` for the modified-file prompt: `read -r -p "..." choice < /dev/tty`. There is no existing `TK_UPDATE_TTY_FROM_STDIN` seam in `update-claude.sh` (unlike `uninstall.sh` which has `TK_UNINSTALL_TTY_FROM_STDIN=1`).

**What's unclear:** S4 requires that we answer "N" to the modified-file prompt without hanging on `/dev/tty`. CONTEXT.md D-04 says "drive update via `TK_UPDATE_TTY_FROM_STDIN=1` (or equivalent existing seam)". Need to confirm whether such a seam exists in the current update-claude.sh.

**Recommendation:** Check the `prompt_modified_file` function in `update-claude.sh` (line 763-819). Looking at lines 802-804:

```bash
if ! read -r -p "..." choice < /dev/tty 2>/dev/null; then
    choice="N"
fi
```

The `2>/dev/null` redirect means if `/dev/tty` fails to open (no TTY), `read` fails and `choice` defaults to `"N"` (fail-closed). In a subprocess invoked as `$(...)`, there is no TTY — `/dev/tty` will return "no such device" or fail, `read` returns non-zero, and `choice="N"` applies. S4 can be proven by verifying that `choice="N"` was applied (the file is in `SKIPPED_PATHS`) without needing to inject a fake TTY. The test just asserts that output does NOT contain the file in UPDATED group and the file is unchanged on disk.

This is simpler than a seam — no code changes needed to `update-claude.sh` for S4.

### Q3 — S5 Uninstall Tool Path

**What we know:** S5 runs `uninstall.sh --dry-run` and then the real uninstall, asserting lib paths appear in `[- REMOVE]` output. The uninstall reads STATE_JSON, which is written by `update-claude.sh` during S5's setup step (a real update run).

**What's unclear:** `uninstall.sh` has its own seams (`TK_UNINSTALL_HOME`, `TK_UNINSTALL_LIB_DIR`). These are already used by `test-uninstall.sh`. Does the post-update STATE_JSON contain absolute paths (which include `$TK_UPDATE_HOME/.claude/`) or relative paths?

**Recommendation:** `write_state` at line 960 in `update-claude.sh` passes `$FINAL_INSTALLED_CSV` which contains absolute paths prefixed with `$CLAUDE_DIR/` (= `$TK_UPDATE_HOME/.claude/`). The uninstall must be invoked with `TK_UNINSTALL_HOME="$SANDBOX"` so it reads state from `$SANDBOX/.claude/toolkit-install.json`. The paths in that state file use `$SANDBOX/.claude/scripts/lib/...` — which `uninstall.sh` will be able to resolve if `TK_UNINSTALL_HOME` is set correctly. Verify this is what `test-uninstall.sh`'s S1 proves for `scripts/uninstall.sh` itself; same pattern applies for lib files.

---

## Sources

### Primary (HIGH confidence)

All findings are VERIFIED against the actual source files in this repository session.

- `scripts/update-claude.sh` (full file) — update loop, synthesize_v3_state, TK_UPDATE_HOME seam, MANIFEST_FILES_JSON extraction, compute_modified_actual, new-files loop, prompt_modified_file
- `manifest.json` (full file) — existing structure, `files.scripts[]` analog, `validate-manifest.py` interaction
- `scripts/validate-manifest.py` (full file) — Check 5 path resolution fallback, Check 6 drift detection scope
- `scripts/lib/state.sh` (full file) — write_state contract, sha256_file, installed_csv format
- `scripts/lib/install.sh` (full file) — compute_file_diffs_obj, compute_skip_set
- `scripts/lib/backup.sh`, `bootstrap.sh`, `dry-run-output.sh`, `optional-plugins.sh` (full files) — confirmed all six target files exist at `scripts/lib/`
- `scripts/tests/test-bootstrap.sh` (full file) — five-scenario shape, seam pattern, assertion helpers
- `scripts/tests/test-uninstall.sh` (full file) — round-trip integration pattern for S5
- `Makefile` (full file) — Test 28 block, version-align target, .PHONY line, CI step wiring
- `.github/workflows/quality.yml` (full file) — `Tests 21-28` step, CI job structure

### Secondary (MEDIUM confidence)

- CONTEXT.md D-01..D-08 — decisions carry rationale verified against code behavior
- REQUIREMENTS.md LIB-01..LIB-02 — acceptance criteria verified against implementation path

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `uninstall.sh` has `TK_UNINSTALL_HOME` and `TK_UNINSTALL_LIB_DIR` seams matching the pattern in `test-uninstall.sh` | S5 design in Q3 | If seam names differ, S5 must be adjusted; no functional impact on LIB-01/02 |
| A2 | `update-claude.sh` `prompt_modified_file` fails closed to `N` when invoked as a subprocess (no TTY) | Section 3c and Q2 | If the function hangs waiting for TTY, S4 needs a separate seam injection |

Both assumptions are LOW risk — A1 is inferable from `test-uninstall.sh` which imports these seams, A2 is confirmed by `2>/dev/null` guard in the read call.

**If this table has only 2 entries:** All other claims in this research were directly verified by reading the source files.
