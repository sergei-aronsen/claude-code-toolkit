# Feature Research

**Domain:** CLI toolkit install/update flow — conditional install, coexistence with other plugins
**Researched:** 2026-04-17
**Confidence:** HIGH (grounded in codebase analysis + domain patterns from Homebrew, chezmoi, Terraform, npm)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = install flow breaks trust.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Dry-run mode (`--dry-run`) | Every serious CLI installer offers preview-before-commit; users won't run curl-pipe-bash blind | LOW | Already in `init-claude.sh`; must be extended to cover mode-selection and skip-list decisions |
| Backup before any mutation | Industry norm: Homebrew, npm, chezmoi all backup or use temp dirs before overwrite; `update-claude.sh` already does `cp -r .claude .claude-backup-*` | LOW | Must extend to `~/.claude/settings.json` merge (currently unprotected per CONCERNS.md) |
| Post-install summary | User needs to know: what was installed, what was skipped (and why), what was backed up | LOW | Currently `update-claude.sh` logs per-file but gives no final summary block |
| Conflict detection before install | Homebrew pattern: detect name collision and surface it before writing any files, not after | MEDIUM | Must check for hard duplicates (code-reviewer agent name collision, Iron Law verbatim copy) before copying |
| Mode auto-recommendation with user override | Detect SP/GSD via filesystem; suggest the right mode; let user override before any file is written | MEDIUM | Core of complement-mode; detection is a single `[ -d ... ]` check but UX prompt needs /dev/tty guard |
| Idempotent re-run | Running init or update twice must produce the same end state; no duplicate entries, no double-backup noise | MEDIUM | Requires install state file to know what was done; currently re-running creates redundant backups |
| Rollback on failure | If install exits mid-way, user is not left in half-installed state | MEDIUM | Current `set -euo pipefail` exits cleanly but leaves partial writes; need `trap ERR` + restore from backup |
| `[y/N]` confirmation before every destructive action | Never mutate `~/.claude/` without explicit consent; PROJECT.md constraint | LOW | Pattern exists in `init-claude.sh` for Council setup; must be consistent throughout |
| Version alignment across all references | Users see a single version number; `manifest.json`, `.toolkit-version`, `CHANGELOG.md`, `init-local.sh` must agree | LOW | CONCERNS.md flags existing drift (3.0.0 vs 2.0.0 vs empty unreleased) |

### Differentiators (Competitive Advantage)

Features that make TK's install flow better than typical plugin installers.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Persist install state to `~/.claude/toolkit-install.json` | Single source of truth: mode chosen, detected bases, installed files, skipped files, timestamp. Enables smart update without re-detection | MEDIUM | Analogous to chezmoi's source/destination/target three-state model; update-claude.sh reads this instead of re-scanning |
| Re-evaluate mode on update | If user installs SP after TK was set up standalone, `update-claude.sh` detects the new base, shows diff of what would change, prompts to switch mode | MEDIUM | Mirrors Terraform plan-then-apply: show the delta, ask for consent, then apply. Depends on install state file |
| Declarative skip-list in `manifest.json` | `requires_base` / `conflicts_with` per file; shell scripts read manifest, not hardcoded arrays. Auditable, extensible, prevents drift | MEDIUM | npm approach: package.json declares peer deps rather than installer hardcoding them |
| Diff-style preview in dry-run | Show `[INSTALL]`, `[SKIP - conflicts with SP]`, `[SKIP - already current]` per file, not just a flat list. chezmoi `diff` approach | LOW | Transforms dry-run from "what would run" into "what would change" — much higher signal |
| Migration offer for v3.x users | Auto-detect conflicting files from previous install, show diff, offer to remove duplicates with backup to `~/.claude-toolkit-migration-backup-YYYYMMDD/` | HIGH | Homebrew tap migration pattern: "you have formula X from tap A, installing same name from tap B requires uninstall first" — but we do it interactively, not as a hard block |
| Mode-aware post-install summary | Group output by section: `Installed (unique to TK)`, `Skipped (duplicate with SP)`, `Skipped (duplicate with GSD)`, `Backed up`. Makes the install decision legible | LOW | No comparable tool does this well; most just log a flat stream |
| Separate `--mode` flag for non-interactive installs | `init-claude.sh --mode complement-full laravel` for CI/scripted setups without prompts | LOW | Unblocks users who pipe curl output into bash in CI; currently framework works but mode does not |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Auto-install SP/GSD as part of TK install | Convenience — "just make it work" | Violates user autonomy over plugin set; TK does not own SP/GSD versioning; creates implicit dependency on external repos staying stable | Detect, suggest, link; user controls their own plugin installs |
| Silent overwrite without backup | Faster installs | Unrecoverable if something breaks; destroys user customizations | Always backup first, never skip (even in `--force` mode) |
| Auto-migrate without confirmation | Reduces friction | User may have intentionally kept the TK version of a command over SP's; removing without asking destroys that | Show diff, ask `[y/N]` per file group, backup before removal |
| Rollback via git history of `~/.claude/` | Elegant if ~/.claude is a git repo | Most users don't version-control `~/.claude/`; brittle assumption | Use timestamped backup dirs, provide `rollback-update.md` command |
| `claude plugin list` as primary detection | Cleaner API | CLI may not be installed, version-locked, or offline; filesystem check is always available | Filesystem-first; mention CLI as future enhancement in code comments |
| BREAKING changes without changelog flag | Saves developer time | Users on `curl-pipe-bash` auto-update get broken setups silently | Conventional Commits `BREAKING CHANGE:` footer + `[BREAKING]` in user-visible output for any mode-skipping a previously-installed file |
| Backwards-compat shims for deprecated TK commands | Zero friction migration | Shims duplicate the very thing we're trying to remove; confuse namespace; hard to remove later | Clean break at v4.0.0, clear migration note in post-install summary pointing to SP/GSD equivalents |
| Interactive prompts that hang under curl-pipe-bash | Full UX in all contexts | `read` without `< /dev/tty` hangs forever; CONCERNS.md flags `setup-council.sh` doing this | All `read` calls use `< /dev/tty 2>/dev/null`; non-interactive fallback to sensible defaults |

