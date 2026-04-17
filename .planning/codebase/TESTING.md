# Testing Patterns

**Analysis Date:** 2026-04-17

This is a documentation/templates repository. There are **no unit tests, no
test framework, no assertion library**. "Testing" here means three things:

1. **Static linting** — `markdownlint` + `shellcheck`
2. **Structural validation** — custom Makefile/CI checks that grep audit
   templates for required sections
3. **Smoke tests of installer scripts** — Makefile and CI invoke
   `scripts/init-local.sh` against synthetic project fixtures

All checks are gated by `make check` locally and
`.github/workflows/quality.yml` in CI.

## Test Framework

**Runner:** GNU Make (`Makefile`) for local; GitHub Actions for CI.

**Linters:**

- `shellcheck` — installed via `brew install shellcheck` or
  `koalaman/shellcheck-precommit@v0.9.0`
- `markdownlint-cli` — installed via `npm install -g markdownlint-cli`
  (locally) or `igorshubovych/markdownlint-cli@v0.37.0` (pre-commit) /
  `DavidAnson/markdownlint-cli2-action@v14` (CI)

**Assertion library:** None. Bash `test -f`, `grep -q`, and `exit` codes are
the assertions.

**Run commands:**

```bash
make help        # List all available targets
make check       # Run lint + validate (primary quality gate)
make lint        # Run shellcheck + markdownlint
make shellcheck  # Run shellcheck only on scripts/
make mdlint      # Run markdownlint on all *.md (excluding node_modules)
make validate    # Validate template structure (audit prompt sections)
make test        # Smoke-test init-local.sh against three fixtures
make install     # Install shellcheck + markdownlint-cli
make clean       # Remove /tmp/test-claude-* and *.bak/*.tmp/.DS_Store
```

## Test File Organization

**Location:** No dedicated test directory. All "tests" live in:

- `Makefile` — executable test logic (lines 32-86)
- `.github/workflows/quality.yml` — CI replicas of the Makefile checks
- `.pre-commit-config.yaml` — pre-commit hook configuration

**Naming:** Not applicable. Test logic is inline in the Makefile/workflow.

**Structure:**

```text
.
├── Makefile                              # Local test runner (4 jobs)
├── .markdownlint.json                    # Markdown lint config
├── .pre-commit-config.yaml               # Pre-commit hooks (shellcheck +
│                                         #   markdownlint + safety hooks)
└── .github/
    └── workflows/
        └── quality.yml                   # CI: 4 parallel jobs
                                          #   (shellcheck, markdownlint,
                                          #    validate-templates,
                                          #    test-init-script)
```

## Test Structure

**Linting (shellcheck) — `Makefile:32-34`:**

```makefile
shellcheck:
	@echo "Running ShellCheck..."
	@find scripts -name '*.sh' -exec shellcheck {} + && echo "✅ ShellCheck passed"
```

**Linting (markdown) — `Makefile:37-39`:**

```makefile
mdlint:
	@echo "Running markdownlint..."
	@markdownlint '**/*.md' --ignore node_modules && echo "✅ Markdownlint passed"
```

**Structural validation — `Makefile:67-86`:**

```makefile
validate:
	@echo "Validating templates..."
	@ERRORS=0; \
	for f in $$(find templates -path '*/prompts/*.md' \( \
		-name 'PERFORMANCE_AUDIT.md' -o \
		-name 'CODE_REVIEW.md' -o \
		-name 'DEPLOY_CHECKLIST.md' \)); do \
		if ! grep -q "QUICK CHECK" "$$f" 2>/dev/null; then \
			echo "❌ Missing QUICK CHECK: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
		if ! grep -qE "САМОПРОВЕРКА|SELF-CHECK" "$$f" 2>/dev/null; then \
			echo "❌ Missing САМОПРОВЕРКА: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then \
		echo "Found $$ERRORS errors"; \
		exit 1; \
	fi
	@echo "✅ All templates valid"
```

**Smoke tests — `Makefile:42-63`:**

Three fixtures, each created in `/tmp`, then `init-local.sh` is invoked and
the resulting `.claude/prompts/SECURITY_AUDIT.md` is asserted to exist:

