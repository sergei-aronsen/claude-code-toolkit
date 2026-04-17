# Codebase Structure

**Analysis Date:** 2026-04-17

## Directory Layout

```text
claude-code-toolkit/
├── templates/                      # Per-framework starter packages
│   ├── base/                       # Generic baseline (fallback for all stacks)
│   │   ├── CLAUDE.md               # Root project instructions
│   │   ├── settings.json           # Claude Code settings template
│   │   ├── agents/                 # 4 base subagents
│   │   ├── prompts/                # 7 audit prompt templates
│   │   ├── skills/                 # 10 skill bundles + skill-rules.json
│   │   └── rules/                  # Auto-loaded project rules
│   ├── laravel/                    # Laravel-specific overrides
│   ├── rails/                      # Ruby on Rails overrides
│   ├── nextjs/                     # Next.js overrides
│   ├── nodejs/                     # Generic Node.js overrides
│   ├── python/                     # Python overrides
│   ├── go/                         # Go overrides
│   └── global/                     # Special: ~/.claude/CLAUDE.md content
│       ├── CLAUDE.md               # Global security rules (14 sections)
│       ├── statusline.sh           # macOS rate-limit statusline
│       └── rate-limit-probe.sh
├── commands/                       # 29 slash commands (kebab-case.md)
├── components/                     # 29 reusable Markdown reference docs
│   └── README.md                   # Index of all components
├── cheatsheets/                    # Quick-reference cards in 9 languages
│   └── {en,ru,es,de,fr,zh,ja,pt,ko}.md
├── scripts/                        # Bash + Python installers
│   ├── init-claude.sh              # Remote installer (curl entry point)
│   ├── init-local.sh               # Local installer (from clone)
│   ├── update-claude.sh            # Smart updater (manifest-driven)
│   ├── setup-security.sh           # Global security setup
│   ├── install-statusline.sh       # macOS statusline (optional)
│   ├── setup-council.sh            # Supreme Council standalone setup
│   ├── verify-install.sh           # Health check
│   └── council/                    # Supreme Council runtime
│       ├── brain.py                # Multi-AI orchestrator
│       ├── config.json.template
│       └── README.md
├── docs/                           # Human-facing documentation
│   ├── features.md
│   ├── howto/{en,ru,es,de,fr,zh,ja,pt,ko}.md
│   └── readme/{ru,es,de,fr,zh,ja,pt,ko}.md
├── examples/                       # Reference CLAUDE.md examples
│   ├── laravel-saas/CLAUDE.md
│   ├── monorepo/CLAUDE.md
│   ├── nextjs-dashboard/CLAUDE.md
│   └── playwright-screenshot-service/README.md
├── .github/                        # GitHub metadata
│   ├── workflows/quality.yml       # CI: shellcheck + markdownlint + template validation
│   ├── ISSUE_TEMPLATE/{bug_report.md, template_request.md}
│   └── PULL_REQUEST_TEMPLATE.md
├── .claude/                        # This repo's own Claude Code config
│   ├── settings.local.json
│   ├── activity.log
│   ├── audit.log
│   └── scratchpad/
├── .planning/                      # GSD planning artifacts (this directory)
│   └── codebase/                   # Codebase mapping outputs
├── manifest.json                   # Version + canonical file list
├── Makefile                        # `make check`, `make test`, `make validate`
├── CLAUDE.md                       # Instructions for Claude when editing this repo
├── README.md                       # English README
├── CHANGELOG.md                    # Versioned change log
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE                         # MIT
├── .markdownlint.json              # markdownlint config
├── .pre-commit-config.yaml         # pre-commit hooks
└── .gitignore
```

## Directory Purposes

**`templates/`**

- Purpose: Per-framework starter packages copied into a target project's `.claude/`.
- Contains: One subdirectory per supported stack. Every subdirectory has the same internal layout (`CLAUDE.md`, `settings.json`, `agents/`, `prompts/`, `skills/`, `rules/`) so the installer can substitute one for another transparently.
- Key files: `templates/base/CLAUDE.md` (the canonical project-level template), `templates/global/CLAUDE.md` (global security rules for `~/.claude/`), each stack's `settings.json`.
- Stacks supported: `base`, `laravel`, `rails`, `nextjs`, `nodejs`, `python`, `go`, `global`.

