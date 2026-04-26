# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- ✅ **v4.1 Polish & Upstream** — Phases 8–12 (shipped 2026-04-25). See `.planning/milestones/v4.1-ROADMAP.md`.
- ✅ **v4.2 Audit System v2** — Phases 13–17 (shipped 2026-04-26). See `.planning/milestones/v4.2-ROADMAP.md`.
- 🟢 **v4.3 Uninstall** — Phases 18–20 (started 2026-04-26).

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
<summary>✅ v4.2 Audit System v2 (Phases 13–17) — SHIPPED 2026-04-26</summary>

- [x] Phase 13: Foundation — FP Allowlist + Skip/Restore Commands (5/5 plans) — completed 2026-04-25
- [x] Phase 14: Audit Pipeline — FP Recheck + Structured Reports (4/4 plans) — completed 2026-04-25
- [x] Phase 15: Council Audit-Review Integration (6/6 plans) — completed 2026-04-25
- [x] Phase 16: Template Propagation — 49 Prompt Files (4/4 plans) — completed 2026-04-25
- [x] Phase 17: Distribution — Manifest, Installers, CHANGELOG (3/3 plans) — completed 2026-04-26

</details>

### 🟢 v4.3 Uninstall (Phases 18–20) — IN PROGRESS

- [ ] **Phase 18: Core Uninstall — Script + Dry-Run + Backup** — `scripts/uninstall.sh` reads `~/.claude/toolkit-install.json` and removes registered files with `--dry-run` preview, `[y/N/d]` user-modification prompt, and full `.claude/` backup
- [ ] **Phase 19: State Cleanup + Idempotency** — Strip toolkit-owned `~/.claude/CLAUDE.md` sections, delete `toolkit-install.json` after success, double-invocation is a no-op
- [ ] **Phase 20: Distribution + Tests** — `manifest.json` registration, installer post-install banner, `CHANGELOG.md [4.3.0]`, Test 21 fresh→install→uninstall→fresh assertion

## Phase Details

### Phase 18: Core Uninstall — Script + Dry-Run + Backup

**Goal**: Toolkit users can run a single command to safely remove every toolkit-installed file from their project's `.claude/` while preserving user modifications and base plugins.
**Depends on**: Nothing (entry phase for v4.3)
**Requirements**: UN-01, UN-02, UN-03, UN-04
**Success Criteria** (what must be TRUE):

1. `bash scripts/uninstall.sh` reads `~/.claude/toolkit-install.json`, computes SHA256 for every file in `installed_files[]`, and removes only those whose hash matches the recorded value (untouched-since-install). Files outside the project's `.claude/` directory and files inside `~/.claude/plugins/cache/claude-plugins-official/superpowers/` or `~/.claude/get-shit-done/` are never deleted.
2. `bash scripts/uninstall.sh --dry-run` prints a 4-group preview (`[- REMOVE]` / `[~ KEEP]` / `[? MODIFIED]` / `[? MISSING]`) using the existing `scripts/lib/dry-run-output.sh` API (which uses single-char markers per `dro_print_header`), exits 0, and produces zero filesystem changes (verified by `git status` + `find ~/.claude-backup-pre-uninstall-* | wc -l = 0`).
3. When a registered file's current SHA256 differs from the manifest, the script reads `[y/N/d]` from `< /dev/tty` (default `N` = keep). `d` shows `diff` against the manifest reference (or notes "reference unavailable") and re-prompts. The prompt loop is re-entrant for every modified file.
4. Before any delete operation, the script writes a full copy of the project's `.claude/` directory to `~/.claude-backup-pre-uninstall-<unix-ts>/` using the same backup convention as `update-claude.sh`. The backup directory is created via `cp -R` and includes the toolkit-install.json snapshot at the time of backup.
5. The script is shellcheck-clean (severity warning), works under `bash <(curl -sSL ...)`, and follows project conventions: `set -euo pipefail`, color codes via `RED`/`GREEN`/`YELLOW`/`BLUE`/`NC`, `${NO_COLOR+x}` + `[ -t 1 ]` gates.

**Plans**: 4 plans

