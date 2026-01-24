# Markdown Lint Rules

Include this section in your CLAUDE.md to ensure consistent markdown formatting.

---

## Markdown Formatting Rules (MANDATORY)

This project uses `markdownlint` for quality checks. **All markdown files MUST pass linting before commit.**

### Quick Command

```bash
# Check all markdown files
npx markdownlint-cli "**/*.md" --ignore node_modules

# Fix auto-fixable issues
npx markdownlint-cli "**/*.md" --ignore node_modules --fix
```

### Critical Rules

#### MD040: Always Specify Code Block Language

```markdown
<!-- BAD -->
` ` `
some code
` ` `

<!-- GOOD -->
` ` `bash
echo "hello"
` ` `

` ` `text
Plain text content
` ` `

` ` `markdown
# Markdown example
` ` `
```

**Available languages:** `bash`, `text`, `markdown`, `json`, `yaml`, `python`, `javascript`, `typescript`, `php`, `sql`, `html`, `css`

#### MD031/MD032: Blank Lines Around Blocks and Lists

```markdown
<!-- BAD -->
Some text
- item 1
- item 2
More text

<!-- GOOD -->
Some text

- item 1
- item 2

More text
```

```markdown
<!-- BAD -->
Some text
` ` `bash
code
` ` `
More text

<!-- GOOD -->
Some text

` ` `bash
code
` ` `

More text
```

#### MD026: No Trailing Punctuation in Headings

```markdown
<!-- BAD -->
## What is this?
## Configuration:

<!-- GOOD -->
## What is This
## Configuration
```

#### MD024: No Duplicate Headings (siblings only)

```markdown
<!-- BAD (same level, same parent) -->
## Setup
## Setup

<!-- GOOD (different parents or levels) -->
# Section A
## Setup

# Section B
## Setup
```

### Pre-commit Check

Add to your workflow:

```yaml
- name: Markdown Lint
  run: npx markdownlint-cli "**/*.md" --ignore node_modules
```

### Config Reference

Project uses `.markdownlint.json`:

```json
{
  "default": true,
  "MD013": false,
  "MD033": false,
  "MD041": false,
  "MD024": {
    "siblings_only": true
  },
  "MD029": {
    "style": "ordered"
  }
}
```

**Disabled rules:**

- `MD013` — Line length (disabled for readability)
- `MD033` — Inline HTML (allowed for flexibility)
- `MD041` — First line heading (not required)

### Self-Check Before Commit

- [ ] All code blocks have language specified
- [ ] Blank lines before/after lists
- [ ] Blank lines before/after code blocks
- [ ] No punctuation at end of headings
- [ ] Ordered lists use sequential numbers (1, 2, 3...)
