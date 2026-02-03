# Playwright in Production — Stability Guide

Why Playwright services crash under load, what parameters actually matter,
and how to build a self-healing screenshot/scraping service.

Based on real production debugging: 32GB server, 500K+ domains, 20 workers,
Docker container crashing every 2-4 hours.

---

## Why Playwright Crashes (Root Causes)

### 1. `/dev/shm` too small (Docker default: 64MB)

**Symptom:** Browsers silently crash. No error in logs. Screenshots return empty or error.

**Cause:** Chrome uses `/dev/shm` (shared memory) for IPC between processes.
Docker default is 64MB. A single Chrome tab can use 100MB+ of shared memory.

**Fix:**

```yaml
services:
  playwright-service:
    shm_size: '2g'   # or '1g' minimum
```

**How to diagnose:**

```bash
docker exec <container> df -h /dev/shm
# If Avail is close to 0 — this is your problem
```

### 2. Zombie Chrome processes (no init system)

**Symptom:** `ps aux | grep chrome | wc -l` keeps growing. Memory usage climbs.
Eventually OOM kill.

**Cause:** When a browser context crashes, Chrome child processes become orphans.
Docker default PID 1 is your app (Node.js) — it doesn't reap zombies.

**Fix:**

```yaml
services:
  playwright-service:
    init: true   # Uses tini as PID 1, reaps zombie processes
```

**Real numbers:** Without `init: true` we observed 2600+ zombie Chrome processes
accumulating over 24 hours. With it — stable at 20-30 processes.

**Alternative:** `dumb-init` in Dockerfile if you can't use `init: true`:

```dockerfile
RUN apt-get update && apt-get install -y dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "app.js"]
```

### 3. Too many concurrent pages per browser

**Symptom:** Container RAM spikes to limit, OOM kill, all in-progress requests fail.

**Cause:** Each browser tab (page) consumes 50-300MB depending on the site.
If `MAX_CONCURRENT_PAGES=150` and you have 6 browsers, that's theoretically
900 tabs × 100MB = 90GB. Even with 20 actual concurrent requests, the browser
process memory is unpredictable.

**Fix:** `MAX_CONCURRENT_PAGES` should be 2-3× your browser pool size, not more.

| Browser Pool | Max Concurrent Pages | Reasoning |
|-------------|---------------------|-----------|
| 4 | 8-12 | 2-3 pages per browser |
| 6 | 12-18 | sweet spot for 16GB |
| 10 | 20-30 | needs 32GB+ |

**Critical mistake we found:** `MAX_CONCURRENT_PAGES` was mapped from
`CRAWL_CONCURRENT_REQUESTS=150` in docker-compose.yaml — a variable meant
for HTTP crawling, not browser tabs. **Always audit what env vars actually control.**

### 4. Too many browser instances

**Symptom:** High base memory even when idle. Slow startup. Frequent GC pauses.

**Cause:** Each Chromium browser instance uses 200-400MB just being open
(no pages loaded). 40 browsers = 8-16GB base memory before any work.

**Sizing formula:**

```text
Base memory = BROWSER_POOL_SIZE × 300MB
Per-request  = ~100-200MB per active page
Total needed = Base + (concurrent_requests × 150MB) + 2GB overhead

Example: 6 browsers, 12 concurrent
= 6×300 + 12×150 + 2000 = 1800 + 1800 + 2000 = 5.6GB
```

**Rule of thumb:** Browser Pool should be 1/3 to 1/2 of your worker count.
Workers that exceed browser capacity should wait, not crash.

### 5. Memory creep (no browser recycling)

**Symptom:** Memory grows 50-100MB per hour. After 8-12 hours, OOM.

**Cause:** Chromium has internal memory fragmentation. Even after closing all
pages and contexts, the browser process doesn't release all memory.
V8 garbage collector doesn't return memory to OS reliably.

**Fix:** Recycle browsers after N screenshots:

```javascript
const MAX_SCREENSHOTS_PER_BROWSER = 150;
const browserScreenshotCount = new Map();

// After each screenshot
const count = (browserScreenshotCount.get(slotIndex) || 0) + 1;
browserScreenshotCount.set(slotIndex, count);

if (count >= MAX_SCREENSHOTS_PER_BROWSER) {
  // Wait for active requests to finish, then close and relaunch
  await triggerBrowserRestart(slotIndex);
  browserScreenshotCount.set(slotIndex, 0);
}
```

**Why 150?** Memory creep is ~0.5MB per screenshot. At 150: +75MB per browser.
With 6 browsers and ~20 screenshots/hour/browser, recycling happens every
7-8 hours — aligns with natural daily restart.

### 6. No backpressure (the #1 architectural mistake)

**Symptom:** Service accepts all requests, queues them internally, memory grows,
response times degrade from 5s to 60s, then crash.

**Cause:** HTTP server (Express) accepts unlimited connections. Semaphore/queue
has no overflow protection. 20 workers send requests simultaneously,
all get queued, all wait, memory for all accumulates.

**Fix:** Reject requests when overloaded:

```javascript
function checkBackpressure(semaphore) {
  // Queue overflow
  if (semaphore.waiting > MAX_QUEUED_REQUESTS) {
    return { status: 503, retryAfter: 5, reason: 'queue_overflow' };
  }
  // Memory pressure
  const rssMB = process.memoryUsage().rss / 1024 / 1024;
  if (rssMB > MEMORY_LIMIT_MB) {
    return { status: 503, retryAfter: 10, reason: 'memory_pressure' };
  }
  return null;
}

app.post('/screenshot', (req, res) => {
  const bp = checkBackpressure(semaphore);
  if (bp) {
    res.set('Retry-After', String(bp.retryAfter));
    return res.status(503).json({ error: 'overloaded', reason: bp.reason });
  }
  // ... process request
});
```

**The client side must handle 503:**

```php
// Laravel example
$response = Http::timeout(20)->post($url, $params);
if ($response->status() === 503) {
    $retryAfter = (int) $response->header('Retry-After', '5');
    sleep($retryAfter);
    continue; // retry
}
```

### 7. fullPage screenshot crash

**Symptom:** `Protocol error: Unable to capture screenshot` or browser crash
on specific sites when using `page.screenshot({ fullPage: true })`.

**Cause:** Playwright tries to resize the viewport to the full page height.
Some sites have infinite scroll, enormous DOM, or CSS that causes
the calculated height to be 50000+ pixels. Chrome can't allocate a buffer
that large and crashes.

**Fix:** Catch the error and use a **fresh page with tall viewport** as fallback:

```javascript
let screenshot;
try {
  screenshot = await page.screenshot({ fullPage: true, type: 'png' });
} catch (fullPageError) {
  // Create NEW context with fixed tall viewport BEFORE loading the page
  const tallContext = await browser.newContext({
    viewport: { width: 1920, height: 15000 },  // max safe height
    // ... same other options
  });
  const tallPage = await tallContext.newPage();
  await tallPage.goto(url, { waitUntil: 'networkidle', timeout });
  screenshot = await tallPage.screenshot({ fullPage: false, type: 'png' });
  await tallContext.close();
}
```

**Why new context, not just resize?** Resizing after load causes re-layout which
can trigger the same crash. Creating a new context with the viewport set BEFORE
navigation avoids this.

**Height limits:**

| Type | Max Height | Reasoning |
|------|-----------|-----------|
| Desktop | 15000px | ~8 full HD screens, enough for most pages |
| Mobile | 20000px | Mobile pages are taller but narrower (less memory) |

Trim excess whitespace on the application side (PHP/Python) after receiving the screenshot.

### 8. Missing fonts in Docker (squares instead of text)

**Symptom:** Screenshots show `□□□□` instead of Chinese, Japanese, Korean,
Arabic text, or emoji. Latin text renders fine.

**Cause:** Docker images don't include CJK or emoji fonts. Chrome falls back
to "tofu" (blank squares) for any character without a matching font.

**Fix:** Add to Dockerfile:

```dockerfile
RUN apt-get update && apt-get install -y \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-liberation \
    fonts-freefont-ttf \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -fv
```

| Package | Coverage |
|---------|----------|
| `fonts-noto-cjk` | Chinese, Japanese, Korean |
| `fonts-noto-color-emoji` | Emoji (color) |
| `fonts-liberation` | Arial/Times New Roman equivalents |
| `fonts-freefont-ttf` | Wide Unicode coverage |

**After installing:** Run `fc-cache -fv` to rebuild the font cache.
Restart the container.

### 9. Docker-compose env var substitution trap

**Symptom:** You set `MAX_CONCURRENT_PAGES: ${MY_VAR:-10}` expecting default 10,
but the service gets 150.

**Cause:** Docker-compose `${VAR:-default}` only uses the default if `VAR` is
**not set at all**. If your `.env` file has `MY_VAR=150` (even from an unrelated
context), docker-compose uses 150.

**Real example:**

```yaml
# docker-compose.yaml
environment:
  MAX_CONCURRENT_PAGES: ${CRAWL_CONCURRENT_REQUESTS:-10}
  # Intent: 10 concurrent pages
  # Reality: CRAWL_CONCURRENT_REQUESTS=150 was in .env (for HTTP crawler)
  # Result: 150 concurrent pages → OOM crash
```

**Fix:** Use dedicated env var names for each service. Never reuse a variable
across services with different semantics:

```yaml
environment:
  MAX_CONCURRENT_PAGES: ${MAX_CONCURRENT_PAGES:-12}
```

**Diagnostic:** Always verify what the container actually sees:

```bash
docker exec <container> env | grep MAX_CONCURRENT
```

---

## Docker Configuration (Complete)

```yaml
services:
  playwright-service:
    build: ./playwright-service
    init: true                    # Zombie process reaper
    shm_size: '2g'                # Chrome shared memory
    restart: unless-stopped       # Auto-restart on crash

    environment:
      PORT: 3000
      MAX_CONCURRENT_PAGES: 12          # NOT 150!
      MAX_SCREENSHOTS_PER_BROWSER: 150  # Browser recycling
      MEMORY_LIMIT_MB: 12800            # 80% of mem_limit
      MAX_QUEUED_REQUESTS: 6            # Backpressure queue threshold
      BROWSER_POOL_SIZE: 6              # Number of browser instances

    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 45s

    # Resource limits
    cpus: 8.0
    mem_limit: 16G
    memswap_limit: 16G              # Same as mem_limit (no swap)

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### Key relationships between parameters

```text
MEMORY_LIMIT_MB = mem_limit × 0.8
  (leave 20% headroom for OS, temp files, GC)

MAX_CONCURRENT_PAGES = BROWSER_POOL_SIZE × 2
  (each browser handles 2-3 pages, more = risk of crash)

