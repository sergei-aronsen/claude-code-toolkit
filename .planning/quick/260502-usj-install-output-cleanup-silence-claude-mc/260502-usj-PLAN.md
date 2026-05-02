---
quick_id: 260502-usj
mode: quick
description: Install output cleanup (Phase 36-A polish) — silence claude mcp add chatter, recolor skipped status grey, drop duplicate Integrations Install Summary table, drop trailing key-rotation block, align bridge skip-message indent, rename "To remove" → "To uninstall"
files_modified:
  - scripts/install.sh
  - scripts/lib/mcp.sh
  - scripts/lib/dry-run-output.sh
  - scripts/lib/bridges.sh
  - scripts/init-claude.sh
  - scripts/init-local.sh
  - scripts/update-claude.sh
  - scripts/tests/test-integrations-tui.sh
  - scripts/tests/test-install-banner.sh
autonomous: true
---

<objective>
Three surgical UX fixes to install.sh's MCP install output, against current main (CI green, Phase 36-A merged at 35a1f90):

1. Silence `claude mcp add` per-call chatter ("Added stdio MCP server …", "File modified: …") that escapes the existing stderr capture wrapper because the CLI writes them to stdout.
2. Recolor the per-row "skipped" status from yellow (currently visually identical to "needs API key") to dim grey so the eye triages it as low-signal.
3. Remove the duplicate "Integrations Install Summary" matrix table that renders right after the per-row "MCP install summary:" block — it carries the same information twice.

Purpose: The Phase 36-A install flow is correct but visually noisy and double-renders its summary. These three fixes land the v4.9.x polish without touching install logic.

Output: Cleaner install transcript — one summary block (the per-row one), grey skipped rows, no leaked `claude mcp add` lines on success.
</objective>

<context>
@.planning/STATE.md
@CLAUDE.md
@scripts/install.sh
@scripts/lib/mcp.sh
@scripts/lib/dry-run-output.sh
@scripts/tests/test-integrations-tui.sh

<interfaces>
<!-- Key facts from the codebase that the executor needs upfront. -->

`scripts/install.sh:288-300` — `print_install_status()` definition. Switch statement
maps state strings to color vars. Uses `_DRO_*` color globals from
`scripts/lib/dry-run-output.sh` (initialised at install.sh:276 by `dro_init_colors`).
Current `skipped)` arm uses `${_DRO_Y:-}` (yellow) — same color as
`installed (needs API key)` arm above, which makes the two visually indistinguishable.

`scripts/install.sh:540-571` — MCP install dispatch wrapper. Already captures
**stderr** to a per-MCP `stderr_tmp` file:

```bash
( mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" ) 2>"$stderr_tmp" || local_rc=$?
```

The leaked lines come from `claude mcp add`'s **stdout** ("Added stdio MCP
server …", "File modified: /Users/.../.claude.json …"). They escape the wrapper.
Fix: also capture stdout, drop on success, retain alongside stderr on failure.

`scripts/install.sh:611-624` — failure arm. `COMPONENT_STDERR_TAIL[]` is
populated from `tail -5 "$stderr_tmp"`. The summary loop (install.sh:738-747)
prints these indented under failure rows. Stdout chatter must NOT pollute that
tail — combine stdout+stderr into one tmpfile so users see what actually went
wrong.

`scripts/install.sh:730-751` — per-row "MCP install summary:" block. Calls
`print_install_status` per entry, then a totals line:

```text
Installed: N · Skipped: M · Failed: K
```

This block stays. It is what tests test-mcp-selector.sh:S7 (line 384) and
test-bridges-install-ux.sh BACKCOMPAT-01 grep for ("MCP install summary").

`scripts/install.sh:752-758` — duplicate matrix table call:

```bash
# Phase 34-03 (TUI-05): per-component summary table…
print_integrations_summary
```

Renders Entry / MCP / CLI / Notes columns + a second totals line of shape
"Installed: N MCPs, M CLIs · Skipped: X · Failed: Y". Duplicates the per-row
block above. **Drop both the call AND the function definition.**

`scripts/lib/mcp.sh:315-467` — `print_integrations_summary()` function (Phase 34-03,
TUI-05). After Task 3 lands it has zero callers — delete the entire function +
the leading "Phase 34-03 (TUI-05)" doc-comment block (lines 315-338) so we don't
leave orphan code behind.

