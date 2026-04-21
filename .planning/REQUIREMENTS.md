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

**Coverage:** 11 / 11 requirements mapped to phases ✓
