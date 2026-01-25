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

## Generated Tests

### For `/e2e flow "user registration"`

```typescript
// tests/e2e/auth/registration.spec.ts
import { test, expect } from '@playwright/test';

test.describe('User Registration', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/register');
  });

  test('should display registration form', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /register/i })).toBeVisible();
    await expect(page.getByLabel(/email/i)).toBeVisible();
    await expect(page.getByLabel(/password/i)).toBeVisible();
    await expect(page.getByRole('button', { name: /sign up/i })).toBeVisible();
  });

  test('should register new user successfully', async ({ page }) => {
    // Arrange
    const email = `test-${Date.now()}@example.com`;
    const password = 'SecurePass123!';

    // Act
    await page.getByLabel(/email/i).fill(email);
    await page.getByLabel(/password/i).fill(password);
    await page.getByLabel(/confirm password/i).fill(password);
    await page.getByRole('button', { name: /sign up/i }).click();

    // Assert
    await expect(page).toHaveURL(/dashboard|welcome/);
    await expect(page.getByText(/welcome|success/i)).toBeVisible();
  });

  test('should show error for invalid email', async ({ page }) => {
    await page.getByLabel(/email/i).fill('invalid-email');
    await page.getByLabel(/password/i).fill('password123');
    await page.getByRole('button', { name: /sign up/i }).click();

    await expect(page.getByText(/invalid email/i)).toBeVisible();
  });

  test('should show error for weak password', async ({ page }) => {
    await page.getByLabel(/email/i).fill('test@example.com');
    await page.getByLabel(/password/i).fill('123');
    await page.getByRole('button', { name: /sign up/i }).click();

    await expect(page.getByText(/password.*characters/i)).toBeVisible();
  });

  test('should show error for existing email', async ({ page }) => {
    // Use known existing user
    await page.getByLabel(/email/i).fill('existing@example.com');
    await page.getByLabel(/password/i).fill('SecurePass123!');
    await page.getByRole('button', { name: /sign up/i }).click();

    await expect(page.getByText(/already exists|taken/i)).toBeVisible();
  });
});
```

---

## Critical Path Tests

### For `/e2e critical`

```typescript
// tests/e2e/critical-paths.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Critical Paths', () => {

  test.describe('Authentication', () => {
    test('user can log in and log out', async ({ page }) => {
      await page.goto('/login');
      await page.getByLabel(/email/i).fill('user@example.com');
      await page.getByLabel(/password/i).fill('password');
      await page.getByRole('button', { name: /log in/i }).click();

      await expect(page).toHaveURL(/dashboard/);

      await page.getByRole('button', { name: /profile|menu/i }).click();
      await page.getByRole('menuitem', { name: /log out/i }).click();

      await expect(page).toHaveURL(/login|home/);
    });
  });

  test.describe('Core Feature', () => {
    test.use({ storageState: 'tests/.auth/user.json' });

    test('user can create and view item', async ({ page }) => {
      // Create
      await page.goto('/items/new');
      await page.getByLabel(/title/i).fill('Test Item');
      await page.getByRole('button', { name: /create/i }).click();

      await expect(page.getByText(/created successfully/i)).toBeVisible();

      // View
      await page.goto('/items');
      await expect(page.getByText('Test Item')).toBeVisible();
    });
  });

});
```

---

## Visual Regression

> **Note:** Playwright supports only `png` and `jpeg` formats for screenshots. WebP is not supported natively. To get WebP, take screenshot in PNG first, then convert using `cwebp` or ImageMagick.

> **Tip:** Use [idcac-playwright](https://www.npmjs.com/package/idcac-playwright) to automatically hide cookie banners before taking screenshots:
>
> ```typescript
> import { getInjectableScript } from 'idcac-playwright';
> await page.evaluate(getInjectableScript());
> ```

### For `/e2e visual /landing`

```typescript
// tests/e2e/visual/landing.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Landing Page Visual', () => {

  test('desktop view matches snapshot', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/');

    // Wait for animations/lazy content
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('landing-desktop.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('mobile view matches snapshot', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('landing-mobile.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('dark mode matches snapshot', async ({ page }) => {
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('landing-dark.png', {
      fullPage: true,
    });
  });

});
```

---

## Page Object Pattern

```typescript
// tests/e2e/pages/LoginPage.ts
import { Page, Locator } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByLabel(/email/i);
    this.passwordInput = page.getByLabel(/password/i);
    this.submitButton = page.getByRole('button', { name: /log in/i });
    this.errorMessage = page.getByRole('alert');
  }

  async goto() {
    await this.page.goto('/login');
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
```

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
