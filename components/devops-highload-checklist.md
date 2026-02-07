# DevOps Checklist: Laravel + Redis + Playwright (Highload)

Checklist for production systems with parsing, screenshots, and heavy workers.

---

## Critical Settings

### 1. Redis Memory Policy

**Problem:** `allkeys-lru` will delete tasks from the queue when memory is low — silently, without errors.

**Solution:**

```bash
# For queues — NEVER use allkeys-lru!
redis-cli CONFIG SET maxmemory 2gb
redis-cli CONFIG SET maxmemory-policy noeviction  # Better to get error than lose data
redis-cli CONFIG REWRITE

# Or separate Redis: one for cache (allkeys-lru), another for queues (noeviction)
```

| Policy | Use for | Behavior on overflow |
| ------ | ------- | -------------------- |
| `noeviction` | Queues | Write error (data preserved) |
| `volatile-lru` | Sessions | Deletes only keys with TTL |
| `allkeys-lru` | Cache | Deletes any "old" keys |

**Ideal setup:** Two Redis instances:

- `redis:6379` — queues (`noeviction`)
- `redis:6380` — cache (`allkeys-lru`)

---

### 2. Worker Self-Healing (Memory Leak Protection)

**Problem:** PHP accumulates memory, workers get "fat" and crash.

**Solution:** Use built-in Laravel flags:

```ini
# /etc/supervisor/conf.d/workers.conf

[program:main-worker]
command=php /var/www/app/artisan queue:work redis \
    --sleep=3 \
    --tries=3 \
    --timeout=120 \
    --max-jobs=100 \      # Restart after 100 jobs
    --max-time=3600 \     # Restart every hour
    --queue=default,parsing
```

| Flag | Value | Description |
| ---- | ----- | ----------- |
| `--max-jobs=N` | 50-200 | Restart after N jobs (reset leaks) |
| `--max-time=N` | 1800-3600 | Hard restart after N seconds |
| `--timeout=N` | 60-300 | Single job timeout |

**Backup cron:** Keep cron restart as insurance in case of deadlock:

```bash
@reboot sleep 30 && /usr/bin/supervisorctl restart all
```

---

### 3. Timeout Cascade

**Problem:** Supervisor kills worker before job finishes — no logs, data lost.

**Rule:** `External Service < Job Timeout < Supervisor stopwaitsecs`

```text
┌─────────────────────────────────────────────────────────────┐
│  Playwright: 60s                                            │
│  ├── Laravel Job $timeout: 120s (more than Playwright)      │
│  │   └── Supervisor --timeout: 120s (= Job)                 │
│  │       └── Supervisor stopwaitsecs: 150s (> timeout)      │
└─────────────────────────────────────────────────────────────┘
```

**In Laravel Job:**

```php
class TakeScreenshotJob implements ShouldQueue
{
    public $timeout = 120;  // Must be >= external service

    // Exponential backoff: 1 min → 5 min → 30 min → 2 hours
    public $backoff = [60, 300, 1800, 7200];
}
```

---

### 4. Zombie Process Killer (Chrome/Playwright)

**Problem:** When PHP worker crashes, Chrome processes stay and consume memory.

#### Solution 1: Cron

```bash
# Kill Chrome processes older than 30 minutes
*/10 * * * * /usr/bin/pkill -9 -f "chrome.*--type=renderer" --older 1800 2>/dev/null || true
```

#### Solution 2: Docker with dumb-init

```dockerfile
FROM node:20-slim
RUN apt-get update && apt-get install -y dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "app.js"]
```

---

### 5. Docker Memory Limits

**Problem:** Memory leak in one service takes down entire server.

```yaml
# docker-compose.yml
services:
  redis:
    image: redis:7
    deploy:
      resources:
        limits:
          memory: 2G
    command: redis-server --maxmemory 2gb --maxmemory-policy noeviction

  app-worker:
    build: .
    deploy:
      resources:
        limits:
          memory: 4G
```

---

## Playwright / Screenshots

### 6. Fonts in Docker (Squares Instead of Text)

**Problem:** Docker lacks fonts for CJK (Chinese, Japanese), Arabic, emoji — text shows as `□□□`.

**Solution:**

```dockerfile
# Dockerfile
RUN apt-get update && apt-get install -y \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-freefont-ttf \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
```

---

### 7. Real User-Agent

**Problem:** Playwright is detected as `HeadlessChrome` → 403 errors.

**Solution:**

```javascript
// Playwright / Node.js
const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'
});
```

```php
// Laravel HTTP
Http::withHeaders([
    'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
])->get($url);
```

```python
# Python requests
requests.get(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'})
```

```go
// Go
req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36")
```

---

### 8. Playwright Tracing (Debug on Steroids)

**Problem:** Logs show dry `TimeoutError` — unclear what happened (captcha? white screen? 500?).

