# Smoke Tests for API — Quick Check That Nothing Is Broken

Minimal set of tests for critical endpoints.

---

## What Are Smoke Tests

```text
"Smoke test" — turned on the device, no smoke = basically works.
```

**Checks:**

- Endpoints respond (not 500)
- Auth works (401/403 where needed)
- Basic response structure

**Does NOT check:**

- Business logic (that's unit tests)
- Edge cases (that's integration tests)
- UI (that's E2E tests)

---

## What to Test

### Critical endpoints (always)

| Type | Examples | Check |
|------|----------|-------|
| Health | `/api/health`, `/up` | 200 OK |
| Auth | `/api/login`, `/api/me` | 200 + 401 |
| Core CRUD | `/api/users`, `/api/posts` | 200 + structure |
| Webhooks | `/webhooks/stripe` | 200 (or 400 without payload) |

### Skip

- Rarely used endpoints
- Admin-only endpoints
- External integrations (test via monitoring)

---

## Examples by Framework

### Laravel (Pest/PHPUnit)

```php
// tests/Feature/SmokeTest.php

use Tests\TestCase;

class SmokeTest extends TestCase
{
    /**
     * @dataProvider publicEndpoints
     */
    public function test_public_endpoints_return_200(string $endpoint): void
    {
        $response = $this->get($endpoint);
        $response->assertStatus(200);
    }

    public static function publicEndpoints(): array
    {
        return [
            'health' => ['/api/health'],
            'home' => ['/'],
        ];
    }

    /**
     * @dataProvider protectedEndpoints
     */
    public function test_protected_endpoints_return_401(string $endpoint): void
    {
        $response = $this->get($endpoint);
        $response->assertStatus(401);
    }

    public static function protectedEndpoints(): array
    {
        return [
            'me' => ['/api/me'],
            'dashboard' => ['/api/dashboard'],
        ];
    }

    public function test_login_works(): void
    {
        $response = $this->post('/api/login', [
            'email' => 'test@example.com',
            'password' => 'password',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['token']);
    }
}
```

**Run:**

```bash
php artisan test --filter=SmokeTest
```

### Next.js (Vitest)

Same pattern using `fetch` against `BASE_URL`. Key differences from Laravel:

- File: `__tests__/smoke.test.ts`, use `describe`/`it.each` with Vitest
- Requires dev server running: `npm run dev &` before tests
- Run: `npx vitest run __tests__/smoke.test.ts`

### Node.js / Express (Jest + Supertest)

Same pattern using `supertest` for direct app testing. Key differences:

- File: `tests/smoke.test.ts`, import app and use `request(app).get(endpoint)`
- No server needed — supertest binds to the app directly
- Run: `npx jest tests/smoke.test.ts`

---

## When to Run

| Moment | How | Why |
|--------|-----|-----|
| Locally | `npm test -- smoke` | Before commit |
| CI/CD | GitHub Actions | Before deploy |
| After deploy | Cron job / monitoring | Check production |

### GitHub Actions Example

```yaml
# .github/workflows/smoke.yml

name: Smoke Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Start server
        run: npm run dev &

      - name: Wait for server
        run: npx wait-on http://localhost:3000

      - name: Run smoke tests
        run: npm run test:smoke
```

---

## How Many Tests Needed

| Project Size | Endpoints | Smoke tests |
|--------------|-----------|-------------|
| Small | 5-10 | 3-5 |
| Medium | 20-50 | 10-15 |
| Large | 100+ | 20-30 critical |

**Rule:** Test what will break users if it goes down.

---

## Checklist for New Project

```markdown
## Smoke Tests Setup

- [ ] Choose test framework (Pest/Vitest/Jest)
- [ ] Create file `tests/smoke.test.{ts,php}`
- [ ] Add public endpoints (health, home)
- [ ] Add protected endpoints (401 check)
- [ ] Add auth flow (login works)
- [ ] Add npm script: `"test:smoke": "..."`
- [ ] Add to CI/CD pipeline
```

---

## Add to CLAUDE.md

```markdown
## Smoke Tests

Minimal tests for critical endpoints:

- Health check → 200
- Protected routes → 401 without auth
- Auth flow → login returns token
- Core CRUD → basic response structure

Run: `npm run test:smoke` or `php artisan test --filter=Smoke`
```

---

## Difference from Other Test Types

```text
┌─────────────────────────────────────────────────────────┐
│  Smoke Tests (this guide)                               │
│  ─────────────────────────────                          │
│  "Does it work at all?"                                 │
│  5-30 tests, < 1 minute                                 │
├─────────────────────────────────────────────────────────┤
│  Unit Tests                                             │
│  ─────────────────────────────                          │
│  "Does the function work correctly?"                    │
│  Many tests, isolated, with mocks                       │
├─────────────────────────────────────────────────────────┤
│  Integration Tests                                      │
│  ─────────────────────────────                          │
│  "Do components work together?"                         │
│  Database, external services                            │
├─────────────────────────────────────────────────────────┤
│  E2E Tests                                              │
│  ─────────────────────────────                          │
│  "Does it work for the user?"                           │
│  Browser, full flow                                     │
└─────────────────────────────────────────────────────────┘
```

---

## Summary

Smoke tests are **insurance**, not a replacement for full testing.

Goal: catch obvious breakages **before** users find them.
