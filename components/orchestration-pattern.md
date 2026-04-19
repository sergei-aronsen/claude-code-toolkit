# Orchestration Pattern — Lean Orchestrator + Fat Subagents

How to build multi-step Claude Code workflows that scale beyond what a single agent's context window can hold. Pattern distilled from `get-shit-done` (`~/.claude/get-shit-done/`) and applicable to any custom slash command or skill.

**Source:** vault notes captured 2026-04-14 to 2026-04-16, sessions on `get-shit-done` and `gsd-map-codebase` projects.

---

## Why this pattern exists

A single Claude agent has a fixed context window. Long workflows (multi-phase planning, full-codebase analysis, multi-AI debate) blow it out fast — every file read, every prior tool call, every prior response stays in context until compaction kicks in and starts dropping detail.

The fix is **delegation, not compression**. The orchestrator stays small and only knows the high-level plan. Each delegated subagent gets a fresh 100% context, does one bounded job, and returns a tiny confirmation string. The orchestrator never sees the subagent's working memory.

Token-budget rule of thumb: orchestrator ≤ 15% of total budget; subagents own the remaining 85%, distributed across waves.

---

## The 5-step pattern

```text
[orchestrator (lean — ~15% context)]
   ↓
   1. init <workflow>          → JSON config (models, paths, flags)
   ↓
   2. agent-skills <agent>     → skills inventory injected into subagent prompt
   ↓
   3. spawn subagents in waves (parallel where possible, isolated each)
        ↓ each subagent: fresh 100% context
        ↓ uses model from step 1 config (sonnet vs opus stratified)
        ↓ writes artifacts directly to .planning/ or similar
        ↓ returns confirmation only (file paths + line counts, NOT contents)
   ↓
   4. collect confirmations (orchestrator reads tiny strings, never full output)
   ↓
   5. atomic commit per artifact group
```

---

## Step 1 — `init <workflow>` returns declarative config

A small CLI script reads the workflow's config file and returns a JSON blob:

```bash
INIT=$(node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" init plan-phase)
# Returns:
# {
#   "researcher_model": "sonnet",
#   "planner_model": "opus",
#   "checker_model": "sonnet",
#   "commit_docs": true,
#   "parallelization": true,
#   "subagent_timeout": 300000,
#   "phase_dir": ".planning/phases/03-feature/",
#   "agents_installed": true
# }
```

**Why JSON:** the orchestrator parses fields and uses them to parameterize the subagent spawn calls. No hardcoded model names. No hardcoded paths. Config lives in one place (`.planning/config.json` or equivalent) and every workflow reads it through `init`.

**Side benefit:** the same `init` call validates that prerequisites are present — required agents installed, required directories created. If something is missing, the orchestrator errors out before spawning a single subagent.

---

## Step 2 — `agent-skills <agent>` injects the agent's contract

```bash
AGENT_SKILLS_RESEARCHER=$(node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" agent-skills gsd-project-researcher)
```

Returns the markdown that defines what the agent is allowed to do, what tools it has, what its quality gates are. The orchestrator pastes this into every subagent prompt as `${AGENT_SKILLS_RESEARCHER}`.

**Why this matters:** it keeps the agent's contract in one canonical place (the agent definition file) and removes the need to duplicate it in every workflow that spawns the agent.

---

## Step 3 — spawn subagents in waves

A wave is a group of subagents that have no dependencies on each other and can run in parallel. The orchestrator:

1. **Discovers** the work units (plans, research dimensions, file groups).
2. **Analyzes dependencies** — which work unit blocks which.
3. **Groups into waves** — independent units in the same wave; dependent ones in subsequent waves.
4. **Spawns the wave** — one `Task` tool call per subagent, all in a single message so the runtime parallelizes them.

Each subagent gets:

- **Fresh context** (100% of its own budget — knows nothing about other subagents)
- **Explicit `<files_to_read>` block** with file paths (no inline content dump — saves tokens)
- **Model from Step 1 config** (sonnet for cheap analysis, opus for hard reasoning)
- **Quality gates** (checklist of "must be true" before returning)
- **Strict output instruction** — write the artifact, return short confirmation

Optional flags the orchestrator may pass:

- `--wave N` for token quota pacing across waves
- `--gaps-only` for re-running only failed/missing units
- `--interactive` for sequential inline execution with checkpoints (rare, mostly for debugging)

---

## Step 4 — collect confirmations only

Subagents write their artifacts directly to disk. They return a tiny string:

```text
## Mapping Complete

**Focus:** tech
**Documents written:**
- `.planning/codebase/STACK.md` (108 lines)
- `.planning/codebase/INTEGRATIONS.md` (130 lines)
```

The orchestrator's context grows by ~20 lines per subagent, regardless of how much work the subagent did. **The orchestrator never reads the subagent's full output.** When it needs to know what's in `STACK.md`, it reads `STACK.md` directly when the time comes — not in the subagent transcript.

This is the #1 trick for keeping the orchestrator lean. Naive implementations dump subagent outputs back into the orchestrator and run out of context by wave 3.

---

## Step 5 — atomic commit per artifact group

