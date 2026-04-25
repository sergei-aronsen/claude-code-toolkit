.PHONY: help check lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands test-matrix-bats cell-parity clean install

# Default target
help:
	@echo "Claude Guides - Available commands:"
	@echo ""
	@echo "  make lint       - Run all linters (shellcheck + markdownlint)"
	@echo "  make shellcheck - Check shell scripts"
	@echo "  make mdlint     - Check markdown files"
	@echo "  make test       - Test init scripts"
	@echo "  make validate   - Validate template structure"
	@echo "  make install    - Install dev dependencies"
	@echo "  make clean      - Clean temporary files"
	@echo ""

# Run all checks (documented in CLAUDE.md as primary quality gate)
check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands cell-parity
	@echo "All checks passed!"

# Install dependencies
install:
	@echo "Installing dependencies..."
	@command -v shellcheck >/dev/null 2>&1 || brew install shellcheck
	@command -v markdownlint >/dev/null 2>&1 || npm install -g markdownlint-cli
	@echo "Done!"

# Run all linters
lint: shellcheck mdlint
	@echo "All checks passed!"

# ShellCheck — covers scripts/ and templates/global/ which both ship to users.
# Audit M-03: templates/global/{rate-limit-probe,statusline}.sh were never linted.
shellcheck:
	@echo "Running ShellCheck..."
	@find scripts templates/global -name '*.sh' -exec shellcheck -S warning {} + && echo "✅ ShellCheck passed"

# Markdown lint
mdlint:
	@echo "Running markdownlint..."
	@markdownlint '**/*.md' --ignore-path .markdownlintignore && echo "✅ Markdownlint passed"

# Test init scripts
test:
	@echo "Testing init scripts..."
	@echo ""
	@echo "Test 1: Laravel project"
	@rm -rf /tmp/test-claude-laravel
	@mkdir -p /tmp/test-claude-laravel
	@cd /tmp/test-claude-laravel && touch artisan && bash $(PWD)/scripts/init-local.sh >/dev/null
	@test -f /tmp/test-claude-laravel/.claude/prompts/SECURITY_AUDIT.md && echo "✅ Laravel init works"
	@echo ""
	@echo "Test 2: Next.js project"
	@rm -rf /tmp/test-claude-nextjs
	@mkdir -p /tmp/test-claude-nextjs
	@cd /tmp/test-claude-nextjs && touch next.config.js && bash $(PWD)/scripts/init-local.sh >/dev/null
	@test -f /tmp/test-claude-nextjs/.claude/prompts/SECURITY_AUDIT.md && echo "✅ Next.js init works"
	@echo ""
	@echo "Test 3: Generic project"
	@rm -rf /tmp/test-claude-generic
	@mkdir -p /tmp/test-claude-generic
	@cd /tmp/test-claude-generic && bash $(PWD)/scripts/init-local.sh >/dev/null
	@test -f /tmp/test-claude-generic/.claude/prompts/SECURITY_AUDIT.md && echo "✅ Generic init works"
	@echo ""
	@echo "Test 4: detect.sh plugin detection harness"
	@bash scripts/tests/test-detect.sh
	@echo ""
	@echo "Test 5: state.sh install-state + lock harness"
	@bash scripts/tests/test-state.sh
	@echo ""
	@echo "Test 6: lib/install.sh - mode skip-set correctness"
	@bash scripts/tests/test-modes.sh
	@echo ""
	@echo "Test 7: --dry-run grouped output + zero filesystem writes"
	@bash scripts/tests/test-dry-run.sh
	@echo ""
	@echo "Test 8: settings.json safe merge - foreign keys, backup, restore"
	@bash scripts/tests/test-safe-merge.sh
	@echo ""
	@echo "Test 9: update drift + v3.x synthesis + mode-switch"
	@bash scripts/tests/test-update-drift.sh
	@echo ""
	@echo "Test 10: update file-diff (new/removed/modified)"
	@bash scripts/tests/test-update-diff.sh
	@echo ""
	@echo "Test 11: update summary + no-op + backup path"
	@bash scripts/tests/test-update-summary.sh
	@echo ""
	@echo "Test 12: migrate three-way diff + user-mod detection"
	@bash scripts/tests/test-migrate-diff.sh
	@echo ""
	@echo "Test 13: migrate full flow (accept/decline/partial/lock/backup-fail)"
	@bash scripts/tests/test-migrate-flow.sh
	@echo ""
	@echo "Test 14: migrate idempotence + self-heal"
	@bash scripts/tests/test-migrate-idempotent.sh
	@echo ""
	@echo "Test 15: setup-security.sh RTK.md install guard"
	@bash scripts/tests/test-setup-security-rtk.sh
	@echo ""
	@echo "Test 16: full install matrix"
	@bash scripts/tests/test-matrix.sh
	@echo ""
	@echo "Test 17: CLAUDE.md.new flow (audit T-02 / CRIT-01 regression guard)"
	@bash scripts/tests/test-claude-md-new.sh
	@echo ""
	@echo "All tests passed!"

