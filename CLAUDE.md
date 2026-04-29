# Claude Code Toolkit — Claude Code Instructions

## Project Overview

**Type:** Documentation / Templates Repository
**Purpose:** Collection of CLAUDE.md templates, components, and examples for Claude Code projects
**Stack:** Markdown, Shell scripts, YAML configs

---

## Quality Checks (MUST PASS)

This project has CI/CD checks. **All PRs must pass before merge.**

### Run All Checks Locally

```bash
make check
```

### Individual Checks

```bash
# Shell scripts
make shellcheck

# Markdown lint
make lint

# Validate templates
make validate
```

---

## Markdown Formatting (CRITICAL)

**All markdown files MUST pass `markdownlint` checks.**

### Common Errors to Avoid

1. **MD040** — Always specify language for code blocks

   ```markdown
   <!-- WRONG -->
   ` ` `
   code here
   ` ` `

   <!-- CORRECT -->
   ` ` `bash
   code here
   ` ` `
   ```

2. **MD031/MD032** — Add blank lines around code blocks and lists

   ```markdown
   <!-- WRONG -->
   Text
   - item
   Text

   <!-- CORRECT -->
   Text

   - item

   Text
   ```

3. **MD026** — No punctuation at end of headings

   ```markdown
   <!-- WRONG -->
   ## What is this?

   <!-- CORRECT -->
   ## What is This
   ```

### Quick Fix

```bash
npx markdownlint-cli "**/*.md" --ignore node_modules --fix
```

---

## Project Structure

```text
claude-guides/
├── templates/           # CLAUDE.md templates (base, laravel, nextjs)
│   └── */CLAUDE.md     # Template files
│   └── */settings.json # VS Code settings
├── components/          # Reusable sections for CLAUDE.md
│   └── *.md            # Individual components
├── examples/            # Complete project examples
│   └── */CLAUDE.md     # Example configurations
├── commands/            # Claude Code slash commands
│   └── *.md            # Command definitions
├── scripts/             # Utility scripts
└── .github/             # CI/CD workflows
```

---

## File Naming Conventions

- **Components:** `kebab-case.md` (e.g., `plan-mode-instructions.md`)
- **Templates:** Directory with `CLAUDE.md` inside
- **Commands:** `kebab-case.md` in `commands/` directory

---

## Git Workflow

- **Branch naming:** `feature/xxx`, `fix/xxx`, `docs/xxx`
- **Commits:** Conventional Commits (`feat:`, `fix:`, `docs:`)
- **Never push directly to `main`**

---

## Before Committing

1. Run `make check` and fix all errors
2. Ensure markdown lint passes
3. Test any shell scripts with `shellcheck`
4. Update CHANGELOG.md if needed

---

## Knowledge Persistence (IMPORTANT!)

When making **significant changes** to the project — save knowledge to three places:

### 1. CLAUDE.md — for Claude Code

Update the corresponding sections in `CLAUDE.md` or templates in `templates/`.

### 2. README.md / docs — for humans

Update documentation if changes affect:

- New components or commands
- Changes in project structure
- New features or practices

### 3. Rules — for auto-loaded project context

Update `.claude/rules/` files when operational facts change. These are auto-loaded into every session — no manual reads needed.

```text
.claude/rules/project-context.md  # Servers, architecture, conventions
.claude/docs/decisions-log.md     # Historical decisions (read on demand)
```

### What to save

- Architectural decisions and their reasons
- New patterns and practices
- Critical gotchas and limitations
- Relationships between components
- Changes in API or structure

---

## Adding New Components

1. Create file in `components/` directory
2. Follow existing component structure
3. Include description at top of file
4. Ensure markdown lint passes
5. Add to README.md if significant

---

## Common Tasks

### Add new template

```bash
mkdir templates/new-template
cp templates/base/CLAUDE.md templates/new-template/
# Edit and customize
```

### Test markdown locally

```bash
npx markdownlint-cli components/your-file.md
```

### Run full validation

```bash
make check
```

<!-- GSD:project-start source:PROJECT.md -->
## Project

**claude-code-toolkit**

A toolkit that augments **Claude Code** with CLAUDE.md templates, slash commands, components, skills, and the Supreme Council multi-AI plan validator. Targets solo developers who want a curated, framework-aware setup on top of base plugins (`superpowers`, `get-shit-done`).

After v4.0 the toolkit positions itself as a **complement, not a replacement**: at install time it detects whether `superpowers` and `get-shit-done` are present and only installs files that do not duplicate those plugins. Users without the bases still get the full standalone install.

