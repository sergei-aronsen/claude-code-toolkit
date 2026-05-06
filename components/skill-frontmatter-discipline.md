# Skill & Slash-Command Frontmatter Discipline

> **Component reference for authors of `commands/*.md`, `skills/*/SKILL.md`,
> and `agents/*.md`.** Not auto-loaded. Cite this when authoring new skills or
> mass-editing existing ones.

A well-written `description` field is the single biggest lever for **skill
discovery**. The runtime matches user requests against `description` to decide
which skill to invoke — vague descriptions stay invisible.

This component encodes the discipline used by Anthropic's first-party skills
catalog and Warp's `update-skill` skill.

---

## The Rule

A `description` field must answer two questions:

1. **What** does the skill do?
2. **When** should it be used?

Format constraints:

- **Begin with an action verb** in third-person singular (`Reviews…`, `Generates…`, `Extracts…`, `Adds…`).
  Not "Helps with…", not "I can help you…", not "A skill that…".
- **Third person**, never first person.
  Not "I review code", but "Reviews code".
- **Specific use case follows immediately** ("Use when …", "Triggers on …").
- **Include key trigger terms** so future sessions match user intent.
- Non-empty. A blank or single-word `description` is a bug.

---

## Examples

### ✅ Good

```yaml
---
name: code-reviewer
description: Reviews diffs for security, architecture, performance, and quality issues. Emits structured findings with severity labels and concrete suggestion blocks. Use when reviewing pull requests, pre-commit changes, or unmerged branch work.
---
```

```yaml
---
name: pdf-processing
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
---
```

```yaml
---
name: git-commit
description: Generates descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
---
```

### ❌ Bad

| Description | Problem |
| ----------- | ------- |
| `Helps with code` | Vague, no verb, no trigger |
| `Does development tasks` | Too broad, no signal |
| `I can help you write tests` | First person, no use case |
| `Code reviewer` | Single noun phrase, no "when" |
| `A skill for working with files` | Indirect ("A skill for…"), no trigger |

---

## Required Frontmatter Fields

Every `SKILL.md` / `commands/*.md` / `agents/*.md` file should declare at least:

```yaml
---
name: kebab-case-name
description: Action-verb sentence. Use when [trigger context].
---
```

Optional fields, when they apply:

| Field | When to set | Example |
| ----- | ----------- | ------- |
| `argument-hint` | Slash command takes arguments | `[phase] [--auto]` |
| `agent` | Slash command dispatches a specific subagent | `gsd-planner` |
| `allowed-tools` | Restrict toolset | `[Read, Grep, Bash(git diff *)]` |
| `disable-model-invocation` | Skill is user-only, never auto-triggered | `true` |

---

## Naming

- **`name`** — kebab-case, lowercase letters, numbers, hyphens only.
  Examples: `add-feature-flag`, `rust-unit-tests`, `update-skill`, `code-reviewer`.
- **No spaces, underscores, dots, or capitals** in `name`.
- File path must align with `name`: `skills/<name>/SKILL.md`, `commands/<name>.md`.

---

## File-Length Tiers

| File length | Structure |
| ----------- | --------- |
| ≤ 200 lines | Keep everything in `SKILL.md` / `commands/<name>.md` |
| > 200 lines | Split detail into `references/` subdirectory; `SKILL.md` keeps only the workflow |

When the main file approaches 200 lines, ask yourself whether each section is
**workflow** (stays in `SKILL.md`) or **reference** (moves to `references/`).
Detailed schemas, exhaustive option tables, and long examples belong in
references.

---

## Self-Check

Before committing a new or edited skill, verify:

- [ ] `description` starts with a third-person action verb
- [ ] `description` includes a specific "Use when …" or equivalent trigger
- [ ] `description` is at least one full sentence (not a fragment)
- [ ] `name` is kebab-case and matches the file path
- [ ] If file > 200 lines, detail is split into `references/`

---

## Provenance

This discipline distills:

- Anthropic Agent SDK skills authoring guidance
- Warp `.agents/skills/update-skill/SKILL.md` (mattpocock-style action-verb rule)
- Existing high-quality skills shipped in this toolkit (`gsd-*`, `superpowers/*`)

When in doubt, look at three good descriptions in `~/.claude/skills/` and match
the cadence.