---

## Feature Dependencies

```
[Persist Install State]
    └──enables──> [Idempotent Re-run]
    └──enables──> [Re-evaluate Mode on Update]
    └──enables──> [Mode-aware Post-install Summary]

[Declarative Skip-list in manifest.json]
    └──enables──> [Conflict Detection Before Install]
    └──enables──> [Diff-style Preview in Dry-run]
    └──enables──> [Mode-aware Post-install Summary]

[Mode Auto-recommendation]
    └──requires──> [Filesystem Detection (SP/GSD paths)]
    └──enables──> [Migration Offer for v3.x users]

[Backup Before Mutation]
    └──enables──> [Rollback on Failure]
    └──enables──> [Migration Offer for v3.x users]

[--mode Flag (non-interactive)]
    └──conflicts──> [Interactive prompts without /dev/tty guard]
```

### Dependency Notes

- **Persist Install State requires Filesystem Detection:** You cannot write install.json until you know which bases are present and which mode was chosen.
- **Migration Offer requires Backup Before Mutation:** Removing files without a backup is the anti-feature; migration is only safe when backup is guaranteed.
- **Declarative Skip-list enables Diff-style Preview:** Without manifest.json encoding `conflicts_with`, dry-run must hardcode which files to skip — fragile and drifts.
- **Re-evaluate Mode on Update requires Persist Install State:** Without knowing what was installed last time and in which mode, `update-claude.sh` cannot compute the delta when bases change.

---

## MVP Definition

### Launch With (v4.0)

Minimum set to ship the complement-mode without breaking user trust.

- [ ] Filesystem detection of SP and GSD — `[ -d ~/.claude/plugins/cache/claude-plugins-official/superpowers/ ]`
- [ ] 4 install modes with hardcoded skip-lists (declarative manifest comes in v4.1)
- [ ] Mode auto-recommendation + user override prompt (with `/dev/tty` guard)
- [ ] Backup before any mutation (extend existing pattern to `settings.json`)
- [ ] `[y/N]` confirmation before destructive steps
- [ ] Persist install state to `~/.claude/toolkit-install.json`
- [ ] Post-install summary grouped by: installed, skipped (reason), backed up
- [ ] `--dry-run` extended to show mode-selection and per-file install/skip decisions
- [ ] Migration offer for v3.x users (detect conflicts, backup, confirm removal)
- [ ] `BREAKING CHANGE:` in CHANGELOG.md + `[BREAKING]` flag in output for removed commands

### Add After Validation (v4.1)

- [ ] Declarative `requires_base` / `conflicts_with` in `manifest.json` per file — replaces hardcoded skip-lists
- [ ] `--mode` flag for non-interactive / CI installs
- [ ] Re-evaluate mode on update (reads install.json, computes delta, prompts if bases changed)
- [ ] Diff-style preview in dry-run (`[INSTALL]` / `[SKIP - reason]` per file)

### Future Consideration (v5+)

