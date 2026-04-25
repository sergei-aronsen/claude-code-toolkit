# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- ✅ **v4.1 Polish & Upstream** — Phases 8–12 (shipped 2026-04-25). See `.planning/milestones/v4.1-ROADMAP.md`.
- 🟢 **v4.2 Audit System v2** — Phases 13–17 (started 2026-04-25).

## Phases

<details>
<summary>✅ v4.0 Complement Mode (Phases 1–7 + 6.1) — SHIPPED 2026-04-21</summary>

- [x] Phase 1: Pre-work Bug Fixes (7/7 plans) — completed 2026-04-21
- [x] Phase 2: Foundation (3/3 plans) — completed 2026-04-21
- [x] Phase 3: Install Flow (3/3 plans) — completed 2026-04-21
- [x] Phase 4: Update Flow (3/3 plans) — completed 2026-04-21
- [x] Phase 5: Migration (3/3 plans) — completed 2026-04-21
- [x] Phase 6: Documentation (3/3 plans) — completed 2026-04-19
- [x] Phase 6.1: README translations sync (3/3 plans, INSERTED) — completed 2026-04-21
- [x] Phase 7: Validation (4/4 plans) — completed 2026-04-21

</details>

<details>
<summary>✅ v4.1 Polish & Upstream (Phases 8–12) — SHIPPED 2026-04-25</summary>

- [x] Phase 8: Release Quality (3/3 plans) — completed 2026-04-24
- [x] Phase 9: Backup & Detection (4/4 plans) — completed 2026-04-24
- [x] Phase 10: Upstream GSD Issues (1/1 plan) — completed 2026-04-24
- [x] Phase 11: UX Polish (3/3 plans) — completed 2026-04-25
- [x] Phase 12: Audit Verification + Template Hardening (2/2 plans, INSERTED) — completed 2026-04-24

</details>

<details>
<summary>🟢 v4.2 Audit System v2 (Phases 13–17) — IN PROGRESS</summary>

- [x] **Phase 13: Foundation — FP Allowlist + Skip/Restore Commands** — Repo-local exception file + `/audit-skip` and `/audit-restore` commands wired through installers (completed 2026-04-25)
- [x] **Phase 14: Audit Pipeline — FP Recheck + Structured Reports** — `/audit` honors allowlist, runs 6-step FP recheck, emits parser-friendly reports with verbatim code (completed 2026-04-25)
- [ ] **Phase 15: Council Audit-Review Integration** — Mandatory Council pass with per-finding REAL/FALSE_POSITIVE verdicts (severity reclassification forbidden)
- [ ] **Phase 16: Template Propagation — 49 Prompt Files** — All 7 frameworks × 7 audit prompt files updated, CI gates assert markers
- [ ] **Phase 17: Distribution — Manifest, Installers, CHANGELOG** — `manifest.json` + installers + `CHANGELOG.md` aligned for v4.2.0 release

</details>

## Phase Details

### Phase 13: Foundation — FP Allowlist + Skip/Restore Commands

**Goal**: Users have a persistent, auto-loaded false-positive allowlist plus the commands to maintain it
**Depends on**: Nothing (entry phase for v4.2)
**Requirements**: EXC-01, EXC-02, EXC-03, EXC-04, EXC-05
**Success Criteria** (what must be TRUE):

1. User can run `/audit-skip <file:line> <rule> <reason>` and see a structured block (location, rule, reason, date, council status) appended to `.claude/rules/audit-exceptions.md`
2. User can run `/audit-restore <file:line> <rule>` and, after a `[y/N]` confirmation, see the matching entry removed from `audit-exceptions.md`
3. `/audit-skip` refuses to write when `<file:line>` is missing from `git ls-files` or beyond the file's line count, and refuses duplicates of `path:line + rule` (showing the existing record instead)
4. `audit-exceptions.md` ships with `globs: ["**/*"]` frontmatter so Claude auto-loads it in every session, schema-aligned with existing `.claude/rules/` files
5. Running `init-claude.sh`, `init-local.sh`, or `update-claude.sh` against a project that already has a user-modified `audit-exceptions.md` leaves the file untouched; only first-time installs seed the empty template

**Plans**: 5 plans

