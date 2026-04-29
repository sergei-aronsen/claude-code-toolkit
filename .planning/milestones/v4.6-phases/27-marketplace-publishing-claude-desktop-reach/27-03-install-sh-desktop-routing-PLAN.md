---
phase: 27
plan: "03"
type: execute
wave: 3
depends_on: ["27-01", "27-02"]
files_modified:
  - scripts/install.sh
  - scripts/lib/skills.sh
  - scripts/tests/test-install-tui.sh
autonomous: true
requirements:
  - DESK-03
must_haves:
  truths:
    - "A user without `claude` on PATH running `bash scripts/install.sh` (no flags) is auto-routed to --skills-only mode and sees a one-line banner explaining why"
    - "`scripts/install.sh --skills-only` is a recognized flag (works for users WITH the CLI too — explicit opt-in)"
    - "In --skills-only mode, skills land at `~/.claude/plugins/tk-skills/<name>/`, NOT `~/.claude/skills/<name>/` (Desktop install location)"
    - "When user passes an explicit flag (`--mcps`, `--skills`, `--components`, `--yes`) the auto-routing does NOT activate — explicit > implicit"
    - "An `is_claude_cli_installed` probe exists in scripts/lib/detect2.sh (or as a new helper in install.sh) and uses `command -v claude` — fail-soft on absence"
    - "`skills_install` accepts an optional override path (env var `TK_SKILLS_HOME` already exists) so the Desktop-routing branch can redirect target dir without changing the helper's contract"
    - "Hermetic test scenario S10 in test-install-tui.sh proves Desktop auto-routing: claude CLI absent + no flags → skills land in Desktop tree, banner printed, exit 0"
  artifacts:
    - path: "scripts/install.sh"
      provides: "--skills-only flag, claude CLI probe, Desktop auto-routing branch, banner output"
      contains: "skills-only"
    - path: "scripts/lib/skills.sh"
      provides: "Updated skills_install helper or _skills_default_home that respects TK_SKILLS_HOME for Desktop tree"
      contains: "TK_SKILLS_HOME"
    - path: "scripts/tests/test-install-tui.sh"
      provides: "S10 scenario: Desktop auto-routing test"
      contains: "S10"
  key_links:
    - from: "scripts/install.sh (argparse loop)"
      to: "--skills-only flag handler"
      via: "case branch in argparse loop"
      pattern: "--skills-only"
    - from: "scripts/install.sh (auto-detect block)"
      to: "TK_SKILLS_HOME export"
      via: "export TK_SKILLS_HOME=$HOME/.claude/plugins/tk-skills"
      pattern: "plugins/tk-skills"
    - from: "scripts/install.sh"
      to: "is_claude_cli_installed function"
      via: "command -v claude probe"
      pattern: "command -v claude"
    - from: "scripts/tests/test-install-tui.sh (S10)"
      to: "scripts/install.sh Desktop auto-routing"
      via: "PATH override removing claude binary"
      pattern: "S10"
---

<objective>
Wire `scripts/install.sh` so that Desktop-only users (no `claude` CLI on PATH)
who run the installer are automatically routed to a `--skills-only` install
branch. Skills land in the Desktop install location
`~/.claude/plugins/tk-skills/<name>/` (instead of `~/.claude/skills/<name>/`)
matching where Claude Desktop's plugin runtime looks for installed plugins.

Per CONTEXT.md decisions:

- **Auto-detection trigger:** `command -v claude` returns non-zero AND no
  explicit page flag (`--mcps` / `--skills` / `--components`) is passed AND
  `--yes` is not passed. Sets `TK_DESKTOP_ONLY=1` internally and promotes to
  `--skills-only` mode.
- **`--skills-only` is also explicitly callable** for users who have the CLI
  but want only the skills (per CONTEXT.md "Specifics" section).
- **Banner content (verbatim from CONTEXT.md):**
  `Claude CLI not detected — installing skills only. Skills available in Claude Desktop Code tab. See docs/CLAUDE_DESKTOP.md for full capability matrix.`
