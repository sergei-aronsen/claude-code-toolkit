---
name: domain-expert-simulation
description: Use before declaring work complete on business-critical phases — simulate a Senior practitioner (auth specialist, payment engineer, DBA, security auditor) reviewing the change with their failure-mode bias
---

# Domain Expert Simulation

## Why this skill exists

Non-programmer cannot do code review themselves. They lack domain expertise to spot what's missing. Simulating a Senior practitioner mid-review compensates: Claude has seen the patterns AND the failure modes.

This is NOT performance theater ("look how thorough we are"). It's a structured search for what's wrong.

## When this skill activates

- Before `/gsd-ship` on auth, payments, infra, security, or privacy changes
- After implementation but before merging to main
- When change touches a domain user is not expert in
- When user says: "is this safe", "review my", "can you check", "что я пропустил"

## The pattern

1. **Identify the domain** — most relevant Senior role
2. **Frame the simulation** — "You are Senior X with 10 years experience. You have been burned by these mistakes."
3. **Ask the killer question** — "What would make you reject this PR?"
4. **Listen to the answer** — don't defend, fix.

## Domain killer questions

### Auth / security

- What attack vectors did this NOT consider? Token replay? CSRF? Rate-limit bypass?
- If a hostile user finds this endpoint, what's the worst case?
- Is the failure mode safe (deny by default) or unsafe (allow by default)?

### Payments

- What happens on partial failure? Money taken but order not created?
- Idempotency — what if user clicks twice?
- Decimal arithmetic correct? Or float-rounding bug?
- Refund flow — chargebacks, disputes, fraud — covered?

### Database / migrations

- Will this lock the table on a 100M-row prod DB?
- If migration fails halfway — automatic rollback or manual?
- Indexes BEFORE or AFTER the column? (BEFORE = table lock)
- Backwards-compat for old API clients during deploy?

### Infrastructure / scaling

- What breaks at 10× current load? 100×?
- Single point of failure — where?
- Cache invalidation — eventual consistency OK or strict required?
- Cross-region: latency, data residency, GDPR?

### Privacy / compliance

- Does this log PII anywhere (Sentry, Posthog, app logs)?
- GDPR right-to-be-forgotten — can user data actually be purged?
- Cross-border data transfer — Schrems II compliant?
- Cookie consent — does this trigger?

### UX / accessibility

- Keyboard-only navigation works?
- Screen reader announces state changes?
- Color contrast WCAG AA?
- Mobile users — tap target ≥44px?
- Loading state for slow connection?

## Simulation framing template

```text
You are a Senior [DOMAIN] Engineer with 10 years experience at [COMPANY-PEER].
You have been on-call during [SPECIFIC-OUTAGE-TYPE] outages.

Review this change:

[paste code or PR diff]

Specifically check:
1. [Domain killer question 1]
2. [Domain killer question 2]
3. [Domain killer question 3]

Reject any concern as "edge case" only if it can NEVER happen in production.
```

Then **fix what you find.** Don't dismiss as "nitpick" — Senior X knows things you don't.

## Combining with /council

For high-stakes phases (auth, payments, breaking API):

1. **Domain expert simulation** — fast, cheap, single Claude session
2. **THEN /council** — Gemini + GPT external review

Two layers catch different classes of issues:

- Domain simulation: domain-specific failure modes
- Council: architectural/design issues across providers

Run both for security or money phases.

## Anti-patterns

- ❌ Performance theater (asking simulation just to validate your design)
- ✅ Asking simulation to find what's wrong

- ❌ Cherry-picking (discarding answers that disagree)
- ✅ Treating disagreement as red flag worth investigating

- ❌ Single perspective on critical change
- ✅ Multiple domain experts on auth/payments (security + privacy + UX)

- ❌ Vague framing: "Review this change"
- ✅ Specific framing: "Review as Senior Payment Systems Engineer who has been on-call during Black Friday outage"

## When NOT to use

- Pure refactoring (no behavior change)
- Doc updates
- Dev tooling changes
- Internal scripts (no user impact)

For these, regular code review or `/audit code` is enough.

## Cross-references

- `components/domain-expert-simulation.md` — full method
- `components/supreme-council.md` — multi-LLM external review (next layer)
- `rules/non-programmer-safeguards.md` — auto-trigger before ship
- `commands/audit.md` — code-level audit (different layer)
