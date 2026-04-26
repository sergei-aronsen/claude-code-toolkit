# Phase 20: Distribution + Tests — Context

**Gathered:** 2026-04-26
**Status:** Ready for planning
**Mode:** Auto-resolved (`/gsd-discuss-phase 20 --auto`)

<domain>
## Phase Boundary

Surface `scripts/uninstall.sh` to end users via three distribution channels and gate the round-trip with one integration test:

1. **Manifest registration** — `manifest.json` `files.scripts[]` lists `scripts/uninstall.sh`; `version` bumps to `4.3.0`; `version-align` gate stays green.
2. **Installer banners** — `init-claude.sh`, `init-local.sh`, `update-claude.sh` each print one new line at the end of their existing post-install summary: `To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)`.
3. **CHANGELOG** — `[4.3.0]` Added section covers UN-01..UN-08, ship-date placeholder `YYYY-MM-DD` until milestone closes.
4. **Round-trip test** — new `scripts/tests/test-uninstall.sh` exercises real `init-local.sh` → uninstall.sh round-trip in a `/tmp/` sandbox, asserts clean-checkout parity, modified-file `y/N/d` coverage, base-plugin invariant, `--dry-run` zero-mutation, double-uninstall no-op. Wired as Makefile `Test 24`. New `scripts/tests/test-install-banner.sh` source-greps each installer for the locked banner line — wired as Makefile `Test 25`.

In scope:

- `manifest.json` schema extension: new `files.scripts` array
- Three installer source edits + one CHANGELOG entry
- Two new test files + two new Makefile slots
- No changes to existing 5 uninstall unit tests (dry-run / backup / prompt / idempotency / state-cleanup)

Out of scope (deferred):

- `--no-banner` flag for `init-claude.sh` / `init-local.sh` (only `update-claude.sh` has one today; KISS — not adding more)
- Registering `scripts/lib/*.sh` in manifest (internal sourced helpers, not user-facing entry points)
- Selective uninstall flags (deferred to v4.4 per Phase 19 D-05)
- Changes to `.github/workflows/quality.yml` — `make test` auto-picks new tests via existing `test-init-script` job

</domain>

<decisions>
## Implementation Decisions

### Test Architecture (UN-08)

- **D-01:** Add ONE new integration test `scripts/tests/test-uninstall.sh` — supplements, does not replace, the 5 existing uninstall unit tests (dry-run / backup / prompt / idempotency / state-cleanup). Reason: each existing unit test owns a single slice of UN-01..UN-06; UN-08 explicitly requires an end-to-end round-trip assertion. Splitting 5 scenarios across 5 more tests duplicates fixture cost; one driver script with 5 scenario blocks is leaner.
- **D-02:** Test runs the REAL installer (`init-local.sh`) against a `/tmp/test-uninstall-roundtrip.XXXXXX` sandbox, then runs the REAL `uninstall.sh` against the same sandbox. No synthetic state-file fabrication. This proves the install→uninstall contract end-to-end, not just uninstall.sh in isolation. Aligns with existing Makefile Test 1-3 pattern (`init-local.sh` against `/tmp/test-claude-*`).
- **D-03:** Five scenario blocks inside the single test file:
  - **S1 — clean round-trip:** install → uninstall (no modifications) → assert `find $SANDBOX/.claude -type f | wc -l == 0`, `toolkit-install.json` absent, base-plugin trees byte-identical
  - **S2 — modified file `y` choice:** install → modify a tracked file → uninstall with `y` to keep → assert backup contains pre-modification copy, modified file deleted
  - **S3 — modified file `N` choice:** install → modify a tracked file → uninstall with `N` (default) → assert modified file preserved, backup still created
  - **S4 — modified file `d` then `N`:** install → modify → uninstall with `d` (diff) then `N` → assert diff was rendered AND original choice respected
  - **S5 — `--dry-run` + double-uninstall idempotency:** install → `uninstall.sh --dry-run` → assert zero filesystem mutations → `uninstall.sh` real → `uninstall.sh` again → assert second run prints "Toolkit not installed; nothing to do" and exits 0
