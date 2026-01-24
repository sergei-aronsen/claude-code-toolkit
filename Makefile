.PHONY: help lint shellcheck mdlint test validate clean install

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
	@shellcheck scripts/*.sh && echo "✅ ShellCheck passed"

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
	@echo "All tests passed!"

# Validate templates
validate:
	@echo "Validating templates..."
	@ERRORS=0; \
	for f in templates/**/*.md; do \
		if ! grep -q "QUICK CHECK" "$$f" 2>/dev/null; then \
			echo "❌ Missing QUICK CHECK: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
		if ! grep -q "САМОПРОВЕРКА" "$$f" 2>/dev/null; then \
			echo "❌ Missing САМОПРОВЕРКА: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then \
		echo "Found $$ERRORS errors"; \
		exit 1; \
	fi
	@echo "✅ All templates valid"

# Clean temporary files
clean:
	@echo "Cleaning..."
	@rm -rf /tmp/test-claude-*
	@find . -name "*.bak" -delete
	@find . -name "*.tmp" -delete
	@find . -name ".DS_Store" -delete
	@echo "Done!"
