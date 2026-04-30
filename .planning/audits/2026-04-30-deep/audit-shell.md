# Shell Audit — 2026-04-30 (deep)

Audit scope: `scripts/*.sh` (15 top-level), `scripts/lib/*.sh` (14 libs).
Methodology: data-flow trace + grep + xxd verification. Heuristics paired with
manual reasoning (per `.claude/rules/lessons-learned.md`).

## Numbers
- files reviewed: 29 (15 top-level + 14 lib)
- shellcheck -S warning findings: 0 (clean)
- new findings: CRIT=0 HIGH=2 MED=4 LOW=4 (10 total)
- regressions of past fixes: 0

## Findings

### S-HIGH-1 — `--clean-backups` rejects every legitimate backup in production

- File:line: `scripts/update-claude.sh:343`
- Severity: HIGH (confidence: 98%)
- Pattern: relative `dirname` vs absolute `find` paths — comparison is structurally
  unreachable in the production code path.

Why exploitable: Reproducible runtime bug. Every legitimate backup directory is
flagged "Refusing to remove suspicious path: …" so the user cannot prune backups
through the documented `--clean-backups` flag. Tests pass only because every
test fixture exports `TK_UPDATE_HOME=$SCR` (an absolute path), which masks the
production behavior.

Data-flow:
1. `scripts/update-claude.sh:82` sets `CLAUDE_DIR=".claude"` (relative).
2. `TK_UPDATE_HOME` is unset in production → block at lines 170-172 is skipped, so
   `CLAUDE_DIR` remains `".claude"`.
3. `scripts/update-claude.sh:274` calls
   `list_backup_dirs "${TK_UPDATE_HOME:-$HOME}"`. The library iterates
   `find "$home" -maxdepth 1 -type d \( -name '.claude-backup-*' … \)` and
   prints **absolute** paths (`scripts/lib/backup.sh:45-51`).
4. `update-claude.sh:343` checks
   `[[ "$d" != "$(dirname "$CLAUDE_DIR")"/.claude-backup-* ]]`. With
   `CLAUDE_DIR=".claude"`, `dirname` returns `.`, so the pattern is
   `./.claude-backup-*` — never matches an absolute path under `$HOME`.
5. The condition is true (path "doesn't match"); the script prints
   `Refusing to remove suspicious path: …` and bumps `rc=1` for every entry.

Verification:
```
$ CLAUDE_DIR=".claude"; d="/Users/test/.claude-backup-1700000000-100"
$ if [[ -z "$d" || "$d" == "/" || "$d" != "$(dirname "$CLAUDE_DIR")"/.claude-backup-* ]]; then
>     echo "REFUSE"; else echo "PROCEED"; fi
REFUSE
```
Verified live in `/tmp/audit-test-clean.sh` (executed during this audit).

Why tests miss it: every test sets `TK_UPDATE_HOME="$SCR"`. Then
`CLAUDE_DIR="$SCR/.claude"` → `dirname` returns `$SCR` (absolute). The pattern
`$SCR/.claude-backup-*` correctly matches `find $SCR …` results.

Fix:

```bash
# Resolve CLAUDE_DIR to an absolute path BEFORE building the pattern.
# Either use realpath/readlink, or compute the same parent that
# list_backup_dirs scans:
parent="${TK_UPDATE_HOME:-$HOME}"
if [[ -z "$d" || "$d" == "/" || "$d" != "$parent"/.claude-backup-* ]]; then
    echo -e "${RED}✗${NC} Refusing to remove suspicious path: ${d}" >&2
    rc=1
elif ! rm -rf "$d"; then
    …
fi
```

Add a regression test that runs `update-claude.sh --clean-backups --dry-run`
without `TK_UPDATE_HOME` (using a stubbed HOME) and asserts no "Refusing"
output appears against legitimate fixtures.

---

### S-HIGH-2 — Glob expansion in `--bridges` list parsing (filename-based RCE-adjacent)

