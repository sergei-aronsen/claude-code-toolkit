# Supreme Council — Deep Reference

This document covers the Supreme Council subsystem in depth. For the
slash command surface, see `commands/council.md`. For per-call cost
analytics, see `commands/council-stats.md`.

The Council ships as part of `claude-code-toolkit` and lives globally
under `~/.claude/council/`. One install drives every project.

---

## Architecture

The Council is a single-file Python orchestrator
(`scripts/council/brain.py`, ~2700 lines, no pip dependencies) that
coordinates two AI reviewers — the Skeptic (Gemini) and the Pragmatist
(ChatGPT) — across three modes: `validate-plan`, `audit-review`, and
`retro`.

```text
   ┌────────────────┐
   │   /council     │
   │  slash command │
   └────────┬───────┘
            │
            ▼
   ┌────────────────┐    ┌─────────────────────────────┐
   │   brain.py     │───▶│ ~/.claude/council/cache/    │ ← SP6 hash cache
   │  orchestrator  │    └─────────────────────────────┘
   └─┬────────────┬─┘
     │            │
     ▼            ▼
 ┌────────┐  ┌──────────────┐
 │Skeptic │  │ Pragmatist   │
 │(Gemini)│  │ (ChatGPT/    │
 │CLI/API │  │  Codex CLI)  │
 └───┬────┘  └──────┬───────┘
     │              │
     └──────┬───────┘
            ▼
  ┌──────────────────┐
  │ OpenRouter free  │ ← SP5 fallback chain
  │ chain            │
  └──────────────────┘
```

Per-run state ends up in:

- `.claude/scratchpad/council-report.md` — markdown report (or empty
  on `--format json`).
- `~/.claude/council/cache/<key>.json` — content-hash cache of
  identical requests within TTL.
- `~/.claude/council/usage.jsonl` — append-only token + cost log.

---

