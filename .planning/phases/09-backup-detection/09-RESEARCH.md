# Phase 9: Backup & Detection — Research

**Researched:** 2026-04-24
**Domain:** POSIX shell scripting — backup lifecycle management + Claude CLI plugin detection
**Confidence:** HIGH

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

See `09-CONTEXT.md` D-01..D-32 in full. Key locks surfaced here:

- D-01: Patterns scanned = `~/.claude-backup-<epoch>-<pid>` + `~/.claude-backup-pre-migrate-<epoch>`. REQUIREMENTS.md `~/.claude/.toolkit-backup-*` is a phantom — plan patches spec, not code.
- D-02: `--keep N` sort by parsed epoch from dir name, not `stat`.
- D-03: Per-dir `[y/N]` prompt; `read < /dev/tty` idiom.
- D-04: Prompt shows name + `du -sh` size + age string from epoch diff.
- D-05: `--dry-run` composes with `--clean-backups` (print only, no prompt, no delete).
- D-06: Exit codes 0/1/2.
- D-08: Threshold = COMBINED count across both patterns.
- D-09: Threshold value = 10 (magic number, no env var).
- D-10: Centralize in new `scripts/lib/backup.sh`.
- D-11: Warning style = `log_warning` YELLOW ⚠.
- D-12: Count via `find "$HOME" -maxdepth 1 -type d \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) | wc -l`.
- D-13: DETECT-06 scope = SP only.
- D-14: CLI check = 4th step in `detect_superpowers()`, after settings.json gate, before `HAS_SP=true`.
- D-15: `command -v claude &>/dev/null` guard; silent skip.
- D-16: Parse via `claude plugin list --json 2>/dev/null | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .enabled'`.
- D-17: No timeout; soft-fail on non-zero exit or non-JSON.
- D-18: CLI version wins over FS `sort -V | tail -1` when CLI available and enabled.
- D-20: No `CLAUDE_PLUGIN_LIST_CHECK` env var — use existing `HAS_SP`/`HAS_GSD` test seam.
- D-21: DETECT-07 scope = both SP and GSD.
- D-22: Skew warning in `update-claude.sh` ONLY.
- D-23: Emit AFTER `read_state` + detection, BEFORE prompts/summary.
- D-24: Non-fatal, no prompt.
- D-25: Any version mismatch fires; no graded severity.
- D-26: `warn_version_skew()` in `scripts/lib/install.sh`.
- D-27: New files = `scripts/lib/backup.sh` + optional test files. No manifest entries.
- D-28: Files modified = update-claude.sh, detect.sh, migrate-to-complement.sh, setup-security.sh (verify), lib/install.sh, REQUIREMENTS.md.
- D-29: bats for BACKUP-01, bash stubs for DETECT-06/07.
- D-30: Per-REQ branches: `feature/backup-01-clean-backups`, etc.
- D-31: Conventional Commit scopes: `feat(backup-01):`, etc.
- D-32: NO new `make check` target this phase.

### Claude's Discretion

- Exact bats vs bash split within BACKUP-01 testing.
- Whether `scripts/lib/backup.sh` exports a `list_backup_dirs()` helper or keeps listing inline.
- Whether BACKUP-02 warning emits before or after the "backup created at X" log line.
- Age string format (`14d 3h` vs `14d` vs `2w 3d`).
- Whether to ship 4 per-REQ plans or 2 bundled plans (backup bundle + detect bundle).

### Deferred Ideas (OUT OF SCOPE)

- Tunable threshold via env/flag (`$TK_BACKUP_WARN_THRESHOLD`) — v4.2+.
- Explicit timeout around `claude plugin list --json` — v4.2+.
- `--force` / `--yes` flag for batch cleanup — explicitly rejected (PROJECT.md invariant).
- Backup relocation to match REQUIREMENTS phantom path — rejected (D-01).
- Version-skew warning on `init-claude.sh` — D-22 scopes to update only.
- Graded semver severity — D-25 rejected.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BACKUP-01 | `update-claude.sh --clean-backups` with per-dir `[y/N]`, `--keep N`, `--dry-run` compose | §Integration Points: arg-parser insertion site; §Bats Harness Reuse for test scaffolding |
| BACKUP-02 | Non-fatal threshold warning (> 10 dirs) centralized in `scripts/lib/backup.sh` | §setup-security.sh Backup Audit (excluded); §BACKUP-02 Caller Surface |
| DETECT-06 | `detect.sh` step 4 CLI cross-check; SP only; FS primary | §Exact Insertion Site; §CLI Output Shape; §jq Expression |
| DETECT-07 | `update-claude.sh` version-skew warning from state schema | §State Schema Verification; §Emission Position; §jq Expressions |

</phase_requirements>

---

## Summary

Phase 9 is a mechanical extension of established patterns. All design choices are locked by 32 decisions in CONTEXT.md. Research confirms the implementation details the planner needs: exact line ranges for code insertion, verified jq expressions, confirmed `< /dev/tty` idiom, BSD/GNU portability constraints, and the exact state schema path `detected.superpowers.version` / `detected.gsd.version`.

The single most important finding: `setup-security.sh` does NOT create a sibling backup directory (`.claude-backup-*` pattern). It only calls `backup_settings_once()` from `lib/install.sh`, which creates a `.bak.<epoch>` file alongside `settings.json` — a completely different path. BACKUP-02 callers are therefore only `update-claude.sh` and `migrate-to-complement.sh`.

**Primary recommendation:** Ship 4 per-REQ plans (D-30 mandates per-REQ branches; plans match branches 1:1 for clean PRs). backup-02 and backup-01 share `scripts/lib/backup.sh` but live in separate branches — create the lib in the BACKUP-01 branch (first merged), then BACKUP-02 branch sources it.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Backup dir cleanup (`--clean-backups`) | Shell CLI (update-claude.sh) | — | Operator housekeeping; no web tier |
| Threshold warning (BACKUP-02) | Shell lib (backup.sh) | Callers (update, migrate) | Centralized to avoid 3-site drift |
| CLI plugin detection (DETECT-06) | Shell lib (detect.sh) | `claude` CLI (subprocess) | detect.sh is the detection abstraction layer |
| Version-skew warning (DETECT-07) | Shell script (update-claude.sh) | Shell lib (install.sh helper) | Skew only meaningful at update time |

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 3.2+ | Script runtime | macOS Monterey ships 3.2; POSIX-shell invariant |
| jq | 1.6+ | JSON parsing | Already a hard dep (statusline, detect.sh, state.sh) |
| find (BSD) | macOS built-in | Dir discovery | D-12 expression is BSD+GNU portable |
| du (BSD) | macOS built-in | Size reporting | `du -sh` is POSIX-standard; same output on BSD and GNU |
| date (BSD) | macOS built-in | Epoch timestamps | `date -u +%s` works on both; used in existing backup dir names |