**`commands/`**

- Purpose: Slash commands installed into every project regardless of stack.
- Contains: 29 `kebab-case.md` files, one per command.
- Key files: `commands/plan.md`, `commands/audit.md`, `commands/tdd.md`, `commands/council.md`, `commands/update-toolkit.md`, `commands/verify.md`, `commands/learn.md`.
- Naming: `kebab-case.md` — basename becomes the slash command (e.g., `find-function.md` → `/find-function`).

**`components/`**

- Purpose: Reusable Markdown sections that template authors embed into `CLAUDE.md` by hand. NOT auto-installed.
- Contains: 29 reference documents grouped into Workflow, Skills, Knowledge, Testing, Audit, DevOps, etc.
- Key files: `components/README.md` (the table-of-contents indexing all components by category), `components/structured-workflow.md`, `components/security-hardening.md`, `components/severity-levels.md`, `components/spec-driven-development.md`.

**`cheatsheets/`**

- Purpose: Quick-reference cards in 9 languages, copied wholesale into every install.
- Contains: One Markdown file per ISO language code.
- Key files: `cheatsheets/en.md`, `cheatsheets/ru.md` (+ es, de, fr, zh, ja, pt, ko).

**`scripts/`**

- Purpose: Bash installers and the Python Supreme Council orchestrator.
- Contains: 7 top-level `.sh` files plus `scripts/council/` for the Python brain.
- Key files: `scripts/init-claude.sh` (remote installer, the canonical entry point), `scripts/init-local.sh` (offline equivalent), `scripts/update-claude.sh` (smart-merge updater), `scripts/setup-security.sh` (global security), `scripts/council/brain.py` (multi-AI review).

**`docs/`**

- Purpose: Long-form human documentation hosted in the repo.
- Contains: `features.md` (feature catalog), `howto/` (how-to guides per language), `readme/` (translated READMEs).
- Key files: `docs/features.md`, `docs/howto/en.md`, `docs/readme/ru.md`.

**`examples/`**

- Purpose: Reference `CLAUDE.md` files showing the toolkit applied to real-world project shapes.
- Contains: Four example projects, each with a single `CLAUDE.md` (or `README.md` for playwright-screenshot-service).
- Key files: `examples/laravel-saas/CLAUDE.md`, `examples/monorepo/CLAUDE.md`, `examples/nextjs-dashboard/CLAUDE.md`.

**`.github/`**

- Purpose: GitHub-specific metadata.
- Contains: One workflow (`quality.yml`), two issue templates, one PR template.
- Key files: `.github/workflows/quality.yml` (the only CI pipeline).

**`.claude/`**

- Purpose: This repo's own Claude Code configuration (eat-your-own-dogfood).
- Contains: Local settings, scratchpad, activity/audit logs.
- Generated/runtime: Not produced by the installer (since the repo authors edit it directly), but mirrors the structure installers create elsewhere.

**`.planning/`**

- Purpose: GSD command artifacts (planning, codebase mapping outputs).
- Contains: `codebase/` for the documents produced by `/gsd-map-codebase`.

## Key File Locations

**Entry Points:**

- `scripts/init-claude.sh`: Remote curl-pipe installer — primary user entry point.
- `scripts/init-local.sh`: Local installer used from a clone and by `Makefile` self-tests.
- `scripts/update-claude.sh`: Smart updater for already-installed projects.
- `scripts/setup-security.sh`: Global `~/.claude/` security hardening.
- `Makefile`: Contributor entry point — `make check`, `make test`, `make validate`.

**Configuration:**

- `manifest.json`: Source-of-truth version + file inventory + section taxonomy.
- `.markdownlint.json`: Markdown lint rules (enforces MD040, MD031/032, MD026).
- `.pre-commit-config.yaml`: Pre-commit hook chain.
- `.gitignore`: Repo-level ignore.
- `templates/base/settings.json` and per-stack `settings.json`: Claude Code settings deployed by installers.

**Core Logic:**

- `scripts/init-claude.sh`: 660 lines. Framework detection, file download list (lines 128-207), per-framework extras (lines 210-240), Council bootstrap (lines 397-557).
- `scripts/update-claude.sh`: 302 lines. Manifest fetch, file refresh, smart `CLAUDE.md` merge (lines 166-266).
- `scripts/setup-security.sh`: 498 lines. Section-by-section merge of global rules, hook generation, plugin enabling.
- `scripts/council/brain.py`: Python orchestrator for Gemini + ChatGPT review.

