# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.3.0] - YYYY-MM-DD

### Added

- **Uninstall script** (`scripts/uninstall.sh`) — single command to safely remove every
  toolkit-installed file from a project's `.claude/` while preserving user modifications
  and base plugins (`superpowers`, `get-shit-done`).
  - UN-01: removes registered files only when current SHA256 matches the recorded hash;
    files outside the project's `.claude/` and inside base-plugin trees are never touched
  - UN-02: `--dry-run` prints a 4-group preview (REMOVE / KEEP / MODIFIED / MISSING) and
    exits 0 with zero filesystem changes
  - UN-03: modified files trigger a `[y/N/d]` prompt read from `< /dev/tty`; default `N`
    keeps the file, `d` shows a diff against the manifest reference and re-prompts
  - UN-04: full `.claude/` backup written to `~/.claude-backup-pre-uninstall-<unix-ts>/`
    before any delete; `--no-backup` flag does not exist

- **State cleanup + idempotency**
  - UN-05: deletes `~/.claude/toolkit-install.json` after successful removal and strips
    any `<!-- TOOLKIT-START -->`…`<!-- TOOLKIT-END -->` block from `~/.claude/CLAUDE.md`;
    user-authored sections preserved verbatim
  - UN-06: second invocation detects missing state file, prints
    `✓ Toolkit not installed; nothing to do`, exits 0, creates no backup directory

- **Distribution** — `manifest.json` registers `scripts/uninstall.sh` under
  `files.scripts[]`; `init-claude.sh`, `init-local.sh`, and `update-claude.sh` end-of-run
  banners include the line
  `To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)`
  (UN-07).

- **Round-trip integration test** — `scripts/tests/test-uninstall.sh` (Makefile Test 24)
  exercises the full install→uninstall round-trip across 5 scenario blocks; new
  `scripts/tests/test-install-banner.sh` (Test 25) gates banner presence in all 3
  installers (UN-08).

## [4.2.0] - 2026-04-26

### Added

- **Persistent FP allowlist** — `.claude/rules/audit-exceptions.md` auto-seeds via `globs: ["**/*"]`
  and is consulted by `/audit` Phase 0 to drop known false positives before reporting (EXC-01..05).
- **`/audit-skip <file:line> <rule> <reason>`** — appends a structured exception block to
  `audit-exceptions.md` after validating the file:line exists in the working tree and that the
  entry is not already allowlisted.
- **`/audit-restore <file:line> <rule>`** — comment-aware removal of an allowlist entry with a
  `[y/N]` confirmation prompt.
- **6-phase `/audit` workflow** — load context → quick check → deep analysis → 6-step FP recheck
  → structured report → mandatory Council pass. Every reported finding survives the FP-recheck and
  ships with verbatim ±10 lines of source code so the Council reasons from the code, not the rule
  label.
- **Structured audit reports** — `/audit` writes to `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md`
  with a fixed schema: Summary table → Findings (ID, severity, rule, location, claim, verbatim
  code, data flow, "why it's real", suggested fix) → Skipped (allowlist) → Skipped (FP recheck)
  → Council verdict slot.
- **Mandatory Supreme Council `audit-review` mode** — every `/audit` run terminates in
  `/council audit-review --report <path>`. Council emits per-finding
  `REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT` verdicts with confidence scores in `[0.0, 1.0]`,
  plus a "Missed findings" section. Severity reclassification is explicitly forbidden (COUNCIL-02).
- **`brain.py --mode audit-review`** — runs Gemini and ChatGPT in parallel for audit-review, flags
  per-finding disagreements as `disputed` without auto-resolution.
- **Template propagation across all 49 prompt files** — every
  `templates/{base,laravel,rails,nextjs,nodejs,python,go}/prompts/{SECURITY_AUDIT,CODE_REVIEW,PERFORMANCE_AUDIT,MYSQL_PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,DEPLOY_CHECKLIST,DESIGN_REVIEW}.md`
  carries the audit-exceptions callout, 6-step FP-recheck SELF-CHECK, structured OUTPUT FORMAT,
  and Council Handoff footer.

### Changed

