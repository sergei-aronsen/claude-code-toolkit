# Project Research Summary

**Project:** claude-code-toolkit (v4.5 Install Flow UX & Desktop Reach)
**Domain:** CLI dev-tools installer + Anthropic Claude Code plugin distribution
**Researched:** 2026-04-29
**Confidence:** HIGH (Phase 24) / MEDIUM-HIGH (Phase 25)

## Executive Summary

v4.5 is two architecturally independent phases that can land in either order. **Phase 24** replaces the multi-command first-run flow (5 separate `bash <(curl ...)` invocations) with a single pure-bash TUI checklist installer that orchestrates the existing per-component scripts. No new runtime dependencies — Bash 3.2 (macOS default) compatible via `read -rsn1` + `read -rsn2` pattern with `< /dev/tty` reads and `stty` save-restore on EXIT/INT/TERM. **Phase 25** opens a new distribution channel by publishing the toolkit as a Claude Code plugin marketplace (`/plugin marketplace add sergei-aronsen/claude-code-toolkit`), exposing three sub-plugins (`tk-skills`, `tk-commands`, `tk-framework-rules`).

The most important correction surfaced by research: **Claude Desktop runs the same Claude Code runtime as the terminal in its Code tab** — there is no plugin gap at the runtime level. The Desktop restriction is content-level (some existing TK skills embed Bash blocks that assume Code-side tooling) and channel-level (Desktop blocks `/plugin marketplace add ./local-dir`, so Desktop users need a published marketplace, not a curl-bash install).

The single highest-risk item is the TUI raw-mode/Ctrl-C recovery — a careless implementation can leave users in a broken terminal that types blind. Prevention is the trap-before-raw-mode pattern from `bootstrap.sh:11` extended to full TUI loop.

## Key Findings

### Recommended Stack

Pure-bash TUI is the only path that satisfies the "no deps in install path" constraint inherited from v4.0–v4.4. `dialog`/`whiptail` absent on macOS base; `gum`/`fzf` are extra installs. The two Bash 3.2 traps are: `read -N` (capital — absent), `read -t 0.001` (sub-second float — absent). Pattern that works: `IFS= read -rsn1 k; if [[ "$k" == $'\e' ]]; then IFS= read -rsn2 extra; fi`. No `declare -n` namerefs (Bash 4.3+), so multi-component state passes via space-separated strings or eval-based indirect expansion.

**Core technologies:**

- **Pure-bash TUI** (`scripts/lib/tui.sh`): `read -rsn1` two-pass for arrow keys, `tput` cursor + clear, ANSI escapes via `\033`. Bash 3.2 verified on macOS Bash 3.2.57.
- **Centralized detection** (`scripts/lib/detect2.sh`): six `is_<name>_installed` probes — sources existing `detect.sh` for SP/GSD, adds `command -v cc-safety-net` (covers brew + npm), `command -v rtk`, `~/.claude/statusline.sh` + settings.json grep for statusline, `~/.claude/toolkit-install.json` for toolkit.
- **Anthropic Claude Code plugin marketplace**: `.claude-plugin/marketplace.json` at repo root + `plugins/<name>/.claude-plugin/plugin.json` per sub-plugin. Schema fields: `name` (kebab-case), `owner.name`, `plugins[]` each with `name` + `source`. Validate via `claude plugin validate .` before publishing.

### Expected Features

**Must have (table stakes):**

- TUI checklist with arrow-nav + space-toggle + enter-confirm; current selection visually distinguished
- Pre-checked + `[installed ✓]` label for detected components; user can uncheck to skip
- Confirmation step before any installer runs (prevents accidental enter-press)
- `--yes` non-interactive mode (CI / scripted): use detected default-set
- `--dry-run` mode: preview which scripts would run with what flags, zero side effects
- Post-install summary: per-component status (installed / skipped / failed)
- `< /dev/tty` semantics: TUI degrades to v4.4 bootstrap.sh y/N flow when no TTY
- Marketplace `marketplace.json` discoverable via `/plugin marketplace add owner/repo`
- `docs/CLAUDE_DESKTOP.md` with honest capability matrix