# Validate templates (check core audit prompts for self-check sections)
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
	@MANIFEST_VER=$$(grep -m1 '"version"' manifest.json | sed 's/.*"version": *"\([^"]*\)".*/\1/'); \
		CHANGELOG_VER=$$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/'); \
		if [ "$$MANIFEST_VER" != "$$CHANGELOG_VER" ]; then \
			echo "❌ Version mismatch: manifest.json=$$MANIFEST_VER, CHANGELOG.md=$$CHANGELOG_VER"; \
			exit 1; \
		fi; \
		echo "✅ Version aligned: $$MANIFEST_VER"
	@if ! grep -q 'compute_file_diffs_obj' scripts/update-claude.sh; then \
		echo "❌ update-claude.sh does not source compute_file_diffs_obj — manifest-driven path missing"; \
		exit 1; \
	fi
	@echo "✅ update-claude.sh is manifest-driven (no hand-maintained file lists)"
	@echo "✅ All templates valid"
	@echo "Validating manifest.json schema..."
	@python3 scripts/validate-manifest.py
	@echo "✅ Manifest schema valid"

# Validate Required Base Plugins section presence across all 7 templates (Pitfall 10 drift guard)
validate-base-plugins:
	@echo "Validating Required Base Plugins section across 7 templates..."
	@MISSING=0; for f in templates/base/CLAUDE.md templates/laravel/CLAUDE.md templates/rails/CLAUDE.md templates/nextjs/CLAUDE.md templates/nodejs/CLAUDE.md templates/python/CLAUDE.md templates/go/CLAUDE.md; do \
		grep -q "^## Required Base Plugins" "$$f" || { echo "❌ $$f missing Required Base Plugins section"; MISSING=$$((MISSING+1)); }; \
	done; \
	if [ $$MISSING -gt 0 ]; then exit 1; fi; \
	echo "✅ All 7 templates carry ## Required Base Plugins"

# Version alignment (D-09) — manifest.json == CHANGELOG.md top release == init-local.sh --version
version-align:
	@echo "Checking version alignment (manifest.json <-> CHANGELOG.md <-> init-local.sh)..."
	@MANIFEST_VER=$$(jq -r '.version' manifest.json); \
	CHANGELOG_VER=$$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/'); \
	SCRIPT_VER=$$(bash scripts/init-local.sh --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); \
	ERRORS=0; \
	if [ -z "$$MANIFEST_VER" ] || [ "$$MANIFEST_VER" = "null" ]; then \
		echo "❌ manifest.json has no .version field"; ERRORS=$$((ERRORS+1)); \
	fi; \
	if [ -z "$$CHANGELOG_VER" ]; then \
		echo "❌ CHANGELOG.md has no '## [X.Y.Z]' header"; ERRORS=$$((ERRORS+1)); \
	fi; \
	if [ -z "$$SCRIPT_VER" ]; then \
		echo "❌ scripts/init-local.sh --version produced no version string"; ERRORS=$$((ERRORS+1)); \
	fi; \
	if [ "$$MANIFEST_VER" != "$$CHANGELOG_VER" ]; then \
		echo "❌ manifest.json=$$MANIFEST_VER, CHANGELOG.md=$$CHANGELOG_VER"; ERRORS=$$((ERRORS+1)); \
	fi; \
	if [ "$$MANIFEST_VER" != "$$SCRIPT_VER" ]; then \
		echo "❌ manifest.json=$$MANIFEST_VER, init-local.sh --version=$$SCRIPT_VER"; ERRORS=$$((ERRORS+1)); \
	fi; \
	if [ "$$ERRORS" -gt 0 ]; then exit 1; fi; \
	echo "✅ Version aligned: $$MANIFEST_VER"

