# Design Review — UI/UX Quality Audit

**Uses:** Playwright MCP for live UI testing

---

## 🎯 Scope

**URL/Component:** `[URL or path to component]`
**Viewport:** Desktop (1440px) / Tablet (768px) / Mobile (375px)
**Focus:** [New feature / Redesign / Bug fix / Full audit]

---

## 📋 7-Phase Review Process

### Phase 1: Preparation

```text
1. Define scope of changes (git diff --name-only for UI files)
2. Launch preview environment
3. Open in Playwright: mcp__playwright__browser_navigate
4. Load design principles from ./context/design-principles.md (if exists)
```

**Checklist:**

- [ ] Preview environment works
- [ ] All changed pages are accessible
- [ ] Design guidelines loaded

---

### Phase 2: Interaction Testing

**Primary user flows:**

| Flow | Steps | Status |
|------|-------|--------|
| [Main action] | [1. Click → 2. Fill → 3. Submit] | ⬜ |
| [Secondary action] | [...] | ⬜ |

**Interactive states to verify:**

- [ ] Hover states
- [ ] Focus states
- [ ] Active/pressed states
- [ ] Disabled states
- [ ] Loading states
- [ ] Empty states
- [ ] Error states

**Tools:**

```text
mcp__playwright__browser_click — click verification
mcp__playwright__browser_hover — hover states
mcp__playwright__browser_snapshot — accessibility tree
```

---

### Phase 3: Responsiveness

Test at three breakpoints:

| Viewport | Width | Status | Issues |
|----------|-------|--------|--------|
| Desktop | 1440px | ⬜ | |
| Tablet | 768px | ⬜ | |
| Mobile | 375px | ⬜ | |

**Check for each viewport:**

- [ ] Layout doesn't break
- [ ] Text readable (min 16px on mobile)
- [ ] Touch targets ≥ 44x44px on mobile
- [ ] No horizontal scroll
- [ ] Images are responsive

**Tool:**

```text
mcp__playwright__browser_resize(width, height)
```

---

### Phase 4: Visual Polish

**Layout & Spacing:**

- [ ] Consistent spacing (using spacing scale)
- [ ] Proper alignment (grid alignment)
- [ ] Visual hierarchy is clear
- [ ] Enough white space

**Typography:**

- [ ] Font sizes match the scale
- [ ] Line heights readable (1.4-1.6 for body)
- [ ] Font weights used meaningfully
- [ ] Maximum 2-3 font families

**Color:**

- [ ] Colors from design system
- [ ] Contrast ratios sufficient (see Phase 5)
- [ ] States distinguishable by color + another attribute
- [ ] Dark mode (if applicable)

**Visual consistency:**

- [ ] Components look uniform
- [ ] Icons of same style and size
- [ ] Borders/shadows consistent
- [ ] Animations smooth (not jerky)

---

### Phase 5: Accessibility (WCAG 2.1 AA)

**Keyboard Navigation:**

- [ ] All interactive elements accessible via keyboard
- [ ] Tab order is logical
- [ ] Focus visible and noticeable
- [ ] Escape closes modals/dropdowns
- [ ] No keyboard traps

**Screen Reader:**

- [ ] Semantic HTML (headings, landmarks, lists)
- [ ] Alt text for images
- [ ] ARIA labels where needed
- [ ] Form labels connected to inputs
- [ ] Error messages announced

**Visual:**

- [ ] Color contrast ≥ 4.5:1 for text
- [ ] Color contrast ≥ 3:1 for UI elements
- [ ] Information not only by color
- [ ] Text resizable to 200%
- [ ] No content loss on zoom

**Tool for checking:**

```text
mcp__playwright__browser_snapshot — shows accessibility tree
```

---

### Phase 6: Robustness

**Edge cases:**

- [ ] Empty states (no data)
- [ ] Loading states (slow network)
- [ ] Error states (API failure)
- [ ] Long content (overflow handling)
- [ ] Special characters in input
- [ ] Rapid clicks/submissions

