# /lookup — Fast Web Search via Perplexity Pro

## Purpose

Quick web search with synthesized answer and citations through your
**Perplexity Pro subscription**. Runs in `search` mode (Sonar) — single-pass,
fewer sources, much faster than `/research`.

Use for "what's the current X" type questions where you need an answer plus
a couple of sources, not a deep multi-step investigation.

---

## Usage

```text
/lookup <query>
```

**Examples:**

- `/lookup current Node.js LTS version`
- `/lookup Stripe API version as of May 2026`
- `/lookup React 19 release date`
- `/lookup latest Tailwind CSS v4 breaking changes`

---

## When to Use

- Single fact, version, or short answer needed
- Speed matters (~15-20s vs ~90s for `/research`)
- 5-15 sources is enough

**Use `/research` instead when:**

- Need deep multi-step exploration
- Comparing 3+ alternatives
- Need 15+ sources for an audit / draft

**Use `/factcheck` instead when:**

- You have a specific claim to verify, not an open question

---

## Pre-flight Checks

Same as `/research`. See that command for details. Falls back to `WebSearch`
and `context7` if `comet-bridge` MCP is not available.

---

## Process

1. Call `mcp__comet-bridge__comet_connect`.
2. Call `mcp__comet-bridge__comet_ask` with:
   - `prompt`: the user's query
   - `mode`: `search`
   - `timeout`: `30000` (30 seconds)
3. Format the response as a short answer + sources list.

---

## Output Format

```markdown
**Answer:** <one-paragraph synthesized answer>

**Sources:**
- [<title>](<url>)
- [<title>](<url>)
```

Aim for 1-3 sentences in the answer. If the underlying response is longer,
keep the full text but lead with a one-line summary.

---

## Cost & Privacy

- No API tokens spent. See `/research` for the full Cost & Privacy section.
- Queries land in your Perplexity chat history.

---

## Related

- `/research` — deep research with 15-30 sources
- `/factcheck` — single-claim verification
- `components/comet-research.md` — security model
