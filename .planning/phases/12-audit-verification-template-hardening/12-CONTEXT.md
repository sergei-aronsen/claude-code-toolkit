# Phase 12: Audit Verification + Template Hardening - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 12 delivers two artifacts, in sequence with a user gate between them:

1. **AUDIT.md** — a 15-row verdict table verifying every claim from the ChatGPT pass-3 template-level audit against this repo's actual code. Each row: `Claim | Status (REAL/PARTIAL/FALSE) | Evidence (file:line) | Action`.
2. **Wave A hardening** — the schema/validation themed subset of REAL findings, implemented under `HARDEN-A-NN` requirements inside v4.1.

**In scope:** verification of all 15 pass-3 claims; implementation of Wave A REAL findings only.
**Out of scope:** Wave B (install safety) and Wave C (provenance/metadata) implementations — those defer to v4.2+ phases. FALSE-verdict claims never get fix work; they're recorded for traceability only.

This phase does not introduce new install modes, CLI flags, or user-facing features beyond what Wave A REAL findings demand.
</domain>

<decisions>
## Implementation Decisions

### Verification Scope
- **D-01:** Verify ALL 15 pass-3 claims. None skipped, even ones pre-judged FALSE. Complete audit record prevents re-opening the same claims in v4.2.
- **D-02:** Evidence bar per claim = grep/glob proof + read the cited code + verdict with `file:line` citation. Deterministic and reviewable, no pure prose verdicts.
- **D-03:** Output = single `12-AUDIT.md` with a 15-row verdict table. Columns: `Claim | Status | Evidence | Action`. Not inline in CONTEXT.md, not per-claim files.
- **D-04:** REAL + PARTIAL rows promote to `HARDEN-A-NN` (Wave A theme only) or get noted for v4.2+ (Waves B/C themes). FALSE rows stay AUDIT-only — no fix work, but still tracked as AUDIT-NN REQ with status=Closed.

### Wave Structure
- **D-05:** Findings split into 3 waves by theme, not by severity or cost:
  - **Wave A (schema/validation)** — plugin manifest JSON schema, markdown command linting, template integrity checksum, other schema-shaped claims.
  - **Wave B (install safety)** — namespace collision, stack autodetection, relative path fragility, collision-detection with existing `.claude/`, merge-strategy declaration.
  - **Wave C (provenance/metadata)** — compat matrix, template version pinning, `installed_templates.json`, dependency graph, uninstall semantics.
  - Final wave membership is determined by the AUDIT.md verdicts; above list is the initial partition, not a lock.
- **D-06:** v4.1 ships Wave A only. Waves B and C defer to v4.2+ and get their own phase numbers at that time. Phase 12 produces REQ definitions for all three waves but only Wave A REQs execute now.

### REQ-ID Naming
- **D-07:** Phase 12 introduces two prefix families:
  - `AUDIT-01..AUDIT-15` — one per pass-3 claim. Every claim, regardless of verdict, gets a REQ-ID row in REQUIREMENTS.md. Status column reflects REAL/PARTIAL/FALSE/Closed.
  - `HARDEN-A-NN` — Wave A fix requirements, one per REAL/PARTIAL Wave-A finding that user approves at the gate.
  - `HARDEN-B-NN` / `HARDEN-C-NN` — reserved for v4.2+ phases; defined in AUDIT.md but not entered into REQUIREMENTS.md traceability until promoted.
- **D-08:** FALSE verdicts tracked as AUDIT-NN REQ rows with `status=Closed - FALSE` so a future auditor re-reading the same ChatGPT report sees the closure reason without re-running verification.

### Verification Methodology
- **D-09:** Verification runs via 3 parallel Explore subagents, 5 claims each. Model tier = Haiku (deterministic grep/glob per global CLAUDE.md routing). Main thread synthesizes returned evidence into AUDIT.md.
- **D-10:** Phase 12 splits into 2 plans:
  - **Plan 12.1 — AUDIT** — produces `12-AUDIT.md` with all 15 verdicts; updates REQUIREMENTS.md with AUDIT-01..15 rows; proposes HARDEN-A-NN REQs for user approval.
  - **Plan 12.2 — WAVE-A IMPLEMENTATION** — executes approved HARDEN-A-NN REQs only. Runs after user gate.
