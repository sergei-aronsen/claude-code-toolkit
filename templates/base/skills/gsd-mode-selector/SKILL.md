---
name: gsd-mode-selector
description: Use when user requests work via natural language ("fix this", "add feature X") — selects appropriate GSD command (gsd-fast / gsd-quick / gsd-plan-phase) based on risk and scope, prevents using heavyweight pipeline for trivial work
---

# GSD Mode Selector

## Why this skill exists

GSD has three modes with 100× cost difference. Wrong mode for task type = wasted money or insufficient quality. This skill picks the right one based on what user actually wants.

## When this skill activates

- User says: "fix", "add", "change", "implement", "do", "make"
- User describes work without specifying GSD command
- Before any `/gsd-*` invocation when scope unclear

## Decision tree

```text
                User describes task
                        │
                        ▼
              Is it trivial single-fix?
                  (typo, 1 line, comment)
                  /  \
                YES   NO
                 │    │
                 ▼    ▼
           /gsd-fast   Is scope < 100 LOC?
                       AND single-concern?
                       AND no security implication?
                       AND no breaking change?
                          /  \
                       YES   NO
                        │    │
                        ▼    ▼
                  /gsd-quick   Is scope architectural?
                               OR multi-file?
                               OR security-relevant?
                               OR breaking change?
                                  /  \
                               YES   NO
                                │    │
                                ▼    ▼
                       /gsd-plan-phase   /gsd-quick
                       + /council if
                       auth/payments
```

## Concrete examples

| User says | Mode | Why |
|---|---|---|
| "поправь опечатку" | `/gsd-fast` | Trivial, single fix |
| "добавь тест для функции X" | `/gsd-quick` | Small, single concern |
| "обнови README" | `/gsd-fast` | Doc update |
| "поправь баг в auth.js" | `/gsd-quick` (small bug) or `/gsd-plan-phase` (security) | Depends |
| "добавь endpoint для users" | `/gsd-quick` | Single concern, <100 LOC |
| "реализуй OAuth" | `/gsd-plan-phase` + `/council` | Security + multi-file |
| "добавь Stripe billing" | `/gsd-plan-phase` + `/council` | Payments + breaking |
| "переделай схему БД" | `/gsd-plan-phase` + `/council` | Migration + breaking |
| "рефакторинг 5 файлов" | `/gsd-plan-phase` | Multi-file |
| "добавь логирование" | `/gsd-quick` | Single concern |
| "новая фича: notifications" | `/gsd-plan-phase` | New feature scope |

## Red-flag keywords (force /gsd-plan-phase + /council)

If user mentions ANY of these → upgrade to full pipeline:

- auth, authentication, authorization, login, password, session, token
- payment, billing, subscription, refund, stripe, paypal
- database migration, schema change, alter table
- breaking change, backward incompatible, public API
- security, encryption, hash, secret, key
- delete, destroy, drop (irreversible operations)
- production hotfix, prod deploy emergency

## Don't ask, route

User wrote "поправь баг" without context. Two ways to respond:

❌ "Какой бага? В каком файле? Это критично?" — slow, breaks flow

✅ Read git status / recent changes / open files → infer scope → pick mode → say "Поехал /gsd-quick: [bug description]" → execute

If context insufficient: ONE quick clarifying question, then execute.

## Override hints

User can override mode with explicit signals:

- "только быстро" / "just quick" → forces `/gsd-fast` even if you'd pick `/gsd-quick`
- "сделай нормально" / "do it properly" → forces `/gsd-plan-phase` even if `/gsd-fast` would suffice
- "council" → adds `/council` to whatever mode

Respect override. User knows their stakes better than the heuristic.

## Anti-patterns

- ❌ Asking 3 clarifying questions before picking mode (kills momentum)
- ❌ Always defaulting to `/gsd-plan-phase` "to be safe" (wastes $4 per typo)
- ❌ Always defaulting to `/gsd-fast` "to save money" (causes silent quality regressions)
- ❌ Overriding red-flag keywords without explicit user permission
- ❌ Skipping `/council` on auth/payments because "it's just a small change"

## Cross-references

- `skills/cost-routing-discipline/SKILL.md` — model selection within mode
- `rules/cost-discipline.md` — auto-load trigger keywords
- `components/cost-discipline.md` — cost rationale