After each wave or each phase, commit the produced artifacts in a single git commit:

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" commit "docs: map existing codebase" --files .planning/codebase/*.md
```

**Why atomic:** if context is lost mid-workflow (compaction, crash, manual `/clear`), every committed wave is a stable resume point. The next session can read the committed artifacts and pick up from the next wave without re-running anything.

---

## Model stratification

A subtle but high-leverage choice: not every subagent needs the same model.

| Subagent role | Recommended model | Why |
|---------------|-------------------|-----|
| Researcher | sonnet | Fast, lower cost, good enough for domain analysis |
| Planner / Roadmapper | opus | Highest reasoning + largest context for complex synthesis |
| Checker / Verifier | sonnet | Fast feedback loop on plan quality |
| Mapper / Inspector | haiku or sonnet | Pure pattern-matching, cheap end of the spectrum |

Cost goes down without quality loss because **opus is reserved for the work that actually needs it**.

---

## Worktree isolation (optional, for stateful workflows)

If subagents may modify shared files (code, config, planning docs), spawn each in its own git worktree so they cannot stomp on each other:

```text
1. Create worktree at agent spawn time
2. Agent executes its plan in isolation (own git state)
3. Orchestrator snapshots tracking files (ROADMAP.md, STATE.md) before merge
4. Merge worktree branch → main via git merge
5. Restore orchestrator tracking files post-merge
6. Cleanup worktree
```

Adds git overhead but eliminates race conditions and branch conflicts when running many agents in parallel.

---

## File-reference convention (`@-notation`)

Pass context to subagents by file reference, not inline content:

```text
<files_to_read>
- .planning/PROJECT.md (Project context and goals)
- .planning/codebase/STACK.md (Existing tech stack — do not re-research)
- .planning/research/SUMMARY.md (Synthesized research findings, if exists)
</files_to_read>
```

The subagent reads only what it needs, and the orchestrator's prompt stays tiny. Compare this to dumping all three files inline — the orchestrator now carries every byte forever.

---

## When to use this pattern

**Use it for:**

- Multi-phase planning workflows (project init, milestone, phase planning)
- Full-codebase analysis (codebase mapping, audits, security reviews)
- Multi-AI debate (your Council pattern qualifies — Gemini + ChatGPT spawned as subagents)
- Any workflow where the total work blows past 1 context window

**Skip it for:**

- One-shot single-tool-call work (just answer inline)
- Tasks where the orchestrator needs the subagent's full output to make the next decision (defeats the purpose)
- Trivial 2-step workflows — overhead costs more than it saves

---

## Wiring it into your own slash command

Minimum viable adaptation in a custom command at `commands/your-command.md`:

### 1. Load context

Call your toolkit's `init` helper at the start of the command. It returns a JSON blob with model
names, paths, and flags — no hardcoded values in the command itself.

```bash
INIT=$(node "$HOME/.claude/your-toolkit/bin/your-tools.cjs" init your-workflow)
```

Parse the JSON for `researcher_model`, `planner_model`, `phase_dir`, and any other fields your
workflow needs.

### 2. Spawn subagents in parallel

For each independent work unit, spawn a subagent using the Agent tool. Pass these fields:

- `subagent_type` — agent name defined in `~/.claude/agents/`
- `model` — value from the INIT blob (sonnet for cheap analysis, opus for hard reasoning)
- `prompt` — includes a `<files_to_read>` block, the work unit description, and a quality-gate
  checklist of "must be true before returning"
- `run_in_background: true` — lets the runtime parallelize all spawns in the same message

Group work units into waves: independent units in the same wave; dependent units in subsequent
waves.

### 3. Collect confirmations

Wait for each subagent. Read the confirmation string only — never the full subagent transcript.
The orchestrator's context grows by ~20 lines per subagent regardless of how much work was done.

### 4. Commit atomically

After each wave completes, commit the produced artifacts in a single commit so every wave is a
stable resume point.

```bash
node "$HOME/.claude/your-toolkit/bin/your-tools.cjs" commit "your: short message" \
    --files .planning/output/*.md
```

### 5. Present next-up

Tell the user what command to run next. Keep the orchestrator's final message short — it has
already delegated the heavy work.

The pattern is portable — `gsd-tools.cjs` is the GSD-specific implementation, but a
`tk-tools.sh` or any other init helper following the same JSON contract works identically.

---

## See Also

- `components/supreme-council.md` — TK's existing multi-AI orchestration via `brain.py`. Refactoring it to use this init-JSON pattern is on the v4.1 roadmap (`ORCH-FUT-02`, `ORCH-FUT-03`).
- `components/structured-workflow.md` — single-agent 3-phase discipline (RIPER-5). Complements this pattern: structured-workflow disciplines a single context, orchestration-pattern scales beyond one context.
- `commands/council.md` — the closest existing TK command to this pattern.

---

## Status

Drafted from vault notes (2026-04-14 to 2026-04-16). Will be formalized and integrated into `manifest.json` during Phase 6 of the v4.0 milestone (see REQUIREMENTS DOCS-08). Implementation requirements (TK-native init helper, Council refactor) are tracked as `ORCH-FUT-01..04` in the v2 backlog.
