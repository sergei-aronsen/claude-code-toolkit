# Surgical Changes

Touch only what you must. Clean up only your own mess.

Adapted from [Andrej Karpathy's observations on LLM coding pitfalls](https://x.com/karpathy/status/2015883857489522876) via [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills).

---

## The Rule

Every changed line should trace directly to the user's request. If it doesn't, it shouldn't be in the diff.

---

## When Editing Existing Code

- **Don't "improve" adjacent code, comments, or formatting.** Scope creep inflates diffs and hides real changes behind cosmetic noise.
- **Don't refactor things that aren't broken.** A working function in a style you dislike is still a working function.
- **Match existing style, even if you'd do it differently.** Consistency across a file beats local optimum.
- **If you notice unrelated dead code, mention it — don't delete it.** The user may have a reason. Flag it for them to decide.

## When Your Changes Create Orphans

- **Remove imports/variables/functions that YOUR changes made unused.** These are your mess — clean them.
- **Don't remove pre-existing dead code unless asked.** Pre-existing orphans are someone else's scope.

---

## The Test

Before finalizing a diff, scan each changed line and ask:

> Does this line trace directly to the user's request?

If no → revert that line. If yes → keep it.

A focused 30-line diff beats a sprawling 200-line diff with "while I was there" cleanups. The user can read the first; the second hides the real change.

---

## Relationship to Other Rules

- **KISS / YAGNI** (`~/.claude/CLAUDE.md`) — governs *what* you build. Surgical Changes governs *how much you touch* when you build it.
- **3-Fix Rule** — if a targeted fix fails 3 times, the architecture is wrong. At that point, stop surgical edits and propose a refactor.
- **Plan Mode** — for non-trivial surgery, plan the minimum set of touched files first.

---

## Anti-Patterns

| Symptom | What it usually is |
|---------|-------------------|
| Diff shows 40 reformatting lines + 3 logic lines | Hidden scope creep |
| "Also cleaned up X while I was there" | Unasked refactor — revert or split to separate commit |
| Renamed variables in files you didn't need to edit | Style imposition — revert |
| Deleted old comments, TODOs, or commented-out code | Not your scope — flag, don't delete |
| Touched imports in 8 files for a 1-function change | Unnecessary blast radius |

---

## When Scope Creep Is Justified

Legitimate cross-file edits when:

- A function rename *requires* updating callers (mechanical, not stylistic).
- A type change *requires* updating consumers (correctness, not taste).
- Security fix (user explicitly asked for hardening pass).
- User explicitly requested cleanup ("also clean up X while you're at it").

If in doubt → ask before expanding scope.
