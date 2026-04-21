# Phase 6: Documentation - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning
**Source:** Autonomous plan-phase (no interactive discuss); decisions locked by orchestrator after reviewing `06-RESEARCH.md` recommendations.

<domain>
## Phase Boundary

Phase 6 finalizes every user-facing surface for the v4.0 release:

- `README.md` positioning (TK as complement, not replacement)
- 7 × `templates/*/CLAUDE.md` "Required Base Plugins" blocks
- `CHANGELOG.md` `[4.0.0]` entry covering all user-visible changes shipped by Phases 1–5
- `docs/INSTALL.md` capturing the 12-cell install matrix
- `components/optional-plugins.md` (new) + `templates/global/RTK.md` (new)
- Script end-of-run "recommended optional plugins" block wired into `init-claude.sh` + `update-claude.sh`
- `components/orchestration-pattern.md` polish, registration, cross-references
- README "Components" section updated to reference orchestration-pattern.md

Out of scope for Phase 6: the 9 non-English README translations (deferred to v4.1); any code changes beyond the script wiring block for DOCS-06 and the RTK.md install wiring for DOCS-07.

</domain>

<decisions>
## Implementation Decisions

### DOCS-04 delivery shape

- `docs/INSTALL.md` is a **standalone file** (not an inline README section).
- Rationale: 12-cell matrix is too dense for the landing README; a dedicated page keeps README focused on positioning while giving contributors a canonical install reference. README links to it.

### DOCS-06 code location

- New library file: `scripts/lib/optional-plugins.sh`, exporting a single function `recommend_optional_plugins` that prints the block.
- Both `init-claude.sh` and `update-claude.sh` source the lib and call the function at end-of-run.
- Rationale: avoids text duplication across 2 entry scripts; any future caveat edit is one-file.

### DOCS-07 install wiring

- `~/.claude/RTK.md` template install folds into `scripts/setup-security.sh` (already the "globals-into-user-home" path).
- Guard: `[ ! -f "$HOME/.claude/RTK.md" ] || return 0` — never clobber `rtk init -g`'s own RTK.md if user already ran it.
- Rationale: setup-security.sh is already the canonical `~/.claude/` writer; a dedicated `install-rtk-notes.sh` adds a script for ~30 lines of logic that naturally belong in the security setup flow.

### Non-English README translations

- Locked OUT of Phase 6. Ship English-only for v4.0.
- Tracked as backlog item for v4.1 milestone.

### CHANGELOG 4.0.0 entry shape

- Keep-a-Changelog 1.0.0 layout: `### Added / Changed / Deprecated / Removed / Fixed / Security` with a **BREAKING CHANGES-first** header block above the categories.
- Link-reference format at bottom for compare URLs.
- Rationale: semver 4.0.0 bump demands the BREAKING block to be immediately visible at the top of the entry; Keep-a-Changelog categories give downstream release note generators a predictable shape.

### `manifest.json` component registry

- Register **only the two new Phase 6 components** (`components/optional-plugins.md` + `components/orchestration-pattern.md`) in `files.components`.
- Do NOT backfill the 27 existing components — that is a separate refactor tracked under manifest cleanup, not Phase 6.
- Rationale: contain Phase 6 scope; the backfill is a pure docs-asset inventory task independent of the 4.0 release.

### SP / GSD install command strings (A1 / A2 from research)

- Superpowers: `claude plugin install superpowers@claude-plugins-official` — matches the key used in `settings.json` `enabledPlugins` (verified in `scripts/detect.sh:54` and `scripts/verify-install.sh:197-200`).
- Get-Shit-Done: `bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)` — matches the filesystem detection path `~/.claude/get-shit-done/` in `scripts/detect.sh:29`.
- Rationale: Both are internal-consistent with how the codebase already detects presence; Phase 6 documents what actually gets installed, not a hypothetical packaging.

### DOCS-05 factual corrections (already applied to REQUIREMENTS.md in commit 2444b40)

