# External Tools — Recommended

> Toolkit doesn't bundle these. They're recommended via the MCP wizard
> (`scripts/lib/integrations-catalog.json`) and standalone setup scripts
> (`scripts/setup-cost-routing.sh`). User opts in.

## Decision matrix

| Tool | Always install | Conditional install | Skip when |
|---|---|---|---|
| Serena MCP | Yes — symbol-aware code navigation + edit | — | Tiny scripting projects (<5k LOC) where the native Edit/Grep tools cover everything |
| better-model (npm) | Yes — for cost routing | — | Subscription-only Anthropic users (Pro plan) |
| claude-context MCP | — | Codebase >100k LOC + non-sensitive OR self-hosted Milvus | Codebase <100k LOC OR sensitive code without self-host |

Morph MCP was removed in v6.1 — see "Why we dropped Morph" below.

## Install order

Order matters because better-model injects `model:`/`effort:` frontmatter
into existing agents/skills. Install in this sequence:

```text
1. GSD plugin             →  claude plugin install get-shit-done@gsd-build
2. Superpowers plugin     →  claude plugin install superpowers@claude-plugins-official
3. Toolkit (this repo)    →  bash <(curl -sSL .../init-claude.sh)
4. Serena MCP             →  toolkit MCP wizard (after `uv tool install serena-agent`)
5. better-model           →  scripts/setup-cost-routing.sh (npx better-model init)
6. claude-context (opt)   →  toolkit MCP wizard (with security warnings)
```

Skipping order = better-model has nothing to inject into = lower coverage of routing rules.

## Serena MCP

**Purpose:** Symbol-aware code retrieval, refactoring and editing via Language
Server Protocol. Replaces text-search-and-replace with structured operations
(find references, rename, move, replace symbol body).

