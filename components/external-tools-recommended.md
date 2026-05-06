# External Tools — Recommended

> Toolkit v6.0 doesn't bundle these. They're recommended via the MCP wizard (`scripts/lib/integrations-catalog.json`) and standalone setup scripts (`scripts/setup-cost-routing.sh`). User opts in.

## Decision matrix

| Tool | Always install | Conditional install | Skip when |
|---|---|---|---|
| Morph MCP | Yes — Fast Apply edits + warpgrep search | — | Single-developer cost-sensitive project with <50k LOC and rare edits |
| better-model (npm) | Yes — for cost routing | — | Subscription-only Anthropic users (Pro plan) |
| claude-context MCP | — | Codebase >100k LOC + non-sensitive OR self-hosted Milvus | Codebase <100k LOC OR sensitive code without self-host |

## Install order

Order matters because better-model injects `model:`/`effort:` frontmatter into existing agents/skills. Install in this sequence:

```text
1. GSD plugin             →  claude plugin install get-shit-done@gsd-build
2. Superpowers plugin     →  claude plugin install superpowers@claude-plugins-official
3. Toolkit (this repo)    →  bash <(curl -sSL .../init-claude.sh)
4. Morph MCP              →  toolkit MCP wizard
5. better-model           →  scripts/setup-cost-routing.sh (npx better-model init)
6. claude-context (opt)   →  toolkit MCP wizard (with security warnings)
```

Skipping order = better-model has nothing to inject into = lower coverage of routing rules.

## Morph MCP

**Purpose:** Fast Apply (replaces native Edit) + warpgrep_codebase_search.

**Cost:** Pay-per-use. ~$0.001 per edit, ~$0.005 per warpgrep query. Typical solo developer: $10-30/month.

**Why critical for solo + GSD:**

- GSD generates many edits per phase
- Native Edit pays Claude full-rewrite tokens per file
- Fast Apply uses specialized model: 5-10× cheaper, 10× faster
- ROI breakeven: ~30 edits/day

**Setup via toolkit MCP wizard:**

```bash
# Wizard prompts for MORPH_API_KEY
bash scripts/init-claude.sh
# Select Morph from MCP catalog → enter API key → done
```

**Manual setup:**

```bash
claude mcp add morph-fast-tools \
  -e MORPH_API_KEY=sk-... \
  -e ALL_TOOLS=true \
  -- npx @morphllm/morphmcp
```

## better-model

**Purpose:** Routes subagent tasks to right model (Sonnet for coding, Opus for architecture, Haiku for search).

**Cost:** Free (npm package). Saves $50-200/month by avoiding Opus on routine tasks.

**Why critical:**

- Default Anthropic UI sends every subagent to Opus
- ~80% of subagent work doesn't need Opus quality
- Sonnet 4.6 is 5× cheaper at ~91% quality on coding
- Haiku 4.5 is 25× cheaper for search/grep

**Install:**

```bash
# Via toolkit setup script (after toolkit + GSD + Superpowers + Morph installed)
bash scripts/setup-cost-routing.sh

# OR manually
npx better-model@latest init
```

## claude-context MCP

**Purpose:** Semantic codebase search via vector DB.

**Cost:** $1-5 one-time embed per 100k LOC + $0/month queries (Zilliz Cloud free tier) or self-hosted Milvus (free).

**When:** Codebase >100k LOC AND active development AND not sensitive code on Zilliz free tier.

**See `components/large-codebase-search.md`** for full setup, security warnings, self-hosted Milvus instructions, and Voyage AI / Ollama alternatives for sensitive code.

## What if a vendor pivots

`commands/vendor-audit.md` (PR 2) is a quarterly review that catches vendor drift. If any of these tools become unreliable:

| Tool gone | Fallback |
|---|---|
| Morph | Native Edit (slower, more expensive) + claude-context for search OR ripgrep + Read |
| better-model | Manual routing rules in CLAUDE.md (matrix is markdown — copy from better-model repo) |
| claude-context | Self-hosted Milvus + Voyage AI / Ollama embedding OR fallback to Morph warpgrep / ripgrep |

Toolkit detects vendor health via `/vendor-audit`. Run quarterly.

## Cost summary for a typical solo developer

For someone building lantern (144k LOC) + jobbhunter (53k LOC) + notebooklm-ultra (305k LOC):

| Setup | Monthly | Annual |
|---|---|---|
| Anthropic API (with discipline + better-model) | $100-200 | $1,200-2,400 |
| Morph MCP | $20-40 | $240-480 |
| claude-context (self-hosted, OpenAI embed) | $5-10 | $60-120 |
| TOTAL | $125-250 | $1,500-3,000 |

Without better-model + Morph: estimate 3-5× higher = $375-1,250/month = $4,500-15,000/year.

The toolkit is paid for in cost savings within first month.

## Cross-references

- `components/cost-discipline.md` — mode selection per task size
- `components/large-codebase-search.md` — claude-context deep-dive
- `commands/vendor-audit.md` — quarterly vendor risk review
- `scripts/setup-cost-routing.sh` (PR 5) — better-model installer
