---
phase: 21-sp-gsd-bootstrap-installer
reviewed: 2026-04-27T08:05:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - scripts/lib/bootstrap.sh
  - scripts/lib/optional-plugins.sh
  - scripts/init-claude.sh
  - scripts/init-local.sh
  - scripts/tests/test-bootstrap.sh
  - Makefile
  - .github/workflows/quality.yml
  - docs/INSTALL.md
findings:
  critical: 0
  warning: 4
  info: 6
  total: 10
status: issues_found
---

# Phase 21: Code Review Report

**Reviewed:** 2026-04-27T08:05:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

The Phase 21 bootstrap implementation is well-structured and meets its core safety
contracts: `lib/bootstrap.sh` and `lib/optional-plugins.sh` correctly avoid setting
`errexit`/`pipefail` (sourced libraries leaving caller's strict-mode untouched),
the curl-fetch chain in `init-claude.sh` fails closed on transport errors,
`TK_NO_BOOTSTRAP=1` is byte-quiet, and `eval "$cmd"` never receives user input —
both `TK_SP_INSTALL_CMD` and `TK_GSD_INSTALL_CMD` are hardcoded literals in
`optional-plugins.sh`. The test suite is hermetic and uses isolated `$HOME`
sandboxes correctly. ShellCheck (severity warning) passes cleanly on all three
new shell files.

The findings below are operational safety issues — none are exploitable by an
attacker — concentrated around (a) ordering of trap registrations during the
critical curl-fetch window, (b) a missed re-application of the color gate after
`detect.sh` re-source in `init-claude.sh` (already handled in `init-local.sh`),
(c) the GSD install command literally being a `bash <(curl | bash)` from a
third-party repo where TK has no integrity check, and (d) several Info-level
hygiene items in the test harness and docs.

## Warnings

### WR-01: Trap registered AFTER first two `mktemp` calls in init-claude.sh

**File:** `scripts/init-claude.sh:69-74`
**Issue:** `DETECT_TMP`, `LIB_INSTALL_TMP`, `LIB_DRO_TMP`, `LIB_OPTIONAL_PLUGINS_TMP`,
and `LIB_BOOTSTRAP_TMP` are all created via `mktemp` on lines 69-73, but the
`trap '... rm -f ...' EXIT` is registered only at line 74 — after all five
`mktemp` calls. With `set -euo pipefail` in effect, if any of those five
`mktemp` invocations were to fail (e.g., disk full, `TMPDIR` unwritable, or a
pre-existing PID collision under heavy concurrency), the script would `exit 1`
on the failing line and any successfully-created temp files from the earlier
lines would leak into `${TMPDIR:-/tmp}`. The Phase 21 comment on line 67 ("trap
registered BEFORE curl so a failed download still cleans up the empty tmp
file") only addresses the curl-fetch window, not the mktemp window.
**Fix:**
```bash
# Register an empty trap first; populate the variables and re-register as each lands.
trap 'rm -f "${DETECT_TMP:-}" "${LIB_INSTALL_TMP:-}" "${LIB_DRO_TMP:-}" "${LIB_OPTIONAL_PLUGINS_TMP:-}" "${LIB_BOOTSTRAP_TMP:-}"' EXIT
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
LIB_INSTALL_TMP=$(mktemp "${TMPDIR:-/tmp}/install-lib.XXXXXX")
LIB_DRO_TMP=$(mktemp "${TMPDIR:-/tmp}/dry-run-output-lib.XXXXXX")
LIB_OPTIONAL_PLUGINS_TMP=$(mktemp "${TMPDIR:-/tmp}/optional-plugins-lib.XXXXXX")
LIB_BOOTSTRAP_TMP=$(mktemp "${TMPDIR:-/tmp}/bootstrap-lib.XXXXXX")
```
The `${VAR:-}` defaults make it safe to fire the trap before all variables are
populated.

### WR-02: `init-claude.sh` does not re-apply color gate after `source "$DETECT_TMP"` re-source

**File:** `scripts/init-claude.sh:113-117`
**Issue:** After `bootstrap_base_plugins` returns, line 116 re-sources
`detect.sh` to refresh `HAS_SP`/`HAS_GSD`. `detect.sh` lines 15-25 redefine
`RED`/`GREEN`/`YELLOW`/`BLUE`/`NC` **unconditionally** (no `[[ -z ]]` guard).
`init-claude.sh` itself was launched without a tty-aware color gate (line 11-15
sets the colors unconditionally too), so this re-assignment is a no-op
**today** — but `init-local.sh:147-176` correctly re-applies the color gate on
the equivalent code path, citing "RESEARCH.md Pitfall 2; uninstall.sh lines
109-123 pattern". The two installers diverge here: if a future change adds a
`if [ -t 1 ]` color gate to `init-claude.sh`, the re-source on line 116 will
silently re-introduce escape codes into a non-tty pipe (e.g., a CI log). This
is a latent bug waiting for the day someone adds the same `[ -t 1 ]` guard to
the remote installer for parity.
**Fix:** Add the same color-gate re-application that `init-local.sh:159-175`
already implements, OR add explicit `[[ -z "${RED:-}" ]] && ...` guards inside
`detect.sh` (preferred — fixes both call sites once). If guarding `detect.sh`,
also revisit `lib/install.sh:13-17` and `lib/state.sh:12-14` which have the
same unconditional-redefinition pattern.

### WR-03: `TK_GSD_INSTALL_CMD` is `bash <(curl | bash)` from a third-party repo with no integrity check

**File:** `scripts/lib/optional-plugins.sh:19`
**Issue:** The hardcoded GSD install command is
`bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)`.
TK does not control the `gsd-build/get-shit-done` repo. If that account is
compromised or the repo is force-pushed by a malicious actor, every
`init-claude.sh` user who answers `y` to the GSD prompt executes attacker code
with the user's full shell privileges — and TK takes the blame. Because
`bootstrap_base_plugins` runs **before** the toolkit's own install (line 113-117
of `init-claude.sh`), an attacker could exfiltrate user secrets, modify
`~/.bashrc`/`~/.zshrc`, or chain into the toolkit's own install path.

The threat is real but exploitability requires upstream supply-chain compromise,
so this is **Warning** not **Critical**. Defense options (in order of effort):

1. **Pin to a SHA** in `TK_GSD_INSTALL_CMD` —
   `https://raw.githubusercontent.com/gsd-build/get-shit-done/<sha>/scripts/install.sh`.
   Brittle but auditable.
2. **Show the URL before eval and require explicit `yes`** (not `y`) — raises
   the bar for accidental confirmation.
3. **At minimum: log the resolved command at `_bootstrap_log_info` level
   *before* `eval`** so the user sees what will execute:
   ```bash
   _bootstrap_log_info "Will run: $cmd"
   eval "$cmd" || rc=$?
   ```

**Fix:** Apply option 3 (cheapest, no UX regression):
```bash
case "${choice:-N}" in
    y|Y)
        _bootstrap_log_info "Running: $cmd"
        local rc=0
        eval "$cmd" || rc=$?
        ...
```

Document the supply-chain trust boundary in `docs/INSTALL.md` so users
understand they are trusting `gsd-build` upstream when they answer `y`.

### WR-04: S3 "byte-quiet" assertion in test-bootstrap.sh is too narrow to enforce D-17

**File:** `scripts/tests/test-bootstrap.sh:163-166`
**Issue:** D-17 in the phase context says `TK_NO_BOOTSTRAP=1` "must produce zero
output and exit 0". The test only asserts that four specific substrings are
absent (`"Install superpowers via plugin marketplace"`,
`"Install get-shit-done via curl install script"`, `"bootstrap skipped"`,
`"install failed"`). If `bootstrap_base_plugins` were ever changed to emit a
new INFO line on the no-op path (e.g., `"bootstrap disabled by env"`), this
test would still pass but the contract would be silently broken. A stricter
assertion would compare the bootstrap-related output region to `""`.
**Fix:** Add a positive assertion that no `_bootstrap_log_*` output appears.
Since the rest of the installer prints framework banners etc., compare a
diff between two runs — one with `TK_NO_BOOTSTRAP=1` and one with
`--no-bootstrap` (both should produce identical stdout up to the bootstrap
section):
```bash
# Compare TK_NO_BOOTSTRAP=1 output with --no-bootstrap output — must be identical (D-16/D-17 equivalence).
diff <(printf '%s\n' "$OUTPUT") <(printf '%s\n' "$OUTPUT2") >/dev/null \
    && assert_pass "S3: TK_NO_BOOTSTRAP=1 == --no-bootstrap (byte-equivalent)" \
    || assert_fail "S3: byte-equivalence" "outputs differ"
```
Alternatively, capture stderr separately and assert it is empty under
`TK_NO_BOOTSTRAP=1` (the bootstrap log helpers write to `>&2`).

## Info

### IN-01: `_bootstrap_prompt_and_run` ignores `IFS` set by caller

**File:** `scripts/lib/bootstrap.sh:46`
**Issue:** `read -r -p "..." choice < "$tty_target"` will tokenize on whatever
`IFS` is currently set to. The TTY/file path is normally fine because we read
into a single variable, but a strict-mode caller that has set `IFS=$'\n'` for
array iteration could see surprising edge behavior on multi-word answers.
**Fix:** Add a local `IFS=$' \t\n'` reset inside `_bootstrap_prompt_and_run`,
or accept the current behavior and document it. Low priority — single-variable
`read -r` is robust in practice.

### IN-02: Color constants in libs are guarded but caller may still leak escape codes when `NO_COLOR` is set

**File:** `scripts/lib/bootstrap.sh:23-31`, `scripts/lib/optional-plugins.sh:10-14`
**Issue:** Both libs honor "do not redefine if caller set them" but neither
checks `${NO_COLOR+x}` (the de-facto cross-tool standard). If a caller forgets
to set the color vars to `''` under `NO_COLOR`, the libs will write escape
codes anyway. `init-local.sh:159-175` already handles this; `init-claude.sh`
does not. This is consistent with the rest of the installer codebase (which
gates on `[ -t 1 ]` only), so it is `Info`, not `Warning`.
**Fix:** Add `[[ -n "${NO_COLOR+x}" ]] && { RED=''; GREEN=''; ...; }` guard
inside the lib for self-contained correctness.

### IN-03: `_bootstrap_prompt_and_run` swallows EOF as silent N — no log line distinguishes EOF from explicit N

**File:** `scripts/lib/bootstrap.sh:46-49`
**Issue:** When `read` fails (no TTY, EOF, file unreadable), the function
emits `"bootstrap skipped — no TTY"` and returns 0. When `read` succeeds with
an empty answer or `n`/`N`, it silently skips with no log line. Both paths
default to N — that is correct per D-06 fail-closed semantics — but a user
running under `script(1)` or in a debugger could be confused why one path
logs and the other does not. Consider unifying:
```bash
if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
    _bootstrap_log_info "${plugin_name} bootstrap skipped — no TTY"
    return 0
fi
```
That clarifies which plugin was skipped (current message is generic).
**Fix:** Include `$plugin_name` in the no-TTY log line.

### IN-04: `mk_mock` in test harness uses `printf %q` — Bash-3.2 BSD vs Bash-4+ GNU divergence

**File:** `scripts/tests/test-bootstrap.sh:60`
**Issue:** `printf '#!/bin/bash\necho %q\nexit %s\n' "$message" "$exit_code"`
relies on `%q`. On macOS BSD bash 3.2.57 (the project's lower bound per
`CLAUDE.md` constraints) `printf %q` quotes with single quotes; on GNU bash
5.x it may use `$'...'` quoting for non-ASCII bytes. The current mock
messages are ASCII-only (`mock-sp-ran`, `mock-gsd-ran`, `fake-claude`) so the
divergence is invisible today, but if a future test passes a string
containing a backslash or newline, the produced mock script will diverge
across platforms.
**Fix:** Document the ASCII-only constraint inline, or replace `%q` with a
safer pattern for arbitrary content:
```bash
mk_mock() {
    local path="$1" message="$2" exit_code="${3:-0}"
    cat > "$path" << SCRIPT
#!/bin/bash
printf '%s\n' "$message"
exit $exit_code
SCRIPT
    chmod +x "$path"
}
```
That avoids `%q` entirely. The current code is fine for the existing 5
scenarios; flag for future maintainers.

### IN-05: `INSTALL.md` flag table line for `--no-bootstrap` is unwrapped, ~370 chars wide

**File:** `docs/INSTALL.md:40`
**Issue:** The Markdown table row for `--no-bootstrap` exceeds 370 columns.
The project disables `MD013` (line length) globally per `.markdownlint.json`,
so the lint passes — but the line is hard to diff and review. The other rows
in the same table are ~80-130 columns. Cosmetic.
**Fix:** Break the cell content with HTML `<br>` (already permitted: `MD033`
disabled) or split into a footnote-style reference. Low priority.

### IN-06: `Makefile` Test 28 recipe correctly uses TAB but spread across 4 lines (cosmetic / verifies task constraint)

**File:** `Makefile:143-145`
**Issue:** Verified via `awk` byte inspection — every recipe line for
`Test 28` is tab-indented (`\t@echo ...`, `\t@bash scripts/tests/test-bootstrap.sh`).
This is correct Makefile syntax and matches the surrounding test entries.
No defect; recording as Info to confirm the project-context.md
"TAB indentation" requirement is satisfied (the review's checklist item 5).
**Fix:** None required.

---

## Cross-File Notes (informational, not findings)

- **Strict-mode hygiene (verified):** `set -euo pipefail` is set in
  `init-claude.sh:8` and `init-local.sh:9`, and grep across all six libraries
  in `scripts/lib/` confirms none of them set strict-mode flags. The
  `lib/bootstrap.sh:19` and `lib/optional-plugins.sh:7` comments make the
  contract explicit. Contract upheld.

- **`eval "$cmd"` safety (verified):** The `eval` in `bootstrap.sh:55` consumes
  `sp_cmd` / `gsd_cmd` which resolve via `${TK_BOOTSTRAP_*_CMD:-${TK_*_INSTALL_CMD:-}}`.
  The `TK_*_INSTALL_CMD` defaults are hardcoded literals in
  `optional-plugins.sh:18-19` with no user-input interpolation. The
  `TK_BOOTSTRAP_*_CMD` overrides are documented as test-seam-only. Contract
  upheld for production paths; WR-03 above flags the supply-chain trust
  boundary that no amount of escaping can address.

- **TTY fail-closed (verified):** `bootstrap.sh:46` redirects stdin from
  `tty_target` (default `/dev/tty`); `read` exits non-zero on EOF or unreadable
  file, the function returns 0 silently with the "bootstrap skipped — no TTY"
  info line. Under `curl | bash` without a controlling terminal this correctly
  fails closed to N. Contract upheld.

- **Curl fetch error handling (verified):** All five `curl -sSLf` calls in
  `init-claude.sh:76-103` use `-f` (fail on HTTP 4xx/5xx) and check the exit
  status with `if ! ... ; then exit 1; fi`. No silent fallthrough. Contract
  upheld.

- **Idempotency probes (verified):** `bootstrap.sh:79` checks
  `~/.claude/plugins/cache/claude-plugins-official/superpowers/`,
  `bootstrap.sh:90` checks `~/.claude/get-shit-done/`. Both are stable
  filesystem markers chosen to match upstream installation paths
  (RESEARCH.md Pitfall 7). Contract upheld; integration tests S1/S2 cover the
  not-yet-installed path.

- **Markdown lint (not run — environment lacks `markdownlint-cli`):** Could
  not execute the markdownlint binary in this review environment (`npx`
  failed with no `package.json` in repo root and `markdownlint-cli` is not
  globally installed). Visual inspection of `docs/INSTALL.md` shows correct
  fenced code blocks with language tags (MD040), blank lines around the new
  v4.4 section (MD031/MD032), and no trailing punctuation on headings
  (MD026). The `.markdownlint-cli2.jsonc` config disables `MD013` so the long
  table row from IN-05 is not a lint failure. Recommend running
  `make mdlint` locally before commit to confirm.

- **CI step ordering (verified):** `.github/workflows/quality.yml:109-118`
  invokes `test-bootstrap.sh` as part of the "Tests 21-28" composite step in
  the `validate-templates` job. The step header text says
  "Tests 21-28 — uninstall + banner suite + bootstrap (UN-01..UN-08,
  BOOTSTRAP-01..04)" which matches the eight `bash scripts/tests/test-*.sh`
  invocations underneath. CI wiring is consistent with the Makefile's Test 28
  entry (lines 143-145). No defect.

---

_Reviewed: 2026-04-27T08:05:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
