.PHONY: help check check-full lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands validate-catalog validate-mdlint-config-sync test-matrix-bats cell-parity clean install test-update-libs test-uninstall-keep-state test-install-tui test-mcp-selector test-install-skills test-integrations-foundation test-integrations-catalog test-cli-installer test-integrations-tui test-catalog-scope-fallback sync-skills-mirror validate-skills-desktop validate-marketplace test-project-secrets test-catalog-serena test-install-hooks test-cost-routing test-migrate-v5-to-v6 test-init-skip-flags test-skills-mirror-checksum test-uninstall-remove-flags test-hook-replay test-verify-install-v6

# Default target
help:
	@echo "Claude Guides - Available commands:"
	@echo ""
	@echo "  make check      - Primary quality gate (lint + validate + parity)"
	@echo "  make check-full - check + bats install matrix (run before push)"
	@echo "  make lint       - Run all linters (shellcheck + markdownlint)"
	@echo "  make shellcheck - Check shell scripts"
	@echo "  make mdlint     - Check markdown files"
	@echo "  make test       - Test init scripts"
	@echo "  make validate   - Validate template structure"
	@echo "  make install    - Install dev dependencies"
	@echo "  make clean      - Clean temporary files"
	@echo ""

# Run all checks (documented in CLAUDE.md as primary quality gate)
check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands validate-catalog validate-mdlint-config-sync validate-skills-desktop validate-marketplace cell-parity
	@echo "All checks passed!"

# Full local validation — `check` + bats install matrix. Run before push to catch
# bats-only regressions that surfaced 59 commits late during v4.1 (RETROSPECTIVE
# 2026-04-25). Requires: brew install bats-core. CI runs the matrix separately.
check-full: check test-matrix-bats
	@echo "All checks + bats matrix passed!"

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

