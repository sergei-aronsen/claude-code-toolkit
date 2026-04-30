---
quick_id: 260430-go5
slug: fix-all-19-audit-findings
status: ready
branch: fix/audit-sweep-2026-04-30
total_tasks: 19
---

# PLAN — Audit Sweep (18 fixes + 1 dead-code commit)

Source: `CONTEXT.md` in this directory + `audit-{security,bugs,infra,shell}.md`.
H2 WITHDRAWN as false positive (literal `\x1f` byte already present at mcp.sh:85; Read-tool render fooled the audit agent).

## Conventions

- One commit per task, Conventional Commits style.
- `make check` must stay green after every commit (run before push).
- Bash 3.2+ POSIX compat. Sourced libs no `set -euo pipefail`. Executables yes.
- After each commit, run `bash scripts/tests/test-*.sh` for files touched.
- Reference the finding ID in commit subject: `fix(<scope>): <one-liner> (<ID>)`.

## Order (dependency-aware)

### Group A — single-line / single-file (fastest, lowest risk)

1. **T1 — Adopt dead-code cleanup (Gemini finding)** — `fix(test): remove unused sha256_any from test-uninstall-prompt.sh`
   - File: `scripts/tests/test-uninstall-prompt.sh:65-72` (already modified locally)
   - Action: `git add` + commit existing diff.
   - Verify: `bash scripts/tests/test-uninstall-prompt.sh` still passes.

2. **T2 — H4: API key echo to scrollback** — `fix(init-claude): use read -s for API keys (H4)`
   - File: `scripts/init-claude.sh:970, 1020, 1035`
   - Change all 3 `read -r -p "...key..." VAR < /dev/tty 2>/dev/null || true` to `read -rs -p "...key..." VAR < /dev/tty 2>/dev/null || true; echo`
   - Match the pattern from `scripts/setup-council.sh` (which already uses `-s`).
   - Verify: visual diff; manual `bash scripts/init-claude.sh --interactive` not feasible in CI but match siblings.

3. **T3 — M1: log_error undefined** — `fix(install): inline error message instead of undefined log_error (M1)`
   - File: `scripts/install.sh:837`
   - Replace `log_error "..."` with `echo -e "${RED}Error:${NC} TK_DISPATCH_ORDER contains invalid component name: ${_local_check_name@Q}" >&2`
   - Verify: `shellcheck scripts/install.sh` clean; `bash scripts/install.sh --dry-run` smoke.

4. **T4 — M3: trap regression in propagate-audit-pipeline-v42.sh:300 + bootstrap.sh:67** — `fix(scripts): printf %q quote tempfile paths in EXIT trap (M3)`
   - Files: `scripts/propagate-audit-pipeline-v42.sh:300`, `scripts/lib/bootstrap.sh:67`
   - Match the pattern from `propagate-audit-pipeline-v42.sh:128`: `trap "rm -rf $(printf '%q' "$tmp")" EXIT` (or equivalent).
   - Verify: `shellcheck` clean.

5. **T5 — M5: setup-council.sh:512 read /dev/tty no `|| true`** — `fix(setup-council): guard read /dev/tty against no-TTY abort (M5)`
   - File: `scripts/setup-council.sh:512`
   - Add `2>/dev/null` and `|| true` matching every other `read … < /dev/tty` in repo.
   - Verify: `shellcheck` clean.

6. **T6 — M7: quality.yml no concurrency cancel-in-progress** — `fix(ci): add concurrency cancel-in-progress group to quality workflow (M7)`
   - File: `.github/workflows/quality.yml`
   - Add at workflow level: `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`
   - Verify: YAML lint via `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"`.

7. **T7 — M8: BSD-only stat in statusline** — `fix(statusline): cross-platform mtime via state.sh pattern (M8)`
   - Files: `templates/global/statusline.sh`, `templates/global/rate-limit-probe.sh`
   - Strategy A (preferred — statusline is macOS-only by design): early-exit on non-Darwin with informative message.
   - Strategy B: copy uname-detect from `scripts/lib/state.sh:24-29` and add GNU `stat -c %Y` fallback.
   - Verify: `shellcheck` clean.

