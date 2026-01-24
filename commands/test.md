# /test — Write Tests

## Purpose

Write tests for code, functions, or features.

---

## Usage

```text
/test <target> [--type=unit|integration|e2e]
```text

**Examples:**

- `/test app/Services/PaymentService.php` — Unit tests for service
- `/test UserController --type=integration` — Integration tests
- `/test checkout flow --type=e2e` — E2E tests
- `/test this function` — Test selected code

---

## Test Types

| Type | Scope | Speed | Dependencies |
|------|-------|-------|--------------|
| Unit | Single function/class | Fast | Mocked |
| Integration | Multiple components | Medium | Some real |
| E2E | Full user flow | Slow | All real |

---

## Framework Templates

### Laravel (PHPUnit/Pest)

```php
// tests/Unit/Services/PaymentServiceTest.php
<?php

namespace Tests\Unit\Services;

use App\Services\PaymentService;
use App\Models\User;
use Tests\TestCase;
use Mockery;

class PaymentServiceTest extends TestCase
{
    private PaymentService $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new PaymentService();
    }

    public function test_process_payment_succeeds_with_valid_data(): void
    {
        // Arrange
        $user = User::factory()->create();
        $amount = 100.00;

        // Act
        $result = $this->service->processPayment($user, $amount);

        // Assert
        $this->assertTrue($result->success);
        $this->assertEquals($amount, $result->amount);
    }

    public function test_process_payment_fails_with_insufficient_balance(): void
    {
        // Arrange
        $user = User::factory()->create(['balance' => 50]);

        // Act & Assert
        $this->expectException(InsufficientBalanceException::class);
        $this->service->processPayment($user, 100.00);
    }
}
```text

### Next.js (Vitest/Jest)

```typescript
// __tests__/services/payment.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { processPayment } from '@/lib/services/payment';
import { prisma } from '@/lib/db';

vi.mock('@/lib/db', () => ({
  prisma: {
    payment: {
      create: vi.fn(),
    },
    user: {
      findUnique: vi.fn(),
    },
  },
}));

describe('PaymentService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should process payment successfully', async () => {
    // Arrange
    const mockUser = { id: '1', balance: 200 };
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockUser);
    vi.mocked(prisma.payment.create).mockResolvedValue({ id: 'pay_1', amount: 100 });

    // Act
    const result = await processPayment('1', 100);

    // Assert
    expect(result.success).toBe(true);
    expect(result.amount).toBe(100);
  });

  it('should throw error for insufficient balance', async () => {
    // Arrange
    const mockUser = { id: '1', balance: 50 };
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockUser);

    // Act & Assert
    await expect(processPayment('1', 100)).rejects.toThrow('Insufficient balance');
  });
});
```text

---

## Test Checklist

### What to Test

- [ ] Happy path (normal operation)
- [ ] Edge cases (empty, null, max values)
- [ ] Error cases (invalid input, exceptions)
- [ ] Boundary conditions
- [ ] Authorization (if applicable)

### What NOT to Test

- [ ] Framework code (Laravel/Next.js internals)
- [ ] Third-party libraries
- [ ] Simple getters/setters
- [ ] Private methods directly

---

## Output Format

```markdown
## Tests for [target]

### Test File
`tests/[path]/[Name]Test.php` or `__tests__/[path]/[name].test.ts`

### Test Cases

| # | Test | Type | Description |
|---|------|------|-------------|
| 1 | test_happy_path | Unit | Normal operation |
| 2 | test_edge_case | Unit | Empty input |
| 3 | test_error_case | Unit | Invalid data |

### Code

\`\`\`php
// Full test code here
\`\`\`

### Run Tests

\`\`\`bash
# Laravel
php artisan test --filter=PaymentServiceTest

# Next.js
npm test -- payment.test.ts
\`\`\`
```text

---

## Actions

1. Identify the target code
2. Determine test type (unit/integration/e2e)
3. List test cases (happy path, edge cases, errors)
4. Write tests following project conventions
5. Show how to run the tests