**Form validation:**

- [ ] Required fields marked
- [ ] Validation messages clear
- [ ] Inline validation (not only on submit)
- [ ] Success feedback after submit

**Error handling:**

- [ ] Errors explain what to do
- [ ] Recovery path is clear
- [ ] Partial failures handled gracefully

---

### Phase 7: Code Health

**Component patterns:**

- [ ] Existing components are used
- [ ] New components are reusable
- [ ] Props interface is clear
- [ ] No hardcoded values (use tokens)

**Design tokens:**

- [ ] Colors from variables/tokens
- [ ] Spacing from scale
- [ ] Typography from system
- [ ] No magic numbers

**Performance:**

- [ ] Images optimized (WebP, lazy loading)
- [ ] No layout shifts (CLS)
- [ ] Animations use transform/opacity
- [ ] Bundle size reasonable

---

## 📊 Issue Triage Matrix

Classify each issue:

| Priority | Criteria | Action |
|----------|----------|--------|
| 🔴 **[Blocker]** | Breaks functionality, accessibility failure, data loss | Must fix before merge |
| 🟠 **[High]** | Poor UX, significant visual bug, WCAG violation | Should fix before merge |
| 🟡 **[Medium]** | Minor inconsistency, edge case issue | Can fix in follow-up |
| ⚪ **[Nitpick]** | Aesthetic preference, minor polish | Optional |

---

## 📝 Report Template

```markdown
## Design Review: [Component/Page Name]

**Date:** [date]
**Reviewer:** Claude
**Viewport tested:** Desktop ✅ | Tablet ✅ | Mobile ✅

### Summary

[1-2 sentences: overall assessment]

### 🔴 Blockers (must fix)

1. **[Issue title]**
   - Location: [file:line or URL]
   - Problem: [description]
   - Impact: [user impact]
   - Fix: [suggested solution]
   - Screenshot: [if applicable]

### 🟠 High Priority

1. ...

### 🟡 Medium Priority

1. ...

### ⚪ Nitpicks

1. ...

### ✅ What's Working Well

- [Positive observation 1]
- [Positive observation 2]

### Screenshots

[Attach screenshots at 1440px width]
```

---

## 🛠 Playwright MCP Quick Reference

```text
# Navigation
mcp__playwright__browser_navigate(url)
mcp__playwright__browser_navigate_back()

# Interaction
mcp__playwright__browser_click(element, ref)
mcp__playwright__browser_hover(element, ref)
mcp__playwright__browser_type(element, ref, text)
mcp__playwright__browser_fill_form(fields)

# Inspection
mcp__playwright__browser_snapshot() — accessibility tree (better than screenshot)
mcp__playwright__browser_take_screenshot(filename)
mcp__playwright__browser_console_messages()

# Viewport
mcp__playwright__browser_resize(width, height)

# Tabs
mcp__playwright__browser_tabs(action: "list" | "new" | "close" | "select")

# Cleanup (ALWAYS call when done — shared browser profile blocks other sessions)
mcp__playwright__browser_close()
```

---

## 🎨 Design Principles Reference

If no project-specific guidelines, use:

**Hierarchy:** Important things look important
**Consistency:** Same patterns for same actions
**Feedback:** User always knows system state
**Forgiveness:** Easy to undo, hard to break
**Simplicity:** Remove until it breaks

---

## ⚠️ Common Issues Checklist

**Layout:**

- [ ] Z-index wars (overlapping elements)
- [ ] Overflow hidden cutting content
- [ ] Flexbox/grid alignment issues

**Typography:**

- [ ] Orphans/widows in text
- [ ] Text truncation without tooltip
- [ ] Missing font fallbacks

**Interactive:**

- [ ] Click targets too small
- [ ] Missing loading states
- [ ] Double-submit possible

**Accessibility:**

- [ ] Focus not visible
- [ ] Color-only information
- [ ] Missing form labels

---

**Inspired by:** [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows)