# Audit INF-MED-4 (2026-04-30 deep): assert .markdownlint.json (cli v1, used by
# `make mdlint` + .pre-commit-config.yaml) and .markdownlint-cli2.jsonc (cli v2,
# used by quality.yml's DavidAnson/markdownlint-cli2-action) carry the same
# rule set. Without this guard a contributor editing one file silently desyncs
# CI from local. Compares the canonicalized rule object, not whitespace.
validate-mdlint-config-sync:
	@echo "Checking markdownlint config alignment (.markdownlint.json vs .markdownlint-cli2.jsonc)..."
	@V1=$$(jq -S . .markdownlint.json); \
	V2=$$(python3 -c 'import json,re,sys; \
src=open(".markdownlint-cli2.jsonc").read(); \
src=re.sub(r"//[^\n]*","",src); \
print(json.dumps(json.loads(src)["config"], sort_keys=True, indent=2))'); \
	if [ "$$V1" != "$$V2" ]; then \
		echo "❌ markdownlint config drift between .markdownlint.json and .markdownlint-cli2.jsonc"; \
		echo "--- .markdownlint.json"; echo "$$V1"; \
		echo "--- .markdownlint-cli2.jsonc (.config)"; echo "$$V2"; \
		exit 1; \
	fi; \
	echo "✅ markdownlint configs aligned"

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
	@echo "Test 18: audit pipeline fixture — allowlist match + FP schema"
	@bash scripts/tests/test-audit-pipeline.sh
	@echo ""
	@echo "Test 19: council audit-review — verdict slot rewrite + parallel dispatch"
	@bash scripts/tests/test-council-audit-review.sh
	@echo ""
	@echo "Test 20: template propagation idempotency (propagate-audit-pipeline-v42.sh)"
	@bash scripts/tests/test-template-propagation.sh
	@echo ""
	@echo "Test 21: uninstall --dry-run zero-mutation contract (UN-02)"
	@bash scripts/tests/test-uninstall-dry-run.sh
	@echo ""
	@echo "Test 22: uninstall backup-before-delete + UN-01 hash-match delete (UN-04)"
	@bash scripts/tests/test-uninstall-backup.sh
	@echo ""
	@echo "Test 23: uninstall [y/N/d] prompt loop — UN-03 stdin-injected 3-branch proof"
	@bash scripts/tests/test-uninstall-prompt.sh
	@echo ""
	@echo "Test 24: uninstall round-trip integration (UN-08 — init→uninstall→clean state)"
	@bash scripts/tests/test-uninstall.sh
	@echo ""
	@echo "Test 25: installer banner gate (UN-07 — grep 'To remove:' in 3 installers)"
	@bash scripts/tests/test-install-banner.sh
	@echo ""
	@echo "Test 26: uninstall idempotency no-op contract (UN-06)"
	@bash scripts/tests/test-uninstall-idempotency.sh
	@echo ""
	@echo "Test 27: uninstall state-cleanup + sentinel strip + base-plugin invariant (UN-05/UN-06)"
	@bash scripts/tests/test-uninstall-state-cleanup.sh
	@echo ""
	@echo "Test 28: bootstrap SP/GSD pre-install prompts (BOOTSTRAP-01..04)"
	@bash scripts/tests/test-bootstrap.sh
	@echo ""
	@echo "Test 29: smart-update coverage for scripts/lib/*.sh (LIB-01..02)"
	@bash scripts/tests/test-update-libs.sh
	@echo ""
	@echo "Test 30: --keep-state partial-uninstall recovery (KEEP-01..02)"
	@bash scripts/tests/test-uninstall-keep-state.sh
	@echo ""
	@echo "Test 31: TUI install orchestrator + dispatch scenarios (TUI-01..09)"
	@bash scripts/tests/test-install-tui.sh
	@echo ""
	@echo "Test 32: MCP catalog + wizard + secrets handling (MCP-01..05, MCP-SEC-01..02)"
	@bash scripts/tests/test-mcp-selector.sh
	@echo ""
	@echo "Test 33: Skills selector + cp-R install + idempotency + --force (SKILL-03..05)"
	@bash scripts/tests/test-install-skills.sh
	@echo ""
	@echo "Test 34: H1 regression — install dispatch name-based lookup (DISPATCH-H1-01..06)"
	@bash scripts/tests/test-install-dispatch-h1.sh
	@echo ""
	@echo "Test 35: backup-lib (BACKUP-LIB-01..10)"
	@bash scripts/tests/test-backup-lib.sh
	@echo ""
	@echo "Test 36: backup-threshold (BACKUP-THRESHOLD-01..06)"
	@bash scripts/tests/test-backup-threshold.sh
	@echo ""
	@echo "Test 37: --clean-backups flag suite (BACKUP-CLEAN-01..25, incl. S-HIGH-1 regression)"
	@bash scripts/tests/test-clean-backups.sh
	@echo ""
	@echo "Test 38: detect-cli plugin liveness (DETECT-CLI-01..06)"
	@bash scripts/tests/test-detect-cli.sh
	@echo ""
	@echo "Test 39: detect-skew plugin version drift (DETECT-SKEW-01..10)"
	@bash scripts/tests/test-detect-skew.sh
	@echo ""
	@echo "Test 40: MCP secrets store (MCP-SEC-T01..11, incl. L1 regression)"
	@bash scripts/tests/test-mcp-secrets.sh
	@echo ""
	@echo "Test 41: MCP wizard happy/error paths (MCP-WIZ-T01..14)"
	@bash scripts/tests/test-mcp-wizard.sh
	@echo ""
	@echo "Test 42: migrate-to-complement.sh --dry-run (MIGRATE-DRY-01..09)"
	@bash scripts/tests/test-migrate-dry-run.sh
	@echo ""
	@echo "Test 43: update-claude.sh --dry-run (UPDATE-DRY-01..11)"
	@bash scripts/tests/test-update-dry-run.sh
	@echo ""
	@echo "Test 44: integrations foundation — schema + cli-installer + alias contracts (CAT-01..04, CLI-01..04)"
	@bash scripts/tests/test-integrations-foundation.sh
	@echo ""
	@echo "Test 45: integrations catalog schema (TEST-01 — Phase 35)"
	@bash scripts/tests/test-integrations-catalog.sh
	@echo ""
	@echo "Test 46: cli-installer primitives (TEST-02 — Phase 35)"
	@bash scripts/tests/test-cli-installer.sh
	@echo ""
	@echo "Test 47: integrations TUI redesign (TEST-03 — Phase 35)"
	@bash scripts/tests/test-integrations-tui.sh
	@echo ""
	@echo "Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)"
	@bash scripts/tests/test-catalog-scope-fallback.sh
	@echo ""
	@echo "Test 49: project secrets library (Phase 37 / SEC-01..06, TEST-01)"
	@bash scripts/tests/test-project-secrets.sh
	@echo ""
	@echo "Test 50: integrations-catalog serena entry shape (v6.1 / F-15 swap audit)"
	@bash scripts/tests/test-catalog-serena.sh
	@echo ""
	@echo "Test 51: install-hooks.sh round-trip + foreign preservation (v6.1 / F-15)"
	@bash scripts/tests/test-install-hooks.sh
	@echo ""
	@echo "Test 52: setup-cost-routing.sh block insert/remove + dry-run (v6.1 / F-15)"
	@bash scripts/tests/test-cost-routing.sh
	@echo ""
	@echo "Test 53: migrate-v5-to-v6.sh dry-run preview + post-migration hints (v6.1 / F-15)"
	@bash scripts/tests/test-migrate-v5-to-v6.sh
	@echo ""
	@echo "Test 54: init-claude.sh setup_hooks/setup_cost_routing skip-flag plumbing (v6.1 / F-3)"
	@bash scripts/tests/test-init-skip-flags.sh
	@echo ""
	@echo "Test 55: uninstall.sh --remove-hooks/--remove-cost-routing opt-in flags (v6.1 / F-3)"
	@bash scripts/tests/test-uninstall-remove-flags.sh
	@echo ""
	@echo "Test 56: tk-* hook fixture-based stdin replay — advisory mode + disable switch (v6.1 / F-15)"
	@bash scripts/tests/test-hook-replay.sh
	@echo ""
	@echo "Test 57: verify-install.sh sections 7 + 8 (advisory hooks + cost routing) (v6.1 / F-15)"
	@bash scripts/tests/test-verify-install-v6.sh
	@echo ""
	@echo "Test 58: skills mirror checksum + catalog regen + validator drift (v6.46.0 / P5+P10)"
	@bash scripts/tests/test-skills-mirror-checksum.sh
	@echo ""
	@echo "All tests passed!"

