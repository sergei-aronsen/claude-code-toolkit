# Requirements: claude-code-toolkit v4.3 — Uninstall

**Defined:** 2026-04-26
**Core Value:** Provide a clean reverse of `init-claude.sh`/`init-local.sh` install. Toolkit users can remove every toolkit-installed file from `.claude/` without touching base plugins (`superpowers`, `get-shit-done`) or user-modified files. Closes HARDEN-C-04 — the only REAL finding from the v4.1 ChatGPT pass-3 audit.

## v1 Requirements

Requirements for the v4.3 release. Each maps to exactly one roadmap phase.

### Core Uninstall Logic

The script that drives the file removal — must be safe, deterministic, and reversible-by-backup.

- [x] **UN-01**: `scripts/uninstall.sh` reads `~/.claude/toolkit-install.json` and removes every file listed under `installed_files[]` whose SHA256 matches the recorded hash. Files are deleted from the project's `.claude/` directory only — never from `~/.claude/` and never from base-plugin directories (`~/.claude/plugins/cache/claude-plugins-official/superpowers/`, `~/.claude/get-shit-done/`).
- [x] **UN-02**: `--dry-run` flag prints the full removal plan (which files would be deleted, which would be kept due to user modification, which would be skipped due to absence) and exits 0 without touching the filesystem.
- [x] **UN-03**: User-modified files (recorded SHA256 ≠ current SHA256) trigger a per-file `[y/N/d]` prompt: `y` removes, `N` keeps (default), `d` shows diff vs the manifest reference and re-prompts. Stdin reads via `< /dev/tty` so the script works under `curl ... | bash`.
- [x] **UN-04**: Before any delete, the script writes a full backup of the project's `.claude/` directory to `~/.claude-backup-pre-uninstall-<unix-ts>/` (parallel to existing backup conventions in `update-claude.sh` + `migrate-to-complement.sh`). Backup is always made — `--no-backup` flag does not exist in v4.3.

### State Cleanup + Idempotency

The script must leave the system in a known-clean state and survive double-invocation.

- [x] **UN-05**: After successful removal, `~/.claude/toolkit-install.json` is deleted (toolkit no longer claims to be installed). `~/.claude/CLAUDE.md` toolkit-owned sections (between `<!-- TOOLKIT-START -->` / `<!-- TOOLKIT-END -->` markers if present) are stripped; user-authored sections preserved verbatim. Base plugins (`superpowers`, `get-shit-done`) and their state remain untouched.
- [x] **UN-06**: Running `uninstall.sh` twice in a row is idempotent — the second run detects missing `~/.claude/toolkit-install.json`, prints `✓ Toolkit not installed; nothing to do`, and exits 0. No errors, no partial state changes, no orphaned backup directory created on no-op runs.

### Distribution + Tests

Wire the new script through manifest, installer banners, CHANGELOG, and CI.

- [ ] **UN-07**: `manifest.json` registers `scripts/uninstall.sh` under `files.scripts[]`. `init-claude.sh`, `init-local.sh`, and `update-claude.sh` end-of-run banners include the line `To remove: bash <(curl -sSL .../scripts/uninstall.sh)` (single-line, no extra prose). `CHANGELOG.md` `[4.3.0]` entry covers UN-01..UN-08 with ship date set when the milestone closes.
- [ ] **UN-08**: New `scripts/tests/test-uninstall.sh` + Makefile `Test 21` assert: (a) fresh install → uninstall → `.claude/` matches a fresh checkout (no toolkit files, no `toolkit-install.json`); (b) modified file detection prompts `y/N/d` and respects each choice; (c) base-plugin files are never touched (compare SP/GSD inventories before vs after); (d) double-uninstall exits 0 with no-op message; (e) `--dry-run` produces zero filesystem changes. CI mirror runs in `.github/workflows/quality.yml`.

## Future Requirements (Deferred)

- AUDIT-02/04/06/10/15 — Wave B/C hardening from v4.1 audit (compat matrix, merge strategy, version pinning, collision detection policy, provenance metadata) — separate milestone
- Council `audit-review` integration with cloud Sentry/Linear — only after v4.2 stabilises
- Installable GSD CLI wrapper in toolkit — crosses repo boundary
- `--no-council` flag for `/audit` — only if friction surfaces post-v4.2

## Out of Scope

- Removing base plugins (`superpowers`, `get-shit-done`) — out of scope; toolkit only owns its own files
- Restoring pre-install state for files that existed before toolkit was installed — backup is the reverse path; uninstall does not "undo install" in the diff-sense, only removes toolkit's contributions
- A `--no-backup` flag — backup is mandatory; if disk space is the worry, run `update-claude.sh --clean-backups` afterward
- Selective uninstall (`--only commands/` or `--except council`) — adds combinatorial test surface; revisit if user demand emerges
- Automatic re-install detection / "reinstall after uninstall" UX shortcuts — `init-claude.sh` already handles fresh install, no special case needed
- Docker/CI uninstall mode — same script handles both; no separate flag

## Traceability

| REQ-ID | Phase | Plan |
|--------|-------|------|
| UN-01 | Phase 18 — Core Uninstall | TBD |
| UN-02 | Phase 18 — Core Uninstall | TBD |
| UN-03 | Phase 18 — Core Uninstall | TBD |
| UN-04 | Phase 18 — Core Uninstall | TBD |
| UN-05 | Phase 19 — State Cleanup + Idempotency | TBD |
| UN-06 | Phase 19 — State Cleanup + Idempotency | TBD |
| UN-07 | Phase 20 — Distribution + Tests | TBD |
| UN-08 | Phase 20 — Distribution + Tests | TBD |

**Coverage:** 8/8 REQ-IDs mapped to exactly one phase. No orphans, no duplicates.

---

*v4.3 roadmap created 2026-04-26 — 3 phases (18–20), 8 REQ-IDs.*