**Solution:** Save trace only on error:

```javascript
const context = await browser.newContext();
await context.tracing.start({ screenshots: true, snapshots: true });

try {
    // ... take screenshot
    await context.tracing.stop(); // Don't save on success
} catch (error) {
    // Save trace only on error
    await context.tracing.stop({ path: `traces/failed-${Date.now()}.zip` });
    throw error;
}
```

Open trace: <https://trace.playwright.dev/>

**Important:** Limit trace storage (7 days max), they are large.

---

### 9. Screenshot Compression

**Problem:** PNG screenshots weigh 1-3MB each.

**Solution:** WebP = -70% size:

```php
// Laravel + Intervention Image
$image = Image::make($screenshot)
    ->encode('webp', 80);  // 80% quality

Storage::disk('s3')->put("screenshots/{$id}.webp", $image);
```

---

## Storage

### 10. Storage Strategy

**Problem:** Screenshots fill disk, `inode` runs out.

#### Solution A: S3/R2 (recommended for >1000 screenshots/day)

```php
// Directly to S3, no local storage
Storage::disk('s3')->put("screenshots/{$id}.webp", $imageData);
```

#### Solution B: Local + cleanup (for small volumes)

```bash
# Delete screenshots older than 30 days
0 4 * * * find /var/www/app/storage/screenshots -mtime +30 -delete

# Delete Playwright temp files
0 4 * * * find /tmp -name "playwright*" -mtime +1 -delete 2>/dev/null
```

---

### 11. Disk Space Alert

```bash
#!/bin/bash
# /opt/scripts/disk-alert.sh

DISK_FREE=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
if [ "$DISK_FREE" -lt 10 ]; then
    curl -X POST "$SLACK_WEBHOOK" -d '{"text":"Warning: Disk < 10GB free!"}'
fi
```

```bash
*/30 * * * * /opt/scripts/disk-alert.sh
```

---

## Database

### 12. Prune Failed Jobs

**Problem:** `failed_jobs` table grows to millions of rows.

```bash
# Delete failed jobs older than 7 days
0 5 * * * cd /var/www/app && php artisan queue:prune-failed --hours=168
```

---

## Resilience Patterns

### 13. Circuit Breaker

**Problem:** External service is down — all workers hang waiting.

```php
// If 5 errors in a row — pause 5 minutes
public function handle()
{
    $failures = Cache::get('playwright_failures', 0);

    if ($failures >= 5) {
        $this->release(300); // Delay for 5 minutes
        return;
    }

    try {
        $this->takeScreenshot();
        Cache::forget('playwright_failures');
    } catch (\Exception $e) {
        Cache::put('playwright_failures', $failures + 1, 300);
        throw $e;
    }
}
```

---

### 14. Rate Limiting (Don't DDoS Sites)

```php
// App/Providers/AppServiceProvider.php
RateLimiter::for('parsing', function ($job) {
    return Limit::perMinute(10)->by($job->site->domain);
});

// In Job
public function middleware()
{
    return [new RateLimited('parsing')];
}
```

---

### 15. Proxy Rotation

```php
// For mass parsing
$proxies = config('services.proxies'); // ['proxy1:8080', 'proxy2:8080']
$proxy = $proxies[array_rand($proxies)];

Http::withOptions(['proxy' => $proxy])->get($url);
```

---

### 18. Playwright Service Stability (Multi-Layer Protection)

**Problem:** Playwright Docker service crashes under load — 20+ workers bombard one
container without backpressure, browsers accumulate memory, zombie processes pile up.

#### Root Cause Analysis (Real Production Case)

| Issue | Root Cause | Impact |
| ----- | ---------- | ------ |
| OOM kills | `MAX_CONCURRENT_PAGES=150` (one browser → 150 tabs) | Container killed by kernel |
| Zombie Chrome | No PID 1 init process in Docker | 2600+ zombie processes |
| /dev/shm crash | Docker default 64MB, Chrome needs more for IPC | Silent browser crashes |
| No backpressure | All requests accepted, no queue limit | Memory spiral → crash |
| No memory monitoring | Health check only tested connectivity | No preemptive action |

#### Docker Configuration (Critical)

```yaml
services:
  playwright-service:
    init: true                    # tini as PID 1 — reaps zombie processes
    shm_size: '2g'                # Chrome IPC needs > 64MB default
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 45s
    environment:
      MAX_CONCURRENT_PAGES: 12    # NOT 150! Match to available RAM
      MAX_SCREENSHOTS_PER_BROWSER: 150  # Browser recycling threshold
      MEMORY_LIMIT_MB: 12800      # RSS limit for backpressure (80% of 16GB)
      MAX_QUEUED_REQUESTS: 6      # Semaphore queue overflow threshold
```

