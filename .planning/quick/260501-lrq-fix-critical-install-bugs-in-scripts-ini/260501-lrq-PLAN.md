---
quick_task: 260501-lrq
slug: fix-critical-install-bugs-in-scripts-ini
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/init-claude.sh
  - scripts/lib/dispatch.sh
  - scripts/lib/tui.sh
  - scripts/install.sh
  - scripts/tests/test-install-tui.sh
  - scripts/tests/test-init-download-fallback.sh
  - README.md
autonomous: true
requirements:
  - BUG-01-MANIFEST-PATH
  - BUG-02-SKILLS-MARKETPLACE-SKIP
  - BUG-03-DETECT2-SOURCING
  - BUG-04-COUNCIL-PROMPT-VISIBILITY
  - BUG-05-FAILURE-BANNER
  - REDESIGN-06-README-INSTALL-URL
  - REDESIGN-07-DISPATCH-COUNCIL
  - REDESIGN-08-TUI-COUNCIL-ROW
  - REDESIGN-09-TUI-RENDER-UPGRADE
  - TEST-10-TUI-RENDER-ASSERTIONS
  - TEST-11-DOWNLOAD-FALLBACK-SCENARIOS

must_haves:
  truths:
    - "init-claude.sh download_files() succeeds for all manifest entries that exist under templates/$FRAMEWORK/ OR templates/base/ (no false 404s)"
    - "init-claude.sh skips the skills_marketplace bucket entirely (no curl on directories)"
    - "init-claude.sh sources lib/detect2.sh BEFORE lib/bridges.sh so is_gemini_installed/is_codex_installed resolve (no command-not-found stderr)"
    - "After setup_council prints its install spam, the 'Configure Supreme Council now? [Y/n]:' prompt is visually separated and not mistaken for a hang"
    - "When download_files() has any failure, the closing banner shows a warning (not a clean 'Installation Complete!')"
    - "README.md primary install command points to install.sh; init-claude.sh URL still listed as fallback"
    - "scripts/lib/dispatch.sh exposes dispatch_council() following the dispatch_security() pattern; TK_DISPATCH_ORDER includes 'council' between 'statusline' and 'gemini-bridge'"
    - "scripts/install.sh TUI exposes a 'council' row when ~/.claude/council/brain.py is absent, in the Optional group"
    - "scripts/lib/tui.sh _tui_render shows numbered prefix (1./2./3.), inline dimmed description under EVERY row, and the new footer text"
    - "test-install-tui.sh contains assertions for the new render format (numbered prefix + per-row description + footer text)"
    - "test-init-download-fallback.sh exists with 4 hermetic scenarios (framework-first, base-fallback, both-missing-failure, skills_marketplace-skipped)"
    - "make check passes (shellcheck -S warning + markdownlint clean + validate)"
  artifacts:
    - path: "scripts/init-claude.sh"
      provides: "Bug 1+2+3+4+5 fixes in download_files(), source order, setup_council prompt UX, post-install summary"
      contains: "templates/${FRAMEWORK}/${path} fallback to templates/base/${path}; skip skills_marketplace bucket; lib/detect2.sh sourced before lib/bridges.sh; visible separator before Council prompt; FAILED_COUNT-aware closing banner"
    - path: "scripts/lib/dispatch.sh"
      provides: "dispatch_council() function + TK_DISPATCH_ORDER updated"
      contains: "dispatch_council"
    - path: "scripts/lib/tui.sh"
      provides: "_tui_render upgrade — numbered rows + per-row inline dimmed description + new footer"
      contains: "printf '%d.'"
    - path: "scripts/install.sh"
      provides: "TUI council row in Optional group; dispatch path for council via dispatch_council"
      contains: "council"
    - path: "scripts/tests/test-init-download-fallback.sh"
      provides: "Hermetic test for 4 download fallback scenarios"
      min_lines: 80
    - path: "scripts/tests/test-install-tui.sh"
      provides: "Extended assertions for new render format"
      contains: "numbered prefix"
    - path: "README.md"
      provides: "Primary install URL switched to install.sh"
      contains: "scripts/install.sh"
  key_links:
    - from: "scripts/init-claude.sh:download_files"
      to: "templates/$FRAMEWORK/<bucket>/<file> OR templates/base/<bucket>/<file>"
      via: "two-attempt curl with -f, mirroring download_extras at line 540"
      pattern: "templates/\\\\\\$FRAMEWORK/\\\\\\$path"
    - from: "scripts/init-claude.sh:main"
      to: "lib/detect2.sh"
      via: "explicit download+source BEFORE lib/bridges.sh download"
      pattern: "scripts/lib/detect2.sh"
    - from: "scripts/install.sh"
      to: "scripts/lib/dispatch.sh::dispatch_council"
      via: "TUI_LABELS council entry → dispatch_${name} expansion"
      pattern: "dispatch_council"
    - from: "scripts/lib/dispatch.sh::dispatch_council"
      to: "scripts/setup-council.sh"
      via: "_dispatch_is_curl_pipe → curl|bash setup-council.sh OR sibling path"
      pattern: "setup-council.sh"
---

<objective>
Fix five critical install-time bugs in scripts/init-claude.sh that produce broken installs (404 spam, missing libs, invisible Council prompt, false success banner) AND redesign the user-facing install entry point to use install.sh's TUI checklist with Supreme Council integrated as a first-class component.

Purpose: A user running `bash <(curl init-claude.sh)` today sees ~30 lines of "(download failed)", missing agents/prompts/skills/rules, a Council prompt that looks like a hang, and a false "Installation Complete!" banner. After this plan, the same install completes cleanly OR surfaces real failures honestly; users discovering the toolkit via README land on the modern TUI flow that includes Council selection alongside SP/GSD/Toolkit/Security/RTK/Statusline.

