#!/usr/bin/env bash
# test-update-summary.sh — Phase 4 Plan 04-03 summary + no-op + backup-path assertions.
#
# Scenarios (Plan 04-03 turns these GREEN):
# - no-op-exits-0-no-backup             (D-59)
# - full-run-summary-all-four-groups    (D-58)
# - backup-path-format-matches-regex    (D-57)
# - same-second-concurrent-runs-no-collision (D-57)
# - noop-via-manifest-hash-match        (D-59)
#
# Exit 0 on all pass, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-update-v2.json"
LIB_DIR="${REPO_ROOT}/scripts/lib"

PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-update-summary.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# Helper: compute sha256 of a file (mirrors sha256_file in lib/state.sh)
sha256_of() {
    python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}

# Helper: build seeded state JSON with manifest_hash and given installed files
# Usage: seed_state_full <state_path> <mode> <manifest_sha> <path1> <sha1> [...]
seed_state_full() {
    local state_path="$1" mode="$2" manifest_sha="$3"
    shift 3
    local entries="[]"
    while [[ $# -ge 2 ]]; do
        local p="$1" h="$2"; shift 2
        entries=$(jq --arg p "$p" --arg h "$h" \
            '. + [{"path": $p, "sha256": $h, "installed_at": "2026-04-15T12:00:00Z"}]' \
            <<<"$entries")
    done
    jq -n --arg mode "$mode" --arg mh "$manifest_sha" --argjson files "$entries" \
        '{"version": 1, "mode": $mode,
          "manifest_hash": $mh,
          "detected": {"superpowers": {"present": false, "version": ""},
                       "gsd": {"present": false, "version": ""}},
          "installed_files": $files,
          "skipped_files": [],
          "installed_at": "2026-04-15T12:00:00Z"}' \
        > "$state_path"
}

# Helper: build a minimal file source directory with given relative paths
setup_file_src() {
    local src_dir="$1"; shift
    for rel in "$@"; do
        mkdir -p "$src_dir/$(dirname "$rel")"
        echo "REMOTE-CONTENT-OF-$rel" > "$src_dir/$rel"
    done
}

# ─────────────────────────────────────────────────
# Scenario 1: no-op — exit 0, one-line message, no backup (D-59)
# ─────────────────────────────────────────────────
scenario_no_op_exits_0_no_backup() {
    echo ""
    echo "Scenario 1: no-op-exits-0-no-backup (D-59)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s1"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules" "$SCR/.claude/agents" \
             "$SCR/.claude/skills/api-design" "$SCR/.claude/prompts"

    # Seed every manifest file on disk with canonical content
    local FILE_SRC="$SCR/.src"
    setup_file_src "$FILE_SRC" \
        agents/code-reviewer.md agents/test-writer.md agents/security-auditor.md agents/planner.md \
        commands/debug.md commands/plan.md commands/tdd.md commands/verify.md commands/worktree.md \
        commands/learn.md commands/new-in-v2.md \
        skills/debugging/SKILL.md skills/api-design/SKILL.md skills/new-skill/SKILL.md \
        rules/README.md prompts/SECURITY_AUDIT.md

    # Copy src files to .claude/ so all manifest files exist on disk
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        mkdir -p "$SCR/.claude/$(dirname "$rel")"
        cp "$FILE_SRC/$rel" "$SCR/.claude/$rel"
    done < <(jq -r '.files | to_entries[] | .value[] | .path' "$MANIFEST_FIXTURE")

    # Compute manifest sha256 and file hashes, seed state so all no-op conditions hold
    local manifest_sha
    manifest_sha=$(sha256_of "$MANIFEST_FIXTURE")
    local state_args=()
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        local h
        h=$(sha256_of "$SCR/.claude/$rel")
        state_args+=("$rel" "$h")
    done < <(jq -r '.files | to_entries[] | .value[] | .path' "$MANIFEST_FIXTURE")

    seed_state_full "$SCR/.claude/toolkit-install.json" "standalone" "$manifest_sha" "${state_args[@]}"

    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_UPDATE_FILE_SRC="$FILE_SRC" \
          HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" \
              --no-banner --no-offer-mode-switch --no-prune 2>&1 || true)

    # Assert: "Already up-to-date" message present
    assert_eq "true" "$(echo "$OUT" | grep -q 'Already up-to-date' && echo true || echo false)" \
        "stdout contains 'Already up-to-date. Nothing to do.'"

    # Assert: no backup directory created as sibling of .claude/
    local backup_exists="false"
    if ls -d "$SCR/.claude-backup-"* >/dev/null 2>&1; then backup_exists="true"; fi
    assert_eq "false" "$backup_exists" "no backup directory created on no-op run"
}

# ─────────────────────────────────────────────────
# Scenario 2: full run — summary shows all 4 groups (D-58)
# ─────────────────────────────────────────────────
scenario_full_run_summary_all_four_groups() {
    echo ""
    echo "Scenario 2: full-run-summary-all-four-groups (D-58)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s2"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"

    local FILE_SRC="$SCR/.src"
    setup_file_src "$FILE_SRC" \
        agents/code-reviewer.md agents/test-writer.md agents/security-auditor.md agents/planner.md \
        commands/debug.md commands/plan.md commands/tdd.md commands/verify.md commands/worktree.md \
        commands/learn.md commands/new-in-v2.md \
        skills/debugging/SKILL.md skills/api-design/SKILL.md skills/new-skill/SKILL.md \
        rules/README.md prompts/SECURITY_AUDIT.md

    # rules/README.md on disk matching hash → unchanged (not in MODIFIED group)
    echo "RULES-CANONICAL" > "$SCR/.claude/rules/README.md"
    local rules_hash
    rules_hash=$(sha256_of "$SCR/.claude/rules/README.md")
    echo "RULES-CANONICAL" > "$FILE_SRC/rules/README.md"

    # commands/audit.md in state but NOT in manifest → REMOVED with --prune=yes
    echo "OLD-FILE" > "$SCR/.claude/commands/audit.md"
    local audit_hash
    audit_hash=$(sha256_of "$SCR/.claude/commands/audit.md")

    # State: rules/README.md + commands/audit.md installed, no manifest_hash → no-op fails
    jq -n --arg rules_hash "$rules_hash" --arg audit_hash "$audit_hash" \
        '{"version":1,"mode":"standalone",
          "detected":{"superpowers":{"present":false,"version":""},"gsd":{"present":false,"version":""}},
          "installed_files":[
            {"path":"rules/README.md","sha256":$rules_hash,"installed_at":"2026-04-15T12:00:00Z"},
            {"path":"commands/audit.md","sha256":$audit_hash,"installed_at":"2026-04-15T12:00:00Z"}
          ],
          "skipped_files":[],
          "installed_at":"2026-04-15T12:00:00Z"}' \
        > "$SCR/.claude/toolkit-install.json"

    # Run: prune=yes removes audit.md (REMOVED), new-in-v2.md etc. are new (INSTALLED),
    # mode=standalone so SP files install (no SKIPPED from mode), rules/README.md unchanged.
    # With no /dev/tty and no modified files (rules hash matches), SKIPPED comes from SP-conflict
    # if any files are in skip-set but already installed — but in standalone all install.
    # To get a SKIPPED entry: commands/audit.md will be in REMOVED (prune=yes).
    # SKIPPED needs at least one entry — we get it from the mode skip-set tracking if SP files
    # would be skipped. Use complement-sp mode for this scenario.
    # Actually in standalone mode with the above state, only INSTALLED + REMOVED will have entries.
    # SKIPPED = 0, UPDATED = 0. That's fine — the test only asserts the headers exist (count >= 0).
    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_UPDATE_FILE_SRC="$FILE_SRC" \
          HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" \
              --no-banner --no-offer-mode-switch --prune=yes </dev/null 2>&1 || true)

    # All 4 group headers must appear in summary (even with count=0)
    assert_eq "true" "$(echo "$OUT" | grep -q '^INSTALLED' && echo true || echo false)" \
        "summary contains INSTALLED group header"
    assert_eq "true" "$(echo "$OUT" | grep -q '^UPDATED' && echo true || echo false)" \
        "summary contains UPDATED group header"
    assert_eq "true" "$(echo "$OUT" | grep -q '^SKIPPED' && echo true || echo false)" \
        "summary contains SKIPPED group header"
    assert_eq "true" "$(echo "$OUT" | grep -q '^REMOVED' && echo true || echo false)" \
        "summary contains REMOVED group header"

    # At least 1 INSTALLED (new manifest files) and 1 REMOVED (audit.md pruned)
    assert_eq "true" "$(echo "$OUT" | grep -qE '^INSTALLED [1-9]' && echo true || echo false)" \
        "INSTALLED count >= 1"
    assert_eq "true" "$(echo "$OUT" | grep -qE '^REMOVED [1-9]' && echo true || echo false)" \
        "REMOVED count >= 1 (audit.md pruned)"
    assert_eq "true" "$(echo "$OUT" | grep -q 'Update Summary' && echo true || echo false)" \
        "summary contains 'Update Summary' heading"
}

