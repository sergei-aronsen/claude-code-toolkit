# Coding Conventions

**Analysis Date:** 2026-04-17

This is a documentation/templates repository. "Code" here primarily means
Markdown content and Bash shell scripts. Conventions are enforced by
`markdownlint`, `shellcheck`, and a custom Makefile validation step — all
gated by GitHub Actions in `.github/workflows/quality.yml`.

## Naming Patterns

**Files:**

- Markdown content files: `kebab-case.md`
  - Components: `components/markdown-lint-rules.md`, `components/plan-mode-instructions.md`,
    `components/security-hardening.md`
  - Slash commands: `commands/find-function.md`, `commands/fix-prod.md`,
    `commands/rollback-update.md`
- Top-level documentation: `UPPERCASE.md`
  - `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `LICENSE`,
    `SECURITY.md`
- Templated CLAUDE files: directory + `CLAUDE.md` inside
  - `templates/base/CLAUDE.md`, `templates/laravel/CLAUDE.md`,
    `templates/nextjs/CLAUDE.md`
- Audit prompts (inside templates): `UPPER_SNAKE_CASE.md`
  - `templates/laravel/prompts/SECURITY_AUDIT.md`,
    `templates/laravel/prompts/PERFORMANCE_AUDIT.md`,
    `templates/laravel/prompts/CODE_REVIEW.md`,
    `templates/laravel/prompts/DEPLOY_CHECKLIST.md`
- Shell scripts: `kebab-case.sh`
  - `scripts/init-claude.sh`, `scripts/init-local.sh`, `scripts/setup-security.sh`,
    `scripts/install-statusline.sh`, `scripts/update-claude.sh`,
    `scripts/verify-install.sh`
- Skills: directory + `SKILL.md` (uppercase)
  - `templates/base/skills/database/SKILL.md`,
    `templates/base/skills/debugging/SKILL.md`

**Directories:**

- All lowercase: `commands/`, `components/`, `templates/`, `scripts/`,
  `cheatsheets/`, `examples/`, `docs/`
- Framework templates use lowercase framework names: `templates/laravel/`,
  `templates/nextjs/`, `templates/nodejs/`, `templates/python/`, `templates/go/`,
  `templates/rails/`, `templates/base/`

**Cheatsheet locale codes:**

- Two-letter ISO: `cheatsheets/en.md`, `cheatsheets/ru.md`, `cheatsheets/de.md`,
  `cheatsheets/fr.md`, `cheatsheets/es.md`, `cheatsheets/pt.md`,
  `cheatsheets/zh.md`, `cheatsheets/ja.md`, `cheatsheets/ko.md`

**Bash variables (in scripts):**

- ALL_CAPS for constants/config: `REPO_URL`, `CLAUDE_DIR`, `DRY_RUN`,
  `FRAMEWORK`, `SCRIPT_DIR`, `GUIDES_DIR`
- Color escape codes: `RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC`
- snake_case for local function names: `detect_framework`, `copy_file`,
  `select_framework`

## Code Style — Markdown

**Linter:** `markdownlint-cli` (and `markdownlint-cli2` in CI)

**Config:** `.markdownlint.json`

```json
{
  "default": true,
  "MD013": false,
  "MD033": false,
  "MD041": false,
  "MD060": false,
  "MD024": { "siblings_only": true },
  "MD029": { "style": "ordered" }
}
```

**Disabled rules:**

- `MD013` — Line length (disabled for documentation readability)
- `MD033` — Inline HTML (allowed for flexibility, e.g., `<details>`, `<br>`)
- `MD041` — First line must be a top-level heading (not enforced)
- `MD060` — Table alignment (disabled)

**Tweaked rules:**

- `MD024` — Duplicate headings allowed across different parents (`siblings_only: true`)
- `MD029` — Ordered list items use sequential numbers (`1, 2, 3...`)

**Critical rules to follow (enforced by CI):**

- `MD040` — Every fenced code block MUST declare a language. Use `text` for
  plain text, `markdown` for markdown samples. Allowed languages used in repo:
  `bash`, `text`, `markdown`, `json`, `yaml`, `python`, `javascript`,
  `typescript`, `php`, `sql`, `html`, `css`
- `MD031` — Blank line BEFORE and AFTER every fenced code block
- `MD032` — Blank line BEFORE and AFTER every list
- `MD026` — No trailing punctuation in headings (`?`, `:`, `.`, `!` forbidden).
  Use `## What is This` not `## What is this?`

**Reference document:** `components/markdown-lint-rules.md` documents these
rules in detail with bad/good examples — copy this section into new templates'
CLAUDE.md files.

**Run locally:**

```bash
# Check all markdown files
npx markdownlint-cli "**/*.md" --ignore node_modules

# Auto-fix what can be fixed
npx markdownlint-cli "**/*.md" --ignore node_modules --fix

# Or via Makefile
make mdlint
```

## Code Style — Shell Scripts

**Linter:** `shellcheck` (severity `warning` in pre-commit and CI)

**Mandatory script header:**

```bash
#!/bin/bash
# script-name.sh — One-line description
#
# Usage:
#   bash <(curl -sSL ...)
#   ./script-name.sh [--flag] [arg]

set -euo pipefail
```

**Patterns observed across `scripts/*.sh`:**

- Always `set -euo pipefail` at the top (`scripts/init-claude.sh:8`,
  `scripts/init-local.sh:9`, `scripts/setup-security.sh:9`,
  `scripts/install-statusline.sh:7`)
- Color codes defined as readonly-style constants at the top of each script
- ANSI color helpers: `RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC` (no color)
- User-facing output uses `echo -e` with color codes
- Argument parsing via `while [[ $# -gt 0 ]]` + `case` block
- Framework auto-detection via file presence checks (`[ -f "artisan" ]`,
  `[ -f "next.config.js" ]`, etc.)