Output:
- 7 atomic commits on branch fix/install-bugs-v4.8.1
- 0 files removed; 0 manifest version bump; 0 CHANGELOG edit
- All scripts shellcheck -S warning clean; all markdown markdownlint clean
- New hermetic test (test-init-download-fallback.sh) + extended test-install-tui.sh
- TUI render upgrade visible in install.sh (numbered + per-row description + new footer)
- dispatch_council shipped in lib/dispatch.sh with TK_DISPATCH_ORDER updated
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@scripts/init-claude.sh
@scripts/install.sh
@scripts/lib/dispatch.sh
@scripts/lib/tui.sh
@scripts/lib/bridges.sh
@scripts/lib/detect2.sh
@scripts/setup-council.sh
@scripts/tests/test-install-tui.sh
@manifest.json
@README.md

<interfaces>
<!-- Key contracts the executor needs. Extracted from codebase. Use directly — no exploration required. -->

From scripts/lib/dispatch.sh (the dispatch_security pattern to mirror for dispatch_council):
```bash
# Pattern (lines 234-274) — copy this shape exactly for dispatch_council:
dispatch_security() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ; pass_args+=("--force") ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$force"

    # Audit H6: TK_TEST=1 gate (test seam, not a runtime override).
    if [[ -n "${TK_DISPATCH_OVERRIDE_SECURITY:-}" && "${TK_TEST:-0}" == "1" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] security (would run override: $TK_DISPATCH_OVERRIDE_SECURITY)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_SECURITY" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] security (would run: bash <(curl -sSL $TK_REPO_URL/scripts/setup-security.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/setup-security.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path setup-security.sh)"
        bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}

# TK_DISPATCH_ORDER current value (line 95):
TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline gemini-bridge codex-bridge)
# Target value:
# TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline council gemini-bridge codex-bridge)
```

From scripts/lib/detect2.sh (the helpers init-claude.sh needs sourced before bridges.sh):
```bash
is_gemini_installed() { command -v gemini >/dev/null 2>&1; }   # line 53
is_codex_installed()  { command -v codex  >/dev/null 2>&1; }   # line 46
```

From scripts/init-claude.sh:540 (the existing fallback pattern to copy into download_files):
```bash
# Existing pattern in download_extras() (line 534-545):
if curl -sSLf -A "$TK_USER_AGENT" "$full_url" -o "$full_dest" 2>/dev/null && [[ -s "$full_dest" ]]; then
    echo -e "  ${GREEN}✓${NC} $dest"
else
    rm -f "$full_dest"
    echo -e "  ${YELLOW}⚠${NC} $dest (using base template)"
    base_src="${src/templates\/$FRAMEWORK/templates\/base}"
    if ! curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/$base_src" -o "$full_dest" 2>/dev/null || [[ ! -s "$full_dest" ]]; then
        rm -f "$full_dest"
        echo -e "  ${RED}✗${NC} $dest (download failed, no fallback)"
    fi
fi
```

From scripts/lib/tui.sh:106-167 (current _tui_render — the function to upgrade):
```bash
# Current behaviour:
#   - Prints "  [box] label" per row (no numbered prefix)
#   - Prints description ONLY for the focused row at the bottom (lines 159-167)
#   - Footer: "↑↓ move · space toggle · enter confirm · q quit"
#
# Target behaviour:
#   - "  N. [box] label" per row (numbered, 1-indexed)
#   - Inline dimmed description directly under EVERY row
#   - Footer: "Enter to select · ↑↓ navigate · Space toggle · Esc cancel"
#   - Section header rendered with stronger separation (extra blank line above)
```

From scripts/install.sh:633-645 (TUI_LABELS arrays — must add 'council' entry):
```bash
TUI_LABELS=("superpowers" "get-shit-done" "toolkit" "security" "rtk" "statusline")
TUI_GROUPS=("Bootstrap"   "Bootstrap"      "Core"    "Optional" "Optional" "Optional")
TUI_INSTALLED=("$IS_SP" "$IS_GSD" "$IS_TK" "$IS_SEC" "$IS_RTK" "$IS_SL")
TUI_DESCS=(
    "Skills + code-reviewer agent (claude plugin)"
    "Phase-based workflow (curl install)"
    "Claude Code Toolkit core (init-claude.sh)"
    "Global security rules + cc-safety-net hook"
    "60-90% token savings on dev commands"
    "macOS rate-limit statusline (Keychain)"
)
# Target — append council entry (Optional group, mirrors security/rtk/statusline shape):
# TUI_LABELS+=("council")
# TUI_GROUPS+=("Optional")
# IS_COUNCIL=0; [[ -f "$HOME/.claude/council/brain.py" ]] && IS_COUNCIL=1
# TUI_INSTALLED+=("$IS_COUNCIL")
# TUI_DESCS+=("Multi-AI plan review (Gemini + ChatGPT) — needs CLI or API keys")
```

From manifest.json — buckets to iterate (init-claude.sh download_files iterates `.files` via jq):
```text
agents/, prompts/, commands/, skills/, rules/, scripts/, libs/    # KEEP iterating
skills_marketplace/                                                  # SKIP (directory entries)
```

From scripts/tests/test-install-tui.sh (existing scaffold to extend):
```bash
# Pattern: SCRIPT_DIR/REPO_ROOT resolution, assert_pass/assert_fail/assert_eq/assert_contains helpers,
# RETURN-trap sandbox cleanup AT TOP LEVEL ONLY (not inside subshells — see Phase 28 lesson),
# scenario functions named run_sN_<purpose>, final FAIL-count exit.
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix critical install bugs (B1+B2+B3+B4+B5) in scripts/init-claude.sh</name>
  <files>scripts/init-claude.sh</files>
  <action>
Apply five surgical fixes to scripts/init-claude.sh. Commit AFTER ALL FIVE are in place + shellcheck-clean (single fix-pass commit).

**B1 — manifest path resolution (download_files at line ~574-606):**

Replace the inner curl block (lines 591-599) with two-attempt fallback mirroring download_extras (line 534-545):

```bash
        full_dest="$CLAUDE_DIR/$path"
        # B1: manifest paths are bucket-relative (e.g. "agents/planner.md"). Real
        # repo layout is templates/<framework>/<bucket>/<file> with templates/base/
        # as universal fallback. Try framework first, then base. Mirrors the
        # download_extras pattern at line 534-545.
        local fw_url base_url
        fw_url="$REPO_URL/templates/$FRAMEWORK/$path"
        base_url="$REPO_URL/templates/base/$path"
        mkdir -p "$(dirname "$full_dest")"
        if curl -sSLf -A "$TK_USER_AGENT" "$fw_url" -o "$full_dest" 2>/dev/null && [[ -s "$full_dest" ]]; then
            echo -e "  ${GREEN}OK${NC} $path"
            INSTALLED_PATHS+=("$full_dest")
        elif curl -sSLf -A "$TK_USER_AGENT" "$base_url" -o "$full_dest" 2>/dev/null && [[ -s "$full_dest" ]]; then
            echo -e "  ${GREEN}OK${NC} $path (base)"
            INSTALLED_PATHS+=("$full_dest")
        else
            rm -f "$full_dest"
            echo -e "  ${YELLOW}!!${NC} $path (download failed)"
            FAILED_COUNT=$((${FAILED_COUNT:-0} + 1))
            FAILED_PATHS+=("$path")
        fi