- File:line: `scripts/lib/bridges.sh:147` and `scripts/install.sh` indirect via
  `_bridge_match` callers; `scripts/lib/bridges.sh:658` (FAIL_FAST loop)
- Severity: HIGH (confidence: 90%)
- Pattern: unquoted array assignment + IFS-driven word split inherits filename
  globbing.

Why exploitable: `--bridges` and `BRIDGES_FORCE` accept arbitrary user/CI input.
The `_bridge_match` helper word-splits the list with `IFS=','` then assigns to
an array WITHOUT disabling glob expansion:

```bash
IFS=','
local tokens=($list)        # ← unquoted: bash globs each element
```

If the cwd contains files matching the user's pattern, those filenames silently
become bridge target names. Concrete sequence:

1. User runs `update-claude.sh --bridges 'g*'` (or a CI provides
   `BRIDGES_FORCE=g*`) from a directory containing files `gemini`, `gnu`, etc.
2. `IFS=','`, `tokens=(g*)` → `tokens=(gemini gnu)`.
3. Each token passes the `[[ "$tok" == "$target" ]]` test against literal
   "gemini" or "codex" — `gnu` won't match either, so it's harmless **today**.
4. Future change adds a third bridge target (e.g. `cursor`); now `cu*` from a
   project directory containing `customer.md` could falsely match.
5. Worse: in the FAIL_FAST loop (lines 653-670), unknown tokens print a
   warning naming the **glob expansion** of the filename — information leak.

Verification (live test from this audit):

```
$ mkdir -p /tmp/glob-test && cd /tmp/glob-test && touch gemini codex something_else
$ bash -c 'list="gemini,co*"; IFS=","; arr=($list); echo "items: ${#arr[@]}";
> for t in "${arr[@]}"; do echo "[$t]"; done'
items: 2
[gemini]
[codex]
```

Same pattern in `scripts/install.sh:783-800` — uses `_bridge_match` directly,
inherits the glob from the helper. Same again at
`scripts/install.sh:803-820` for the FAIL_FAST warning loop.

Fix:

```bash
# Add `set -f` (or local `set +o noglob`/`set -o noglob`) before the array
# split, restore after. Bash 3.2 portable:
_bridge_match() {
    local target="$1" list="$2"
    [[ -z "$list" ]] && return 1
    local saved_ifs="$IFS"
    local saved_glob
    case "$-" in *f*) saved_glob=on ;; *) saved_glob=off ;; esac
    set -f
    IFS=','
    # shellcheck disable=SC2206
    local tokens=($list)
    IFS="$saved_ifs"
    [[ "$saved_glob" == "off" ]] && set +f
    …
}
```

Or simpler: use `read -ra tokens <<< "${list//,/$'\n'}"` to avoid both glob
and IFS pollution.

Apply same patch to the FAIL_FAST loop at `bridges.sh:658` and any future
caller of the helper.

---

### S-MED-1 — `release_lock` releases the wrong lock when bridges helper changes `LOCK_DIR`

- File:line: `scripts/lib/bridges.sh:217-218, 232-235`; trap interaction with
  `scripts/update-claude.sh:947`
- Severity: MED (confidence: 75%)
- Pattern: shared mutable global (`LOCK_DIR`) + EXIT trap that reads it
  unconditionally.

Why exploitable: rare, but reproducible under specific test seam combinations.
Trace:

1. `update-claude.sh:174-176` sets `STATE_FILE` and `LOCK_DIR` to the per-project
   path.
2. `update-claude.sh:947` registers `trap 'release_lock; rm -f …' EXIT`.
3. `update-claude.sh:948` `acquire_lock` succeeds — parent now holds
   `$CLAUDE_DIR/.toolkit-install.lock`.
