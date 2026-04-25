# Performance Audit — Laravel Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

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

## 6. SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

## Procedure

For every candidate finding, execute these six steps in order. Produce a `## SELF-CHECK` block per finding (in your scratchpad — not the final report) before deciding whether to report or drop it. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow user input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look exploitable in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the threat surface (e.g. an upstream sanitizer documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, etc.), the finding is a design trade-off, not a vulnerability. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual exploit scenario, not the rule label. A theoretical XSS sink behind 3 unlikely preconditions and no PII is not CRITICAL. If you cannot describe a concrete attack path the user would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

## Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `lib/utils.py:5` | `SEC-EVAL` | 5 | `eval is required by build-time codegen; never reached at runtime` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

## When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

## Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not exploit-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op (record `cross-ref skipped: no allowlist file present`) but the step itself MUST be acknowledged in the SELF-CHECK trace.

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

## 7. OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->

## Report Path

```text
.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md
```

- `<type>` is one of the 7 canonical slugs documented in the next section. Backward-compat aliases resolve to a canonical slug at dispatch time.
- Timestamp is local time, generated with `date '+%Y-%m-%d-%H%M'` (24-hour, no separator between hour and minute).
- The audit creates the directory with `mkdir -p .claude/audits` on first write.
- The toolkit does NOT auto-add `.claude/audits/` to `.gitignore` — let the user decide which audit reports to commit.

---

## Type Slug to Prompt File Map

| `/audit` argument | Report filename slug | Prompt loaded |
|-------------------|----------------------|---------------|
| `security` | `security` | `templates/<framework>/prompts/SECURITY_AUDIT.md` |
| `code-review` | `code-review` | `templates/<framework>/prompts/CODE_REVIEW.md` |
| `performance` | `performance` | `templates/<framework>/prompts/PERFORMANCE_AUDIT.md` |
| `deploy-checklist` | `deploy-checklist` | `templates/<framework>/prompts/DEPLOY_CHECKLIST.md` |
| `mysql-performance` | `mysql-performance` | `templates/<framework>/prompts/MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres-performance` | `postgres-performance` | `templates/<framework>/prompts/POSTGRES_PERFORMANCE_AUDIT.md` |
| `design-review` | `design-review` | `templates/<framework>/prompts/DESIGN_REVIEW.md` |

Backward-compat aliases: `code` resolves to `code-review` and `deploy` resolves to `deploy-checklist` at dispatch time. The report filename ALWAYS uses the canonical slug, never the alias.

---

## YAML Frontmatter

Every report opens with a YAML frontmatter block containing exactly these 7 keys:

```yaml
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 3
skipped_allowlist: 1
skipped_fp_recheck: 2
council_pass: pending
---
```

- `audit_type` — one of the 7 canonical slugs from the type map.
- `timestamp` — quoted `YYYY-MM-DD-HHMM` (the same string used in the report filename).
- `commit_sha` — `git rev-parse --short HEAD` output, or the literal string `none` when the project is not a git repo.
- `total_findings` — integer count of entries in the `## Findings` section.
- `skipped_allowlist` — integer count of rows in the `## Skipped (allowlist)` table.
- `skipped_fp_recheck` — integer count of rows in the `## Skipped (FP recheck)` table.
- `council_pass` — starts at `pending`. Phase 15's `/council audit-review` mutates this to `passed`, `failed`, or `disputed` after collating per-finding verdicts.

---

## Section Order (Fixed)

After the YAML frontmatter, the report MUST contain these five H2 sections in this exact order:

1. `## Summary`
2. `## Findings`
3. `## Skipped (allowlist)`
4. `## Skipped (FP recheck)`
5. `## Council verdict`

Plus the report's title H1 (`# <Type Title> Audit — <project name>`) immediately after the closing `---` of the frontmatter and before `## Summary`.

Do NOT reorder. Do NOT introduce intermediate H2 sections. Render an empty section as the literal placeholder `_None_` — the allowlist case uses a longer placeholder shown verbatim in the Skipped (allowlist) section below. Phase 15 navigates by these literal H2 headings.

---

## Summary Section

The Summary table has columns `severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck`, with one row per severity (CRITICAL, HIGH, MEDIUM, LOW). The rubric is in `components/severity-levels.md` — do not redefine. INFO is NOT a reportable finding severity; informational observations belong in the audit's scratchpad, never in `## Findings`. See the Full Report Skeleton below for the verbatim layout.

---

## Finding Entry Schema (### Finding F-NNN)

Each surviving finding becomes an `### Finding F-NNN` H3 block. `F-NNN` is zero-padded to 3 digits and sequential per report (`F-001`, `F-002`, ...). The 9 fields appear in this exact order:

1. **ID** — the `F-NNN` identifier matching the H3 heading.
2. **Severity** — one of CRITICAL, HIGH, MEDIUM, LOW (per `components/severity-levels.md`).
3. **Rule** — the auditor's rule-id (e.g. `SEC-SQL-INJECTION`, `PERF-N+1`).
4. **Location** — `<path>:<start>-<end>` for a range, or `<path>:<line>` for a single point.
5. **Claim** — one-sentence statement of the alleged issue, ≤ 160 chars.
6. **Code** — verbatim ±10 lines around the flagged line, fenced with the language matching the source extension (see Verbatim Code Block section).
7. **Data flow** — markdown bullet list tracing input from origin to the flagged sink, ≤ 6 hops.
8. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from in Phase 15.
9. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

See the Full Report Skeleton below for the verbatim entry template (a SQL-INJECTION example demonstrating all 9 fields).

