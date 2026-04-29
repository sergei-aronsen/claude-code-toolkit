# Council Integration Skill

> Load this skill whenever the user invokes a GSD workflow command with
> `--council`, when running an audit that needs Council confirmation, or
> when SKIP/RETHINK verdict handling is required.

---

## Rule

**Council is a hard gate, not a suggestion.**

When `/council` returns SKIP or RETHINK on a plan, halt the workflow and
surface the verdict to the user. Do NOT proceed to plan-checker, executor,
or merge step until the user either revises the plan or explicitly
overrides the verdict.

---

## When This Skill Activates

| Trigger | What it means |
|---------|---------------|
| `/gsd-plan-phase --council <N>` | Run Council between research and plan-checker |
| `/gsd-execute-phase --council <N>` | Run Council before invoking gsd-executor |
| `/audit ... --council-review` | Audit's Phase 5 Council pass (already mandatory in v4.2+) |
| User asks "should I run Council on this plan?" | Yes — Council is cheap with caching |

---

## Integration Pattern: gsd-plan-phase

When the user types `/gsd-plan-phase <N> --council` (or attaches `--council`
to any GSD plan invocation), inject a Council review between research and
plan-checker. Read the phase goal from `.planning/phases/<N>-*/goal.md`
or `.planning/phases/<N>-*/PLAN.md` frontmatter, then:

```bash
brain "<phase goal text + key constraints from RESEARCH.md>"
```

Read the verdict from the Council report at
`.claude/scratchpad/council-report.md`:

| Verdict | Action |
|---------|--------|
| `PROCEED` | Continue to plan-checker as normal |
| `SIMPLIFY` | Surface concerns to user, ask whether to (a) replan with reduced scope, (b) proceed with the existing plan, (c) abort |
| `RETHINK` | **Halt.** Print the Skeptic + Pragmatist verdicts. Ask the user to revise the plan. Do not invoke plan-checker. |
| `SKIP` | **Halt.** Print verdicts and ask whether the phase should be cancelled or rescoped. |

If the user revises the plan, re-run `brain` (the cache will hit on
identical text — re-prompt the user to bypass with `--no-cache` if the
revisions are subtle).

---

## Integration Pattern: gsd-execute-phase

For high-risk phases (security work, schema migrations, irreversible
changes), the user attaches `--council` to invocation. Run Council on
the *plan content* before spawning the executor:

```bash
PHASE_DIR=$(ls -d .planning/phases/<N>-*/ | head -1)
brain "$(cat "$PHASE_DIR/PLAN.md")"
```

Verdict semantics are the same as plan-phase. RETHINK/SKIP halts execute
before any code changes happen.

---

## Integration Pattern: audit

`/audit` runs Council mandatorily in Phase 5 (since v4.2). The
`--council-review` flag noted in older PLAN documents is now the default.
The audit report lands at `.claude/audits/<type>-<TIMESTAMP>.md` with a
placeholder Council slot:

```text
_pending — run /council audit-review_
```

Replace it by running:

```bash
brain --mode audit-review --report .claude/audits/<type>-<timestamp>.md
```

`run_audit_review()` rewrites the slot in place with the verdict table
(REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT / disputed). Do NOT manually
edit the slot — the rewrite is atomic and signed.

---

## Reading Verdicts

The display block printed by `brain` follows this shape:

```text
============================================================
📋 SUPREME COUNCIL REPORT
============================================================

🧐 THE SKEPTIC (Gemini ...):
<full Skeptic prose>
VERDICT: PROCEED|SIMPLIFY|RETHINK|SKIP

🔨 THE PRAGMATIST (ChatGPT ...):
<full Pragmatist prose>
VERDICT: PROCEED|SIMPLIFY|RETHINK|SKIP

------------------------------------------------------------
  Skeptic:    <verdict>
  Pragmatist: <verdict>
  Final:      <verdict> — <one-line reason>
------------------------------------------------------------

✅|💡|🔄|⛔ VERDICT: <final>
============================================================
```

**Final verdict** is the more conservative of the two. Always read
the `Final:` row, not the individual reviewer rows, when deciding to
halt or proceed.

---

## Cache Behavior

Identical plan text within TTL (default 7 days) replays the cached
report. The display starts with:

```text
♻️  [cached <ts>] Returning previous Council report — no API calls.
   (use --no-cache to force a fresh run)
```

When the user says "the verdict is stale" or "I tweaked the plan",
either:

- Suggest `brain --no-cache "<plan>"` for a one-off bypass.
- Or run `brain clear-cache` (via `/council clear-cache`) to wipe the
  whole cache directory.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Config not found: ~/.claude/council/config.json` | Council not installed | Run `bash <(curl -sSL .../setup-council.sh)` |
| `Gemini CLI mode selected but 'gemini' is not in PATH` | Gemini CLI missing | `npm install -g @google/gemini-cli` or switch to API mode in config |
| `OpenAI CLI mode selected but 'codex' is not in PATH` | Codex CLI missing | `npm install -g @openai/codex` or switch to API mode |
| `No reviewers available — aborting` | Both providers unavailable | Configure at least one of Gemini or OpenAI |
| Verdict feels "off" / outdated | Cache hit on stale plan | `brain --no-cache "<plan>"` or `brain clear-cache` |
| `record_usage` not logging | `COUNCIL_NO_USAGE_LOG=1` set | Unset the env var |
| Cost gate blocks the call | `COUNCIL_COST_CONFIRM_THRESHOLD` exceeded | Confirm at the prompt or raise the threshold |

---

## When NOT to Use Council

- Single-file bug fixes or typo corrections.
- Routine refactors with no architectural impact.
- Doc-only PRs.
- When the user has already approved a plan via a different review process.

Council is best for **plan justification and approach validation**, not
line-level code review. Use `/audit` for code review and `/council
audit-review` for confirming audit findings.

---

## Checklist Before Halting on RETHINK/SKIP

- [ ] Council report saved at `.claude/scratchpad/council-report.md`
- [ ] Both Skeptic and Pragmatist verdicts printed to user
- [ ] `Final:` row shown explicitly, not just individual rows
- [ ] User asked: revise plan, override verdict, or abort phase
- [ ] No downstream tools (plan-checker, executor) invoked
