---
phase: 27
plan: "02"
type: execute
wave: 2
depends_on: ["27-01"]
files_modified:
  - scripts/validate-skills-desktop.sh
  - scripts/validate-marketplace.sh
  - Makefile
  - .github/workflows/quality.yml
autonomous: true
requirements:
  - MKT-03
  - DESK-02
  - DESK-04
must_haves:
  truths:
    - "Running `make validate-skills-desktop` scans every templates/skills-marketplace/<name>/SKILL.md and prints a per-skill PASS/FLAG verdict"
    - "Running `make validate-skills-desktop` exits 0 when ≥ 4 skills PASS the Desktop-safety heuristic, exits 1 otherwise (DESK-04 threshold)"
    - "Running `make validate-marketplace` invokes `claude plugin marketplace add ./` against the local repo when TK_HAS_CLAUDE_CLI=1; skips with a [skipped] notice (exit 0) when the env-var is unset"
    - "`make check` chain runs both validators (validate-skills-desktop unconditionally; validate-marketplace which is a no-op when claude CLI absent)"
    - "CI workflow `quality.yml` runs `make validate-skills-desktop` as a dedicated step in the validate-templates job"
    - "Heuristic for FLAG: SKILL.md contains either `(Read|Write|Bash|Grep|Edit|Task)\\(` OR `Use (the )?(Read|Bash|Write) tool` — anything else PASSes"
    - "validate-skills-desktop.sh writes a per-run artifact to .audit-skills-desktop.txt (gitignored) with the full PASS/FLAG table"
  artifacts:
    - path: "scripts/validate-skills-desktop.sh"
      provides: "Heuristic Desktop-compatibility scanner for SKILL.md files"
      min_lines: 60
      contains: "templates/skills-marketplace"
    - path: "scripts/validate-marketplace.sh"
      provides: "Wraps `claude plugin marketplace add ./` smoke; gated by TK_HAS_CLAUDE_CLI=1"
      min_lines: 30
      contains: "TK_HAS_CLAUDE_CLI"
    - path: "Makefile"
      provides: "validate-skills-desktop and validate-marketplace targets, both wired into check"
      contains: "validate-skills-desktop"
    - path: ".github/workflows/quality.yml"
      provides: "CI runs validate-skills-desktop on every push/PR to main"
      contains: "validate-skills-desktop"
  key_links:
    - from: "Makefile (check target)"
      to: "validate-skills-desktop"
      via: "Make dependency listed in `check:` target line"
      pattern: "check:.*validate-skills-desktop"
    - from: "scripts/validate-skills-desktop.sh"
      to: "templates/skills-marketplace/*/SKILL.md"
      via: "find + grep heuristic loop"
      pattern: "templates/skills-marketplace"
    - from: "scripts/validate-marketplace.sh"
      to: ".claude-plugin/marketplace.json"
      via: "claude plugin marketplace add ./ subprocess"
      pattern: "claude plugin marketplace add"
---

<objective>
Add two validators that gate Phase 27's marketplace surface:

1. **`scripts/validate-skills-desktop.sh`** — heuristic scan of every mirrored
   SKILL.md to identify which skills are Desktop-Code-tab compatible (PASS) vs
   Code-terminal-only (FLAG). The threshold is set by DESK-04: at least 4 skills
   must PASS or the script exits 1.
2. **`scripts/validate-marketplace.sh`** — wraps `claude plugin marketplace add ./`
   against the repo's `.claude-plugin/marketplace.json` (created in Plan 01) to
   smoke-test the structure. Gated behind `TK_HAS_CLAUDE_CLI=1` because CI
   runners do not have the `claude` CLI by default.

Both targets are wired into `make check`. CI's `quality.yml` adds a dedicated
`validate-skills-desktop` step (the marketplace target stays no-op in CI until
the env-var is set).

Heuristic correctness check (informational): the planning agent grep-sampled
`templates/skills-marketplace/*/SKILL.md` and found only 2 SKILL.md files
(`firecrawl`, `shadcn`) carrying `Bash(...)` patterns. The remaining 20 are
expected to PASS. The DESK-04 threshold of ≥ 4 PASS is far below that — the
gate is therefore green at the start and exists to catch FUTURE regressions
when new skills are added.

Purpose: fulfill MKT-03 (live marketplace smoke test gated on CLI presence),
DESK-02 (Desktop-safety scanner), and DESK-04 (CI threshold gate).

