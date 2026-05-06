---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 5
type: execute
wave: 4
depends_on:
  - 40-01
  - 40-02
  - 40-03
files_modified:
  - scripts/tests/test-uninstall-state-cleanup.sh
autonomous: true
requirements:
  - TEST-05

must_haves:
  truths:
    - "test-uninstall-state-cleanup.sh has 6 new scenarios per CONTEXT D-12: UN-SEC-01-Y, UN-SEC-01-N, UN-SEC-03-Y, UN-SEC-03-N, UN-SEC-04 (fingerprint diff), UN-SEC-05 (--keep-state)"
    - "All scenarios use the existing hermetic mktemp -d sandbox + trap EXIT INT TERM cleanup pattern (mirrors lines 79-83 of the existing test)"
    - "All scenarios reuse the TK_UNINSTALL_TTY_FROM_STDIN seam (CONTEXT D-13, PATTERNS.md confirmed seam name) — no new seam introduced"
    - "UN-SEC-01-Y: feeds `y\\n` to single-MCP cleanup → mcp-config.env rewritten without named MCP's keys, OTHER MCPs' keys preserved byte-identically, mode 0600 maintained"
    - "UN-SEC-01-N: feeds `\\n` (default N) → mcp-config.env byte-identical before/after"
    - "UN-SEC-03-Y: feeds `y\\n` to full-toolkit prompt → mcp-config.env removed, STATE_FILE removed AFTER (ordering check via -f tests of both files at successive points OR file-modification-order analysis)"
    - "UN-SEC-03-N: feeds `\\n` to full-toolkit prompt → mcp-config.env byte-identical, STATE_FILE removed (toolkit gone, secrets preserved)"
    - "UN-SEC-04: filesystem-fingerprint snapshot of all *.env files outside sandbox $HOME/.claude/ before AND after uninstall is byte-identical (sha256 + filename list comparison) — under both --dry-run and live runs"
    - "UN-SEC-05: --keep-state flag → mcp-config.env byte-identical, STATE_FILE byte-identical, no `[y/N]` substring in stdout"
    - "PASS floor for test-uninstall-state-cleanup.sh bumped by 6 (existing baseline + 6 new scenarios; record actual baseline in summary)"
  artifacts:
    - path: "scripts/tests/test-uninstall-state-cleanup.sh"
      provides: "6 new scenarios extending existing 249-line file in-place; sha256_any helper reused for fingerprint diff; mode-0600 inline check"
      contains: "UN-SEC-01-Y\\|UN-SEC-04\\|UN-SEC-05"
  key_links:
    - from: "Each new scenario"
      to: "TK_UNINSTALL_TTY_FROM_STDIN seam"
      via: "STDIN_INPUT=$(printf 'y\\n' or '\\n') | TK_UNINSTALL_TTY_FROM_STDIN=1 bash uninstall.sh"
      pattern: 'TK_UNINSTALL_TTY_FROM_STDIN'
    - from: "UN-SEC-01-Y / UN-SEC-03-* scenarios"
      to: "sha256_any helper (line 67-74)"
      via: "Pre/post snapshots of mcp-config.env content + bytes for byte-identical assertions"
      pattern: 'sha256_any'
    - from: "UN-SEC-04 fingerprint scenario"
      to: "find + sha256 over all *.env outside ~/.claude/"
      via: "Snapshot before run + snapshot after run + diff (must be empty)"
      pattern: 'find.*\.env.*-not -path'
    - from: "UN-SEC-05 KEEP_STATE scenario"
      to: "Plan 40-03 KEEP_STATE gate"
      via: "Run uninstall.sh --keep-state with seeded mcp-config.env + STATE_FILE; assert both byte-identical post-run + no `[y/N]` substring in captured stdout"
      pattern: 'KEEP_STATE\\|--keep-state'
---

<objective>
Extend `scripts/tests/test-uninstall-state-cleanup.sh` (249-line existing hermetic test file) with 6 new scenarios that lock the Phase 40 uninstall-secret-cleanup contract end-to-end. Satisfies TEST-05.

Purpose: Plans 40-01 / 40-02 / 40-03 land the implementation; this plan locks the contract so future regressions are caught immediately. Six scenarios per CONTEXT D-12:

