# Performance Audit — Laravel Template

## Goal

Comprehensive performance audit of a Laravel application. Act as a Senior Performance Engineer.

> **⚠️ Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for audits — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Build | `npm run build` | Success, no warnings |
| 2 | N+1 queries | `grep -rn "->each\|->map" app/Http/Controllers/ \| grep -v "with("` | Minimum |
| 3 | Model::all() | `grep -rn "::all()" app/Http/Controllers/` | Empty or with pagination |
| 4 | Missing indexes | `grep -rn "where(" app/Http/Controllers/ \| grep -v "index"` | Check indexes |
| 5 | Job timeouts | `grep -rn "ShouldQueue" app/Jobs/ \| xargs -I{} grep -L "timeout" {}` | Empty |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# performance-check.sh

echo "⚡ Performance Quick Check..."

# 1. Build test
npm run build > /tmp/build.log 2>&1
[ $? -eq 0 ] && echo "✅ Build: Success" || echo "❌ Build: Failed"

# 2. N+1 patterns
N_PLUS_1=$(grep -rn "\->each\|->map" app/Http/Controllers/ 2>/dev/null | grep -v "with(" | wc -l)
[ "$N_PLUS_1" -eq 0 ] && echo "✅ N+1: No obvious patterns" || echo "🟡 N+1: Found $N_PLUS_1 potential N+1"

# 3. Model::all() without pagination
ALL_CALLS=$(grep -rn "::all()" app/Http/Controllers/ 2>/dev/null | wc -l)
[ "$ALL_CALLS" -eq 0 ] && echo "✅ all(): No Model::all() in controllers" || echo "❌ all(): Found $ALL_CALLS Model::all() calls"

# 4. Jobs without timeout
JOBS_NO_TIMEOUT=$(find app/Jobs -name "*.php" -exec grep -L 'timeout' {} \; 2>/dev/null | wc -l)
[ "$JOBS_NO_TIMEOUT" -eq 0 ] && echo "✅ Jobs: All jobs have timeout" || echo "🟡 Jobs: $JOBS_NO_TIMEOUT jobs without timeout"

# 5. Missing eager loading in controllers
MISSING_EAGER=$(grep -rn "->get()\|->first()\|->find(" app/Http/Controllers/ 2>/dev/null | grep -v "with(" | wc -l)
echo "ℹ️  Queries without with(): $MISSING_EAGER (check if needed)"

# 6. Config cache status
php artisan config:cache --dry-run 2>/dev/null
[ $? -eq 0 ] && echo "✅ Config: Cacheable" || echo "❌ Config: env() outside config files"

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**What is already optimized:**

- [ ] MySQL connection pooling (Laravel default)
- [ ] Redis for queues and cache
- [ ] Supervisor for queue workers
- [ ] Vite for frontend build

**Commands for analysis:**

```bash
# Bundle analysis
npx vite-bundle-visualizer

# Cache status
php artisan cache:status
```

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | N+1 on main pages, memory leaks | Fix immediately |
| HIGH | Missing indexes, jobs without timeout | Fix before deploy |
| MEDIUM | Suboptimal queries, large bundle | Next sprint |
| LOW | Micro-optimizations | Backlog |

---

## 1. DATABASE PERFORMANCE

### 1.1 N+1 Query Detection

```php
// ❌ N+1 — query in each iteration
@foreach($sites as $site)
    {{ $site->labels->count() }}  // SELECT * FROM labels WHERE site_id = ?
@endforeach

// ✅ Correct — eager loading
$sites = Site::with('labels')->get();
// or with count
$sites = Site::withCount('labels')->get();
```

- [ ] All `@foreach` accessing relations
- [ ] All `->map()`, `->each()` accessing relations
- [ ] Nested loops with DB queries

### 1.2 Missing Indexes

Check indexes on:

- [ ] **Foreign keys** — all `*_id` fields
- [ ] **WHERE fields** — `status`, `type`, `is_active`, `created_at`
- [ ] **ORDER BY fields** — `created_at`, `updated_at`, `sort_order`
- [ ] **Unique fields** — `email`, `url`, `slug`
- [ ] **Composite indexes** — for frequent WHERE combinations