- `caveman` ships **en + wenyan** (Classical Chinese), NOT en + ru — verified against upstream JuliusBrussee/caveman README 2026-04-18.
- `caveman-compress` **auto-backs up** `CLAUDE.md` to `CLAUDE.original.md` — no manual backup required; the caveat is that the backup is single-generation and overwrites on re-compress.
- `rtk` issue #1276 is still OPEN as of 2026-04-18; upstream's intended fix is internal `LC_ALL=C`, user-side workaround is `exclude_commands = ["ls"]` — `components/optional-plugins.md` must document the distinction.

### Claude's Discretion

- Exact wording of README positioning block — implementer picks prose; locked invariants are: (1) "complement" not "replacement", (2) both standalone and complement install paths shown, (3) one paragraph of guidance per mode.
- Exact per-template "Required Base Plugins" prose — one canonical 15-line block reused verbatim across all 7 templates (see research §5 for the shape).
- Order of `### Added / Changed / …` sub-blocks inside the 4.0.0 CHANGELOG entry — Keep-a-Changelog leaves ordering at author's discretion.
- `docs/INSTALL.md` table styling (markdown pipe-table vs HTML fallback) — pipe-table preferred unless markdownlint MD060 is re-enabled (currently disabled).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-internal specs

- `.planning/ROADMAP.md` — Phase 6 section + SC-1..SC-6
- `.planning/REQUIREMENTS.md` — DOCS-01..08 (corrected DOCS-05 post-2444b40)
- `.planning/PROJECT.md` — project identity, in-scope / out-of-scope
- `.planning/phases/06-documentation/06-RESEARCH.md` — gap analysis, CHANGELOG catalog, install matrix, upstream verification, pitfalls

### Phase 1–5 SUMMARY files (source of truth for CHANGELOG content)

- `.planning/phases/01-prework/01-01-SUMMARY.md` .. `01-03-SUMMARY.md`
- `.planning/phases/02-foundation/02-01-SUMMARY.md` .. `02-04-SUMMARY.md`
- `.planning/phases/03-install-flow/03-01-SUMMARY.md` .. `03-03-SUMMARY.md`
- `.planning/phases/04-update-flow/04-01-SUMMARY.md` .. `04-03-SUMMARY.md`
- `.planning/phases/05-migration/05-01-SUMMARY.md` .. `05-03-SUMMARY.md`

### External specs