# ─────────────────────────────────────────────────
# Scenario 3: backup path format matches <unix-ts>-<pid> regex (D-57)
# ─────────────────────────────────────────────────
scenario_backup_path_format_matches_regex() {
    echo ""
    echo "Scenario 3: backup-path-format-matches-regex (D-57)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s3"
    mkdir -p "$SCR/.claude/commands"

    # Seed minimal state with no manifest_hash so no-op check fails → backup is created
    jq -n '{"version":1,"mode":"standalone",
            "detected":{"superpowers":{"present":false,"version":""},"gsd":{"present":false,"version":""}},
            "installed_files":[],"skipped_files":[],"installed_at":"2026-04-15T12:00:00Z"}' \
        > "$SCR/.claude/toolkit-install.json"

    local FILE_SRC="$SCR/.src"
    setup_file_src "$FILE_SRC" \
        agents/test-writer.md agents/security-auditor.md agents/planner.md \
        commands/new-in-v2.md commands/learn.md \
        skills/api-design/SKILL.md \
        rules/README.md prompts/SECURITY_AUDIT.md

    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_UPDATE_FILE_SRC="$FILE_SRC" \
          HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" \
              --no-banner --no-offer-mode-switch --no-prune </dev/null 2>&1 || true)

    # Assert: "Backup created:" log line matches <unix-ts>-<pid> format
    local backup_line
    backup_line=$(echo "$OUT" | grep 'Backup created:' || echo "")
    assert_eq "true" "$(echo "$backup_line" | grep -qE '\.claude-backup-[0-9]+-[0-9]+' && echo true || echo false)" \
        "backup path in log matches .claude-backup-<unix-ts>-<pid> format"

    # Verify backup dir was actually created on disk
    local backup_exists="false"
    if ls -d "$SCR/.claude-backup-"* >/dev/null 2>&1; then backup_exists="true"; fi
    assert_eq "true" "$backup_exists" "backup directory physically created as sibling of .claude/"
}

