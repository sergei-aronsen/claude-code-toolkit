# Deep Code Review — Claude Code Toolkit

Scope: scripts/, scripts/lib/, scripts/council/, Makefile, manifest.json, .github/workflows/quality.yml. Focused on correctness, logic, edge cases, resource leaks. Security audit explicitly out of scope (running in parallel).

Confidence threshold: >=80% before reporting. Trace-through performed on each finding.

---

## Counts

- Critical: 0
- High: 3
- Medium: 4
- Low: 4
- Total: 11

---

## High

### H-1. install.sh dispatches the wrong bridge when only one CLI is detected

- **File:** `scripts/install.sh:843-873, 897-910` (interaction with `:611-649`)
- **Bug:** The dispatch loop indexes `TK_DISPATCH_ORDER[$i]` to derive `local_name` (the action) and `TUI_LABELS[$i]` to derive `local_label` (the displayed name). `TK_DISPATCH_ORDER` is fixed at 8 entries (`scripts/lib/dispatch.sh:75`): `superpowers gsd toolkit security rtk statusline gemini-bridge codex-bridge`. `TUI_LABELS` is built dynamically and only appends `gemini-bridge` if `IS_GEM=1` and `codex-bridge` if `IS_COD=1`.
- **Trigger:** A user with only Codex CLI installed (`IS_GEM=0, IS_COD=1`):
  - `TUI_LABELS = [superpowers, gsd, toolkit, security, rtk, statusline, codex-bridge]` (length 7)
  - Loop runs `i=0..6`. At `i=6`: `local_name = TK_DISPATCH_ORDER[6] = "gemini-bridge"`, `local_label = TUI_LABELS[6] = "codex-bridge"`.
  - The dispatch case at `:898` matches `gemini-bridge` and calls `bridge_create_global "gemini"` even though the user has no Gemini CLI and the UI offered "codex-bridge".
  - The codex-bridge row is never executed.
- **Force-select path is also broken:** `--bridges codex` at `:773-790` correctly sets `TUI_RESULTS[6]=1` keyed by TUI_LABELS scan, but the dispatch then runs `gemini-bridge` for that index.
- **Symmetric case:** with `IS_GEM=1, IS_COD=0`, TUI_LABELS[6]="gemini-bridge", local_name=TK_DISPATCH_ORDER[6]="gemini-bridge" — works by accident. Only the codex-only case is broken.
- **Fix:** Build `TUI_DISPATCH_NAMES` as a parallel array to `TUI_LABELS`, appending exactly the same conditional bridge entries; index into it instead of `TK_DISPATCH_ORDER` inside the loop. Or: skip-forward the loop counter when a dispatch-order entry is absent from `TUI_LABELS`.

### H-2. mcp.sh joins install_args with empty separator, producing one mashed token

- **File:** `scripts/lib/mcp.sh:85`
- **Bug:**
  ```sh
  MCP_INSTALL_ARGS+=("$(jq -r --arg n "$name" '[.[$n].install_args[] ] | join("")' "$catalog_path")")
  ```
  Comment two lines above explicitly says "Use `$'\037'` (unit separator, ASCII 31) to join install_args[] — survives spaces in args." but the code passes `""` to `join`. Each MCP's catalog `install_args` (e.g. `["context7", "--", "npx", "-y", "@upstash/context7-mcp"]`) is concatenated to `"context7--npx-y@upstash/context7-mcp"`.
- **Trigger:** Any call to `mcp_wizard_run <name>` after `mcp_catalog_load`. At `:378-381`, `IFS=$'\037'` is set and the packed string is re-split — but with no `\037` inside, `install_args` becomes the single mashed token. `claude mcp add` is then invoked at `:436` with that one argument and fails (or worse: succeeds while passing nonsense to the MCP catalog).
- **Why hidden so far:** `--dry-run` at `:388-391` prints `${install_args[*]}` which space-joins the array — but the array has only one element, so the printed line just shows `claude mcp add context7--npx-y@upstash/context7-mcp`. Tests asserting on dry-run output may not have caught the missing spaces.
- **Fix:** Replace `join("")` with `join("")`. (jq encodes `` as ASCII 31, matching `$'\037'`.)

### H-3. setup-security.sh `install_rtk_notes` never installs RTK.md under `bash <(curl ...)`

