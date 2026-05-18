# /council — Multi-AI Plan Validation (Supreme Council)

## Purpose

Challenge an implementation plan with Gemini (The Skeptic) and ChatGPT
(The Pragmatist) before coding. The Council is not a linter — it
validates whether the approach is justified, well-scoped, and free of
common production-readiness traps.

---

## Usage

```text
/council <feature description>
```

**Examples:**

- `/council add OAuth login with Google`
- `/council refactor payment service to Stripe SDK v3`
- `/council implement role-based permissions`

---

## Modes

`brain.py` (the orchestrator behind this command) supports three modes
plus an `audit-review` mode. Pick the one that matches your task.

### validate-plan (default)

```text
/council <feature description>
brain "<feature description>"
```

Runs Skeptic + Pragmatist over the plan plus the auto-collected
project context (CLAUDE.md, README, planning docs, recent commits,
TODOs, git diff, matching test files, all secret-redacted). Produces
a final consolidated verdict (`PROCEED / SIMPLIFY / RETHINK / SKIP`)
plus a TL;DR block at the top of the report.

Output: `.claude/scratchpad/council-report.md`

### audit-review

```text
/council audit-review --report <path-to-audit-report>
brain --mode audit-review --report <path>
```

Per-finding verdict table with header
`| ID | verdict | confidence | justification |` (`REAL / FALSE_POSITIVE
/ NEEDS_MORE_CONTEXT`) plus an in-place rewrite of the report's
`## Council verdict` slot and the YAML `council_pass:` frontmatter key.
Mandatory in `/audit` Phase 5. Prompt template:
`scripts/council/prompts/audit-review.md`.

### retro

```text
brain --mode retro --commit <sha>
```

Reads the commit's diff plus the Council report saved before the
commit, then asks the Pragmatist whether the implementation matches
what was approved. Output: `ALIGNED / DRIFT / UNCLEAR`.

---

## Flags

| Flag | What it does | Phase |
|------|--------------|-------|
| `--no-cache` | Bypass the content-hash cache and force a fresh run | SP6 |
| `--dry-run` | Build full prompts + show estimated cost; no API calls | SP8 |
| `--format json` | Emit single-line JSON instead of markdown report | SP8 |
| `--lang en\|ru\|auto` | Council prompt language (default `auto` = detect from CLAUDE.md) | SP9 |
| `--commit <sha>` | Required with `--mode retro` | SP8 |
| `--report <path>` | Required with `--mode audit-review` | SP1 |
| `--with-facts` | Slash-command pre-flight: extract factual claims, fact-check via `comet-bridge` MCP, pass annotated plan to brain.py | v6.7 |
| `--strict-facts` | With `--with-facts`: fail loudly if `comet-bridge` is unavailable instead of silently skipping the pre-flight | v6.7 |

`brain stats` and `brain clear-cache` are subcommands (not flags) and
are documented under their own slash commands (`/council-stats`,
`/council clear-cache`).

---

## When to Use

| Situation | Use /council |
|-----------|--------------|
| New feature (payments, auth) | yes |
| Security-related changes | yes |
| Architectural refactoring | yes |
| Breaking API changes | yes |
| Plan feels overcomplicated | yes |
| Simple bug fix | no |
| UI tweaks | no |
| Time-critical hotfix | no |

---