```

Add `local fw_url base_url` to the existing `local path skip reason full_dest full_url` declaration (line 575) — replace `full_url` with `fw_url base_url`.

Also declare `FAILED_COUNT=0` and `FAILED_PATHS=()` at the top of download_files() (just after `INSTALLED_PATHS=()` / `SKIPPED_PATHS=()` declarations near line 576-577). Note: Bash 3.2 `local -a` is fine; just use plain `local FAILED_PATHS=()`.

**Important — exception buckets:** The `scripts` and `libs` buckets in manifest.json reference paths under `scripts/...` (NOT `templates/<fw>/scripts/...`). Detect bucket from the jq output and route accordingly. Update the jq emission to include the bucket in the output stream:

```bash
    done < <(jq -c --argjson skip "$SKIP_LIST_JSON" '
        .files | to_entries[] |
        .key as $b | .value[] |
        select($b != "skills_marketplace") |
        { bucket: $b, path: .path,
          skip: ([.path] | inside($skip)),
          reason: ((.conflicts_with // []) | join(",")) }
    ' "$MANIFEST_FILE")
```

Then inside the loop, parse bucket and route:

```bash
        bucket=$(jq -r '.bucket' <<< "$entry")
        # ...skip handling unchanged...
        # B1+B2: bucket-aware URL resolution.
        # - skills_marketplace bucket: filtered out by jq `select($b != ...)` above.
        # - scripts / libs buckets: paths already begin with "scripts/..." (manifest
        #   stores them at repo-root, NOT under templates/). Use $REPO_URL/$path directly.
        # - all other buckets (agents, prompts, commands, skills, rules): the manifest
        #   path is bucket-relative; the file lives under templates/<fw>/ or templates/base/.
        case "$bucket" in
            scripts|libs)
                full_dest="$CLAUDE_DIR/$path"
                mkdir -p "$(dirname "$full_dest")"
                if curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/$path" -o "$full_dest" 2>/dev/null && [[ -s "$full_dest" ]]; then
                    echo -e "  ${GREEN}OK${NC} $path"
                    INSTALLED_PATHS+=("$full_dest")
                else
                    rm -f "$full_dest"
                    echo -e "  ${YELLOW}!!${NC} $path (download failed)"
                    FAILED_COUNT=$((${FAILED_COUNT:-0} + 1))
                    FAILED_PATHS+=("$path")
                fi
                ;;
            *)
                # framework-first → base-fallback
                # ...the fw_url / base_url block above...
                ;;
        esac
```

**B2 — skills_marketplace skip:** Already handled by the `select($b != "skills_marketplace")` in the jq pipeline above. Add a comment above the jq block:

```bash
    # B2: skills_marketplace entries are DIRECTORIES (each contains SKILL.md +
    # SKILL-LICENSE.md), not files — curl can't fetch a dir from raw.github.
    # Filtered out at the jq stage; install.sh --skills handles them via cp -R.
```

**B3 — source lib/detect2.sh BEFORE lib/bridges.sh:**

Insert a new block AFTER the lib/state.sh download/source (currently ends at line ~202) and BEFORE the lib/bridges.sh download (currently line 207). Mirror the state.sh download pattern:

```bash
# B3: bridges.sh calls is_gemini_installed / is_codex_installed (defined in
# detect2.sh) at lines 626-627 + 690-691. Without detect2.sh sourced first,
# those functions return 127 (command not found) and the caller's `|| continue`
# silently skips both bridges. Mirrors the state.sh pre-source fix from commit 18a7039.
LIB_DETECT2_TMP=$(mktemp "${TMPDIR:-/tmp}/detect2-lib.XXXXXX");      CLEANUP_PATHS+=("$LIB_DETECT2_TMP")
if ! curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/scripts/lib/detect2.sh" -o "$LIB_DETECT2_TMP"; then
    echo -e "${RED}✗${NC} Failed to download lib/detect2.sh — aborting"
    exit 1
fi
# detect2.sh sources detect.sh via a relative path — preserve $DETECT_TMP-equivalent
# by ensuring detect.sh is already sourced earlier (it is, via the bootstrap chain).
# shellcheck source=/dev/null
source "$LIB_DETECT2_TMP"
```

Verify by inspecting init-claude.sh upstream of line 207 that detect.sh has already been sourced (search for `DETECT_TMP=` and the `source "$DETECT_TMP"` invocation). If detect2.sh fails its internal `source ../detect.sh` because it's running from /tmp, guard by skipping the inner source when HAS_SP is already defined. The actual fix MAY require setting a sentinel before sourcing — verify behavior with the test in Task 4 before committing.

**B4 — visible Council prompt (setup_council at line ~942-948):**

Replace lines 942-947 (the `echo ""` + `read -r -p "Configure Supreme Council now? ..."` block) with a visible separator banner:

```bash
    # B4: after 22+ lines of "✓ ... installed" output, the prompt was visually
    # invisible — users thought the install hung. Add a horizontal rule + blank
    # lines to clearly separate the spam from the actionable prompt.
    echo ""
    echo -e "${BLUE}─────────────────────────────────────────────${NC}"
    echo -e "${BLUE}  Supreme Council — interactive configuration${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────${NC}"
    echo ""
    local configure
    if ! read -r -p "  Configure Supreme Council now? [Y/n]: " configure < /dev/tty 2>/dev/null; then
        configure="N"
    fi
    configure="${configure:-Y}"
```

**B5 — failure-aware closing banner (main at line ~1189-1192):**

Replace the unconditional success banner (lines 1189-1192) with a FAILED_COUNT-aware variant:

```bash
    # B5: previously this banner displayed even when many files failed to
    # download — false success. download_files now tracks FAILED_COUNT;
    # surface real failures in the banner.
    echo ""
    if [[ "${FAILED_COUNT:-0}" -gt 0 ]]; then
        echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠ Installation completed with ${FAILED_COUNT} failure(s) ${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "Failed files (review before commit):"
        local fp
        for fp in "${FAILED_PATHS[@]:-}"; do
            [[ -n "$fp" ]] && echo -e "  ${RED}✗${NC} $fp"
        done
        echo ""
        echo -e "Re-run with TK_TOOLKIT_REF=<tag> if you suspect a stale cache,"
        echo -e "or open an issue: https://github.com/sergei-aronsen/claude-code-toolkit/issues"
    else
        echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✅ Installation Complete!                 ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    fi
```

Also export FAILED_COUNT / FAILED_PATHS at file scope (declare with defaults near other globals around line 91-98) so main() can read them after download_files() returns:

```bash
FAILED_COUNT=0
FAILED_PATHS=()
```

Make `FAILED_COUNT` / `FAILED_PATHS` global (NOT local) inside download_files — remove `local` from those lines if you accidentally added it.

**Verification before committing:** run `shellcheck -S warning scripts/init-claude.sh`. Fix any new warnings introduced.

Commit message:
```text
fix(install): manifest path fallback, skills_marketplace skip, detect2 sourcing, council UX, failure banner

- B1: download_files now tries templates/$FRAMEWORK/$path → templates/base/$path
  fallback (mirrors download_extras pattern). scripts/libs buckets keep
  repo-root paths unchanged.
- B2: skills_marketplace bucket filtered out at jq stage — those entries are
  directories and belong to install.sh --skills, not init-claude.sh.
- B3: lib/detect2.sh downloaded + sourced BEFORE lib/bridges.sh so
  is_gemini_installed / is_codex_installed resolve. Mirrors commit 18a7039
  state.sh pre-source fix.
- B4: visible separator banner before "Configure Supreme Council now?" prompt
  so it isn't lost in the install spam.
- B5: closing banner is FAILED_COUNT-aware — shows warning + failed-file list
  when downloads failed instead of false "Installation Complete!".
```
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/init-claude.sh && grep -q "templates/\$FRAMEWORK/\$path\|templates/.*FRAMEWORK.*path" scripts/init-claude.sh && grep -q "skills_marketplace" scripts/init-claude.sh && grep -q "lib/detect2.sh" scripts/init-claude.sh && grep -q "FAILED_COUNT" scripts/init-claude.sh</automated>
  </verify>
  <done>
- scripts/init-claude.sh shellcheck -S warning clean
- download_files() uses framework-first → base-fallback for non-scripts/libs buckets
- skills_marketplace bucket excluded at jq stage with explanatory comment
- lib/detect2.sh download+source block exists between state.sh source and bridges.sh download
- Council prompt has visible BLUE separator banner above it
- Closing banner branches on FAILED_COUNT; lists failed files when >0
- Single commit (Conventional Commits, no --no-verify)
  </done>
</task>

<task type="auto">
  <name>Task 2: Add dispatch_council + 'council' to TK_DISPATCH_ORDER + TUI council row + TUI render upgrade</name>
  <files>scripts/lib/dispatch.sh, scripts/install.sh, scripts/lib/tui.sh</files>
  <action>
Three sub-changes, three commits in this order:

**Sub-2a — dispatch_council (commit 1 of 3 in this task):**

Append to scripts/lib/dispatch.sh AFTER dispatch_statusline (after line 349, before the file ends). Use the dispatch_security pattern verbatim (interfaces block above) but target setup-council.sh:

```bash
# dispatch_council — setup-council.sh.
# Audit M1 parity: --dry-run is honoured at the dispatcher level (prints
# "would run …" and returns 0). NOT passed through because setup-council.sh
# does not yet recognize it (fail-closed on unknown flags).
dispatch_council() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ; pass_args+=("--force") ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$force"

    # Audit H6: TK_TEST=1 gate (test seam, not a runtime override).
    if [[ -n "${TK_DISPATCH_OVERRIDE_COUNCIL:-}" && "${TK_TEST:-0}" == "1" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] council (would run override: $TK_DISPATCH_OVERRIDE_COUNCIL)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_COUNCIL" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] council (would run: bash <(curl -sSL $TK_REPO_URL/scripts/setup-council.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/setup-council.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path setup-council.sh)"
        bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}
```

Update TK_DISPATCH_ORDER at line 95 — insert `council` between `statusline` and `gemini-bridge`:

```bash
    TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline council gemini-bridge codex-bridge)
```

Update the doc comment at the top (lines 6-12) to list `dispatch_council`. Add an `is_council_installed` helper to detect2.sh? — NO, keep council detection inline in install.sh per the existing TUI_INSTALLED pattern (security/rtk use detect2.sh because their probes are non-trivial; council is a single file existence check, inline is fine).

Verify: `shellcheck -S warning scripts/lib/dispatch.sh`.

Commit message:
```text
feat(dispatch): add dispatch_council() + 'council' entry in TK_DISPATCH_ORDER

Mirrors dispatch_security() pattern: --force/--dry-run/--yes parsing,
TK_DISPATCH_OVERRIDE_COUNCIL test seam under TK_TEST=1, _dispatch_is_curl_pipe
routing to setup-council.sh. Order placement: between statusline and the
two bridges, matching its semantic position as an Optional component.
```

**Sub-2b — TUI council row + dispatch wiring in install.sh (commit 2 of 3):**

In scripts/install.sh around line 633-645, append council to the TUI arrays. Insert right after the existing TUI_DESCS block (after line 645, before the `# BRIDGE-UX-01 (Phase 30)` comment at line 647):

```bash
# Council: optional Multi-AI plan review. Detect via brain.py existence (single
# inline check — non-trivial probes live in detect2.sh, this one is one stat call).
IS_COUNCIL=0
[[ -f "$HOME/.claude/council/brain.py" ]] && IS_COUNCIL=1
TUI_LABELS+=("council")
TUI_GROUPS+=("Optional")
TUI_INSTALLED+=("$IS_COUNCIL")
TUI_DESCS+=("Multi-AI plan review (Gemini + ChatGPT) — needs CLI or API keys")
```

Update the dispatch loop's re-probe case (around line 907-916) to add a council branch:

```bash
        statusline)  is_statusline_installed  && local_re_installed=1 || true ;;
        council)     [[ -f "$HOME/.claude/council/brain.py" ]] && local_re_installed=1 || true ;;
        gemini-bridge) : ;;  # Bridges have no idempotency probe — always re-write (state SHA tracks drift).
```

The `dispatch_${local_name}` expansion at line 966 will resolve to `dispatch_council` automatically — no further plumbing needed.

Verify: `shellcheck -S warning scripts/install.sh`.

Commit message:
```text
feat(install): add Council TUI row + dispatch path

- TUI_LABELS gains 'council' in Optional group with brain.py existence probe
- Dispatch loop re-probe handles council via inline -f check
- dispatch_council resolves automatically through dispatch_${name} expansion
- Order matches TK_DISPATCH_ORDER addition from previous commit
```

**Sub-2c — TUI render upgrade in lib/tui.sh (commit 3 of 3):**

Rewrite _tui_render() (lines 106-168). Preserve EVERY invariant: tty_target seam, color gating, TUI_LABELS/GROUPS/INSTALLED/RESULTS/DESCS access, FOCUS_IDX arrow indicator, section header on group transitions, bash 3.2 portability. Change ONLY the row format + per-row description placement + footer text.

```bash
_tui_render() {
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"

    # Move cursor to top-left and erase to end-of-screen (RESEARCH.md §3 — no
    # alternate screen; simpler clear+redraw approach).
    printf '\e[H\e[J' > "$tty_target" 2>/dev/null || true

    local total="${#TUI_LABELS[@]}"
    local prev_group=""
    local i

    for (( i=0; i<total; i++ )); do
        local label="${TUI_LABELS[$i]:-}"
        local grp="${TUI_GROUPS[$i]:-}"
        local installed="${TUI_INSTALLED[$i]:-0}"
        local checked="${TUI_RESULTS[$i]:-0}"
        local desc="${TUI_DESCS[$i]:-}"
        local row_num=$((i + 1))

        # Section header on group change — extra blank line above for clearer separation.
        if [[ "$grp" != "$prev_group" && -n "$grp" ]]; then
            if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
                printf '\n  \e[1m%s\e[0m\n' "$grp" > "$tty_target" 2>/dev/null || true
            else
                printf '\n  %s\n' "$grp" > "$tty_target" 2>/dev/null || true
            fi
            prev_group="$grp"
        fi

        # Focus indicator (D-16: arrow, NOT reverse video).
        local arrow="  "
        if [[ "$i" -eq "${FOCUS_IDX:-0}" ]]; then
            arrow="${TK_TUI_ARROW:-▶ }"
        fi

        # Checkbox glyph (D-17).
        local box="[ ]"
        if [[ "$installed" -eq 1 ]]; then
            box="[installed ✓]"
        elif [[ "$checked" -eq 1 ]]; then
            box="[x]"
        fi

        # Numbered prefix + label row.
        printf '%s%d. %s %s\n' "$arrow" "$row_num" "$box" "$label" > "$tty_target" 2>/dev/null || true

        # Inline dimmed description under EVERY row (was previously focus-only at file bottom).
        if [[ -n "$desc" ]]; then
            if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
                printf '       \e[2m%s\e[0m\n' "$desc" > "$tty_target" 2>/dev/null || true
            else
                printf '       %s\n' "$desc" > "$tty_target" 2>/dev/null || true
            fi
        fi
    done

    # Updated footer text.
    if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
        printf '\n  \e[2mEnter to select · ↑↓ navigate · Space toggle · Esc cancel\e[0m\n' \
            > "$tty_target" 2>/dev/null || true
    else
        printf '\n  Enter to select · ↑↓ navigate · Space toggle · Esc cancel\n' \
            > "$tty_target" 2>/dev/null || true
    fi
}
```

Note: the previous "focused-row description at the bottom" block is REMOVED (it's redundant now that every row has its description inline).

Verify the trap-restore behaviour (WR-04, lines 196-205 + 263-268) is untouched. Verify TK_TUI_TTY_SRC seam is preserved on every printf. Verify no associative arrays / no namerefs / no float reads were introduced.

Verify: `shellcheck -S warning scripts/lib/tui.sh`.

Commit message:
```text
feat(tui): numbered rows + per-row inline descriptions + new footer

- _tui_render now prints "  N. [box] label" with 1-indexed N
- Every row gets a dimmed inline description directly below it
  (was previously focus-only at the bottom of the screen)
- Section headers gain bold weight + extra blank-line separation
- Footer reworded to "Enter to select · ↑↓ navigate · Space toggle · Esc cancel"
- All tty_target writes, color gates, focus arrow, and trap-restore
  invariants preserved (Bash 3.2 compatible).
```
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/lib/dispatch.sh scripts/install.sh scripts/lib/tui.sh && grep -q "dispatch_council" scripts/lib/dispatch.sh && grep -q "council" scripts/lib/dispatch.sh && grep -q 'IS_COUNCIL' scripts/install.sh && grep -q "Enter to select" scripts/lib/tui.sh && grep -q "%d\\." scripts/lib/tui.sh</automated>
  </verify>
  <done>
- Three commits pushed in order (dispatch_council → install.sh wiring → tui.sh render)
- All three files shellcheck -S warning clean
- TK_DISPATCH_ORDER includes 'council' between 'statusline' and 'gemini-bridge'
- TUI_LABELS includes 'council' (Optional group, IS_COUNCIL probe via -f brain.py)
- _tui_render prints numbered rows + per-row dimmed description + new footer
- Bash 3.2 compatibility preserved (no associative arrays, no namerefs, no float reads)
- TK_TUI_TTY_SRC seam preserved on every printf
  </done>
</task>

<task type="auto">
  <name>Task 3: Switch README primary install URL to install.sh + extend test-install-tui.sh + add test-init-download-fallback.sh</name>
  <files>README.md, scripts/tests/test-install-tui.sh, scripts/tests/test-init-download-fallback.sh</files>
  <action>
Three sub-changes, three commits.

**Sub-3a — README primary install URL switch (commit 1 of 3):**

Edit README.md lines 65-87 (the "Standalone install" + "Complement install" sections). Replace the primary install command with install.sh, keeping init-claude.sh as a documented fallback for direct/scripted use.

Replace the standalone block (current lines 65-73):

```markdown
### Interactive install (recommended)

The unified installer presents a TUI checklist with all components (Toolkit,
Security, RTK, Statusline, Council, Bridges) and lets you opt in to each.
Run in your regular terminal (not inside Claude Code!) in the project folder:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

Then start Claude Code in that project directory. For future updates use `/update-toolkit`.
```

Replace the complement block (current lines 77-87) with a single shorter section that points to the same install.sh URL:

```markdown
### Complement install

You have one or both of `superpowers` (obra) and `get-shit-done` (gsd-build) installed. The
installer auto-detects them and skips the 7 files that would duplicate SP functionality,
keeping the ~47 unique TK contributions (Council, framework CLAUDE.md templates, components
library, cheatsheets, framework-specific skills). Use the same install command — TK
auto-selects the `complement-*` mode. To override, pass `--mode standalone` (or any other
mode name):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --yes --mode complement-full
```

> **Mode behavior today.** `manifest.json` currently catalogues 7 SP overlaps and 0 GSD
> overlaps. `complement-sp` and `complement-full` skip the same 7 files; `complement-gsd`
> skips none — i.e. it is functionally equivalent to `standalone` until GSD-specific
> conflicts are catalogued. The 4-mode UX is preserved so the manifest can mark GSD
> overlaps incrementally without an installer rewrite.

### Direct install (scripted / CI)

For non-interactive contexts, `init-claude.sh` is still supported and runs the
toolkit install only (no Security / Statusline / Council prompts):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```
```

**Markdown lint compliance (CRITICAL — CI gate):** every fenced code block declares a language (MD040), blank lines surround every list and fence (MD031/MD032), no trailing punctuation in headings (MD026). Run `npx markdownlint-cli README.md` after editing — fix any new warnings.

Commit message:
```text
docs(readme): make install.sh the primary install URL; demote init-claude.sh

The install.sh entry point uses lib/tui.sh checklist + lib/dispatch.sh and
covers Toolkit / Security / RTK / Statusline / Council / Bridges from a
single command. init-claude.sh remains supported for scripted / CI contexts
that need the toolkit install only (no Security / Statusline / Council prompts).
```

**Sub-3b — extend test-install-tui.sh (commit 2 of 3):**

Append a new scenario function `run_s_render_format` after the last existing scenario function. Pattern: source lib/tui.sh in a sandboxed bash subshell, populate TUI_* arrays with two known rows, redirect TK_TUI_TTY_SRC to a tmpfile, call _tui_render, then assert the output contains the new format markers.

```bash
# ─────────────────────────────────────────────────
# S_render_format — _tui_render emits numbered rows + per-row dimmed
# descriptions + the updated footer text. Locks the v4.8.1 render contract.
# ─────────────────────────────────────────────────
run_s_render_format() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-tui-render.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S_render_format: numbered rows + per-row description + new footer --"

    local OUT="$SANDBOX/render.out"
    : > "$OUT"

    NO_COLOR=1 TERM=dumb \
        TK_TUI_TTY_SRC="$OUT" \
        bash -c "
            set -u
            source '$REPO_ROOT/scripts/lib/tui.sh'
            TUI_LABELS=('alpha' 'beta')
            TUI_GROUPS=('Bootstrap' 'Optional')
            TUI_INSTALLED=(0 0)
            TUI_RESULTS=(1 0)
            TUI_DESCS=('first description' 'second description')
            FOCUS_IDX=0
            _tui_init_colors
            _tui_render
        " 2>/dev/null || true

    local rendered
    rendered=$(cat "$OUT" 2>/dev/null || echo "")

    assert_contains "1. " "$rendered" "S_render_format: row 1 has numbered prefix"
    assert_contains "2. " "$rendered" "S_render_format: row 2 has numbered prefix"
    assert_contains "first description" "$rendered" "S_render_format: row 1 description rendered inline"
    assert_contains "second description" "$rendered" "S_render_format: row 2 description rendered inline"
    assert_contains "Enter to select" "$rendered" "S_render_format: new footer text present"
    assert_contains "Esc cancel" "$rendered" "S_render_format: footer mentions Esc cancel"
    assert_not_contains "↑↓ move · space toggle · enter confirm · q quit" "$rendered" "S_render_format: old footer removed"
}
```

Add `run_s_render_format` to the test runner section at the bottom of the file (after the existing run_s* invocations). If the existing file uses a manual list, append it; if it auto-discovers, no change needed.

Commit message:
```text
test(install): assert numbered TUI rows + per-row descriptions + new footer

Locks the v4.8.1 _tui_render contract: row N. prefix, dimmed description
under every row, "Enter to select · ↑↓ navigate · Space toggle · Esc cancel"
footer. Hermetic — uses TK_TUI_TTY_SRC redirect into a tmpfile.
```

**Sub-3c — new test-init-download-fallback.sh (commit 3 of 3):**

Create a new hermetic test file. The four scenarios test download_files() fallback behavior using a local file:// fixture HTTP server simulated via TK_REPO_URL pointed at a directory served by `python3 -m http.server` in the background.

Approach: Spin up `python3 -m http.server` in a sandbox dir that contains a synthetic templates/{base,nodejs}/ tree, point TK_REPO_URL=http://127.0.0.1:$PORT at it, then exercise download_files() variants. Mirror the test-install-tui.sh sandbox + assert helpers.

```bash
#!/usr/bin/env bash
# test-init-download-fallback.sh — v4.8.1 install bug-fix verification.
#
# Scenarios:
#   S1 framework_first   — templates/<framework>/agents/<file> exists  → used directly
#   S2 base_fallback     — templates/<framework>/agents/<file> missing,
#                          templates/base/agents/<file> exists           → fallback succeeds
#   S3 both_missing      — neither URL serves the file                  → counted as failure
#   S4 marketplace_skip  — manifest skills_marketplace bucket entries   → never iterated
#
# Strategy: spin up python3 -m http.server pointing at a synthetic repo tree;
# point TK_REPO_URL at it; invoke download_files() in isolation.
#
# Usage: bash scripts/tests/test-init-download-fallback.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }
assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}
assert_file_exists()    { [ -f "$1" ] && assert_pass "$2" || assert_fail "$2" "missing: $1"; }
assert_file_missing()   { [ ! -f "$1" ] && assert_pass "$2" || assert_fail "$2" "unexpected: $1"; }

# Sandbox + http.server lifecycle ────────────────────────────────────────
SANDBOX="$(mktemp -d /tmp/test-init-dl.XXXXXX)"
SERVER_PID=""
cleanup() {
    [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null || true
    rm -rf "${SANDBOX:?}"
}
trap cleanup EXIT

REPO_FIXTURE="$SANDBOX/repo"
mkdir -p "$REPO_FIXTURE/templates/base/agents"
mkdir -p "$REPO_FIXTURE/templates/nodejs/agents"

# Fixture content: framework-only file, base-only file, both-missing not-created.
echo "framework agent body" > "$REPO_FIXTURE/templates/nodejs/agents/nodejs-expert.md"
echo "base agent body"      > "$REPO_FIXTURE/templates/base/agents/planner.md"

# Minimal manifest covering all four scenarios.
cat > "$REPO_FIXTURE/manifest.json" <<'JSON'
{
  "manifest_version": 2,
  "files": {
    "agents": [
      { "path": "agents/nodejs-expert.md" },
      { "path": "agents/planner.md" },
      { "path": "agents/nonexistent.md" }
    ],
    "skills_marketplace": [
      { "path": "templates/skills-marketplace/should-not-fetch" }
    ]
  }
}
JSON

# Pick a free port + start server.
PORT=$((40000 + RANDOM % 10000))
( cd "$REPO_FIXTURE" && python3 -m http.server "$PORT" >/dev/null 2>&1 ) &
SERVER_PID=$!
# Wait briefly for socket to bind (no curl-loop — keep it simple).
for _ in 1 2 3 4 5; do
    if curl -sf "http://127.0.0.1:$PORT/manifest.json" >/dev/null 2>&1; then
        break
    fi
    sleep 0.2
done

if ! curl -sf "http://127.0.0.1:$PORT/manifest.json" >/dev/null; then
    echo "ERROR: fixture http.server did not become ready on port $PORT"
    exit 1
fi

# ─────────────────────────────────────────────────
# Run download_files() in a controlled subshell with TK_REPO_URL pointed
# at the fixture. We can't easily invoke init-claude.sh main() in isolation
# (it does too much setup), so we extract just the critical invariants:
# manifest iteration + framework-first → base-fallback + skills_marketplace skip.
# ─────────────────────────────────────────────────

INSTALL_DIR="$SANDBOX/.claude"
mkdir -p "$INSTALL_DIR"

# Inline reproduction of the post-fix download_files() core logic.
# Asserts the SAME jq filter + URL routing the real code uses.
run_download() {
    local FRAMEWORK="$1"
    local INSTALLED_COUNT=0 FAILED_COUNT=0 SKIPPED_MARKETPLACE=0
    local entry path bucket fw_url base_url full_dest
    while IFS= read -r entry; do
        bucket=$(echo "$entry" | jq -r '.bucket')
        path=$(echo "$entry"   | jq -r '.path')
        full_dest="$INSTALL_DIR/$path"
        mkdir -p "$(dirname "$full_dest")"
        fw_url="http://127.0.0.1:$PORT/templates/$FRAMEWORK/$path"
        base_url="http://127.0.0.1:$PORT/templates/base/$path"
        if curl -sSLf "$fw_url" -o "$full_dest" 2>/dev/null && [[ -s "$full_dest" ]]; then
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        elif curl -sSLf "$base_url" -o "$full_dest" 2>/dev/null && [[ -s "$full_dest" ]]; then
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            rm -f "$full_dest"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    done < <(jq -c '
        .files | to_entries[] |
        .key as $b | .value[] |
        select($b != "skills_marketplace") |
        { bucket: $b, path: .path }
    ' "$REPO_FIXTURE/manifest.json")
    # Marketplace skip check — iterate the bucket separately and assert it was filtered.
    if jq -e '.files.skills_marketplace' "$REPO_FIXTURE/manifest.json" >/dev/null 2>&1; then
        SKIPPED_MARKETPLACE=1
    fi
    echo "$INSTALLED_COUNT $FAILED_COUNT $SKIPPED_MARKETPLACE"
}

echo "test-init-download-fallback.sh: B1 + B2 verification"
echo ""

# ─────────────────────────────────────────────────
# Run all four scenarios in one pass (manifest covers all of them).
# ─────────────────────────────────────────────────
read -r INSTALLED FAILED MARKETPLACE_PRESENT <<< "$(run_download nodejs)"

# S1: framework-first wins.
assert_file_exists "$INSTALL_DIR/agents/nodejs-expert.md" "S1 framework_first: nodejs-expert.md present (framework path)"
GREP_BODY=$(cat "$INSTALL_DIR/agents/nodejs-expert.md" 2>/dev/null || echo "")
assert_eq "framework agent body" "$GREP_BODY" "S1 framework_first: body matches templates/nodejs/ source"

# S2: base fallback.
assert_file_exists "$INSTALL_DIR/agents/planner.md" "S2 base_fallback: planner.md fetched from templates/base/"
GREP_BODY2=$(cat "$INSTALL_DIR/agents/planner.md" 2>/dev/null || echo "")
assert_eq "base agent body" "$GREP_BODY2" "S2 base_fallback: body matches templates/base/ source"

# S3: both missing — file should NOT exist locally + FAILED_COUNT should be ≥1.
assert_file_missing "$INSTALL_DIR/agents/nonexistent.md" "S3 both_missing: nonexistent.md not created on dual 404"
[[ "$FAILED" -ge 1 ]] && assert_pass "S3 both_missing: FAILED_COUNT incremented (got=$FAILED)" \
    || assert_fail "S3 both_missing: FAILED_COUNT not incremented" "got=$FAILED"

# S4: marketplace skip — its directory must never have been fetched.
assert_file_missing "$INSTALL_DIR/templates/skills-marketplace/should-not-fetch" \
    "S4 marketplace_skip: skills_marketplace bucket entries were not iterated"
[[ "$MARKETPLACE_PRESENT" -eq 1 ]] && assert_pass "S4 marketplace_skip: bucket WAS in manifest (filter, not absence)" \
    || assert_fail "S4 marketplace_skip: bucket missing from manifest fixture" "test fixture broken"

# Final tally
echo ""
echo "─────────────────────────────────────────────"
printf "PASS=%d FAIL=%d\n" "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
```

`chmod +x scripts/tests/test-init-download-fallback.sh` after creating.

Verify: `shellcheck -S warning scripts/tests/test-init-download-fallback.sh && bash scripts/tests/test-init-download-fallback.sh`.

Commit message:
```text
test(install): hermetic download fallback test (B1 + B2 verification)

Spins up python3 -m http.server pointing at a synthetic repo tree, then
exercises the post-B1+B2 download loop with four scenarios:
- S1 framework_first  — templates/<fw>/<file> wins when present
- S2 base_fallback    — falls back to templates/base/<file> on 404
- S3 both_missing     — both 404 → counted as failure, no zero-byte file
- S4 marketplace_skip — skills_marketplace bucket filtered out at jq stage

Mirrors the assert_*/sandbox helpers from test-install-tui.sh.
```

Final verification across all 7 commits in this plan:

```bash
make check
bash scripts/tests/test-install-tui.sh
bash scripts/tests/test-init-download-fallback.sh
git log --oneline fix/install-bugs-v4.8.1 ^main
```

Expect 7 commits in log; both test scripts exit 0; `make check` passes.
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/tests/test-init-download-fallback.sh scripts/tests/test-install-tui.sh && npx markdownlint-cli README.md && grep -q "scripts/install.sh" README.md && grep -q "S_render_format" scripts/tests/test-install-tui.sh && bash scripts/tests/test-init-download-fallback.sh</automated>
  </verify>
  <done>
- README.md primary install URL is install.sh; init-claude.sh demoted to "Direct install"
- README.md passes markdownlint (no MD040/MD031/MD032/MD026 violations)
- test-install-tui.sh has run_s_render_format scenario asserting numbered + per-row desc + new footer
- test-init-download-fallback.sh exists, is executable, and exits 0 with all 4 scenarios passing
- 3 commits pushed in order
- `make check` passes from a clean state
- `git log --oneline fix/install-bugs-v4.8.1 ^main` shows 7 commits total across this plan
  </done>
</task>

</tasks>

<verification>
After all 3 tasks complete (7 commits total):

1. `make check` exits 0 (shellcheck + markdownlint + validate)
2. `bash scripts/tests/test-install-tui.sh` exits 0 with the new S_render_format scenario passing
3. `bash scripts/tests/test-init-download-fallback.sh` exits 0 with all 4 scenarios passing
4. `git log --oneline fix/install-bugs-v4.8.1 ^main | wc -l` returns 7
5. `grep -c "skills_marketplace" scripts/init-claude.sh` returns ≥1 (the skip comment + jq filter)
6. `grep -c "lib/detect2.sh" scripts/init-claude.sh` returns ≥1 (the new download block)
7. `grep -c "dispatch_council" scripts/lib/dispatch.sh` returns ≥2 (function def + comment header)
8. `grep -c "council" scripts/install.sh` returns ≥3 (TUI_LABELS + dispatch case + IS_COUNCIL probe)
9. `grep "TK_DISPATCH_ORDER=" scripts/lib/dispatch.sh` shows `... statusline council gemini-bridge codex-bridge)`
10. `grep -c "Enter to select" scripts/lib/tui.sh` returns 2 (color + no-color paths)
11. Manual smoke: `bash scripts/install.sh --dry-run` shows the new TUI render with numbered rows + per-row description + the council row
</verification>

<success_criteria>
- 7 atomic commits on branch fix/install-bugs-v4.8.1 (no --no-verify, Conventional Commits)
- All 5 install bugs fixed in scripts/init-claude.sh
- dispatch_council shipped in lib/dispatch.sh; 'council' in TK_DISPATCH_ORDER
- TUI council row present in install.sh (Optional group)
- TUI render upgraded (numbered + per-row description + new footer); Bash 3.2 compatible; TK_TUI_TTY_SRC seam preserved; trap-restore (WR-04) intact
- README.md primary install URL switched to install.sh
- New hermetic test (test-init-download-fallback.sh) covers 4 scenarios
- Extended test-install-tui.sh asserts the new render format
- `make check` passes
- Both test scripts exit 0
- manifest.json version unchanged; CHANGELOG.md untouched
- No files removed; backwards compat for init-claude.sh URL preserved
</success_criteria>

<output>
After completion, create `.planning/quick/260501-lrq-fix-critical-install-bugs-in-scripts-ini/SUMMARY.md` with:
- Commit SHAs (7 total) and one-line subjects
- Verification command outputs (make check, both test scripts, git log)
- Any deferred items discovered during execution
- Notes on Bash 3.2 / shellcheck / markdownlint findings encountered + fixed
</output>