- [Keep a Changelog 1.0.0](https://keepachangelog.com/en/1.0.0/) — CHANGELOG entry format for 4.0.0
- [rtk-ai/rtk#1276](https://github.com/rtk-ai/rtk/issues/1276) — upstream issue referenced in DOCS-05, DOCS-07
- [JuliusBrussee/caveman README](https://github.com/JuliusBrussee/caveman/blob/main/README.md) — DOCS-05 caveman caveats source

### Quality gates

- `./CLAUDE.md` — project-level markdownlint rules (MD040/MD031/MD032/MD026), conventional commits, manifest-driven updates
- `.markdownlint.json` — lint config (MD013/MD033/MD041/MD060 disabled; MD024 siblings-only; MD029 ordered)
- `Makefile` — `make check` = `make lint validate` = markdownlint + shellcheck + manifest version alignment

</canonical_refs>

<specifics>
## Specific Ideas

### CHANGELOG 4.0.0 content catalog (from research §2)

Must cover, at minimum:

- **Added:** `scripts/detect.sh`; 4 install modes (`standalone`, `complement-sp`, `complement-gsd`, `complement-full`); `toolkit-install.json` state file + schema v2 with `synthesized_from_filesystem`; manifest schema v2 with `requires_base`, `conflicts_with`, `sp_equivalent` per-file fields; `scripts/migrate-to-complement.sh`; `scripts/lib/install.sh` (`compute_skip_set`, `recommend_mode`); `scripts/lib/state.sh` (`write_state`, atomic replace, install-lock directory); `--dry-run`, `--force`, `--force-mode-change` flags on init-local; D-77 migrate hint on update-claude.sh; 4-group update summary (INSTALLED / UPDATED / SKIPPED / REMOVED); per-file user-modified detection with three-way diff.
- **Changed:** `init-claude.sh` + `init-local.sh` rewritten for mode-aware installs; `update-claude.sh` re-evaluates detection on every run and diffs against manifest; `setup-security.sh` safely merges `~/.claude/settings.json` (backup + JSON merge); every audit prompt template gained `QUICK CHECK` + `SELF-CHECK` sections (CI-enforced).
- **Fixed:** v3.x bugs triaged in Phase 1 (`commands/design.md` drift, version drift, BSD `head -n -1` silent breakage, `setup-council.sh` stdin without `< /dev/tty`, `setup-security.sh` no-backup mutation of settings.json).
- **BREAKING CHANGES:**
  1. Default install mode now recommends `complement-sp`/`complement-gsd`/`complement-full` when the respective base plugin is detected — v3.x users upgrading without migration see duplicates until they run `migrate-to-complement.sh`.
  2. 7 files are no longer installed in `complement-sp` mode: `agents/code-reviewer.md`, `commands/{debug,plan,tdd,verify,worktree}.md`, `skills/debugging/SKILL.md` — users relying on TK's copies must use SP's equivalents.
  3. `manifest.json` schema bumped 1 → 2; any third-party tooling parsing manifest must handle the new `manifest_version` field and per-file `requires_base` / `conflicts_with` / `sp_equivalent` fields.
  4. `toolkit-install.json` state schema bumped 1 → 2; v1 installs read correctly via `jq '... // false'` backwards-compat default on the new `synthesized_from_filesystem` field, but v1 tooling reading the new field directly will see `null`.

### Install matrix (DOCS-04) — 12 cells

`{ standalone × complement-sp × complement-gsd × complement-full } × { fresh install, upgrade from v3.x, re-run idempotence }`

Each cell documents: precondition (what's on disk), command (exact `init-*.sh` invocation), expected stdout headline, expected `toolkit-install.json` mode field, expected files landed vs skipped, expected duplicates removed vs kept.

Source: Phase 3 SC-1..SC-5 (install flow) + Phase 4 SC-1..SC-6 (update flow) + Phase 5 SC-1..SC-5 (migration). All SC rows already validated in UAT → matrix is a presentation of already-verified behavior, not net-new validation.

### "Required Base Plugins" block shape (DOCS-02)

~15 lines, reused verbatim across all 7 templates:

```markdown
## Required Base Plugins

This toolkit complements two base plugins that provide core engineering workflows:

- **superpowers** (obra/superpowers) — TDD discipline, code review, debugging, writing plans
  Install: `claude plugin install superpowers@claude-plugins-official`
- **get-shit-done** (gsd-build/get-shit-done) — structured project workflows, phase execution, state tracking
  Install: `bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)`

If either is installed, run `bash <(curl -sSL .../scripts/init-claude.sh)` and the toolkit auto-selects the `complement-*` mode that skips duplicate files. Run `bash <(curl -sSL .../scripts/migrate-to-complement.sh)` if upgrading from TK v3.x.
```

Protection against drift: `make validate` grows a check — all 7 templates contain literal substring `## Required Base Plugins`.

### orchestration-pattern.md polish scope (DOCS-08)

- Mechanical fix: flatten nested `\`\`\`markdown inside \`\`\`bash` fences in the "Wiring it into your own slash command" section (lines 201–231) into separate siblings — clears 9 markdownlint errors.
- Content polish: cross-reference from `components/supreme-council.md` (orchestration-pattern is the generic form; Council is the multi-AI specialization) and from `components/structured-workflow.md` (orchestration-pattern is the micro-pattern; structured-workflow is the macro-pipeline).
- Register in `manifest.json` `files.components` array.
- README "Components" section: add a one-paragraph blurb + link.

</specifics>

<deferred>
## Deferred Ideas

- 9 non-English README translations (es, de, fr, pt, zh, ja, ko, ru, it) — backlog for v4.1 milestone.
- Backfill of 27 pre-existing components into `manifest.json` `files.components` — separate manifest-cleanup task, not Phase 6.
- Upstream PR to rtk-ai/rtk with LC_ALL=C fix for issue #1276 — out of scope; TK only documents the user-side workaround.
- Automated link-checker for README and CHANGELOG — considered for Phase 7 (Validation) if time permits.
- `docs/RELEASE-CHECKLIST.md` — owned by Phase 7 (VALIDATE-01), not Phase 6.

</deferred>

---

*Phase: 06-documentation*
*Context locked: 2026-04-19 via autonomous plan-phase*
