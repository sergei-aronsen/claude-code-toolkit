# /doc — Generate Documentation

## Purpose

Generate documentation for a file, function, class, or module.

---

## Usage

```text
/doc <target>
```text

**Examples:**

- `/doc app/Services/PaymentService.php` — Document entire file
- `/doc UserController::store` — Document specific method
- `/doc src/lib/utils.ts` — Document TypeScript module

---

## Behavior

1. **Read the target** — Analyze the code structure
2. **Identify purpose** — What does it do?
3. **Document interface** — Parameters, returns, exceptions
4. **Add examples** — Usage examples if applicable

---

## Output Format

### For Functions/Methods

```markdown
## functionName

**Purpose:** Brief description of what the function does.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| param1 | string | Description |
| param2 | number | Description |

**Returns:** `ReturnType` — Description of return value

**Throws:**
- `ExceptionType` — When condition occurs

**Example:**
\`\`\`php
$result = functionName('value', 123);
\`\`\`
```text

### For Classes

```markdown
## ClassName

**Purpose:** Brief description of the class responsibility.

**Dependencies:**
- `DependencyA` — Why it's needed
- `DependencyB` — Why it's needed

### Public Methods

| Method | Description |
|--------|-------------|
| method1() | What it does |
| method2() | What it does |

### Usage

\`\`\`php
$instance = new ClassName($dep1, $dep2);
$instance->method1();
\`\`\`
```text

### For Files/Modules

```markdown
## filename.ext

**Purpose:** What this file/module provides.

**Exports:**
| Name | Type | Description |
|------|------|-------------|
| export1 | function | Description |
| export2 | class | Description |

**Dependencies:**
- Internal: List of internal imports
- External: List of external packages

**Architecture Notes:**
- Key design decisions
- Important patterns used
```text

---

## Self-Check

Before generating documentation:

1. **Is this already documented?** — Don't duplicate existing docs
2. **Is it self-explanatory?** — Don't over-document obvious code
3. **What level of detail?** — Match project's documentation style

---

## Actions

1. Read the target file/function
2. Analyze code structure and purpose
3. Generate documentation in appropriate format
4. Show the documentation (don't write to file unless asked)
