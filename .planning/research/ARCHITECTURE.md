# Architecture Research — v4.5 (TUI Installer + Marketplace)

**Domain:** CLI toolkit installer meta-orchestration + Claude Code plugin marketplace publishing
**Researched:** 2026-04-29
**Confidence:** HIGH (direct codebase analysis; no external sources needed for integration questions)

---

## Standard Architecture

### v4.5 Layer Cake (updated from v4.0 diagram)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Layer 0 — TUI Meta-Installer  (NEW in v4.5)                                 │
│  scripts/install.sh                                                          │
│  Checklist UI over /dev/tty; detects installed components; dispatches to    │
│  per-component scripts via flag-passing. Falls through to no-tty if no TTY. │
└────────────────────────────────┬─────────────────────────────────────────────┘
                                 │  calls scripts with flags
                    ┌────────────┼────────────┐────────────────────┐
                    ▼            ▼            ▼                    ▼
┌───────────────────────┐ ┌───────────┐ ┌──────────────┐ ┌───────────────────┐
│  scripts/init-claude  │ │setup-sec  │ │install-status│ │ (rtk / council    │
│  (or init-local.sh)   │ │  urity.sh │ │    line.sh   │ │  advice messages) │
└───────────────────────┘ └───────────┘ └──────────────┘ └───────────────────┘
          │                    │
          ▼                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Layer 1 — Shared Library  scripts/lib/                                       │
│  bootstrap.sh   detect.sh   install.sh   state.sh   backup.sh               │
│  dry-run-output.sh   optional-plugins.sh   [NEW: tui.sh]  [NEW: detect2.sh] │
└──────────────────────────────────────────────────────────────────────────────┘
          │                    │
          ▼                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Layer 2 — Manifest + Content  (unchanged)                                    │
│  manifest.json   templates/   commands/   skills/   cheatsheets/             │
│  [NEW: marketplace.json]   [NEW: plugins/tk-skills/  tk-commands/            │
│                                           tk-framework-rules/ ]              │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Layer 3 — State  (unchanged)                                                 │
│  ~/.claude/toolkit-install.json  (SHA256-classified, per-project)            │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Question 1: TUI Dispatcher Integration

### 1a. Placement in the Layer Cake

`scripts/install.sh` sits ABOVE all per-component scripts as a pure orchestrator.
This placement is correct for three reasons:

1. It introduces zero new install logic — it only calls scripts that already exist.
2. Per-component scripts remain fully runnable standalone (backwards compat surface unchanged).
3. The TUI reads from `/dev/tty` and writes to stdout/stderr — the same contract already
   established by `bootstrap.sh`, `uninstall.sh [y/N/d]`, and `init-claude.sh select_framework`.

`scripts/install.sh` is NOT added to `manifest.json files.scripts[]`. It is a developer-facing
entrypoint, not a toolkit file installed into user projects. (Compare: `uninstall.sh` IS in
`manifest.json` because it lives in `.claude/scripts/` after install. `install.sh` never does.)

### 1b. New vs Sourced Functions

`scripts/install.sh` should source two new lib files and the existing ones:

```
sources from scripts/lib/:
  tui.sh          (NEW) — pure-bash checklist renderer + input loop
  detect2.sh      (NEW) — is_<component>_installed() probes (see 1c below)
  optional-plugins.sh   (EXISTING) — TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD constants
  dry-run-output.sh     (EXISTING) — dro_* helpers (--dry-run output)
```

`install.sh` itself owns only:
- Argument parsing (`--yes`, `--force`, `--no-bootstrap`, `--dry-run`, `--skills-only`)
- Dispatch logic: map checklist selection → script invocation
- Order-of-operations sequencing (see 1e)
- Top-level error collection and summary

`tui.sh` owns:
- `tui_checklist <items_array>` — renders the checklist, returns a bitfield/array of selections
- `tui_is_tty` — `[ -e /dev/tty ] && [ -t 0 ]` gate
- Color helpers (re-use existing RED/GREEN/YELLOW/NC constants via guard pattern)

