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
| 6 | Model event N+1 | `grep -A5 "static::deleting" app/Models/ \| grep "each"` | Empty |
| 7 | whereHas chains | `grep -rn "whereHas" app/Http/Controllers/` | < 10 |
| 8 | Frontend polling | `grep -rn "setInterval\|usePoll" resources/js/` | Endpoints cached |

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

# 7. whereHas chains in controllers
WHERE_HAS=$(grep -rn "whereHas" app/Http/Controllers/ 2>/dev/null | wc -l)
[ "$WHERE_HAS" -gt 10 ] && echo "🟡 Eloquent: Found $WHERE_HAS whereHas calls in controllers (check for performance)" || echo "✅ whereHas: $WHERE_HAS (OK)"

# 8. Unsafe model events (N+1 on delete/update)
MODEL_EVENTS=$(grep -rn "static::deleting\|static::updating" app/Models/ 2>/dev/null | wc -l)
MODEL_EACH=$(grep -A5 "static::deleting\|static::updating" app/Models/ 2>/dev/null | grep -c "each\|->map")
[ "$MODEL_EACH" -gt 0 ] && echo "❌ Models: Found N+1 patterns in model events!" || echo "✅ Model events: $MODEL_EVENTS events, no N+1 patterns"

# 9. Frontend polling
POLLING=$(grep -rn "setInterval\|usePoll" resources/js/ 2>/dev/null | wc -l)
[ "$POLLING" -gt 0 ] && echo "ℹ️  Frontend: Found $POLLING polling patterns. Verify backend endpoints are cached." || echo "✅ Polling: None found"

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

### 1.5 Model Events and Observers

Model events (`deleting`, `updating`, `created`) are silent N+1 killers during bulk operations.

```bash
# Find all model events
grep -rn "static::deleting\|static::updating\|static::created" app/Models/
grep -rn "class .*Observer" app/Observers/
```

```php
// ❌ CRITICAL — N+1 on delete (1 query per related record)
static::deleting(function ($site) {
    $site->checks->each->delete();
});

// ✅ Bulk query — single DELETE statement
static::deleting(function ($site) {
    $site->checks()->delete();
});
```

- [ ] `deleting` events do not use `each()` or per-record loops
- [ ] `created`/`updated` events do not make synchronous API calls or notifications
- [ ] Observers do not trigger cascading queries

### 1.6 Complex Eloquent Chains (whereHas)

`whereHas` generates `EXISTS (SELECT ...)` subqueries. Multiple chained `whereHas` calls create exponentially heavier queries.

```bash
# Find complex chains
grep -rn "whereHas\|whereDoesntHave" app/
```

```php
// ❌ Heavy — 3 EXISTS subqueries
Site::whereHas('lastCheck', fn($q) => $q->where('status', 'alive'))
    ->whereHas('user', fn($q) => $q->where('active', true))
    ->whereDoesntHave('labels')
    ->get();

// ✅ Better — JOIN for belongsTo/hasOne relations
Site::join('site_checks', 'sites.last_check_id', '=', 'site_checks.id')
    ->where('site_checks.status', 'alive')
    ->get();
```

- [ ] Replace `whereHas` with `join` where possible (especially belongsTo/hasOne)
- [ ] No `whereHas` inside loops or polling endpoints
- [ ] Chains of 3+ `whereHas` are refactored or cached

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

### 2.4 env() Outside Config Files

`env()` returns `null` when config is cached. This silently breaks features in production.

```bash
# Find env() calls outside config/
grep -rn "env(" app/ routes/ --include="*.php"
```

```php
// ❌ CRITICAL — returns null when config is cached
class SomeService
{
    public function call()
    {
        $key = env('API_KEY'); // null in production!
    }
}

// ✅ Always use config()
// config/services.php:
'api_key' => env('API_KEY'),

// In code:
$key = config('services.api_key');
```

- [ ] Zero `env()` calls in `app/`, `routes/`, `resources/`
- [ ] All `env()` calls only in `config/*.php`

### 2.5 Collection vs Query Builder

Fetching all records then filtering in PHP wastes memory and DB bandwidth.

```php
// ❌ BAD — loads all users into memory, then filters
$admins = User::all()->where('role', 'admin');
$count = User::all()->count();
$emails = User::all()->pluck('email')->unique();

// ✅ GOOD — filtering at database level
$admins = User::where('role', 'admin')->get();
$count = User::count();
$emails = User::distinct()->pluck('email');
```

- [ ] No `Model::all()->where()` — use `Model::where()->get()`
- [ ] No `Model::all()->count()` — use `Model::count()`
- [ ] No `->get()->filter()` — use `->where()->get()`
- [ ] No `->get()->sortBy()` — use `->orderBy()->get()`

---

### 2.6 Production Infrastructure

#### OPcache

PHP without OPcache is 3-5x slower. Must be enabled in production.

```bash
php -m | grep -i opcache
php -r "var_dump(opcache_get_status()['opcache_enabled']);"
```

```ini
; php.ini
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0     ; Production only! Requires restart on deploy
```