- [x] 13-01-PLAN.md — Seed file template (`templates/base/rules/audit-exceptions.md`, EXC-03)
- [x] 13-02-PLAN.md — `/audit-skip` command spec with validation (EXC-01, EXC-04)
- [x] 13-03-PLAN.md — `/audit-restore` command spec with `[y/N]` confirmation (EXC-02)
- [x] 13-04-PLAN.md — Installer wiring across init-claude.sh, init-local.sh, update-claude.sh (EXC-05)
- [x] 13-05-PLAN.md — Gap closure: comment-aware /audit-restore (CR-01 fix, EXC-02)

### Phase 14: Audit Pipeline — FP Recheck + Structured Reports

**Goal**: `/audit` produces FP-rechecked, parser-friendly reports the Council can reason from
**Depends on**: Phase 13 (allowlist file must exist before pipeline reads it)
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03, AUDIT-04, AUDIT-05
**Success Criteria** (what must be TRUE):

1. Running `/audit` on a project with a populated `audit-exceptions.md` shows a `Skipped (allowlist)` table listing every dropped finding by `path:line + rule`, and those findings do not appear in the main report
2. Every reported finding survives the 6-step FP recheck (read context, trace data flow, check execution context, cross-reference exceptions, apply platform-constraint rule, severity sanity check); findings dropped at this stage land in a `Skipped (FP recheck)` table with a one-line reason
3. Each reported finding includes a verbatim ±10 lines code block (with language fence) copied directly from the source file
4. Report is written to `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md` (directory auto-created), with a fixed section structure: Summary table → Findings → Skipped (allowlist) → Skipped (FP recheck) → Council verdict slot
5. Each finding entry contains all required fields: ID, severity, rule, location range, claim, verbatim code, data-flow narrative, "why it is real" reasoning, suggested fix

**Plans**: 4 plans

- [x] 14-01-PLAN.md — `components/audit-fp-recheck.md` SOT (6-step FP-recheck procedure) [AUDIT-02, AUDIT-03]
- [x] 14-02-PLAN.md — `components/audit-output-format.md` SOT (structured report schema) [AUDIT-04, AUDIT-05]
- [x] 14-03-PLAN.md — Rewrite `commands/audit.md` with 6-phase workflow contract [AUDIT-01..05]
- [x] 14-04-PLAN.md — Test fixture + `scripts/tests/test-audit-pipeline.sh` + Makefile Test 17 [AUDIT-01..05]

### Phase 15: Council Audit-Review Integration

**Goal**: Every audit terminates in a mandatory Council pass that confirms or rejects each finding using the embedded code
**Depends on**: Phase 14 (Council needs the structured report to reason from)
**Requirements**: COUNCIL-01, COUNCIL-02, COUNCIL-03, COUNCIL-04, COUNCIL-05, COUNCIL-06
**Success Criteria** (what must be TRUE):

1. `/audit` invokes `/council audit-review --report <path>` after writing the report, and the audit run is reported as incomplete until the Council pass returns (no `--no-council` flag exists in v4.2)
2. Council prompt explicitly forbids severity reclassification; severity disagreements appear only as comments and never change the auditor's CRITICAL/HIGH/MEDIUM/LOW label
3. Council output includes a per-finding verdict table with `REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT`, a confidence score in `[0.0, 1.0]`, and a one-line justification grounded in the embedded code block
4. Council output includes a "Missed findings" section listing real issues visible in the embedded code that the auditor did not report — each with location, rule, code excerpt, claim, and suggested severity (auditor accepts or rejects, never auto-merged)
5. When Council marks a finding `FALSE_POSITIVE`, `/audit` prints the verdict and prompts the user to invoke `/audit-skip` — the audit never auto-writes exceptions on the user's behalf
6. `scripts/council/brain.py` runs Gemini and ChatGPT in parallel for `audit-review` mode and flags per-finding disagreements (one REAL, one FALSE_POSITIVE) as `disputed` without auto-resolution

**Plans**: 6 plans

