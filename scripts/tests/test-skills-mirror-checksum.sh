#!/bin/bash
# Test: scripts/lib/skill-checksum.sh + sync-skills-mirror.sh schema
#
# Verifies:
#   1. skill-checksum.sh produces deterministic 64-hex output for a fixture dir
#   2. Identical dirs produce identical hashes (idempotent)
#   3. Different content produces different hashes
#   4. .DS_Store + dotfiles are ignored
#   5. sync-skills-mirror.sh --help exits 0 and shows usage
#   6. sync-skills-mirror.sh --check with no upstream changes hits the
#      "no-upstream-found" branch for memo-skill (exit 0)
#   7. generate-skills-catalog.sh writes valid JSON matching manifest skills_pins
#   8. validate-manifest.py catches sha256 drift
#   9. validate-manifest.py catches catalog drift
#  10. --normalize: trailing whitespace + CRLF + extra blank lines → same hash
#  11. --normalize: real content change still produces different hash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "PASS: $*"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $*" >&2; FAIL=$((FAIL+1)); }

CHECKSUM="${REPO_ROOT}/scripts/lib/skill-checksum.sh"
SYNC="${REPO_ROOT}/scripts/sync-skills-mirror.sh"
GEN="${REPO_ROOT}/scripts/generate-skills-catalog.sh"
VALIDATE="${REPO_ROOT}/scripts/validate-manifest.py"
MANIFEST="${REPO_ROOT}/manifest.json"
CATALOG="${REPO_ROOT}/templates/skills-catalog.json"

# Working sandbox under cwd (safety-net blocks rm -rf /tmp paths).
SANDBOX="${REPO_ROOT}/test_sandbox_$$"
mkdir -p "$SANDBOX"
trap 'rm -rf "$SANDBOX"' EXIT

# ─────────────────────────────────────────────────
# 1. Deterministic 64-hex output
# ─────────────────────────────────────────────────
mkdir -p "$SANDBOX/fixture1"
echo "hello" > "$SANDBOX/fixture1/a.md"
echo "world" > "$SANDBOX/fixture1/b.md"
sha=$(bash "$CHECKSUM" "$SANDBOX/fixture1")
if [[ "$sha" =~ ^[0-9a-f]{64}$ ]]; then
    pass "checksum produces 64-hex"
else
    fail "checksum format: got '$sha'"
fi

# ─────────────────────────────────────────────────
# 2. Idempotent: same input → same hash
# ─────────────────────────────────────────────────
sha2=$(bash "$CHECKSUM" "$SANDBOX/fixture1")
if [[ "$sha" == "$sha2" ]]; then
    pass "checksum idempotent across runs"
else
    fail "checksum not idempotent: $sha vs $sha2"
fi

# ─────────────────────────────────────────────────
# 3. Different content → different hash
# ─────────────────────────────────────────────────
mkdir -p "$SANDBOX/fixture2"
echo "hello" > "$SANDBOX/fixture2/a.md"
echo "WORLD" > "$SANDBOX/fixture2/b.md"   # different
sha3=$(bash "$CHECKSUM" "$SANDBOX/fixture2")
if [[ "$sha" != "$sha3" ]]; then
    pass "different content produces different hash"
else
    fail "checksum collision on different content"
fi

# ─────────────────────────────────────────────────
# 4. .DS_Store ignored
# ─────────────────────────────────────────────────
mkdir -p "$SANDBOX/fixture3"
echo "hello" > "$SANDBOX/fixture3/a.md"
echo "world" > "$SANDBOX/fixture3/b.md"
sha_before=$(bash "$CHECKSUM" "$SANDBOX/fixture3")
echo "junk" > "$SANDBOX/fixture3/.DS_Store"
echo "more junk" > "$SANDBOX/fixture3/.hidden"
sha_after=$(bash "$CHECKSUM" "$SANDBOX/fixture3")
if [[ "$sha_before" == "$sha_after" ]]; then
    pass ".DS_Store + dotfiles ignored"
else
    fail "dotfiles affected hash: before=$sha_before after=$sha_after"
fi

# ─────────────────────────────────────────────────
# 5. sync-skills-mirror.sh --help
# ─────────────────────────────────────────────────
help_out=$(bash "$SYNC" --help 2>&1)
help_rc=$?
if [[ "$help_rc" -eq 0 ]] && echo "$help_out" | grep -q "MODES:"; then
    pass "sync --help exit 0 + shows usage"
else
    fail "sync --help rc=$help_rc"
fi

