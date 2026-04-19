<!-- markdownlint-disable MD046 -->
<!-- MD046 disabled intentionally: §7 and §8 use indented code blocks to render
     markdown-with-nested-fences examples without triggering the fence-pair pathology
     documented in §9 Pitfall 1. Fenced style is used everywhere else in this file. -->

# Phase 6: Documentation — Research

**Researched:** 2026-04-18
**Domain:** Documentation authoring — README repositioning, changelog (Keep a Changelog), per-template sections, upstream plugin verification, markdownlint compliance
**Confidence:** HIGH (filesystem state verified; upstream rtk/caveman state fetched live 2026-04-18)

---

## User Constraints (from CONTEXT.md)

No CONTEXT.md exists for Phase 6 (standalone research before planning). Constraints are therefore derived from three authoritative sources already locked earlier in the milestone:

### Locked Decisions (inherited from milestone)

- **v4.0.0 is a breaking release** — `manifest.json`, `CHANGELOG.md`, `scripts/init-local.sh`, and every other version reference must align (ROADMAP Phase 7 SC-4, Phase 1 BUG-06 precondition).
- **Complement mode is the default behavior** when SP and/or GSD are detected (MODE-01..06, Phase 3).
- **`manifest.json` is the single source of truth** for file lists. Any new component added in Phase 6 (only `components/optional-plugins.md` is new per DOCS-05, and `components/orchestration-pattern.md` moves from "present but unregistered" to "manifest-registered" per DOCS-08) MUST be added to the manifest `files.components` (new key) or an existing bucket — not hand-listed anywhere else.
- **`make check` (markdownlint + shellcheck + validate) is CI-enforced** — every `.md` file must pass linting (`.markdownlint.json` rules); every `.sh` file must pass shellcheck.
- **Supreme Council stays inside TK** — Council is TK's killer feature (PROJECT.md); docs must feature it prominently as "unique TK value survives every install mode."
- **Filesystem detection only** — docs must NOT advertise `claude plugin list` as a detection signal for v4.0 (PROJECT.md "Out of Scope").

### Claude's Discretion (Phase 6 research identifies the following as open choices)

