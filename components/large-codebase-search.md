# Large Codebase Search

> When grep + Read stops scaling. Three orthogonal axes — symbolic
> (Serena), textual (ripgrep), semantic (claude-context). Pick the one
> that matches the question, not the codebase size.

## Pick by query, not by size

| Question | Tool |
|---|---|
| "Find function `foo`, all callers, all overrides" | **Serena** (LSP, symbol-level) |
| "Find every place we touch the `stripe_customer_id` column" | `rg` (Claude built-in) |
| "Find the code that retries on auth failure" (no exact term) | **claude-context** (semantic vectors) |
| "Rename `User` to `Account` across project" | **Serena** (`rename` refactor) |

If you only have one of these, install **Serena first** — it covers the
symbolic and refactor cases for free, and that's where the biggest
discovery-token spend usually sits.

## When you need it

| Codebase size | Recommended stack |
|---|---|
| < 10k LOC | `rg` + `Read` (Claude built-in) |
| 10k - 50k LOC | Serena + `rg` |
| 50k - 100k LOC | Serena + `rg` (claude-context optional for "find code about X" queries) |
| > 100k LOC | Serena + `rg` + claude-context (persistent vector index) |

## Why it matters

Discovery (finding the right file/function) is 30-50% of token spend on
big projects. Loading 50 files at 5KB each just to find the one that
matters = 250KB context = expensive.

The three search axes flip this:

- **Serena** answers structural questions in one tool call (LSP returns
  the precise symbol locations) instead of N grep+Read iterations.
- **Vector indexing** (claude-context) flips frequent semantic queries:
  index once (~$1-5 for 100k LOC, OpenAI embedding), query thousands of
  times for free, each query returns top-K relevant chunks (~5KB)
  instead of N files (~250KB).
- **ripgrep** stays free and fast for exact-term searches and is
  complementary to both.

## Tools

### Serena (symbolic / refactor)

Already covered in `components/external-tools-recommended.md` (Serena
section). The MCP catalog entry is `serena` (`integrations-catalog.json`,
v6.1+). Open source, MIT, runs locally.

```text
Pros:
- IDE-level understanding (find references, rename, move, type hierarchy)
- 40+ language LSP backends (TypeScript, Python, Go, Rust, Java, ...)
- Symbol-aware editing (replace symbol body, insert before/after symbol)
- Local — code never leaves your machine
- Free

Cons:
- Per-language LSP server may need setup (Java/Scala/Kotlin in particular)
- Less effective for natural-language semantic queries — pair with
  claude-context for that

When:
- Any codebase >10k LOC
- Heavy refactoring or cross-file navigation
- You want symbolic precision (find ALL callers, not text matches)
```

### claude-context (semantic / persistent index, big codebase)

Install via toolkit MCP wizard:

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
- Best for repeated semantic queries on stable codebases

Cons:
- Setup overhead (Milvus + OpenAI keys)
- Free tier shares metadata (security caveat below)
- Sensitive code requires self-hosted Milvus

When:
- Codebase > 100k LOC
- Frequent semantic queries (>30/day)
- Stable codebase (heavy reads, modest writes)
- Pair with Serena for the structural questions
```

## Security: claude-context for sensitive code

**DO NOT use Zilliz Cloud free tier for code containing:**

- API keys, secrets, credentials
- Customer data references
- Proprietary algorithms / IP
- HIPAA / GDPR-regulated logic
- Payment processing code

The free tier's metadata is shared across tenants. While vectors aren't
directly readable, embedding inversion research
(arxiv.org/abs/2305.03010) shows approximate code reconstruction is
possible.

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

Voyage's `voyage-code-3` model is purpose-built for code search and
outperforms OpenAI's general embedding.

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

Local = zero cost per embedding + zero cloud exposure. Trade-off:
slower indexing, less accurate retrieval.

## Cost projection

For a 305k LOC codebase like notebooklm-ultra:

| Setup | One-time | Monthly |
|---|---|---|
| Serena (symbolic) | $0 | $0 |
| claude-context (Zilliz Cloud free) | ~$3 (embed) | ~$0 |
| claude-context (self-hosted Milvus + OpenAI embed) | ~$3 (embed) + $0 (Docker) | ~$0 |
| claude-context (self-hosted + local Ollama) | $0 + $0 | ~$0 |

For >100k LOC active dev: Serena + self-hosted claude-context with
Voyage AI = best ROI.

## Index lifecycle (claude-context)

After initial embed:

- File changes trigger re-embed of changed chunks only (Merkle tree diff)
- Re-embed cost is proportional to delta, not full codebase
- Stale chunks pruned automatically

Typical month for 100k LOC project: ~10% files change = ~$0.30 in
incremental embeds.

## Cross-references

- `components/external-tools-recommended.md` — install order including
  Serena and claude-context
- `components/cost-discipline.md` — when paying for search vs. doing it manually
- `components/security-hardening.md` — sensitive code handling
- `docs/research/morph-deep-dive-2026-05-06.md` — why Morph WarpGrep was dropped
