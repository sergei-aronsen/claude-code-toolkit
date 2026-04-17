# Architecture

**Analysis Date:** 2026-04-17

## Pattern Overview

**Overall:** Static asset library / template repository (no runtime). The repo is a curated collection of Markdown documents, JSON configs, and Bash installers that are downloaded into a target project's `.claude/` directory by installer scripts. There is no application server, no compiled artifact, no runtime — the "execution" happens in two places: (1) the installer scripts at install time, and (2) Claude Code itself when it reads the installed files.

**Key Characteristics:**

- **Distribution-only.** The repo ships content; consumers fetch it via `curl | bash` against `raw.githubusercontent.com` (see `scripts/init-claude.sh:18` `REPO_URL`).
- **Manifest-driven.** `manifest.json` is the single source of truth for "what files exist and at what version." Both installers and the smart-update script read it.
- **Layered template inheritance.** Framework templates (e.g., `templates/laravel/`) override `templates/base/` on a per-file basis, with automatic fallback to base when a framework-specific file is missing (`scripts/init-claude.sh:289-293`, `scripts/init-local.sh:108-117`).
- **Content-as-code.** Slash commands, agents, prompts, skills, and rules are all Markdown files with YAML frontmatter — interpreted by Claude Code at runtime, not by this repo.
- **Idempotent installs with smart merge.** Update script preserves user-customized sections of `CLAUDE.md` while overwriting toolkit-managed ones (`scripts/update-claude.sh:179-266`).

## Layers

**Layer 1 — Templates (`templates/`)**

- Purpose: Per-framework starter packages that get copied into a target project's `.claude/`.
- Location: `templates/{base,laravel,rails,nextjs,nodejs,python,go,global}/`
- Contains: `CLAUDE.md`, `settings.json`, `agents/`, `prompts/`, `skills/`, `rules/`.
- Depends on: Nothing (leaf content).
- Used by: `scripts/init-claude.sh`, `scripts/init-local.sh`, `scripts/update-claude.sh` (read selected template path), and `scripts/setup-security.sh` (reads `templates/global/CLAUDE.md`).

**Layer 2 — Shared content (`commands/`, `cheatsheets/`)**

- Purpose: Framework-agnostic assets installed for every project regardless of stack.
- Location: `commands/*.md` (29 slash commands), `cheatsheets/{en,ru,es,de,fr,zh,ja,pt,ko}.md`
- Contains: Slash command definitions, multilingual quick-reference cards.
- Depends on: Nothing.
- Used by: All install scripts copy these wholesale (`scripts/init-claude.sh:166-207`, `scripts/init-local.sh:177-196`).

**Layer 3 — Components (`components/`)**

- Purpose: Reusable Markdown sections that humans (or future Claude sessions) embed inside `CLAUDE.md` templates by hand.
- Location: `components/*.md` (29 files), index at `components/README.md`
- Contains: Workflow guides, hardening checklists, MCP guides, severity definitions, etc.
- Depends on: Nothing.
- Used by: Authors of `templates/*/CLAUDE.md` (manual reference, not auto-installed).

**Layer 4 — Installer scripts (`scripts/`)**

- Purpose: Orchestrate downloading/copying of the layers above into a target project.
- Location: `scripts/{init-claude.sh, init-local.sh, update-claude.sh, setup-security.sh, install-statusline.sh, setup-council.sh, verify-install.sh}` plus `scripts/council/{brain.py, README.md, config.json.template}`
- Depends on: `manifest.json` (update script), `templates/`, `commands/`, `cheatsheets/`.
- Used by: End users (via `curl | bash`) and the `Makefile`.

**Layer 5 — Quality gates (`Makefile`, `.github/workflows/`)**

- Purpose: Lint and validate the repo's own content before publishing.
- Location: `Makefile`, `.github/workflows/quality.yml`, `.markdownlint.json`, `.pre-commit-config.yaml`
- Depends on: All content layers.
- Used by: Contributors locally (`make check`) and CI on every push/PR to `main`.

**Layer 6 — Documentation (`docs/`, `examples/`, `README.md`, `CHANGELOG.md`)**

