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

Per-finding verdict table (`REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT`)
plus an in-place rewrite of the report's `## Council verdict` slot and
the YAML `council_pass:` frontmatter key. Mandatory in `/audit` Phase 5.

### retro

```text
brain --mode retro --commit <sha>
```

Phase 24 SP8. Reads the commit's diff plus the Council report saved
before the commit, then asks the Pragmatist whether the implementation
matches what was approved. Output: `ALIGNED / DRIFT / UNCLEAR`.

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

## Process

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

Markdown report header (after `--format markdown`, the default):

```text
============================================================
📋 SUPREME COUNCIL REPORT
============================================================

🧐 THE SKEPTIC (Gemini ...): ... VERDICT: ...
🔨 THE PRAGMATIST (ChatGPT ...): ... VERDICT: ...

------------------------------------------------------------
  Skeptic:    <v>
  Pragmatist: <v>
  Final:      <v> — <one-line reason>
------------------------------------------------------------

✅|💡|🔄|⛔ VERDICT: <final>
============================================================
```

JSON shape (`--format json`):

```json
{
  "verdict": "PROCEED|SIMPLIFY|RETHINK|SKIP",
  "skeptic": "...", "pragmatist": "...",
  "concerns_skeptic": [...], "concerns_pragmatist": [...],
  "domain": "security|performance|ux|migration|general",
  "fallback_used": {"skeptic": false, "pragmatist": false},
  "cache_hit": false
}
```

---

## Integration

- `/plan` → `/council` → implement → `/verify` → `/audit security` → `/deploy`
- `/audit` invokes Council in Phase 5 mandatorily — no `--no-council` flag.
- `/council clear-cache` empties `~/.claude/council/cache/`.
- `/council-stats` shows token usage and cost from `~/.claude/council/usage.jsonl`.

Deep documentation: `docs/COUNCIL.md`.