[VERIFIED: codebase grep — jq, find, du, date all used in existing scripts]

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| bats-core | any | Test framework | BACKUP-01 test via Phase 8 helpers.bash harness |
| python3 | 3.8+ | state.sh write_state | Already a dep; not needed for new backup/detect code |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `find -maxdepth 1 \| wc -l` | `ls -d ~/.claude-backup-* 2>/dev/null \| wc -l` | `ls` glob fails when 0 matches (exit 1); `find` returns 0 with empty output |
| Epoch from dir name | `stat -f %m` (macOS) / `stat -c %Y` (Linux) | `stat` is already BSD/GNU divergent (state.sh has a `uname` guard for it); parsing the name avoids the conditional entirely (D-02) |
| `wc -l` (leading spaces) | `grep -c .` | `wc -l` on macOS BSD emits leading spaces — use `$( ... | tr -d ' ')` or arithmetic expansion `$(( $(find ... | wc -l) ))` |

**Installation:** No new packages. Phase 9 uses existing runtime dependencies.

---

## Architecture Patterns

### Recommended Project Structure (new + modified files)

```text
scripts/
├── lib/
│   ├── backup.sh          NEW  — warn_if_too_many_backups(), list_backup_dirs()
│   └── install.sh         MOD  — warn_version_skew() appended
├── update-claude.sh       MOD  — --clean-backups arg, dispatch, warn_version_skew() call
├── detect.sh              MOD  — CLI cross-check step 4 in detect_superpowers()
├── migrate-to-complement.sh MOD — source backup.sh + call warn_if_too_many_backups()
└── tests/
    ├── test-clean-backups.sh  NEW  — bash-only or bats (Claude's discretion)
    └── test-detect-cli.sh     NEW  — bash unit test with stub claude binary
```

### Pattern 1: `< /dev/tty` Prompt Idiom

**What:** All interactive prompts in this codebase use `read -r -p "..." var < /dev/tty 2>/dev/null` with a fail-closed fallback.

**When to use:** Any prompt that must survive `curl | bash` invocation (no stdin).

```bash
# Source: scripts/update-claude.sh:525, :381, :598 (VERIFIED: grep)
local decision=""
if ! read -r -p "Remove $dir? [y/N]: " decision < /dev/tty 2>/dev/null; then
    decision="N"   # fail-closed under curl|bash
fi
case "${decision:-N}" in
    y|Y) rm -rf "$dir" ;;
    *)   : ;;          # skip
esac
```

**Key property:** `2>/dev/null` suppresses "no such file" on systems where `/dev/tty` is unavailable. The `if !` catches both unavailability and EOF. Default `"N"` is the fail-closed safe value.

### Pattern 2: FIFO-Based tty Simulation in Tests

**What:** When a test needs to exercise the "y" path of a `< /dev/tty` prompt, a named FIFO stands in for the terminal.

```bash
# Source: scripts/tests/test-update-diff.sh:295-312 (VERIFIED: read)
local FIFO="$SCR/.fifo/tty"
mkfifo "$FIFO"
(echo "y" > "$FIFO") &
local BG_PID=$!
OUT=$(... bash "$SCRIPT" 0<"$FIFO" 2>&1 || true)
wait "$BG_PID" 2>/dev/null || true
```

**For BACKUP-01 tests needing multiple prompts:** Write all answers before the script runs, or use a co-process. The single `echo "y" > FIFO` pattern works only when there is exactly one read. For N prompts, write N lines:

```bash
printf 'y\ny\nn\n' > "$FIFO" &
```

**Alternative (fail-closed path only):** No FIFO needed. The `if ! read < /dev/tty` branch activates automatically when there is no tty in the test subprocess, defaulting to `"N"`. Test the non-interactive default by omitting the FIFO entirely.

### Pattern 3: Epoch Parsing from Dir Name

**What:** Extract the UTC epoch embedded in `~/.claude-backup-<epoch>-<pid>` and `~/.claude-backup-pre-migrate-<epoch>`.

```bash
# No external tool needed — pure bash parameter expansion
dir_name="$(basename "$dir")"
epoch=""
case "$dir_name" in
    .claude-backup-[0-9]*-[0-9]*)
        epoch="${dir_name#.claude-backup-}"
        epoch="${epoch%-*}"   # strip trailing -<pid>
        ;;
    .claude-backup-pre-migrate-[0-9]*)
        epoch="${dir_name#.claude-backup-pre-migrate-}"
        ;;
esac
```

**Age calculation (POSIX arithmetic, BSD+GNU):**

```bash
now=$(date -u +%s)
age_secs=$(( now - epoch ))
```

**Age string format (recommend: `14d 3h` / `5h 12m` / `47m` / `<1m`):**

```bash
fmt_age() {
    local secs="$1"
    local days=$(( secs / 86400 ))
    local hours=$(( (secs % 86400) / 3600 ))
    local mins=$(( (secs % 3600) / 60 ))
    if   [[ $days  -gt 0 ]]; then echo "${days}d ${hours}h"
    elif [[ $hours -gt 0 ]]; then echo "${hours}h ${mins}m"
    elif [[ $mins  -gt 0 ]]; then echo "${mins}m"
    else echo "<1m"
    fi
}
```

[ASSUMED] — age format chosen by Claude's discretion (D-04 says `14d 3h`, `5h 12m`, `<1m` as examples).

### Pattern 4: Backup Count with BSD `wc -l`

**What:** macOS BSD `wc -l` emits leading whitespace. Arithmetic expansion strips it safely.

```bash
# Source: D-12 (VERIFIED: find -maxdepth 1 is BSD+GNU portable per grep of existing usage)
count=$(( $(find "$HOME" -maxdepth 1 -type d \
    \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
    2>/dev/null | wc -l) ))
```

The `$(( ... ))` arithmetic context coerces the whitespace-padded string to an integer on all shells.

### Anti-Patterns to Avoid

