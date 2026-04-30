---
name: Testing
description: Testing patterns — TDD, mocking, coverage, e2e. Triggers on test/testing/tdd/mock/coverage/e2e keywords.
---

# Testing Skill

> Load this skill when writing tests, implementing TDD, or setting up test infrastructure.

---

## Rule

**WRITE TESTS THAT PROVIDE VALUE!**

- Test behavior, not implementation
- Fast tests run often
- Reliable tests build confidence

---

## Test Pyramid

```text
        /\
       /  \      E2E (few)
      /----\     - Critical user flows
     /      \    - Slow, expensive
    /--------\   Integration (some)
   /          \  - Component interactions
  /------------\ - Database, APIs
 /              \
/________________\ Unit (many)
                   - Fast, isolated
                   - Pure functions
```

| Type | Ratio | Speed | Scope |
|------|-------|-------|-------|
| Unit | 70% | ms | Single function/class |
| Integration | 20% | seconds | Multiple components |
| E2E | 10% | minutes | Full user flow |

---

## TDD Workflow

### Red-Green-Refactor

```text
1. RED    - Write failing test
2. GREEN  - Write minimal code to pass
3. REFACTOR - Improve code, keep tests green
```

### TDD Example

```typescript
// 1. RED - Write test first
describe('calculateDiscount', () => {
  it('should apply 10% discount for orders over $100', () => {
    expect(calculateDiscount(150)).toBe(135);
  });
});

// 2. GREEN - Minimal implementation
function calculateDiscount(total: number): number {
  if (total > 100) {
    return total * 0.9;
  }
  return total;
}

// 3. REFACTOR - Improve if needed
const DISCOUNT_THRESHOLD = 100;
const DISCOUNT_RATE = 0.1;

function calculateDiscount(total: number): number {
  if (total > DISCOUNT_THRESHOLD) {
    return total * (1 - DISCOUNT_RATE);
  }
  return total;
}
```

---

## Test Structure (AAA Pattern)

```typescript
describe('UserService', () => {
  describe('createUser', () => {
    it('should create user with valid data', async () => {
      // Arrange - Set up test data and dependencies
      const userData = { email: 'test@example.com', name: 'Test' };
      const mockRepo = { save: vi.fn().mockResolvedValue({ id: 1, ...userData }) };
      const service = new UserService(mockRepo);

      // Act - Execute the code being tested
      const result = await service.createUser(userData);

      // Assert - Verify the outcome
      expect(result.id).toBe(1);
      expect(result.email).toBe('test@example.com');
      expect(mockRepo.save).toHaveBeenCalledWith(userData);
    });
  });
});
```

---

## Test Naming Conventions

### Pattern: should_expectedBehavior_when_condition

```typescript
// Good names
it('should return null when user not found')
it('should throw error when email is invalid')
it('should apply discount when order exceeds threshold')

// Bad names
it('test user')
it('works')
it('createUser test')
```

### Describe Blocks

```typescript
describe('ComponentName or FunctionName', () => {
  describe('methodName', () => {
    describe('when condition', () => {
      it('should expected behavior', () => {});
    });
  });
});
```

---

## Mocking Patterns

### Mock Functions

```typescript
// Vitest
const mockFn = vi.fn();
mockFn.mockReturnValue(42);
mockFn.mockResolvedValue({ data: 'async' });
mockFn.mockRejectedValue(new Error('fail'));

// Verify calls
expect(mockFn).toHaveBeenCalled();
expect(mockFn).toHaveBeenCalledWith('arg');
expect(mockFn).toHaveBeenCalledTimes(2);
```

### Mock Modules

```typescript
// Vitest
vi.mock('@/lib/db', () => ({
  prisma: {
    user: {
      findUnique: vi.fn(),
      create: vi.fn(),
    },
  },
}));

// Reset between tests
beforeEach(() => {
  vi.clearAllMocks();
});
```

### Partial Mocks

```typescript
// Mock only specific methods
vi.mock('@/lib/api', async () => {
  const actual = await vi.importActual('@/lib/api');
  return {
    ...actual,
    fetchData: vi.fn(),  // Only mock this
  };
});
```

---

## Test Fixtures and Factories

### Factory Pattern

```typescript
// factories/user.ts
export function createUser(overrides = {}): User {
  return {
    id: 1,
    email: 'test@example.com',
    name: 'Test User',
    createdAt: new Date(),
    ...overrides,
  };
}

// Usage
const user = createUser({ email: 'custom@example.com' });
```

### Builder Pattern

```typescript
class UserBuilder {
  private user: Partial<User> = {};

  withEmail(email: string) {
    this.user.email = email;
    return this;
  }

  withRole(role: Role) {
    this.user.role = role;
    return this;
  }

  build(): User {
    return {
      id: 1,
      email: 'default@example.com',
      name: 'Test',
      ...this.user,
    };
  }
}

// Usage
const admin = new UserBuilder().withRole('admin').build();
```

---

## Coverage Guidelines

| Metric | Target | Critical |
|--------|--------|----------|
| Statements | 80% | 90% for core logic |
| Branches | 75% | 85% for conditionals |
| Functions | 85% | 95% for public APIs |
| Lines | 80% | 90% for critical paths |

### What to Cover

- Business logic
- Edge cases
- Error handling
- Security-sensitive code

### What NOT to Cover

- Framework code
- Simple getters/setters
- Third-party libraries
- Auto-generated code

---

## Testing Anti-Patterns

### Avoid

```typescript
// Testing implementation details
expect(component.state.isLoading).toBe(true);  // BAD
expect(screen.getByText('Loading...')).toBeInTheDocument();  // GOOD

// Tests that always pass
it('should work', () => {
  const result = doSomething();
  expect(result).toBeDefined();  // Too weak
});

// Shared mutable state
let sharedData;  // BAD - tests affect each other
beforeEach(() => { sharedData = createData(); });  // Reset each test
```

### Prefer

```typescript
// Test behavior from user perspective
// Isolated tests with clear assertions
// Meaningful assertions that can fail
```

---

## Framework Quick Reference

### Vitest (JavaScript/TypeScript)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should do something', async () => {
    const result = await service.method();
    expect(result).toMatchObject({ key: 'value' });
  });
});
```

### PHPUnit (PHP)

```php
class UserServiceTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new UserService();
    }

    public function test_creates_user_with_valid_data(): void
    {
        $result = $this->service->create(['email' => 'test@example.com']);

        $this->assertInstanceOf(User::class, $result);
        $this->assertEquals('test@example.com', $result->email);
    }
}
```

### Go testing

```go
func TestCalculateDiscount(t *testing.T) {
    tests := []struct {
        name     string
        total    float64
        expected float64
    }{
        {"no discount", 50, 50},
        {"with discount", 150, 135},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := CalculateDiscount(tt.total)
            if result != tt.expected {
                t.Errorf("got %v, want %v", result, tt.expected)
            }
        })
    }
}
```

---

## When to Use This Skill

- Writing unit tests
- Setting up test infrastructure
- Implementing TDD workflow
- Creating mocks and fixtures
- Improving test coverage
- Debugging flaky tests