1. **UN-SEC-01-Y** — single-MCP cleanup, user answers Y → file rewritten without named MCP's keys, others preserved
2. **UN-SEC-01-N** — single-MCP cleanup, default N → file byte-identical
3. **UN-SEC-03-Y** — full-toolkit prompt, Y → mcp-config.env removed, STATE_FILE removed AFTER (ordering)
4. **UN-SEC-03-N** — full-toolkit prompt, N → mcp-config.env preserved, STATE_FILE removed
5. **UN-SEC-04** — fingerprint diff: NO `*.env` outside `~/.claude/` is touched (under both --dry-run and live)
6. **UN-SEC-05** — `--keep-state` preserves mcp-config.env + STATE_FILE; no `[y/N]` in stdout

All scenarios use the existing hermetic `mktemp -d` + `trap EXIT INT TERM` sandbox pattern. All TTY interactions reuse the `TK_UNINSTALL_TTY_FROM_STDIN` seam (CONTEXT D-13, PATTERNS.md confirmed). The fingerprint diff (UN-SEC-04) is the only new helper pattern — it uses `find` + `sha256_any` to snapshot all `*.env` outside the toolkit home before and after, then `diff` the snapshots.

Output: `scripts/tests/test-uninstall-state-cleanup.sh` extended with 6 new scenarios in-place; PASS counter floor bumped by 6.
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
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-03-SUMMARY.md
@scripts/tests/test-uninstall-state-cleanup.sh
@scripts/tests/test-uninstall-prompt.sh
@scripts/uninstall.sh

<interfaces>
<!-- Existing test infrastructure (DO NOT modify) -->

From scripts/tests/test-uninstall-state-cleanup.sh:
- Line 67-74: `sha256_any()` cross-platform helper (sha256sum on Linux, shasum on macOS)
- Line 79-83: sandbox + seam exports pattern:
  ```bash
  SANDBOX="$(mktemp -d /tmp/uninstall-state.XXXXXX)"
  trap 'rm -rf "${SANDBOX:?}"' EXIT
  export TK_UNINSTALL_HOME="$SANDBOX"
  export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"
  ```
- PASS / FAIL counters (read existing file to find exact variable names and floor logic)

From scripts/tests/test-uninstall-prompt.sh:
- Line 127-144: STDIN prompt-injection harness:
  ```bash
  STDIN_INPUT=$(printf 'y\nd\nN\n\n')
  OUTPUT=$(printf '%s' "$STDIN_INPUT" | \
      HOME="$SANDBOX" \
      TK_UNINSTALL_HOME="$SANDBOX" \
      TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
      TK_UNINSTALL_TTY_FROM_STDIN=1 \
      TK_UNINSTALL_FILE_SRC="$SANDBOX/.reference" \
      bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?
  ```

From Plan 40-01:
- `uninstall_prompt_mcp_keys <name> [<key>...]` — prompts via `< /dev/tty` (or /dev/stdin via seam), default N
- Per-MCP loop recovers names via `claude mcp list` ∩ `mcp_catalog_names`

From Plan 40-02:
- Full-toolkit prompt block with `_mcp_config_path` resolution, key/MCP count derivation, fail-closed N

From Plan 40-03:
- KEEP_STATE gate covers helper call AND mcp-config.env block AND STATE_FILE block

