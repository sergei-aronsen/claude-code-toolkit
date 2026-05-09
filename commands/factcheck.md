# /factcheck — Verify a Specific Claim with Sources

## Purpose

Verify a single factual claim against current web sources. Returns a verdict
(`VERIFIED`, `DISPUTED`, `UNVERIFIABLE`) with supporting citations.

Built on the same `comet-bridge` MCP as `/research` and `/lookup` — uses
your **Perplexity Pro subscription**, no API tokens spent.

---

## Usage

```text
/factcheck <claim>
```

**Examples:**

- `/factcheck Postgres 18 was released in 2026`
- `/factcheck React 19 deprecates the legacy Context API`
- `/factcheck Stripe Treasury accepts EUR deposits in May 2026`
- `/factcheck Bun supports Node-native HTTP/2 in production`

---

## When to Use

- Reviewing a plan / spec / comment that contains version-sensitive claims
- Auditing AI-generated text for hallucinated facts
- Pre-flight check before relying on a "fact" in code or docs

**Use `/research` instead when:**

- The question is open-ended ("what's new in X?")

**Use `/lookup` instead when:**

- You want an answer, not a verdict on a specific assertion

---

## Pre-flight Checks

Same as `/research`. Falls back to `WebSearch` + reasoning if `comet-bridge`
is unavailable, but the verdict will be lower-confidence.

---

## Process

1. Call `mcp__comet-bridge__comet_connect`.
2. Call `mcp__comet-bridge__comet_ask` with a structured verification prompt:

   ```text
   Fact-check this claim and return a verdict.

   Claim: "<user claim>"

   Required output:
   1. Verdict: VERIFIED | DISPUTED | UNVERIFIABLE
   2. One-sentence justification
   3. 2-4 supporting sources with titles and URLs
   4. If DISPUTED: what the actual current state is
   ```

   With `mode`: `search`, `timeout`: `60000`.
3. Parse the structured response. If the model didn't follow the format,
   fall back to extracting verdict heuristically (look for keywords:
   "true / false / partially / no evidence").

---

## Output Format

```markdown
**Claim:** <user claim>

**Verdict:** ✅ VERIFIED  |  ❌ DISPUTED  |  ❓ UNVERIFIABLE

**Justification:** <one-line explanation>

<if DISPUTED>
**Actual state:** <correct version of the fact>
</if>

**Sources:**
- [<title>](<url>)
- [<title>](<url>)
```

---

## Verdict Definitions

- **VERIFIED** — Multiple authoritative sources confirm the claim. No
  contradicting evidence found.
- **DISPUTED** — At least one authoritative source contradicts the claim,
  or the claim is partially true (right concept, wrong version/date/scope).
- **UNVERIFIABLE** — No public sources address the claim within reasonable
  search depth. Possibly internal / private / too obscure.

---

## Cost & Privacy

- No API tokens spent. See `/research` for the full Cost & Privacy section.

---

## Related

- `/research` — deep open-ended research
- `/lookup` — fast search
- `/council --with-facts` *(future)* — auto-runs `/factcheck` on each plan claim
- `components/comet-research.md` — security model
