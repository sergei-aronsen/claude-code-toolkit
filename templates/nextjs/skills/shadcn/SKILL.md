---
name: Shadcn UI Expert
description: Deep expertise in Shadcn UI - component installation, Radix primitives, styling patterns, form integration
---

# Shadcn UI Expert Skill

This skill provides Shadcn UI expertise including component management, Radix primitives, styling with `cn()`, form integration with React Hook Form + Zod.

---

## 🎯 The Golden Rule: "It's NOT a Library"

Shadcn UI is **NOT** installed via npm as a single package. Components are copied into your codebase.

### Critical Understanding

```tsx
// ❌ WRONG — This import does not exist
import { Button } from 'shadcn-ui';
import { Button } from '@shadcn/ui';

// ✅ CORRECT — Import from your local components
import { Button } from "@/components/ui/button";
```text

### Adding New Components

```bash
# Check if component exists first
ls components/ui/

# If missing, install it
npx shadcn@latest add accordion
npx shadcn@latest add dialog
npx shadcn@latest add form

# Install multiple at once
npx shadcn@latest add button card input label
```text

---

## 📁 File Structure & Imports

### Standard Location

```text
components/
└── ui/                    # All Shadcn components live here
    ├── button.tsx
    ├── card.tsx
    ├── dialog.tsx
    ├── form.tsx
    ├── input.tsx
    └── ...
```text

### Import Syntax

```tsx
// ✅ Always use path alias
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";

// ❌ Never use relative paths
import { Button } from "../../components/ui/button";
```text

### Path Alias Setup (tsconfig.json)

```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./*"]
    }
  }
}
```text

---

## 🎨 Styling with `cn()` Utility

The `cn()` function merges classes correctly using `clsx` + `tailwind-merge`.

### Always Use for Custom Components

```tsx
import { cn } from "@/lib/utils";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'destructive';
}

export function CustomButton({ className, variant, ...props }: ButtonProps) {
  return (
    <button
      className={cn(
        // Base styles
        "px-4 py-2 rounded-md font-medium",
        // Variant styles
        variant === 'destructive' && "bg-destructive text-destructive-foreground",
        // Allow overrides via className prop
        className
      )}
      {...props}
    />
  );
}
```text

### Common Mistakes

```tsx
// ❌ Template literal — doesn't handle conflicts
className={`bg-red-500 ${className}`}

// ❌ Array join — doesn't handle conflicts
className={["bg-red-500", className].join(" ")}

// ✅ cn() — properly merges and handles conflicts
className={cn("bg-red-500", className)}
```text

### Why `cn()` Matters

```tsx
// With cn(), later classes win:
cn("bg-red-500", "bg-blue-500")  // → "bg-blue-500"

// Without cn(), both stay (broken):
`bg-red-500 bg-blue-500`  // → Both classes, unpredictable result
```text

---

## 🎯 Icons (Lucide React)

Shadcn uses **Lucide React** as the default icon library.

### Installation

```bash
pnpm add lucide-react
```text

### Usage

```tsx
// Import icons individually
import {
  Loader2,    // Spinner
  Mail,       // Email
  User,       // User profile
  Settings,   // Settings gear
  ChevronDown // Dropdown arrow
} from "lucide-react";

// Use in components
<Button disabled={isLoading}>
  {isLoading && <Loader2 className="mr-2 size-4 animate-spin" />}
  Submit
</Button>

// Icon sizing
<Mail className="size-4" />   {/* 16px */}
<Mail className="size-5" />   {/* 20px */}
<Mail className="size-6" />   {/* 24px */}
```text

### Common Icons Reference

| Icon | Use Case |
|------|----------|
| `Loader2` | Loading spinner (add `animate-spin`) |
| `Check` | Success, checkbox |
| `X` | Close, remove |
| `ChevronDown/Up/Left/Right` | Dropdowns, accordions |
| `Plus` / `Minus` | Add/remove actions |
| `Search` | Search inputs |
| `Eye` / `EyeOff` | Password visibility |

---

## 📝 Forms (React Hook Form + Zod)

Shadcn's Form components integrate React Hook Form with Zod validation.

### Installation

```bash
npx shadcn@latest add form input label
pnpm add zod react-hook-form @hookform/resolvers
```text

### Complete Form Pattern

```tsx
"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";

import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";

// 1. Define schema
const formSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
});

type FormValues = z.infer<typeof formSchema>;

// 2. Create form component
export function LoginForm() {
  // 3. Initialize form
  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      email: "",
      password: "",
    },
  });

  // 4. Handle submit
  async function onSubmit(values: FormValues) {
    console.log(values);
  }

  // 5. Render
  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Email</FormLabel>
              <FormControl>
                <Input placeholder="email@example.com" {...field} />
              </FormControl>
              <FormDescription>
                We'll never share your email.
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="password"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Password</FormLabel>
              <FormControl>
                <Input type="password" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? "Logging in..." : "Log in"}
        </Button>
      </form>
    </Form>
  );
}
```text