- **D-11:** User review gate between Plan 12.1 and Plan 12.2. After AUDIT.md lands, stop. User reads verdicts and explicitly approves which REAL/PARTIAL Wave-A rows become HARDEN-A-NN REQs. Auto-promote is rejected — some REAL findings may be real-but-not-worth-fixing (e.g., claims already mitigated by existing checks).

### Claude's Discretion
- Plan file layout (`PLAN-1-AUDIT.md` + `PLAN-2-WAVE-A.md` vs single PLAN.md with two phases) — Claude decides during `/gsd-plan-phase 12`.
- Exact partition of the 15 claims across 3 Explore agents (5/5/5 split by claim number, or grouped by theme for better locality) — Claude decides at plan time.
- Whether Plan 12.2 further splits HARDEN-A-NN REQs across multiple sub-plans — Claude decides after gate, based on how many REQs pass approval.
- AUDIT.md table cell formatting (absolute vs repo-relative paths, line ranges vs single lines) — Claude decides; convention is repo-relative path + `:line` or `:start-end`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Pass-3 Audit Source
- `~/.claude/projects/-Users-sergeiarutiunian-Projects-claude-code-toolkit/memory/project_next_session_audit.md` §"ChatGPT Audit — Pass 3 (corrected for template-repo semantics)" — the 15 claims to verify. Section includes: retracted pass-1/2 findings, 15 template-level risks, HIGH/MEDIUM ranking, predicted bug list, verification plan notes.

### Project Roadmap + Requirements
- `.planning/ROADMAP.md` §"Phase 12: Audit Verification + Template Hardening" — phase entry point, goal currently TBD, to be filled after this CONTEXT.md lands.
- `.planning/REQUIREMENTS.md` — where AUDIT-01..15 + HARDEN-A-NN rows get added to the traceability table.
- `.planning/STATE.md` §"Roadmap Evolution" 2026-04-24 entry — originating note for this phase.

### Install/Update Script Code (verification targets)
- `scripts/init-claude.sh` — remote installer with framework autodetect (~line 289-294 fallback chain).
- `scripts/init-local.sh` — local installer with same fallback (~line 105-116).
- `scripts/update-claude.sh` — manifest-driven updater, backup at ~line 85-87, manifest parse at ~line 67-74.
- `scripts/migrate-to-complement.sh` — 3-way diff migration.
- `scripts/detect.sh` — base-plugin detection (primary filesystem).
- `manifest.json` — file inventory, `conflicts_with` arrays, sp_equivalent mapping.
- `Makefile` — existing quality gates: `check`, `validate-base-plugins`, `version-align`, `translation-drift`, `agent-collision-static`.

### Existing Validation Infra
- `scripts/validate-manifest.py` — manifest validation script (already exists — relevant to AUDIT-01 plugin manifest schema claim).
- `scripts/tests/test-*.sh` — existing integration tests (dry-run, detect, matrix, migrate-diff, update-diff, etc.) — baseline for "what's already tested vs claimed missing".
- `.github/workflows/quality.yml` — CI gates: shellcheck, markdownlint, template validation (`QUICK CHECK` + `SELF-CHECK` markers), install-matrix smoke test.

### Prior Phase Contexts (for pattern continuity)
- `.planning/milestones/v4.0-phases/*/XX-CONTEXT.md` — v4.0 phase contexts, especially Phase 7 (validation) for audit/verification patterns and Phase 2 (foundation) for manifest handling.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`scripts/validate-manifest.py`** — already validates manifest.json structure. AUDIT-01 (plugin manifest schema) verification should start here: does this script cover what pass-3 calls "plugin.schema.json"? If yes, AUDIT-01 is FALSE or PARTIAL.
- **`make check` targets** — `validate-base-plugins`, `version-align`, `translation-drift`, `agent-collision-static` already exist. Several pass-3 claims (namespace collision, version pinning, compat) may already be mitigated here.
- **`scripts/tests/test-dry-run.sh`** — dry-run test harness already exists. AUDIT-08 (no dry-run installer mode) is likely FALSE or PARTIAL; verification must confirm which install scripts actually support `--dry-run`.
- **`scripts/detect.sh`** — framework autodetection lives here. AUDIT-03 (stack autodetection fragile) verification reads this script and grades its confidence mechanism.
- **Framework → base fallback chain** (`init-claude.sh:289-294`, `init-local.sh:105-116`) — already implements per-file override. AUDIT-05 (relative path fragility) and AUDIT-10 (collision detection) partly mitigated here.
- **Backup-before-update** (`update-claude.sh:85-87`) — already creates timestamped backups. Relevant to any "reversibility" claim in pass-3.
- **Idempotent creation** — lessons-learned, project-context, skill-rules, current-task, CLAUDE.md only written if missing. Relevant to AUDIT-10 collision detection and AUDIT-13 uninstall semantics.

