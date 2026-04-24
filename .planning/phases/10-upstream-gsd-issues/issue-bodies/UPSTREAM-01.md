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

Running `node ~/.claude/get-shit-done/bin/gsd-tools.cjs audit-open` crashes immediately with
`ReferenceError: output is not defined` at `bin/gsd-tools.cjs:786` (or `:784` when `--json` is
passed). This blocks `complete-milestone.md` workflow Step 1 (`pre_close_artifact_audit`), which
calls `audit-open` as part of the milestone close flow. The crash surfaces as an uncaught
exception to the agent.

This appears to be a regression from the fix in PR #2239 (filed against #2236, closed
2026-04-15 as COMPLETED) — that PR was closed WITHOUT being merged (`mergedAt: null`), and the
bug persists in v1.36.0.

### What did you expect?

`audit-open` should produce the formatted audit report on stdout (or JSON when `--json` is
passed) without crashing.

### Steps to reproduce

1. Install GSD v1.36.0 (`~/.claude/get-shit-done/VERSION` reads `1.36.0`).
2. From any project directory (no setup required — crash happens before I/O):

   ```bash
   node ~/.claude/get-shit-done/bin/gsd-tools.cjs audit-open
   ```

3. Observe the immediate `ReferenceError` crash.

### Error output / logs

```text
/Users/REDACTED/.claude/get-shit-done/bin/gsd-tools.cjs:786
        output(formatAuditReport(result), raw);
        ^

ReferenceError: output is not defined
    at runCommand (/Users/REDACTED/.claude/get-shit-done/bin/gsd-tools.cjs:786:9)
    at main (/Users/REDACTED/.claude/get-shit-done/bin/gsd-tools.cjs:388:11)
    at Object.<anonymous> (/Users/REDACTED/.claude/get-shit-done/bin/gsd-tools.cjs:1158:1)
    at Module._compile (node:internal/modules/cjs/loader:1829:14)
```

### GSD Configuration

Not relevant — the crash happens before any config is read.

### Root cause analysis

File: `bin/gsd-tools.cjs`, lines 779–789 (the `audit-open` case handler):

```javascript
case 'audit-open': {
  const { auditOpenArtifacts, formatAuditReport } = require('./lib/audit.cjs');
  const includeRaw = args.includes('--json');
  const result = auditOpenArtifacts(cwd);
  if (includeRaw) {
    output(JSON.stringify(result, null, 2), raw);  // BUG: bare `output`
  } else {
    output(formatAuditReport(result), raw);         // BUG: bare `output`
  }
  break;
}
```

The module-level `core` object is loaded at line 168 (`const core = require('./lib/core.cjs');`).
No `output` is destructured from `core` in this scope. Every other caller in the same file
uses `core.output(...)` (e.g. lines 1045, 1056, 1059, 1062). The `audit-open` handler uses
bare `output()`, which is undefined.

### Suggested fix

Two-line diff at `bin/gsd-tools.cjs:784,786`:

```diff
-      output(JSON.stringify(result, null, 2), raw);
+      core.output(JSON.stringify(result, null, 2), raw);
     } else {
-      output(formatAuditReport(result), raw);
+      core.output(formatAuditReport(result), raw);
```

### Prior art

- Issue #2236 — same bug, closed 2026-04-15 as COMPLETED.
- PR #2239 — proposed fix, CLOSED WITHOUT MERGE (`mergedAt: null`).

Since #2236 is closed per repo convention (closed issues are not reopened), filing this as a
new issue with a cross-reference so maintainers can re-land PR #2239 or a variant.

Note: I am on v1.36.0 (pinned to the plugin shipped with Claude Code). Latest npm release is
1.38.3 — if that version already contains the fix, a patch release for 1.36.x would still help
users on Claude Code-bundled GSD.