**Project:** [oraios/serena](https://github.com/oraios/serena) — MIT, 23.9k stars.

**Cost:** Free (open source). The LLM still does the orchestration; Serena
provides the precise tool surface.

**Why critical for solo + GSD:**

- LSP backend gives the agent IDE-level understanding of 40+ languages
- Symbol-level edits are dramatically cheaper than full-file rewrites and
  far less error-prone than regex search-and-replace
- Stays local (LSP servers run on your machine; nothing ships to a vendor)
- Ranked the single most impactful tool by Opus 4.6 / GPT 5.4 in independent
  third-party evaluations

**Prerequisites:**

```bash
# 1. Install uv (Python package manager) — https://docs.astral.sh/uv/getting-started/installation/
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Install serena-agent
uv tool install -p 3.13 serena-agent@latest --prerelease=allow

# 3. Initialise (sets up language server backend by default)
serena init
```

**Setup via toolkit MCP wizard:**

```bash
# Wizard handles `claude mcp add` invocation
bash scripts/init-claude.sh
# Select Serena from MCP catalog → done (no API key required)
```

**Manual setup (equivalent of the wizard):**

```bash
claude mcp add --scope user serena \
  -- serena start-mcp-server --context claude-code --project-from-cwd
```

**Optional:** start Claude Code with Serena's prompt override to maximise
Serena tool usage:

```bash
claude --system-prompt="$(serena prompts print-cc-system-prompt-override)"
```

### Disable the auto-opening dashboard tab

Serena spawns a web dashboard at `http://127.0.0.1:24282/dashboard/` and
opens it in the browser **on every server start**. Combined with stale-
process leaks (each Claude session binds the next free port: 24282 →
24283 → 24284…), this produces dozens of tabs after a day of work,
especially after deploys or scripts that touch project state.

**Disable globally** in `~/.serena/serena_config.yml`:

```yaml
web_dashboard: false
web_dashboard_open_on_launch: false
```

If you want the dashboard available for debugging but not auto-opened:
keep `web_dashboard: true` and set `web_dashboard_open_on_launch: false`.

**Periodic zombie cleanup:**

```bash
lsof -i -P 2>/dev/null | awk '/:2428[0-9]/ {print $2}' | sort -u | xargs -r kill
```

## better-model

**Purpose:** Routes subagent tasks to the right model (Sonnet for coding,
Opus for architecture, Haiku for search).

**Cost:** Free (npm package). Saves $50-200/month by avoiding Opus on
routine tasks.

**Why critical:**

- Default Anthropic UI sends every subagent to Opus
- ~80% of subagent work doesn't need Opus quality
- Sonnet 4.6 is 5× cheaper at ~91% quality on coding
- Haiku 4.5 is 25× cheaper for search/grep

**Install:**

```bash
# Via toolkit setup script (after toolkit + GSD + Superpowers + Serena installed)
bash scripts/setup-cost-routing.sh

# OR manually
npx better-model@latest init
```

## claude-context MCP

**Purpose:** Semantic codebase search via vector DB. Complements Serena —
Serena answers structural queries ("all callers of `foo`"), claude-context
answers semantic ones ("code that handles auth retries").

**Cost:** $1-5 one-time embed per 100k LOC + $0/month queries (Zilliz Cloud
free tier) or self-hosted Milvus (free).

**When:** Codebase >100k LOC AND active development AND not sensitive code
on Zilliz free tier.

**See `components/large-codebase-search.md`** for full setup, security
warnings, self-hosted Milvus instructions, and Voyage AI / Ollama
alternatives for sensitive code.

## Why we dropped Morph (v6.1, 2026-05-06)

Morph (Fast Apply + WarpGrep + Compact) was the v6.0 default Layer-3
recommendation. We removed it in v6.1 because:

1. **No public source for the SDK and MCP server.** `@morphllm/morphsdk`
   and `@morphllm/morphmcp` are MIT-licensed on npm but the source repo
   does not exist on GitHub. The toolkit was piping user code to a closed
   binary that calls a paid SaaS — auditability was effectively zero.
2. **No published privacy / retention policy.** Morph's docs do not state
   whether code uploaded for Fast Apply / WarpGrep is logged, retained, or
   used for training. Vendor risk classification: Tier 3 (paid SaaS, no
   privacy guarantee).
3. **WarpGrep loses on every measurable axis** to Serena (symbolic),
   claude-context (semantic vector at scale), and ripgrep+ast-grep
   (free, local).
4. **Fast Apply has no plug-and-play replacement** that meets our
   "≥2k stars OR known maintainer" bar. Honest answer: Claude Code's
   native `Edit` tool is sufficient for ~95% of cases. Anthropic has not
   shipped a "fast apply" / Predicted-Outputs equivalent as of May 2026.
   See `docs/research/fast-apply-replacement-2026-05-06.md` for the full
   alternatives matrix.

**Migration:** if you previously installed `morph-fast-tools` via the
v6.0 wizard, run `claude mcp remove morph-fast-tools` and re-run the
wizard to install Serena.

## What if a vendor pivots

`commands/vendor-audit.md` is a quarterly review that catches vendor
drift. If any of these tools become unreliable:

| Tool gone | Fallback |
|---|---|
| Serena | Native Edit + ripgrep + ast-grep + LSP-aware editor (slower, more steps) |
| better-model | Manual routing rules in CLAUDE.md (matrix is markdown — copy from better-model repo) |
| claude-context | Self-hosted Milvus + Voyage AI / Ollama embedding OR fallback to ripgrep + ast-grep |

Toolkit detects vendor health via `/vendor-audit`. Run quarterly.

## Cost summary for a typical solo developer

For someone building lantern (144k LOC) + jobbhunter (53k LOC) +
notebooklm-ultra (305k LOC):

| Setup | Monthly | Annual |
|---|---|---|
| Anthropic API (with discipline + better-model) | $100-200 | $1,200-2,400 |
| Serena (open source) | $0 | $0 |
| claude-context (self-hosted, OpenAI embed) | $5-10 | $60-120 |
| TOTAL | $105-210 | $1,260-2,520 |

Without better-model + claude-context: estimate 2-4× higher.

## Cross-references

- `components/cost-discipline.md` — mode selection per task size
- `components/large-codebase-search.md` — claude-context deep-dive
- `commands/vendor-audit.md` — quarterly vendor risk review
- `scripts/setup-cost-routing.sh` — better-model installer
- `docs/research/morph-deep-dive-2026-05-06.md` — full Morph removal rationale
- `docs/research/fast-apply-replacement-2026-05-06.md` — apply-model alternatives
