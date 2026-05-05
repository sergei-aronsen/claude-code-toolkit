---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 3
type: execute
wave: 3
depends_on:
  - 40-01
  - 40-02
files_modified:
  - scripts/uninstall.sh
autonomous: true
requirements:
  - UN-SEC-04
  - UN-SEC-05

must_haves:
  truths:
    - "When KEEP_STATE=1, the per-MCP loop's uninstall_prompt_mcp_keys call is SKIPPED entirely"
    - "When KEEP_STATE=1, the full-toolkit mcp-config.env prompt block is SKIPPED entirely"
    - "When KEEP_STATE=1, the existing STATE_FILE removal stays SKIPPED (unchanged from v4.4 KEEP-01)"
    - "When KEEP_STATE=1, no `[y/N]` substring appears in stdout (verified later in Plan 40-05 tests as UN-SEC-05 assertion)"
    - "uninstall.sh --help text documents that --keep-state implies --keep-secrets and explains the Secret cleanup prompts"
    - "Project .env files outside ~/.claude/ are NEVER touched by uninstall.sh — implementation invariant: no code path reads or modifies any .env outside the toolkit home"
    - "Under --dry-run with KEEP_STATE=0, the helper and full-toolkit block print `[dry-run] would prompt: ...` lines without TTY interaction (D-08)"
  artifacts:
    - path: "scripts/uninstall.sh"
      provides: "Extended KEEP_STATE gate around Plan 40-01 helper call + Plan 40-02 mcp-config.env block; updated --help text; sed range bumped"
      contains: "implies --keep-secrets"
  key_links:
    - from: "Plan 40-01 per-MCP loop's uninstall_prompt_mcp_keys call"
      to: "KEEP_STATE flag"
      via: "Skip helper call when KEEP_STATE=1; claude mcp remove still runs (not a secret op)"
      pattern: 'KEEP_STATE.*-eq 0'
    - from: "Plan 40-02 mcp-config.env prompt block"
      to: "KEEP_STATE flag"
      via: "Internal KEEP_STATE branch added inside outer file-exists guard"
      pattern: 'KEEP_STATE.*MCP_CFG'
    - from: "uninstall.sh --help text"
      to: "sed -n range"
      via: "Comment header extended; sed range bumped to cover new lines"
      pattern: 'sed -n'
---

<objective>
Extend the existing `KEEP_STATE` gate so it covers BOTH the Plan 40-01 per-MCP key-cleanup helper AND the Plan 40-02 full-toolkit `mcp-config.env` prompt, plus update `--help` text. Satisfies UN-SEC-05 (`--keep-state` implies `--keep-secrets`) and explicitly documents UN-SEC-04 (project `.env` never touched — the test for this invariant lives in Plan 40-05).

Purpose: v4.4 KEEP-01 introduced `--keep-state` to preserve `~/.claude/toolkit-install.json` after uninstall. The flag is for users saying "I'm uninstalling but I might come back." It would be inconsistent for `--keep-state` to preserve the metadata file but actively prompt to delete the API keys. Phase 40 unifies the semantics: `--keep-state` ALSO means "do not touch any secret-bearing file." Per CONTEXT D-07 no new `--keep-secrets` flag is introduced (YAGNI per CLAUDE.md). UN-SEC-04 is a negative invariant: this plan documents the contract; Plan 40-05 enforces it via filesystem fingerprint test.

Output: `scripts/uninstall.sh` modified to (a) wrap Plan 40-01 helper call in `if [[ $KEEP_STATE -eq 0 ]]`, (b) wrap Plan 40-02 prompt block with KEEP_STATE-aware internal branch, (c) extend `--help` comment header with "Secret cleanup" section + "implies --keep-secrets" note, (d) bump `sed -n` range that renders `--help`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-CONTEXT.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-PATTERNS.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-01-SUMMARY.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-02-SUMMARY.md
@scripts/uninstall.sh

<interfaces>
<!-- Pre-existing KEEP_STATE wiring (DO NOT modify these touchpoints; only extend) -->

From scripts/uninstall.sh (existing):
- Line ~25: `KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}` — env-var precedence (KEEP-01 D-09)
- Line ~31-33: `--keep-state) KEEP_STATE=1 ;;` — flag handler in case
- Line ~824-834: `if [[ $KEEP_STATE -eq 0 ]]; then rm -f "$STATE_FILE"; ... fi` — existing gate (UN-05 D-06 anchor)
- Line ~3-19: comment header rendered by `--help`
- Line ~35: `sed -n '3,19p' "$0"` (or similar range) — what `--help` actually prints

From Plan 40-01 (now in tree):
- Per-MCP loop with `uninstall_prompt_mcp_keys "$_mcp_name" $_keys` call inside

