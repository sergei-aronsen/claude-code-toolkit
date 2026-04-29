# Milestones

## v4.6 Install Flow UX & Desktop Reach (Shipped: 2026-04-29)

**Phases completed:** 4 phases (24–27), 17 plans, 42 tasks
**Git range:** `v4.4.0 → v4.6.0` — 50+ commits, 429 files changed (+86,348 / −67)
**Timeline:** 2026-04-29 single-day intensive
**Audit:** `.planning/v4.6-MILESTONE-AUDIT.md` — passed (36/36 REQ-IDs, 28/28 connections, 5 of 6 E2E flows verified)

**Delivered:** Replaced 5 separate curl-bash invocations with a single guided TUI installer (Components / MCPs / Skills) and published the toolkit as a Claude Code plugin marketplace so Claude Desktop users get the value surface architecturally available to them.

**Key accomplishments:**

- **Unified TUI Installer + Centralized Detection (Phase 24 / TUI-01..07, DET-01..05, DISPATCH-01..03, BACKCOMPAT-01)** — `scripts/lib/{tui,detect2,dispatch}.sh` foundation libs with Bash 3.2 compatible `tui_checklist` (no `read -N`, no float `-t`, no `declare -n` namerefs; `read -rsn1` + `read -rsn2` for arrow tail), `< /dev/tty` with `TK_TUI_TTY_SRC` test seam and fail-closed default-set on no-TTY, `trap '<restore-stty>' EXIT INT TERM` registered before raw mode, three-layer NO_COLOR gate per [no-color.org](https://no-color.org). Six binary `is_*_installed` probes in `detect2.sh` (toolkit, superpowers, gsd, security, rtk, statusline) with `cc-safety-net` brew+npm coverage fix. `scripts/install.sh` (440 LOC) orchestrates detection → TUI → confirmation → dispatch → summary with `--yes`, `--dry-run`, `--force`, `--fail-fast`, `--no-color`, `--no-banner` flags. `test-install-tui.sh` PASS=43 (38 base + 5 from S10). `init-claude.sh` URL stays byte-identical with all v4.4 flags.
- **MCP Selector (Phase 25 / MCP-01..05, MCP-SEC-01/02)** — 9-MCP curated catalog at `scripts/lib/mcp-catalog.json` (context7, firecrawl, magic, notion, openrouter, playwright, resend, sentry, sequential-thinking) loaded via `scripts/lib/mcp.sh` (433 LOC); `is_mcp_installed` 3-state probe (0/1/2 with CLI-absent fail-soft); per-MCP wizard with hidden-input `read -rsp` for API keys, never echoed; `~/.claude/mcp-config.env` mode 0600 enforcement via `mcp_secrets_set` with `[y/N]` collision prompt; `scripts/install.sh --mcps` flag routing. Test suites: `test-mcp-selector.sh` PASS=21, `test-mcp-secrets.sh` PASS=11, `test-mcp-wizard.sh` PASS=14. `docs/MCP-SETUP.md` documents the plaintext-on-disk caveat + rotate-to-secret-manager recipe. Adjusted scope: replaced per-MCP `templates/mcps/<name>/{mcp.json,setup.sh,config-prompt.txt}` directory tree with a single JSON catalog — simpler, no duplication for zero-config MCPs.
- **Skills Selector (Phase 26 / SKILL-01..05)** — 22-skill marketplace mirror under `templates/skills-marketplace/<name>/` (ai-models, analytics-tracking, chrome-extension-development, copywriting, docx, find-skills, firecrawl, i18n-localization, memo-skill, next-best-practices, notebooklm, pdf, resend, seo-audit, shadcn, stripe-best-practices, tailwind-design-system, typescript-advanced-types, ui-ux-pro-max, vercel-composition-patterns, vercel-react-best-practices, webapp-testing). License preservation: 2 skills with upstream `LICENSE` mirrored as-is, 20 received `SKILL-LICENSE.md` provenance fallback. `scripts/lib/skills.sh` exposes `SKILLS_CATALOG[]` + `is_skill_installed` (`[ -d ]` probe) + `skills_install` (cp -R, returns 2 without `--force`); `scripts/sync-skills-mirror.sh` standalone maintainer tool with `--dry-run`. `scripts/install.sh --skills` flag. `test-install-skills.sh` PASS=15. `manifest.json` `files.skills_marketplace[]` 22 entries auto-discovered by `update-claude.sh` via existing LIB-01 D-07 jq path. `docs/SKILLS-MIRROR.md` records mirror date + upstream URLs + re-sync procedure.
- **Marketplace Publishing + Claude Desktop Reach (Phase 27 / MKT-01..04, DESK-01..04)** — `.claude-plugin/marketplace.json` at repo root with 3 sub-plugins (`tk-skills` Desktop-compatible, `tk-commands` Code-only, `tk-framework-rules` Code-only); 4 relative symlinks (mode 120000) point sub-plugin trees at existing repo content for zero duplication. Decision: `plugin.json` is single source of truth for version (marketplace.json entries omit version — silently overridden). `scripts/validate-skills-desktop.sh` heuristic-greps for `(Read|Write|Bash|Grep|Edit|Task)\(` to flag Code-only skills; result: 20 of 22 PASS, 2 (firecrawl, shadcn) FLAG informational — well above the 4-skill DESK-04 gate. `scripts/validate-marketplace.sh` gated by opt-in `TK_HAS_CLAUDE_CLI=1` env var. `scripts/install.sh --skills-only` flag + auto-routing when `command -v claude` fails. `docs/CLAUDE_DESKTOP.md` 94-line capability matrix (Code tab parity vs remote/Chat tab gaps). `manifest.json` 4.4.0 → 4.6.0; `CHANGELOG.md [4.6.0]` consolidated entry. CI step `Tests 21-33` + dedicated DESK-02/04 + MKT-03 jobs.
- **Cross-phase wiring verified end-to-end** — `gsd-integration-checker` confirmed all 28 expected connections wired (Phase 24 libs consumed by 25/26/27; install.sh extended with `--mcps`/`--skills`/`--skills-only` without flag-mutex breakage; mirror reachable from `tk-skills` symlink; manifest 4.6.0 registers all libs/scripts/skills_marketplace[]). Fix commit `f2c607d` resolved 3 minor gaps surfaced during integration check (CHANGELOG `templates/mcps/` reference removed, MCP names corrected, `validate-marketplace` CI step added). All 5 hermetic test suites pass concurrently. BACKCOMPAT-01 invariant preserved end-to-end (`test-bootstrap.sh` PASS=26 unchanged).

**Tech debt acknowledged (not blocking ship):**

- 8 HUMAN-UAT items deferred (live-PTY or external-CLI dependent — cannot be automated): Phase 24 interactive TUI render + Ctrl-C restore; Phase 25 interactive TUI + real-CLI MCP detection + hidden-input visual UX; Phase 26 interactive 22-row TUI render; Phase 27 live `claude plugin marketplace add` smoke + Claude Desktop end-to-end install.
- 5 advisory code-review WR findings in Phase 24 (`tui.sh` seam-bypass + EXIT-trap clobber + `dispatch.sh` `eval` env-var injection — low real-world risk; tracked in `.planning/phases/24-unified-tui-installer-centralized-detection/24-REVIEW.md`).
- MKT-03 partial: marketplace structure verified statically; live runtime smoke deferred as HUMAN-UAT.

**Archived:**

- `.planning/milestones/v4.6-ROADMAP.md` — full phase breakdown with all 17 plans
- `.planning/milestones/v4.6-REQUIREMENTS.md` — 36 REQ-IDs with traceability + adjustments table

---

## v4.4 Bootstrap & Polish (Shipped: 2026-04-27)

**Phases completed:** 3 phases (21–23), 8 plans, 19 tasks
**Git range:** `v4.3.0 → v4.4.0` — 62 commits, 59 files changed (+12935 / −71)
**Timeline:** 2026-04-26 → 2026-04-27

**Delivered:** Streamlined first-run UX so the toolkit can offer to install `superpowers` and `get-shit-done` via their canonical installers before detection runs, closed the silent smart-update gap on `scripts/lib/*.sh`, and finished installer-flag symmetry — `--no-banner` now lives on all three installers and `uninstall.sh` learned `--keep-state` for partial-uninstall recovery.

**Key accomplishments:**

- **SP/GSD Bootstrap Installer (Phase 21 / BOOTSTRAP-01..04)** — `scripts/lib/bootstrap.sh` + `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` constants in `optional-plugins.sh` invoke the canonical upstream installers verbatim (`claude plugin install superpowers@claude-plugins-official` and `bash <(curl -sSL .../get-shit-done/.../install.sh)`); `init-claude.sh` and `init-local.sh` source it before `detect.sh` and re-run detection after bootstrap so `~/.claude/toolkit-install.json` reflects the post-bootstrap mode (`complement-sp`, `complement-gsd`, `complement-full`); fail-closed `N` when `< /dev/tty` is unavailable (CI / piped); `--no-bootstrap` flag and `TK_NO_BOOTSTRAP=1` env var preserve unchanged v4.3 behaviour; `scripts/tests/test-bootstrap.sh` proves three branches (prompt-y, prompt-N, `--no-bootstrap` skip).
- **Smart-Update Coverage for `scripts/lib/*.sh` (Phase 22 / LIB-01/02)** — `manifest.json` gained a `files.libs[]` registry covering `scripts/lib/{backup,dry-run-output,install,state}.sh`; `update-claude.sh` iterates the new section with the same diff/backup/safe-write contract used for top-level scripts so a stale `lib/backup.sh` on disk gets refreshed on `update-claude.sh` and post-update SHA256 matches the manifest fixture; hermetic 5-scenario regression test in `scripts/tests/test-update-libs.sh` (Makefile Test 29 + CI Tests 21-29).
- **Installer Flag Symmetry — `--no-banner` (Phase 23 / BANNER-01)** — `init-claude.sh` and `init-local.sh` learned `--no-banner` and `NO_BANNER=1` env-form (`NO_BANNER=${NO_BANNER:-0}` so caller-exported env is honoured byte-identically across all three installers); banner `echo` wrapped in `if [[ $NO_BANNER -eq 0 ]]` gate; `scripts/tests/test-install-banner.sh` extended from 3 to 7 assertions covering env-form default, argparse clause, and gate pattern in both installers.
- **Partial-Uninstall Recovery — `--keep-state` (Phase 23 / KEEP-01/02)** — `scripts/uninstall.sh --keep-state` (and `TK_UNINSTALL_KEEP_STATE=1` env var) preserves `~/.claude/toolkit-install.json` after the run instead of deleting it as the LAST step (UN-05 D-06), so subsequent `uninstall.sh` runs after `[y/N/d]` rejections are NOT a no-op; all UN-01..UN-08 invariants stand (SHA256 classify, prompt, base-plugin diff, sentinel strip); 11-assertion hermetic test in `scripts/tests/test-uninstall-keep-state.sh` covers S1 (partial-N recovery), S2 (full-y branch), S3 (env-only flag) — Makefile Test 30 + CI Tests 21-30.
- **Inline correctness fix during ship (WR-01)** — Code review caught that `NO_BANNER=0` clobbered caller-exported env value, breaking the documented `NO_BANNER=1 init-claude.sh` path in BANNER-01; fixed inline as commit `094424c` before merge by switching all three installers to env-form `NO_BANNER=${NO_BANNER:-0}` and updating `test-install-banner.sh` A4/A7 grep patterns.

**Archived:**

- `.planning/milestones/v4.4-ROADMAP.md` — full phase breakdown with all 8 plans
- `.planning/milestones/v4.4-REQUIREMENTS.md` — 9 REQ-IDs with traceability (BOOTSTRAP-01..04, LIB-01/02, BANNER-01, KEEP-01/02)

---

## v4.3 Uninstall (Shipped: 2026-04-26)

**Phases completed:** 3 phases, 10 plans, 12 tasks

**Key accomplishments:**

- `scripts/uninstall.sh` skeleton with argparse, state-file load, SHA256 `classify_file` helper, and `is_protected_path` guard — pure read-only diagnostic, zero filesystem mutations, shellcheck-warning clean
- 1. [Rule 1 - Bug] classify_file path resolution: PROJECT_DIR not CLAUDE_DIR
- `scripts/uninstall.sh` non-dry-run path: creates `.claude-backup-pre-uninstall-<ts>/` before any `rm`, deletes only hash-matched files (REMOVE_LIST), preserves MODIFIED files (deferred to 18-04), prints 4-group post-run summary. `list_backup_dirs` extended for new pattern. 12-assertion hermetic test proves all invariants.
- `prompt_modified_for_uninstall()` + MODIFIED_LIST loop added to `scripts/uninstall.sh`. Every MODIFIED file triggers a re-entrant `[y/N/d]` prompt: `y` removes, `N` (default) keeps, `d` shows non-trivial diff and re-prompts. Reads `/dev/tty`; fail-closed `N` when unavailable. `test-uninstall-prompt.sh` proves all three branches via stdin injection — 10 assertions pass including A7 (W2 closure: diff body non-empty).
- Hermetic 5-assertion bash test that locks the UN-06 no-op contract: absent toolkit-install.json exits 0 with exact log wording and zero filesystem side-effects
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:

---

## v4.2 Audit System v2 (Shipped: 2026-04-26)

**Phases completed:** 5 phases (13–17), 22 plans, 23 tasks
**Git range:** `v4.1.1 (f87eace) → v4.2.0 (29cca9c)` — 82 commits, 207 files changed (+39997 / −18884)
**Timeline:** 2026-04-25 → 2026-04-26

**Delivered:** Replaced `/audit` with a deterministic FP-rechecked, structured-report pipeline that terminates in a mandatory Council pass. Findings are filtered through a repo-local `audit-exceptions.md` allowlist plus a 6-step FP recheck, written to a parser-friendly schema, and verified per-finding by Gemini + ChatGPT before the audit is considered complete.

**Key accomplishments:**

- **Foundation — FP Allowlist + Skip/Restore (Phase 13 / EXC-01..05)** — Seeded `templates/base/rules/audit-exceptions.md` with `globs: ["**/*"]` auto-load frontmatter + HTML-commented entry schema; shipped `/audit-skip` (hard-refusal append with `git ls-files` validation, exact-triple duplicate detection, atomic write) and `/audit-restore` (default-N `[y/N]` confirmation, comment-aware sed-strip + `in_comment` awk state machine to prevent CR-01 corruption); wired all three installers (`init-claude.sh`, `init-local.sh`, `update-claude.sh`) with byte-identical heredocs and idempotent first-install-only seeding.
- **Audit Pipeline — FP Recheck + Structured Reports (Phase 14 / AUDIT-01..05)** — Authored `components/audit-fp-recheck.md` (6-step recheck SOT) and `components/audit-output-format.md` (report schema SOT); rewrote `commands/audit.md` with a 6-phase workflow contract (load context → quick check → deep analysis → FP recheck → structured report → Council pass); reports land at `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md` with verbatim ±10-line code blocks per finding plus `Skipped (allowlist)` and `Skipped (FP recheck)` tables; locked by Test 17 (`scripts/tests/test-audit-pipeline.sh`, 82 assertions).
- **Council Audit-Review Integration (Phase 15 / COUNCIL-01..06)** — `scripts/council/prompts/audit-review.md` encodes byte-exact `<verdict-table>` / `<missed-findings>` contract; per-finding `REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT` verdicts with `[0.0, 1.0]` confidence and one-line justifications grounded in embedded code; severity reclassification is forbidden by prompt contract; `brain.py audit-review` runs Gemini + ChatGPT in parallel and flags per-finding disagreements as `disputed` without auto-resolution; `commands/audit.md` Council Handoff section gained byte-exact FP nudge (D-12/COUNCIL-05) and three-option disputed prompt (D-13); `commands/council.md` `## Modes` section surfaces `/council audit-review --report <path>` as the mandatory Phase 5 step.
- **Template Propagation — 49 Prompt Files (Phase 16 / TEMPLATE-01..03)** — `scripts/propagate-audit-pipeline-v42.sh` spliced four contract blocks (top-of-file allowlist callout, 6-step FP-recheck SELF-CHECK, structured OUTPUT FORMAT, Council handoff footer) into all 49 framework prompts (`templates/{base,laravel,rails,nextjs,nodejs,python,go}/prompts/*.md`) in one atomic commit `33be0b1`; preserved RU/EN language partitions; CI gate (Test 20 + `make validate` + `validate-templates` job) asserts all six numbered FP steps + literal `Council handoff` marker on every prompt.
- **Distribution — Manifest, Installers, CHANGELOG (Phase 17 / DIST-01..03)** — Bumped `manifest.json` to `4.2.0` and registered `templates/base/rules/audit-exceptions.md`; extended `setup-council.sh` Step 4 + `init-claude.sh setup_council()` with mtime-aware install of `scripts/council/prompts/audit-review.md`; `CHANGELOG.md` `[4.2.0]` entry covers all Phase 13–16 features with concrete ship date 2026-04-26; `make check` + `make test` green at close.

**Archived:**

- `.planning/milestones/v4.2-ROADMAP.md` — full phase breakdown with all 22 plans
- `.planning/milestones/v4.2-REQUIREMENTS.md` — 22 REQ-IDs with traceability

---

## v4.1 Polish & Upstream (Shipped: 2026-04-25)

**Phases completed:** 5 phases (8–12), 13 plans, 11 REQ-IDs
**Git range:** `c8f4111 → 61d4eed`
**Timeline:** 2026-04-21 → 2026-04-25

**Delivered:** Hardened v4.0 release against the bugs discovered during v4.0 ship — added bats install-matrix automation, backup hygiene, CLI-cross-checked plugin detection, version-skew warnings, chezmoi-grade `--dry-run` UX, and three filed upstream issues for `gsd-build/get-shit-done` bugs that should not be patched in this repo.

**Key accomplishments:**

- **Release Quality (Phase 8 / REL-01/02/03)** — Ported the 13-cell install matrix to bats with pinned `bats-action@v4.0.0` SHA, added a `cell-parity` gate that locks 13 cell names across 3 surfaces (`Makefile` / `validate-release.sh` / `docs/INSTALL.md`), and shipped `--collect-all` mode on `validate-release.sh` for aggregated CI failure output instead of fail-fast.
- **Backup & Detection (Phase 9 / BACKUP-01/02, DETECT-06/07)** — Centralized backup logic in `scripts/lib/backup.sh` with `list_backup_dirs()` + `warn_if_too_many_backups()`, wired non-fatal threshold warnings into `update-claude.sh` + `migrate-to-complement.sh`, added `claude plugin list` cross-check as step 4 in `detect_superpowers()` (filesystem still wins on any CLI failure), and shipped `warn_version_skew()` in `update-claude.sh` only.
- **Upstream GSD Issues (Phase 10 / UPSTREAM-01/02/03)** — Filed three well-formed issues in `gsd-build/get-shit-done` ([#2659](https://github.com/gsd-build/get-shit-done/issues/2659) audit-open ReferenceError, [#2660](https://github.com/gsd-build/get-shit-done/issues/2660) extractOneLinerFromBody returns label, [#2661](https://github.com/gsd-build/get-shit-done/issues/2661) ROADMAP checkbox auto-sync gap) with full repro, root-cause analysis, and suggested fixes — zero code changes in this toolkit per Success Criterion 4.
- **UX Polish (Phase 11 / UX-01)** — New `scripts/lib/dry-run-output.sh` shared library exposes `dro_init_colors`/`dro_print_header`/`dro_print_file`/`dro_print_total`; refactored `init-claude.sh`, `update-claude.sh`, `migrate-to-complement.sh` to all share chezmoi-grade `[+ INSTALL]` / `[~ UPDATE]` / `[- SKIP]` / `[- REMOVE]` grouped output with right-aligned counts; `${NO_COLOR+x}` + `[ -t 1 ]` gates correctly disable color in non-TTY and honor [no-color.org](https://no-color.org).
- **Audit Verification + Hardening (Phase 12 / HARDEN-A-01)** — Verified ChatGPT pass-3 audit claims against the codebase with `grep` + file reads (8/15 claims FALSE — hallucinated features that already existed; 6/15 PARTIAL deferred to v4.2+; 1/15 REAL = uninstall script deferred as HARDEN-C-04); shipped Wave-A `scripts/validate-commands.py` enforcing `## Purpose` + `## Usage` H2 headings on `commands/*.md` via `make validate-commands` and CI.
- **CI hardening surfaced during ship** — `bd09abd` silenced SC2034 on sourced color vars in matrix helpers; `2cfa2e8` added `fetch-depth: 0` to the `test-matrix-bats` job so 4 `-upgrade` cells could find `PRE_40_COMMIT` in the GitHub Actions shallow clone.
- **External signal evaluated** — `forrestchang/andrej-karpathy-skills` (83K stars) cherry-picked: only "Surgical Changes" was a genuinely new rule; KISS/YAGNI/Plan Mode rules duplicated existing coverage. Added `components/surgical-changes.md` instead of installing the full plugin.

**Archived:**

- `.planning/milestones/v4.1-ROADMAP.md` — full phase breakdown with all 13 plans
- `.planning/milestones/v4.1-REQUIREMENTS.md` — 11 REQ-IDs with traceability

---

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