### Form with Select

```tsx
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

<FormField
  control={form.control}
  name="role"
  render={({ field }) => (
    <FormItem>
      <FormLabel>Role</FormLabel>
      <Select onValueChange={field.onChange} defaultValue={field.value}>
        <FormControl>
          <SelectTrigger>
            <SelectValue placeholder="Select a role" />
          </SelectTrigger>
        </FormControl>
        <SelectContent>
          <SelectItem value="admin">Admin</SelectItem>
          <SelectItem value="user">User</SelectItem>
          <SelectItem value="guest">Guest</SelectItem>
        </SelectContent>
      </Select>
      <FormMessage />
    </FormItem>
  )}
/>
```text

---

## 🎨 Theme & Colors

### CSS Variables (globals.css)

Shadcn uses CSS variables for theming. Always use semantic tokens:

```tsx
// ✅ Use semantic variables (auto dark mode)
<div className="bg-background text-foreground">
<div className="bg-card text-card-foreground">
<div className="bg-primary text-primary-foreground">
<div className="bg-muted text-muted-foreground">
<div className="border-border">
<div className="ring-ring">

// ❌ Avoid hardcoded colors (breaks dark mode)
<div className="bg-white text-black">
<div className="bg-slate-900">
```text

### Available Tokens

| Token | Light | Dark | Use Case |
|-------|-------|------|----------|
| `background` | White | Dark | Page background |
| `foreground` | Dark | Light | Primary text |
| `card` | White | Slightly lighter | Card backgrounds |
| `primary` | Brand color | Brand color | Buttons, links |
| `secondary` | Gray | Gray | Secondary buttons |
| `muted` | Light gray | Dark gray | Disabled, subtle |
| `accent` | Light gray | Dark gray | Hover states |
| `destructive` | Red | Red | Errors, delete |

---

## 🔧 Common Components Patterns

### Dialog (Modal)

```tsx
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";

<Dialog>
  <DialogTrigger asChild>
    <Button>Open Dialog</Button>
  </DialogTrigger>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Are you sure?</DialogTitle>
      <DialogDescription>
        This action cannot be undone.
      </DialogDescription>
    </DialogHeader>
    <DialogFooter>
      <Button variant="outline">Cancel</Button>
      <Button>Confirm</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```text

### Card

```tsx
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

<Card>
  <CardHeader>
    <CardTitle>Card Title</CardTitle>
    <CardDescription>Card description here.</CardDescription>
  </CardHeader>
  <CardContent>
    <p>Card content goes here.</p>
  </CardContent>
  <CardFooter>
    <Button>Action</Button>
  </CardFooter>
</Card>
```text

### Toast Notifications

```tsx
// Setup: Add Toaster to root layout
import { Toaster } from "@/components/ui/toaster";

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Toaster />
      </body>
    </html>
  );
}

// Usage in components
import { useToast } from "@/components/ui/use-toast";

function MyComponent() {
  const { toast } = useToast();

  return (
    <Button
      onClick={() => {
        toast({
          title: "Success",
          description: "Your changes have been saved.",
        });
      }}
    >
      Save
    </Button>
  );
}
```text

---

## ⚠️ Common Mistakes

### 1. Wrong Import Path

```tsx
// ❌ These don't exist
import { Button } from 'shadcn-ui';
import { Button } from '@radix-ui/react-button';  // Raw Radix, unstyled

// ✅ Correct
import { Button } from "@/components/ui/button";
```text

### 2. Missing Component Installation

```bash
# Error: Cannot find module '@/components/ui/accordion'
# Solution: Install the component first
npx shadcn@latest add accordion
```text

### 3. Not Using `cn()` for Class Merging

```tsx
// ❌ className override won't work properly
<Button className={`mt-4 ${className}`}>

// ✅ Use cn()
<Button className={cn("mt-4", className)}>
```text

### 4. Forgetting `asChild` for Custom Triggers

```tsx
// ❌ Renders nested buttons (invalid HTML)
<DialogTrigger>
  <Button>Open</Button>
</DialogTrigger>

// ✅ Use asChild to pass props to child
<DialogTrigger asChild>
  <Button>Open</Button>
</DialogTrigger>
```text

### 5. Using Wrong Icon Library

```tsx
// ❌ Don't mix icon libraries
import { FaUser } from 'react-icons/fa';

// ✅ Use Lucide (Shadcn default)
import { User } from 'lucide-react';
```text