**Key insight:** `init: true` eliminates the need for `pkill chrome renderer` cron.
`shm_size: '2g'` eliminates silent Chrome IPC crashes.

#### Backpressure Pattern (Service Level)

```javascript
// Semaphore with queue overflow detection
function checkBackpressure() {
  if (semaphore.waiting > MAX_QUEUED_REQUESTS) {
    return { status: 503, retryAfter: 5 };  // Queue overflow
  }
  if (getMemoryUsage().rss > MEMORY_LIMIT_MB) {
    return { status: 503, retryAfter: 10 }; // Memory pressure
  }
  return null; // OK to proceed
}

// In request handler — check BEFORE acquiring semaphore
app.post('/screenshot', async (req, res) => {
  const bp = checkBackpressure();
  if (bp) {
    res.set('Retry-After', bp.retryAfter);
    return res.status(503).json({ error: 'Service overloaded' });
  }
  // ... acquire semaphore and process
});
```

#### Concurrency Limiter (Queue Level)

```php
// Laravel Redis throttle middleware
class PlaywrightConcurrencyLimiter
{
    public function handle(object $job, Closure $next): void
    {
        Redis::throttle('playwright:concurrent')
            ->block(0)            // don't wait
            ->allow($maxConcurrent)
            ->every(60)
            ->then(
                fn() => $next($job),
                fn() => $job->release(5)  // retry in 5s
            );
    }
}
```

#### Browser Recycling

```javascript
// Track screenshots per browser slot
const browserScreenshotCount = new Map();

// After each screenshot
count++;
if (count >= MAX_SCREENSHOTS_PER_BROWSER) {
  // Close old browser, launch new one (after current requests finish)
  triggerBrowserRestart(slotIndex);
}
```

**Why 150?** Memory creep is ~0.5MB per screenshot. At 150: +75MB per browser.
With 6 browsers, recycling every 150 = ~7-8 hours between restarts.

#### Enhanced Health Endpoint

```javascript
app.get('/health', (req, res) => {
  const mem = process.memoryUsage();
  res.json({
    status: 'healthy',
    memory: {
      rss: Math.round(mem.rss / 1024 / 1024),
      heapUsed: Math.round(mem.heapUsed / 1024 / 1024),
      heapTotal: Math.round(mem.heapTotal / 1024 / 1024),
    },
    activeRequests,
    memoryWarning: mem.rss / 1024 / 1024 > MEMORY_LIMIT_MB,
    browsers: browserPool.filter(b => b?.isConnected()).length,
  });
});
```

**Important:** Health endpoint must be lightweight — no test context creation.
External monitor checks `memoryWarning` flag for preemptive restart.

#### Sizing Guide

| Server RAM | Docker RAM | Browser Pool | Max Concurrent | Workers |
| ---------- | ---------- | ------------ | -------------- | ------- |
| 16GB | 8G | 4 | 8 | 6+2 |
| 32GB | 16G | 6 | 12 | 10+2 |
| 64GB | 32G | 10 | 20 | 16+4 |
| 160GB | 140G | 12 | 24 | 16+4 |

**Formula:** Workers ≈ Browser Pool × 2 (each browser handles 2-3 contexts).
Max Concurrent = Browser Pool × 2 (or × 3 for lighter pages).

#### Checklist

```markdown
- [ ] Docker: init: true (zombie killer)
- [ ] Docker: shm_size >= 1g (Chrome IPC)
- [ ] Docker: healthcheck configured
- [ ] MAX_CONCURRENT_PAGES matches RAM (NOT 150!)
- [ ] Backpressure: 503 + Retry-After on overload
- [ ] Browser recycling every 100-200 screenshots
- [ ] Memory monitoring in /health endpoint
- [ ] Client handles 503 with sleep(Retry-After)
- [ ] Workers count <= Browser Pool × 3
- [ ] Supervisor: --max-jobs, --max-time, --memory flags
```

---

## Monitoring

### 16. Health Endpoint

```php
// routes/api.php
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toIso8601String(),
        'checks' => [
            'redis' => rescue(fn() => Redis::ping() ? 'ok' : 'fail', 'fail'),
            'database' => rescue(fn() => DB::connection()->getPdo() ? 'ok' : 'fail', 'fail'),
            'queue_parsing' => Redis::llen('queues:parsing'),
            'queue_screenshots' => Redis::llen('queues:screenshots'),
            'disk_free_gb' => round(disk_free_space('/') / 1024 / 1024 / 1024, 1),
            'memory_usage_mb' => round(memory_get_usage(true) / 1024 / 1024, 1),
        ],
    ]);
});
```

---

### 17. Alert Thresholds

| Metric | Warning | Critical |
| ------ | ------- | -------- |
| RAM usage | > 80% | > 90% |
| Disk free | < 20GB | < 10GB |
| Queue size | > 5000 | > 10000 |
| Failed jobs/hour | > 50 | > 200 |
| Redis memory | > 70% | > 90% |

