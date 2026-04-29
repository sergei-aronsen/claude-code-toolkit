# Phase 24 — Council Globalize + Rework

> **Goal:** Move Supreme Council from mixed scope to fully global, file-based prompts,
> add cost tracking, OpenRouter + Codex CLI fallback, GSD integration, MCP server for
> Claude Desktop. Ship as one cohesive feature PR.
>
> **Branch:** `feature/council-global-rework`
> **Created:** 2026-04-29
> **Owner:** Claude Code (autonomous execution per fresh-session entry below)

---

## Fresh-session entry

After context clear, drop into the project root and say:

```text
Read .planning/phases/24-council-globalize/PLAN.md and execute Sub-Phase 1.
```

After Sub-Phase 1 ships (PR review or self-merge per the user), continue with
`Read … and execute Sub-Phase 2.` etc. Each sub-phase is independent and
self-contained — the plan, acceptance criteria, and commit-message templates
are all here.

---

## Context summary (so the fresh session has everything)

### What Council is today

- **Binary:** `~/.claude/council/brain.py` (1175 lines, Python 3.8+, curl-only).
- **Config:** `~/.claude/council/config.json` (0600 perms, holds API keys).
- **Shell alias:** `brain` added to `~/.zshrc` / `~/.bash_profile` by
  `init-claude.sh::setup_council` (lines 803–824).
- **Audit-review prompt:** `~/.claude/council/prompts/audit-review.md` (already
  global).
- **Slash command:** `commands/council.md` — currently per-project (installed to
  `./.claude/commands/` via `manifest.json`). **This is the inconsistency.**
- **CLAUDE.md instructions:** `templates/base/CLAUDE.md:305` "Supreme Council
  (Optional)". `templates/global/CLAUDE.md` has **0 mentions**.

### Council orchestration (validate-plan mode)