Output: 2 new shell scripts + 2 new Make targets + 1 new CI step.
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
@scripts/validate-commands.py
@scripts/validate-manifest.py
@Makefile
@.github/workflows/quality.yml

<interfaces>
<!-- Existing patterns the executor should follow exactly. -->

Makefile `check` target (current state, line 19 of Makefile):

```makefile
check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands cell-parity
	@echo "All checks passed!"
```

Plan 02 must extend this to include `validate-skills-desktop` (always) and
`validate-marketplace` (gated, no-op if env-var unset). Final form:

```makefile
check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands validate-skills-desktop validate-marketplace cell-parity
	@echo "All checks passed!"
```

Existing validator pattern (from Makefile validate-commands target, line 331):

```makefile
validate-commands:
	@echo "Validating commands/*.md for required headings (HARDEN-A-01)..."
	@python3 scripts/validate-commands.py
```

Plan 02 mirrors this style. Update `.PHONY` declaration on line 1 to include
the two new targets.

CI quality.yml current step (line 121-128 of .github/workflows/quality.yml):

```yaml
- name: Tests 21-33 — uninstall + banner suite + bootstrap + lib coverage + TUI orchestrator + MCP selector + Skills selector ...
  run: |
    bash scripts/tests/test-uninstall-dry-run.sh
    ...
- name: HARDEN-A-01 — validate commands/*.md required headings
  run: make validate-commands

- name: REL-02 — cell-parity (all 3 surfaces carry all 13 cell names)
  run: make cell-parity
```

Plan 02 inserts a new step BEFORE `cell-parity`:

```yaml
- name: DESK-02/DESK-04 — Skills Desktop-safety audit (≥4 PASS threshold)
  run: make validate-skills-desktop
```

Heuristic regex per CONTEXT.md "Validate-Skills-Desktop Gate":
- FLAG match: `(Read|Write|Bash|Grep|Edit|Task)\(` OR `Use (the )?(Read|Bash|Write) tool`
- PASS: no FLAG match in SKILL.md

Pre-verified counts (planning agent grep against current repo state):
- 2 SKILL.md files contain `Bash(...)` patterns: `firecrawl/SKILL.md`, `shadcn/SKILL.md`
- Expected PASS count: 20 (well above DESK-04 threshold of 4)

Existing project shell-script conventions (from CLAUDE.md / scripts/init-claude.sh):
- `set -euo pipefail` at the top
- Color helpers: `RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'`
- `${RED}Error:${NC}` prefix on user-facing errors
- `${GREEN}✓${NC}` on success lines
- Bash 3.2+ compatible (no `read -N`, no `declare -n`)

`.gitignore` should add `.audit-skills-desktop.txt` because it is a runtime artifact.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create scripts/validate-skills-desktop.sh — heuristic SKILL.md scanner with DESK-04 threshold gate</name>
  <files>
    scripts/validate-skills-desktop.sh,
    .gitignore
  </files>
  <read_first>
    - .planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md (Validate-Skills-Desktop Gate section)
    - templates/skills-marketplace/firecrawl/SKILL.md (sample FLAG candidate — first 30 lines)
    - templates/skills-marketplace/ai-models/SKILL.md (sample PASS candidate — first 30 lines)
    - scripts/validate-commands.py (style reference for validator output)
  </read_first>
  <action>