- **Other components not offered** in skills-only mode (no MCPs, no security
  setup, no statusline).
- **Mechanism:** export `TK_SKILLS_HOME=$HOME/.claude/plugins/tk-skills` BEFORE
  invoking the skills branch — `scripts/lib/skills.sh:_skills_default_home`
  already honors this seam, so zero-changes-to-skills.sh is the goal.

Output: argparse extension + auto-detect block + 1 banner + 1 hermetic test
scenario (S10).

Purpose: deliver DESK-03 (Desktop-only auto-routing).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md
@.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-01-marketplace-surface-PLAN.md
@.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-02-validators-and-make-wiring-PLAN.md
@scripts/install.sh
@scripts/lib/skills.sh
@scripts/lib/detect2.sh
@scripts/tests/test-install-tui.sh

<interfaces>
<!-- Verbatim contracts the executor needs. Do NOT explore beyond this block. -->

Existing argparse loop in scripts/install.sh (lines 45-77):

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)       YES=1;       shift ;;
        --no-color)  NO_COLOR=1;  export NO_COLOR; shift ;;
        --dry-run)   DRY_RUN=1;   shift ;;
        --force)     FORCE=1;     shift ;;
        --fail-fast) FAIL_FAST=1; shift ;;
        --no-banner) NO_BANNER=1; shift ;;
        --mcps)      MCPS=1;      shift ;;
        --skills)    SKILLS=1;    shift ;;
        # ... add --skills-only HERE ...
        ...
    esac
done
```

Existing routing-gate block (line 172 onward):

```bash
# --mcps and --skills are mutually exclusive: exactly one of three branches runs per invocation.
if [[ "$MCPS" -eq 1 && "$SKILLS" -eq 1 ]]; then
    echo -e "${RED}✗${NC} --mcps and --skills are mutually exclusive" >&2
    exit 1
fi

if [[ "$MCPS" -eq 1 ]]; then
    # MCP catalog page ...
    exit 0
fi

if [[ "$SKILLS" -eq 1 ]]; then
    # Skills catalog page ...
    exit 0
fi