4. Some downstream code (e.g. bridge sync flow) calls
   `_bridge_write_state_entry`, which:
   - saves `saved_lock_dir="${LOCK_DIR:-}"` (line 217)
   - reassigns `LOCK_DIR="$(_bridge_lock_dir)"` (line 218) — different path under
     a `TK_BRIDGE_HOME` test seam OR when state lives in a separate per-project
     scope.
   - If the parent's PID does NOT match the bridge lock's PID file (the parent
     never acquired the bridge lock), the helper calls a fresh `acquire_lock`
     under the bridge `LOCK_DIR`.
5. SIGINT (Ctrl-C) fires HERE — between `acquire_lock` for bridge and
   `release_lock` at the bottom of the helper.
6. The EXIT trap from `update-claude.sh:947` runs `release_lock`, which reads
   the **current** `LOCK_DIR` (the bridge path). It releases the bridge lock,
   never the parent's `$CLAUDE_DIR/.toolkit-install.lock`.
7. Parent lock is leaked until reclaimed by the 3600s ceiling at
   `state.sh:231`.

Why this matters: the leaked lock blocks all subsequent toolkit
install/update/uninstall in that project for up to an hour, with a yellow
warning about a "stale lock from PID … recent". Combined with `kill -0` PID
liveness checks, if the user's PID is rapidly reassigned the lock could be
held longer.

Fix: have `_bridge_write_state_entry` snapshot the current parent
`LOCK_DIR` before mutation and restore it INSIDE its own RETURN/EXIT-scoped
trap so a SIGINT mid-helper does not leave the global pointing at the
helper's value:

```bash
_bridge_write_state_entry() {
    …
    local saved_lock_dir="${LOCK_DIR:-}"
    # shellcheck disable=SC2064
    trap "LOCK_DIR=$(printf '%q' "$saved_lock_dir")" RETURN
    LOCK_DIR="$(_bridge_lock_dir)"
    …
}
```

Or, more robust, make `release_lock` accept a `LOCK_DIR` argument so the
parent's EXIT trap can call `release_lock "$PARENT_LOCK_DIR"` explicitly.

---

### S-MED-2 — `init-local.sh` registers `release_lock` trap AFTER acquire_lock

- File:line: `scripts/init-local.sh:329-330`
- Severity: MED (confidence: 95%)
- Pattern: trap-after-resource-acquired (canonical SIGINT-leak shape).

Why exploitable: SIGINT in the 1-instruction window between
`acquire_lock || exit 1` (line 329) and `trap 'release_lock' EXIT` (line 330)
leaves the lock dir on disk with this PID's pidfile. Subsequent toolkit
operations in the same project then need to wait the 60s+kill-0 stale-reclaim
or the 3600s hard ceiling.

Compare with the correct ordering:
- `scripts/uninstall.sh:108` registers trap BEFORE acquire_lock at line 620.
- `scripts/migrate-to-complement.sh:82` registers trap BEFORE acquire_lock at
  line 369.
- `scripts/init-claude.sh:133` registers EXIT trap at top; lock release is
  guarded by `NEED_LOCK_RELEASE` flag flipped right after `acquire_lock` at
  line 538-539. Same race in 1-instruction window but documented (line
  121-123 in init-claude.sh).

Past sweep lesson "Pattern propagation requires a sweep, not a fix" applies —
init-local.sh was never updated when the others were.

Fix:

```bash
# Register trap BEFORE acquiring the lock (matches uninstall.sh:108).
trap 'release_lock 2>/dev/null || true' EXIT
acquire_lock || exit 1
```

The `2>/dev/null || true` guard is needed because state.sh might not be
sourced if a different lock-source path is taken.

Also recommend: same hardening for init-claude.sh's `NEED_LOCK_RELEASE`
window (line 538-539). Because EXIT trap is already installed but the flag
gates `release_lock` from running, a SIGINT after acquire_lock but before
the flag flip leaks the lock in exactly the same way.

---