`detect2.sh` owns:
- `is_toolkit_installed` — `[ -f "$CLAUDE_DIR/toolkit-install.json" ]`
- `is_security_installed` — `command -v cc-safety-net` (covers both brew and npm, NOT just npm)
- `is_statusline_installed` — `[ -f "$HOME/.claude/statusline.sh" ] && grep -q statusLine "$HOME/.claude/settings.json" 2>/dev/null`
- `is_rtk_installed` — `command -v rtk`
- `is_sp_installed` — delegates to `detect.sh::detect_superpowers` (re-use, do not duplicate)
- `is_gsd_installed` — delegates to `detect.sh::detect_gsd` (re-use)

The existing `detect.sh` is NOT replaced. `detect2.sh` is an extension that adds the four new
component probes. It sources `detect.sh` internally so all signals are available in one place.
New name avoids retroactive breakage of callers (init-claude.sh, update-claude.sh) that already
source `detect.sh` directly.

### 1c. Centralized Detection — Corrected Signals

Current signals that need correction:

| Component | Current (broken/partial) | Corrected |
|-----------|--------------------------|-----------|
| cc-safety-net | `setup-security.sh` checks `command -v cc-safety-net` but that already works for brew+npm; the issue is `install.sh` had no probe at all | Add `is_security_installed` in `detect2.sh` using `command -v cc-safety-net` |
| statusline | No probe exists anywhere | `[ -f "$HOME/.claude/statusline.sh" ] && grep -q "statusLine" "$HOME/.claude/settings.json"` |
| RTK | No probe exists | `command -v rtk` |
| SP | `detect.sh::detect_superpowers` — already correct (v4.1 DETECT-06) | Delegate |
| GSD | `detect.sh::detect_gsd` — already correct | Delegate |
| Toolkit | `[ -f "$STATE_FILE" ]` in init scripts | `is_toolkit_installed` delegates to same check |

Note: statusline detection requires BOTH the script AND the settings key. The script alone is
insufficient — statusline only works when `settings.json` has the `statusLine` configuration.

### 1d. TUI State → Script Flag Mapping

The TUI checklist presents 6 items. Each maps to a script invocation:

```
Checklist item         Script called                      Flag(s) added
─────────────────────  ──────────────────────────────     ──────────────────
[ ] Toolkit (base)     scripts/init-claude.sh             --mode <detected> [--framework <f>]
                       (or init-local.sh in clone mode)
[ ] superpowers        eval "$TK_SP_INSTALL_CMD"          (no wrapper needed)
[ ] get-shit-done      eval "$TK_GSD_INSTALL_CMD"         (no wrapper needed)
[ ] Security Pack      scripts/setup-security.sh          --yes    ← NEW FLAG NEEDED
[ ] RTK                advice message only                (not installable via script)
[ ] Statusline         scripts/install-statusline.sh      --yes    ← NEW FLAG NEEDED
```

Flag additions required on existing scripts:

**`scripts/setup-security.sh` needs `--yes`**

Current behavior: interactive y/N prompts throughout (Step 1 CLAUDE.md merge, Step 3 hook config).
With `--yes`: skip all prompts, use defaults everywhere.
Implementation: `YES=${YES:-0}` at top, `--yes` sets `YES=1`.
All `read -r -p "..." < /dev/tty` blocks gated: `if [[ $YES -eq 1 ]]; then ... fi`.

**`scripts/install-statusline.sh` needs `--yes`**

Current behavior: prints errors and exits on macOS/jq/token checks; no interactive prompts
(the script is already mostly non-interactive). The only prompt is implicit: it installs without
asking. With `--yes`: already effectively non-interactive. The `--yes` flag is still needed for
semantic symmetry and for test seams that need to know the caller is unattended.
Implementation: `YES=${YES:-0}`, accepted but currently a no-op; reserved for future prompt additions.