# Translation drift (D-10) — docs/readme/*.md line count within ±20% of README.md.
# Phase 7.1 contract: translations must fit this gate.
translation-drift:
	@echo "Checking README translation drift (±20% line count tolerance)..."
	@if [ ! -f README.md ]; then echo "❌ README.md missing at repo root"; exit 1; fi
	@README_LINES=$$(wc -l < README.md | tr -d ' '); \
	MIN=$$(( README_LINES * 80 / 100 )); \
	MAX=$$(( README_LINES * 120 / 100 )); \
	ERRORS=0; \
	for f in docs/readme/de.md docs/readme/es.md docs/readme/fr.md docs/readme/ja.md \
	          docs/readme/ko.md docs/readme/pt.md docs/readme/ru.md docs/readme/zh.md; do \
		if [ ! -f "$$f" ]; then \
			echo "❌ Missing translation: $$f"; ERRORS=$$((ERRORS+1)); continue; \
		fi; \
		LINES=$$(wc -l < "$$f" | tr -d ' '); \
		if [ "$$LINES" -lt "$$MIN" ] || [ "$$LINES" -gt "$$MAX" ]; then \
			echo "❌ $$f: $$LINES lines outside ±20% of README.md $$README_LINES (tolerance $$MIN-$$MAX)"; \
			ERRORS=$$((ERRORS+1)); \
		fi; \
	done; \
	if [ "$$ERRORS" -gt 0 ]; then exit 1; fi; \
	echo "✅ All 8 translations within ±20% of README.md ($$README_LINES lines)"

# Static agent-collision check (D-11 static layer — VALIDATE-03 precondition).
# Asserts every agents/*.md in manifest that is shadowed by superpowers carries
# conflicts_with: ["superpowers"] so the install-time skip-set filter catches it.
# Pure jq — no install required.
agent-collision-static:
	@echo "Checking agents/* conflicts_with annotations (VALIDATE-03 static gate)..."
	@SP_CONFLICT_AGENTS=$$(jq -r '[.files.agents[] | select((.conflicts_with // []) | index("superpowers"))] | length' manifest.json); \
	if [ -z "$$SP_CONFLICT_AGENTS" ] || [ "$$SP_CONFLICT_AGENTS" = "null" ]; then \
		echo "❌ jq query failed against manifest.json"; exit 1; \
	fi; \
	if [ "$$SP_CONFLICT_AGENTS" -lt 1 ]; then \
		echo "❌ manifest.json has zero agents annotated conflicts_with: [\"superpowers\"] — VALIDATE-03 regression"; \
		echo "   At minimum, agents/code-reviewer.md must be annotated (SP ships code-reviewer agent)."; \
		exit 1; \
	fi; \
	SP_CONFLICT_FILES=$$(jq -r '[.. | objects | select(has("conflicts_with")) | select(.conflicts_with | index("superpowers")) | .path] | length' manifest.json); \
	echo "✅ Static agent-collision check: $$SP_CONFLICT_FILES files annotated conflicts_with SP ($$SP_CONFLICT_AGENTS agents, others commands/skills)"

# Validate commands/*.md for required ## Purpose and ## Usage headings (HARDEN-A-01 — derived from AUDIT-12)
validate-commands:
	@echo "Validating commands/*.md for required headings (HARDEN-A-01)..."
	@python3 scripts/validate-commands.py

# REL-01: run bats matrix suite (requires: brew install bats-core locally; CI uses bats-core/bats-action)
test-matrix-bats:
	@echo "Running bats install matrix..."
	@bats scripts/tests/matrix/*.bats

# REL-02: cell-parity gate — all 3 surfaces must carry all 13 cell names
cell-parity:
	@echo "Checking cell-parity (all 3 surfaces)..."
	@bash scripts/cell-parity.sh

# Clean temporary files
clean:
	@echo "Cleaning..."
	@rm -rf /tmp/test-claude-*
	@find . -name "*.bak" -delete
	@find . -name "*.tmp" -delete
	@find . -name ".DS_Store" -delete
	@echo "Done!"