- [x] 18-01-PLAN.md — Script skeleton: argparse, state load, SHA256 classification, base-plugin exclusion (UN-01)
- [x] 18-02-PLAN.md — `--dry-run` 4-group preview using dro_* primitives, zero-mutation contract (UN-02)
- [ ] 18-03-PLAN.md — Backup-before-delete to `~/.claude-backup-pre-uninstall-<ts>/` + REMOVE_LIST hash-match delete loop (UN-04, UN-01)
- [ ] 18-04-PLAN.md — Per-MODIFIED-file [y/N/d] prompt via /dev/tty with re-entrant d-branch diff (UN-03)

### Phase 19: State Cleanup + Idempotency

**Goal**: After a successful uninstall the system reports "toolkit not installed" and a second invocation is a clean no-op.
**Depends on**: Phase 18 (delete logic must exist before state cleanup runs)
**Requirements**: UN-05, UN-06
**Success Criteria** (what must be TRUE):

1. After all registered files are processed (kept or removed per user choice), the script deletes `~/.claude/toolkit-install.json` and strips any `<!-- TOOLKIT-START -->` … `<!-- TOOLKIT-END -->` block from `~/.claude/CLAUDE.md` if present. User-authored sections of `~/.claude/CLAUDE.md` are preserved verbatim (compared via `diff` with sentinel block masked out).
2. Base plugins (`superpowers`, `get-shit-done`) are never touched: `find ~/.claude/plugins/cache/claude-plugins-official/superpowers -type f` and `find ~/.claude/get-shit-done -type f` produce identical inventories before and after the uninstall (line-count + SHA256 manifest match).
3. Running `bash scripts/uninstall.sh` a second time on an already-uninstalled project: detects missing `~/.claude/toolkit-install.json`, prints `✓ Toolkit not installed; nothing to do`, exits 0, creates no backup directory (no `~/.claude-backup-pre-uninstall-*` parallel created on no-op runs), and produces zero filesystem changes.
4. Partial-uninstall recovery: if the user answers `N` (keep) on every modified file, the script preserves all kept files and still deletes `toolkit-install.json` only when the user explicitly chooses `--keep-state` (TBD whether this is in scope or strictly v4.4).

**Plans**: TBD

### Phase 20: Distribution + Tests

**Goal**: New script reaches end users via manifest + installer banners + `CHANGELOG.md [4.3.0]`, and CI proves the round-trip works across all 4 install modes.
**Depends on**: Phase 18 + Phase 19 (script must work before distribution)
**Requirements**: UN-07, UN-08
**Success Criteria** (what must be TRUE):

1. `manifest.json` registers `scripts/uninstall.sh` under `files.scripts[]`; `version` is `4.3.0` and `updated:` carries the release date. `make check` `version-align` gate passes.
2. `init-claude.sh`, `init-local.sh`, and `update-claude.sh` end-of-run banners include exactly one new line: `To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)`. Banners do not regress existing post-install messages — `scripts/tests/test-install-banner.sh` (or equivalent) gates the full banner string.
3. `CHANGELOG.md` `[4.3.0]` entry covers UN-01..UN-08 with the ship date set when the milestone closes (placeholder `YYYY-MM-DD` until then).
4. `scripts/tests/test-uninstall.sh` + Makefile `Test 21` execute in a `/tmp/` sandbox: fresh install → uninstall → final state matches a clean checkout (`find .claude -type f | wc -l = 0` for unmodified install). Modified-file scenarios cover `y` / `N` / `d` choices. Base-plugin inventory unchanged. `--dry-run` produces zero changes. Double-uninstall exits 0 with no-op message. CI runs the test in `.github/workflows/quality.yml`.

**Plans**: TBD

## Progress

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v4.0 Complement Mode | 1–7 + 6.1 | 29/29 | ✅ Shipped | 2026-04-21 |
| v4.1 Polish & Upstream | 8–12 | 13/13 | ✅ Shipped | 2026-04-25 |
| v4.2 Audit System v2 | 13–17 | 22/22 | ✅ Shipped | 2026-04-26 |
| v4.3 Uninstall | 18–20 | 0/TBD | 🟢 In progress | — |