**`scripts/init-claude.sh` already has non-interactive fallback** (mode auto-detected when no TTY).
No new flag needed for the dispatch case. The TUI pre-selects the framework and passes it as a
positional argument: `bash init-claude.sh $FRAMEWORK --mode $MODE --no-bootstrap`.
`--no-bootstrap` is required because `install.sh` handles SP/GSD itself (bootstrap step comes
BEFORE toolkit install in the order-of-operations contract — see 1e).

### 1e. Order-of-Operations Contract

```
Step 1: SP install (if selected and not already installed)
Step 2: GSD install (if selected and not already installed)
Step 3: Re-run detect.sh  ← post-bootstrap re-source (mirrors bootstrap.sh BOOTSTRAP-03)
Step 4: Toolkit install   ← init-claude.sh with --no-bootstrap (avoids double-prompt)
                            Passes detected mode based on Step 3 result
Step 5: Security Pack     ← setup-security.sh --yes
Step 6: RTK               ← print install instructions only (not scriptable)
Step 7: Statusline        ← install-statusline.sh --yes (macOS only; skip on Linux)
```

Rationale for this order:

- **SP/GSD before toolkit (Steps 1-3 before 4):** `init-claude.sh` reads detection state to
  choose install mode. If toolkit installs first then SP installs, the mode is wrong (standalone
  instead of complement-full). Re-running update-claude.sh would correct it but that is bad UX.
  Bootstrap must run with SP/GSD already present.

- **Toolkit before Security (Step 4 before 5):** `setup-security.sh` modifies `~/.claude/CLAUDE.md`
  and `~/.claude/settings.json`. These are global, not per-project. No dependency on the toolkit
  files in `.claude/`. Can technically run in parallel, but sequential is simpler and the extra
  5 seconds is not a UX problem.

- **Security before RTK/Statusline (Step 5 before 6-7):** Convention only. No hard dependency.

- **RTK is advice-only (Step 6):** RTK is installed via `brew` or `cargo`. There is no
  `curl | bash` equivalent that TUI can invoke safely. Print the install command, do not attempt
  to run it. This avoids brew prompts mid-TUI-flow.

- **Statusline last (Step 7):** macOS-only. Silently skipped on Linux (`uname != Darwin`).
  Relies on `settings.json` written by Step 5, so must run after Security.

### 1f. Failure Handling

Model: **continue-with-remaining**. Each step is non-fatal. Collect results and summarize.

```bash
# In install.sh dispatch loop:
declare -A STEP_RESULTS  # "ok" | "skipped" | "failed: <reason>"

run_step() {
    local name="$1" cmd="$2"
    local rc=0
    eval "$cmd" || rc=$?
    if [[ $rc -eq 0 ]]; then
        STEP_RESULTS["$name"]="ok"
    else
        STEP_RESULTS["$name"]="failed: exit $rc"
    fi
}
```

After all steps, print a summary table:
```
  Toolkit     ✓ installed
  superpowers ✓ already installed
  Security    ✓ installed
  RTK         → install manually: brew install rtk && rtk init -g
  Statusline  ✗ failed (no OAuth token in Keychain — run: claude login)
```

Rationale: "abort on first failure" breaks the UX contract. A user who already has toolkit
installed wants security even if toolkit step reports "already installed" (which is exit 0).
The only exception is Step 3 (re-detect after SP/GSD): if this fails the mode for Step 4 is
wrong, so install.sh should warn and let user choose to proceed or abort.

### 1g. Test Seam — Hermetic TUI Testing

Existing pattern from `bootstrap.sh`: `TK_BOOTSTRAP_TTY_SRC` env var overrides the
`< /dev/tty` read target. The same pattern applies here.

```bash
# In tui.sh:
_tui_tty_src() { echo "${TK_TUI_TTY_SRC:-/dev/tty}"; }

tui_checklist() {
    ...
    read -r -p "$prompt" choice < "$(_tui_tty_src)" 2>/dev/null || choice=""
    ...
}
```