MAX_QUEUED_REQUESTS = BROWSER_POOL_SIZE
  (if queue > browsers, you're already behind)
```

### Browser Launch Arguments

Chromium accepts flags that significantly affect stability in Docker:

```javascript
const browser = await chromium.launch({
  headless: true,
  args: [
    '--no-sandbox',              // Required in Docker (container IS the sandbox)
    '--disable-setuid-sandbox',  // Companion to --no-sandbox
    '--disable-dev-shm-usage',   // Use /tmp instead of /dev/shm (fallback if shm_size not set)
    '--disable-gpu',             // No GPU in Docker (prevents GPU-related crashes)
    '--disable-extensions',      // No extensions needed
    '--disable-background-timer-throttling',  // Don't throttle background tabs
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
  ],
});
```

**`--disable-dev-shm-usage` vs `shm_size`:**

| Approach | How it works | When to use |
|----------|-------------|-------------|
| `shm_size: '2g'` | Increases /dev/shm to 2GB | Preferred — Chrome works naturally |
| `--disable-dev-shm-usage` | Redirects shared memory to /tmp | Fallback — if you can't control docker-compose |

Using both is fine as belt-and-suspenders. If you can only choose one, prefer `shm_size`.

### Graceful Shutdown (SIGTERM Handling)

Docker sends SIGTERM before SIGKILL (default 10s grace period).
Without a handler, browsers die mid-request — corrupted screenshots, leaked resources.

```javascript
let isShuttingDown = false;

async function gracefulShutdown(signal) {
  if (isShuttingDown) return;
  isShuttingDown = true;
  console.log(`Received ${signal}, shutting down gracefully...`);

  // Stop accepting new requests
  server.close();

  // Wait for active requests to finish (max 30s)
  const maxWait = 30_000;
  const start = Date.now();
  while (activeRequests > 0 && Date.now() - start < maxWait) {
    await new Promise(r => setTimeout(r, 1000));
  }

  // Close all browsers
  for (const browser of browserPool) {
    try { await browser?.close(); } catch (e) { /* ignore */ }
  }

  process.exit(0);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
```

Match Docker's `stop_grace_period` (or Supervisor `stopwaitsecs`) to your max wait time + buffer:

```yaml
services:
  playwright-service:
    stop_grace_period: 45s  # > 30s graceful wait + 10s buffer
```

### Timeout Hierarchy (Critical)

Timeouts must be nested correctly or you get silent failures:

```text
┌──────────────────────────────────────────────────────────────┐
│ Playwright page.goto timeout: 45s                            │
│ ├── HTTP client timeout (Laravel): 60s (> Playwright)        │
│ │   ├── Laravel Job $timeout: 180s (> HTTP client)           │
│ │   │   └── Supervisor stopwaitsecs: 200s (> Job timeout)    │
│ │   │       └── Docker stop_grace_period: 45s (for shutdown) │
└──────────────────────────────────────────────────────────────┘
```

**Rule:** `External Service < HTTP Client < Job Timeout < Supervisor stopwaitsecs`

If Supervisor kills the worker before the job finishes — no error log, no retry,
job just disappears. This is one of the hardest bugs to debug.

### Screenshot Optimization (PNG vs WebP)

Raw screenshots from Playwright are PNG — typically 1-3MB each.
Convert to WebP on the application side for 70% size reduction:

```php
// Laravel + Intervention Image
$image = Image::make($pngData)
    ->encode('webp', 80);  // 80% quality, ~300KB instead of 1.5MB

Storage::disk('s3')->put("screenshots/{$id}.webp", $image);
```

```javascript
// Node.js (in the service itself)
const screenshot = await page.screenshot({ type: 'png' });
// Or directly:
const screenshot = await page.screenshot({ type: 'jpeg', quality: 80 });
// Note: Playwright doesn't support WebP natively, use sharp for conversion
```

**Storage math:** 10K screenshots/day × 1.5MB = 15GB/day (PNG) vs 4.5GB/day (WebP).

### Resource Blocking (When NOT Taking Screenshots)

For scraping/parsing (not screenshots), block heavy resources for 3-5x speed:

```javascript
await page.route('**/*', (route) => {
  const type = route.request().resourceType();
  if (['image', 'media', 'font', 'stylesheet'].includes(type)) {
    return route.abort();
  }
  // Block trackers (save time on JS execution)
  const url = route.request().url();
  if (/googletagmanager|analytics|doubleclick|facebook.*pixel/.test(url)) {
    return route.abort();
  }
  return route.continue();
});
```

**For screenshots: do NOT block images or CSS** — you need visual fidelity.
But you CAN block trackers, analytics, and video to save memory:

```javascript
await page.route('**/*', (route) => {
  const type = route.request().resourceType();
  if (['media'].includes(type)) return route.abort();
  const url = route.request().url();
  if (/googletagmanager|analytics|doubleclick/.test(url)) return route.abort();
  return route.continue();
});
```

### tmpfs for Chrome Cache

Chrome writes temporary files to `/tmp`. In Docker, this goes to the
container's writable layer (overlay filesystem) — slow and can fill up disk.

Mount tmpfs for fast, auto-cleaning temp storage:

```yaml
services:
  playwright-service:
    tmpfs:
      - /tmp/.cache:noexec,nosuid,size=1g
```

This gives Chrome 1GB of RAM-backed temp storage that auto-cleans on restart.
`noexec,nosuid` are security flags (no running binaries from tmp).

### Context Isolation (One Context Per Request)

**Never reuse browser contexts between requests.** Each request should get
a fresh context with its own cookies, storage, and viewport:

```javascript
// CORRECT: new context per request
const context = await browser.newContext({
  viewport, userAgent, locale, timezoneId,
  ignoreHTTPSErrors: true,
});
const page = await context.newPage();
try {
  // ... take screenshot
} finally {
  await context.close();  // ALWAYS close in finally
}

// WRONG: reusing context across requests
// Cookies from site A leak into site B
// Memory accumulates without release
```

**Always close context in `finally`** — even if the screenshot fails.
Unclosed contexts are the #1 source of memory leaks.

---

## Health Endpoint (What to Monitor)

A proper health endpoint should be **lightweight** (no test browser/context creation)
and expose enough data for external monitoring to make decisions.

```javascript
app.get('/health', (req, res) => {
  const mem = process.memoryUsage();
  const rssMB = Math.round(mem.rss / 1024 / 1024);
  const memoryWarning = rssMB > MEMORY_LIMIT_MB;

  res.json({
    status: memoryWarning ? 'warning' : 'healthy',
    memory: {
      rss: rssMB,
      heapUsed: Math.round(mem.heapUsed / 1024 / 1024),
      heapTotal: Math.round(mem.heapTotal / 1024 / 1024),
    },
    activeRequests,
    maxConcurrentPages: MAX_CONCURRENT_PAGES,
    browsers: browserPool.filter(b => b?.isConnected()).length,
    memoryWarning,
    uptime: Math.round(process.uptime()),
  });
});
```

**What to alert on:**

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| RSS | > 80% of limit | > 90% of limit | Preemptive restart |
| `memoryWarning` | true | - | Stop workers, restart container |
| `browsers` | < pool size | 0 | Container is dying |
| `activeRequests` | > max concurrent | - | Backpressure not working |

### Preemptive restart pattern

External monitor (Laravel scheduler, cron, etc.) checks `/health` every 5 minutes.
If `memoryWarning: true` — restart the container BEFORE OOM kill.
This gives you a clean restart with zero lost requests (workers are stopped first).

---

## Concurrency Control (Multi-Layer)

Single-layer concurrency control doesn't work. You need protection at every level:

```text
Layer 1: Queue workers (Supervisor)
  └─ Limited number of workers (10-12, not 50)

Layer 2: Job middleware (Laravel/framework)
  └─ Redis throttle: max N concurrent jobs
  └─ Excess jobs → release back to queue with delay

Layer 3: HTTP client (in application)
  └─ Handle 503 → sleep(Retry-After) → retry
  └─ Handle "browser closed" → sleep(3) → retry (no config change)

Layer 4: Service itself (Playwright)
  └─ Semaphore with MAX_CONCURRENT_PAGES
  └─ Backpressure: reject with 503 when queue full or memory high
  └─ Browser recycling after N screenshots
```

### Why multi-layer

- Layer 1 alone: workers still overwhelm the service (20 workers > 12 capacity)
- Layer 2 alone: doesn't protect against service memory issues
- Layer 3 alone: requests still pile up on the service
- Layer 4 alone: workers hang and eventually timeout

**All four together:** smooth degradation, no crashes, no lost work.

### Worker count formula

```text
Workers = BROWSER_POOL_SIZE × 2

Example: 6 browsers × 2 = 12 workers (10 regular + 2 priority)
```

More workers than this just creates queue pressure with no throughput gain.

---

## Error Categories

Not all errors should be handled the same way:

### Proxy errors (change proxy, retry)

```text
HTTP 403, 407, 429
Connection refused (to target site)
ERR_HTTP2_PROTOCOL_ERROR
Timeout (target site)
```

**Action:** Switch to different proxy, retry.

### Service-retryable errors (wait, retry same config)

```text
browser has been closed
context has been closed
Target closed
Target page, context or browser has been closed
Protocol error
Navigation failed because page was closed
```

**Action:** Sleep 3 seconds, retry with same proxy. These errors mean the browser
was recycled or crashed — not a proxy/target issue.

### Backpressure errors (wait longer, retry)

```text
HTTP 503 from Playwright service
```

**Action:** Sleep `Retry-After` seconds (typically 5-10), retry.

### Fatal errors (don't retry)

```text
Invalid URL
DNS resolution failed (NXDOMAIN)
SSL certificate error (for non-redirect domains)
```

**Action:** Mark as failed, don't retry.

---

## Graceful Browser Restart

When recycling a browser, you can't just `browser.close()` — active requests
on that browser will fail. Pattern:

```javascript
async function triggerBrowserRestart(slotIndex) {
  // Mark slot as restarting (new requests go to other browsers)
  isRestarting[slotIndex] = true;

  // Wait for active requests on this slot to finish (max 30s)
  const maxWait = 30_000;
  const start = Date.now();
  while (activeRequestsPerSlot[slotIndex] > 0 && Date.now() - start < maxWait) {
    await new Promise(r => setTimeout(r, 1000));
  }

  // Close old browser
  try {
    await browserPool[slotIndex]?.close();
  } catch (e) {
    // Browser might already be dead — that's fine
  }

  // Launch new browser
  browserPool[slotIndex] = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });

  isRestarting[slotIndex] = false;
  browserScreenshotCount.set(slotIndex, 0);
}
```

**Key points:**

- Flag `isRestarting` prevents new requests from being routed to this slot
- Wait loop gives active requests time to finish (with timeout)
- Even if the old browser is dead, `close()` might throw — catch it
- `--disable-dev-shm-usage` is a fallback if `shm_size` in docker-compose isn't enough

---

## Proxy Cascade Pattern

For screenshot services that need to handle IP-blocked sites:

```text
Attempt 1: Datacenter proxy (random from pool)
  ↓ fail
