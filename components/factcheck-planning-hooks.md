# Fact-check Planning Hooks

Solo-developer integration: surface `/factcheck` and `/research` reminders
during GSD planning so plans don't lock with stale, hallucinated, or
deprecated external claims.

## What ships

`templates/global/hooks/tk-pre-gsd-plan-factcheck.sh` — `UserPromptSubmit`
advisory hook installed by `scripts/install-hooks.sh`.

It fires on prompts that match BOTH:

1. A GSD planning entry point: `/gsd-discuss-phase`, `/gsd-plan-phase`,
   `/gsd-plan-review-convergence`.
2. An external-dependency signal — keyword from the trigger set OR a
   semver-ish pattern (`v1.2`, `3.x`, `2.10.1`).

When both fire, the hook prints a stdout reminder pointing the user at
`/factcheck`, `/research`, and `/lookup`. Claude Code injects the text as
additional context. Never blocks.

## Trigger keyword set

| Bucket | Examples |
|---|---|
| Verbs | `upgrade to`, `migrate to`, `switch to`, `move to` |
| Lifecycle | `latest version`, `deprecated`, `removed in`, `breaking change`, `no longer supported` |
| SDK / library nouns | `stripe sdk`, `openai sdk`, `next.js`, `nuxt`, `remix`, `astro`, `react`, `vue`, `svelte`, `angular`, `django`, `rails`, `laravel`, `spring boot`, `fastapi`, `node.js`, `deno`, `bun` |
| Russian | `обнови до`, `перейти на`, `новая версия`, `устарел`, `больше не поддерж` |
| Regex fallback | `v?\d+\.\d+(\.\d+)?` and `v?\d+\.x` |

The list is intentionally generous. False positives cost a one-line
reminder; false negatives cost a stale plan.

## Why these triggers

External claims are the single largest source of plan rot in solo-dev
work. SDK majors ship every few months; deprecations land between
sessions; "the latest version" today differs from yesterday. Council
review (PR-2) only catches drift if the plan already carries
`[VERIFIED]` / `[DISPUTED]` / `[UNVERIFIABLE]` markers. This hook nudges
those markers into existence at the right moment — *before*
`/gsd-plan-phase` locks them in.

## Workflow

```text
/gsd-discuss-phase  ──►  hook fires ──►  user runs /factcheck on each external claim
                                          │
                                          ▼
                                   plan gets [VERIFIED] / [DISPUTED] markers
                                          │
                                          ▼
                            /council picks up markers, grounds review
                                          │
                                          ▼
                                  /gsd-execute-phase
```

## Opt-outs

| Knob | Effect |
|---|---|
| Append `(no-factcheck-gate)` to the prompt | Silences this hook for that one invocation |
| `export TK_FACTCHECK_GATE=0` | Disables this hook only |
| `export TK_HOOKS_DISABLE=1` | Disables all TK advisory hooks |

## Install

```bash
bash scripts/install-hooks.sh
```

Re-running is idempotent. The hook is registered with `_tk_owned: true`
and `_tk_hook_id: tk-pre-gsd-plan-factcheck.sh`, so foreign and TK-owned
entries with different ids are preserved verbatim.

## Tests

- `scripts/tests/test-install-hooks.sh` — verifies the hook is among the 5
  TK hooks installed in `~/.claude/settings.json`.
- `scripts/tests/test-hook-replay.sh` — fixture-based stdin replay covering
  positive trigger, semver regex fallback, negative cases, per-prompt
  opt-out, and per-hook env opt-out.

## Related

- `commands/factcheck.md` — the slash command this hook nudges users
  toward.
- `commands/research.md`, `commands/lookup.md` — sibling research entry
  points.
- `components/comet-research.md` — threat model for the underlying
  Perplexity Pro bridge.
- `commands/council.md` — Council picks up `[VERIFIED]` / `[DISPUTED]` /
  `[UNVERIFIABLE]` markers automatically (PR-2).