For tests, provide a file of pre-recorded keystrokes:
```bash
# test-install-tui.sh
echo -e " \n \n\n" > /tmp/fake_tty   # space=select, enter=confirm
TK_TUI_TTY_SRC=/tmp/fake_tty bash scripts/install.sh --dry-run
```

The `--yes` flag in `install.sh` bypasses TUI entirely (all items pre-selected to their
auto-detected defaults), enabling CI runs:
```bash
# CI: non-interactive full install
TK_NO_BOOTSTRAP=1 bash scripts/install.sh --yes --dry-run
```

### 1h. Backwards Compatibility — init-claude.sh vs install.sh

Recommendation: **model (b) — `init-claude.sh` stays primary; `install.sh` is an
orchestrating wrapper.**

Rationale:
- The existing curl URL (`bash <(curl -sSL .../scripts/init-claude.sh)`) is documented in
  README.md, INSTALL.md, all template CLAUDE.md files, and likely bookmarked/scripted by
  existing users. Invalidating it for a UX improvement is too high a cost.
- `install.sh` adds value for new users who want the single-command flow. Existing users who
  run `init-claude.sh` directly get the same behavior as before.
- Trampoline direction: `init-claude.sh` does NOT need to call `install.sh`. They are
  independent entry points at the same layer. `install.sh` calls `init-claude.sh` internally.

Concretely:
- `scripts/init-claude.sh`: unchanged URL, unchanged flag semantics, unchanged behavior.
- `scripts/install.sh`: new file, new URL (`bash <(curl -sSL .../scripts/install.sh)`),
  calls `init-claude.sh` (and other scripts) as sub-processes.

The v4.4 `bootstrap.sh` y/N flow is **retained as the no-TTY fallback**, not deprecated.
When `install.sh` detects no TTY (CI, piped), it skips the TUI and falls through to
`init-claude.sh` alone (which invokes bootstrap.sh internally as it does today).
`--no-bootstrap` is passed when `install.sh` has already handled SP/GSD installation.

---

## Question 2: Marketplace Integration with Existing Manifest

### 2a. Single Source of Truth: marketplace.json Derives from manifest.json

`marketplace.json` and `manifest.json` serve different audiences and different consumers:

| File | Audience | Consumer | Content Shape |
|------|----------|----------|---------------|
| `manifest.json` | TK install scripts | bash (`jq`) | Version, file paths, `conflicts_with`, `requires_base`, section names |
| `marketplace.json` | Claude Code platform | Anthropic plugin marketplace API | Plugin metadata: name, description, sub-plugins, schema per Anthropic spec |

They are NOT duplicates. `marketplace.json` does NOT list individual files. It declares plugin
bundles that point to sub-plugin directories. The sub-plugin directories reuse existing content
(symlinks or references to `skills/`, `commands/`, `templates/`).

The single source of truth relationship:
- `manifest.json` version field is canonical. `marketplace.json.version` must match it.
- A CI check (add to `make validate`) asserts: `jq -r .version manifest.json == jq -r .version marketplace.json`.
- File content lives in `skills/`, `commands/`, `templates/` — referenced by both.

### 2b. Sub-Plugin Physical Layout

```
<repo root>/
├── manifest.json            (existing — unchanged structure)
├── marketplace.json         (NEW — root-level)
├── plugins/                 (NEW directory)
│   ├── tk-skills/
│   │   ├── plugin.json      (sub-plugin metadata for marketplace)
│   │   └── (no file copies — symlinks or README pointing to skills/)
│   ├── tk-commands/
│   │   ├── plugin.json
│   │   └── (points to commands/)
│   └── tk-framework-rules/
│       ├── plugin.json
│       └── (points to templates/)
└── skills/                  (existing — unchanged)
└── commands/                (existing — unchanged)
└── templates/               (existing — unchanged)
```

Why `plugins/` directory rather than root-level sub-directories:
- Keeps the root clean (already has ~12 top-level items)
- Groups marketplace-specific metadata without polluting content directories
- `plugin.json` is the marketplace adapter; the actual content stays where it is