# Default: components page (Phase 24)
```

Plan 03 must:

1. Add `--skills-only` flag setting `SKILLS_ONLY=1` (and also setting `SKILLS=1`
   for downstream branch reuse).
2. After argparse, BEFORE the routing gate, run a Desktop-detection block:

   ```bash
   # DESK-03: auto-route Desktop-only users (no claude CLI) to skills-only mode
   # when no explicit page flag is set.
   TK_DESKTOP_ONLY=0
   if ! command -v claude >/dev/null 2>&1; then
       TK_DESKTOP_ONLY=1
   fi

   AUTO_SKILLS_ONLY=0
   if [[ "$TK_DESKTOP_ONLY" -eq 1 \
         && "$MCPS" -eq 0 \
         && "$SKILLS" -eq 0 \
         && "$SKILLS_ONLY" -eq 0 \
         && "$YES" -eq 0 ]]; then
       AUTO_SKILLS_ONLY=1
       SKILLS_ONLY=1
       SKILLS=1
   fi
   ```

3. When SKILLS_ONLY=1, BEFORE the existing `if [[ "$SKILLS" -eq 1 ]]` branch,
   export `TK_SKILLS_HOME` to redirect target:

   ```bash
   if [[ "$SKILLS_ONLY" -eq 1 ]]; then
       export TK_SKILLS_HOME="$HOME/.claude/plugins/tk-skills"
       if [[ "$AUTO_SKILLS_ONLY" -eq 1 ]]; then
           echo ""
           echo -e "${YELLOW}!${NC} Claude CLI not detected — installing skills only."
           echo "  Skills available in Claude Desktop Code tab."
           echo "  See docs/CLAUDE_DESKTOP.md for full capability matrix."
           echo ""
       else
           echo ""
           echo -e "${BLUE}i${NC} --skills-only mode: skills install to ~/.claude/plugins/tk-skills/"
           echo ""
       fi
   fi
   ```

4. The existing `if [[ "$SKILLS" -eq 1 ]]` skills-page branch (line 350) runs
   unchanged — the redirected `TK_SKILLS_HOME` env-var is already honored by
   `_skills_default_home()` in scripts/lib/skills.sh.

Existing scripts/lib/skills.sh seam (line 60-62):

```bash
_skills_default_home() {
    echo "${TK_SKILLS_HOME:-$HOME/.claude/skills}"
}
```

This already accepts an override. Plan 03 just sets the env-var before the
existing skills branch runs.

Existing test-install-tui.sh has 9 scenarios (S1-S9). Plan 03 adds S10:

```bash
S10_desktop_auto_skills_only_routing() {
    local section="S10_desktop_auto_skills_only_routing"
    local sandbox; sandbox=$(mktemp -d)
    # Override PATH so 'claude' is missing.
    local fake_path; fake_path=$(mktemp -d)
    # Override TUI TTY to non-existent (force --yes-style fall-through? No —
    # we want auto-route from CLI absence even WITHOUT --yes).
    # Actually: AUTO_SKILLS_ONLY only fires when YES=0, so we DO need a TTY.
    # Use a real fixture file as TTY source.
    local tty_fixture="$sandbox/tty.in"
    : > "$tty_fixture"  # empty — selection gets canceled, but the auto-route
    # branch fires BEFORE TUI rendering so we'll see the banner.

    # Run install.sh with PATH stripped of claude.
    PATH="$fake_path" \
    HOME="$sandbox" \
    TK_TUI_TTY_SRC="$tty_fixture" \
    TK_SKILLS_MIRROR_PATH="$REPO_ROOT/templates/skills-marketplace" \
    bash "$REPO_ROOT/scripts/install.sh" 2>&1 | tee "$sandbox/out.log"

    # Banner should be in output.
    assert_contains "$section" "Claude CLI not detected" "$(cat "$sandbox/out.log")"
    assert_contains "$section" "skills only" "$(cat "$sandbox/out.log")"

    # Skills catalog branch should have entered (look for catalog header
    # printed by skills branch — choose a stable string, e.g. "skill(s)").
    # If no TTY interaction, the branch exits cleanly with "No TTY available
    # for skills TUI" — that's still proof the skills branch was entered,
    # which proves the auto-route worked.
    assert_contains "$section" "No TTY available for skills TUI" "$(cat "$sandbox/out.log")"

    rm -rf "$sandbox" "$fake_path"
}
```

Test seams already established (D-23 + D-24 from Phase 24):
- `TK_TUI_TTY_SRC` — overrides /dev/tty path
- `TK_SKILLS_MIRROR_PATH` — overrides skills source
- `TK_SKILLS_HOME` — overrides skills target

Existing test runner pattern (from test-install-tui.sh tail):

```bash
echo "Running test-install-tui.sh..."
S1_detect
S2_detect
S3_yes
S4_dry_run
S5_force
S6_fail_fast
S7_no_tty
S8_stderr_tail
S9_no_tty_bootstrap_fork
# add S10_desktop_auto_skills_only_routing
echo ""
echo "PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add --skills-only flag + Desktop auto-routing block to scripts/install.sh</name>
  <files>scripts/install.sh</files>
  <read_first>
    - scripts/install.sh (full read — 800 lines; pay close attention to lines 40-80 argparse, lines 130-180 source + routing gate, lines 350-450 skills branch)
    - scripts/lib/skills.sh (lines 50-70 — _skills_default_home seam)
  </read_first>
  <action>
1. In scripts/install.sh, add `SKILLS_ONLY=0` to the flag defaults block (near
   line 42 where `MCPS=0`, `SKILLS=0` are declared):

   ```bash
   MCPS=0
   SKILLS=0
   SKILLS_ONLY=0
   ```

