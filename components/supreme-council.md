# Supreme Council — Multi-AI Plan Validation

> Optional advanced feature: before Claude Code starts coding, Gemini and ChatGPT challenge whether the plan is worth doing at all.

---

## TL;DR

- Claude drafts plan, Gemini challenges justification, ChatGPT evaluates practicality
- NOT a linter — validates whether the approach is justified, not whether the code is clean
- Verdicts: PROCEED / SIMPLIFY / RETHINK / SKIP
- Install: `curl -sSL .../setup-council.sh | bash`
- Usage: `/council "add OAuth with Google"` or `brain "add OAuth with Google"`

---

## How It Works

```text
Claude Code → creates plan
    ↓
The Skeptic (Gemini) → challenges justification, checks for overengineering
    ↓
The Pragmatist (ChatGPT) → evaluates production readiness, maintenance cost
    ↓
Final Report → PROCEED / SIMPLIFY / RETHINK / SKIP → .claude/scratchpad/council-report.md
```

### Phase 1 — Context Discovery

Orchestrator runs `tree` to get project structure, sends it to Gemini.
Gemini identifies critical files for the planned change.

### Phase 2 — The Skeptic (Gemini)

Gemini reads the identified files and challenges the plan:

- **Problem Assessment** — is this solving a real problem?
- **Simplicity Check** — is there a simpler approach?
- **Do-Nothing Analysis** — what happens if we skip this entirely?
- **Concerns** — max 3, ranked by impact (skips trivial issues Claude Code handles)

Does NOT look for SOLID violations, linting issues, or basic security — Claude Code already does that.

In CLI mode, Gemini reads files natively via `@file` syntax (no size limits).
In API mode, file contents are embedded in the prompt (20KB per file limit).

Both modes include **git diff** (uncommitted changes) and **CLAUDE.md** project rules
when available, so reviewers understand what is changing and what conventions apply.

Ends with: `VERDICT: PROCEED / SIMPLIFY / RETHINK / SKIP`

### Phase 3 — The Pragmatist (ChatGPT)

ChatGPT receives the plan, The Skeptic's assessment, **file contents**, git diff, and
project rules. Does NOT repeat The Skeptic's points. Focuses on:

- **Production Readiness** — will this actually work in production?
- **Maintenance Forecast** — long-term cost, will the next developer understand this?
- **Alternative Approaches** — proven prior art, libraries, simpler patterns
- **Agreement with Skeptic** — specific agree/disagree creates a dialogue

Ends with: `VERDICT: PROCEED / SIMPLIFY / RETHINK / SKIP`

### Phase 4 — Final Report

Both reviews combined into `.claude/scratchpad/council-report.md`.
The more conservative verdict wins (SKIP > RETHINK > SIMPLIFY > PROCEED).
Claude reads the report and decides how to proceed.

---

## Verdicts

| Verdict | Meaning | Action |
|---------|---------|--------|
| PROCEED | Plan is justified and well-scoped | Start implementation |
| SIMPLIFY | Core idea is valid, approach is overcomplicated | Reduce scope, re-run `/council` |
| RETHINK | Problem is real, solution is wrong | Try different approach, re-run `/council` |
| SKIP | Cost outweighs benefit | Don't do this, move on |

---

## When to Use

| Situation | Use Council |
|-----------|-------------|
| New feature (payments, auth, integrations) | Yes |
| Security-related changes | Yes |
| Architectural refactoring | Yes |
| Breaking API changes | Yes |
| Plan feels overcomplicated | Yes |
| "Should we even do this?" moments | Yes |
| Simple bug fix | No |
| UI tweaks, typos | No |
| Time-critical hotfix | No |

---

## Installation

### Prerequisites

- Python 3.8+
- Gemini CLI or Gemini API key
- OpenAI API key

### Install

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh | bash
```

The script will:

1. Check dependencies (Python, tree)
2. Ask for Gemini mode (CLI or API)
3. Ask for API keys
4. Install orchestrator to `~/.claude/council/`
5. Add `brain` alias to shell config
6. Verify installation

### Gemini CLI Setup (if chosen)

```bash
npm install -g @google/gemini-cli
gemini login
```

---

## Configuration

**File:** `~/.claude/council/config.json`

```json
{
  "gemini": {
    "mode": "cli",
    "api_key": "",
    "model": "gemini-3-pro-preview"
  },
  "openai": {
    "api_key": "",
    "model": "gpt-5.2"
  }
}
```

### Gemini Modes

- `cli` — uses `gemini` command. Free with Google subscription.
- `api` — uses REST API. Requires key from [AI Studio](https://aistudio.google.com/app/apikey).

### Environment Variable Overrides

Environment variables take priority over config:

```bash
export OPENAI_API_KEY="sk-..."
export GEMINI_API_KEY="..."
```

### Changing Models

Edit `config.json` to update model names as new versions release.

---

## Usage

### From Claude Code

```text
/council "add OAuth login with Google"
```

### From Terminal

```bash
brain "add payment processing with Stripe"
# or:
python3 ~/.claude/council/brain.py "refactor auth to use JWT"
```

### Output

Report saved to `.claude/scratchpad/council-report.md`:

```text
SUPREME COUNCIL REPORT
============================================================

THE SKEPTIC (Gemini gemini-3-pro-preview):
[Problem assessment, simplicity check, do-nothing analysis]

THE PRAGMATIST (ChatGPT gpt-5.2):
[Production readiness, maintenance forecast, alternatives]

------------------------------------------------------------
  Skeptic:    SIMPLIFY
  Pragmatist: PROCEED
  Final:      SIMPLIFY — Core idea is valid, but the approach is overcomplicated.
------------------------------------------------------------

VERDICT: SIMPLIFY
```

---

## Security vs Original Implementation

| Issue | Original | Fixed |
|-------|----------|-------|
| API keys | Hardcoded in source | config.json + env vars |
| Shell injection | `shell=True` | `shell=False` with list args |
| Temp files | No cleanup on crash | `try/finally` cleanup |
| Input validation | None | Length + path traversal checks |
| Models | Hardcoded | Configurable |
| Path traversal | No check | Files must be under project root |

---

## Cost Estimate

Per review (typical feature):

| Model | Approx Cost |
|-------|-------------|
| Gemini (CLI) | Free with subscription |
| Gemini (API) | ~$0.01-0.05 |
| ChatGPT (API) | ~$0.10-0.50 |
| **Total** | **~$0.10-0.50** |

---

## Context Enrichment

The orchestrator automatically collects and sends to reviewers:

- **Project files** — critical files identified by Gemini (Gemini CLI uses native `@file`)
- **Git diff** — uncommitted changes (`git diff HEAD`, max 30KB)
- **CLAUDE.md** — project rules and conventions (max 10KB)
- **Total context limit** — 200K characters across all files

This ensures reviewers see actual code, what is changing, and project conventions.

---

## Limitations

- Adds 1-3 minutes to planning phase
- Requires external API access
- Not suitable for time-critical hotfixes
- Reviewers may disagree — human judgment needed
- Quality depends on current model capabilities

---

## Add to CLAUDE.md

```markdown
## Supreme Council (Optional)

For high-stakes changes, use multi-AI plan validation:
`/council "feature description"` or `brain "feature description"`

**When to use:** New features, security, refactoring, overcomplicated plans.
**Verdicts:** PROCEED / SIMPLIFY / RETHINK / SKIP
**Output:** `.claude/scratchpad/council-report.md`

Full guide: `components/supreme-council.md`
```