**tk-skills** (Desktop-compatible):
- Plugin.json lists: `skills/ai-models/SKILL.md`, `skills/api-design/SKILL.md`, `skills/database/SKILL.md`,
  `skills/docker/SKILL.md`, `skills/i18n/SKILL.md`, `skills/llm-patterns/SKILL.md`,
  `skills/observability/SKILL.md`, `skills/tailwind/SKILL.md`, `skills/testing/SKILL.md`
- Excludes: `skills/debugging/SKILL.md` (conflicts_with superpowers — skip for Desktop too)
- Desktop safety audit: each SKILL.md must be checked for Bash tool assumptions.
  Skills that assume Claude Code tools (Bash, Write, Edit) are Code-only.

**tk-commands** (Code-only):
- Plugin.json lists all `commands/*.md` entries minus those in `conflicts_with: ["superpowers"]`
- These are Claude Code slash commands — not usable in Desktop (no slash command support)

**tk-framework-rules** (Code-only):
- Plugin.json lists `templates/base/rules/` and `templates/*/rules/` directories
- Project-scoped rules are a Code-only concept (Desktop has no project context)

### 2c. Coexistence with curl-bash Flow

The marketplace publishing does NOT break the existing curl-bash install. They are completely
independent surfaces:

```
curl-bash path:
  bash <(curl -sSL .../scripts/init-claude.sh)
  bash <(curl -sSL .../scripts/install.sh)       ← new, additive
  → Reads manifest.json, downloads files to .claude/

Marketplace path:
  /plugin marketplace add sergei-aronsen/claude-code-toolkit
  → Reads marketplace.json, installs via Claude Code plugin system to ~/.claude/plugins/
```

No shared state, no shared file paths. Both can be used simultaneously on the same machine
(they write to different locations). The curl-bash path writes to `.claude/` (per-project).
The marketplace path writes to `~/.claude/plugins/` (global).

### 2d. Update Flow Integration

Two update surfaces remain independent:

```
curl-bash users:
  bash <(curl -sSL .../scripts/update-claude.sh)
  → Existing smart-merge logic (unchanged)

Marketplace users:
  /plugin update claude-code-toolkit
  → Anthropic handles versioning; no TK code involved
```

There is no need to synchronize these two paths. If a user installs via marketplace AND
via curl-bash, they have two installations. Documentation in `docs/CLAUDE_DESKTOP.md` should
clarify this and recommend one path per use case (curl-bash for Code users, marketplace for
Desktop-only users).

---

## Question 3: `--skills-only` Install Path

### 3a. Flag on install.sh, Not a New Script

Add `--skills-only` as a flag to `scripts/install.sh`, not a separate `install-skills.sh`.
Rationale: a new script creates a third curl URL to document and maintain. `install.sh` already
has the orchestration logic; `--skills-only` is just a filtered dispatch.

Behavior under `--skills-only`:
- Skips: Toolkit install, Security, Statusline, RTK advice
- Runs only: SP/GSD bootstrap prompts (optional, can be suppressed with `--no-bootstrap`),
  then skill file placement
- Target: `~/.claude/plugins/tk-skills/skills/` (global, not per-project)

### 3b. Skills Installation Target for Desktop Users

Desktop-safe skills land at: `~/.claude/plugins/tk-skills/skills/<name>/SKILL.md`

This mirrors how Claude Code plugin system structures skills under `~/.claude/plugins/`.
The marketplace path installs there automatically. The `--skills-only` flag does the same
thing manually (for users who prefer curl over the plugin marketplace).

### 3c. Desktop-Only User Detection

Detection logic in `install.sh` (and exposed as `is_claude_code_user` in `detect2.sh`):

```bash
is_claude_code_user() {
    command -v claude >/dev/null 2>&1
}
```

If `claude` CLI is absent from PATH, the user is Desktop-only (or hasn't installed Claude Code
yet). The TUI should show a simplified checklist in this case:
- Skip: Toolkit install (requires claude CLI)
- Skip: Security Pack (modifies `~/.claude/settings.json` via hooks — Code-only)
- Skip: Statusline (requires claude CLI for OAuth)
- Show: Skills only (Desktop-compatible)
- Show: RTK advice (optional, not Claude-CLI-dependent)