- Exact wording of the README "complement vs standalone" paragraphs (tone, length).
- Whether the install matrix lives in README or a new `docs/INSTALL.md` (DOCS-04 says "or section in README" — both acceptable).
- Exact shape of the "Required Base Plugins" template block (reuse one canonical block across 7 files vs author inline each; see §5 of this research — recommendation: single canonical block).
- Whether to land `components/optional-plugins.md` + `~/.claude/RTK.md` as net-new files or extend `templates/global/CLAUDE.md` with an RTK section (DOCS-07 specifies `~/.claude/RTK.md`; recommendation honors the spec).
- Wording of the "recommended optional plugins" block printed by `init-claude.sh` / `update-claude.sh` (DOCS-06).
- Whether to preserve the existing `README.md` "Killer Features" table or refactor (recommendation: preserve — already sells TK's unique value).
- Whether CHANGELOG 4.0.0 groups changes by phase (1–5) or by Keep-a-Changelog category (Added/Changed/Fixed/Breaking) — recommendation: Keep-a-Changelog category shape with a `### BREAKING CHANGES` subsection, consistent with existing entries (`[3.0.0]`, `[2.8.0]`, etc.).

### Deferred Ideas (OUT OF SCOPE)

- `components/optional-plugins.md` for plugins beyond rtk, caveman, superpowers, get-shit-done (DOCS-05 limits scope to these 4).
- Interactive install flow for the optional plugins block (DOCS-06 explicitly says "non-interactive — informational only, no auto-install").
- Refactoring `brain.py` to consume `tk-tools.sh init` (ORCH-FUT-03, v4.1).
- Landing `scripts/tk-tools.sh` (ORCH-FUT-02, v4.1).
- Non-English README translation (docs/readme/*.md) updates — v4.1 follow-up once English README has stabilized. English README.md is the authoritative source; the nine locale variants currently contain stale v3.x positioning and ideally track the English version, but synchronizing 9 files × "complement repositioning" × mdlint compliance is out of proportion for Phase 6 scope.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCS-01 | `README.md` repositions toolkit as "complement to `superpowers` + `get-shit-done`"; install section shows both modes with one-paragraph guidance | Current README is standalone-only; §1 Gap Analysis captures the specific changes; §5 design for complement paragraphs |
| DOCS-02 | Each `templates/*/CLAUDE.md` (7 stacks) gains a `## Required Base Plugins` section | Grep over 7 templates confirms NO existing `Required Base Plugins` section in any of them; §5 proposes a canonical single block |
| DOCS-03 | `CHANGELOG.md` `[4.0.0]` entry documents BREAKING CHANGES | Current CHANGELOG has `[Unreleased]` with only BUG-01..07 under Fixed; §2 catalogs all Phase 1–5 user-visible changes |
| DOCS-04 | `docs/INSTALL.md` (or README section) documents the 12-cell install matrix | `docs/INSTALL.md` does NOT exist yet; §3 enumerates all 12 cells from Phase 3/4/5 SUMMARIES |
| DOCS-05 | `components/optional-plugins.md` documents rtk + caveman with caveats | File does NOT exist yet; §4 has verified upstream state — requirement's caveman claims are partially incorrect, flagged for correction |
| DOCS-06 | `init-claude.sh` + `update-claude.sh` print "recommended optional plugins" block at end | Both scripts have clear end-of-run hook points (§6 identifies exact line numbers) |
| DOCS-07 | `~/.claude/RTK.md` template gains "Known Issues" section | File does NOT exist in `templates/global/` — must be created net-new; §7 proposes content skeleton |
| DOCS-08 | `components/orchestration-pattern.md` polished, registered in manifest, cross-referenced | File exists at 247 lines but has 9 markdownlint errors in the nested code block (lines 211–231); §8 identifies exact fixes + manifest wiring |

---

## Executive Summary

Phase 6 is pure documentation — no script behavior changes, no new libraries, no runtime surface. The phase polishes user-facing positioning (README, CHANGELOG, per-template base-plugin disclosure), introduces one new component (`components/optional-plugins.md`), one new template file (`templates/global/RTK.md`), one new docs page or README section (install matrix), and polishes one existing draft component (`orchestration-pattern.md` already in repo — needs 9 markdownlint fixes + manifest registration + cross-links).

**The single highest-impact finding:** the requirement text for DOCS-05 contains **two factual errors about upstream `caveman`** that the planner must correct before writing `components/optional-plugins.md`:

1. Requirement says "en + ru language modes (zh per upstream README)". **Upstream reality (verified 2026-04-18 via WebFetch on github.com/JuliusBrussee/caveman/blob/main/README.md):** caveman ships **en + wenyan (Classical Chinese)** — NOT Russian. The "zh" in the requirement almost certainly refers to the wenyan (文言文) mode.
2. Requirement says "`compress` mode rewrites CLAUDE.md so a backup is required first". **Upstream reality:** caveman-compress **automatically creates `CLAUDE.original.md` as a backup** — the user does not have to back up manually. The correct caveat is "caveman-compress requires you to commit CLAUDE.md to git FIRST so the original is version-controlled" (not "back up first").

Both corrections must be reflected in `components/optional-plugins.md` and in any init-script block that references caveman.

**Second high-impact finding:** `rtk` install command in the existing `README.md` (`brew install rtk`) is correct, but the README's "Note" about "RTK and cc-safety-net separate hooks" is ambiguous — Phase 6 should align it with DOCS-06's optional-plugins block wording.

**Third finding:** `orchestration-pattern.md` is already drafted and readable but has exactly 9 markdownlint errors in a single nested-code-block section (lines 201–231). The fix is mechanical: replace the nested ` ```markdown ... ```bash ... ``` ` structure with a flattened "Wiring it into your own slash command" section that uses numbered instructions and separate code fences rather than a markdown-inside-markdown example. Once lint passes, add to manifest and append cross-link references.

**Primary recommendation:** write a single canonical `## Required Base Plugins` block (~15 lines) and copy it verbatim into all 7 templates, so future SP/GSD install-command changes are one edit. Add a `files.components` bucket to `manifest.json` and register `optional-plugins.md` + `orchestration-pattern.md` + all 29 existing components.

---

## 1. Gap Analysis — Current State vs DOCS-01..08 Target State

### DOCS-01 — README complement repositioning

**Current state (README.md lines 1–166, verified 2026-04-18):**

- Line 16: "Solo developers building products with Claude Code" — no mention of SP/GSD.
- Lines 26–55: "Global Setup" has 3 subsections: Security Pack, RTK (already here), Statusline. **RTK is recommended but superpowers and get-shit-done are NOT mentioned anywhere in README.**
- Lines 57–75: "Installation (per project)" describes `init-claude.sh` but does NOT explain that four install modes exist, does NOT explain complement mode, does NOT mention SP/GSD auto-detection.
- Line 78: "Killer Features" table is intact — preserve.
- Line 126: "Structure After Installation" shows `.claude/` layout — still accurate for standalone mode; must be annotated for complement modes.

**Target state (DOCS-01):**

- New "Install Modes" subsection (or replace existing "Installation (per project)") showing the 4 modes with one-paragraph guidance each.
- Two primary paths: "I have/want superpowers and get-shit-done" (complement modes) vs "I don't" (standalone).
- "Structure After Installation" annotated to say "files marked †conflict with superpowers; omitted in complement-sp and complement-full modes."
- Forward pointer: "For the full install matrix and upgrade steps, see [docs/INSTALL.md](docs/INSTALL.md)" (or inline section anchor if we choose README-only).

**Gap:** ~30 lines to add/rewrite in README.md. No file creation.

---

### DOCS-02 — "Required Base Plugins" in 7 templates

**Current state (grep results, verified 2026-04-18):**

- Base template headings (`##` level, with trailing space): 19 sections, none named "Required Base Plugins" or similar.
- Laravel: 19 sections — no match.
- Rails: 19 sections — no match.
- Next.js: 19 sections — no match.
- Node.js: 19 sections — no match.
- Python: 19 sections — no match.
- Go: 19 sections — no match.

**Insertion point recommendation:** immediately after `## Project Overview` / `## 🎯 Project Overview` (line 3–11 depending on template), before `## 📌 Compact Instructions`. The section belongs at the top so new users see the prerequisite before reading any workflow detail.

**Target state (DOCS-02):** 7 templates each gain the same ~15-line block (see §5 for the canonical content). Maintenance burden: editing one canonical source is ideal, but the install scripts copy templates file-by-file, so the block must be present literally in each file.

**Gap:** 7 files × ~15 lines of new content, identical in each. High risk of drift if authored 7 times independently. §5 recommends a design that keeps them identical by construction.

---

### DOCS-03 — CHANGELOG 4.0.0 entry

**Current state (CHANGELOG.md lines 1–19):**

- Heading format follows Keep a Changelog: `## [X.Y.Z] - YYYY-MM-DD` with `### Added`, `### Changed`, `### Fixed`, `### Breaking Changes` (convention from historical entries).
- `## [Unreleased]` exists with `### Fixed` containing BUG-01..07 (Phase 1 output only).
- **Nothing from Phases 2, 3, 4, 5 is captured yet.** Manifest schema bump, detect.sh, install modes, update flow rewrite, migration script — all unrecorded.

**Target state (DOCS-03):**

- Rename `## [Unreleased]` to `## [4.0.0] - 2026-MM-DD` (date filled at Phase 7 release).
- Add `### BREAKING CHANGES` section listing: default mode changes, duplicates skipped in complement modes, manifest schema v1→v2, removed `VERSION="2.0.0"` hardcode in `init-local.sh`.
- Add `### Added` section listing: detect.sh, lib/install.sh, lib/state.sh, migrate-to-complement.sh, --mode flag, --dry-run, 14 Makefile test groups, `toolkit-install.json` state file, orchestration-pattern.md component, optional-plugins.md component, RTK.md template, per-template Required Base Plugins section.
- Add `### Changed` section listing: init-claude.sh refactored for 4 modes, update-claude.sh re-evaluates detection, settings.json safe merge, manifest-driven update loop (no more hand-lists), README repositioned as complement.
- Keep BUG-01..07 under `### Fixed`.

**Gap:** ~80–120 lines of new CHANGELOG content. Phase SUMMARY files (05-01/02/03, plus Phase 2/3/4) have all the content ready to consolidate — §2 catalogs it.

---

### DOCS-04 — Install matrix

**Current state:** `docs/INSTALL.md` does NOT exist (verified). `docs/howto/en.md` exists and is general (setup/troubleshooting), not an install matrix.

**Target state:** 12-cell matrix (4 modes × {fresh install, upgrade from v3.x, re-run / idempotent}) as a single table or 4 tables-by-mode. Each cell documents expected behavior, based on Phase 3/4/5 SC criteria.

**Gap:** Full new document (~100–150 lines) or a README section. §3 enumerates all 12 cells.

---

### DOCS-05 — `components/optional-plugins.md`

**Current state:** File does NOT exist. `caveman` is NOT referenced anywhere in the repo except in REQUIREMENTS.md/ROADMAP.md (0 grep hits outside planning docs). `rtk` IS referenced (25 files: README, 9 docs/readme/*, 8 docs/howto/*, security-hardening.md, mcp-servers-guide.md, scripts/setup-security.sh, scripts/verify-install.sh, and the two planning docs).

**Target state:** new `components/optional-plugins.md` with sections for `rtk`, `caveman`, `superpowers`, `get-shit-done`. Each section has: install command, purpose, caveats, known issues link. §4 provides verified upstream data.

**Gap:** Full new component (~150 lines). Must also add to `manifest.json` under a new `files.components` key (manifest doesn't have a components bucket yet — components/*.md are not currently manifest-registered).

---

### DOCS-06 — init/update scripts print optional-plugins block

**Current state (init-claude.sh lines 716–759, update-claude.sh):**

- `init-claude.sh` `main()` (line 717) calls `recommend_security` + `recommend_statusline` + `setup_council` + `create_post_install`. The "Next steps" block is at lines 729–744. The `POST_INSTALL.md` written at lines 762–811 is Claude-facing (not user-facing stdout).
- `update-claude.sh` `print_update_summary` is called at line 763 (last substantive line before EOF); `print_update_summary` is defined at line 209.

**Target state (DOCS-06):** each script prints a new "Optional Plugins" block (cyan/blue header, ~15 lines) at end of install/update run. Block is informational only — no `[y/N]` prompt, no auto-install.

**Gap:** ~15 lines of shell per script (2 scripts), plus a shared content source. §6 identifies exact line insertion points.

---

### DOCS-07 — `~/.claude/RTK.md` with Known Issues

**Current state:** `templates/global/` contains `CLAUDE.md`, `rate-limit-probe.sh`, `statusline.sh` — no `RTK.md`. The install for RTK is `rtk init -g` which creates a file at `~/.claude/RTK.md` per upstream (`rtk init -g` "Install[s] hook + RTK.md"). TK currently does NOT ship its own RTK.md.

**Target state (DOCS-07):** TK ships `templates/global/RTK.md` (net-new file) that gets copied to `~/.claude/RTK.md`. Includes a "Known Issues" section documenting rtk-ai/rtk#1276 (the `ls`-on-non-English-locale bug) and the workaround.

**IMPORTANT consideration:** `rtk init -g` creates its OWN `~/.claude/RTK.md`. If TK also installs one, the two will conflict. Two resolutions:

1. TK's RTK.md is a **supplement** file at a different path — e.g., `~/.claude/RTK-toolkit-notes.md` — and references the real rtk-maintained RTK.md. Safer (no overwrite risk).
2. TK's RTK.md is installed ONLY if `~/.claude/RTK.md` does not already exist (idempotent install guard). Matches the "don't overwrite user files" constraint from CLAUDE.md and Phase 3 SAFETY-01..04.

Phase 6 planning MUST pick one and document it in the plan. Recommendation: **option 2** — ship `templates/global/RTK.md`, install it to `~/.claude/RTK.md` only if absent, with clear comment header "This file is TK's fallback RTK.md. If you installed rtk and ran `rtk init -g`, rtk's version is authoritative; see the Known Issues section below regardless."

**Gap:** net-new file in `templates/global/RTK.md` (~60 lines) + install guard in `scripts/setup-security.sh` or a new `scripts/install-rtk-notes.sh` (latter adds scope; recommend folding into setup-security.sh or standalone optional install block). Manifest registration under `templates.global`.

---

### DOCS-08 — `orchestration-pattern.md` polish + manifest registration + cross-refs

**Current state (components/orchestration-pattern.md 247 lines, verified with markdownlint):**

- Content is fully drafted, readable, and correct.
- 9 markdownlint errors all clustered in lines 201–231: nested code block section "Wiring it into your own slash command". The nested ` ```markdown ... ```bash ... ``` ` pattern breaks the parser (ordered list numbering, fence pairing).
- NOT in `manifest.json` — grep for "orchestration-pattern" returns 0 hits in manifest.
- NOT referenced from `components/supreme-council.md` (0 hits) or `components/structured-workflow.md` (0 hits).
- The component's own "See also" section at lines 237–241 already references `supreme-council.md`, `structured-workflow.md`, and `commands/council.md` — **the cross-references are one-directional currently; DOCS-08 requires bidirectional**.

**Target state (DOCS-08):**

- 9 mdlint errors fixed (specific fix in §8).
- Added to `manifest.json` (requires a new `files.components` bucket — see §5 Manifest Design).
- `supreme-council.md` "See also" / bottom section gets "See also: orchestration-pattern.md — the lean-orchestrator + fat-subagents pattern Council implements".
- `structured-workflow.md` "See also" or integration section gets "See also: orchestration-pattern.md — scaling beyond a single agent's context window".
- `README.md` "Components" or feature section gets a short blurb + link.

**Gap:** mdlint fixes on ~30 lines; 1 new bucket in manifest; 2–3 sentences appended to 2 existing components; 1 blurb in README. §8 provides the exact content.

---

## 2. CHANGELOG Content Catalog — Phase 1–5 User-Visible Changes

This section catalogs every user-visible change from Phases 1–5 that must land in CHANGELOG.md `[4.0.0]`. Source: all SUMMARY files in `.planning/phases/*/` + current CHANGELOG `[Unreleased]`.

### BREAKING CHANGES (must lead the 4.0.0 entry — semver justification)

1. **Default install behavior changes when SP and/or GSD are detected.** Previously (v3.x) all 54 TK files installed unconditionally. v4.0 auto-selects `complement-*` mode and skips 7 files (6 commands/skills + 1 agent) that duplicate SP functionality. Users who relied on TK's `/debug`, `/plan`, `/tdd`, `/verify`, `/worktree`, `skills/debugging`, or the TK-owned `agents/code-reviewer.md` will instead use SP's equivalents. Override: `--mode standalone`.
2. **`manifest.json` schema bumped from v1 (implicit) to v2 (explicit `manifest_version: 2`).** Old v3.x install scripts refuse to run against a v2 manifest. Users running an old installer against the v4.0 repo see a hard error `manifest.json has manifest_version=2; this installer expects v1`. (Phase 2 MANIFEST-02.)
3. **`scripts/init-local.sh` no longer hardcodes version.** Reads from `manifest.json` at runtime via `jq`. Removal of `VERSION="2.0.0"` constant from line 11. (Phase 1 BUG-06.)
4. **`scripts/update-claude.sh` no longer hand-iterates a file list.** The iterated list now comes from `manifest.json`. Custom TK installs that relied on update-claude.sh skipping certain files will see those files installed on next update (if listed in manifest). (Phase 4 UPDATE-02.)
5. **`~/.claude/settings.json` is now merged additively.** `setup-security.sh` no longer overwrites the file — it reads, merges only TK-owned keys (permissions.deny, hooks.PreToolUse, env block), and writes via atomic temp-file rename. (Phase 3 SAFETY-01..04.)
6. **`scripts/setup-security.sh` creates a timestamped backup before every mutation.** Previously silent clobber; now `~/.claude/settings.json.bak.<unix-ts>` is written before any edit. Restore-from-backup on merge failure. (Phase 1 BUG-05.)
7. **Post-update summary format changed** from unstructured log lines to a 4-group block (`INSTALLED N`, `UPDATED M`, `SKIPPED P (with reason)`, `REMOVED Q (backed up to path)`). Users who scrape update output must adjust. (Phase 4 UPDATE-06.)
8. **Backup directory naming changed** from `~/.claude-backup-<unix-ts>/` to `~/.claude-backup-<unix-ts>-<pid>/` to prevent same-second collision. (Phase 4 UPDATE-05.)

### Added

- `scripts/detect.sh` — filesystem detection of `superpowers` and `get-shit-done`, sources `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` (Phase 2 DETECT-01..04).
- `scripts/lib/install.sh` — `recommend_mode`, `compute_skip_set`, `MODES` array (Phase 2 DETECT-05, Phase 3 MODE-01..06).
- `scripts/lib/state.sh` — atomic `write_state`, `acquire_lock`, `release_lock`, `sha256_file` (Phase 2 STATE-01..05, Phase 5 D-75 v2 extension).
- `scripts/migrate-to-complement.sh` — one-time migration script for v3.x users with SP/GSD installed; three-column hash diff, [y/N/d] prompt, cp -R full backup, write_state rewrite, idempotent (Phase 5 MIGRATE-01..06).
- `~/.claude/toolkit-install.json` — install state file: mode, detected bases, installed files + sha256, skipped files + reason (Phase 2 STATE-01..05). Schema version 2 adds `synthesized_from_filesystem` (Phase 5 D-75).
- 4 install modes: `standalone`, `complement-sp`, `complement-gsd`, `complement-full` (Phase 3 MODE-01).
- `--mode <name>` flag on `init-claude.sh` + interactive prompt + auto-recommendation (Phase 3 MODE-02/03).
- `--dry-run` flag on `init-claude.sh` — previews [INSTALL]/[SKIP] per file (Phase 3 MODE-06).
- `--offer-mode-switch=yes|no|interactive` + `--prune=yes|no|interactive` + `--no-banner` flags on `update-claude.sh` (Phase 4 UPDATE-01..04).
- `conflicts_with` + `sp_equivalent` + `requires_base` fields on per-file manifest entries (Phase 2 MANIFEST-01/03, Phase 5 D-71).
- `make validate-manifest.py` check — every manifest path exists, `conflicts_with` values are from known plugin set (Phase 2 MANIFEST-04).
- Makefile test targets: 14 test groups (up from 0), all hermetic, covering detect, install, state, update drift, update diff, update summary, migrate diff, migrate flow, migrate idempotence, and more (Phases 2–5).
- `components/orchestration-pattern.md` — lean orchestrator + fat subagents pattern (this phase DOCS-08 finalizes).
- `components/optional-plugins.md` — rtk, caveman, superpowers, get-shit-done recommendations (this phase DOCS-05).
- `templates/global/RTK.md` — fallback RTK notes with rtk-ai/rtk#1276 caveat (this phase DOCS-07).
- "Required Base Plugins" section in all 7 `templates/*/CLAUDE.md` files (this phase DOCS-02).

### Changed

- `scripts/init-claude.sh` — refactored to 4-mode dispatch; sources `detect.sh` + `lib/install.sh` from remote `$REPO_URL` on remote installs; respects `--mode` override; manifest-schema-v2 guard hard-fails on v1 manifests (Phase 3).
- `scripts/init-local.sh` — same mode-aware logic as init-claude.sh; reads version from manifest (Phase 1 BUG-06, Phase 3 MODE-05).
- `scripts/update-claude.sh` — rewritten for re-detection on every run, mode-drift surfacing, manifest-driven iteration, 4-group summary, D-77 migrate hint when triple-AND holds (Phase 4).
- `scripts/setup-security.sh` — safe settings.json merge with timestamped backup (Phase 1 BUG-05, Phase 3 SAFETY-01..04).
- `scripts/setup-council.sh` — `< /dev/tty` guards on every interactive `read`; silent `read -rs` for API-key prompts; `python3 json.dumps()` for API-key heredoc interpolation (Phase 1 BUG-02, BUG-03).
- `README.md` — repositioned as "complement to superpowers + get-shit-done"; install section shows standalone + complement modes (this phase DOCS-01).
- `manifest.json` — schema v2; 7 entries gain `conflicts_with`; 6 entries gain `sp_equivalent` (Phase 2 MANIFEST-01/03, Phase 5 D-71).

### Fixed

- BUG-01: BSD-incompatible `head -n -1` in `scripts/update-claude.sh` smart-merge replaced with POSIX `sed '$d'`. Silent CLAUDE.md truncation on macOS fixed.
- BUG-02: `< /dev/tty` guards on every interactive `read` in `scripts/setup-council.sh`; silent `read -rs` for API-key prompts. Fixes curl|bash prompts being consumed as stream.
- BUG-03: `python3 json.dumps` JSON-escapes API keys containing `"`, `\`, newline in heredoc-written `config.json`. Fixes malformed Council config.
- BUG-04: Silent `sudo apt-get install tree` in setup-council.sh replaced with interactive prompt + visible error path.
- BUG-05: `setup-security.sh` timestamped backup of `~/.claude/settings.json` before every mutation; restore-on-merge-failure.
- BUG-06: `scripts/init-local.sh` reads version from `manifest.json`; `make validate` enforces manifest ↔ CHANGELOG version alignment.
- BUG-07: `commands/design.md` added to update-claude.sh loop (structurally fixed in Phase 4 UPDATE-02: update loop iterates manifest, not hand-list).

---

## 3. Install Matrix — 12 Cells

All cell behaviors derived from Phase 3 SC-1..SC-5, Phase 4 SC-1..SC-5, Phase 5 SC-1..SC-5, and the SUMMARY files.

**Reading convention:** rows = 4 modes; columns = 3 scenarios (fresh install, upgrade from v3.x, re-run / idempotent behavior).

### Mode: `standalone` (no SP, no GSD, or user overrode)

| Scenario | Expected Behavior |
|----------|------------------|
| **Fresh install** | 54 files installed (all of `manifest.json`'s `files.*`). `toolkit-install.json` written with `mode: standalone`, `detected: {superpowers: {present: false}, gsd: {present: false}}`. Exit 0. `settings.json` merged (TK-owned keys only). |
| **Upgrade from v3.x** | v3.x users have no `toolkit-install.json`. `update-claude.sh` synthesizes state from disk (Phase 5 D-75 `synthesized_from_filesystem: true`). If SP/GSD NOT present, no mode switch offered; update proceeds in standalone mode. If D-77 triple-AND holds (standalone AND SP/GSD detected AND duplicates on disk), a single CYAN hint suggests running `./scripts/migrate-to-complement.sh`. No file removed without confirmation. Post-update 4-group summary. Backup created at `~/.claude-backup-<unix-ts>-<pid>/`. |
| **Re-run / idempotent** | `update-claude.sh` detects no manifest drift (compares `manifest_hash` in state file); prints "No-op — already up to date" and exits 0 without backup or changes. If manifest changed: applies diff (new files offered, removed files confirmed for deletion). |

### Mode: `complement-sp` (SP detected, GSD absent)

| Scenario | Expected Behavior |
|----------|------------------|
| **Fresh install** | 47 files installed; 7 skipped with `reason: conflicts_with superpowers` — `commands/{debug,plan,tdd,verify,worktree}.md`, `skills/debugging/SKILL.md`, `agents/code-reviewer.md`. `toolkit-install.json` written with `mode: complement-sp` + `skipped_files` populated. User's SP `code-reviewer` agent survives untouched. |
| **Upgrade from v3.x** | v3.x duplicate files present on disk. `update-claude.sh` D-77 hint fires (triple-AND holds). User runs `migrate-to-complement.sh`: three-column hash diff (TK template / on-disk / SP equivalent). `cp -R` full backup to `~/.claude-backup-pre-migrate-<unix-ts>/`. `[y/N/d]` per-file prompt (d shows diff, re-prompts). `toolkit-install.json` rewritten with `mode: complement-sp`. User-modified files warned with an extra line before the prompt. |
| **Re-run / idempotent** | `migrate-to-complement.sh` second run: reads state, finds `mode=complement-sp`, computes `compute_skip_set ∩ filesystem`, finds empty set → prints `Already migrated to complement-sp. Nothing to do.` exits 0 (SC-4 text invariant). No backup, no prompts. |

### Mode: `complement-gsd` (GSD detected, SP absent)

| Scenario | Expected Behavior |
|----------|------------------|
| **Fresh install** | All 54 TK files installed — **no files currently conflict with GSD** per `manifest.json` (all `conflicts_with` values point at `superpowers` only). `toolkit-install.json` records `mode: complement-gsd`, `detected.gsd.present: true`. Skipped files list is empty. Phase 2 MANIFEST-03 explicitly notes: "The original 13-entry seed list was fully evaluated; 7 confirmed SP equivalents, 6 TK-unique entries remain without `conflicts_with`." No confirmed GSD conflicts exist in the current manifest. Mode exists for future use and for `complement-full` composition. |
| **Upgrade from v3.x** | Same as fresh install for now (no files to remove since no GSD conflicts). `toolkit-install.json` state updated to `mode: complement-gsd`. |
| **Re-run / idempotent** | `update-claude.sh`: no-op if manifest unchanged. `migrate-to-complement.sh`: self-heal branch (`No duplicate files found on disk. Nothing to migrate.`) exit 0. |

### Mode: `complement-full` (both SP and GSD detected)

| Scenario | Expected Behavior |
|----------|------------------|
| **Fresh install** | Same 47 files as `complement-sp` install (SP conflicts skipped; no GSD conflicts currently). `toolkit-install.json` records `mode: complement-full`, both `detected.*.present: true`. |
| **Upgrade from v3.x** | Same as `complement-sp` upgrade — the 7 SP duplicates are the only files requiring migration. D-77 hint fires. |
| **Re-run / idempotent** | Same as `complement-sp`: "Already migrated to complement-full. Nothing to do." exit 0. |

**Matrix notes for planner:**

- The `complement-gsd` column is functionally identical to `standalone` in current manifest state (no GSD conflicts). Documentation should be honest about this: "complement-gsd currently behaves like standalone; the mode exists to compose with SP into complement-full and to accommodate future GSD conflict entries." This is not a documentation-only concern — it was explicitly noted in Phase 2 MANIFEST-03.
- All "upgrade from v3.x" cells assume a user with `./scripts/update-claude.sh` usage. Users who skip update and go straight to `init-claude.sh` (rare) hit the "fresh install" semantics regardless of prior v3.x state.
- All re-run cells assume `manifest.json` and `toolkit-install.json` are consistent. If a user manually edits state, the scripts self-heal (Phase 5 UAT-5 verified).

---

## 4. Optional Plugins — Upstream Verification (2026-04-18)

### rtk (rtk-ai/rtk) — VERIFIED

| Claim (DOCS-05 / existing README) | Upstream Status (2026-04-18) | Source |
|-----------------------------------|-------------------------------|--------|
| `brew install rtk` install command | CORRECT | github.com/rtk-ai/rtk/blob/master/README.md (WebFetch verified) |
| `rtk init -g` installs hook + RTK.md | CORRECT ("Install[s] hook + RTK.md") | Same |
| Issue #1276 still open | OPEN as of 2026-04-18. Title: "rtk ls returns '(empty)' for non-empty directories on non-English locales". | github.com/rtk-ai/rtk/issues/1276 (WebFetch verified) |
| Workaround is `exclude_commands = ["ls"]` in `~/Library/Application Support/rtk/config.toml` | **Partially correct.** The upstream issue's recommended fix is `cmd.env("LC_ALL", "C")` in Rust source code (not user-configurable). A user-side `exclude_commands` workaround DOES work (rtk's config supports this array per README), but it is NOT what the upstream issue recommends — it bypasses rtk's optimization for that command instead of fixing the bug. | Same issue thread + README |
| rtk config path on macOS: `~/Library/Application Support/rtk/config.toml` | CORRECT | README |
| `caveman` sits next to rtk in the optional-plugins recommendation | Caveman is a distinct, unrelated tool (Claude Code skill/plugin for token compression); no dependency on rtk. OK to co-recommend. | github.com/JuliusBrussee/caveman |

**Flag for planner:** the "Note" in current README.md lines 44–47 about RTK and cc-safety-net combined hook is correct (Phase 3 SAFETY work already routes them through a single PreToolUse entry). Preserve verbatim or reference `components/security-hardening.md` for the detail.

### caveman (JuliusBrussee/caveman) — VERIFIED WITH CORRECTIONS

| Claim (DOCS-05) | Upstream Status (2026-04-18) | Correction Required |
|-----------------|-------------------------------|---------------------|
| Language modes: "en + ru" | **INCORRECT.** Caveman ships **en + wenyan (Classical Chinese)**. No Russian mode. Intensity levels: Lite / Full (default) / Ultra; wenyan parallels: Wenyan-Lite / Wenyan-Full / Wenyan-Ultra. | Update to "en + wenyan (Classical Chinese)" |
| Language modes: "zh per upstream README" | Partially correct — "zh" in caveman is specifically Classical Chinese (文言文), not modern Chinese. | Rename to "wenyan (Classical Chinese)" for accuracy |
| `compress` mode rewrites CLAUDE.md so a backup is required first | **Partially misleading.** caveman-compress automatically creates `CLAUDE.original.md` as a human-readable backup. The user does NOT have to back up manually. | Correct caveat: "caveman-compress will auto-backup your `CLAUDE.md` to `CLAUDE.original.md`. Even so, commit your CLAUDE.md to git BEFORE running compress so you can diff or revert from version control." |
| Install command | Upstream install: `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman`. Requires Claude Code's plugin system. | Document this exact two-line install |
| Compression rate | ~46% input token reduction per upstream README ("~46% on average"). | Document the claim with attribution |

**Flag for planner:** the requirement text for DOCS-05 was drafted before upstream verification. The corrections above are load-bearing — shipping the incorrect "ru" claim would mislead users who speak Russian into thinking caveman supports their language, and the misleading "backup first" claim suggests caveman is destructive when it is not.

### superpowers (obra/superpowers) — CO-RECOMMENDATION

The optional-plugins block should list SP for the symmetric case: users who installed TK first, didn't install SP, and want to know about it. Install instructions from the official plugin marketplace:

```text
claude plugin marketplace add obra/superpowers
claude plugin install superpowers@superpowers
```

Purpose: shipped skills (systematic-debugging, writing-plans, test-driven-development, verification-before-completion, using-git-worktrees), agents (code-reviewer), commands. Complements TK perfectly since v4.0 toolkit is explicitly designed around SP.

### get-shit-done (gsd-build/get-shit-done) — CO-RECOMMENDATION

Same symmetric logic. Install via the official plugin marketplace (user confirms plugin name before install per CLAUDE.md typosquatting rule). Purpose: phase-based workflow (`/gsd-plan-phase`, `/gsd-execute-phase`, `/gsd-discuss-phase`, etc.). Complements TK for users who want structured multi-phase project work on top of the toolkit's framework templates.

---

## 5. Template Block Design — "Required Base Plugins"

**Design goal:** all 7 templates carry the SAME block, so future changes to SP/GSD install commands are one edit, not seven. Two options evaluated:

### Option A — Write once, copy verbatim (RECOMMENDED)

Author the canonical block in a single file under `components/` (e.g., `components/required-base-plugins.md`), then copy the content verbatim into each of the 7 `templates/*/CLAUDE.md` files. The copy is done by hand during Phase 6 (one-time) and manually re-synced if SP/GSD change.

**Pro:** Simple, no new infrastructure. Templates remain self-contained (the install scripts copy templates file-by-file; they don't compose).
**Con:** Drift risk if someone edits one file and forgets the other 6. Mitigated by: (a) `make validate` extension that greps for the block's signature line in all 7 files; (b) convention that the block is bracketed with an HTML comment marker.

### Option B — Include directive at install time

Use a sentinel in template `CLAUDE.md` like `<!-- INCLUDE: required-base-plugins.md -->` and have `init-claude.sh` substitute the file contents at install time.

**Pro:** No drift — single source of truth.
**Con:** New install-time indirection — breaks the current 1:1 "template → destination" model. Adds scope well beyond Phase 6. REJECTED.

**Recommended canonical block (15 lines):**

```markdown
## Required Base Plugins

This toolkit is designed to **complement** two Claude Code plugins. Install them first for
the full experience; TK will auto-detect them and skip duplicate files.

| Plugin | Purpose | Install |
|--------|---------|---------|
| `superpowers` (obra) | Skills (debugging, plans, TDD, verification, worktrees), `code-reviewer` agent | `claude plugin marketplace add obra/superpowers && claude plugin install superpowers@superpowers` |
| `get-shit-done` (gsd-build) | Phase-based workflow: `/gsd-plan-phase`, `/gsd-execute-phase`, and more | `claude plugin marketplace add gsd-build/get-shit-done && claude plugin install get-shit-done@get-shit-done` |

> **Without these plugins** TK still installs in `standalone` mode — you get every TK file,
> but you'll miss SP's systematic debugging and GSD's phase workflow. See
> [components/optional-plugins.md](.claude/components/optional-plugins.md) for the full rationale.
```

**Insertion point:** all 7 templates — immediately after `## Project Overview` / `## 🎯 Project Overview` (lines 3–11 depending on template), before the `## 📌 Compact Instructions` section.

**Drift protection proposal:** extend `scripts/validate-manifest.py` (or create a new `make validate-base-plugins` target) to grep each of the 7 `templates/*/CLAUDE.md` files for the exact string `## Required Base Plugins` and fail CI if any is missing. Low effort, high value.

### Manifest Design — add `files.components` bucket

`manifest.json` currently has buckets: `files.{agents, prompts, commands, skills, rules}` plus `templates.*`. **`components/*.md` is NOT currently manifest-registered** — init/update scripts don't copy components (they're reference material, not auto-installed into `.claude/`). However, Phase 6 DOCS-08 explicitly says `components/orchestration-pattern.md` must be "added to `manifest.json` under `components`".

Interpretation: add a new `files.components` key. Two sub-options:

1. **Register ALL 29 components** (full inventory, catches drift). Effort: ~30 lines of new manifest content.
2. **Register only the 2 Phase 6 components** (`optional-plugins.md`, `orchestration-pattern.md`). Effort: ~6 lines. Scope: narrow.

Recommendation: **option 2 for Phase 6 scope**. Full components registration is worthwhile but orthogonal; can ship as Phase 7 manifest-audit task or v4.1. Option 2 also avoids opening the question "do we install components into `.claude/` or not?" (answer: no, keep them in the repo's `components/` — `manifest.json` just tracks their existence for drift checks).

The new `files.components` entries:

```json
"components": [
  { "path": "components/orchestration-pattern.md" },
  { "path": "components/optional-plugins.md" }
]
```

Phase 7's `make validate-manifest.py` already checks every manifest path exists on disk (Phase 2 MANIFEST-04) — this integrates automatically.

---

## 6. Script Wiring — Where DOCS-06 Block Prints

### `scripts/init-claude.sh` — end-of-run hook

**Current end-of-run (lines 716–755, `main()` function):**

```text
main() {
    create_structure
    download_files
    create_gitignore
    create_scratchpad
    create_lessons_learned
    echo ""
    echo -e "${GREEN}╔═...Installation Complete!...═╗${NC}"
    echo ""
    echo "Next steps:" ...                    # line 729
    echo "Installed:" ...                     # line 733
    echo "Available commands:" ...            # line 736
    recommend_security                        # line 742
    recommend_statusline                      # line 743
    if [[ "$SKIP_COUNCIL" != true ]]; then
        setup_council                         # line 747
    fi
    echo "🔍 Verify installation: ..."        # line 751
    echo "⚠  Restart Claude Code ..."         # line 754
    create_post_install                       # line 758
}
```

**Recommended insertion point:** between `recommend_statusline` (line 743) and `setup_council` (line 747), or after `setup_council`. Recommendation: **between `recommend_statusline` and `setup_council`** — Council setup is the most interactive, so optional-plugins block is better placed before it (avoids confusing "more setup after Council" readability).

**Proposed function:**

```bash
# Show recommended optional plugins block (DOCS-06)
recommend_optional_plugins() {
    echo ""
    echo -e "${CYAN}🧩 Recommended optional plugins:${NC}"
    echo ""
    echo -e "  ${YELLOW}rtk${NC} — 60-90% token savings on dev commands"
    echo -e "    Install: ${YELLOW}brew install rtk && rtk init -g${NC}"
    echo -e "    ${RED}Known issue${NC}: rtk ls broken on non-English locales (rtk-ai/rtk#1276)"
    echo -e "    Workaround: add exclude_commands = [\"ls\"] to ~/Library/Application Support/rtk/config.toml"
    echo ""
    echo -e "  ${YELLOW}caveman${NC} — ~46% fewer input tokens per session"
    echo -e "    Install: ${YELLOW}claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman${NC}"
    echo -e "    ${YELLOW}⚠${NC} caveman-compress auto-backs up CLAUDE.md to CLAUDE.original.md; commit CLAUDE.md to git before running compress"
    echo -e "    Languages: en + wenyan (Classical Chinese)"
    echo ""
    echo -e "  ${YELLOW}superpowers${NC} (obra) — skills + code-reviewer agent (TK complements)"
    echo -e "    Install: ${YELLOW}claude plugin marketplace add obra/superpowers${NC}"
    echo ""
    echo -e "  ${YELLOW}get-shit-done${NC} (gsd-build) — phase-based workflow (TK complements)"
    echo -e "    Install: ${YELLOW}claude plugin marketplace add gsd-build/get-shit-done${NC}"
    echo ""
    echo -e "  ${BLUE}Details:${NC} see ${BLUE}.claude/components/optional-plugins.md${NC}"
}
```

**Note:** `CYAN='\033[0;36m'` is not defined in init-claude.sh currently — update-claude.sh defines it (line 31). Either define it in init-claude.sh (1 new line near line 14) or use `BLUE` instead.

### `scripts/update-claude.sh` — end-of-run hook

**Current end (lines 759–766):**

```text
jq --arg mh "$MANIFEST_HASH" '. + { manifest_hash: $mh }' "$STATE_FILE" > "$STATE_TMP"
mv "$STATE_TMP" "$STATE_FILE"
print_update_summary "$BACKUP_DIR"          # line 763
echo ""
# (end of file)
```

**Recommended insertion point:** **after** `print_update_summary` (line 763) — the 4-group summary should retain prominence; optional-plugins block is informational tail.

**Proposed:**

```bash
print_update_summary "$BACKUP_DIR"
echo ""
recommend_optional_plugins  # sourced from scripts/lib/optional-plugins.sh (new) or inline
```

**Shared content strategy:** the recommend_optional_plugins function is identical between init and update. Two options:

1. **Define it inline** in both scripts (duplicated ~25 lines each). Simple, no new infrastructure. Drift risk.
2. **Extract to `scripts/lib/optional-plugins.sh`**, source it in both scripts (similar to how both currently source `lib/install.sh` + `lib/state.sh`). Single source of truth. Adds a new lib file (+1 file to register in manifest `files.lib` or leave alongside others).

Recommendation: **option 2** — matches existing lib pattern, enables future edits in one place, follows Phase 2 D-30/D-31 DETECT-05 wiring style.

---

## 7. `templates/global/RTK.md` Content Skeleton

**File path:** `templates/global/RTK.md` (new, 60–80 lines)

**Install target:** `~/.claude/RTK.md` (global, not project-scoped)

**Install guard:** `setup-security.sh` or a dedicated installer copies only if `~/.claude/RTK.md` does NOT already exist. If it exists (rtk init -g installed it, or user edited theirs), the script prints a note and skips. **Never overwrite without explicit user consent** (CLAUDE.md safety rule).

**Content outline (proposed, shown as an indented block to avoid nested-fence rendering issues inside this research doc):**

    # RTK — Toolkit Notes (Claude Code)

    > Fallback notes when `rtk init -g` has not yet been run. If you installed rtk and ran
    > `rtk init -g`, rtk's own `~/.claude/RTK.md` is authoritative. The Known Issues section
    > below still applies regardless.

    ## What RTK Does

    RTK is a CLI proxy that reduces token consumption by 60–90% on common dev commands
    (`git status`, `cargo test`, `ls`, `grep`, etc.). Installs as a shell hook that
    transparently rewrites commands before they reach the Claude Code Bash tool.

    ## Quick Install

    ```bash
    brew install rtk
    rtk init -g   # installs hook + real RTK.md (overwrites this fallback)
    ```

    ## Known Issues

    ### rtk ls returns (empty) on non-English locales — rtk-ai/rtk#1276 (open as of 2026-04)

    **Symptom:** `rtk ls /tmp` prints `(empty)` even when the directory has files, if your
    system locale is non-English (e.g., `LANG=es_ES.UTF-8`).

    **Cause:** `rtk ls` parses `ls -la` output with an English-month regex. Non-English locales
    emit localized month names, so the regex misses every row.

    **Workaround (user-side, no code change):** disable RTK's ls optimization:

    ```bash
    # edit ~/Library/Application Support/rtk/config.toml (macOS)
    # or ~/.config/rtk/config.toml (Linux)
    exclude_commands = ["ls"]
    ```

    **Upstream fix:** issue tracks a one-line patch `cmd.env("LC_ALL", "C")` in the rtk source.
    Track status at github.com/rtk-ai/rtk/issues/1276.

    ## Relationship to Claude Code Safety Net

    RTK and the `cc-safety-net` hook both register against PreToolUse. If they run as separate
    hooks, their output conflicts. The Claude Code Toolkit's `setup-security.sh` installs a
    combined hook that sequences both. If you see duplicate rewrites or missed blocks, verify
    your `~/.claude/settings.json` has the combined hook and not two separate entries.

**Manifest registration:** add under `templates.global` or extend to `templates.global.files: [...]`. Effort: 1 new manifest entry.

**Install wiring:** `setup-security.sh` is the natural home (it already installs `templates/global/CLAUDE.md` sections into `~/.claude/CLAUDE.md`). Add a guarded copy of `templates/global/RTK.md` to `~/.claude/RTK.md` if absent.

---

## 8. `orchestration-pattern.md` Polish Plan

### Exact markdownlint errors (verified 2026-04-18)

```text
components/orchestration-pattern.md:211 MD031 (blanks-around-fences) "```"
components/orchestration-pattern.md:214 MD029 (ol-prefix) expected 1; got 2
components/orchestration-pattern.md:221 MD029 expected 2; got 3
components/orchestration-pattern.md:224 MD029 expected 3; got 4
components/orchestration-pattern.md:225 MD031 "```bash"
components/orchestration-pattern.md:229 MD029 expected 4; got 5
components/orchestration-pattern.md:230 MD032 (blanks-around-lists)
components/orchestration-pattern.md:231 MD031 "```"
components/orchestration-pattern.md:231 MD040 (fenced-code-language) missing language
```

All errors are in lines 201–231 (section "Wiring it into your own slash command"). Root cause: the section nests a \`\`\`markdown fenced block that contains an inner \`\`\`bash block. The outer fence is terminated by the inner \`\`\`, which confuses markdownlint's fence-pair tracker and cascade-fails ordered-list numbering (MD029) and list/fence spacing (MD031, MD032, MD040).

### Recommended fix

Replace the nested code block (lines 200–231) with a flattened section. Instead of showing "a markdown file containing a bash snippet" as a single fenced block, split into prose + separate fenced blocks. The rewritten section looks like this (shown here as an indented block so it renders safely inside this research document):

    ## Wiring it into your own slash command

    Minimum viable adaptation in a custom command at `commands/your-command.md`:

    ### 1. Load context

    Call your init helper at the top of the command and parse JSON for model names, paths, flags:

    ```bash
    INIT=$(node "$HOME/.claude/your-toolkit/bin/your-tools.cjs" init your-workflow)
    ```

    ### 2. Spawn subagents in parallel

    For each independent work unit, spawn a subagent with:

    - `subagent_type: <agent>` (defined in `~/.claude/agents/`)
    - `model: <from INIT>`
    - `prompt:` includes `<files_to_read>`, the work unit, and a `<quality_gate>` checklist
    - `run_in_background: true` so they parallelize

    ### 3. Collect confirmations

    Wait for each subagent. Read confirmation strings only — never the full transcript.

    ### 4. Commit atomically

    ```bash
    node "$HOME/.claude/your-toolkit/bin/your-tools.cjs" commit "your: short message" --files <produced-files>
    ```

    ### 5. Present next-up

    Tell the user what to run next.

Same information, no nested-fence pathology. All 9 mdlint errors in `components/orchestration-pattern.md` vanish. The indented-block rendering above is a research-doc convenience; the actual edit to `components/orchestration-pattern.md` uses real fenced blocks at the top level (no indentation).

### Manifest registration

Add under new `files.components` bucket (see §5 Manifest Design). 1-line entry.

### Cross-reference additions

Append to `components/supreme-council.md` (end of file, after the "Add to CLAUDE.md" block at line 274):

```markdown
## See Also

- [orchestration-pattern.md](./orchestration-pattern.md) — lean-orchestrator + fat-subagents
  pattern that Council implements. Explains why `brain.py` spawns Gemini and ChatGPT as
  parallel subagents rather than calling them sequentially from one context.
```

Append to `components/structured-workflow.md` (end of file, after line 253 "Example Flow" section):

```markdown
## See Also

- [orchestration-pattern.md](./orchestration-pattern.md) — scaling multi-step workflows
  **beyond a single agent's context window**. Structured Workflow disciplines a single
  context; orchestration-pattern delegates across many fresh contexts. Complementary patterns.
```

### README "Components" blurb

Insert in README.md after line 90 ("See [detailed descriptions and examples]...") or in a new short "Components" section. Proposed blurb:

```markdown
**Orchestration pattern** — see [components/orchestration-pattern.md](components/orchestration-pattern.md)
for the lean-orchestrator + fat-subagents design Council and GSD workflows both use.
Helps any custom slash command scale beyond a single context window.
```

---

## 9. Pitfalls & Gotchas

### Pitfall 1: Markdownlint nested-fence pathology

**What goes wrong:** A \`\`\`markdown fenced block that contains an inner \`\`\`bash fenced block is closed by the inner ``` — not by the later outer ```. Markdownlint and most renderers misinterpret the structure, cascading into MD029/MD031/MD032/MD040 errors.

**How to detect early:** run `markdownlint <file>` BEFORE committing any doc with nested code examples. `make check` in CI catches it but the feedback loop is slow.

**Fix pattern:** flatten. Never show "a markdown file with a code block inside" as a single fence. Use prose + separate fenced blocks at the same depth.

**Evidence:** `components/orchestration-pattern.md` lines 201–231 — see §8.

### Pitfall 2: Markdownlint MD026 (no-trailing-punctuation-in-headings)

**What goes wrong:** `## What is this?`, `## Installation.`, `## Done!` all fail MD026. The `.markdownlint.json` rule disables some rules but NOT MD026.

**Fix pattern:** phrase headings declaratively. "What This Is", "Installation", "Done".

**Evidence:** CLAUDE.md (`templates/base/CLAUDE.md`) already follows this convention; preserve it in all new headings.

### Pitfall 3: Markdownlint MD040 (fenced-code-language)

**What goes wrong:** ```\n some_code \n``` fails — the fence must declare a language even for plain output. `.markdownlint.json` does NOT disable MD040.

**Fix pattern:** use `bash`, `text`, `json`, `javascript`, `typescript`, `php`, `python` — whichever fits. For pure ASCII-art or shell output, use `text`.

**Evidence:** Phase 5 SUMMARY files use ```text for ASCII-art blocks (e.g., 05-01 line 7 area).

### Pitfall 4: Markdownlint MD031/MD032 (blank lines around fences/lists)

**What goes wrong:** a line of prose directly touching a ``` opener or a `-` list item.

**Fix pattern:** always blank-line-separate prose from fences and lists. Even nested lists sometimes need it.

**Evidence:** all 9 orchestration-pattern.md errors are MD031/MD032/MD029/MD040 — see §8.

### Pitfall 5: `manifest.json` single-source-of-truth drift

**What goes wrong:** a new component authored in `components/` doesn't make it into `manifest.json`. CI's `make validate-manifest.py` only checks manifest paths exist — it does NOT check that every file on disk is in the manifest (that check would require a reverse walk, which is NOT currently implemented).

**Fix pattern:** whenever a new `components/*.md`, `scripts/*.sh`, or `templates/*` file lands, add to manifest in the same commit. Phase 6 adds 2 component entries and 1 template-global entry.

**Evidence:** `components/orchestration-pattern.md` has been in the repo since 2026-04-14 and is NOT yet in manifest — DOCS-08 finally fixes this.

### Pitfall 6: CHANGELOG version alignment (Phase 1 BUG-06)

**What goes wrong:** `manifest.json` says `3.0.0`, `init-local.sh` says `2.0.0`, CHANGELOG `[Unreleased]` is empty. Install scripts report different versions than the manifest.

**Fix pattern (Phase 1 fix, still enforced):** `make validate` now runs a manifest ↔ CHANGELOG alignment check. CHANGELOG `[X.Y.Z]` heading must match `manifest.version`. DOCS-03 MUST land the version bump in lockstep: `manifest.json` → `4.0.0`, CHANGELOG `[Unreleased]` → `[4.0.0]`, `scripts/init-local.sh` — no change (already reads manifest).

**Evidence:** `.github/workflows/quality.yml` + `make validate` target (Phase 1 Plan 01-05).

### Pitfall 7: Bash heredoc quoting of plugin install commands

**What goes wrong:** a "recommended plugin" block printed by a shell script can interpolate `$`-prefixed strings in install commands. `$HOME`, `$SHELL`, and (if mistyped) `$marketplace_name` would expand unexpectedly.

**Fix pattern:** quote all install commands with single quotes within `echo -e "..."` contexts, or use `printf '%s\n' 'literal text with $VAR'`. Safer still: escape `\$` for every literal `$` in install commands.

**Evidence:** DOCS-06 block prints `claude plugin marketplace add JuliusBrussee/caveman` — this specific line has no `$` so it's safe, but the drift risk is real when plugins change.

### Pitfall 8: Incorrect upstream claims (caveman en+ru)

**What goes wrong:** writing documentation from requirement text without upstream verification. The requirement for DOCS-05 claims caveman supports Russian. Upstream reality: caveman supports en + wenyan. Publishing the wrong claim misleads users.

**Fix pattern:** ALWAYS verify upstream claims with a live fetch during research phase. Document the fetch date and URL in RESEARCH.md so the plan inherits the current truth, not the stale requirement.

**Evidence:** §4 Upstream Verification — flagged before any documentation file is authored.

### Pitfall 9: `~/.claude/RTK.md` overwrite collision

**What goes wrong:** TK ships `templates/global/RTK.md` and installs to `~/.claude/RTK.md`. User previously ran `rtk init -g` which already created `~/.claude/RTK.md`. TK's version silently clobbers rtk's (or vice versa on next rtk update).

**Fix pattern:** `setup-security.sh` install of TK's RTK.md MUST check `[ ! -f ~/.claude/RTK.md ]` before copy. Print an info line if skipped so the user knows rtk's version is authoritative.

**Evidence:** §7 explicitly calls for this guard.

### Pitfall 10: Templates drift in the Required Base Plugins block

**What goes wrong:** §5 recommends copying a canonical block into all 7 templates. Over time, 2 get edited and 5 get missed. Future installs show inconsistent plugin recommendations.

**Fix pattern:** add a `make validate-base-plugins` (or extend `validate`): grep every `templates/*/CLAUDE.md` for the sentinel line `## Required Base Plugins` + for the install command signatures. Fail CI if any template is missing. Lightweight (~20 lines of bash).

**Evidence:** §5 Drift Protection Proposal.

### Pitfall 11: Nine non-English README translations drift

**What goes wrong:** Phase 6 edits `README.md` (English) but leaves `docs/readme/ru.md`, `docs/readme/zh.md`, `docs/readme/de.md`, `docs/readme/fr.md`, `docs/readme/es.md`, `docs/readme/pt.md`, `docs/readme/ja.md`, `docs/readme/ko.md` at the v3.x positioning. Non-English users see the old standalone-only story.

**Fix pattern:** either sync all 9 (large scope) or mark them stale in a header note ("English README is authoritative for v4.0; translations pending"). Phase 6 scope is English-only per §Deferred Ideas; plan MUST state this explicitly.

**Evidence:** `docs/readme/*.md` are all pre-v4.0 and will fall out of sync the moment English README is updated.

---

## 10. Validation Architecture (Nyquist enabled)

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `make` + shellcheck + markdownlint-cli + custom `validate-manifest.py` + 14 bash test scripts in `scripts/tests/` |
| Config files | `.markdownlint.json`, `Makefile`, `.github/workflows/quality.yml`, `.pre-commit-config.yaml` |
| Quick run command | `make mdlint` (fastest — just markdownlint) or `make validate` (includes manifest alignment) |
| Full suite command | `make check` (= `make lint validate`) OR `make test` (14 test groups + lint + validate) |
| Phase 6-specific | `markdownlint components/optional-plugins.md components/orchestration-pattern.md templates/global/RTK.md README.md CHANGELOG.md` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-01 | README repositioned as complement | manual (prose review) + mdlint | `markdownlint README.md` | exists ✅ |
| DOCS-02 | 7 templates have `## Required Base Plugins` | grep + mdlint | `for f in templates/*/CLAUDE.md; do grep -q '## Required Base Plugins' "$f" \|\| echo "MISSING: $f"; done` | templates exist ✅ |
| DOCS-03 | CHANGELOG 4.0.0 entry with BREAKING CHANGES | mdlint + manifest-version-alignment check | `make validate` (Phase 1 BUG-06 alignment check) | exists ✅ |
| DOCS-04 | Install matrix present (docs/INSTALL.md or README) | manual + mdlint | `markdownlint docs/INSTALL.md` (if chosen) | ❌ create new |
| DOCS-05 | `components/optional-plugins.md` exists + lints | mdlint | `markdownlint components/optional-plugins.md` | ❌ create new |
| DOCS-06 | `init-claude.sh` + `update-claude.sh` print block | shellcheck + manual stdout inspection | `bash scripts/init-claude.sh --dry-run 2>&1 \| grep -A20 "Recommended optional plugins"` | ✅ (modify) |
| DOCS-07 | `templates/global/RTK.md` exists + lints | mdlint | `markdownlint templates/global/RTK.md` | ❌ create new |
| DOCS-08 | orchestration-pattern.md lints + registered + cross-linked | mdlint + grep | `markdownlint components/orchestration-pattern.md` AND `grep -q orchestration-pattern manifest.json components/supreme-council.md components/structured-workflow.md README.md` | ✅ (polish) |

### Sampling Rate

- **Per task commit:** `make mdlint` (covers DOCS-01..08 file-level), `make validate` (covers manifest alignment + DOCS-03).
- **Per wave merge:** `make check` (lint + validate full suite).
- **Phase gate:** `make check` AND `make test` (full 14 test groups) AND manual review of rendered README/CHANGELOG.
- **Before `/gsd-verify-work`:** `make check` green + visual confirmation of render in GitHub UI.

### Wave 0 Gaps

Phase 6 files to create before verification can run:

- [ ] `components/optional-plugins.md` — net-new (DOCS-05)
- [ ] `templates/global/RTK.md` — net-new (DOCS-07)
- [ ] `docs/INSTALL.md` — net-new IF we pick the standalone-file option for DOCS-04 (README-section option skips this)
- [ ] `.planning/phases/06-documentation/` planning directory already created

Existing files to modify (NO Wave 0 gaps; already exist and ready for edit):

- `README.md`, `CHANGELOG.md`, `manifest.json`, `components/orchestration-pattern.md`, `components/supreme-council.md`, `components/structured-workflow.md`, `scripts/init-claude.sh`, `scripts/update-claude.sh`, all 7 `templates/*/CLAUDE.md` files.

New validation-helper consideration (optional but recommended):

- [ ] `make validate-base-plugins` target — greps all 7 templates for Required Base Plugins section (Pitfall 10 prevention). Bash, ~20 lines. Not strictly required for DOCS-02 compliance, but insulates future contributors from drift.

---

## 11. Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 6 is pure documentation — no auth surface |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | No access control |
| V5 Input Validation | partial | Install scripts already validate --mode input (Phase 3); Phase 6 adds no new input paths |
| V6 Cryptography | no | No crypto |
| V7 Error Handling / Logging | partial | Optional-plugins block prints to stdout; must not print secrets — easy to satisfy |
| V14 Configuration | yes | DOCS-07 installs `templates/global/RTK.md` to `~/.claude/`; must follow existing "never overwrite user files without confirmation" invariant (Phase 3 SAFETY rules) |

### Known Threat Patterns for Phase 6 stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| User-file overwrite during RTK.md install | Tampering | `[ ! -f ~/.claude/RTK.md ]` guard before copy (Pitfall 9 in §9) |
| Malicious upstream plugin install | Tampering | Optional-plugins block recommends plugins BY NAME only — user installs via `claude plugin marketplace add` which uses Claude Code's own plugin trust model. TK does NOT auto-install any plugin. Explicit in DOCS-06 wording. |
| Outdated upstream claim (caveman ru) | Information Disclosure / Integrity | Live-fetched upstream verification in §4; documentation carries a "verified YYYY-MM-DD" timestamp so future contributors re-verify before v4.1 doc updates. |
| Prompt injection via Required Base Plugins block | Tampering | The canonical block (§5) contains no user-controllable data. It's hardcoded literal text. No injection surface. |
| Secret leakage in update-claude.sh optional-plugins stdout | Information Disclosure | The proposed `recommend_optional_plugins` function (§6) prints only literal strings. No variable expansion of anything that could contain a secret. Zero surface. |

### Project-specific security constraints (from CLAUDE.md global rules)

- All install commands MUST use HTTPS (already enforced in `init-claude.sh` `REPO_URL`).
- No `eval`, `exec`, `system` with user-derived data — not introduced by Phase 6.
- Heredoc/string-interpolation safety — `components/optional-plugins.md` and the script blocks use only literal text, no variable interpolation of user input.

---

## 12. Assumptions Log

All claims in §§1–11 are either verified (filesystem-grepped or live-WebFetched) or directly cited from Phase 1–5 SUMMARY files. The following are the ONLY items tagged `[ASSUMED]` and require user confirmation before the planner locks them:

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SP install command is `claude plugin marketplace add obra/superpowers && claude plugin install superpowers@superpowers` | §4, §5 canonical block, §6 init block | If the exact marketplace/plugin name differs, users will see a "plugin not found" error on install. LOW risk — matches TK's existing expectations for SP, and the name `superpowers` is referenced repeatedly in manifest and requirements. Verify with `claude plugin marketplace list` or obra/superpowers README before release. |
| A2 | GSD install command is `claude plugin marketplace add gsd-build/get-shit-done && claude plugin install get-shit-done@get-shit-done` | §4, §5, §6 | Same as A1 — LOW risk. Name matches repo path and toolkit-wide references. Verify before release. |
| A3 | `docs/INSTALL.md` is the preferred artifact for DOCS-04 over a README section | §1, §2 | If discussion-phase prefers README-only, no new file is created; content moves inline. COSMETIC — the cell content (§3) is identical either way. |
| A4 | Recommendation to register only 2 components (not all 29) in `files.components` | §5 Manifest Design | If a broader registration policy is desired, Phase 6 scope expands by ~30 lines of manifest edits. LOW risk — orthogonal to DOCS-05/08 completion. |
| A5 | `recommend_optional_plugins` extracts to `scripts/lib/optional-plugins.sh` (vs inline duplication) | §6 | If user prefers inline (simpler), skip the new lib file. LOW risk — both work. |
| A6 | `templates/global/RTK.md` installed via `setup-security.sh` (vs a dedicated `install-rtk-notes.sh`) | §7 | If the user wants a separate script, Phase 6 scope grows. LOW risk — install line is ~5 bash lines either way. |
| A7 | Non-English README translations (docs/readme/*.md) are OUT OF SCOPE for Phase 6 | Deferred Ideas | If user expects translations updated, scope grows ~9 files. MEDIUM risk — translation quality and maintenance burden are their own question. |
| A8 | `components/orchestration-pattern.md` polished in-place (not rewritten) | §8 | If the user wants a bigger rewrite, scope grows. LOW risk — current content is correct, just has mdlint bugs. |

If any of A1–A8 is wrong, the planner should address it in CONTEXT.md before authoring PLAN.md. All other claims in the document are verified.

---

## 13. Open Questions

1. **DOCS-04 delivery channel — `docs/INSTALL.md` vs README section.**
   - What we know: requirement says "docs/INSTALL.md (or section in README)". Both are acceptable.
   - What's unclear: which does the user prefer?
   - Recommendation: ship `docs/INSTALL.md` as a standalone file. README gets a 3-line teaser + link. Rationale: README is already dense (166 lines); the 12-cell matrix would bloat it. A standalone page is easier to bookmark/search. Keep the matrix rich without distorting README scan-readability.

2. **DOCS-06 content-sharing strategy — inline vs `scripts/lib/optional-plugins.sh`.**
   - What we know: both init-claude.sh and update-claude.sh should print the same block.
   - What's unclear: whether the user wants a new lib file (matches Phase 2/4 lib pattern) or accepts inline duplication (minimal-change).
   - Recommendation: new lib file (§6).

3. **DOCS-07 install mechanism — new script vs fold into setup-security.sh.**
   - What we know: `templates/global/RTK.md` needs an install path.
   - What's unclear: whether the user wants a dedicated `scripts/install-rtk-notes.sh` or folding into setup-security.sh.
   - Recommendation: fold into setup-security.sh (global setup is already this script's job). Guard with `[ ! -f ~/.claude/RTK.md ]`. Single point of install discoverability.

4. **Non-English README translations update scope.**
   - What we know: 9 translations under `docs/readme/*.md` are currently v3.x positioning.
   - What's unclear: does Phase 6 fix 1 (English) or 10 (English + 9 translations)?
   - Recommendation: Phase 6 = English only. Add an explicit "last sync" note at the top of each non-English file. Full translation refresh is v4.1 scope.

5. **DOCS-03 — Phase-grouped vs Keep-a-Changelog-grouped.**
   - What we know: historical entries (3.0.0, 2.8.0, 2.6.0, etc.) all use Keep-a-Changelog categories.
   - What's unclear: for a 5-phase breaking release, do we add a phase-grouped "Summary" preamble for discoverability?
   - Recommendation: lead with a BREAKING CHANGES section, follow Keep-a-Changelog categories (Added / Changed / Fixed), DO add a brief "Migration from v3.x" subsection at the end with a one-line link to `./scripts/migrate-to-complement.sh` and `docs/INSTALL.md`.

6. **`components/optional-plugins.md` placement — dedicated section vs folded into existing mcp-servers-guide.md.**
   - What we know: requirement DOCS-05 explicitly names a new file.
   - What's unclear: whether the user wants to avoid a 30th component.
   - Recommendation: new file per the requirement. Scope and cross-discoverability justify the separate file.

---

## 14. Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `markdownlint-cli` | `make mdlint`, CI | already required by project | managed via `npm install -g` (`make install`) | — |
| `shellcheck` | `make shellcheck`, CI | already required by project | managed via `brew install shellcheck` / `apt-get` | — |
| `python3 >= 3.8` | `validate-manifest.py`, Council | already required | — | — |
| `jq` | `init-claude.sh`, `update-claude.sh`, `migrate-to-complement.sh` | already required (mentioned in `install-statusline.sh:31-40`) | — | — |
| WebFetch / WebSearch | Upstream verification (§4) | used during this research | — | — (research-time only, not a runtime dependency) |
| `claude` CLI (for plugin install commands in docs) | documentation only | user-side; not a TK dependency | — | — (docs reference, TK never invokes `claude` CLI) |

No Phase 6 external runtime dependencies beyond what the toolkit already requires. All additions are files (Markdown + shell-print strings + manifest entries).

---

## 15. Sources

### Primary (HIGH confidence)

- **Filesystem inspection** (2026-04-18):
  - `.planning/REQUIREMENTS.md` (DOCS-01..08 canonical text)
  - `.planning/ROADMAP.md` (Phase 6 description + SC-1..SC-6)
  - `.planning/PROJECT.md` (core value, out-of-scope list, key decisions)
  - `.planning/STATE.md` (Phase 5 complete, Phase 6 not started)
  - `.planning/phases/05-migration/05-{01,02,03}-SUMMARY.md` (Phase 5 outputs)
  - `.planning/phases/05-migration/05-HUMAN-UAT.md` (5 UAT outcomes, TTY-manual carry-over)
  - `README.md` (current positioning gap)
  - `CHANGELOG.md` (Unreleased entry with BUG-01..07 only)
  - `manifest.json` (v2 schema, 54 registered files, no components bucket)
  - `templates/{base,laravel,rails,nextjs,nodejs,python,go}/CLAUDE.md` (19-section structure, no Required Base Plugins anywhere)
  - `templates/global/{CLAUDE.md,rate-limit-probe.sh,statusline.sh}` (no RTK.md file)
  - `components/{orchestration-pattern,supreme-council,structured-workflow,README}.md`
  - `scripts/{init-claude,update-claude}.sh` (end-of-run hook points identified)
  - `.planning/config.json` (nyquist_validation: true)
  - `Makefile`, `.markdownlint.json`, `.github/workflows/quality.yml` (validation surface)

- **Live markdownlint output** against `components/orchestration-pattern.md` — 9 errors, line numbers captured verbatim in §8.

### Secondary (MEDIUM–HIGH confidence)

- **WebFetch 2026-04-18** — `github.com/JuliusBrussee/caveman/blob/main/README.md`
  - Modes: Lite/Full/Ultra + Wenyan variants (NOT en + ru as the requirement claims)
  - Install: `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman`
  - Compress auto-backs up to `CLAUDE.original.md`
- **WebFetch 2026-04-18** — `github.com/rtk-ai/rtk/issues/1276`
  - Title: "rtk ls returns '(empty)' for non-empty directories on non-English locales"
  - Status: OPEN
  - Upstream fix: `cmd.env("LC_ALL", "C")` in Rust source
- **WebFetch 2026-04-18** — `github.com/rtk-ai/rtk/blob/master/README.md`
  - Install: `brew install rtk`
  - macOS config path: `~/Library/Application Support/rtk/config.toml`
  - `rtk init -g` installs hook + RTK.md
  - `exclude_commands = [...]` config key supported

### Tertiary (LOW confidence / inferred)

- SP install command `claude plugin marketplace add obra/superpowers && claude plugin install superpowers@superpowers` — matches manifest references and is the TK's project-wide convention, but not fetched from obra/superpowers README in this research session. **Verify before release.** (Assumption A1.)
- GSD install command `claude plugin marketplace add gsd-build/get-shit-done && claude plugin install get-shit-done@get-shit-done` — same as A1. **Verify before release.** (Assumption A2.)

---

## 16. Metadata

**Confidence breakdown:**

- Gap analysis (§1): HIGH — filesystem state fully verified by Grep/Read
- CHANGELOG content catalog (§2): HIGH — sourced from Phase 1–5 SUMMARY files verbatim
- Install matrix (§3): HIGH — derived from Phase 3/4/5 SC criteria
- Optional plugins upstream state (§4): HIGH for rtk, HIGH for caveman (live-fetched); MEDIUM for SP/GSD install commands (inferred from repo-wide conventions)
- Template block design (§5): HIGH — recommendation grounded in current template structure
- Script wiring (§6): HIGH — line numbers and function names verified
- RTK.md skeleton (§7): MEDIUM — content is my proposal, format follows existing templates/global convention
- Orchestration polish (§8): HIGH — exact mdlint errors captured; fix is mechanical
- Pitfalls (§9): HIGH — grounded in verified current-state evidence
- Validation architecture (§10): HIGH — matches Phase 1–5 validation patterns
- Security domain (§11): HIGH — no new attack surface
- Assumptions (§12): LOW to MEDIUM — A1–A8 flagged for user confirmation
- Open questions (§13): by construction open

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — docs claims about upstream caveman and rtk should be re-verified if Phase 6 drags past this window)

---

*Phase 6 research complete. Planner can now author PLAN.md files. Recommended plan structure (3 plans):*

- *06-01: Core text (README + CHANGELOG + 7 template Required Base Plugins blocks + install matrix file/section)*
- *06-02: New components (optional-plugins.md + templates/global/RTK.md + manifest registration)*
- *06-03: Polish & wiring (orchestration-pattern.md fix + cross-refs + DOCS-06 script blocks)*

*Parallelization: 06-01 and 06-02 can run in the same wave (independent files). 06-03 depends on 06-02 (needs optional-plugins.md to exist for its cross-references). Wave structure: Wave 1 = {06-01, 06-02}, Wave 2 = {06-03}.*
