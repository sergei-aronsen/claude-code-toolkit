# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
