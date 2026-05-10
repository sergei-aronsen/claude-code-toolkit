# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- ✅ **v4.1 Polish & Upstream** — Phases 8–12 (shipped 2026-04-25). See `.planning/milestones/v4.1-ROADMAP.md`.
- ✅ **v4.2 Audit System v2** — Phases 13–17 (shipped 2026-04-26). See `.planning/milestones/v4.2-ROADMAP.md`.
- ✅ **v4.3 Uninstall** — Phases 18–20 (shipped 2026-04-26). See `.planning/milestones/v4.3-ROADMAP.md`.
- ✅ **v4.4 Bootstrap & Polish** — Phases 21–23 (shipped 2026-04-27). See `.planning/milestones/v4.4-ROADMAP.md`.
- ✅ **v4.6 Install Flow UX & Desktop Reach** — Phases 24–27 (shipped 2026-04-29). See `.planning/milestones/v4.6-ROADMAP.md`.
- ✅ **v4.8 Multi-CLI Bridge** — Phases 28–31 (shipped 2026-04-29). See `.planning/milestones/v4.8-ROADMAP.md`.
- ✅ **v4.9 Integrations Catalog** — Phases 32–35 (shipped 2026-05-02).
- ✅ **v5.0 Per-MCP Scope + Project Secrets Boundary** — Phases 36–41 (shipped 2026-05-06). See `.planning/milestones/v5.0-ROADMAP.md`.
- ✅ **v6.0 Toolkit Overlay Redesign** — shipped 2026-05-06 (PRs #41–47).
- ✅ **v6.1 Morph→Serena swap + audit closures** — shipped 2026-05-06 (PRs #49–53).
- ✅ **v6.3 Solo-founder gaps closed** — product-thinking gate + vendor changelog + auto-format hook (shipped 2026-05-07, PR #60).
- ✅ **v6.4 Project-scope MCP storage redesign** — global slot per project (shipped 2026-05-07, PR #66).
- ✅ **v6.11 CODE_REVIEW regression rewrite** — shipped 2026-05-08 (PR #77).
- ✅ **v6.12 SECURITY_AUDIT adversarial rewrite** — shipped 2026-05-08 (PR #78).
- ✅ **v6.12.1 Meta-audit cleanup** — severity rubric, naming parity, raw-HTML specificity (shipped 2026-05-09, PR #79).
- ✅ **v6.13.0 F-006 propagator demote + 5-prompt meta-audit** — shipped 2026-05-09 (PR #81).
- ✅ **v6.14.0 Base-prompt meta-audit wave 1** — F-101/F-104/F-107/F-111 (shipped 2026-05-10, PR #82). Hotfix PR #83 deleted phantom release-pin workflow.
- ✅ **v6.14.1 Meta-audit wave-2 surgical findings** — 4 of 139 (shipped 2026-05-10, PR #84).
- ✅ **v6.14.2 Meta-audit wave-2 calibration findings** — 8 of 135 (shipped 2026-05-10, PR #86).
- ✅ **v6.14.3 Meta-audit wave-2 calibration findings** — 7 of ~117 (shipped 2026-05-10, PR #87).
- ✅ **v6.16.0 Install MCP scope picker** — lock-screen after sub-picker + Back removal + catalog patch (comet-bridge → user, datadog → project, posthog → project) (shipped 2026-05-10, PR #92).
- ✅ **v6.17.0 DEPLOY_CHECKLIST runbook + DESIGN_REVIEW Phase 7 dissolution** — Council-validated base-prompt reworks (20 wave-2 findings: F-290..F-306 + F-321/F-326/F-329); originally tracked as v6.15.0/v6.15.1 in stacked PRs #88/#89 against pre-v6.16.0 main, consolidated post-v6.16.0 (shipped 2026-05-10).

## Active Milestone

**v6.17.1 — Audit-rubric SOTs + 30-file framework re-splice** (in progress).

Three canonical SOT components for audit rubrics (Phase 3 stage 1) + rubric-anchors splice sentinel + 30-file re-splice (Phase 3 stage 2). Originally stacked as PRs #90/#91 (v6.15.2/v6.15.3) against pre-v6.16.0 main; bundled into v6.17.1 after v6.17.0 ships.

Pending scope:

- Per-audit severity rubrics
- Per-audit SELF-CHECK variants
- DEPLOY_CHECKLIST rework
- DESIGN_REVIEW identity split
- Coverage extensions
- F-003 carry-over (Category enum scope)

## Backlog

### High priority

- **v6.15.x — KNOWN-DEBT-1 framework prompt drift sweep**: 28 files in `templates/{laravel,rails,python,go}/prompts/*.md` carry substantially older content than `templates/base/prompts/*.md`. Pick (a) regen from base + framework-specific delta, or (b) extend splice pipeline to base→framework sentinel sync.

### Medium priority

- **Phase B (Pocock doctrine)** — CONTEXT.md/ubiquitous-language doctrine + `/zoom-out` + `/audit-depth` Ousterhout deep-modules audit (~700 LOC md, 1-2 days). Triaged from INBOX 2026-05-06. Run B.1 → B.2 → B.3, atomic commits, one `/council` validation pass on B.1 doctrine.
- **Auto-update orchestrator** — `scripts/update-skills-mcps.sh` fans out plugin/skill/MCP updates. Triaged from INBOX 2026-04-29.
- **Skill catalog: huashu-design** — add `alchaincyf/huashu-design` to skills selector catalog. Triaged from INBOX 2026-04-29 (Phase 26 shipped 2026-04-29 — slot directly into existing catalog now).

### Low priority / optional

- **Phase C (Warp picks)** — `/diagnose-ci` 7-step CI-failure loop + `components/feature-flag-lifecycle.md` (~300 LOC md, ~1 day). Triaged from INBOX 2026-05-06. Drop if budget tight; C.1 high-value only on CI-heavy projects.

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
<summary>✅ v4.2 Audit System v2 (Phases 13–17) — SHIPPED 2026-04-26</summary>

- [x] Phase 13: Foundation — FP Allowlist + Skip/Restore Commands (5/5 plans) — completed 2026-04-25
- [x] Phase 14: Audit Pipeline — FP Recheck + Structured Reports (4/4 plans) — completed 2026-04-25
- [x] Phase 15: Council Audit-Review Integration (6/6 plans) — completed 2026-04-25
- [x] Phase 16: Template Propagation — 49 Prompt Files (4/4 plans) — completed 2026-04-25
- [x] Phase 17: Distribution — Manifest, Installers, CHANGELOG (3/3 plans) — completed 2026-04-26

</details>

<details>
<summary>✅ v4.3 Uninstall (Phases 18–20) — SHIPPED 2026-04-26</summary>

- [x] Phase 18: Core Uninstall — Script + Dry-Run + Backup (4/4 plans) — completed 2026-04-26
- [x] Phase 19: State Cleanup + Idempotency (3/3 plans) — completed 2026-04-26
- [x] Phase 20: Distribution + Tests (3/3 plans) — completed 2026-04-26

</details>

<details>
<summary>✅ v4.4 Bootstrap & Polish (Phases 21–23) — SHIPPED 2026-04-27</summary>

- [x] Phase 21: SP/GSD Bootstrap Installer (3/3 plans) — completed 2026-04-27
- [x] Phase 22: Smart-Update Coverage for `scripts/lib/*.sh` (2/2 plans) — completed 2026-04-27
- [x] Phase 23: Installer Symmetry & Recovery (3/3 plans) — completed 2026-04-27

</details>

<details>
<summary>✅ v4.6 Install Flow UX & Desktop Reach (Phases 24–27) — SHIPPED 2026-04-29</summary>

- [x] Phase 24: Unified TUI Installer + Centralized Detection (5/5 plans) — completed 2026-04-29
- [x] Phase 25: MCP Selector (4/4 plans) — completed 2026-04-29
- [x] Phase 26: Skills Selector (4/4 plans) — completed 2026-04-29
- [x] Phase 27: Marketplace Publishing + Claude Desktop Reach (4/4 plans) — completed 2026-04-29

</details>

<details>
<summary>✅ v4.8 Multi-CLI Bridge (Phases 28–31) — SHIPPED 2026-04-29</summary>

- [x] Phase 28: Bridge Foundation (3/3 plans) — completed 2026-04-29
- [x] Phase 29: Sync & Uninstall Integration (3/3 plans) — completed 2026-04-29
- [x] Phase 30: Install-time UX (3/3 plans) — completed 2026-04-29
- [x] Phase 31: Distribution + Tests + Docs (3/3 plans) — completed 2026-04-29

</details>

<details>
<summary>✅ v4.9 Integrations Catalog (Phases 32–35) — SHIPPED 2026-05-02</summary>

- [x] Phase 32: Foundation — Schema Migration + CLI Installer Library (3/3 plans) — completed 2026-05-02
- [x] Phase 33: Catalog Population — 11 New Entries + Drop + Re-categorize (4/4 plans) — completed 2026-05-02
- [x] Phase 34: TUI Redesign — Categories, Status, Unofficial Confirm, Component Flags (3/3 plans) — completed 2026-05-02
- [x] Phase 35: Distribution + Tests + Docs (4/4 plans) — completed 2026-05-02

</details>

---

## Historical Progress

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v4.0 Complement Mode | 1–7 + 6.1 | 29/29 | ✅ Shipped | 2026-04-21 |
| v4.1 Polish & Upstream | 8–12 | 13/13 | ✅ Shipped | 2026-04-25 |
| v4.2 Audit System v2 | 13–17 | 22/22 | ✅ Shipped | 2026-04-26 |
| v4.3 Uninstall | 18–20 | 10/10 | ✅ Shipped | 2026-04-26 |
| v4.4 Bootstrap & Polish | 21–23 | 8/8 | ✅ Shipped | 2026-04-27 |
| v4.6 Install Flow UX & Desktop Reach | 24–27 | 17/17 | ✅ Shipped | 2026-04-29 |
| v4.8 Multi-CLI Bridge | 28–31 | 12/12 | ✅ Shipped | 2026-04-29 |
| v4.9 Integrations Catalog | 32–35 | 14/14 | ✅ Shipped | 2026-05-02 |
| v5.0 Per-MCP Scope + Project Secrets Boundary | 36–41 | 16/16 | ✅ Shipped | 2026-05-06 |
| v6.0 Toolkit Overlay Redesign | — | — | ✅ Shipped | 2026-05-06 |
| v6.1 Morph→Serena swap | — | — | ✅ Shipped | 2026-05-06 |
| v6.3 Solo-founder gaps | — | — | ✅ Shipped | 2026-05-07 |
| v6.4 MCP storage redesign | — | — | ✅ Shipped | 2026-05-07 |
| v6.11 CODE_REVIEW rewrite | — | — | ✅ Shipped | 2026-05-08 |
| v6.12 SECURITY_AUDIT rewrite | — | — | ✅ Shipped | 2026-05-08 |
| v6.12.1 Meta-audit cleanup | — | — | ✅ Shipped | 2026-05-09 |
| v6.13.0 Propagator demote + 5-prompt audit | — | — | ✅ Shipped | 2026-05-09 |
| v6.14.0 Meta-audit wave 1 | — | 4/4 findings | ✅ Shipped | 2026-05-10 |
| v6.14.1 Wave-2 surgical | — | 4/139 findings | ✅ Shipped | 2026-05-10 |
| v6.14.2 Wave-2 calibration | — | 8/135 findings | ✅ Shipped | 2026-05-10 |
| v6.14.3 Wave-2 calibration | — | 7/~117 findings | ✅ Shipped | 2026-05-10 |
| v6.16.0 Install MCP scope picker | — | — | ✅ Shipped | 2026-05-10 |
| v6.17.0 DEPLOY+DESIGN reworks | — | 20 findings | ✅ Shipped | 2026-05-10 |
| v6.17.1 Rubric SOTs + 30-file re-splice | — | — | 🔄 In progress | — |
| v6.15.x Framework drift sweep | — | 0/28 files | 📋 Backlog | — |