**Should have (differentiators):**

- `--force` re-runs detected components (re-install path)
- Grouped sections in TUI (Essentials: Toolkit + SP + GSD / Optional: Security + RTK + Statusline)
- Per-component description shown when item focused
- `--skills-only` install path that places skills under `~/.claude/plugins/` for Desktop users
- Skill-Desktop-safety audit script wired into CI (`make check`)

**Defer (v4.6+):**

- `--preset minimal|full|dev` flag (no demand surfaced)
- Live install progress bar (line-based status sufficient for v4.5)
- Marketplace signing/integrity (no Anthropic spec for it yet)

### Architecture Approach

`scripts/install.sh` is a **pure orchestrator** at a new top layer — it sources `scripts/lib/{tui,detect2,dispatch}.sh`, runs the TUI, and dispatches to existing per-component scripts (`init-claude.sh`, `setup-security.sh`, `install-statusline.sh`, etc.) via `bash -c` subprocess calls. Zero rewrite of those scripts. Backwards compatibility: existing `init-claude.sh` URL stays valid; `install.sh` is the new recommended entry point but does NOT trampoline through `init-claude.sh`.

**Major components:**

1. **`scripts/install.sh`** — TUI entry point, orchestrates detection → menu → confirm → dispatch → summary.
2. **`scripts/lib/tui.sh`** — pure-bash checklist renderer; exposes `tui_checklist <items_var> <results_var>`; trap-managed raw mode; `TK_TUI_TTY_SRC` test seam.
3. **`scripts/lib/detect2.sh`** — six `is_<name>_installed` functions (toolkit, sp, gsd, security, rtk, statusline); sources existing `detect.sh` for SP/GSD; emits standard 0/1 exit codes.
4. **`scripts/lib/dispatch.sh`** — per-component install dispatchers (`dispatch_toolkit`, `dispatch_security`, `dispatch_rtk`, `dispatch_statusline`); each accepts `--yes`/`--dry-run`/`--force` flags.
5. **`.claude-plugin/marketplace.json`** + **`plugins/{tk-skills,tk-commands,tk-framework-rules}/.claude-plugin/plugin.json`** — Phase 25 marketplace surface.
6. **`scripts/tests/test-install-tui.sh`** — hermetic TUI test using `TK_TUI_TTY_SRC` to inject keystrokes from a fixture file.
7. **`scripts/validate-skills-desktop.sh`** — CI gate that scans `templates/base/skills/*/SKILL.md` for Bash blocks and Code-only tool references, fails if any non-audited skill ships under `tk-skills`.

### Critical Pitfalls

1. **TUI raw-mode trap** — Set `stty -g | trap restore` BEFORE entering raw mode. `Ctrl-C` mid-render must restore terminal cleanly. Use `|| true` on restore so trap failure doesn't compound.
2. **`< /dev/tty` discipline** — Every `read` in TUI must redirect from `/dev/tty`. Pipe-from-curl consumes stdin. Test seam: `TK_TUI_TTY_SRC` env var (mirrors `TK_BOOTSTRAP_TTY_SRC` from v4.4).
3. **Bash 3.2 compat** — Use `read -rsn1` (lowercase n), not `-N`. No float `-t`. No `declare -n`. Static check: `bash --version` gate in CI.
4. **`cc-safety-net` detection regression** — Must use `command -v cc-safety-net`, NOT npm-path scan. Brew install path was missed by v4.4 `setup-security.sh`. Verbatim copy from `verify-install.sh:151`.
5. **Marketplace schema drift** — Anthropic spec evolves silently. Mitigation: validate with live `claude plugin marketplace add` invocation in CI smoke test (gated behind opt-in; `claude` CLI not in CI base image).
6. **Skill Desktop safety** — `debugging`, `docker`, `database`, `testing` SKILL.md files contain Bash code blocks. They are skill instructions, not actual shell scripts, but the skill audit must confirm they don't *require* Code-side tools. CI gate: `validate-skills-desktop.sh`.
7. **BOOTSTRAP-01..04 invariant regression** — v4.4's 26-assertion `test-bootstrap.sh` must stay green throughout Phase 24 refactoring. `bootstrap.sh` becomes the no-TTY fallback, not a deprecated script.