# ─────────────────────────────────────────────────
# 6. sync --check memo-skill (no-upstream branch)
# ─────────────────────────────────────────────────
out=$(bash "$SYNC" --check memo-skill 2>&1)
rc=$?
if [[ "$rc" -eq 0 ]] && echo "$out" | grep -qF "no-upstream-found (mirror sha intact)"; then
    pass "sync --check memo-skill: no-upstream branch exit 0"
else
    fail "sync --check memo-skill: rc=$rc out=$out"
fi

# ─────────────────────────────────────────────────
# 7. generate-skills-catalog.sh
# ─────────────────────────────────────────────────
# Snapshot existing catalog content; regenerate; compare counts.
expected_count=$(jq '[.skills_pins | to_entries[] | select(.value._status=="active" and .value.repo != null and .value.commit != null)] | length' "$MANIFEST")
bash "$GEN" >/dev/null
got_count=$(jq '.skills_count' "$CATALOG")
if [[ "$got_count" == "$expected_count" ]]; then
    pass "catalog regen: $got_count skills (expected $expected_count)"
else
    fail "catalog skills_count mismatch: got=$got_count expected=$expected_count"
fi

# ─────────────────────────────────────────────────
# 8. validate-manifest catches sha256 drift
# ─────────────────────────────────────────────────
backup=$(cat "$MANIFEST")
python3 - "$MANIFEST" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
# Pick first active pin with a sha256 and mutate it.
for name, p in m['skills_pins'].items():
    if p.get('_status') == 'active' and p.get('sha256'):
        p['sha256'] = 'f' * 64
        break
json.dump(m, open(sys.argv[1], 'w'), indent=2)
PY
if python3 "$VALIDATE" >/dev/null 2>&1; then
    fail "validate-manifest did NOT catch sha256 drift"
else
    pass "validate-manifest caught sha256 drift"
fi
printf '%s' "$backup" > "$MANIFEST"

# ─────────────────────────────────────────────────
# 9. validate-manifest catches catalog drift
# ─────────────────────────────────────────────────
cat_backup=$(cat "$CATALOG")
python3 - "$CATALOG" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
if c['skills']:
    c['skills'][0]['commit'] = 'f' * 40
json.dump(c, open(sys.argv[1], 'w'), indent=2)
PY
if python3 "$VALIDATE" >/dev/null 2>&1; then
    fail "validate-manifest did NOT catch catalog drift"
else
    pass "validate-manifest caught catalog drift"
fi
printf '%s' "$cat_backup" > "$CATALOG"

# ─────────────────────────────────────────────────
# 10. --normalize collapses markdownlint-style cosmetic differences
# ─────────────────────────────────────────────────
mkdir -p "$SANDBOX/norm-a" "$SANDBOX/norm-b"
printf 'hello world\n\nsecond paragraph\n' > "$SANDBOX/norm-a/doc.md"
# Same logical content but with: CRLF line endings, trailing spaces,
# extra blank lines, leading/trailing blank lines.
printf '\nhello world   \r\n\n\n\nsecond paragraph\t\r\n\n\n' > "$SANDBOX/norm-b/doc.md"
sha_a_raw=$(bash "$CHECKSUM" "$SANDBOX/norm-a")
sha_b_raw=$(bash "$CHECKSUM" "$SANDBOX/norm-b")
sha_a_norm=$(bash "$CHECKSUM" --normalize "$SANDBOX/norm-a")
sha_b_norm=$(bash "$CHECKSUM" --normalize "$SANDBOX/norm-b")
if [[ "$sha_a_raw" != "$sha_b_raw" ]] && [[ "$sha_a_norm" == "$sha_b_norm" ]]; then
    pass "--normalize collapses whitespace-only diff (raw differs, normalized equal)"
else
    fail "--normalize behaviour: raw a=$sha_a_raw b=$sha_b_raw / norm a=$sha_a_norm b=$sha_b_norm"
fi

# ─────────────────────────────────────────────────
# 11. --normalize does NOT mask real content change
# ─────────────────────────────────────────────────
mkdir -p "$SANDBOX/norm-c"
printf 'hello world\n\nDIFFERENT paragraph\n' > "$SANDBOX/norm-c/doc.md"
sha_c_norm=$(bash "$CHECKSUM" --normalize "$SANDBOX/norm-c")
if [[ "$sha_a_norm" != "$sha_c_norm" ]]; then
    pass "--normalize preserves real content differences"
else
    fail "--normalize collapsed real content change: $sha_a_norm == $sha_c_norm"
fi

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────
echo ""
echo "Result: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
