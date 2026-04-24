### GSD Version

1.36.0

### Runtime

Claude Code

### Operating System

macOS

### Node.js Version

v25.9.0

### Shell

/bin/zsh

### Installation Method

Manual install via `/Users/REDACTED/.claude/get-shit-done/` (plugin directory, not npm).

### What happened?

After running `/gsd-execute-phase N --auto` on a project configured with
`parallelization: true, use_worktrees: false` (the recommended default for single-repo
solo-dev workflows), per-plan `- [ ]` checkboxes inside ROADMAP.md stay unchecked even after
all plans in the phase complete successfully and their SUMMARY.md files land on disk.

The only way to sync the checkboxes is a manual call:

```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs roadmap update-plan-progress <N>
```

During v4.0 execution, this manual call was needed after phases 2, 3, 4, 5, and 6.1
(5 invocations recorded in the v4.0 retrospective).

### What did you expect?

`update-plan-progress` should fire automatically from within `execute-plan.md` (per plan) OR
from the orchestrator's wave-complete handler (per wave), so that by the time
`phase complete` runs, ROADMAP checkboxes match the actual SUMMARY files on disk.

### Steps to reproduce

1. Project config (`.planning/config.json`):

   ```json
   {
     "parallelization": true,
     "use_worktrees": false
   }
   ```

2. ROADMAP.md contains a phase with 3 planned items:

   ```markdown
   Plans:
   - [ ] 09-01-PLAN.md — ...
   - [ ] 09-02-PLAN.md — ...
   - [ ] 09-03-PLAN.md — ...
   ```

3. Run `/gsd-execute-phase 9 --auto` in Claude Code.
4. Wait for all 3 plans to complete (`09-01-SUMMARY.md`, `09-02-SUMMARY.md`,
   `09-03-SUMMARY.md` land on disk).
5. Inspect ROADMAP.md — the `- [ ]` markers remain unchanged.
6. Manually run `node ~/.claude/get-shit-done/bin/gsd-tools.cjs roadmap update-plan-progress 9`
   — checkboxes now become `- [x]`.

### Error output / logs

No error — silent failure to sync.

### Root cause analysis

The `execute-phase.md` + `execute-plan.md` workflows have THREE checkpoints where plan
checkboxes SHOULD be updated:

- **Checkpoint A (per-plan, in `execute-plan.md` ~line 418):**

  ```bash
  node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress "${PHASE}"
  ```

  Guarded with `# Skip in parallel mode — orchestrator handles ROADMAP.md centrally`. With
  `parallelization: true, use_worktrees: false`, the agent is in "parallel scheduling" but
  NOT worktree-isolated. The guard is ambiguous — in practice the agent interprets "parallel
  mode" as active and skips the call.

- **Checkpoint B (post-wave orchestrator, `execute-phase.md` ~line 738):**

  ```bash
  node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress "${PHASE_NUMBER}" "${plan_id}" "complete"
  ```

  Runs only in the worktree merge post-step. Explicitly skipped when `use_worktrees: false`.

- **Checkpoint C (phase complete, `execute-phase.md` ~line 1353):**

  `phase complete` in `phase.cjs:843-854` includes a safety-net checkbox loop. Works only if
  `phase complete` is actually reached.

With `parallelization: true, use_worktrees: false`:

- Checkpoint A skipped (guard interpretation).
- Checkpoint B skipped (`use_worktrees: false`).
- Only Checkpoint C fires, at phase end.

This means per-plan ROADMAP sync depends entirely on reaching `phase complete`. If anything
interrupts the phase between last-plan-done and `phase complete` (agent stop, context limit,
error), no checkboxes are ever updated.

### Prior art (related but distinct)

- **#536** (closed 2026-02-15) — `execute-phase never calls phase complete`. Different root
  cause: older workflow had no `phase complete` call at all. Fixed by adding the call.
- **#1572** (closed 2026-04-03) — `phase complete does not update plan checkboxes in
  ROADMAP.md`. Fixed by adding the safety-net loop in `phase.cjs:843`. Does not address the
  Checkpoint A ambiguity.
- **#2005** (closed 2026-04-22) — `phase complete silently skips roadmap updates... when
  wrapped in <details>`. Different root cause: `<details>` layout parsing.

None of the closed issues address the Checkpoint A guard-interpretation gap when
`parallelization: true, use_worktrees: false`.

### Suggested fix

The `parallelization: true` and `use_worktrees: true` flags are orthogonal. The ROADMAP
update should skip ONLY in worktree-isolation mode (where the orchestrator merges per-plan
results centrally). In non-worktree parallel mode, each plan agent shares the same repo and
should call `update-plan-progress` directly.

In `execute-plan.md`, replace the current guard with an explicit worktree-mode check:

```markdown
# Skip only in worktree isolation mode — orchestrator handles ROADMAP.md centrally
if [ "${GSD_WORKTREE_MODE:-false}" != "true" ]; then
  node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress "${PHASE}"
fi
```

This makes Checkpoint A fire in `parallelization: true, use_worktrees: false` mode while
remaining skipped in `use_worktrees: true` mode.

Alternative: keep Checkpoint A as-is but add a new Checkpoint D in the orchestrator that runs
`update-plan-progress` after EACH plan completes (not just after each wave), regardless of
worktree mode. This centralizes the responsibility in the orchestrator.