**Core Value:** **Install only what adds value over `superpowers` + `get-shit-done`.** No duplicate commands, no shadow agents, no name collisions. The toolkit's unique contributions (Council, framework CLAUDE.md templates, components library, cheatsheets) are always installed; everything else is conditional on detected base plugins.

### Constraints

- **Tech stack**: Markdown + POSIX shell (bash, must work on macOS BSD and GNU Linux). No Node/Python runtime dependency for install scripts.
- **Compatibility**: install scripts must work under `curl ... | bash` (no stdin assumptions without `< /dev/tty`); macOS BSD `head`/`sed`/`tail` (no GNU-only flags).
- **Safety**: never overwrite `~/.claude/settings.json` without backup and JSON merge; never delete user files without confirmation; every destructive action prompts.
- **Detection**: filesystem-only (no `claude plugin list` dependency in v4.0).
- **Quality gate**: `make check` (markdownlint + shellcheck + validate) must pass on every PR; CI enforced via `.github/workflows/quality.yml`.
- **Versioning**: v4.0.0 is a breaking release — `manifest.json`, `CHANGELOG.md`, `init-local.sh`, and any other version reference must align.
- **Commits**: Conventional Commits, branches `feature/xxx` / `fix/xxx`, never push directly to `main`.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Markdown — Templates, components, commands, prompts, skills, agents, cheatsheets (the bulk of the repo). Linted via `markdownlint`.
- Bash (POSIX-compatible Bash 3.2+) — All installer/updater/verifier scripts in `scripts/`. All scripts use `set -euo pipefail`.
- Python 3.8+ — Single file `scripts/council/brain.py` (Supreme Council orchestrator, curl-only, no pip dependencies).
- YAML — GitHub Actions workflow `.github/workflows/quality.yml`, pre-commit config `.pre-commit-config.yaml`.
- JSON — Config files (`manifest.json`, `.markdownlint.json`, `templates/base/settings.json`, `scripts/council/config.json.template`).
- Make — Single `Makefile` (~95 lines) acts as the project task runner.
## Runtime
- macOS (Darwin) — Required for `install-statusline.sh` (uses `security` Keychain command and `stat -f %m`).
- Linux (Ubuntu) — Required for CI runners (`ubuntu-latest` in `.github/workflows/quality.yml`); also supported by `init-claude.sh`, `update-claude.sh`, `setup-security.sh`, `setup-council.sh`.
- Bash shell with `set -euo pipefail` semantics.
- No build artifact, no compilation step — repo is consumed by `curl | bash` pipelines from raw.githubusercontent.com.
- None for the toolkit itself (no `package.json`, no `pyproject.toml`, no `Cargo.toml`, no `go.mod`).
- `npm` (global) used to install `markdownlint-cli` via `make install` in `Makefile:24`.
- `brew` used to install `shellcheck`, `jq`, `tree` on macOS during setup.
- `apt-get` used to install `tree` on Linux in `scripts/setup-council.sh:66`.
- Lockfile: not applicable (no application dependencies).
## Frameworks
- None — this is a documentation/templates repository, not an application framework.
- `make test` (`Makefile:42-63`) — integration tests for `scripts/init-local.sh` against synthetic Laravel/Next.js/generic projects under `/tmp/test-claude-*`.
- Template content validation via `make validate` (`Makefile:66-86`) and the `validate-templates` job in `.github/workflows/quality.yml` (greps for required headings: `QUICK CHECK`, `САМОПРОВЕРКА`/`SELF-CHECK`, `ФОРМАТ ОТЧЁТА`/`OUTPUT FORMAT`).
- GNU Make — orchestrates linters and validators.
- `markdownlint-cli` (installed globally via npm) — markdown linting.
- `shellcheck` — shell script static analysis (`Makefile:32-34` runs against `scripts/`).
- `pre-commit` (Python) — optional local hook framework via `.pre-commit-config.yaml`.
## Key Dependencies
- `bash` — All installer scripts.
- `curl` — Used by every installer to fetch files from `https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/...` and to call external APIs from `scripts/council/brain.py`.
- `jq` — Required by `scripts/install-statusline.sh:31-40`, `templates/global/rate-limit-probe.sh`, `templates/global/statusline.sh` (parses Keychain JSON and rate-limit cache).
- `git` — Implicit (repo is git-distributed).
- `python3` (>= 3.8) — Required only for Supreme Council; verified in `scripts/setup-council.sh:36-50`.
- `tree` — Optional; auto-installed by `scripts/setup-council.sh:60-75` for project structure analysis in `brain.py`.
- `gemini` CLI (optional) — Installed via `npm install -g @google/gemini-cli`; used in CLI mode by `brain.py:251-260`.
- `security` (macOS Keychain) — Reads Claude Code OAuth token in `templates/global/rate-limit-probe.sh:35` and `scripts/install-statusline.sh:50`.
- `markdownlint-cli` (npm global) — Configured by `.markdownlint.json` (disables MD013/MD033/MD041/MD060; sets MD024.siblings_only=true and MD029.style=ordered).
- `shellcheck` (brew/apt) — Severity threshold `warning` in CI (`.github/workflows/quality.yml:23`) and pre-commit (`.pre-commit-config.yaml:10`).
- `markdownlint-cli2-action@v14` (pinned to SHA `455b6612...`) — CI markdown lint.
- `ludeeus/action-shellcheck@v2.0.0` (pinned to SHA `00b27aa7...`) — CI shell lint.
- `actions/checkout@v4` (pinned to SHA `34e11487...`) — CI checkout.
- `shellcheck-precommit@v0.9.0`
- `markdownlint-cli@v0.37.0`
- `pre-commit-hooks@v4.5.0` (trailing-whitespace, end-of-file-fixer, check-yaml, check-added-large-files --maxkb=500, detect-private-key, check-merge-conflict).
- GitHub Actions — single workflow `.github/workflows/quality.yml` with 4 jobs (shellcheck, markdownlint, validate-templates, test-init-script).
- `permissions: contents: read` set at workflow level (CI security best practice).
## Configuration
- No `.env` file; no environment variables required to use the repo itself.
- Supreme Council reads `~/.claude/council/config.json` (created from `scripts/council/config.json.template`) with optional env overrides `GEMINI_API_KEY` and `OPENAI_API_KEY` (referenced in `scripts/setup-council.sh:98,129`).
- Statusline reads OAuth token from macOS Keychain item `Claude Code-credentials` via `security find-generic-password` — never persisted to disk.
- `Makefile` — primary task runner. Targets: `help`, `check` (= `lint validate`), `lint` (= `shellcheck mdlint`), `shellcheck`, `mdlint`, `test`, `validate`, `install`, `clean`.
- `manifest.json` — version manifest (current `version: 3.0.0`, `updated: 2026-02-16`). Lists all distributable files under `files.{agents,prompts,commands,skills,rules}`, `claude_md_sections.{system,user}`, and `templates.{base,laravel,nextjs,nodejs,python,go,rails}`. Consumed by `scripts/update-claude.sh:67-74` to drive smart updates.
- `.markdownlint.json` — disables MD013 (line length), MD033 (inline HTML), MD041 (first-line-h1), MD060; configures MD024 (siblings_only) and MD029 (ordered style).
- `.pre-commit-config.yaml` — optional local enforcement of the same lint rules.
## Platform Requirements
- macOS or Linux with `bash`, `git`, `make`.
- For lint pass: `shellcheck` + `markdownlint-cli` (installed via `make install`).
- For Supreme Council development: `python3 >= 3.8`, `curl`, `tree`.
- "Production" = end-user developer machines that run `bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)` to install `.claude/` configuration into their own projects.
- Distribution channel: GitHub raw content (no package registry, no CDN).
- CI runs on `ubuntu-latest` GitHub-hosted runners.
- Statusline feature requires macOS specifically (Keychain + BSD `stat`).
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Markdown content files: `kebab-case.md`
- Top-level documentation: `UPPERCASE.md`
- Templated CLAUDE files: directory + `CLAUDE.md` inside
- Audit prompts (inside templates): `UPPER_SNAKE_CASE.md`
- Shell scripts: `kebab-case.sh`
- Skills: directory + `SKILL.md` (uppercase)
- All lowercase: `commands/`, `components/`, `templates/`, `scripts/`,
- Framework templates use lowercase framework names: `templates/laravel/`,
- Two-letter ISO: `cheatsheets/en.md`, `cheatsheets/ru.md`, `cheatsheets/de.md`,
- ALL_CAPS for constants/config: `REPO_URL`, `CLAUDE_DIR`, `DRY_RUN`,
- Color escape codes: `RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC`
- snake_case for local function names: `detect_framework`, `copy_file`,
## Code Style — Markdown
- `MD013` — Line length (disabled for documentation readability)
- `MD033` — Inline HTML (allowed for flexibility, e.g., `<details>`, `<br>`)
- `MD041` — First line must be a top-level heading (not enforced)
- `MD060` — Table alignment (disabled)
- `MD024` — Duplicate headings allowed across different parents (`siblings_only: true`)
- `MD029` — Ordered list items use sequential numbers (`1, 2, 3...`)
- `MD040` — Every fenced code block MUST declare a language. Use `text` for
- `MD031` — Blank line BEFORE and AFTER every fenced code block
- `MD032` — Blank line BEFORE and AFTER every list
- `MD026` — No trailing punctuation in headings (`?`, `:`, `.`, `!` forbidden).
## Code Style — Shell Scripts
#!/bin/bash
#
- Always `set -euo pipefail` at the top (`scripts/init-claude.sh:8`,
- Color codes defined as readonly-style constants at the top of each script
- ANSI color helpers: `RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC` (no color)
- User-facing output uses `echo -e` with color codes
- Argument parsing via `while [[ $# -gt 0 ]]` + `case` block
- Framework auto-detection via file presence checks (`[ -f "artisan" ]`,
- `mkdir -p` before any file copy
- Idempotent install: check `[ ! -f "$file" ]` before overwrite
- Use double-bracket `[[ ... ]]` for conditionals where possible
## Import Organization
## Error Handling
- Fail-fast via `set -euo pipefail` (errors, undefined vars, pipe failures)
- Explicit exit codes on validation failures
- User-facing errors prefixed with `${RED}Error:${NC}` and printed to stdout
- Example pattern from `scripts/install-statusline.sh:24-28`:
- Validation loops accumulate `ERRORS` counter then `exit 1` if non-zero
## Logging
- Success: `${GREEN}✓${NC}` or `✅`
- Warning: `${YELLOW}⚠${NC}`
- Error: `${RED}✗${NC}` or `❌`
- Info/section header: `${BLUE}...${NC}` or `${CYAN}...${NC}`
## Comments
- Header block with name, one-line purpose, and usage examples
- Section dividers using `# ====...====` to separate phases
- Inline comments only when behavior is non-obvious
- HTML comments `<!-- ... -->` for editor-only notes, not rendered in output
## Function Design
- Functions defined before main flow
- Parameters accessed via `$1`, `$2`, with `local` declarations inside body
- Helper pattern from `scripts/init-local.sh:98-117` (`copy_file`):
- Default parameter values via `${3:-default}`
## Module Design
- `components/` — reusable Markdown sections that can be composed into
- `commands/` — self-contained slash command definitions (one `.md` per command)
- `templates/<framework>/` — full opinionated bundle for a framework
- `scripts/` — independent installer scripts, each runnable standalone
## Commit Conventions
- `feat:` — new feature/command/component
- `fix:` — bug fix or correction
- `refactor:` — code restructure without behavior change
- `docs:` — documentation-only changes (rare; most changes ARE docs here)
- `feat: add /design command, facts-only research, plan compliance checks`
- `fix: clarify install runs in terminal, fix settings.json $schema`
- `refactor: redesign Supreme Council from code review to hypothesis validation`
- Never push directly to `main`
- Always `git pull` before commit/push (parallel Claude sessions may push)
- Lower-case summary, no trailing period
- Body explains "why" not "what" when non-trivial
## Branch Naming
- `feature/<name>` — new features (e.g., `feature/learn-auto-load`)
- `fix/<name>` — bug fixes (e.g., `fix/audit-cleanup`, `fix/audit-round2`)
- `refactor/<name>` — refactors
- `docs/<name>` — documentation changes
## CHANGELOG Conventions
## Required Audit Template Sections
- `QUICK CHECK` — 5-minute rapid assessment
- `САМОПРОВЕРКА` or `SELF-CHECK` — false positive filter
- `ФОРМАТ ОТЧЁТА` or `OUTPUT FORMAT` — report template (CI only)
## Knowledge Persistence Convention
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- **Distribution-only.** The repo ships content; consumers fetch it via `curl | bash` against `raw.githubusercontent.com` (see `scripts/init-claude.sh:18` `REPO_URL`).
- **Manifest-driven.** `manifest.json` is the single source of truth for "what files exist and at what version." Both installers and the smart-update script read it.
- **Layered template inheritance.** Framework templates (e.g., `templates/laravel/`) override `templates/base/` on a per-file basis, with automatic fallback to base when a framework-specific file is missing (`scripts/init-claude.sh:289-293`, `scripts/init-local.sh:108-117`).
- **Content-as-code.** Slash commands, agents, prompts, skills, and rules are all Markdown files with YAML frontmatter — interpreted by Claude Code at runtime, not by this repo.
- **Idempotent installs with smart merge.** Update script preserves user-customized sections of `CLAUDE.md` while overwriting toolkit-managed ones (`scripts/update-claude.sh:179-266`).
## Layers
- Purpose: Per-framework starter packages that get copied into a target project's `.claude/`.
- Location: `templates/{base,laravel,rails,nextjs,nodejs,python,go,global}/`
- Contains: `CLAUDE.md`, `settings.json`, `agents/`, `prompts/`, `skills/`, `rules/`.
- Depends on: Nothing (leaf content).
- Used by: `scripts/init-claude.sh`, `scripts/init-local.sh`, `scripts/update-claude.sh` (read selected template path), and `scripts/setup-security.sh` (reads `templates/global/CLAUDE.md`).
- Purpose: Framework-agnostic assets installed for every project regardless of stack.
- Location: `commands/*.md` (29 slash commands), `cheatsheets/{en,ru,es,de,fr,zh,ja,pt,ko}.md`
- Contains: Slash command definitions, multilingual quick-reference cards.
- Depends on: Nothing.
- Used by: All install scripts copy these wholesale (`scripts/init-claude.sh:166-207`, `scripts/init-local.sh:177-196`).
- Purpose: Reusable Markdown sections that humans (or future Claude sessions) embed inside `CLAUDE.md` templates by hand.
- Location: `components/*.md` (29 files), index at `components/README.md`
- Contains: Workflow guides, hardening checklists, MCP guides, severity definitions, etc.
- Depends on: Nothing.
- Used by: Authors of `templates/*/CLAUDE.md` (manual reference, not auto-installed).
- Purpose: Orchestrate downloading/copying of the layers above into a target project.
- Location: `scripts/{init-claude.sh, init-local.sh, update-claude.sh, setup-security.sh, install-statusline.sh, setup-council.sh, verify-install.sh}` plus `scripts/council/{brain.py, README.md, config.json.template}`
- Depends on: `manifest.json` (update script), `templates/`, `commands/`, `cheatsheets/`.
- Used by: End users (via `curl | bash`) and the `Makefile`.
- Purpose: Lint and validate the repo's own content before publishing.
- Location: `Makefile`, `.github/workflows/quality.yml`, `.markdownlint.json`, `.pre-commit-config.yaml`
- Depends on: All content layers.
- Used by: Contributors locally (`make check`) and CI on every push/PR to `main`.
- Purpose: Human-facing explanations and reference projects.
- Location: `docs/{features.md, howto/, readme/}`, `examples/{laravel-saas, monorepo, nextjs-dashboard, playwright-screenshot-service}/`
- Depends on: Nothing.
- Used by: Humans browsing GitHub.
## Data Flow
## Key Abstractions
- Purpose: Declares the canonical list of toolkit files and their target paths, plus the recognized `claude_md_sections` (system vs. user) for smart-merge.
- Examples: `manifest.json:6-71` (file lists), `manifest.json:73-104` (section names), `manifest.json:106-114` (template registry).
- Pattern: Flat JSON, hand-edited, single version field at root.
- Purpose: Self-contained per-stack package with the same internal layout.
- Examples: `templates/base/`, `templates/laravel/`, `templates/nextjs/`, `templates/python/`, `templates/go/`, `templates/rails/`, `templates/nodejs/`, plus `templates/global/` (special: only ships `CLAUDE.md` + statusline scripts for the global home directory install).
- Pattern: `templates/<stack>/{CLAUDE.md, settings.json, agents/*.md, prompts/*.md, rules/*.md, skills/*/SKILL.md}`.
- Purpose: A user-invocable `/name` command in Claude Code.
- Examples: `commands/plan.md`, `commands/audit.md`, `commands/council.md`, `commands/tdd.md` (29 total).
- Pattern: Single Markdown file, kebab-case basename, with `## Purpose`, `## Usage`, `## When to Use` sections.
- Purpose: A capability bundle that Claude loads on demand based on triggers in `skills/skill-rules.json`.
- Examples: `templates/base/skills/{ai-models, api-design, database, debugging, docker, i18n, llm-patterns, observability, tailwind, testing}/SKILL.md`.
- Pattern: Each skill is a directory containing `SKILL.md` (lightweight index); detailed `rules/*.md` may be loaded later by Claude as needed.
- Purpose: Project context that Claude Code reads at session start, scoped via YAML frontmatter `globs:`.
- Examples: `templates/base/rules/{README.md, project-context.md}`, with `lessons-learned.md` seeded by installers (`globs: []` = audit-only, never auto-loaded).
- Pattern: Markdown file with YAML frontmatter declaring `description:` and `globs:`.
- Purpose: Reusable building block that template authors copy/embed into `CLAUDE.md` files.
- Examples: `components/{plan-mode-instructions, structured-workflow, security-hardening, severity-levels, ...}.md`.
- Pattern: Standalone Markdown, indexed by `components/README.md`. Not auto-installed — manual reference only.
- Purpose: Specialized Claude subagent invokable for a specific task.
- Examples: `templates/base/agents/{code-reviewer, planner, security-auditor, test-writer}.md`, plus per-stack experts (e.g., `templates/laravel/agents/laravel-expert.md`).
- Pattern: Markdown file describing the subagent's role and tools.
## Entry Points
- Location: `scripts/init-claude.sh`
- Triggers: `bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)`
- Responsibilities: Detect framework, download all toolkit files into `./.claude/`, optionally configure Supreme Council and recommend security/statusline setup.
- Location: `scripts/init-local.sh`
- Triggers: `/path/to/claude-code-toolkit/scripts/init-local.sh [--dry-run] [framework]`
- Responsibilities: Same as `init-claude.sh` but copies from the local clone instead of HTTP. Also driven by the `Makefile`'s `test` target (`Makefile:42-63`) for self-testing.
- Location: `scripts/update-claude.sh`
- Triggers: `bash <(curl -sSL .../scripts/update-claude.sh)` from inside an existing project.
- Responsibilities: Refresh toolkit files in-place, preserve user-customized sections in `CLAUDE.md`, write backup, bump `.toolkit-version`.
- Location: `scripts/setup-security.sh`
- Triggers: Recommended after `init-claude.sh`; modifies `~/.claude/` (not the project).
- Responsibilities: Install global security rules into `~/.claude/CLAUDE.md`, install `cc-safety-net`, configure combined PreToolUse hook, enable four official Anthropic plugins.
- `scripts/install-statusline.sh` — macOS-only statusline using Keychain OAuth token (requires `jq`).
- `scripts/setup-council.sh` — Standalone Supreme Council installer (also invoked inline by `init-claude.sh:setup_council`).
- `scripts/verify-install.sh` — Read-only health check across toolkit, security, plugins, statusline, council.
- Location: `Makefile`
- Triggers: `make check` (default contributor command, per `CLAUDE.md`).
- Responsibilities: Runs `shellcheck` over `scripts/`, `markdownlint` over all `*.md`, and `validate` (greps audit prompts in `templates/**/prompts/` for required `QUICK CHECK` and `САМОПРОВЕРКА|SELF-CHECK` sections) — `Makefile:65-86`.
- Location: `.github/workflows/quality.yml`
- Triggers: Push to `main`, PR against `main`.
- Responsibilities: Mirrors `make check` (shellcheck + markdownlint + template validation) plus runs `init-local.sh` against synthetic Laravel and Next.js projects in `/tmp` to verify installer correctness (`.github/workflows/quality.yml:70-92`).
- Location: `scripts/council/brain.py`
- Triggers: Shell alias `brain "<plan>"` (added to `~/.zshrc` / `~/.bash_profile` by `init-claude.sh:533-553`) or `/council` slash command.
- Responsibilities: Sends an implementation plan to Gemini and ChatGPT in parallel, collates responses. Reads `~/.claude/council/config.json`.
## Error Handling
- `set -euo pipefail` at the top of every install script — fail fast on undefined variables and pipe errors.
- **Per-file fallback chain.** Remote installer: framework template → base template (`scripts/init-claude.sh:289-294`). Local installer: framework → base → repo root (`scripts/init-local.sh:105-116`).
- **Soft skips on download failure.** `update-claude.sh` logs `⚠ Skipped` when both framework and base downloads fail, but continues (`scripts/update-claude.sh:107-110`).
- **Idempotent file creation.** Lessons-learned, `project-context.md`, `skill-rules.json`, `current-task.md`, and `CLAUDE.md` are created only if missing — never overwritten.
- **Backup before update.** `update-claude.sh:85-87` always creates `.claude-backup-<timestamp>/` before any change.
- **Manifest validation in CI.** `Makefile:66-86` and `.github/workflows/quality.yml:43-68` ensure every audit prompt template contains `QUICK CHECK` and `SELF-CHECK` markers; missing markers fail the build.
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
