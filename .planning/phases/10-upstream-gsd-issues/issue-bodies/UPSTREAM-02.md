### GSD Version

1.36.0

### Runtime

Claude Code

### Operating System

macOS

### Node.js Version

v25.9.0

### Shell

/bin/zsh

### Installation Method

Manual install via `/Users/REDACTED/.claude/get-shit-done/` (plugin directory, not npm).

### What happened?

When `gsd-tools milestone complete <version>` writes an entry to `MILESTONES.md`, the
`**Key accomplishments:**` bullet list contains the literal string `One-liner:` (the label)
for every phase instead of the one-liner prose that follows the label.

Example output for a milestone with three SUMMARY files using the standard `**One-liner:** prose`
body pattern:

```markdown
**Key accomplishments:**
- One-liner:
- One-liner:
- One-liner:
```

### What did you expect?

The accomplishments list should contain the actual prose:

```markdown
**Key accomplishments:**
- Filesystem-based superpowers/GSD detection library via sourced shell script
- `--clean-backups` flag ships on `update-claude.sh` with per-dir prompts and `--keep N`
- `claude plugin list --json` CLI cross-check as step 4 in `detect_superpowers()`
```

### Steps to reproduce

1. Create SUMMARY.md files following the standard template, where each SUMMARY has an H1
   followed by a blank line, then `**One-liner:** <prose>`:

   ```markdown
   # Phase 2 Plan 01: Foundation Summary

   **One-liner:** Filesystem-based detection library via sourced shell script.
   ```

2. Run `node ~/.claude/get-shit-done/bin/gsd-tools.cjs milestone complete <version>`.
3. Inspect the generated `MILESTONES.md` entry — the accomplishments contain `One-liner:`
   labels instead of the prose.

Programmatic repro (isolates the faulty function):

```javascript
const { extractOneLinerFromBody } = require('~/.claude/get-shit-done/bin/lib/core.cjs');
const content = `# Phase 2 Plan 01: Foundation Summary\n\n**One-liner:** Real prose here.\n`;
console.log(extractOneLinerFromBody(content));
// Actual:   "One-liner:"
// Expected: "Real prose here." (or the full "One-liner: Real prose here." prefixed string)
```

### Error output / logs

Not an error — wrong output. The noise is written silently to `MILESTONES.md`.

### Root cause analysis

File 1: `bin/lib/milestone.cjs`, lines 131–136 — extraction loop:

```javascript
for (const s of summaries) {
  const content = fs.readFileSync(path.join(phasesDir, dir, s), 'utf-8');
  const fm = extractFrontmatter(content);
  const oneLiner = fm['one-liner'] || extractOneLinerFromBody(content);
  if (oneLiner) accomplishments.push(oneLiner);
}
```

File 2: `bin/lib/core.cjs`, lines 1384–1391 — `extractOneLinerFromBody`:

```javascript
function extractOneLinerFromBody(content) {
  if (!content) return null;
  const body = content.replace(/^---\n[\s\S]*?\n---\n*/, '');
  const match = body.match(/^#[^\n]*\n+\*\*([^*]+)\*\*/m);
  return match ? match[1].trim() : null;
}
```

The regex `\*\*([^*]+)\*\*` matches the SHORTEST `**...**` span. In `**One-liner:** prose`,
the first `**...**` pair wraps only the label text `One-liner:` — because the colon, space,
and prose that follow the closing `**` are NOT inside the capture group. The regex matches
`**One-liner:**`, captures group 1 = `One-liner:`, and returns that as the "one-liner".

All 29 v4.0 SUMMARY files used the `**One-liner:** prose` template and none had `one-liner:`
in YAML frontmatter — so the `fm['one-liner']` path always missed, and `extractOneLinerFromBody`
always returned `"One-liner:"`.

### Suggested fix

Option A (minimal — strip the known label prefix pattern):

```javascript
function extractOneLinerFromBody(content) {
  if (!content) return null;
  const body = content.replace(/^---\n[\s\S]*?\n---\n*/, '');
  // Match "**Label:** prose" OR "**prose**" — label is optional
  const match = body.match(/^#[^\n]*\n+\*\*(?:[A-Za-z][A-Za-z -]*:\s*)?([^*]+)\*\*/m);
  if (match) return match[1].trim();
  // Fallback — match "**Label:** prose" where prose is OUTSIDE the bold
  const labelMatch = body.match(/^#[^\n]*\n+\*\*[A-Za-z][A-Za-z -]*:\*\*\s*([^\n]+)/m);
  return labelMatch ? labelMatch[1].trim() : null;
}
```

Option B (document the template contract): require SUMMARY authors to use YAML frontmatter
`one-liner:` field, and update the SUMMARY template in `templates/summary.md` to demonstrate
the frontmatter path. Keep `extractOneLinerFromBody` as a fallback but document which body
shapes it actually supports.

Option A is recommended — it's backward-compatible with existing SUMMARY files and fixes the
immediate bug without requiring content migration.
