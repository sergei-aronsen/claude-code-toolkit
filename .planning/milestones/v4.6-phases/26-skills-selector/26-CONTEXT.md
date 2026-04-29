# Phase 26: Skills Selector - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

A developer running `scripts/install.sh --skills` browses a curated 22-skill marketplace mirror via TUI checklist, selects skills to install, and the orchestrator copies each from `templates/skills-marketplace/<name>/` to `~/.claude/skills/<name>/`. Skills become loadable by Claude Code immediately. Re-running without `--force` skips already-installed; with `--force` overwrites. Mirror is version-pinned (snapshot in repo) with re-sync helper.

Out of scope: marketplace publishing (Phase 27), Desktop-specific routing (Phase 27 DESK-03), MCP installation (Phase 25), skill authoring tooling.
</domain>

<decisions>
## Implementation Decisions

### Mirror Architecture
- **Snapshot (not on-demand fetch):** Skill content committed to `templates/skills-marketplace/<name>/`. Version-pinned, offline-installable, git-trackable diffs. Trade-off: repo size grows; acceptable since each skill is small markdown.
- **Re-sync via `scripts/sync-skills-mirror.sh`:** Manual one-shot script. Pulls fresh content from skills.sh upstream, updates `docs/SKILLS-MIRROR.md` mirror-date. Documented for maintainers.
- **Content sourcing:** Skills already installed locally in `~/.claude/skills/` are sourced from there directly; remaining skills fetched from skills.sh upstream. The sync script handles both code paths transparently.

### License Preservation
- **Per-skill LICENSE file:** Each `templates/skills-marketplace/<name>/` directory ships with a `LICENSE` file copied from upstream. If upstream lacks a LICENSE, fall back to `SKILL-LICENSE.md` quoting the SKILL.md frontmatter `license:` field (or note "License not provided upstream — included under fair use mirror exception").
- **`docs/SKILLS-MIRROR.md`:** Records upstream URL + mirror-date + license type for each of the 22 skills. Updated by `sync-skills-mirror.sh`.

### Install Mechanics
- **Probe:** `is_skill_installed <name>` checks `[ -d ~/.claude/skills/<name>/ ]`. Three-state return matches `is_mcp_installed` pattern (0=installed, 1=not-installed, 2=N/A — unused for skills since no CLI dependency).
- **Copy:** `cp -R templates/skills-marketplace/<name>/. ~/.claude/skills/<name>/` (the trailing `/.` ensures directory contents copy correctly).
- **`--force` semantics:** Without `--force`, skip installed skills with log line `→ <name>: already installed (skip)`. With `--force`, `rm -rf` target directory first, then copy. Mirrors Phase 24's component install behavior.
- **TK_SKILLS_HOME seam:** Override `~/.claude/skills/` for hermetic testing.

### Distribution
- **`manifest.json` extension:** New top-level `files.skills_marketplace[]` array, sorted alphabetically, with each entry being a directory path like `templates/skills-marketplace/ai-models/`. `update-claude.sh` smart-update auto-discovers via existing `.files | to_entries[] | .value[] | .path` jq path with zero special-casing (LIB-01 D-07 invariant).
- **Per-skill manifest entries** vs single directory entry: list each skill as a separate entry so the manifest validator can check existence of each. Trade-off: 22 entries vs 1; chose 22 for granular coverage.

### Test Strategy
- **Sample test fixture (3 skills):** `scripts/tests/test-install-skills.sh` uses 3 representative skills (e.g., `ai-models`, `pdf`, `tailwind-design-system`) for assertion coverage. Tests: cp-R correctness, idempotency, `--force` overwrite, refusal-to-overwrite, manifest entries valid. Target: ≥12 assertions.
- **Full 22-skill smoke deferred:** Could become Phase 27 or a separate `make test-skills-mirror-full` target.

### Claude's Discretion
- Specific TUI layout (column widths, status icons) follows Phase 24 conventions.
- Skill ordering in the TUI (alphabetical vs grouped by category) — alphabetical for simplicity.
- Failure handling: if `cp -R` fails for one skill, mark `failed`, continue with rest (mirrors `mcp_wizard_run` pattern).
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/lib/tui.sh` (Phase 24) — `tui_checklist`, three-layer NO_COLOR gate.
- `scripts/lib/detect2.sh` (Phase 24) — `is_*_installed` probe pattern; new `is_skill_installed <name>` follows same shape.
- `scripts/lib/dispatch.sh` (Phase 24) — for `dispatch_skills` if added to canonical order.
- `scripts/lib/mcp.sh` (Phase 25) — reference implementation for catalog-driven TUI page wiring (`mcp_status_array` pattern, install.sh `--mcps` branch).
- `scripts/install.sh` (Phase 24) — gains `--skills` flag, mirrors `--mcps` routing structure.

### Established Patterns
- Bash 3.2 — no `mapfile`, no `${var^^}`, all libs POSIX-friendly.
- Test seams via `TK_*` env vars (precedent: `TK_TUI_TTY_SRC`, `TK_MCP_CONFIG_HOME`).
- Hermetic tests sandbox `$HOME` to tmpdir.
- File-mode safety: skills don't need 0600 (public content), but each install logs cp-R completion + verification.
- `manifest.json` schema: arrays sorted alphabetically; new top-level keys validated by `scripts/validate-manifest.sh`.
- `update-claude.sh` covers all `files.*[]` arrays with zero new code (LIB-01 D-07).

### Integration Points
- `scripts/install.sh` argparse — add `--skills` branch routing to `_run_skills_selector`.
- `scripts/lib/dispatch.sh` `TK_DISPATCH_ORDER` — append `skills` only if it becomes a default checklist item; v1 routes only via `--skills` subcommand.
- `manifest.json` — register new `files.skills_marketplace[]` array (22 entries).
- `Makefile` — add `Test 33` for `test-install-skills.sh`; add `make sync-skills-mirror` standalone target.
- `.github/workflows/quality.yml` — extend `Tests 21-32` step to `Tests 21-33`.
- `docs/INSTALL.md` — new `### --skills flag` subsection under `## install.sh`.
- `docs/SKILLS-MIRROR.md` — new doc, lists 22 skills with metadata.
</code_context>

<specifics>
## Specific Ideas

- The 22 skills are EXPLICIT in REQUIREMENTS.md SKILL-01. No selection grey area.
- Each skill ships with companion files where they exist (`AUTHENTICATION.md`, `references/`, `scripts/`, etc.) per SKILL-01 final clause.
- `cp -R` (not `rsync`) per SKILL-03 explicit choice.
- `is_skill_installed` is a directory probe, NOT a filesystem-content match — `[ -d ~/.claude/skills/<name>/ ]` is sufficient.
- License audit: maintainer responsibility documented in `docs/SKILLS-MIRROR.md`. CI does NOT validate license correctness automatically (out of scope).
</specifics>

<deferred>
## Deferred Ideas

- **Skill removal flow** — `--skills-remove` to delete from `~/.claude/skills/`. Defer; users can `rm -rf` manually.
- **Per-skill version pinning beyond mirror snapshot** — track upstream commit SHA for each skill. Defer; mirror-date in SKILLS-MIRROR.md is sufficient for v1.
- **Custom skill addition (BYO)** — drop-in user-supplied skills outside the catalog. Defer.
- **Full 22-skill integration smoke test** — Phase 27 or a future maintenance phase.
- **License audit CI gate** — automated validation that every mirror dir has a LICENSE file. Defer; maintainer-side `sync-skills-mirror.sh` enforces it pre-commit.
- **Cron-style auto-sync** — automated upstream pull on schedule. Defer; manual is intentional.
</deferred>
