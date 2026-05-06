# Vendor Risk Audit

> Quarterly review of external dependencies. Catches vendor drift before it becomes an incident.

## What to review

The toolkit overlay depends on multiple external systems. Each has different vendor risk profile:

| Vendor | What we depend on | Risk type |
|---|---|---|
| GSD (gsd-build) | Phase workflows + verification gates | Maintainer drift, $GSD memecoin pivot |
| Superpowers (obra) | Discipline skills (TDD, debug, brainstorm) | Single maintainer (Jesse Vincent) |
| Anthropic (Claude API) | Model availability + pricing | Pricing changes, model deprecation |
| Morph LLM | Fast Apply + warpgrep MCP | Paid API, vendor pricing pivot |
| better-model (talkstream) | Cost routing matrix | Single maintainer, low star count |
| claude-context (zilliztech) | Vector DB MCP | Org-backed but Zilliz cloud free tier ToS shifts |

## Quarterly review checklist

For each vendor, check:

### 1. Maintainer health

```bash
# When was last meaningful commit?
gh api repos/<org>/<repo>/commits/main | jq -r '.commit.committer.date'

# Are PRs being reviewed/merged?
gh pr list --repo <org>/<repo> --state open --limit 10
```

Red flag: no commits in 60+ days AND open PRs accumulating.

### 2. Funding/business signals

- Did maintainer launch a token/memecoin recently? (e.g., $GSD on Solana — signals priority shift)
- Did they pivot to SaaS+lock-in (e.g., affaan-m/everything-claude-code's `ecc.tools`)?
- Did the company get acquired? Layoffs? Open roles closed?

### 3. Breaking change cadence

- More than 1 breaking release per month = unstable upstream
- Look for migration scripts in last 5 releases — frequent migrations = volatility
- Check CHANGELOG.md for "BREAKING" keyword count over last quarter

### 4. Security posture

- Are CVEs filed/fixed promptly?
- Does the project have a SECURITY.md?
- Are dependencies pinned (lockfiles)?
- For MCP servers: do they handle credentials securely?

### 5. Alternative readiness

For each vendor — what's the exit plan if they pivot or go away?

| Vendor | Exit alternative |
|---|---|
| GSD | Pure Superpowers (90% of GSD's discipline value) + toolkit/audit + framework templates |
| Superpowers | GSD covers most discipline; or pocock/skills (lighter, anti-GSD design) |
| Anthropic | OpenAI/Google as backup (toolkit's `/council` already supports both) |
| Morph | Native Edit tool + claude-context for search (slower, more expensive) |
| better-model | Manual routing rules in CLAUDE.md (matrix is markdown, not Node) |
| claude-context | Self-hosted Milvus + Voyage embedding; or fallback to ripgrep + Read |

## Migration cost estimate

When forced to switch:

| Scenario | Effort |
|---|---|
| GSD → pure Superpowers | ~1-2 days (rewrite phase workflows as plans) |
| Superpowers → GSD | ~2-3 days (replicate IRON LAW patterns in custom skills) |
| Anthropic → OpenAI | ~1 day for /council; main session is provider-bound |
| Morph → native | Free (just disable MCP) but +$50-100/mo on edit costs |
| better-model → manual | ~30 min (paste matrix into CLAUDE.md manually) |
| claude-context → self-host | ~1 day (Docker Compose + Milvus + Ollama embeddings) |

## When to act on a red flag

Don't switch on first warning. Wait for **2+ signals** to converge:

- Memecoin launch + zero new features in 30 days = likely pivot
- Single maintainer + acquisition rumor + license change pending = high risk
- Breaking change weekly + open issues accumulating = abandonware trajectory

## Ad-hoc triggers (don't wait quarterly)

Run vendor review immediately if:

- Public security incident at vendor (breach, leak)
- License change announced
- Maintainer publicly stops the project
- Pricing model changes >2× overnight

## Toolkit /vendor-audit command

The `/vendor-audit` slash command (PR 2) automates checks 1-3 across all 6 vendors. Run quarterly — first Monday of each quarter is a good cadence.

## Cross-references

- `commands/vendor-audit.md` (PR 2) — slash command
- `docs/research/gsd-vs-alternatives-2026-05-06.md` — original vendor analysis
- `components/external-tools-recommended.md` — exit plan summary table