- **`manifest.json`** — bumped to `4.2.0` and registered `templates/base/rules/audit-exceptions.md`
  under `files.rules`.
- **`commands/audit.md`** — rewritten around the 6-phase workflow; documents the Council Handoff UX
  (FALSE_POSITIVE nudge → user runs `/audit-skip`; disputed verdict prompt).
- **`commands/council.md`** — added `## Modes` section with `audit-review` subsection documenting
  input format (path to structured audit report), expected Council prompt, and verdict-table output
  schema.

### Fixed

- _None — this is an additive feature release. See [4.1.1] for the prior patch._

### Documentation

- **CI gates** — `make validate` now asserts every audit prompt carries the `Council Handoff`
  marker plus all six numbered FP-recheck steps; missing markers fail the build (TEMPLATE-03).
- **`make test`** — adds Test 18 (audit pipeline fixture), Test 19 (Council audit-review
  verdict-slot rewrite + parallel dispatch), Test 20 (template propagation idempotency).

## [4.1.1] - 2026-04-25

### Fixed

- **CRIT-01** — Replaced fragile 95-line emoji-anchored sed smart-merge in `update-claude.sh` with chezmoi-style `.new` flow. Toolkit never touches user `CLAUDE.md`; updates land as `CLAUDE.md.new` for manual review/merge.
- **CRIT-02** — Aligned `manifest.json` version with v4.1.0 git tag.
- **C-01..C-10** — Lock TOCTOU fix in `state.sh`, atomic state-write with manifest_hash, `curl -sSLf` (fail on HTTP 4xx/5xx) across all installers, anchored regex in `setup-security.sh`, JSON-based plugin presence check.
- **Sec-H1** — Anthropic OAuth Bearer token moved off `curl` argv. Written to `mktemp` header file with `chmod 600`, passed via `-H @file`. EXIT trap cleans up.
- **BRAIN-H1..H4, M1, M2, M5** — `brain.py` corrected docstring, `Path.relative_to` validation, stdin body, header-file auth (chmod 0o600), partial-Council fallback (one provider failure → use surviving verdict), per-provider availability flags.
- **S-01** — All hook scripts in `templates/*/settings.json` read `f=$(jq -r '.tool_input.file_path // empty')` from STDIN. Removed undefined `$FILE_PATH` references.
- **PERF-02** — `sha256_file` prefers `sha256sum` → `shasum -a 256` → chunked Python fallback.
- **T-02, T-05** — New regression suite `test-claude-md-new.sh` (19 assertions, 7 scenarios). CI matrix extended to `[ubuntu-latest, macos-latest]` for `test-init-script` job.
- **M-03** — `make shellcheck` extended to `templates/global/`.

### Notes

Patch release closing 53 audit findings (2 CRIT, 14 HIGH, 20 MED, 17 LOW) cross-reviewed by Supreme Council. Council follow-up applied 4 additional refinements (passes A/B/C/D).

## [4.1.0] - 2026-04-25

### Added

- Phase 11 UX polish: chezmoi-grade dry-run preview with `[+ ADD]` / `[~ MOD]` / `[- REMOVE]` grouping for both `install` and `update` flows.
- `migrate-to-complement.sh --dry-run` now emits the same grouped preview before any destructive change.
- New audit pipeline (`AUDIT-REPORT.md`) — full deep audit covering security, correctness, performance, portability, JSON state-file integrity. Cross-AI reviewed via Supreme Council (Gemini Skeptic + ChatGPT Pragmatist).

### Fixed

- `manifest.json` `version` and `updated` fields now match the `v4.1.0` git tag (previously drifted at `4.0.0` / `2026-04-19`).

### Notes

This release closes the v4.1 milestone. See `.planning/archived/v4.1/` for phase artifacts.

## [4.0.0] - 2026-04-21

### BREAKING CHANGES

- **Default install behavior changes when SP and/or GSD are detected.** Previously (v3.x) all
  54 TK files installed unconditionally. v4.0 auto-selects `complement-*` mode and skips 7 files
  (6 commands/skills + 1 agent) that duplicate SP functionality. Users who relied on TK's
  `/debug`, `/plan`, `/tdd`, `/verify`, `/worktree`, `skills/debugging`, or TK-owned
  `agents/code-reviewer.md` will instead use SP's equivalents. Override: `--mode standalone`.
