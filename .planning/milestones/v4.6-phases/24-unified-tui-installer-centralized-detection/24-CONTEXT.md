# Phase 24: Unified TUI Installer + Centralized Detection - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a single `scripts/install.sh` orchestrator that:

1. Sources three new shared libs (`scripts/lib/{tui,detect2,dispatch}.sh`)
2. Renders a Bash 3.2-compatible arrow/space/enter TUI checklist of components
3. Pre-checks uninstalled components, marks installed ones `[installed ✓]`
4. Confirms (`Install N component(s)? [y/N]`), then dispatches per-component installers in canonical order
5. Prints a per-component status summary

The new entry point is **additive** — `scripts/init-claude.sh` URL stays byte-identical; the v4.4 BOOTSTRAP-01..04 contract and 26-assertion `test-bootstrap.sh` stay green throughout.

The libs (`tui.sh`, `detect2.sh`, `dispatch.sh`) are designed for reuse by Phase 25 (MCP selector) and Phase 26 (Skills selector) — they are the foundation, not single-use.

**In scope:** TUI rendering, centralized `is_<name>_installed` detection v2, per-component dispatchers, `install.sh` entry, `--yes`/`--no-color`/`--dry-run`/`--force`/`--fail-fast` flags, `--yes` flag added to `setup-security.sh` (active) and `install-statusline.sh` (no-op for symmetry), backwards-compat preservation.

**Out of scope (deferred to later phases or excluded):** MCP catalog (Phase 25), Skills catalog (Phase 26), live progress bars (TUI-FUT-01), `--preset` bundles (TUI-FUT-02), TUI section grouping for MCPs/Skills (Phase 25-26 build on the precedent set here).

</domain>

<decisions>
## Implementation Decisions

User explicitly delegated all gray-area calls in `discuss-phase` ("сам принимай самые лучшие решения"). Every decision below is **Claude's Discretion**, locked in for downstream agents to implement without re-asking. Rationale stated so the planner can re-open if a constraint emerges during research.

### Item ordering & TUI grouping

- **D-01:** TUI renders **grouped sections** with section headers, not a flat list. Three groups in fixed order:
  - **Bootstrap** — `superpowers`, `get-shit-done`
  - **Core** — `toolkit`
  - **Optional** — `security`, `rtk`, `statusline`
  - Rationale: SP/GSD have a different lifecycle (canonical upstream installers, not TK-owned); toolkit is the load-bearing TK install; security/rtk/statusline are addons. Grouping makes the install map self-explanatory and sets a precedent for Phase 25 (MCPs group) + Phase 26 (Skills group).
- **D-02:** Section headers render as a non-selectable, dimmed (or bold-only on `NO_COLOR`) row above their items. They do not occupy a checkbox slot.
- **D-03:** Within each group, items render in the canonical dispatch order (DISPATCH-01: SP → GSD; toolkit; security → RTK → statusline). Already-installed items stay in place (do not float to bottom) — preserves a stable visual map across runs.

### SP/GSD placement (TUI vs separate bootstrap step)

- **D-04:** SP/GSD live in the **same TUI** as TK components, in the Bootstrap group at the top. **Single confirmation point**, single render pass. Rationale: BACKCOMPAT-01 says `bootstrap.sh` becomes the **no-TTY fallback** for SP/GSD prompts only — the TUI replaces the interactive layer above it. Two TUI pages would re-introduce the multi-prompt flow we are explicitly deleting.
- **D-05:** When `/dev/tty` is unavailable (CI, piped install) and `--yes` is **not** passed, `install.sh` falls back to the existing `bootstrap.sh` `read -r -p < /dev/tty` flow for SP/GSD only — **identical** to current v4.4 behavior. TK components fall back to "install nothing, exit 0" (fail-closed, see D-09).
- **D-06:** When `--yes` is passed, the TUI is bypassed entirely; `install.sh` synthesizes the default-set (D-15) and dispatches in canonical order. No `bootstrap.sh` invocation needed because `--yes` already authorized the install.
- **D-07:** `bootstrap.sh` library is **not deleted or rewritten** in this phase — it stays as the no-TTY fallback. Phase 24 only adds new code paths; no v4.4 lib internals change.

