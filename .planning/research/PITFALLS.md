# Pitfalls Research

**Domain:** v4.5 — Unified TUI Installer + Marketplace Publishing + Claude Desktop reach (adding to existing curl-bash shell toolkit)
**Researched:** 2026-04-29
**Confidence:** HIGH (all findings grounded in actual codebase files: `scripts/lib/bootstrap.sh`, `scripts/tests/test-bootstrap.sh`, `scripts/lib/install.sh`, `scripts/detect.sh`, `scripts/init-claude.sh`, `scripts/verify-install.sh`, `scripts/setup-security.sh`, `.planning/PROJECT.md`, `.planning/MILESTONES.md`)

> This document supersedes the v4.0 PITFALLS (installer refactor) for v4.5 scope.
> The v4.0 pitfalls (detection false-negatives, atomic writes, BSD head -n -1, etc.) are ALREADY RESOLVED.
> Focus here is on NEW failure modes introduced by TUI, marketplace, and Desktop reach work.

---

## Critical Pitfalls

### Pitfall 1: TUI Reads `read` from Pipe Instead of `/dev/tty` — Silent Wrong Default

**What goes wrong:**
The new TUI checklist installer (`scripts/install.sh`) uses `read -rsn1` to capture arrow keys and spacebar from the user. Under `curl | bash`, stdin is the curl network pipe — not the terminal. The first `read -rsn1` call either reads a byte from the download stream (selecting a random component) or blocks indefinitely waiting for EOF. The installer appears to hang or selects all/no components with no feedback.

**Why it happens:**
The `curl | bash` pipeline rewires stdin of the bash process to the curl socket. Every `read` that does not explicitly redirect from `/dev/tty` consumes from that socket. The bootstrap.sh pattern (BOOTSTRAP-01) already solved this for the y/N prompts with `TK_BOOTSTRAP_TTY_SRC`, but the TUI is a heavier read loop that needs the same seam on EVERY keypress read.

**How to avoid:**
Every `read` call inside the TUI render loop must use `< /dev/tty`:
```bash
read -rsn1 key < /dev/tty
```
Also: at TUI startup, probe TTY availability BEFORE entering the render loop:
```bash
if ! [ -t 0 ] && ! [ -e /dev/tty ]; then
    # Non-interactive: fall through to --yes default set or legacy bootstrap.sh path
    _tui_fallback_noninteractive
    return 0
fi
```
Use the same `TK_TUI_TTY_SRC` seam pattern established in `TK_BOOTSTRAP_TTY_SRC` (bootstrap.sh:43) for test injection. The fallback must activate automatically — the TUI is NOT a hard requirement; it is a UX enhancement over the two-prompt bootstrap flow.

**Warning signs:**
- `bash <(curl -sSL .../install.sh)` hangs with no output after the banner.
- In CI, the job hangs until timeout rather than completing with defaults.
- Running `echo "" | bash scripts/install.sh` causes wrong component selection.

**CI gate:**
Add a test scenario `S_PIPE` analogous to `test-bootstrap.sh S3` that pipes stdin from `/dev/null` and asserts: TUI exits 0, no components are mutated, output contains a "non-interactive" notice.

**Phase to address:** Phase 24 (TUI installer).

---

### Pitfall 2: TUI Leaves Terminal in Raw Mode After Ctrl-C — User Types Blind

**What goes wrong:**
The TUI sets the terminal into raw (no-echo, single-char) mode via `stty -echo -icanon` to capture arrow keys. If the user hits Ctrl-C mid-interaction (or the script exits non-zero due to a download error), the `EXIT` trap may not fire, or may fire after `stty` was set but before the restore. The terminal stays raw. The user's next shell session shows typed characters as invisible or garbled until `reset` is run.

**Why it happens:**
Bash `set -euo pipefail` exits immediately on the first non-zero return. If `stty raw` succeeds but the subsequent curl fails, the EXIT trap is the only cleanup path. If `stty` restoration is inside a function called from the trap, and that function fails, bash may not restore the terminal. Also: `SIGPIPE` (from curl | bash flow) can bypass normal EXIT on some bash versions.

**How to avoid:**
```bash
# Pattern: save state before entering raw mode, restore unconditionally
_TUI_STTY_SAVED=""
_tui_enter_raw() {
    _TUI_STTY_SAVED=$(stty -g < /dev/tty 2>/dev/null || echo "")
    [[ -n "$_TUI_STTY_SAVED" ]] && stty -echo -icanon min 1 time 0 < /dev/tty
}
_tui_exit_raw() {
    [[ -n "$_TUI_STTY_SAVED" ]] && stty "$_TUI_STTY_SAVED" < /dev/tty 2>/dev/null || true
    _TUI_STTY_SAVED=""
}
trap '_tui_exit_raw' EXIT INT TERM HUP
```
Key constraints:
- Save/restore from `/dev/tty` explicitly (not stdin which may be the pipe).
- Use `|| true` on restore so it never causes the trap itself to fail.
- Register the trap BEFORE calling `_tui_enter_raw`, not after.

**Warning signs:**
- After Ctrl-C, terminal input is invisible.
- `stty: stdin isn't a terminal` error in CI output.
- Test that simulates SIGINT does not restore `stty` state.

**CI gate:**
Test scenario: send SIGINT to a running install.sh process and assert `stty -g < /dev/tty` before and after match (or that the term is not in raw mode). Use the `TK_TUI_TTY_SRC` seam pointing at a PTY created via `script -q /dev/null` in the test harness.

**Phase to address:** Phase 24 (TUI installer).

---

### Pitfall 3: Terminal Escape Sequences Corrupt CI Build Logs

**What goes wrong:**
The TUI renders using ANSI escape sequences for cursor movement (`tput cup`, `\033[A`, `\033[2K`) and color codes. When the installer runs in CI (GitHub Actions `ubuntu-latest` runner), stdout is not a TTY. `[ -t 1 ]` returns false, but if the TUI render path checks `[ -t 1 ]` only once at startup and then branches into a "color disabled" path, cursor-movement sequences may still be emitted (they are separate from color). GitHub Actions HTML log renderer treats raw escape bytes as unicode replacement characters, producing garbage lines in the build log and breaking log parsing tools.