## Implications for Roadmap

Based on research, suggested two-phase structure (matching milestone scope):

### Phase 24: Unified TUI Installer + Centralized Detection

**Rationale:** Internal work — no external dependencies (Anthropic spec verification). Phase 24 quickly consolidates the existing 5-command flow into one entry point, delivering a fast UX win for existing curl-bash users. Order inside the phase: `detect2.sh` → `tui.sh` → `--yes` flag rollout (`setup-security.sh`, `install-statusline.sh`) → `dispatch.sh` → `install.sh` → tests.

**Delivers:**

- `scripts/install.sh` single curl-bash entry point with TUI checklist
- `scripts/lib/{tui,detect2,dispatch}.sh` shared libraries
- `--yes` flag added to `setup-security.sh` (real, gates each `read`) and `install-statusline.sh` (semantic no-op for symmetry)
- `scripts/tests/test-install-tui.sh` hermetic test (target ≥15 assertions covering TUI rendering, key handling, no-TTY fallback, --yes path, --dry-run, --force)
- `manifest.json` registers new lib files under `files.libs[]`
- README + `docs/INSTALL.md` updated: one canonical command at top, advanced per-component scripts documented below

**Addresses (REQ-IDs candidates):**

- TUI-01..06: TUI rendering, navigation, confirmation, fallback, dry-run, --force
- DET-01..04: centralized detection (toolkit / sp+gsd / security / rtk+statusline)
- DISPATCH-01..03: subprocess dispatch with --yes flag rollout, order-of-operations contract, failure handling
- BACKCOMPAT-01: existing init-claude.sh URL keeps working unchanged

**Avoids (pitfall mapping):**

- Pitfall 1, 2 (TUI raw-mode + tty discipline) → trap-before-raw + `TK_TUI_TTY_SRC` seam
- Pitfall 3 (Bash 3.2) → CI gate + verified pattern
- Pitfall 4 (cc-safety-net detection) → `command -v` not path-scan
- Pitfall 7 (BOOTSTRAP-01..04 regression) → existing test-bootstrap.sh kept green; bootstrap.sh stays as no-TTY fallback

### Phase 25: Marketplace Publishing + Claude Desktop Reach

**Rationale:** Depends on Anthropic marketplace spec verification (external). Must do skill-Desktop-safety audit first to bound `tk-skills` scope. Can run in parallel with late Phase 24 if desired but separate ROADMAP entry.

**Delivers:**

- `.claude-plugin/marketplace.json` with three sub-plugins
- `plugins/{tk-skills,tk-commands,tk-framework-rules}/.claude-plugin/plugin.json` + content directories
- `scripts/validate-skills-desktop.sh` — CI gate scanning skill markdown for Code-only assumptions
- `docs/CLAUDE_DESKTOP.md` — honest capability matrix (what works in Code tab vs blocked in remote/Chat)
- `--skills-only` flag on `install.sh` (skills land at `~/.claude/plugins/` for Desktop-only users)
- README + `docs/INSTALL.md` gain marketplace install path alongside curl-bash

**Addresses (REQ-IDs candidates):**

- MKT-01..05: marketplace.json, plugin.json schema, sub-plugin layout, schema validation, install instructions
- DESK-01..04: capability matrix doc, skill safety audit, Desktop user routing, validate-skills-desktop CI gate
- BACKCOMPAT-02: marketplace channel coexists with curl-bash (no double-install collision)

**Avoids (pitfall mapping):**

- Pitfall 5 (marketplace schema drift) → live CLI validation
- Pitfall 6 (skill Desktop safety) → audit + CI gate