# Test 29 — smart-update coverage for scripts/lib/*.sh (LIB-01..02), invokable standalone
test-update-libs:
	@bash scripts/tests/test-update-libs.sh

# Test 30 — --keep-state partial-uninstall recovery (KEEP-01..02), invokable standalone
test-uninstall-keep-state:
	@bash scripts/tests/test-uninstall-keep-state.sh

# Test 31 — TUI install orchestrator + dispatch scenarios (TUI-01..09), invokable standalone
test-install-tui:
	@bash scripts/tests/test-install-tui.sh

# Test 32 — MCP catalog + wizard + secrets (MCP-01..05, MCP-SEC-01..02), invokable standalone
test-mcp-selector:
	@bash scripts/tests/test-mcp-selector.sh

# Test 33 — Skills selector + cp-R install + idempotency + --force (SKILL-03..05), invokable standalone
test-install-skills:
	@bash scripts/tests/test-install-skills.sh

# Test 44 — integrations foundation (CAT-01..04 + CLI-01..04), invokable standalone
test-integrations-foundation:
	@bash scripts/tests/test-integrations-foundation.sh

# Test 45 — integrations catalog schema (TEST-01 — Phase 35), invokable standalone
test-integrations-catalog:
	@bash scripts/tests/test-integrations-catalog.sh

# Test 46 — cli-installer primitives (TEST-02 — Phase 35), invokable standalone
test-cli-installer:
	@bash scripts/tests/test-cli-installer.sh

# Test 47 — integrations TUI redesign (TEST-03 — Phase 35), invokable standalone
test-integrations-tui:
	@bash scripts/tests/test-integrations-tui.sh

# Test 48 — catalog default_scope fallback (Phase 36 / SCOPE-03), invokable standalone
test-catalog-scope-fallback:
	@bash scripts/tests/test-catalog-scope-fallback.sh

# Test 49 — project secrets library (Phase 37 / SEC-01..06, TEST-01), invokable standalone
test-project-secrets:
	@bash scripts/tests/test-project-secrets.sh

# Test 50 — v6.1 catalog serena entry shape (F-15), invokable standalone
test-catalog-serena:
	@bash scripts/tests/test-catalog-serena.sh

# Test 51 — v6.1 install-hooks.sh round-trip (F-15), invokable standalone
test-install-hooks:
	@bash scripts/tests/test-install-hooks.sh

# Test 52 — v6.1 setup-cost-routing.sh contract (F-15), invokable standalone
test-cost-routing:
	@bash scripts/tests/test-cost-routing.sh

# Test 53 — v6.1 migrate-v5-to-v6.sh dry-run (F-15), invokable standalone
test-migrate-v5-to-v6:
	@bash scripts/tests/test-migrate-v5-to-v6.sh

