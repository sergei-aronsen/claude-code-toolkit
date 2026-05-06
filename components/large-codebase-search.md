# Large Codebase Search

> When grep + Read stops scaling. Threshold: ~100k LOC. Below that — ripgrep + Read are fine. Above — semantic search via vector DB pays for itself.

## When you need it

| Codebase size | Tool |
|---|---|
| < 10k LOC | `rg` + `Read` (Claude built-in) |
| 10k - 50k LOC | `rg` + `Read`, optionally Morph warpgrep MCP for ad-hoc semantic queries |
| 50k - 100k LOC | Morph warpgrep MCP (semantic, no setup) |
| > 100k LOC | claude-context MCP (persistent vector index, free queries) |

## Why it matters

Discovery (finding the right file/function) is 30-50% of token spend on big projects. Loading 50 files at 5KB each just to find the one that matters = 250KB context = expensive.

Vector indexing flips this:

- Index once (~$1-5 for 100k LOC, OpenAI embedding)
- Query thousands of times for free
- Each query returns top-K relevant chunks (~5KB) instead of N files (~250KB)

## Tools

### Morph warpgrep (ad-hoc, no setup)

Already-installed MCP `mcp__morph-fast-tools__warpgrep_codebase_search`.

```text
Pros:
- Zero setup (works immediately)
- Hybrid search (semantic + grep fallback)
- Per-query pricing (no subscription)

Cons:
- Per-query cost adds up (~$0.005 per query)
- No persistent index — rebuilds on file changes
- Less effective for very large codebases (>200k LOC)

When:
- Codebase 50-100k LOC
- Occasional queries (< 30/day)
- You don't want to maintain another service
```

### claude-context (persistent index, big codebase)

Install via toolkit MCP wizard (PR 5):

```bash
# Public Zilliz Cloud (free tier — DO NOT USE for sensitive code)
claude mcp add claude-context \
  -e OPENAI_API_KEY=sk-... \
  -e MILVUS_ADDRESS=https://in03-xxx.zillizcloud.com \
  -e MILVUS_TOKEN=db_xxx \
  -- npx @zilliz/claude-context-mcp@latest
```

```text
Pros:
- Persistent index (one-time embed cost ~$1-5 per 100k LOC)
- Free queries (after embed)
- Incremental updates via Merkle tree (changed files re-embed only)
- Best for repeated queries on stable codebases

Cons:
- Setup overhead (Milvus + OpenAI keys)
- Free tier shares metadata (security caveat below)
- Sensitive code requires self-hosted Milvus

When:
- Codebase > 100k LOC
- Frequent queries (>30/day)
- Stable codebase (heavy reads, modest writes)
```

## Security: claude-context for sensitive code

**DO NOT use Zilliz Cloud free tier for code containing:**

- API keys, secrets, credentials
- Customer data references
- Proprietary algorithms / IP
- HIPAA / GDPR-regulated logic
- Payment processing code

The free tier's metadata is shared across tenants. While vectors aren't directly readable, embedding inversion research (arxiv.org/abs/2305.03010) shows approximate code reconstruction is possible.

### Self-hosted Milvus setup

```yaml
# docker-compose.yml
version: '3'
services:
  milvus:
    image: milvusdb/milvus:v2.4.0
    command: ["milvus", "run", "standalone"]
    environment:
      - ETCD_USE_EMBED=true
      - COMMON_STORAGETYPE=local
    ports:
      - "19530:19530"
    volumes:
      - milvus_data:/var/lib/milvus
volumes:
  milvus_data:
```

```bash
docker-compose up -d
```

Then:

```bash
claude mcp add claude-context \
  -e OPENAI_API_KEY=sk-... \
  -e MILVUS_ADDRESS=http://localhost:19530 \
  -e MILVUS_TOKEN= \
  -- npx @zilliz/claude-context-mcp@latest
```

### Alternative: Voyage AI embedding (better for code)

Voyage's `voyage-code-3` model is purpose-built for code search and outperforms OpenAI's general embedding.

```bash
claude mcp add claude-context \
  -e VOYAGE_API_KEY=pa-... \
  -e EMBEDDING_PROVIDER=voyageai \
  -e EMBEDDING_MODEL=voyage-code-3 \
  -e MILVUS_ADDRESS=http://localhost:19530 \
  -- npx @zilliz/claude-context-mcp@latest
```

Cost: $0.02 / Mtok (similar to OpenAI), better accuracy on code retrieval benchmarks.

### Local embedding (Ollama)

For maximum privacy:

```bash
ollama pull nomic-embed-text
# Configure claude-context to use Ollama via env vars (verify support in latest version)
```

Local = zero cost per embedding + zero cloud exposure. Trade-off: slower indexing, less accurate retrieval.

## Cost projection

For a 305k LOC codebase like notebooklm-ultra:

| Setup | One-time | Monthly (50 queries/day) |
|---|---|---|
| Morph warpgrep | $0 | ~$7.50 |
| claude-context (Zilliz Cloud free) | ~$3 (embed) | ~$0 |
| claude-context (self-hosted Milvus + OpenAI embed) | ~$3 (embed) + $0 (Docker) | ~$0 |
| claude-context (self-hosted + local Ollama) | $0 + $0 | ~$0 |

For >100k LOC active dev: self-hosted claude-context with Voyage AI = best ROI.

## Index lifecycle

After initial embed:

- File changes trigger re-embed of changed chunks only (Merkle tree diff)
- Re-embed cost is proportional to delta, not full codebase
- Stale chunks pruned automatically

Typical month for 100k LOC project: ~10% files change = ~$0.30 in incremental embeds.

## Cross-references

- `components/external-tools-recommended.md` — install order including claude-context
- `components/cost-discipline.md` — when paying for search vs. doing it manually
- `components/security-hardening.md` — sensitive code handling
