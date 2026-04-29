---
phase: 26
plan: "03"
type: execute
wave: 2
depends_on: ["01", "02"]
files_modified:
  - scripts/install.sh
autonomous: true
requirements: [SKILL-03]
must_haves:
  truths:
    - "User running scripts/install.sh --skills sees a TUI page listing 22 skills with per-skill installed/uninstalled status"
    - "Selected skills are copied to ~/.claude/skills/<name>/ via cp -R from templates/skills-marketplace/<name>/"
    - "Re-running --skills without --force skips already-installed skills with skipped status"
    - "Re-running --skills --force overwrites already-installed skills"
    - "scripts/install.sh --skills --yes --dry-run produces would-install rows for all 22 uninstalled skills with zero filesystem mutations"
    - "scripts/install.sh (no --skills) still works byte-identically with the Phase 24 components flow"
    - "BACKCOMPAT-01 invariant preserved: test-bootstrap.sh PASS=26 + test-install-tui.sh PASS=38 stay green"
  artifacts:
    - path: "scripts/install.sh"
      provides: "--skills flag routing branch with TUI page + dispatch loop + summary"
      contains: "SKILLS=1"
  key_links:
    - from: "scripts/install.sh --skills branch"
      to: "scripts/lib/skills.sh"
      via: "_source_lib skills + skills_catalog_load + skills_status_array + skills_install"
      pattern: "_source_lib skills"
    - from: "scripts/install.sh --skills branch"
      to: "templates/skills-marketplace/"
      via: "skills_install reads source via TK_SKILLS_MIRROR_PATH"
      pattern: "skills_install"
    - from: "scripts/install.sh --skills branch"
      to: "$HOME/.claude/skills/"
      via: "skills_install writes target via TK_SKILLS_HOME"
      pattern: "TK_SKILLS_HOME|TK_SKILLS_MIRROR_PATH"
---

<objective>
Wire the `--skills` flag and TUI routing branch into `scripts/install.sh`, mirroring the Phase 25 `--mcps` routing pattern. Selected skills install via `skills_install` (cp -R from `templates/skills-marketplace/<name>/`). The branch is mutex with `--mcps` and the default Components page — exactly one of three branches runs per invocation.

Purpose: Closes SKILL-03 (TUI catalog + cp -R install + idempotent + --force overwrite). Provides the user-facing surface that Plan 04 will test.

Output: `scripts/install.sh` gains a `SKILLS` flag, a routing branch (~140-180 lines added), and a `--skills` entry in the help text. The branch reuses `tui_checklist`, `tui_confirm_prompt`, `print_install_status`, and `dro_init_colors` from existing Phase 24 infrastructure. No new files. No changes to default flow.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/26-skills-selector/26-CONTEXT.md
@.planning/phases/26-skills-selector/26-01-skills-lib-and-sync-script-PLAN.md
@.planning/phases/25-mcp-selector/25-03-install-sh-mcps-page-SUMMARY.md
@scripts/install.sh
@scripts/lib/skills.sh
@scripts/lib/tui.sh
@scripts/lib/dispatch.sh

<interfaces>
<!-- Reference: existing Phase 25 --mcps routing branch in scripts/install.sh:168-331 -->

The --mcps branch structure (mirror this pattern for --skills):

```bash
# Flag declaration (line ~40)
MCPS=0
SKILLS=0   # ← NEW

# Argparse (lines 41-78)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mcps)    MCPS=1;   shift ;;
        --skills)  SKILLS=1; shift ;;   # ← NEW
        ...
```

```bash
# Lib sourcing (around line 134)
if [[ "$MCPS" -eq 1 ]]; then
    _source_lib mcp
fi
if [[ "$SKILLS" -eq 1 ]]; then     # ← NEW
    _source_lib skills
fi
```

```bash
# Routing gate (around line 168)
if [[ "$MCPS" -eq 1 ]]; then
    # ... 163 lines ... exit 0/1
fi

if [[ "$SKILLS" -eq 1 ]]; then     # ← NEW BRANCH (~140-180 lines)
    # ... TUI + dispatch + summary ... exit 0/1
fi

# Default Phase 24 components flow continues unchanged below
```

