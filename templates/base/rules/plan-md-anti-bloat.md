---
description: PLAN.md right-sizing — length heuristic and "omit empty sections" discipline
globs:
  - "**/PLAN.md"
  - "**/.planning/**/*.md"
  - "**/specs/**/TECH.md"
---

# PLAN.md Anti-Bloat Rules

These rules apply when authoring or editing **planning documents** — `PLAN.md`,
files under `.planning/`, and `specs/<id>/TECH.md`. Goal: every section must
earn its place. Optional headings with no real content waste reviewer attention
and dilute the signal-to-noise of the doc.

## Length heuristic

Right-size the plan to the change it covers:

| Change shape | Target length |
| ------------ | ------------- |
| Single-file change with clear approach | Skip the plan, or keep it under **40 lines** |
| Multi-module change with some ambiguity | **80–150 lines** |
| Cross-cutting / architecturally novel change | Longer is fine — but every section must earn its place |

If `Context` and `Proposed changes` describe the same files and state from two
angles, **collapse them** into one grounded section.

## Omit empty sections

Optional sections (`Risks`, `Dependencies`, `Follow-ups`, `End-to-end flow`,
`Diagram`, `Parallelization`, `Testing notes`) are include-only-when-they-add-signal.

- **Omit the heading entirely if empty.**
- **Do not write `None`, `N/A`, `(no risks identified)`, or any placeholder
  prose under an empty heading.** Delete the heading.
- A heading with one bullet that says "nothing to add here" is worse than no
  heading. Delete it.

## Ground the plan in real code

- Reference actual files with line numbers: `app/foo.rs:42`, `lib/bar.ts (120-220)`.
- Do not guess about current architecture when the code can be inspected directly.
- Prefer concrete implementation guidance over generic architecture language.
- Explain why the proposed design fits **this** repo, not why it would fit any repo.

## Reference, do not restate

- If `PRODUCT.md` or a parent design doc already describes user-visible
  behavior, link to it. Do not paraphrase it.
- Each behavior invariant from upstream docs should map to a concrete test or
  verification step in this plan — but the invariant itself stays in the
  upstream doc.

## Diagrams

Include a Mermaid diagram **only** when a visual will explain the design faster
than prose (data flow, state transitions, sequence across layers). Prefer one
or two focused diagrams over decorative ones.

## Self-check before saving

Before writing the file:

- [ ] Did I reference real files with line numbers, or am I guessing?
- [ ] Are all my optional sections carrying real content, or did I leave a
      placeholder I should delete?
- [ ] Did I collapse `Context` + `Proposed changes` if they describe the same
      thing twice?
- [ ] If I added a section that is hard to defend, did I delete it?

If any answer is "no" or "didn't check," fix before committing.