1. Create `scripts/validate-skills-desktop.sh` with this content:

   ```bash
   #!/bin/bash
   #
   # validate-skills-desktop.sh — DESK-02 + DESK-04
   # Scans every templates/skills-marketplace/<name>/SKILL.md for Code-only
   # tool-execution patterns. Skills without matches are PASS (Desktop-safe
   # instruction-only); skills with matches are FLAG (Code-terminal only).
   #
   # Threshold (DESK-04): at least 4 skills must PASS or the script exits 1.
   #
   # Usage: bash scripts/validate-skills-desktop.sh
   # Output: per-skill verdict to stdout + .audit-skills-desktop.txt artifact.

   set -euo pipefail

   RED='\033[0;31m'
   GREEN='\033[0;32m'
   YELLOW='\033[1;33m'
   BLUE='\033[0;34m'
   NC='\033[0m'

   THRESHOLD=4
   MIRROR_DIR="${TK_SKILLS_MIRROR:-templates/skills-marketplace}"
   ARTIFACT="${TK_SKILLS_AUDIT_FILE:-.audit-skills-desktop.txt}"

   if [ ! -d "$MIRROR_DIR" ]; then
       echo -e "${RED}Error:${NC} skills mirror dir not found: $MIRROR_DIR" >&2
       exit 1
   fi

   PASS_COUNT=0
   FLAG_COUNT=0
   PASS_NAMES=()
   FLAG_NAMES=()

   # Heuristic — extended grep for either tool call pattern OR English instruction.
   # FLAG_REGEX intentionally conservative: matches anything that suggests the
   # skill needs Claude Code's tool-execution layer.
   FLAG_REGEX='(Read|Write|Bash|Grep|Edit|Task)\(|Use (the )?(Read|Bash|Write) tool'

   # Iterate skills in alphabetical order (predictable output for diffing).
   while IFS= read -r skill_dir; do
       name=$(basename "$skill_dir")
       skill_md="$skill_dir/SKILL.md"
       if [ ! -f "$skill_md" ]; then
           continue
       fi
       if grep -E -q "$FLAG_REGEX" "$skill_md"; then
           FLAG_COUNT=$((FLAG_COUNT + 1))
           FLAG_NAMES+=("$name")
       else
           PASS_COUNT=$((PASS_COUNT + 1))
           PASS_NAMES+=("$name")
       fi
   done < <(find "$MIRROR_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

   # Build artifact + stdout in one go (artifact is plain text, stdout is colored).
   {
       echo "# Skills Desktop-safety audit"
       echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
       echo "# Mirror: $MIRROR_DIR"
       echo "# Threshold (DESK-04): >= $THRESHOLD PASS"
       echo ""
       echo "## PASS ($PASS_COUNT)"
       for n in "${PASS_NAMES[@]+"${PASS_NAMES[@]}"}"; do
           echo "  $n"
       done
       echo ""
       echo "## FLAG ($FLAG_COUNT)"
       for n in "${FLAG_NAMES[@]+"${FLAG_NAMES[@]}"}"; do
           echo "  $n"
       done
   } > "$ARTIFACT"

   echo -e "${BLUE}Skills Desktop-safety audit${NC}"
   echo ""
   echo -e "${GREEN}PASS ($PASS_COUNT)${NC}:"
   for n in "${PASS_NAMES[@]+"${PASS_NAMES[@]}"}"; do
       echo "  ${GREEN}✓${NC} $n"
   done
   echo ""
   echo -e "${YELLOW}FLAG ($FLAG_COUNT)${NC}:"
   for n in "${FLAG_NAMES[@]+"${FLAG_NAMES[@]}"}"; do
       echo "  ${YELLOW}⚠${NC} $n"
   done
   echo ""
   echo "Artifact: $ARTIFACT"
   echo ""

   if [ "$PASS_COUNT" -lt "$THRESHOLD" ]; then
       echo -e "${RED}✗${NC} DESK-04 gate failed: only $PASS_COUNT skill(s) PASS Desktop-safety (need >= $THRESHOLD)"
       exit 1
   fi

   echo -e "${GREEN}✓${NC} DESK-04 gate green: $PASS_COUNT skill(s) PASS (threshold: $THRESHOLD)"
   exit 0
   ```

2. Make it executable: `chmod +x scripts/validate-skills-desktop.sh`

3. Run it manually once to verify it produces the expected counts on the
   current 22-skill mirror:

   ```bash
   bash scripts/validate-skills-desktop.sh
   ```

   Expected output:
   - PASS count: 20 (anything ≥ 4 is acceptable for the threshold gate)
   - FLAG count: 2 (firecrawl, shadcn)
   - Exit code: 0
   - Artifact created: `.audit-skills-desktop.txt`

4. Add `.audit-skills-desktop.txt` to `.gitignore` (artifact must not be
   committed). Append the line to existing `.gitignore`:

   ```text
   .audit-skills-desktop.txt
   ```

5. Validate with shellcheck: `shellcheck -S warning scripts/validate-skills-desktop.sh`
   — must produce zero warnings. If shellcheck flags `${arr[@]+"${arr[@]}"}` as
   SC2068, suppress with `# shellcheck disable=SC2068` immediately above the line.

6. Commit: `git add scripts/validate-skills-desktop.sh .gitignore && git commit -m "feat(27): add validate-skills-desktop.sh DESK-04 gate (DESK-02, DESK-04)"`
  </action>
  <verify>
    <automated>
