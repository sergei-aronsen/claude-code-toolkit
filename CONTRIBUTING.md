# Contributing to Claude Code Toolkit

Thank you for your interest in contributing! This document provides guidelines and instructions.

## How to Contribute

### Reporting Issues

- Check if the issue already exists
- Use the appropriate issue template
- Provide as much detail as possible

### Suggesting Templates

1. Open an issue with the "Template Request" label
2. Describe the framework/use case
3. Share example prompts if you have them

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run the primary quality gate: `make check` (covers lint, validate,
   manifest schema, version alignment, translation drift, agent
   collisions, command headings, skills desktop-safety, marketplace,
   markdownlint config sync, and cell-parity)
5. Commit with a descriptive message
6. Push and create a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/claude-code-toolkit.git
cd claude-code-toolkit

# Install dependencies
make install

# Primary quality gate (run this before every commit):
make check

# Individual targets, if you want to drill in:
make lint            # shellcheck + markdownlint
make test            # init-script + helper test suites
make validate        # template structure + manifest schema
```

## Template Guidelines

### Required Sections

Every audit template MUST include:

1. **QUICK CHECK** - 5-minute rapid assessment
2. **PROJECT SPECIFICS** - Customizable section
3. **SEVERITY LEVELS** - Consistent severity definitions
4. **SELF-CHECK** - False positive filter
5. **REPORT FORMAT** - Output template
6. **ACTIONS** - Step-by-step instructions

### Style Guide

- Use English for main content
- Use emoji for severity: CRITICAL, HIGH, MEDIUM, LOW, INFO
- Include code examples with clear "bad" vs "good" patterns
- Keep bash scripts shellcheck-compliant

### Markdown Formatting (MANDATORY)

**Before every commit, run markdownlint:**

```bash
npx markdownlint-cli2 "**/*.md"
```

Common errors to avoid:

- **MD031/MD032**: Add blank lines around code blocks and lists
- **MD040**: Always specify language for code blocks (use `text` if not code)
- **MD058**: Add blank lines around tables
- **MD060**: Align table columns properly (all pipes must align vertically)

**Example of proper table alignment:**

```markdown
| Column 1 | Column 2       | Column 3 |
| -------- | -------------- | -------- |
| Short    | Longer content | Value    |
| Data     | More data      | End      |
```

**CI/CD will fail if markdownlint errors are present.**

### Testing Your Changes

```bash
# Test init script with your changes
cd /tmp && mkdir test-project && cd test-project
touch artisan  # or next.config.js for Next.js
bash /path/to/claude-code-toolkit/scripts/init-local.sh

# Verify templates work
cat .claude/prompts/SECURITY_AUDIT.md
```

## Code of Conduct

- Be respectful and constructive
- Focus on the technical merits
- Help others learn

## Questions?

Open an issue with the "Question" label or start a discussion.

---

Thank you for contributing!
