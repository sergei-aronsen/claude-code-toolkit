# /e2e — End-to-End Testing

## Purpose

Generate E2E tests with Playwright for user flows and critical paths.

---

## Usage

```text
/e2e [action] [options]
```

**Actions:**

- `/e2e flow <description>` — Generate test for user flow
- `/e2e page <url>` — Generate tests for page
- `/e2e critical` — Generate tests for critical paths
- `/e2e visual <page>` — Visual regression test

---

## Examples

```text
/e2e flow "user registration"       # Test registration flow
/e2e page /dashboard                # Tests for dashboard page
/e2e critical                       # Auth, checkout, core features
/e2e visual /landing                # Screenshot comparison test
```

---

## Test Structure

All generated tests follow AAA pattern (Arrange-Act-Assert) with semantic selectors.

### `/e2e flow` — generates complete test suite

```typescript
// tests/e2e/auth/registration.spec.ts
import { test, expect } from '@playwright/test';

test.describe('User Registration', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/register');
  });

  test('should register new user successfully', async ({ page }) => {
    await page.getByLabel(/email/i).fill(`test-${Date.now()}@example.com`);
    await page.getByLabel(/password/i).fill('SecurePass123!');
    await page.getByRole('button', { name: /sign up/i }).click();
    await expect(page).toHaveURL(/dashboard|welcome/);
  });

  test('should show error for invalid email', async ({ page }) => {
    await page.getByLabel(/email/i).fill('invalid-email');
    await page.getByRole('button', { name: /sign up/i }).click();
    await expect(page.getByText(/invalid email/i)).toBeVisible();
  });
});
```

### `/e2e critical` — auth + core CRUD flows

Uses `storageState` for authenticated tests. Covers: login/logout, create/view/edit/delete for core entities.

### `/e2e visual` — screenshot regression

> Playwright supports only `png` and `jpeg`. For WebP, convert after capture.

Generates desktop (1920x1080), mobile (375x667), and dark mode snapshots with `toHaveScreenshot()` and `maxDiffPixels: 100`.

### Page Object Pattern

For reusable pages, generates classes with typed locators and action methods (e.g., `LoginPage.login(email, password)`).

---

## Test Categories

| Category | Purpose | Example |
|----------|---------|---------|
| Smoke | Basic functionality | App loads, login works |
| Critical Path | Core user flows | Registration → Dashboard |
| Regression | Prevent bugs | Known edge cases |
| Visual | UI consistency | Screenshot comparison |

---

## Commands

```bash
# Run all E2E tests
npx playwright test

# Run specific test file
npx playwright test registration.spec.ts

# Run with UI
npx playwright test --ui

# Update snapshots
npx playwright test --update-snapshots

# Generate report
npx playwright show-report
```

---

## Actions

1. Identify user flow or page
2. Generate test structure with AAA pattern
3. Use semantic selectors (roles, labels)
4. Add assertions for happy path
5. Add edge case tests
6. Include visual tests if applicable