chmod +x scripts/validate-skills-desktop.sh \
  && shellcheck -S warning scripts/validate-skills-desktop.sh \
  && bash scripts/validate-skills-desktop.sh > /tmp/audit.out 2>&1 \
  && PASS=$(grep -E '^PASS \(' /tmp/audit.out | sed 's/.*(\([0-9]*\)).*/\1/') \
  && FLAG=$(grep -E '^FLAG \(' /tmp/audit.out | sed 's/.*(\([0-9]*\)).*/\1/') \
  && test "$PASS" -ge 4 \
  && test "$FLAG" -ge 0 \
  && test -f .audit-skills-desktop.txt \
  && grep -q "DESK-04 gate green" /tmp/audit.out \
  && grep -q "^.audit-skills-desktop.txt$" .gitignore \
  && echo "PASS: validate-skills-desktop.sh works, gate green ($PASS PASS / $FLAG FLAG)"
    </automated>
  </verify>
  <done>
    - `scripts/validate-skills-desktop.sh` exists, is executable, and exits 0 against the current 22-skill mirror with PASS_COUNT ≥ 4
    - Output artifact `.audit-skills-desktop.txt` is created on every run
    - `.audit-skills-desktop.txt` is in `.gitignore`
    - `shellcheck -S warning` produces zero warnings
    - Threshold gate verbiage `DESK-04 gate green` appears on stdout
  </done>
  <acceptance_criteria>
    - `bash scripts/validate-skills-desktop.sh` exits 0 against the current repo state
    - Output contains `PASS (N)` line where N ≥ 4
    - File `.audit-skills-desktop.txt` is created with `## PASS` + `## FLAG` sections
    - `.gitignore` has a line `.audit-skills-desktop.txt` (or matching pattern that excludes it from `git status --porcelain`)
    - `shellcheck -S warning scripts/validate-skills-desktop.sh` returns exit 0
    - Manual override test: `TK_SKILLS_MIRROR=/nonexistent bash scripts/validate-skills-desktop.sh` exits non-zero with `Error: skills mirror dir not found`
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: Create scripts/validate-marketplace.sh + wire both validators into Makefile + CI</name>
  <files>
    scripts/validate-marketplace.sh,
    Makefile,
    .github/workflows/quality.yml
  </files>
  <read_first>
    - .planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md (Make Targets + CI Wiring section)
    - .claude-plugin/marketplace.json (created by Plan 01 — confirm exists)
    - Makefile (lines 1, 19, 320-355 — .PHONY declaration, check target, validate-commands target)
    - .github/workflows/quality.yml (lines 121-135 — Tests step + validate-commands step + cell-parity step)
  </read_first>
  <action>
1. Create `scripts/validate-marketplace.sh`:

   ```bash
   #!/bin/bash
   #
   # validate-marketplace.sh — MKT-03
   # Wraps `claude plugin marketplace add ./` smoke against the local repo.
   # Gated by TK_HAS_CLAUDE_CLI=1 because CI runners do not ship `claude`.
   # When the env-var is unset, this script prints a [skipped] notice and exits 0
   # so it can be a member of `make check` without breaking CI.
   #
   # Usage:
   #   TK_HAS_CLAUDE_CLI=1 bash scripts/validate-marketplace.sh   # full smoke
   #   bash scripts/validate-marketplace.sh                       # skip (CI default)

   set -euo pipefail

   RED='\033[0;31m'
   GREEN='\033[0;32m'
   YELLOW='\033[1;33m'
   BLUE='\033[0;34m'
   NC='\033[0m'

   if [ "${TK_HAS_CLAUDE_CLI:-0}" != "1" ]; then
       echo -e "${YELLOW}[skipped]${NC} validate-marketplace: TK_HAS_CLAUDE_CLI not set"
       echo "  Set TK_HAS_CLAUDE_CLI=1 and ensure 'claude' is on PATH to run the smoke."
       exit 0
   fi

   if ! command -v claude >/dev/null 2>&1; then
       echo -e "${RED}Error:${NC} TK_HAS_CLAUDE_CLI=1 but 'claude' not found on PATH" >&2
       exit 1
   fi

   if [ ! -f ".claude-plugin/marketplace.json" ]; then
       echo -e "${RED}Error:${NC} .claude-plugin/marketplace.json not found at $(pwd)" >&2
       echo "  Run from repo root (where .claude-plugin/ lives)." >&2
       exit 1
   fi

   # Validate marketplace JSON before invoking claude (catch schema breaks early).
   if ! python3 -c "import json,sys; json.load(open('.claude-plugin/marketplace.json'))" >/dev/null 2>&1; then
       echo -e "${RED}Error:${NC} .claude-plugin/marketplace.json is not valid JSON" >&2
       exit 1
   fi

   echo -e "${BLUE}Validating marketplace via claude CLI...${NC}"
   echo ""

   # Smoke: add the marketplace from the local repo. The CLI prints discovered plugins.
   if ! claude plugin marketplace add ./ 2>&1 | tee /tmp/tk-marketplace-out.$$; then
       echo -e "${RED}✗${NC} claude plugin marketplace add ./ failed"
       rm -f /tmp/tk-marketplace-out.$$
       exit 1
   fi

   # Assert all 3 sub-plugins are mentioned in the CLI output.
   MISSING=0
   for plugin in tk-skills tk-commands tk-framework-rules; do
       if ! grep -qF "$plugin" /tmp/tk-marketplace-out.$$; then
           echo -e "${RED}✗${NC} sub-plugin not discovered by CLI: $plugin"
           MISSING=$((MISSING + 1))
       fi
   done
   rm -f /tmp/tk-marketplace-out.$$

   if [ "$MISSING" -gt 0 ]; then
       echo -e "${RED}✗${NC} $MISSING sub-plugin(s) missing from marketplace add output"
       exit 1
   fi

   echo ""
   echo -e "${GREEN}✓${NC} MKT-03 smoke green: 3 sub-plugins discovered"
   exit 0
   ```