- Purpose: Human-facing explanations and reference projects.
- Location: `docs/{features.md, howto/, readme/}`, `examples/{laravel-saas, monorepo, nextjs-dashboard, playwright-screenshot-service}/`
- Depends on: Nothing.
- Used by: Humans browsing GitHub.

## Data Flow

**Flow 1 — Remote install (`init-claude.sh` from curl)**

1. User runs `bash <(curl -sSL .../scripts/init-claude.sh) [framework]`.
2. Script parses CLI args; if no framework given, runs `detect_framework()` against marker files (`artisan`, `next.config.*`, `go.mod`, etc.) at `scripts/init-claude.sh:49-65`.
3. Interactive menu (`select_framework()` at `scripts/init-claude.sh:68-103`) confirms the stack if `/dev/tty` is available.
4. `create_structure()` makes `.claude/{prompts,agents,commands,skills,rules,docs,cheatsheets,scratchpad}` directories.
5. `download_files()` iterates `FILES[]` (a hardcoded `src:dest` list at `scripts/init-claude.sh:128-207`), `curl`s each from `REPO_URL` to `.claude/$dest`, with base-template fallback on 404 (`scripts/init-claude.sh:291-293`).
6. Framework-specific extras (e.g., `laravel-expert.md` agent and `skills/laravel/SKILL.md`) appended at `scripts/init-claude.sh:210-240`.
7. `create_gitignore()`, `create_scratchpad()`, `create_lessons_learned()` seed local-only files.
8. Optional `setup_council()` downloads `scripts/council/brain.py` to `~/.claude/council/` and writes `config.json` (chmod 600).
9. `create_post_install()` writes `.claude/POST_INSTALL.md` for Claude to read on next session.

**Flow 2 — Local install (`init-local.sh` from a clone)**

1. Runs from inside this repo: `SCRIPT_DIR` derived via `BASH_SOURCE`, `GUIDES_DIR` is the repo root (`scripts/init-local.sh:13-15`).
2. Same framework detection as Flow 1.
3. `copy_file()` helper (`scripts/init-local.sh:98-117`) tries `templates/$FRAMEWORK/`, then `templates/base/`, then `$GUIDES_DIR/$src` — pure local file copy, no network.
4. Iterates fixed lists: 7 prompts, 4 agents, 10 skills, then loops `commands/*.md` and `cheatsheets/*.md` wholesale.
5. Skips `CLAUDE.md` and `settings.json` if they already exist (preserves user edits).

**Flow 3 — Smart update (`update-claude.sh`)**

1. Requires existing `.claude/` directory; aborts with init suggestion if missing (`scripts/update-claude.sh:55-60`).
2. Fetches `manifest.json` from REPO_URL, parses `"version"` via `grep -o`.
3. Reads `.claude/.toolkit-version` for local version (defaults `unknown`).
4. Creates timestamped backup: `.claude-backup-YYYYMMDD-HHMMSS` via `cp -r`.
5. Re-downloads agents, prompts, skills, commands from remote, with base-template fallback.
6. **Smart-merge `CLAUDE.md`** (`scripts/update-claude.sh:166-266`): downloads new template, extracts user sections (`## 🎯 Project Overview`, `## 📁 Project Structure`, `## ⚡ Essential Commands`, `## ⚠️ Project-Specific Notes`) from existing file via `sed -n`, splices them into the new template by line-number computation.
7. Preserves `rules/*` and `skills/skill-rules.json` if they already exist.
8. Writes new version to `.claude/.toolkit-version`.

**Flow 4 — Global security setup (`setup-security.sh`)**

1. Operates on `~/.claude/CLAUDE.md` (global, not project) at `scripts/setup-security.sh:21`.
2. Downloads `templates/global/CLAUDE.md` and merges section-by-section: detects `## NN. TITLE` headers, appends only missing numbered sections (`scripts/setup-security.sh:64-99`).
3. Installs `cc-safety-net` npm package globally if `npm` available.
4. Generates `~/.claude/hooks/pre-bash.sh` — a combined PreToolUse hook running safety-net first, then RTK rewrite (`scripts/setup-security.sh:146-186`).
5. Patches `~/.claude/settings.json` via inline Python: removes prior Bash hooks, adds the combined one, ensures `enabledPlugins` for the four official Anthropic plugins.

