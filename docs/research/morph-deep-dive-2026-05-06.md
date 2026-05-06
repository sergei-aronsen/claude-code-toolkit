# Morph deep-dive — 2026-05-06

> Status: research pass requested by user. Decision aid for whether toolkit
> should continue recommending Morph as an optional Layer-3 integration.
> All external claims are linked or footnoted; toolkit-internal claims are
> cited by absolute path + line number.

## TL;DR

1. **Recommendation:** Keep Morph in the integrations catalog, but **demote
   warpgrep to "optional, second-tier" while keeping Fast Apply (`edit_file`)
   as the primary value prop**. Add `chunkhound` (1.2k stars, MIT, fully local,
   zero-cloud) as the privacy-respecting code-search alternative; reposition
   `claude-context` (10.8k stars, Zilliz-backed) as the persistent-index
   option. WarpGrep is still useful for ad-hoc queries on small codebases
   but loses on every other axis to either chunkhound (privacy + local) or
   claude-context (scale + persistent index).
2. **Strongest alternative for code search:** `chunkhound` (local Tree-sitter
   + DuckDB vector, MIT, no cloud calls) for privacy/airgap; `claude-context`
   (10.8k stars, Zilliz/Milvus + Voyage embeds) for >100k LOC. Both have
   ~2-15× more GitHub stars and broader maintainership than the morphllm org.
3. **Biggest risk:** the **`@morphllm/morphmcp` npm package has no public
   source repository** (verified by `curl
   https://api.github.com/orgs/morphllm/repos?per_page=100` — 23 repos,
   none named `morphmcp` or `morphsdk`). The toolkit ships an MCP that
   pipes file content to a closed-source binary that calls a paid SaaS.
   `MIT` license claim on the package itself does not give source access.
   Same for `@morphllm/morphsdk` — license MIT, but `package.json` lists
   no `repository` field and `dist/` is the only artefact. This is a
   supply-chain concern even if the company is reputable.
4. **Catalog change required:** in
   `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/lib/integrations-catalog.json:249-285`
   keep `morph-fast-tools` but rewrite description to lead with Fast Apply
   and call WarpGrep a "fallback for ad-hoc agentic search". Add a new
   `chunkhound` entry. Strengthen the `claude-context` description to
   call out the OSS source repo. Update
   `/Users/sergeiarutiunian/Projects/claude-code-toolkit/components/large-codebase-search.md`
   to recommend chunkhound first for privacy-sensitive codebases.
5. **Couldn't verify:** absolute weekly-active-user counts. We have npm
   download proxies (5.5k weekly for `morphmcp`, 30.8k for `morphsdk`,
   2.9k for `claude-context-mcp`), but downloads ≠ active users (CI
   pulls inflate this). Morph's privacy policy says paid-tier 30-day
   retention but does not publish a SOC-2 report or an external audit
   we could find.

## Methodology

### What I read

**Local sources (read top-to-bottom, cited by line number):**

- `_external/morph/` — fresh clone of `morphllm/morph-claude-code-plugin`
  commit `06f96f06` (v0.2.8, MIT-licensed). Verified that all hooks,
  skills, and helpers are open source.
- `_external/morph/hooks/lib/morph.js:1-53` — the only file that touches
  the API; uses `@morphllm/morphsdk` `CompactClient.compact()`.
- `_external/morph/package.json` — declares `@morphllm/morphsdk: ^0.2.157`.
- `~/.claude/plugins/cache/morph/morph-compact/0.2.8/node_modules/@morphllm/morphsdk/`
  — installed SDK. `package.json` declares `license: MIT` but **omits the
  `repository` field**. Only `dist/` and a thin `README.md`.
- `scripts/lib/integrations-catalog.json:249-285` — toolkit's MCP catalog
  entries for `morph-fast-tools` and `claude-context`.
- `scripts/setup-cost-routing.sh:1-158` — wraps `npx better-model init`,
  no Morph references.
- `components/large-codebase-search.md:1-178` — toolkit's recommendation
  document; already prefers claude-context for >100k LOC.
- `components/external-tools-recommended.md:1-124` — install order;
  currently puts Morph at step 4 of 6.
- `components/vendor-risk.md:1-105` — toolkit already documents Morph
  vendor risk in qualitative terms.
- `components/mcp-servers-guide.md:202-220` — how Morph MCP is presented.
- `templates/base/skills/cost-routing-discipline/SKILL.md:60-70`,
  `templates/base/rules/cost-discipline.md:87-97`,
  `templates/base/rules/three-layer-bridge.md:60-101` —
  user-visible instructions that say "use Morph Fast Apply for ALL edits".
- `commands/vendor-audit.md:1-80` — quarterly audit checklist already
  enumerates Morph as a vendor under review.
- `docs/research/v6-post-ship-audit-2026-05-06.md:259-261, 311` — the
  v6 audit's F-24 finding and Q4 question both flag Morph
  doc-vs-catalog drift.
