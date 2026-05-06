# Domain Expert Simulation

> Non-programmer cannot do code review themselves. Domain expert simulation = ask Claude to roleplay a senior practitioner before declaring work done. Compensates for missing peer review.

## When to use

- Before `/gsd-ship` on any business-critical phase
- After implementation but before merging to main
- When the change touches a domain you're not expert in (auth, payments, infra, security, scaling)
- When user feedback says "feels off" but you can't articulate why

## The pattern

1. **Identify the domain** — auth specialist? Payment systems engineer? DBA? Infrastructure SRE? Privacy lawyer?
2. **Frame the simulation** — "You are a Senior X with 10 years experience. Review this change with the eye of someone who has been burned by these mistakes."
3. **Ask the killer question** — "What would make you reject this PR?"
4. **Listen to the answer** — don't defend, fix.

## Domain-specific killer questions

### Auth/security

- "What attack vectors did this NOT consider? Token replay? CSRF? Rate-limit bypass?"
- "If a hostile user finds this endpoint, what's the worst case?"
- "Is the failure mode safe (deny by default) or unsafe (allow by default)?"

### Payments

- "What happens on partial failure? Money taken but order not created?"
- "Idempotency — what if user clicks twice?"
- "Decimal arithmetic correct? Or float-rounding bug?"
- "Refund flow — does it cover all edge cases (chargebacks, disputes, fraud)?"

### Database / migrations

- "Will this migration lock the table on a 100M-row prod DB?"
- "If it fails halfway — is rollback automatic or manual?"
- "Are indexes added BEFORE or AFTER the column they index? (BEFORE causes table lock)"
- "Does schema change preserve backwards-compat for old API clients?"

### Infrastructure / scaling

- "What breaks at 10× current load? 100×?"
- "Single point of failure — where?"
- "Cache invalidation — eventual consistency OK or strict?"
- "Cross-region: latency, data residency, GDPR?"

### Privacy / compliance

- "Does this log PII anywhere (Sentry, Posthog, app logs)?"
- "GDPR right-to-be-forgotten — can user data actually be purged?"
- "Cross-border data transfer — Schrems II compliant?"
- "Cookie consent — does this trigger?"

### UX / accessibility

- "Keyboard-only navigation works?"
- "Screen reader announces state changes?"
- "Color contrast WCAG AA?"
- "Mobile users — tap target ≥44px?"
- "Loading state for slow connection?"

## Anti-patterns

### Performance theater

- ❌ Asking simulation just to validate your design
- ✅ Asking simulation to find what's wrong

### Cherry-picking

- ❌ Discarding answers that disagree with you
- ✅ Treating disagreement as red flag worth investigating

### Single perspective

- ❌ Asking only one domain expert
- ✅ Asking 2-3 different domain experts on critical changes (auth: security + privacy + UX)

### Vague framing

- ❌ "Review this change"
- ✅ "Review this change as a Senior Payment Systems Engineer who has been on-call during a Black Friday outage"

## Example: payment endpoint review

```text
You are a Senior Payment Systems Engineer with 10 years at Stripe and PayPal.

Review this endpoint:

[paste code or PR diff]

Specifically check:
1. Idempotency — duplicate-charge protection?
2. Failure modes — what state does the system end in if X fails?
3. Audit trail — can you trace any payment to its origin?
4. Refund path — covers all edge cases (chargebacks, disputes, fraud)?
5. Money math — decimal arithmetic, no floats?

Reject any concern as "edge case" only if it can NEVER happen in production.
```

Then **fix what you find.** Don't dismiss as "nitpick" — Senior X knows things you don't.

## Combining with /council

For high-stakes phases (auth, payments, breaking API):

1. Domain expert simulation (cheap, fast — single Claude session)
2. THEN `/council` (Gemini + GPT external review — expensive, thorough)

Two layers catch different classes of issues. Domain simulation catches domain-specific failure modes. Council catches architectural/design issues across providers.

## Toolkit skill

`skills/domain-expert-simulation/SKILL.md` (PR 2) implements this as a discipline skill triggered by keywords like "review my", "is this safe", "can you check".

## Cross-references

- `components/audit-fp-recheck.md` — for code-level review (different layer)
- `components/supreme-council.md` — multi-LLM external review
- `rules/non-programmer-safeguards.md` (PR 2) — auto-trigger before ship
