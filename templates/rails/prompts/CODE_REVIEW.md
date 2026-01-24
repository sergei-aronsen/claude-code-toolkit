# Code Review — Laravel Template

## Goal

Comprehensive code review of a Laravel application. Act as a Senior Tech Lead.

> **⚠️ Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for code review — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | PHP Syntax | `php -l app/**/*.php` | No errors |
| 2 | Pint (style) | `./vendor/bin/pint --test` | No changes |
| 3 | PHPStan | `./vendor/bin/phpstan analyse` | Level OK |
| 4 | Build | `npm run build` | Success |
| 5 | Tests | `php artisan test` | Pass |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# code-check.sh

echo "📝 Code Quality Check..."

# 1. PHP Syntax
php -l app/**/*.php 2>&1 | grep -q "error" && echo "❌ PHP Syntax errors" || echo "✅ PHP Syntax"

# 2. Pint
./vendor/bin/pint --test > /dev/null 2>&1 && echo "✅ Pint" || echo "🟡 Pint: needs formatting"

# 3. Build
npm run build > /dev/null 2>&1 && echo "✅ Build" || echo "❌ Build failed"

# 4. God classes (>300 lines)
GOD_CLASSES=$(find app -name "*.php" -exec wc -l {} \; | awk '$1 > 300 {print $2}' | wc -l)
[ "$GOD_CLASSES" -eq 0 ] && echo "✅ No god classes" || echo "🟡 God classes: $GOD_CLASSES files >300 lines"

# 5. TODO/FIXME
TODOS=$(grep -rn "TODO\|FIXME" app/ resources/js/ --include="*.php" --include="*.vue" --include="*.js" 2>/dev/null | wc -l)
echo "ℹ️  TODO/FIXME: $TODOS comments"

# 6. dd() / dump() left in code
DD_CALLS=$(grep -rn "dd(\|dump(" app/ --include="*.php" 2>/dev/null | wc -l)
[ "$DD_CALLS" -eq 0 ] && echo "✅ No dd()/dump()" || echo "❌ dd()/dump(): $DD_CALLS calls found"

# 7. console.log in Vue
CONSOLE=$(grep -rn "console.log" resources/js/ --include="*.vue" --include="*.js" 2>/dev/null | wc -l)
[ "$CONSOLE" -lt 10 ] && echo "✅ console.log: $CONSOLE" || echo "🟡 console.log: $CONSOLE (too many)"

echo "Done!"
```text

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Accepted decisions (no need to fix):**

- [Conscious architectural decisions]

**Key files for review:**

- `app/Services/` — business logic
- `app/Http/Controllers/` — should be thin
- `resources/js/Pages/` — Inertia pages (if used)
- `app/Jobs/` — background tasks

**Project patterns:**

- FormRequest for validation
- Services for business logic
- Jobs for long operations

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Bug, security issue, data loss | **BLOCKER** — fix now |
| HIGH | Serious logic problem | Fix before merge |
| MEDIUM | Code smell, maintainability | Fix in this PR |
| LOW | Style, nice-to-have | Can be deferred |

---

## 1. SCOPE REVIEW

### 1.1 Define review scope

```bash
# Recent changes
git diff --name-only HEAD~5

# Uncommitted changes
git status --short
```text

- [ ] Which files changed
- [ ] Which new files created
- [ ] Relationship between changes

### 1.2 Categorization

- [ ] Controllers (app/Http/Controllers/*)
- [ ] Services (app/Services/*)
- [ ] Models (app/Models/*)
- [ ] Jobs (app/Jobs/*)
- [ ] Migrations (database/migrations/*)
- [ ] Config (config/*)
- [ ] Routes (routes/*)

---

## 2. ARCHITECTURE & STRUCTURE

### 2.1 Single Responsibility Principle

```php
// ❌ Bad — Controller does everything
class SiteController extends Controller
{
    public function store(Request $request)
    {
        // Validation here
        $validated = $request->validate([...]);

        // Business logic here
        $html = Http::get($validated['url'])->body();
        preg_match('/<title>(.*?)<\/title>/', $html, $matches);
        $title = $matches[1] ?? null;

        // Saving here
        $site = Site::create([...]);

        // Notification here
        Mail::to($request->user())->send(new SiteCreated($site));

        return redirect()->route('sites.show', $site);
    }
}