- `CHANGELOG.md:35-37` — confirms Morph and claude-context were added
  to the catalog in v6.0.0 (PR #45).

**External sources (cited inline / in tables):**

- Morph site: `morphllm.com`, `docs.morphllm.com/quickstart`,
  `docs.morphllm.com/`, `docs.morphllm.com/mcpquickstart`,
  `docs.morphllm.com/sdk/components/warp-grep`.
- Morph product pages: `morphllm.com/products/warpgrep`,
  `morphllm.com/agentic-search`, `morphllm.com/codebase-indexing`,
  `morphllm.com/comparisons/swe-grep-vs-warpgrep`,
  `morphllm.com/comparisons/cursor-alternatives`,
  `morphllm.com/comparisons/morph-vs-aider-diff`.
- Morph privacy: `morphllm.com/privacy`.
- Morph pricing: `morphllm.com/pricing`.
- Y Combinator listing: `ycombinator.com/companies/morph`.
- GitHub: `github.com/morphllm`, `github.com/morphllm/morph-claude-code-plugin`,
  `github.com/morphllm/opencode-morph-plugin`,
  `github.com/zilliztech/claude-context`, `github.com/oraios/serena`,
  `github.com/chunkhound/chunkhound`.
- npm registry download API: `api.npmjs.org/downloads/point/last-week/...`
  (verified actual JSON values for three packages).
- GitHub org API: `api.github.com/orgs/morphllm/repos?per_page=100`
  (verified the org has 23 public repos and none of them is `morphmcp`
  or `morphsdk`).

### What I couldn't read

- `docs.morphllm.com/api/warpgrep`, `docs.morphllm.com/products/warpgrep`,
  `docs.morphllm.com/guides/warpgrep` — all returned 404. Morph appears
  to have moved/restructured these endpoints; the live URLs are
  `morphllm.com/products/warpgrep` (marketing) and
  `docs.morphllm.com/sdk/components/warp-grep` (SDK reference).
- `docs.morphllm.com/guides/mcp` — returned 500 then later 200 with
  scant detail; documented privacy specifically for MCP transport is
  thin. The general privacy policy at `morphllm.com/privacy` is the
  only authoritative statement.
- `npmjs.com/package/@morphllm/morphmcp` — 403 from WebFetch. Used the
  registry JSON API instead.
- npm download history before 2026-04-29 — the API only ships last-week
  by default, so I cannot quantify "downloads growing" vs "downloads
  flat". Quoted single-week numbers only.
- SOC-2 / external audit reports — not found in public surface. Morph's
  privacy policy makes claims about zero-retention enterprise tiers but
  does not link to a SOC-2 report or an independent audit.
- Source code for `@morphllm/morphmcp` and `@morphllm/morphsdk` — both
  are dist-only npm packages published with `license: MIT` but **no
  GitHub repository field** and **no public source repo in the
  morphllm org**. Cannot independently verify what these packages
  send over the wire — the OpenCode and Claude Code plugins (which are
  OSS) only show the API call contract, not the SDK's internals.

## Morph product surface

Verified from `docs.morphllm.com/quickstart`, `morphllm.com/`, and
`morphllm.com/pricing`.

| Product / SKU | What it does | Model | Price (paid tier) | Toolkit exposure | Failure mode w/o key |
|---|---|---|---|---|---|
| **Fast Apply** | Merges lazy edit snippets (`// ... existing code ...` markers) into original files. Replaces native Edit. | `morph-v3-fast` (small, 10.5k tok/s) and `morph-v3-large` (large, ~higher accuracy) | `$0.80` in / `$1.20` out per 1M tokens (fast); `$0.90` / `$1.90` (large) | `mcp__morph-fast-tools__edit_file` MCP tool. Catalog entry `morph-fast-tools` at `integrations-catalog.json:249`. Mentioned in `cost-routing-discipline/SKILL.md:60-63` as default for "ALL edits". | Falls back to native Claude Edit (slower, more tokens, but functionally equivalent). |
| **WarpGrep** | RL-trained search subagent. Runs `ripgrep` locally on the user's worktree, sends matches + LLM reasoning to Morph servers. Returns file:line spans. | `morph-warp-grep-v2` | `$0.80` per 100K tokens (so a single rich query is well below `$0.01`; Morph's marketing claims `~$0.003/search`). | `mcp__morph-fast-tools__codebase_search` (and `github_codebase_search`). Mentioned in `large-codebase-search.md:26-45` for 50-100k LOC. | Falls back to ripgrep + Claude reasoning (slower per-query, no LLM-driven query refinement). |
| **Compact** ("Flash Compact") | Compresses transcript history during `/compact`. Verbatim deletion of low-signal tokens. | `morph-compact` | `$0.20` in / `$0.50` out per 1M tokens. | Separate plugin `morphllm/morph-claude-code-plugin` (the `_external/morph/` clone). Hooks `PreCompact` + `SessionStart`. Not in toolkit catalog directly — installed via `claude plugin install morph-compact@morph` if user opts in. | Native Claude compaction runs (slower / lower-quality summary, but functionally equivalent). |
| **Glance** | Headless PR testing with screen-recordings. | (proprietary) | "Plus" pricing tier; not in pricing table. | Not in toolkit. | n/a |
| **Monitor** | Unified PR feed viewer. | n/a (UI product) | Plus tier. | Not in toolkit. | n/a |
| **Router** | LLM router endpoint that picks model per request. | n/a (multi-model) | `$0.005/request` overhead on top of underlying model token costs. | Not in toolkit (toolkit uses `better-model` for routing instead). | n/a |
| **General models (Qwen 3.5 397B, Qwen 3.6 27B)** | General-purpose LLMs Morph hosts. | Qwen variants | `$0.55` in / `$3.50` out (Qwen 3.5); `$0.55` in / `$2.40` out (Qwen 3.6). | Not in toolkit — these compete with OpenRouter, not with Anthropic. | n/a |

