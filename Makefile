.PHONY: help check lint shellcheck mdlint test validate clean install

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
check: lint validate
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

# ShellCheck
shellcheck:
	@echo "Running ShellCheck..."
	@find scripts -name '*.sh' -exec shellcheck {} + && echo "✅ ShellCheck passed"

# Markdown lint
mdlint:
	@echo "Running markdownlint..."
	@markdownlint '**/*.md' --ignore node_modules && echo "✅ Markdownlint passed"

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

# Clean temporary files
clean:
	@echo "Cleaning..."
	@rm -rf /tmp/test-claude-*
	@find . -name "*.bak" -delete
	@find . -name "*.tmp" -delete
	@find . -name ".DS_Store" -delete
	@echo "Done!"
