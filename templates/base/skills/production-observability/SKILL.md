---
name: production-observability
description: Use after deploying a phase to production, when integrating new external services, or when user-facing behavior changes — instruments runtime errors (Sentry), user funnels (Posthog), and pre-ship smoke (Playwright)
---

# Production Observability

## Why this skill exists

GSD verifies plan-vs-spec consistency. It does NOT verify product-vs-reality. Code passes all gates, ships to prod, and breaks for users — silently — until you hear about it from support.

**Iron law:** If a phase ships to production without observability instrumentation, you have NOT shipped quality. You shipped hope.

## When this skill activates

- After `/gsd-execute-phase` complete, before `/gsd-ship`
- When user mentions: "ship", "deploy", "release", "production", "monitor"
- When integrating: payments, auth, third-party API, anything that talks to external service
- When user-facing UI changes (ANY change visible to end users)

## Three-tool minimum

```text
1. Sentry        — runtime error capture (zero-config catches 90% of crashes)
2. Playwright    — pre-ship smoke against deployed URL (catches deploy-time regressions)
3. Posthog/etc.  — user-event funnel + session replay (catches "looks fine but conversion dropped")
```

Skipping ANY of these = blind deploy.

## Pre-ship checklist

Before running `/gsd-ship`:

1. **Sentry instrumented?**
   - Server-side: `Sentry.init(dsn=...)` at app startup
   - Client-side: SDK loaded in HTML head OR via Next.js wizard
   - Source maps uploaded for stack traces

2. **Playwright e2e for critical path exists?**
   - At minimum: load homepage, click primary CTA, verify next page
   - For SaaS: signup flow + first action + payment (if applicable)
   - Runs in CI, not optional

3. **Posthog (or similar) tracking critical events?**
   - 3-5 events maximum: `signup_completed`, `first_action`, `payment_succeeded`, `error_seen`
   - Funnel built on Posthog dashboard, monitored

If any answer is NO — instrument BEFORE shipping. Not after.

## Post-ship verification ritual

Within 1 hour of ship:

```text
1. Sentry dashboard — zero new errors in last hour? OK
2. Playwright in CI — green run against deployed URL? OK
3. Posthog funnel — conversion rate within 10% of pre-ship baseline? OK
```

If ANY red — rollback or investigate. Don't wait for users to report.

## Anti-patterns

- ❌ "I'll add observability after launch" — never happens
- ❌ "It's just a small change" — small changes cause biggest outages
- ❌ "We have logs" — logs ≠ observability (no aggregation, no alerting, no replay)
- ❌ "Sentry is too expensive" — outage from missing it costs more
- ❌ Capturing PII in Sentry breadcrumbs — use `beforeSend` to scrub
- ❌ Posthog session replay on auth flows — exclude via `data-ph-no-capture`

## Cost reality check

Free tiers cover most solo projects:

- Sentry: 5k errors/month free
- Posthog: 1M events/month free
- Playwright in GitHub Actions: 2000 free CI minutes/month

Estimated monthly cost for typical solo SaaS: $0-30 for first 6 months, scales with usage.

## Reference

- `components/production-observability.md` — full setup patterns per stack
- `templates/global/hooks/pre-ship-reality-check.sh` (PR 3) — automated pre-ship check
- `skills/reality-check/SKILL.md` — post-ship validation discipline