The bullet labels (`**Severity:**`, `**Rule:**`, `**Location:**`, `**Claim:**`) and section labels (`**Code:**`, `**Data flow:**`, `**Why it is real:**`, `**Suggested fix:**`) are byte-exact — Phase 15's Council parser navigates the entry by them.

---

## Verbatim Code Block (AUDIT-03)

### Layout

```text
<!-- File: <path> Lines: <start>-<end> -->
[optional clamp note]
[fenced code block here with <lang> from the Extension Map]
```

`<lang>` is the language fence selected per the Extension to Language Fence Map below. `start = max(1, L - 10)` and `end = min(T, L + 10)` where `L` is the flagged line and `T` is the total line count of the file. The HTML range comment is the FIRST line above the fence; the clamp note (when present) is the SECOND line above the fence.

### Clamp Behaviour

When the ±10 range is clipped by the start or end of the file, emit a `<!-- Range clamped to file bounds (start-end) -->` note immediately above the fenced block. Example: flagged line 5 in an 8-line file → `start = max(1, 5-10) = 1`, `end = min(8, 5+10) = 8`, rendered range `1-8`, clamp note required.

### Extension to Language Fence Map

| Extension(s) | Fence |
|--------------|-------|
| `.ts`, `.tsx` | `ts` (or `tsx` for JSX-bearing files) |
| `.js`, `.jsx`, `.mjs`, `.cjs` | `js` |
| `.py` | `python` |
| `.sh`, `.bash`, `.zsh` | `bash` |
| `.rb` | `ruby` |
| `.go` | `go` |
| `.php` | `php` |
| `.md` | `markdown` |
| `.yml`, `.yaml` | `yaml` |
| `.json` | `json` |
| `.toml` | `toml` |
| `.html`, `.htm` | `html` |
| `.css`, `.scss`, `.sass` | `css` |
| `.sql` | `sql` |
| `.rs` | `rust` |
| `.java` | `java` |
| `.kt`, `.kts` | `kotlin` |
| `.swift` | `swift` |
| *unknown* | `text` |

The code block MUST be verbatim — no ellipses, no redaction, no `// ... rest of function` cuts. Council reasons from the actual code, not a paraphrase.

---

## Skipped (allowlist) Section

Columns: `ID | path:line | rule | council_status`. Empty-state placeholder is the literal string `_None — no` followed by a backtick-quoted `audit-exceptions.md` reference and `in this project_`. The verbatim layout is in the Full Report Skeleton below.

`council_status` is parsed from the matching entry's `**Council:**` bullet inside `audit-exceptions.md`. Allowed values: `unreviewed`, `council_confirmed_fp`, `disputed`. Use `sed '/^<!--/,/^-->/d'` (per `commands/audit-restore.md` post-13-05 fix) to strip HTML comment blocks before walking entries — the seed file ships with an HTML-commented example heading that would otherwise produce false matches. The `F-A001`..`F-ANNN` numbering is independent of `F-NNN` for surviving findings.

---

## Skipped (FP recheck) Section

Columns: `path:line | rule | dropped_at_step | one_line_reason`. Empty-state placeholder: `_None_`. The verbatim layout is in the Full Report Skeleton below.

`dropped_at_step` MUST be an integer in 1-6 matching the FP-recheck step where the finding was dropped (see `components/audit-fp-recheck.md`). `one_line_reason` MUST be ≤ 100 chars and reference concrete tokens visible in the source — never `looks fine`, `trusted code`, or `out of scope`.

---

## Council Verdict Slot (handoff to Phase 15)

The audit writes this section as a literal placeholder. Phase 15's `/council audit-review` mutates it in place after collating Gemini + ChatGPT verdicts.

```markdown
## Council verdict

_pending — run /council audit-review_
```

Byte-exact constraints: U+2014 em-dash (literal `—`, not hyphen-minus, not en-dash); single-underscore italic (`_..._`), no asterisks; no backticks, no bold, no code fence, no trailing whitespace. DO NOT REFORMAT — Phase 15 greps for this exact byte sequence to locate the slot before rewriting it.

---

## Full Report Skeleton

<output_format>

```text
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 1
skipped_allowlist: 1
skipped_fp_recheck: 1
council_pass: pending
---

# Security Audit — claude-code-toolkit

## Summary

| severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck |
|----------|----------------|-------------------------|--------------------------|
| HIGH | 1 | 1 | 1 |

## Findings

### Finding F-001

- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/users.ts:42
- **Claim:** User-supplied id flows into a string-concatenated SQL query without parameterization.

**Code:**

[fenced code block here — verbatim ±10 lines around src/users.ts:42, ts language fence]

**Data flow:**

- `req.params.id` arrives from the HTTP route handler.
- Passed unchanged into `db.query()`.
- No parameterized binding between origin and sink.

**Why it is real:**

The literal `db.query("SELECT * FROM users WHERE id=" + req.params.id)` concatenates an Express request parameter directly into the SQL string. The route is public, so an attacker can supply a malicious id and reach the sink unauthenticated.

**Suggested fix:**

[fenced code block here — replacement using parameterized query]

## Skipped (allowlist)

| ID | path:line | rule | council_status |
|----|-----------|------|----------------|
| F-A001 | lib/utils.py:5 | SEC-EVAL | unreviewed |

## Skipped (FP recheck)

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| src/legacy.js:14 | SEC-EVAL | 3 | eval guarded by isBuildTime(); never reached at runtime |

## Council verdict

_pending — run /council audit-review_
```

</output_format>

1. **Run Quick Check** — 5 minutes
2. **Scan the project** — collect all issues
3. **Self-check** — filter out false positives
4. **Prioritize** — critical, important, recommendations
5. **Measure** — if possible, indicate impact
6. **Suggest** — specific fixes with code

Start the audit. First show a summary of found issues.

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