---

## Supervisor Full Config

```ini
[program:parsing-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/app/artisan queue:work redis --sleep=3 --tries=3 --timeout=120 --max-jobs=100 --max-time=3600 --queue=parsing
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=10
redirect_stderr=true
stdout_logfile=/var/www/app/storage/logs/parsing-worker.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=5
stopwaitsecs=150

[program:screenshot-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/app/artisan queue:work redis --sleep=3 --tries=2 --timeout=180 --max-jobs=50 --max-time=1800 --queue=screenshots
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=4
redirect_stderr=true
stdout_logfile=/var/www/app/storage/logs/screenshot-worker.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=5
stopwaitsecs=210
```

---

## Maintenance Cron Jobs

```bash
# Restart workers on server reboot
@reboot sleep 30 && /usr/bin/supervisorctl restart all

# Clean old Laravel logs
0 3 * * * find /var/www/app/storage/logs -name "*.log" -mtime +7 -delete

# Clean Playwright temp files
0 4 * * * find /tmp -name "playwright*" -mtime +1 -delete 2>/dev/null

# Zombie Chrome killer
*/10 * * * * /usr/bin/pkill -9 -f "chrome.*--type=renderer" --older 1800 2>/dev/null || true

# Clean failed_jobs older than 7 days
0 5 * * * cd /var/www/app && php artisan queue:prune-failed --hours=168

# Disk space alert
*/30 * * * * /opt/scripts/disk-alert.sh

# Health check
*/5 * * * * /opt/scripts/health-check.sh >> /var/log/health-check.log 2>&1
```

---

## Quick Diagnostic Commands

```bash
# Worker status
supervisorctl status

# Queue sizes
redis-cli LLEN 'queues:parsing'
redis-cli LLEN 'queues:screenshots'

# Redis memory
redis-cli INFO memory | grep used_memory_human

# Zombie Chrome
pgrep -f "chrome.*--type=renderer" | wc -l

# Top by memory
ps aux --sort=-%mem | head -10

# Failed jobs
php artisan tinker --execute="echo DB::table('failed_jobs')->count();"

# Disk usage
df -h /
```

---

## Final Checklist

```markdown
## Production Readiness Checklist

### Redis
- [ ] maxmemory is set (2-4GB)
- [ ] noeviction for queues (NOT allkeys-lru!)
- [ ] Memory usage monitoring

### Workers
- [ ] --max-jobs=100 --max-time=3600
- [ ] Cascade: External < Job timeout < stopwaitsecs
- [ ] stopasgroup=true, killasgroup=true
- [ ] Log rotation (stdout_logfile_maxbytes)

### Playwright/Chrome
- [ ] Zombie killer cron
- [ ] Fonts: noto-cjk, noto-emoji, liberation
- [ ] Real User-Agent (not HeadlessChrome)
- [ ] Tracing on failure (with storage limit)
- [ ] WebP compression

### Docker
- [ ] mem_limit for containers
- [ ] dumb-init (kills child processes)

### Storage
- [ ] S3 or cleanup cron
- [ ] Disk alert < 10GB
- [ ] Temp files cleanup

### Database
- [ ] queue:prune-failed daily
- [ ] Backup
- [ ] Slow query log

### Resilience
- [ ] Circuit breaker for external services
- [ ] Exponential backoff ($backoff = [60, 300, 1800])
- [ ] Rate limiting per domain

### Monitoring
- [ ] /health endpoint
- [ ] Queue size alerts
- [ ] Error rate alerts
- [ ] Disk space alerts
```

---

## Common Problems and Solutions

| Symptom | Cause | Solution |
| ------- | ----- | -------- |
| RAM 100%, server unresponsive | Redis/Chrome without limit | maxmemory + mem_limit |
| Jobs disappear | allkeys-lru | noeviction |
| Workers crash without logs | stopwaitsecs < timeout | Increase stopwaitsecs |
| Memory grows over time | PHP leaks | --max-jobs=100 |
| Chrome accumulates | Zombie processes | pkill --older cron |
| Squares on screenshots | Missing fonts | fonts-noto-cjk |
| 403 on parsing | HeadlessChrome UA | Real User-Agent |
| Disk filled up | Screenshots/logs | S3 + cleanup cron |
| Unclear why it crashed | No debug info | Playwright tracing |

---

## Alternatives

### Laravel Horizon Instead of Supervisor

For Laravel projects, Horizon provides:

- Web dashboard for queues
- Metrics out of the box
- Worker auto-balancing
- Better integration

```bash
composer require laravel/horizon
php artisan horizon:install
php artisan horizon
```

---

## See Also

- [API Health Monitoring](./api-health-monitoring.md) — external API monitoring
- [Quick Check Scripts](./quick-check-scripts.md) — check scripts
