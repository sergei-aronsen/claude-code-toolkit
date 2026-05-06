---
name: reality-check
description: Use after `/gsd-ship` to verify product behaves correctly in production — runs Playwright e2e against deployed URL, checks Sentry for new errors, validates Posthog conversion funnel
---

# Reality Check (Post-Ship)

## Iron law

```text
NO SHIP IS COMPLETE WITHOUT RUNTIME VERIFICATION AGAINST PRODUCTION.
```

Code merged + CI green + deploy succeeded ≠ feature works for users. Reality check is the only thing that proves it.

## When this skill activates

- Immediately after `/gsd-ship` completes
- When user says: "did it work", "verify deploy", "check prod"
- 24 hours after ship for delayed regression check
- After ANY hotfix to production

## The procedure

### Step 1: Smoke test (within 1 minute of deploy)

Run Playwright e2e against deployed URL, NOT localhost:

```bash
PROD_URL=https://yourapp.com npm run test:e2e:prod
```

Expected: green. If red — rollback immediately, investigate next.

### Step 2: Error rate (within 1 hour)

Check Sentry dashboard for last 1 hour vs last 24 hours baseline:

```text
Last 1h errors: N
Last 24h average / hour: M

If N > 2*M  → red flag, investigate
If N > 5*M  → rollback now
```

### Step 3: User behavior (within 6 hours)

Check Posthog (or similar) for conversion rate change on critical funnel:

```text
Pre-ship baseline (avg of last 7 days): 12.3% signup→first-action
Post-ship 6h window: 11.8% (within ±1%)  → OK
Post-ship 6h window: 8.1%  → red flag
Post-ship 6h window: <5%  → rollback
```

### Step 4: 24-hour delayed regression

Some bugs surface after timezone rollover, weekly cron jobs, or batch processes. Check at 24h post-ship:

- Sentry error count for last 24h (full day cycle)
- Customer support tickets count
- Posthog funnel for full day

## Tooling

- **Playwright** — pre-ship smoke + post-ship runtime smoke
- **Sentry** — error monitoring (set up SLO alerts: page on >5× baseline)
- **Posthog** — funnel monitoring (alert on >20% conversion drop)
- **Plausible** — alternative to Posthog (privacy-first, simpler)

If any of these are NOT installed — see `skills/production-observability/SKILL.md` first. Reality check requires observability infrastructure.

## What to do when red

```text
Step 1 (Playwright fail)  →  Rollback. Investigate logs. Hotfix or revert.
Step 2 (Sentry spike)     →  Triage top error. If user-facing: rollback. If internal: hotfix.
Step 3 (conversion drop)  →  Don't rollback yet. Check session replay. Often UX bug, not crash.
Step 4 (delayed)          →  Same triage as Step 2/3 but with more context.
```

## Anti-patterns

- ❌ Trusting CI green to mean "shipped successfully" — CI tests staging, not production
- ❌ "We'll watch it" — no concrete time window = will be forgotten
- ❌ Reality check only on big releases — small releases cause big outages
- ❌ Skipping reality check because "it's a config change" — config changes cause biggest outages
- ❌ Running Playwright against staging instead of prod — staging ≠ prod

## Toolkit hook

`templates/global/hooks/pre-ship-reality-check.sh` (PR 3) automates Steps 1-2 BEFORE allowing `/gsd-ship` to complete. If you have it installed: GSD will block ship if Sentry shows recent errors or Playwright fails.

## Cross-references

- `skills/production-observability/SKILL.md` — instrumentation discipline (prerequisite)
- `components/production-observability.md` — setup patterns per stack
- `templates/global/hooks/pre-ship-reality-check.sh` (PR 3) — automation
