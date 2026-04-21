# Plan 02-02 Checkpoint: MANIFEST-03 Count Discrepancy

**Status:** BLOCKING — awaiting user decision before manifest.json can be written
**Created:** 2026-04-17
**Plan:** 02-02 (manifest v2 schema + conflicts_with annotations)

---

## Context

Task 1 of Plan 02-02 is a `checkpoint:decision` gate that blocks manifest.json from being written
until the user resolves two coupled decisions:

**(A)** `templates/base/skills/debugging/SKILL.md` is currently **UNTRACKED** in git.
What is its fate — commit it, or exclude it?

**(B)** MANIFEST-03 requirement text says "≥10 entries" but the live scan produced only
7 confirmed SP conflicts (6 if debugging/SKILL.md is excluded). How should this be reconciled?

---

## 7 Confirmed SP Conflicts (Live Scan — SP 5.0.7)

| # | TK File (repo-relative) | SP Equivalent | Conflict Type |
|---|------------------------|---------------|---------------|
| 1 | `templates/base/agents/code-reviewer.md` | `agents/code-reviewer.md` | HARD — identical agent name collision |
| 2 | `commands/debug.md` | skill `systematic-debugging/SKILL.md` | FUNCTIONAL — both provide systematic debugging |
| 3 | `commands/tdd.md` | skill `test-driven-development/SKILL.md` | FUNCTIONAL — both provide TDD workflow |
| 4 | `commands/worktree.md` | skill `using-git-worktrees/SKILL.md` | FUNCTIONAL — both provide worktree management |
| 5 | `commands/verify.md` | skill `verification-before-completion/SKILL.md` | FUNCTIONAL — both provide pre-commit verification |
| 6 | `commands/plan.md` | skill `writing-plans/SKILL.md` | FUNCTIONAL — both provide planning methodology |
| 7 | `templates/base/skills/debugging/SKILL.md` | skill `systematic-debugging/SKILL.md` | FUNCTIONAL — content nearly identical (Iron Law); **UNTRACKED** |

**GSD conflicts: 0** — GSD uses `gsd-` prefix on all commands/agents, no name collisions.

**6 confirmed TK-unique entries:** `commands/checkpoint.md`, `commands/handoff.md`,
`commands/learn.md`, `commands/audit.md`, `commands/context-prime.md`, `templates/base/agents/planner.md`

---

## MANIFEST-03 Requirement Text (current)

```text
MANIFEST-03: Each of the 7 confirmed hard duplicates is annotated with conflicts_with
(debug, tdd, worktree, verify, checkpoint, handoff, learn, audit, context-prime, plan,
debugging skill, code-reviewer agent, planner agent — total ≥10 entries)
```

The parenthetical list in MANIFEST-03 mixes confirmed conflicts with TK-unique entries.
The live scan confirms only 7 (or 6 without debugging/SKILL.md) have real SP equivalents.

---

## The Three Options

### option-a — Recommended by Research

**Commit debugging/SKILL.md + amend REQUIREMENTS.md MANIFEST-03 text**

- Final conflict count: **7** (matches live scan exactly)
- Clears existing tech debt (untracked file gets committed)
- REQUIREMENTS.md amendment: `Each of the 7 confirmed hard duplicates (live scan against SP 5.0.7)
  is annotated with conflicts_with. The 13-entry seed list (D-16) was fully evaluated;
  7 confirmed, 6 TK-unique.`
- Adds debugging/SKILL.md to git before Phase 3 removes it under complement-sp mode

**Pros:** Accurate, clears debt, matches research recommendation (RESEARCH.md Open Questions #2+#3)
**Cons:** File enters git history then exits at Phase 3

---

### option-b

**Exclude debugging/SKILL.md + amend REQUIREMENTS.md to reflect 6 conflicts**

- Final conflict count: **6**
- Keeps untracked file out of git (must delete or .gitignore it)
- REQUIREMENTS.md amendment: `Each of the 6 confirmed hard duplicates (live scan against SP 5.0.7)
  in TK commands + agents is annotated with conflicts_with.`
- Loses skills/* bucket coverage in conflict set

**Pros:** No churn, simpler amendment
**Cons:** Leaves tech debt, loses SKILL.md coverage

---

### option-c — NOT Recommended

**Commit debugging/SKILL.md + keep REQUIREMENTS.md at ≥10 by broadening conflict definition**

- Final conflict count: **≥10** (forces promotion of TK-unique files to conflicts_with)
- No REQUIREMENTS.md amendment needed
- Requires marking entries like `commands/checkpoint.md` as `conflicts_with: ["superpowers"]`
  despite no confirmed SP equivalent — would create false positives at install time

**Pros:** No REQUIREMENTS.md change needed
**Cons:** Violates live-scan authority (D-15/D-16), creates install false positives,
goes against RESEARCH.md guidance

---

## Decision Required

**Select one:** `option-a`, `option-b`, or `option-c`

The orchestrator will dispatch a continuation agent with your selection.
The continuation agent will execute Task 2 (manifest v2 rewrite) and Task 3 (validate-manifest.py)
based on your choice.