### Failure handling default

- **D-08:** Default behavior on per-component failure: **continue-on-error**. Subsequent components still run; the failure is recorded and surfaced in the summary. Rationale: 5+ components in one run; a transient network failure on one should not abort the rest. Mirrors `update-claude.sh` resilient pattern.
- **D-09:** `--fail-fast` flag opts into stop-on-first-failure for CI use. Exit code reflects the failed component's exit code.
- **D-10:** Per-component status states: `installed ✓` (success), `skipped` (already installed without `--force`), `failed (exit N)` (dispatcher returned non-zero), `unknown` (no detection probe ran — reserved for Phase 25 MCP `claude` CLI absence).
- **D-11:** "Fail-closed default" applies to TWO TTY-absence cases: (a) `/dev/tty` unavailable and `--yes` not passed → exit 0 with "no-TTY, run with `--yes` for non-interactive install" message; (b) `read` from `TK_TUI_TTY_SRC` returns EOF → cancel, restore terminal, exit 0. Never silently install without explicit confirmation.

### --yes default-set semantics

- **D-12:** `--yes` default-set = **"all uninstalled components, in canonical dispatch order"**. Matches the TUI pre-check logic: a TUI user would see exactly these items pre-checked. `--yes` is "accept TUI defaults non-interactively", not "install everything".
- **D-13:** Already-installed components are **skipped** under `--yes` (status `skipped`). To re-run them, user passes `--yes --force`.
- **D-14:** `--yes --force` re-runs every component regardless of detection. Component dispatchers respect `--force` per their own contracts (existing `init-claude.sh --force`, etc.).
- **D-15:** No `--preset` flag in v4.6 — TUI-FUT-02 deferred. `--yes` is the single non-interactive entry; `--yes --force` is the only "install everything" surface.

### Selection visual + key bindings

- **D-16:** Selection indicator: **arrow `▶` prefix on the focused row**, not reverse video. Rationale: reverse-video renders unpredictably under tmux/screen with non-default color schemes; the arrow is unambiguous on every terminal that handles the rest of the TUI.
- **D-17:** Checkbox glyphs: `[ ]` (unchecked), `[x]` (checked), `[installed ✓]` (replaces checkbox for already-installed items per TUI-04).
- **D-18:** Key bindings: `↑`/`↓` move, `space` toggle, `enter` confirm, `q` or `Ctrl-C` cancel. **No vim-style `j`/`k`** in v4.6 — keep the surface minimal; doc-friendly; one canonical scheme.
- **D-19:** Help line at the bottom of the TUI: `↑↓ move · space toggle · enter confirm · q quit`. Always shown — discoverability over screen real estate.
- **D-20:** Description text (TUI-04 "optional description on focused row") renders on a **single dimmed line below the help line**, updated on focus change. No multi-line descriptions in v4.6.

### Detection v2 (`scripts/lib/detect2.sh`)

- **D-21:** `detect2.sh` **sources** `scripts/detect.sh` at the top — does not duplicate SP/GSD logic (DET-01). Adds these new functions only:
  - `is_superpowers_installed` — wraps `HAS_SP` from sourced `detect.sh`
  - `is_gsd_installed` — wraps `HAS_GSD`
  - `is_toolkit_installed` — `[ -f "$HOME/.claude/toolkit-install.json" ]` (DET-05)
  - `is_security_installed` — `command -v cc-safety-net` AND grep `cc-safety-net` in `~/.claude/hooks/pre-bash.sh` OR `~/.claude/settings.json` (DET-02 — fixes v4.4 brew-install miss)
  - `is_rtk_installed` — `command -v rtk` (DET-04)
  - `is_statusline_installed` — `[ -f "$HOME/.claude/statusline.sh" ]` AND grep `statusLine` in `~/.claude/settings.json` (DET-03)
- **D-22:** Each `is_*_installed` returns 0 (installed) or 1 (not installed). No third "unknown" state for the v4.6 component set — that's introduced by Phase 25 for MCPs (`claude` CLI absence).
- **D-23:** Detection runs **once at startup**, results cached in shell vars (`IS_TOOLKIT=`, `IS_SECURITY=`, etc.). TUI reads cache; dispatch re-checks before invoking each dispatcher (cheap re-probe, catches mid-run drift).