- **`ls -d ~/.claude-backup-* | wc -l`:** Glob expansion fails with exit 1 when 0 matches; `find` returns 0.
- **`stat -f %m` without uname guard:** BSD-only flag; state.sh already demonstrates the correct `uname` guard pattern.
- **`sort -V` for epoch sort:** `-V` is not POSIX; exists on GNU but not BSD. For epoch-numeric sort, use `sort -t- -k3,3n` or extract epochs and sort numerically in a loop. D-02 mandates parsing the epoch from the name; sorting by extracted epoch integer is portable.
- **Sourcing backup.sh without `set -euo pipefail` awareness:** backup.sh must NOT set `set -euo pipefail` at file level (same rule as state.sh and install.sh — sourced libs must not alter caller error mode).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic JSON write | Manual `>` redirect | `tempfile + os.replace` (already in state.sh) | Non-atomic writes corrupt state on script kill |
| BSD/GNU stat portability | New `uname` guard | `date -u +%s` from dir name (D-02) | Dir name carries the epoch monotonically — no stat needed |
| Plugin JSON parse | Custom grep/sed | `jq` (already a hard dep) | jq handles all edge cases; grep on JSON is fragile |
| `/dev/tty` simulation in tests | Custom expect/pexpect | FIFO pattern (already in test-update-diff.sh) | Established precedent in this codebase |

---

## Integration Points

### DETECT-06: Exact Insertion Site in `detect_superpowers()`

```
detect.sh:32-77 — detect_superpowers() body
  :34  — [STEP 1] FS dir exists?
  :43  — [STEP 2] versioned subdir found? (sets local var=ver)
  :57  — [STEP 3] settings.json enabledPlugins gate
  :71  — closes STEP 3 block
  :73  — HAS_SP=true        ← INSERT STEP 4 (CLI cross-check) BETWEEN LINE 71 AND 73
  :74  — SP_VERSION="$ver"  ← CLI version may override this (D-18)
```

**Step 4 insertion replaces lines 73-76 with:**

```bash
# [STEP 4] DETECT-06: cross-check with `claude plugin list --json`.
# SP only — GSD is not a Claude Code plugin (no entry in `claude plugin list`).
# Silent skip when claude CLI absent or errors. FS result wins on any CLI failure.
if command -v claude &>/dev/null && command -v jq &>/dev/null; then
    local cli_enabled
    cli_enabled=$(claude plugin list --json 2>/dev/null \
        | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .enabled' \
        2>/dev/null || echo "")
    case "$cli_enabled" in
        "false")
            # CLI explicitly disabled — override FS
            HAS_SP=false; SP_VERSION=""; export HAS_SP SP_VERSION; return 1 ;;
        "true")
            # CLI confirms enabled; use CLI version (D-18) if available
            local cli_ver
            cli_ver=$(claude plugin list --json 2>/dev/null \
                | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version' \
                2>/dev/null || echo "")
            [[ -n "$cli_ver" ]] && ver="$cli_ver"
            ;;
        "")
            # Empty = CLI doesn't know about SP — fall back to FS truth (don't override)
            ;;
    esac
fi

HAS_SP=true
SP_VERSION="$ver"
export HAS_SP SP_VERSION
return 0
```

**Note:** Two calls to `claude plugin list --json` in the `"true"` branch. Consider capturing output to a variable once to halve subprocess cost. The planner may inline this optimization.

[VERIFIED: lines 71-76 read directly from scripts/detect.sh]

### DETECT-07: Emission Position in `update-claude.sh`

```
update-claude.sh (annotated lines after research):
  :52   — test seam: HAS_SP/HAS_GSD env var bypass (or source detect.sh)
  :277  — STATE_JSON populated (read_state / synthesize_v3_state)
  :286  — STATE_MODE extracted from STATE_JSON
  :291  — STATE_MANIFEST_HASH extracted
  :297  — migrate hint block (standalone + SP/GSD present)
  :314  — RECOMMENDED=$(recommend_mode)
          ↑ warn_version_skew() invocation goes HERE (after line 291, before line 297 or 314)
  :455  — is_update_noop: early exit
  :459  — backup dir created (BACKUP-02 threshold check goes HERE)
  :210  — print_update_summary() called (at end of main flow)
```

**Exact position for `warn_version_skew()` call:** After line 291 (STATE_MANIFEST_HASH extraction), before line 297 (migrate hint block). This satisfies D-23 ("after read_state + detection, before prompts or summary"). The migrate hint block at 297 counts as informational display, not a "prompt", so inserting before it is acceptable — but inserting before the hint block keeps the warning with other read-only informational output.

[VERIFIED: lines read directly from scripts/update-claude.sh]

### DETECT-07: jq Expressions for `warn_version_skew()`

**State schema v2 (VERIFIED: scripts/lib/state.sh:86-93):**

```json
{
  "version": 2,
  "detected": {
    "superpowers": { "present": true,  "version": "5.0.7" },
    "gsd":         { "present": false, "version": "" }
  }
}
```

**Critical disambiguation:** `state.version` = schema version (integer `2`), NOT the toolkit or plugin version. Plugin versions live at `state.detected.superpowers.version` and `state.detected.gsd.version`. DETECT-07 reads the latter two.

```bash
# Source: D-26 (jq expressions specified in CONTEXT.md, cross-verified against state.sh schema)
stored_sp=$(jq -r '.detected.superpowers.version // ""' "$STATE_FILE" 2>/dev/null || echo "")
stored_gsd=$(jq -r '.detected.gsd.version // ""'        "$STATE_FILE" 2>/dev/null || echo "")
```

**`warn_version_skew()` implementation (lands in `scripts/lib/install.sh`):**

```bash
# warn_version_skew — compare stored plugin versions against current detection.
# Emits one YELLOW ⚠ line per changed plugin. Non-fatal, no prompt (D-24/D-25).
# Caller must have already sourced detect.sh (SP_VERSION / GSD_VERSION in scope)
# and called read_state (STATE_FILE path available).
warn_version_skew() {
    [[ -f "${STATE_FILE:-}" ]] || return 0
    local stored_sp stored_gsd
    stored_sp=$(jq -r '.detected.superpowers.version // ""' "$STATE_FILE" 2>/dev/null || echo "")
    stored_gsd=$(jq -r '.detected.gsd.version // ""'        "$STATE_FILE" 2>/dev/null || echo "")
    # Only fire when stored version is non-empty AND differs from current (D-23)
    if [[ -n "$stored_sp"  && "$stored_sp"  != "${SP_VERSION:-}"  ]]; then
        echo -e "${YELLOW}⚠${NC} Base plugin version changed: superpowers ${stored_sp} → ${SP_VERSION:-unknown} — review install matrix"
    fi
    if [[ -n "$stored_gsd" && "$stored_gsd" != "${GSD_VERSION:-}" ]]; then
        echo -e "${YELLOW}⚠${NC} Base plugin version changed: get-shit-done ${stored_gsd} → ${GSD_VERSION:-unknown} — review install matrix"
    fi
}
```

