# Phase 16: Template Propagation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 16-template-propagation-49-prompt-files
**Mode:** auto (single-pass, recommended-default selection per gray area)
**Areas discussed:** Splice Strategy, Block Insertion Points, Idempotency, Language Preservation, CI Gate Extension, Component / SOT Discipline

---

## Splice Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| One Bash splice script (`scripts/propagate-audit-pipeline-v42.sh`) reading components at run-time | Idempotent, deterministic, durable for v4.3+ | ✓ |
| 49 hand edits via Edit tool | Slow, error-prone, breaks SOT discipline | |
| Inline the SOT bodies directly into a script | Couples Phase 14 SOT changes to script edits — defeats the purpose | |

**User's choice:** Bash script reading components at run time (recommended default — D-01)
**Notes:** SOT discipline preserved — components are the single source of truth, the script is a fan-out consumer.

---

## Block Insertion Points

| Decision | Selected Approach |
|----------|-------------------|
| Top-of-file callout location | First non-frontmatter line below H1 + tagline; HTML comment format (D-05) |
| 6-step FP-recheck SELF-CHECK location | Replaces existing free-form `## NN. SELF-CHECK` body, preserves heading number; appended near top if absent (D-06) |
| Structured OUTPUT FORMAT location | Appended at file bottom, BELOW any existing report-format section (preserves prior content per TEMPLATE-02) (D-07) |
| Council Handoff footer location | LAST H2 section of the file (D-08) |

**User's choice:** Locations chosen to be unambiguous and preserve any existing content (TEMPLATE-02 enforcement).

---

## Idempotency

| Option | Description | Selected |
|--------|-------------|----------|
| Sentinel HTML comment per block; 4 sentinels = full splice; 1-3 = error | Re-running script on already-spliced file is a no-op; partial state aborts | ✓ |
| Hash-based detection (compute file hash, compare to ledger) | More fragile against unrelated edits | |
| No idempotency — script always splices | Risk of duplicate sections | |

**User's choice:** Sentinel HTML comments (recommended default — D-09)
**Notes:** Test 20 wires the idempotency check (run script twice, assert `diff -r` empty).

---

## Language Preservation (TEMPLATE-02)

| Option | Description | Selected |
|--------|-------------|----------|
| All four spliced blocks ship in English; surrounding prompt prose untouched | Matches all 49 current files (English-only); contracts are tooling-readable not user-facing | ✓ |
| Localize FP-recheck procedure body per-framework | Out of scope; contracts must stay byte-exact for the Phase 14 + 15 tooling | |
| Translate top-of-file callout based on detected file language | Premature; no Russian prompt files exist today | |

**User's choice:** English-only contract blocks; surrounding prompt prose untouched (recommended default — D-11, D-12)

---

## CI Gate Extension (TEMPLATE-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing `Makefile validate` audit-prompt grep loop with `Council handoff` + `1. **Read context**` checks; mirror in `quality.yml`; add Test 20 for idempotency | Single source of truth for the gate; CI mirrors local | ✓ |
| Separate validate target dedicated to v4.2 markers | Splits the gate; harder to maintain | |
| Skip CI gate; rely on manual review | Drift risk over time | |

**User's choice:** Extend existing validate + mirror in CI + add Test 20 (recommended default — D-13, D-14, D-15)

---

## Component / SOT Discipline

| Option | Description | Selected |
|--------|-------------|----------|
| No new `components/*.md` SOT in this phase; consume Phase 14 SOTs at script-run time | Maintains "one component, one edit point" discipline | ✓ |
| Create `components/audit-prompt-template.md` aggregating the four blocks | Adds a new SOT layer; redundant with Phase 14 components | |

**User's choice:** Consume existing SOTs (recommended default — D-16, D-17)

---

## Claude's Discretion

- Top-of-file callout wording (constraint: short, references audit-exceptions.md by full relative path)
- Council Handoff footer paragraph wording (constraint: quote byte-exact slot string + link to audit.md Phase 5 + council.md Modes)
- awk vs sed vs pure Bash for block insertion — pick whichever is shortest and clearest
- Sentinel comment text format (constraint: namespaced under `v42-splice`)

## Deferred Ideas

- Localizing contract blocks (out of scope; v4.3 if templates get localized)
- Auto-running splice script in CI on PRs touching components (premature)
- Per-framework custom Council handoff footers (Council is framework-agnostic by design)
- Wholesale prompt content rewrites (explicitly forbidden by REQUIREMENTS.md)
- Versioned splice scripts for future migrations (premature)
