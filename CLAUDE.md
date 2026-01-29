# Claude Guides — Claude Code Instructions

## Project Overview

**Type:** Documentation / Templates Repository
**Purpose:** Collection of CLAUDE.md templates, components, and examples for Claude Code projects
**Stack:** Markdown, Shell scripts, YAML configs

---

## Quality Checks (MUST PASS)

This project has CI/CD checks. **All PRs must pass before merge.**

### Run All Checks Locally

```bash
make check
```

### Individual Checks

```bash
# Shell scripts
make shellcheck

# Markdown lint
make lint

# Validate templates
make validate
```

---

## Markdown Formatting (CRITICAL)

**All markdown files MUST pass `markdownlint` checks.**

### Common Errors to Avoid

1. **MD040** — Always specify language for code blocks

   ```markdown
   <!-- WRONG -->
   ` ` `
   code here
   ` ` `

   <!-- CORRECT -->
   ` ` `bash
   code here
   ` ` `
   ```

2. **MD031/MD032** — Add blank lines around code blocks and lists

   ```markdown
   <!-- WRONG -->
   Text
   - item
   Text

   <!-- CORRECT -->
   Text

   - item

   Text
   ```

3. **MD026** — No punctuation at end of headings

   ```markdown
   <!-- WRONG -->
   ## What is this?

   <!-- CORRECT -->
   ## What is This
   ```

### Quick Fix

```bash
npx markdownlint-cli "**/*.md" --ignore node_modules --fix
```

---

## Project Structure

```text
claude-guides/
├── templates/           # CLAUDE.md templates (base, laravel, nextjs)
│   └── */CLAUDE.md     # Template files
│   └── */settings.json # VS Code settings
├── components/          # Reusable sections for CLAUDE.md
│   └── *.md            # Individual components
├── examples/            # Complete project examples
│   └── */CLAUDE.md     # Example configurations
├── commands/            # Claude Code slash commands
│   └── *.md            # Command definitions
├── scripts/             # Utility scripts
└── .github/             # CI/CD workflows
```

---

## File Naming Conventions

- **Components:** `kebab-case.md` (e.g., `plan-mode-instructions.md`)
- **Templates:** Directory with `CLAUDE.md` inside
- **Commands:** `kebab-case.md` in `commands/` directory

---

## Git Workflow

- **Branch naming:** `feature/xxx`, `fix/xxx`, `docs/xxx`
- **Commits:** Conventional Commits (`feat:`, `fix:`, `docs:`)
- **Never push directly to `main`**

---

## Before Committing

1. Run `make check` and fix all errors
2. Ensure markdown lint passes
3. Test any shell scripts with `shellcheck`
4. Update CHANGELOG.md if needed

---

## Knowledge Persistence (IMPORTANT!)

When making **significant changes** to the project — save knowledge to three places:

### 1. CLAUDE.md — for Claude Code

Update the corresponding sections in `CLAUDE.md` or templates in `templates/`.

### 2. README.md / docs — for humans

Update documentation if changes affect:

- New components or commands
- Changes in project structure
- New features or practices

### 3. MCP Memory — for persistence between sessions

> **IMPORTANT:** All memory entries must be written in English, regardless of conversation language.

**Knowledge Graph (memory)** — for relationships and architecture:

```text
"Save to knowledge graph: added component X, related to Y"
"Add to knowledge graph: decision to use approach Z because of reason W"
```

**Memory Bank** — for facts and decisions:

```text
"Save to memory-bank: why we chose structure X"
"Record in project memory: gotcha about Y"
```

### What to save

- Architectural decisions and their reasons
- New patterns and practices
- Critical gotchas and limitations
- Relationships between components
- Changes in API or structure

---

## Adding New Components

1. Create file in `components/` directory
2. Follow existing component structure
3. Include description at top of file
4. Ensure markdown lint passes
5. Add to README.md if significant

---

## Common Tasks

### Add new template

```bash
mkdir templates/new-template
cp templates/base/CLAUDE.md templates/new-template/
# Edit and customize
```

### Test markdown locally

```bash
npx markdownlint-cli components/your-file.md
```

### Run full validation

```bash
make check
```