- **7 files are no longer installed in `complement-sp` mode:** `agents/code-reviewer.md`,
  `commands/debug.md`, `commands/plan.md`, `commands/tdd.md`, `commands/verify.md`,
  `commands/worktree.md`, `skills/debugging/SKILL.md`. Users relying on TK's copies must use
  SP's equivalents.
- **`manifest.json` schema bumped from v1 (implicit) to v2 (explicit `manifest_version: 2`).**
  Old v3.x install scripts refuse to run against a v2 manifest. Users running an old installer
  against the v4.0 repo see a hard error: `manifest.json has manifest_version=2; this installer
  expects v1`.
- **`toolkit-install.json` state schema bumped v1 → v2.** v1 installs read correctly via
  `jq '... // false'` backwards-compat default on the new `synthesized_from_filesystem` field,
  but v1 tooling reading the new field directly will see `null`.
- **`scripts/init-local.sh` no longer hardcodes version.** Reads from `manifest.json` at runtime
  via `jq`. The `VERSION="2.0.0"` constant is removed from line 11.
- **`scripts/update-claude.sh` no longer hand-iterates a file list.** The iterated list now comes
  from `manifest.json`. Custom TK installs that relied on update-claude.sh skipping certain files
  will see those files installed on next update (if listed in manifest).
- **`~/.claude/settings.json` is now merged additively.** `setup-security.sh` no longer overwrites
  the file — it reads, merges only TK-owned keys (permissions.deny, hooks.PreToolUse, env block),
  and writes via atomic temp-file rename.
- **Post-update summary format changed** from unstructured log lines to a 4-group block
  (`INSTALLED N`, `UPDATED M`, `SKIPPED P (with reason)`, `REMOVED Q (backed up to path)`).
  Users who scrape update output must adjust. Backup directories are now suffixed with PID
  (`~/.claude-backup-<unix-ts>-<pid>/`) to prevent same-second collision.

### Added

- `scripts/detect.sh` — filesystem detection of `superpowers` and `get-shit-done`; sources
  `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` environment variables.
- `scripts/lib/install.sh` — `recommend_mode`, `compute_skip_set`, `MODES` array for
  mode-aware installs.
- `scripts/lib/state.sh` — atomic `write_state`, `acquire_lock`, `release_lock`, `sha256_file`
  for install-state management.
- `scripts/migrate-to-complement.sh` — one-time migration for v3.x users with SP/GSD installed;
  three-column hash diff, `[y/N/d]` per-file prompt, `cp -R` full backup, idempotent.
- `~/.claude/toolkit-install.json` — install state file: mode, detected bases, installed files
  with sha256 hashes, skipped files with reasons. Schema v2 adds `synthesized_from_filesystem`.
- 4 install modes: `standalone`, `complement-sp`, `complement-gsd`, `complement-full`.
- `--mode <name>` flag on `init-claude.sh` and `init-local.sh` — overrides auto-detected mode
  with interactive prompt and auto-recommendation.
- `--dry-run` flag on `init-claude.sh` — previews `[INSTALL]`/`[SKIP]` per file without writing.
- `--offer-mode-switch=yes|no|interactive`, `--prune=yes|no|interactive`, `--no-banner` flags
  on `update-claude.sh`.
- `conflicts_with`, `sp_equivalent`, `requires_base` fields on per-file manifest entries.
- `make validate-manifest.py` check — every manifest path exists, `conflicts_with` values are
  from the known plugin set.
- Makefile test targets: 14 test groups (up from 0), all hermetic — covering detect, install,
  state, update drift, update diff, update summary, migrate diff, migrate flow, migrate idempotence.
- `components/orchestration-pattern.md` — lean orchestrator + fat subagents pattern.
- `components/optional-plugins.md` — rtk, caveman, superpowers, get-shit-done recommendations
  with verified caveats.