<!-- Reference: skills.sh contract from Plan 01 -->

```bash
# Globals provided by skills.sh:
SKILLS_CATALOG=(ai-models ... webapp-testing)   # 22-entry alpha array

# Functions:
skills_catalog_names                       # prints 22 names
is_skill_installed <name>                  # 0=installed, 1=not
skills_status_array                        # populates TUI_INSTALLED[] from SKILLS_CATALOG
skills_install <name> [--force]            # 0=installed, 1=err, 2=exists+no-force
```

<!-- Reference: TUI globals contract from scripts/lib/tui.sh -->

tui_checklist reads:
  TUI_LABELS[]      — display names
  TUI_GROUPS[]      — group label per row
  TUI_INSTALLED[]   — 1 or 0 per row
  TUI_DESCS[]       — optional row description

tui_checklist writes:
  TUI_RESULTS[]     — 1 selected, 0 not selected
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add --skills flag declaration, argparse, and lib sourcing in scripts/install.sh</name>
  <read_first>
    - scripts/install.sh (lines 1-160 — flags, argparse, lib sourcing, routing gate location)
  </read_first>
  <files>scripts/install.sh</files>
  <action>
Edit `scripts/install.sh` to add the `SKILLS` flag. Three small surgical edits:

**Edit 1 — flag declaration (around line 40, after `MCPS=0`):**
Add: `SKILLS=0`

**Edit 2 — argparse case (in the `while [[ $# -gt 0 ]]` block, after `--mcps)` case):**
Add: `--skills)    SKILLS=1;    shift ;;`

**Edit 3 — help text (around line 67, after `--mcps        Install curated MCP servers via TUI catalog (Phase 25)`):**
Add: `  --skills      Install curated skills via TUI catalog (Phase 26)`

**Edit 4 — lib sourcing (around line 135, after `_source_lib mcp` block):**
Add a parallel block:
```bash
# SKILLS=1 path needs the skills catalog + cp-R installer.
if [[ "$SKILLS" -eq 1 ]]; then
    _source_lib skills
fi
```

**Edit 5 — mutex guard (around line 168, BEFORE the `if [[ "$MCPS" -eq 1 ]]` routing gate):**

Add a sanity check:
```bash
# --mcps and --skills are mutex: exactly one of three branches runs per invocation.
if [[ "$MCPS" -eq 1 && "$SKILLS" -eq 1 ]]; then
    echo -e "${RED}✗${NC} --mcps and --skills are mutually exclusive" >&2
    exit 1
fi
```

Do NOT touch any other line of install.sh in this task. The actual `--skills` routing branch is added in Task 2.

Verify the edits do not break the existing `--mcps` flow:
```bash
bash scripts/install.sh --help | grep -E -- "--mcps|--skills"
# Expected: 2 lines — both flags listed in alpha order in help
```

Also verify shellcheck still passes:
```bash
shellcheck -S warning scripts/install.sh
# Expected: 0 warnings (existing SC2034 disables stay valid)
```
  </action>
  <verify>
    <automated>
      bash scripts/install.sh --help | grep -c -- "--skills"
      # MUST output: 1

      bash scripts/install.sh --help | grep -c -- "--mcps"
      # MUST output: 1

      grep -c "^SKILLS=0$" scripts/install.sh
      # MUST output: 1

      grep -c '^\s*--skills)' scripts/install.sh
      # MUST output: 1

      grep -c "_source_lib skills" scripts/install.sh
      # MUST output: 1

      bash scripts/install.sh --mcps --skills 2>&1 | grep -c "mutually exclusive"
      # MUST output: 1

      shellcheck -S warning scripts/install.sh
      # MUST exit 0
    </automated>
  </verify>
  <acceptance_criteria>
    - `SKILLS=0` declared as flag default in install.sh.
    - `--skills` case branch in argparse sets `SKILLS=1`.
    - `--skills` documented in `--help` output.
    - `_source_lib skills` invoked when `SKILLS=1`.
    - `--mcps --skills` returns non-zero with "mutually exclusive" error.
    - All existing flags still parse correctly (`--yes`, `--mcps`, `--dry-run`, `--force`, `--fail-fast`, `--no-color`, `--no-banner`).
    - shellcheck -S warning passes.
    - Phase 24 default flow unaffected — `bash scripts/install.sh --help | grep "components"` still works (the default flow runs when neither --mcps nor --skills is set).
  </acceptance_criteria>
  <done>--skills flag is declared, parsed, documented, and the skills lib is conditionally sourced. Mutex with --mcps enforced. shellcheck clean. No changes to default flow yet (routing branch comes in Task 2).</done>
