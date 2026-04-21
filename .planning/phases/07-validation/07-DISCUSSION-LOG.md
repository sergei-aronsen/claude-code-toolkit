# Phase 7: Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 07-validation
**Areas discussed:** Translation-scope placement, Matrix execution strategy, Sandbox isolation per cell, RELEASE-CHECKLIST.md shape, Release cut scope, Version alignment enforcement

---

## Translation Scope (scope-creep adjudication)

Mid-discuss user requested Phase 6 README translations be included in v4.0 (reversing Phase 6 CONTEXT decision to defer to v4.1).

| Option | Description | Selected |
|--------|-------------|----------|
| Insert Phase 7.1 Translations | New decimal phase 7.1 before 7. Clean boundary: 7.1 syncs, 7 validates. Phase 6 CONTEXT unchanged; ROADMAP gets new phase. | ✓ |
| Fold into Phase 7 scope | Extend VALIDATE-* with DOCS-TR-01 inside Phase 7. Mixes content with release gating. | |
| Keep deferred to v4.1 | Tag v4.0.0 English-only; translations carry explicit "out-of-date, see EN" banner. | |
| Pre-phase-7 hotfix | Standalone /gsd-quick commit outside any phase; loses audit trail. | |

**User's choice:** Insert Phase 7.1 Translations.
**Notes:** Translations marked reversed from Phase 6's v4.1 deferral. Phase 7 now validates translation sync as invariant (D-12).

---

## Matrix Execution Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: auto + human sign-off | `scripts/validate-release.sh` runs cells; human verifies semantic invariants (SP hooks, translations, agent collision). Leverages 14 existing tests. | ✓ |
| Full manual checklist | md + bash snippets; human ticks boxes. No new runner. | |
| Full automated only | Runner-only; PASS/FAIL table. No human gate. | |