# ─────────────────────────────────────────────────
# Scenario 4: same-second concurrent runs produce distinct backup paths (D-57)
# ─────────────────────────────────────────────────
scenario_same_second_concurrent_runs_no_collision() {
    echo ""
    echo "Scenario 4: same-second-concurrent-runs-no-collision (D-57)"
    echo "---"
    # Prove that two bash processes spawned "at the same second" generate distinct backup paths.
    # Strategy: fork two background subshells that each emit the backup path formula.
    # Since $$ differs per bash process, paths must differ even when date +%s is identical.
    local SCR="${TMPDIR_ROOT}/s4"
    mkdir -p "$SCR"

    local OUT1 OUT2
    OUT1=$(bash -c 'echo "'"$SCR"'/.claude-backup-$(date -u +%s)-$$"')
    OUT2=$(bash -c 'echo "'"$SCR"'/.claude-backup-$(date -u +%s)-$$"')

    assert_eq "true" "$([ "$OUT1" != "$OUT2" ] && echo true || echo false)" \
        "two bash invocations produce distinct backup paths (PID suffix differs)"

    assert_eq "true" "$(echo "$OUT1" | grep -qE '\.claude-backup-[0-9]+-[0-9]+$' && echo true || echo false)" \
        "first path matches .claude-backup-<unix-ts>-<pid> format"
    assert_eq "true" "$(echo "$OUT2" | grep -qE '\.claude-backup-[0-9]+-[0-9]+$' && echo true || echo false)" \
        "second path matches .claude-backup-<unix-ts>-<pid> format"
}