- `mkdir -p` before any file copy
- Idempotent install: check `[ ! -f "$file" ]` before overwrite
- Use double-bracket `[[ ... ]]` for conditionals where possible

**Run locally:**

```bash
# Direct
shellcheck scripts/*.sh

# Via Makefile (uses find + exec)
make shellcheck
```

## Import Organization

Not applicable — no source code with import statements. Markdown links use
relative paths (`./components/foo.md`) or full GitHub raw URLs from
`scripts/init-claude.sh:18` (`REPO_URL`).

## Error Handling

**Shell scripts:**

- Fail-fast via `set -euo pipefail` (errors, undefined vars, pipe failures)
- Explicit exit codes on validation failures
- User-facing errors prefixed with `${RED}Error:${NC}` and printed to stdout
- Example pattern from `scripts/install-statusline.sh:24-28`:

  ```bash
  if [[ "$(uname)" != "Darwin" ]]; then
      echo -e "${RED}Error: This tool requires macOS.${NC}"
      exit 1
  fi
  ```

- Validation loops accumulate `ERRORS` counter then `exit 1` if non-zero
  (see `Makefile:67-85`, `.github/workflows/quality.yml:46-67`)

## Logging

**Approach:** Plain `echo -e` with ANSI colors. No external logger.

**Conventions:**

- Success: `${GREEN}✓${NC}` or `✅`
- Warning: `${YELLOW}⚠${NC}`
- Error: `${RED}✗${NC}` or `❌`
- Info/section header: `${BLUE}...${NC}` or `${CYAN}...${NC}`

## Comments

**Shell scripts:**

- Header block with name, one-line purpose, and usage examples
- Section dividers using `# ====...====` to separate phases
  (see `scripts/init-local.sh:142, 153, 162, 173`)
- Inline comments only when behavior is non-obvious

**Markdown:**

- HTML comments `<!-- ... -->` for editor-only notes, not rendered in output
  (see `templates/base/skills/*/SKILL.md`, `scripts/init-local.sh:217`)

## Function Design

**Shell scripts:**

- Functions defined before main flow
- Parameters accessed via `$1`, `$2`, with `local` declarations inside body
- Helper pattern from `scripts/init-local.sh:98-117` (`copy_file`):

  ```bash
  copy_file() {
      local src="$1"
      local dest="$2"
      local label="${3:-$dest}"
      # ... body
  }
  ```

- Default parameter values via `${3:-default}`

## Module Design

Not applicable — no programming modules. Conceptual modules:

- `components/` — reusable Markdown sections that can be composed into
  CLAUDE.md files
- `commands/` — self-contained slash command definitions (one `.md` per command)
- `templates/<framework>/` — full opinionated bundle for a framework
- `scripts/` — independent installer scripts, each runnable standalone

## Commit Conventions

**Style:** Conventional Commits (enforced by convention, not tooling)

**Allowed types observed in `git log`:**

- `feat:` — new feature/command/component
- `fix:` — bug fix or correction
- `refactor:` — code restructure without behavior change
- `docs:` — documentation-only changes (rare; most changes ARE docs here)

**Format:**

```text
<type>: <imperative summary in lowercase>
```

**Examples from history:**

- `feat: add /design command, facts-only research, plan compliance checks`
- `fix: clarify install runs in terminal, fix settings.json $schema`
- `refactor: redesign Supreme Council from code review to hypothesis validation`

**Rules (from `CLAUDE.md` and global conventions):**

- Never push directly to `main`
- Always `git pull` before commit/push (parallel Claude sessions may push)
- Lower-case summary, no trailing period
- Body explains "why" not "what" when non-trivial

## Branch Naming

**Pattern:** `<type>/<short-description>` (kebab-case)

**Active/historical branches in repo:**

- `feature/<name>` — new features (e.g., `feature/learn-auto-load`)
- `fix/<name>` — bug fixes (e.g., `fix/audit-cleanup`, `fix/audit-round2`)
- `refactor/<name>` — refactors
- `docs/<name>` — documentation changes

## CHANGELOG Conventions

**Format:** Keep a Changelog (`https://keepachangelog.com/en/1.0.0/`)

**Versioning:** Semantic Versioning (`https://semver.org/spec/v2.0.0.html`)

**Sections:** `### Added`, `### Changed`, `### Fixed`, `### Removed` under
each `## [X.Y.Z] - YYYY-MM-DD` heading. Top of file always has an
`## [Unreleased]` block. See `CHANGELOG.md:1-10`.

## Required Audit Template Sections

When adding/editing files under `templates/*/prompts/`, the following
sections are mandatory (validated in CI by `.github/workflows/quality.yml:48-67`
and `Makefile:67-85`):

- `QUICK CHECK` — 5-minute rapid assessment
- `САМОПРОВЕРКА` or `SELF-CHECK` — false positive filter
- `ФОРМАТ ОТЧЁТА` or `OUTPUT FORMAT` — report template (CI only)

Files validated: `SECURITY_AUDIT.md`, `PERFORMANCE_AUDIT.md`, `CODE_REVIEW.md`,
`DEPLOY_CHECKLIST.md` inside any `templates/*/prompts/` directory.

## Knowledge Persistence Convention

When making significant changes, update three locations (per `CLAUDE.md:103-127`):

1. `CLAUDE.md` or relevant template — for Claude Code instructions
2. `README.md` / `docs/` — for human readers
3. `.claude/rules/project-context.md` — for auto-loaded session context

---

*Convention analysis: 2026-04-17*