- **File:** `scripts/setup-security.sh:87-105`
- **Bug:** `src_rtk="$(dirname "$0")/../templates/global/RTK.md"`. Under `bash <(curl -sSL .../setup-security.sh)`, `$0` is `bash` (or `/dev/fd/N`), so `dirname "$0"` is `.` (or `/dev/fd`). The src path resolves to `./../templates/global/RTK.md` which never exists in the user's CWD.
- **Trigger:** Every curl|bash invocation. The function silently logs "ℹ Skipping RTK.md install — source file not found (offline / partial install)" and returns 0. The user thinks the install succeeded.
- **Impact:** `~/.claude/RTK.md` is never created via the documented install path. Only contributors running `./scripts/setup-security.sh` from a local clone get RTK.md.
- **Fix:** Mirror `install-statusline.sh:116-143` — fall back to curl-fetching `templates/global/RTK.md` from `$REPO_URL` to a tempfile, then `cp`/`mv` into place. Or detect curl|bash and short-circuit to remote fetch.

---

## Medium

### M-1. install.sh references undefined `log_error` function

- **File:** `scripts/install.sh:837`
- **Bug:**
  ```sh
  log_error "TK_DISPATCH_ORDER contains invalid component name: ${_local_check_name@Q}"
  ```
  `log_error` is never defined in install.sh nor any sourced library (`detect.sh`, `lib/{tui,detect2,dispatch,bridges,dry-run-output,optional-plugins,bootstrap,mcp,skills,state,backup,install}.sh`). Under `set -euo pipefail`, an undefined function = "command not found", non-zero exit, instant abort with no diagnostic line.
- **Trigger:** Adversarial state where `TK_DISPATCH_ORDER` contains an entry not matching `^[a-z][a-z0-9-]*$`. In the shipped code this can't happen (dispatch.sh hard-codes the array), so the validator is defensive — but if a future patch ever picks up the value from env, the failure path itself crashes. Also, ironically, the guard exists *because* a future revision might allow env override.
- **Fix:** Replace with `echo -e "${RED}✗${NC} TK_DISPATCH_ORDER contains invalid component name: ${_local_check_name@Q}" >&2`. Or define `log_error()` near the top alongside `print_install_status`.

### M-2. uninstall.sh treats install-time-unhashable files as MODIFIED, prompting needlessly

- **File:** `scripts/uninstall.sh:541-551` and `scripts/lib/state.sh:97-101`
- **Bug:** During install, when a file isn't yet readable (race during async install), `state.sh:101` records `{"path": ..., "sha256": ""}`. Uninstall reads this empty string into `$sha256` and feeds it to `classify_file`, which computes the actual current hash and compares with `""` — never equal, so verdict is `MODIFIED`. The user sees a `[y/N/d]` prompt for a file that the toolkit owns and has not been edited.
- **Trigger:** Any file that was unreadable at install time (rare), or any future install path that intentionally records empty sha256.
- **Fix:** In `classify_file` (line ~233), special-case empty `recorded`: return `MODIFIED` only if file exists; otherwise emit a new verdict (e.g. `UNKNOWN_HASH`) that defaults to keeping the file silently or prompts with a different copy. Alternatively in `state.sh:101`, drop entries with empty sha256 so they are never registered.

### M-3. install.sh dispatch loop iterates over too few elements when bridges enabled (silent skip)

- **File:** `scripts/install.sh:843, 968`
- **Bug:** Both the dispatch loop and the summary loop use `_disp_count=${#TUI_LABELS[@]}` and `_sum_count=${#TUI_LABELS[@]}`. With bridges enabled and `IS_GEM=1, IS_COD=1`, TUI_LABELS has 8 entries — matches TK_DISPATCH_ORDER (8). With only one CLI installed, the loop runs only over the labels actually rendered, but since TK_DISPATCH_ORDER is indexed by the same `i`, position drift is the same root cause as H-1.
- **Trigger / fix:** See H-1 — same fix solves both.

### M-4. update-claude.sh re-source detect.sh re-uses cached file but bootstrap doesn't refresh the variables in init-claude.sh

- **File:** `scripts/init-claude.sh:182-186` (and parallel in init-local.sh:192-214)
- **Bug:** After `bootstrap_base_plugins`, init-claude.sh re-sources `$DETECT_TMP`. detect.sh at line 125-126 ends with `detect_superpowers || true; detect_gsd`. Both functions write env vars via `export`. Sourcing into the same shell context re-runs both. Looks fine.
- **Real subtle issue:** `bootstrap.sh` may have just installed superpowers via `claude plugin install`. The plugin lands at `~/.claude/plugins/cache/claude-plugins-official/superpowers/<version>/`. detect.sh:32-50 picks it up. BUT GSD installs via `bash <(curl -sSL ...)` which under the hood may have changed the working directory or printed prompts that consume the user's TTY. After bootstrap returns, init-claude.sh calls `select_mode` (line 362) which does `read -r -p "..." choice < /dev/tty` — but if GSD's installer left the TTY in raw mode (some installers do), the user's input is mangled.
- **Verdict:** Speculative — would need to test against actual GSD installer. Marking as Medium pending verification. The `_tui_restore` pattern in `lib/tui.sh:65-75` is a hint that someone considered this, but it's not invoked here.
- **Fix (defensive):** Wrap `bootstrap_base_plugins` with `stty sane </dev/tty 2>/dev/null || true` after return.