2. Extend the argparse loop (around line 47-58) to handle `--skills-only`.
   Add this case BEFORE the catch-all `*)` branch:

   ```bash
       --skills-only) SKILLS_ONLY=1; SKILLS=1; shift ;;
   ```

   Setting BOTH `SKILLS_ONLY=1` and `SKILLS=1` lets the existing skills branch
   (line 350 onward) run unchanged. The `SKILLS_ONLY=1` flag is what gates
   target-directory redirection.

3. Update the `--help` output (around line 60-77) to document the new flag.
   Add this line in the usage section, after the `--skills` line:

   ```
   --skills-only Install skills to Desktop tree (~/.claude/plugins/tk-skills/);
                 auto-activates when 'claude' CLI is absent on PATH (DESK-03)
   ```

4. Insert the Desktop auto-detection block AFTER the routing gate's mutex check
   (after the `if [[ "$MCPS" -eq 1 && "$SKILLS" -eq 1 ]]` block; before the
   `if [[ "$MCPS" -eq 1 ]]` block — around line 180):

   ```bash
   # ─────────────────────────────────────────────────
   # DESK-03: Desktop-only auto-routing.
   # Trigger condition (all must hold):
   #   - `command -v claude` returns non-zero (CLI absent)
   #   - no explicit page flag set (--mcps, --skills, --skills-only)
   #   - --yes not passed (CI / non-interactive paths get the components branch)
   # When triggered: promote to --skills-only mode + print explanatory banner.
   # ─────────────────────────────────────────────────
   TK_DESKTOP_ONLY=0
   if ! command -v claude >/dev/null 2>&1; then
       TK_DESKTOP_ONLY=1
   fi

   AUTO_SKILLS_ONLY=0
   if [[ "$TK_DESKTOP_ONLY" -eq 1 \
         && "$MCPS" -eq 0 \
         && "$SKILLS" -eq 0 \
         && "$SKILLS_ONLY" -eq 0 \
         && "$YES" -eq 0 ]]; then
       AUTO_SKILLS_ONLY=1
       SKILLS_ONLY=1
       SKILLS=1
   fi

   if [[ "$SKILLS_ONLY" -eq 1 ]]; then
       export TK_SKILLS_HOME="$HOME/.claude/plugins/tk-skills"
       if [[ "$AUTO_SKILLS_ONLY" -eq 1 ]]; then
           echo ""
           echo -e "${YELLOW}!${NC} Claude CLI not detected — installing skills only."
           echo "  Skills available in Claude Desktop Code tab."
           echo "  See docs/CLAUDE_DESKTOP.md for full capability matrix."
           echo ""
       else
           echo ""
           echo -e "${BLUE}i${NC} --skills-only mode: skills install to ~/.claude/plugins/tk-skills/"
           echo ""
       fi
   fi
   ```

5. Update the routing comment (the existing `Routing gate: --mcps takes the
   MCP page; --skills takes the Skills page;` block on line 173) to mention
   `--skills-only`:

   ```bash
   # Routing gate: --mcps takes the MCP page; --skills (or --skills-only / Desktop
   # auto-route) takes the Skills page; default is the Phase 24 components page.
   # Mutex — exactly one of three branches per invocation.
   ```

6. Update the closing helper-text in the skills branch (line 503):

   ```bash
   # Find the existing line that prints removal hint:
   #   echo "To remove a skill: rm -rf ~/.claude/skills/<name>"
   # Replace with conditional:
   if [[ "$SKILLS_ONLY" -eq 1 ]]; then
       echo "To remove a skill: rm -rf ~/.claude/plugins/tk-skills/<name>"
   else
       echo "To remove a skill: rm -rf ~/.claude/skills/<name>"
   fi
   ```

7. Verify shellcheck passes:

   ```bash
   shellcheck -S warning scripts/install.sh
   ```

8. Sanity-test the auto-routing manually (in a sandbox where `claude` is not
   on PATH):

   ```bash
   PATH=/usr/bin:/bin bash scripts/install.sh --dry-run < /dev/null 2>&1 | head -20
   ```

   Should print the "Claude CLI not detected" banner if `claude` isn't in
   /usr/bin or /bin. If the maintainer's `claude` is in a sandboxed PATH, the
   banner should NOT appear.

