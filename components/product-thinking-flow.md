# Product Thinking Flow

Solo-founder workflow: validate → experiment → spec → plan → build → audit.

## The full cycle

```text
[Idea]
   ↓
product-thinking skill (auto-trigger on "build/MVP/ship/pricing")
   ↓
   AskUserQuestion interview (8-9 questions, full mode)
   OR
   Lite mode (3 questions for trivial changes)
   ↓
.planning/product/<feature-slug>.md
status: validated | needs-experiment | rejected | risk-accepted
   ↓
If status = validated:           → /gsd-discuss-phase
If status = needs-experiment:    → run experiment first, return to skill with results
If status = rejected:            → save lesson, stop
If status = risk-accepted:       → /gsd-discuss-phase with documented risk
   ↓
Optional: /product-review (4 personas: skeptic + marketer + cfo + user-empath)
   ↓
.planning/product/review-<slug>-<date>.md
   ↓
/gsd-discuss-phase   → SPEC.md (technical questions)
   ↓
/gsd-plan-phase      → PLAN.md (implementation breakdown)
   ↓
/gsd-execute-phase   → code (with TDD via Superpowers skill)
   ↓
/audit               → security/perf/code review
   ↓
/learn               → save successful patterns to .claude/rules/
```

## Trigger surface

| Skill / command | Trigger | Mode |
|-----------------|---------|------|
| `product-thinking` | Auto on "build/MVP/ship/pricing/launch/pivot" keywords | Soft skill |
| `/product-review` | Manual invocation | Hard command |
| `product-gate.sh` UserPromptSubmit hook | Auto on keyword detection | Suggest, not block |
| GSD `/gsd-discuss-phase` | Reads `.planning/product/<slug>.md` if present | Integration |

## Status decision tree

```text
Has clear target user?    No → REJECTED (no JTBD)
                          Yes ↓
Has pain intensity (urgent/frequent/expensive/embarrassing)?
                          No → REJECTED (nice-to-have)
                          Yes ↓
Has measurable 30-day metric?
                          No → REJECTED (undefined "done")
                          Yes ↓
Has named distribution channel with plan?
                          No → REJECTED (distribution risk = death)
                          Yes ↓
If pricing involved: LTV/CAC > 3?
                          No → REJECTED (broken economics)
                          Yes ↓
If pricing involved: B2B price ≥ $1000/yr or B2C ≤ $100/mo?
                          No → REJECTED (SaaS graveyard)
                          Yes ↓
Has cheapest experiment with decision rule?
                          No → NEEDS-EXPERIMENT
                          Yes ↓
                          VALIDATED → /gsd-discuss-phase
```

User can override any REJECTED → `risk-accepted` with explicit acknowledgment.

## File hierarchy

```text
.planning/
├── product/
│   ├── <feature-slug>.md           # validation gate output
│   ├── review-<slug>-<date>.md     # /product-review output (optional)
│   └── ...
├── specs/                          # /gsd-discuss-phase output
│   └── SPEC-<feature>.md
├── plans/                          # /gsd-plan-phase output
│   └── PLAN-<feature>.md
└── audits/
    ├── vendor-changelog-<date>.md
    └── audit-<feature>-<date>.md
```

## Anti-fatigue mechanisms

The skill is designed to NOT become bureaucracy:

1. **Idempotency** — if file exists, skill reads it, does not re-interview
2. **History prefill** — last 3 product files prefill target user + channel
3. **Lite mode** — 3 questions for trivial changes (button rename, copy fix)
4. **Domain config** — `~/.claude/product-config.json` removes generic gates,
   uses your real ICP/pricing/advantages
5. **Risk-accepted escape hatch** — solo founder can override gate with
   documented acknowledgment

## When NOT to invoke

The skill should auto-skip for:

- Bug fixes (even if the bug affects a feature)
- Internal refactors with no user-facing change
- Documentation updates
- Test additions
- Linting/formatting fixes
- Dependency upgrades (use `/update-deps` instead)
- Security patches (use `/audit` or `/security-review` instead)

If user explicitly asks for product validation on these → use lite mode.

## Customization for your stack

Each framework template can add stack-specific product hooks (v6.4+):

| Stack | Additional questions |
|-------|----------------------|
| Laravel SaaS | Multi-tenant onboarding, subscription tiers, churn |
| Next.js | SEO landing, Core Web Vitals, conversion funnel |
| Mobile (RN/native) | App Store ASO, retention curves, push opt-in rate |
| API | DX, time-to-first-call, dev adoption metrics |

For v6.3, only base skill ships. Stack overrides land in v6.4.

## Integration with Council

`/council` reviews **technical** correctness.
`/product-review` reviews **business** correctness.

For high-stakes decisions, run both:

```text
/product-review --council
```

Aggregated report covers both axes.

## Hidden risks

1. **Validation theater** — filling the markdown gives false sense of "validated".
   Real validation = a paying customer. The file is hypothesis, not proof.
2. **Gate-and-go** — user fills file once, never updates with experiment results.
   Encourage updating after experiment runs.
3. **Prompt fatigue** — after 2 weeks user may resent the skill. Mitigate via
   lite mode and history prefill.
4. **Bypass abuse** — if user always uses `risk-accepted`, the skill becomes
   noise. Track frequency in `.planning/product/_audit.md`.

Surface these in the skill's output when relevant.