// ✅ Good — Controller only coordinates
class SiteController extends Controller
{
    public function store(StoreSiteRequest $request, SiteService $service)
    {
        $site = $service->create($request->validated());
        return redirect()->route('sites.show', $site);
    }
}
```text

- [ ] Controllers < 100 lines
- [ ] Controller methods < 20 lines
- [ ] Business logic in Services, not in Controllers
- [ ] Validation in FormRequest, not in Controller

### 2.2 Dependency Injection

```php
// ❌ Bad — hardcoded dependencies
class ParserService
{
    public function parse(string $url): array
    {
        $client = new GuzzleHttp\Client(); // Hardcoded
        $response = $client->get($url);
    }
}

// ✅ Good — DI via constructor
class ParserService
{
    public function __construct(
        private ClientInterface $client
    ) {}

    public function parse(string $url): array
    {
        $response = $this->client->get($url);
    }
}
```text

- [ ] Dependencies injected via constructor
- [ ] No `new ClassName()` inside methods (except DTO)
- [ ] No static service calls

### 2.3 Proper File Placement

```text
app/
├── Http/
│   ├── Controllers/        // Routing only
│   └── Requests/           // Validation
├── Services/               // Business logic
├── Models/                 // Eloquent only
├── Jobs/                   // Background tasks
├── DTOs/                   // Data Transfer Objects
└── Enums/                  // Enumerations
```text

- [ ] Files in correct directories
- [ ] No God-classes (> 300 lines)
- [ ] Logic extracted from Models

---

## 3. CODE QUALITY

### 3.1 Naming Conventions

```php
// ❌ Bad — unclear names
$d = Site::find($id);
$res = $this->proc($d);

// ✅ Good — descriptive names
$site = Site::find($siteId);
$parsedData = $this->parseContent($site);
```text

- [ ] **Variables** — nouns, camelCase: `$siteUrl`, `$parsedContent`
- [ ] **Methods** — verbs, camelCase: `getSite()`, `parseContent()`
- [ ] **Classes** — nouns, PascalCase: `SiteService`, `ParsedResult`
- [ ] **Boolean** — is/has/can/should: `$isActive`, `$hasLabels`

### 3.2 Method Length & Complexity

```php
// ❌ Bad — long method with deep nesting
public function process(array $data): array
{
    foreach ($data as $item) {
        if ($item['type'] === 'site') {
            if ($item['status'] === 'active') {
                if (!empty($item['url'])) {
                    // deep nesting...
                }
            }
        }
    }
}

// ✅ Good — split into methods, early returns
public function process(array $data): array
{
    return collect($data)
        ->filter(fn($item) => $this->shouldProcess($item))
        ->mapWithKeys(fn($item) => $this->processItem($item))
        ->filter()
        ->toArray();
}

private function shouldProcess(array $item): bool
{
    return $item['type'] === 'site'
        && $item['status'] === 'active'
        && !empty($item['url']);
}
```text

- [ ] Methods < 20 lines (ideally < 10)
- [ ] Nesting < 3 levels
- [ ] Early returns are used

### 3.3 DRY (Don't Repeat Yourself)

```php
// ❌ Bad — duplication
$active = Site::where('status', 'active')
    ->where('user_id', auth()->id())
    ->orderBy('created_at', 'desc')
    ->get();

$pending = Site::where('status', 'pending')
    ->where('user_id', auth()->id())
    ->orderBy('created_at', 'desc')
    ->get();

// ✅ Good — scope in model
class Site extends Model
{
    public function scopeForUser($query, ?User $user = null)
    {
        return $query->where('user_id', ($user ?? auth()->user())->id);
    }

    public function scopeStatus($query, string $status)
    {
        return $query->where('status', $status);
    }
}

// Usage
$active = Site::forUser()->status('active')->latest()->get();
```text

- [ ] No copy-paste code
- [ ] Repeated queries extracted to scopes

### 3.4 Type Safety

```php
// ❌ Bad — no typing
function process($data) {
    $result = [];
}

// ✅ Good — full typing
declare(strict_types=1);

public function process(array $sites, ?ParserOptions $options = null): ProcessedResult
{
}
```text

- [ ] All methods have return type
- [ ] Parameters are typed
- [ ] Nullable types explicitly specified (`?string`, `?int`)

---

## 4. LARAVEL BEST PRACTICES

### 4.1 Eloquent Usage

```php
// ❌ Bad
$site = Site::where('id', $id)->first();
$sites = Site::all()->where('status', 'active');
$count = Site::get()->count();

// ✅ Good
$site = Site::find($id);
$sites = Site::where('status', 'active')->get();
$count = Site::count();
```text

- [ ] Using `find()` instead of `where('id', $id)->first()`
- [ ] Using `findOrFail()` when record must exist
- [ ] Filtering in Query Builder, not in Collection

### 4.2 Request Validation

```php
// ❌ Bad — validation in controller
public function store(Request $request)
{
    $request->validate([
        'url' => 'required|url|max:255',
    ]);
}

