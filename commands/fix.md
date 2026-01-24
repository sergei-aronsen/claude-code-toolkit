# /fix — Fix Found Issue

## Purpose

Fix a specific issue found during audit or code review.

---

## Usage

```text
/fix <issue-reference>
```text

**Examples:**

- `/fix SQL injection in UserController:45`
- `/fix N+1 query in ProjectService`
- `/fix missing auth check on /api/admin`

---

## Workflow

### 1. Understand the Issue

- What is the vulnerability/problem?
- Where exactly is it? (file:line)
- What's the impact?

### 2. Analyze Context

- Read surrounding code
- Understand the intent
- Check for related code

### 3. Implement Fix

- Minimal change principle
- Don't break existing functionality
- Follow project patterns

### 4. Verify Fix

- Does it solve the problem?
- Does it introduce new issues?
- Are there similar issues elsewhere?

---

## Fix Templates

### SQL Injection

```php
// Before (vulnerable)
DB::select("SELECT * FROM users WHERE id = " . $request->id);

// After (safe)
DB::select("SELECT * FROM users WHERE id = ?", [$request->id]);
```text

### XSS

```tsx
// Before (vulnerable)
<div dangerouslySetInnerHTML={{__html: userInput}} />

// After (safe)
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{__html: DOMPurify.sanitize(userInput)}} />
```text

### Missing Auth

```typescript
// Before (unprotected)
export async function POST(request: Request) {
  const data = await request.json();
  // ...
}

// After (protected)
import { getServerSession } from 'next-auth';

export async function POST(request: Request) {
  const session = await getServerSession(authOptions);
  if (!session) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }
  const data = await request.json();
  // ...
}
```text

### N+1 Query

```php
// Before (N+1)
$users = User::all();
foreach ($users as $user) {
    echo $user->posts->count(); // N queries!
}

// After (eager loading)
$users = User::with('posts')->get();
foreach ($users as $user) {
    echo $user->posts->count(); // 0 additional queries
}
```text

---

## Output Format

```markdown
## Fix Applied

**Issue:** [description]
**File:** [file:line]
**Severity:** [CRITICAL/HIGH/MEDIUM/LOW]

### Changes Made

\`\`\`diff
- old code
+ new code
\`\`\`

### Verification
- [ ] Issue is resolved
- [ ] No new issues introduced
- [ ] Tests pass (if applicable)

### Related
- Similar issues to check: [list if any]
```text

---

## Actions

1. Read the issue description
2. Locate the problematic code
3. Understand the context
4. Implement the minimal fix
5. Show the diff
6. Suggest verification steps
