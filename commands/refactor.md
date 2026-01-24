# /refactor — Refactor Code

## Purpose

Improve code structure without changing functionality.

---

## Usage

```text
/refactor <target> [--type=extract|simplify|rename|pattern]
```text

**Examples:**

- `/refactor UserController` — General refactoring
- `/refactor this function --type=extract` — Extract methods
- `/refactor OrderService --type=pattern` — Apply design pattern
- `/refactor --type=simplify` — Simplify complex code

---

## Refactoring Types

| Type | When to Use | Goal |
|------|-------------|------|
| Extract | Long methods, duplicated code | Smaller, reusable units |
| Simplify | Complex conditionals, deep nesting | Readable code |
| Rename | Unclear names | Self-documenting code |
| Pattern | Common problems | Proven solutions |

---

## Common Refactorings

### 1. Extract Method

```php
// Before
public function processOrder(Order $order): void
{
    // Validate order
    if (!$order->items->count()) {
        throw new EmptyOrderException();
    }
    if ($order->total < 0) {
        throw new InvalidTotalException();
    }

    // Calculate totals
    $subtotal = $order->items->sum('price');
    $tax = $subtotal * 0.2;
    $total = $subtotal + $tax;

    // Save
    $order->update(['total' => $total]);
}

// After
public function processOrder(Order $order): void
{
    $this->validateOrder($order);
    $total = $this->calculateTotal($order);
    $order->update(['total' => $total]);
}

private function validateOrder(Order $order): void
{
    if (!$order->items->count()) {
        throw new EmptyOrderException();
    }
    if ($order->total < 0) {
        throw new InvalidTotalException();
    }
}

private function calculateTotal(Order $order): float
{
    $subtotal = $order->items->sum('price');
    $tax = $subtotal * 0.2;
    return $subtotal + $tax;
}
```text

### 2. Simplify Conditionals

```typescript
// Before
function getDiscount(user: User, order: Order): number {
  if (user.isPremium) {
    if (order.total > 100) {
      if (order.items.length > 5) {
        return 0.25;
      } else {
        return 0.20;
      }
    } else {
      return 0.10;
    }
  } else {
    if (order.total > 100) {
      return 0.05;
    } else {
      return 0;
    }
  }
}

// After
function getDiscount(user: User, order: Order): number {
  if (!user.isPremium) {
    return order.total > 100 ? 0.05 : 0;
  }

  if (order.total <= 100) {
    return 0.10;
  }

  return order.items.length > 5 ? 0.25 : 0.20;
}
```text

### 3. Replace Conditionals with Polymorphism

```php
// Before
class PaymentProcessor
{
    public function process(Payment $payment): void
    {
        switch ($payment->type) {
            case 'credit_card':
                // 50 lines of credit card logic
                break;
            case 'paypal':
                // 50 lines of PayPal logic
                break;
            case 'crypto':
                // 50 lines of crypto logic
                break;
        }
    }
}

// After
interface PaymentMethod
{
    public function process(Payment $payment): void;
}

class CreditCardPayment implements PaymentMethod { /* ... */ }
class PayPalPayment implements PaymentMethod { /* ... */ }
class CryptoPayment implements PaymentMethod { /* ... */ }

class PaymentProcessor
{
    public function process(Payment $payment, PaymentMethod $method): void
    {
        $method->process($payment);
    }
}
```text

---

## Refactoring Checklist

### Before Refactoring

- [ ] Tests exist and pass
- [ ] Code is under version control
- [ ] Understand what the code does

### During Refactoring

- [ ] Small steps (commit after each change)
- [ ] Run tests frequently
- [ ] Don't change functionality

### After Refactoring

- [ ] All tests still pass
- [ ] Code is more readable
- [ ] No new bugs introduced

---

## Output Format

```markdown
## Refactoring: [target]

### Problem
[What's wrong with current code]

### Solution
[What refactoring approach to use]

### Before
\`\`\`php
// Current code
\`\`\`

### After
\`\`\`php
// Refactored code
\`\`\`

### Changes Summary
- Extracted X methods
- Simplified Y conditionals
- Renamed Z variables

### Verification
- [ ] Tests pass
- [ ] Functionality unchanged
- [ ] Code is cleaner
```text

---

## Actions

1. Understand current code behavior
2. Identify code smells
3. Choose appropriate refactoring
4. Apply in small steps
5. Verify tests pass after each step
6. Show before/after comparison