- **D-04:** Test seams: same `TK_UNINSTALL_HOME` / `TK_UNINSTALL_LIB_DIR` / `TK_UNINSTALL_TTY_FROM_STDIN=1` already established in Phase 18+19. No new env-var seams. `init-local.sh` already accepts copying from local repo, no curl needed.
- **D-05:** Test slot in Makefile = **Test 24**, NOT Test 21. Reason: Phase 18 unit tests already occupy Test 21 (dry-run), Test 22 (backup), Test 23 (prompt). ROADMAP §"Phase 20" success criterion #4 wording "Test 21" is a misnomer dating from when the round-trip test was the first uninstall test slot. Plan 03 documents this in CHANGELOG and in 20-PLAN comments. Banner test = **Test 25**.

### Banner Placement (UN-07)

- **D-06:** Single dedicated `echo "To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)"` line in each of three installers, placed immediately before the existing final line so a single `grep -F "To remove: bash"` against the source file matches in all three. Identical wording (no per-installer variation) so `test-install-banner.sh` runs one grep three times.
- **D-07:** Anchor lines for the new echo:
  - `scripts/init-claude.sh` — directly above `echo "Read .claude/POST_INSTALL.md and show its contents to the user."` (current line 905)
  - `scripts/init-local.sh` — directly below the "Security setup (recommended):" block (after line 425, before any closing `fi`/main flow)
  - `scripts/update-claude.sh` — after `print_update_summary "$BACKUP_DIR"` and below the existing "⚠ Restart Claude Code" line so it is the LAST line of normal-mode output. Honors the existing `--no-banner` flag in update-claude.sh: skip the new echo when `NO_BANNER=1`.
- **D-08:** No new `--no-banner` flag in `init-claude.sh` / `init-local.sh`. Reason: KISS — `update-claude.sh` already has `--no-banner` because it can be re-run silently; install scripts are one-shot and benefit from terminal output. If suppression demand emerges in v4.4, add the flag then.
- **D-09:** Banner gating mechanism: source-grep, not runtime invocation. New `scripts/tests/test-install-banner.sh` runs `grep -F 'To remove: bash <(curl' scripts/init-claude.sh scripts/init-local.sh scripts/update-claude.sh` and asserts each file matches exactly once. Reason: deterministic, no network, no /tmp churn, runs in milliseconds. Runtime stdout capture would also work but adds fixture cost without catching anything new.

### manifest.json Structure (UN-07)

- **D-10:** New `files.scripts` array — single entry today: `{"path": "scripts/uninstall.sh"}`. Schema mirrors existing `files.agents` / `files.prompts` / `files.commands` / `files.skills` / `files.rules` arrays. No `conflicts_with`, no `sp_equivalent` — uninstall.sh is toolkit-exclusive, no superpowers analog.
- **D-11:** Internal sourced libs (`scripts/lib/state.sh`, `scripts/lib/backup.sh`, `scripts/lib/dro.sh`) are NOT registered in manifest. Reason: they are implementation details of `scripts/uninstall.sh`; users never invoke them directly; smart-update logic in `scripts/update-claude.sh` does not iterate `files.scripts` (yet). Adding them now creates dead schema; revisit if `update-claude.sh` ever copies user-installed scripts/.
- **D-12:** `manifest.json` `version` bumps `4.2.0 → 4.3.0` and `updated:` is set to placeholder `"YYYY-MM-DD"` until the milestone tag commit. Same commit also bumps `CHANGELOG.md` `[4.3.0]` heading and `init-local.sh --version` so the `make check version-align` gate stays green throughout the phase. All three version edits happen in ONE plan — partial bumps fail the gate.

### CHANGELOG Entry (UN-07)

- **D-13:** Single `## [4.3.0] - YYYY-MM-DD` entry under `Added`, organized by sub-section:
  - **Uninstall script** (UN-01..UN-06): one bullet per requirement, citing the user-facing capability (not the test ID)
  - **Distribution** (UN-07): manifest registration + installer banners + this CHANGELOG entry itself
  - **Tests** (UN-08): round-trip integration test + Makefile Test 24 + banner test + Test 25