**User's choice:** Hybrid.
**Notes:** 14 existing scripts/tests/*.sh give a strong automation base; matrix runner composes them.

---

## Auto-Runner Asserts (per cell)

| Option | Description | Selected |
|--------|-------------|----------|
| Exit code 0 of install/update/migrate | Base invariant. | Claude's discretion — all 4 |
| `toolkit-install.json` schema + content | Parse with jq, verify `mode`, `installed_files[]`, `skipped_files[]`. | Claude's discretion — all 4 |
| `~/.claude/settings.json` keys intact | Pre/post diff — only TK-owned entries change. | Claude's discretion — all 4 |
| Skip-list matches mode | grep install result vs manifest filter. | Claude's discretion — all 4 |

**User's choice:** "сам решай" — deferred to Claude's discretion. All 4 recorded as default asserts.

---

## Sandbox Isolation per Cell

| Option | Description | Selected |
|--------|-------------|----------|
| tmp $HOME sandbox | `HOME=/tmp/tk-matrix-<cell>/...` per cell. POSIX, no Docker. Matches existing pattern. | ✓ |
| Docker per cell | Reproducible but conflicts with "POSIX, no runtime deps" invariant; macOS BSD not exercised. | |
| Single host + cleanup | Fast but risks clobbering real user config. | |

**User's choice:** tmp $HOME sandbox.

---

## v3.x Upgrade Simulation

| Option | Description | Selected |
|--------|-------------|----------|
| Git checkout v3.0.0 tag → install → reset main | Real v3.x state via history. | ✓ |
| Static v3.x fixture in tests/fixtures/ | Pre-captured snapshot. Drift risk. | |
| `synthesized_from_filesystem` fallback only | Exercise existing Phase 5 D-71 escape hatch. | |

**User's choice:** Git checkout v3.0.0 tag.
**Notes:** No `v3.0.0` git tag exists (`git tag -l` empty) — researcher must identify the canonical pre-4.0 commit. Candidate: parent of `c5c8cbc`. Phase may need to annotate the commit with a lightweight tag `v3.0.0-preflight`.

---

## RELEASE-CHECKLIST.md Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Human-runnable md + runner-script | Dual surface, same snippets. Checklist is audit-friendly; runner is automation-friendly. | ✓ |
| Only md checklist | Self-contained, no runner. Loses reproducibility. | |
| Only runner + auto-generated md | Single source but md is harder to read. | |

**User's choice:** Dual surface.

---

## Fail Mode

| Option | Description | Selected |
|--------|-------------|----------|
| Fail-fast | Exit on first FAIL. Matches `make check`. | ✓ |
| Collect-all | Run all 12, aggregate failures. | |
| Hybrid via `--fail-fast` flag | Default collect-all, flag to switch. | |

**User's choice:** Fail-fast.

---

## Release Cut Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Ready-to-tag | Phase finalizes CHANGELOG date + verifies. Human does `git tag` + `git push --tags` separately. | ✓ |
| Phase includes `git tag` | Phase commits the annotated tag. | |

**User's choice:** Ready-to-tag.
**Notes:** Preserves CLAUDE.md "never push directly to main" invariant. Agent does not cut release tags.

---

## Version Alignment Enforcement

| Option | Description | Selected |
|--------|-------------|----------|
| make check + CI target | New `make version-align` permanent gate. Blocks future drift too. | ✓ |
| Release-checklist-only snippet | One-off check. No forward guarantee. | |

**User's choice:** make check + CI gate.

---

## Follow-up

| Option | Description | Selected |
|--------|-------------|----------|
| Ready for context | Write CONTEXT.md now; Phase 7.1 comes via `/gsd-insert-phase`. | ✓ |
| Discuss agent collision check mechanism | Static manifest grep vs runtime sandbox check. | |
| Discuss make check extensions | version-align, translation-drift, release-gate integration. | |

**User's choice:** Ready for context.
**Notes:** Agent collision handled via Claude's discretion in D-11 (both static + runtime enforced).

## Claude's Discretion

- Exact assertion wording and bash mechanics inside `scripts/validate-release.sh` (D-03 contract preserved).
- Markdown layout of RELEASE-CHECKLIST.md (pipe-table vs per-cell sections).
- `jq` vs `python3 -c 'import json'` for version-align implementation.
- Cell cleanup cadence (per-cell rm vs shared base dir).
- `docs/INSTALL.md` vs `docs/RELEASE-CHECKLIST.md` cell-parity auto-check (nice-to-have, not blocker).
- Exact implementation of agent-collision check (both static + runtime required per D-11; bash specifics are planner's choice).

## Deferred Ideas

- Phase 7.1 for README translation sync (reversal of Phase 6 v4.1 deferral).
- Bats automation (v4.1, TEST-01).
- Docker per-cell (permanently out — conflicts with POSIX invariant).
- Auto git tag + push (out — CLAUDE.md invariant).
- `--collect-all` fail mode (v4.1+).
- BACKUP-01/02 backup hygiene (v4.1).
- INSTALL.md ↔ RELEASE-CHECKLIST.md parity auto-check (v4.1).

---

## 2026-04-21 — Auto-mode Re-Discuss Pass

**Invocation:** `/gsd-discuss-phase 7 --auto`
**Context state at invocation:** `has_context=true`, `has_plans=true` (4 plans; 3 executed, 07-04 pending), Phase 7.1 shipped.
**Mode decision:** Auto-select "Update it" per check_existing.

### Analysis Outcome

No new gray areas surfaced. All 12 D-items (D-01..D-12) remain locked and consistent with executed plans 07-01/02/03. Plan 07-04 (release gate) is fully specified by existing D-08/D-09/D-10/D-11 and does not require new decisions.

### Metadata-Only Updates Applied

| Field | Before | After |
|-------|--------|-------|
| Status | Ready for planning | Plans 07-01/02/03 executed; 07-04 release gate pending human checkpoint |
| Blocker | Phase 7.1 must ship | Phase 7.1 shipped 2026-04-21 — unblocked, `make translation-drift` green |
| Updated | (absent) | 2026-04-21 |

### Decisions Reaffirmed (no change)

- D-01..D-12 remain authoritative.
- `<canonical_refs>` unchanged — all referenced artifacts still live at paths listed.
- `<code_context>` unchanged — Makefile:42-95 pattern + 14 test scripts in `scripts/tests/` remain the reusable base; `validate-release.sh` + `test-matrix.sh` landed per Plan 07-03.
- Deferred ideas unchanged.

**Outcome:** Context is current. Auto-advance to plan-phase.
