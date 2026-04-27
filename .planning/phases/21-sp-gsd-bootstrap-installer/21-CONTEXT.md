# Phase 21: SP/GSD Bootstrap Installer - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning
**Mode:** `--auto` (Claude selected recommended defaults; user can revise CONTEXT.md before planning)

<domain>
## Phase Boundary

Adds an interactive bootstrap step to `scripts/init-claude.sh` and `scripts/init-local.sh` that runs BEFORE `scripts/detect.sh`. Two `[y/N]` prompts ask the user whether to install `superpowers` and/or `get-shit-done`. On `y`, the toolkit invokes the canonical upstream install commands directly (no forks, no vendoring). After bootstrap, `detect.sh` re-runs so the toolkit install proceeds in the correct mode. A `--no-bootstrap` flag (and `TK_NO_BOOTSTRAP=1` env) skips the prompts entirely for CI / scripted users.

Out-of-scope reminders: bootstrap does NOT run during `update-claude.sh`, `migrate-to-complement.sh`, or `uninstall.sh`. It is a first-run UX feature for the install entry points only.

</domain>

<decisions>
## Implementation Decisions

### Bootstrap library + invocation site

- **D-01 (BOOTSTRAP-01..04):** Bootstrap logic lives in a new `scripts/lib/bootstrap.sh` shared library, sourced by both `init-claude.sh` and `init-local.sh`. Precedent: `scripts/lib/{backup,dry-run-output,optional-plugins,state,install}.sh`. Library exposes a single entry point — e.g. `bootstrap_base_plugins()` — that handles env/flag parsing, idempotency, prompts, invocation, and post-bootstrap re-detection.
- **D-02 (BOOTSTRAP-01):** Bootstrap fires BEFORE `detect.sh` runs in both `init-claude.sh` and `init-local.sh`. Concretely: bootstrap is the first user-facing step after CLI flag parsing and lib sourcing, before any install-mode resolution.
- **D-03 (BOOTSTRAP-02):** Bootstrap is NOT wired into `scripts/update-claude.sh`, `scripts/migrate-to-complement.sh`, or `scripts/uninstall.sh`. Migration users are pre-v4.0 — they have already chosen what plugins to keep. Update is for already-installed toolkits; re-prompting on every update would be noise.

### Prompt structure

- **D-04 (BOOTSTRAP-01):** Two separate sequential `[y/N]` prompts: first for `superpowers`, then for `get-shit-done`. SP first because the plugin install is faster (Claude marketplace) and fails fast if `claude` CLI is missing. GSD second because the curl-installer is slower (network round-trip) and self-contained (no `claude` CLI dependency).
- **D-05 (BOOTSTRAP-01):** Default for both prompts is `N`. Pressing Enter on either prompt skips that plugin. Aligns with toolkit invariant: never auto-install on user's behalf.
- **D-06 (BOOTSTRAP-01):** Prompts read `< /dev/tty`. If `/dev/tty` is unavailable (piped install, CI without TTY), the bootstrap layer behaves as if both answers were `N` and emits a single info line (`bootstrap skipped — no TTY`). No prompt is rendered. Same fail-closed pattern as `prompt_modified_for_uninstall()` (UN-03 D-04).
- **D-07 (BOOTSTRAP-01):** Exact prompt text:
  - SP: `Install superpowers via plugin marketplace? [y/N] `
  - GSD: `Install get-shit-done via curl install script? [y/N] `

### Idempotency + missing prerequisites

- **D-08 (BOOTSTRAP-01):** Idempotency check — bootstrap calls `detect.sh` style filesystem probes BEFORE rendering each prompt. If `~/.claude/plugins/cache/claude-plugins-official/superpowers/` already exists, the SP prompt is suppressed and the bootstrap layer logs `superpowers already installed — skipping.`. Same idempotency for GSD against `~/.claude/get-shit-done/`. Idempotent re-runs of `init-claude.sh` are quiet.
- **D-09 (BOOTSTRAP-02):** Missing `claude` CLI → SP prompt is suppressed entirely with a single warn line: `claude CLI not on PATH — superpowers bootstrap skipped (install Claude Code first).`. GSD prompt is independent (uses `curl`, no claude dep) and renders normally. This avoids prompting `[y/N]` for an action that cannot possibly succeed.
- **D-10 (BOOTSTRAP-02):** Upstream installer failure (any non-zero exit from `claude plugin install …` or `bash <(curl -sSL …)`) is non-fatal: bootstrap logs `⚠ <plugin> install failed (exit code N) — continuing toolkit install`. Toolkit install proceeds in whatever mode `detect.sh` resolves post-bootstrap. REQ-02 invariant.

