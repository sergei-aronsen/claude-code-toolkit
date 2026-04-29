# Requirements — v4.7 Multi-CLI Bridge

**Defined:** 2026-04-29
**Core Value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Milestone goal:** Copy `CLAUDE.md` → `GEMINI.md` / `AGENTS.md` at install with SHA256 drift tracking + `[y/N/d]` prompt on update, so users running multiple agentic CLIs (Gemini CLI, OpenAI Codex CLI) don't maintain duplicate context files manually.

## v4.7 Requirements

Requirements grouped by category. Each maps to exactly one phase via the Traceability table.

### Detection (`scripts/lib/detect2.sh` extension)

- [x] **BRIDGE-DET-01**: `is_gemini_installed` — `command -v gemini` (binary present on PATH) returns 0/1. Filesystem cross-check: `[ -d ~/.gemini/ ]` (presence of config dir) treated as soft-confirm; CLI-PATH wins.
- [x] **BRIDGE-DET-02**: `is_codex_installed` — `command -v codex` (OpenAI Codex CLI). Same fail-soft semantics as BRIDGE-DET-01. Filesystem cross-check: `[ -d ~/.codex/ ]`.
- [x] **BRIDGE-DET-03**: Detection registered in `detect2.sh` alongside existing 6 binary probes from v4.6 Phase 24 (toolkit, superpowers, gsd, security, rtk, statusline). Maintains 0/1 return contract; no 3-state.

### Bridge generation (`scripts/lib/bridges.sh` new lib)

- [x] **BRIDGE-GEN-01**: `bridge_create_project <target>` (target = `gemini` | `codex`) reads canonical `<project>/CLAUDE.md` (existing v4.0 contract), prepends auto-generated header banner, writes plain copy to `<project>/GEMINI.md` (gemini) or `<project>/AGENTS.md` (codex). Idempotent: re-run with same source overwrites bridge with same content.
- [x] **BRIDGE-GEN-02**: `bridge_create_global <target>` reads `~/.claude/CLAUDE.md`, writes `~/.gemini/GEMINI.md` (gemini) or `~/.codex/AGENTS.md` (codex). `mkdir -p ~/.gemini/` (or `~/.codex/`) before write — fail-soft if mkdir blocked (permissions). NEVER touches `~/.claude/CLAUDE.md` itself.
- [x] **BRIDGE-GEN-03**: Auto-generated header banner is byte-identical across all bridges:

  ```text
  <!--
    Auto-generated from CLAUDE.md by claude-code-toolkit (v4.7+).
    Edit CLAUDE.md (canonical source). This file regenerates on update-claude.sh.
    To stop sync: run `update-claude.sh --break-bridge <name>`.
  -->
  ```

  Banner is at the very top of the bridge file, separated from copied content by one blank line.
- [x] **BRIDGE-GEN-04**: Bridge files registered in `~/.claude/toolkit-install.json` under new `bridges[]` array entry: `{ "target": "gemini", "path": "<abs-path>", "scope": "project|global", "source_sha256": "<sha256-of-CLAUDE.md-at-write>", "bridge_sha256": "<sha256-of-bridge-file-at-write>", "user_owned": false }`. Tracking enables drift detection in BRIDGE-SYNC-01.

### Sync on update (`update-claude.sh` extension)

- [x] **BRIDGE-SYNC-01**: `update-claude.sh` iterates `bridges[]` from `toolkit-install.json`. For each bridge:
  - Compute current SHA256 of source `CLAUDE.md` and bridge file.
  - If `source_sha256` changed AND `bridge_sha256` matches recorded (no user edits): re-copy + update both SHAs in state. Log `[~ UPDATE] GEMINI.md` (chezmoi-grade output via `dro_*` helpers from v4.1 UX-01).
  - If `bridge_sha256` differs from recorded (user edits detected): prompt `[y/N/d]` (overwrite / keep / show diff). `N` is default. `d` shows diff and re-prompts. Mirrors v4.3 UN-03 contract.
  - If `user_owned: true` (set by `--break-bridge`): skip silently, log `[- SKIP] GEMINI.md (--break-bridge)`.
- [x] **BRIDGE-SYNC-02**: `update-claude.sh --break-bridge <target>` flag sets `user_owned: true` for the named bridge in toolkit-install.json. Subsequent `update-claude.sh` runs skip that bridge. Reversible: `--restore-bridge <target>` clears the flag (re-syncs on next update).
- [x] **BRIDGE-SYNC-03**: When `CLAUDE.md` itself was deleted by user (rare), `update-claude.sh` does NOT delete bridges; logs `[? ORPHANED] GEMINI.md (CLAUDE.md missing)` and continues. Bridges become user-owned by default in that case.

### Install-time UX (`scripts/install.sh` + `init-claude.sh` + `init-local.sh`)