**Why it happens:**
The existing `dro_init_colors` helper in `scripts/lib/dry-run-output.sh` gates only color via `[ -t 1 ]` and `${NO_COLOR+x}`. The TUI render loop is NEW code and will not automatically inherit this gate. Cursor movement requires a separate check and a `NO_TUI` fallback path.

**How to avoid:**
The TUI must check TTY availability before ANY rendering — not just before color:
```bash
_TUI_ENABLED=0
if [[ -t 0 ]] && [[ -t 1 ]] && [[ -z "${CI:-}" ]] && [[ -z "${NO_TUI:-}" ]]; then
    _TUI_ENABLED=1
fi
```
When `_TUI_ENABLED=0`: fall through to the legacy two-prompt bootstrap flow (bootstrap.sh already handles this). Never emit `tput` or `\033[` cursor sequences when not in TUI mode.

Also: `NO_TUI=1` must be documented in the `--help` output alongside `NO_BANNER` and `TK_NO_BOOTSTRAP`. The `--yes` flag implies `NO_TUI=1` for CI automation.

**Warning signs:**
- CI build log contains lines like `[2K[1A[?25l` as text.
- `make test` passes locally but the CI `Tests 21-30` step produces garbled output.
- `verify-install.sh` exits non-zero because it parses TUI output and hits raw escape bytes.

**CI gate:**
In `quality.yml`, the `Tests 21-30` step already runs with `NO_BANNER=1`. Add `NO_TUI=1` to the same step. Add an assertion in the test harness that `grep -P '\x1b\[' "$OUTPUT"` returns no matches when `NO_TUI=1`.

**Phase to address:** Phase 24 (TUI installer).

---

### Pitfall 4: Bash 3.2 (macOS) Incompatibilities in TUI Read Loop

**What goes wrong:**
The TUI uses arrow-key detection via `read -rsn1` plus escape-sequence multi-byte reads. Bash 3.2 (default on macOS before Catalina; still present on older systems) has several incompatibilities:

1. `read -N1` (uppercase N) does not exist in Bash 3.2 — it silently falls through to end of input.
2. Arrays cannot be declared with `local -a arr=()` inside functions in Bash 3.2 — must use `local arr; arr=()` in separate statements.
3. `[[ $'\e' == ... ]]` escape comparisons behave differently — `$'\e'` is `\033` but `$'\x1b'` is not recognized in all Bash 3.2 builds.
4. `printf '%s' "$key" | xxd` for debugging escape sequences may differ.

**Why it happens:**
macOS ships Bash 3.2 (GPL v2; Apple cannot ship GPL v3 Bash 4+) and the constraint in `PROJECT.md` requires Bash 3.2+ support. TUI code written and tested on macOS with Homebrew bash 5.x will silently fail on the system `/bin/bash`.

**How to avoid:**
- Use only `read -rsn1` (lowercase n) for single-char reads — verified Bash 3.2 compatible.
- Escape sequence multi-byte read: read first byte; if `$'\033'`, then read two more in a loop:
  ```bash
  read -rsn1 -t 0.1 key2 < /dev/tty || key2=""
  read -rsn1 -t 0.1 key3 < /dev/tty || key3=""
  ```
  Use `-t 0.1` for the subsequent reads to avoid blocking — `-t` is available in Bash 3.2.
- Test all array operations under `/bin/bash` on macOS explicitly (not `bash` which may be Homebrew).
- Add a CI job with `shell: /bin/bash` on `macos-latest` runner to catch regressions.

**Warning signs:**
- Arrow keys advance the checklist cursor on macOS brew bash but not on `/bin/bash`.
- `shellcheck --shell=bash` (which defaults to bash 4 semantics) passes but real macOS fails.
- The `scripts/tests/` helper `scripts/tests/test-bootstrap.sh` uses `#!/usr/bin/env bash` — same risk applies to new TUI tests.

**CI gate:**
Add a `macos-compat` CI job that runs `scripts/tests/test-tui.sh` with `BASH=/bin/bash bash scripts/tests/test-tui.sh`. Ensure all test scripts in `scripts/tests/` use `#!/bin/bash` (system bash) not `#!/usr/bin/env bash` when testing compat.

**Phase to address:** Phase 24 (TUI installer).

---

### Pitfall 5: Marketplace Schema Drift — `marketplace.json` Silently Rejected

**What goes wrong:**
The root-level `marketplace.json` targets the Claude Code plugin marketplace spec. Anthropic's marketplace schema is not publicly versioned or announced on a changelog — it is inferred from official plugin examples and documentation. If the schema changes between when `marketplace.json` is authored (Phase 25 planning) and when users run `claude plugin marketplace add sergei-aronsen/claude-code-toolkit`, the CLI rejects the manifest with a non-obvious error like `"Invalid plugin manifest"` or silently ignores sub-plugins it doesn't understand.

**Why it happens:**
The TK marketplace schema will be authored from documentation available at planning time. Anthropic may add required fields (e.g., `min_cli_version`, `categories`, `entrypoint`) or change field names after the spec snapshot. Because this is a distributed toolkit (curl-bash, no auto-update for `marketplace.json` itself unless the user re-runs install), a schema change can silently break marketplace installation for all existing users.

**How to avoid:**
1. Author `marketplace.json` ONLY after checking the current Anthropic marketplace spec against a live `claude plugin marketplace add` invocation (not just docs).
2. Pin `"manifest_version": 1` (or whatever the current version is) so CLI rejects on version mismatch rather than silently misinterpreting fields.
3. Add a smoke test to CI that runs `claude plugin marketplace validate marketplace.json` if such a subcommand exists; otherwise validate the JSON schema against the official JSONSchema if Anthropic publishes one.
4. Include a `"last_verified_cli_version"` comment field in `marketplace.json` so maintainers know when validation was last performed.

**Warning signs:**
- `claude plugin marketplace add sergei-aronsen/claude-code-toolkit` returns a 400-class error or "unknown plugin format".
- Sub-plugins (`tk-skills`, `tk-commands`, `tk-framework-rules`) are not listed after install.
- The Claude CLI version in CI is older than when `marketplace.json` was authored.