## Key Abstractions

**Manifest entry**

- Purpose: Declares the canonical list of toolkit files and their target paths, plus the recognized `claude_md_sections` (system vs. user) for smart-merge.
- Examples: `manifest.json:6-71` (file lists), `manifest.json:73-104` (section names), `manifest.json:106-114` (template registry).
- Pattern: Flat JSON, hand-edited, single version field at root.

**Framework template**

- Purpose: Self-contained per-stack package with the same internal layout.
- Examples: `templates/base/`, `templates/laravel/`, `templates/nextjs/`, `templates/python/`, `templates/go/`, `templates/rails/`, `templates/nodejs/`, plus `templates/global/` (special: only ships `CLAUDE.md` + statusline scripts for the global home directory install).
- Pattern: `templates/<stack>/{CLAUDE.md, settings.json, agents/*.md, prompts/*.md, rules/*.md, skills/*/SKILL.md}`.

**Slash command**

- Purpose: A user-invocable `/name` command in Claude Code.
- Examples: `commands/plan.md`, `commands/audit.md`, `commands/council.md`, `commands/tdd.md` (29 total).
- Pattern: Single Markdown file, kebab-case basename, with `## Purpose`, `## Usage`, `## When to Use` sections.

**Skill (progressive-disclosure)**

- Purpose: A capability bundle that Claude loads on demand based on triggers in `skills/skill-rules.json`.
- Examples: `templates/base/skills/{ai-models, api-design, database, debugging, docker, i18n, llm-patterns, observability, tailwind, testing}/SKILL.md`.
- Pattern: Each skill is a directory containing `SKILL.md` (lightweight index); detailed `rules/*.md` may be loaded later by Claude as needed.

**Auto-loaded rule**

- Purpose: Project context that Claude Code reads at session start, scoped via YAML frontmatter `globs:`.
- Examples: `templates/base/rules/{README.md, project-context.md}`, with `lessons-learned.md` seeded by installers (`globs: []` = audit-only, never auto-loaded).
- Pattern: Markdown file with YAML frontmatter declaring `description:` and `globs:`.

**Component (reference document)**

- Purpose: Reusable building block that template authors copy/embed into `CLAUDE.md` files.
- Examples: `components/{plan-mode-instructions, structured-workflow, security-hardening, severity-levels, ...}.md`.
- Pattern: Standalone Markdown, indexed by `components/README.md`. Not auto-installed — manual reference only.

**Agent (subagent definition)**

- Purpose: Specialized Claude subagent invokable for a specific task.
- Examples: `templates/base/agents/{code-reviewer, planner, security-auditor, test-writer}.md`, plus per-stack experts (e.g., `templates/laravel/agents/laravel-expert.md`).
- Pattern: Markdown file describing the subagent's role and tools.

## Entry Points

**Remote installer (the canonical entry point)**

- Location: `scripts/init-claude.sh`
- Triggers: `bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)`
- Responsibilities: Detect framework, download all toolkit files into `./.claude/`, optionally configure Supreme Council and recommend security/statusline setup.

**Local installer (for cloned repo)**

- Location: `scripts/init-local.sh`
- Triggers: `/path/to/claude-code-toolkit/scripts/init-local.sh [--dry-run] [framework]`
- Responsibilities: Same as `init-claude.sh` but copies from the local clone instead of HTTP. Also driven by the `Makefile`'s `test` target (`Makefile:42-63`) for self-testing.

**Smart updater**

- Location: `scripts/update-claude.sh`
- Triggers: `bash <(curl -sSL .../scripts/update-claude.sh)` from inside an existing project.
- Responsibilities: Refresh toolkit files in-place, preserve user-customized sections in `CLAUDE.md`, write backup, bump `.toolkit-version`.

**Global security setup**

- Location: `scripts/setup-security.sh`
- Triggers: Recommended after `init-claude.sh`; modifies `~/.claude/` (not the project).
- Responsibilities: Install global security rules into `~/.claude/CLAUDE.md`, install `cc-safety-net`, configure combined PreToolUse hook, enable four official Anthropic plugins.

