---
phase: 25
plan: "04"
type: execute
wave: 4
depends_on:
  - "25-01"
  - "25-02"
  - "25-03"
files_modified:
  - scripts/tests/test-mcp-selector.sh
  - manifest.json
  - Makefile
  - .github/workflows/quality.yml
  - docs/MCP-SETUP.md
  - docs/INSTALL.md
autonomous: true
requirements:
  - MCP-05
  - MCP-SEC-02
  - MCP-01
tags: [test, manifest, docs, ci, phase-25]

must_haves:
  truths:
    - "scripts/tests/test-mcp-selector.sh is a hermetic test file with at least 12 assert_* invocations covering catalog parse correctness, three-state is_mcp_installed, wizard hidden-input contract, mcp-config.env mode 0600, collision prompt behavior, CLI-absent --mcps banner path, install-success path, and OAuth-only --yes skip"
    - "test-mcp-selector.sh sandboxes HOME via TK_MCP_CONFIG_HOME, mocks claude binary via TK_MCP_CLAUDE_BIN, mocks TTY via TK_MCP_TTY_SRC, performs zero filesystem writes outside the mktemp tmpdir"
    - "test-mcp-selector.sh exits 0 when all assertions pass and 1 if any fail; output uses the same OK/FAIL format as test-install-tui.sh"
    - "manifest.json gains scripts/lib/mcp.sh and scripts/lib/mcp-catalog.json under files.libs[] in alphabetical sort position; test files are NOT added"
    - "Makefile gains Test 32 entry pointing to test-mcp-selector.sh, .PHONY updated, standalone target test-mcp-selector exists"
    - ".github/workflows/quality.yml extends the existing tests step from Tests 21-31 to Tests 21-32 by appending bash scripts/tests/test-mcp-selector.sh"
    - "docs/MCP-SETUP.md is a new file documenting mcp-config.env file location and 0600 mode rationale, plaintext-on-disk caveat, rotate-to-secret-manager recipe, and the 9 curated MCPs"
    - "docs/INSTALL.md gains a new H3 subsection for the --mcps flag under the existing install.sh v4.5+ section"
    - "make check passes after all edits land"
    - "test-bootstrap.sh and test-install-tui.sh remain green"
  artifacts:
    - path: "scripts/tests/test-mcp-selector.sh"
      provides: "Hermetic 12-plus-assertion test for MCP-05"
      contains: "assert_eq assert_contains run_s"
      min_lines: 200
    - path: "manifest.json"
      provides: "files.libs gains mcp.sh + mcp-catalog.json"
      contains: "scripts/lib/mcp.sh"
    - path: "Makefile"
      provides: "Test 32 target plus standalone invocation"
      contains: "test-mcp-selector"
    - path: ".github/workflows/quality.yml"
      provides: "CI step running test-mcp-selector.sh"
      contains: "test-mcp-selector.sh"
    - path: "docs/MCP-SETUP.md"
      provides: "User-facing MCP install + secrets rotation guide"
      contains: "mcp-config.env"
    - path: "docs/INSTALL.md"
      provides: "--mcps flag subsection"
      contains: "--mcps"
  key_links:
    - from: "test-mcp-selector.sh"
      to: "scripts/lib/mcp.sh"
      via: "source under set -euo pipefail with hermetic sandbox"
      pattern: "source.*scripts/lib/mcp.sh"
    - from: "manifest.json files.libs"
      to: "scripts/lib/mcp.sh"
      via: "alphabetical insertion between install.sh and optional-plugins.sh"
      pattern: "scripts/lib/mcp"
    - from: "Makefile Test 32"
      to: "test-mcp-selector.sh"
      via: "bash scripts/tests/test-mcp-selector.sh"
      pattern: "test-mcp-selector"
    - from: ".github/workflows/quality.yml"
      to: "test-mcp-selector.sh"
      via: "appended to the Tests 21-32 step"
      pattern: "test-mcp-selector.sh"
---

<objective>
Wire the Phase 25 deliverables into the toolkit's test, distribution, and documentation surfaces. Three concerns merge into one plan because they all consume the same upstream artifacts (mcp.sh, mcp-catalog.json, install.sh --mcps) and they must land atomically — shipping a manifest that lists mcp.sh without a test exercising it, OR shipping a test without CI integration, breaks the toolkit invariant that every distributed lib has CI coverage.

