---
name: Laravel Expert
description: Deep expertise in Laravel - Eloquent, patterns, performance, security, testing
---

# Laravel Expert Skill

This skill provides deep Laravel expertise including Eloquent optimization, architectural patterns, security best practices, and testing strategies.

---

## 🔥 Common Pitfalls

### N+1 Query Problem

```php
// ❌ N+1 — 1 + N queries
foreach (Site::all() as $site) {
    echo $site->owner->name;
}

// ✅ Eager loading — 2 queries
foreach (Site::with('owner')->get() as $site) {
    echo $site->owner->name;
}

// ✅ Nested
Site::with(['owner', 'checks.results'])->get();

// ✅ Conditional
Site::with(['checks' => fn($q) => $q->failed()])->get();
```

### Mass Assignment

```php
// ❌ CRITICAL
protected $guarded = [];

// ❌ Sensitive fields in fillable
protected $fillable = ['name', 'email', 'is_admin'];

// ✅ Safe
protected $fillable = ['name', 'email', 'bio'];
// Use forceFill() for admin fields with explicit check
```

### Query Builder vs Eloquent

```php
// When to use Query Builder:
// - Bulk operations
// - Complex aggregations
// - Performance critical paths

DB::table('sites')
    ->where('status', 'active')
    ->update(['checked_at' => now()]);

// When to use Eloquent:
// - CRUD with relationships
// - Model events needed
// - Accessors/mutators
$site = Site::find($id);
$site->update(['status' => 'active']);
```

---

## 🏗️ Architecture Patterns

### Action Classes

```php
// app/Actions/Sites/CreateSite.php
namespace App\Actions\Sites;

use App\Models\Site;
use App\Models\User;

class CreateSite
{
    public function __construct(
        private AnalyzerService $analyzer
    ) {}

    public function execute(array $data, User $user): Site
    {
        $site = Site::create([
            ...$data,
            'owner_id' => $user->id,
            'status' => 'pending',
        ]);

        $this->analyzer->queueCheck($site);

        return $site;
    }
}
```

### Service Classes

```php
// Stateless, injected via DI
class AnalyzerService
{
    public function __construct(
        private HttpClient $http,
        private CacheManager $cache
    ) {}

    public function analyze(Site $site): AnalysisResult
    {
        $cacheKey = "analysis.{$site->id}";
        
        return $this->cache->remember(
            $cacheKey,
            now()->addHour(),
            fn() => $this->performAnalysis($site)
        );
    }

    private function performAnalysis(Site $site): AnalysisResult
    {
        $response = $this->http->get($site->url);
        return new AnalysisResult($response);
    }
}
```

### Repository Pattern (Optional)

```php
// Use when need to swap implementations or testing
interface SiteRepositoryInterface
{
    public function findActive(): Collection;
    public function create(array $data): Site;
}

class EloquentSiteRepository implements SiteRepositoryInterface
{
    public function findActive(): Collection
    {
        return Site::where('status', 'active')->get();
    }

    public function create(array $data): Site
    {
        return Site::create($data);
    }
}
```

---

## 🚀 Performance

### Database Indexing

```php
// Migration
Schema::table('sites', function (Blueprint $table) {
    $table->index('status');
    $table->index(['owner_id', 'status']);
    $table->index('created_at');
});
```

### Query Optimization

```php
// Select only needed columns
Site::select(['id', 'name', 'url'])->get();

// Use exists() instead of count()
if (Site::where('url', $url)->exists()) { }

// Chunking for large datasets
Site::chunk(100, function ($sites) {
    foreach ($sites as $site) {
        // Process
    }
});

// Cursor for memory efficiency
foreach (Site::cursor() as $site) {
    // One at a time
}
```

### Caching

```php
// Simple cache
$sites = Cache::remember("user.{$userId}.sites", 3600, function () use ($userId) {
    return Site::where('owner_id', $userId)->with('latestCheck')->get();
});

// Tagged cache (Redis only)
$sites = Cache::tags(['sites', "user.{$userId}"])
    ->remember('list', 3600, fn() => Site::all());

// Invalidate
Cache::tags(['sites'])->flush();
Cache::forget("user.{$userId}.sites");
```

---

## 🔐 Security

### Input Validation

```php
// app/Http/Requests/StoreSiteRequest.php
class StoreSiteRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'url' => ['required', 'url', 'max:2048', 'unique:sites,url'],
            'interval' => ['nullable', 'integer', 'min:1', 'max:1440'],
        ];
    }

    public function messages(): array
    {
        return [
            'url.unique' => 'This site is already being monitored.',
        ];
    }
}
```

### Authorization Policies

```php
// app/Policies/SitePolicy.php
class SitePolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, Site $site): bool
    {
        return $user->id === $site->owner_id
            || $user->hasRole('admin');
    }

    public function update(User $user, Site $site): bool
    {
        return $user->id === $site->owner_id;
    }

    public function delete(User $user, Site $site): bool
    {
        return $user->id === $site->owner_id;
    }
}

// Usage
$this->authorize('update', $site);
// or
Gate::authorize('update', $site);
```

### Rate Limiting

```php
// routes/web.php
Route::middleware(['throttle:api'])->group(function () {
    Route::post('/sites', [SiteController::class, 'store']);
});

// Custom rate limiter in AppServiceProvider
RateLimiter::for('api', function (Request $request) {
    return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
});
```

---

## 🧪 Testing Helpers

### Test Traits

```php
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;

class SiteTest extends TestCase
{
    use RefreshDatabase, WithFaker;
}
```

### Factories

```php
// database/factories/SiteFactory.php
class SiteFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => $this->faker->company(),
            'url' => $this->faker->url(),
            'status' => 'active',
            'owner_id' => User::factory(),
        ];
    }

    public function inactive(): static
    {
        return $this->state(['status' => 'inactive']);
    }
}

// Usage
Site::factory()
    ->for(User::factory(), 'owner')
    ->has(Check::factory()->count(5))
    ->create();
```

### Mocking

```php
$this->mock(AnalyzerService::class, function ($mock) {
    $mock->shouldReceive('analyze')
        ->once()
        ->with(Mockery::type(Site::class))
        ->andReturn(new AnalysisResult(['score' => 85]));
});
```