### S-MED-3 — TUI `eval`-restored parent EXIT trap can drop parent cleanup on signal

- File:line: `scripts/lib/tui.sh:201-205, 263-268`
- Severity: MED (confidence: 70%)
- Pattern: TUI replaces parent trap, restores via `eval` only on normal
  return. SIGINT/SIGTERM flow is correct but the EXIT path between TUI
  cleanup and trap restoration is racy.

Why exploitable: limited. Under standard SIGINT during `_tui_read_key`'s
blocking `read`, bash returns from the read non-zero, the loop breaks,
`_tui_restore` runs, and the parent trap is `eval`-restored. So the
documented path is fine.

The concern is on SIGTERM (or any signal where bash is configured to exit
without unwinding back to the eval-restore line). The trap on line 205
fires `_tui_restore` and then bash exits. Line 263-268 (the
`_parent_exit_trap` re-install) NEVER runs. Result: parent's
`run_cleanup` (in install.sh:127) is skipped — tmpfiles leaked, lock
unreleased.

The current fallback (parent's INT/TERM trap is also overridden by the
TUI's `trap '_tui_restore' INT TERM`) means even the parent's INT/TERM
handlers are silenced for the duration of the menu.

Fix: install TUI traps as ADD-ONS rather than replacements:

```bash
# Compose with parent traps instead of replacing them.
local _parent_exit_trap
_parent_exit_trap=$(trap -p EXIT 2>/dev/null || echo "")
local _parent_int_trap
_parent_int_trap=$(trap -p INT 2>/dev/null || echo "")
local _parent_term_trap
_parent_term_trap=$(trap -p TERM 2>/dev/null || echo "")

trap '_tui_restore || true; '"${_parent_exit_trap#trap -- *}"' EXIT
…
```

Or simpler: make the TUI's `_tui_restore` idempotent and have the parent's
`run_cleanup` call `_tui_restore` itself before unrelated cleanup.

---

### S-MED-4 — `setup-security.sh` writes raw curl output via `echo` with no
flag-prefix protection

- File:line: `scripts/setup-security.sh:166`
- Severity: MED (confidence: 70%)
- Pattern: `echo "$VAR"` where `$VAR` may begin with `-e`/`-n`/`-E` if the
  upstream template ever changes shape.

Why exploitable: today, `templates/global/CLAUDE.md` begins with `# Global
Security Rules` (verified via `head -3`). Bash builtin `echo` is also
immune to these flags by default. So today this is benign.

But: the script is `#!/bin/bash`. If a developer ever runs it under `sh`
(some Linux distros symlink sh→dash) **or** the upstream template begins
with `-e` (e.g. a future audit/lint header line `-e "..."`), the leading
flag gets parsed. Result is silent corruption of `~/.claude/CLAUDE.md`.

Fix: use `printf` with explicit format to defeat any leading-dash parsing.
This is the canonical pattern used elsewhere in the same file
(setup-security.sh:197 uses `printf '%s\n' "$SECURITY_CONTENT"`):

```bash
# scripts/setup-security.sh:166
printf '%s\n' "$SECURITY_CONTENT" > "$CLAUDE_MD"
```

Same one-line patch on line 175 (where SECURITY_CONTENT is appended via
`{ ; echo "$SECURITY_CONTENT"; } >> "$CLAUDE_MD"`).

---

### S-LOW-1 — `is_statusline_installed` matches `"statusLine"` substring inside any JSON value

- File:line: `scripts/lib/detect2.sh:123`
- Severity: LOW (confidence: 80%)
- Pattern: `grep -q '"statusLine"' settings.json` matches comments,
  description fields, or `"statusLine_disabled"` keys.

Why exploitable: false-positive detection. A user who has disabled their
statusline by renaming the key to `_disabled_statusLine` or who has a
description field containing the literal string `"statusLine"` reports
"installed" when it is not. Defensible from the safety-rule audit M5
elsewhere — the same pattern was rejected in `setup-security.sh:316-340`
in favor of python+json walking.

Fix: pattern-match the full key shape via grep -E or python+json:

```bash
is_statusline_installed() {
    [[ -f "$HOME/.claude/statusline.sh" ]] || return 1
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json,sys
try:
    c=json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
sys.exit(0 if "statusLine" in c else 1)' "$HOME/.claude/settings.json" 2>/dev/null
    else
        grep -qE '"statusLine"[[:space:]]*:' "$HOME/.claude/settings.json" 2>/dev/null
    fi
}
```

---

### S-LOW-2 — `propagate-audit-pipeline-v42.sh` tempfile leak on script-abort path

- File:line: `scripts/propagate-audit-pipeline-v42.sh:298, 305, 347`
- Severity: LOW (confidence: 80%)
- Pattern: trap on INT/TERM only — does not cover the `set -e` exit path.

Why exploitable: the file uses `set -euo pipefail`. Inside `insert_blocks()`,
`mktemp` succeeds (line 298), then `write_spliced_file` is called (line 347).
If `write_spliced_file` returns non-zero, bash propagates the failure,
the script exits — and the trap registered at line 305 only fires on
INT/TERM. Tempfile is leaked into the parent dir (`mktemp "${f}.XXXXXX"`).

Mitigation effort: low — script is developer-only (CHANGELOG-driven prompt
splice). But the leaked tempfile sits next to `$f` (a prompt source file)
with the random suffix, so a user running `git status` afterwards sees
unrelated files staged for review.

Fix: replace INT/TERM trap with EXIT-scoped + explicit cleanup:

```bash
insert_blocks() {
    local f="$1"
    local tmp
    tmp=$(mktemp "${f}.XXXXXX")
    local _quoted_tmp
    _quoted_tmp=$(printf '%q' "$tmp")
    # shellcheck disable=SC2064
    trap "rm -f $_quoted_tmp" RETURN  # fires on every function exit path
    …
    mv "$tmp" "$f"
    trap - RETURN  # explicit clear after successful mv
}
```

---

### S-LOW-3 — Backups created in PWD invisible to `--clean-backups`

- File:line: `scripts/update-claude.sh:950` vs `scripts/lib/backup.sh:45`
- Severity: LOW (confidence: 95%)
- Pattern: backup directory created relative to PWD (via `dirname
  ".claude"` = `.`), but `list_backup_dirs` only scans `$HOME` (or
  `TK_UPDATE_HOME`).

Why exploitable: not a security bug — operational. Trace:

1. `update-claude.sh:950`:
   `BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-$(date)..."`
2. With `CLAUDE_DIR=".claude"` (line 82, never reassigned in production),
   this is `./.claude-backup-…`, written to `$PWD`.
3. `list_backup_dirs "${TK_UPDATE_HOME:-$HOME}"` only scans `$HOME`.
4. So backups created by `update-claude.sh` from a project subdir
   (typical run) are invisible to `--clean-backups`.

This compounds with S-HIGH-1: even if the user works around the `dirname`
matching bug, project-local backups under `~/projects/foo/` are still
invisible to `list_backup_dirs` because `find $HOME -maxdepth 1` does not
recurse into `~/projects/`.

Fix: align the two paths. Either:
- Force `BACKUP_DIR` to live under `$HOME` (consistent with
  `uninstall.sh:627` which uses `$(dirname "$CLAUDE_DIR")/.claude-backup-…`
  but with CLAUDE_DIR= "$(pwd)/.claude" so the parent is the project root —
  same problem, opposite direction).
- Extend `list_backup_dirs` to also scan PWD's parent.
- Maintain a backup index file (`~/.claude/backups.list`) appended to on
  every backup creation — single source of truth.

---

### S-LOW-4 — `setup-security.sh` curl response stored in shell variable can be very large

- File:line: `scripts/setup-security.sh:159`
- Severity: LOW (confidence: 75%)
- Pattern: `SECURITY_CONTENT=$(curl …)` with no `--max-filesize`.

Why exploitable: defensive only. If an upstream RTK / mirror serves a multi-MB
HTML 502/503 page (or a fork mirror returns a binary), `SECURITY_CONTENT`
inflates RAM and the subsequent `echo "$SECURITY_CONTENT" > "$CLAUDE_MD"`
silently writes the bogus content into the user's global CLAUDE.md.

The `curl -sSLf` already handles HTTP errors (non-2xx → exit 22), but a
2xx with HTML body bypasses that.

Fix:

```bash
# Either size-cap the download:
SECURITY_CONTENT=$(curl -sSLf -A "$TK_USER_AGENT" --max-filesize 1048576 \
    "$REPO_URL/templates/global/CLAUDE.md" 2>/dev/null)

# Or hash-pin to a known-good SHA256 (project policy recommends this for
# external installer fetch already — see lib/bootstrap.sh:72-103
# TK_GSD_PIN_SHA256 pattern):
EXPECTED_SHA256="..."
ACTUAL=$(printf '%s' "$SECURITY_CONTENT" | shasum -a 256 | awk '{print $1}')
[[ "$ACTUAL" == "$EXPECTED_SHA256" ]] || { echo "...mismatch..."; exit 1; }
```

Pinning is too aggressive given upstream evolves; size cap + content-type
sniff is the pragmatic fix.

---

## Past-fix regression check

| Past ID | Status | Evidence |
| --- | --- | --- |
| H1 (install dispatch index mismatch, name-based lookup) | still fixed | `scripts/install.sh:865-873` `_local_label_to_dispatch_name` map present; loop at 875 derives dispatch name from TUI label |
| H3 (setup-security.sh RTK.md curl-pipe detection) | still fixed | `scripts/setup-security.sh:91-143` `install_rtk_notes` falls through to remote download when local sibling absent (curl|bash case) |
| H4 (read -rs for API keys, 3 sites) | still fixed | `scripts/setup-council.sh:160,214,239` all use `read -rs -p` for API keys; `scripts/lib/mcp.sh:417` uses `read -rsp` for env_key prompt |
| H5 (TK_TOOLKIT_REF env-var pinning) | still fixed | All entry points read `TK_TOOLKIT_REF`: init-claude.sh:21, uninstall.sh:81, setup-security.sh:50, update-claude.sh:77 |
| H6 (TK_DISPATCH_OVERRIDE_* gated on TK_TEST=1) | still fixed | dispatch.sh:125,162,199,242,280,317 gate every override with `&& "${TK_TEST:-0}" == "1"`; bootstrap.sh:121 same |
| M1 (install.sh:837 undefined log_error) | still fixed | install.sh:847-849 uses inline `echo -e "${RED}Error:${NC} …" >&2` (no log_error reference) |
| M2 (uninstall MODIFIED→REMOVE on empty installed-sha) | still fixed | uninstall.sh:265-267 `[[ -z "$recorded" ]]` returns REMOVE |
| M3 (trap quoting via printf %q) | still fixed | propagate-audit-pipeline-v42.sh:127-128, setup-security.sh:128, lib/bootstrap.sh:77, lib/bridges.sh:526, uninstall.sh:327 all use `printf '%q'` for trap paths |
| M4 (install.sh empty-array Bash 3.2 ${arr[@]+…} ) | still fixed | install.sh:204,247,261,322,372,374 etc. all use `${arr[@]+"${arr[@]}"}` |
| M5 (setup-council.sh:512 read /dev/tty || true) | still fixed | setup-council.sh:518 `read -r CD_ANSWER < /dev/tty 2>/dev/null \|\| true` |
| M6 (update-claude.sh mktemp paths in EXIT trap) | still fixed | update-claude.sh:944-947 — CLAUDE_MD_TMP, CMP_LOCAL_NORM, CMP_REMOTE_NORM declared empty so trap covers them |
| M7 (quality.yml concurrency cancel-in-progress) | still fixed | not re-verified; outside shell scope |
| M8 (statusline early-exit on non-Darwin) | still fixed | not re-verified in this audit |
| L1 (mcp_secrets_load key shape regex) | still fixed | mcp.sh:202 `[[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]` |
| L2 (predictable /tmp stderr names, 3 sites) | still fixed | install.sh:364,533,926 all use generic `tk-mcp.XXXXXX`/`tk-skill.XXXXXX`/`tk-install.XXXXXX` (no embedded component name) |
| L3 (skills.sh:147 root-recursive-delete guard) | still fixed | skills.sh:150-153 guards target against empty/`/`/`//` |
| L4 (curl browser User-Agent) | still fixed | every curl call across init-claude/install/uninstall/update/setup-security/setup-council uses `-A "$TK_USER_AGENT"` |
| L5 (brain.py ANSI sanitization) | still fixed | python file outside shell-audit scope |
| H2 (claimed "join with empty string" in mcp.sh) | confirmed FP | xxd of `scripts/lib/mcp.sh` line 85 shows byte `1f` (US, ASCII 31) at offset 0x52 inside `join("…")`. The `\x1f` separator IS present; Read tool only renders it as invisible whitespace. Lessons-learned #1 holds. |

## Skipped / FP

| Suspected | Why FP | Evidence |
| --- | --- | --- |
| `release_lock` releases the wrong PID's lock during `acquire_lock` stale-reclaim | Already fixed (audit H1 fix at state.sh:248-260 compares pid file against `$$` before rm-rf). Confirmed by reading scripts/lib/state.sh:253-258 |
| `dispatch.sh:298 brew install rtk && rtk init -g` not capturing brew failure | `&&` short-circuits on brew failure; rtk-init never runs; function returns brew's exit code via `set -e` style propagation. Tested mentally with set -e off (libs do not set it) — the `&&` makes the command-substitution chain exit non-zero correctly when consumed via subshell capture in install.sh:955. |
| TUI `eval "$_parent_exit_trap"` could inject arbitrary code | The string comes from `trap -p` which is bash's own quoting output. Untrusted only if a different shell or LD_PRELOAD overrides bash builtins — out of threat model. |
| `acquire_lock` race when two processes mkdir LOCK_DIR simultaneously | mkdir is atomic on POSIX (returns EEXIST). Only one process wins. Verified by reading state.sh:168 `while ! mkdir "$LOCK_DIR" 2>/dev/null` — the loser stays in the loop. |
| `_bridge_match` token comparison with whitespace-only token | Empty `tok` after trim won't equal "gemini" or "codex" so falls through correctly. Verified by reading bridges.sh:152-154 trim + 154 == comparison. |
| `mcp_wizard_run` arg array reconstruction with `\037` separator | `\037` byte is verified present (`xxd` of mcp.sh:85 shows `1f` at offset 0x52). Lessons-learned point #1 (verify-with-xxd) explicitly covers this. |
| `setup-security.sh:166 echo "$SECURITY_CONTENT"` interprets backslash escapes | Bash builtin `echo` does NOT interpret `\n` etc. unless `-e` is passed. The leading-dash flag-injection concern is captured separately as S-MED-4. The escape-interpretation risk doesn't apply to bash. |
| `update-claude.sh:343` pattern test could allow `$d=/.claude-backup-*` literally to bypass | The `[[ != ]]` operator with unquoted RHS does pattern-matching, but on the LITERAL `/` prefix the pattern `./.claude-backup-*` rejects it. Path with `/` cannot match a pattern starting with `.`. Verified live during S-HIGH-1 trace. |

---

_Audited by: deep-bash-shell-audit, 2026-04-30. Sweep follows `.claude/rules/lessons-learned.md`._