- [x] **BRIDGE-UX-01**: `scripts/install.sh` (v4.6 unified TUI) gains 2 new component rows in the Components page when their CLI is detected:
  - `[ ] Gemini CLI bridge   (CLAUDE.md → GEMINI.md)   [detected: gemini@<version>]`
  - `[ ] Codex CLI bridge    (CLAUDE.md → AGENTS.md)   [detected: codex@<version>]`
  Items NOT shown when CLI absent (no clutter for users who don't have these CLIs).
- [x] **BRIDGE-UX-02**: `init-claude.sh` and `init-local.sh` post-install (after `~/.claude/` and `<project>/.claude/` are populated) detect installed CLIs and prompt per CLI: `Gemini CLI detected. Create GEMINI.md → CLAUDE.md bridge? [Y/n]`. Default `Y`. Reads from `< /dev/tty` with `TK_BRIDGE_TTY_SRC` test seam (mirrors v4.4 BOOTSTRAP-01 pattern). Fail-closed `N` on no-TTY (CI / piped install).
- [x] **BRIDGE-UX-03**: `--no-bridges` flag on `init-claude.sh`, `init-local.sh`, and `install.sh` skips all bridge prompts unconditionally. `TK_NO_BRIDGES=1` env-var equivalent. Mirrors v4.4 `--no-bootstrap` / `TK_NO_BOOTSTRAP` symmetry pattern.
- [x] **BRIDGE-UX-04**: `--bridges <comma-list>` (e.g., `--bridges gemini,codex`) flag forces bridge creation non-interactively for CI/scripted installs. Skips per-CLI prompt, requires the named CLI to be installed (errors with exit 1 if absent and `--fail-fast` is set; skips with warning otherwise).

### Uninstall integration (`scripts/uninstall.sh` extension)

- [x] **BRIDGE-UN-01**: `uninstall.sh` includes bridges from `toolkit-install.json::bridges[]` in its REMOVE_LIST. Each bridge classified via existing SHA256 helper (`classify_file`): clean → REMOVE; user-modified → MODIFIED list with `[y/N/d]` prompt (v4.3 UN-03 reuse). Base-plugin invariant (UN-05 `diff -q`) unchanged.
- [x] **BRIDGE-UN-02**: `uninstall.sh --keep-state` (v4.4 KEEP-01 flag) preserves `bridges[]` entries alongside the rest of toolkit-install.json. No special-case handling needed — bridges follow same state-file lifecycle as other tracked files.

### Distribution + tests + docs

- [x] **BRIDGE-DIST-01**: `manifest.json` registers `scripts/lib/bridges.sh` under existing `files.libs[]` array. `update-claude.sh` auto-discovers it via the v4.4 LIB-01 D-07 jq path (`.files | to_entries[] | .value[] | .path`) — zero code changes to `update-claude.sh` needed. `manifest.json` version bumped to `4.7.0`.
- [x] **BRIDGE-DIST-02**: `CHANGELOG.md [4.7.0]` consolidated entry covers all BRIDGE-* requirements, mirrors v4.4/v4.5 consolidation pattern.
- [ ] **BRIDGE-TEST-01**: `scripts/tests/test-bridges.sh` hermetic test (≥15 assertions) covers:
  - Plain copy correctness (header + content match)
  - Idempotency on re-create
  - Drift detection (modify bridge → SHA mismatch → `[y/N/d]` branches)
  - `--break-bridge` flag persists user_owned flag
  - `--no-bridges` / `TK_NO_BRIDGES=1` skip path
  - `--bridges gemini,codex` non-interactive force
  - Uninstall round-trip removes bridges
  - BACKCOMPAT-01: `test-bootstrap.sh` PASS=26 unchanged; v4.6 `test-install-tui.sh` PASS=43 unchanged.
- [ ] **BRIDGE-DOCS-01**: `docs/BRIDGES.md` (new) documents:
  - Which CLIs are supported and which file each reads (`GEMINI.md` for Gemini CLI, `AGENTS.md` for OpenAI Codex CLI — note this is the OpenAI standard, NOT `CODEX.md`)
  - Plain-copy semantics + drift behavior
  - How to opt out (`--no-bridges`, `--break-bridge`, `--restore-bridge`)
  - Why no symlink (single-source-of-truth tradeoff: would lock all CLIs to byte-identical content; chosen plain copy + sync to allow per-CLI edits)
  - Future scope: branding substitution layer (deferred to v4.8 if friction)
- [ ] **BRIDGE-DOCS-02**: `docs/INSTALL.md` "Installer Flags" table extended with `--no-bridges`, `--bridges <list>`, `--break-bridge <name>`, `--restore-bridge <name>` rows. README mentions multi-CLI support in the Killer Features grid.

## Future Requirements

Deferred from v4.7 — tracked for later milestones.

### Substitution layer (deferred to v4.8 if friction)

- **BRIDGE-FUT-01**: Branding substitution — minimal whitelist replacement table (e.g., `Claude Code` → `Gemini CLI`, `~/.claude/` → `~/.gemini/`) applied during copy. Bash 3.2 compatible (parallel arrays, no `declare -A`). Opt-in via `--substitute-branding` flag. Default off — risk of false replace nonzero (e.g., `claude` CLI command name should NOT be substituted). Revisit if users report Gemini/Codex confused by `Claude` references.
- **BRIDGE-FUT-02**: Per-CLI tone overlay — small per-CLI `templates/bridges/<name>-overlay.md` snippets prepended/appended (e.g., note for Gemini about `gemini.md` reading order). Defer until usage signals demand.

### Additional CLIs

- **BRIDGE-FUT-03**: Cursor support — `.cursorrules` is the convention. Different mechanism (single-file rules, not a Markdown context). Out of v4.7 scope; defer.
- **BRIDGE-FUT-04**: Aider support — `CONVENTIONS.md` is the convention. Defer.

### Sync UX

- **BRIDGE-FUT-05**: `update-claude.sh --bridges-only` mode that re-syncs ONLY bridges without touching the rest of `~/.claude/`. Edge utility, defer.

## Out of Scope

Explicit exclusions for v4.7 with reasoning.

- **Symlink-based bridging** — rejected in favour of plain copy. Symlink locks all CLIs to byte-identical content, prevents per-CLI customization. Drift handled via SHA256 + prompt instead. (See PROJECT.md "Key context".)
- **Branding substitution at install time** — over-engineering for v4.7. Plain copy first; modern LLMs handle `Claude` references in another CLI's context fine. Revisit if users report friction (BRIDGE-FUT-01).
- **Auto-installing Gemini CLI / Codex CLI on user's behalf** — TK does NOT vendor third-party binaries (v4.5 OOS pattern). Detection is fail-soft; absent CLI = no bridge offered.
- **Bridge file format normalization** (e.g., stripping Claude-specific YAML frontmatter, rewriting skill paths) — over-engineering. Plain copy as-is; users handle CLI-specific quirks themselves.
- **Cursor `.cursorrules` support** — different file format (single-line rules, not Markdown context). Out of scope; defer (BRIDGE-FUT-03).
- **Backwards-compat shim for users who manually created `GEMINI.md` before v4.7** — installer detects existing file, prompts `[y/N/d]` instead of silent overwrite. Standard contract (UN-03). No special migration path.

## Traceability

Phases mapped to requirements. Filled by `gsd-roadmapper` on 2026-04-29.

| Phase | Requirements | Status |
|-------|--------------|--------|
| 28 — Bridge Foundation | BRIDGE-DET-01, BRIDGE-DET-02, BRIDGE-DET-03, BRIDGE-GEN-01, BRIDGE-GEN-02, BRIDGE-GEN-03, BRIDGE-GEN-04 | Pending |
| 29 — Sync & Uninstall Integration | BRIDGE-SYNC-01, BRIDGE-SYNC-02, BRIDGE-SYNC-03, BRIDGE-UN-01, BRIDGE-UN-02 | Pending |
| 30 — Install-time UX | BRIDGE-UX-01, BRIDGE-UX-02, BRIDGE-UX-03, BRIDGE-UX-04 | Pending |
| 31 — Distribution + Tests + Docs | BRIDGE-DIST-01, BRIDGE-DIST-02, BRIDGE-TEST-01, BRIDGE-DOCS-01, BRIDGE-DOCS-02 | Pending |

**Coverage:** 18/18 v4.7 requirements mapped, 0 orphans, 0 duplicates.

### Per-REQ-ID lookup

| REQ-ID | Phase |
|--------|-------|
| BRIDGE-DET-01 | 28 |
| BRIDGE-DET-02 | 28 |
| BRIDGE-DET-03 | 28 |
| BRIDGE-GEN-01 | 28 |
| BRIDGE-GEN-02 | 28 |
| BRIDGE-GEN-03 | 28 |
| BRIDGE-GEN-04 | 28 |
| BRIDGE-SYNC-01 | 29 |
| BRIDGE-SYNC-02 | 29 |
| BRIDGE-SYNC-03 | 29 |
| BRIDGE-UN-01 | 29 |
| BRIDGE-UN-02 | 29 |
| BRIDGE-UX-01 | 30 |
| BRIDGE-UX-02 | 30 |
| BRIDGE-UX-03 | 30 |
| BRIDGE-UX-04 | 30 |
| BRIDGE-DIST-01 | 31 |
| BRIDGE-DIST-02 | 31 |
| BRIDGE-TEST-01 | 31 |
| BRIDGE-DOCS-01 | 31 |
| BRIDGE-DOCS-02 | 31 |