### Phase Ordering Rationale

- Phase 24 first because: zero external blockers, fast win for existing users, validates new lib conventions before Phase 25 builds on them.
- Phase 25 can begin DESK-04 audit in parallel with late Phase 24 work (independent file surface).
- Both phases ship under v4.5 as a single milestone.

### Research Flags

**Phase 24 — no further research needed.** TUI pattern fully documented in STACK.md with live-tested code; detection signals are standard POSIX; dispatch order rationale in ARCHITECTURE.md.

**Phase 25 — verify at planning time (not user decisions; just code/CLI reads):**

- Confirm `.claude-plugin/marketplace.json` schema against latest Anthropic docs (spec may evolve between research date 2026-04-29 and planning date)
- Run `claude plugin marketplace add` against the in-repo manifest to verify schema acceptance before merging
- Enumerate `setup-security.sh` `read -r -p` blocks before writing `--yes` gate (count likely 3–5)
- DESK-04 skill audit: count of skills passing Desktop-safety gate determines `tk-skills` final size

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (TUI pattern) | HIGH | Live-tested on macOS Bash 3.2.57 |
| Stack (marketplace schema) | HIGH | Pinned to Anthropic docs fetched 2026-04-29 |
| Features | HIGH | Codebase + rustup + blurayne reference; well-understood domain |
| Architecture | HIGH | All contracts derived from existing v4.4 code; integration plan verified end-to-end |
| Pitfalls | HIGH | 18 concrete pitfalls each with prevention control + phase assignment |
| Desktop-runtime delta | MEDIUM-HIGH | Anthropic docs + GitHub issue #52147 + community confirmation; no formal compatibility matrix exists |

**Overall confidence:** HIGH for Phase 24, MEDIUM-HIGH for Phase 25 (gated on marketplace spec re-verification at planning time).

### Gaps to Address

- **Marketplace command path namespacing** — does Anthropic CLI namespace sub-plugin command files (so `tk-commands` doesn't collide with `commands/` from other plugins)? Verify at Phase 25 planning time via live `claude plugin install` test.
- **Skill audit count** — DESK-04 audit will determine how many existing skills are Desktop-safe. If <4 pass, Phase 25 scope rebalances toward `tk-commands` + `tk-framework-rules`.
- **CI smoke test for marketplace** — `claude` CLI not in GitHub Actions ubuntu-latest base. Either install at job start (extra time + flakiness) or gate marketplace tests behind opt-in env var.

## Sources

### Primary (HIGH confidence)

- Anthropic Claude Code docs `code.claude.com/docs/en/plugin-marketplaces` (fetched 2026-04-29) — marketplace schema
- Anthropic Claude Code docs `code.claude.com/docs/en/plugins-reference` (fetched 2026-04-29) — plugin.json schema
- Anthropic Claude Code docs `code.claude.com/docs/en/desktop` (fetched 2026-04-29) — Desktop runtime parity
- Live `bash --version` on macOS 25 (Apple Silicon) — Bash 3.2.57 confirmed
- `scripts/lib/bootstrap.sh` (v4.4 BOOTSTRAP-01..04) — `< /dev/tty` + fail-closed N pattern
- `scripts/tests/test-bootstrap.sh` — 26-assertion regression oracle to preserve

### Secondary (MEDIUM confidence)

- GitHub issue claude-plugins-official#52147 — Desktop blocks `/plugin marketplace add ./local-dir`
- `forrestchang/andrej-karpathy-skills` (83K stars) — cherry-picked Surgical Changes pattern as v4.1 precedent
- `rustup-init.sh` UX patterns — TUI feature taxonomy reference

### Tertiary (LOW confidence)

- "Some TK skills embed Bash" assertion — needs DESK-04 audit to confirm scope. Different researchers gave conflicting estimates of how many skills require auditing.

---
*Research completed: 2026-04-29*
*Ready for roadmap: yes*