```php
// Example migration with proper indexes
Schema::create('sites', function (Blueprint $table) {
    $table->id();
    $table->string('url')->index();                    // Frequently searched
    $table->string('status')->index();                 // Filtered
    $table->foreignId('import_id')->constrained()->index(); // FK
    $table->timestamps();

    // Composite index for frequent query
    $table->index(['status', 'created_at']);
});
```

### 1.3 Query Optimization

```php
// ❌ Bad — loads everything
$sites = Site::all();

// ✅ Good — only needed fields + pagination
$sites = Site::select(['id', 'url', 'title', 'status'])
    ->paginate(50);

// ❌ Bad — counting via collection
$count = Site::all()->count();

// ✅ Good — counting at DB level
$count = Site::count();

// ❌ Bad — filtering in PHP
$active = Site::all()->filter(fn($s) => $s->status === 'active');

// ✅ Good — filtering in SQL
$active = Site::where('status', 'active')->get();
```

- [ ] No `Model::all()` for tables > 100 records
- [ ] No `->get()` without `->select()` for large tables
- [ ] No processing in PHP what can be done in SQL

### 1.4 Pagination

- [ ] All lists > 50 records use `->paginate()` or `->cursorPaginate()`
- [ ] API endpoints return paginated data

---

## 2. LARAVEL OPTIMIZATION

### 2.1 Caching Strategy

```php
// ❌ Bad — query on every access
$settings = Setting::all();

// ✅ Good — caching
$settings = Cache::remember('settings', 3600, function () {
    return Setting::all();
});
```

- [ ] Static data is cached (settings, dictionaries)
- [ ] Heavy computations are cached
- [ ] Dashboard statistics are cached

### 2.2 Default Eager Loading

```php
class Site extends Model
{
    // Automatically load relations
    protected $with = ['labels', 'import'];
}
```

- [ ] Frequently used relations in `$with`
- [ ] No redundant relations in `$with`

### 2.3 Config & Route Caching

```bash
php artisan config:cache   # Config cache
php artisan route:cache    # Route cache
php artisan view:cache     # View cache
php artisan event:cache    # Event cache
composer dump-autoload -o  # Autoload optimization
```

- [ ] Commands added to deploy script
- [ ] No `env()` calls outside config files (breaks config:cache)

---

## 3. QUEUE & JOBS OPTIMIZATION

### 3.1 Job Configuration

```php
class ParseSiteJob implements ShouldQueue
{
    public $timeout = 120;           // ✅ Required
    public $tries = 3;               // ✅ Required
    public $backoff = [60, 120, 300]; // ✅ Exponential backoff
    public $maxExceptions = 3;       // ✅ Exception limit

    // ✅ Uniqueness — don't duplicate identical jobs
    public function uniqueId(): string
    {
        return $this->site->id;
    }

    // ✅ Failed handling
    public function failed(Throwable $exception): void
    {
        Log::error('Job failed', [
            'site_id' => $this->site->id,
            'error' => $exception->getMessage()
        ]);
    }
}
```

- [ ] All jobs have `$timeout`
- [ ] All jobs have `$tries` and `$backoff`
- [ ] All jobs have `failed()` method
- [ ] Long jobs use `$uniqueId` against duplication

### 3.2 Batch Processing

```php
// ❌ Bad — creates 10000 jobs at once
Site::where('status', 'pending')->each(function ($site) {
    ParseSiteJob::dispatch($site);
});

// ✅ Good — chunk dispatch
Site::where('status', 'pending')
    ->chunk(100, function ($sites) {
        foreach ($sites as $site) {
            ParseSiteJob::dispatch($site)->delay(now()->addSeconds(rand(1, 60)));
        }
    });
```

- [ ] Bulk operations use `chunk()`
- [ ] There is delay between jobs for rate limiting

### 3.3 Queue Memory Leaks

```php
// ❌ Memory leak — model in memory the whole time
class ParseSiteJob implements ShouldQueue
{
    public function __construct(public Site $site) {}
}

// ✅ Better — only ID, load on execution
class ParseSiteJob implements ShouldQueue
{
    public function __construct(public int $siteId) {}

    public function handle(ParserService $parser): void
    {
        $site = Site::find($this->siteId);
        if (!$site) return;

        $parser->parse($site);
    }
}
```