8. **T8 — L1: mcp_secrets_load keys not validated** — `fix(mcp): validate key shape alongside values (L1)`
   - File: `scripts/lib/mcp.sh:184-199`
   - Add key regex check `^[A-Z_][A-Z0-9_]*$` matching env-var conventions.
   - Verify: `bash scripts/tests/test-mcp-*.sh` passes (if exists).

9. **T9 — L2: predictable /tmp stderr names** — `fix(install): use mktemp for component stderr capture (L2)`
   - File: `scripts/install.sh:355, 523, 892`
   - Already uses `mktemp` at 892 — verify 355 and 523 match. May already be safe; if so, mark FP-after-verify and skip.

10. **T10 — L3: lib/skills.sh rm -rf no `/` guard** — `fix(skills): defensive guard against root-rm in skills helper (L3)`
    - File: `scripts/lib/skills.sh:147`
    - Add `[[ "$target" != "/" && -n "$target" ]]` precondition.

11. **T11 — L5: brain.py reports include unsanitized LLM output** — `fix(council): sanitize ANSI/control chars in saved reports (L5)`
    - File: `scripts/council/brain.py:2200, 2643`
    - Copy sanitization from `update-claude.sh:1005-1008`. Python: `re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)` plus control-char strip.

### Group B — multi-site within one file (medium scope)

12. **T12 — H6: TK_DISPATCH_OVERRIDE_* gate** — `fix(dispatch): gate TK_DISPATCH_OVERRIDE_* with TK_TEST=1 (H6)`
    - File: `scripts/lib/dispatch.sh:117, 153, 184, 231, 268, 304` (6 sites)
    - Wrap each `bash "$TK_DISPATCH_OVERRIDE_*"` in `if [[ "${TK_TEST:-0}" == "1" ]]; then bash "$..."; else _dispatch_run_*_default; fi`
    - Match the eval-gate pattern at lines 127-131 (already gated).
    - Verify: `shellcheck` clean; `bash scripts/tests/test-dispatch*.sh` (if exists).

13. **T13 — M2: uninstall MODIFIED on empty installed-sha** — `fix(uninstall): treat empty installed-sha as UNHASHABLE not MODIFIED (M2)`
    - Files: `scripts/uninstall.sh:541-551`, `scripts/lib/state.sh:97-101`
    - In `classify_file`: if installed-sha is empty, return UNCHANGED (or new UNHASHABLE verdict that auto-cleans without prompt).
    - Verify: `bash scripts/tests/test-uninstall-state-cleanup.sh` and related uninstall tests pass.

14. **T14 — M4: install.sh empty-array Bash 3.2** — `fix(install): guard empty local_flags expansion for Bash 3.2 (M4)`
    - File: `scripts/install.sh:917, 920`
    - Replace `"${local_flags[@]}"` with `"${local_flags[@]+"${local_flags[@]}"}"` matching siblings 363/365/531/533.
    - Verify: `shellcheck` clean.

15. **T15 — M6: update-claude.sh bare mktemp not in trap** — `fix(update): register orphaned mktemp paths to EXIT trap (M6)`
    - File: `scripts/update-claude.sh:1129, 1211, 1212`
    - Either (a) switch to `mktemp -t toolkit-update.XXXXXX` and add to existing CLEANUP_PATHS at line 935, OR (b) add explicit per-tmp trap fragment matching the patterns elsewhere in the file.
    - Verify: `shellcheck` clean; `bash scripts/tests/test-update-libs.sh` passes.

### Group C — single-file refactor (higher scope)