**Pricing tiers (from `morphllm.com/pricing`):**

- Free: 250K credits, 200 req/month, low rate limits, $0.
- Starter: $20/month, 3M credits.
- Pro: $20 first month then $60/month, 10M credits.
- Scale: $400/month, 80M credits, "practically no rate limits".
- Enterprise: dedicated infrastructure, SSO, ZDR (zero data retention).

**Authentication:** all products use `MORPH_API_KEY` in env or in
`~/.claude/morph/.env` (the plugin's install skill creates this with
`mode 0600` per `_external/morph/skills/install/SKILL.md:14-19`).

## WarpGrep technical analysis

### Indexing model

WarpGrep is **NOT** a vector-DB / embedding-based search. Per
`morphllm.com/agentic-search` and `morphllm.com/codebase-indexing` Morph
explicitly positions WarpGrep against the embedding-search approach:

> "Stale embeddings cause up to 20% performance declines in downstream
> tasks. This is why Claude Code uses no embeddings at all — Anthropic
> chose grep over vector search."

WarpGrep is an **agentic search subagent**:

1. The MCP runs locally and resolves the project path via
   `resolveSessionRepoRoot` (per
   `deepwiki.com/morphllm/opencode-morph-plugin/3.2-...`).
2. `ripgrep` runs **locally** on the user's machine (so the codebase
   is not uploaded wholesale).
3. The `morph-warp-grep-v2` model runs on Morph servers; it issues
   ripgrep + read + list invocations via the MCP, with up to 8
   parallel calls per turn, up to 4 turns (some Morph blog posts say
   3 turns × 12 = 36 — numbers shift across pages, so treat as
   "tens of tool-calls per query").
4. The grep matches and the LLM reasoning over them happen on Morph's
   servers. Final result is XML-structured `file:line-range` spans
   sent back to the local agent.

### Privacy

This is the key finding for sensitive code:

- **The query, ripgrep matches, and any file content the model decides
  to read leave the user's machine and are processed by Morph's API**.
  Morph's privacy policy
  (`morphllm.com/privacy`) splits behaviour by tier:
  - Free / pay-as-you-go: **90-day retention** for support / debugging.
  - Paid (Starter / Pro / Scale): **30-day retention**.
  - Enterprise (ZDR): in-memory only, purged immediately.
- Morph commits to **not training on user data** outside the explicit
  "report a bug" support flow — but the data still touches Morph's
  storage on non-enterprise tiers.
- For a **public** GitHub repo, the SDK exposes
  `github_codebase_search` which Morph indexes server-side; no upload
  needed. For **private** codebases, the path above (local ripgrep,
  matches sent to Morph) applies.

### Persistence

No client-side index. Each query starts from scratch — `morph-warp-grep-v2`
runs the agentic loop fresh against the live filesystem state. There is
no "stale index" concern, but also no amortization: the per-query cost
is the only cost (no upfront `index` step), but you pay it on every
query.

### Latency

