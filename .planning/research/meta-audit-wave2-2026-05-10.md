# Meta-Audit Wave 2 — Findings (v6.14.1+ scope)

**Date:** 2026-05-10
**Method:** 7 parallel adversarial reviewer agents, one per base prompt.
**Scope:** `templates/base/prompts/*.md` (7 files).
**Total findings:** 139

## Distribution

| Prompt | Findings | HIGH | MED | LOW | ID range |
|--------|----------|------|-----|-----|----------|
| CODE_REVIEW | 25 | 5 | 19 | 1 | F-200..F-224 |
| SECURITY_AUDIT | 26 | 4 | 16 | 6 | F-230..F-255 |
| PERFORMANCE_AUDIT | 15 | 5 | 9 | 1 | F-260..F-274 |
| DEPLOY_CHECKLIST | 17 | 1 | 14 | 2 | F-290..F-306 |
| DESIGN_REVIEW | 11 | 5 | 5 | 1 | F-320..F-330 |
| MYSQL_PERFORMANCE_AUDIT | 21 | 0 | 21 | 0 | F-350..F-370 |
| POSTGRES_PERFORMANCE_AUDIT | 24 | 2 | 19 | 2 | F-380..F-403 |
| **Totals** | **139** | **22** | **103** | **13** | — |

---

## Triage by Effort

### v6.14.1 — small/surgical fixes (1-line edits, no semantic change)

Quick wins. Each finding ~5-15 min to fix and test. Bundle into single PR.

**MYSQL_PERFORMANCE_AUDIT — copy-paste / unit errors (CRITICAL bugs):**

- **F-357** (line 390, 396) — References "PgBouncer for PostgreSQL" in MySQL prompt. PgBouncer is PostgreSQL-only. Replace with ProxySQL/MaxScale or delete.
- **F-359** (line 437-439) — SQL `AVG_TIMER_WAIT > 1000000000000` treats nanoseconds as milliseconds. Threshold = 1000s, not 1ms. Wrong rows or empty result.
- **F-369** (line 450-501) — Entire PostgreSQL config block (shared_buffers, work_mem, random_page_cost) erroneously embedded in MySQL prompt. Auditors copying into my.cnf cause errors.

**SECURITY_AUDIT — internal contradictions:**

- **F-247** (line 597-615 vs 588) — Gate 1 adversarial-review says "every HIGH or CRITICAL" at line 599 but "every severity" at line 588. Specify: Gate 1 mandatory for HIGH/CRITICAL only.
- **F-232** (line 72 vs 250 vs 655) — `eval` red-flagged absolute at line 72/250 but allowed in build-time codegen at line 655. Gate red-flag list behind "user-influenced code path" qualifier.

**DESIGN_REVIEW — markdown / parity nits:**

- **F-330** (line 276-299) — H1 headings (`# Navigation`) in code-reference section violate hierarchy. Change to `## Navigation` or inline.
- **F-320** (line 1-20) — Missing `## GOAL` section. Sibling audits all have it. Add after callout block.

**Cross-prompt parity:**

- **F-322 / F-273** — Add explicit `## CATEGORY CONSTRAINT` section to DESIGN_REVIEW + PERFORMANCE_AUDIT (constraint is implicit/buried).

### v6.14.2 — medium fixes (per-prompt small batches)

Each prompt gets a focused PR for cohesion. ~30 findings.

- CODE_REVIEW: F-200, F-201, F-211, F-217, F-221, F-223 (severity SOT references, terminology)
- SECURITY_AUDIT: F-230, F-231, F-242, F-243, F-246, F-251 (clarifications + section ordering)
- PERFORMANCE_AUDIT: F-261, F-263, F-265, F-272 (definitions, workload context)
- POSTGRES_PERFORMANCE_AUDIT: F-380, F-382, F-383, F-388, F-396, F-398 (version qualifiers + error guards)
- MYSQL_PERFORMANCE_AUDIT: F-352, F-353, F-358, F-360, F-364, F-367 (bug fixes + thresholds)

### v6.15.0 — DEPLOY_CHECKLIST rework (HIGH risk)

CHANGELOG flagged "DEPLOY rework" as v6.14.1+ scope. Wave 2 confirms via F-290:

> **F-290** — Audit machinery (SELF-CHECK, OUTPUT FORMAT, FALSE-POSITIVE CONTROL) injected into a checklist prompt, not an audit prompt. DevOps operators face 6-step FP procedures on a checkbox-only workflow.

Fix path: split DEPLOY_CHECKLIST into two prompts OR remove audit machinery entirely. Includes 14 MED findings (F-291..F-306) on real safety gaps:

- Atomicity & rollback-point clarity (F-296)
- Backward-compatibility check on migrations (F-293)
- Pre-deploy baseline metrics (F-305)
- Threat model integration (F-295)

Dependent on `/council` validation — touches workflow contract that operators rely on.

### v6.15.1 — DESIGN_REVIEW identity split (HIGH risk)

CHANGELOG flagged "DESIGN identity split" as v6.14.1+ scope. Wave 2 confirms via F-321 / F-329:

> **F-321** — Title "UI/UX Quality Audit" but Phase 7 audits software architecture (component reuse, design tokens, bundle size, performance).
>
> **F-329** — Phase 7 "Code Health" audits non-design concerns; belongs in CODE_REVIEW or PERFORMANCE_AUDIT.

Fix path: either split DESIGN_REVIEW into two prompts (UI/UX + Design-System Code Health) OR remove Phase 7. Decision needs `/council`.

### v6.15.2 — Severity rubric per-audit calibration

Multiple findings flag missing per-audit severity calibration:

- **F-218** (CODE_REVIEW) — define what HIGH/CRITICAL mean for code-review (data loss vs invalid state)
- **F-274** (PERFORMANCE_AUDIT) — clarify CRITICAL alignment between perf and security
- **F-385** (POSTGRES) — workload-specific thresholds (OLTP >99% vs OLAP 70-80% cache hit)
- **F-263** (PERFORMANCE_AUDIT) — p95 definition (rolling window? outlier treatment?)

Approach: per-audit calibration tables referencing `components/severity-levels.md` SOT. Avoid redefining rubric.

### v6.15.3 — FALSE-POSITIVE CONTROL three-gate parity

v6.14.0 F-104 added three-gate structure to SECURITY_AUDIT. Wave 2 finds it missing in:

- **F-260** (PERFORMANCE_AUDIT)
- **F-324** (DESIGN_REVIEW)
- **F-363** (MYSQL)
- (POSTGRES status uncertain — gate exists but partial)

Approach: extract three-gate template to `components/audit-fp-control.md` and splice via v42 pipeline.

### v6.15.4 — UNCERTAINTY DISCIPLINE / Non-Blocking Observations parity

Multiple findings flag inconsistency:

- **F-204** (CODE_REVIEW shorter than SECURITY_AUDIT)
- **F-327** (DESIGN_REVIEW references "Non-Blocking Observations" section that doesn't exist in template)
- **F-301** (DEPLOY_CHECKLIST UNCERTAINTY DISCIPLINE out of place — checklist not audit)

Approach: extract canonical UNCERTAINTY DISCIPLINE to component, splice consistently.

### Deferred

- **F-205 / F-206 / F-207 / F-209** — Type Slug to Prompt File Map duplication. Solved by F-101's existing schema doc — confirm propagation.
- **F-220** — Council audit-review semantics for non-security audits (does Gemini reason from security frame?). Needs `/council` policy decision.
- **F-403** — Postgres audit lacks "Automation" section (asymmetric with MySQL audit). Add or de-scope.

---

## Highest-Risk Findings (security / correctness bugs)

These are not just clarifications — real defects in shipped prompts:

| Finding | Prompt | Bug |
|---------|--------|-----|
| F-359 | MYSQL | `AVG_TIMER_WAIT > 1e12` ns vs ms unit error (off by 10^9) |
| F-369 | MYSQL | Postgres config block embedded in MySQL prompt |
| F-357 | MYSQL | "PgBouncer for PostgreSQL" referenced in MySQL prompt |
| F-381 | POSTGRES | DATABASE_URL with `user:pass` leaks credentials in process listings, K8s secrets, git diff |
| F-394 | POSTGRES | pg_stat_statements query output may leak SENSITIVE DATA via prepared statement names |
| F-353 | MYSQL | Fragmentation calc `DATA_FREE / NULLIF(DATA_LENGTH, 0)` produces NULL for empty tables, no `WHERE` guard |

---

## Recommended Sequencing

1. **v6.14.1 surgical PR** — bug fixes (F-359, F-369, F-357), security (F-381 stage), markdown (F-330), missing GOAL (F-320). One PR, ~10 findings, all low-risk.
2. **v6.14.2 per-prompt PRs** — clarifications by prompt; 4-6 PRs, ~30 findings.
3. **v6.15.0 DEPLOY rework** — `/council` first, then full rework.
4. **v6.15.1 DESIGN identity split** — `/council` first, then split.
5. **v6.15.2..v6.15.4** — calibration / FP-control / UNCERTAINTY parity. Each gets dedicated PR with component extraction.

---

## Raw Findings (Per Prompt)

### CODE_REVIEW (F-200..F-224)

(See agent output transcript — preserved in PR description.)

Highlights:

- F-200 HIGH 79: severity SOT reference vs SECURITY_AUDIT inline copy
- F-201 HIGH 82: contradiction on inline rubric redefinition
- F-202 HIGH 153-166: BUSINESS LOGIC weaker than SECURITY_AUDIT
- F-205 HIGH 207: v42-splice copy-paste not centralized
- F-209 HIGH 347: Category field omits parenthetical constraint
- F-220 HIGH 440: Council audit-review semantics unclear for non-security
- + 19 MED + 1 LOW

### SECURITY_AUDIT (F-230..F-255)

- F-230 HIGH 14-18: exploit chain output format unclear (one chain = one finding?)
- F-231 HIGH 62-64: severity table positional vs precondition-rule mapping
- F-232 HIGH 72/250/655: eval contradicting rules
- F-245 HIGH 539-556 vs 77-103: inference forbidden vs threat-model required contradiction
- + 16 MED + 6 LOW

### PERFORMANCE_AUDIT (F-260..F-274)

- F-260 HIGH 298-307: missing three-gate FALSE-POSITIVE CONTROL
- F-262 HIGH 318: step 3 uses security examples, not perf-specific
- F-263 HIGH 49-54: p95 definition ambiguous
- F-264 HIGH 289-295: APM tool SOT undefined
- F-268 HIGH 298-307: missing ATTACKER MODEL / WORKLOAD ADVERSARY
- F-271 HIGH 318: "eval inside build-time codegen" example — security pattern in perf audit
- + 9 MED + 1 LOW

### DEPLOY_CHECKLIST (F-290..F-306)

- F-290 HIGH 8-10: audit machinery in checklist prompt — fundamental mismatch
- + 14 MED (sequencing, atomicity, threat model, smoke test automation, rollback specificity)
- + 2 LOW

### DESIGN_REVIEW (F-320..F-330)

- F-320 HIGH 1-20: missing `## GOAL` section
- F-321 HIGH 1, 186-208: identity split (UI/UX vs software architecture)
- F-322 HIGH 497, 599: implicit Category constraint
- F-324 HIGH 357-402: missing FALSE-POSITIVE CONTROL three-gate
- F-329 HIGH 186-208: Phase 7 scope creep (bundle size, lazy loading)
- + 5 MED + 1 LOW

### MYSQL_PERFORMANCE_AUDIT (F-350..F-370)

- F-350 SEC 51: `/etc/mysql/debian.cnf` plaintext password file path hardcoded
- F-353 BUG 349-350: NULL fragmentation calc on empty tables
- F-357 BUG 390/396: PgBouncer in MySQL prompt
- F-359 BUG 437-439: AVG_TIMER_WAIT unit error (1e9x off)
- F-364 PARITY 511-574: missing FALSE-POSITIVE CONTROL gates
- F-369 BUG 450-501: PostgreSQL config block in MySQL prompt
- + 15 more MED

### POSTGRES_PERFORMANCE_AUDIT (F-380..F-403)

- F-380 HIGH 110: `idle_in_transaction_session_timeout` scope confusion
- F-381 HIGH 455: DATABASE_URL credential leak
- F-394 SEC 308: pg_stat_statements may leak credentials in error logs
- F-392 BUG 251-252: unused-index check unreliable if uptime < 7d
- F-398 BUG 557: ALTER TABLE non-instant for non-immutable defaults
- + 19 MED + 2 LOW