Attempt 2: Datacenter proxy (different random)
  ↓ fail
Attempt 3: Direct (no proxy)
  ↓ fail
Attempt 4: Residential proxy (2captcha, BrightData, etc.)
```

```php
// Laravel implementation
const MAX_PROXY_RETRIES = 4;
const RESIDENTIAL_ATTEMPT_AFTER = 3;

for ($attempt = 1; $attempt <= MAX_PROXY_RETRIES; $attempt++) {
    $proxy = match(true) {
        $attempt <= 2   => $this->getRandomDatacenterProxy(),
        $attempt === 3  => null,  // direct, no proxy
        default         => $this->getResidentialProxy(),
    };

    try {
        return $this->takeScreenshot($url, $proxy);
    } catch ($e) {
        if ($this->isServiceRetryableError($e)) {
            sleep(3);  // Browser recycling — don't change proxy
            continue;
        }
        // Proxy/target error — try next proxy
        continue;
    }
}
```

**Why this order?**

- Datacenter first: fast (5-10ms latency), unlimited traffic, free
- Direct third: some sites actually block proxy IPs but allow datacenter
- Residential last: slow (100-500ms), expensive (per GB), but handles IP-level blocks

**Residential proxies handle ~5% of domains** that block all datacenter IPs at the firewall level (TCP connect fails). Worth the cost for completeness.

---

## Anti-Detection (Quick Reference)

Stealth and stability are different concerns but both affect success rate.

### UA Rotation

Don't use a single User-Agent. Rotate from a pool of 15-20 real Chrome UAs:

```javascript
const DESKTOP_UAS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ... Chrome/131.0.0.0 ...',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ... Chrome/131.0.0.0 ...',
  // ... 13 more
];