16. **T16 — H1: install.sh dispatch index mismatch** — `fix(install): map dispatch by name not index (H1)`
    - File: `scripts/install.sh:843-873, 897-910`
    - Strategy: replace `local_name="${TK_DISPATCH_ORDER[$i]}"` with name-based lookup. Iterate over TUI_LABELS (which is what was selected) and call `dispatch_${TUI_LABELS[$i]}` directly. Bridge labels (`gemini-bridge`/`codex-bridge`) need the name extraction logic preserved.
    - Add regression test: feed `IS_GEM=0 IS_COD=1` scenario, assert codex bridge invoked, gemini bridge NOT invoked.
    - Verify: `shellcheck` clean; new test passes; existing `bash scripts/tests/test-bridges-install-ux.sh` passes.

17. **T17 — H3: setup-security.sh RTK.md curl|bash** — `fix(setup-security): download RTK.md via curl when not local (H3)`
    - File: `scripts/setup-security.sh:87-105`
    - Detect curl|bash mode (e.g., `[[ "${BASH_SOURCE[0]:-}" == /dev/fd/* || "${0:-}" == bash ]]`) — pattern exists in `scripts/lib/dispatch.sh:_dispatch_is_curl_pipe`.
    - When curl|bash: download via `_tk_curl_safe "$REPO_URL/templates/global/RTK.md" -o "$tmp"` then `cp` to dest.
    - Else: existing local-path behavior.
    - Verify: `shellcheck` clean; manual smoke `bash <(cat scripts/setup-security.sh)` (simulating curl|bash).

### Group D — repo-wide refactor (largest scope, last)

18. **T18 — L4: curl no browser User-Agent (project §2 rule)** — `fix(http): add browser User-Agent to all curl invocations (L4)`
    - Strategy: add `TK_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"` constant in `scripts/lib/bootstrap.sh` (or new `scripts/lib/http.sh`).
    - Either (a) wrap every `curl` in a `tk_curl()` helper that adds `-A "$TK_USER_AGENT"`, OR (b) add `-A "$TK_USER_AGENT"` inline to every `curl` call.
    - Files affected: every script using curl. Use `grep -rn '\bcurl\b' scripts/` to enumerate.
    - Verify: `shellcheck` clean; smoke test on at least 1 curl path (e.g., `bash scripts/tests/test-update-libs.sh`).

19. **T19 — H5: TK_TOOLKIT_REF env var** — `feat(installers): support TK_TOOLKIT_REF for pinning toolkit version (H5)`
    - Strategy: introduce `TK_TOOLKIT_REF` env var (default `main`). All 8 installers replace hardcoded `/main/` in `REPO_URL` with `/${TK_TOOLKIT_REF:-main}/`.
    - Files: `scripts/install.sh:34`, `scripts/init-claude.sh:18`, `scripts/update-claude.sh:76`, `scripts/setup-security.sh:49`, `scripts/setup-council.sh:19`, `scripts/install-statusline.sh:35`, `scripts/uninstall.sh:80`, `scripts/migrate-to-complement.sh:59`, `scripts/lib/bootstrap.sh` (REPO_URL), `scripts/lib/dispatch.sh:70`.
    - Add brief README doc paragraph.
    - Verify: `shellcheck` clean; smoke test setting `TK_TOOLKIT_REF=v4.8.0` then dry-run an installer.
    - **Defer** the optional `TK_TOOLKIT_PIN_SHA256` checksum mode — follow-up issue (out of scope for this sweep).

## Final steps after T19

- Run `make check` (full).
- Run `bash scripts/tests/test-bridges-foundation.sh && bash scripts/tests/test-bridges-sync.sh && bash scripts/tests/test-bridges-install-ux.sh && bash scripts/tests/test-update-libs.sh && bash scripts/tests/test-uninstall*.sh`.
- Update CHANGELOG.md "Unreleased" with audit-sweep entry.
- Push branch + open PR titled `fix(audit-sweep): close 18 audit findings + dead code (2026-04-30)`.
- Update STATE.md "Quick Tasks Completed" table with this entry.
- Write SUMMARY.md (status: complete) in this task dir.
