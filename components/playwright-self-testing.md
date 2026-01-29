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
## Visual Self-Testing with Playwright

**After ANY visual/UI change, self-test using Playwright MCP before reporting completion.**

Workflow:
1. Navigate to affected page (`mcp__playwright__browser_navigate`)
2. Check for console errors
3. Interact with changed elements (snapshot → click → verify)
4. Take screenshots of changed areas
5. If bug found — fix, redeploy, re-test

Requires: Playwright MCP server in `.claude/settings.json`.
Full guide: `components/playwright-self-testing.md`
```

---

## MCP Server Setup

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-playwright"]
    }
  }
}
```

Save to `.claude/settings.json` or `~/.claude/settings.json` (global).
