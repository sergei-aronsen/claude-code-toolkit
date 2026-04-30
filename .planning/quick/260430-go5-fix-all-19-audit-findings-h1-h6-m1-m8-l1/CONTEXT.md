---
quick_id: 260430-go5
slug: fix-all-19-audit-findings
date: 2026-04-30
status: planning
branch: fix/audit-sweep-2026-04-30
---

# Audit Sweep — 19 findings

## Source reports

- `audit-security.md` — Security Auditor agent (1H, 1M, 2L, 1I after FP filter)
- `audit-bugs.md` — code-reviewer agent (3H, 4M, 4L)
- `audit-infra.md` — infra/CI agent (1H, 4M, 6L, 4I-positive)
- `audit-shell.md` — shell deep-dive agent (1H, 4M, 2L)

## Cross-referenced findings (deduplicated)

### HIGH (6)

**H1. install.sh dispatch loop installs wrong bridge**
- File: `scripts/install.sh:843-873, 897-910`
- Bug: `TK_DISPATCH_ORDER` (8 fixed entries) and `TUI_LABELS` (6-8 dynamic) indexed by same `$i`. With only Codex CLI (`IS_GEM=0, IS_COD=1`), TUI_LABELS[6]="codex-bridge" but TK_DISPATCH_ORDER[6]="gemini-bridge" → user gets Gemini bridge despite no Gemini CLI; codex bridge silently never installed. `--bridges codex` same fault.
- Fix: index TUI_LABELS via lookup against TK_DISPATCH_ORDER name, not by position. Or rebuild TUI_LABELS to match TK_DISPATCH_ORDER size with empty placeholders.

**H2. WITHDRAWN — false positive (verified 2026-04-30 against Gemini cross-check).**
- Original claim: `lib/mcp.sh:85` joins with empty string instead of `\037`.
- Verification: `xxd` of line 85 shows bytes `6a 6f 69 6e 28 22 1f 22 29` = `join("` + literal `\x1f` (ASCII 31 unit-separator) + `")`. Separator IS present; Read-tool renderer displayed US byte as nothing, fooling the audit agent.
- Source is correct. No fix needed. Sweep size: 18 findings, not 19.

**H3. setup-security.sh silently skips RTK.md under curl|bash**
- File: `scripts/setup-security.sh:87-105`
- Bug: `src_rtk="$(dirname "$0")/../templates/global/RTK.md"`. Under `bash <(curl ...)` `$0` = `bash`/`/dev/fd/N`, so `dirname` returns `.`/`/dev/fd`. File never exists. Logs "offline / partial install" and returns 0.
- Fix: when not on local checkout (detected via missing local repo), download RTK.md from raw.githubusercontent.com same as other files. Use existing helper pattern.

**H4. init-claude.sh API keys echoed to terminal scrollback**
- Files: `scripts/init-claude.sh:970, 1020, 1035`
- Bug: `read -r -p` (no `-s`) for Gemini/OpenAI/OpenRouter keys. Standalone `setup-council.sh` correct.
- Fix: add `-s` flag + trailing `echo` newline. Match setup-council.sh pattern.

**H5. Distribution chain pinned to mutable `main` (no checksum verify)**
- Files: `scripts/install.sh:34`, `init-claude.sh:18`, `update-claude.sh:76`, `setup-security.sh:49`, `setup-council.sh:19`, `install-statusline.sh:35`, `uninstall.sh:80`, `migrate-to-complement.sh:59`
- Bug: all 8 installers fetch from `raw.githubusercontent.com/.../main/...`. No `TK_TOOLKIT_REF` override, no checksum verify. `TK_GSD_PIN_SHA256` exists for GSD only (`scripts/lib/bootstrap.sh:63-95`).
- Fix: introduce `TK_TOOLKIT_REF` env var (default `main`, override accepts tag/sha). Document in README. Optional pin sha256 for advanced users following the GSD pattern.
- Scope note: this is a bigger lift. Implement `TK_TOOLKIT_REF` only in this sweep (defer optional pin sha256 to follow-up).

**H6. TK_DISPATCH_OVERRIDE_* env-bash without TK_TEST=1 gate**
- File: `scripts/lib/dispatch.sh:117, 153, 184, 231, 268, 304` (6 sites)
- Bug: all 6 dispatchers honor `bash $TK_DISPATCH_OVERRIDE_*` test seam without `TK_TEST=1` gate. Same RCE class as the recently-hardened C2 eval (commit 76fcc4c, f16a825).
- Fix: add `TK_TEST=1` gate to each override site, matching the eval gate pattern.

### MEDIUM (8)

**M1. install.sh:837 calls undefined log_error**
- File: `scripts/install.sh:837`
- Bug: TK_DISPATCH_ORDER alphabet validator calls `log_error`. Function does not exist anywhere in script tree. Under `set -euo pipefail`: validator failure crashes with exit 127 instead of clean reject.
- Fix: define `log_error()` locally OR replace call with inline `echo -e "${RED}Error:${NC} ..." >&2`.

**M2. uninstall.sh empty-sha → MODIFIED prompt for unhashable files**
- Files: `scripts/uninstall.sh:541-551`, `scripts/lib/state.sh:97-101`
- Bug: state.sh records `{"sha256": ""}` when file unreadable at install time. classify_file computes actual hash, compares against `""` → never equal → verdict MODIFIED → user prompted `[y/N/d]` for files toolkit owns and user never edited.
- Fix: in classify_file, treat empty installed-sha as "unknown" → return UNCHANGED (or new UNHASHABLE verdict). Skip prompt.