### Output streaming + invocation

- **D-11 (BOOTSTRAP-02):** When bootstrap invokes upstream installers, output streams verbatim to stdout/stderr — no redirection, no capture, no progress massaging. User sees the upstream installer's UX directly. This makes failures debuggable and avoids the trap of presenting our error wrapping above the upstream's actual error.
- **D-12 (BOOTSTRAP-02):** Canonical install commands are referenced via shell variables defined once in `scripts/lib/optional-plugins.sh` (which already documents them in `recommend_optional_plugins()`). `scripts/lib/bootstrap.sh` reads those constants. Single source of truth — drift between bootstrap, optional-plugins recommendation, templates, and docs is impossible.
  - SP_INSTALL_CMD = `claude plugin install superpowers@claude-plugins-official`
  - GSD_INSTALL_CMD = `bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)`
- **D-13 (BOOTSTRAP-02):** Bootstrap surfaces the upstream installers' exit codes but never fails the toolkit install. The toolkit-install.json `bootstrap` field (if added) records `attempted: true|false` and `installed: true|false` per plugin so downstream debugging is possible — but D-15 below decides not to add that field for v4.4 to avoid state schema drift.

### Re-detection + state

- **D-14 (BOOTSTRAP-03):** After bootstrap completes (whether plugins were installed or skipped), `detect.sh` is re-sourced and the install mode is recomputed via the existing `lib/install.sh` mode-resolution path. `init-claude.sh` and `init-local.sh` then proceed using the post-bootstrap mode. No special handling — bootstrap finishes, then everything downstream behaves as if it were a fresh detect.
- **D-15 (BOOTSTRAP-03):** No new fields in `~/.claude/toolkit-install.json`. The mode the toolkit was installed in already reflects the post-bootstrap reality. Adding a `bootstrap_run: true` flag would be schema drift for no consumer; current state primitives suffice.

### Flag + env semantics

- **D-16 (BOOTSTRAP-04):** `--no-bootstrap` CLI flag + `TK_NO_BOOTSTRAP=1` env var both skip bootstrap entirely. Resolution order: CLI flag wins if present; otherwise the env var is consulted; otherwise default (run bootstrap). Same precedence pattern as `NO_BANNER` in `update-claude.sh` (UN-07 banner gate).
- **D-17 (BOOTSTRAP-04):** Skipping bootstrap is byte-quiet — no log line, no banner. Symmetry with `--no-banner`: opt-out flags should produce v4.3-equivalent output.
- **D-18 (BOOTSTRAP-04):** `--no-bootstrap` is documented in three surfaces: (1) the `--help` output of both `init-claude.sh` and `init-local.sh`, (2) `docs/INSTALL.md`, (3) the new `manifest.json` entry's metadata if it carries doc fields.

### Test architecture

- **D-19 (BOOTSTRAP-04):** Test seam — two env vars `TK_BOOTSTRAP_SP_CMD` and `TK_BOOTSTRAP_GSD_CMD` override the real install commands when set. The test suite sets these to mock scripts under a sandbox `$HOME` that record invocation and exit with controllable codes. Production sets neither var; `bootstrap.sh` falls through to the canonical commands from `optional-plugins.sh`. Same test-seam idiom as `TK_UNINSTALL_HOME` / `TK_UNINSTALL_FILE_SRC` from Phase 18.
- **D-20 (BOOTSTRAP-04):** Hermetic test `scripts/tests/test-bootstrap.sh` covers 5 scenarios:
  - S1: prompt-y for both → mocks invoked, post-detect resolves to `complement-full`
  - S2: prompt-N for both → no mocks invoked, post-detect resolves to `standalone`
  - S3: `--no-bootstrap` → no prompt, no mocks, no log line about bootstrap
  - S4: `claude` CLI missing → SP prompt suppressed, GSD prompt still renders
  - S5: SP install fails (mock exit 1) → toolkit install continues, post-detect reflects failure (still `standalone` for SP), GSD prompt independent