Six surfaces touched:

1. Hermetic test scripts/tests/test-mcp-selector.sh mirroring scripts/tests/test-install-tui.sh patterns: PASS/FAIL counters, sandbox via mktemp -d, mock binaries via path overrides, fixture files for TTY input. Target at least 12 assertions across 8 scenarios.

2. manifest.json files.libs gains scripts/lib/mcp.sh and scripts/lib/mcp-catalog.json so update-claude.sh auto-discovers them via the existing jq path (LIB-01 D-07 zero-special-casing invariant). The catalog JSON lives under scripts/lib/ so it belongs in files.libs not inventory.components. Test files are NOT in manifest — they ship via repo, not via curl-bash.

3. Makefile Test 32 follows the established pattern from Test 31. Target test-mcp-selector also exposed standalone for fast iteration.

4. CI single-line append to the existing Tests 21-XX step (renamed from 21-31 to 21-32) in .github/workflows/quality.yml.

5. docs/MCP-SETUP.md new file. Content: install + browse instructions, the 9 curated MCPs with their env-var requirements, file location of ~/.claude/mcp-config.env, the 0600 mode rationale (MCP-SEC-01), the plaintext-on-disk caveat with rotate-to-secret-manager recipe (MCP-SEC-02 doc requirement). Markdown must pass markdownlint.

6. docs/INSTALL.md append a new H3 subsection under existing install.sh v4.5+ section. Mirrors structure of existing TUI controls subsection.

CRITICAL — manifest version is NOT bumped to 4.5.0 here. Phase 24 D-31 (from 24-05 SUMMARY) defers version bump to Phase 27 distribution phase. make check passes because validate-manifest.py only checks schema, and version-align checks manifest.json equals CHANGELOG.md equals init-local.sh --version — if those three stay aligned at 4.4.0, alignment passes.

CHANGELOG.md is NOT modified here either — also deferred to Phase 27 release-prep, matching Phase 24 pattern (zero CHANGELOG edits in 24-01..24-05).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/25-mcp-selector/25-CONTEXT.md
@.planning/phases/25-mcp-selector/25-01-mcp-catalog-and-loader-SUMMARY.md
@.planning/phases/25-mcp-selector/25-02-wizard-and-secrets-SUMMARY.md
@.planning/phases/25-mcp-selector/25-03-install-sh-mcps-page-SUMMARY.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-04-install-orchestrator-and-tests-SUMMARY.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-05-manifest-and-docs-SUMMARY.md
@scripts/tests/test-install-tui.sh
@scripts/lib/mcp.sh
@scripts/lib/mcp-catalog.json
@scripts/install.sh
@manifest.json
@Makefile
@.github/workflows/quality.yml
@docs/INSTALL.md
@.markdownlint.json

<interfaces>
Reference patterns:

From scripts/tests/test-install-tui.sh:1-67 — assertion helpers (assert_pass, assert_fail, assert_eq, assert_contains, assert_not_contains), the _NOOP_SCRIPT global tmpfile pattern, the SANDBOX mktemp + RETURN trap pattern. Copy these idioms verbatim into the new test file.

From manifest.json:225-253 — current files.libs ordering. Pre-Phase 25 order is alphabetical: backup.sh, bootstrap.sh, detect2.sh, dispatch.sh, dry-run-output.sh, install.sh, optional-plugins.sh, state.sh, tui.sh. Insertion target: mcp-catalog.json sorts alpha after install.sh (i-n-s less than m-c-p — wait, m comes BEFORE i alphabetically only when comparing first letters, but 'i' less than 'm'). Verify by writing all 9 entries plus the 2 new ones in a file and running sort. Correct alpha order is: backup, bootstrap, detect2, dispatch, dry-run-output, install, mcp-catalog.json, mcp.sh, optional-plugins, state, tui. So mcp-catalog.json and mcp.sh go BETWEEN install.sh and optional-plugins.sh.

From Makefile:1 — .PHONY line; line 153-154 — Test 31 echo + bash invocation pattern; line 167-168 — standalone test-install-tui target.

From .github/workflows/quality.yml:109-121 — the existing Tests 21-31 step block.