# Test 58 — v6.46.0 skills mirror checksum + catalog drift (P5+P10), invokable standalone
test-skills-mirror-checksum:
	@bash scripts/tests/test-skills-mirror-checksum.sh

# Test 54 — v6.1 init-claude.sh skip-flag plumbing (F-3), invokable standalone
test-init-skip-flags:
	@bash scripts/tests/test-init-skip-flags.sh

# Test 55 — v6.1 uninstall.sh --remove-* opt-in flags (F-3), invokable standalone
test-uninstall-remove-flags:
	@bash scripts/tests/test-uninstall-remove-flags.sh

# Test 56 — v6.1 advisory-hook stdin replay (F-15 item 1), invokable standalone
test-hook-replay:
	@bash scripts/tests/test-hook-replay.sh

# Test 57 — v6.1 verify-install.sh sections 7+8 (F-15 item 5), invokable standalone
test-verify-install-v6:
	@bash scripts/tests/test-verify-install-v6.sh

# Skills mirror re-sync (maintainer-only) — re-syncs templates/skills-marketplace/
# from local $HOME/.claude/skills/. Not run by CI.
sync-skills-mirror:
	@bash scripts/sync-skills-mirror.sh

# Validate templates (check core audit prompts for self-check sections)
validate:
	@echo "Validating templates..."
	@ERRORS=0; \
	for f in $$(find templates -path '*/prompts/*.md' \( \
		-name 'PERFORMANCE_AUDIT.md' -o \
		-name 'CODE_REVIEW.md' \)); do \
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
	@echo "Checking v4.2 audit pipeline markers (Council Handoff + FP-recheck step 1)..."
	@# v6.15.0: DEPLOY_CHECKLIST is a deployment runbook, not an audit
	@# prompt — excluded from QUICK CHECK / SELF-CHECK / Council Handoff
	@# checks above and below. See CHANGELOG v6.15.0.
	@ERRORS=0; \
	for f in $$(find templates -path '*/prompts/*.md' \( \
		-name 'SECURITY_AUDIT.md' -o \
		-name 'CODE_REVIEW.md' -o \
		-name 'PERFORMANCE_AUDIT.md' -o \
		-name 'MYSQL_PERFORMANCE_AUDIT.md' -o \
		-name 'POSTGRES_PERFORMANCE_AUDIT.md' -o \
		-name 'DESIGN_REVIEW.md' \)); do \
		if ! grep -qF 'Council Handoff' "$$f" 2>/dev/null; then \
			echo "❌ Missing 'Council Handoff' marker: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
		if ! grep -qF '1. **Read context**' "$$f" 2>/dev/null; then \
			echo "❌ Missing '1. **Read context**' marker: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
		if ! grep -qF '6. **Severity sanity check**' "$$f" 2>/dev/null; then \
			echo "❌ Missing '6. **Severity sanity check**' marker: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then \
		echo "Found $$ERRORS v4.2 marker errors across audit prompts"; \
		exit 1; \
	fi
	@echo "✅ All 6 prompt files carry v4.2 pipeline markers (TEMPLATE-03; v6.22.0 framework cleanup)"
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

# Validate Required Base Plugins section presence across all 5 templates (Pitfall 10 drift guard)
# v6.0: nextjs/ removed (GSD skills-marketplace covers Next.js stack), nodejs/ merged into base.
validate-base-plugins:
	@echo "Validating Required Base Plugins section across 5 templates..."
	@MISSING=0; for f in templates/base/CLAUDE.md templates/laravel/CLAUDE.md templates/rails/CLAUDE.md templates/python/CLAUDE.md templates/go/CLAUDE.md; do \
		grep -q "^## Required Base Plugins" "$$f" || { echo "❌ $$f missing Required Base Plugins section"; MISSING=$$((MISSING+1)); }; \
	done; \
	if [ $$MISSING -gt 0 ]; then exit 1; fi; \
	echo "✅ All 5 templates carry ## Required Base Plugins"

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