- **D-14:** No `### Changed` / `### Fixed` / `### Removed` / `### Security` sub-sections in `[4.3.0]` — milestone is purely additive. Skip empty sub-sections per Keep-a-Changelog convention.
- **D-15:** Ship-date placeholder `YYYY-MM-DD` is locked LITERAL — `make check version-align` accepts the literal placeholder during the in-progress window. Final tag commit replaces with the actual ISO date in one atomic commit alongside the `v4.3.0` tag.

### CI Integration

- **D-16:** No edits to `.github/workflows/quality.yml`. Reason: existing `test-init-script` job runs `make test`, which now includes Test 24 + Test 25 once the Makefile is updated. New tests are picked up automatically. Adding a separate workflow step would duplicate execution.

### Claude's Discretion

The user delegated all gray areas with `--auto`. Decisions above reflect KISS/YAGNI bias: minimal v4.3 surface, defer expansion (banner suppress flags, lib/ manifest entries) to v4.4 if real demand emerges. Claude has flexibility on:

- Exact source line numbers for banner echo insertion (anchor patterns are stable; line numbers shift across the phase)
- Test fixture filename inside the sandbox (`commands/clean.md` is conventional from Phase 19 Plan 03 — reuse)
- CHANGELOG bullet wording (must accurately reflect each UN-XX requirement)
- Order of plans within Phase 20 (manifest+CHANGELOG bump first to satisfy version-align gate, then banners, then tests)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap + Requirements

- `.planning/ROADMAP.md` §"Phase 20: Distribution + Tests" — 4 success criteria
- `.planning/REQUIREMENTS.md` §"Distribution" — UN-07 (manifest + banners + CHANGELOG), UN-08 (round-trip test)

### Phase 18 + 19 Foundation (must not regress)

- `scripts/uninstall.sh` — full Phase 18+19 implementation; Plan 03 round-trip test exercises this end-to-end
- `scripts/tests/test-uninstall-{dry-run,backup,prompt,idempotency,state-cleanup}.sh` — 5 existing unit tests; round-trip test must NOT duplicate their assertions
- `.planning/phases/18-core-uninstall-script-dry-run-backup/18-VERIFICATION.md` — Phase 18 invariants
- `.planning/phases/19-state-cleanup-idempotency/19-VERIFICATION.md` — Phase 19 invariants (UN-05/UN-06 gates)

### Distribution Conventions

- `manifest.json` — current schema (`files.{agents,prompts,commands,skills,rules}`, `templates.*`, `claude_md_sections.*`); Phase 20 adds `files.scripts`
- `Makefile` §`version-align` (lines 200+) — D-09 alignment gate; manifest.json + CHANGELOG.md + init-local.sh --version must match
- `Makefile` §`test` (lines 42+) — Test 1-23 catalog; Phase 20 adds Test 24 (round-trip) + Test 25 (banner gate)
- `CHANGELOG.md` — Keep-a-Changelog format; current top entry is `[4.2.0] - 2026-04-26`

### Banner Anchors

- `scripts/init-claude.sh` line ~904 — final `echo "Read .claude/POST_INSTALL.md..."`
- `scripts/init-local.sh` line ~424 — final security-setup recommendation block
- `scripts/update-claude.sh` end of file — `Restart Claude Code` line; honors existing `NO_BANNER=1` flag

### CI Configuration

- `.github/workflows/quality.yml` `test-init-script` job — runs `make test`; auto-picks up Test 24 + Test 25

### Project Conventions

- `CLAUDE.md` §"Markdown Formatting (CRITICAL)" — markdownlint MD040/MD031/MD032/MD026 rules apply to CHANGELOG additions
- `CLAUDE.md` §"Quality Checks" — `make check` must pass on every PR

### External Specs