**Testing:**

- `Makefile:42-63`: `make test` target — runs `init-local.sh` against synthetic Laravel/Next.js/generic projects in `/tmp`.
- `.github/workflows/quality.yml:70-92`: Same tests, but in CI.
- `Makefile:65-86` and `.github/workflows/quality.yml:43-68`: Template content validation (audit prompts must contain `QUICK CHECK` and `SELF-CHECK`).
- `scripts/verify-install.sh`: Read-only post-install health check.

## Naming Conventions

**Files:**

- **Components:** `kebab-case.md` (e.g., `components/plan-mode-instructions.md`, `components/security-hardening.md`).
- **Slash commands:** `kebab-case.md` (e.g., `commands/find-function.md`, `commands/update-toolkit.md`). Basename becomes the `/command` name.
- **Templates:** Each stack is a directory containing `CLAUDE.md` + `settings.json` + the standard subfolders. Always `CLAUDE.md` (uppercase, no hyphens) — never `claude.md` or `CLAUDE.MD`.
- **Audit prompts:** `SCREAMING_SNAKE_CASE.md` (e.g., `templates/base/prompts/SECURITY_AUDIT.md`, `PERFORMANCE_AUDIT.md`, `CODE_REVIEW.md`, `DEPLOY_CHECKLIST.md`, `MYSQL_PERFORMANCE_AUDIT.md`, `POSTGRES_PERFORMANCE_AUDIT.md`, `DESIGN_REVIEW.md`).
- **Agents:** `kebab-case.md` (e.g., `templates/base/agents/code-reviewer.md`, `security-auditor.md`).
- **Skills:** Each skill is a directory; the entry file is always `SKILL.md` (uppercase). Skill directory names are `kebab-case` or single lowercase words (e.g., `templates/base/skills/api-design/SKILL.md`, `skills/llm-patterns/SKILL.md`).
- **Cheatsheets / docs translations:** ISO 639-1 language code (e.g., `cheatsheets/ru.md`, `docs/howto/ja.md`).
- **Shell scripts:** `kebab-case.sh` in `scripts/` (e.g., `init-claude.sh`, `setup-security.sh`).
- **Top-level metadata:** `SCREAMING_CASE.md` (e.g., `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`).

**Directories:**

- **Stack templates:** lowercase single word (`templates/laravel`, `templates/nextjs`, `templates/python`).
- **Skill folders:** `kebab-case` (e.g., `skills/ai-models`, `skills/api-design`, `skills/llm-patterns`).
- **Subdirectories of `.claude/` (created by installer):** lowercase singular (`prompts`, `agents`, `commands`, `skills`, `rules`, `docs`, `cheatsheets`, `scratchpad`).
- **GitHub metadata:** Standard GitHub conventions (`.github/workflows/`, `.github/ISSUE_TEMPLATE/`).

## Where to Add New Code

**New slash command:**

- Implementation: `commands/<name>.md` — single Markdown file with `## Purpose`, `## Usage`, `## When to Use` sections (follow `commands/plan.md` as the canonical example).
- Register: Add `"commands/<name>.md"` to `manifest.json` under `files.commands` (sorted alphabetically) AND add a download entry in `scripts/init-claude.sh:FILES[]` and the iteration list in `scripts/update-claude.sh:147`.

**New component (reference doc):**

- Implementation: `components/<kebab-name>.md`.
- Register: Add a row to the appropriate category table in `components/README.md`.
- Note: Components are NOT auto-installed; they are referenced by template authors.

**New framework template:**

- Implementation: Create `templates/<stack>/` mirroring `templates/base/` layout (`CLAUDE.md`, `settings.json`, `agents/`, `prompts/`, `skills/`, `rules/`).
- Register: Add `"<stack>": "templates/<stack>"` to `manifest.json:templates`. Add the framework to detection logic in `scripts/init-claude.sh:detect_framework` (lines 49-65) and `scripts/init-local.sh:detect_framework` (lines 69-85). Add to the menu in `select_framework` (lines 68-103). Add a stack-specific extras block in `init-claude.sh:210-240` if the stack ships its own expert agent or skill.

