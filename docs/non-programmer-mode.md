# Non-Programmer Mode (v6.0)

This guide is for solo founders, designers, PMs, and operators who ship real products with Claude Code but do not write code themselves end-to-end. The goal: **right tool at the right time, never block, never pretend everything is fine when it isn't.**

## What "non-programmer" means here

You can read code well enough to spot obvious problems. You cannot:

- Tell whether a Sentry stacktrace is benign or critical without help
- Audit a Stripe integration line by line and confidently say "no PCI exposure"
- Decide whether a database migration is reversible
- Estimate whether a refactor is 1 day or 1 week of human-developer time

That is fine. v6.0 is built on the assumption that this is the default mode for solo product builders in 2026.

## Recommended install (all four steps)

```bash
# 1. Install the toolkit (auto-detects framework)
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)

# 2. Security pack (combined safety-net + Anthropic plugins)
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)

# 3. Advisory hooks (v6.0)
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-hooks.sh)

# 4. Cost routing (v6.0)
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-cost-routing.sh)
```

After step 4 your `~/.claude/CLAUDE.md` carries:

- Global security rules (forbidden patterns, doubt protocol, self-review checklist)
- Combined Bash hook (cc-safety-net + RTK)
- TK advisory hooks: pre-plan-council, post-phase-audit, pre-ship-reality-check, cost-warning
- better-model routing block: Haiku 4.5 / Sonnet 4.6 / Opus 4.7 per command

## Recommended workflow

### Small change, low risk

```text
You: "поправь опечатку в README"
Claude: invokes /gsd-fast (Haiku 4.5, ~$0.001/call)
```

Skip planning. Skip council. Skip audit. The advisory hooks won't fire — no high-stakes keywords.

### Medium change

```text
You: "добавь endpoint для users"
Claude: invokes /gsd-quick (Sonnet 4.6, ~$0.05/call)
```

Single-concern endpoint. No council needed. Hook may suggest `/audit security` after — accept it; takes ~30 sec.

### Large change with security implication

```text
You: "добавь Stripe billing"
Claude: invokes /gsd-plan-phase (Opus 4.7, ~$0.50/plan + $1-3/execute)
TK hook fires: "high-stakes (payment) detected — consider /council before execute"
You: /council
```

The council prompt routes to Gemini + ChatGPT for cross-AI validation of the plan. Costs ~$0.10 in API. Catches plan-level errors humans + single-LLM miss.

After execute, post-phase-audit hook suggests `/audit security && /audit code`. Run both.

Before deploy, pre-ship-reality-check hook fires when you push to main. Run the reality-check skill: Playwright e2e against prod URL, Sentry baseline, Posthog funnel. Don't skip — payment integrations are the #1 source of "shipped Friday, fired Monday" outages.

## Domain-expert simulation skill

When you don't have a domain expert on call, the `domain-expert-simulation` skill stands in. Trigger:

```text
You: "проверь — это безопасно?" (or "is this safe?")
Claude: loads skills/domain-expert-simulation/SKILL.md
        runs killer-question pass per relevant domain
        (auth / payments / db / infra / privacy / UX)
```

This is not a real expert. It's a checklist scaffold built from real expert review processes. It catches obvious misses (no rate limit on login endpoint, no idempotency key on payment, no unique index on the lookup column) but cannot replace a real review for high-stakes shipping.

## What v6.0 explicitly does NOT do

- **Auto-merges code.** Every code change is yours to accept or reject.
- **Auto-deploys.** Every ship operation requires explicit user confirmation. The reality-check hook only reminds, never blocks (unless `TK_HOOKS_BLOCK_SHIP=1`).
- **Auto-pays.** Every paid external tool (Morph, claude-context, better-model API consumption) requires explicit install + API key entry. No covert spend.
- **Replaces a real engineer for high-stakes work.** v6.0 catches what a careful checklist + multi-AI review can catch. It does not catch a subtle race condition in a distributed system. Get a human reviewer for those.

## Cost expectations (rough)

For a moderate product (lantern-class — 100k LOC, 5-10 features per month):

| Component | Monthly | Notes |
|---|---|---|
| Claude Code subscription | $20-200 | Max plan recommended |
| Anthropic API (council, agents) | $10-50 | Council ~$0.10/run, ~50 runs/month |
| Morph API | $20-100 | Token-efficient edits, scales w/ activity |
| claude-context (Milvus + Voyage) | $0-30 | Self-host Milvus; Voyage cheap |
| better-model | $0 | npm package, free, just routes |
| Sentry + Posthog (free tiers) | $0 | Free tier covers most solo products |

Total for a non-programmer-profile solo founder: **$50-380/month** on tooling, replacing what would otherwise be $5-15k/month in contractor or junior-dev time.

## When to step out of v6.0

Three triggers:

1. **You hire a real engineer.** They will want SP discipline + GSD workflow direct, not your overlay.
2. **You scale to multi-developer team.** TK is solo-developer optimized; team scenarios need different rule layers (CODEOWNERS, branch protection automation, etc.) which TK does not provide.
3. **You ship something where a single bug is unrecoverable.** Medical, financial, life-safety — get a real domain expert + real auditor, not a simulation skill.

For everything else, v6.0 is built to be the long-term default for the non-programmer solo profile.
