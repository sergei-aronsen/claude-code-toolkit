# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- 🚧 **v4.1 Polish & Upstream** — Phases 8–11 (in progress, started 2026-04-21).

## Overview (v4.1)

v4.1 hardens the v4.0 release cycle. No new install modes, no breaking changes. Four phases:
port release matrix to bats + add cell-parity check, ship backup hygiene and detection enhancements,
file the three upstream GSD CLI issues discovered in v4.0, and polish `--dry-run` output to
chezmoi-grade.

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

Full phase detail archived at `.planning/milestones/v4.0-ROADMAP.md`.

</details>

### 🚧 v4.1 Polish & Upstream (In Progress)

**Phase Numbering:** continuing from v4.0 (last used: 7). Next: 8.

- [x] **Phase 8: Release Quality** - Port install matrix to bats, add cell-parity check, ship `--collect-all` fail mode (completed 2026-04-24)
- [ ] **Phase 9: Backup & Detection** - `--clean-backups` flag, threshold warnings, `claude plugin list` integration, version-skew detection
- [ ] **Phase 10: Upstream GSD Issues** - File 3 issues in `gsd-build/get-shit-done` (no toolkit code changes)
- [ ] **Phase 11: UX Polish** - chezmoi-grade styled `--dry-run` diff output across install/update/migrate

## Phase Details

### Phase 8: Release Quality

**Goal**: Release validation infrastructure becomes bats-based, cross-referenced across docs + runner + checklist, and supports `--collect-all` aggregation for multi-cell failures
**Depends on**: Nothing (v4.1 first phase)
**Requirements**: REL-01, REL-02, REL-03
**Success Criteria** (what must be TRUE):

1. `scripts/tests/matrix/*.bats` replicates all 13 install-matrix cells from `validate-release.sh` with 63 assertions preserved; `make test-matrix-bats` exits 0
2. `make check` gains `cell-parity` target asserting every `--cell <name>` in `docs/INSTALL.md` appears in both `validate-release.sh --list` and as a section heading in `docs/RELEASE-CHECKLIST.md`
3. `scripts/validate-release.sh --collect-all` runs all 13 cells regardless of failures and emits a final aggregated table; default fail-fast behavior unchanged without the flag
4. Bash `validate-release.sh` remains functional during transition; no regression in existing 63 assertions

**Plans:** 3/3 plans complete

Plans:
- [x] 08-01-PLAN.md — REL-01: port 13-cell matrix to bats, extract helpers.bash, add make test-matrix-bats + CI job
- [x] 08-02-PLAN.md — REL-02: add scripts/cell-parity.sh + make cell-parity target; fix docs/INSTALL.md 12→13 cells drift and add 13 --cell commands
- [x] 08-03-PLAN.md — REL-03: add --collect-all flag to validate-release.sh with aggregated ASCII table, --all mutex guard

### Phase 9: Backup & Detection

**Goal**: Users have tooling to manage accumulated backup dirs and get early warnings about plugin version skew; detection cross-checks filesystem against `claude plugin list` CLI
**Depends on**: Phase 8
**Requirements**: BACKUP-01, BACKUP-02, DETECT-06, DETECT-07
**Success Criteria** (what must be TRUE):

1. `scripts/update-claude.sh --clean-backups` lists every `~/.claude-backup-*` and `~/.claude-backup-pre-migrate-*` dir (real on-disk patterns) with size + age, prompts `[y/N]` per dir, supports `--keep N` to preserve N most recent
2. Every script creating a new backup dir checks backup count and prints a warning (non-fatal) when count > 10, pointing users to `--clean-backups`
3. `scripts/detect.sh` parses `claude plugin list` JSON when available; if filesystem says SP is present but CLI says disabled, CLI overrides; filesystem remains primary when CLI absent
4. `scripts/update-claude.sh` detects SP/GSD version change between install state and current, emits one-line warning with before/after versions

**Plans:** 4 plans (waves 1–2)