`scripts/lib/dry-run-output.sh:21-39` — `dro_init_colors()`. Defines `_DRO_G`
(green), `_DRO_C` (cyan), `_DRO_Y` (yellow), `_DRO_R` (red), `_DRO_NC` (reset).
**No grey constant exists yet** — Task 2 adds `_DRO_GREY` here following the
exact same TTY + NO_COLOR gating pattern.

`scripts/tests/test-integrations-tui.sh:267-287` — A12 + A13 + A14 assertions:

- A12 (line 270): `assert_contains "Integrations Install Summary" "$i_out" …`
  → DELETE (banner gone after Task 3).
- A13 (lines 275-278): `assert_contains "Entry" / "MCP" / "CLI" / "Notes" …`
  → DELETE (matrix table headers gone).
- A14 (lines 283-287): `assert_contains "Installed:" / "MCPs" / "CLIs" / "Skipped:" / "Failed:"`
  → KEEP "Installed:" / "Skipped:" / "Failed:" (per-row block still has its own totals
  line of shape `Installed: N · Skipped: M · Failed: K`); DELETE the "MCPs" + "CLIs"
  assertions specifically (those substrings only existed in the matrix totals line).

Result: A12 + A13 + (A14's MCPs + CLIs lines) deleted = 6 assertions removed.
A11 and A14's surviving 3 assertions keep the file's PASS count internally
consistent. **No assertion in test-mcp-selector.sh or test-install-tui.sh
greps for "Integrations Install Summary" or "MCPs," — those tests are unaffected.**

`scripts/tests/test-bridges-sync.sh:327` — asserts `PASS=58 FAIL=0` from
test-install-tui.sh. test-install-tui.sh does NOT grep for any of the strings
removed by these fixes (verified by grep — zero matches for "MCP install summary",
"Integrations Install Summary", "MCPs, "). PASS=58 baseline stays intact.

`scripts/tests/test-bridges-install-ux.sh:255-258` — asserts the same baselines
including `test-install-tui.sh:PASS=58 FAIL=0`. Unaffected for the same reason.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Capture claude mcp add stdout to silence install chatter</name>
  <files>scripts/install.sh</files>
  <action>
At scripts/install.sh:567-571, change the dispatch wrapper to capture BOTH
stdout and stderr to `stderr_tmp` (combined stream), so `claude mcp add`'s
"Added stdio MCP server <name> with command: …" / "File modified: …" stdout
lines are no longer leaked to the user's terminal during the install loop.

Current code:

```bash
local_rc=0
if [[ -n "$stderr_tmp" ]]; then
    ( mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" ) 2>"$stderr_tmp" || local_rc=$?
else
    mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" || local_rc=$?
fi
```

Replace with combined-capture form:

```bash
local_rc=0
if [[ -n "$stderr_tmp" ]]; then
    ( mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" ) >"$stderr_tmp" 2>&1 || local_rc=$?
else
    mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" || local_rc=$?
fi
```

Rationale: `claude mcp add` writes confirmation lines to stdout, not stderr.
Just adding `>"$stderr_tmp"` on the same redirect line collapses both streams
into the temp file. On success the file is dropped (no code path reads it for
rc=0/2/3). On failure (rc=*), the existing `tail -5 "$stderr_tmp"` at line
615-617 picks up whatever was the last 5 lines of combined output — slightly
noisier on failure than pure stderr, but the user already wanted that
context (it's the same data, just a few extra lines).

Do NOT change:
- The `( … )` subshell — keeps wizard env-var pollution scoped.
- The fallback branch (no `stderr_tmp`) — when mktemp failed there's nowhere
  to redirect to, current passthrough behavior is correct.
- The CLI install branch at install.sh:695-699 — that one already uses
  `>"$cli_stderr_tmp" 2>&1` (combined). Confirms this pattern is the right
  shape; this task brings the MCP branch into parity.
- The `--dry-run` path inside `mcp_wizard_run` (mcp.sh:811-814) — it prints
  `[+ INSTALL] mcp <name> (would run: …)` to stdout. That line WAS being
  printed visibly under --dry-run (no MCP wizard collapse there because
  rc=0 stdout was untouched before). After this change it gets captured
  too and silently dropped. That's acceptable: the per-row summary
  already shows `would-install` for the same entries, and the
  `print_integrations_summary` call already echoed the would-install rows
  separately (until Task 3 removes that). For symmetry with non-dry-run,
  the dry-run wizard chatter now also goes silent — net win for output
  cleanliness.
  </action>
  <verify>
    <automated>NO_COLOR=1 bash -c '
SANDBOX=$(mktemp -d /tmp/usj-t1.XXXXXX)
trap "rm -rf $SANDBOX" EXIT
MOCK="$SANDBOX/mock-claude"
cat > "$MOCK" <<MOCKEOF
#!/bin/bash
if [[ "\${1:-}" == "mcp" && "\${2:-}" == "add" ]]; then
  echo "Added stdio MCP server \${3} with command: npx test to local config"
  echo "File modified: \$HOME/.claude.json"
  exit 0
fi
if [[ "\${1:-}" == "mcp" && "\${2:-}" == "list" ]]; then
  exit 0
fi
exit 0
MOCKEOF
chmod +x "$MOCK"
HOME="$SANDBOX" TK_MCP_CONFIG_HOME="$SANDBOX" TK_MCP_CLAUDE_BIN="$MOCK" \
  bash scripts/install.sh --integrations --yes 2>&1 | tee "$SANDBOX/full" >/dev/null
# After fix: zero "Added stdio MCP server" lines in user-visible output.
COUNT=$(grep -c "Added stdio MCP server" "$SANDBOX/full" || true)
if [[ "$COUNT" -ne 0 ]]; then
  echo "FAIL: $COUNT chatter lines leaked"; exit 1
fi
echo "OK: chatter silenced"
'</automated>
  </verify>
  <done>
- scripts/install.sh:567-571 dispatch wrapper redirects stdout+stderr (`>"$stderr_tmp" 2>&1`).
- Manual smoke (verify command) shows zero `Added stdio MCP server` and zero `File modified:` lines in install output for successful MCP installs against a mock claude.
- `bash scripts/tests/test-mcp-selector.sh` still green (S7 still finds "MCP install summary" string in its captured output — that string is printed BY install.sh, not by claude, so it's outside the wrapper).
- `bash scripts/tests/test-install-tui.sh` still PASS=58.
- `bash scripts/tests/test-mcp-wizard.sh` still green.
- `make shellcheck` clean (no new warnings on install.sh).
  </done>
</task>

<task type="auto">
  <name>Task 2: Recolor "skipped" status from yellow to dim grey</name>
  <files>scripts/lib/dry-run-output.sh, scripts/install.sh</files>
  <action>
Add a new `_DRO_GREY` color constant to `scripts/lib/dry-run-output.sh` and
use it for the `skipped)` arm of `print_install_status` in scripts/install.sh.
Yellow currently doubles as the "needs API key" signal — making "skipped"
look identical defeats the triage goal of the per-row summary block.

Step 1 — `scripts/lib/dry-run-output.sh:21-39`, extend `dro_init_colors()`:

```bash
dro_init_colors() {
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
        _DRO_G='\033[0;32m'   # green  — [+ INSTALL]
        _DRO_C='\033[0;36m'   # cyan   — [~ UPDATE]
        _DRO_Y='\033[1;33m'   # yellow — [- SKIP]
        _DRO_R='\033[0;31m'   # red    — [- REMOVE]
        _DRO_GREY='\033[90m'  # dim grey — low-signal "skipped" / "already" rows
        _DRO_NC='\033[0m'
    else
        _DRO_G=''
        _DRO_C=''
        _DRO_Y=''
        _DRO_R=''
        _DRO_GREY=''
        _DRO_NC=''
    fi
}
```

Also update the `# Globals:` header comment on line 6 to add `_DRO_GREY`:

```bash
# Globals: _DRO_G _DRO_C _DRO_Y _DRO_R _DRO_GREY _DRO_NC (set by dro_init_colors)
```

Step 2 — `scripts/install.sh:296`, swap the `skipped)` color from `_DRO_Y`
to `_DRO_GREY`:

```bash
skipped)        printf '  %b%-30s %s%b\n' "${_DRO_GREY:-}" "$component" "$state" "${_DRO_NC:-}" ;;
```

Leave every other arm untouched:
- `installed (needs API key)` keeps yellow (`_DRO_Y`) — that IS still a state
  the user needs to act on.
- `installed*` keeps green (`_DRO_G`).
- `would-install` keeps cyan (`_DRO_C`).
- `failed*` keeps red (`_DRO_R`).
- The default `*)` arm (line 298) stays uncolored.

Note: install.sh does NOT currently reference `_DRO_GREY` anywhere else.
This is a one-call-site swap. The wildcard-prefixed states like
`skipped: claude unavailable` and `skipped:fail-fast` (set in install.sh:596,
637, 641) match the bare `skipped)` arm via the case fall-through ONLY when
the state is exactly `skipped`. The compound forms like `skipped: claude unavailable`
fall through to the default `*)` arm (uncolored) under current code — that
behavior is preserved (no change to wildcard handling). If we wanted them
also grey, we'd write `skipped*)`; do NOT make that broader change in this task.
  </action>
  <verify>
    <automated>bash -c '
# Source the lib in isolation, init colors with NO_COLOR unset and TTY-on (force via subshell trick).
out=$(NO_COLOR= bash -c "
unset NO_COLOR
source scripts/lib/dry-run-output.sh
dro_init_colors
echo \"GREY=[\${_DRO_GREY:-}]\"
" 2>&1)
# Under non-TTY (no -t 1) _DRO_GREY stays empty — confirm var EXISTS (no unbound err under set -u).
if ! echo "$out" | grep -q "GREY="; then
  echo "FAIL: _DRO_GREY not set by dro_init_colors"; exit 1
fi
# Confirm install.sh now references _DRO_GREY exactly once (the skipped arm).
COUNT=$(grep -c "_DRO_GREY" scripts/install.sh || true)
if [[ "$COUNT" -ne 1 ]]; then
  echo "FAIL: expected 1 _DRO_GREY ref in install.sh, found $COUNT"; exit 1
fi
# Confirm skipped arm uses _DRO_GREY (not _DRO_Y).
if ! grep -q "skipped).*_DRO_GREY" scripts/install.sh; then
  echo "FAIL: skipped arm not updated"; exit 1
fi
echo "OK: grey wired and skipped arm switched"
'
make shellcheck</automated>
  </verify>
  <done>
- `scripts/lib/dry-run-output.sh:21-39` adds `_DRO_GREY='\033[90m'` (TTY-on path) + `_DRO_GREY=''` (TTY-off path).
- `# Globals:` comment on line 6 of dry-run-output.sh updated.
- `scripts/install.sh:296` `skipped)` arm uses `${_DRO_GREY:-}` not `${_DRO_Y:-}`.
- No other call sites changed (verified by `grep -c "_DRO_GREY" scripts/install.sh` returning 1).
- `make shellcheck` clean.
- `bash scripts/tests/test-install-tui.sh` still PASS=58.
- `bash scripts/tests/test-mcp-selector.sh` still green.
  </done>
</task>

<task type="auto">
  <name>Task 3: Drop duplicate Integrations Install Summary matrix table</name>
  <files>scripts/install.sh, scripts/lib/mcp.sh, scripts/tests/test-integrations-tui.sh</files>
  <action>
Remove the duplicate per-component matrix table that renders right after the
per-row "MCP install summary:" block. The matrix carries the same data in
a different shape (Entry / MCP / CLI / Notes columns + a totals line of shape
"Installed: N MCPs, M CLIs · Skipped: X · Failed: Y") and confuses users who
read the per-row block first and then see seemingly-different totals.

Step 1 — `scripts/install.sh:752-758`, delete the entire comment block + call:

```bash
    # Phase 34-03 (TUI-05): per-component summary table. Renders the per-entry
    # × per-component matrix from RESULT_NAMES[] / RESULT_MCP_STATE[] /
    # RESULT_CLI_STATE[] populated by the dispatch loop above. Mirrors Phase 25
    # D-28 contract; complements (does NOT replace) the per-row "MCP install
    # summary" block above (legacy block keeps test-mcp-selector S7/S13 happy).
    print_integrations_summary
```

Replace those 7 lines with nothing (collapse the blank line gap so install.sh
flows directly from the per-row totals line at install.sh:750-751 into the
"Follow-up block for MCPs registered without env vars" comment block at line
761-764).

Step 2 — `scripts/lib/mcp.sh:315-467`, delete the entire `print_integrations_summary`
function definition AND its leading documentation block. Range to remove:

- Line 315: `# print_integrations_summary — Phase 34-03 (TUI-05) — per-entry × per-component`
- … through line 467: `}`  (closing brace of `print_integrations_summary`)

Leave the surrounding code intact:
- Line 314 (blank) — keep as separator above the next function.
- Line 469: `# mcp_catalog_names — print all 9 catalog names…` — keep, this is
  the next function's doc block, no merge needed.

After removal, `print_integrations_summary` has zero callers in the entire repo
(the only caller was install.sh:758, removed in step 1). Confirm with grep:
`grep -rn "print_integrations_summary" scripts/` should return ZERO matches
after this task.

Step 3 — `scripts/tests/test-integrations-tui.sh:267-287`, prune the assertions
that depended on the matrix output:

DELETE the entire A12 block (lines 267-270):

```bash
# ─────────────────────────────────────────────────
# A12 — Integrations Install Summary banner renders under --dry-run
# ─────────────────────────────────────────────────
assert_contains "Integrations Install Summary" "$i_out" "A12: summary banner renders under --integrations --dry-run"
```

DELETE the entire A13 block (lines 272-278):

```bash
# ─────────────────────────────────────────────────
# A13 — Summary table header carries Entry / MCP / CLI / Notes columns
# ─────────────────────────────────────────────────
assert_contains "Entry" "$i_out" "A13: summary header carries Entry column"
assert_contains "MCP" "$i_out" "A13: summary header carries MCP column"
assert_contains "CLI" "$i_out" "A13: summary header carries CLI column"
assert_contains "Notes" "$i_out" "A13: summary header carries Notes column"
```

In A14 (lines 280-287), DELETE the two assertions that only exist in the
matrix totals line ("MCPs" and "CLIs"). Keep the three that still match the
per-row block totals line of shape `Installed: N · Skipped: M · Failed: K`.

After edit, A14 should look like:

```bash
# ─────────────────────────────────────────────────
# A14 — Per-row MCP install summary totals line carries shape "Installed: N · Skipped: M · Failed: K"
# ─────────────────────────────────────────────────
assert_contains "Installed:" "$i_out" "A14: summary total line carries 'Installed:'"
assert_contains "Skipped:" "$i_out" "A14: summary total line carries 'Skipped:'"
assert_contains "Failed:" "$i_out" "A14: summary total line carries 'Failed:'"
```

Re-word the A14 banner comment as shown above so the file documents WHY this
totals line still exists (it's now the per-row block's totals, not the
matrix's). Do NOT renumber A15+ — assertion IDs are stable for git-grep
debugging across history.

Total assertions removed: 1 (A12) + 4 (A13) + 2 (A14 MCPs/CLIs) = **7 assertions**.

Cross-impact verification (what the executor MUST check after edits, not
predict-and-skip):

- test-mcp-selector.sh:S7 (line 384) asserts `MCP install summary` — survives,
  that string is printed by install.sh:732 NOT by `print_integrations_summary`.
- test-install-tui.sh — DOES NOT grep for any removed string (zero matches
  for "Integrations Install Summary", "MCPs,", "Entry", "Notes" in the file).
  PASS=58 baseline stays. test-bridges-sync.sh:327 + test-bridges-install-ux.sh:256
  assertions remain valid.
- test-bridges-install-ux.sh BACKCOMPAT-01 (S13) — greps for "Install" headers
  generally; confirm by re-running.
- test-bridges-sync.sh S10b — invokes test-install-tui.sh and asserts PASS=58.

Do NOT touch:
- The per-row "MCP install summary:" header (install.sh:732). It stays.
- The per-row totals line (install.sh:750-751). It stays.
- The follow-up block for "registered without env vars" (install.sh:765+).
- The duplicate `print_install_status` site at install.sh:1877 (separate
  Skills/components branch, unrelated to this fix).
- Any RESULT_* array writes — they stay populated even though their consumer
  (`print_integrations_summary`) is gone. No reads remain after this task,
  but the writes are cheap and removing them risks accidentally dropping
  state another future caller might want. Leave the arrays in place.
  </action>
  <verify>
    <automated>bash -c '
# Confirm caller and definition are both gone.
CALL=$(grep -c "print_integrations_summary" scripts/install.sh 2>/dev/null || true)
if [[ "$CALL" -ne 0 ]]; then
  echo "FAIL: install.sh still calls print_integrations_summary ($CALL refs)"; exit 1
fi
DEF=$(grep -c "print_integrations_summary" scripts/lib/mcp.sh 2>/dev/null || true)
if [[ "$DEF" -ne 0 ]]; then
  echo "FAIL: mcp.sh still defines print_integrations_summary ($DEF refs)"; exit 1
fi
ANYWHERE=$(grep -rn "print_integrations_summary" scripts/ 2>/dev/null | wc -l | tr -d " ")
if [[ "$ANYWHERE" -ne 0 ]]; then
  echo "FAIL: residual print_integrations_summary refs ($ANYWHERE) somewhere in scripts/"; exit 1
fi
# Confirm the deleted assertions are absent and the kept ones still present.
if grep -q "Integrations Install Summary" scripts/tests/test-integrations-tui.sh; then
  echo "FAIL: A12 assertion still references removed banner"; exit 1
fi
if grep -q "summary header carries Entry column" scripts/tests/test-integrations-tui.sh; then
  echo "FAIL: A13 Entry assertion still present"; exit 1
fi
if grep -q "summary total line carries .MCPs." scripts/tests/test-integrations-tui.sh; then
  echo "FAIL: A14 MCPs assertion still present"; exit 1
fi
echo "OK: structural changes verified"
'
bash scripts/tests/test-integrations-tui.sh
bash scripts/tests/test-mcp-selector.sh
bash scripts/tests/test-install-tui.sh
bash scripts/tests/test-mcp-wizard.sh
bash scripts/tests/test-bridges-sync.sh
bash scripts/tests/test-bridges-install-ux.sh
make shellcheck</automated>
  </verify>
  <done>
- scripts/install.sh:752-758 — comment block + `print_integrations_summary` call removed.
- scripts/lib/mcp.sh:315-467 — entire `print_integrations_summary` function + its preceding doc block removed.
- `grep -rn print_integrations_summary scripts/` returns ZERO matches.
- scripts/tests/test-integrations-tui.sh — A12 block (4 lines) deleted, A13 block (7 lines) deleted, A14 reduced from 5 to 3 assertions with re-worded banner comment. Total -7 assertions.
- `bash scripts/tests/test-integrations-tui.sh` exits 0 with new (lower) PASS count, FAIL=0.
- `bash scripts/tests/test-mcp-selector.sh` still green (S7 finds "MCP install summary").
- `bash scripts/tests/test-install-tui.sh` still PASS=58.
- `bash scripts/tests/test-mcp-wizard.sh` still green.
- `bash scripts/tests/test-bridges-sync.sh` S10b still asserts PASS=58 successfully.
- `bash scripts/tests/test-bridges-install-ux.sh` still green (BACKCOMPAT-01 baseline holds).
- `make shellcheck` clean.
  </done>
</task>

<task type="auto">
  <name>Task 4: Delete trailing key-rotation explainer + "To remove an MCP" line</name>
  <files>scripts/install.sh</files>
  <action>
At scripts/install.sh:819-820 + 826, delete the three echo lines:

- Line 819-820 (key rotation explainer): redundant — the auto-source flow above
  already explains "edit mcp-config.env, restart claude" implicitly through
  the 1)/2)/3) numbered instructions.
- Line 826 ("To remove an MCP: claude mcp remove <name>"): single-MCP guidance
  out of place in a bulk-install completion block.

Leave the surrounding `if [[ "${NO_BANNER:-0}" != "1" ]]; then` wrapper intact — just remove the three echo lines and the empty echo before line 826 if it leaves a stray double-blank.

After: MCP-branch finishes after the 3) "Reload shell env" line. No tests grep these strings.
  </action>
  <verify>
make shellcheck
grep -c "When you change a key" scripts/install.sh   # → 0
grep -c "To remove an MCP" scripts/install.sh        # → 0
  </verify>
  <done>
- 3 echo lines removed.
- shellcheck clean.
- No test breakage (grep across scripts/tests/ for these strings → 0).
  </done>
</task>

<task type="auto">
  <name>Task 5: Align bridge skip-message indent</name>
  <files>scripts/lib/bridges.sh</files>
  <action>
At scripts/lib/bridges.sh:204-208, normalize the `bridge:` continuation indent so all body prose aligns under "skipped". Keep the `rm` command at 4-space indent so it stands out.

Before:
  echo "bridge: skipped — $target_path is a symlink to $_link_dest" >&2
  echo "bridge:   the toolkit refuses to overwrite symlinks (could clobber another tool's config)." >&2
  echo "bridge:   to install this bridge, remove the symlink first:" >&2
  echo "bridge:     rm $target_path" >&2
  echo "bridge:   then re-run the install command." >&2

After:
  echo "bridge: skipped — $target_path is a symlink to $_link_dest" >&2
  echo "bridge: the toolkit refuses to overwrite symlinks (could clobber another tool's config)." >&2
  echo "bridge: to install this bridge, remove the symlink first:" >&2
  echo "bridge:    rm $target_path" >&2
  echo "bridge: then re-run the install command." >&2

All prose body now starts at column 9 (after `bridge: `). The `rm` line keeps a 3-space inner indent so the command visually nests under "remove the symlink first:".
  </action>
  <verify>
bash scripts/tests/test-bridges-foundation.sh
bash scripts/tests/test-bridges-install-ux.sh
make shellcheck
  </verify>
  <done>
- 4 lines re-indented as shown.
- bridges-foundation + bridges-install-ux still green.
- shellcheck clean.
  </done>
</task>

<task type="auto">
  <name>Task 6: Rename "To remove:" → "To uninstall:" in completion banner</name>
  <files>scripts/install.sh, scripts/init-claude.sh, scripts/init-local.sh, scripts/update-claude.sh, scripts/tests/test-install-banner.sh</files>
  <action>
Rename the leading label across all 4 producer scripts and the test BANNER constant.

- scripts/install.sh:1914     `To remove:` → `To uninstall:`
- scripts/init-claude.sh:1457 `To remove:` → `To uninstall:`
- scripts/init-local.sh:544   `To remove:` → `To uninstall:`
- scripts/update-claude.sh:1394 `To remove:` → `To uninstall:`
- scripts/tests/test-install-banner.sh:42 BANNER constant `To remove:` → `To uninstall:`

URL itself stays intact — only the leading label changes.
  </action>
  <verify>
bash scripts/tests/test-install-banner.sh
make shellcheck
grep -rn "To remove: bash" scripts/ | wc -l   # → 0 (all 5 sites renamed)
grep -rn "To uninstall: bash" scripts/ | wc -l # → 5
  </verify>
  <done>
- All 5 sites renamed.
- test-install-banner.sh green against new label.
- shellcheck clean.
  </done>
</task>

</tasks>

<verification>
After all three tasks land, run the full hermetic test sweep:

```bash
bash scripts/tests/test-install-tui.sh && \
bash scripts/tests/test-mcp-selector.sh && \
bash scripts/tests/test-integrations-tui.sh && \
bash scripts/tests/test-mcp-wizard.sh && \
bash scripts/tests/test-bridges-sync.sh && \
bash scripts/tests/test-bridges-install-ux.sh && \
make shellcheck
```

All commands must exit 0. test-install-tui PASS=58, test-bridges-sync S10b
still asserts PASS=58, test-bridges-install-ux BACKCOMPAT-01 still green.

Manual smoke (against any project with claude CLI installed) — optional but
recommended after the automated sweep:

```bash
bash scripts/install.sh --integrations --yes
```

Expected new behavior:

1. No "Added stdio MCP server …" / "File modified: …" lines during the
   per-MCP loop (Task 1).
2. "skipped" rows in the "MCP install summary:" block render in dim grey,
   visually distinct from the yellow "installed (needs API key)" rows (Task 2).
3. Output ends with the per-row "MCP install summary:" block + its single
   `Installed: N · Skipped: M · Failed: K` line — NOT followed by a second
   "Integrations Install Summary" matrix table (Task 3).
</verification>

<success_criteria>
- All 7 named test files exit 0 (test-install-tui, test-mcp-selector,
  test-integrations-tui, test-mcp-wizard, test-bridges-sync,
  test-bridges-install-ux, plus `make shellcheck`).
- `grep -rn "print_integrations_summary" scripts/` returns zero matches.
- `grep -rn "Integrations Install Summary" scripts/` returns zero matches
  (string was only ever produced by the deleted function).
- `grep -c "_DRO_GREY" scripts/install.sh` returns exactly 1.
- `grep -c "Added stdio MCP server" <captured-install-output>` returns 0
  (verified via the Task 1 mock-claude smoke).
- No new shellcheck warnings on any of the touched files.
</success_criteria>

<output>
No SUMMARY.md required for this quick task — the changes are surgical and
self-documenting from `git diff`. CHANGELOG entry deferred to PR open time
per task constraints.
</output>