No external ADRs — this milestone is fully scoped within `REQUIREMENTS.md` and `ROADMAP.md`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Five existing uninstall unit tests** (`scripts/tests/test-uninstall-{dry-run,backup,prompt,idempotency,state-cleanup}.sh`) — Phase 20 round-trip test reuses their assertion helper pattern (`assert_pass`, `assert_fail`, `assert_eq`, `assert_contains`, `sha256_any`) and sandbox setup (`mktemp -d /tmp/...`, `TK_UNINSTALL_HOME` seam, `trap 'rm -rf $SANDBOX' EXIT`)
- **`scripts/init-local.sh`** — already takes `--dry-run`, `--version`, framework-detection arguments; round-trip test invokes it against a real sandbox project dir. Existing Makefile Tests 1-3 prove the install path works.
- **`Makefile` `version-align`** (line 202) — D-09 gate already enforces the three-way version match; Phase 20 only needs to bump in lockstep, not implement the gate
- **CHANGELOG `[4.2.0]`** (top entry) — provides the structural template for `[4.3.0]`: Added/Changed/Fixed sub-sections, bullet style, link format

### Established Patterns

- **Single-entry-line `echo` for installer banners** — every installer ends with one or more `echo` lines forming a post-install summary; the new "To remove" line slots in seamlessly without restructuring
- **Source-grep tests** — `make check` already runs source-grep on audit prompt templates (looking for `QUICK CHECK` / `SELF-CHECK` markers); the new banner test follows the same lightweight pattern
- **Manifest array entries** — `files.{agents,prompts,...}` are arrays of `{path, [conflicts_with], [sp_equivalent]}` objects; the new `files.scripts` array follows the same shape with the simplest variant (`{path}` only)

### Integration Points

- **`make check`** — version-align + shellcheck + markdownlint must stay green after manifest + CHANGELOG + init-local.sh version bump
- **`make test`** — `test-init-script` CI job runs this; Phase 20's Test 24 + Test 25 plug in as new `@bash scripts/tests/test-uninstall.sh` and `@bash scripts/tests/test-install-banner.sh` lines
- **`scripts/update-claude.sh` `--no-banner`** — existing flag; the new "To remove" echo respects it for symmetry

</code_context>

<specifics>
## Specific Ideas

- **Locked banner wording** (per ROADMAP success criterion #2): exactly `To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)` — no leading/trailing prose, no shell color codes (would break the literal grep), no quotes around the URL.
- **Locked manifest version**: `4.3.0` — bump from current `4.2.0`. The `updated` field uses placeholder `"YYYY-MM-DD"` until milestone close, then a single commit replaces it with the real ISO date alongside the `v4.3.0` tag.
- **Locked CHANGELOG heading**: `## [4.3.0] - YYYY-MM-DD` (also placeholder).
- **Round-trip test sandbox naming**: `/tmp/test-uninstall-roundtrip.XXXXXX` — disambiguates from the 5 existing uninstall unit tests' sandbox prefixes.
- **Plan ordering hint**: manifest + CHANGELOG + init-local.sh `--version` bump should be Plan 01 (smallest, gates the version-align check). Banners = Plan 02. Round-trip test = Plan 03. Banner gate test = Plan 04 (or fold into Plan 02). Final ordering decided by planner.

</specifics>

<deferred>
## Deferred Ideas

These came up during analysis and belong in future phases — captured here so they're not lost:

- **`--no-banner` flag for `init-claude.sh` / `init-local.sh`** (v4.4 if demanded): currently only `update-claude.sh` has it. Add only if real users complain about the new "To remove" line in install output.
- **Registering `scripts/lib/*.sh` in manifest** (v4.4 if `update-claude.sh` learns to copy user scripts): today the libs are implicit dependencies of `scripts/uninstall.sh`, fetched alongside it by curl. If smart-update grows a `files.scripts` iteration loop, formalize the lib registration then.
- **Selective uninstall flags** (`--keep-state`, `--only commands/`, etc.) (v4.4+): out of scope per Phase 19 D-05 and `REQUIREMENTS.md`.
- **Banner localization** (v4.5+): "To remove" is English-only; `cheatsheets/` ship 9 languages. If multilingual install banners ever land, the new line will need translation infra.

### Reviewed Todos (not folded)

None — `gsd-tools todo match-phase` returned no matches for Phase 20.

</deferred>

---

*Phase: 20-distribution-tests*
*Context gathered: 2026-04-26 (auto-resolved)*
