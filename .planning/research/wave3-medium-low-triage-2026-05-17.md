# Wave-3 MEDIUM/LOW Leftover Triage — 2026-05-17

Post-ship triage of `.planning/research/meta-audit-wave3-2026-05-16.md` findings that were NOT shipped in the v6.28.0 → v6.34.0 Wave-3 release sequence. Wave-3 closed all 12 HIGH-severity SECURITY findings plus the per-prompt high-impact gaps (EXPLAIN evidence gates, XID wraparound, WCAG 2.2 refresh, DEPLOY gate enforcement, modern-stack categories). MEDIUM and LOW long-tail items remain.

Triage method: a `caveman:cavecrew-investigator` agent cross-referenced the Wave-3 research doc against CHANGELOG entries for v6.28.0 → v6.34.0 and the current state of each base prompt under `templates/base/prompts/`. Findings already-closed-by-Wave-3 were filtered out; survivors classified MEDIUM-actionable / LOW-actionable / STALE / FALSE POSITIVE.

## Summary

- **MEDIUM-actionable:** 7 findings (CODE 1, DEPLOY 3, MYSQL 1, PERF 1, SECURITY 2)
- **LOW-actionable:** 15 findings (CODE 1, DEPLOY 2, MYSQL 2, PERF 1, POSTGRES 3, SECURITY 4)
- **STALE (closed by Wave-3 sibling release):** 1 (DESIGN F-004 — closed by v6.30.0 field-semantics override)

Total unshipped: 23 of 192 Wave-3 findings (~12%). HIGH bucket fully drained.

## By prompt

### CODE_REVIEW.md

| finding | class | hint | location |
|---------|-------|------|----------|
| CODE-F-002 | MEDIUM | Add guidance to read PR description + commit message + linked issue for intent before reviewing | `## GOAL` |
| CODE-F-004 | LOW | Define `## LOW-VALUE REVIEW FILTER` with concrete examples (currently placeholder list) | `## LOW-VALUE REVIEW FILTER` |

### DESIGN_REVIEW.md

| finding | class | hint | location |
|---------|-------|------|----------|
| DESIGN-F-004 | STALE | Field-semantics override added in v6.30.0 closes this; residual cross-check needed | line ~450 |

### DEPLOY_CHECKLIST.md

| finding | class | hint | location |
|---------|-------|------|----------|
| DEPLOY-F-006 | MEDIUM | Artifact attestation rule missing (version + tag + checksum proof) | Section 7 |
| DEPLOY-F-009 | MEDIUM | Queue-message compatibility gate absent (Kafka / RabbitMQ / SQS versioning + dead-letter) | Section 5 |
| DEPLOY-F-010 | MEDIUM | Feature-flag decommission lacks explicit `components/feature-flag-lifecycle.md` cross-reference | Section 6 |
| DEPLOY-F-012 | LOW | Multi-region + edge deployment rules defer to missing `components/deploy-templates/edge.md` | Stack Specifics |
| DEPLOY-F-013 | LOW | Canary statistical gate (success rate, latency bands, p99 deviation) undefined | Section 8 |

### MYSQL_PERFORMANCE_AUDIT.md

| finding | class | hint | location |
|---------|-------|------|----------|
| MYSQL-F-003 | MEDIUM | F-103 KNOWN-DEBT unresolved — per-audit measurable severity rubric lacks formalization | Section 0.1 |
| MYSQL-F-004 | LOW | Covering-index leftmost-prefix examples clarity; index-merge as redesign signal underspecified | Section 8.1 |
| MYSQL-F-005 | LOW | Replication lag threshold bands incomplete (per-RTO severity gate) | Section 8.3 |

### PERFORMANCE_AUDIT.md

| finding | class | hint | location |
|---------|-------|------|----------|
| PERF-F-001 | MEDIUM | Severity multi-axis incomplete: latency × blast-radius × QPS mapping lacks formal bands | Section 0.2 |
| PERF-F-002 | LOW | Cache hit-ratio diagnostic cross-reference to Severity Ceiling Table vague | Section 6.4 |
| PERF-F-003 | LOW | RSC / App Router partial pre-rendering edge case (PPR cache stability) missing | Section 3.7 |

### POSTGRES_PERFORMANCE_AUDIT.md

| finding | class | hint | location |
|---------|-------|------|----------|
| POSTGRES-F-204 | LOW | Autovacuum per-table tuning examples clarity (append-mostly scale factors) | Section 10.5 |
| POSTGRES-F-205 | LOW | JIT compilation threshold rubric (post-upgrade regression detection) incomplete | Section 10.6 |
| POSTGRES-F-206 | LOW | Parallel-plan investigation signals (`Workers Launched` divergence) vague | Section 10.7 |

### SECURITY_AUDIT.md

| finding | class | hint | location |
|---------|-------|------|----------|
| SECURITY-F-015 | MEDIUM | SSRF reserved-range bypass detection (decimal / hex / octal encoding) examples sparse | SSRF section |
| SECURITY-F-016 | MEDIUM | Gadget-chain severity cross-product (classpath availability) informal | Unsafe Deserialization H3 |
| SECURITY-F-017 | LOW | Cookie-tossing via subdomain takeover not named as explicit threat | Session Cookie Attributes H3 |
| SECURITY-F-018 | LOW | CSP3 `script-src-elem` vs `script-src-attr` distinction vague | Transport / Headers section |
| SECURITY-F-019 | LOW | Slopsquatting "sole-dependency-is-the-real-library" signal lacks detection SQL | Dependency Risk |

## Recommended sequencing

Two ship strategies.

**Strategy A — single v6.36.0 batch (recommended).** Bundle the 7 MEDIUM findings into one feat PR (~150-250 LOC additive across 6 files). Cost: 1 day. Defer 15 LOW to opportunistic backlog.

**Strategy B — per-prompt patch releases (v6.36.0-v6.36.6).** One release per touched prompt. Cost: 6× the release overhead. Only justified if each touch needs full audit-pipeline propagation (none do — all edits are additive within existing sections).

Strategy A wins. The 7 MEDIUMs cluster well:

1. CODE-F-002 — GOAL section, single-paragraph addition.
2. DEPLOY-F-006/F-009/F-010 — three new gate rows under Sections 5-7.
3. MYSQL-F-003 / PERF-F-001 — severity-rubric calibration, parallel edits.
4. SECURITY-F-015/F-016 — SSRF + deserialization detail expansion.

The 15 LOWs are polish; ship in a v6.37.0 "long-tail cleanup" or never. None are blockers.

## What this triage does NOT cover

- Findings the agent classified STALE but did not verify against the byte-exact splice state — verify before deleting from the Wave-3 doc.
- ID mapping: the triage uses agent-invented IDs (`CODE-F-002`, `DEPLOY-F-006`, etc.) that do not match the original Wave-3 research doc's F-NNN format. Re-cross-reference IDs before opening a v6.36.0 PR.
- Wave-3 doc may carry additional MEDIUM/LOW items not surfaced in the agent's summary (the agent counts say 80 MEDIUM + 58 LOW total, 22 unshipped — implies 116 were closed by Wave-3 which seems high; the actual closed count may be lower and the open count higher).