---

## Low

### L-1. init-claude.sh `recommend_security` mentions `bash <(curl...)` while `setup_council` uses `--no-council` only at start

- **File:** `scripts/init-claude.sh:706-712`
- **Bug:** Cosmetic — `recommend_security` is printed at the end of `main()` even when the user just ran `setup-security.sh` separately. No way to detect; just noisy.
- **Fix:** Probe `~/.claude/hooks/pre-bash.sh` existence (or `is_security_installed`-equivalent) and skip the recommendation if already installed.

### L-2. init-claude.sh `download_extras` fallback chain rewrites correctly but logs misleading message

- **File:** `scripts/init-claude.sh:482-493`
- **Bug:** When framework template fails AND base template also fails, the warning prints `"$dest (using base template)"` BEFORE attempting the base download. If both fail, the user sees two lines: "⚠ X.md (using base template)" then "✗ X.md (download failed, no fallback)". Confusing — first line implies success.
- **Fix:** Move the "(using base template)" message inside the success branch of the fallback download.

### L-3. update-claude.sh `--break-bridge` accepts case-insensitive target but RESTORE error message echoes the user's casing while stored target is lowercased

- **File:** `scripts/update-claude.sh:197, 217`
- **Bug:** `_bb_target=$(echo "$BREAK_BRIDGE" | tr '[:upper:]' '[:lower:]')`. If user passes `--break-bridge GEMINI`, lookup succeeds. Subsequent log message at line 208 says `target=$_bb_target` (lowercase) — fine. But the validator block at `:198-204` echoes `"$BREAK_BRIDGE"` (the original casing) for the error path. Users running `--break-bridge GeminiCLI` see the un-normalised form and might think the script preserved their input. Cosmetic.
- **Fix:** Echo `$_bb_target` (post-normalised) to make the error consistent.

### L-4. brain.py `parse_verdict_table` parses "F-001" as finding ID by prefix only — vulnerable to user-content injection

- **File:** `scripts/council/brain.py:521`
- **Bug:** `if not finding_id.startswith("F-")` accepts `F-` followed by anything: `F-malicious`, `F-`, `F-evilrow|with|pipes`. Existing `extract_block` at `:483-496` already wraps with `<<<COUNCIL_REPORT_BEGIN>>>` sentinel sanitization, but the verdict-table parser itself is permissive.
- **Trigger:** A reviewer model that emits a verdict row with `F-${attacker-controlled}` would pollute the `rows` dict with arbitrary keys. The dict is then iterated at `:2230-2237` and printed to stdout. Low impact (just display), but still a parsing-fragility issue.
- **Fix:** Require `re.match(r"^F-\d+$", finding_id)` to reject non-numeric suffixes.

---

## Manifest / Versioning

- `manifest.json` version 4.8.0 matches CHANGELOG.md (verified by `make version-align`). No drift detected.
- The project intel claim "currently 3.0.0" was stale memory — actual current is 4.8.0.

## False Positives Filtered Out

The following were investigated and confirmed NOT bugs:
- bridges.sh:171-173 symlink check before write — correct.
- state.sh acquire_lock PID liveness check — already audited and patched.
- Makefile validate target — uses `find ... \(... -o ... \)` correctly across both BSD and GNU find.
- mcp.sh:131 `claude mcp list` parsing — regex escape applied, OK.
- brain.py `_run_dry_run` skipping load_config — intentional, docstring at :3228 explains why.
- init-local.sh BRIDGES_JSON='[]' default — works correctly with state.sh:135 preservation logic.

## Coverage Gap (Not a Bug Per Se)

- `setup-security.sh:89` and `install-statusline.sh:41` both use `dirname "$0"` to find sibling lib files. Statusline correctly falls back to curl on lib not found; setup-security correctly falls back at line 76-84 for `lib/install.sh`; but `install_rtk_notes` (H-3) never falls back. Test seam `make test` exercises only `init-local.sh`, so the curl|bash path of `setup-security.sh` is not tested in CI.
