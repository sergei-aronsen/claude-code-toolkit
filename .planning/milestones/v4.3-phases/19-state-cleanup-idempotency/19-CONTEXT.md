# Phase 19: State Cleanup + Idempotency — Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Make `scripts/uninstall.sh` leave the system in a known-clean state and survive double-invocation. Two requirements: UN-05 (delete `~/.claude/toolkit-install.json` and strip toolkit-owned sentinel block from `~/.claude/CLAUDE.md`, never touching base plugins) and UN-06 (second invocation is a clean no-op).

In scope:
- State file deletion at end of successful uninstall flow
- Sentinel block strip from `~/.claude/CLAUDE.md` (`<!-- TOOLKIT-START --> ... <!-- TOOLKIT-END -->`)
- Idempotency guard: missing `toolkit-install.json` → `✓ Toolkit not installed; nothing to do`, exit 0, zero side-effects
- Base-plugin invariant verification (superpowers + get-shit-done untouched before vs after)

Out of scope (deferred):
- Instrumenting `setup-security.sh` / `init-claude.sh` to WRITE sentinels around their additions (defer to v4.4 — see Deferred Ideas)
- `--keep-state` flag for partial-uninstall (defer to v4.4)
- Filesystem-scan-based idempotency (state file alone is canonical signal)

</domain>

<decisions>
## Implementation Decisions