**New audit prompt:**

- Implementation: `templates/base/prompts/<NAME>.md` (and per-stack overrides where they differ).
- Required sections: `QUICK CHECK` and `САМОПРОВЕРКА` or `SELF-CHECK` and `ФОРМАТ ОТЧЁТА` or `OUTPUT FORMAT` — enforced by `Makefile:65-86` and `.github/workflows/quality.yml:43-68`. Without these, `make check` and CI will fail.
- Register: Add to `manifest.json:files.prompts` and to the prompt loops in `scripts/init-claude.sh`, `scripts/init-local.sh`, `scripts/update-claude.sh`.

**New skill:**

- Implementation: Create `templates/base/skills/<name>/SKILL.md` (lightweight index following progressive-disclosure pattern). Optional `rules/*.md` and other resources within the same directory.
- Register: Add an entry to `templates/base/skills/skill-rules.json` with keyword/intent/file-pattern triggers (see existing entries at `templates/base/skills/skill-rules.json:5-28`). Add to `manifest.json:files.skills` and to the skill loops in installer scripts.

**New agent (subagent definition):**

- Implementation: `templates/base/agents/<role>.md` for shared agents, or `templates/<stack>/agents/<role>.md` for stack-specific.
- Register: Add to `manifest.json:files.agents` and to the agent loops in installer scripts.

**New auto-loaded rule:**

- Implementation: `templates/base/rules/<domain>.md` with YAML frontmatter declaring `description:` and `globs:`.
- Pattern: `globs: ["**/*"]` for always-loaded; specific globs (e.g., `["lang/**"]`) for path-scoped rules. `globs: []` means audit-only (never auto-loaded — used for `lessons-learned.md`).
- Note: Installer copies `project-context.md` only if missing — user content is preserved on update.

**New translation (cheatsheet/howto):**

- Implementation: Add `cheatsheets/<lang>.md` and `docs/howto/<lang>.md` and `docs/readme/<lang>.md`.
- Register: Add to the `FILES[]` cheatsheet block in `scripts/init-claude.sh:198-207`.

**New utility script:**

- Implementation: `scripts/<kebab-name>.sh`. Start with `set -euo pipefail`, use the standard color palette (RED/GREEN/YELLOW/BLUE/CYAN/NC), use `log_info`/`log_success`/`log_warning`/`log_error` helpers if interactive.
- Quality gate: Must pass `shellcheck` (run via `make shellcheck` or `make check`).

## Special Directories

**`templates/global/`**

- Purpose: Special template targeting `~/.claude/` (the user's global home directory), NOT a project's `.claude/`.
- Contents: `CLAUDE.md` (the 14-section global security rules merged section-by-section by `setup-security.sh`), `statusline.sh`, `rate-limit-probe.sh`.
- Generated: No.
- Committed: Yes.

**`scripts/council/`**

- Purpose: Self-contained Python orchestrator for the Supreme Council multi-AI review feature. Installs to `~/.claude/council/` (global), not the project.
- Contents: `brain.py` (orchestrator), `config.json.template` (sample config), `README.md`.
- Generated: No.
- Committed: Yes. The installed `~/.claude/council/config.json` is generated at install time and chmod 600.

**`.claude/`**

- Purpose: This repo dogfoods its own toolkit — `.claude/` here is a working install used while editing the repo.
- Contents: `settings.local.json`, `scratchpad/`, `activity.log`, `audit.log`.
- Generated: Partially (`activity.log`, `audit.log` are runtime).
- Committed: `settings.local.json` follows the standard `.local` ignore convention; logs and scratchpad are gitignored.

**`.planning/`**

- Purpose: Output target for GSD planning commands (`/gsd-plan-phase`, `/gsd-map-codebase`, etc.).
- Contents: `codebase/` (this directory's outputs).
- Generated: Yes — produced by GSD agents.
- Committed: Optional; depends on team policy.

**`/tmp/test-claude-*` (transient)**

- Purpose: Sandbox directories used by `Makefile`'s `test` target to validate `init-local.sh` against synthetic Laravel/Next.js/generic projects.
- Generated: Yes — created and torn down by `make test` and `make clean` (`Makefile:42-63`, `Makefile:89-95`).
- Committed: No (outside the repo).

---

*Structure analysis: 2026-04-17*