From docs/INSTALL.md:82-138 — the install.sh (unified entry, v4.5+) section structure with H3 subsections for Quick start, Flags, TUI controls, Backwards compatibility.

New file path locations: docs/MCP-SETUP.md (sibling of docs/INSTALL.md). The toolkit lints all .md via markdownlint with rules from .markdownlint.json (MD040 enforced, MD031/032 enforced, MD026 forbids trailing punctuation in headings, MD013 line length disabled).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Author scripts/tests/test-mcp-selector.sh hermetic test</name>
  <files>scripts/tests/test-mcp-selector.sh</files>
  <read_first>
    - scripts/tests/test-install-tui.sh (full file — copy assertion helpers, sandbox + RETURN trap, mock binary, _NOOP_SCRIPT idioms)
    - scripts/lib/mcp.sh (functions to test: mcp_catalog_load, mcp_catalog_names, is_mcp_installed, mcp_secrets_load, mcp_secrets_set, mcp_wizard_run, mcp_status_array)
    - scripts/lib/mcp-catalog.json (the 9 entries the test asserts against)
    - scripts/install.sh (the --mcps branch — exercised end-to-end in S7 and S8)
    - .planning/phases/25-mcp-selector/25-CONTEXT.md (test scaffold spec — TK_MCP_CLAUDE_BIN, TK_MCP_CONFIG_HOME, TK_MCP_TTY_SRC seams)
  </read_first>
  <behavior>
    - Test file exits 0 when all assertions pass; exits 1 if any fail
    - Final stdout line matches "Result: PASS=N FAIL=0"
    - Total assert_* invocations is at least 12 (target 18 across 8 scenarios)
    - Hermetic — every test uses a fresh mktemp -d sandbox cleaned up by RETURN trap; no writes outside the sandbox
    - shellcheck -S warning passes
    - Test invocation under "make test-mcp-selector" prints "FAIL=0"
  </behavior>
  <action>
Create scripts/tests/test-mcp-selector.sh as a new executable bash script. Use shebang #!/usr/bin/env bash. Header comment block per scripts/tests/test-install-tui.sh:1-15 style. Set "set -euo pipefail". Copy the assertion helpers (assert_pass, assert_fail, assert_eq, assert_contains, assert_not_contains) verbatim from scripts/tests/test-install-tui.sh:24-51.

SCRIPT_DIR + REPO_ROOT discovery via:

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

Implement these 8 scenarios as run_sN_<name>() functions. Each function gets its own SANDBOX via mktemp -d, with a "trap rm -rf SANDBOX RETURN" cleanup. Total assertion target is 18.

S1_catalog_correctness — at least 3 assertions
  - Source scripts/lib/mcp.sh
  - Call mcp_catalog_load
  - assert_eq "9" "${#MCP_NAMES[@]}" "S1: catalog contains 9 entries"
  - assert_eq "context7" "${MCP_NAMES[0]}" "S1: alphabetical first entry is context7"
  - Find index of notion via _mcp_lookup_index and assert MCP_OAUTH at that index equals 1

S2_detection_three_state — at least 3 assertions
  - Mock claude binary that prints "context7    sse    https://mcp.context7.com" when invoked with "mcp list" args, exits 0
  - Set TK_MCP_CLAUDE_BIN to the mock path
  - is_mcp_installed context7 returns 0 — assert
  - is_mcp_installed firecrawl returns 1 — assert
  - Unset TK_MCP_CLAUDE_BIN, set PATH=/usr/bin:/bin, unset _MCP_CLI_WARNED
  - is_mcp_installed context7 returns 2 — assert (CLI absent fail-soft)

S3_secret_persistence_and_mode — at least 3 assertions
  - Sandbox HOME via TK_MCP_CONFIG_HOME pointing to SANDBOX
  - mkdir -p SANDBOX/.claude
  - Call mcp_secrets_set FOO bar
  - assert_contains "FOO=bar" "$(cat SANDBOX/.claude/mcp-config.env)" "S3: FOO=bar persisted"
  - Cross-platform mode check: if "stat -f %Mp%Lp PATH" returns "0600" OR "stat -c %a PATH" returns "600" — assert pass; else assert fail
  - Call mcp_secrets_set BAR baz; assert both lines present; mode still 0600