**M3. propagate-audit-pipeline-v42.sh:300 trap regression (also bootstrap.sh:67)**
- Files: `scripts/propagate-audit-pipeline-v42.sh:300`, `scripts/lib/bootstrap.sh:67`
- Bug: trap interpolates `'$tmp'` directly. Regression of audit M6 fix (commit 63b1fb5). Same file already has `printf '%q'` correct form at line 128.
- Fix: replace `trap 'rm -rf "$tmp"' EXIT` with `trap "rm -rf $(printf '%q' "$tmp")" EXIT` matching line 128 pattern.

**M4. install.sh:917, 920 empty-array Bash 3.2 unguarded**
- File: `scripts/install.sh:917, 920`
- Bug: `"${local_flags[@]}"` unguarded. Same file uses safe `"${arr[@]+"${arr[@]}"}"` at 363, 365, 531, 533. Bash 3.2 (macOS support floor) aborts under `set -u`.
- Fix: rewrite both expansions to safe form.

**M5. setup-council.sh:512 read < /dev/tty no `|| true`**
- File: `scripts/setup-council.sh:512`
- Bug: lone outlier — every other `read … < /dev/tty` in repo guards with `2>/dev/null` and `|| true`/`if !`. Under `set -e` with no TTY: kills installer.
- Fix: add guard pattern matching siblings.

**M6. update-claude.sh bare mktemp + missing EXIT-trap registration**
- File: `scripts/update-claude.sh:1129, 1211, 1212`
- Bug: 3 temp files use `mktemp` without templates and aren't in trap cleanup list at line 935. SIGINT mid-update leaks them.
- Fix: switch to `mktemp -t toolkit-update.XXXXXX` with explicit prefix; add to trap cleanup list at line 935.

**M7. quality.yml no concurrency cancel-in-progress group**
- File: `.github/workflows/quality.yml`
- Bug: every PR force-push spawns redundant 5-job runs. No `concurrency:` block.
- Fix: add `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }` at workflow level.

**M8. statusline.sh + rate-limit-probe.sh BSD-only `stat -f %m` no Darwin guard**
- Files: `templates/global/statusline.sh`, `templates/global/rate-limit-probe.sh`
- Bug: `stat -f %m` BSD-only. No `uname == Darwin` guard. Linux silently misbehaves. `scripts/lib/state.sh:24-29` has correct cross-platform pattern.
- Fix: copy state.sh pattern (uname-detect + GNU `stat -c %Y` fallback). Or short-circuit on non-Darwin (statusline is macOS-only by design — exit cleanly with informational message).

### LOW (5)

**L1. mcp_secrets_load keys not validated (only values)**
- File: `scripts/lib/mcp.sh:184-199`
- Fix: add key shape validation alongside value validation. Defense in depth.

**L2. /tmp predictable stderr names leak component name on shared Linux**
- File: `scripts/install.sh:355, 523, 892`
- Fix: use `mktemp` with random suffix, not predictable name including component.

**L3. lib/skills.sh:147 rm -rf $target no `/` guard**
- File: `scripts/lib/skills.sh:147`
- Fix: copy guard from `state.sh` — check `[[ "$target" != "/" && "$target" != "" ]]` before rm.

**L4. curl no browser User-Agent (project §2 rule violation)**
- Files: every script that uses `curl` (8+ scripts)
- Bug: project's own global rule §2 demands browser UA on outgoing requests. Repo-wide non-compliance.
- Fix: define `TK_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"` constant in `lib/bootstrap.sh` or new `lib/http.sh`. Add `-H "User-Agent: $TK_USER_AGENT"` to every `curl` call. Or wrap in `tk_curl()` helper.

**L5. brain.py reports include hostile LLM output without ANSI sanitization**
- File: `scripts/council/brain.py:2200, 2643`
- Fix: copy ANSI/control-char sanitization pattern from `update-claude.sh:1005-1008` before writing reviewer text to disk.

## Out of scope (deferred)

- I1: Council reviewer text ANSI sanitization in additional brain.py paths beyond 2200/2643 (handle in L5 if discovered).
- 4 info-positive items from infra audit (already correct, no action).

## Constraints

- Each finding = atomic commit (Conventional Commits)
- Branch: `fix/audit-sweep-2026-04-30`
- Bash 3.2+ POSIX compat (macOS support floor)
- Sourced libs: NO `set -euo pipefail`
- Executables: `set -euo pipefail` mandatory
- shellcheck `-S warning` clean post-fix
- markdownlint clean post-fix (run `make check`)
- All existing tests must pass post-fix (run `scripts/tests/test-*.sh`)
- New test coverage required for: H1 (dispatch index), H2 (mcp.sh join), M2 (uninstall classify_file), H6 (override gate)

## Order

Recommend executor sequence by file ownership for least merge friction:
1. H2 (mcp.sh) — single file, smallest blast radius, highest impact
2. H4, M3 (single-line fixes)
3. M1, M4, M5, M6, M7, M8 (file-local fixes)
4. H6 (dispatch.sh, 6 sites — single file)
5. L1, L2, L3, L5 (defense-in-depth)
6. H1 (install.sh — biggest refactor, dispatch index)
7. H3 (setup-security.sh + RTK.md download path)
8. L4 (curl UA — repo-wide sweep, last)
9. H5 (TK_TOOLKIT_REF env var — touches all 8 installers, last)