- `templates/global/RTK.md` — fallback RTK notes with rtk-ai/rtk#1276 caveat and workaround.
- `## Required Base Plugins` section in all 7 `templates/*/CLAUDE.md` files — discloses SP/GSD
  dependency and install commands so new users set up the full complement stack first.
- `manifest.json` `inventory.components` bucket (non-install metadata for Phase 6 components).
- `Makefile validate-base-plugins` drift guard — verifies all 7 templates carry the section
  heading on every `make check`.

### Changed

- `scripts/init-claude.sh` — refactored to 4-mode dispatch; sources `detect.sh` +
  `lib/install.sh` from `$REPO_URL` on remote installs; respects `--mode` override;
  manifest-schema-v2 guard hard-fails on v1 manifests.
- `scripts/init-local.sh` — same mode-aware logic as `init-claude.sh`; reads version from
  `manifest.json` at runtime (removes `VERSION="2.0.0"` hardcode).
- `scripts/update-claude.sh` — rewritten for re-detection on every run, mode-drift surfacing,
  manifest-driven iteration, 4-group summary, D-77 migrate hint when complement migration
  is appropriate.
- `scripts/setup-security.sh` — safe `~/.claude/settings.json` merge with timestamped backup
  (`settings.json.bak.<unix-ts>`); restore-on-merge-failure.
- `scripts/setup-council.sh` — `< /dev/tty` guards on every interactive `read`; silent
  `read -rs` for API-key prompts; `python3 json.dumps()` for API-key heredoc interpolation.
- `README.md` — repositioned as "complement to superpowers + get-shit-done"; install section
  shows standalone + complement modes with one paragraph of guidance per mode.
- `manifest.json` — schema v2 (`manifest_version: 2`); 7 entries gain `conflicts_with`; 6
  entries gain `sp_equivalent`.

### Fixed

- BUG-01: BSD-incompatible `head -n -1` in `scripts/update-claude.sh` smart-merge replaced
  with POSIX `sed '$d'`. Silent CLAUDE.md truncation on macOS fixed.
- BUG-02: `< /dev/tty` guards on every interactive `read` in `scripts/setup-council.sh`;
  silent `read -rs` for API-key prompts. Fixes curl|bash prompts being consumed as stream.