- **D-21 (BOOTSTRAP-04):** Test 28 added to `Makefile` and CI mirror `quality.yml` `validate-templates` job. Five assertions per scenario; total assertion count documented in test header comment.

### Manifest + version-align

- **D-22 (LIB-01 cross-cut):** `scripts/lib/bootstrap.sh` is registered in `manifest.json` as part of Phase 22 (LIB-01..02). Phase 21 plans must NOT pre-register it — that is Phase 22's contract surface. Phase 21 commits the file but Phase 22 owns the manifest schema change.
- **D-23 (BOOTSTRAP-04):** Manifest version stays at `4.3.0` for the duration of Phase 21 — version bump to `4.4.0` happens during Phase 23 distribution work alongside the CHANGELOG `[4.4.0]` entry. Phase 21 is feature-only.

### Claude's Discretion

- Exact log-line wording (the strings prefixed with `bootstrap skipped`, `superpowers already installed`, `claude CLI not on PATH`, etc.) — researcher / planner choose phrasing consistent with existing log_warning/log_info patterns in `lib/install.sh`.
- Whether `bootstrap.sh` exposes one entry point or splits SP/GSD into helpers — implementation detail, planner picks based on testability.
- Whether the GSD curl-installer is invoked via `bash <(curl …)` directly or via a small wrapper that captures the install URL into a temp file first — researcher decides based on whether `bash <(curl …)` is testable under `--no-bootstrap` mocking.

### Folded Todos

None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 21 requirements + roadmap
- `.planning/REQUIREMENTS.md` § "SP/GSD Bootstrap Installer" — BOOTSTRAP-01..04 spec
- `.planning/ROADMAP.md` § "Phase 21: SP/GSD Bootstrap Installer" — success criteria
- `.planning/PROJECT.md` § "Current Milestone: v4.4 Bootstrap & Polish" — non-fork invariant

### Existing toolkit code that bootstrap must integrate with
- `scripts/init-claude.sh` — global installer entry point; bootstrap inserts before `detect.sh` source
- `scripts/init-local.sh` — local installer entry point; same insertion point
- `scripts/detect.sh` — filesystem-based SP/GSD detection; bootstrap calls this BOTH before prompt (for idempotency) AND after install (for mode resolution)
- `scripts/lib/install.sh` — mode resolution (`resolve_install_mode`); consumed post-bootstrap
- `scripts/lib/optional-plugins.sh` — canonical install strings; bootstrap MUST source from here per D-12

### Existing patterns + precedents
- `scripts/lib/backup.sh` — shared lib pattern (color guards, no `set -euo pipefail`, namespaced helpers)
- `scripts/lib/dry-run-output.sh` — shared lib pattern + integration with multiple installers
- `scripts/uninstall.sh` (Phase 18) — `< /dev/tty` fail-closed prompt pattern (`prompt_modified_for_uninstall`); test seam env vars (`TK_UNINSTALL_HOME`, `TK_UNINSTALL_FILE_SRC`); UN-03 reference for D-06
- `scripts/update-claude.sh` — `NO_BANNER` flag/env precedence pattern; UN-07 reference for D-16

### Documentation surfaces (must be updated)
- `docs/INSTALL.md` — install matrix; add `--no-bootstrap` to `init-claude.sh` invocation rows
- `components/optional-plugins.md` — already has canonical install strings (lines 99, 119); cross-reference for SP/GSD invocation
- `templates/*/CLAUDE.md` (×7) — already document required base plugins; no edit expected unless planner finds drift

