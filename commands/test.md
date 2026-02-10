# /test — Write Tests

## Purpose

Write tests for code, functions, or features.

---

## Usage

```text
/test <target> [--type=unit|integration|e2e]
```

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

### PHPUnit/Pest Pattern

```php
class ServiceTest extends TestCase
{
    private Service $service;

    protected function setUp(): void { parent::setUp(); $this->service = new Service(); }

    public function test_happy_path(): void
    {
        // Arrange -> Act -> Assert
        $result = $this->service->process($validInput);
        $this->assertTrue($result->success);
    }

    public function test_error_case(): void
    {
        $this->expectException(DomainException::class);
        $this->service->process($invalidInput);
    }
}
```

### Vitest/Jest Pattern

```typescript
describe('Service', () => {
  beforeEach(() => { vi.clearAllMocks(); });

  it('should succeed with valid input', async () => {
    // Arrange: vi.mocked(dep).mockResolvedValue(data)
    // Act: const result = await service.process(input)
    // Assert: expect(result.success).toBe(true)
  });

  it('should throw on invalid input', async () => {
    await expect(service.process(bad)).rejects.toThrow('message');
  });
});
```

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
[path to test file]

### Test Cases
| # | Test | Type | Description |
|---|------|------|-------------|
| 1 | test_happy_path | Unit | Normal operation |
| 2 | test_edge_case | Unit | Empty input |

### Code
[Full test code]

### Run
[Framework-specific test command]
```

---

## Actions

1. Identify the target code
2. Determine test type (unit/integration/e2e)
3. List test cases (happy path, edge cases, errors)
4. Write tests following project conventions
5. Show how to run the tests