[VERIFIED: schema at state.sh:86-93; YELLOW+NC constants defined in install.sh:14-16]

### BACKUP-01: Arg Parser Insertion Site in `update-claude.sh`

Current arg parser at lines 14-25:

```bash
for arg in "$@"; do
    case "$arg" in
        --no-banner) NO_BANNER=1 ;;
        --offer-mode-switch=yes)  ... ;;
        --prune=yes) PRUNE_MODE="yes" ;;
        ...
        *) ;;
    esac
done
```

**New flags to add:**

```bash
# Before the loop, initialize:
CLEAN_BACKUPS=0
KEEP_N=""
DRY_RUN_CLEAN=0

# Inside the case:
--clean-backups)       CLEAN_BACKUPS=1 ;;
--keep)                # value in next arg — requires refactoring loop to while+shift
                       # OR use --keep=N form:
--keep=*)              KEEP_N="${arg#--keep=}" ;;
--dry-run)             DRY_RUN_CLEAN=1 ;;  # existing flag or new
```

**Recommendation:** Use `--keep=N` form (matches `--offer-mode-switch=yes` precedent at line 17) to avoid needing a while+shift loop. If `--dry-run` already exists in the arg parser, reuse it; otherwise add it.

**Dispatch position:** `--clean-backups` dispatch must happen BEFORE the lock acquisition at line 455 (D-28 context note: "keep cleanup outside the tree-backup mutation"). Check `.claude` dir existence at line 265, then insert:

```bash
# After line 269 (banner block), before line 274 (state file check):
if [[ $CLEAN_BACKUPS -eq 1 ]]; then
    run_clean_backups "${KEEP_N:-}" "$DRY_RUN_CLEAN"
    exit $?
fi
```

[VERIFIED: line ranges from scripts/update-claude.sh direct read]

---

## setup-security.sh Backup Audit

**Finding (CRITICAL for D-28):** `setup-security.sh` does **NOT** create a `.claude-backup-<epoch>-<pid>` or `.claude-backup-pre-migrate-<epoch>` sibling directory. [VERIFIED: grep of scripts/setup-security.sh for `backup`, `cp -R`, `.claude-backup`]

It only calls `backup_settings_once()` from `lib/install.sh`, which creates `~/.claude/settings.json.bak.<epoch>` — a `.bak.*` suffixed file alongside `settings.json`, entirely within `~/.claude/`, NOT a sibling directory of `.claude/`.

**Impact on D-10/D-28:** `setup-security.sh` is **excluded** from the BACKUP-02 caller surface. The D-10 note "if / when `setup-security.sh` creates a backup sibling" is a future-conditional that is currently FALSE.

**BACKUP-02 callers (Phase 9):**

1. `scripts/update-claude.sh` — creates `.claude-backup-<epoch>-<pid>` at line 457
2. `scripts/migrate-to-complement.sh` — creates `.claude-backup-pre-migrate-<epoch>` at line 270

No third caller. D-28's "setup-security.sh (verify)" is verified negative.

---

## BACKUP-02 Caller Surface

**Call site in `update-claude.sh` (line 457-459):**

```bash
BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-$(date -u +%s)-$$"
cp -R "$CLAUDE_DIR" "$BACKUP_DIR"
log_success "Backup created: $BACKUP_DIR"
# ← INSERT: warn_if_too_many_backups HERE (after successful backup creation, D-11)
```

**Call site in `migrate-to-complement.sh` (line 270-278):**

```bash
BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-pre-migrate-$(date -u +%s)"
if ! cp -R "$CLAUDE_DIR" "$BACKUP_DIR"; then
    log_error "Backup failed ..."
    exit 1
fi
log_success "Backup created: $BACKUP_DIR"
# ← INSERT: warn_if_too_many_backups HERE
```

**`warn_if_too_many_backups()` in `scripts/lib/backup.sh`:**

```bash
# warn_if_too_many_backups — emit a single YELLOW ⚠ when combined backup dir count > 10.
# Threshold is hard-coded at 10 per D-09 (v4.1; tunable in v4.2+ via env var).
# Must be called AFTER a successful backup creation (D-11: "Emitted AFTER dir created").
warn_if_too_many_backups() {
    local count
    count=$(( $(find "$HOME" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
        2>/dev/null | wc -l) ))
    if [[ $count -gt 10 ]]; then
        echo -e "${YELLOW}⚠${NC} ${count} toolkit backup dirs under \$HOME — run \`update-claude.sh --clean-backups\` to prune"
    fi
}
```

Note: `YELLOW` and `NC` must either be passed as args or re-declared in backup.sh (sourced libs redeclare color constants — this is the existing pattern in state.sh:12-13 and install.sh:12-14).

[VERIFIED: color constant redeclaration pattern in state.sh:12-13, install.sh:12-14]

---

## Bats Harness Reuse

### Available helpers in `scripts/tests/matrix/lib/helpers.bash`

[VERIFIED: file read directly]

| Helper | Signature | Usable for BACKUP-01 |
|--------|-----------|----------------------|
| `sandbox_setup <name>` | Creates `/tmp/tk-matrix-<name>-<epoch>` with `.claude/` | YES — provides isolated HOME |
| `assert_eq <expected> <actual> <msg>` | String equality with PASS/FAIL counter | YES — check exit codes, dir counts |
| `assert_contains <needle> <haystack> <msg>` | grep-based substring | YES — check warning text in output |
| `stage_sp_cache <cell_home>` | Seeds SP plugin dir fixture | Indirectly (not needed for backup tests) |

### New Assertions Needed for BACKUP-01

These do not exist in helpers.bash and must be added to the test file (or helpers.bash if canonical):

```bash
# assert_dir_absent <path> <msg>
assert_dir_absent() {
    local path="$1" msg="$2"
    if [[ ! -d "$path" ]]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg} (dir exists: $path)" >&2
    fi
}

# assert_dir_present <path> <msg>
assert_dir_present() {
    local path="$1" msg="$2"
    if [[ -d "$path" ]]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg} (dir missing: $path)" >&2
    fi
}

# assert_backup_count <home> <expected_count> <msg>
assert_backup_count() {
    local home="$1" expected="$2" msg="$3"
    local actual
    actual=$(( $(find "$home" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
        2>/dev/null | wc -l) ))
    assert_eq "$expected" "$actual" "$msg"
}
```

