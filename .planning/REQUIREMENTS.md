# Requirements: claude-code-toolkit v4.4 — Bootstrap & Polish

**Defined:** 2026-04-27
**Core Value:** Streamline first-run UX (toolkit can offer to install SP/GSD via their canonical installers) and close residual smart-update / installer-symmetry gaps surfaced during v4.3.

## v4.4 Requirements

Each requirement maps to exactly one roadmap phase. REQ-IDs continue numbering inside the toolkit conventions (BOOTSTRAP / LIB / BANNER / KEEP categories are new for this milestone).

### SP/GSD Bootstrap Installer

The toolkit should offer to install `superpowers` and/or `get-shit-done` before running detection, by invoking their canonical installers directly — no forks, no vendoring.

- [x] **BOOTSTRAP-01**: Before `detect.sh` runs, `init-claude.sh` and `init-local.sh` prompt the user (via `< /dev/tty` with fail-closed `N` if no TTY) — `Install superpowers via plugin marketplace? [y/N]` and `Install get-shit-done via curl install script? [y/N]`. Default `N` for both. Skipped entirely under non-interactive contexts.
- [x] **BOOTSTRAP-02**: On `y` for SP, the installer runs `claude plugin install superpowers@claude-plugins-official` (the canonical command — same string already used in `components/optional-plugins.md` and `templates/*/CLAUDE.md`). On `y` for GSD, the installer runs `bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)`. No forks. No retries. Surface the upstream installer's output verbatim. Continue on failure with a non-fatal warning so the toolkit install does not break.
- [x] **BOOTSTRAP-03**: After bootstrap, `detect.sh` runs again so the toolkit install proceeds in the correct mode (`standalone` → `complement-sp` / `complement-gsd` / `complement-full`). State written to `~/.claude/toolkit-install.json` reflects the post-bootstrap detection.
- [x] **BOOTSTRAP-04**: `--no-bootstrap` flag (and `TK_NO_BOOTSTRAP=1` env var) skips the prompts entirely so CI / scripted users get unchanged v4.3 behaviour. Documented in `docs/INSTALL.md` and the `--help` output of both installers. Hermetic test in `scripts/tests/test-bootstrap.sh` proves three branches: prompt-y, prompt-N, `--no-bootstrap` skip.

### Smart-Update Coverage for `scripts/lib/*.sh`

`scripts/lib/backup.sh`, `dry-run-output.sh`, `install.sh`, and `state.sh` are sourced by every install / update script but live outside `manifest.json`, so `update-claude.sh` silently skips them. Close the gap.

- [x] **LIB-01**: Register `scripts/lib/{backup,dry-run-output,install,state}.sh` in `manifest.json` (either under a new `files.libs[]` array or by extending `files.scripts[]` — pick one and document the choice). Every entry carries a target install path and (where appropriate) `conflicts_with` annotations. `make check` `version-align` and `validate` stay green.
- [x] **LIB-02**: `scripts/update-claude.sh` iterates the new manifest section and updates each lib file with the same diff/backup/safe-write contract used for top-level scripts. Hermetic test in `scripts/tests/test-update-libs.sh` proves a stale `lib/backup.sh` on disk gets refreshed on `update-claude.sh`, and that the post-update SHA256 matches the manifest fixture.

### `--no-banner` Symmetry

`update-claude.sh` already honours `--no-banner` to suppress the closing "To remove: bash <(curl …)" banner. `init-claude.sh` and `init-local.sh` print the banner unconditionally. Bring them up to parity.

- [x] **BANNER-01**: `init-claude.sh` and `init-local.sh` learn `--no-banner` (and `NO_BANNER=1` env var, byte-identical to `update-claude.sh`'s `NO_BANNER=0` default + `--no-banner` flip). When set, the closing "To remove: …" banner is suppressed. When absent, behaviour is unchanged from v4.3. Hermetic test in `scripts/tests/test-install-banner.sh` extended to cover both installers in both modes.

### `--keep-state` Partial-Uninstall Recovery

If the user answers `N` on every modified file in `scripts/uninstall.sh`, the state file is still deleted as the LAST step (UN-05 D-06). Subsequent `uninstall.sh` runs become a no-op even though modified files remain on disk. Add an opt-in flag.

- [x] **KEEP-01**: `scripts/uninstall.sh --keep-state` (and `TK_UNINSTALL_KEEP_STATE=1` env var) preserves `~/.claude/toolkit-install.json` after the run instead of deleting it as the LAST step. All other UN-01..UN-08 invariants stand: SHA256 classify, `[y/N/d]` prompt, base-plugin diff -q, sentinel strip. Documented in `--help` output.
- [x] **KEEP-02**: Hermetic test in `scripts/tests/test-uninstall-keep-state.sh` proves a re-run after `--keep-state` sees the same state file and re-classifies the still-modified files correctly. Asserts: state file exists post-run, second invocation is NOT a no-op, MODIFIED list non-empty on second invocation, base-plugin invariant still passes.

## Future Requirements

Items deferred to v4.5+:

- Selective uninstall (`--only commands/`, `--except council/`) — combinatorial test surface, only revisit on real demand
- Sentinel writer instrumentation in `setup-security.sh` / `init-claude.sh` (wraps toolkit-owned writes in `<!-- TOOLKIT-START --> ... <!-- TOOLKIT-END -->` markers — Phase 19 D-01 deferred indefinitely; Phase 19 already shipped strip-only reader side)

## Out of Scope

- Forking or vendoring `superpowers` / `get-shit-done` source — bootstrap installer must invoke the canonical upstream installers (BOOTSTRAP-02). This invariant is non-negotiable per user direction 2026-04-27.
- Auto-installing SP/GSD without consent — every `BOOTSTRAP-01` prompt defaults to `N`, no opt-out for the prompt itself except `--no-bootstrap`.
- Patching upstream GSD / SP installers — `gsd-build/get-shit-done` and `obra/superpowers` own their installers. We invoke, we do not patch.
- Rewriting `~/.claude/settings.json` during bootstrap — SP/GSD installers handle their own settings. Toolkit's safe-merge stays scoped to its own hooks (per v4.0 Phase 3 SAFETY-01..04).
- Council `audit-review` → Sentry/Linear ticket creation — WONTFIX per user direction 2026-04-27. Sentry reserved for error monitoring; project tracking lives outside the toolkit.
- AUDIT-02/04/06 hardening — WONTFIX (KISS/YAGNI; closed 2026-04-26).
- AUDIT-10/12/14/15 hardening — already covered by shipped behaviour (closed 2026-04-26).
- DETECT-FUT-01 CLI detection — already closed by DETECT-06 in v4.1 Phase 9.
- Docker-per-cell isolation — permanently locked out (conflicts with POSIX-shell invariant).
- Auto-cut `git tag` from phase execution — permanently locked out (CLAUDE.md "never push directly to main").

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| BOOTSTRAP-01 | Phase 21 | Planned |
| BOOTSTRAP-02 | Phase 21 | Planned |
| BOOTSTRAP-03 | Phase 21 | Planned |
| BOOTSTRAP-04 | Phase 21 | Planned |
| LIB-01 | Phase 22 | Planned |
| LIB-02 | Phase 22 | Planned |
| BANNER-01 | Phase 23 | Planned |
| KEEP-01 | Phase 23 | Planned |
| KEEP-02 | Phase 23 | Planned |

**Coverage:** 9 / 9 requirements mapped to phases (100%).