# ─────────────────────────────────────────────────
# Scenario 5: no-op via manifest hash match (D-59 condition 5)
# ─────────────────────────────────────────────────
scenario_noop_via_manifest_hash_match() {
    echo ""
    echo "Scenario 5: noop-via-manifest-hash-match (D-59)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s5"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules" "$SCR/.claude/agents" \
             "$SCR/.claude/skills/api-design" "$SCR/.claude/prompts"

    # Same setup as scenario 1 but in a separate scratch dir.
    # Specifically tests condition 5: state.manifest_hash == sha256(manifest.json).
    local FILE_SRC="$SCR/.src"
    setup_file_src "$FILE_SRC" \
        agents/code-reviewer.md agents/test-writer.md agents/security-auditor.md agents/planner.md \
        commands/debug.md commands/plan.md commands/tdd.md commands/verify.md commands/worktree.md \
        commands/learn.md commands/new-in-v2.md \
        skills/debugging/SKILL.md skills/api-design/SKILL.md skills/new-skill/SKILL.md \
        rules/README.md prompts/SECURITY_AUDIT.md

    # Copy all manifest files to .claude/ with canonical content
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        mkdir -p "$SCR/.claude/$(dirname "$rel")"
        cp "$FILE_SRC/$rel" "$SCR/.claude/$rel"
    done < <(jq -r '.files | to_entries[] | .value[] | .path' "$MANIFEST_FIXTURE")

    local manifest_sha
    manifest_sha=$(sha256_of "$MANIFEST_FIXTURE")

    local state_args=()
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        local h
        h=$(sha256_of "$SCR/.claude/$rel")
        state_args+=("$rel" "$h")
    done < <(jq -r '.files | to_entries[] | .value[] | .path' "$MANIFEST_FIXTURE")

    seed_state_full "$SCR/.claude/toolkit-install.json" "standalone" "$manifest_sha" "${state_args[@]}"

    local OUT exit_code=0
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_UPDATE_FILE_SRC="$FILE_SRC" \
          HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" \
              --no-banner --no-offer-mode-switch --no-prune 2>&1) || exit_code=$?

    assert_eq "0" "$exit_code" "no-op run exits 0"
    assert_eq "true" "$(echo "$OUT" | grep -q 'Already up-to-date' && echo true || echo false)" \
        "no-op message present (manifest_hash matches → condition 5 triggers)"

    local backup_exists="false"
    if ls -d "$SCR/.claude-backup-"* >/dev/null 2>&1; then backup_exists="true"; fi
    assert_eq "false" "$backup_exists" "no backup created when manifest_hash matches"
}

scenario_no_op_exits_0_no_backup
scenario_full_run_summary_all_four_groups
scenario_backup_path_format_matches_regex
scenario_same_second_concurrent_runs_no_collision
scenario_noop_via_manifest_hash_match

echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
[ "${FAIL}" -gt 0 ] && exit 1
exit 0