### Test Scaffolding Recommendation

**BACKUP-01 test file:** `scripts/tests/test-clean-backups.sh` (bash-only, NOT bats).

Rationale: The Phase 8 bats matrix tests are about install cell correctness. `--clean-backups` is a CLI flag behavior with interactive prompts. The FIFO simulation pattern (from `test-update-diff.sh`) already exists in the bash test infrastructure. Mixing into the bats matrix adds a non-install cell that would need special treatment (D-29 notes this as a decision point). Using the bash pattern keeps BACKUP-01 alongside the analogous prompt-behavior tests.

If bats is preferred, the model to follow is `scripts/tests/matrix/translation-sync.bats` — a non-install-cell bats file (cell 13, Phase 8 note in CONTEXT.md).

---

## Testing Strategy Detail

### DETECT-06: Stubbing `claude` on PATH

```bash
# In test setup: create a mock claude binary in a temp fixtures/bin/
MOCK_BIN="$(mktemp -d)/bin"
mkdir -p "$MOCK_BIN"

# Scenario A: SP enabled (CLI confirms)
cat > "$MOCK_BIN/claude" <<'MOCK'
#!/bin/bash
if [[ "$1 $2 $3" == "plugin list --json" ]]; then
    echo '[{"id":"superpowers@claude-plugins-official","version":"5.1.0","enabled":true}]'
fi
MOCK
chmod +x "$MOCK_BIN/claude"

# Prepend to PATH so command -v claude finds the mock:
PATH="$MOCK_BIN:$PATH" source "$REPO_ROOT/scripts/detect.sh"
# Assert: HAS_SP=true, SP_VERSION=5.1.0
```

```bash
# Scenario B: SP disabled (CLI overrides FS)
cat > "$MOCK_BIN/claude" <<'MOCK'
#!/bin/bash
echo '[{"id":"superpowers@claude-plugins-official","version":"5.0.7","enabled":false}]'
MOCK
# Also stage the SP FS dir so FS says "present":
stage_sp_cache "$CELL_HOME" "5.0.7"
# Assert: HAS_SP=false (CLI wins over FS)
```

```bash
# Scenario C: CLI absent (command -v claude returns non-zero)
# No mock binary — remove from PATH entirely or use a $MOCK_BIN with no claude file
unset PATH_WITH_MOCK
# Assert: HAS_SP follows FS result
```

```bash
# Scenario D: CLI errors (non-zero exit)
cat > "$MOCK_BIN/claude" <<'MOCK'
#!/bin/bash
exit 1
MOCK
# Assert: HAS_SP follows FS result (soft-fail, D-17)
```

```bash
# Scenario E: CLI returns non-JSON
cat > "$MOCK_BIN/claude" <<'MOCK'
#!/bin/bash
echo "Error: could not connect to daemon"
MOCK
# Assert: jq 2>/dev/null || echo "" returns ""; FS wins
```

[ASSUMED] — the stub binary approach is the standard pattern for CLI mocking in bash tests; confirmed by analogy with TK_UPDATE_FILE_SRC seam pattern.

### DETECT-07: Seeding a Fake `toolkit-install.json`

Use `TK_UPDATE_HOME` seam (already wired in update-claude.sh:109-115):

```bash
# Test setup:
SCR=$(mktemp -d)
mkdir -p "$SCR/.claude"

# Seed state with an OLD plugin version:
cat > "$SCR/.claude/toolkit-install.json" <<'JSON'
{
  "version": 2,
  "mode": "standalone",
  "detected": {
    "superpowers": { "present": true,  "version": "5.0.7" },
    "gsd":         { "present": false, "version": "" }
  },
  "installed_files": [],
  "skipped_files": [],
  "installed_at": "2026-01-01T00:00:00Z"
}
JSON

# Run update-claude.sh with HAS_SP=true, SP_VERSION="5.1.0" (simulating upgraded SP):
OUT=$(TK_UPDATE_HOME="$SCR" \
      TK_UPDATE_LIB_DIR="$LIB_DIR" \
      TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
      TK_UPDATE_FILE_SRC="$FILE_SRC" \
      HAS_SP=true HAS_GSD=false SP_VERSION="5.1.0" GSD_VERSION="" \
      bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --no-offer-mode-switch 2>&1 || true)

# Assert: warning line present in OUT
assert_contains "superpowers 5.0.7 → 5.1.0" "$OUT" "version-skew warning emitted"
assert_contains "review install matrix"       "$OUT" "skew warning contains guidance"
```

**Scenario: stored version empty (pre-v4.1 install) — must stay silent:**

```bash
# "version": "" in state → warn_version_skew() must not fire
```

[VERIFIED: TK_UPDATE_HOME seam at update-claude.sh:109-115]

---

## BSD/GNU Portability Verification

### Commands Used in Phase 9

| Command | Flag | macOS BSD | GNU Linux | Verdict |
|---------|------|-----------|-----------|---------|
| `find` | `-maxdepth 1` | YES | YES | Safe [VERIFIED: find(1) macOS man page; GNU find docs] |
| `find` | `-type d` | YES | YES | Safe |
| `find` | `\( -name ... -o -name ... \)` | YES | YES | Safe |
| `du` | `-sh` | YES | YES | Safe — `-s` summary, `-h` human; POSIX subset |
| `date` | `-u +%s` | YES | YES | Safe [VERIFIED: used in existing scripts] |
| `wc` | `-l` (with leading spaces) | Emits leading spaces | No leading spaces | Use `$(( $(wc -l) ))` to strip |
| `sort` | `-V` (version sort) | NO (BSD sort) | YES | **AVOID** for epoch sort — use `-n` |
| `stat` | `-f %m` / `-c %Y` | Divergent | Divergent | Avoid for backup age — use epoch from name (D-02) |

### Age Calculation: Confirmed POSIX-Safe

```bash
# Both macOS and Linux support date -u +%s (VERIFIED: existing usage in update-claude.sh:457)
# Arithmetic is pure bash — no external tool:
now=$(date -u +%s)
age_secs=$(( now - epoch ))  # epoch extracted from dir name via parameter expansion
```

### `du -sh` Output Format

```
macOS BSD:  " 4.0K\t./path"  (tab-separated with leading space on size)
GNU Linux:  "4.0K\t./path"   (no leading space)
```

For display only (BACKUP-01 prompt), this is acceptable — the user sees `4.0K` either way. No parsing needed; `du -sh "$dir" | cut -f1` gives the size column on both platforms.