The absence of `claude` CLI is a soft heuristic: a user could have Claude Code installed but
`claude` not on PATH. The TUI should note this and offer a manual override.

---

## Question 4: Backwards Compatibility

### 4a. Existing init-claude.sh URL Stays Valid

Decision: init-claude.sh stays the primary single-script entry point. install.sh is additive.

```
Before v4.5:
  bash <(curl -sSL .../scripts/init-claude.sh)    # canonical
  bash setup-security.sh                           # separate
  bash install-statusline.sh                       # separate

After v4.5:
  bash <(curl -sSL .../scripts/init-claude.sh)    # still works, unchanged
  bash <(curl -sSL .../scripts/install.sh)        # NEW recommended for first-time users
```

`init-claude.sh` receives zero changes for backwards-compat reasons. Any new flags (if needed)
are additive. No existing flag semantics change.

### 4b. v4.4 bootstrap.sh y/N Flow

Status: **retained as fallback, superseded by TUI for interactive sessions**.

`bootstrap.sh::bootstrap_base_plugins()` is called by `init-claude.sh` today.
After v4.5, `install.sh` handles SP/GSD bootstrap via the TUI checklist and passes
`--no-bootstrap` when calling `init-claude.sh`. The `bootstrap.sh` function is still invoked
when the user calls `init-claude.sh` directly (i.e., NOT through `install.sh`).

Deprecation path:
- v4.5: bootstrap.sh retained, unchanged
- Future: If install.sh adoption is high, bootstrap.sh prompts could be marked "legacy" and
  eventually removed from init-claude.sh. Not in scope for v4.5.

---

## Component Diagram — v4.5

```
USER
 |
 |-- curl/.../scripts/install.sh  (NEW canonical entrypoint for v4.5)
 |       |
 |       |-- [no TTY]  →  scripts/init-claude.sh --no-bootstrap $FRAMEWORK $MODE
 |       |
 |       |-- [has TTY]
 |       |    |
 |       |    |-- sources: scripts/lib/tui.sh         (NEW)
 |       |    |-- sources: scripts/lib/detect2.sh     (NEW, sources detect.sh)
 |       |    |-- sources: scripts/lib/optional-plugins.sh  (existing)
 |       |    |-- sources: scripts/lib/dry-run-output.sh    (existing)
 |       |    |
 |       |    |-- renders TUI checklist
 |       |    |
 |       |    |-- [user selects SP]    →  eval "$TK_SP_INSTALL_CMD"
 |       |    |-- [user selects GSD]   →  eval "$TK_GSD_INSTALL_CMD"
 |       |    |-- [re-source detect.sh]
 |       |    |-- [user selects TK]    →  scripts/init-claude.sh --no-bootstrap ...
 |       |    |-- [user selects SEC]   →  scripts/setup-security.sh --yes
 |       |    |-- [user selects SL]    →  scripts/install-statusline.sh --yes
 |       |    |-- [user selects RTK]   →  print advice message
 |       |    |
 |       |    +-- print summary table
 |       |
 |       +-- [--skills-only]
 |               |
 |               +-- copy skills/* to ~/.claude/plugins/tk-skills/skills/
 |
 |-- curl/.../scripts/init-claude.sh  (UNCHANGED — existing entry point)
 |       |
 |       |-- bootstrap_base_plugins() (bootstrap.sh — SP/GSD prompts)
 |       |-- detect.sh + lib/install.sh + manifest.json
 |       |-- download files to ./.claude/
 |       +-- write toolkit-install.json
 |
 |-- /plugin marketplace add .../claude-code-toolkit  (NEW marketplace path)
         |
         +-- reads marketplace.json
         +-- installs plugins/tk-skills/ → ~/.claude/plugins/tk-skills/
         +-- installs plugins/tk-commands/ → ~/.claude/plugins/tk-commands/
         +-- installs plugins/tk-framework-rules/ → ~/.claude/plugins/tk-framework-rules/
```