**CI gate:**
In `quality.yml`, add a `validate-marketplace` job that runs `jq . marketplace.json > /dev/null` (JSON validity) and checks required top-level fields against a locally maintained schema fixture at `scripts/tests/marketplace-schema.json`. This is not a live CLI validation (Claude CLI is not available in CI) but prevents structural drift.

**Phase to address:** Phase 25 (Marketplace publishing).

---

### Pitfall 6: Curl-Bash Users Discovering Marketplace — Double-Install Collision

**What goes wrong:**
A user who installed via `curl | bash init-claude.sh` discovers the marketplace entry and runs `claude plugin marketplace add sergei-aronsen/claude-code-toolkit`. The marketplace install places `tk-commands/*.md` at a different path than what `toolkit-install.json` tracks (marketplace may install to `~/.claude/plugins/marketplace/sergei-aronsen-claude-code-toolkit/commands/` rather than `~/.claude/commands/`). Now two copies of the commands exist. When the user later runs `update-claude.sh`, it refreshes the curl-bash copy but not the marketplace copy. The user sees duplicate `/council`, `/audit` etc.

**Why it happens:**
Two installation channels produce two independent file trees. `toolkit-install.json` only tracks the curl-bash channel. Marketplace has its own plugin manifest that Claude Code reads separately.

**How to avoid:**
1. `docs/CLAUDE_DESKTOP.md` and `docs/INSTALL.md` must prominently document the two channels are MUTUALLY EXCLUSIVE — not additive.
2. On curl-bash install, detect whether a marketplace install is already present (check `~/.claude/plugins/marketplace/sergei-aronsen*/` or equivalent path) and warn:
   ```bash
   if [[ -d "$HOME/.claude/plugins/marketplace/sergei-aronsen-claude-code-toolkit" ]]; then
       echo "⚠ Marketplace install detected. Running both curl-bash AND marketplace installs is unsupported."
       echo "  Remove the marketplace install first: claude plugin marketplace remove sergei-aronsen/claude-code-toolkit"
       exit 1
   fi
   ```
3. Marketplace `marketplace.json` must carry a `"install_channel": "marketplace"` field that init scripts can read to detect the channel conflict.

**Warning signs:**
- User reports `/council` appears twice in Claude Code's command list.
- `update-claude.sh` completes successfully but user sees old marketplace commands still present.
- `toolkit-install.json` exists AND `~/.claude/plugins/marketplace/sergei-aronsen*/` exists simultaneously.

**CI gate:**
Add a new install-matrix cell `marketplace-conflict` that verifies `init-claude.sh` emits the conflict warning and exits non-zero when the marketplace directory is pre-seeded.

**Phase to address:** Phase 25 (Marketplace publishing).

---

### Pitfall 7: Marketplace Sub-Plugin Path Collisions with Existing Plugin Directories

**What goes wrong:**
The marketplace registers three sub-plugins: `tk-skills`, `tk-commands`, `tk-framework-rules`. If `~/.claude/plugins/` already contains entries from the `superpowers@claude-plugins-official` cache (path: `~/.claude/plugins/cache/claude-plugins-official/superpowers/`), the marketplace installer may place its files under a conflicting path if its output directory is not namespaced. For example, if both superpowers and tk-commands install to `~/.claude/commands/`, the second install silently overwrites files or interleaves them with no ownership tracking.

**Why it happens:**
Marketplace sub-plugin path resolution is controlled by the Anthropic Claude Code runtime, not by TK. If TK's `marketplace.json` declares `"path": "commands/"` without a sub-plugin namespace prefix, the runtime places files directly into the shared `commands/` tree.

**How to avoid:**
1. In `marketplace.json`, use namespaced paths for all sub-plugin files. Example: instead of `"path": "commands/council.md"`, use `"path": "plugins/tk-commands/commands/council.md"` and let Claude Code's plugin resolution handle the lookup.
2. Verify that the Anthropic spec supports namespaced command paths before authoring the manifest.
3. If namespacing is not supported, `tk-commands` should NOT be offered via marketplace (it would collide with both superpowers and the curl-bash install). In that case, restrict marketplace to `tk-skills` only (which is the primary Desktop value anyway per PROJECT.md).

**Warning signs:**
- After marketplace install, `~/.claude/commands/debug.md` is overwritten by a marketplace version.
- SP's `/debug` command stops working because TK's marketplace copy shadows it.
- `toolkit-install.json` SHA256 check on `commands/debug.md` fails on next update-claude.sh run.

**CI gate:**
The `agent-collision-static` gate (already in `make check` per PROJECT.md) must be extended to also verify marketplace-installed command paths do not collide with superpowers-owned paths. This requires a fixture of known superpowers paths in `scripts/tests/`.

**Phase to address:** Phase 25 (Marketplace publishing).

---

### Pitfall 8: Marketplace Removal Leaves Sub-Plugin Files Behind — Uninstall Path Divergence

**What goes wrong:**
A user runs `claude plugin marketplace remove sergei-aronsen/claude-code-toolkit`. The marketplace uninstaller removes the top-level plugin entry but may not know about sub-plugin files that were installed to shared directories. The `tk-skills/*.md` files remain in `~/.claude/skills/` even after remove. If the user then re-installs via curl-bash, `init-claude.sh` finds those stale skill files, skips writing them (idempotent install), and the user ends up with a mix of marketplace-version and curl-bash-version skills.

**Why it happens:**
The marketplace uninstall contract is whatever Anthropic implements. TK has no control over it. The curl-bash install's idempotency logic assumes "file exists → already installed → skip" but cannot distinguish marketplace-leftovers from curl-bash installs.

**How to avoid:**
1. Design `marketplace.json` so ALL sub-plugin files are under a plugin-namespaced prefix that the marketplace runtime can cleanly remove. Never install to shared directories from marketplace.
2. Document in `docs/CLAUDE_DESKTOP.md`: after marketplace remove, run `bash <(curl -sSL .../scripts/uninstall.sh)` to clean up any residual files.
3. If idempotency logic sees a file that is NOT in `toolkit-install.json` (i.e., not curl-bash owned), it must NOT treat it as "already installed" — it should warn and offer to overwrite.

