---
name: Tailwind CSS Expert
description: Deep expertise in Tailwind CSS - utility-first workflow, class ordering, responsive design, accessibility
---

# Tailwind CSS Expert Skill

This skill provides Tailwind CSS expertise including utility-first patterns, consistent class ordering, responsive design, and accessibility best practices.

---

## 🎯 Core Principles

### Utility-First Mindset

- **Check before custom:** Before writing custom CSS, ask: "Is there a utility for this?"
- **Composition:** Build complex components by composing small utilities
- **Readability:** Code must be instantly readable by other developers

### When to Use Custom CSS

| Scenario | Approach |
| ---------- | ---------- |
| One-off styles | Utility classes |
| Repeated pattern (3+ times) | Extract component |
| Complex animations | `@keyframes` in CSS |
| Third-party overrides | Custom CSS with specificity |

---

## 📐 Class Ordering Convention

Sort classes in logical groups (Box Model order):

```tsx
<div className="
  {/* 1. Layout & Position */}
  flex items-center justify-between
  absolute top-0 left-0 z-10

  {/* 2. Spacing */}
  m-4 p-6 gap-4

  {/* 3. Sizing */}
  w-full h-10 max-w-md

  {/* 4. Typography */}
  text-lg font-semibold text-foreground leading-tight

  {/* 5. Visuals */}
  bg-background rounded-xl shadow-sm border border-border

  {/* 6. Interactive States */}
  hover:bg-accent focus:ring-2 focus-visible:ring-ring active:scale-95

  {/* 7. Transitions */}
  transition-colors duration-200
"/>
```

### Quick Reference

| Group | Examples |
| ------- | ---------- |
| Layout | `flex`, `grid`, `block`, `hidden`, `absolute`, `relative` |
| Spacing | `m-*`, `p-*`, `gap-*`, `space-*` |
| Sizing | `w-*`, `h-*`, `size-*`, `min-*`, `max-*` |
| Typography | `text-*`, `font-*`, `leading-*`, `tracking-*` |
| Visuals | `bg-*`, `rounded-*`, `shadow-*`, `border-*`, `opacity-*` |
| Interactive | `hover:*`, `focus:*`, `active:*`, `disabled:*` |

---

## 🔧 Common Patterns Cheatsheet

### Flexbox

```tsx
// Center everything
<div className="flex items-center justify-center">

// Space between with vertical center
<div className="flex items-center justify-between">

// Column layout
<div className="flex flex-col gap-4">

// Wrap items
<div className="flex flex-wrap gap-2">
```

### Grid

```tsx
// Basic grid
<div className="grid grid-cols-3 gap-4">

// Responsive grid
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">

// App layout (header/content/footer)
<div className="grid grid-rows-[auto_1fr_auto] min-h-screen">

// Spanning columns
<div className="col-span-2">
```

### Sizing

```tsx
// Square shorthand
<div className="size-10">  {/* = w-10 h-10 */}

// Full viewport
<div className="w-screen h-screen">  {/* 100vw/100vh */}

// Full parent
<div className="w-full h-full">  {/* 100% */}

// Aspect ratio
<div className="aspect-video">  {/* 16:9 */}
<div className="aspect-square">  {/* 1:1 */}
```

### Colors & Opacity

```tsx
// Modern opacity syntax (preferred)
<div className="bg-primary/10">

// Avoid legacy syntax
<div className="bg-primary bg-opacity-10">  {/* ❌ */}
```

---

## 📱 Responsive Design (Mobile-First)

### Breakpoints

| Prefix | Min-width | Target |
| -------- | ----------- | -------- |
| (none) | 0px | Mobile (default) |
| `sm:` | 640px | Large phones, tablets |
| `md:` | 768px | Tablets, small laptops |
| `lg:` | 1024px | Desktops |
| `xl:` | 1280px | Large screens |
| `2xl:` | 1536px | Extra large |

### Patterns

```tsx
// Stack on mobile, row on desktop
<div className="flex flex-col md:flex-row gap-4">

// Hide sidebar on mobile
<aside className="hidden lg:block w-64">

// Responsive text
<h1 className="text-2xl md:text-3xl lg:text-4xl">

// Responsive padding
<section className="px-4 md:px-8 lg:px-16">
```

### Mobile-First Approach

```tsx
// ✅ Start with mobile, add breakpoints for larger
<div className="p-4 md:p-6 lg:p-8">

// ❌ Don't start with desktop and override down
<div className="p-8 sm:p-4">  {/* Confusing */}
```

---

## ♿ Accessibility

### Focus States

```tsx
// Always include focus-visible for keyboard users
<button className="
  focus:outline-none
  focus-visible:ring-2
  focus-visible:ring-ring
  focus-visible:ring-offset-2
">

// Skip link for screen readers
<a href="#main" className="sr-only focus:not-sr-only">
  Skip to content
</a>
```

### Icon Buttons

```tsx
// Always provide accessible name
<button className="p-2" aria-label="Close menu">
  <XIcon className="size-5" />
  <span className="sr-only">Close menu</span>
</button>
```

### Custom Interactive Elements

```tsx
// If using div as button
<div
  role="button"
  tabIndex={0}
  className="cursor-pointer focus-visible:ring-2"
  onClick={handleClick}
  onKeyDown={(e) => e.key === 'Enter' && handleClick()}
>
```

---

## ⚠️ Prohibited Patterns

### Avoid `@apply` (except globals)

```css
/* ❌ Don't use @apply for components */
.btn-primary {
  @apply bg-primary text-white px-4 py-2 rounded;
}

/* ✅ Use component abstraction instead */
// Button.tsx
export function Button({ children }) {
  return (
    <button className="bg-primary text-white px-4 py-2 rounded">
      {children}
    </button>
  );
}
```

### Avoid Unnecessary Arbitrary Values

```tsx
// ❌ Arbitrary when standard exists
<div className="top-[12px]">

// ✅ Use standard spacing
<div className="top-3">  {/* 12px */}

// ✅ Arbitrary OK when truly custom
<div className="grid-cols-[200px_1fr_100px]">
```

### Conflicting Classes

```tsx
// ❌ Never combine conflicting utilities
<div className="flex hidden">
<div className="block inline">

// ✅ Use responsive or conditional
<div className="hidden md:flex">
```

### Hardcoded Colors (Theme Breaking)

```tsx
// ❌ Breaks dark mode
<div className="bg-white text-black">

// ✅ Use CSS variables / theme tokens
<div className="bg-background text-foreground">
```

---

## 🎨 Theme Integration

### CSS Variables Pattern

```tsx
// Use semantic color names
<div className="bg-background">      {/* --background */}
<div className="text-foreground">    {/* --foreground */}
<div className="bg-primary">         {/* --primary */}
<div className="text-muted-foreground"> {/* --muted-foreground */}
<div className="border-border">      {/* --border */}
```

### Dark Mode

```tsx
// Automatic via CSS variables (preferred)
<div className="bg-background">  {/* Switches automatically */}

// Manual dark mode classes (when needed)
<div className="bg-white dark:bg-slate-900">
```

---

## 🔍 Debugging Tips

### Visual Debugging

```tsx
// Temporarily add outline to see boundaries
<div className="outline outline-red-500">

// Or use ring (doesn't affect layout)
<div className="ring-2 ring-red-500">
```

### Common Issues

| Problem | Solution |
| --------- | ---------- |
| Flex item not shrinking | Add `min-w-0` or `overflow-hidden` |
| Grid overflow | Check `grid-cols-*` matches children count |
| Text not wrapping | Add `break-words` or `overflow-wrap` |
| Z-index not working | Ensure parent has `position: relative` |
