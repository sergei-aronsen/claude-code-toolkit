# Components — Reusable Guidelines

Reference materials for Claude Code. Loaded on demand or embedded in CLAUDE.md.

---

## Workflow & Process

| Component | Description |
|-----------|-------------|
| [structured-workflow.md](./structured-workflow.md) | 3-phase approach: Research → Plan → Execute. Tool restrictions by phase. |
| [plan-mode-instructions.md](./plan-mode-instructions.md) | Thinking levels: `think` → `think hard` → `ultrathink`. Plan Mode activation. |
| [bootstrap-workflow.md](./bootstrap-workflow.md) | Workflow for new projects: IDEA → STACK → INSTRUCTIONS → ADAPTATION. |
| [spec-driven-development.md](./spec-driven-development.md) | Specifications before code. Opus as architect, Sonnet/Haiku as implementers. |
| [surgical-changes.md](./surgical-changes.md) | Touch only what you must. Don't refactor adjacent code. Clean only your own orphans. |

---

## Skills & Learning System

| Component | Description |
|-----------|-------------|
| [skills-system.md](./skills-system.md) | Self-learning + progressive disclosure: accumulate knowledge, modular SKILL.md + resources/. |
| [hooks-auto-activation.md](./hooks-auto-activation.md) | Auto-activation of skills by prompt. Scoring system and confidence levels. |

---

## Knowledge & Persistence

| Component | Description |
|-----------|-------------|
| [memory-persistence.md](./memory-persistence.md) | Knowledge persistence with `.claude/rules/` (auto-loaded) and `.claude/docs/` (on-demand). |
| [mcp-servers-guide.md](./mcp-servers-guide.md) | Guide to MCP servers: context7, playwright, sequential-thinking. |

---

## Testing & Quality

| Component | Description |
|-----------|-------------|
| [playwright-self-testing.md](./playwright-self-testing.md) | Visual self-testing after UI changes. Playwright MCP workflow, tips, troubleshooting. |
| [playwright-stability-guide.md](./playwright-stability-guide.md) | Playwright in production: Docker config, memory, backpressure, anti-detection, stealth. |
| [smoke-tests-guide.md](./smoke-tests-guide.md) | Minimal tests for API. Examples for Laravel, Next.js, Node.js. |
| [quick-check-scripts.md](./quick-check-scripts.md) | Bash scripts: find secrets, debug code, TODO/FIXME, large files. |
| [markdown-lint-rules.md](./markdown-lint-rules.md) | Markdownlint rules: MD040, MD031/32, MD026. Config reference. |

---

## Audit Support

| Component | Description |
|-----------|-------------|
| [severity-levels.md](./severity-levels.md) | 5 levels: CRITICAL, HIGH, MEDIUM, LOW, INFO. Examples for each. |
| [report-format.md](./report-format.md) | Report templates: Security Audit, Code Review, Deploy Checklist. |
| [self-check-section.md](./self-check-section.md) | Filter false positives. Checklist before adding finding to report. |

---

## DevOps & Infrastructure

| Component | Description |
|-----------|-------------|
| [devops-highload-checklist.md](./devops-highload-checklist.md) | Production checklist for Laravel + Redis + Playwright. 17 sections. |
| [api-health-monitoring.md](./api-health-monitoring.md) | Monitoring paid APIs (Stripe, OpenAI). Laravel + Vue implementation. |

---

## Configuration & Setup

| Component | Description |
|-----------|-------------|
| [claude-md-guide.md](./claude-md-guide.md) | Global vs Project CLAUDE.md: what goes where, size guidelines, anti-patterns. |

---

## Git & Version Control

| Component | Description |
|-----------|-------------|
| [git-worktrees-guide.md](./git-worktrees-guide.md) | Parallel work on branches. Creating, listing, removing worktrees. |

---

## Frontend & Localization

| Component | Description |
|-----------|-------------|
| [i18n-multilanguage.md](./i18n-multilanguage.md) | Multilanguage interface: file structure, key naming, plural forms, Intl API, Laravel+Vue integration. |

---

## Skills (subfolder)

| Component | Description |
|-----------|-------------|
| [skills/debugging/SKILL.md](./skills/debugging/SKILL.md) | Debugging methodology: 4 phases. Iron Law: don't fix without understanding the cause. |

---

## How to Use

**Embed in CLAUDE.md:**

```markdown
<!-- Copy needed sections from component into your CLAUDE.md -->
```

**Load on demand:**

```text
"Read components/structured-workflow.md and follow this approach"
```

**Reference for Claude:**

Components are automatically available to Claude through Glob/Read when working with the project.
