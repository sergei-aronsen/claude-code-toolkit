---
name: product-review
description: Multi-persona business review of a feature plan or SPEC. Parallel to /council but focused on product/marketing/economics, not technical correctness. Invokes product-thinking skill if `.planning/product/<slug>.md` is missing, then runs persona review.
---

# /product-review — Multi-Persona Business Review

## Purpose

Solo founders don't have a product manager, a CMO, a CFO, or a target user
in the room. This command simulates that room — four personas review the
feature from four orthogonal angles and produce explicit verdicts.

Parallel to `/council` (which reviews technical correctness). `/product-review`
reviews **business correctness**.

## When to Use

- Before committing to a major feature build (≥ 1 week of work)
- Before pricing or billing changes
- Before launching to a new market segment
- Before pivot or major direction shift
- After cheapest experiment runs — to decide build / kill / iterate

NOT for:

- Trivial bug fixes
- Internal refactors
- Visual polish (use UI review skills instead)

## Usage

```text
/product-review "feature description"
/product-review .planning/product/<slug>.md
/product-review --lite "feature description"
```

Flags:

- `--lite` — 3-question fast review (skip CFO + Marketer if no pricing/channel concerns)
- `--persona <name>` — run only one persona (skeptic / marketer / cfo / user-empath)
- `--council` — combine with `/council` technical review in one report

## Procedure

1. **Idempotency** — derive `<feature-slug>` from input. Check
   `.planning/product/<slug>.md`. If missing → invoke `product-thinking` skill
   first. If present → use as input.

2. **Personas activated** (parallel):
   - **product-skeptic** — devil's advocate, attacks the idea from every angle
   - **marketer-pragmatist** — "how do I sell this? what's the channel? what's the message?"
   - **cfo-pragmatist** — "does the math work? what's CAC, LTV, payback?"
   - **user-empath** — "as the actual target user, would I use this? when? why?"

3. **Each persona produces:**
   - Verdict: APPROVED / REVISE / REJECT
   - Top 3 concerns
   - Suggested changes
   - Confidence (high/medium/low)

4. **Aggregation:**
   - If all 4 APPROVED → status `validated`
   - If 1+ REJECT → status `needs-revision` with consolidated changes
   - If mixed → status `needs-experiment` with explicit decision rule

5. **Output:** `.planning/product/review-<slug>-YYYY-MM-DD.md`

## Persona files

Located in `templates/council-prompts/personas/`:

- `product-skeptic.md`
- `marketer-pragmatist.md`
- `cfo-pragmatist.md`
- `user-empath.md`

Customize per project for sharper feedback.

## Output format

```markdown
# Product Review: <Feature Name>

**Date:** YYYY-MM-DD
**Input:** .planning/product/<slug>.md
**Aggregated status:** validated | needs-revision | needs-experiment | rejected

## Persona verdicts

| Persona | Verdict | Confidence | Top concern |
|---------|---------|------------|-------------|
| product-skeptic | APPROVED / REVISE / REJECT | high/med/low | <one line> |
| marketer-pragmatist | ... | ... | ... |
| cfo-pragmatist | ... | ... | ... |
| user-empath | ... | ... | ... |

## Consolidated changes (if any REVISE / REJECT)

1. <specific change>
2. <specific change>
3. <specific change>

## Persona reports

### product-skeptic

<full report>

### marketer-pragmatist

<full report>

### cfo-pragmatist

<full report>

### user-empath

<full report>

## Decision

<final decision with reasoning>

## Handoff

- If `validated` → `/gsd-discuss-phase`
- If `needs-revision` → revise `.planning/product/<slug>.md`, re-run `/product-review`
- If `needs-experiment` → run cheapest experiment first
- If `rejected` → save lessons to `.claude/rules/lessons-learned.md`
```

## Integration with /council

`/product-review --council` runs both:

1. `/product-review` (4 product personas)
2. `/council` (technical Gemini + ChatGPT review)

Output combined report. Useful for high-stakes decisions (new product line,
pivot, $10k+ build commitment).

## Cost

Uses Council infrastructure (Gemini + ChatGPT API). Cost ~$0.05-0.20 per
review depending on input size. Tracked in `~/.claude/council/usage.jsonl`.

Run `/council-stats` to see cumulative cost.
