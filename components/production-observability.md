# Production Observability

> Closes the GSD blind spot: GSD verifies plan-vs-spec, not product-vs-reality. Real quality requires runtime testing + monitoring against deployed code.

## When to use

- After any phase ships to production (`/gsd-ship`)
- When user-facing behavior changes
- When integrating a new external service
- For non-programmers who cannot read stack traces — instrumented errors are the only way to know something broke

## Three-tool stack

| Tool | Purpose | Cost (small project) |
|---|---|---|
| Sentry | Runtime error capture (client + server) | Free up to 5k events/month |
| Posthog (or Plausible) | User-event funnel + session replay | Free up to 1M events/month |
| Playwright (e2e) | Pre-ship smoke tests against deployed URL | Free (just CI minutes) |

## Install order

1. **Sentry first** — without it, you're blind. Sign up at sentry.io, create project, get DSN.
2. **Playwright in CI** — before Posthog. One e2e per critical path catches more than 100 unit tests for non-programmer.
3. **Posthog last** — adds value only after Sentry catches errors and Playwright proves critical paths work.

## Sentry setup pattern

```bash
# Node/Next.js
npm install @sentry/nextjs
npx @sentry/wizard@latest -i nextjs
```

```bash
# Laravel
composer require sentry/sentry-laravel
php artisan sentry:publish --dsn=https://...
```

```bash
# Python (Django/FastAPI)
pip install --upgrade sentry-sdk
# Add Sentry.init(dsn=...) at app startup
```

Set `SENTRY_DSN` in production env vars only — never in client-side code without `tunnel` config (Sentry's CSP-aware proxy).

## Playwright setup pattern

```bash
npm install -D @playwright/test
npx playwright install --with-deps chromium
```

Minimal e2e for critical path:

```javascript
// tests/e2e/smoke.spec.js
const { test, expect } = require('@playwright/test');

test('homepage loads + critical CTA works', async ({ page }) => {
  await page.goto(process.env.PROD_URL);
  await expect(page.locator('h1')).toBeVisible();
  await page.click('text=Sign Up');
  await expect(page).toHaveURL(/.*signup/);
});
```

Run in CI on every PR + after every deploy.

## Posthog setup pattern

For SaaS / dashboards:

```html
<script>
  !function(t,e){var o,n,p,r;...
  posthog.init('YOUR_API_KEY',{api_host:'https://app.posthog.com'});
</script>
```

Track 3-5 critical events maximum:

- `signup_completed`
- `first_action_completed`
- `payment_succeeded`
- `error_seen` (paired with Sentry event ID)

## Reality check ritual

Before declaring `/gsd-ship` complete:

1. Sentry dashboard for last 1 hour: zero new errors? OK
2. Playwright `npm run test:e2e:prod` against deployed URL: green? OK
3. Posthog funnel: conversion rate within 10% of pre-ship baseline? OK

If any FAIL — rollback or investigate before claiming success. Toolkit's `reality-check` skill automates this.

## What NOT to instrument

- Don't capture PII in Sentry breadcrumbs (use `beforeSend` to scrub)
- Don't capture auth tokens, passwords, credit card numbers — Sentry's data scrubber catches some but verify
- Don't index sensitive code in Posthog session replay — exclude via `data-ph-no-capture` attribute
- Don't run Playwright against production with destructive actions (delete account, etc.) — use staging or dedicated test account

## Cross-references

- `components/cost-discipline.md` — observability has a cost; budget for it
- `templates/global/hooks/pre-ship-reality-check.sh` (PR 3) — automates this ritual
- `skills/reality-check/SKILL.md` (PR 2) — discipline pattern