### Established Patterns
- **Manifest-driven distribution** — `manifest.json` is single source of truth for file inventory and update logic. Any new schema/validation work in Wave A extends this rather than inventing a parallel registry.
- **CI greps for markers** — template validation works by grepping `QUICK CHECK` / `SELF-CHECK` / `ФОРМАТ ОТЧЁТА` headings. AUDIT-12 (markdown commands as templates without linting) verification compares this against pass-3's "required sections / frontmatter / step markers not enforced" claim — likely PARTIAL.
- **`curl | bash` distribution** — all installer scripts use `set -euo pipefail`, POSIX-compatible Bash 3.2+, no Node/Python runtime for install. Wave A implementations must not violate this invariant.
- **Conventional Commits + branches** — `feature/audit-verify`, `feature/harden-a-manifest-schema`, etc. Never push to main.

### Integration Points
- **REQUIREMENTS.md traceability table** — where AUDIT-01..15 + HARDEN-A-NN rows land. Existing v4.1 rows stop at UX-01.
- **ROADMAP.md Phase 12 block** — currently `Goal: [To be planned]`. Plan 12.1 updates this with the real goal + success criteria derived from this CONTEXT.md.
- **Makefile `check` target** — if Wave A adds a new validation (e.g., `schema-check`), it hooks into `check: lint validate validate-base-plugins version-align translation-drift agent-collision-static` as an additional target.
- **`.github/workflows/quality.yml`** — any new quality gate in Wave A gets wired here as well, mirroring the `make check` addition.

### Creative Options
- If `validate-manifest.py` already covers pass-3's "plugin.schema.json" claim, AUDIT-01 can produce a FALSE verdict with minimal fix work — optionally promoting to "document this script's coverage in CONTRIBUTING.md" as a HARDEN-A sub-item.
- Wave A implementations may largely be *tests that codify existing behavior* rather than new features — a "prove what's already there" posture. Evidence-first planning means tests come before code changes.

</code_context>

<specifics>
## Specific Ideas

- User explicitly wants the user-review gate between AUDIT.md and Wave A. Rationale: some REAL findings may be "real-but-we-don't-care" — e.g., a real gap that's worth noting but not worth a v4.1 fix. Auto-promotion would force spurious fix work.
- User wants FALSE verdicts preserved as REQ rows so a future auditor re-running the same ChatGPT audit sees the verdict without re-investigating. "Full pass-3 paper trail in REQUIREMENTS" is the exact phrasing that won over "only REAL/PARTIAL as REQ-IDs".
- Global CLAUDE.md subagent routing applies: Explore agents for deterministic grep/glob = Haiku tier. If a claim requires cross-file reasoning, that specific claim escalates to Sonnet.
- ChatGPT's pass-3 audit was already self-corrected after user told it "this is a template-distribution repo, not runtime-engine". Pass-1 and pass-2 runtime findings are retracted (confirmed FALSE) and do NOT enter AUDIT-01..15. Only pass-3's 15 template-level claims are verified.

</specifics>

<deferred>
## Deferred Ideas

- **Wave B implementation** (install safety — namespace collision, stack autodetection, relative path fragility, collision detection, merge-strategy) — deferred to v4.2+ as its own phase after v4.1 ships.
- **Wave C implementation** (provenance/metadata — compat matrix, template version pinning, `installed_templates.json`, dependency graph, uninstall semantics) — deferred to v4.2+ as its own phase.
- **Pass-4 audit from another AI** — not in scope. If the user wants Gemini or Claude-opus to run a similar pass, that's its own phase in v4.2+.
- **Retroactive runtime-audit verification** — pass-1 and pass-2 claims were already retracted. Not re-verifying those in Phase 12.
- **Issue filing for FALSE verdicts upstream** — if a FALSE verdict reveals ChatGPT hallucinated a path, that's not a toolkit fix and not an upstream issue. No action; stays recorded in AUDIT.md.

</deferred>

---

*Phase: 12-audit-verification-template-hardening*
*Context gathered: 2026-04-24*