Plans:
- [ ] 09-01-PLAN.md — BACKUP-01: --clean-backups flag on update-claude.sh + scripts/lib/backup.sh foundation + REQUIREMENTS.md phantom-path fix (wave 1)
- [ ] 09-02-PLAN.md — BACKUP-02: threshold warning wired into update-claude.sh + migrate-to-complement.sh via warn_if_too_many_backups (wave 2, depends on 09-01)
- [ ] 09-03-PLAN.md — DETECT-06: `claude plugin list --json` CLI cross-check as step 4 in detect_superpowers() (wave 1)
- [ ] 09-04-PLAN.md — DETECT-07: warn_version_skew() helper + wiring in update-claude.sh between STATE_MANIFEST_HASH extraction and migrate hint (wave 2, depends on 09-03)

### Phase 10: Upstream GSD Issues

**Goal**: Three v4.0-discovered bugs in `gsd-build/get-shit-done` are filed as well-formed upstream issues with repro, stack trace, and suggested fix — not patched in this repo
**Depends on**: Phase 9
**Requirements**: UPSTREAM-01, UPSTREAM-02, UPSTREAM-03
**Success Criteria** (what must be TRUE):

1. GitHub issue filed in `gsd-build/get-shit-done` for `audit-open` ReferenceError with minimum repro + stack trace + suggested fix (missing `output` helper import)
2. GitHub issue filed for `milestone complete` accomplishment-extraction grabbing YAML/frontmatter noise instead of one-liner prose, with v4.0 MILESTONES.md artifact as repro
3. GitHub issue filed for missing auto-sync of ROADMAP.md plan checkboxes on plan completion, with repro via `gsd-execute-phase` + observed manual `update-plan-progress` workaround
4. This repo carries zero code changes for UPSTREAM-01/02/03 — only `.planning/` notes documenting issue URLs for cross-reference

### Phase 11: UX Polish

**Goal**: Every `--dry-run` output (install, update, migrate) produces chezmoi-grade styled diff — colored +/-/~ markers, grouped by action with counts, right-aligned
**Depends on**: Phase 10
**Requirements**: UX-01
**Success Criteria** (what must be TRUE):

1. `scripts/init-claude.sh --dry-run` shows colored `[+ INSTALL]` / `[- SKIP]` grouped output with total-per-group count right-aligned
2. `scripts/update-claude.sh --dry-run` shows the same color-coded grouped style for INSTALL / UPDATE / SKIP / REMOVE groups
3. `scripts/migrate-to-complement.sh --dry-run` uses the same styling for per-file action previews
4. Color output respects `NO_COLOR=1` env var and non-TTY detection (plain output when stdout is not a terminal)

## Progress

**Execution Order:**
Phases execute in numeric order: 8 → 9 → 10 → 11

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 8. Release Quality | v4.1 | 3/3 | Complete    | 2026-04-24 |
| 9. Backup & Detection | v4.1 | 0/4 | Not started | - |
| 10. Upstream GSD Issues | v4.1 | 0/? | Not started | - |
| 11. UX Polish | v4.1 | 0/? | Not started | - |
| 12. Audit Verification + Template Hardening | v4.1 | 2/2 | Complete   | 2026-04-24 |

### Phase 12: Audit Verification + Template Hardening

**Goal**: Verify all 15 ChatGPT pass-3 template-level audit claims against
actual code; implement Wave A (schema/validation) REAL findings approved
at user gate; create full AUDIT-NN + HARDEN-A-NN REQ traceability
**Depends on**: Phase 11
**Requirements**: AUDIT-01..AUDIT-15, HARDEN-A-01..HARDEN-A-NN (NN TBD after gate)
**Success Criteria** (what must be TRUE):

1. `12-AUDIT.md` exists with 15-row verdict table; every row has Status
   + Evidence (file:line or "not found") + Action; no row is blank or
   prose-only
2. REQUIREMENTS.md carries AUDIT-01..AUDIT-15 rows with correct statuses;
   FALSE rows are closed; REAL/PARTIAL rows have HARDEN wave assignment
3. HARDEN-A-NN REQs (user-approved subset) are implemented and wired into
   `make check`; CI passes
4. Wave B and Wave C REQs are defined in AUDIT.md but NOT entered in
   REQUIREMENTS.md until promoted in v4.2+

**Plans:** 2/2 plans complete

Plans:
- [x] 12-01-PLAN.md — AUDIT: verify 15 claims, produce verdict table, propose HARDEN-A-NN
- [x] 12-02-PLAN.md — WAVE-A: implement user-approved HARDEN-A-NN REQs (gated on 12-01 approval)