## Installation

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh)
```

The installer asks you to choose:

- **Gemini mode** — CLI (free under subscription, requires
  `npm install -g @google/gemini-cli`) or API (`GEMINI_API_KEY`).
- **OpenAI mode** — Codex CLI (`npm install -g @openai/codex`) or
  API (`OPENAI_API_KEY`).
- **OpenRouter fallback key** — optional, used when the primary
  backend errors or rate-limits.

Config lives at `~/.claude/council/config.json` with `0600` perms.
Local edits are preserved on update via the `.upstream-new.json`
sidecar pattern.

---

## Modes

### validate-plan

Run before implementing a non-trivial feature. The Skeptic and
Pragmatist each receive the plan plus a redacted context bundle:

- CLAUDE.md project rules
- README head
- `.planning/PROJECT.md` (if present)
- Last 20 commits (`git log`)
- TODO/FIXME grep
- Git diff (uncommitted)
- Files Gemini selected as relevant + matching tests
- Domain-specific persona overlay

Each reviewer emits a verdict (`PROCEED / SIMPLIFY / RETHINK / SKIP`).
The final verdict is the more conservative of the two.

### audit-review

Phase 5 of `/audit`. Council reads the structured audit report at
`.claude/audits/<type>-<TIMESTAMP>.md` and emits a per-finding verdict
table (`REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT`). The verdict slot
is rewritten in place; the YAML `council_pass:` frontmatter mutates
from `pending` to `passed | failed | disputed`.

### retro

Post-implementation alignment check. Reads `git show <sha>` plus the
Council report saved before the commit and asks the Pragmatist whether
the diff matches the approved plan. Output: `ALIGNED / DRIFT / UNCLEAR`.

---

## Provider Selection

| Provider | Mode | Cost | Reasoning Effort |
|----------|------|------|------------------|
| Gemini 3 Pro | API | $1.25/M input, $10/M output | thinking_budget=32768 |
| Gemini CLI | CLI | $0 (subscription) | n/a |
| GPT-5.2 | API | $1.25/M input, $10/M output | reasoning.effort=high |
| GPT-5.2 Pro | API | $15/M input, $60/M output | reasoning.effort=high |
| o3 | API | $2/M input, $8/M output | reasoning.effort=high |
| Codex CLI | CLI | $0 (subscription) | --config model_reasoning_effort=high |
| OpenRouter free chain | API | $0 | varies |

Switch modes by editing `~/.claude/council/config.json`:

```json
{
  "gemini":  {"mode": "cli", "model": "gemini-3-pro-preview", "thinking_budget": 32768},
  "openai":  {"mode": "cli", "model": "gpt-5.2", "reasoning_effort": "high",
              "cli_reasoning_effort": "high"},
  "fallback": {"openrouter": {"api_key": "", "models": [
    "tencent/hy3-preview:free",
    "nvidia/nemotron-3-super-120b-a12b:free",
    "inclusionai/ling-2.6-1t:free",
    "openrouter/free"
  ]}}
}
```

Pricing rates live separately in `~/.claude/council/pricing.json` and
are consulted by `record_usage()` to compute per-call cost. Update
when provider rates change.

---

## Cost Considerations

- **CLI providers cost $0** but token estimates are recorded for
  visibility (chars / 4 estimate, marked `estimated: true`).
- **API providers report exact tokens** via `usage` payload.
- **Cache hits cost $0** and are logged with `mode:
  validate-plan-cache-hit` so `/council-stats` shows cache savings.
- **OpenRouter free models cost $0** but reliability is variable; the
  chain tries each model until one succeeds.

Set a confirmation gate when costs spike:

```bash
export COUNCIL_COST_CONFIRM_THRESHOLD=0.50
```

The user is prompted to confirm any call where the estimated input
cost exceeds the threshold. CI / non-TTY runs bypass the gate with a
stderr warning so automation never blocks silently.

---

## Customization

### Editable system prompts

The four base prompts live at `~/.claude/council/prompts/`:

- `skeptic-system.md`
- `pragmatist-system.md`
- `audit-review-skeptic.md`
- `audit-review-pragmatist.md`

Edit them directly. Updates from upstream are written alongside as
`<name>.md.upstream-new.md` so your edits never get clobbered. Diff
with `diff -u <name>.md <name>.md.upstream-new.md` and merge by hand.

### Persona overlays (SP8)

When the plan classifies into a non-general domain, the matching
overlay under `~/.claude/council/prompts/personas/<domain>-<role>.md`
prepends to the base prompt:

| Domain | Trigger keywords |
|--------|------------------|
| security | auth, password, crypto, JWT, token, session |
| performance | perf, latency, cache, N+1, slow, optimi[sz]e |
| ux | UI, UX, accessibility, a11y, WCAG, screen reader |
| migration | migration, backwards, deprecat\* |

Edit overlays directly to inject team-specific guidance.

### Russian translations (SP9)

`~/.claude/council/prompts/ru/<name>.md` replaces the English source
when `--lang ru` or auto-detection (Cyrillic ratio in CLAUDE.md > 0.2)
selects ru. Verdict tokens stay English so the orchestrator's parser
remains language-agnostic.

### Redaction patterns (SP3)

`~/.claude/council/redaction-patterns.txt` carries one regex per line.
Defaults cover Stripe live keys (`sk_live_*`), Anthropic API keys
(`sk-ant-*`), generic high-entropy hex, and `.env` quoted secrets.
Append project-specific patterns (e.g., your auth header shape) and
they apply to every Council call.

### Pricing overrides (SP4)

`~/.claude/council/pricing.json` overlays the built-in `DEFAULT_PRICING`
table. Add or override per-model rates as providers update prices:

```json
{
  "gpt-5.3": {"input_per_1m": 1.50, "output_per_1m": 12.0}
}
```

---

## Cache (SP6)

- Key = sha256(plan | git_head | cwd)
- Path = `~/.claude/council/cache/<key>.json`
- TTL = `config.cache.ttl_days` (default 7)
- Hit = no provider call; output replays with `[cached <ts>]` marker
- Bypass single run: `brain --no-cache "<plan>"`
- Wipe everything: `/council clear-cache` or `brain clear-cache`

---

## Observability

`~/.claude/council/usage.jsonl` is append-only. Each row:

```json
{
  "ts": "2026-04-29T15:00:00Z",
  "mode": "validate-plan-skeptic",
  "provider": "gemini", "model": "gemini-3-pro-preview",
  "tokens_in": 18432, "tokens_out": 1842,
  "cost_usd": 0.041,
  "estimated": false,
  "verdict": "SIMPLIFY",
  "fallback_used": false,
  "plan_hash": "abcdef1234567890"
}
```

Inspect via `/council-stats --day | --week | --month | --total | --csv`.

Set `COUNCIL_DEBUG=1` to trace every context block (size, redaction
counts, persona matches, lang switches) on stderr.

Set `COUNCIL_NO_USAGE_LOG=1` to opt out of usage logging (rare; CI
scenarios where `usage.jsonl` is sensitive).

---

## MCP integration

Phase 24 Sub-Phase 11 ships `scripts/council/mcp-server.py` — a
stdio JSON-RPC MCP server that exposes Council to Claude Desktop.
See the SP11 changelog entry once available, or run
`scripts/setup-council.sh` after the v4.8 release for the auto-config
into `claude_desktop_config.json`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Config not found: ~/.claude/council/config.json` | Council not installed | Run `setup-council.sh` |
| `Gemini CLI mode selected but 'gemini' is not in PATH` | CLI missing | `npm install -g @google/gemini-cli` or switch to API mode |
| `OpenAI CLI mode selected but 'codex' is not in PATH` | Codex CLI missing | `npm install -g @openai/codex` or switch to API mode |
| `No reviewers available — aborting` | Both providers unavailable | Configure at least one |
| Verdict feels stale | Cache hit on subtly different plan | `--no-cache` or `clear-cache` |
| Cost gate blocks a CI run | Threshold too low | Raise `COUNCIL_COST_CONFIRM_THRESHOLD` or unset |
| Redaction missed a secret | Pattern not in defaults | Append to `~/.claude/council/redaction-patterns.txt` |
| Russian output wanted but didn't trigger | CLAUDE.md too short / English-heavy | Force with `--lang ru` |

---

## Related Files

- `scripts/council/brain.py` — orchestrator (single file, no pip deps)
- `scripts/setup-council.sh` — installer wizard
- `scripts/lib/council-prompts.sh` — prompt + redaction + pricing + persona installers
- `templates/council-prompts/` — upstream prompt sources
- `templates/council-pricing.json` — upstream pricing defaults
- `templates/council-redaction-patterns.txt` — upstream redaction defaults
- `commands/council.md` — slash command surface
- `commands/council-stats.md` — usage analytics command
- `commands/council-clear-cache.md` — cache reset command
