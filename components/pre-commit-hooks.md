# Pre-Commit Hooks Guide

> Automate code quality checks before commits.

---

## Why Pre-Commit Hooks

| Benefit | Description |
|---------|-------------|
| Consistency | Same checks for all developers |
| Early feedback | Catch issues before CI |
| Automation | No manual lint/format steps |
| Clean history | No "fix lint" commits |

---

## Node.js (Husky + lint-staged)

### Setup

```bash
# Install
pnpm add -D husky lint-staged

# Initialize Husky
pnpm exec husky init
```

### Configuration

```json
// package.json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md}": [
      "prettier --write"
    ]
  }
}
```

### Husky Hook

```bash
# .husky/pre-commit
pnpm lint-staged
```

### Pre-Push Hook (Tests)

```bash
# .husky/pre-push
pnpm test
```

### Commit Message Validation

```bash
# Install commitlint
pnpm add -D @commitlint/cli @commitlint/config-conventional

# Create config
echo "export default { extends: ['@commitlint/config-conventional'] };" > commitlint.config.js

# Add hook
echo "pnpm exec commitlint --edit \$1" > .husky/commit-msg
```

---

## Python (pre-commit framework)

### Setup

```bash
# Install
pip install pre-commit
# or
uv add --dev pre-commit

# Install hooks
pre-commit install
```

### Configuration

```yaml
# .pre-commit-config.yaml
repos:
  # Ruff (linting + formatting)
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.9
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  # Type checking
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.8.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic]

  # General
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
      - id: detect-private-key

  # Commit message
  - repo: https://github.com/commitizen-tools/commitizen
    rev: v3.13.0
    hooks:
      - id: commitizen
        stages: [commit-msg]
```

### Commands

```bash
# Run on all files
pre-commit run --all-files

# Update hooks
pre-commit autoupdate

# Skip hooks (emergency)
git commit --no-verify
```

---

## Go

### Setup with pre-commit

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/dnephin/pre-commit-golang
    rev: v0.5.1
    hooks:
      - id: go-fmt
      - id: go-vet
      - id: go-lint
      - id: go-imports
      - id: go-mod-tidy

  - repo: https://github.com/golangci/golangci-lint
    rev: v1.55.2
    hooks:
      - id: golangci-lint
```

### Alternative: Makefile + Git Hooks

```makefile
# Makefile
.PHONY: lint fmt test

lint:
    golangci-lint run

fmt:
    gofmt -s -w .
    goimports -w .

test:
    go test -race ./...

pre-commit: fmt lint test
```

```bash
# .git/hooks/pre-commit
#!/bin/sh
make pre-commit
```

---

## Laravel / PHP

### Setup with Husky

```bash
# Install Husky via npm (for frontend)
npm install -D husky lint-staged

# Initialize
npx husky init
```

### Configuration

```json
// package.json
{
  "lint-staged": {
    "*.php": [
      "./vendor/bin/pint"
    ],
    "*.{js,vue}": [
      "eslint --fix",
      "prettier --write"
    ]
  }
}
```

### PHP-Specific Hooks

```bash
# .husky/pre-commit
#!/bin/sh

# PHP Lint
./vendor/bin/pint --test
if [ $? -ne 0 ]; then
    echo "Pint failed. Run: ./vendor/bin/pint"
    exit 1
fi

# PHPStan (optional, can be slow)
# ./vendor/bin/phpstan analyse --memory-limit=2G

# Run lint-staged for JS/Vue
npx lint-staged
```

---

## Common Hooks

### Trailing Whitespace

```yaml
- repo: https://github.com/pre-commit/pre-commit-hooks
  hooks:
    - id: trailing-whitespace
    - id: end-of-file-fixer
```

### Large Files

```yaml
- repo: https://github.com/pre-commit/pre-commit-hooks
  hooks:
    - id: check-added-large-files
      args: ['--maxkb=500']
```

### Secrets Detection

```yaml
- repo: https://github.com/Yelp/detect-secrets
  rev: v1.4.0
  hooks:
    - id: detect-secrets
      args: ['--baseline', '.secrets.baseline']
```

### JSON/YAML Validation

```yaml
- repo: https://github.com/pre-commit/pre-commit-hooks
  hooks:
    - id: check-json
    - id: check-yaml
    - id: check-toml
```

---

## Commit Message Validation

### Conventional Commits Format

```text
type(scope): description

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `style` | Formatting |
| `refactor` | Code refactoring |
| `test` | Adding tests |
| `chore` | Maintenance |

### Examples

```text
feat(auth): add OAuth2 login
fix(api): handle null response from payment gateway
docs: update README with setup instructions
refactor(db): optimize user queries
```

---

## lint-staged Patterns

### TypeScript/JavaScript

```json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{js,jsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md,yml}": ["prettier --write"]
  }
}
```

### With Type Checking

```json
{
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write",
      "bash -c 'tsc --noEmit'"
    ]
  }
}
```

### Run Tests for Changed Files

```json
{
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "vitest related --run"
    ]
  }
}
```

---

## Troubleshooting

### Skip Hooks (Emergency)

```bash
git commit --no-verify -m "emergency fix"
git push --no-verify
```

### Reset Hooks

```bash
# Husky
rm -rf .husky
pnpm exec husky init

# pre-commit
pre-commit uninstall
pre-commit install
```

### Debug lint-staged

```bash
npx lint-staged --debug
```

---

## Best Practices

| Practice | Why |
|----------|-----|
| Fast hooks | Don't slow down commits |
| Fix, don't just check | Auto-fix when possible |
| Staged files only | Don't check entire repo |
| Skip CI in hooks | Run tests in CI, not locally |
| Allow bypass | `--no-verify` for emergencies |