**Warning signs:**
- After `claude plugin marketplace remove`, some skill files still appear in `~/.claude/skills/`.
- After re-installing via curl-bash, `toolkit-install.json` does not list skills that were marketplace-leftovers, breaking future updates.
- `verify-install.sh` reports install healthy but skill files are stale marketplace versions.

**Phase to address:** Phase 25 (Marketplace publishing).

---

### Pitfall 9: Skills Assuming Bash/Shell Tool Availability — Desktop Incompatibility

**What goes wrong:**
Several `templates/base/skills/` SKILL.md files contain `bash` code blocks that instruct Claude to RUN commands (not just as illustrative examples). Specifically:

- `debugging/SKILL.md` (line 35–45): `tail -100 storage/logs/laravel.log`, `php artisan tinker`, `git log` — these are EXECUTED instructions.
- `database/SKILL.md`: SQL and migration commands requiring a shell.
- `i18n/SKILL.md`: references file operations.

Claude Desktop does not have a Bash tool. When `tk-skills` is installed via marketplace and loaded in Desktop, Claude reads the SKILL.md, attempts to follow instructions referencing Bash commands, and either hallucinates shell output or errors with "tool not available". The user gets degraded, confusing behavior.

**Why it happens:**
The skills were authored for Claude Code (which has Bash, Read, Write, Edit tools). They were never audited for Desktop compatibility. The marketplace publishing work creates the first path for these skills to be loaded in Desktop.

**How to avoid:**
Before `tk-skills` is published to marketplace, audit every SKILL.md against this checklist:
- Does it contain `bash` code blocks with EXECUTABLE commands (not just config snippets)?
- Does it reference `.claude/` relative paths (project-relative, not available globally in Desktop)?
- Does it reference framework-specific tooling (`php artisan`, `npm run`, `docker compose`) that requires a project context?

Skills that fail the audit must either:
(a) Be excluded from `tk-skills` marketplace sub-plugin (Code-only), OR
(b) Carry a `<!-- REQUIRES_BASH_TOOL -->` marker that the installer checks before including.

Safe skills (based on current codebase read): `ai-models`, `llm-patterns`, `tailwind`, `observability` (contain patterns and principles, no executable shell instructions).
Risky skills: `debugging`, `database`, `docker`, `testing`, `i18n` (contain executable Bash blocks).

**Warning signs:**
- Claude Desktop user reports "I don't have a terminal" after following skill instructions.
- A skill says "run `php artisan tinker`" in a Desktop session.
- `docs/CLAUDE_DESKTOP.md` claims all skills work in Desktop without this audit having been done.

**CI gate:**
Add `scripts/validate-skills-desktop.sh` that greps all SKILL.md files under `templates/base/skills/` for `bash` code blocks containing executable patterns (`\$ `, `artisan`, `docker`, `npm run`, `git`, `tail -`). Emit a WARNING for each match. If a skill is tagged `<!-- DESKTOP_SAFE -->`, suppress the warning. CI fails if untagged risky skills are present in `marketplace.json`'s `tk-skills` file list.

**Phase to address:** Phase 25 (Marketplace publishing / Desktop reach).

---

### Pitfall 10: Skills Referencing Project-Relative Paths — Desktop Global Context Mismatch