</task>

<task type="auto">
  <name>Task 2: Add --skills routing branch with TUI page, dispatch loop, and summary</name>
  <read_first>
    - scripts/install.sh (lines 168-335 — Phase 25 --mcps branch as the structural template to mirror)
    - scripts/lib/skills.sh (Plan 01 — function contracts: skills_status_array, skills_install)
    - scripts/lib/tui.sh (lines 162-220 — tui_checklist + tui_confirm_prompt contract)
    - scripts/install.sh (lines 95-145 — _source_lib helper, detect2_cache, print_install_status definition site)
  </read_first>
  <files>scripts/install.sh</files>
  <action>
Add the `--skills` routing branch to `scripts/install.sh`. Insertion point: immediately after the `--mcps` branch closing `fi` (currently around line 331), BEFORE the comment `# (End of MCP routing branch — components page continues below unchanged.)`. Place the new branch as a sibling block.

Update the closing-comment to reflect both branches:
```bash
# (End of MCP / Skills routing branches — components page continues below unchanged.)
```

The new --skills branch (~140 lines):

```bash
if [[ "$SKILLS" -eq 1 ]]; then
    # Skills catalog page — populate TUI_* arrays from the 22-skill catalog.
    skills_status_array

    # Build TUI globals from SKILLS_CATALOG.
    # shellcheck disable=SC2034  # consumed by tui_checklist
    TUI_LABELS=("${SKILLS_CATALOG[@]}")
    # shellcheck disable=SC2034
    TUI_GROUPS=()
    # shellcheck disable=SC2034
    TUI_DESCS=()
    local_total=${#SKILLS_CATALOG[@]}
    for ((i=0; i<local_total; i++)); do
        TUI_GROUPS+=("Skills")
        TUI_DESCS+=("Curated skill mirrored from upstream")
    done

    # Selection: --yes default-set OR TUI page.
    TUI_RESULTS=()
    if [[ "$YES" -eq 1 ]]; then
        # Default-set: select all not-installed; --force re-runs already-installed.
        for ((i=0; i<local_total; i++)); do
            if [[ "${TUI_INSTALLED[$i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
                TUI_RESULTS[$i]=0
            else
                TUI_RESULTS[$i]=1
            fi
        done
    else
        # TTY check (mirrors Phase 25 _install_tty_src gate).
        _install_tty_src="${TK_TUI_TTY_SRC:-/dev/tty}"
        if [[ ! -r "$_install_tty_src" ]]; then
            echo "No TTY available for skills TUI; pass --yes for non-interactive install."
            exit 0
        fi
        if ! tui_checklist; then
            echo "Skills install cancelled."
            exit 0
        fi
        local_selected=0
        for ((i=0; i<${#TUI_RESULTS[@]}; i++)); do
            [[ "${TUI_RESULTS[$i]:-0}" -eq 1 ]] && local_selected=$((local_selected + 1))
        done
        if ! tui_confirm_prompt "Install ${local_selected} skill(s)? [y/N] "; then
            echo "Skills install cancelled."
            exit 0
        fi
    fi

    # ─────────────────────────────────────────────
    # Skills dispatch loop (mirrors Phase 25 D-08 continue-on-error pattern).
    # ─────────────────────────────────────────────
    echo ""
    echo -e "${BLUE}Installing selected skill(s)...${NC}"
    echo ""
    INSTALLED_COUNT=0
    SKIPPED_COUNT=0
    FAILED_COUNT=0
    COMPONENT_STATUS=()
    COMPONENT_NAMES=()
    COMPONENT_STDERR_TAIL=()
    for ((i=0; i<local_total; i++)); do
        local_name="${SKILLS_CATALOG[$i]}"
        COMPONENT_NAMES+=("$local_name")
        if [[ "${TUI_RESULTS[$i]:-0}" -ne 1 ]]; then
            if [[ "${TUI_INSTALLED[$i]}" -eq 1 ]]; then
                COMPONENT_STATUS+=("installed ✓")
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            else
                COMPONENT_STATUS+=("skipped")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            fi
            COMPONENT_STDERR_TAIL+=("")
            continue
        fi

        # Dry-run shortcut: announce would-install without invoking skills_install.
        if [[ "$DRY_RUN" -eq 1 ]]; then
            COMPONENT_STATUS+=("would-install")
            COMPONENT_STDERR_TAIL+=("")
            continue
        fi

        # Capture stderr to a per-skill tmpfile (D-28).
        stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-skill-${local_name}-XXXXXX") || stderr_tmp=""
        [[ -n "$stderr_tmp" ]] && CLEANUP_PATHS+=("$stderr_tmp")

        local_skill_args=()
        [[ "$FORCE" -eq 1 ]] && local_skill_args+=("--force")

        local_rc=0
        if [[ -n "$stderr_tmp" ]]; then
            ( skills_install "$local_name" "${local_skill_args[@]+"${local_skill_args[@]}"}" ) 2>"$stderr_tmp" || local_rc=$?
        else
            skills_install "$local_name" "${local_skill_args[@]+"${local_skill_args[@]}"}" || local_rc=$?
        fi

        case "$local_rc" in
            0)
                COMPONENT_STATUS+=("installed ✓")
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                COMPONENT_STDERR_TAIL+=("")
                ;;
            2)
                COMPONENT_STATUS+=("skipped: already installed (use --force)")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                COMPONENT_STDERR_TAIL+=("")
                ;;
            *)
                COMPONENT_STATUS+=("failed (exit $local_rc)")
                FAILED_COUNT=$((FAILED_COUNT + 1))
                local_tail=""
                if [[ -n "$stderr_tmp" && -s "$stderr_tmp" ]]; then
                    local_tail=$(tail -5 "$stderr_tmp")
                fi
                COMPONENT_STDERR_TAIL+=("$local_tail")
                if [[ "$FAIL_FAST" -eq 1 ]]; then
                    for ((j=i+1; j<local_total; j++)); do
                        COMPONENT_NAMES+=("${SKILLS_CATALOG[$j]}")
                        COMPONENT_STATUS+=("skipped")
                        COMPONENT_STDERR_TAIL+=("")
                        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                    done
                    break
                fi
                ;;
        esac
    done

    # Print skills install summary.
    echo ""
    echo -e "${BLUE}Skills install summary:${NC}"
    echo ""
    for ((i=0; i<${#COMPONENT_NAMES[@]}; i++)); do
        local_name="${COMPONENT_NAMES[$i]}"
        local_state="${COMPONENT_STATUS[$i]:-unknown}"
        print_install_status "$local_name" "$local_state"
        case "$local_state" in
            failed*)
                local_tail="${COMPONENT_STDERR_TAIL[$i]:-}"
                if [[ -n "$local_tail" ]]; then
                    while IFS= read -r tail_line; do
                        printf '      %s\n' "$tail_line"
                    done <<< "$local_tail"
                fi
                ;;
        esac
    done
    echo ""
    printf 'Installed: %d · Skipped: %d · Failed: %d\n' \
        "$INSTALLED_COUNT" "$SKIPPED_COUNT" "$FAILED_COUNT"
    if [[ "${NO_BANNER:-0}" != "1" ]]; then
        echo ""
        echo "To remove a skill: rm -rf ~/.claude/skills/<name>"
    fi
    if [[ $FAILED_COUNT -gt 0 ]]; then
        exit 1
    fi
    exit 0
fi
```