function getRandomUA(isMobile) {
  const pool = isMobile ? MOBILE_UAS : DESKTOP_UAS;
  return pool[Math.floor(Math.random() * pool.length)];
}
```

### Random delays

Bots are fast and consistent. Humans are slow and random.

```javascript
// Before navigation: 500-2000ms
await new Promise(r => setTimeout(r, 500 + Math.random() * 1500));
await page.goto(url, { waitUntil: 'networkidle' });

// Between scrolls: 200-600ms
for (const step of scrollSteps) {
  await new Promise(r => setTimeout(r, 200 + Math.random() * 400));
  await page.evaluate(y => window.scrollTo(0, y), step);
}
```

### Stealth plugin

See `playwright-stealth-techniques.md` for full guide. Quick setup:

```javascript
import { chromium } from 'playwright-extra';
import stealth from 'puppeteer-extra-plugin-stealth';
chromium.use(stealth());
```

---

## Sizing Guide

| Server RAM | Docker mem_limit | Browser Pool | Max Concurrent | Workers | Memory Limit MB |
|-----------|-----------------|-------------|---------------|---------|----------------|
| 8GB | 4G | 3 | 6 | 4+1 | 3200 |
| 16GB | 8G | 4 | 8 | 6+2 | 6400 |
| 32GB | 16G | 6 | 12 | 10+2 | 12800 |
| 64GB | 32G | 10 | 20 | 16+4 | 25600 |
| 160GB | 140G | 12 | 24 | 16+4 | 112000 |

**Notes:**

- Docker mem_limit = 50% of server RAM (leave room for app, DB, Redis, OS)
- Memory Limit MB = 80% of Docker mem_limit (backpressure threshold)
- Workers = Browser Pool × 2 (main + priority split)
- Beyond 12 browsers, throughput gains diminish (context switch overhead)

---

## Page Load and Scroll Gotchas

### `networkidle` vs `load`

```javascript
// Recommended for screenshots (waits for lazy-loaded images)
await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });

// Faster but may miss lazy-loaded content
await page.goto(url, { waitUntil: 'load', timeout: 30000 });
```

`networkidle` waits until there are no network requests for 500ms.
On sites with analytics/tracking scripts that fire continuously,
this can cause timeout. Always set an explicit timeout.

### scroll_to_bottom is critical but expensive

Many modern sites use lazy loading — images and content only load when
scrolled into view. Without scrolling, you get a screenshot with placeholder
images or empty sections.

**But:** scrolling loads more content, which uses more memory per tab.
On a 50000px page, scrolling can load 200+ images.

**Mitigation:**

- Height limit (15000-20000px max)
- Random delays between scrolls (helps with both anti-detection and memory)
- Close context immediately after screenshot (release memory)

```javascript
// Scroll with height limit and random delays
async function scrollToBottom(page, maxHeight = 15000) {
  const viewportHeight = page.viewportSize().height;
  let currentPos = 0;

  while (currentPos < maxHeight) {
    currentPos += viewportHeight;
    await page.evaluate(y => window.scrollTo(0, y), currentPos);
    // Random delay: looks human + gives browser time to load
    await new Promise(r => setTimeout(r, 200 + Math.random() * 400));

    // Check if we've reached the bottom
    const pageHeight = await page.evaluate(() => document.body.scrollHeight);
    if (currentPos >= pageHeight) break;
  }

  // Scroll back to top for the screenshot
  await page.evaluate(() => window.scrollTo(0, 0));
  // Wait for any final lazy-loaded content
  await new Promise(r => setTimeout(r, 1000));
}
```

### Cookie banners block screenshots

Cookie consent banners can cover 30-50% of the viewport. Must be handled
before taking the screenshot:

1. **Click accept** (with `force: true`, no `isVisible()` check)
2. **Click inside iframes** (Sourcepoint, Schibsted use iframes)
3. **CSS fallback** (hide banner with `display: none`)

```javascript
// Click with force: true — skips visibility check
// Some banners are position:fixed and report as "not visible"
await btn.click({ timeout: 2000, force: true });
```

**The `isVisible()` trap:** Cookie banners with `position: fixed` sometimes
report `isVisible() = false` because they're outside the normal layout flow.
This caused us to skip clicking → banner stays → covers screenshot.
Use `force: true` instead.

---

## Compiled TypeScript Gotcha

If the Playwright service is written in TypeScript but runs compiled JavaScript
(`node dist/api.js`), editing `.ts` files has no effect until you rebuild:

```bash
# Inside the container:
docker exec <container> npm run build