// ✅ Good — FormRequest
class StoreSiteRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'url' => ['required', 'url', 'max:255'],
            'labels' => ['array'],
            'labels.*' => ['exists:labels,id'],
        ];
    }

    public function messages(): array
    {
        return [
            'url.required' => 'Site URL is required',
        ];
    }
}
```text

- [ ] Validation in FormRequest classes
- [ ] Custom error messages
- [ ] `authorize()` checks access rights

### 4.3 Config & Environment

```php
// ❌ Bad — env() in code
class ScreenshotService
{
    public function capture(string $url): string
    {
        $apiKey = env('SCREENSHOT_API_KEY'); // Breaks config:cache!
    }
}

// ✅ Good — via config
// config/services.php
'screenshot' => [
    'api_key' => env('SCREENSHOT_API_KEY'),
],

// In service
$this->apiKey = config('services.screenshot.api_key');
```text

- [ ] `env()` only in config files
- [ ] All settings via `config()`

---

## 5. ERROR HANDLING

### 5.1 Exception Handling

```php
// ❌ Bad — suppressing errors
try {
    $result = $this->parse($url);
} catch (Exception $e) {
    // Silence...
}

// ✅ Good — specific exceptions with logging
try {
    $result = $this->parser->parse($url);
} catch (ConnectionException $e) {
    Log::warning('Failed to connect', [
        'url' => $url,
        'error' => $e->getMessage()
    ]);
    throw new SiteUnreachableException($url, $e);
}
```text

- [ ] Specific exception types
- [ ] Logging with context
- [ ] No empty catch blocks

### 5.2 User-Facing Errors

```php
// ❌ Bad — technical errors to user
return response()->json([
    'error' => $e->getMessage() // "SQLSTATE[23000]..."
], 500);

// ✅ Good — clear messages
if ($e instanceof SiteUnreachableException) {
    return back()->with('error', 'Could not connect to the site.');
}
```text

- [ ] User sees clear messages
- [ ] Technical details only in logs

---

## 6. SECURITY & PERFORMANCE CHECK

### 6.1 Security Quick Check

- [ ] No SQL injection (raw queries without bindings)
- [ ] No XSS (v-html with user data, {!! !!})
- [ ] No mass assignment vulnerabilities
- [ ] Authorization is checked
- [ ] No dd()/dump() in production code

### 6.2 Performance Quick Check

- [ ] No N+1 queries
- [ ] Eager loading is used
- [ ] Pagination for lists
- [ ] Heavy operations in queue

---

## 7. SELF-CHECK

**Before adding an issue to the report:**

| Question | If "no" → don't include |
| -------- | ------------------------- |
| Does it affect **functionality** or **maintainability**? | Cosmetics are not critical |
| Will **fixing benefit** developers/users? | Refactoring for the sake of refactoring is a waste |
| Is it a **violation** of project conventions? | Check existing patterns |
| Is the **time worth** fixing? | 5 min fix vs 1 hour review |

**DO NOT include in report:**

| Seems like a problem | Why it may not be |
| ------------------- | --------------------- |
| "No comments" | Code may be self-documenting |
| "Long file" | If logically related — OK |
| "Could be better" | Without specifics not actionable |
| "Service is big" | If logic is related — OK |

---

## 8. REPORT FORMAT

```markdown
# Code Review Report — [Project Name]
Date: [date]
Scope: [which files/commits reviewed]

## Summary

| Category | Issues | Critical |
|-----------|---------|-----------|
| Architecture | X | X |
| Code Quality | X | X |
| Laravel | X | X |
| Security | X | X |
| Performance | X | X |

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|--------|----------|---------|
| 1 | SiteController.php | 45 | 200 lines of business logic | Extract to SiteService |

## Code Suggestions

### 1. SiteController — extract logic

```php
// Before (app/Http/Controllers/SiteController.php:45-120)
public function store(Request $request) {
    // 75 lines...
}

// After
public function store(StoreSiteRequest $request, SiteService $service) {
    $site = $service->create($request->validated());
    return redirect()->route('sites.show', $site);
}
```text

## Good Practices Found

- [What's good]

```text

---

## 9. ACTIONS

1. **Run Quick Check** — 5 minutes
2. **Define scope** — which files to check
3. **Go through categories** — Architecture, Code Quality, Laravel
4. **Self-check** — filter out false positives
5. **Prioritize** — Critical → High → Medium
6. **Show fixes** — specific code before/after

Start code review. Show scope and summary first.