---

## New Files vs Modified Files vs Deprecated Files

### New Files

| File | Type | Purpose |
|------|------|---------|
| `scripts/install.sh` | New script | TUI meta-installer; orchestrates all components |
| `scripts/lib/tui.sh` | New lib | Pure-bash checklist renderer; reads from TK_TUI_TTY_SRC |
| `scripts/lib/detect2.sh` | New lib | is_*_installed() component probes; sources detect.sh |
| `marketplace.json` | New data | Root-level marketplace manifest; version must match manifest.json |
| `plugins/tk-skills/plugin.json` | New data | Sub-plugin descriptor for skills marketplace bundle |
| `plugins/tk-commands/plugin.json` | New data | Sub-plugin descriptor for commands marketplace bundle |
| `plugins/tk-framework-rules/plugin.json` | New data | Sub-plugin descriptor for framework rules |
| `docs/CLAUDE_DESKTOP.md` | New doc | What works on Desktop vs Code; skills-only install guide |

### Modified Files

| File | Change | Backwards-Compatible |
|------|--------|---------------------|
| `scripts/setup-security.sh` | Add `--yes` flag and `YES=0` env-form | YES — new flag, existing callers unaffected |
| `scripts/install-statusline.sh` | Add `--yes` flag (semantic no-op initially) | YES — new flag |
| `manifest.json` | Bump version to 4.5.0; add `files.scripts[]` entry for `scripts/install.sh`; add `files.libs[]` entries for `tui.sh` and `detect2.sh` | YES — additive |
| `CHANGELOG.md` | Add [4.5.0] section | YES |

### Deprecated (not removed in v4.5)

| File | Status | Notes |
|------|--------|-------|
| `scripts/lib/bootstrap.sh` | Retained | Still called by init-claude.sh when invoked directly; not called by install.sh (TUI handles SP/GSD) |

---

## manifest.json — Single Source of Truth Decision

`marketplace.json` must NOT duplicate file lists from `manifest.json`.

The only data `marketplace.json` shares with `manifest.json` is the version string.
`marketplace.json` references sub-plugin directories; those directories reference skills/
and commands/ via plugin.json (not by listing individual files). Individual file lists
remain exclusively in `manifest.json`.

Version sync enforcement: add to `make validate` (and CI `validate-templates` job):

```bash
TK_VER=$(jq -r .version manifest.json)
MP_VER=$(jq -r .version marketplace.json 2>/dev/null || echo "MISSING")
if [[ "$TK_VER" != "$MP_VER" ]]; then
    echo "ERROR: manifest.json version ($TK_VER) != marketplace.json version ($MP_VER)" >&2
    exit 1
fi
```

---

## Build Order (Phase 24 vs Phase 25 Independence)

Phase 24 (TUI installer + detection) and Phase 25 (Marketplace + Desktop) are architecturally
independent. They share no common files that would block one while the other is in progress.

```
Phase 24 dependencies:
  tui.sh  ────────────────────────────────────────────────────┐
  detect2.sh  ──────────────────────────────────────────────┐ │
  setup-security.sh --yes  ─────────────────────────────────┤ │
  install-statusline.sh --yes  ─────────────────────────────┤ │
  All must exist before install.sh can be completed  ────── install.sh

Phase 25 dependencies:
  marketplace.json schema verified  ────┐
  Desktop-safe skill audit  ────────────┤
  plugin.json format confirmed  ────────┤
  All independent of Phase 24  ─── marketplace.json + plugins/ directory

Cross-phase dependency: NONE (can develop in parallel)
```

Within Phase 24, ordering:
1. `detect2.sh` — needed by `install.sh` to auto-detect and pre-check items
2. `tui.sh` — needed by `install.sh` for the checklist render
3. `--yes` flags on `setup-security.sh` and `install-statusline.sh` — needed by dispatch
4. `scripts/install.sh` — assembles everything; written last
5. Tests (`scripts/tests/test-install.sh`) — after all of the above