- BUG-03: `python3 json.dumps` JSON-escapes API keys containing `"`, `\`, newline in
  heredoc-written `config.json`. Fixes malformed Council config.
- BUG-04: Silent `sudo apt-get install tree` in `setup-council.sh` replaced with interactive
  prompt and visible error path.
- BUG-05: `setup-security.sh` timestamped backup of `~/.claude/settings.json` before every
  mutation; restore-on-merge-failure.
- BUG-06: `scripts/init-local.sh` reads version from `manifest.json`; `make validate`
  enforces manifest ↔ CHANGELOG version alignment.
- BUG-07: `commands/design.md` added to `update-claude.sh` loop (structurally fixed in
  Phase 4: update loop now iterates manifest, not a hand-list).

### Migration from v3.x

See [docs/INSTALL.md](docs/INSTALL.md) for the install matrix and `scripts/migrate-to-complement.sh`
for the automated migration path (per-file confirmation, full backup before any removal).

## [3.0.0] - 2026-02-16

### Added

- **Supreme Council** — multi-AI code review system (Gemini + ChatGPT)
  - `brain.py` orchestrator: sends plans to Gemini (Architect) and ChatGPT (Critic)
  - 4-phase review: Context Discovery → Architectural Audit → Second Opinion → Final Report
  - Security-hardened vs original: no hardcoded keys, no shell=True, temp file cleanup, input validation
  - Configurable models via `~/.claude/council/config.json` with env var overrides
  - Gemini modes: CLI (free with subscription) or API
  - Path traversal protection, file size limits, command timeouts
- **`/council` command** — multi-AI pre-implementation review
  - Run before coding high-stakes features (auth, payments, refactoring)
  - Outputs APPROVED/REJECTED report to `.claude/scratchpad/council-report.md`
- **`setup-council.sh`** — installation script
  - Dependency checks (Python 3.8+, tree, curl)
  - Interactive Gemini mode selection (CLI vs API)
  - API key configuration (prompt + env var support)
  - Automatic `brain` shell alias
  - Installation verification
- **Supreme Council component** — `components/supreme-council.md`
  - Full documentation: how it works, when to use, configuration, security improvements
- Supreme Council section in base CLAUDE.md template
- `/council` command distributed to all projects via init-claude.sh

### Changed

- Updated README: 26 → 29 slash commands, added Supreme Council to features and quick start
- Updated `manifest.json` to v3.0.0
- Updated `init-claude.sh` with council command and setup recommendation

## [2.8.0] - 2026-02-06

### Added

- **Production Safety Guide** — new component `components/production-safety.md`
  - Deployment safety: incremental deploy pattern, pre/post-deploy verification
  - Queue and worker safety: rolling restarts, check before modify, test on subset
  - Bug fix approach: simplest solution first, rule of three attempts
  - File targeting: verify correct variant, branch, upstream status
  - Rollback decision framework: when to rollback vs hotfix
- **`/deploy` command** — safe deployment workflow with 4 phases
  - Pre-deploy: git state, conflict check, tests, build
  - Deploy: framework-specific steps with rolling worker restart
  - Post-deploy: smoke tests, log check, worker status
  - Rollback decision: automatic verification with user approval
  - Framework auto-detection (Laravel, Next.js, Node.js, Python, Go)
- **`/fix-prod` command** — production hotfix workflow
  - Diagnose first (gather evidence, identify scope, rollback decision)
  - Minimal change rule (fix only the broken thing)
  - Post-fix monitoring (immediate + short-term)
  - Common production issues quick reference
- **Production Safety section** in all 7 CLAUDE.md templates
  - Bug Fix Approach rules
  - Deployment safety rules
  - File Targeting checklist
  - Laravel template: extra Queue and Worker Safety subsection
- Inspired by insights from 94 Claude Code sessions (1,307 messages)

### Changed

- Updated Quick Commands table in all templates (+2 commands: `/deploy`, `/fix-prod`)
- Updated README: 24 → 26 slash commands, 23+ → 24+ guides
- Updated `docs/features.md` with Production Safety section and new commands
- Updated `manifest.json` to v2.8.0 with Production Safety section

## [2.6.0] - 2026-01-23

### Added

- **Compact Instructions** — section for preserving critical rules during `/compact`
  - Added to all CLAUDE.md templates (base, laravel, nextjs)
  - 4-5 key rules that should be preserved after compaction
  - Security, Architecture, Workflow, Git + framework-specific
- **AI Models skill** — extracted from CLAUDE.md into separate skill
  - `skills/ai-models/SKILL.md` — loaded on demand
  - Claude 4.5 (Opus, Sonnet, Haiku) with model IDs
  - Gemini 3 (Pro, Flash) with model IDs
  - Code examples for Python, TypeScript, PHP
- **Available Skills** section in CLAUDE.md templates
- **DATABASE_PERFORMANCE_AUDIT.md** — renamed and moved to `templates/*/prompts/`

### Changed

- **README.md** — reorganized section order:
  Who Is This For → Quick Start → Key Concepts → Structure → What's Inside → MCP → Examples
- Templates in "What's Inside" is now the first item
- Security audit example uses `/audit security`
- Updated audit count: 5 → 6 (added Database)
- CLAUDE.md templates reduced by 10-20%

### Fixed

- Markdown syntax issues in laravel template

## [2.5.0] - 2026-01-23

### Added

- **`/verify` command** — quick check before PR
  - Build, types, lint, tests in one command
  - Modes: `quick`, `full`, `pre-commit`, `pre-pr`
  - Security scan for pre-pr mode
  - Auto-detection of framework (Laravel, Next.js, Node.js)
- **`/learn` command** — extracting and saving patterns
  - Saves problem solutions to `.claude/rules/lessons-learned.md` (auto-loaded)
  - Integration with Memory Bank and Knowledge Graph
  - Pattern types: error resolution, workarounds, debugging, user corrections
  - **Mistakes & Learnings** pattern (Error → Learning → Prevention) from loki-mode
  - Self-Correction Protocol for automatic learning from mistakes
- **`/debug` command** — systematic debugging process
  - 4 phases: Root Cause → Pattern Analysis → Hypothesis → Implementation
  - Rule "3+ fixes = architectural problem"
  - Common Rationalizations table
  - Inspired by [superpowers](https://github.com/obra/superpowers)
- **`/worktree` command** — git worktrees management
  - Actions: create, list, remove, cleanup
  - Supplement to existing `components/git-worktrees-guide.md`
- **Enhanced Security Audit** — concepts from Trail of Bits
  - "Context before vulnerabilities" principle
  - Codebase Size Strategy (SMALL/MEDIUM/LARGE)
  - Risk Level Triggers (HIGH/MEDIUM/LOW)
  - Rationalizations table
  - Sharp Edges section (API footguns)
  - Red Flags for immediate escalation
- **Hooks Auto-Activation** — automatic skills activation (`components/hooks-auto-activation.md`)
  - **Scoring system** — different triggers give different points (keywords: 2, intentPatterns: 4, pathPatterns: 5)
  - **Confidence levels** — HIGH/MEDIUM/LOW based on score
  - **Threshold filtering** — minConfidenceScore, maxSkillsToShow
  - **Exclude patterns** — false positives prevention
  - **JSON Schema** — validation and IDE autocomplete
  - TypeScript implementation with examples
  - Inspired by [claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase)
- **Modular Skills** — progressive disclosure (`components/modular-skills.md`)
  - Splitting large guidelines into modules
  - Navigation table in main SKILL.md
  - Resources loaded on demand
  - 60-85% token savings
- **Skill Accumulation** — self-learning system (`components/skill-accumulation.md`)
  - Automatic skill creation when patterns are detected
  - Updating existing skills on user corrections
  - Proposal formats for creation/update
  - Templates in `templates/base/skills/`
- **Design Review** — UI/UX audit with Playwright MCP (`templates/*/prompts/DESIGN_REVIEW.md`)
  - 7-phase review process (Preparation → Interaction → Responsiveness → Visual → Accessibility → Robustness → Code)
  - Triage matrix: [Blocker], [High], [Medium], [Nitpick]
  - WCAG 2.1 AA accessibility checks
  - Responsive testing (1440px, 768px, 375px)
  - Next.js specific version with hydration, next/image, Tailwind checks
  - Inspired by [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows)
- **Structured Workflow** — 3-phase development approach (`components/structured-workflow.md`)
  - Phase 1: RESEARCH (read-only) — only Glob, Grep, Read
  - Phase 2: PLAN (scratchpad-only) — plan in `.claude/scratchpad/`
  - Phase 3: EXECUTE (full access) — after confirmation
  - Explicit tool restrictions by phase
  - Plan template with checkboxes
  - Inspired by [RIPER-5](https://github.com/tony/claude-code-riper-5)
- **Smoke Tests Guide** — minimal tests for API (`components/smoke-tests-guide.md`)
  - What to test: health, auth, core CRUD
  - Examples for Laravel (Pest), Next.js (Vitest), Node.js (Jest)
  - GitHub Actions workflow
  - Checklist for new project
- Inspired by [everything-claude-code](https://github.com/affaan-m/everything-claude-code), [superpowers](https://github.com/obra/superpowers), [Trail of Bits](https://github.com/trailofbits/skills), [loki-mode](https://github.com/asklokesh/loki-mode), [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase)

### Changed

- Updated README with `/verify` and `/learn` in commands table
- Added Quick Commands section to all templates

## [2.4.0] - 2026-01-22

### Added

- **Gemini 3 models support** — AI Models section now includes both Claude and Gemini
  - Claude 4.5: Opus, Sonnet, Haiku
  - Gemini 3: Pro, Flash
  - Code examples for both providers (Python, PHP, TypeScript)
  - Deprecation warning for old versions (Claude 3.5/4.0, Gemini 1.x/2.x)
- **Architecture Guidelines (STRICT!)** section in all templates:
  - KISS Principle — simplest working solution
  - YAGNI — no features "for the future"
  - No Boilerplate — no Interfaces/Factories/DTOs unless requested
  - File Structure — prefer larger files, ask before creating new files
- **Coding Style** section:
  - Functional programming over complex OOP
  - Don't over-split functions (50 lines is fine)
  - One file doing one thing well > 5 files with abstractions
- **Bootstrap Workflow** documentation:
  - New section in README.md
  - New component `components/bootstrap-workflow.md`
  - Correct order: IDEA → STACK → INSTRUCTIONS → ADAPTATION
  - Example prompts for Laravel and Next.js projects
- **Knowledge Persistence** pattern — save knowledge to 3 places:
  - CLAUDE.md (for Claude Code)
  - docs/README (for humans)
  - MCP Memory (for persistence between sessions)
- **CHANGELOG rule** in Git Workflow — update on `feat:`, `fix:`, breaking changes
- **`/install` command** — quick installation from Claude Guides repository

### Changed

- Renamed "Claude Models" section to "AI Models" in all templates
- Updated all CLAUDE.md templates with new guidelines

## [2.3.0] - 2026-01-22

### Added

- Memory Persistence system — MCP memory sync with Git
  - New component `components/memory-persistence.md` with full documentation
  - Template files in `templates/*/memory/`:
    - `README.md` — sync instructions for each project
    - `knowledge-graph.json` — Knowledge Graph export template
    - `project-context.md` — Memory Bank context template
- Session start workflow in all CLAUDE.md templates:
  - Check MCP vs git sync dates
  - Read project memory from MCP
  - Load Knowledge Graph relationships

### Changed

- Updated all CLAUDE.md templates (base, laravel, nextjs):
  - Added "AT THE START OF EACH SESSION" section with sync check
  - Added pre-commit sync instructions in Knowledge Persistence
  - Added immediate sync rule after MCP changes
- Updated `mcp-servers-guide.md` with Git sync section
- Updated README.md with Memory Persistence subsection

## [2.2.0] - 2026-01-21

### Added

- Knowledge Graph Memory MCP server (`@modelcontextprotocol/server-memory`)
  - Builds entity relationships instead of simple key-value storage
  - Best suited for Claude Opus 4.5 architectural analysis
- Spec-Driven Development component (`components/spec-driven-development.md`)
  - Write specifications before code
  - Template for .spec.md files
  - Workflow: spec → review → implement
- `.claude/specs/` directory structure for projects

### Changed

- Updated MCP servers guide with Knowledge Graph Memory
- Updated README with Spec-Driven Development section

## [2.1.0] - 2026-01-21

### Added

- MCP Servers Guide (`components/mcp-servers-guide.md`)
  - context7 — documentation lookup for libraries
  - playwright — browser automation and UI testing
  - memory-bank — project memory between sessions
  - sequential-thinking — step-by-step problem solving
- Quick install commands for MCP servers in README

## [1.1.0] - 2025-01-13

### Added

- CI/CD with GitHub Actions (shellcheck, markdownlint, template validation)
- `update-claude.sh` script for updating templates in existing projects
- Dry-run mode (`--dry-run`) for init scripts
- More framework detection (Django, Rails, Go, Rust)
- Makefile for development tasks
- Pre-commit hooks configuration
- GitHub issue and PR templates
- New commands: `/fix`, `/explain`, `/test`, `/refactor`, `/migrate`
- Example configurations for Laravel SaaS, Next.js Dashboard, Monorepo
- LICENSE (MIT)
- SECURITY.md
- CONTRIBUTING.md

### Changed

- Improved init scripts with backup functionality
- Better error handling in shell scripts

## [1.0.0] - 2025-01-13

### Added

- Initial release
- Base templates (framework-agnostic):
  - SECURITY_AUDIT.md
  - PERFORMANCE_AUDIT.md
  - CODE_REVIEW.md
  - DEPLOY_CHECKLIST.md
- Laravel-specific templates
- Next.js-specific templates
- Reusable components:
  - severity-levels.md
  - self-check-section.md
  - report-format.md
  - quick-check-scripts.md
- Slash commands: `/doc`, `/find-script`, `/find-function`, `/audit`
- Init scripts (`init-claude.sh`, `init-local.sh`)
- README with usage instructions
