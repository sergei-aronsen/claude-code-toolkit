# Audit Severity Anchor

Canonical severity rubric reference for all audit prompts. Closes wave-2
finding F-242 (severity rubric duplication / drift across base prompts).

This component is the **single point of reference** for severity labels
in audit findings. Audit prompts that need to surface a severity must
either:

1. Defer to this anchor (citation-only): "See `components/audit-severity-anchor.md` for the canonical rubric."
2. Specialize the calibration with audit-specific thresholds (e.g.,
   PERFORMANCE_AUDIT latency thresholds, SECURITY_AUDIT exploit
   preconditions) **without redefining** the four labels themselves.

Audit prompts must NOT redefine CRITICAL / HIGH / MEDIUM / LOW with
different semantics. If a redefinition seems necessary, that is a
signal the audit needs a *calibration table* (mapping audit-specific
inputs to one of the four canonical levels), not a new rubric.

## Canonical Levels (frozen — do not redefine)

| Level | Reachability | Action |
| ------- | -------- | -------- |
| **CRITICAL** | Exploitable today, data loss / RCE / auth bypass / regulated-data exposure with realistic preconditions | **BLOCKER** — fix before merge |
| **HIGH** | Serious correctness or security issue requiring auth or non-trivial preconditions to exploit / trigger | Fix before deploy |
| **MEDIUM** | Real issue with bounded blast radius (information disclosure, missing rate limit, weak policy, p95 > 1s) | Fix this sprint |
| **LOW** | Defense-in-depth, hardening, micro-optimization, minor style or maintainability concern | Backlog |

The full rubric (with category-by-category examples for SECURITY,
PERFORMANCE, CODE_REVIEW, DESIGN) lives in `components/severity-levels.md`
— this anchor is the short reference card.

## Severity Ceiling Table (precondition → maximum severity)

The **maximum severity** a finding may claim is bounded by its weakest
precondition. Apply the lowest ceiling that matches; never inflate.

| Required attacker class | Required interaction | Max severity |
|-------------------------|----------------------|--------------|
| Unauthenticated, network-reachable | None | **CRITICAL** |
| Unauthenticated, network-reachable | Click link / open page | HIGH |
| Authenticated user (any tenant) | None | HIGH |
| Authenticated user (any tenant) | Click link / open page | MEDIUM |
| Tenant-admin (or peer tenant cross-over) | None | MEDIUM |
| Tenant-admin | Click link / specific UI flow | LOW–MEDIUM |
| Org-admin / instance-admin | Any | LOW (admin can already cause harm) |
| Compromised external service (OAuth app, partner API) | None | HIGH |
| Compromised external service | Specific webhook payload | MEDIUM |
| Insider with shell access | Any | Out of scope (assume admin) |

When a finding's preconditions span multiple rows, take the **strongest**
precondition the attacker actually needs to satisfy — not an aggregate.

For data-classification multipliers (PII, PHI, PCI, financial
credentials), see SECURITY_AUDIT `## DATA CLASSIFICATION` — that table
extends this anchor with audit-specific multipliers without changing
the four canonical labels.

## Audit-Specific Calibration

Each audit may add a calibration table that maps audit-specific inputs
to one of the four canonical labels. The labels themselves do not move.

Examples already in production:

- **SECURITY_AUDIT** — `## EXPLOIT PRECONDITIONS` adds the Severity
  Ceiling Table above plus `## DATA CLASSIFICATION` multipliers.
- **PERFORMANCE_AUDIT** — `## 0.2 SEVERITY THRESHOLDS` maps p95 latency
  bands to the four levels (CRITICAL > 5s end-to-end, HIGH > 2s p95,
  MEDIUM > 1s p95, LOW < 1s).
- **POSTGRES_PERFORMANCE_AUDIT** — `## 0.1 SEVERITY THRESHOLDS`
  calibrates to PostgreSQL engine signals (e.g.
  `pg_stat_statements.mean_exec_time`, buffer-pool hit ratio,
  transaction-id age vs autovacuum_freeze_max_age). Local to the
  sub-prompt because the umbrella `## 0.2` does not bind PostgreSQL
  specifics (added in v6.33.0).
- **MYSQL_PERFORMANCE_AUDIT** — `## 0.1 SEVERITY THRESHOLDS` calibrates
  to MySQL engine signals (e.g.
  `events_statements_summary_by_digest.avg_ms`, InnoDB buffer-pool hit
  ratio, replication lag) and includes a `### 0.1.1` multi-axis rubric
  (`Severity = max(SignalBand, BlastRadius, UserVisibility, ...)`).
  Local to the sub-prompt for the same reason as POSTGRES (added in
  v6.34.0, multi-axis in v6.36.0).
- **CODE_REVIEW** — `## SEVERITY AND CONFIDENCE` adds confidence axes
  (HIGH / MEDIUM / LOW) that combine multiplicatively with severity
  to gate which findings appear in the structured report.

## Anti-Patterns

- **Redefining a label** ("for this audit, CRITICAL means …") — use the
  ceiling table or audit-specific calibration instead.
- **Inventing new labels** ("BLOCKER+", "URGENT-MEDIUM", "P0") — pick
  one of the four. Reviewer tooling and report templates assume the
  fixed set.
- **Using emoji-only severity** ("🚨 finding") without an explicit
  CRITICAL / HIGH / MEDIUM / LOW label — emojis decorate, they don't
  classify.
- **Padding** — five weak MEDIUMs are worse than one verified CRITICAL.
  If you can't describe a concrete attack path / failure mode the user
  would care about, drop or downgrade.