Within Phase 25, ordering:
1. Verify Anthropic marketplace schema (MUST happen before writing plugin.json files)
2. `plugins/tk-skills/plugin.json` — safest to write first (Desktop-compatible)
3. Desktop-safe skill audit — determines what goes into tk-skills
4. `marketplace.json` at root — references all three sub-plugins; written after they exist
5. `docs/CLAUDE_DESKTOP.md` — documents what works; written after audit complete

---

## Anti-Patterns for v4.5

### Anti-Pattern 1: install.sh re-implementing detect.sh logic

Do not duplicate `[ -d ~/.claude/plugins/cache/claude-plugins-official/superpowers/ ]` in
`install.sh`. Source `detect.sh` via `detect2.sh` instead. Single source of truth for paths.

### Anti-Pattern 2: marketplace.json duplicating manifest.json file lists

Every file in `manifest.json` files.skills[] does NOT appear in `marketplace.json`.
`marketplace.json` references sub-plugin directories only. Individual files are tracked
in manifest.json alone.

### Anti-Pattern 3: install.sh aborting on component failure

Per the continue-with-remaining failure model (1f above): never `exit 1` on a single
component failure. Collect, continue, summarize. The only exception is a hard prerequisite
failure (e.g., cannot download tui.sh — install.sh cannot function at all).

### Anti-Pattern 4: Calling install.sh from init-claude.sh

The trampoline direction is one-way: `install.sh` → `init-claude.sh`. Not the reverse.
If `init-claude.sh` called `install.sh`, the TUI would appear mid-install, which is confusing.
And it would break the existing curl-bash user flow.

### Anti-Pattern 5: Adding --yes to init-claude.sh

`init-claude.sh` already has non-interactive fallback (no-TTY auto-detect). `--yes` is
not needed there and would be redundant with `--mode`. Only `setup-security.sh` and
`install-statusline.sh` need `--yes` because they have interactive prompts that have no
existing non-interactive path.

---

## Integration Points Summary

| Boundary | Communication | File(s) | New/Existing |
|----------|---------------|---------|--------------|
| install.sh → init-claude.sh | subprocess call with flags | `--no-bootstrap --mode $M $FRAMEWORK` | Existing flags |
| install.sh → setup-security.sh | subprocess call | `--yes` | New flag on security |
| install.sh → install-statusline.sh | subprocess call | `--yes` | New flag on statusline |
| install.sh → detect2.sh | source | `is_*_installed()` functions | New lib |
| install.sh → tui.sh | source | `tui_checklist()` | New lib |
| detect2.sh → detect.sh | source | `detect_superpowers`, `detect_gsd` | Existing lib |
| marketplace.json → plugins/*/plugin.json | JSON references | plugin bundle metadata | New files |
| manifest.json ↔ marketplace.json | version sync (CI check) | `.version` field | New CI assertion |
| install.sh --skills-only → skills/ | file copy to ~/.claude/plugins/ | `skills/*/SKILL.md` | New code path |

---

## Sources

- Direct codebase analysis: `scripts/init-claude.sh`, `scripts/lib/bootstrap.sh`,
  `scripts/lib/install.sh`, `scripts/lib/optional-plugins.sh`, `scripts/detect.sh`,
  `scripts/setup-security.sh`, `scripts/install-statusline.sh`, `scripts/uninstall.sh`,
  `manifest.json`
- Project requirements: `.planning/PROJECT.md` (v4.5 milestone section)
- Existing architecture: `.planning/codebase/ARCHITECTURE.md` (v4.0 layer diagram)
- Existing research: `.planning/research/ARCHITECTURE.md` (v4.0 complement-mode patterns)
- Confidence: HIGH — all integration decisions traced directly to existing code contracts

---

*Architecture research for: claude-code-toolkit v4.5 TUI Installer + Marketplace*
*Researched: 2026-04-29*