Key design notes:

1. **DRY_RUN shortcut placed BEFORE skills_install call.** Phase 25 SUMMARY noted the bug where dry-run still tried to collect secrets via TTY. For skills there are no secrets, but we still avoid invoking skills_install in dry-run mode to honor the "preview without writes" contract.

2. **Reuses TUI_* globals + tui_checklist + tui_confirm_prompt** — same pattern as the --mcps branch. The 22-skill list is single-group ("Skills") for v1; CONTEXT.md notes alphabetical-flat is the chosen ordering.

3. **--force semantics:** plumbed through to `skills_install --force`. skills_install Plan 01 contract: rc=0 success, rc=2 already-exists-without-force, rc=1 error.

4. **No "claude CLI present" check** — skills require zero CLI dependency (CONTEXT.md "MCP_CLI_PRESENT not applicable for skills"). Branch always runs.

5. **Removal banner customized** — instead of `claude mcp remove <name>` (Phase 25), we say `rm -rf ~/.claude/skills/<name>`. Per CONTEXT.md Deferred Ideas: "Skill removal flow — defer; users can rm -rf manually."

6. **Mutex** — the SKILLS=1 branch always exits 0 or 1, so the default Phase 24 components page is unreachable when --skills is set.

7. **CLEANUP_PATHS** — already declared at script top; appending stderr_tmp paths is consistent with Phase 25 pattern.

