# Components — Reusable Guidelines

Reference materials for Claude Code. Loaded on demand or embedded
in CLAUDE.md.

This index lists the most commonly-referenced components. Browse
the directory for the full set; every file is self-describing.

---

## Workflow & Process

| Component | Description |
|-----------|-------------|
| [surgical-changes.md](./surgical-changes.md) | Touch only what you must. Don't refactor adjacent code. Clean only your own orphans. |
| [production-safety.md](./production-safety.md) | Production hygiene: incremental deploys, file-target discipline, rolling restarts. |
| [context-management.md](./context-management.md) | Long-session hygiene: when to compact, what to summarise, what to retain. |
| [cost-discipline.md](./cost-discipline.md) | Token + API cost discipline for long agentic sessions. |

---

## Knowledge & Persistence

| Component | Description |
|-----------|-------------|
| [memory-persistence.md](./memory-persistence.md) | Knowledge persistence with `.claude/rules/` (auto-loaded) + `.claude/docs/` (on-demand). |
| [mcp-servers-guide.md](./mcp-servers-guide.md) | MCP servers: context7, playwright, sequential-thinking. |
| [large-codebase-search.md](./large-codebase-search.md) | Strategies for searching codebases too big to grep linearly. |
| [comet-research.md](./comet-research.md) | `/research` flow + Comet MCP integration. |

---

## Testing & Quality

| Component | Description |
|-----------|-------------|
| [playwright-self-testing.md](./playwright-self-testing.md) | Visual self-testing after UI changes via Playwright MCP. |
| [playwright-stability-guide.md](./playwright-stability-guide.md) | Playwright in production: Docker, memory, backpressure, stealth. |
| [smoke-tests-guide.md](./smoke-tests-guide.md) | Minimal API smoke tests. Examples for Laravel, Next.js, Node.js. |
| [quick-check-scripts.md](./quick-check-scripts.md) | Bash scripts: find secrets, debug code, TODO/FIXME, large files. |
| [markdown-lint-rules.md](./markdown-lint-rules.md) | Markdownlint rules: MD040, MD031/32, MD026. Config reference. |
| [pre-commit-hooks.md](./pre-commit-hooks.md) | `pre-commit` framework — config, hooks, integration. |

---

## Audit Support (SOTs)

These five files fan out via `scripts/propagate-audit-pipeline-v42.sh`
into spliced regions of `templates/base/prompts/*_AUDIT.md`. Edit
the SOT, then run propagate to update all six audit prompts.

| Component | Description |
|-----------|-------------|
| [audit-output-format.md](./audit-output-format.md) | Structured-report schema: path, frontmatter, fixed H2 order, finding fields, Council slot. |
| [audit-fp-recheck.md](./audit-fp-recheck.md) | 6-step false-positive recheck procedure (Phase 3 of `/audit`). |
| [audit-fp-control-gates.md](./audit-fp-control-gates.md) | Three-gate FP CONTROL wrapper (Adversarial → recheck → Calibration). |
| [audit-severity-anchor.md](./audit-severity-anchor.md) | CRITICAL/HIGH/MEDIUM/LOW labels + Severity Ceiling Table. |
| [audit-uncertainty-discipline.md](./audit-uncertainty-discipline.md) | Confidence vs severity decoupling; anti-padding rules. |
| [severity-levels.md](./severity-levels.md) | Short reference card for audit report Summary tables (subset of severity-anchor). |
| [report-format.md](./report-format.md) | Report templates: Security Audit, Code Review, Deploy Checklist. |
| [self-check-section.md](./self-check-section.md) | Filter false positives. Checklist before adding finding to report. |

---

## DevOps & Infrastructure

| Component | Description |
|-----------|-------------|
| [devops-highload-checklist.md](./devops-highload-checklist.md) | Production checklist for Laravel + Redis + Playwright. 17 sections. |
| [api-health-monitoring.md](./api-health-monitoring.md) | Monitoring paid APIs (Stripe, OpenAI). Laravel + Vue. |
| [production-observability.md](./production-observability.md) | Logging, metrics, tracing for production services. |
| [deployment-strategies.md](./deployment-strategies.md) | Blue/green, canary, rolling — when to use which. |
| [github-actions-guide.md](./github-actions-guide.md) | GitHub Actions patterns: pinning, permissions, secrets discipline. |
| [feature-flag-lifecycle.md](./feature-flag-lifecycle.md) | Flag birth → ramp → cleanup. Avoid permanent flags. |
| [rate-limit-statusline.md](./rate-limit-statusline.md) | Claude Code rate-limit statusline integration (macOS Keychain probe). |

---

## Configuration & Setup

| Component | Description |
|-----------|-------------|
| [claude-md-guide.md](./claude-md-guide.md) | Global vs Project CLAUDE.md: what goes where, size guidelines, anti-patterns. |
| [security-hardening.md](./security-hardening.md) | Layered hardening: Forbidden Patterns, Doubt Protocol, framework-specific notes. |
| [external-tools-recommended.md](./external-tools-recommended.md) | Recommended external CLIs (gh, jq, tree, etc.) per stack. |

---

## Prompt Engineering

| Component | Description |
|-----------|-------------|
| [system-prompt-architecture.md](./system-prompt-architecture.md) | 7-block reusable template for system prompts. Backs `/prompt-audit`. |
| [skill-frontmatter-discipline.md](./skill-frontmatter-discipline.md) | Frontmatter rules for `SKILL.md` files. |
| [factcheck-planning-hooks.md](./factcheck-planning-hooks.md) | `/factcheck` flow + planning-hook patterns. |
| [domain-expert-simulation.md](./domain-expert-simulation.md) | Persona overlays for the Council and `/audit` review. |
| [open-design.md](./open-design.md) | Open-ended design exploration before committing to a plan. |
| [product-thinking-flow.md](./product-thinking-flow.md) | Product-first reasoning: user value before implementation detail. |

---

## Council & Multi-AI

| Component | Description |
|-----------|-------------|
| [supreme-council.md](./supreme-council.md) | `/council` multi-AI plan validator (Gemini + ChatGPT). |

---

## Frontend & Localization

| Component | Description |
|-----------|-------------|
| [i18n-multilanguage.md](./i18n-multilanguage.md) | Multilanguage interface: file structure, plural forms, Intl API, Laravel+Vue. |

---

## Vendor & Dependency Hygiene

| Component | Description |
|-----------|-------------|
| [vendor-pinning.md](./vendor-pinning.md) | Pin every vendored dependency to a SHA. Drift detection via `manifest.json:vendor_pins`. |
| [vendor-risk.md](./vendor-risk.md) | Risk model for third-party plugins, MCPs, marketplaces. |

---

## How to Use

**Embed in CLAUDE.md:**

```markdown
<!-- Copy needed sections from a component into your CLAUDE.md -->
```

**Load on demand:**

```text
"Read components/<file>.md and follow this approach"
```

**Reference for Claude:**

Components are available via Glob/Read when working with the project.