### Test infrastructure
- `Makefile` Tests 24..27 (uninstall suite) — new Test 28 follows same shape (sandbox HOME, hermetic, mock seam vars)
- `.github/workflows/quality.yml` `validate-templates` job — CI mirror runs the new test alongside existing 27

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/lib/optional-plugins.sh` `recommend_optional_plugins()` — already holds canonical SP and GSD install strings (lines 31, 34). Phase 21 MUST extract these into shared constants (e.g. `TK_SP_INSTALL_CMD`, `TK_GSD_INSTALL_CMD`) at the top of `optional-plugins.sh` so `bootstrap.sh` can source them without duplication.
- `scripts/detect.sh` line 77 — already does `command -v claude &>/dev/null` check; D-09 logic mirrors this style.
- `scripts/uninstall.sh` `prompt_modified_for_uninstall()` (Phase 18) — `< /dev/tty` fail-closed pattern with re-entrant loop; bootstrap prompt is simpler (no diff branch) but pattern transfers cleanly.
- `scripts/lib/install.sh` `log_info` / `log_warning` / `log_error` helpers — bootstrap MUST use these for consistent output styling, never raw `echo`.

### Established Patterns

- **Shared lib invariants:** `scripts/lib/*.sh` files do NOT carry `set -euo pipefail` (they are sourced; setting it would alter caller error mode). They guard color constants with `[[ -z "${VAR:-}" ]] && VAR='…'`. `bootstrap.sh` follows the same shape.
- **Manifest path discipline:** `scripts/lib/*.sh` paths are NOT in `manifest.json` as of v4.3 — Phase 22 closes that gap. Phase 21 ships `bootstrap.sh` but does NOT touch `manifest.json` (D-22 invariant).
- **Test sandbox pattern:** All Phase 18..20 tests use `$HOME=/tmp/tk-…` sandboxes with the install-script `TK_*` env-var seams. Test 28 follows the same idiom.

### Integration Points

- `init-claude.sh` line of insertion: between argparse (the `while [[ $# -gt 0 ]]; do … done` loop) and the `source detect.sh` call. Roughly after line where DRY_RUN/MODE flags are parsed but before the first detection pass.
- `init-local.sh` mirrors the same insertion site. Both installers MUST insert at byte-equivalent points.
- `update-claude.sh` is NOT touched by this phase. `migrate-to-complement.sh` is NOT touched. `uninstall.sh` is NOT touched.

</code_context>

<specifics>
## Specific Ideas

- "No forks" is non-negotiable per user direction 2026-04-27 (logged in PROJECT.md and REQUIREMENTS.md Out of Scope). Bootstrap must invoke the canonical commands `claude plugin install superpowers@claude-plugins-official` and `bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)` literally — those exact strings, no rewrap, no proxy.
- The user has explicitly emphasised that fail-soft behaviour (continue on upstream installer error) is correct. Don't add abort-on-failure or retry logic.
- Test seam pattern (`TK_*_CMD` env vars) already used in v4.3 (`TK_UNINSTALL_*`). Stay consistent.

</specifics>

<deferred>
## Deferred Ideas

- **Selective plugin presets** (`--bootstrap=sp`, `--bootstrap=gsd`, `--bootstrap=both`) — non-interactive bootstrap with explicit selection. Currently scope is interactive prompts + `--no-bootstrap` skip only. Defer to v4.5+ if CI users surface demand for explicit non-interactive Yes-answer.
- **Bootstrap during `update-claude.sh`** — D-03 explicitly excludes this. If users start asking "I updated and SP is still missing, why didn't update install it?", revisit in v4.5.
- **Auto-install other recommended plugins** (rtk, caveman) — out of scope. Bootstrap is for the two base plugins the toolkit complements; rtk/caveman are productivity addons that stay in `recommend_optional_plugins()` end-of-run text only.
- **Dependency-aware install order** — e.g. install `claude` itself if not present. Out of scope. Toolkit assumes Claude Code is installed (it's the runtime). D-09 surfaces the missing-CLI case as a clean skip.

</deferred>

---

*Phase: 21-sp-gsd-bootstrap-installer*
*Context gathered: 2026-04-27 (auto mode)*
