# Milestones

## v4.0 Complement Mode (Shipped: 2026-04-21)

**Phases completed:** 8 phases (1–7 + 6.1 inserted), 29 plans, 56 tasks
**Git range:** `f7a… v3.x-preflight → 4c7bca1` (closing commit)
**Timeline:** 2026-04-17 → 2026-04-21

**Delivered:** Transformed the toolkit from standalone installer into a complement-aware system that detects `superpowers` + `get-shit-done` and installs only files that add unique value, with 4-mode install flow, smart update, safe migration, and a 13-cell install matrix validator.

**Key accomplishments:**

- **Complement-aware install flow** — 4 install modes (`standalone`, `complement-sp`, `complement-gsd`, `complement-full`) with auto-recommendation, `--mode` flag override, `--dry-run` grouped preview, manifest-driven skip-list, and `init-local.sh` parity (Phase 3).
- **Mode-aware update pipeline** — `update-claude.sh` re-evaluates detection on every run, surfaces mode drift with `[y/N]` confirmation, handles new/removed/modified files from manifest drift, produces 4-group post-update summary, writes tree backups with `<unix-ts>-<pid>` suffix (Phase 4).
- **Safe migration path for v3.x users** — `migrate-to-complement.sh` with three-way diff (TK template / on-disk / SP equivalent), two-signal user-modification detection, `[y/N/d]` per-file prompt, full backup to `~/.claude-backup-pre-migrate-<unix-ts>/`, idempotent re-runs, state rewrite to complement-mode (Phase 5).
- **Manifest v2 schema + atomic state** — Every file declares `conflicts_with: ["superpowers" | "get-shit-done"]`; `~/.claude/toolkit-install.json` captures mode, detection, installed/skipped files with SHA256 hashes; `mkdir`-based POSIX lock with stale-lock recovery; `detect.sh` exposes `HAS_SP`, `HAS_GSD` (Phase 2).
- **Complement-first documentation** — README repositioned as a complement to `superpowers` + `get-shit-done`, all 7 templates carry "Required Base Plugins" section, `docs/INSTALL.md` 12-cell install matrix, `components/optional-plugins.md` covers rtk + caveman + SP + GSD with upstream-verified caveats; 8 non-English translations (de, es, fr, ja, ko, pt, ru, zh) synced to v4.0 complement-first with `make translation-drift` gate (Phase 6 + 6.1).
- **Release validation infrastructure** — `scripts/validate-release.sh` runs 13 sandbox-isolated cells (4 modes × {fresh, upgrade-v3.x, rerun} + translation-sync) with 63 assertions; `Makefile` enforces `version-align` + `translation-drift` + `agent-collision-static` via `make check`; dual-surface `docs/RELEASE-CHECKLIST.md` for human sign-off; CHANGELOG `[4.0.0]` header carries concrete release date 2026-04-21 (Phase 7).
- **Pre-work bug fixes** — BUG-01 (BSD `head -n -1` → POSIX `sed`) preserved CLAUDE.md on macOS updates; BUG-02 (`< /dev/tty` guards) unblocked `curl | bash`; BUG-03 (`python3 json.dumps` for API keys) eliminated JSON-escape bug; BUG-05 (`settings.json` timestamped backup) + BUG-06 (version alignment) + BUG-04 (apt-get prompt) + BUG-07 (`design.md` in update loop) (Phase 1).

**Archived:**

- `.planning/milestones/v4.0-ROADMAP.md` — full phase breakdown with all 29 plans
- `.planning/milestones/v4.0-REQUIREMENTS.md` — all requirements with traceability