2. Make executable: `chmod +x scripts/validate-marketplace.sh`

3. Sanity-test the no-op path (CI behavior): `bash scripts/validate-marketplace.sh`
   should print the `[skipped]` notice and exit 0.

4. Edit `Makefile`:

   a. Update line 1 `.PHONY` declaration to include `validate-skills-desktop`
      and `validate-marketplace`. Append both names to the existing list, e.g.:

      ```makefile
      .PHONY: help check check-full lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands test-matrix-bats cell-parity clean install test-update-libs test-uninstall-keep-state test-install-tui test-mcp-selector test-install-skills sync-skills-mirror validate-skills-desktop validate-marketplace
      ```

   b. Update the `check:` target (currently line 19) to include both new targets
      BEFORE `cell-parity`:

      ```makefile
      check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands validate-skills-desktop validate-marketplace cell-parity
      	@echo "All checks passed!"
      ```

   c. Add two new targets near the existing `validate-commands` target
      (around line 331). Insert AFTER the `validate-commands` block:

      ```makefile
      # DESK-02 + DESK-04: skills Desktop-safety heuristic gate (>= 4 PASS required).
      validate-skills-desktop:
      	@echo "Running skills Desktop-safety audit (DESK-02, DESK-04)..."
      	@bash scripts/validate-skills-desktop.sh

      # MKT-03: live marketplace smoke (gated by TK_HAS_CLAUDE_CLI=1; CI default = skip).
      validate-marketplace:
      	@echo "Running marketplace smoke (MKT-03; gated by TK_HAS_CLAUDE_CLI)..."
      	@bash scripts/validate-marketplace.sh
      ```

5. Edit `.github/workflows/quality.yml` to add a dedicated CI step for
   validate-skills-desktop. Insert AFTER the `Tests 21-33 ...` step and BEFORE
   the `HARDEN-A-01` step (around line 130):

   ```yaml
       - name: DESK-02/DESK-04 — Skills Desktop-safety audit (>= 4 PASS threshold)
         run: make validate-skills-desktop
   ```

   Do NOT add a `validate-marketplace` CI step — it would always skip in CI (no
   `claude` CLI). The make target stays in the chain so local maintainer runs
   with `TK_HAS_CLAUDE_CLI=1` exercise it.

6. Verify the entire chain still passes:

   ```bash
   make check
   ```

   Expected: exits 0 with no errors.

7. Verify YAML is still valid:

   ```bash
   python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"
   ```

   Must exit 0.

8. Commit: `git add scripts/validate-marketplace.sh Makefile .github/workflows/quality.yml && git commit -m "feat(27): wire validate-marketplace + validate-skills-desktop into make check + CI (MKT-03, DESK-02, DESK-04)"`
  </action>
  <verify>
    <automated>
