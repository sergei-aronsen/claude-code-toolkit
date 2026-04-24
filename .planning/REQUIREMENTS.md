# Requirements: claude-code-toolkit v4.1 — Polish & Upstream

**Defined:** 2026-04-21
**Core Value:** Harden the v4.0 release cycle with better automation, safer housekeeping, richer detection, and upstream contributions — no new user-facing install modes, no breaking changes.

## v1 Requirements

Requirements for the v4.1 release. Each maps to exactly one roadmap phase.

### Release Quality

Carry-overs from v4.0 deferred items. Make the release validation infrastructure more robust, cross-checked, and reusable.

- [ ] **REL-01**: Port all 13 install-matrix cells from `scripts/validate-release.sh` bash functions to bats test files under `scripts/tests/matrix/*.bats`, preserving the 63 assertions. `make test-matrix-bats` runs the suite. Bash version remains for backward compat during transition.
- [ ] **REL-02**: `make check` gains `cell-parity` target that greps every `--cell <name>` example from `docs/INSTALL.md` and cross-references against `scripts/validate-release.sh --list` and `docs/RELEASE-CHECKLIST.md` section headers. Fails if any cell name appears in ≤2 of 3 surfaces.
- [ ] **REL-03**: `scripts/validate-release.sh` accepts `--collect-all` flag. When set, all 13 cells run regardless of failures; final exit code reflects worst-case but the runner aggregates assertion failures into a final table. Default behavior unchanged (fail-fast).

### Backup Hygiene

Carry-overs BACKUP-01/02 from v4.0. Backup dirs accumulate under `~/.claude-backup-*` and `~/.claude/.toolkit-backup-*` — give users tooling to manage them.

- [ ] **BACKUP-01**: `scripts/update-claude.sh --clean-backups` scans `~/.claude/.toolkit-backup-*` dirs, prompts per dir with size + age, removes on `[y/N]` confirmation. Supports `--keep N` to preserve the N most recent.
- [ ] **BACKUP-02**: Any script that creates a new backup dir also checks total count under `~/.claude/.toolkit-backup-*/` and `~/.claude-backup-pre-migrate-*/`. If count exceeds 10, print a one-line warning pointing to `update-claude.sh --clean-backups`. Non-fatal.

### Detection Enhancements

DETECT-FUT-01/02 from v4.0. Filesystem detection remains primary; CLI becomes a cross-check input for stale-cache and version-skew cases.

- [ ] **DETECT-06**: `scripts/detect.sh` gains optional `CLAUDE_PLUGIN_LIST_CHECK` path. When `claude plugin list` CLI exists, parse its JSON output; if SP/GSD is filesystem-present but CLI reports disabled, override filesystem detection with the CLI truth. Filesystem remains primary when CLI absent or errors.
- [ ] **DETECT-07**: On `update-claude.sh` run, compare `SP_VERSION` / `GSD_VERSION` captured in `~/.claude/toolkit-install.json` at install time against current detection. If mismatch detected, emit `⚠ Base plugin version changed: superpowers 5.0.7 → 5.1.0 — review install matrix` one-liner. Non-fatal.

### Upstream GSD Issues

Three bugs discovered in `get-shit-done` CLI (upstream `gsd-build/get-shit-done` repo) during v4.0 execution. **File issues, do NOT patch in this repo** — those bugs belong to the upstream maintainers. Each requirement produces a reproducible issue report with minimum repro + suggested fix, not a PR in this toolkit.

- [ ] **UPSTREAM-01**: File issue for `gsd-tools audit-open` `ReferenceError: output is not defined` at `/Users/sergeiarutiunian/.claude/get-shit-done/bin/gsd-tools.cjs:786`. Include repro (`gsd-tools audit-open` on any project), stack trace, suggested fix (import missing `output` helper).
- [ ] **UPSTREAM-02**: File issue for `gsd-tools milestone complete` emitting noise into MILESTONES.md accomplishments — first-line-of-SUMMARY.md heuristic grabs YAML frontmatter keys ("One-liner:", "Site 1", etc.) instead of the one-liner prose. Include v4.0 artifact as repro; suggested fix: parse the `**One-liner:**` or "## One-liner" section body, not the raw first line.
- [ ] **UPSTREAM-03**: File issue for missing auto-sync of ROADMAP.md plan checkboxes on plan-complete. Repro: run `gsd-execute-phase N --auto`, observe that SUMMARY.md files land but `- [ ]` plan entries in ROADMAP.md remain unchecked until manual `gsd-tools roadmap update-plan-progress N`. Suggested fix: hook `update-plan-progress` into the state `advance-plan` path.

### UX Polish

One-item category. Visual polish for `--dry-run` output across install/update/migrate scripts.

- [ ] **UX-01**: `scripts/init-claude.sh --dry-run`, `scripts/update-claude.sh --dry-run`, and `scripts/migrate-to-complement.sh --dry-run` produce chezmoi-grade styled diff output. Colored `+` / `-` / `~` per file, grouped by action (INSTALL / UPDATE / SKIP / REMOVE), right-aligned file counts per group. Matches chezmoi's `diff` presentation quality.

## Audit Verification (Phase 12)

Traceability records for all 15 ChatGPT pass-3 template-level claims.
Every claim gets a REQ-ID regardless of verdict. FALSE rows are closed
immediately; REAL/PARTIAL rows that pass the user gate become HARDEN-A-NN
requirements.