**Optional installers**

- `scripts/install-statusline.sh` — macOS-only statusline using Keychain OAuth token (requires `jq`).
- `scripts/setup-council.sh` — Standalone Supreme Council installer (also invoked inline by `init-claude.sh:setup_council`).
- `scripts/verify-install.sh` — Read-only health check across toolkit, security, plugins, statusline, council.

**Quality gate (developer entry point)**

- Location: `Makefile`
- Triggers: `make check` (default contributor command, per `CLAUDE.md`).
- Responsibilities: Runs `shellcheck` over `scripts/`, `markdownlint` over all `*.md`, and `validate` (greps audit prompts in `templates/**/prompts/` for required `QUICK CHECK` and `САМОПРОВЕРКА|SELF-CHECK` sections) — `Makefile:65-86`.

**CI entry point**

- Location: `.github/workflows/quality.yml`
- Triggers: Push to `main`, PR against `main`.
- Responsibilities: Mirrors `make check` (shellcheck + markdownlint + template validation) plus runs `init-local.sh` against synthetic Laravel and Next.js projects in `/tmp` to verify installer correctness (`.github/workflows/quality.yml:70-92`).

**Supreme Council runtime entry**

- Location: `scripts/council/brain.py`
- Triggers: Shell alias `brain "<plan>"` (added to `~/.zshrc` / `~/.bash_profile` by `init-claude.sh:533-553`) or `/council` slash command.
- Responsibilities: Sends an implementation plan to Gemini and ChatGPT in parallel, collates responses. Reads `~/.claude/council/config.json`.

## Error Handling

**Strategy:** Best-effort installation with graceful fallbacks, not strict failure.

**Patterns:**

- `set -euo pipefail` at the top of every install script — fail fast on undefined variables and pipe errors.
- **Per-file fallback chain.** Remote installer: framework template → base template (`scripts/init-claude.sh:289-294`). Local installer: framework → base → repo root (`scripts/init-local.sh:105-116`).
- **Soft skips on download failure.** `update-claude.sh` logs `⚠ Skipped` when both framework and base downloads fail, but continues (`scripts/update-claude.sh:107-110`).
- **Idempotent file creation.** Lessons-learned, `project-context.md`, `skill-rules.json`, `current-task.md`, and `CLAUDE.md` are created only if missing — never overwritten.
- **Backup before update.** `update-claude.sh:85-87` always creates `.claude-backup-<timestamp>/` before any change.
- **Manifest validation in CI.** `Makefile:66-86` and `.github/workflows/quality.yml:43-68` ensure every audit prompt template contains `QUICK CHECK` and `SELF-CHECK` markers; missing markers fail the build.

## Cross-Cutting Concerns

**Logging:** Bash scripts use color-coded `echo -e` with ANSI escape codes (`RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC`). `scripts/update-claude.sh` and `scripts/verify-install.sh` define semantic helpers (`log_info`, `log_success`, `log_warning`, `log_error`, `pass`, `fail`, `warn`).

**Validation:** Template authoring rules enforced by `make validate` and CI: every audit prompt must contain `QUICK CHECK` and `САМОПРОВЕРКА|SELF-CHECK` headings. Markdown style enforced by `.markdownlint.json` (rules MD040, MD031/032, MD026 are explicitly called out in `CLAUDE.md`).

**Authentication:** None at the toolkit level. The Supreme Council component reads API keys from `~/.claude/council/config.json` (chmod 600) and from `OPENAI_API_KEY` / `GEMINI_API_KEY` environment variables. Statusline reads OAuth tokens from macOS Keychain.

**Versioning:** Single `version` field in `manifest.json:2` is the source of truth. Installers stamp `.claude/.toolkit-version` with that value so the updater can detect drift. `CHANGELOG.md` is the human-readable record.

**Internationalization:** Reference docs and quick-reference cards exist in 9 languages (`cheatsheets/{en,ru,es,de,fr,zh,ja,ko,pt}.md`, `docs/howto/{same}.md`, `docs/readme/{same minus en}.md`). Project-level CLAUDE.md templates are English-only.

---

*Architecture analysis: 2026-04-17*