S4_collision_prompt_default_n — at least 2 assertions
  - After S3-style setup, write fixture file: printf "N\n" > SANDBOX/tty.fix
  - Call TK_MCP_TTY_SRC=$SANDBOX/tty.fix mcp_secrets_set FOO new_value
  - mcp_secrets_load
  - assert_eq "bar" "${MCP_SECRET_VALUES[0]}" "S4: default-N preserves original FOO=bar"
  - assert that the function returned 0 (no-op success)

S5_collision_prompt_y_overwrites — at least 1 assertion
  - printf "y\n" > SANDBOX/tty.fix2
  - TK_MCP_TTY_SRC=$SANDBOX/tty.fix2 mcp_secrets_set FOO updated_value
  - mcp_secrets_load
  - assert_eq "updated_value" "${MCP_SECRET_VALUES[0]}" "S5: y answer overwrites FOO"
  - assert FOO appears exactly once (no duplicate) via grep -c

S6_wizard_hidden_input_no_leak — at least 2 assertions
  - Mock claude that records argv + env to claude.argv file
  - printf "secret_xyz\n" > SANDBOX/tty.fix
  - OUTPUT=$(TK_MCP_CLAUDE_BIN=mock TK_MCP_TTY_SRC=fixture mcp_wizard_run context7 2>&1) — capture combined stream
  - assert_not_contains "secret_xyz" "$OUTPUT" "S6: secret value MUST NOT appear in wizard output"
  - assert_contains "CONTEXT7_API_KEY=secret_xyz" "$(cat SANDBOX/.claude/mcp-config.env)" "S6: secret persisted to mcp-config.env"

S7_install_sh_mcps_dry_run — at least 2 assertions
  - Mock claude binary
  - OUTPUT=$(HOME=SANDBOX TK_MCP_CONFIG_HOME=SANDBOX TK_MCP_CLAUDE_BIN=mock NO_COLOR=1 bash REPO_ROOT/scripts/install.sh --mcps --yes --dry-run 2>&1)
  - RC capture via "|| RC=$?"
  - assert_eq "0" "$RC" "S7: install.sh --mcps --yes --dry-run exits 0"
  - assert_contains "would-install" "$OUTPUT" "S7: --dry-run summary shows would-install rows"
  - assert_contains "MCP install summary" "$OUTPUT" "S7: MCP-branch summary header rendered"

S8_install_sh_mcps_no_cli — at least 2 assertions
  - PATH=/usr/bin:/bin, no TK_MCP_CLAUDE_BIN
  - OUTPUT=$(HOME=SANDBOX TK_MCP_CONFIG_HOME=SANDBOX PATH=/usr/bin:/bin NO_COLOR=1 bash REPO_ROOT/scripts/install.sh --mcps --yes 2>&1) — capture combined stream; allow non-zero exit via "|| true"
  - assert_contains "claude CLI not found" "$OUTPUT" "S8: CLI-absent banner emitted"
  - Capture exit code; assert_eq "0" "$RC" "S8: --mcps without CLI exits 0 (read-only browse mode)"

Total: 18 assertions across 8 scenarios. Comfortable above the 12-floor.

End of file: print summary header, call all 8 scenarios in sequence, print final result line:

  echo "test-mcp-selector.sh: MCP-01..05 + MCP-SEC-01..02 integration suite"
  echo ""
  run_s1_catalog_correctness
  run_s2_detection_three_state
  run_s3_secret_persistence_and_mode
  run_s4_collision_prompt_default_n
  run_s5_collision_prompt_y_overwrites
  run_s6_wizard_hidden_input_no_leak
  run_s7_install_sh_mcps_dry_run
  run_s8_install_sh_mcps_no_cli
  echo ""
  echo "Result: PASS=$PASS FAIL=$FAIL"
  [[ "$FAIL" -eq 0 ]]

Mark executable: chmod +x scripts/tests/test-mcp-selector.sh.

shellcheck -S warning MUST pass. Use real fixture tmpfiles (printf "N\n" > path) — do NOT use process substitution like "<(echo N)" because it does not portably expand inside env-var assignments under all shell modes.