Test seeding requirements:
- Sandbox `$HOME/.claude/mcp-config.env` must be pre-populated with MCP_*_KEY=value entries for at least 2 MCPs (so UN-SEC-01-Y can prove "other MCPs preserved")
- Sandbox `$HOME/.claude/toolkit-install.json` (STATE_FILE) must exist (Plan 40-01's MCP-loop recovery path otherwise short-circuits when state is absent — this matters for UN-SEC-01 scenarios)
- Mock `claude` CLI on PATH OR set `TK_MCP_CLAUDE_BIN` to a stub script that emits a known `claude mcp list` format — without this, the per-MCP loop has no MCPs to iterate
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add UN-SEC-01-Y, UN-SEC-01-N, UN-SEC-03-Y, UN-SEC-03-N scenarios (4 prompt-driven scenarios)</name>
  <files>scripts/tests/test-uninstall-state-cleanup.sh</files>
  <action>
Read the existing `test-uninstall-state-cleanup.sh` (249 lines) end-to-end before editing. Identify:
- Exact PASS/FAIL counter variables (likely `PASS` and `FAIL` based on test-integrations-catalog.sh convention; verify by reading the file)
- Exact sandbox setup pattern (line 79-83 reference + any reset logic between scenarios)
- Where existing scenarios end (likely a "summary line" or final PASS-floor assertion)
- Existing PASS floor (record in summary)

Each new scenario follows the per-scenario harness pattern:

```bash
echo ""
echo "── UN-SEC-01-Y: single-MCP cleanup, user answers Y ──"
# (1) reset sandbox to clean state for THIS scenario
SCENARIO_HOME="$(mktemp -d /tmp/uninstall-un-sec-01-y.XXXXXX)"
mkdir -p "$SCENARIO_HOME/.claude"
# Seed mcp-config.env with two MCPs' keys (one to remove, one to preserve)
cat > "$SCENARIO_HOME/.claude/mcp-config.env" <<'EOF'
MCP_FIRECRAWL_FIRECRAWL_API_KEY=firecrawl-secret-redacted
MCP_NOTION_NOTION_TOKEN=notion-secret-redacted
EOF
chmod 0600 "$SCENARIO_HOME/.claude/mcp-config.env"
# Seed toolkit-install.json (STATE_FILE) so the script doesn't short-circuit on state absence
echo '{"version":"5.0.0","installed_files":[]}' > "$SCENARIO_HOME/.claude/toolkit-install.json"

# (2) Set up a mock `claude` CLI that emits a known `claude mcp list` so per-MCP loop has work to do
MOCK_CLAUDE_BIN="$SCENARIO_HOME/mock-claude"
cat > "$MOCK_CLAUDE_BIN" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "mcp list") echo "firecrawl  some-cmd"; echo "notion  some-cmd" ;;
    "mcp remove") exit 0 ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$MOCK_CLAUDE_BIN"

# (3) Snapshot mcp-config.env BEFORE
PRE_HASH="$(sha256_any "$SCENARIO_HOME/.claude/mcp-config.env")"

# (4) Drive uninstall with `y\n\n` stdin: y to per-MCP firecrawl prompt, \n (default N) to per-MCP notion prompt, \n (default N) to full-toolkit prompt
STDIN_INPUT=$(printf 'y\n\n\n')
RC=0
OUTPUT=$(printf '%s' "$STDIN_INPUT" | \
    HOME="$SCENARIO_HOME" \
    TK_UNINSTALL_HOME="$SCENARIO_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE_BIN" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

# (5) Assertions
# 5a: mcp-config.env still exists (only firecrawl keys removed; notion + file itself preserved)
if [[ -f "$SCENARIO_HOME/.claude/mcp-config.env" ]]; then
    POST_CONTENT="$(cat "$SCENARIO_HOME/.claude/mcp-config.env")"
    # 5b: firecrawl entries gone
    if echo "$POST_CONTENT" | grep -q '^MCP_FIRECRAWL_'; then
        FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-01-Y FAIL: firecrawl keys still present"
    # 5c: notion entries preserved
    elif ! echo "$POST_CONTENT" | grep -q '^MCP_NOTION_NOTION_TOKEN=notion-secret-redacted$'; then
        FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-01-Y FAIL: notion keys not preserved"
    # 5d: mode 0600 maintained
    elif [[ "$(ls -l "$SCENARIO_HOME/.claude/mcp-config.env" | awk '{print $1}')" != "-rw-------" ]]; then
        FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-01-Y FAIL: mode not 0600 after rewrite"
    else
        PASS=$((PASS + 1)); echo "  ✓ UN-SEC-01-Y PASS"
    fi
else
    FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-01-Y FAIL: mcp-config.env missing after Y on per-MCP only (full-toolkit prompt was N)"
fi
rm -rf "$SCENARIO_HOME"
```

Repeat the harness for the other three scenarios with these variations:

**UN-SEC-01-N** — feed `\n\n\n` (all defaults N). Assert post-run mcp-config.env hash == PRE_HASH (byte-identical). Mode 0600 preserved. Both firecrawl and notion entries still present.

**UN-SEC-03-Y** — feed `\n\ny\n` (default N for both per-MCP prompts, Y for full-toolkit prompt). Assert:
- mcp-config.env REMOVED (`[[ ! -f ... ]]`)
- STATE_FILE (toolkit-install.json) ALSO removed
- Ordering: this scenario doesn't directly observe ordering across the two `rm` calls without instrumentation. Indirect ordering check: capture stdout for the `log_success "Removed: $MCP_CFG"` line and the `log_success "State file removed: $STATE_FILE"` line; assert MCP_CFG line appears BEFORE STATE_FILE line in `OUTPUT` via `awk '/Removed: .*mcp-config.env/{a=NR} /State file removed/{b=NR} END{exit (a&&b&&a<b)?0:1}'`.

**UN-SEC-03-N** — feed `\n\n\n` (all defaults). Assert:
- mcp-config.env hash == PRE_HASH (byte-identical)
- STATE_FILE removed (toolkit gone, secrets preserved)

**Bash 3.2 / macOS BSD invariants:**
- `mktemp -d /tmp/...XXXXXX` — POSIX form, BSD-safe.
- `chmod +x` — universal.
- `printf '%s' "$STDIN_INPUT" | ... bash "$REPO_ROOT/scripts/uninstall.sh"` — stdin redirection POSIX.
- `awk '/.../{a=NR} ... END{exit ...}'` — POSIX awk.
- Mode-check via `ls -l ... | awk '{print $1}'` per PATTERNS.md "Mode-0600 stat assertion in tests" — works on BSD + GNU `ls`.
- Avoid `stat -f` / `stat -c` divergence (CONTEXT D-16).

**Hermetic / cleanup discipline:**
- Each scenario uses its OWN `SCENARIO_HOME` (not the file-level SANDBOX) so failure of one does not pollute another.
- `rm -rf "$SCENARIO_HOME"` at end of each scenario.
- The file-level `trap 'rm -rf "${SANDBOX:?}"' EXIT INT TERM` (existing line 80) catches anything that escapes scenario teardown.

**Security review (CLAUDE.md):**
- Mock `claude` script writes to a sandbox-only path; no global filesystem effects.
- The seeded `mcp-config.env` contains placeholder-looking strings (`firecrawl-secret-redacted`); they are NOT real secrets. Documented in test comments.
- The mode-0600 check after rewrite is a security invariant assertion (Plan 40-01 helper guarantees this).
  </action>
  <verify>
    <automated>bash -n scripts/tests/test-uninstall-state-cleanup.sh && shellcheck -S warning scripts/tests/test-uninstall-state-cleanup.sh && bash scripts/tests/test-uninstall-state-cleanup.sh 2>&1 | grep -q 'UN-SEC-01-Y PASS\|✓ UN-SEC-01-Y' && bash scripts/tests/test-uninstall-state-cleanup.sh 2>&1 | grep -q 'UN-SEC-01-N PASS\|✓ UN-SEC-01-N' && bash scripts/tests/test-uninstall-state-cleanup.sh 2>&1 | grep -q 'UN-SEC-03-Y PASS\|✓ UN-SEC-03-Y' && bash scripts/tests/test-uninstall-state-cleanup.sh 2>&1 | grep -q 'UN-SEC-03-N PASS\|✓ UN-SEC-03-N'</automated>
  </verify>
  <done>
    - `bash -n scripts/tests/test-uninstall-state-cleanup.sh` clean
    - `shellcheck -S warning` clean
    - All four scenarios pass on macOS BSD and Linux (test in CI)
    - UN-SEC-01-Y proves: firecrawl keys removed, notion keys preserved, mode 0600 maintained
    - UN-SEC-01-N proves: byte-identical file (sha256 hash matches pre-run)
    - UN-SEC-03-Y proves: mcp-config.env removed before STATE_FILE (ordering via stdout line numbers)
    - UN-SEC-03-N proves: mcp-config.env preserved, STATE_FILE removed
    - PASS counter incremented by 4
  </done>
</task>

<task type="auto">
  <name>Task 2: Add UN-SEC-04 (fingerprint diff) + UN-SEC-05 (--keep-state preservation) scenarios</name>
  <files>scripts/tests/test-uninstall-state-cleanup.sh</files>
  <action>
Two more scenarios — these exercise different code paths than the prompt-driven scenarios in Task 1.

**UN-SEC-04 — project .env never touched (fingerprint diff under --dry-run AND live)**

The contract: NO `.env` file outside `$HOME/.claude/` is opened or modified by uninstall.sh. The test creates several "project" directories under `$SCENARIO_HOME/projects/*` each with their own `.env` files, takes a sha256 + filename fingerprint, runs uninstall.sh, takes a second fingerprint, asserts they are identical. Run twice — once with `--dry-run`, once live.

```bash
echo ""
echo "── UN-SEC-04: project .env files never touched (fingerprint diff) ──"
SCENARIO_HOME="$(mktemp -d /tmp/uninstall-un-sec-04.XXXXXX)"
mkdir -p "$SCENARIO_HOME/.claude"
mkdir -p "$SCENARIO_HOME/projects/alpha" "$SCENARIO_HOME/projects/beta" "$SCENARIO_HOME/projects/gamma"

# Seed several "project" .env files at different depths
echo "DATABASE_URL=postgres://placeholder" > "$SCENARIO_HOME/projects/alpha/.env"
echo "API_KEY=placeholder-1" > "$SCENARIO_HOME/projects/beta/.env"
echo "STRIPE_KEY=placeholder-2" > "$SCENARIO_HOME/projects/gamma/.env"
echo "ROOT_VAR=placeholder" > "$SCENARIO_HOME/.env"

# Seed toolkit state so uninstall has something to do
echo '{"version":"5.0.0","installed_files":[]}' > "$SCENARIO_HOME/.claude/toolkit-install.json"
cat > "$SCENARIO_HOME/.claude/mcp-config.env" <<'EOF'
MCP_FIRECRAWL_FIRECRAWL_API_KEY=fc-redacted
EOF
chmod 0600 "$SCENARIO_HOME/.claude/mcp-config.env"

# Snapshot ALL .env files outside .claude/ before run
fingerprint() {
    # find all .env files NOT inside .claude/, sha256 each, sort, output
    find "$SCENARIO_HOME" -name '.env' -not -path '*/.claude/*' -type f 2>/dev/null \
        | sort \
        | while IFS= read -r f; do
            printf '%s  %s\n' "$(sha256_any "$f")" "${f#$SCENARIO_HOME/}"
          done
}

PRE_FP="$(fingerprint)"

# Run #1: dry-run
RC=0
OUTPUT=$(printf '\n\n\n' | \
    HOME="$SCENARIO_HOME" \
    TK_UNINSTALL_HOME="$SCENARIO_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run 2>&1) || RC=$?

POST_FP_DRYRUN="$(fingerprint)"

# Run #2: live
RC=0
OUTPUT=$(printf '\n\n\n' | \
    HOME="$SCENARIO_HOME" \
    TK_UNINSTALL_HOME="$SCENARIO_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

POST_FP_LIVE="$(fingerprint)"

# Assertions: both post-run fingerprints must equal pre-run fingerprint
if [[ "$PRE_FP" != "$POST_FP_DRYRUN" ]]; then
    FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-04 FAIL (--dry-run): project .env fingerprints diverged"
    diff <(echo "$PRE_FP") <(echo "$POST_FP_DRYRUN") || true
elif [[ "$PRE_FP" != "$POST_FP_LIVE" ]]; then
    FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-04 FAIL (live): project .env fingerprints diverged"
    diff <(echo "$PRE_FP") <(echo "$POST_FP_LIVE") || true
else
    PASS=$((PASS + 1)); echo "  ✓ UN-SEC-04 PASS (project .env files byte-identical under both --dry-run and live)"
fi
rm -rf "$SCENARIO_HOME"
```

**UN-SEC-05 — `--keep-state` preserves all secret files + no `[y/N]` in stdout**

```bash
echo ""
echo "── UN-SEC-05: --keep-state preserves mcp-config.env + STATE_FILE; no [y/N] surfaced ──"
SCENARIO_HOME="$(mktemp -d /tmp/uninstall-un-sec-05.XXXXXX)"
mkdir -p "$SCENARIO_HOME/.claude"
cat > "$SCENARIO_HOME/.claude/mcp-config.env" <<'EOF'
MCP_FIRECRAWL_FIRECRAWL_API_KEY=fc-redacted
MCP_NOTION_NOTION_TOKEN=notion-redacted
EOF
chmod 0600 "$SCENARIO_HOME/.claude/mcp-config.env"
echo '{"version":"5.0.0","installed_files":[]}' > "$SCENARIO_HOME/.claude/toolkit-install.json"

PRE_MCP_HASH="$(sha256_any "$SCENARIO_HOME/.claude/mcp-config.env")"
PRE_STATE_HASH="$(sha256_any "$SCENARIO_HOME/.claude/toolkit-install.json")"

RC=0
OUTPUT=$(HOME="$SCENARIO_HOME" \
    TK_UNINSTALL_HOME="$SCENARIO_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    bash "$REPO_ROOT/scripts/uninstall.sh" --keep-state 2>&1) || RC=$?

# Assertions
if [[ ! -f "$SCENARIO_HOME/.claude/mcp-config.env" ]]; then
    FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-05 FAIL: mcp-config.env removed despite --keep-state"
elif [[ "$(sha256_any "$SCENARIO_HOME/.claude/mcp-config.env")" != "$PRE_MCP_HASH" ]]; then
    FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-05 FAIL: mcp-config.env modified despite --keep-state"
elif [[ ! -f "$SCENARIO_HOME/.claude/toolkit-install.json" ]]; then
    FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-05 FAIL: STATE_FILE removed despite --keep-state"
elif [[ "$(sha256_any "$SCENARIO_HOME/.claude/toolkit-install.json")" != "$PRE_STATE_HASH" ]]; then
    FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-05 FAIL: STATE_FILE modified despite --keep-state"
elif echo "$OUTPUT" | grep -q '\[y/N\]'; then
    FAIL=$((FAIL + 1)); echo "  ✗ UN-SEC-05 FAIL: [y/N] prompt surfaced despite --keep-state"
else
    PASS=$((PASS + 1)); echo "  ✓ UN-SEC-05 PASS (both files byte-identical, no prompts surfaced)"
fi
rm -rf "$SCENARIO_HOME"
```

**Bash 3.2 / macOS BSD invariants:**
- `find ... -name '.env' -not -path '*/.claude/*' -type f` — POSIX find. Verify on BSD: BSD find supports `-name`, `-not`, `-path`, `-type`. The `*/.claude/*` glob excludes paths containing `/.claude/` segment.
- `diff <(echo ...) <(echo ...)` — uses bash process substitution; bash 3.2 supports it. If shellcheck flags compatibility, fall back to writing both fingerprints to temp files and `diff -q`.
- `sha256_any` is the existing helper at line 67-74.
- `printf '\n\n\n'` for default-N drives.

**Performance:**
- Each scenario creates and tears down its own sandbox; total runtime impact ~6×0.3s = ~2s. Acceptable.

**Edge cases:**
- The mock `claude` is not seeded for UN-SEC-04 and UN-SEC-05 because:
  - UN-SEC-04 doesn't depend on per-MCP loop firing; it just asserts no project `.env` is touched. The loop short-circuits when `claude` is absent, which is fine.
  - UN-SEC-05 doesn't depend on per-MCP loop firing either; KEEP_STATE skips the helper call regardless.
- For UN-SEC-04, ensure that the per-MCP loop's silent skip (when `claude` CLI absent) does not error out and contaminate stdout. The fingerprint check is the primary contract; stdout content is secondary.

**PASS floor adjustment:**

After all 6 scenarios, locate the existing PASS-floor line at end-of-file (e.g., `if [[ $PASS -ge NN ]]; then ...`). Bump `NN` by 6. Record the original NN in the SUMMARY for traceability. CONTEXT D-12 says "current PASS — re-verify at plan time, then floor moves up by 6 new scenarios."

**Security review (CLAUDE.md):**
- All seed values are placeholder strings clearly marked `-redacted` or `placeholder` — no real secrets.
- `find` operations confined to `$SCENARIO_HOME` (mktemp'd subtree) — cannot traverse outside.
- The `[y/N]` substring search is over captured stdout (variable), not over user files.
- No new env vars introduced (CONTEXT D-13: reuse `TK_UNINSTALL_TTY_FROM_STDIN`).
  </action>
  <verify>
    <automated>bash -n scripts/tests/test-uninstall-state-cleanup.sh && shellcheck -S warning scripts/tests/test-uninstall-state-cleanup.sh && bash scripts/tests/test-uninstall-state-cleanup.sh 2>&1 | grep -q 'UN-SEC-04 PASS\|✓ UN-SEC-04' && bash scripts/tests/test-uninstall-state-cleanup.sh 2>&1 | grep -q 'UN-SEC-05 PASS\|✓ UN-SEC-05' && bash scripts/tests/test-uninstall-state-cleanup.sh; echo "exit code: $?"</automated>
  </verify>
  <done>
    - `bash -n scripts/tests/test-uninstall-state-cleanup.sh` clean
    - `shellcheck -S warning` clean
    - All 6 scenarios pass on macOS and Linux
    - UN-SEC-04 proves: 4 project `.env` files (alpha, beta, gamma, root) byte-identical under both `--dry-run` and live runs
    - UN-SEC-05 proves: mcp-config.env hash unchanged, STATE_FILE hash unchanged, no `[y/N]` in stdout
    - PASS counter floor at end-of-file bumped by 6
    - Final exit code is 0
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Test sandbox $SCENARIO_HOME → uninstall.sh | Test-internal hermetic boundary; mktemp ensures isolation |
| Captured stdout → grep substring search | Test-internal; the search is over a known-bounded string variable |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-05-01 | Tampering | mock-claude script in $SCENARIO_HOME | mitigate | Sandbox is mktemp'd /tmp subtree; cleanup via per-scenario rm -rf + file-level trap EXIT |
| T-40-05-02 | Information Disclosure | placeholder secrets in seed files | accept | Strings clearly marked `-redacted`/`placeholder`; documented in test comments |
| T-40-05-03 | Denial of Service | find traversal of large sandbox | mitigate | Sandbox depth limited to 3 levels (projects/<dir>/.env); negligible runtime |
| T-40-05-04 | Elevation of Privilege | sourcing $REPO_ROOT/scripts/uninstall.sh as user | accept | Test runs as user; uninstall.sh respects TK_UNINSTALL_HOME — cannot escape sandbox |
| T-40-05-05 | Repudiation | PASS/FAIL counter integrity | mitigate | Counters incremented atomically per scenario; final floor assertion locks total |
| T-40-05-06 | Spoofing | mock claude returning fake mcp list | accept | Mock is in test sandbox PATH only via TK_MCP_CLAUDE_BIN; cannot leak to real environment |
</threat_model>

<verification>
- `bash -n scripts/tests/test-uninstall-state-cleanup.sh` parses clean
- `shellcheck -S warning scripts/tests/test-uninstall-state-cleanup.sh` reports no warnings
- All 6 new scenarios print PASS lines on green run
- PASS-floor assertion at end-of-file bumped by exactly 6
- `bash scripts/tests/test-uninstall-state-cleanup.sh` exits 0
- No new env-var seam introduced (`grep -nE 'TK_UNINSTALL_[A-Z_]+_FROM_STDIN' scripts/tests/test-uninstall-state-cleanup.sh` returns only `TK_UNINSTALL_TTY_FROM_STDIN`)
- `make check` (project root) green
- All other test files unchanged: `make shellcheck`, `bash scripts/tests/test-mcp-selector.sh` (PASS=36), `bash scripts/tests/test-mcp-wizard.sh` (PASS=53), `bash scripts/tests/test-mcp-secrets.sh` (PASS=11), `bash scripts/tests/test-project-secrets.sh` (PASS=42) all green
</verification>

<success_criteria>
- 6 new scenarios in test-uninstall-state-cleanup.sh: UN-SEC-01-Y, UN-SEC-01-N, UN-SEC-03-Y, UN-SEC-03-N, UN-SEC-04, UN-SEC-05
- All scenarios use TK_UNINSTALL_TTY_FROM_STDIN seam (no new seam introduced)
- UN-SEC-01-Y: firecrawl removed, notion preserved, mode 0600 maintained
- UN-SEC-01-N: mcp-config.env byte-identical
- UN-SEC-03-Y: mcp-config.env removed, STATE_FILE removed AFTER (verified via stdout line ordering)
- UN-SEC-03-N: mcp-config.env preserved, STATE_FILE removed
- UN-SEC-04: 4 project .env files byte-identical under both --dry-run and live
- UN-SEC-05: mcp-config.env + STATE_FILE byte-identical, no [y/N] in stdout
- PASS floor bumped by exactly 6
- All other test suites stay green (make check baseline preserved)
- Bash 3.2 / macOS BSD safe (no GNU-only flags, no associative arrays, no `mapfile`)
- Hermetic: each scenario uses its own mktemp'd SCENARIO_HOME with per-scenario rm -rf cleanup
</success_criteria>

<output>
After completion, create `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-05-SUMMARY.md` summarizing:
- Original PASS floor (recorded from existing test file before edits)
- New PASS floor (original + 6)
- All 6 scenario names confirming green run
- Confirmation: `make check` green
- Confirmation: All other test suite baselines unchanged (test-mcp-selector PASS=36, test-mcp-wizard PASS=53, test-mcp-secrets PASS=11, test-project-secrets PASS=42, test-integrations-catalog PASS≥13 from Plan 40-04)
- Phase 40 complete: UN-SEC-01..05, INT-13, INT-14, TEST-05, TEST-06 all delivered across plans 40-01 through 40-05
</output>
