# Phase 12: Audit Verification + Template Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 12-audit-verification-template-hardening
**Areas discussed:** Verification scope, Wave grouping, REQ-ID naming, Verification methodology

---

## Verification scope

### Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| All 15 (Recommended) | Verify every pass-3 claim. Complete audit record. Higher cost but definitive — prevents re-asking in v4.2. Many will be quick FALSE verdicts since already mitigated. | ✓ |
| HIGH+MEDIUM only (9) | Skip the 6 LOWER items. Faster but leaves gaps. LOWER items would need re-audit later. | |
| HIGH only (5) | Just manifest schema, namespace collision, stack autodetection, relative path fragility, merge-strategy. Minimal — but 10 unverified claims remain open. | |

**User's choice:** All 15 (Recommended)
**Notes:** Complete audit record chosen over faster-but-gappy alternatives. Future v4.2 auditor won't need to re-open the same claims.

### Evidence bar

| Option | Description | Selected |
|--------|-------------|----------|
| grep + read (Recommended) | Each claim gets grep/glob proof + read actual code + verdict REAL/PARTIAL/FALSE with file:line citation. | ✓ |
| Read-and-reason only | Read relevant files, write prose verdict. Faster but less auditable. | |
| Reproducible repro script | Each REAL claim gets a shell snippet demonstrating the issue. Highest rigor, highest cost. | |

**User's choice:** grep + read (Recommended)
**Notes:** Determinism and reviewability prioritized over repro-script rigor.

### Output artifact

| Option | Description | Selected |
|--------|-------------|----------|
| AUDIT.md + REQ table (Recommended) | Single AUDIT.md with 15-row verdict table. REAL rows promote to REQ-IDs in REQUIREMENTS.md. | ✓ |
| Inline in CONTEXT.md | No separate AUDIT.md. Evidence embedded inside 12-CONTEXT.md decisions section. | |
| Per-claim files under claims/ | One markdown per claim. Maximum granularity. | |

**User's choice:** AUDIT.md + REQ table (Recommended)
**Notes:** Clean separation: audit.md = evidence, REQUIREMENTS.md = action.

---

## Wave grouping

### Axis

| Option | Description | Selected |
|--------|-------------|----------|
| By theme (Recommended) | A = schema/validation, B = install safety, C = provenance/metadata. Coherent PRs per wave. | ✓ |
| By severity | A = HIGH (5), B = MEDIUM (4), C = LOWER (6). | |
| By cost | A = cheap, B = medium, C = deep refactor. | |

**User's choice:** By theme (Recommended)
**Notes:** Thematic grouping produces coherent PRs; severity mix across themes was an explicit acceptable tradeoff.

### v4.1 cut

| Option | Description | Selected |
|--------|-------------|----------|
| Wave A only in v4.1 (Recommended) | Waves B+C become v4.2 scope. Keeps v4.1 shippable. | ✓ |
| Waves A+B in v4.1 | Heavier v4.1, +2-3 weeks, Wave C stays v4.2. | |
| All 3 waves in v4.1 | Full pass-3 closure, slowest path. | |
| Verification only in v4.1 | AUDIT.md only, all 3 waves become v4.2 phases. | |

**User's choice:** Wave A only in v4.1 (Recommended)
**Notes:** Scope protection over closure. Phases 8-11 already commit v4.1; adding only Wave A keeps release velocity.

---

## REQ-ID naming

### Prefix family

| Option | Description | Selected |
|--------|-------------|----------|
| AUDIT-* + HARDEN-* (Recommended) | AUDIT-01..15 = verification rows; HARDEN-A-NN / HARDEN-B-NN / HARDEN-C-NN = wave-scoped fixes. | ✓ |
| VERIFY-* + TEMPLATE-* | Loses wave association in ID. | |
| Reuse topical prefixes | Semantically descriptive but proliferates prefix families. | |
| Flat PH12-NN | Simplest but opaque. | |

**User's choice:** AUDIT-* + HARDEN-* (Recommended)
**Notes:** Wave letter embedded in HARDEN-X-NN ID makes provenance visible without lookup.

### Verdict tracking

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — all 15 as AUDIT-NN (Recommended) | Every claim is a REQ row, FALSE rows marked Closed. Full paper trail. | ✓ |
| Only REAL/PARTIAL as REQ-IDs | FALSE stays in AUDIT.md only, cleaner REQ table. | |

**User's choice:** Yes — all 15 as AUDIT-NN (Recommended)
**Notes:** Future auditor re-reading the same ChatGPT report sees closure without re-investigation.

---

## Verification methodology

### Runner

| Option | Description | Selected |
|--------|-------------|----------|
| Parallel Explore agents (Recommended) | 3 agents, 5 claims each, Haiku tier, main thread synthesizes. | ✓ |
| Main thread sequential | Higher context cost, full visibility per verdict. | |
| Single Plan agent does all 15 | Serial, single context. | |

**User's choice:** Parallel Explore agents (Recommended)
**Notes:** Parallel + Haiku tier aligns with global CLAUDE.md subagent routing for deterministic grep work.

### Plan split

| Option | Description | Selected |
|--------|-------------|----------|
| 2 plans: AUDIT + WAVE-A (Recommended) | Plan 12.1 produces AUDIT.md; Plan 12.2 implements Wave A fixes. | ✓ |
| 1 plan covering audit + Wave A | Simpler but blocks user gate. | |
| N plans: 1 audit + 1 per HARDEN-A-NN | Maximum granularity, planning overhead multiplies. | |

**User's choice:** 2 plans: AUDIT + WAVE-A (Recommended)
**Notes:** Two-plan split enables the user-review gate between audit evidence and fix execution.

### Audit gate

| Option | Description | Selected |
|--------|-------------|----------|
| User review gate (Recommended) | After AUDIT.md lands, stop. User approves which REAL rows become HARDEN-A-NN REQs. | ✓ |
| Auto-promote all REAL to HARDEN-A | Fastest path, risks spurious fix work. | |

**User's choice:** User review gate (Recommended)
**Notes:** Some REAL findings are expected to be real-but-not-worth-fixing; explicit approval prevents spurious Wave-A work.

---

## Claude's Discretion

- Plan file layout (single PLAN.md with two phases vs PLAN-1-AUDIT.md + PLAN-2-WAVE-A.md)
- Exact partition of 15 claims across 3 Explore agents (by number or by theme)
- Whether Plan 12.2 further splits across sub-plans based on approved HARDEN-A count
- AUDIT.md cell formatting conventions (path-relative, line range vs single line)

## Deferred Ideas

- Wave B implementation (install safety) → v4.2+ phase
- Wave C implementation (provenance/metadata) → v4.2+ phase
- Pass-4 audit from another AI → v4.2+ phase if desired
- Retroactive runtime-audit (pass-1/pass-2) verification — already retracted, not re-verifying
- Upstream issue filing for FALSE-verdict hallucinations — no action, stays in AUDIT.md only