8. **`local` variable collision warning:** `local_total`, `local_name`, `local_state`, `local_tail`, `local_rc`, `local_selected`, `local_skill_args` — these are NOT `local`-declared (the script body is not inside a function). Bash semantics: they're regular shell vars in the script scope. This matches the Phase 25 --mcps branch convention.

Verify the branch is reachable and tests pass:
```bash
shellcheck -S warning scripts/install.sh
# 0 warnings

bash scripts/tests/test-install-tui.sh
# PASS=38 FAIL=0 (Phase 24 invariant)

bash scripts/tests/test-bootstrap.sh
# PASS=26 FAIL=0 (Phase 21 invariant)
```

Smoke test the dry-run path manually (will be replaced by Plan 04 hermetic test):
```bash
TK_SKILLS_HOME=/tmp/empty-skills-home \
TK_SKILLS_MIRROR_PATH="$(pwd)/templates/skills-marketplace" \
bash scripts/install.sh --skills --yes --dry-run 2>&1 | tail -30
# Expected: prints "Skills install summary:" and 22 "would-install" rows.
```
  </action>
  <verify>
    <automated>
      grep -c "if \[\[ \"\$SKILLS\" -eq 1 \]\]" scripts/install.sh
      # MUST output: 1 (the routing branch opening)

      grep -c "skills_status_array" scripts/install.sh
      # MUST output: 1

      grep -c "skills_install" scripts/install.sh
      # MUST output: 2 (one for stderr-capture branch, one for non-stderr branch)

      grep -c "Skills install summary:" scripts/install.sh
      # MUST output: 1

      grep -c "rm -rf ~/.claude/skills" scripts/install.sh
      # MUST output: 1 (the --no-banner removal hint)

      shellcheck -S warning scripts/install.sh
      # MUST exit 0

      bash scripts/tests/test-install-tui.sh 2>&1 | tail -3 | grep -E "PASS=38.*FAIL=0"
      # MUST match (Phase 24 BACKCOMPAT-01 invariant)

      bash scripts/tests/test-bootstrap.sh 2>&1 | tail -3 | grep -E "PASS=26.*FAIL=0"
      # MUST match (Phase 21 BOOTSTRAP-01..04 invariant)

      # Smoke test: --skills --yes --dry-run with empty TK_SKILLS_HOME → 22 would-install rows
      mkdir -p /tmp/skills-smoke-empty
      TK_SKILLS_HOME=/tmp/skills-smoke-empty TK_SKILLS_MIRROR_PATH="$(pwd)/templates/skills-marketplace" bash scripts/install.sh --skills --yes --dry-run 2>&1 | grep -c "would-install"
      # MUST output: 22
    </automated>
  </verify>
  <acceptance_criteria>
    - `if [[ "$SKILLS" -eq 1 ]]` routing branch present in scripts/install.sh.
    - Branch calls `skills_status_array` to populate TUI_INSTALLED.
    - Branch builds TUI_LABELS from SKILLS_CATALOG.
    - Branch calls `skills_install <name> [--force]` per selected skill.
    - Branch handles rc=0 (installed), rc=2 (already-exists), rc≠0,2 (failed) per Plan 01 contract.
    - --dry-run path produces "would-install" rows without invoking skills_install.
    - Branch terminates with `exit 0` (success) or `exit 1` (any FAILED_COUNT > 0).
    - Default Phase 24 components flow unaffected (`bash scripts/install.sh --help` still lists components).
    - test-install-tui.sh PASS=38 (Phase 24 BACKCOMPAT-01 preserved).
    - test-bootstrap.sh PASS=26 (Phase 21 BOOTSTRAP-01..04 preserved).
    - shellcheck -S warning clean.
    - Smoke test with empty TK_SKILLS_HOME shows 22 "would-install" rows in --yes --dry-run mode.
  </acceptance_criteria>
  <done>scripts/install.sh --skills branch is wired end-to-end: TUI page or --yes default-set, --force overwrite, --dry-run preview, per-skill summary with installed/skipped/failed states. BACKCOMPAT-01 invariants (test-bootstrap PASS=26, test-install-tui PASS=38) preserved. Hermetic test in Plan 04 will exercise correctness.</done>