## Prerequisites

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh)
```

Check:

```bash
test -f ~/.claude/council/brain.py && echo "Installed" || echo "Not installed"
```

---

## Model Selection

The Council ships with `"model": "auto"` in `~/.claude/council/config.json`.
At runtime `auto` resolves to the toolkit-tracked latest IDs:

- `openai` → `gpt-5.5`
- `gemini` → `gemini-3-pro-preview`

Pin a specific ID by editing `~/.claude/council/config.json`:

```json
{
  "openai": { "model": "gpt-5.5-pro" },
  "gemini": { "model": "gemini-3-pro-preview" }
}
```

When a known-stale ID (e.g., `gpt-5.2`) is detected, brain.py emits a one-line
WARN at startup but does NOT silently rewrite the file — explicit pins are
respected. The `LATEST_MODELS` map in `scripts/council/brain.py` is bumped per
toolkit release.

---

## Process

### Step 0 — Fact-check pre-flight (optional, `--with-facts`)

When `--with-facts` is passed, the Council voices reason on **web-verified
facts** rather than training-data assumptions. The slash command — not
brain.py — handles this step, because it has direct access to the
`comet-bridge` MCP that brain.py (a separate subprocess) cannot reach.

Pipeline:

1. **Pre-flight check.** Verify `comet-bridge` is registered and connected
   (`/mcp` shows `comet-bridge ✔ connected`). If missing:
   - Default mode: print `fact-check skipped (comet-bridge not available)`
     and proceed with the **raw** plan.
   - `--strict-facts` mode: fail with a clear hint to run
     `scripts/setup-comet.sh`.
2. **Extract factual claims.** Read the plan and pull out spans that
   should be fact-checked:
   - **Semantic versions** — `\b\d+\.\d+(?:\.\d+(?:-[a-z0-9.]+)?)?\b`
     (e.g. `Stripe 2026-04-22.dahlia`, `React 19.2.1`).
   - **Dates** — ISO `\b\d{4}-\d{2}-\d{2}\b` and `Month YYYY`.
   - **Library / framework / API names** mentioned with version-sensitive
     verbs (`released`, `deprecated`, `removed in`, `EOL`, `end of life`).
   - **External service references** with claims about features /
     pricing / availability (`Stripe Treasury accepts EUR`, `Postgres 18
     supports X`, etc.).
   - Skip claims that are obvious framing (`our app uses React`) and
     non-factual aspirations (`we want to ship X by Q3`).
3. **Verify each claim.** For each extracted span, call:

   ```text
   mcp__comet-bridge__comet_connect
   mcp__comet-bridge__comet_ask:
     prompt: "Fact-check: <claim>. Return verdict (VERIFIED/DISPUTED/
              UNVERIFIABLE), one-line justification, 2-4 sources with URLs."
     mode: search
     timeout: 60000
   ```

   Equivalent to `/factcheck` per claim, batched.
4. **Annotate the plan.** Replace each verified span inline with the
   verdict marker:

   ```text
   <original claim> [VERIFIED ✓ src1, src2]
   <original claim> [DISPUTED ✗ src1] (actual: <correction>)
   <original claim> [UNVERIFIABLE]
   ```

   Keep markers compact (≤80 chars) so the plan stays readable.
5. **Pass annotated plan to brain.py.** `brain.py` detects the markers
   in `compose_system_prompt()` and appends a directive that teaches both
   voices how to interpret them — they treat VERIFIED as ground truth,
   DISPUTED as known-incorrect, UNVERIFIABLE as needing judgment. No
   re-checking, no wasted verdict space.

### Step 1 — Create Plan

Formulate a detailed implementation plan via `/plan` or by hand.

### Step 2 — Run Council Review

```bash
brain "<detailed implementation plan>"
```

The orchestrator auto-collects:

- CLAUDE.md project rules
- README.md (head)
- `.planning/PROJECT.md` (if present)
- Recent git log (last 20 commits)
- TODO/FIXME grep
- Git diff (uncommitted)
- Files Gemini picked as relevant + matching tests
- Domain-specific persona overlay (security / performance / ux / migration)
- Russian system prompts when `--lang ru` or auto-detect triggers

All blocks pass through redaction (Stripe live keys, sk-ant-, .env
secrets, generic high-entropy hex) before transmission.

### Step 3 — Read Report

`.claude/scratchpad/council-report.md`. The TL;DR at the top shows
verdict + top 3 concerns + detected domain in 5 seconds.

- **PROCEED** — start implementation
- **SIMPLIFY** — reduce scope, re-run
- **RETHINK** — try a different approach, re-run
- **SKIP** — don't do this

### Step 4 — Report to User

```text
Council review complete. Verdict: [PROCEED/SIMPLIFY/RETHINK/SKIP].
Key concerns: [3-bullet TL;DR].
[Commencing implementation / Adjusting plan / Skipping task].
```

---

## Iron Rules

1. **DO** run `/plan` before `/council` for non-trivial tasks.
2. **DO** wait for PROCEED before coding.
3. **DO** address concerns in SIMPLIFY/RETHINK verdicts.
4. **DO** re-run council after major plan changes
   (`--no-cache` if subtle edits should bust the cache).
5. **DO NOT** use for simple bug fixes (overhead).
6. **DO NOT** implement non-PROCEED plans without rework.
7. **DO NOT** use for time-critical hotfixes (too slow).

---

## Output Format

Markdown (default) prints `📋 SUPREME COUNCIL REPORT` with Skeptic +
Pragmatist sections, a per-reviewer summary line, and the final verdict.
JSON (`--format json`) emits one line:
`{verdict, skeptic, pragmatist, concerns_skeptic[], concerns_pragmatist[],
domain, fallback_used: {skeptic, pragmatist}, cache_hit}`.
Full schema and examples live in `docs/COUNCIL.md`.

---

## Integration

- `/plan` → `/council` → implement → `/verify` → `/audit security` → `/deploy`
- `/audit` invokes Council in Phase 5 mandatorily — no `--no-council` flag.
- `/council clear-cache` empties `~/.claude/council/cache/`.
- `/council-stats` shows token usage and cost from `usage.jsonl`.

Deep documentation: `docs/COUNCIL.md`.