```makefile
test:
	@echo "Test 1: Laravel project"
	@rm -rf /tmp/test-claude-laravel
	@mkdir -p /tmp/test-claude-laravel
	@cd /tmp/test-claude-laravel && touch artisan && \
	    bash $(PWD)/scripts/init-local.sh >/dev/null
	@test -f /tmp/test-claude-laravel/.claude/prompts/SECURITY_AUDIT.md && \
	    echo "✅ Laravel init works"
	# ... Test 2: Next.js (touch next.config.js)
	# ... Test 3: Generic (no marker file)
```

**Patterns:**

- Setup: `rm -rf /tmp/test-claude-*` then `mkdir -p` (idempotent)
- Fixture marker: `touch artisan` for Laravel, `touch next.config.js` for
  Next.js, nothing for generic
- Assertion: `test -f <expected-output> && echo "✅ ..."`; missing file →
  exit code 1 propagates via `set -e` semantics
- Teardown: `make clean` (`Makefile:89-95`) removes `/tmp/test-claude-*`,
  `*.bak`, `*.tmp`, `.DS_Store`

## Mocking

**Framework:** None. Tests use real filesystem fixtures in `/tmp`.

**What is "mocked":**

- Project framework detection — by creating a single marker file
  (`artisan`, `next.config.js`, `package.json`, `go.mod`, `requirements.txt`,
  `pyproject.toml`, `bin/rails`, `config/application.rb`) the script's
  `detect_framework()` function (`scripts/init-local.sh:69-85`,
  `scripts/init-claude.sh:49-65`) selects the right template path

**What is NOT mocked:**

- Filesystem operations are real
- Markdown lint and shellcheck run against the actual repo content
- Network calls in `init-claude.sh` (curl) are NOT exercised by the smoke
  tests — only `init-local.sh` (no network) is tested

## Fixtures and Factories

**Test data:** Synthetic empty projects in `/tmp/test-claude-*`:

```bash
# Laravel fixture
rm -rf /tmp/test-claude-laravel
mkdir -p /tmp/test-claude-laravel
cd /tmp/test-claude-laravel && touch artisan

# Next.js fixture
rm -rf /tmp/test-claude-nextjs
mkdir -p /tmp/test-claude-nextjs
cd /tmp/test-claude-nextjs && touch next.config.js

# Generic fixture
rm -rf /tmp/test-claude-generic
mkdir -p /tmp/test-claude-generic
```

**Location:** `/tmp/` (not committed). Created and torn down by `make test`
and `make clean`.

## Coverage

**Requirements:** None enforced. There is no coverage tool.

**What IS effectively covered:**

- Every `*.md` file → markdownlint
- Every `scripts/*.sh` → shellcheck
- Audit prompts under `templates/*/prompts/` matching `PERFORMANCE_AUDIT.md`,
  `CODE_REVIEW.md`, `DEPLOY_CHECKLIST.md` → structural section validation
  (locally via Makefile)
- CI also validates `SECURITY_AUDIT.md` and additionally requires the
  `OUTPUT FORMAT` / `ФОРМАТ ОТЧЁТА` section
  (`.github/workflows/quality.yml:48-67`)
- `init-local.sh` framework detection for Laravel, Next.js, generic

**Gaps (deliberately not covered):**

- `init-claude.sh` (curl-based remote installer) is not smoke-tested
- `setup-security.sh`, `install-statusline.sh`, `update-claude.sh`,
  `verify-install.sh`, `setup-council.sh` are linted but not executed in CI
- Other framework templates (Rails, Node.js, Python, Go, base) are not
  smoke-tested by `make test`
- No content/semantic validation of CLAUDE.md templates beyond markdownlint

## CI Workflow

**File:** `.github/workflows/quality.yml`

**Triggers:** push to `main`, pull_request to `main`

**Permissions:** `contents: read` (least privilege)

**Jobs (4, run in parallel on `ubuntu-latest`):**

1. **`shellcheck`** — uses `ludeeus/action-shellcheck@v2.0.0` (pinned to
   commit SHA `00b27aa7cb85167568cb48a3838b75f4265f2bca`), `scandir: ./scripts`,
   `severity: warning`
2. **`markdownlint`** — uses `DavidAnson/markdownlint-cli2-action@v14`
   (pinned to SHA `455b6612a7b7a80f28be9e019b70abdd11696e4e`),
   `globs: '**/*.md'`, `config: '.markdownlint.json'`