- [ ] 15-01-PLAN.md — Council audit-review prompt SOT (COUNCIL-02, COUNCIL-03, COUNCIL-04)
- [ ] 15-02-PLAN.md — Test fixtures: audit-report.md + 3 stub backends (COUNCIL-06)
- [ ] 15-03-PLAN.md — commands/audit.md Council Handoff UX text: FP nudge + disputed prompt (COUNCIL-01, COUNCIL-05)
- [ ] 15-04-PLAN.md — brain.py audit-review mode: argparse, parallel dispatch, in-place rewrite (COUNCIL-01, COUNCIL-02, COUNCIL-03, COUNCIL-04, COUNCIL-06)
- [ ] 15-05-PLAN.md — commands/council.md ## Modes section (COUNCIL-01)
- [ ] 15-06-PLAN.md — test-council-audit-review.sh + Makefile Test 19 (COUNCIL-02, COUNCIL-03, COUNCIL-05, COUNCIL-06)

### Phase 16: Template Propagation — 49 Prompt Files

**Goal**: Every framework's audit prompt set picks up the new pipeline + Council behavior consistently
**Depends on**: Phase 14 + Phase 15 (prompts must reference the structured format and Council handoff)
**Requirements**: TEMPLATE-01, TEMPLATE-02, TEMPLATE-03
**Success Criteria** (what must be TRUE):

1. All 49 prompt files (`templates/{base,laravel,rails,nextjs,nodejs,python,go}/prompts/{SECURITY_AUDIT,CODE_REVIEW,PERFORMANCE_AUDIT,MYSQL_PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,DEPLOY_CHECKLIST,DESIGN_REVIEW}.md`) carry the four required additions: top-of-file callout to `audit-exceptions.md`, 6-step FP-recheck SELF-CHECK section, structured OUTPUT FORMAT, and "Council handoff" footer
2. Existing prompt language is preserved — Russian sections stay Russian, English sections stay English; no translation drift introduced
3. `make validate` (and the matching CI job in `.github/workflows/quality.yml`) asserts every updated prompt contains the literal `Council handoff` marker plus all six numbered FP-recheck steps; missing markers fail the build

**Plans**: TBD

### Phase 17: Distribution — Manifest, Installers, CHANGELOG

**Goal**: New files reach end users via manifest, installers, and a complete `[4.2.0]` changelog entry
**Depends on**: Phase 13 + Phase 14 + Phase 15 + Phase 16 (all artifacts must exist before they can be distributed)
**Requirements**: DIST-01, DIST-02, DIST-03
**Success Criteria** (what must be TRUE):

1. `manifest.json` registers `templates/base/rules/audit-exceptions.md`, `commands/audit-skip.md`, and `commands/audit-restore.md`; `version` field is `4.2.0` and `updated:` field carries the release date
2. `commands/council.md` documents an `audit-review` mode (input format = path to structured audit report, expected Council prompt verbatim, output schema), and `commands/audit.md` documents the new 6-phase workflow (load context → quick check → deep analysis → FP recheck → structured report → Council pass)
3. `CHANGELOG.md` `[4.2.0]` entry covers all v4.2 features (FP allowlist, `/audit-skip`/`/audit-restore`, FP recheck pipeline, structured reports, mandatory Council audit-review, 49-file template propagation, manifest/installer wiring) with the ship date set when the milestone closes

**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1–7 + 6.1 | v4.0 | 29/29 | Complete | 2026-04-21 |
| 8. Release Quality | v4.1 | 3/3 | Complete | 2026-04-24 |
| 9. Backup & Detection | v4.1 | 4/4 | Complete | 2026-04-24 |
| 10. Upstream GSD Issues | v4.1 | 1/1 | Complete | 2026-04-24 |
| 11. UX Polish | v4.1 | 3/3 | Complete | 2026-04-25 |
| 12. Audit Verification + Template Hardening | v4.1 | 2/2 | Complete | 2026-04-24 |
| 13. Foundation — FP Allowlist + Skip/Restore | v4.2 | 5/5 | Complete    | 2026-04-25 |
| 14. Audit Pipeline — FP Recheck + Structured Reports | v4.2 | 4/4 | Complete    | 2026-04-25 |
| 15. Council Audit-Review Integration | v4.2 | 0/6 | Planned | - |
| 16. Template Propagation — 49 Prompt Files | v4.2 | 0/0 | Not started | - |
| 17. Distribution — Manifest, Installers, CHANGELOG | v4.2 | 0/0 | Not started | - |