For the sandbox HOME override, both HOME=$SANDBOX and TK_MCP_CONFIG_HOME=$SANDBOX must be set when invoking install.sh, because install.sh internally sources detect2.sh which reads $HOME directly.
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/tests/test-mcp-selector.sh && bash scripts/tests/test-mcp-selector.sh 2>&1 | tail -3 | grep -q "FAIL=0" && [ "$(grep -cE 'assert_(eq|contains|not_contains|pass|fail)' scripts/tests/test-mcp-selector.sh)" -ge 12 ]</automated>
  </verify>
  <done>scripts/tests/test-mcp-selector.sh exists and is executable; bash invocation prints "FAIL=0" on the result line; at least 12 assert_* invocations present; shellcheck -S warning is clean.</done>
</task>

<task type="auto">
  <name>Task 2: Wire manifest.json + Makefile + CI step</name>
  <files>manifest.json, Makefile, .github/workflows/quality.yml</files>
  <read_first>
    - manifest.json (current files.libs[] order around lines 225-253)
    - Makefile (Test 31 entry around line 153-154; standalone target around line 167-168; .PHONY at line 1)
    - .github/workflows/quality.yml (Tests 21-31 step around line 109-121)
    - scripts/validate-manifest.py (schema check that must keep passing)
    - scripts/tests/test-update-libs.sh (LIB-01 D-07 invariant test — must stay green after the manifest edit)
  </read_first>
  <behavior>
    - manifest.json gains two new objects in files.libs[] at alpha position: scripts/lib/mcp-catalog.json then scripts/lib/mcp.sh, both between install.sh and optional-plugins.sh
    - manifest.json valid JSON; python3 scripts/validate-manifest.py exits 0
    - Makefile gains test-mcp-selector to .PHONY line; gains a Test 32 echo + bash invocation block in the test target after the Test 31 block; gains a standalone test-mcp-selector target
    - .github/workflows/quality.yml step name renames to Tests 21-32, descriptive suffix mentions MCP-01..05 + MCP-SEC-01..02, and "bash scripts/tests/test-mcp-selector.sh" appended as the LAST line of the step's run block
    - make check passes
    - bash scripts/tests/test-update-libs.sh stays green (auto-discovers new libs without code changes)
    - make test-mcp-selector runs and the test passes
  </behavior>
  <action>
manifest.json edits

Locate files.libs around manifest.json:225-253. After the scripts/lib/install.sh entry at line 242, insert TWO new entries IN THIS ORDER (mcp-catalog.json first, then mcp.sh — alpha within their pair):

      {
        "path": "scripts/lib/mcp-catalog.json"
      },
      {
        "path": "scripts/lib/mcp.sh"
      },

Final files.libs alphabetical order: backup, bootstrap, detect2, dispatch, dry-run-output, install, mcp-catalog.json, mcp.sh, optional-plugins, state, tui.

Do NOT bump "version" (still 4.4.0 — Phase 27 does the version bump per Phase 24 D-31).
Do NOT update "updated" date (per Phase 24 D-31 convention — "updated" reflects last manifest schema change, not feature additions).

The validator scripts/validate-manifest.py uses SOURCE_MAP to translate manifest paths but falls back to repo-root resolution for paths not matching the prefixes (commands/, agents/, prompts/, skills/, rules/). scripts/lib/mcp.sh and scripts/lib/mcp-catalog.json hit the fallback and resolve to scripts/lib/mcp.sh on disk — same pattern as existing scripts/lib/state.sh.

Makefile edits

Edit 1 — Update the .PHONY line at the top to add test-mcp-selector. The line currently ends with "test-uninstall-keep-state test-install-tui". Append "test-mcp-selector" so it becomes "... test-install-tui test-mcp-selector".

Edit 2 — In the "test:" target, AFTER the Test 31 block at lines 153-154, insert a new block (two leading TABs, matching existing convention):

	@echo ""
	@echo "Test 32: MCP catalog + wizard + secrets handling (MCP-01..05, MCP-SEC-01..02)"
	@bash scripts/tests/test-mcp-selector.sh

Edit 3 — AFTER the standalone "test-install-tui:" target at lines 167-168, insert a new standalone target:

# Test 32 — MCP catalog + wizard + secrets (MCP-01..05, MCP-SEC-01..02), invokable standalone
test-mcp-selector:
	@bash scripts/tests/test-mcp-selector.sh

quality.yml edits

Locate the step around line 109. Two changes:

Change 1 — Rename step from "Tests 21-31 — uninstall + banner suite + bootstrap + lib coverage + TUI orchestrator (UN-01..UN-08, BOOTSTRAP-01..04, LIB-01..02, BANNER-01, KEEP-01..02, TUI-01..09)" to:

  Tests 21-32 — uninstall + banner suite + bootstrap + lib coverage + TUI orchestrator + MCP selector (UN-01..UN-08, BOOTSTRAP-01..04, LIB-01..02, BANNER-01, KEEP-01..02, TUI-01..09, MCP-01..05, MCP-SEC-01..02)

Change 2 — As the LAST line of the step's run block, after "bash scripts/tests/test-install-tui.sh", append (with the same 10-space indent as the surrounding lines):

          bash scripts/tests/test-mcp-selector.sh

After all three edits, run "make check" and "bash scripts/tests/test-update-libs.sh" to confirm the LIB-01 invariant holds. The test-update-libs.sh stays green BECAUSE update-claude.sh already auto-discovers via the existing jq path .files | to_entries[] | .value[] | .path — no code change needed in update-claude.sh.
  </action>
  <verify>
    <automated>jq -e '.files.libs[].path | select(. == "scripts/lib/mcp.sh")' manifest.json && jq -e '.files.libs[].path | select(. == "scripts/lib/mcp-catalog.json")' manifest.json && python3 scripts/validate-manifest.py && grep -q 'test-mcp-selector' Makefile && grep -q 'Test 32' Makefile && grep -q 'test-mcp-selector.sh' .github/workflows/quality.yml && grep -q 'Tests 21-32' .github/workflows/quality.yml && bash scripts/tests/test-update-libs.sh 2>&1 | tail -3 | grep -q "FAIL=0" && make test-mcp-selector 2>&1 | tail -3 | grep -q "FAIL=0"</automated>
  </verify>
  <done>manifest.json files.libs lists both new entries in alpha position; validate-manifest.py exits 0; Makefile has Test 32 + standalone target + .PHONY entry; quality.yml step renamed Tests 21-32 with appended test invocation; test-update-libs.sh stays green proving LIB-01 D-07 zero-special-casing invariant; make test-mcp-selector runs and passes.</done>
</task>

<task type="auto">
  <name>Task 3: Create docs/MCP-SETUP.md and update docs/INSTALL.md</name>
  <files>docs/MCP-SETUP.md, docs/INSTALL.md</files>
  <read_first>
    - docs/INSTALL.md (existing structure — particularly the install.sh v4.5+ section starting around line 82)
    - .planning/phases/25-mcp-selector/25-CONTEXT.md (collision handling, OAuth handling, plaintext-on-disk caveat)
    - scripts/lib/mcp-catalog.json (the canonical 9-MCP list — derive the doc table from this)
    - .markdownlint.json (lint rules — MD040 enforced, MD031/032 enforced, MD026 forbids trailing punctuation in headings)
  </read_first>
  <behavior>
    - docs/MCP-SETUP.md is a new file passing markdownlint
    - docs/MCP-SETUP.md contains H1 title "MCP Setup", an intro paragraph, an H2 "Quick install" section with three install variants, an H2 "The 9 curated MCPs" with a markdown table, an H2 "Configuration file" with the 0600 mode rationale and plaintext-on-disk caveat, an H2 "Rotating to a secret manager" with the manual recipe, an H2 "Troubleshooting" section
    - docs/INSTALL.md gains a new H3 subsection "--mcps flag" inserted between "TUI controls" and "Backwards compatibility"
    - markdownlint passes for both files (npx markdownlint-cli docs/MCP-SETUP.md docs/INSTALL.md exits 0)
    - Every fenced code block has a language tag (MD040)
    - No headings end with punctuation (MD026)
  </behavior>
  <action>
Create the new file docs/MCP-SETUP.md. Use the structure below as a writing brief — replace placeholder text with the prose described:

H1 heading: "MCP Setup"