### Dispatch (`scripts/lib/dispatch.sh`)

- **D-24:** Each dispatcher invokes its existing per-component script as `bash -c` subprocess via curl-pipe (matching the project's distribution model) when `install.sh` is run via `curl | bash`, or via local path when run from clone. Detection of the run mode: `[[ "${BASH_SOURCE[0]}" == /dev/fd/* || "${0}" == bash ]]` for curl-pipe; otherwise local.
- **D-25:** Dispatcher contract: `dispatch_<name> [--force] [--dry-run] [--yes]` — flags pass through to the underlying script. Each dispatcher returns the script's exit code unchanged.
- **D-26:** `setup-security.sh` learns a real `--yes` flag that gates the existing interactive `read -r -p` blocks with safe defaults (DISPATCH-02). `install-statusline.sh` accepts `--yes` as a no-op (DISPATCH-02 semantic symmetry — the script is already non-interactive). `init-claude.sh` already non-interactive; no flag added.

### Post-install summary

- **D-27:** Summary uses **the existing `dro_*` chezmoi-grade output API** (`scripts/lib/dry-run-output.sh`, UX-01 precedent). New helpers added if needed:
  - `dro_print_install_status <component> <state>` (`installed ✓`, `skipped`, `failed (exit N)`)
  - Trailing total line: `Installed: N · Skipped: M · Failed: K`
- **D-28:** Failed components surface their dispatcher's last 5 lines of stderr in the summary (truncated), so users can see why without re-running. Captured via `bash -c '... 2>&1' | tee` to a per-component temp file.
- **D-29:** Exit code: 0 if no failures (or `--fail-fast` not triggered), 1 if any failure occurred (matches POSIX convention; CI gate-friendly).

### Backwards compatibility

- **D-30:** `init-claude.sh` URL is the v4.4 contract surface — **not modified by Phase 24**. `install.sh` is a parallel new entry point. The 26-assertion `test-bootstrap.sh` runs unchanged in CI throughout this phase; any TUI-related test goes into the new `test-install-tui.sh` ≥15 assertions (TUI-07).
- **D-31:** All v4.4 flags preserved on `init-claude.sh`: `--no-bootstrap`, `--no-banner`, `TK_NO_BOOTSTRAP`, `NO_BANNER`. New `install.sh` adopts the same flag names where applicable (`--no-banner` for summary suppression; `TK_NO_BOOTSTRAP` honored when `install.sh` falls back to `bootstrap.sh` for SP/GSD).
- **D-32:** No deprecation warning on `init-claude.sh`. Both entry points coexist indefinitely (REQUIREMENTS.md "backwards-compat shim... not scheduled" confirms).

### Test seam pattern

- **D-33:** `TK_TUI_TTY_SRC` mirrors the v4.4 `TK_BOOTSTRAP_TTY_SRC` test seam shape exactly — fixture file path with pre-recorded keystrokes; `install.sh` reads via `< "${TK_TUI_TTY_SRC:-/dev/tty}"`. Test fixture format: one keystroke per line, raw bytes for special keys (e.g., `$'\e[A'` for ↑).
- **D-34:** `test-install-tui.sh` covers (≥15 assertions): keystroke injection (↑↓ space enter q Ctrl-C), `--yes` non-interactive default-set, `--dry-run` zero-mutation, `--force` re-runs detected components, `--fail-fast` stops on first failure, no-TTY fallback, terminal-restore on Ctrl-C mid-render.

### Claude's Discretion

User delegated all decisions wholesale. Items above are locked. The planner has flexibility to refine the following without re-discussion:

- Exact ANSI sequences for arrow / dim / bold rendering (research the most portable forms; Bash 3.2 only).
- `dro_print_install_status` exact column widths and color choices.
- Whether `dispatch_<name>` is a function in `dispatch.sh` or a separate `scripts/dispatch/<name>.sh` file (function preferred, single-file lib stays cohesive).
- Help line placement (top vs bottom of TUI viewport) — choose what looks right after first render test.
- Whether keystroke-buffer flushing requires a `read -t 0.001` between keys on macOS Bash 3.2 (research; precedent in `bash-tui` patterns).
- Stderr-tail length in failure summary (5 lines is a starting point; tune if too noisy).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 24 requirements + scope

- `.planning/REQUIREMENTS.md` §"Phase 24 — Unified TUI Installer + Centralized Detection" — TUI-01..07, DET-01..05, DISPATCH-01..03, BACKCOMPAT-01 (16 REQ-IDs)
- `.planning/ROADMAP.md` §"Phase 24" — 5 success criteria (TUI within 2s, pre-check logic, Ctrl-C restore, `--yes` non-interactive, byte-identical `init-claude.sh` URL)
- `.planning/PROJECT.md` §"Constraints" — Bash 3.2 macOS BSD compat, `< /dev/tty` semantics, `make check` quality gate

### Existing code to source / reuse / extend

- `scripts/detect.sh` — DET-01 sources this (HAS_SP / HAS_GSD / SP_VERSION / GSD_VERSION exports)
- `scripts/lib/bootstrap.sh` — D-04/D-05 pattern reference: `< /dev/tty` + `TK_BOOTSTRAP_TTY_SRC` test seam, fail-closed N on EOF, color guards `[[ -z "${RED:-}" ]]`
- `scripts/lib/dry-run-output.sh` — D-27 chezmoi-grade output API (`dro_init_colors`, `dro_print_header`, `dro_print_file`, `dro_print_total`)
- `scripts/lib/optional-plugins.sh` §18-19 — D-04 `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` canonical install command constants
- `scripts/init-claude.sh` — D-30 contract surface that stays unchanged; flag-parsing pattern reference
- `scripts/setup-security.sh` — D-26 target for new active `--yes` flag
- `scripts/install-statusline.sh` — D-26 target for `--yes` no-op stub
- `scripts/uninstall.sh` §71-74 — log helper shape (`log_info` / `log_warning`) for consistency

### Tests that must stay green throughout

- `scripts/tests/test-bootstrap.sh` — 26-assertion v4.4 BOOTSTRAP contract (BACKCOMPAT-01 invariant)
- `scripts/tests/test-install-banner.sh` — 7-assertion banner symmetry across init-claude / init-local / update-claude (Phase 23 BANNER-01)
- `scripts/tests/test-update-libs.sh` — 15-assertion smart-update over `scripts/lib/*.sh` (Phase 22 LIB-01/02; new `tui.sh`/`detect2.sh`/`dispatch.sh` should auto-discover via existing `files.libs[]` jq path)

### Distribution + manifest

- `manifest.json` §`files.libs[]` — D-26 LIB-01 contract: new `tui.sh`/`detect2.sh`/`dispatch.sh` entries added here for `update-claude.sh` auto-discovery
- `manifest.json` §`files.scripts[]` — `install.sh` entry added here

### Documentation surface

- `docs/INSTALL.md` §"Installer Flags" — D-31 documents `--yes`/`--no-color`/`--dry-run`/`--force`/`--fail-fast` for the new `install.sh` entry alongside the existing `init-claude.sh` flags

### Standards

- [no-color.org](https://no-color.org) — D-19/TUI-06 `${NO_COLOR+x}` honor contract

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`scripts/detect.sh`** (126 lines) — exports `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` after sourcing. `detect2.sh` sources this and wraps. Don't duplicate SP/GSD probes.
- **`scripts/lib/bootstrap.sh`** — `_bootstrap_log_info` / `_bootstrap_log_warning` helpers, `< /dev/tty` pattern, `TK_BOOTSTRAP_TTY_SRC` test seam shape that `TK_TUI_TTY_SRC` will mirror exactly.
- **`scripts/lib/dry-run-output.sh`** (`dro_*` API) — chezmoi-grade output for the post-install summary. Add `dro_print_install_status` helper rather than building a parallel reporter.
- **`scripts/lib/optional-plugins.sh`** — `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` canonical commands; reuse for SP/GSD dispatchers (D-04).
- **`scripts/uninstall.sh`** §389 idempotency guard — `[[ ! -f "$STATE_FILE" ]]` early-exit pattern; reusable for `is_toolkit_installed`-driven skip logic in dispatchers.

### Established Patterns

- **Color guards** — `[[ -z "${RED:-}" ]] && RED='\033[0;31m'` (every lib re-applies; never assumes caller didn't set them). `tui.sh` follows the same idiom.
- **`set -euo pipefail`** in scripts; **never** in sourced libs (must not alter caller error mode). `tui.sh`/`detect2.sh`/`dispatch.sh` are sourced libs → no errexit.
- **Test seam shape** — `TK_<FEATURE>_<INPUT>_SRC` env var overrides hardcoded path; defaults to canonical path when unset. v4.4 BOOTSTRAP-01 establishes this for every new TTY-reading lib.
- **Per-feature manifest registration** — `manifest.json` `files.libs[]` auto-discovered by `update-claude.sh` jq path (Phase 22 LIB-01 D-07 zero-special-casing). New libs slot in with zero update-claude.sh changes.
- **Hermetic test pattern** — `scripts/tests/test-*.sh` self-contained Bash, exits non-zero on assertion fail, wired into Makefile + `.github/workflows/quality.yml`. `test-install-tui.sh` follows same shape.
- **Chezmoi-grade dry-run output** (UX-01) — `[+ INSTALL]` / `[~ UPDATE]` / `[- SKIP]` / `[- REMOVE]` 4-group format. Post-install summary extends this pattern with install-status equivalents (D-27).

### Integration Points

- **`scripts/install.sh` (new top-level)** — sources `lib/{tui,detect2,dispatch}.sh`; not a trampoline — owns the orchestration loop (DISPATCH-03).
- **`manifest.json`** — new `tui.sh`/`detect2.sh`/`dispatch.sh` rows under `files.libs[]`; new `install.sh` row under `files.scripts[]`. Atomic version bump to 4.6.0 in this phase or deferred to Phase 27 distribution phase (planner decides).
- **`Makefile`** — new `Test 31` target for `test-install-tui.sh`; CI step renamed `Tests 21-30` → `Tests 21-31`.
- **`.github/workflows/quality.yml`** — same as Makefile; mirror the new test in CI.
- **`docs/INSTALL.md`** — add `## install.sh (unified entry, v4.6+)` section alongside existing `init-claude.sh` docs.

</code_context>

<specifics>
## Specific Ideas

User's discretion-mode response set the tone: **prefer minimal, conventional, well-precedented choices** over novel ones. Concrete preferences this implies:

- TUI feel should match `git add -i` / `lazygit` aesthetic — readable, no flashy animations, works over SSH.
- Reuse existing libs (`dro_*`, `bootstrap.sh` shape, `detect.sh`) wherever possible — every new mechanism is an audit liability.
- Single canonical key scheme; doc-line always visible; no clever hidden bindings.
- Resilient over loud — keep going on per-component failure unless explicitly told otherwise (`--fail-fast`).
- CI-friendly — `--yes` does the obvious thing (install all uninstalled), exit codes match POSIX convention.

</specifics>

<deferred>
## Deferred Ideas

Out of Phase 24 scope; tracked for later.

- **Vim-style `j`/`k`** key bindings — TUI-FUT-04 (new). Add only if user demand surfaces.
- **Multi-line item descriptions** — single-line in v4.6; multi-line is a TUI v2 feature.
- **Live progress bars** — TUI-FUT-01 already in REQUIREMENTS.md "Future Requirements".
- **`--preset minimal|full|dev`** bundles — TUI-FUT-02 already deferred.
- **Grouped MCPs/Skills sections in TUI** — Phase 25/26 build on this group precedent; their groups land in those phases, not 24.
- **Auto-bump `manifest.json` version to 4.6.0** in Phase 24 — defer to Phase 27 distribution phase (single atomic bump for the whole milestone, matches v4.4 precedent).
- **TUI section search / filter** (`/` to filter long lists) — irrelevant for 6-item list; revisit when MCP catalog (9 items) + Skills catalog (22 items) ship in 25/26.
- **Localize TUI text** — English-only in v4.6; localization deferred indefinitely (the toolkit's CI tooling is English-first, see `cheatsheets/` precedent).

</deferred>

---

*Phase: 24-unified-tui-installer-centralized-detection*
*Context gathered: 2026-04-29*
