# /tdd — Test-Driven Development

## Purpose

Implement a feature using strict TDD: write tests first, then minimal code to pass.

---

## Usage

```text
/tdd <feature or function>
```text

**Examples:**

- `/tdd UserService::createUser`
- `/tdd site creation endpoint`
- `/tdd password reset flow`

---

## TDD Workflow

```text
┌─────────────────────────────────────────────────┐
│                                                 │
│   1. RED      Write failing test                │
│      ↓                                          │
│   2. GREEN    Write minimal code to pass        │
│      ↓                                          │
│   3. REFACTOR Improve code, tests still pass    │
│      ↓                                          │
│   (repeat)                                      │
│                                                 │
└─────────────────────────────────────────────────┘
```text

---

## Phase 1: RED (Tests Only)

### What to Test

| Category | Examples |
|----------|----------|
| Happy Path | Valid input → expected output |
| Edge Cases | Empty, null, zero, max values |
| Boundaries | Off-by-one, limits |
| Errors | Invalid input, exceptions |
| Security | Auth, validation bypass |

### Test Structure

```php
describe('Feature', function () {
    describe('action', function () {
        it('does X when Y', function () {
            // Arrange
            // Act
            // Assert
        });
    });
});
```text

### Rules

- ✅ Write ALL tests before any implementation
- ✅ Tests MUST fail initially
- ✅ Tests should fail for the RIGHT reason
- ❌ DO NOT write implementation code yet
- ❌ DO NOT skip edge cases

---

## Phase 2: GREEN (Implementation)

### Process

1. Pick ONE failing test
2. Write MINIMUM code to pass it
3. Run tests
4. If green, move to next test
5. Repeat until all tests pass

### Rules

- ✅ Write simplest code that passes
- ✅ Run tests after each change
- ❌ DO NOT write more than needed
- ❌ DO NOT modify tests to pass
- ❌ DO NOT optimize yet

---

## Phase 3: REFACTOR

### When All Tests Green

1. Look for code smells
2. Extract methods/classes
3. Improve naming
4. Remove duplication
5. Run tests after each change

### Rules

- ✅ Keep tests green throughout
- ✅ Small refactoring steps
- ❌ DO NOT add new functionality
- ❌ DO NOT break tests

---

## Output Format

### Phase 1 Output

```markdown
## TDD Phase 1: Tests for [Feature]

### Test File
`tests/Feature/[Name]Test.php`

### Test Cases
| # | Test | Category |
|---|------|----------|
| 1 | creates_user_with_valid_data | Happy |
| 2 | validates_email_format | Validation |
| 3 | rejects_duplicate_email | Edge |
| 4 | requires_authentication | Security |

### Test Code
\`\`\`php
// Full test implementation
\`\`\`

### Run Tests (Should Fail)
\`\`\`bash
php artisan test --filter=UserServiceTest
\`\`\`

Expected: 4 tests, 4 failures
```text

### Phase 2 Output

```markdown
## TDD Phase 2: Implementation

### Iteration 1
**Target:** test_creates_user_with_valid_data

**Code Added:**
\`\`\`php
// Minimal implementation
\`\`\`

**Result:** 1 pass, 3 failures

### Iteration 2
...

### Final Result
All 4 tests passing ✅
```text

---

## Examples

### Laravel Example

```php
// Phase 1: Tests
describe('UserService', function () {
    it('creates user with valid data', function () {
        $service = new UserService();
        
        $user = $service->create([
            'name' => 'John',
            'email' => 'john@example.com',
        ]);
        
        expect($user)->toBeInstanceOf(User::class);
        expect($user->name)->toBe('John');
    });
    
    it('throws for invalid email', function () {
        $service = new UserService();
        
        expect(fn() => $service->create([
            'name' => 'John',
            'email' => 'invalid',
        ]))->toThrow(ValidationException::class);
    });
});
```text

### Next.js Example

```typescript
// Phase 1: Tests
describe('createUser', () => {
  it('creates user with valid data', async () => {
    const formData = new FormData();
    formData.set('name', 'John');
    formData.set('email', 'john@example.com');
    
    const result = await createUser(formData);
    
    expect(result.success).toBe(true);
    expect(result.user.name).toBe('John');
  });
  
  it('throws for unauthorized user', async () => {
    vi.mocked(auth).mockResolvedValue(null);
    
    await expect(createUser(new FormData()))
      .rejects.toThrow('Unauthorized');
  });
});
```text

---

## Commands

```bash
# Run specific test file
php artisan test --filter=UserServiceTest
pnpm test UserService.test.ts

# Watch mode
php artisan test --filter=UserServiceTest --watch
pnpm test --watch UserService

# With coverage
php artisan test --coverage
pnpm test --coverage
```text