9. Verify existing tests stay green:

   ```bash
   bash scripts/tests/test-install-tui.sh
   bash scripts/tests/test-bootstrap.sh
   bash scripts/tests/test-mcp-selector.sh
   bash scripts/tests/test-install-skills.sh
   ```

   All four must report `PASS=N FAIL=0`. Any FAIL is a regression — fix it
   before committing.

10. Commit: `git add scripts/install.sh && git commit -m "feat(27): add --skills-only flag + Desktop auto-routing for CLI-absent users (DESK-03)"`
  </action>
  <verify>
    <automated>
shellcheck -S warning scripts/install.sh \
  && grep -q '\-\-skills-only) SKILLS_ONLY=1' scripts/install.sh \
  && grep -q 'TK_DESKTOP_ONLY' scripts/install.sh \
  && grep -q 'Claude CLI not detected' scripts/install.sh \
  && grep -q 'TK_SKILLS_HOME=.HOME/.claude/plugins/tk-skills' scripts/install.sh \
  && grep -q 'AUTO_SKILLS_ONLY' scripts/install.sh \
  && bash scripts/tests/test-install-tui.sh > /tmp/t1.out 2>&1 \
  && grep -qE 'FAIL=0' /tmp/t1.out \
  && bash scripts/tests/test-bootstrap.sh > /tmp/t2.out 2>&1 \
  && grep -qE 'FAIL=0' /tmp/t2.out \
  && bash scripts/tests/test-install-skills.sh > /tmp/t3.out 2>&1 \
  && grep -qE 'FAIL=0' /tmp/t3.out \
  && echo "PASS: install.sh updated, all existing tests green"
    </automated>
  </verify>
  <done>
    - `scripts/install.sh` defines `SKILLS_ONLY=0`, parses `--skills-only` flag
    - Auto-detection block sets `TK_DESKTOP_ONLY=1` when `command -v claude` fails
    - When auto-route condition holds (CLI absent + no page flags + no --yes), promotes to `--skills-only` and prints documented banner
    - When `SKILLS_ONLY=1`, exports `TK_SKILLS_HOME=$HOME/.claude/plugins/tk-skills` BEFORE the skills branch runs
    - `--help` output mentions `--skills-only`
    - Removal hint at end of skills branch is conditional on `SKILLS_ONLY` (mentions `~/.claude/plugins/tk-skills/` when set, `~/.claude/skills/` otherwise)
    - Existing tests (test-install-tui, test-bootstrap, test-mcp-selector, test-install-skills) still pass
    - shellcheck-warning gate clean
  </done>
  <acceptance_criteria>
    - `grep -c '\-\-skills-only' scripts/install.sh` returns ≥ 3 (default, argparse case, --help line)
    - `grep -c 'TK_SKILLS_HOME' scripts/install.sh` returns ≥ 1 (export line in SKILLS_ONLY block)
    - `grep -c 'Claude CLI not detected' scripts/install.sh` returns exactly 1 (banner line)
    - `grep -c 'plugins/tk-skills' scripts/install.sh` returns ≥ 2 (export + removal hint)
    - `shellcheck -S warning scripts/install.sh` exits 0
    - All four existing test files still report `FAIL=0` after the change
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: Add S10 hermetic test scenario for Desktop auto-routing in test-install-tui.sh</name>
  <files>scripts/tests/test-install-tui.sh</files>
  <read_first>
    - scripts/tests/test-install-tui.sh (full file — focus on test runner tail and existing scenarios S7/S9 for PATH/TTY override patterns)
    - scripts/install.sh (verify S10's expected output strings match what install.sh actually prints)
  </read_first>
  <action>
1. Add a new scenario function S10 to `scripts/tests/test-install-tui.sh`,
   placed after the S9 function and before the test-runner tail. The function
   must use the existing `assert_*` and `${REPO_ROOT}` patterns from earlier
   scenarios.

   Recommended template (adjust assert function names to match the file's
   existing helpers — re-read test-install-tui.sh line 1-50 to confirm names):

   ```bash
   S10_desktop_auto_skills_only_routing() {
       local section="S10_desktop_auto_skills_only_routing"
       local sandbox; sandbox=$(mktemp -d -t tk-tui-s10-XXXXXX)
       CLEANUP_PATHS+=("$sandbox")

       # Empty PATH ensures `claude` is missing — triggers DESK-03 auto-route.
       local fake_path; fake_path=$(mktemp -d -t tk-fake-path-XXXXXX)
       CLEANUP_PATHS+=("$fake_path")

       # Empty TTY fixture: skills branch will hit "No TTY available" exit
       # AFTER the auto-route block prints its banner. We assert on the banner
       # plus the proof that we entered the skills branch.
       local tty_fixture="$sandbox/tty.in"
       : > "$tty_fixture"

       local out; out=$(PATH="$fake_path" \
                        HOME="$sandbox" \
                        TK_TUI_TTY_SRC="$tty_fixture" \
                        TK_SKILLS_MIRROR_PATH="$REPO_ROOT/templates/skills-marketplace" \
                        bash "$REPO_ROOT/scripts/install.sh" 2>&1 || true)

       # A1: banner from auto-route block.
       assert_contains "$section/A1" "Claude CLI not detected" "$out"
       # A2: link to capability matrix.
       assert_contains "$section/A2" "docs/CLAUDE_DESKTOP.md" "$out"
       # A3: proof skills branch was entered (no-TTY exit message from skills page).
       assert_contains "$section/A3" "No TTY available for skills TUI" "$out"
       # A4: TK_SKILLS_HOME redirected to plugins/tk-skills tree (proof: removal hint).
       # On no-TTY exit, the removal hint may not print — alternative: dry-run check.

       # Re-run with --dry-run + --yes to assert the redirection takes effect.
       local out2; out2=$(PATH="$fake_path" \
                          HOME="$sandbox" \
                          TK_SKILLS_MIRROR_PATH="$REPO_ROOT/templates/skills-marketplace" \
                          bash "$REPO_ROOT/scripts/install.sh" --skills-only --yes --dry-run 2>&1 || true)
       # A5: would-install rows reference plugins/tk-skills tree (or just confirm the
       # explicit-mode banner).
       assert_contains "$section/A5" "plugins/tk-skills" "$out2"
   }
   ```

   IMPORTANT: re-read `scripts/tests/test-install-tui.sh` to confirm:
   - The exact assert helper name (likely `assert_contains` or similar — match
     exactly what's used in S1-S9).
   - Whether `CLEANUP_PATHS` is the cleanup-array convention or another name.
   - Whether `REPO_ROOT` is set or another variable holds the path.

2. Add S10 to the test runner at the bottom of the file (alongside the other
   `S1_detect`, `S2_detect`, ..., `S9_no_tty_bootstrap_fork` calls):

   ```bash
   S1_detect
   S2_detect
   S3_yes
   S4_dry_run
   S5_force
   S6_fail_fast
   S7_no_tty
   S8_stderr_tail
   S9_no_tty_bootstrap_fork
   S10_desktop_auto_skills_only_routing
   ```

3. Run the test:

   ```bash
   bash scripts/tests/test-install-tui.sh
   ```

   Expected: PASS count increases by ≥ 4 (the new assertions A1-A4 or A1-A5),
   FAIL=0. The previous total was PASS=38, FAIL=0; new total should be PASS=43+
   or so — exact number depends on how many `assert_contains` calls land.

4. If A5's `plugins/tk-skills` substring isn't in `--dry-run` output of
   install.sh, refine the assertion (option: instead of A5, assert that the
   explicit-mode banner `--skills-only mode: skills install to ~/.claude/plugins/tk-skills/`
   appears in `out2`). Use whichever string is reliably emitted.

5. Verify shellcheck pass on the test file:

   ```bash
   shellcheck -S warning scripts/tests/test-install-tui.sh
   ```

6. Verify CI step name still applies (check 21-33 step still encompasses the new
   scenario without renaming — S10 is just a new function, the step name doesn't
   list scenario counts so no change needed).

7. Commit: `git add scripts/tests/test-install-tui.sh && git commit -m "test(27): add S10 Desktop auto-routing scenario to test-install-tui.sh (DESK-03)"`
  </action>
  <verify>
    <automated>
shellcheck -S warning scripts/tests/test-install-tui.sh \
  && grep -q 'S10_desktop_auto_skills_only_routing' scripts/tests/test-install-tui.sh \
  && bash scripts/tests/test-install-tui.sh > /tmp/s10.out 2>&1 \
  && grep -qE 'FAIL=0' /tmp/s10.out \
  && PASS=$(grep -oE 'PASS=[0-9]+' /tmp/s10.out | head -1 | sed 's/PASS=//') \
  && test "$PASS" -gt 38 \
  && echo "PASS: S10 added, total assertions=$PASS (>38 baseline)"
    </automated>
  </verify>
  <done>
    - `scripts/tests/test-install-tui.sh` contains a `S10_desktop_auto_skills_only_routing` function
    - S10 is invoked in the runner block at the bottom of the file
    - S10 asserts on at least 3 strings: `Claude CLI not detected`, `docs/CLAUDE_DESKTOP.md`, and a proof of skills branch entry
    - Total assertion count increases vs the pre-change baseline
    - `bash scripts/tests/test-install-tui.sh` reports `PASS=N FAIL=0` with N > 38 (previous baseline)
    - shellcheck-warning still clean
  </done>
  <acceptance_criteria>
    - `grep -c 'S10_desktop' scripts/tests/test-install-tui.sh` returns ≥ 2 (function definition + runner invocation)
    - `bash scripts/tests/test-install-tui.sh` exits 0 with `FAIL=0` in output
    - Total `PASS=N` count is strictly greater than 38 (baseline before S10)
    - shellcheck warning gate passes on the test file
  </acceptance_criteria>
</task>

</tasks>

<verification>
After both tasks:

1. `scripts/install.sh` has 3 new identifiers: `--skills-only` flag,
   `SKILLS_ONLY` variable, and `AUTO_SKILLS_ONLY` variable.
2. The auto-route banner text matches CONTEXT.md verbatim spec.
3. `scripts/lib/skills.sh` is untouched (its existing `TK_SKILLS_HOME` seam
   handles redirection).
4. `scripts/tests/test-install-tui.sh` contains S10 scenario.

Run the full test suite:
```bash
bash scripts/tests/test-install-tui.sh   # must report FAIL=0 and PASS > 38
bash scripts/tests/test-bootstrap.sh     # must report FAIL=0
bash scripts/tests/test-install-skills.sh # must report FAIL=0
make check                                # must exit 0
```

All four must succeed.
</verification>

<success_criteria>
- `scripts/install.sh` accepts `--skills-only` flag (explicit) and auto-routes to skills-only mode when `command -v claude` fails AND no page flag AND no --yes (DESK-03)
- Desktop banner printed on auto-route exactly as documented in CONTEXT.md
- `TK_SKILLS_HOME=$HOME/.claude/plugins/tk-skills` exported BEFORE skills branch runs, so installed skills land in Desktop tree
- Hermetic test S10 in test-install-tui.sh proves the auto-route path
- Existing tests (test-install-tui, test-bootstrap, test-install-skills, test-mcp-selector) all stay green
- `make check` passes end-to-end
</success_criteria>

<output>
After completion, create `.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-03-install-sh-desktop-routing-SUMMARY.md` with:

- `requirements_addressed: [DESK-03]`
- `tests_passing`: list test files + PASS counts after change
- `behavioral_diff`: before vs after (what install.sh does for a CLI-absent user)
- Note any deviations (e.g. if S10 needed alternate assertions due to install.sh output realities)
</output>