# Then restart:
docker compose restart playwright-service

# Or rebuild the image entirely:
docker compose build --no-cache playwright-service
docker compose up -d playwright-service
```

Check `package.json` scripts section to see if the service runs `.ts` directly
(ts-node) or compiled `.js`.

---

## Monitoring Commands

```bash
# Container resource usage (live)
docker stats <container>

# Current memory breakdown
curl -s http://127.0.0.1:3001/health | jq '.memory'

# Chrome process count (should be stable)
docker exec <container> sh -c "ps aux | grep chrome | wc -l"

# Container logs (last 100 lines)
docker logs <container> --tail 100

# Worker status
supervisorctl status | grep screenshot
```

---

## Checklist for New Playwright Service

```markdown
## Docker
- [ ] `init: true` (zombie process reaper)
- [ ] `shm_size: '2g'` (Chrome shared memory)
- [ ] `healthcheck` configured (curl /health every 30s)
- [ ] `mem_limit` set (50% of server RAM)
- [ ] `memswap_limit` = `mem_limit` (disable swap for predictable OOM)
- [ ] `restart: unless-stopped`
- [ ] `stop_grace_period` > graceful shutdown timeout
- [ ] `tmpfs` for /tmp/.cache (Chrome temp files)
- [ ] Fonts: `fonts-noto-cjk`, `fonts-noto-color-emoji`, `fonts-liberation`
- [ ] Env vars use dedicated names (no reusing vars across services)

## Browser
- [ ] Launch args: --no-sandbox, --disable-dev-shm-usage, --disable-gpu
- [ ] MAX_CONCURRENT_PAGES = BROWSER_POOL_SIZE × 2 (NOT 50+!)
- [ ] Browser recycling every 100-200 screenshots
- [ ] Graceful restart: wait for active requests before closing browser
- [ ] New context per request (never reuse contexts)
- [ ] Always close context in `finally` block

## Service
- [ ] Backpressure: 503 + Retry-After on queue overflow or memory pressure
- [ ] Memory monitoring in /health (RSS, heapUsed, memoryWarning)
- [ ] Lightweight /health (no test context creation!)
- [ ] SIGTERM handler: stop accepting, wait for active, close browsers
- [ ] UA rotation (15+ real Chrome UAs)
- [ ] Random delays before navigation (500-2000ms)
- [ ] fullPage crash fallback (tall viewport pattern)
- [ ] Screenshot height limit (15000px desktop, 20000px mobile)

## Client
- [ ] Handle HTTP 503 with sleep(Retry-After)
- [ ] Handle "browser closed" errors as retryable (sleep 3s)
- [ ] Concurrency limiter (Redis throttle or similar)
- [ ] Workers count ≤ Browser Pool × 3
- [ ] Proxy cascade: datacenter → direct → residential
- [ ] Screenshot compression: PNG → WebP (70% smaller)
- [ ] Timeout hierarchy: Playwright < HTTP < Job < Supervisor

## Workers (Supervisor)
- [ ] `--max-jobs` (restart after N jobs, prevents memory leaks)
- [ ] `--max-time` (restart every hour)
- [ ] `--memory` (restart if PHP/Node exceeds threshold)
- [ ] `stopwaitsecs` > job timeout
- [ ] `stopasgroup=true`, `killasgroup=true`

## Monitoring
- [ ] /health returns memory stats and memoryWarning flag
- [ ] External check every 5 min (preemptive restart on memoryWarning)
- [ ] Alert on container restart
- [ ] Log rotation configured (json-file, max-size 10m)
- [ ] Resource blocking for analytics/trackers (even in screenshot mode)
```

---

## See Also

- [playwright-stealth-techniques.md](./playwright-stealth-techniques.md) — anti-detection, stealth plugin, fingerprint fixes
- [playwright-self-testing.md](./playwright-self-testing.md) — visual UI testing with Playwright MCP
- [devops-highload-checklist.md](./devops-highload-checklist.md) — broader production checklist