### Sentinel Block Strip (UN-05)
- **D-01:** Strip-only in v4.3. Phase 19 implements the *reader* side (strip block if present in `~/.claude/CLAUDE.md`); the *writer* side (installers wrapping their additions in `<!-- TOOLKIT-START --> ... <!-- TOOLKIT-END -->`) is deferred to v4.4. Reason: UN-05 explicitly says "if present" → strip is graceful no-op when sentinels absent; current installers (`setup-security.sh`, `init-claude.sh`) do not yet write sentinels, so strip code is dormant but correct. Adding writer instrumentation in this phase doubles scope and crosses into setup-security territory that wasn't audited.
- **D-02:** Strip semantics: remove the FIRST `<!-- TOOLKIT-START -->` … `<!-- TOOLKIT-END -->` pair plus exactly ONE leading and ONE trailing blank line if present. If markers are unmatched (start without end, or vice versa), log a warning and leave file untouched — never partial-strip. If multiple START/END pairs exist (shouldn't happen, but defensive), strip ALL pairs.
- **D-03:** Empty-file handling: if `~/.claude/CLAUDE.md` becomes empty or whitespace-only after strip, leave the empty file on disk — do NOT delete. Reason: the file is shared with other tools (rtk, gsd, user-authored content); deleting a file the toolkit only partially owns violates least-destruction principle. Backup covers any recovery need.

### State File Deletion (UN-05)
- **D-04:** Always delete `~/.claude/toolkit-install.json` at the end of a successful uninstall flow, regardless of how many files the user kept (answered `N` on per-file `[y/N/d]` prompt). Reason: the state file represents "toolkit was installed per this manifest"; once the uninstall flow has run, that claim is no longer accurate. If users want to keep files AND state, they should use `--dry-run` (preview only).
- **D-05:** No `--keep-state` flag in v4.3. Per `REQUIREMENTS.md` Out of Scope ("Selective uninstall — adds combinatorial test surface; revisit if user demand emerges"), this stays in v4.4 backlog.
- **D-06:** Delete order: backup → strip sentinel block → file delete loop → delete `toolkit-install.json` (LAST). State delete is the final atomic step so any earlier failure leaves the state file intact, allowing the user to re-run `uninstall.sh` and have it pick up where it left off. If state-file deletion fails (e.g., readonly mount), log a warning and exit 0 — files are already removed; the user can manually `rm` the orphan.

### Idempotency (UN-06)
- **D-07:** Single canonical signal: `~/.claude/toolkit-install.json` missing → script prints `✓ Toolkit not installed; nothing to do` and exits 0 immediately, BEFORE backup, BEFORE any filesystem scan, BEFORE creating any temp files. Zero side-effects on no-op runs.
- **D-08:** No filesystem scan fallback. If user manually deleted `toolkit-install.json` but kept toolkit files, the script honors the user's manual cleanup intent (state says "not installed" → believe state). Acceptable trade-off: simpler logic, predictable behavior, matches the install-side contract that state file IS the truth.
- **D-09:** No-op guard placement: the `[[ -f "$STATE_FILE" ]]` check happens IMMEDIATELY after argparse, before lock acquisition, before backup directory creation. Specifically: NO `~/.claude-backup-pre-uninstall-*` directory is created on no-op runs (acceptance criterion in `ROADMAP.md` success criteria #3).

### Base-Plugin Invariant (UN-05)
- **D-10:** Verification mechanism: at end of uninstall flow, compare `find ~/.claude/plugins/cache/claude-plugins-official/superpowers -type f | sort` and `find ~/.claude/get-shit-done -type f | sort` outputs against snapshots taken at script start. Any mismatch → log error, exit 1 (script must never modify base plugins; if it does, that's a bug worth surfacing loudly). Snapshots stored in temp file under `${TMPDIR:-/tmp}` and cleaned up via `trap EXIT`.
- **D-11:** Reuse the existing exclusion list from Phase 18 `scripts/uninstall.sh` (it already excludes `~/.claude/plugins/cache/claude-plugins-official/superpowers/` and `~/.claude/get-shit-done/` from the delete loop). The invariant check is a defense-in-depth assertion, not the primary mechanism.

### Claude's Discretion

The user delegated all four gray areas (sentinel writer scope, state delete timing, idempotency signal, empty-file handling) with `решай все сам`. Decisions above reflect KISS/YAGNI bias: minimal v4.3 surface, defer expansion to v4.4 if real demand emerges. Claude has flexibility on the implementation details (exact sed/awk vs python strip, exact log message wording, lock acquisition path) — final wording locked during planning.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap + Requirements
- `.planning/ROADMAP.md` §"Phase 19: State Cleanup + Idempotency" — success criteria 1–4 (sentinel strip, base-plugin invariant, idempotency, partial-uninstall recovery)
- `.planning/REQUIREMENTS.md` §"State Cleanup + Idempotency" — UN-05 (state delete + sentinel strip), UN-06 (idempotent double-invoke)

### Phase 18 Foundation (must not regress)
- `scripts/uninstall.sh` — argparse, color gating, log helpers, mktemp+trap pattern (lines 1–80 establish the conventions Phase 19 plans must follow)
- `scripts/lib/state.sh` — `STATE_FILE` constant (`$HOME/.claude/toolkit-install.json`), `read_state()`, `acquire_lock()`/`release_lock()` semantics
- `scripts/lib/backup.sh` — backup directory naming convention (`~/.claude-backup-pre-uninstall-<unix-ts>/`)
- `.planning/phases/18-core-uninstall-script-dry-run-backup/18-VERIFICATION.md` — confirms Phase 18 invariants Phase 19 builds on

### Test Conventions
- `scripts/tests/test-uninstall-dry-run.sh` — sandbox pattern (`TMPDIR` + `TK_UNINSTALL_LIB_DIR` env var seam) for testing without curl
- `scripts/tests/test-uninstall-prompt.sh` — `TK_UNINSTALL_TTY_FROM_STDIN=1` seam for /dev/tty injection
- `scripts/tests/test-uninstall-backup.sh` — backup-directory assertion pattern

### Project Conventions
- `CLAUDE.md` §"Markdown Formatting (CRITICAL)" — markdownlint MD040/MD031/MD032/MD026 rules apply to any new docs
- `CLAUDE.md` §"Quality Checks" — `make check` must pass (shellcheck severity=warning, markdownlint, validate)

### External Specs
No external ADRs — this milestone is fully scoped within `REQUIREMENTS.md` and `ROADMAP.md`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`scripts/lib/state.sh`** — `STATE_FILE`, `LOCK_DIR`, `acquire_lock`/`release_lock`, `iso8601_utc_now`, `sha256_file`. Phase 19 uses `STATE_FILE` for the no-op check and the final `rm`. Lock acquisition is OPTIONAL on uninstall (no concurrent install/uninstall race in v4.3 — single-user toolkit) but RECOMMENDED for symmetry with install.
- **`scripts/lib/backup.sh`** — Phase 18 backup primitive. Phase 19 must NOT call this on no-op runs (per D-09).
- **`scripts/uninstall.sh:20-44`** — argparse pattern + `--no-backup` rejection. Phase 19 adds the no-op guard immediately after this block, before color constants.

### Established Patterns
- **`set -euo pipefail`** at top of every script — Phase 19 plans inherit
- **ANSI color gating** via `[ -t 1 ]` + `[ -z "${NO_COLOR+x}" ]` — Phase 19 reuses
- **`trap 'cleanup' EXIT`** for tempfile management — Phase 19 plans must register before any `mktemp`
- **Test sandbox pattern**: tests use `TK_UNINSTALL_LIB_DIR` env var to bypass curl and `TK_UNINSTALL_TTY_FROM_STDIN=1` to inject stdin (per Phase 18 18-HUMAN-UAT.md). Phase 19 tests follow same pattern; new env var `TK_UNINSTALL_HOME` may be needed to redirect `~/.claude/` lookups in tests (TBD in planner).

### Integration Points
- **End of `scripts/uninstall.sh`** — Phase 19 logic appends after the file-delete loop (Phase 18 18-03-PLAN.md output) and before the final exit. Strip + state-delete are the LAST two operations.
- **Top of `scripts/uninstall.sh` (after argparse)** — no-op idempotency guard. Must short-circuit before lock acquisition and backup creation.
- **No installer-side changes**: per D-01, sentinel WRITERS in `setup-security.sh` / `init-claude.sh` are deferred. Phase 19 is read/strip only.

</code_context>

<specifics>
## Specific Ideas

- Sentinel strip should be implemented in pure bash (sed-based) for portability — no python dependency on the strip path. python3 is acceptable as a fallback for sha256 already, but strip should not require it.
- The `nothing-to-do` log line wording is fixed: `✓ Toolkit not installed; nothing to do` (locked by ROADMAP success criterion #3).
- Backup-not-created-on-no-op is testable via `find ~/.claude-backup-pre-uninstall-* 2>/dev/null | wc -l` returning `0` after a no-op run.

</specifics>

<deferred>
## Deferred Ideas

These came up during analysis and belong in future phases — captured here so they're not lost:

- **Sentinel writer instrumentation** (v4.4): Update `setup-security.sh` to wrap its appended security rules in `<!-- TOOLKIT-START --> ... <!-- TOOLKIT-END -->`, and update `init-claude.sh`/`init-local.sh` similarly for any global writes. Without writers, Phase 19's strip code never has anything to strip in practice — but the strip code itself is correct and ready.
- **`--keep-state` flag** (v4.4): For users who want to answer `N` to every modified file and still preserve state. Out of scope per `REQUIREMENTS.md`.
- **Selective uninstall** (`--only commands/`, `--except council/`) (v4.5+): Combinatorial test surface; only revisit if real users ask.
- **Filesystem-scan idempotency fallback** (v4.4 if needed): If users report orphaned toolkit files after manual `rm` of `toolkit-install.json`, add a `--scan-orphans` flag. Not adding speculatively.
- **Re-install detection / upgrade UX** (v4.4+): "User uninstalled then re-installed; show migration banner." `init-claude.sh` already handles fresh install; defer until the friction is observed.

### Reviewed Todos (not folded)
None — `gsd-tools todo match-phase` returned no matches for Phase 19.

</deferred>

---

*Phase: 19-state-cleanup-idempotency*
*Context gathered: 2026-04-26*