</task>

</tasks>

<verification>
After both tasks:

1. `bash scripts/install.sh --help | grep -- "--skills"` → present in help
2. `bash scripts/install.sh --mcps --skills` → exit 1 with "mutually exclusive"
3. `TK_SKILLS_HOME=/tmp/empty TK_SKILLS_MIRROR_PATH="$(pwd)/templates/skills-marketplace" bash scripts/install.sh --skills --yes --dry-run` → exit 0, prints 22 would-install rows, no filesystem mutations under /tmp/empty
4. `TK_SKILLS_HOME=/tmp/empty TK_SKILLS_MIRROR_PATH="$(pwd)/templates/skills-marketplace" bash scripts/install.sh --skills --yes` → exit 0, all 22 skills copied to /tmp/empty/, prints 22 installed rows
5. Re-run #4 → all 22 skipped, exit 0 (idempotency)
6. `TK_SKILLS_HOME=/tmp/empty TK_SKILLS_MIRROR_PATH="$(pwd)/templates/skills-marketplace" bash scripts/install.sh --skills --yes --force` → all 22 re-installed, exit 0
7. `bash scripts/tests/test-install-tui.sh` → PASS=38 FAIL=0
8. `bash scripts/tests/test-bootstrap.sh` → PASS=26 FAIL=0
9. `bash scripts/tests/test-mcp-selector.sh` → PASS=21 FAIL=0 (Phase 25 invariant)
10. `make check` → all checks pass
</verification>

<success_criteria>
- `scripts/install.sh --skills` opens a 22-row TUI catalog with per-skill installed/uninstalled detection.
- Selected skills install via `cp -R` from `templates/skills-marketplace/<name>/` to `~/.claude/skills/<name>/`.
- `--yes` default-set selects all uninstalled skills.
- `--force` overwrites already-installed skills.
- `--dry-run` produces a preview without filesystem mutations.
- Mutex with `--mcps`. Default Phase 24 components flow unchanged.
- BACKCOMPAT-01 (test-bootstrap PASS=26 + test-install-tui PASS=38) preserved.
- shellcheck clean. make check passes.
</success_criteria>

<output>
After completion, create `.planning/phases/26-skills-selector/26-03-install-sh-skills-page-SUMMARY.md`. Note line counts before/after, any deviations from this plan (Phase 25 03 SUMMARY shows the dry-run-position-fix style of deviation note as the template).
</output>
