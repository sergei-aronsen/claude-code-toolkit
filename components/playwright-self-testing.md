# Visual Self-Testing with Playwright MCP

After ANY visual/UI change, self-test using Playwright MCP before reporting completion.

**Requires:** Playwright MCP server configured in `.claude/settings.json`.

---

## When to Self-Test

This applies to any change that affects what the user sees:

- CSS fixes and layout changes
- Component modifications
- Filter, dropdown, or form changes
- New pages or sections
- Any frontend work

---

## Workflow

1. **Deploy** the changes (or ensure dev server is running)
2. **Navigate** to the affected page: `mcp__playwright__browser_navigate`
3. **Log in** if needed (use `browser_snapshot` to find form elements, then `browser_click`/`browser_fill_form`)
4. **Take a screenshot** to verify the page loads without errors
5. **Check console errors** — if navigate result shows `[ERROR]`, fix immediately
6. **Interact** with changed elements — open dropdowns, click buttons, toggle filters
7. **Take screenshots** of the specific areas you changed
8. **Report findings** to the user with a summary of what was verified
9. **Close the browser** with `browser_close` — multiple Claude sessions share the same browser profile, so leaving it open will block other sessions from launching it

---

## Tips

### Finding and clicking elements

```text
1. browser_snapshot → get accessibility tree with element refs
2. browser_click ref="<element_ref>" → interact with elements
3. browser_fill_form → fill input fields
```

### Dealing with overlays

```text
# Close a fixed overlay (dropdown backdrop, modal overlay)
browser_evaluate: () => { document.querySelector('.fixed.inset-0')?.click(); return 'done'; }
```

### Large pages

```text
# If snapshot exceeds token limits, save and search
browser_snapshot → saved to file
Grep on the saved file to find specific refs
```

### Common issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Blank page | Missing import or runtime error | Check console errors in navigate result |
| Element not found | Wrong selector or page not loaded | Wait for page load, re-snapshot |
| Stale screenshot | Cache or CDN | Hard refresh or cache-bust |
| Browser won't start | Another session holds the browser open | See [Parallel Sessions](#parallel-sessions-browser-conflicts) section below |
| `Target page, context or browser has been closed` | Previous session crashed without cleanup | Kill stale processes (see below) |

---

## Parallel Sessions (Browser Conflicts)

**Problem:** Multiple Claude Code sessions share the same Playwright browser profile (`user-data-dir`). If one session doesn't close the browser, others can't launch it.

**Symptoms:**

- Browser fails to start
- `Target page, context or browser has been closed` error
- Playwright MCP hangs on first `browser_navigate`

### Solution 1 — Always Close the Browser (Manual)

**CRITICAL:** Always call `browser_close` as the last step of any Playwright workflow.

Even if your testing is done, the browser stays open and locks the profile. Other Claude sessions will fail until the browser is closed.

### Solution 2 — Use Chromium Instead of System Chrome

System Chrome can conflict with Playwright because Chrome redirects new instances to the already-running window. Chromium is a separate binary that Playwright manages independently.

```json
{
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest", "--browser", "chromium"],
    "env": {}
  }
}
```

Install Chromium:

```bash
npx playwright install chromium
```

### Solution 3 — Stop Hook (Automatic Cleanup)

Add a stop hook to automatically kill the Playwright browser when a Claude session ends — even if `browser_close` wasn't called (context exhausted, crash, user interrupted).

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "pkill -f 'user-data-dir=.*mcp-chrome' 2>/dev/null; rm -f ~/Library/Caches/ms-playwright/mcp-chrome-*/SingletonLock 2>/dev/null; true"
          }
        ]
      }
    ]
  }
}
```

**What it does:**

- `pkill -f 'user-data-dir=.*mcp-chrome'` — kills the Playwright Chrome process (matches only Playwright's Chrome by the `mcp-chrome` user-data-dir argument, not your regular Chrome)
- `rm -f .../SingletonLock` — removes stale lock files (if Chrome crashed without cleanup)
- `true` — ensures the hook always succeeds (no error if no processes found)

> **Note (macOS):** The `Library/Caches/ms-playwright` path is macOS-specific. On Linux, the path is typically `~/.cache/ms-playwright`.

### Emergency Manual Fix

If browser is stuck right now:

```bash
# Kill Playwright's Chrome (safe — doesn't touch your regular Chrome)
pkill -f 'user-data-dir=.*mcp-chrome'

# Remove stale lock (macOS)
rm -f ~/Library/Caches/ms-playwright/mcp-chrome-*/SingletonLock

# Remove stale lock (Linux)
rm -f ~/.cache/ms-playwright/mcp-chrome-*/SingletonLock
```

---

## Do NOT Skip This Step

Even if the change seems trivial:

- A missing import can break the entire page
- A wrong CSS class can hide critical content
- A key mismatch in Vue/React can cause silent render failures
- A typo in a route can return 404

Self-testing catches these before the user has to report them.

---

## If You Find a Bug

1. Fix the issue immediately
2. Redeploy (or restart dev server)
3. Re-test the same workflow
4. Only report completion when the test passes

---

## Add to CLAUDE.md

```markdown
## Visual Self-Testing (Playwright MCP)

**After ANY visual/UI change, self-test using Playwright MCP before reporting completion.**

Workflow:

1. Navigate to affected page (`mcp__playwright__browser_navigate`)
2. Check for console errors
3. Interact with changed elements (snapshot → click → verify)
4. Take screenshots of changed areas
5. If bug found — fix, redeploy, re-test
6. **Always call `browser_close` after finishing tests** — other sessions share the same browser profile

Requires: Playwright MCP server in `.claude/settings.json`.
Full guide: `components/playwright-self-testing.md`
```

---

## MCP Server Setup

### Recommended (Chromium — avoids Chrome conflicts)

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--browser", "chromium"],
      "env": {}
    }
  }
}
```

Then install Chromium: `npx playwright install chromium`

### Alternative (System Chrome)

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "env": {}
    }
  }
}
```

Save to `.claude/settings.json` or `~/.claude/settings.json` (global).

> **Tip:** If you run multiple Claude Code sessions in parallel, use the Chromium config + stop hook (see above) to avoid conflicts.