- [ ] OPcache enabled in production
- [ ] `validate_timestamps=0` in production (restart/clear on deploy)

#### Xdebug

Xdebug in production slows everything 2-3x even when not actively debugging.

```bash
php -m | grep -i xdebug
```

- [ ] Xdebug NOT loaded in production (`php -m` should not list it)

#### Drivers

```bash
php artisan tinker --execute="
echo 'Cache: ' . config('cache.default') . PHP_EOL;
echo 'Session: ' . config('session.driver') . PHP_EOL;
echo 'Queue: ' . config('queue.default') . PHP_EOL;
echo 'Log: ' . config('logging.default') . PHP_EOL;
"
```

| Driver | Bad | Good |
| ------ | --- | ---- |
| Cache | `file`, `database` | `redis`, `memcached` |
| Session | `file` | `redis`, `database` |
| Queue | `sync` | `redis`, `database`, `sqs` |
| Log level | `debug` | `warning` or `error` |

- [ ] Cache driver is `redis` (not `file`)
- [ ] Session driver is `redis` or `database` (not `file`)
- [ ] Queue driver is `redis` (not `sync`)
- [ ] `LOG_LEVEL` is `warning` or `error` in production (not `debug`)

#### Redis Health

```bash
redis-cli info stats | grep -E "keyspace_hits|keyspace_misses"
redis-cli info memory | grep -E "used_memory_human|maxmemory_policy"
```

| Metric | Warning | Action |
| ------ | ------- | ------ |
| Hit ratio < 80% | Keys expire too fast | Increase TTL or memory |
| `maxmemory-policy` = `noeviction` | Redis crashes when full | Set `allkeys-lru` |
| `used_memory` near `maxmemory` | Evictions starting | Increase maxmemory |

- [ ] Redis cache hit ratio > 80%
- [ ] `maxmemory-policy` = `allkeys-lru` (not `noeviction`)

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

### 3.4 Queue Payload Size

Job arguments are serialized into the queue backend. Passing large data bloats Redis/DB and slows queue processing.

```php
// ❌ CRITICAL — raw HTML stored in Redis payload
ParseSiteJob::dispatch($site, $htmlContent);

// ✅ Store data externally, pass only a reference
Cache::put("site_html:{$site->id}", $htmlContent, 300);
ParseSiteJob::dispatch($site->id);
```

- [ ] Job constructors do not accept raw HTML, file content, or Base64 strings
- [ ] Large data is stored in Cache/Storage, job receives ID or cache key
- [ ] Check `failed_jobs` table for oversized payloads: `SELECT id, LENGTH(payload) FROM failed_jobs ORDER BY LENGTH(payload) DESC LIMIT 10`

---

### 3.5 Non-Queued Notifications

Synchronous mail/SMS blocks the HTTP request. User waits while SMTP connects.

```bash
# Find notifications not using ShouldQueue
grep -rL "ShouldQueue" app/Notifications/ 2>/dev/null
```

```php
// ❌ BAD — blocks request for 2-5 seconds
class OrderConfirmation extends Notification
{
    // No ShouldQueue = synchronous!
}

// ✅ GOOD — queued
class OrderConfirmation extends Notification implements ShouldQueue
{
    use Queueable;
}
```

- [ ] All Notifications implement `ShouldQueue`
- [ ] All Mailables implement `ShouldQueue` (or dispatched via queue)
- [ ] Exception: only critical security notifications (password reset) may be synchronous

### 3.6 Job Idempotency

Jobs may be retried on failure. A non-idempotent job can corrupt data when executed more than once.

```php
// ❌ Dangerous — not idempotent
class IncrementViewsJob implements ShouldQueue
{
    public function handle(): void
    {
        $site = Site::find($this->siteId);
        $site->increment('views'); // Double-counted on retry!
    }
}

// ✅ Safe — idempotent with ShouldBeUnique + state check
class ProcessSiteJob implements ShouldQueue, ShouldBeUnique
{
    public function handle(): void
    {
        $site = Site::find($this->siteId);
        if ($site->status === 'processed') {
            return; // Already done
        }
        DB::transaction(function () use ($site) {
            $site->update(['status' => 'processed']);
            // ... other operations
        });
    }

    public function uniqueId(): string
    {
        return (string) $this->siteId;
    }
}
```

- [ ] Jobs produce the same result when executed multiple times
- [ ] State-changing jobs check current state before modifying
- [ ] Long-running jobs implement `ShouldBeUnique`
- [ ] External API calls use idempotency keys where supported
- [ ] Database operations wrapped in transactions

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

### 5.3 Frontend Polling

Frequent polling from frontend can overwhelm the backend even with "simple" endpoints.

```bash
# Find polling intervals
grep -rn "setInterval\|usePoll\|polling" resources/js/
```

- [ ] Endpoints called at intervals < 30s respond in < 50ms
- [ ] Polling endpoints use `Cache::remember()` or Redis, not raw DB aggregations
- [ ] Polling intervals are reasonable (no sub-second polling for non-critical data)
- [ ] Consider WebSockets/SSE for real-time data instead of polling

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