**What goes wrong:**
Several SKILL.md files reference paths like `.claude/skills/`, `.claude/rules/`, `.claude/scratchpad/`. These paths are meaningful only within a project context (Claude Code's CWD). In Claude Desktop, there is no project — the model operates globally. A skill that says "write your findings to `.claude/scratchpad/current-task.md`" in Desktop causes Claude to create that file relative to whatever Desktop considers CWD (often `~` or undefined), not a project directory.

**Why it happens:**
Skills were authored for project-scoped Claude Code sessions. The path convention is correct for Code but incorrect for Desktop's global session model.

**How to avoid:**
Skills that reference `.claude/` relative paths are NOT Desktop-safe. They must be excluded from `tk-skills` marketplace sub-plugin or have the path references rewritten to use `~/` absolute paths with a Desktop-appropriate convention.

The `debugging/SKILL.md` skill-rules trigger in `skill-rules.json` references `*.log` and `**/logs/**` file patterns — these are project-relative globs that have no meaning in Desktop's file system view.

Document in `docs/CLAUDE_DESKTOP.md`: "Skills that reference `.claude/` paths or project-relative globs are Code-only and are excluded from the Desktop-compatible `tk-skills` sub-plugin."

**Phase to address:** Phase 25 (Marketplace / Desktop reach).

---

### Pitfall 11: `cc-safety-net` Detection Misses Brew-Installed Binary — Regresses npm Path

**What goes wrong:**
v4.5 adds brew support for `cc-safety-net` to the TUI component detection. The current detection in `scripts/verify-install.sh` and `scripts/setup-security.sh` uses `command -v cc-safety-net` (which finds both npm-global and brew paths correctly). However, the NEW centralized `is_cc_safety_net_installed()` function in `scripts/lib/detect.sh` may be written with an npm-specific path check (`[[ -f "$(npm root -g)/cc-safety-net/..." ]]`) that misses brew installs.

The concrete regression: a user who installed `cc-safety-net` via `brew install cc-safety-net` (v4.5 new path) is told "not installed" by the TUI, and the TUI offers to re-install it. The user re-installs via npm. Now two copies exist — one brew binary, one npm binary — and they may be different versions.

**Why it happens:**
The `command -v` pattern (already used in `verify-install.sh:151`) is path-agnostic. A new `is_cc_safety_net_installed()` function written from scratch may copy the npm-path pattern from `setup-security.sh:164-169` (which checks `command -v cc-safety-net` but the INSTALL path is always `npm install -g`) without realizing the detection function must remain install-path-agnostic.

**How to avoid:**
The canonical detection pattern is `command -v cc-safety-net &>/dev/null` — it is already correct in `verify-install.sh` and `setup-security.sh`. The new `is_cc_safety_net_installed()` MUST use this exact form:
```bash
is_cc_safety_net_installed() {
    command -v cc-safety-net &>/dev/null
}
```
Never use `npm root -g` or a hardcoded path as the detection signal. The install path changes; the binary name does not.

Add a regression assertion in `scripts/tests/test-detect-skew.sh` (existing file) that verifies `is_cc_safety_net_installed()` returns true when a mock binary named `cc-safety-net` is placed on PATH (regardless of whether npm or brew is present).

**Warning signs:**
- TUI shows "cc-safety-net: not installed" for a user who installed via brew.
- `verify-install.sh` and the TUI disagree on installation status.
- `test-setup-security-rtk.sh` (existing test at `scripts/tests/`) passes but a new TUI detection test fails.

**CI gate:**
The new `is_cc_safety_net_installed()` function must be tested by placing a mock script named `cc-safety-net` on PATH and asserting return code 0, with NO npm present in the test sandbox.

**Phase to address:** Phase 24 (Centralized detection).

---

### Pitfall 12: Statusline Detection Signal Change Falsely Reports Uninstalled

**What goes wrong:**
The current statusline detection in `verify-install.sh` uses two signals: (1) `grep -q "statusLine" ~/.claude/settings.json` AND (2) `[ -f ~/.claude/statusline.sh ]`. The new `is_statusline_installed()` in `scripts/lib/detect.sh` might use only signal (1) or only signal (2). A user who installed statusline via the v4.3 or earlier installer (which wrote the file but may have a slightly different settings.json key name) gets a false negative.

The specific fragility: `settings.json` uses `"statusLine"` (camelCase) for the shell integration config, but the key name could be `"status_line"`, `"statusline"`, or just the presence of `statusline.sh` in the hooks. If the detection function does a case-sensitive grep for `"statusLine"` but the user's settings has a different casing, the detection fails.

**How to avoid:**
Copy the EXACT detection logic from `verify-install.sh:228-250` into the new `is_statusline_installed()` function — do not rewrite it:
```bash
is_statusline_installed() {
    [[ -f "$HOME/.claude/statusline.sh" ]] && \
    grep -q "statusLine" "$HOME/.claude/settings.json" 2>/dev/null
}
```
Both signals are required AND must match what `verify-install.sh` already uses. If they are ever changed, change both locations together (or consolidate into a single source of truth in `scripts/lib/detect.sh` and have `verify-install.sh` source it).

Add a `shellcheck`-friendly assertion in the test suite that `is_statusline_installed()` output matches `verify-install.sh`'s statusline check for the same fixture directory.

**Warning signs:**
- TUI shows "Statusline: not installed" but `verify-install.sh` shows it installed.
- User runs TUI, re-installs statusline (which is already present), and gets a "already installed — skipping" message.
- The two signals diverge after a settings.json migration by a future Claude Code release.

**Phase to address:** Phase 24 (Centralized detection).

---

### Pitfall 13: TUI Reads Detection State at Startup — Stale During Long Session

**What goes wrong:**
The TUI runs detection at startup (to pre-check already-installed components). The user sees `[✓] Toolkit` and `[✓] superpowers`. They then manually run `claude plugin install superpowers@claude-plugins-official` in a DIFFERENT terminal. The TUI still shows superpowers as installed (correct), but if the user UNCHECKS superpowers in the TUI and presses Enter to proceed, the TUI re-runs install with superpowers UNCHECKED, potentially installing TK in complement mode without SP even though SP is now present.

Less critical but related: the user installs `cc-safety-net` in another terminal during the TUI session, then comes back and the TUI still shows it unchecked (stale detection). The user re-installs it, which is harmless but confusing.

**Why it happens:**
Detection is a one-shot at startup. The TUI is an interactive session that may stay open for minutes. External state changes invalidate the cached detection.

**How to avoid:**
The TUI checklist must RE-RUN detection immediately before executing any install action (when the user presses Enter to confirm). The startup detection is only for UX convenience (pre-checking boxes). The authoritative detection is the one that runs at install time:
```bash
# TUI: on Enter/confirm
_tui_execute_selections() {
    # Re-run detection — do NOT use startup-cached values
    source "$DETECT_TMP"
    bootstrap_base_plugins  # existing bootstrap.sh logic handles SP/GSD
    # ... proceed with fresh HAS_SP / HAS_GSD
}
```
This is already the pattern in `init-claude.sh:141-144` (re-sources `$DETECT_TMP` after bootstrap). The TUI must not bypass this re-source step.

**Warning signs:**
- User installs SP externally during TUI session; TUI proceeds in standalone mode.
- TUI-selected component set diverges from actual post-install state.
- `toolkit-install.json` records `mode: standalone` immediately after a complement-full install.

**Phase to address:** Phase 24 (TUI installer).

---

### Pitfall 14: `init-claude.sh` Trampoline Breaks Existing URL Bookmarks

**What goes wrong:**
v4.5 introduces a new entry point: `scripts/install.sh`. The PROJECT.md spec says "Existing `init-claude.sh` URL stays valid. New `install.sh` is the recommended entry point; old script trampolines to it with previous flag semantics intact." If the trampoline is implemented incorrectly, users who bookmarked:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```
...will get unexpected behavior. Specifically:

1. The trampoline might forward `--dry-run` but not `--mode` or `--framework` — partial flag forwarding.
2. The trampoline calls `install.sh` which has a different exit code convention, and any `set -euo pipefail` in the parent context exits prematurely.
3. Users who source `init-claude.sh` (not `bash <(curl)`) will source the trampoline, which `exec`s install.sh — this is not sourcing-safe.

**How to avoid:**
The trampoline must forward ALL recognized flags verbatim. Use `exec` or `"$@"` pass-through:
```bash
# In init-claude.sh trampoline body:
exec bash <(curl -sSL "$REPO_URL/scripts/install.sh") "$@"
```
The flag list in `init-claude.sh:54` documents: `--dry-run, --no-council, --no-bootstrap, --mode <name>, --force, --force-mode-change, --no-banner`. ALL of these must survive the trampoline. Test with every flag permutation.

Also: `init-local.sh` is the local-path equivalent and must receive the same trampoline treatment.

**Warning signs:**
- `bash <(curl ... init-claude.sh) --mode complement-sp` ignores `--mode`.
- `bash <(curl ... init-claude.sh) --no-banner` produces a banner (flag dropped by trampoline).
- `init-claude.sh --dry-run` exits 0 without any output (trampoline exited before forwarding).

**CI gate:**
Extend `scripts/tests/test-install-banner.sh` (existing 7-assertion test) with a trampoline-path scenario: verify `init-claude.sh --no-banner` produces zero banner output when trampolining to a mocked `install.sh`.

**Phase to address:** Phase 24 (TUI installer — entry point refactor).

---

### Pitfall 15: Existing Flags Silently Dropped During v4.5 Refactor

**What goes wrong:**
v4.4 shipped these flags and env vars, all of which must survive v4.5:
- `--no-bootstrap` / `TK_NO_BOOTSTRAP=1` (BOOTSTRAP-01, Phase 21)
- `--no-banner` / `NO_BANNER=1` (BANNER-01, Phase 23, env-form `NO_BANNER=${NO_BANNER:-0}`)
- `--keep-state` / `TK_UNINSTALL_KEEP_STATE=1` (KEEP-01, Phase 23)
- `--dry-run` (all three installers)
- `--mode` / `--force` / `--force-mode-change` (v4.0)

The v4.5 refactor introduces `scripts/install.sh` as the new entry point and touches the argparse sections of `init-claude.sh` and `init-local.sh`. If ANY of these flags are removed from argparse during the refactor, the failure is SILENT — the unknown flag hits the `*` case and the installer either exits with "Unknown argument" or silently ignores it (depending on whether `exit 1` or `shift` is in the default case).

**Why it happens:**
The argparse block in `init-claude.sh:25-58` is a long case statement. When adding new flags (e.g., `--yes`, `--force` for TUI, `--skills-only`), developers may restructure the case statement and accidentally omit an existing arm.

**How to avoid:**
Add a source-grep assertion in the test suite for EVERY documented flag. The existing `test-install-banner.sh` already has this pattern (asserts `--no-banner` and `NO_BANNER` appear as grep patterns). Extend it:
```bash
# For each known flag, assert it appears in init-claude.sh argparse block
for flag in "--no-bootstrap" "--no-banner" "--dry-run" "--mode" "--force" "--force-mode-change" "--keep-state"; do
    assert_contains "$flag" "$(grep -c "$flag" scripts/init-claude.sh)" "argparse includes $flag"
done
```
Also: the `--help` output must list all flags. If `--help` is added to `scripts/install.sh`, its flag list must be kept in sync with the argparse case statement (a second source-grep assertion on the `--help` text).

**Warning signs:**
- `bash init-claude.sh --no-bootstrap` prints "Unknown argument: --no-bootstrap".
- `NO_BANNER=1 bash init-claude.sh` produces a banner (env var dropped).
- `test-install-banner.sh` assertions A4-A7 (env-form patterns) fail.

**CI gate:**
Extend `scripts/tests/test-install-banner.sh` to cover all v4.4 flags. This is already the right test file per the Phase 23 contract.

**Phase to address:** Phase 24 (TUI installer / entry point refactor).

---

### Pitfall 16: BOOTSTRAP-01..04 Invariants Regressed When Superseded by TUI

**What goes wrong:**
v4.4 `scripts/lib/bootstrap.sh` implements the two-prompt y/N pre-install flow. v4.5 says "bootstrap.sh stays as the no-tty fallback." This means bootstrap.sh must still function correctly when `_TUI_ENABLED=0`. If the TUI code path calls `bootstrap.sh` only when `_TUI_ENABLED=1` fails, and the `_TUI_ENABLED=0` path was not tested after TUI integration, the BOOTSTRAP-01..04 invariants may be silently broken.

Specifically, the 26-assertion `test-bootstrap.sh` test suite tests `scripts/lib/bootstrap.sh` via `scripts/init-local.sh`. If `init-local.sh` is refactored to call `install.sh` instead, and `install.sh` calls bootstrap.sh differently than the current `if [[ "${NO_BOOTSTRAP:-false}" != "true" ...]]; then bootstrap_base_plugins` pattern, S1–S5 may fail.

**How to avoid:**
The BOOTSTRAP-01..04 contract is LOCKED (referenced in PROJECT.md as validated requirements). Any v4.5 refactor that touches the bootstrap.sh call site in `init-claude.sh` or `init-local.sh` MUST keep `test-bootstrap.sh` green with ZERO assertion changes. This is a non-negotiable regression gate.

Add to the Phase 24 success criteria: "Run `bash scripts/tests/test-bootstrap.sh`; all 26 assertions pass without modification."

**Warning signs:**
- `test-bootstrap.sh` S3 (byte-quiet `--no-bootstrap`) fails after TUI integration.
- `TK_NO_BOOTSTRAP=1` env var no longer suppresses bootstrap when `_TUI_ENABLED=0`.
- Bootstrap is called twice (once by TUI, once by legacy path) when TUI exits early.

**CI gate:**
`test-bootstrap.sh` is already wired into Makefile Test 28 and CI `Tests 21-28`. Must remain green throughout Phase 24 work.

**Phase to address:** Phase 24 (TUI installer).

---

### Pitfall 17: TUI Keyboard Injection Tests Are Flaky Under Parallel CI

**What goes wrong:**
TUI tests require injecting keyboard input (arrow keys = multi-byte escape sequences, spacebar, enter). The test approach must use the `TK_TUI_TTY_SRC` file-based seam (write key bytes to a temp file, point TUI to it). Flakiness arises when:
1. The temp file is written AFTER the TUI starts reading it (race: producer vs. consumer).
2. Arrow key sequences require exact byte timing (`\033[A` is three bytes read with minimal delay); if the temp file write is not atomic, the TUI reads partial sequences.
3. Parallel CI jobs share `/tmp` — temp file names collide.
4. The TUI's `read -t 0.1` timeout (for multi-byte escape sequences) fires before the second byte is written, fragmenting the sequence.

**Why it happens:**
File-based TTY injection is inherently a producer-consumer race. The `test-bootstrap.sh` seam uses a static file written entirely before the test runs — this works because the bootstrap prompt is a single-line read. The TUI's interactive loop reads keys one-at-a-time across multiple loop iterations.

**How to avoid:**
Write the ENTIRE key sequence to the temp file BEFORE starting the TUI process:
```bash
# Pre-write full sequence: down-arrow, space, enter (select second item, confirm)
printf '\033[B \n' > "$TTY_FILE"
```
Use `mktemp` with a unique prefix per test scenario to prevent `/tmp` collisions. Do NOT use named FIFOs (pipes) for this seam — they block on write until the reader opens, causing deadlocks in single-process tests.

For the `read -t 0.1` escape sequence fragmentation: write all three bytes of the escape sequence atomically (they are all in the same `printf` call above) and the file read is instant — timing is not a concern for file-based reads.

**Warning signs:**
- TUI tests pass 90% of the time but fail occasionally in CI.
- A test failure produces "unexpected character" or wrong item selected.
- Test runs differently when CI has high load vs. low load.

**CI gate:**
Mark TUI tests as non-parallelizable (bats `--no-parallelize-across-files` or equivalent) if using bats. If using the existing `scripts/tests/` shell test pattern, ensure each scenario uses a unique `/tmp/test-tui-$$.XXXXXX` mktemp prefix.

**Phase to address:** Phase 24 (TUI installer).

---

### Pitfall 18: Marketplace Tests Require Live Claude CLI — Not Available in Standard CI

**What goes wrong:**
Phase 25 marketplace validation needs `claude plugin marketplace validate marketplace.json` or `claude plugin marketplace add` to verify the manifest is accepted. The Claude CLI is not installed on GitHub Actions `ubuntu-latest` runners by default. Adding it as a CI dependency introduces: version pinning problems (CLI updates may change the schema), authentication requirements (the CLI may require a signed-in user), and rate limits on marketplace API calls.

**Why it happens:**
Marketplace validation is fundamentally a live API interaction. Unlike the existing test surface (all hermetic shell tests using mocked seam env vars), marketplace tests require external services.

**How to avoid:**
Split into two test tiers:

1. **Hermetic tier (CI-safe):** JSON schema validation against a manually maintained `scripts/tests/marketplace-schema-fixture.json` that captures the current required fields. Run in every CI job. Catches structural drift without a live CLI.
   ```bash
   # In quality.yml validate-templates job:
   jq -e '.name and .description and .plugins and (.plugins | length > 0)' marketplace.json
   ```

2. **Smoke tier (opt-in, not CI):** A `make test-marketplace` target that requires `claude` CLI on PATH and runs the live `claude plugin marketplace validate` command. Document in `docs/RELEASE-CHECKLIST.md` as a manual pre-release check. Gate behind `MARKETPLACE_SMOKE_TEST=1 make test-marketplace` to prevent accidental CI registration.

**Warning signs:**
- `quality.yml` gains a step that calls `claude plugin marketplace` without a `claude` CLI install step.
- CI fails with "command not found: claude" on marketplace validate step.
- The live smoke test is added to CI and rate-limits the Anthropic marketplace API.

**CI gate:**
`make check` must NOT require the Claude CLI. Marketplace JSON validity is checked by jq schema only. Live validation is `make test-marketplace` (opt-in). Document this split in `docs/RELEASE-CHECKLIST.md`.

**Phase to address:** Phase 25 (Marketplace publishing).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| TUI with inline `stty` calls vs. ncurses | No deps, pure bash | Terminal compatibility varies; resize events unhandled | Acceptable for v4.5 given POSIX-only constraint; document known limitations |
| Marketplace JSON validated only by jq (no live CLI) | No Claude CLI needed in CI | Schema drift not caught until release | Acceptable if pre-release smoke test is in RELEASE-CHECKLIST.md |
| Skills Desktop-safety by exclusion (not tagging) | Simple: just exclude risky skills | Desktop feature set is artificially small; no per-skill granularity | Acceptable for v4.5 MVP; add `<!-- DESKTOP_SAFE -->` tagging in v4.6 |
| Double-install detection only on curl-bash side | Low-friction for curl-bash users | Marketplace users who also have curl-bash install get no warning | Never acceptable once both channels coexist; must be detected |
| Static detection at TUI startup | Fast, no wait for re-detection | Stale state if user installs externally during session | Acceptable only if authoritative re-detection fires at confirm time |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| TUI + `curl \| bash` | Using bare `read` or `read -N1` (uppercase) | `read -rsn1 key < /dev/tty` with non-interactive fallback |
| TUI + CI | Emitting cursor-movement escape sequences when `[ -t 1 ]` is false | Check `_TUI_ENABLED` before ANY `tput` or `\033[` output; `--yes` implies `NO_TUI=1` |
| Marketplace + curl-bash | Both channels install to overlapping paths | Detect conflicting channel at install time; document mutual exclusivity |
| Marketplace manifest + Claude CLI | Authoring schema from docs without live validation | Validate `marketplace.json` against a live `claude plugin marketplace` invocation before Phase 25 close |
| `cc-safety-net` + brew | Path-specific detection (`npm root -g`) misses brew binary | `command -v cc-safety-net` is the ONLY correct detection signal |
| Statusline detection + new `detect.sh` | Rewriting the two-signal check from memory | Copy exact pattern from `verify-install.sh:228-250`; consolidate into single source |
| Skills + Desktop | Publishing all skills to `tk-skills` marketplace sub-plugin | Audit each SKILL.md; exclude those with Bash tool requirements or `.claude/` relative paths |
| bootstrap.sh + TUI | TUI calling bootstrap.sh only when `_TUI_ENABLED=1` | bootstrap.sh is the fallback; it must be called when TUI is disabled; `test-bootstrap.sh` 26 assertions must remain green |

---

## "Looks Done But Isn't" Checklist

- [ ] **TUI non-interactive fallback:** `bash <(curl ... install.sh)` without a terminal falls through to bootstrap.sh y/N flow or `--yes` defaults — verify with `echo "" | bash scripts/install.sh`.
- [ ] **Ctrl-C recovery:** After Ctrl-C in the TUI, `stty -g < /dev/tty` output matches the pre-TUI saved state — verify manually on macOS and Linux.
- [ ] **Bash 3.2 compat:** TUI runs correctly under `/bin/bash` on macOS (not Homebrew bash) — verify with `BASH=/bin/bash bash scripts/install.sh --dry-run`.
- [ ] **No escape sequences in CI log:** `NO_TUI=1 bash scripts/install.sh --dry-run 2>&1 | grep -P '\x1b' | wc -l` outputs 0.
- [ ] **All v4.4 flags survive trampoline:** `bash scripts/init-claude.sh --no-bootstrap --no-banner --dry-run` produces expected output (test each flag individually and combined).
- [ ] **`test-bootstrap.sh` still green:** All 26 assertions pass without modification after TUI integration.
- [ ] **`cc-safety-net` detection agnostic:** `is_cc_safety_net_installed()` returns 0 with a brew-installed binary and 1 with no binary, without npm present.
- [ ] **Statusline detection matches `verify-install.sh`:** Same fixture directory produces same result from both functions.
- [ ] **No double-install:** Running marketplace install then `init-claude.sh` produces a conflict warning, not a silent merge.
- [ ] **Marketplace JSON valid:** `jq -e '.name and .plugins' marketplace.json` exits 0.
- [ ] **`tk-skills` Desktop-safe:** No SKILL.md in `tk-skills` file list contains executable Bash blocks or `.claude/` relative paths.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Terminal left in raw mode after TUI crash | LOW | User runs `reset` or `stty sane` in terminal |
| Marketplace + curl-bash double-install | MEDIUM | `claude plugin marketplace remove sergei-aronsen/claude-code-toolkit` then re-run `init-claude.sh --force` |
| Stale marketplace files after remove | LOW | `bash <(curl -sSL .../scripts/uninstall.sh)` to clean up orphaned files |
| `marketplace.json` schema rejection | HIGH | Remove marketplace entry; rebuild `marketplace.json` against current spec; re-publish; notify users via CHANGELOG |
| Desktop skill loads Code-only skill | LOW | User sees non-functional instructions; update `tk-skills` to exclude the skill; no data loss |
| BOOTSTRAP-01..04 regression | MEDIUM | Revert the `init-claude.sh` or `bootstrap.sh` change that caused it; `test-bootstrap.sh` is the regression oracle |
| cc-safety-net false-negative detection | LOW | User told "not installed"; user re-installs (harmless if idempotent); fix detection function |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| TUI reads from pipe instead of `/dev/tty` | Phase 24 | `S_PIPE` test scenario in `test-tui.sh`; `echo "" \| bash install.sh` exits 0 |
| TUI leaves terminal in raw mode | Phase 24 | SIGINT test in `test-tui.sh`; `stty -g` before/after match |
| Escape sequences in CI logs | Phase 24 | `NO_TUI=1` in CI; grep for `\x1b` in test output |
| Bash 3.2 incompatibilities | Phase 24 | `macos-compat` CI job with `/bin/bash` |
| Marketplace schema drift | Phase 25 | `validate-marketplace` CI job; `jq` schema fixture |
| Double-install collision | Phase 25 | `marketplace-conflict` install-matrix cell |
| Sub-plugin path collisions | Phase 25 | `agent-collision-static` gate extended for marketplace paths |
| Marketplace remove leftovers | Phase 25 | Documented in `docs/CLAUDE_DESKTOP.md` uninstall section |
| Skills with Bash tool requirements in Desktop | Phase 25 | `validate-skills-desktop.sh` CI script |
| Skills with `.claude/` relative paths in Desktop | Phase 25 | Same `validate-skills-desktop.sh` script |
| `cc-safety-net` brew detection regression | Phase 24 | Regression test in `test-detect-skew.sh` |
| Statusline detection signal divergence | Phase 24 | Cross-assertion: same fixture → same result from `is_statusline_installed()` and `verify-install.sh` |
| TUI stale detection at startup | Phase 24 | Re-detection at confirm time; `test-tui.sh` external-install scenario |
| `init-claude.sh` trampoline flag forwarding | Phase 24 | Extend `test-install-banner.sh` with trampoline scenarios |
| v4.4 flags silently dropped | Phase 24 | Source-grep assertions for all documented flags in `test-install-banner.sh` |
| BOOTSTRAP-01..04 regression | Phase 24 | `test-bootstrap.sh` 26 assertions unchanged |
| TUI test flakiness | Phase 24 | Pre-write full key sequence; `mktemp` unique per scenario |
| Marketplace tests requiring live CLI | Phase 25 | Hermetic jq tier in CI; smoke tier in `make test-marketplace` (opt-in) |

---

## Sources

- Codebase reads (2026-04-29): `scripts/lib/bootstrap.sh` (BOOTSTRAP-01..04 contract), `scripts/tests/test-bootstrap.sh` (26-assertion test seam pattern), `scripts/lib/install.sh` (safe-merge, detect re-source pattern), `scripts/detect.sh` (DETECT-06 filesystem-primary + CLI cross-check), `scripts/init-claude.sh` (argparse, cleanup trap, bootstrap call site), `scripts/verify-install.sh` (statusline two-signal detection, cc-safety-net command -v pattern), `scripts/setup-security.sh` (npm-only cc-safety-net install path), `templates/base/skills/debugging/SKILL.md` and `templates/base/skills/docker/SKILL.md` (Bash tool usage audit)
- `.planning/PROJECT.md` — v4.5 milestone spec, BOOTSTRAP/BANNER/KEEP invariants, constraints (Bash 3.2+, BSD/Linux, no Node in install path)
- `.planning/MILESTONES.md` — v4.4 ship notes: BOOTSTRAP-01..04 (26 assertions), BANNER-01 (7 assertions), KEEP-01/02 (11 assertions), LIB-01/02
- Known prior bugs from v4.0 pre-work: BUG-02 (`< /dev/tty` guards), BUG-01 (BSD `head -n -1`)
- Shell TUI patterns: `stty -g` save/restore, `read -rsn1` Bash 3.2 compatibility, file-based TTY injection seam
- Marketplace publishing: Anthropic Claude Code plugin marketplace spec (to be verified live at Phase 25 planning time against current CLI)

---

*Pitfalls research for: v4.5 — TUI installer + marketplace publishing + Desktop reach on existing curl-bash toolkit*
*Researched: 2026-04-29*