chmod +x scripts/validate-marketplace.sh \
  && shellcheck -S warning scripts/validate-marketplace.sh \
  && bash scripts/validate-marketplace.sh 2>&1 | grep -q '\[skipped\]' \
  && grep -q 'validate-skills-desktop' Makefile \
  && grep -q 'validate-marketplace' Makefile \
  && grep -q '^check: .*validate-skills-desktop.*validate-marketplace' Makefile \
  && grep -q 'validate-skills-desktop' .github/workflows/quality.yml \
  && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))" \
  && make validate-skills-desktop > /tmp/vsd.out 2>&1 \
  && grep -q 'DESK-04 gate green' /tmp/vsd.out \
  && make validate-marketplace > /tmp/vm.out 2>&1 \
  && grep -q '\[skipped\]' /tmp/vm.out \
  && make check > /tmp/check.out 2>&1 \
  && grep -q 'All checks passed' /tmp/check.out \
  && echo "PASS: validators wired, make check still green"
    </automated>
  </verify>
  <done>
    - `scripts/validate-marketplace.sh` exists, executable, exits 0 with `[skipped]` when TK_HAS_CLAUDE_CLI not set
    - Makefile `.PHONY` updated with both new target names
    - Makefile `check:` target includes `validate-skills-desktop validate-marketplace` before `cell-parity`
    - Two new Make targets defined in Makefile, each running its respective shell script
    - `.github/workflows/quality.yml` has a new step `DESK-02/DESK-04 — Skills Desktop-safety audit` running `make validate-skills-desktop`
    - `make check` passes end-to-end (existing checks + new validators)
    - `python3 -c "import yaml; yaml.safe_load(...)"` exits 0 against the modified workflow file
  </done>
  <acceptance_criteria>
    - `bash scripts/validate-marketplace.sh` exits 0 with `[skipped]` notice when `TK_HAS_CLAUDE_CLI` is unset
    - `make validate-skills-desktop` runs and exits 0 (against current 22-skill mirror with PASS=20, FLAG=2)
    - `make validate-marketplace` runs and exits 0 with skip notice
    - `make check` runs the full chain (existing 7 targets + 2 new + cell-parity) and exits 0 with `All checks passed!`
    - `grep -c 'validate-skills-desktop' Makefile` returns ≥ 3 (target name in .PHONY + check chain + target definition)
    - `grep 'validate-skills-desktop' .github/workflows/quality.yml` returns at least 1 match
    - YAML parse: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` exits 0
    - Shellcheck: `shellcheck -S warning scripts/validate-marketplace.sh` exits 0
  </acceptance_criteria>
</task>

</tasks>

<verification>
After both tasks:

1. Two new shell scripts in `scripts/` that pass shellcheck-warning.
2. Makefile carries both targets in `.PHONY` and in the `check` chain.
3. CI workflow runs `make validate-skills-desktop` as a dedicated step.
4. Repo's `.audit-skills-desktop.txt` is gitignored (no untracked-file noise).
5. `make check` passes end-to-end.
6. Sample run of `make validate-skills-desktop` reports PASS=20, FLAG=2 (firecrawl, shadcn).

Run end-to-end gate: `make check` — must exit 0 with `All checks passed!`.
</verification>

<success_criteria>
- `scripts/validate-skills-desktop.sh` exists, executable, performs the documented heuristic, exits 0 when ≥ 4 skills PASS, exits 1 otherwise (DESK-02, DESK-04)
- `scripts/validate-marketplace.sh` exists, executable, runs `claude plugin marketplace add ./` only when `TK_HAS_CLAUDE_CLI=1`, no-op skip otherwise (MKT-03)
- Both targets registered in Makefile `.PHONY` and the `check` chain
- CI workflow runs `validate-skills-desktop` as a dedicated step
- `make check` continues to pass
- Skills audit artifact (`.audit-skills-desktop.txt`) is gitignored
- All shellcheck-warning gates pass on both new scripts
</success_criteria>

<output>
After completion, create `.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-02-validators-and-make-wiring-SUMMARY.md` with:

- `requirements_addressed: [MKT-03, DESK-02, DESK-04]`
- `audit_results`: PASS_COUNT, FLAG_COUNT, FLAG_NAMES at time of plan completion (so future regressions are visible in the diff)
- `make check exit code` after change
- Note: marketplace smoke (`TK_HAS_CLAUDE_CLI=1 make validate-marketplace`) needs maintainer run — record whether smoke was exercised locally or deferred
</output>
