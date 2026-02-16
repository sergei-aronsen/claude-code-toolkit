# Supreme Council — Multi-AI Code Review

> Optional advanced feature: Claude Code writes code, Gemini and ChatGPT review before implementation.

---

## TL;DR

- Claude drafts plan, Gemini reviews architecture, ChatGPT provides second opinion
- Use for: new features, security changes, refactoring, payments, breaking API changes
- Install: `curl -sSL .../setup-council.sh | bash`
- Usage: `/council "add OAuth with Google"` or `brain "add OAuth with Google"`

---

## How It Works

```text
Claude Code → creates plan
    ↓
Gemini (Architect) → analyzes structure, reads files, reviews architecture
    ↓
ChatGPT (Critic) → independent second opinion on plan + Gemini's critique
    ↓
Final Report → APPROVED / REJECTED → saved to .claude/scratchpad/council-report.md
```

### Phase 1 — Context Discovery

Orchestrator runs `tree` to get project structure, sends it to Gemini.
Gemini identifies critical files for the planned change.

### Phase 2 — Architectural Audit (Gemini)

Gemini reads the identified files and performs deep review:

- SOLID/DRY violations
- Security risks (injection, auth bypass, data exposure)
- Performance concerns (N+1, missing indexes, memory leaks)
- Edge cases and race conditions

Ends with: `VERDICT: APPROVED` or `VERDICT: REJECTED`

### Phase 3 — Second Opinion (ChatGPT)

ChatGPT receives the plan and Gemini's critique, provides independent review:

- Agreement/disagreement with Gemini
- Additional concerns missed by Gemini
- Alternative approaches
- Security vulnerabilities

Ends with: `VERDICT: APPROVED` or `VERDICT: REJECTED`

### Phase 4 — Final Report

Both reviews combined into `.claude/scratchpad/council-report.md`.
Claude reads the report and decides whether to proceed.

---

## When to Use

| Situation | Use Council |
|-----------|-------------|
| New feature (payments, auth, integrations) | Yes |
| Security-related changes | Yes |
| Architectural refactoring | Yes |
| Breaking API changes | Yes |
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
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-council.sh | bash
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
SUPREME COUNCIL FINAL REPORT
=============================

ARCHITECT (Gemini gemini-3-pro-preview):
[Gemini's architectural review]

CRITIC (ChatGPT gpt-5.2):
[ChatGPT's security review]

STATUS: PLAN APPROVED / PLAN REJECTED
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

For high-stakes changes, use multi-AI review:
`/council "feature description"` or `brain "feature description"`

**When to use:** New features, security, refactoring, payments, breaking API changes.
**Output:** `.claude/scratchpad/council-report.md` (APPROVED / REJECTED)

Full guide: `components/supreme-council.md`
```
