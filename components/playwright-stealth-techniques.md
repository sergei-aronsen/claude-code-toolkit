# Playwright Stealth — Anti-Detection for Web Scraping

Techniques to prevent bot detection when using Playwright for screenshots and scraping.

**Problem:** Default Playwright (headless Chromium) is easily detected by WAF systems
(Akamai Bot Manager, Cloudflare, DataDome, Google Cloud Armor).
Sites return `ERR_HTTP2_PROTOCOL_ERROR`, 403, or empty pages.

---

## Quick Diagnosis

### Step 1 — Check what is detected

Navigate to [bot.sannysoft.com](https://bot.sannysoft.com/) with your Playwright setup
and extract results:

```javascript
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1920, height: 1080 } });
  const page = await ctx.newPage();

  await page.goto('https://bot.sannysoft.com/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);

  const results = await page.evaluate(() => {
    const rows = document.querySelectorAll('table tr');
    const data = {};
    rows.forEach(row => {
      const cells = row.querySelectorAll('td');
      if (cells.length >= 2) {
        const key = cells[0].textContent.trim();
        const cls = cells[1].className;
        if (cls.includes('failed')) data[key] = 'FAIL';
      }
    });
    return data;
  });

  console.log('Failed tests:', Object.keys(results));
  await browser.close();
})();
```

### Step 2 — Classify the block type

| Symptom | Block Type | Fingerprint helps |
|---------|-----------|-------------------|
| `ERR_HTTP2_PROTOCOL_ERROR` | TLS/HTTP2 fingerprint or WAF | Yes |
| 403 Forbidden | WAF/CDN rule | Maybe |
| Empty page / JS challenge | JavaScript fingerprint | Yes |
| TCP timeout (connect fails) | IP-level firewall | No — need proxy |
| `ERR_CERT_COMMON_NAME_INVALID` | SSL cert mismatch | Use `ignoreHTTPSErrors` |

---

## Solution: playwright-extra + stealth plugin

### Install

```bash
npm install playwright-extra puppeteer-extra-plugin-stealth
```

### Basic Usage

```javascript
const { chromium } = require('playwright-extra');
const stealth = require('puppeteer-extra-plugin-stealth')();
chromium.use(stealth);

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ...',
    viewport: { width: 1920, height: 1080 },
    locale: 'nb-NO',
    timezoneId: 'Europe/Oslo',
  });
  const page = await context.newPage();
  // Stealth is active — no additional addInitScript needed
})();
```

### What stealth fixes automatically

| Detection Vector | Without stealth | With stealth |
|-----------------|----------------|--------------|
| `navigator.webdriver` | `true` (detected) | `false` |
| `window.chrome` | Missing | Present (faked) |
| `navigator.plugins` | Empty array (0) | Populated (5 plugins) |
| PluginArray type | Wrong type | Correct MimeType/Plugin |
| `navigator.permissions` | Headless behavior | Normal behavior |
| WebGL Renderer | "SwiftShader" | Spoofed real GPU |
| Chrome iframe test | Detected | Passes |
| CDP detection | Detected | Hidden |

### Real test results (bot.sannysoft.com)

- **Without stealth:** 49/56 passed, **7 failed**
- **With stealth:** **56/56 passed, 0 failed**

### Real-world impact

| Site | Without stealth | With stealth |
|------|----------------|--------------|
| te.com (Akamai) | `ERR_HTTP2_PROTOCOL_ERROR` | 200 OK |
| nespresso.com (Akamai) | `ERR_HTTP2_PROTOCOL_ERROR` | 200 OK |
| swatch.com (Google Cloud) | Timeout | 200 OK |
| grundfos.com | `ERR_HTTP2_PROTOCOL_ERROR` | 200 OK |

---

## Additional Context Options

Always set these for a realistic fingerprint:

```javascript
const context = await browser.newContext({
  userAgent: '...', // Modern Chrome UA matching Playwright's Chromium version
  viewport: { width: 1920, height: 1080 },
  locale: 'nb-NO',            // Match target audience
  timezoneId: 'Europe/Oslo',  // Match target audience
  colorScheme: 'light',
  deviceScaleFactor: 1,
  hasTouch: false,
  ignoreHTTPSErrors: true,    // For redirect domains with cert mismatches
});
```

---

## When stealth is NOT enough

### IP-level blocking

Some sites block entire datacenter IP ranges (Hetzner, AWS, GCP) at the firewall.
TCP connection itself fails — no TLS handshake occurs.

**Diagnosis:**

```bash
# From server
curl -s -m 10 -o /dev/null -w 'HTTP %{http_code} connect:%{time_connect}s' https://target.com

# connect:0.000000s = TCP blocked (IP-level)
# connect:0.082s + HTTP 000 = TLS/fingerprint blocked
# connect:0.082s + HTTP 403 = WAF rule
```

**Solution:** Residential proxies (not datacenter).

### Client Hints (sec-ch-ua)

Modern anti-bot checks `sec-ch-ua` headers. If User-Agent says Chrome 135
but Client Hints are empty — detected.

Playwright handles this automatically when you set a matching `userAgent`,
but if you use a custom UA, ensure consistency.

---

## Integration with Firecrawl Playwright Service

For projects using Firecrawl's Playwright service (`api.ts`):

### 1. Add dependencies to package.json

```json
{
  "dependencies": {
    "playwright": "^1.55.1",
    "playwright-extra": "^4.3.6",
    "puppeteer-extra-plugin-stealth": "^2.11.2"
  }
}
```

### 2. Replace imports in api.ts

```typescript
// Before
import { chromium, Browser, BrowserContext } from 'playwright';

// After
import { chromium } from 'playwright-extra';
import { Browser, BrowserContext } from 'playwright';
import stealth from 'puppeteer-extra-plugin-stealth';
chromium.use(stealth());
```

### 3. Add locale/timezone to all browser contexts

```typescript
const contextOptions = {
  locale: 'nb-NO',
  timezoneId: 'Europe/Oslo',
  userAgent,
  viewport,
  ignoreHTTPSErrors: true,
};
```

### 4. Rebuild Docker

```bash
docker compose build --no-cache playwright-service
docker compose up -d playwright-service
```

---

## Proxy vs Stealth Decision Matrix

| Scenario | Stealth alone | Proxy alone | Both needed |
|----------|--------------|-------------|-------------|
| Small/medium sites | Yes | No | No |
| Corporate WAF (Akamai, Cloudflare) | Yes | No | No |
| IP-blocked datacenter ranges | No | Yes | No |
| Advanced anti-bot (DataDome, PerimeterX) | Maybe | Maybe | Yes |

**For typical web scraping (different domains, 1 visit each):**
85-90% of sites work with stealth alone, no proxy needed.

---

## User-Agent Policy

**NEVER use bot-identifying User-Agent strings.** Always use a real browser UA:

```text
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36
```

This applies to ALL HTTP requests — not just Playwright, but also:

- PHP `Http::get()` calls (alive checks, API calls)
- cURL requests
- Any server-side HTTP client

---

---

## Cookie Banners

Cookie consent overlays block content on many EU sites. Use `idcac-playwright` to auto-dismiss:

```bash
npm install idcac-playwright
```

```javascript
import { getInjectableScript } from 'idcac-playwright';

// After page.goto(), inject the script
await page.evaluate(getInjectableScript());
```

This injects 10,000+ selectors from [I Still Don't Care About Cookies](https://github.com/OhMyGuus/I-Still-Dont-Care-About-Cookies) database.

See also: `components/playwright-self-testing.md` → Cookie Banners section.

---

## Add to CLAUDE.md

```markdown
## Playwright Stealth (Anti-Detection)

Use `playwright-extra` + `puppeteer-extra-plugin-stealth` for all Playwright services.
Default Playwright is detected by WAF (Akamai, Cloudflare, DataDome).

Key: stealth plugin, locale/timezone, real Chrome UA, `ignoreHTTPSErrors`.
Test on bot.sannysoft.com — all tests must pass.
Cookie banners: use `idcac-playwright` to auto-dismiss (10,000+ selectors).

Full guide: `components/playwright-stealth-techniques.md`
```