3. **`validate-templates`** — inline bash that greps each
   `templates/**/SECURITY_AUDIT.md` (and the other three audit files) for
   `QUICK CHECK`, `САМОПРОВЕРКА|SELF-CHECK`, and
   `ФОРМАТ ОТЧЁТА|OUTPUT FORMAT`. Increments `ERRORS` and `exit 1` if any
   are missing.
4. **`test-init-script`** — replicates `make test`: `cd /tmp`, creates
   Laravel and Next.js fixtures, runs `bash $GITHUB_WORKSPACE/scripts/init-local.sh`,
   asserts `.claude/prompts/SECURITY_AUDIT.md` exists.

**Action SHA pinning:** All third-party actions are pinned to full commit
SHAs (not tags) per security best practice — see commit `93b1149` `fix: pin
GitHub Actions to SHA, add permissions to CI workflow`.

## Pre-Commit Hooks

**Config:** `.pre-commit-config.yaml`

**Install:**

```bash
pip install pre-commit
pre-commit install
```

**Hooks (in execution order):**

1. `koalaman/shellcheck-precommit@v0.9.0` — shellcheck with `--severity=warning`
2. `igorshubovych/markdownlint-cli@v0.37.0` — markdownlint with
   `--config .markdownlint.json`
3. `pre-commit/pre-commit-hooks@v4.5.0`:
   - `trailing-whitespace`
   - `end-of-file-fixer`
   - `check-yaml`
   - `check-added-large-files` with `--maxkb=500`
   - `detect-private-key`
   - `check-merge-conflict`

## Test Types

**Unit tests:** None.

**Integration tests:** Effectively the smoke tests in `make test` and the
`test-init-script` CI job — they integrate file detection, template
selection, and file copy logic of `init-local.sh`.

**Structural/contract tests:** The `validate` target and `validate-templates`
CI job enforce that every audit prompt template contains the required sections.
This is a contract between authors and the project's documented template
guidelines (`CONTRIBUTING.md:50-60`).

**Linting:** shellcheck (warnings) + markdownlint (full ruleset minus
disabled rules in `.markdownlint.json`).

**E2E:** None. The remote installer `init-claude.sh` (which fetches files
via curl from GitHub) is not exercised end-to-end in CI.

## Common Patterns

**Asserting a file exists after a script runs:**

```bash
test -f /tmp/test-claude-laravel/.claude/prompts/SECURITY_AUDIT.md && \
    echo "✅ Laravel init works"
```

**Validating a section appears in many files:**

```bash
ERRORS=0
for f in templates/**/SECURITY_AUDIT.md; do
    [ -f "$f" ] || continue
    grep -q "QUICK CHECK" "$f" || { echo "❌ $f"; ERRORS=$((ERRORS + 1)); }
done
[ $ERRORS -eq 0 ] || exit 1
```

**Quick local fix workflow:**

```bash
# Auto-fix markdown issues, then re-check everything
npx markdownlint-cli "**/*.md" --ignore node_modules --fix
make check
```

## Before Committing — Checklist

From `CLAUDE.md:81-86` and `CONTRIBUTING.md:24, 68-92`:

1. Run `make check` and fix all errors
2. Ensure markdownlint passes (CI/CD will fail otherwise)
3. Test any shell script changes with `shellcheck`
4. Update `CHANGELOG.md` under `## [Unreleased]` if user-visible

## Adding a New Test

**To smoke-test a new framework template** (e.g., Rust):

1. Add detection logic to `scripts/init-local.sh:detect_framework()`
   (`scripts/init-local.sh:69-85`)
2. Add a new test block to `Makefile:test:` following the Laravel/Next.js
   pattern (`Makefile:42-63`)
3. Mirror the new test as a step in `.github/workflows/quality.yml`
   `test-init-script` job (`.github/workflows/quality.yml:70-91`)

**To validate a new required section in audit templates:**

1. Add a `grep -q` check to `Makefile:validate:` (`Makefile:67-85`)
2. Mirror it in `.github/workflows/quality.yml:validate-templates` job
   (`.github/workflows/quality.yml:46-67`)
3. Document the new requirement in `CONTRIBUTING.md` under "Required Sections"
   (`CONTRIBUTING.md:50-60`)

---

*Testing analysis: 2026-04-17*