- [ ] `claude plugin list` as secondary detection signal (supplement filesystem check)
- [ ] Automated install matrix smoke tests (bats or similar; 4 modes × 3 scenarios)
- [ ] Web-based install state dashboard (overkill for solo dev target user)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Filesystem detection (SP + GSD) | HIGH | LOW | P1 |
| Mode auto-recommendation + override | HIGH | LOW | P1 |
| Backup before mutation (settings.json) | HIGH | LOW | P1 |
| Persist install state (install.json) | HIGH | MEDIUM | P1 |
| Post-install summary (grouped) | HIGH | LOW | P1 |
| Dry-run extended to mode+skip decisions | HIGH | LOW | P1 |
| Migration offer for v3.x users | HIGH | HIGH | P1 |
| `[y/N]` per destructive action | HIGH | LOW | P1 |
| Rollback on failure (trap ERR + restore) | MEDIUM | MEDIUM | P2 |
| Declarative skip-list in manifest.json | MEDIUM | MEDIUM | P2 |
| `--mode` flag for non-interactive | MEDIUM | LOW | P2 |
| Re-evaluate mode on update | MEDIUM | MEDIUM | P2 |
| Diff-style preview in dry-run | MEDIUM | LOW | P2 |
| Automated install matrix tests | LOW | HIGH | P3 |

**Priority key:**

- P1: Must have for v4.0 launch
- P2: Should have, add in v4.1
- P3: Nice to have, future consideration

---

## Comparable Tool Analysis

| Pattern | Tool | What They Do | TK Approach |
|---------|------|--------------|-------------|
| Conflict detection | Homebrew | `conflicts_with` declared in formula; install blocked with clear message if conflicting formula present | Declarative `conflicts_with` in manifest.json; non-blocking (we skip, not abort) |
| Deprecation suggestion | npm | `WARN deprecated` with "use X instead" shown at install time | `[BREAKING]` in post-install summary listing SP/GSD equivalents for removed TK commands |
| Preview before mutation | chezmoi `diff` | Shows diff of source vs destination before `apply` | `--dry-run` shows `[INSTALL]` / `[SKIP - reason]` per file |
| Plan-then-apply | Terraform | `plan` is free, shows full change set; `apply` requires explicit consent | Dry-run (plan) → confirm → install (apply) |
| Persist install state | chezmoi source/target model | Three-state model; always knows current vs desired | `~/.claude/toolkit-install.json` as single source of truth |
| Formula migration | Homebrew tap conflict | Detects same-name formula from different tap; requires explicit uninstall | Migration offer: detect duplicate files from v3, backup, confirm removal interactively |
| Idempotent re-run | Most package managers | Re-running install on already-installed package is a no-op | Check install.json before writing; skip files that match current version |

---

## Install Matrix Testing

4 modes × 3 scenarios = 12 test cases. Recommended as a manual checklist for v4.0 (automated in v4.1+).

| Scenario | standalone | complement-sp | complement-gsd | complement-full |
|----------|------------|---------------|----------------|-----------------|
| Fresh install | All files written; install.json created | SP-conflicting files skipped; install.json records mode | GSD-conflicting files skipped | Both skip-lists applied |
| Upgrade from v3.x | Migration offer shown; duplicates backed up and removed with confirm | Same + SP duplicates offered for removal | Same + GSD duplicates | Both |
| Re-run idempotence | No files overwritten; no new backup created; install.json updated timestamp only | Same | Same | Same |

**What each cell must verify:**

- Correct files present in `~/.claude/`
- install.json written with correct mode, skipped-files list, timestamp
- Backup dir created before any mutation
- Post-install summary output matches actual filesystem state
- No orphaned partial writes if script is interrupted (Ctrl-C test)

---

## Sources

- Codebase: `/Users/sergeiarutiunian/Projects/claude-code-toolkit/.planning/PROJECT.md` (requirements, constraints, concerns)
- Codebase: `scripts/init-claude.sh`, `scripts/update-claude.sh` (existing install flow)
- Homebrew conflict docs: <https://github.com/Homebrew/brew/issues/16398> (MEDIUM confidence — GitHub issue)
- Homebrew tap conflict UX: <https://github.com/Homebrew/brew/pull/20304> (MEDIUM confidence)
- Idempotent bash patterns: <https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/> (HIGH confidence — widely cited)
- chezmoi diff/apply model: <https://www.chezmoi.io/user-guide/daily-operations/> (HIGH confidence — official docs)
- Terraform plan/apply pattern: <https://developer.hashicorp.com/terraform/cli/commands/plan> (HIGH confidence — official docs)
- npm deprecation UX: <https://docs.npmjs.com/deprecating-and-undeprecating-packages-or-package-versions/> (HIGH confidence — official docs)
- Dry-run UX patterns: <https://medium.com/@Praxen/the-dry-run-button-ux-that-saves-your-users-money-a0a9be0b16fe> (MEDIUM confidence — blog)

---

*Feature research for: claude-code-toolkit complement-mode install/update flow*
*Researched: 2026-04-17*