---

## Common Pitfalls

### Pitfall 1: `wc -l` Leading Spaces on macOS

**What goes wrong:** `count=$(find ... | wc -l)` gives `"      3"` on macOS, and `[[ $count -gt 10 ]]` may fail in strict string comparison contexts.

**Why it happens:** macOS BSD `wc -l` always right-justifies the count with spaces.

**How to avoid:** Always wrap in arithmetic: `count=$(( $(find ... | wc -l) ))`.

**Warning signs:** Test passes on Linux CI but fails on macOS.

### Pitfall 2: `sort -V` Not Available on macOS BSD sort

**What goes wrong:** Using `sort -V` to sort backup dirs by version/epoch gives "sort: illegal option -- V" on macOS.

**Why it happens:** `-V` (version sort) is a GNU coreutils extension.

**How to avoid:** Extract epochs numerically and sort with `sort -n`. For `--keep N`, collect epochs with a loop, sort numerically, take the N largest.

**Warning signs:** Shellcheck may not catch this; it only appears at runtime on macOS.

### Pitfall 3: `backup.sh` Sourcing Without Color Constants

**What goes wrong:** `warn_if_too_many_backups()` uses `YELLOW` and `NC` but the sourcing script may not have defined them yet.

**Why it happens:** Lib files are sourced at various points in callers.

**How to avoid:** Declare `YELLOW` and `NC` inside `backup.sh` (pattern: state.sh:12-13 does the same). Callers that redeclare them get the last write — all set to the same value anyway.

### Pitfall 4: `claude plugin list --json` Returns Array or Object

**What goes wrong:** If the CLI returns `{}` instead of `[]` on an empty result, `jq '.[] | select(...)'` emits an error.

**Why it happens:** CLI output format not fully specified; future Claude Code versions could change it.

**How to avoid:** Always pipe through `jq -r '... | .enabled' 2>/dev/null || echo ""`. The `2>/dev/null` on jq suppresses parse errors; `|| echo ""` gives a safe empty default.

### Pitfall 5: Two Subprocess Calls for `claude plugin list --json`

**What goes wrong:** The DETECT-06 insertion calls `claude plugin list --json` twice — once to get `.enabled`, once to get `.version`.

**Why it happens:** The reference design in D-16 only asks for `.enabled`; D-18 adds version retrieval as a separate concern.

**How to avoid:** Capture the full JSON output to a variable:

```bash
local cli_json=""
cli_json=$(claude plugin list --json 2>/dev/null || echo "")
local cli_enabled cli_ver
cli_enabled=$(jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .enabled'  <<<"$cli_json" 2>/dev/null || echo "")
cli_ver=$(    jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version' <<<"$cli_json" 2>/dev/null || echo "")
```

### Pitfall 6: `detect.sh` No `set -euo pipefail`

**What goes wrong:** Adding `set -e` or `pipefail` in detect.sh breaks callers that source it inside their own `set -e` context (a `return 1` from `detect_superpowers` when SP is absent would abort the entire caller).

**Why it happens:** detect.sh is a sourced library, not a script. Line 12 of detect.sh already documents this: "No errexit/nounset/pipefail here — sourced files must not alter caller error mode."

**How to avoid:** backup.sh must carry the same disclaimer. No `set -euo pipefail` at file level.

---

## `claude plugin list --json` CLI Output Shape

[VERIFIED: D-13 in CONTEXT.md cites live CLI probe; CONTEXT.md canonical_refs confirms shape]

```json
[
  {
    "id": "superpowers@claude-plugins-official",
    "version": "5.0.7",
    "scope": "user",
    "enabled": true,
    "installPath": "/Users/username/.claude/plugins/cache/...",
    "installedAt": "2026-01-15T10:00:00Z",
    "lastUpdated": "2026-03-01T08:00:00Z"
  }
]
```

**Key properties:**

- `enabled` is a boolean (`true`/`false`), NOT a string. `jq -r '... | .enabled'` outputs `true` or `false` as plain text strings.
- GSD does **not** appear in this array (confirmed by live probe per D-13).
- An empty array `[]` is returned when no plugins are registered. `jq '.[] | select(.id == ...)` on `[]` emits nothing (empty string), which maps to the "fall back to FS" case (D-16 `empty` branch).

**Three states for `cli_enabled` variable:**

| Value | Meaning | Action |
|-------|---------|--------|
| `"true"` | CLI confirms SP enabled | Proceed; CLI version wins (D-18) |
| `"false"` | CLI says SP disabled | Override FS → `HAS_SP=false` |
| `""` (empty) | CLI doesn't know about SP, or CLI errored | FS result wins, no override |

[VERIFIED: D-16 specifies these three states explicitly; jq `-r` output for booleans is `true`/`false` as text]

---

## Plan Decomposition Recommendation

**Recommendation: 4 per-REQ plans.**

D-30 already mandates 4 per-REQ branches. Plans align 1:1 with branches. The only shared artifact is `scripts/lib/backup.sh` — create it in the `feature/backup-01-clean-backups` plan (BACKUP-01 needs it first), then BACKUP-02 plan sources it. This sequencing means BACKUP-01 must merge before BACKUP-02 branches off, OR BACKUP-02 creates a stub backup.sh and BACKUP-01 fills it in. The cleaner approach: BACKUP-01 plan creates the full `backup.sh` (including `warn_if_too_many_backups()`), BACKUP-02 plan only wires the call sites in migrate-to-complement.sh (update-claude.sh already gets the call in BACKUP-01).

**Plan execution order:** BACKUP-01 → BACKUP-02 → DETECT-06 → DETECT-07

All four are independent of each other except the `backup.sh` dependency (BACKUP-01 before BACKUP-02).

---

## Code Examples

### `warn_version_skew()` Full Implementation

```bash
# Source: D-26 (CONTEXT.md), state schema verified at state.sh:86-93
# Lands in: scripts/lib/install.sh (append at end)
warn_version_skew() {
    [[ -f "${STATE_FILE:-}" ]] || return 0
    command -v jq &>/dev/null || return 0
    local stored_sp stored_gsd
    stored_sp=$(jq -r '.detected.superpowers.version // ""' "$STATE_FILE" 2>/dev/null || echo "")
    stored_gsd=$(jq -r '.detected.gsd.version // ""'        "$STATE_FILE" 2>/dev/null || echo "")
    if [[ -n "$stored_sp"  && "$stored_sp"  != "${SP_VERSION:-}"  ]]; then
        echo -e "${YELLOW}⚠${NC} Base plugin version changed: superpowers ${stored_sp} → ${SP_VERSION:-unknown} — review install matrix"
    fi
    if [[ -n "$stored_gsd" && "$stored_gsd" != "${GSD_VERSION:-}" ]]; then
        echo -e "${YELLOW}⚠${NC} Base plugin version changed: get-shit-done ${stored_gsd} → ${GSD_VERSION:-unknown} — review install matrix"
    fi
}
```

