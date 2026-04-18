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
	@ERRORS=0; \
		MANIFEST_CMDS=$$(grep '"commands/' manifest.json | sed 's|.*"commands/\([^"]*\)".*|\1|'); \
		LOOP_LINE=$$(awk '/mkdir -p "\$$CLAUDE_DIR\/commands"/{getline; print; exit}' scripts/update-claude.sh); \
		LOOP_CMDS=$$(echo "$$LOOP_LINE" | sed 's/.*for file in //; s/; do.*//'); \
		for cmd in $$LOOP_CMDS; do \
			if ! echo "$$MANIFEST_CMDS" | grep -qx "$$cmd"; then \
				echo "❌ update-claude.sh lists '$$cmd' not in manifest.json files.commands"; \
				ERRORS=$$((ERRORS + 1)); \
			fi; \
		done; \
		for cmd in $$MANIFEST_CMDS; do \
			if ! echo "$$LOOP_CMDS" | tr ' ' '\n' | grep -qx "$$cmd"; then \
				echo "❌ manifest.json files.commands has '$$cmd' missing from update-claude.sh loop"; \
				ERRORS=$$((ERRORS + 1)); \
			fi; \
		done; \
		if [ $$ERRORS -gt 0 ]; then \
			echo "Found $$ERRORS commands drift errors"; \
			exit 1; \
		fi; \
		echo "✅ update-claude.sh commands match manifest.json"
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