From Plan 40-02 (now in tree):
- Full-toolkit prompt block with outer guard `if [[ -n "$MCP_CFG" && -f "$MCP_CFG" ]]`
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Gate Plan 40-01 helper + Plan 40-02 block on KEEP_STATE; refine dry-run paths; update --help</name>
  <files>scripts/uninstall.sh</files>
  <action>
Three precise edits in `scripts/uninstall.sh`:

**Edit A — gate the per-MCP `uninstall_prompt_mcp_keys` call (UN-SEC-05 leg #1):**

Inside Plan 40-01's `for _mcp_name in "${INSTALLED_MCPS[@]}"; do ... done` loop, the current call site is:

```bash
# shellcheck disable=SC2086 -- intentional whitespace word-split on key list
uninstall_prompt_mcp_keys "$_mcp_name" $_keys
```

Wrap with KEEP_STATE check:

```bash
if [[ $KEEP_STATE -eq 0 ]]; then
    # shellcheck disable=SC2086 -- intentional whitespace word-split on key list
    uninstall_prompt_mcp_keys "$_mcp_name" $_keys
fi
```

**Important:** the `claude mcp remove --scope user "$_mcp_name"` step earlier in the loop is NOT secret-related — it removes the MCP registration only. That step continues to run regardless of `KEEP_STATE`. Only the SECRET-cleanup helper is gated.

**Edit B — gate the full-toolkit `mcp-config.env` block (UN-SEC-05 leg #2):**

Plan 40-02's outer guard is:

```bash
if [[ -n "$MCP_CFG" && -f "$MCP_CFG" ]]; then
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        echo "[dry-run] would prompt: also remove $MCP_CFG?"
    else
        # ... prompt + rm logic ...
    fi
fi
```

Refactor to add KEEP_STATE branch FIRST (mirrors the structure of the existing STATE_FILE block at line ~824-834):

```bash
if [[ -n "$MCP_CFG" && -f "$MCP_CFG" ]]; then
    if [[ $KEEP_STATE -ne 0 ]]; then
        log_info "mcp-config.env preserved (--keep-state): $MCP_CFG"
    elif [[ ${DRY_RUN:-0} -eq 1 ]]; then
        echo "[dry-run] would prompt: also remove $MCP_CFG?"
    else
        # ... existing prompt + rm logic from Plan 40-02 unchanged ...
    fi
fi
```

This preserves "skip when file absent" (outer guard unchanged) while adding KEEP_STATE branch as the FIRST internal check. Symmetric with the existing STATE_FILE block (line 826-834).

**Edit C — extend `--help` comment header + bump sed range (D-19):**

Current header at lines 3-19 documents `--help`, `--dry-run`, `--keep-state`. Extend:

1. Modify the `--keep-state` line to read:
   ```text
   #   bash scripts/uninstall.sh --keep-state  # preserve toolkit-install.json + secrets (implies --keep-secrets)
   ```

2. Add a new "Secret cleanup" section block AFTER the existing usage block (before the existing closing line at ~19):
   ```text
   #
   # Secret cleanup:
   #   When a registered MCP is removed, you are prompted [y/N] to also remove
   #   that MCP's keys from ~/.claude/mcp-config.env. Default N preserves the keys.
   #   At the end of a full toolkit uninstall, you are prompted ONCE to remove the
   #   entire ~/.claude/mcp-config.env. Default N preserves the file.
   #   Project .env files are NEVER touched by this script.
   #   --keep-state implies --keep-secrets (no secret prompts surfaced).
   ```

3. Bump the `sed -n '3,19p' "$0"` range to cover new lines. Count exact line count after Edit C step 2; new range likely `'3,28p'` or similar. Verify by running `bash scripts/uninstall.sh --help` after edit and confirming the new section renders.

**Implementation order:**
- Edit A first (additive — new `if` wrapper).
- Edit B second (refactor outer guard with internal KEEP_STATE branch).
- Edit C third (extend header, then bump sed range AFTER counting actual final line numbers).

**Bash 3.2 / macOS BSD invariants (CONTEXT D-16):**
- `[[ $KEEP_STATE -eq 0 ]]`, `[[ $KEEP_STATE -ne 0 ]]` — POSIX-safe.
- `sed -n '3,Np'` — POSIX, BSD-supported.
- No `mapfile`, no `${var,,}`, no `read -N`.

**UN-SEC-04 negative invariant (no code added; documentation only):**
This plan does NOT add code to verify "no project `.env` ever touched." The invariant is the absence of any `find ... -name '.env'` / `cat .env` / `read .env` against paths outside `~/.claude/`. Plan 40-05 test enforces this via filesystem fingerprint diff. Manual verification check during this plan:

```bash
grep -nE '\.env(\b|$)' scripts/uninstall.sh
```

Expected matches limited to:
1. `mcp-config.env` (toolkit-managed file inside `~/.claude/`)
2. Comments in `--help` text mentioning `.env` for documentation
3. No reads/writes of any `.env` outside `~/.claude/`

**Security review (CLAUDE.md):**
- No new shell execution, no eval, no path interpolation.
- KEEP_STATE branches are purely skips — strictly reduce side effects, never increase them.
- `--help` text exposes user-visible behavior only; no secrets disclosed.
  </action>
  <verify>
    <automated>bash -n scripts/uninstall.sh && shellcheck -S warning scripts/uninstall.sh && grep -q 'implies --keep-secrets' scripts/uninstall.sh && bash scripts/uninstall.sh --help 2>&1 | grep -q 'Secret cleanup' && bash scripts/uninstall.sh --help 2>&1 | grep -q 'implies --keep-secrets'</automated>
  </verify>
  <done>
    - `bash -n scripts/uninstall.sh` clean
    - `shellcheck -S warning scripts/uninstall.sh` clean
    - `grep -nE 'KEEP_STATE.*-eq 0' scripts/uninstall.sh` shows at least 3 sites: helper-call wrapper, mcp-config.env block (or its `-ne 0` mirror), STATE_FILE block (existing)
    - `bash scripts/uninstall.sh --help` prints the new "Secret cleanup" section
    - `bash scripts/uninstall.sh --help` prints the `(implies --keep-secrets)` text on the `--keep-state` line
    - The `--help` output is byte-identical between two runs (no nondeterminism introduced)
    - With `KEEP_STATE=1` (env-var or flag) and `mcp-config.env` present in sandbox `$HOME`, running uninstall.sh shows NO `[y/N]` prompt substring in stdout
    - `make shellcheck` (project root) green
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| --keep-state flag → behavior gate | Pre-existing flag; this plan EXTENDS its scope but does not introduce a new boundary |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-03-01 | Tampering | --help text rendering | mitigate | `sed -n '3,Np' "$0"` reads the script's own comment block; no external input. Range bumped only after counting actual lines |
| T-40-03-02 | Information Disclosure | --help mentions Secret cleanup behavior | accept | Documenting user-visible behavior is the intended outcome; no key names or values disclosed |
| T-40-03-03 | Denial of Service | KEEP_STATE check adds zero loops | mitigate | Plain `[[ ]]` test, O(1). No new failure modes |
| T-40-03-04 | Elevation of Privilege | --keep-state implies --keep-secrets means file PRESERVED, never deleted unexpectedly | mitigate | Strictly safer default; the broader scope cannot cause data loss, only data preservation |
| T-40-03-05 | Repudiation | log_info "preserved" line in KEEP_STATE branch | mitigate | Symmetric with existing STATE_FILE preserved log; user has on-screen confirmation |
</threat_model>

<verification>
- `bash -n scripts/uninstall.sh` parses clean
- `shellcheck -S warning scripts/uninstall.sh` reports no warnings
- `grep -n 'implies --keep-secrets' scripts/uninstall.sh` shows the documented implication
- `bash scripts/uninstall.sh --help` includes the new "Secret cleanup" block
- Manual run with `KEEP_STATE=1` shows zero `[y/N]` substrings in stdout (UN-SEC-05 invariant)
- `grep -nE '\.env(\b|$)' scripts/uninstall.sh` confirms `.env` references are limited to `mcp-config.env` and `--help` documentation only (UN-SEC-04 invariant)
- `make shellcheck` green
</verification>

<success_criteria>
- Plan 40-01 helper call wrapped in `if [[ $KEEP_STATE -eq 0 ]]`
- Plan 40-02 prompt block has internal KEEP_STATE branch (skip + log_info "preserved" message)
- Existing STATE_FILE block at line ~824 byte-identical (do not touch)
- `--help` text includes "Secret cleanup" section
- `--help` text mentions `(implies --keep-secrets)` on the `--keep-state` line
- `--help` text mentions "Project .env files are NEVER touched"
- `sed -n` range correctly bumped to cover the new lines
- Bash 3.2 / macOS BSD safe (no GNU-only flags, no associative array)
- UN-SEC-04 invariant verified by grep: no reads of `.env` outside `~/.claude/`
- Dry-run paths still work: prints `[dry-run] would prompt: ...` when `KEEP_STATE=0` and `DRY_RUN=1`
</success_criteria>

<output>
After completion, create `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-03-SUMMARY.md` summarizing:
- Final line numbers of the three KEEP_STATE gates (helper call, mcp-config.env block, STATE_FILE block — last one unchanged)
- Final line count and `sed -n` range for `--help` rendering
- Confirmation that `--help` output renders correctly with the new "Secret cleanup" section
- Confirmation that `grep -nE '\.env(\b|$)' scripts/uninstall.sh` returns only the expected references (mcp-config.env + --help text)
- Note that UN-SEC-04 negative invariant is enforced by tests in Plan 40-05, not this plan
</output>