# Static conflicts_with schema check (D-11 static layer — VALIDATE-03 precondition).
# Pure jq — no install required.
#
# v6.1 — assertion rewritten. The original gate required at least 1 agent
# entry annotated conflicts_with: ["superpowers"], a rule that became wrong
# when SP 5.1.0 dropped the agents/ directory entirely (audit
# docs/research/v6-post-ship-audit-2026-05-06.md, F-2). The annotation on
# agents/code-reviewer.md was removed in v6.1.
#
# New gate: every conflicts_with present in manifest must be a non-empty
# array of strings, and every string must be in the known plugin whitelist
# {"superpowers", "get-shit-done"}. The skip-set is enforced by
# scripts/lib/install.sh::compute_skip_set, which silently ignores unknown
# plugin names; the static gate prevents that silent typo.
agent-collision-static:
	@echo "Checking conflicts_with schema integrity (VALIDATE-03 static gate)..."
	@TOTAL=$$(jq -r '[.. | objects | select(has("conflicts_with"))] | length' manifest.json); \
	if [ -z "$$TOTAL" ] || [ "$$TOTAL" = "null" ]; then \
		echo "❌ jq query failed against manifest.json"; exit 1; \
	fi; \
	BAD_TYPE=$$(jq -r '[.. | objects | select(has("conflicts_with")) | select((.conflicts_with | type) != "array" or (.conflicts_with | length) == 0)] | length' manifest.json); \
	if [ "$$BAD_TYPE" -gt 0 ]; then \
		echo "❌ $$BAD_TYPE manifest entries have invalid conflicts_with shape (must be non-empty string array)"; \
		exit 1; \
	fi; \
	BAD_VALUE=$$(jq -r '[.. | objects | select(has("conflicts_with")) | .conflicts_with[] | select(. != "superpowers" and . != "get-shit-done")] | length' manifest.json); \
	if [ "$$BAD_VALUE" -gt 0 ]; then \
		echo "❌ $$BAD_VALUE conflicts_with values are not in known plugin set {superpowers, get-shit-done}"; \
		jq -r '.. | objects | select(has("conflicts_with")) | .conflicts_with[] | select(. != "superpowers" and . != "get-shit-done")' manifest.json; \
		exit 1; \
	fi; \
	SP_FILES=$$(jq -r '[.. | objects | select(has("conflicts_with")) | select(.conflicts_with | index("superpowers")) | .path] | length' manifest.json); \
	GSD_FILES=$$(jq -r '[.. | objects | select(has("conflicts_with")) | select(.conflicts_with | index("get-shit-done")) | .path] | length' manifest.json); \
	echo "✅ conflicts_with schema valid: $$TOTAL annotated entries (SP=$$SP_FILES, GSD=$$GSD_FILES)"

# Validate commands/*.md for required ## Purpose and ## Usage headings (HARDEN-A-01 — derived from AUDIT-12)
validate-commands:
	@echo "Validating commands/*.md for required headings (HARDEN-A-01)..."
	@python3 scripts/validate-commands.py

# Validate scripts/lib/integrations-catalog.json schema v2 (Phase 32-01 / CAT-03).
# Replaces the implicit shape contract that previously lived only in mcp.sh's jq queries.
validate-catalog:
	@echo "Validating integrations-catalog.json schema (CAT-03)..."
	@python3 scripts/validate-integrations-catalog.py

# DESK-02 + DESK-04: skills Desktop-safety heuristic gate (>= 4 PASS required).
validate-skills-desktop:
	@echo "Running skills Desktop-safety audit (DESK-02, DESK-04)..."
	@bash scripts/validate-skills-desktop.sh

# MKT-03: live marketplace smoke (gated by TK_HAS_CLAUDE_CLI=1; CI default = skip).
validate-marketplace:
	@echo "Running marketplace smoke (MKT-03; gated by TK_HAS_CLAUDE_CLI)..."
	@bash scripts/validate-marketplace.sh

# REL-01: run bats matrix suite (requires: brew install bats-core locally; CI uses bats-core/bats-action)
test-matrix-bats:
	@echo "Running bats install matrix..."
	@bats scripts/tests/matrix/*.bats

# REL-02: cell-parity gate — all 3 surfaces must carry all 13 cell names
cell-parity:
	@echo "Checking cell-parity (all 3 surfaces)..."
	@bash scripts/cell-parity.sh

# Clean temporary files
# Audit L11: scope find to current tree, exclude .git/ and node_modules/, and
# stop at the first level of test fixtures so a contributor's stashed *.bak
# under .git/ or a vendored node_modules/ tree is not silently deleted.
clean:
	@echo "Cleaning..."
	@rm -rf /tmp/test-claude-*
	@find . -path ./.git -prune -o -path ./node_modules -prune -o -type f -name "*.bak" -print -delete
	@find . -path ./.git -prune -o -path ./node_modules -prune -o -type f -name "*.tmp" -print -delete
	@find . -path ./.git -prune -o -path ./node_modules -prune -o -type f -name ".DS_Store" -print -delete
	@echo "Done!"