Intro paragraph: explain that scripts/install.sh --mcps opens a TUI catalog of nine curated MCP servers, prompts for required API keys, persists them to ~/.claude/mcp-config.env, and runs claude mcp add to register each MCP with the local Claude installation.

H2 "Quick install" section. Three fenced bash code blocks with language tag. First: interactive TUI catalog via "bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --mcps". Second: non-interactive via the same URL with "--mcps --yes" flag. Third: dry-run preview via "--mcps --dry-run". Each preceded by a one-line plain-prose description.

H2 "The 9 curated MCPs". Markdown table with columns Name, Description, "Required env vars". Nine rows, one per MCP. Pull values from scripts/lib/mcp-catalog.json:
- context7: Up-to-date library docs (React, Next.js, Tailwind, etc.) — CONTEXT7_API_KEY
- sentry: Error monitoring + issue triage — SENTRY_AUTH_TOKEN
- sequential-thinking: Structured step-by-step reasoning (zero-config) — none
- playwright: Browser automation + screenshot — none
- notion: Workspace pages + databases (OAuth) — OAuth flow
- magic: UI component generation (21st.dev) — MAGIC_API_KEY
- firecrawl: Website scraping + crawling — FIRECRAWL_API_KEY
- resend: Transactional email send — RESEND_API_KEY
- openrouter: Multi-model LLM routing — OPENROUTER_API_KEY

After the table, a one-paragraph note explaining that --yes skips OAuth-only MCPs (notion) because OAuth requires browser interaction; pass --yes --force to attempt those anyway.

H2 "Configuration file". Explain that secrets live at ~/.claude/mcp-config.env, mode 0600, owner-only readable, re-asserted after every write. Schema is plain KEY=value lines (no quotes), one per line. Show a 3-line text example fenced as "text" language. Then explain the collision prompt: re-running the wizard for a key already in the file prompts "[y/N] Overwrite KEY?" with default N preserving existing.

H3 "Plaintext-on-disk caveat" under the Configuration file H2. Explain that the file is plaintext on disk, mode 0600 protects against other-user reads on multi-user machines but root and backup tooling can still read it. Note this is the same posture as ~/.aws/credentials, ~/.npmrc, ~/.docker/config.json. Mention the rotation recipe below as the alternative.

H2 "Rotating to a secret manager". Numbered list (3 items) for the manual rotation recipe:

1. Move existing secrets via "mv ~/.claude/mcp-config.env ~/mcp-config.env.bak"
2. Configure your shell (~/.zshrc or ~/.bashrc) to load secrets from a secret manager into the environment before invoking claude. Show a fenced bash example using 1Password CLI: export CONTEXT7_API_KEY=$(op read 'op://Personal/context7/api_key') etc.
3. Re-run claude mcp add with the env vars now live in your shell. Skip the toolkit wizard for those MCPs going forward.

End with a one-line mention that automated wizard integration is tracked as MCP-FUT-01 (no link — the deferred-items registry lives in .planning/STATE.md).

H2 "Troubleshooting". Four bullet items:
- "claude CLI not found" — install Claude CLI from Anthropic docs and re-run; --mcps page renders read-only when CLI is absent
- OAuth flow failure — notion uses claude mcp add's built-in OAuth; copy redirect URL back to terminal if auto-open fails
- mcp-config.env mode incorrect — re-run the wizard; mcp_secrets_set re-asserts 0600 after every write
- is_mcp_installed reports installed but claude mcp list disagrees — toolkit parses the first column of claude mcp list output; file an issue if local Claude version emits different column order

CRITICAL markdownlint rules to satisfy:
- Every fenced code block must have a language tag (MD040). Use "bash" for shell, "text" for plain examples.
- Blank line BEFORE and AFTER every fenced code block (MD031).
- Blank line BEFORE and AFTER every list (MD032).
- No trailing punctuation in headings — no question marks, colons, periods, exclamation marks (MD026).
- Long lines are fine — MD013 is disabled per .markdownlint.json.

Update the existing file docs/INSTALL.md. Locate the install.sh (unified entry, v4.5+) section starting around line 82. The current H3 subsections are: Quick start, Flags, TUI controls, Backwards compatibility. Insert a NEW H3 subsection BETWEEN "TUI controls" and "Backwards compatibility":

