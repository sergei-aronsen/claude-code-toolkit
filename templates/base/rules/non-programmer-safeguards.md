---
description: Pre-ship ritual for non-programmer profile — domain expert simulation, "what breaks for users", reality-check trigger, no-silent-deploys
globs:
  - "**/*"
---

# Non-Programmer Safeguards

> Auto-loaded for every session. Compensates for missing peer review in solo + AI workflow.

## Pre-ship checklist (mandatory)

Before invoking `/gsd-ship` or merging to main, answer ALL of these:

1. **What breaks for users if this is wrong?**
   - If "I don't know" → STOP. Go back to `/gsd-discuss-phase` or `/gsd-plan-phase` to clarify spec.
   - If "nothing user-facing" → continue, but instrument logs for internal observability.

2. **What would Senior $DOMAIN say?**
   - Trigger `domain-expert-simulation` skill
   - Apply killer questions for relevant domain (auth/payments/db/infra/privacy/UX)
   - Fix anything found, don't dismiss as edge case

3. **Is observability instrumented?**
   - Sentry catching server + client errors?
   - Playwright e2e covers critical path?
   - Posthog (or alternative) tracks conversion events?
   - If NO → install per `skills/production-observability/SKILL.md` BEFORE ship

4. **Does reality match plan?**
   - GSD verifies plan ↔ spec
   - Toolkit `reality-check` verifies product ↔ reality
   - Trigger `skills/reality-check/SKILL.md` post-ship

## Hard blocks

NEVER ship if ANY of these are true:

- Test suite red (CI failed)
- Security audit produced HIGH or CRITICAL findings
- Database migration not tested against prod-shaped data
- Auth/payment changes shipped without `/council` external review
- No rollback path defined ("how do I undo this in 60 seconds?")
- User says "looks weird" without investigation

## Soft warnings (proceed only with explicit ack)

These are not auto-blocks but require user acknowledgment:

- Coverage <80% on changed code
- New dependencies added (check vendor-risk.md)
- Performance regression >10% on key endpoint
- New external API call (rate limits? error handling? timeouts?)

## Domain-specific extras

### For auth/payments/billing changes

- `/council` mandatory (not optional)
- Domain expert simulation as Security Engineer + Payment Engineer
- Idempotency check (double-click protection)
- Failure-mode review (what if half completes?)

### For database migrations

- Tested against prod-shaped data (volume + indexes)
- Backwards-compat for in-flight requests during deploy
- Index added BEFORE column (else table lock)
- Rollback script exists and tested

### For public API breaking changes

- Versioned (e.g., /v2/users) or deprecation period announced
- All consumers identified and notified
- Migration guide written

## Why these rules exist

User is solo + non-programmer building real products. They cannot:

- Read 200-line stack traces and find root cause
- Spot "wait, this is unsafe" patterns in code review
- Predict scaling failure modes from architectural diagrams
- Catch idempotency bugs in payment flows
- Verify GDPR compliance in data handling

These safeguards = compensating controls. They don't replace expertise — they make expertise scaling tractable for solo developers + AI.

## When to override

User MAY override (but should explicitly):

- Personal/throwaway projects (no users to break for)
- Internal tools (no compliance/security exposure)
- Experimental branches (not for prod)

User MAY NOT override:

- Production deploys to apps with paying users
- Anything touching auth, payments, PII
- Public APIs

## Cross-references

- `components/domain-expert-simulation.md`
- `skills/domain-expert-simulation/SKILL.md`
- `skills/reality-check/SKILL.md`
- `skills/production-observability/SKILL.md`
- `commands/council.md`
- `templates/global/hooks/pre-ship-reality-check.sh` (PR 3)
