# Design Review — Next.js UI/UX Quality Audit

**Uses:** Playwright MCP for live interface testing

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
2. Start dev server: npm run dev
3. Open in Playwright: mcp__playwright__browser_navigate
4. Load design principles from ./context/design-principles.md (if exists)
```

**Next.js specific files to check:**

```text
app/                    # App Router pages
components/             # UI components
styles/                 # Global styles
tailwind.config.js      # Design tokens (if Tailwind)
```

**Checklist:**

- [ ] Dev server is running
- [ ] All modified pages/components are accessible
- [ ] Design system/tokens loaded

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
- [ ] Loading states (Suspense boundaries)
- [ ] Empty states
- [ ] Error states (error.tsx)

**Next.js specific:**

- [ ] Client/Server component boundaries work
- [ ] useTransition for non-blocking updates
- [ ] Optimistic updates (if present)

**Tools:**

```text
mcp__playwright__browser_click — click testing
mcp__playwright__browser_hover — hover states
mcp__playwright__browser_snapshot — accessibility tree
```

---

### Phase 3: Responsiveness

Test at three breakpoints:

| Viewport | Width | Tailwind | Status |
|----------|-------|----------|--------|
| Desktop | 1440px | `xl:` | ⬜ |
| Tablet | 768px | `md:` | ⬜ |
| Mobile | 375px | default | ⬜ |

**Check for each viewport:**

- [ ] Layout doesn't break
- [ ] Text is readable (min 16px on mobile)
- [ ] Touch targets ≥ 44x44px on mobile
- [ ] No horizontal scroll
- [ ] next/image responsive (sizes prop)

**Tool:**

```text
mcp__playwright__browser_resize(width, height)
```

---

### Phase 4: Visual Polish

**Layout & Spacing:**

- [ ] Consistent spacing (Tailwind spacing scale)
- [ ] Proper alignment (grid/flex)
- [ ] Visual hierarchy is clear
- [ ] Container max-width appropriate

**Typography:**

- [ ] Font sizes from Tailwind scale
- [ ] Line heights readable
- [ ] next/font for optimization
- [ ] Prose styling for content (if present)

**Color:**

- [ ] Colors from tailwind.config.js or CSS variables
- [ ] Contrast ratios sufficient
- [ ] Dark mode via `dark:` classes
- [ ] CSS variables for theming

**Next.js Image optimization:**

- [ ] Using next/image (not img)
- [ ] Proper sizes/srcSet
- [ ] Priority for LCP images
- [ ] Placeholder blur (if needed)

---

### Phase 5: Accessibility (WCAG 2.1 AA)

**Keyboard Navigation:**

- [ ] All interactive elements accessible
- [ ] Tab order logical
- [ ] Focus visible (focus-visible:)
- [ ] Escape closes modals
- [ ] No keyboard traps

**Screen Reader:**

- [ ] Semantic HTML (headings, landmarks)
- [ ] Alt text for next/image
- [ ] ARIA labels where needed
- [ ] Form labels connected

**Visual:**

- [ ] Color contrast ≥ 4.5:1 for text
- [ ] Color contrast ≥ 3:1 for UI
- [ ] Information not only by color
- [ ] Text resizable up to 200%

**Next.js specific:**

- [ ] Metadata for SEO (generateMetadata)
- [ ] Skip links for navigation
- [ ] Focus management on route change

**Tool:**

```text
mcp__playwright__browser_snapshot — accessibility tree
```

---

### Phase 6: Robustness

**Edge cases:**

- [ ] Empty states (no data)
- [ ] Loading states (loading.tsx, Suspense)
- [ ] Error states (error.tsx, ErrorBoundary)
- [ ] Not found (not-found.tsx)
- [ ] Long content (overflow)
- [ ] Offline behavior

**Form validation:**

- [ ] Server Actions validation
- [ ] Client-side validation (react-hook-form/zod)
- [ ] Error messages clear
- [ ] useFormStatus for pending state

**Next.js specific:**

- [ ] Streaming works (Suspense)
- [ ] Partial rendering doesn't break UI
- [ ] Route handlers errors handled
- [ ] Revalidation doesn't create flicker

---

### Phase 7: Code Health

**Component patterns:**

- [ ] Server Components where possible
- [ ] Client Components minimal ('use client')
- [ ] Composition over props drilling
- [ ] No unnecessary re-renders

**Design tokens (Tailwind):**

```javascript
// tailwind.config.js
theme: {
  extend: {
    colors: { ... },    // Custom colors
    spacing: { ... },   // Custom spacing
    fontSize: { ... },  // Typography scale
  }
}
```

- [ ] Custom values in config, not hardcoded
- [ ] Consistent class ordering
- [ ] No arbitrary values `[123px]` without reason

**Performance:**

- [ ] Images via next/image
- [ ] Fonts via next/font
- [ ] Dynamic imports for heavy components
- [ ] No CLS (Cumulative Layout Shift)

**Bundle analysis:**

```bash
npm run build
# Check .next/analyze (if @next/bundle-analyzer is configured)
```

---

## 📊 Issue Triage Matrix

| Priority | Criteria | Action |
|----------|----------|--------|
| 🔴 **[Blocker]** | Breaks functionality, a11y failure, hydration error | Must fix before merge |
| 🟠 **[High]** | Poor UX, visual bug, WCAG violation | Should fix before merge |
| 🟡 **[Medium]** | Minor inconsistency, edge case | Can fix in follow-up |
| ⚪ **[Nitpick]** | Aesthetic preference, minor polish | Optional |

---

## 📝 Report Template

```markdown
## Design Review: [Component/Page Name]