- [ ] **AUDIT-01**: Plugin manifest schema missing — no `plugin.schema.json` for `.claude-plugin/plugin.json` validation — Status: FALSE
- [ ] **AUDIT-02**: No template compatibility matrix — no `compatibility.json` to block incompatible stack combos — Status: PARTIAL
- [ ] **AUDIT-03**: Namespace collision between templates — two framework templates ship same-named commands, overwrite each other — Status: FALSE
- [ ] **AUDIT-04**: No template merge-strategy declaration — base+python+rag overlay semantics undefined — Status: PARTIAL
- [ ] **AUDIT-05**: Relative path assumptions in templates — `../skills/rag.md` inside template markdown breaks post-install — Status: FALSE
- [ ] **AUDIT-06**: No template version pinning — installer pulls main branch, no `template.lock.json` / `template_version` field — Status: PARTIAL
- [ ] **AUDIT-07**: No template feature-flags — workflow-v2 / memory-v3 / agents-v1 versions not declared — Status: FALSE
- [ ] **AUDIT-08**: Stack autodetection fragile — confidence scoring, override, dry-run preview missing — Status: FALSE
- [ ] **AUDIT-09**: No dry-run installer mode — no preview of install plan — Status: FALSE
- [ ] **AUDIT-10**: No collision detection with existing `.claude/` — overwrite/merge/fail behavior undeclared — Status: PARTIAL
- [ ] **AUDIT-11**: No template integrity checksum — no `manifest.hash` — Status: FALSE
- [ ] **AUDIT-12**: Markdown commands as templates without linting — required sections/frontmatter/step markers not enforced — Status: PARTIAL
- [ ] **AUDIT-13**: No dependency graph between templates — rag requires memory, installer doesn't enforce — Status: FALSE
- [ ] **AUDIT-14**: No uninstall semantics — can't remove template safely — Status: REAL
- [ ] **AUDIT-15**: No template provenance metadata — no `installed_templates.json` post-install — Status: PARTIAL

## Wave A Hardening (Phase 12 — user gate complete)

HARDEN-A-NN requirements approved by user gate on 2026-04-24 proceed to
Plan 12.2 implementation. Rejected/deferred rows keep their status for the
paper trail.

- [x] **HARDEN-A-01**: Add `validate-commands` Makefile target that greps `commands/*.md` for `## Purpose` and `## Usage` headings; wire into `check` target and `.github/workflows/quality.yml`; fail with list of non-compliant files — Status: Done (implemented 2026-04-24 via `scripts/validate-commands.py` + `make validate-commands`)

## Future Requirements

Items deferred to v4.2+ after initial scope assessment:

- Docker-per-cell isolation — permanently locked out (conflicts with POSIX-shell invariant)
- Auto-cut `git tag` from phase execution — permanently locked out (CLAUDE.md "never push directly to main")
- Installable GSD CLI wrapper inside toolkit — crosses repo boundary, belongs in gsd-build/get-shit-done

## Out of Scope

- Re-implementing `superpowers` or `get-shit-done` features — unchanged from v4.0
- Auto-installing SP/GSD on user's behalf — unchanged from v4.0
- Migrating users without consent — unchanged from v4.0
- Patching upstream GSD CLI bugs in this repo — UPSTREAM-01/02/03 file issues, don't fork
- Net-new install modes beyond the 4 shipped in v4.0 — no `complement-partial`, no `migrate-lite`, etc.
- Backwards-compat shims for pre-v4.0 install state formats — migration path is `migrate-to-complement.sh`; no second-tier shim

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| REL-01 | Phase 8 | Planned |
| REL-02 | Phase 8 | Planned |
| REL-03 | Phase 8 | Planned |
| BACKUP-01 | Phase 9 | Planned |
| BACKUP-02 | Phase 9 | Planned |
| DETECT-06 | Phase 9 | Planned |
| DETECT-07 | Phase 9 | Planned |
| UPSTREAM-01 | Phase 10 | Planned |
| UPSTREAM-02 | Phase 10 | Planned |
| UPSTREAM-03 | Phase 10 | Planned |
| UX-01 | Phase 11 | Planned |
| AUDIT-01 | Phase 12 | Closed - FALSE |
| AUDIT-02 | Phase 12 | REAL |
| AUDIT-03 | Phase 12 | Closed - FALSE |
| AUDIT-04 | Phase 12 | REAL |
| AUDIT-05 | Phase 12 | Closed - FALSE |
| AUDIT-06 | Phase 12 | REAL |
| AUDIT-07 | Phase 12 | Closed - FALSE |
| AUDIT-08 | Phase 12 | Closed - FALSE |
| AUDIT-09 | Phase 12 | Closed - FALSE |
| AUDIT-10 | Phase 12 | REAL (Deferred v4.2+) |
| AUDIT-11 | Phase 12 | Closed - FALSE |
| AUDIT-12 | Phase 12 | REAL |
| AUDIT-13 | Phase 12 | Closed - FALSE |
| AUDIT-14 | Phase 12 | REAL (Deferred v4.2+) |
| AUDIT-15 | Phase 12 | REAL |
| HARDEN-A-01 | Phase 12 | Done |

**Coverage:** 27 / 27 requirements mapped to phases ✓
