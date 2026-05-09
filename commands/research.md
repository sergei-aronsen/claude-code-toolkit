# /research — Deep Web Research via Perplexity Pro

## Purpose

Run deep, multi-source research with citations through your **Perplexity Pro
subscription** instead of paying per-token for the Sonar API. Routes through
the optional `comet-bridge` MCP that talks to a locally-running Comet browser
where you are logged into Perplexity.

Use for questions that need current web facts, not in-context reasoning:
library deprecations, recent releases, security advisories, comparisons of
competing tools, market state, regulatory changes.

---

## Usage

```text
/research <query>
```

**Examples:**

- `/research What changed in the Stripe API between Jan and May 2026?`
- `/research Compare Bun, Deno, and Node.js for production HTTP services in 2026`
- `/research Which Postgres connection poolers handle pgvector best?`
- `/research Current state of WebAssembly Component Model adoption`

---

## When to Use

- Question needs **current** facts (post-knowledge-cutoff data)
- Multiple sources should be cross-referenced
- Citations matter (auditing claims, drafting docs, evaluating tech)
- You want a synthesized answer, not raw search results

**Use `/lookup` instead when:**

- Single quick fact needed (~15s vs ~90s)
- Don't need 15+ sources

**Use `/factcheck` instead when:**

- You already have a claim and just want to verify it

---

## Pre-flight Checks

Before running, this command verifies:

1. `comet-bridge` MCP server is registered and `✓ connected` in `/mcp`.
2. Comet browser process is alive on CDP port 9223 (`lsof -nP -iTCP:9223 -sTCP:LISTEN`).
3. CDP responds (`curl -s http://127.0.0.1:9223/json/version`).
4. Perplexity is reachable (any tab on `perplexity.ai` exists, or
   `comet_connect` succeeds).

If any check fails, the command **falls back** to:

- `WebSearch` (built-in Claude Code) for the query, and
- `context7` MCP for library docs (if installed),
- prints a one-line hint: `Run scripts/setup-comet.sh to enable Pro-subscription
  research without API costs.`

---

## Process

1. Call `mcp__comet-bridge__comet_connect`.
2. Call `mcp__comet-bridge__comet_ask` with:
   - `prompt`: the user's query
   - `mode`: `research` (deep multi-step)
   - `timeout`: `240000` (4 minutes; deep research can take 60-180s)
3. Parse the returned text. Extract:
   - main answer body
   - source list (`N источников` / `N sources`)
   - follow-up questions if present
4. Format output as Markdown with inline citations and a Sources block at
   the end.

---

## Output Format

```markdown
## Answer

<synthesized answer with [1][2][3] citations inline>

## Follow-ups

- <suggested follow-up 1>
- <suggested follow-up 2>

## Sources

1. <title> — <url>
2. <title> — <url>
...
```

If the response from Comet contains a numeric source count but no extracted
URL list (older detector or partial DOM), include the raw count and a note:
`Sources visible in Comet tab: N. Open the tab to inspect.`

---

## Cost & Privacy

- **No API tokens spent.** Goes through your Perplexity Pro web session.
- **Privacy:** queries land in your Pro account chat history. The MCP agent
  has DOM access to whatever is open in the isolated Comet profile. Use a
  burner Perplexity account if your queries reveal client/business context.
- See `components/comet-research.md` for the full security model.

---

## Troubleshooting

- **Tool hangs >2 min on `comet_ask`** — completion detector misfired.
  Run `mcp__comet-bridge__comet_screenshot` to see if the answer is rendered;
  then `mcp__comet-bridge__comet_stop` to release the lock.
- **`Comet not running`** — start with `~/comet-mcp/launch.sh`.
- **`Not authenticated`** — Pplx session cookies expired; re-login via OTP
  in Comet.
- **Russian / non-English Perplexity UI returns slow results** — needs
  `perplexity-comet-mcp` ≥ a version with i18n completion markers
  (PR #9 to upstream, currently sourced from
  `github:sergei-aronsen/Perplexity-Comet-MCP#feat/i18n-completion-detection`
  via the catalog).

---

## Related

- `/lookup` — fast single-search variant
- `/factcheck` — single-claim verification
- `scripts/setup-comet.sh` — one-shot installer for Comet + isolated profile + MCP
- `components/comet-research.md` — security model and account-isolation guide