**Date:** [date]
**Reviewer:** Claude
**Framework:** Next.js [version]
**Viewport tested:** Desktop ✅ | Tablet ✅ | Mobile ✅

### Summary

[1-2 sentences: overall assessment]

### 🔴 Blockers

1. **[Issue title]**
   - Location: `app/page.tsx:42`
   - Problem: [description]
   - Impact: [user impact]
   - Fix: [suggested solution]

### 🟠 High Priority

1. ...

### 🟡 Medium Priority

1. ...

### ⚪ Nitpicks

1. ...

### ✅ What's Working Well

- [Positive observation]

### Core Web Vitals Check

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| LCP | < 2.5s | | ⬜ |
| FID | < 100ms | | ⬜ |
| CLS | < 0.1 | | ⬜ |
```

---

## 🛠 Playwright MCP Quick Reference

```text
# Navigation
mcp__playwright__browser_navigate(url)

# Interaction
mcp__playwright__browser_click(element, ref)
mcp__playwright__browser_hover(element, ref)
mcp__playwright__browser_type(element, ref, text)

# Inspection
mcp__playwright__browser_snapshot() — accessibility tree
mcp__playwright__browser_take_screenshot(filename)
mcp__playwright__browser_console_messages() — check for hydration errors

# Viewport
mcp__playwright__browser_resize(width, height)

# Cleanup (ALWAYS call when done — shared browser profile blocks other sessions)
mcp__playwright__browser_close()
```

---

## ⚡ Next.js Specific Checks

### Hydration Issues

```text
mcp__playwright__browser_console_messages(level: "error")
# Look for: "Hydration failed", "Text content mismatch"
```

### Image Optimization

```jsx
// ❌ Bad
<img src="/hero.jpg" />

// ✅ Good
<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority  // for LCP image
/>
```

### Loading States

```jsx
// app/dashboard/loading.tsx
export default function Loading() {
  return <DashboardSkeleton />
}
```

### Error Handling

```jsx
// app/dashboard/error.tsx
'use client'
export default function Error({ error, reset }) {
  return (
    <div>
      <p>Something went wrong</p>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

---

## 🎨 Tailwind Design System Checklist

**Required in tailwind.config.js:**

```javascript
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: { /* scale */ },
        secondary: { /* scale */ },
        // semantic colors
        success: '',
        warning: '',
        error: '',
      },
      fontFamily: {
        sans: ['var(--font-inter)'],
      },
    },
  },
}
```

**Component consistency:**

- [ ] Button variants defined
- [ ] Input styles consistent
- [ ] Card patterns reusable
- [ ] Spacing scale followed

---

**Inspired by:** [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows)
