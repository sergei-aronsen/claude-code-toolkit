# Shell Script Audit — `scripts/` (recursive)

**Date:** 2026-04-30
**Scope:** All `*.sh` under `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/`
**Tooling:** `shellcheck 0.11.0 -S style -x`. `shfmt` not installed (skipped).

## Numbers

- **Total scripts:** 77 (15 top-level, 14 `lib/`, 48 `tests/`)
- **Total shellcheck findings (severity=style/info):** 61
  - SC2015 (`A && B || C` not if-else): 16 — mostly **false positives** (callers want short-circuit)
  - SC2004 (`$/${} unnecessary in arith`): 14 — pure style, no impact
  - SC2059 (printf format with vars): 10 — color-prefixed test output, **acceptable**
  - SC2016 (single-quote interp): 8 — most are intentional (literal backticks in markdown grep)
  - SC2329 (function never invoked): 7 — exported-for-source helpers, **false positive**
  - SC1091 (`source` not followed): 4 — local-clone resolution, **false positive**
  - SC1003 (escape single quote): 2 — intentional literal `'`
- **Severity=warning (CI gate):** 0 findings → CI green
- **Real bugs found via manual review:** 7 (1 High, 4 Medium, 2 Low)

## Verified-clean checks

- All scripts have `set -euo pipefail` (top-level executables) or deliberately omit it (sourced libraries — correct: `set -e` in a library would corrupt the caller's error mode).
- Shebangs split: top-level installers use `#!/bin/bash`; tests + `cell-parity.sh` + `validate-release.sh` use `#!/usr/bin/env bash`. Both safe; project CLAUDE.md prefers `#!/bin/bash` but neither breaks portability.
- `mktemp` always uses templates with `XXXXXX` (no predictable-path bare invocations) — **except** `update-claude.sh:1129, 1211, 1212` (see M2).
- BSD/GNU portability handled: `lib/state.sh:25-28` and `verify-install.sh:286-288` branch on `uname` for `stat -f`/`-c`. No GNU-only `grep -P`, `sed -i ''`, `find -regex`, `date -d`, `head --bytes`.
- `cd` always inside `cd "$X" && pwd` command-substitutions or guarded with `&&`.
- `local var=$(cmd)` exit-code masking: not present (only arithmetic locals).
- `< /dev/tty` consistently used for `read -p` so `curl|bash` works — **except** `setup-council.sh:512` (see M3).
- File descriptor leaks: no `exec N<` opens that aren't paired.
- `eval` is gated on `TK_TEST=1` in `lib/dispatch.sh` and `lib/bootstrap.sh` (audit C2 closure preserved). `lib/dry-run-output.sh:52` uses eval for indirect expansion (Bash 3.2 limitation, value source is internal — safe). `lib/tui.sh:264` evals previously-saved trap (safe within trust boundary).
- `rm -rf "$LOCK_DIR"` in `lib/state.sh` is guarded by `[[ -n "$LOCK_DIR" && "$LOCK_DIR" != "/" ]]` everywhere (216, 233, 258).

---

## Findings

### H1 — Unconditional code-execution from `TK_DISPATCH_OVERRIDE_*` env vars

- **shellcheck code:** manual / category: privilege escalation via env
- **Severity:** High
- **File:lines:** `scripts/lib/dispatch.sh:112-117, 148-153, 184-?, 226-231, 263-268, 299-304`

```bash
if [[ -n "${TK_DISPATCH_OVERRIDE_SUPERPOWERS:-}" ]]; then
    ...
    bash "$TK_DISPATCH_OVERRIDE_SUPERPOWERS"   # ← executes any path from env
    return $?
fi
```

- **Why exploitable:** Audit C2 (Sept) hardened `eval "$TK_SP_INSTALL_CMD"` so it now requires `TK_TEST=1`. The `TK_DISPATCH_OVERRIDE_*` family — documented in the same comment block as a "test seam" — was **not** gated. Six dispatchers honor it unconditionally: `_SUPERPOWERS`, `_GSD`, `_TOOLKIT`, `_SECURITY`, `_RTK`, `_STATUSLINE`. Threat model: an attacker who controls the env *before* the user runs `bash <(curl ...)` (e.g. compromised shell rc, malicious `.envrc` autoloaded by direnv, hijacked CI variable) sets `TK_DISPATCH_OVERRIDE_SUPERPOWERS=/tmp/payload.sh` and the install runs payload as the user. Same threat shape as the C2 finding — just a different code path.
- **False-positive note:** Real. The hardened eval and the unhardened `bash $path` both deserve the same `TK_TEST=1` gate.
- **Fix:**

```bash
if [[ "${TK_TEST:-0}" == "1" && -n "${TK_DISPATCH_OVERRIDE_SUPERPOWERS:-}" ]]; then
    ...
fi
```

  Apply to all six override branches.

---

### M1 — Trap with single-quoted `$var` interpolation regresses audit M6

- **shellcheck code:** SC2064 (suppressed)
- **Severity:** Medium
- **File:lines:** `scripts/propagate-audit-pipeline-v42.sh:300`, `scripts/lib/bootstrap.sh:67`

```bash
# propagate-audit-pipeline-v42.sh:300
trap "rm -f '$tmp'" INT TERM
# lib/bootstrap.sh:67
trap "rm -f '$tmp'" RETURN
```

- **Why exploitable:** Audit M6 fixed the same pattern in `propagate-audit-pipeline-v42.sh:128` (now uses `printf '%q'`). Two siblings remain. If `TMPDIR` contains a literal `'` (rare on macOS, possible on user-customized systems), the trap registration fails with a syntax error → tempfile leaks. **Same file even has the fixed pattern at line 128 — clear inconsistency**.
- **Fix:** Match `update-claude.sh:1073` and `propagate-audit-pipeline-v42.sh:128`:

```bash
local _quoted_tmp; _quoted_tmp=$(printf '%q' "$tmp")
trap "rm -f $_quoted_tmp" RETURN
```

---

### M2 — `mktemp` without template + missing trap registration in `update-claude.sh`

- **Severity:** Medium
- **File:lines:** `scripts/update-claude.sh:1129, 1211, 1212`

```bash
CLAUDE_MD_TMP=$(mktemp)              # 1129 — bare mktemp, no template
...
CMP_LOCAL_NORM=$(mktemp)             # 1211
CMP_REMOTE_NORM=$(mktemp)            # 1212
```

- **Why it breaks:** (a) Inconsistent with the project's hardened pattern (every other `mktemp` in this script uses `"${TMPDIR:-/tmp}/<purpose>.XXXXXX"`). On macOS BSD bare `mktemp` produces `/tmp/tmp.XXXXXXXXXXX` — works but unidentifiable in a leak. (b) None of these three are added to the global EXIT-trap cleanup list at line 935. If `cmp -s` or `normalize_md` is killed mid-run, the temp files leak. Lines 1141, 1147, 1220 do clean up on the happy paths, but error paths (set -e abort) leak.
- **Fix:** `CLAUDE_MD_TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md.XXXXXX")` and append to the trap variable list (or extend the trap to include them).

---

### M3 — `read … < /dev/tty` without `2>/dev/null || true` aborts under `set -e`

- **Severity:** Medium
- **File:line:** `scripts/setup-council.sh:512`

```bash
printf "  Register Council as MCP server in Claude Desktop? [y/N]: "
read -r CD_ANSWER < /dev/tty
```

- **Why it breaks:** Top of file sets `set -euo pipefail`. If `/dev/tty` is unavailable (script piped from `curl|bash` *and* stdin is closed, or container without a controlling terminal), `read` returns non-zero → `set -e` kills the entire installer with no friendly message. Every other `read … < /dev/tty` in the codebase uses the `2>/dev/null` and either `|| true` or `if !` guard. Same script line 143, 188 do it correctly; line 512 is the lone exception.
- **Fix:**

```bash
read -r CD_ANSWER < /dev/tty 2>/dev/null || CD_ANSWER="N"
```

---

### M4 — Empty-array expansion under `set -u` on Bash 3.2 (macOS default)

- **shellcheck code:** SC2086-adjacent (no rule, but Bash 3.2 quirk)
- **Severity:** Medium
- **File:lines:** `scripts/install.sh:917, 920`

```bash
local_flags=()
[[ "$FORCE" -eq 1 ]]   && local_flags+=("--force")
[[ "$DRY_RUN" -eq 1 ]] && local_flags+=("--dry-run")
[[ "$YES" -eq 1 ]]     && local_flags+=("--yes")
...
( "dispatch_${local_name}" "${local_flags[@]}" ) 2>"$stderr_tmp"   # 917
"dispatch_${local_name}" "${local_flags[@]}"                        # 920
```

- **Why it breaks:** When the user invokes `install.sh` with no flags, `local_flags` stays empty. On Bash 3.2 (default macOS shell — explicit project target per CLAUDE.md), `"${arr[@]}"` of an empty array under `set -u` raises *"local_flags[@]: unbound variable"* and aborts. The same file *already* uses the safe form at lines 363, 365, 531, 533: `"${local_flags[@]+"${local_flags[@]}"}"`. Lines 917 and 920 regressed to the unguarded form.
- **Fix:** `( "dispatch_${local_name}" "${local_flags[@]+"${local_flags[@]}"}" ) 2>"$stderr_tmp"` — match the pattern already used elsewhere in the same file.

---

### L1 — `curl` without User-Agent (project rule violation)

- **Severity:** Low
- **Files:** All curl-using scripts (`init-claude.sh`, `init-local.sh`, `update-claude.sh`, `setup-security.sh`, `setup-council.sh`, `install.sh`, `lib/bootstrap.sh`, `lib/bridges.sh`, …)
- **Why it matters:** The project's global rule (CLAUDE.md §2) explicitly says *"Always set a real browser User-Agent for outgoing HTTP requests — never use default library UA"*. Every `curl -sSLf …` here ships as `curl/X.Y.Z`. GitHub raw doesn't reject this UA, so functionally fine — but it's a stated rule that's universally violated. It also makes installer traffic trivially fingerprintable in any intermediate proxy/WAF.
- **Fix:** Either define a wrapper helper in `lib/install.sh` (or top of each installer):

```bash
TK_UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
_tk_curl() { curl -A "$TK_UA" "$@"; }
```

  …or document an explicit exemption from the rule for installer scripts.

---

### L2 — `lib/skills.sh:147` `rm -rf "$target"` lacks defensive guard

- **Severity:** Low
- **File:line:** `scripts/lib/skills.sh:138-147`

```bash
target="${home}/${name}"
...
if [[ -d "$target" && "$force" -eq 1 ]]; then
    rm -rf "$target" || return 1
fi
```

- **Why it could break:** `name` is checked for empty (line 130) but **not for path traversal**. `home` comes from `${TK_SKILLS_HOME:-$HOME/.claude/skills}` — if `HOME` is unset and `TK_SKILLS_HOME` is unset, `home` becomes `/.claude/skills`. The `SKILLS_CATALOG` array is hardcoded so user input isn't currently a vector, but the function takes `$1` directly and any future caller that passes user input gets an `rm -rf` with no defense. Mirrors the defensive pattern already used in `lib/state.sh:216` (`[[ -n "$LOCK_DIR" && "$LOCK_DIR" != "/" ]]`).
- **Fix:**

```bash
[[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "skills_install: bad name" >&2; return 1; }
[[ -n "$target" && "$target" != "/" && "$target" == "$home"/* ]] || return 1
rm -rf "$target" || return 1
```

---

## Severity counts

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 1 |
| Medium   | 4 |
| Low      | 2 |
| **Total real bugs** | **7** |

Shellcheck total raw findings: **61**. After FP filtering (SC2329 sourced helpers, SC1091 dynamic source paths, SC2059 colorized test prints, SC2015 intentional short-circuits, SC2016 literal-backtick greps): **0 actionable shellcheck findings**. CI's warning-severity gate stays clean.

## Top 5 real bugs (priority order)

1. **H1 — TK_DISPATCH_OVERRIDE_* unconditional bash exec** (`lib/dispatch.sh` x6) — RCE class, same shape as the already-hardened C2 eval. Gate behind `TK_TEST=1`.
2. **M1 — Trap with `'$tmp'` regresses audit M6** (`propagate-audit-pipeline-v42.sh:300`, `lib/bootstrap.sh:67`) — leaks tempfiles when TMPDIR contains `'`.
3. **M4 — Empty-array `"${local_flags[@]}"` aborts on Bash 3.2** (`install.sh:917, 920`) — flagless install crashes on stock macOS shell. Project explicitly targets Bash 3.2+.
4. **M3 — `read < /dev/tty` aborts setup-council** (`setup-council.sh:512`) — the one prompt missing the `2>/dev/null` guard kills the whole script under `set -e` when no TTY.
5. **M2 — Bare `mktemp` + missing trap entry in update-claude** (`update-claude.sh:1129, 1211, 1212`) — three temp files leak on SIGINT mid-update; inconsistent with the rest of the file.