### `list_backup_dirs()` (optional helper in backup.sh)

```bash
# Stdout: one absolute path per line, sorted descending by epoch (newest first)
# No output when no dirs found.
list_backup_dirs() {
    local home="${1:-$HOME}"
    # Print each dir with its extracted epoch as a sort key, then strip the key
    while IFS= read -r dir; do
        local name epoch
        name="$(basename "$dir")"
        case "$name" in
            .claude-backup-[0-9]*-[0-9]*)
                epoch="${name#.claude-backup-}"
                epoch="${epoch%-*}"
                ;;
            .claude-backup-pre-migrate-[0-9]*)
                epoch="${name#.claude-backup-pre-migrate-}"
                ;;
            *) continue ;;
        esac
        printf '%s %s\n' "$epoch" "$dir"
    done < <(find "$home" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
        2>/dev/null) \
    | sort -rn \
    | cut -d' ' -f2-
}
```

Note: `sort -rn` sorts by the numeric epoch key (first column), descending. This is POSIX-safe (no `-V`).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| FS-only SP detection | FS + settings.json gate | Phase 3 (DETECT-03) | Handles stale-cache false positives |
| FS + settings.json gate | FS + settings.json + CLI cross-check | Phase 9 (DETECT-06) | Handles CLI-disabled-but-FS-present case |
| No backup housekeeping | `--clean-backups` CLI flag | Phase 9 (BACKUP-01) | Users can prune accumulated backup dirs |
| No version tracking | Plugin versions stored in state schema v2 | Phase 4 | Enables DETECT-07 skew detection |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `claude plugin list --json` `.enabled` is a strict boolean serialized as `true`/`false` text by `jq -r` | CLI Output Shape | Planner uses `.enabled` jq filter; if it's a string `"true"` the `case` logic still works (comparing `"true"` to `"true"`), but the filter would need adjustment if it's 1/0 or yes/no |
| A2 | `claude` CLI call takes < 200ms on a live machine (no timeout needed per D-17) | CLI Integration | If the CLI hangs in CI, DETECT-06 will hang test runs. D-17 explicitly defers the fix. |
| A3 | FIFO pattern for multi-prompt injection (N `y\n` lines) works with the `< /dev/tty` read idiom | Testing Strategy | If the bash `read < /dev/tty` does NOT fall through to FIFO when `/dev/tty` is redirected via `0<FIFO`, the fail-closed path must be tested instead |
| A4 | Age string format `14d 3h` / `5h 12m` / `<1m` (Claude's discretion per D-04) | Pattern 3 | Cosmetic only — wrong format doesn't break behavior |

---

## Open Questions

1. **FIFO + `< /dev/tty` interaction for multi-prompt BACKUP-01 tests**
   - What we know: The existing FIFO test in `test-update-diff.sh:295-312` works for a single `< /dev/tty` read.
   - What's unclear: Whether `0<FIFO` redirects ALL subsequent `< /dev/tty` reads in the subprocess, or only stdin-based reads.
   - Recommendation: Write the BACKUP-01 test to exercise the fail-closed path (no FIFO) for batch assertions; use the FIFO with `printf 'y\ny\nn\n' > FIFO &` for the specific "N prompts answered" test.

2. **`claude plugin list --json` availability in CI**
   - What we know: `command -v claude` guard is in place (D-15); missing CLI is a silent skip.
   - What's unclear: Whether the `ubuntu-latest` GitHub Actions runner has `claude` on PATH.
   - Recommendation: DETECT-06 tests must work without real `claude` by using the mock binary stub. No CI dependency on real claude CLI.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | All scripts | ✓ | 3.2+ (macOS), 5.x (Linux) | — |
| jq | DETECT-06/07, backup.sh | ✓ | 1.6+ (existing hard dep) | — |
| bats-core | BACKUP-01 tests (if bats chosen) | Check CI | Phase 8 bats tests imply available | bash-only test as fallback |
| claude CLI | DETECT-06 at runtime | Optional | Unknown | Silent skip via `command -v` guard |
| find | BACKUP-01/02 dir discovery | ✓ | macOS BSD + GNU Linux | — |
| du | BACKUP-01 size display | ✓ | POSIX standard | — |

---

## Validation Architecture

> `workflow.nyquist_validation` not explicitly set to `false` in `.planning/config.json` — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bats-core (BACKUP-01 optional) + bash unit tests (DETECT-06/07) |
| Config file | None — bats files are self-contained; bash tests run via `bash test-file.sh` |
| Quick run command | `bash scripts/tests/test-clean-backups.sh && bash scripts/tests/test-detect-cli.sh` |
| Full suite command | `make test` (existing target, picks up new test files in `scripts/tests/`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BACKUP-01 | `--clean-backups` lists dirs, prompts per-dir, removes on `y` | bash unit | `bash scripts/tests/test-clean-backups.sh` | ❌ Wave 0 |
| BACKUP-01 | `--keep N` preserves N most recent by epoch | bash unit | `bash scripts/tests/test-clean-backups.sh` | ❌ Wave 0 |
| BACKUP-01 | `--dry-run` composes: prints list, no delete | bash unit | `bash scripts/tests/test-clean-backups.sh` | ❌ Wave 0 |
| BACKUP-01 | Exit 2 on invalid `--keep` value | bash unit | `bash scripts/tests/test-clean-backups.sh` | ❌ Wave 0 |
| BACKUP-01 | Empty set: prints message + exits 0 | bash unit | `bash scripts/tests/test-clean-backups.sh` | ❌ Wave 0 |
| BACKUP-02 | Threshold warning emitted when count > 10 | bash unit | `bash scripts/tests/test-backup-threshold.sh` | ❌ Wave 0 |
| BACKUP-02 | No warning when count <= 10 | bash unit | `bash scripts/tests/test-backup-threshold.sh` | ❌ Wave 0 |
| DETECT-06 | CLI disabled overrides FS present → `HAS_SP=false` | bash unit | `bash scripts/tests/test-detect-cli.sh` | ❌ Wave 0 |
| DETECT-06 | CLI absent → FS result wins (silent skip) | bash unit | `bash scripts/tests/test-detect-cli.sh` | ❌ Wave 0 |
| DETECT-06 | CLI errors (non-zero exit) → soft-fail, FS wins | bash unit | `bash scripts/tests/test-detect-cli.sh` | ❌ Wave 0 |
| DETECT-06 | CLI returns non-JSON → soft-fail, FS wins | bash unit | `bash scripts/tests/test-detect-cli.sh` | ❌ Wave 0 |
| DETECT-06 | CLI enabled + version → SP_VERSION uses CLI version | bash unit | `bash scripts/tests/test-detect-cli.sh` | ❌ Wave 0 |
| DETECT-06 | Plugin absent from CLI list (empty) → FS wins | bash unit | `bash scripts/tests/test-detect-cli.sh` | ❌ Wave 0 |
| DETECT-07 | Stored version differs → warning emitted | bash unit | `bash scripts/tests/test-detect-skew.sh` | ❌ Wave 0 |
| DETECT-07 | Stored version matches current → silent | bash unit | `bash scripts/tests/test-detect-skew.sh` | ❌ Wave 0 |
| DETECT-07 | Stored version empty (pre-v4.1) → silent | bash unit | `bash scripts/tests/test-detect-skew.sh` | ❌ Wave 0 |
| DETECT-07 | No state file → silent | bash unit | `bash scripts/tests/test-detect-skew.sh` | ❌ Wave 0 |

### Nyquist Edge Case Coverage

| Scenario | REQ | Test type | Notes |
|----------|-----|-----------|-------|
| 0 backup dirs | BACKUP-01/02 | unit | Empty-set path (D-07) |
| 1 backup dir | BACKUP-01 | unit | Single-item list |
| Exactly 10 backup dirs | BACKUP-02 | unit | Boundary: must NOT warn |
| 11 backup dirs | BACKUP-02 | unit | Boundary: MUST warn |
| `--keep 0` (keep none) | BACKUP-01 | unit | Edge: all go to prompt queue |
| `--keep` value = all dirs | BACKUP-01 | unit | Edge: nothing to prompt |
| `--keep` negative | BACKUP-01 | unit | Exit 2 (D-06) |
| `--keep` non-numeric | BACKUP-01 | unit | Exit 2 (D-06) |
| `--dry-run` with 5 dirs | BACKUP-01 | unit | Print only, no delete, exit 0 |
| CLI absent | DETECT-06 | unit | `command -v claude` fails → FS wins |
| CLI present + SP enabled | DETECT-06 | unit | `HAS_SP=true`, `SP_VERSION` from CLI |
| CLI present + SP disabled | DETECT-06 | unit | `HAS_SP=false` (overrides FS) |
| CLI present + SP missing from list | DETECT-06 | unit | Empty jq result → FS wins |
| CLI non-zero exit | DETECT-06 | unit | Soft-fail → FS wins |
| CLI non-JSON output | DETECT-06 | unit | jq error → empty → FS wins |
| No state file | DETECT-07 | unit | Function returns 0 silently |
| State has empty version | DETECT-07 | unit | Must NOT fire warning |
| Version matches | DETECT-07 | unit | Silent |
| Version differs (SP only) | DETECT-07 | unit | SP warning line only |
| Version differs (both) | DETECT-07 | unit | Two warning lines |

### Sampling Rate

- **Per task commit:** `bash scripts/tests/test-clean-backups.sh && bash scripts/tests/test-detect-cli.sh`
- **Per wave merge:** `make test` (full suite including Phase 8 matrix cells)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `scripts/tests/test-clean-backups.sh` — covers BACKUP-01 (all rows above)
- [ ] `scripts/tests/test-backup-threshold.sh` — covers BACKUP-02 (can be merged into test-clean-backups.sh if preferred)
- [ ] `scripts/tests/test-detect-cli.sh` — covers DETECT-06
- [ ] `scripts/tests/test-detect-skew.sh` — covers DETECT-07 (can be merged with test-detect-cli.sh)
- [ ] `scripts/lib/backup.sh` — source file under test (must exist before tests run)

---

## Security Domain

Phase 9 adds no authentication, no new file ingestion from user input, no cryptography, and no network endpoints. The only security-adjacent concern is destructive file operations (`rm -rf` on backup dirs).

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | partial | `--keep N` value validated (exit 2 on non-numeric/negative) |
| V6 Cryptography | no | — |

**`rm -rf` safety:** Per-dir `[y/N]` prompt (D-03) + `--dry-run` preview (D-05) are the primary safeguards. The `--force` batch delete flag is explicitly rejected (PROJECT.md invariant: "every destructive action prompts"). `rm -rf` is called only on paths that match the known backup dir name patterns — not on arbitrary user-provided paths.

---

## Sources

### Primary (HIGH confidence)

- `scripts/update-claude.sh` (read directly) — arg parser lines 14-25, read_state position 277-291, backup dir creation 457-459, `< /dev/tty` idiom 381/525/598
- `scripts/detect.sh` (read directly) — detect_superpowers() body 32-77, insertion site at line 71-73
- `scripts/lib/state.sh` (read directly) — state schema v2 at 86-93, `detected.superpowers.version` JSON path
- `scripts/lib/install.sh` (read directly) — `warn_version_skew()` landing zone, color constants at 12-14
- `scripts/lib/backup.sh` — does not yet exist (Phase 9 creates it)
- `scripts/tests/matrix/lib/helpers.bash` (read directly) — `sandbox_setup`, `assert_eq`, `assert_contains` API
- `scripts/tests/test-update-diff.sh` (read directly) — FIFO simulation pattern lines 295-312
- `scripts/setup-security.sh` (grep'd) — confirmed NO sibling `.claude-backup-*` dir creation
- `scripts/migrate-to-complement.sh` (read directly) — second backup pattern at line 270

### Secondary (MEDIUM confidence)

- D-01..D-32 in `09-CONTEXT.md` — all implementation decisions (gathered from live CLI probe and codebase scout during discuss-phase)

### Tertiary (LOW confidence)

- A3 (FIFO multi-prompt behavior) — inferred from single-prompt test; not tested with multiple consecutive reads

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — POSIX shell, jq; all pre-existing deps
- Architecture: HIGH — all insertion sites verified by direct file read
- Pitfalls: HIGH — BSD/GNU divergences confirmed by existing `uname` guards in codebase
- Testing patterns: HIGH — FIFO and seam patterns verified from existing test code

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (stable codebase; no moving dependencies)