H3 heading: "--mcps flag"

Body content:
- Opening paragraph: scripts/install.sh --mcps opens a separate TUI page that lists nine curated MCP servers (cross-reference docs/MCP-SETUP.md). Selecting an MCP triggers a per-MCP wizard that prompts for required API keys with hidden input via read -rs, persists them to ~/.claude/mcp-config.env (mode 0600), and invokes claude mcp add.
- Three fenced bash code blocks with the same three install variants from MCP-SETUP.md (interactive, --yes, --dry-run). Each preceded by a one-line description.
- Closing two paragraphs:
  - When the claude CLI is not on PATH, --mcps prints a banner and renders the catalog read-only — selecting MCPs has no effect. Install the CLI first, then re-run.
  - The components page and the MCPs page are mutually exclusive within a single invocation. To install components AND MCPs, run install.sh twice (once without --mcps, once with).

Same markdownlint rules apply.
  </action>
  <verify>
    <automated>test -f docs/MCP-SETUP.md && grep -q "^# MCP Setup$" docs/MCP-SETUP.md && grep -q "0600" docs/MCP-SETUP.md && grep -q "Rotating to a secret manager" docs/MCP-SETUP.md && grep -q "## The 9 curated MCPs" docs/MCP-SETUP.md && grep -q "### --mcps flag" docs/INSTALL.md && npx --yes markdownlint-cli docs/MCP-SETUP.md docs/INSTALL.md && make mdlint</automated>
  </verify>
  <done>docs/MCP-SETUP.md exists with H1 + 5 H2 sections (Quick install, The 9 curated MCPs, Configuration file, Rotating to a secret manager, Troubleshooting); docs/INSTALL.md gains the --mcps H3 subsection in the correct position; both pass markdownlint and the project make mdlint target.</done>
</task>

</tasks>

<verification>
- shellcheck -S warning scripts/tests/test-mcp-selector.sh — 0 warnings
- bash scripts/tests/test-mcp-selector.sh — exits 0, prints FAIL=0
- python3 scripts/validate-manifest.py — exit 0
- bash scripts/tests/test-update-libs.sh — exits 0 (LIB-01 D-07 invariant preserved)
- bash scripts/tests/test-bootstrap.sh — exits 0 (BACKCOMPAT-01 invariant preserved)
- bash scripts/tests/test-install-tui.sh — exits 0 (Phase 24 invariant preserved)
- make check — exits 0
- npx markdownlint-cli docs/MCP-SETUP.md docs/INSTALL.md — exit 0
</verification>

<success_criteria>
1. scripts/tests/test-mcp-selector.sh provides at least 12 (target 18) hermetic assertions covering MCP-01 (catalog), MCP-02 (three-state detection), MCP-04 (wizard), MCP-05 (this test file), MCP-SEC-01 (mode 0600), MCP-SEC-02 (collision prompt + KEY=value schema).
2. manifest.json files.libs lists scripts/lib/mcp.sh and scripts/lib/mcp-catalog.json in alpha position; smart-update auto-discovery via existing jq path keeps working — proven by test-update-libs.sh staying green.
3. Makefile Test 32 + standalone target + .PHONY entry land; CI step renamed Tests 21-32 with appended invocation.
4. docs/MCP-SETUP.md is the user-facing MCP install + secrets-rotation guide (MCP-SEC-02 doc requirement).
5. docs/INSTALL.md gains the --mcps H3 subsection.
6. make check passes; markdownlint clean for both docs.
7. test-bootstrap.sh + test-install-tui.sh remain green — Phase 24 BACKCOMPAT-01 invariant preserved.
</success_criteria>

<output>
After completion, create .planning/phases/25-mcp-selector/25-04-tests-manifest-and-docs-SUMMARY.md documenting:
- Final assertion count for test-mcp-selector.sh (target ≥12, expected ~18)
- The exact two-line insertion in manifest.json (alphabetical placement)
- Whether any unexpected lint errors surfaced in MCP-SETUP.md and how they were resolved
- A git diff summary line per file (e.g., "+18 -0 manifest.json", "+5 -1 .github/workflows/quality.yml")
- Confirmation that make check, test-bootstrap.sh, test-install-tui.sh, test-update-libs.sh all stayed green
</output>
