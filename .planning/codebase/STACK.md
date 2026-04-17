# Technology Stack

**Analysis Date:** 2026-04-17

## Languages

**Primary:**
- Markdown — Templates, components, commands, prompts, skills, agents, cheatsheets (the bulk of the repo). Linted via `markdownlint`.
- Bash (POSIX-compatible Bash 3.2+) — All installer/updater/verifier scripts in `scripts/`. All scripts use `set -euo pipefail`.
- Python 3.8+ — Single file `scripts/council/brain.py` (Supreme Council orchestrator, curl-only, no pip dependencies).

**Secondary:**
- YAML — GitHub Actions workflow `.github/workflows/quality.yml`, pre-commit config `.pre-commit-config.yaml`.
- JSON — Config files (`manifest.json`, `.markdownlint.json`, `templates/base/settings.json`, `scripts/council/config.json.template`).
- Make — Single `Makefile` (~95 lines) acts as the project task runner.

## Runtime

**Environment:**
- macOS (Darwin) — Required for `install-statusline.sh` (uses `security` Keychain command and `stat -f %m`).
- Linux (Ubuntu) — Required for CI runners (`ubuntu-latest` in `.github/workflows/quality.yml`); also supported by `init-claude.sh`, `update-claude.sh`, `setup-security.sh`, `setup-council.sh`.
- Bash shell with `set -euo pipefail` semantics.
- No build artifact, no compilation step — repo is consumed by `curl | bash` pipelines from raw.githubusercontent.com.

**Package Manager:**
- None for the toolkit itself (no `package.json`, no `pyproject.toml`, no `Cargo.toml`, no `go.mod`).
- `npm` (global) used to install `markdownlint-cli` via `make install` in `Makefile:24`.
- `brew` used to install `shellcheck`, `jq`, `tree` on macOS during setup.
- `apt-get` used to install `tree` on Linux in `scripts/setup-council.sh:66`.
- Lockfile: not applicable (no application dependencies).

## Frameworks

**Core:**
- None — this is a documentation/templates repository, not an application framework.

**Testing:**
- `make test` (`Makefile:42-63`) — integration tests for `scripts/init-local.sh` against synthetic Laravel/Next.js/generic projects under `/tmp/test-claude-*`.
- Template content validation via `make validate` (`Makefile:66-86`) and the `validate-templates` job in `.github/workflows/quality.yml` (greps for required headings: `QUICK CHECK`, `САМОПРОВЕРКА`/`SELF-CHECK`, `ФОРМАТ ОТЧЁТА`/`OUTPUT FORMAT`).

**Build/Dev:**
- GNU Make — orchestrates linters and validators.
- `markdownlint-cli` (installed globally via npm) — markdown linting.
- `shellcheck` — shell script static analysis (`Makefile:32-34` runs against `scripts/`).
- `pre-commit` (Python) — optional local hook framework via `.pre-commit-config.yaml`.

## Key Dependencies

**Critical (runtime tools required by scripts):**
- `bash` — All installer scripts.
- `curl` — Used by every installer to fetch files from `https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/...` and to call external APIs from `scripts/council/brain.py`.
- `jq` — Required by `scripts/install-statusline.sh:31-40`, `templates/global/rate-limit-probe.sh`, `templates/global/statusline.sh` (parses Keychain JSON and rate-limit cache).
- `git` — Implicit (repo is git-distributed).
- `python3` (>= 3.8) — Required only for Supreme Council; verified in `scripts/setup-council.sh:36-50`.
- `tree` — Optional; auto-installed by `scripts/setup-council.sh:60-75` for project structure analysis in `brain.py`.
- `gemini` CLI (optional) — Installed via `npm install -g @google/gemini-cli`; used in CLI mode by `brain.py:251-260`.
- `security` (macOS Keychain) — Reads Claude Code OAuth token in `templates/global/rate-limit-probe.sh:35` and `scripts/install-statusline.sh:50`.

**Linting toolchain:**
- `markdownlint-cli` (npm global) — Configured by `.markdownlint.json` (disables MD013/MD033/MD041/MD060; sets MD024.siblings_only=true and MD029.style=ordered).
- `shellcheck` (brew/apt) — Severity threshold `warning` in CI (`.github/workflows/quality.yml:23`) and pre-commit (`.pre-commit-config.yaml:10`).
- `markdownlint-cli2-action@v14` (pinned to SHA `455b6612...`) — CI markdown lint.
- `ludeeus/action-shellcheck@v2.0.0` (pinned to SHA `00b27aa7...`) — CI shell lint.
- `actions/checkout@v4` (pinned to SHA `34e11487...`) — CI checkout.

**Pre-commit hooks (`.pre-commit-config.yaml`):**
- `shellcheck-precommit@v0.9.0`
- `markdownlint-cli@v0.37.0`
- `pre-commit-hooks@v4.5.0` (trailing-whitespace, end-of-file-fixer, check-yaml, check-added-large-files --maxkb=500, detect-private-key, check-merge-conflict).

**Infrastructure:**
- GitHub Actions — single workflow `.github/workflows/quality.yml` with 4 jobs (shellcheck, markdownlint, validate-templates, test-init-script).
- `permissions: contents: read` set at workflow level (CI security best practice).

## Configuration

**Environment:**
- No `.env` file; no environment variables required to use the repo itself.
- Supreme Council reads `~/.claude/council/config.json` (created from `scripts/council/config.json.template`) with optional env overrides `GEMINI_API_KEY` and `OPENAI_API_KEY` (referenced in `scripts/setup-council.sh:98,129`).
- Statusline reads OAuth token from macOS Keychain item `Claude Code-credentials` via `security find-generic-password` — never persisted to disk.

**Build:**
- `Makefile` — primary task runner. Targets: `help`, `check` (= `lint validate`), `lint` (= `shellcheck mdlint`), `shellcheck`, `mdlint`, `test`, `validate`, `install`, `clean`.
- `manifest.json` — version manifest (current `version: 3.0.0`, `updated: 2026-02-16`). Lists all distributable files under `files.{agents,prompts,commands,skills,rules}`, `claude_md_sections.{system,user}`, and `templates.{base,laravel,nextjs,nodejs,python,go,rails}`. Consumed by `scripts/update-claude.sh:67-74` to drive smart updates.
- `.markdownlint.json` — disables MD013 (line length), MD033 (inline HTML), MD041 (first-line-h1), MD060; configures MD024 (siblings_only) and MD029 (ordered style).
- `.pre-commit-config.yaml` — optional local enforcement of the same lint rules.

## Platform Requirements

**Development:**
- macOS or Linux with `bash`, `git`, `make`.
- For lint pass: `shellcheck` + `markdownlint-cli` (installed via `make install`).
- For Supreme Council development: `python3 >= 3.8`, `curl`, `tree`.

**Production:**
- "Production" = end-user developer machines that run `bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)` to install `.claude/` configuration into their own projects.
- Distribution channel: GitHub raw content (no package registry, no CDN).
- CI runs on `ubuntu-latest` GitHub-hosted runners.
- Statusline feature requires macOS specifically (Keychain + BSD `stat`).

---

*Stack analysis: 2026-04-17*