Marketing claims (Morph's own pages):

- "Under 6 seconds" for typical queries
  (`morphllm.com/comparisons/swe-grep-vs-warpgrep`).
- "3.8 steps" average vs "12.4+" for naive grep loops
  (`morphllm.com/products/warpgrep`).
- 0.73 F1 on SWE-Bench, vs SWE-Grep 0.72, Claude Haiku 0.72, Gemini
  Flash 0.66 (same source).

These are **Morph's own benchmarks**. The cited claim that they
"publish SWE-Bench Pro traces through the SEAL leaderboard" gives some
external verifiability, but I did not independently re-run the
benchmark.

### WarpGrep vs claude-context — side-by-side

| Axis | WarpGrep (Morph) | claude-context (Zilliz) |
|---|---|---|
| Indexing model | None (agentic ripgrep + LLM reasoning, fresh per query) | Hybrid: BM25 + dense vector embeddings (OpenAI / Voyage / Ollama / Gemini), AST-aware chunking. |
| Index persisted | No | Yes — Milvus / Zilliz Cloud, incremental Merkle-tree updates. |
| Privacy (default) | Local ripgrep + remote LLM. Code matches sent to Morph. 30 / 90-day retention. | Embeddings sent to chosen provider (OpenAI / Voyage default; Ollama option for full local). Vectors stored in Milvus (self-host or Zilliz Cloud). |
| Privacy (max-paranoid mode) | Enterprise tier (ZDR) — in-memory only. | Self-host Milvus + Ollama embeddings = zero cloud. |
| Latency per query | ~6s (LLM reasoning) | <100ms (vector lookup). Indexing is upfront. |
| Cost — query | $0.003-0.005/query | $0 after indexing. |
| Cost — upfront | $0 | ~$1-5 per 100k LOC for OpenAI embeds (one-time). |
| Cost — best for | <100k LOC, sporadic queries (<30/day) | >100k LOC, frequent queries. |
| Install complexity | `claude mcp add ...` + API key. 1 step. | `claude mcp add ...` + Milvus connection (Zilliz cloud or local Docker) + embedding-provider key. 2-3 steps. |
| GitHub stars (source) | morph-claude-code-plugin: **14**. opencode-morph-plugin: **52**. The `morphmcp` MCP server has **no public source repo**. | zilliztech/claude-context: **10.8k**. |
| License | Marketplace plugins MIT. SDK + MCP server are MIT-licensed npm packages but **dist-only, no public source**. | MIT (full source on GitHub). |
| Maintainer | morphllm Inc. (YC, ~3 staff). | Zilliz (the company behind Milvus, ~150+ staff, raised $113M Series B). |
| npm weekly downloads | `@morphllm/morphmcp`: 5,536. `@morphllm/morphsdk`: 30,798. (week of 2026-04-29 → 05-05.) | `@zilliz/claude-context-mcp`: 2,910. |

Reading the table: **Morph wins on zero-setup convenience and fresh-state
correctness; claude-context wins on long-term cost, privacy options,
maintainership depth, and license/transparency.** They optimize different
points on the curve.

## Trust & supply-chain

### Stars and activity (`morphllm` org, 23 repos verified)

Top public repos by stars:

| Repo | Stars | Last push |
|---|---|---|
| `opencode-morph-plugin` | 52 | 2026-05-01 |
| `morph-claude-code-plugin` | 14 | 2026-04-21 |
| `morph-demos` | 5 | 2025-09-02 |
| `coding-agent-bench` | 5 | 2025-12-18 |
| `examples` | 3 | 2026-03-25 |
| 18 other repos | 0 each | various |

The Claude-Code-specific plugin has only 14 stars. The OpenCode plugin
(52 stars) is the more developed one — it's about 4× ahead in maturity
and probably the canonical target for Morph integration. The Claude
Code plugin v0.2.8 was released 2026-04-21 (15 days ago); v0.2.x cadence
is roughly weekly.

The org's most-starred repo is **52 stars** which is small for a
production-relied-on integration. Compare:

- `oraios/serena` — 23.9k stars, 1.6k forks.
- `zilliztech/claude-context` — 10.8k stars, 792 forks.
- `chunkhound/chunkhound` — 1.2k stars, 98 forks.

### Maintainer

- Listed as Y Combinator Summer 2023 batch (`ycombinator.com/companies/morph`).
- Founder: Tejas Bhakta (per YC listing).
- Team: 3 people (per YC listing, 2026-05-06).
- Operating entity: AutoInfra, Inc. (per `morphllm.com/`).
- HQ: San Francisco.
- Funding: not disclosed publicly. YC-backed but no public Series A
  announcement found.

The YC page's "Founding Year: 2025" combined with "Batch: Summer 2023"
is **internally inconsistent** — likely a YC data-quality issue rather
than evidence of fraud, but worth flagging that even Morph's own
profile is contradictory.

### Source-availability gap (the real risk)

**This is the supply-chain finding worth acting on.** Verified by:

1. `curl https://api.github.com/orgs/morphllm/repos?per_page=100` returns
   23 repos, **none named `morphmcp` or `morphsdk`**.
2. Reading
   `~/.claude/plugins/cache/morph/morph-compact/0.2.8/node_modules/@morphllm/morphsdk/package.json`
   — declares `license: MIT` and ships only `dist/` (compiled
   JavaScript). **No `repository` field**.
3. The toolkit's `morph-fast-tools` MCP entry
   (`integrations-catalog.json:249-265`) installs `npx -y @morphllm/morphmcp`
   — same situation: published with `license: MIT` but no public source.

So:

- **What is open:** the `morph-claude-code-plugin` (the install skill,
  hooks, transcript parsing). The `opencode-morph-plugin`. Both wrappers.
- **What is closed:** the MCP server binary (`@morphllm/morphmcp`),
  the SDK (`@morphllm/morphsdk`), and obviously the server-side models
  (`morph-v3-fast`, `morph-warp-grep-v2`, `morph-compact`).

The `MIT` license tag on a compiled-JS-only npm package is unusual but
not unique to Morph — many SaaS shops do this. Practically, it means
the toolkit cannot independently verify what is sent over the wire,
beyond what the open-source wrapper plugin shows. The wrapper at
`_external/morph/hooks/lib/morph.js:34-53` shows that, for compaction,
we send the entire transcript text (extracted to `{role, content}`
pairs) plus the last user message as `query`.

This is **not a smoking gun** — the SDK is doing what the docs say
it does. But a malicious update to `@morphllm/morphmcp` would not be
catchable by anyone outside Morph until users notice misbehavior. The
package is also pinned only as `^0.2.157` in
`_external/morph/package.json:7` (caret range, auto-updates inside
the 0.2.x line). The Claude Code plugin's own commit hash in
`~/.claude/plugins/installed_plugins.json` is pinned (`06f96f06`) so
**plugin** force-pushes are detectable, but the npm-resolved
`@morphllm/morphsdk` is not.

### Recent issues / PRs (`morph-claude-code-plugin`)

- 1 open issue (#8: "Bundle the full Morph experience").
- No closed issues listed.
- Active development cadence: 9 version bumps in 27 days (2026-03-25 →
  2026-04-21).
- No `SECURITY.md`, no `CODE_OF_CONDUCT.md`, no `LICENSE` file at the
  repo root (the `package.json` does not declare a license either).

### Pricing transparency

Morph is **better than typical** here: the `pricing` page lists per-token
costs for every named model (`morph-v3-fast` $0.80/$1.20/Mtok, etc.)
and per-tier subscription numbers. Free tier gives 250k credits / 200
req/month — enough to evaluate.

### Supply-chain risk summary

- **OSS plugin** layer (`morph-claude-code-plugin`, `opencode-morph-plugin`):
  low risk. Pinned by commit hash. MIT.
- **npm SDK + MCP** layer: **medium-high risk**. Closed source
  distributed under MIT label. No commit-hash pinning at the user's
  level. Force-publish to npm with malicious code would propagate to
  all installs immediately.
- **Server side** (the actual `morph-v3-fast` etc. inference): outside
  toolkit's control. Standard SaaS risk — Morph could pivot, raise
  prices, terminate accounts, retain code longer than promised.

### Third-party adoption

- Cited by SuperClaude_Framework (issue #336 about API key setup).
- Mentioned in PulseMCP, mcpmarket, mcp.directory — standard MCP
  directory listings.
- No mention by Anthropic (which has its own native Edit and is
  unlikely to bless a competitor in the apply space).
- Cursor doesn't use Morph (it has its own apply model).
- Aider doesn't use Morph (it has Polyglot diff format).
- The OpenCode editor has the deepest integration (52-star plugin
  maintained by Morph itself).

## Alternatives matrix

Scoring is **subjective** (1-10) per axis with explicit reasoning where
two-source evidence is available. Scores marked `(unverified)` rely on
single-source claims (mostly Morph's own marketing).

### Fast Apply alternatives

| Tool | Speed | Accuracy | Cost / token efficiency | License / OSS | Maturity | Total | Notes |
|---|---|---|---|---|---|---|---|
| **Morph Fast Apply** | 9 (10.5k tok/s, marketing) | 9 (98% claimed) | 8 ($0.80-1.20/Mtok, beats native Edit on token spend) | 5 (MIT label, dist-only) | 7 (1.5y old, YC, weekly releases) | **38/50** | Best on raw mechanics; worst on transparency. |
| **Native Claude Edit (search/replace)** | 4 (50-100 tok/s implied by Morph's own benchmarks) | 7 (86% Morph claim, "~78% works without human edits" Aider claim) | 5 (full-rewrite tokens cost more) | 10 (Anthropic-controlled, no third-party) | 10 (default in product) | **36/50** | The benchmark numbers come from Morph's own marketing — treat as biased but directionally correct. |
| **Aider's Polyglot diff** | 6 (200-300 tok/s, Morph's number) | 6 (80% Morph claim) | 9 ("4.2x fewer tokens than Claude Code" — Morph's number, but Aider verifies similar elsewhere) | 10 (Apache 2.0, full source) | 9 (Aider is well-known) | **40/50** | Best privacy (no third-party SaaS). Requires Aider as the agent though, not a drop-in for Claude Code. |
| **Cursor Apply** | 7 (1000 tok/s, Morph's number) | 6 (85% Morph claim) | 6 (bundled with Cursor sub) | 1 (closed) | 9 | **29/50** | Not available in Claude Code at all — IDE-locked. |
| **Composer (Cursor)** | 7 | 7 | 5 | 1 | 7 | **27/50** | Same as Cursor Apply — IDE-locked, no Claude Code path. |

**Verdict for Fast Apply:** Morph wins for Claude Code users specifically
because the alternatives are either (a) inferior to native Edit
(nothing) or (b) require switching agent (Aider). **Keep Morph in this
slot.** Caveat the OSS gap.

### Code search alternatives

| Tool | Latency | Accuracy | Privacy | Cost long-term | License / source | Maturity | Total |
|---|---|---|---|---|---|---|---|
| **WarpGrep (Morph)** | 6 (~6s/query, agentic) | 8 (0.73 F1 SWE-bench, Morph's number) | 5 (code + matches sent to Morph; 30/90-day retention) | 6 (per-query cost) | 5 (MIT label, no source repo for MCP) | 7 | **37/60** |
| **claude-context (Zilliz)** | 9 (<100ms post-index) | 8 (BM25 + dense, Voyage `voyage-code-3` purpose-built) | 7 (depends — Voyage/OpenAI/local) | 9 (free queries after $1-5 embed) | 10 (full OSS, 10.8k stars) | 9 | **52/60** |
| **chunkhound** | 9 (local DuckDB) | 7 (cAST + Tree-sitter, multi-hop) | 10 (fully local-first option) | 10 (free) | 10 (MIT, full OSS) | 6 (1.2k stars, smaller community) | **52/60** |
| **serena (oraios)** | 8 (LSP-driven, symbol-level) | 8 (LSP gives true symbol semantics — beats embeddings on call-graph queries) | 10 (LSP runs locally) | 10 (free) | 10 (MIT, 23.9k stars, well-maintained) | 9 | **55/60** |
| **ripgrep + ast-grep + Read** | 7 (depends on agent loop) | 6 (no semantic) | 10 (local) | 10 (free) | 10 (BSD/MIT) | 10 | **53/60** |

**Verdict for code search:** `serena` is the highest-scoring all-rounder
because LSP gives **structural** code understanding (call graph, symbol
references) that no other tool here gives. `chunkhound` and `claude-context`
beat WarpGrep on every axis except "ad-hoc, zero-setup, codebase you
don't want to index". **WarpGrep is not the right default**, but it's a
fine fallback. **Add chunkhound and serena to the toolkit's catalog.**

### Compaction alternatives

| Tool | Speed | Quality | Cost | License | Total | Notes |
|---|---|---|---|---|---|---|
| **Morph Flash Compact** | 9 (33k tok/s) | 8 ("verbatim deletion" — keeps surviving lines byte-identical) | 7 ($0.20-0.50/Mtok) | 5 (closed model + MIT-label SDK) | 6 (15-day-old plugin, 14 stars) | **35/50** |
| **Native Claude compaction** | 5 (slower, summary-style) | 7 (summary loses some detail) | 5 (consumes Claude tokens) | 10 (Anthropic-controlled) | 10 | **37/50** |
| **claude-context recall (as compaction proxy)** | 8 | 6 (not designed for transcript compaction — used as long-term retrieval) | 9 | 10 | 9 | **42/50** |
| **MemGPT / Mem0** | 6 | 6 | 8 | 10 | 6 | **36/50** |

**Verdict for compaction:** Morph's "verbatim" approach is theoretically
nicer than Claude's "summary" approach for long sessions where you need
exact wording later. But Claude Code does not currently allow third
parties to *replace* compaction (per
`_external/morph/README.md:42-46` — "we are unable to alter the output
of a compaction" — they work around it with prompt injection). This
is a **fragile** integration. The `morph-compact` plugin's own README
warns: "even with these instructions, there's no guarantee that
compaction will respect them." **Do not push compaction as a primary
benefit; keep it as an experimental opt-in.**

## claude-context status check

Goals: confirm catalog presence, install procedure usability,
self-host vs hosted-only.

### Catalog presence

Verified: yes, in `scripts/lib/integrations-catalog.json:267-285`:

```json
"claude-context": {
  "name": "claude-context",
  "display_name": "Claude Context (semantic search)",
  "category": "dev-tools",
  "env_var_keys": ["MILVUS_TOKEN", "OPENAI_API_KEY"],
  "install_args": ["claude-context", "--", "npx", "-y",
                   "@zilliz/claude-context-mcp@latest"],
  "description": "Vector-DB semantic code search (Milvus + OpenAI/Voyage embeddings). Justified for 100k+ LOC codebases. v6.0 recommended.",
  "requires_oauth": false,
  "default_scope": "user"
}
```

### Install procedure usability

The catalog entry only declares two env vars: `MILVUS_TOKEN` and
`OPENAI_API_KEY`. **This is incomplete.** Per
`components/large-codebase-search.md:51-58`, the actual full install
needs:

```bash
claude mcp add claude-context \
  -e OPENAI_API_KEY=sk-... \
  -e MILVUS_ADDRESS=https://in03-xxx.zillizcloud.com \
  -e MILVUS_TOKEN=db_xxx \
  -- npx @zilliz/claude-context-mcp@latest
```

The `MILVUS_ADDRESS` env var is required but missing from the catalog
entry. **Catalog gap to fix.**

Beyond the env var: setup also requires either (a) a Zilliz Cloud
account (free tier is shared multi-tenant — see security warning in
`large-codebase-search.md:78-88`) or (b) a self-hosted Milvus
docker-compose stack. The `large-codebase-search.md` doc walks through
the docker-compose setup, but the MCP wizard does not surface this —
a user picking `claude-context` from the wizard will likely get stuck
at the `MILVUS_ADDRESS` stage.

### Self-host vs hosted-only

`@zilliz/claude-context-mcp` runs **client-side** (it's a stdio MCP).
What's hosted:

- **Vector store** — Milvus / Zilliz Cloud. Self-host via Docker is
  documented in `large-codebase-search.md:91-108`.
- **Embedding provider** — OpenAI / Voyage / Ollama / Gemini. Ollama
  is local; the others send chunks of source code to their respective
  APIs.

For sensitive code, the toolkit already correctly recommends the
self-host + Ollama path (`large-codebase-search.md:140-148`). For
non-sensitive code, Zilliz free tier + Voyage `voyage-code-3` is
cited as the best price/quality.

### User friction

Estimated install time:

- Zilliz free tier + OpenAI: ~10 minutes (account signup + 2 keys).
- Self-hosted Milvus + Voyage: ~30 minutes (Docker + env tuning).
- Self-hosted Milvus + Ollama: ~45 minutes (also pull a 1-2GB embedding
  model).

This is significantly higher friction than Morph's "1 env var"
install. **The catalog should communicate this** — currently the
`description` says "v6.0 recommended" but does not flag the multi-step
setup.

## Recommendation

**Outcome: Keep Morph but reposition; add chunkhound and serena.**

Morph is not the wrong choice — it's just not the **only** choice, and
the toolkit currently overstates its primacy. The SKILL files
(`templates/base/skills/cost-routing-discipline/SKILL.md:60-63`) say
"Use Morph Fast Apply for ALL edits". This is justifiable for Fast
Apply (best in class for Claude Code today). It is **not** justifiable
for WarpGrep (claude-context wins on cost-at-scale, chunkhound wins on
privacy, serena wins on accuracy).

The biggest risk is **not** that Morph is bad — it's that the toolkit
nudges users into a single-vendor lock-in for a category (search) where
better OSS options exist with stronger maintainership. If Morph
disappears tomorrow (3-person YC startup, single funding round, no
public traction milestones), the toolkit loses the search story. With
chunkhound or serena catalogued as alternates, the toolkit has a clean
exit.

### Concrete catalog and doc changes

1. **`scripts/lib/integrations-catalog.json:249-265` — split Morph into
   two entries** (or at minimum rewrite the description):
   - **Keep `morph-fast-tools` as the primary edit tool**, but rewrite
     the description to lead with Fast Apply and downgrade WarpGrep:
     `"Fast Apply token-efficient diffs (10.5k tok/s, 98% accuracy).
     Includes warpgrep_codebase_search as a fallback for ad-hoc
     agentic search on small codebases. v6.0 recommended for Fast Apply."`
   - Note the **closed-source SDK** caveat in the catalog `description`
     or via a new field like `oss_status: "wrapper-only"`.

2. **`scripts/lib/integrations-catalog.json` — add new `chunkhound`
   entry** under `mcp.*`:

   ```json
   "chunkhound": {
     "display_name": "ChunkHound (local code search)",
     "category": "dev-tools",
     "env_var_keys": [],
     "install_args": ["chunkhound", "--", "uvx", "chunkhound", "mcp"],
     "description": "Local-first semantic code search (Tree-sitter + DuckDB vector). Zero cloud, MIT, 1.2k stars. Best fit for sensitive codebases or air-gapped dev.",
     "requires_oauth": false,
     "default_scope": "user"
   }
   ```

   (Verify exact CLI invocation against `chunkhound`'s docs before
   merge — search shows `pypi.org/project/chunkhound` and an MCP entry
   in the project's main README.)

3. **`scripts/lib/integrations-catalog.json` — add `serena` entry**:

   ```json
   "serena": {
     "display_name": "Serena (LSP-driven semantic search + edit)",
     "category": "dev-tools",
     "env_var_keys": [],
     "install_args": ["serena", "--", "uvx", "--from",
                      "git+https://github.com/oraios/serena", "serena",
                      "start-mcp-server"],
     "description": "Symbol-level code understanding via LSP. Beats vector-DB on call-graph queries. MIT, 23.9k stars.",
     "requires_oauth": false,
     "default_scope": "user"
   }
   ```

4. **`scripts/lib/integrations-catalog.json:267-285` — fix
   `claude-context` env var list** by adding `MILVUS_ADDRESS`. Without
   it the wizard prompts the wrong subset.

5. **`components/large-codebase-search.md:7-12` — update the threshold
   table** to:

   | Codebase size | Recommended |
   |---|---|
   | <10k LOC | `rg` + `Read` |
   | 10k-50k LOC | `rg` + `Read`, optional chunkhound for repeated queries |
   | 50k-100k LOC | chunkhound (privacy) OR Morph WarpGrep (zero-setup) OR serena (call-graph queries) |
   | >100k LOC | claude-context + Voyage (scale) OR self-hosted variant (sensitive code) |

6. **`components/external-tools-recommended.md:5-12` — update install
   matrix** so Morph's "Always install: Yes — Fast Apply edits +
   warpgrep search" becomes "Always install: Yes — Fast Apply only;
   warpgrep optional".

7. **`templates/base/skills/cost-routing-discipline/SKILL.md:60-70` and
   `templates/base/rules/cost-discipline.md:87-97`** — soften the
   "ALWAYS Morph for edits" wording to "Prefer Morph Fast Apply when
   available, fall back to native Edit otherwise; never use Morph for
   single-line changes (overhead beats savings)".

8. **`commands/vendor-audit.md:21-29`** — extend the audit checklist
   to include the **source-availability gap** explicitly: "Verify
   `@morphllm/morphmcp` and `@morphllm/morphsdk` published source repo
   exists; if not, treat as YELLOW (closed-source SaaS dependency)".

9. **`docs/research/morph-deep-dive-2026-05-06.md`** — this file. Drop
   in `docs/research/` so the next refactor or vendor pivot has a
   reference point, and link from `commands/vendor-audit.md`.

10. **(Optional but recommended) `manifest.json` and update flow** —
    pin the `@morphllm/morphmcp` version explicitly (not `^0.2.157`)
    so the installer locks to a tested version. Use `~0.2.157` (patch-
    only) at minimum. This applies to both the toolkit's own usage and
    the marketplace plugin (file an upstream issue with morphllm/morph-
    claude-code-plugin asking for tighter pinning).

### Migration impact

- Users following `cost-routing-discipline/SKILL.md` will see softened
  language but no behavioural change — Morph remains the recommended
  default.
- Users on `complement-full` install will see two new optional MCP
  catalog entries (chunkhound, serena). Default install set unchanged.
- `claude-context` users on Zilliz Cloud will get a `MILVUS_ADDRESS`
  prompt they previously had to set manually — strict improvement.

## Open questions

1. **WarpGrep ground-truth benchmark.** All accuracy numbers
   (0.73 F1, 39% fewer tokens, 26% fewer turns) are from
   `morphllm.com/comparisons/swe-grep-vs-warpgrep` — Morph's own
   marketing. The page says traces are on the SEAL leaderboard
   but I did not pull and reproduce them. **Severity: low** —
   we are not betting the toolkit on the exact percentages, only
   on the ordering (warpgrep > naive grep loops).

2. **`@morphllm/morphmcp` and `@morphllm/morphsdk` source repo.** The
   org has 23 public repos; neither package's source is among them.
   This was verified via the GitHub API. It is *possible* there's a
   private repo + selective release flow, but from the user side it
   means we cannot independently audit the binary. **Severity: medium**.

3. **Morph privacy claims under load.** The privacy policy at
   `morphllm.com/privacy` makes specific tier-based retention claims
   (90 days free / 30 days paid / 0 enterprise). I did not find a
   SOC-2, ISO-27001, or external audit reference confirming these.
   For non-sensitive solo projects this is fine. For corporate use,
   user should request the SOC-2 directly. **Severity: low for
   target audience (solo devs)**.

4. **Real npm download trends.** I have a single-week snapshot:
   - `@morphllm/morphmcp`: 5,536 downloads.
   - `@morphllm/morphsdk`: 30,798 downloads.
   - `@zilliz/claude-context-mcp`: 2,910 downloads.
   I could not pull the 90-day trend without a richer API call
   (`api.npmjs.org/downloads/range/...`). Direction matters: if
   morphmcp is doubling weekly, the supply-chain risk of pinning to
   `^0.2.x` is higher because each release reaches more users.
   **Severity: low** — the absolute numbers (~5k/week for the MCP
   server, ~30k/week for the SDK) are healthy enough to indicate
   real adoption.

5. **Anthropic native Edit roadmap.** If Anthropic ships a Morph-style
   apply model natively in Sonnet 4.8 (rumored for May 2026 per
   `nxcode.io` search hits), the entire Fast Apply value prop
   collapses overnight. The toolkit should monitor this — it's the
   single biggest event that would make Morph redundant. **Severity:
   strategic, not immediate**.

6. **YC profile inconsistency.** `ycombinator.com/companies/morph` lists
   "Founding Year: 2025" but "Batch: Summer 2023". Likely a YC
   profile data issue, not evidence of misrepresentation, but the
   contradiction did show up in two different `WebFetch` reads of
   the same page. Not actionable.

---

**Sources cited above:**

- Morph quickstart: https://docs.morphllm.com/quickstart
- Morph homepage: https://morphllm.com/
- Morph pricing: https://morphllm.com/pricing
- Morph privacy policy: https://morphllm.com/privacy
- Morph WarpGrep product page: https://morphllm.com/products/warpgrep
- Morph SWE-grep comparison: https://morphllm.com/comparisons/swe-grep-vs-warpgrep
- Morph aider comparison: https://morphllm.com/comparisons/morph-vs-aider-diff
- Morph Cursor alternatives: https://morphllm.com/comparisons/cursor-alternatives
- Morph indexing essay: https://morphllm.com/codebase-indexing
- Morph agentic search essay: https://morphllm.com/agentic-search
- Morph MCP docs: https://docs.morphllm.com/mcpquickstart
- Morph WarpGrep SDK: https://docs.morphllm.com/sdk/components/warp-grep
- Morph YC profile: https://ycombinator.com/companies/morph
- morphllm GitHub org: https://github.com/morphllm
- morph-claude-code-plugin: https://github.com/morphllm/morph-claude-code-plugin
- opencode-morph-plugin: https://github.com/morphllm/opencode-morph-plugin
- DeepWiki on warpgrep_codebase_search: https://deepwiki.com/morphllm/opencode-morph-plugin/3.2-warpgrep_codebase_search-local-search
- claude-context: https://github.com/zilliztech/claude-context
- serena: https://github.com/oraios/serena
- chunkhound: https://github.com/chunkhound/chunkhound
- npm registry API for download counts: https://api.npmjs.org/downloads/point/last-week/...