- [ ] Jobs store only ID, not entire models

---

## 4. HTTP & EXTERNAL API OPTIMIZATION

### 4.1 HTTP Client Configuration

```php
// ❌ Bad — no timeout, can hang forever
$response = Http::get($url);

// ✅ Good — full configuration
$response = Http::timeout(30)
    ->connectTimeout(10)
    ->retry(3, 100, function ($exception, $request) {
        return $exception instanceof ConnectionException;
    })
    ->get($url);
```

- [ ] All external requests have `timeout()`
- [ ] There is `retry()` with reasonable logic
- [ ] There is `connectTimeout()` separate from general timeout

### 4.2 Concurrent Requests

```php
// ❌ Bad — sequential
foreach ($urls as $url) {
    $responses[] = Http::get($url);
}

// ✅ Good — parallel
$responses = Http::pool(fn (Pool $pool) =>
    collect($urls)->map(fn ($url) =>
        $pool->timeout(30)->get($url)
    )
);
```

- [ ] Where possible — parallel requests are used

---

## 5. FRONTEND OPTIMIZATION

### 5.1 Inertia.js Optimization (if used)

```php
// ❌ Bad — passing everything
return Inertia::render('Sites/Index', [
    'sites' => Site::with('labels', 'import', 'screenshots')->get()
]);

// ✅ Good — only needed data
return Inertia::render('Sites/Index', [
    'sites' => Site::select(['id', 'url', 'title', 'status'])
        ->with('labels:id,name,site_id')
        ->paginate(50)
]);

// ✅ Lazy loading props
return Inertia::render('Sites/Show', [
    'site' => $site,
    'statistics' => Inertia::lazy(fn () => $this->getStatistics($site))
]);
```

- [ ] Props contain only necessary data
- [ ] `Inertia::lazy()` is used for heavy data
- [ ] Relations are loaded with `select()` of needed fields

### 5.2 Bundle Size

- [ ] JavaScript < 500KB gzipped
- [ ] CSS < 100KB gzipped
- [ ] Code splitting is used
- [ ] Heavy components are lazy loaded

---

## 6. SELF-CHECK

**Before adding an issue to the report:**

| Question | If "no" → exclude from report |
| -------- | ---------------------------------- |
| Does it affect **runtime**? | If only deploy time — not critical |
| **Eager loading** already exists in model `$with`? | Check model before N+1 |
| Is it **actually used** in production paths? | Dev-only code doesn't matter |
| Do I have **measurable data** about the impact? | "Might be slow" ≠ problem |
| Will the **fix** have a noticeable effect? | Micro-optimizations < 50ms are not needed |

---

## 7. REPORT FORMAT

```markdown
# Performance Audit Report — [Project Name]
Date: [date]

## Summary

| Metric | Before | After | Improvement |
|---------|-----|-------|-----------|
| Avg page load | Xms | Xms | X% |
| DB queries per page | X | X | X% |
| Bundle size | XKB | XKB | X% |

## CRITICAL Issues

| # | Issue | File:line | Impact | Solution |
|---|----------|-------------|---------|---------|
| 1 | N+1 in SiteController@index | app/.../SiteController.php:45 | ~500ms | Add `with('labels')` |

## HIGH — N+1 Queries found

| Controller | Method | Relation | Solution |
|------------|--------|-------|---------|
| SiteController | index | labels | `Site::with('labels')` |

## MEDIUM — Missing indexes

| Table | Field | Query type | Migration |
|---------|------|-------------|----------|
| sites | status | WHERE | `$table->index('status')` |
```

---

## 8. ACTIONS

1. **Run Quick Check** — 5 minutes
2. **Scan the project** — collect all issues
3. **Self-check** — filter out false positives
4. **Prioritize** — critical, important, recommendations
5. **Measure** — if possible, indicate impact
6. **Suggest** — specific fixes with code

Start the audit. First show a summary of found issues.