`brain.py::_run_validate_plan` does Phase 1 (Gemini picks files) → Phase 2
(Skeptic verdict) → Phase 3 (Pragmatist evaluates plan + Skeptic's verdict)
→ Phase 4 (final report). Verdicts: `PROCEED / SIMPLIFY / RETHINK / SKIP`.

### Council orchestration (audit-review mode)

`brain.py::run_audit_review` parses an audit report, dispatches Gemini +
ChatGPT in **parallel** via `ThreadPoolExecutor` (the validate-plan flow is
serial because Pragmatist depends on Skeptic). Each backend produces
`<verdict-table>` and `<missed-findings>` blocks. Verdicts:
`REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT`.

### Existing system prompts (in brain.py:51–83)

- `GEMINI_SYSTEM` (Skeptic — challenges WHETHER to build)
- `GPT_SYSTEM` (Pragmatist — production readiness)
- `AUDIT_REVIEW_GEMINI_SYSTEM`
- `AUDIT_REVIEW_GPT_SYSTEM`

### Provider chain (today)

1. **Gemini CLI** (preferred, free with Google subscription)
2. **Gemini API** (fallback)
3. **OpenAI API** (only path for ChatGPT)

### Provider chain (target after this phase)

1. **Gemini CLI** (free with Google sub)
2. **Codex CLI** (free with ChatGPT Plus/Pro $20+) — NEW
3. **Gemini API** (fallback)
4. **OpenAI API** (fallback)
5. **OpenRouter free chain** (last resort) — NEW

### Confirmed user decisions (2026-04-29)

- ✅ Variant A: Council fully global (binary already global; command + CLAUDE.md
  follow). Per-project `commands/council.md` removed from manifest.
- ✅ Per-project output for reports stays at
  `./.claude/scratchpad/council-report.md` (linked to working branch).
- ✅ Prompts as files in `~/.claude/council/prompts/`.
- ✅ FP-recheck phrase mandatory in every system prompt.
- ✅ Cost tracker via `/council stats --day|--week|--month|--total`.
- ✅ OpenRouter free fallback chain (specific models: `tencent/hy3-preview:free`,
  `nvidia/nemotron-3-super-120b-a12b:free`, `inclusionai/ling-2.6-1t:free`,
  `openrouter/free`).
- ✅ Codex CLI as preferred ChatGPT provider when Plus subscription is active.
- ✅ Caching by hash, domain auto-detect, `--dry-run`, retro mode, privacy
  redaction, TL;DR summary, JSON output.
- ✅ Multilingual prompts (ru) — Russian by default per user preference.
- ✅ MCP server so Council works from Claude Desktop too.
- ✅ **Reasoning effort: maximum.** Council runs are infrequent (a few times
  per day at most), so we always pay for the strongest reasoning the model
  offers. Concretely:
  - OpenAI: `reasoning: { effort: "high" }` for `gpt-5.2-pro` / `o3-pro` /
    `o3` (high is the max public effort); for `gpt-5.2` use the
    `reasoning_effort` API param.
  - Codex CLI: `--config model_reasoning_effort=high` (Codex CLI supports
    `low|medium|high`; default is `medium`).
  - Gemini API: `thinkingConfig: { includeThoughts: true, thinkingBudget:
    32768 }` (max budget on `gemini-3-pro-preview`).
  - Gemini CLI: relies on the model's default thinking budget — no flag
    surfaces yet, document this and leave room for `--thinking-budget`
    when CLI exposes it.
  - All four are configurable via `~/.claude/council/config.json` keys
    `gemini.thinking_budget`, `openai.reasoning_effort`,
    `openai.cli_reasoning_effort`. Defaults pinned to "max".
- ✅ **CLI-first provider recommendations during setup.** During
  `setup-council.sh` (and `init-claude.sh::setup_council`), detect:
  - `command -v gemini` → if missing, print:
    `⚠ Gemini CLI not found. Install it (npm i -g @google/gemini-cli) and
    sign in with a Google AI Pro/Ultra subscription to avoid API charges.`
  - `command -v codex` → if missing, print:
    `⚠ Codex CLI not found. Install it (npm i -g @openai/codex or brew
    install --cask codex) and sign in with ChatGPT Plus/Team to avoid API
    charges.`
  Detection is informational only — user can still pick "API" mode and
  paste keys. No hard block. Show recommendations once at setup; do not
  re-warn on every Council run.
- ❌ No local-model fallback (Ollama). Claude Code Opus is smarter than any
  small local model, and OpenRouter free covers the API outage case.
- ❌ No new tests for each phase — smoke tests inline are enough; existing
  `scripts/tests/test-council-*.sh` runs as regression gate.

### Project conventions to follow

- Conventional Commits: `feat(council):`, `fix(council):`, `refactor(council):`.
- Branch already created: `feature/council-global-rework`.
- All scripts pass `shellcheck -S warning` before commit.
- All Python passes `python3 -c "import ast; ast.parse(open(...).read())"`.
- `make check` and `make test` zero-fail before any push.
- Russian for explanation in PR body / commit body footers; subject line in
  English (per project's English-language commit history).

---

## Sub-Phase 1 — Globalize Council artifacts (P0)

**Goal:** Move slash command + instructions to global scope; binary stays where
it is; existing per-project installs get a one-shot cleanup hint.

### Files touched

- `scripts/setup-council.sh` — also install `~/.claude/commands/council.md`
  (download from `commands/council.md` upstream into the global commands dir).
- `scripts/init-claude.sh::setup_council` — same addition. Either inline or
  refactor to call `setup-council.sh` non-interactively (preferred:
  inline — matches current pattern, fewer dependencies on TTY plumbing).
- `manifest.json` — remove `commands/council.md` from `files.commands[]`. The
  file stays in the repo; it's just no longer per-project distributable.
  Update `manifest_version` stays at `2`. Bump `version` to `4.5.0` (this
  phase is the headliner of the v4.5 milestone).
- `templates/base/CLAUDE.md` — remove the "Supreme Council (Optional)"
  section at line 305. Replace with a one-liner:
  `> Supreme Council is global — see ~/.claude/CLAUDE.md "Supreme Council" section.`
- `templates/global/CLAUDE.md` — add a full "Supreme Council" section (see
  Sub-Phase 2 for the FP-recheck-aware content; for Sub-Phase 1 ship the
  current per-project content verbatim, FP recheck arrives in Sub-Phase 2).
- `scripts/verify-install.sh` — extend the "Council" section to confirm:
  - `~/.claude/council/brain.py` exists and is +x
  - `~/.claude/commands/council.md` exists (NEW check)
  - `~/.claude/council/config.json` exists (0600)
  - `brain` alias resolves in shell.
- `scripts/migrate-to-complement.sh` — add detection of stale per-project
  `./.claude/commands/council.md` from v4.4 installs. If found AND
  `~/.claude/commands/council.md` also exists with different sha256, log a
  warning + offer interactive removal. Idempotent on re-run.
- `scripts/setup-council.sh` — at the top of the wizard (after the
  "Checking dependencies" step), add a `recommend_clis()` helper that
  prints both warnings if `gemini` / `codex` are missing from `$PATH`. The
  helper is purely informational and never blocks; record the printed
  recommendations to `~/.claude/council/setup.log` for later auditing.
- `scripts/init-claude.sh::setup_council` — call the same `recommend_clis`
  helper before the existing config-file write. Source the helper from
  `setup-council.sh` (extracted into `scripts/lib/cli-recommendations.sh`
  so both entry points can share it).
- `README.md` — update install matrix references.
- `CHANGELOG.md` — add `[Unreleased]` entry for v4.5.0.

### Acceptance criteria

- Fresh `init-claude.sh` install puts `council.md` in `~/.claude/commands/`
  AND nothing in `./.claude/commands/council.md`.
- Fresh project's `manifest.json` consumer (smart update) does not list
  `commands/council.md` as a file to install.
- `verify-install.sh` reports Council OK only when global command is present.
- `make check` + `make test` pass.
- No regression in existing `scripts/tests/test-council-audit-review.sh`
  (81 assertions).

### Commit plan

1. `refactor(council): remove commands/council.md from per-project manifest`
2. `feat(council): install slash command globally via setup-council.sh`
3. `feat(council): mirror global install in init-claude.sh::setup_council`
4. `refactor(templates): drop Supreme Council from base CLAUDE.md`
5. `feat(templates): add Supreme Council section to global CLAUDE.md`
6. `feat(verify): check global Council command in verify-install.sh`
7. `feat(migrate): detect stale per-project council.md leftovers`
8. `docs(council): refresh README + CHANGELOG for global Council`

---

## Sub-Phase 2 — Prompts as files + FP-recheck

**Goal:** Move all 4 system prompts out of brain.py into editable files; add
mandatory FP-recheck + Confidence + Code citation requirements.

### Files touched

- New: `templates/council-prompts/skeptic-system.md`
- New: `templates/council-prompts/pragmatist-system.md`
- New: `templates/council-prompts/audit-review-skeptic.md`
- New: `templates/council-prompts/audit-review-pragmatist.md`
- `scripts/setup-council.sh` — install all four into `~/.claude/council/prompts/`
  on first run. Sha256-guard: if a file exists AND its sha256 differs from the
  shipped one AND no `<!-- council-prompt-ours: <sha> -->` marker matches the
  shipped sha → preserve user's customization, write `<name>.upstream-new.md`
  alongside (mirrors the `.security.new` pattern from PR #9).
- `scripts/init-claude.sh::setup_council` — call same install logic.
- `scripts/council/brain.py` — refactor:
  - New `load_prompt(name)` function: read from
    `~/.claude/council/prompts/<name>.md`. If file missing → fall back to
    embedded constant (keeps brain.py self-contained for first-run case).
  - `GEMINI_SYSTEM` / `GPT_SYSTEM` / `AUDIT_REVIEW_*` become defaults; runtime
    reads from files.
  - Helpers cache the file contents per process (read once).
- New file content for each prompt:
  - **Existing role description** (preserved verbatim — Skeptic, Pragmatist,
    audit-reviewer).
  - **NEW: FP-recheck block** (mandatory):

    ```text
    Before stating any concern, recommendation, or finding:
    1. Verify it against the actual code path (file content provided in context).
       Cite the specific file path and line numbers in your justification.
    2. State your **Confidence: HIGH | MEDIUM | LOW** for each item.
    3. If LOW or you cannot find the supporting code, explicitly mark
       "needs verification" — do NOT fabricate concerns.
    Many findings are false positives in practice. It is better to say
    "I'm not sure, please verify lines X–Y of file Z" than to recommend
    an incorrect fix.
    ```

  - **NEW: Mandatory verdict template** with explicit `**Confidence:**` and
    `**Code citation:**` fields per concern.

### Acceptance criteria

- Editing `~/.claude/council/prompts/skeptic-system.md` and re-running
  `/council "..."` reflects the new instructions without re-installing
  brain.py.
- All four prompt files include the FP-recheck block verbatim.
- `make test` passes — `test-council-audit-review.sh` 81 assertions still
  green (the audit-review prompt content changes but verdict-table parsing
  is unchanged).

### Commit plan

1. `feat(council): externalize system prompts to ~/.claude/council/prompts/`
2. `feat(council): require FP-recheck + Confidence in every Council verdict`
3. `feat(council): preserve user prompt edits via .upstream-new pattern`

---

## Sub-Phase 3 — Context enrichment

**Goal:** Pass more relevant context to Council without blowing the 200K
budget; add privacy redaction.

### Files touched

- `scripts/council/brain.py` — new helper functions:
  - `get_readme()` — read `<root>/README.md`, cap at 10K chars.
  - `get_recent_log()` — `git log --oneline -20`, cap 5K.
  - `get_todos()` — `grep -rEn 'TODO|FIXME|HACK|XXX'` over top-level dirs
    (skip node_modules/.git/.venv etc.), cap 5K.
  - `get_planning_context()` — read `<root>/.planning/PROJECT.md` if exists,
    cap 10K.
  - `get_tests_for(file_paths)` — for each src file Gemini picked, also pull
    the matching test (`tests/<basename>*`, `__tests__/<basename>*`,
    `test_<basename>*`) if present.
- New: `~/.claude/council/redaction-patterns.txt` (default: API key formats,
  bearer tokens, JWT, .env values). User can append patterns. Each line is a
  Python regex.
- `scripts/council/brain.py::redact_context()` — apply patterns before
  sending. Replaces matches with `***REDACTED***`. Logged count of redactions
  (without content) to stderr.
- `_run_validate_plan` integrates new context blocks into both Skeptic and
  Pragmatist prompts (after the existing `rules_block`, before `FILES CONTEXT`).
- All new fetches respect the `MAX_TOTAL_CONTEXT` budget; if adding a block
  would exceed, truncate proportionally and emit a `(context truncated)`
  marker.

### Acceptance criteria

- `brain "fix auth"` from a project with README/git history/.planning/
  surfaces all four new context blocks in stderr trace mode (`COUNCIL_DEBUG=1`).
- Redaction triggered on a fixture containing `OPENAI_API_KEY=sk-foobar` →
  output replaces value with `***REDACTED***`.
- Total context never exceeds 200K chars (assert in unit-style smoke).

### Commit plan

1. `feat(council): pull README, git log, TODOs into Council context`
2. `feat(council): auto-include matching tests for Gemini-picked source files`
3. `feat(council): redact secrets before sending to providers`

---

## Sub-Phase 4 — Cost tracking + `/council stats`

**Goal:** Log every API call's token usage + estimated cost; expose via slash
command.

### Files touched

- `scripts/council/brain.py` — extend each `ask_*` function to capture token
  usage from response. Append one JSON line per call to
  `~/.claude/council/usage.jsonl`:

  ```json
  {
    "ts": "2026-04-29T14:32:15Z",
    "mode": "validate" | "audit-review",
    "provider": "gemini" | "openai" | "openrouter" | "codex",
    "model": "gemini-3-pro-preview",
    "tokens_in": 12453,
    "tokens_out": 847,
    "cost_usd": 0.0234,
    "verdict": "PROCEED",
    "fallback_used": false,
    "plan_hash": "a1b2c3d4..."
  }
  ```

- New: `~/.claude/council/pricing.json` — pricing per model in $/1M tokens
  (input + output). Shipped with current rates; user updates manually.
- New: `commands/council-stats.md` (global, installed by setup-council.sh
  alongside `council.md`) — usage doc.
- `scripts/council/brain.py::cmd_stats()` — implements `--day|--week|--month|--total`
  reading from usage.jsonl. Group by provider/model/mode. Output table or
  CSV (`--csv`). Optional `--since YYYY-MM-DD`.
- New: confirm-gate (env `COUNCIL_COST_CONFIRM_THRESHOLD=0.10`). If estimated
  cost (input tokens × in_rate) exceeds threshold, prompt confirmation before
  send. Default disabled.

### Acceptance criteria

- After 3 `/council` calls, `/council stats --day` shows 3 rows with
  non-zero token counts and a $ total.
- `--csv` produces parseable CSV (one row per call).
- Disabling network and running `--total` does not error (reads local file).

### Commit plan

1. `feat(council): log every call to usage.jsonl with token counts`
2. `feat(council): add /council stats command with --day/--week/--month/--total`
3. `feat(council): optional cost-confirm gate via env threshold`

---

## Sub-Phase 5 — Codex CLI + OpenRouter fallback chain

**Goal:** Add Codex CLI as preferred ChatGPT provider (free with Plus); add
OpenRouter free models as last-resort fallback.

### Files touched

- `scripts/council/brain.py`:
  - New `ask_chatgpt_cli(prompt, model, file_paths=None)` mirroring
    `ask_gemini_cli`. Invocation: pipe prompt to stdin of `codex exec --json
    --model <model>` (verify exact flags during impl — Codex CLI docs say it
    supports non-interactive exec mode; check `codex exec --help` first).
  - `ask_chatgpt(prompt, config, system_prompt=None)` routes by
    `config.openai.mode`: `"cli"` → `ask_chatgpt_cli`, `"api"` → existing
    API path. Default `cli` if `command -v codex` succeeds, else `api`.
  - New `ask_openrouter(prompt, model, api_key)`. Tries each model in
    `config.fallback.openrouter.models[]` in order until one succeeds.
  - New fallback orchestrator: if primary backend (Gemini for Skeptic,
    OpenAI for Pragmatist) fails with quota/network/5xx, retry via
    OpenRouter chain, log `fallback_used: true` in usage.jsonl.
- `scripts/setup-council.sh` and `scripts/init-claude.sh::setup_council`:
  - Detect `command -v codex` during interactive setup. If present and user
    chose "1) Codex CLI" prompt, write `mode: "cli"` to config.openai.
  - Add OpenRouter step: optional, prompts for key, no key = no fallback.
- **Reasoning effort wiring** (per the "Reasoning effort: maximum" decision
  in the Confirmed user decisions section above):
  - `ask_gemini_api` — append `"thinkingConfig": {"includeThoughts": true,
    "thinkingBudget": <budget>}` to the `generationConfig` object in the
    POST body. Budget read from `config.gemini.thinking_budget` (default
    32768).
  - `ask_chatgpt` (API path) — for `gpt-5.2-pro` / `o3-pro` / `o3` /
    `gpt-5.2`, add top-level `"reasoning": {"effort":
    "<config.openai.reasoning_effort>"}` to the request body. Default
    `high`. For older models that don't accept the field, omit silently.
  - `ask_chatgpt_cli` — pass `--config
    model_reasoning_effort=<config.openai.cli_reasoning_effort>` (default
    `high`) to every `codex exec` invocation.
  - `ask_gemini_cli` — leave the call untouched for now; comment a TODO
    referencing this section so a future contributor can wire a flag when
    the Gemini CLI exposes one.
- `~/.claude/council/config.json` schema extension:

  ```json
  {
    "gemini": {
      "mode": "cli|api",
      "thinking_budget": 32768
    },
    "openai": {
      "mode": "cli|api",
      "reasoning_effort": "high",
      "cli_reasoning_effort": "high"
    },
    "fallback": {
      "openrouter": {
        "api_key": "",
        "models": [
          "tencent/hy3-preview:free",
          "nvidia/nemotron-3-super-120b-a12b:free",
          "inclusionai/ling-2.6-1t:free",
          "openrouter/free"
        ]
      }
    }
  }
  ```

- `manifest.json::sp_equivalent_note` companion — add `provider_chain_note`
  explaining the routing.

### Acceptance criteria

- Stub Codex CLI (`COUNCIL_STUB_CHATGPT=path/to/stub.sh` already supported)
  drives a successful Pragmatist call with `mode: "cli"`.
- Stub OpenAI failure → script falls through to OpenRouter stub → success
  → `fallback_used: true` in usage.jsonl.
- Inspecting the prompt sent to OpenAI API in `--dry-run` shows
  `"reasoning": {"effort": "high"}` in the request body.
- Inspecting the prompt sent to Gemini API in `--dry-run` shows
  `"thinkingConfig"` with `"thinkingBudget": 32768` in `generationConfig`.
- `codex exec` invocation in `--dry-run` includes `--config
  model_reasoning_effort=high`.
- Existing `test-council-audit-review.sh` still passes (uses stub envs).

### Commit plan

1. `feat(council): add Codex CLI provider for ChatGPT (mode: cli)`
2. `feat(council): pin reasoning effort to max for Skeptic + Pragmatist`
3. `feat(council): add OpenRouter free-model fallback chain`
4. `feat(council): orchestrate primary -> OpenRouter fallback on quota/error`
5. `feat(setup-council): wizard prompts for Codex CLI + OpenRouter`

---

## Sub-Phase 6 — Caching by content hash

**Goal:** Don't re-charge / re-spend tokens on identical Council requests.

### Files touched

- `scripts/council/brain.py`:
  - `cache_key(plan, file_contents, git_head)` — sha256 of concatenated input.
  - `cache_path(key)` — `~/.claude/council/cache/<key>.json`.
  - Pre-call lookup → if hit and within TTL → return cached, log
    `cache_hit: true`. Append `[cached <ts>]` marker to displayed output.
  - `--no-cache` CLI flag forces miss.
  - TTL configurable via `config.cache.ttl_days` (default 7).
- New: `commands/council-clear-cache.md` (global) — `/council clear-cache`
  → `rm -f ~/.claude/council/cache/*`.

### Acceptance criteria

- Two `/council "<same plan>"` calls within TTL → second is a cache hit, no
  API call, output identical.
- `--no-cache` forces real call even on identical input.
- `/council clear-cache` empties the dir.

### Commit plan

1. `feat(council): cache identical requests by content hash`
2. `feat(council): /council clear-cache + --no-cache flag`

---

## Sub-Phase 7 — GSD integration

**Goal:** Hook Council into the GSD workflow at natural decision points.

### Files touched

- `commands/gsd-plan-phase.md` — add `--council` flag. When set, after
  research-phase agent and before plan-checker agent, runs
  `/council "<phase goal>"`. SKIP/RETHINK verdict blocks transition to
  plan-checker, surfaces verdict to user, exits.
- `commands/gsd-execute-phase.md` — add `--council` flag for high-risk
  phases. Runs Council before invoking gsd-executor. Same SKIP/RETHINK
  block semantics.
- `commands/audit.md` — add `--council-review` flag. After audit report
  is produced, automatically invoke `/council audit-review --report
  <path>` (already supported by brain.py:run_audit_review).
- New: `templates/base/skills/council-integration/SKILL.md` — when to
  invoke, how to read verdicts, troubleshooting.
- `manifest.json` — register the new skill.

### Acceptance criteria

- `/gsd-plan-phase --council` integration tested with stub envs (no real
  API calls); verdict block correctly halts on injected SKIP.
- `/audit --council-review` produces a `council_pass: passed|failed|disputed`
  field in the audit report.

### Commit plan

1. `feat(gsd): add --council flag to gsd-plan-phase`
2. `feat(gsd): add --council flag to gsd-execute-phase`
3. `feat(audit): add --council-review flag to chain audit -> Council`
4. `feat(skills): council-integration skill with usage guidance`

---

## Sub-Phase 8 — Quality of life

**Goal:** Domain auto-detect, TL;DR summary, dry-run, JSON output, retro mode.

### Files touched

- `scripts/council/brain.py`:
  - `detect_domain(plan_text)` — regex on plan keywords:
    - `auth|password|crypto|JWT|token|session` → security
    - `perf|latency|cache|N\+1|slow|optimi[sz]e` → performance
    - `UI|UX|accessibility|a11y|WCAG|screen reader` → ux
    - `migration|backwards|deprecat` → migration
    - default → general
  - When domain detected, prepend
    `~/.claude/council/prompts/personas/<domain>-skeptic.md` (if exists) to
    the base Skeptic prompt. Same for Pragmatist.
  - `--dry-run` flag: build full prompt + context, print to stdout with
    estimated cost, do NOT call APIs.
  - `--format json` flag: emit structured JSON instead of markdown
    `{verdict, confidence, concerns: [...], cost_usd, fallback_used}`.
  - `tldr_summary(verdict, concerns)` — generate 3-bullet summary, prepend
    to written report file.
  - New mode: `brain --mode retro --commit <sha>` — read commit diff +
    Council report from before the commit, ask "did the implementation
    match what was approved?" Output: ALIGNED / DRIFT / UNCLEAR.
- New persona prompts: `templates/council-prompts/personas/security-skeptic.md`,
  `personas/security-pragmatist.md` (and same for performance/ux/migration).

### Acceptance criteria

- `brain --dry-run "fix auth bug"` shows constructed prompt + estimated
  cost, exits 0 without API calls.
- `brain --format json "..."` emits valid JSON parseable by `jq`.
- Plan with "auth" keyword triggers security persona prompts (verifiable in
  `--dry-run` output).

### Commit plan

1. `feat(council): auto-detect domain and load specialized persona prompts`
2. `feat(council): --dry-run flag for cost preview without API call`
3. `feat(council): --format json for tooling integration`
4. `feat(council): TL;DR auto-summary at the top of every report`
5. `feat(council): retrospective mode for post-implementation review`

---

## Sub-Phase 9 — Multilingual prompts (ru)

**Goal:** Russian Council prompts for users whose CLAUDE.md is in Russian.

### Files touched

- New: `templates/council-prompts/ru/skeptic-system.md` (Russian translation
  of the Sub-Phase 2 Skeptic prompt + FP-recheck block).
- New: `templates/council-prompts/ru/pragmatist-system.md`.
- New: `templates/council-prompts/ru/audit-review-skeptic.md`.
- New: `templates/council-prompts/ru/audit-review-pragmatist.md`.
- `scripts/council/brain.py`:
  - `--lang ru|en` flag (default: en).
  - Auto-detect: read `~/.claude/CLAUDE.md` first 500 chars; if Cyrillic
    char ratio > 0.2 → default to ru. Override with `--lang en`.
  - `load_prompt()` checks `~/.claude/council/prompts/<lang>/<name>.md`
    first, falls back to `~/.claude/council/prompts/<name>.md`.
- Localized verdict labels: `ПРОДОЛЖАТЬ / УПРОСТИТЬ / ПЕРЕДУМАТЬ / ПРОПУСТИТЬ`.

### Acceptance criteria

- `brain --lang ru "<plan>"` produces Russian Skeptic + Pragmatist output.
- Auto-detect triggers ru when global CLAUDE.md is Russian.
- English-only users unaffected (default lang stays en).

### Commit plan

1. `feat(council): translate system prompts to Russian (ru/)`
2. `feat(council): --lang flag with CLAUDE.md auto-detection`

---

## Sub-Phase 10 — Cleanup, docs, CHANGELOG

**Goal:** Documentation and final polish.

### Files touched

- `commands/council.md` — rewrite to cover all new flags
  (`--lang`, `--format`, `--dry-run`, `--no-cache`, `--mode retro`).
- New: `docs/COUNCIL.md` — deep documentation: architecture, provider
  selection, cost considerations, customization (prompt editing,
  redaction patterns, persona prompts), MCP integration.
- `README.md` — Council section overhaul.
- `CHANGELOG.md` — finalize v4.5.0 entry with all sub-phase summaries.
- `manifest.json::version` → `4.5.0`, `updated` → today's date.

### Commit plan

1. `docs(council): rewrite commands/council.md for v4.5 features`
2. `docs(council): add docs/COUNCIL.md deep reference`
3. `docs(readme): refresh Council section + Killer Features table`
4. `chore: bump manifest.json + CHANGELOG to v4.5.0`

---

## Sub-Phase 11 — MCP server for Claude Desktop

**Goal:** Expose Council as an MCP tool callable from Claude Desktop, not
just terminal.

### Files touched

- New: `scripts/council/mcp-server.py` — minimal MCP server (Python, single
  file, no pip deps if possible — use stdlib `socket` + JSON-RPC over stdio
  per MCP spec). Wraps `brain.py::_run_validate_plan` and
  `run_audit_review`. Tools exposed:
  - `council_validate(plan: str, files?: list[str], lang?: str)` → markdown
    verdict.
  - `council_audit_review(report_path: str)` → updated report path.
  - `council_stats(period: 'day'|'week'|'month'|'total')` → summary.
- `scripts/setup-council.sh` — append optional step "Configure Claude
  Desktop integration?". If yes, modify
  `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)
  or `%APPDATA%\Claude\claude_desktop_config.json` (Windows) to register:

  ```json
  "mcpServers": {
    "supreme-council": {
      "command": "python3",
      "args": ["~/.claude/council/mcp-server.py"]
    }
  }
  ```

  Atomic write via tempfile + os.replace (mirror lib/install.sh pattern).
  Backup existing config first.
- `commands/council.md` — note that the same Council also runs from Claude
  Desktop via the MCP server.

### Acceptance criteria

- `claude_desktop_config.json` after setup contains `supreme-council` server
  entry, foreign keys preserved.
- Server starts and exits cleanly under `python3 mcp-server.py < /dev/null`
  (basic stdio handshake test).
- Calling `council_validate` from a Claude Desktop conversation produces a
  verdict (manual smoke test by user).

### Commit plan

1. `feat(council): MCP server wrapping brain.py for Claude Desktop`
2. `feat(setup-council): register supreme-council MCP server in Claude Desktop config`

---

## Out-of-scope (NOT in this phase)

- Streaming Council output (cosmetic).
- Slack/Discord webhook integration.
- Adversarial Council mode (3+ models with disagreement requirement).
- Council leaderboard / metrics on which AI gives "better" advice.
- Plan format normalization (forced "Goal/Approach/Risks" template).
- Verdict-based CI exit codes (`brain --exit-code-on-verdict` flag).

These are noted for a potential v4.6+ follow-up.

---

## Acceptance gate for the whole phase (PR merge)

- All 11 sub-phases complete with their acceptance criteria green.
- `make check` and `make test` pass (zero FAIL markers).
- `shellcheck -S warning` clean on every modified `*.sh`.
- `python3 -m py_compile scripts/council/brain.py scripts/council/mcp-server.py` clean.
- Manual smoke (user, after PR ready):
  - Fresh `init-claude.sh` install in two projects, confirm `/council` works
    from both, no per-project `commands/council.md` files.
  - `brain "<simple plan>"` end-to-end with real APIs (or stubs).
  - `/council stats --total` displays usage from above runs.
  - `/council --dry-run "..."` produces preview without spending tokens.
  - Edit `~/.claude/council/prompts/skeptic-system.md`, re-run, observe
    instructions reflect the edit.
  - Set `OPENAI_API_KEY` empty + `codex` not in PATH → graceful error
    pointing to Plus subscription / OpenRouter setup.
  - Verify Council MCP tool is invokable from Claude Desktop.

---

## Open questions (resolve during execution)

1. **Codex CLI exact non-interactive flags.** The Codex CLI docs mention
   `codex exec` for scripting; verify with `codex --help` during Sub-Phase 5
   that we get plain stdout (no ANSI, no progress UI) with stdin prompt
   input. Fallback: use `--output-format=plain` / `--no-color` flags. If the
   CLI is interactive-only, fall back to API for ChatGPT.
2. **OpenRouter pricing for free models.** Free models genuinely have $0
   cost but may have rate limits / quality cliffs. Document the chain in
   docs/COUNCIL.md so users understand the trade-off.
3. **Russian auto-detect threshold.** 20% Cyrillic ratio is a guess; tune
   based on real `~/.claude/CLAUDE.md` samples.
4. **MCP server transport.** stdio is simplest but Claude Desktop also
   supports HTTP. Start with stdio; document HTTP as advanced option.

---

## Notes for the executing session

- Each sub-phase ends with a `make check && make test` verification before
  moving on.
- Use `git commit --no-verify=false` (default) — let pre-commit hooks
  catch markdown lint and shellcheck issues during commit. Fix and commit
  again rather than `--no-verify`.
- Stop and ask the user before:
  - Modifying anything in `~/.claude/` directly outside of the test sandbox
    paths (the implementation should write only via the upstream installer
    scripts, not from the test session itself).
  - Sending real API requests to Gemini / OpenAI / OpenRouter from the
    test session — use stubs.
  - Force-pushing the feature branch.
- Atomic commits per the commit plan; multi-file commits OK only when the
  files are mutually dependent (e.g. brain.py change + matching prompt file
  rename).
- After all 11 sub-phases ship, open the PR with `gh pr create --draft`
  initially so the user can read the full diff before promoting to ready.
