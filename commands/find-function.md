# /find-function — Find Functions and Methods

## Purpose

Find where a function, method, or class is defined or used in the codebase.

---

## Usage

```text
/find-function <name> [--usage]
```text

**Examples:**

- `/find-function processPayment` — Find definition
- `/find-function UserService --usage` — Find all usages
- `/find-function handleSubmit` — Find React handler

---

## Search Strategy

### 1. Definition Search

```bash
# PHP
grep -rn "function $NAME" app/ lib/
grep -rn "public function $NAME" app/
grep -rn "class $NAME" app/

# TypeScript/JavaScript
grep -rn "function $NAME" src/ app/ lib/
grep -rn "const $NAME = " src/ app/ lib/
grep -rn "export function $NAME" src/ app/ lib/
grep -rn "export const $NAME" src/ app/ lib/
```text

### 2. Usage Search (with --usage flag)

```bash
# Find all calls to the function
grep -rn "$NAME(" app/ lib/ src/ components/
grep -rn "->$NAME(" app/          # PHP method calls
grep -rn "::$NAME(" app/          # PHP static calls
```text

---

## Output Format

### Definition Found

```markdown
## Function: `functionName`

**Defined in:** `app/Services/PaymentService.php:45`

\`\`\`php
public function functionName(string $param): Result
{
    // Implementation...
}
\`\`\`

**Type:** Public method of `PaymentService`
**Parameters:** `$param: string`
**Returns:** `Result`
```text

### With --usage Flag

```markdown
## Function: `functionName`

**Definition:** `app/Services/PaymentService.php:45`

### Usages (5 found)

| File | Line | Context |
|------|------|---------|
| Controller.php | 23 | `$service->functionName($data)` |
| Job.php | 45 | `$this->service->functionName($item)` |
| Test.php | 12 | `$mock->functionName(...)` |
```text

### Not Found

```markdown
## Function: `functionName`

**Status:** Not found in codebase

**Suggestions:**
- Check spelling
- Function may be from a package (vendor/)
- Try searching partial name: `/find-function payment`
```text

---

## Behavior

1. **Search definitions first** — Find where it's declared
2. **Show signature** — Parameters and return type
3. **Context matters** — Show surrounding code
4. **Suggest alternatives** — If not found, help user search differently

---

## Actions

1. Search for function/method definition
2. If found, read the file and extract signature
3. If --usage flag, search for all usages
4. Format results with file locations and code snippets
