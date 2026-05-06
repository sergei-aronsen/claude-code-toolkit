#!/usr/bin/env bash
# test-integrations-catalog.sh — Phase 35 (TEST-01) hermetic schema check.
#
# Locks the v4.9 contract for scripts/lib/integrations-catalog.json:
#   - schema_version is the integer 2 (Phase 32 CAT-01 schema)
#   - categories[] is the canonical 10-list (Phase 33 D-04 final order)
#   - components.mcp has 23 entries (Phase 40 INT-13 added Calendly; v6.0 INT-15 added morph + claude-context:
#     20 baseline + 1 = 21. Phase 33 math note: 21 - 1 (DROP-01
#     sequential-thinking) + 0 = 20; Phase 40 INT-13 +1 = 21.
#     v6.1: morph-fast-tools replaced by serena 1-for-1 — count stays 23.)
#   - components.cli has 8 entries
#   - every MCP entry has the required keys
#   - every entry's category is in the top-level categories[] enum
#   - every CLI entry has detect_cmd + install.darwin + install.linux + post_install_hint
#   - the unofficial set is exactly {notebooklm, telegram}
#   - sequential-thinking is gone (DROP-01 regression guard)
#   - no `sudo` token in any install string (CLI-04 D-17 invariant)
#
# Hermetic — does NOT shell out to claude / brew / npm / network. Only python3.
#
# Usage: bash scripts/tests/test-integrations-catalog.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CATALOG="${REPO_ROOT}/scripts/lib/integrations-catalog.json"

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

echo "test-integrations-catalog.sh: TEST-01 schema contract for integrations-catalog.json"
echo ""

# ─────────────────────────────────────────────────
# A1 — catalog file exists at the canonical path
# ─────────────────────────────────────────────────
if [[ -f "$CATALOG" ]]; then
    assert_pass "A1: catalog file exists at scripts/lib/integrations-catalog.json"
else
    assert_fail "A1: catalog file exists" "missing path: $CATALOG"
    echo "Result: PASS=$PASS FAIL=$FAIL"
    exit 1
fi

# ─────────────────────────────────────────────────
# A2 — JSON parses
# ─────────────────────────────────────────────────
if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CATALOG" 2>/dev/null; then
    assert_pass "A2: catalog parses as valid JSON"
else
    assert_fail "A2: catalog parses as valid JSON" "json.load raised"
fi

# Helper: run python3 inline against the catalog and emit OK / FAIL <msg>.
_pyq() {
    local label="$1"
    shift
    local script="$1"
    local out
    out=$(python3 - "$CATALOG" <<PY 2>&1
import json, sys
catalog_path = sys.argv[1]
with open(catalog_path, "r", encoding="utf-8") as fh:
    catalog = json.load(fh)
$script
PY
    ) || true
    if [[ "$out" == "OK" ]]; then
        assert_pass "$label"
    else
        assert_fail "$label" "$out"
    fi
}

# ─────────────────────────────────────────────────
# A3 — schema_version == 2
# ─────────────────────────────────────────────────
_pyq "A3: schema_version == 2" '
sv = catalog.get("schema_version")
if sv == 2:
    print("OK")
else:
    print("schema_version is " + repr(sv) + ", expected 2")
'

# ─────────────────────────────────────────────────
# A4 — categories[] matches canonical 10-list (order-sensitive per Phase 33 D-04)
# ─────────────────────────────────────────────────
_pyq "A4: categories[] is the canonical 10-list" '
expected = [
    "docs-research", "backend", "payments", "email", "workspace",
    "project-management", "communication", "design", "dev-tools", "monitoring",
]
actual = catalog.get("categories")
if actual == expected:
    print("OK")
else:
    print("categories mismatch: got " + repr(actual))
'

# ─────────────────────────────────────────────────
# A5 — components.mcp has 23 entries
# (Phase 33 baseline: 21 - 1 DROP-01 = 20; Phase 40 INT-13 added Calendly = 21;
#  v6.0 INT-15 added morph-fast-tools + claude-context = 23;
#  v6.1: morph-fast-tools replaced by serena 1-for-1, count unchanged.)
# ─────────────────────────────────────────────────
_pyq "A5: components.mcp has exactly 23 entries" '
mcp = catalog.get("components", {}).get("mcp", {})
if isinstance(mcp, dict) and len(mcp) == 23:
    print("OK")
else:
    print("components.mcp count is " + str(len(mcp)) + ", expected 23")
'

# ─────────────────────────────────────────────────
# A6 — every MCP entry has the required keys
# ─────────────────────────────────────────────────
_pyq "A6: every MCP entry has all required keys" '
required = ("name", "display_name", "category", "install_args", "env_var_keys",
            "requires_oauth", "description")
mcp = catalog.get("components", {}).get("mcp", {})
missing = []
for name, entry in mcp.items():
    miss = [k for k in required if k not in entry]
    if miss:
        missing.append((name, miss))
if not missing:
    print("OK")
else:
    print("entries missing required keys: " + repr(missing))
'

# ─────────────────────────────────────────────────
# A7 — every MCP entry.category is a member of top-level categories[]
# ─────────────────────────────────────────────────
_pyq "A7: every MCP entry.category is in categories[]" '
mcp = catalog.get("components", {}).get("mcp", {})
cats = set(catalog.get("categories", []))
bad = [(n, e.get("category")) for n, e in mcp.items() if e.get("category") not in cats]
if not bad:
    print("OK")
else:
    print("entries with unknown category: " + repr(bad))
'

# ─────────────────────────────────────────────────
# A8 — components.cli has 8 entries (Phase 33 D-04 final composition: 5
# survivors with CLI value (firecrawl, playwright, sentry) + 5 added INT
# CLIs (supabase, cloudflare, stripe, aws-cloudwatch-logs, aws-cost-explorer))
# ─────────────────────────────────────────────────
_pyq "A8: components.cli has exactly 8 entries" '
cli = catalog.get("components", {}).get("cli", {})
if isinstance(cli, dict) and len(cli) == 8:
    print("OK")
else:
    print("components.cli count is " + str(len(cli)) + ", expected 8")
'

# ─────────────────────────────────────────────────
# A9 — every CLI entry has detect_cmd + install.darwin + install.linux + post_install_hint
# ─────────────────────────────────────────────────
_pyq "A9: every CLI entry has all required fields" '
cli = catalog.get("components", {}).get("cli", {})
errors = []
for name, entry in cli.items():
    if not isinstance(entry, dict):
        errors.append((name, "not an object"))
        continue
    if not entry.get("detect_cmd"):
        errors.append((name, "missing detect_cmd"))
    install = entry.get("install", {})
    if not install.get("darwin"):
        errors.append((name, "missing install.darwin"))
    if not install.get("linux"):
        errors.append((name, "missing install.linux"))
    if not entry.get("post_install_hint"):
        errors.append((name, "missing post_install_hint"))
if not errors:
    print("OK")
else:
    print("CLI entries with missing fields: " + repr(errors))
'

# ─────────────────────────────────────────────────
# A10 — unofficial: true set equals exactly {notebooklm, telegram}
# (Phase 33 INT-09 + INT-10; D-09 boundary)
# ─────────────────────────────────────────────────
_pyq "A10: unofficial set == {notebooklm, telegram}" '
mcp = catalog.get("components", {}).get("mcp", {})
unofficial = sorted([n for n, e in mcp.items() if e.get("unofficial") is True])
expected = ["notebooklm", "telegram"]
if unofficial == expected:
    print("OK")
else:
    print("unofficial set is " + repr(unofficial) + ", expected " + repr(expected))
'

# ─────────────────────────────────────────────────
# A11 — sequential-thinking entry is GONE (DROP-01 regression guard)
# ─────────────────────────────────────────────────
_pyq "A11: sequential-thinking entry is absent (DROP-01)" '
mcp = catalog.get("components", {}).get("mcp", {})
cli = catalog.get("components", {}).get("cli", {})
if "sequential-thinking" in mcp or "sequential-thinking" in cli:
    print("sequential-thinking still in catalog")
else:
    print("OK")
'

# ─────────────────────────────────────────────────
# A12 — no `sudo` token in any install string (CLI-04 D-17 no-sudo invariant)
# ─────────────────────────────────────────────────
_pyq "A12: no sudo token in any install string" '
import re
cli = catalog.get("components", {}).get("cli", {})
sudo_re = re.compile(r"(^|[\s;|&])sudo([\s$]|$)")
hits = []
for name, entry in cli.items():
    install = entry.get("install", {}) if isinstance(entry, dict) else {}
    for plat, cmd in install.items():
        if isinstance(cmd, str) and sudo_re.search(cmd):
            hits.append((name, plat))
if not hits:
    print("OK")
else:
    print("install strings containing sudo: " + repr(hits))
'

# ─────────────────────────────────────────────────
# A13 — every MCP entry name self-references its key (defensive consistency)
# ─────────────────────────────────────────────────
_pyq "A13: every MCP entry.name equals its key" '
mcp = catalog.get("components", {}).get("mcp", {})
mismatches = [(k, e.get("name")) for k, e in mcp.items() if e.get("name") != k]
if not mismatches:
    print("OK")
else:
    print("name != key: " + repr(mismatches))
'

# ─────────────────────────────────────────────────
# A14 — every MCP install_args is a non-empty list of strings
# ─────────────────────────────────────────────────
_pyq "A14: every MCP install_args is a non-empty list of strings" '
mcp = catalog.get("components", {}).get("mcp", {})
errors = []
for name, entry in mcp.items():
    args = entry.get("install_args")
    if not isinstance(args, list) or len(args) == 0:
        errors.append((name, "not a non-empty list"))
        continue
    for arg in args:
        if not isinstance(arg, str):
            errors.append((name, "non-string arg: " + repr(arg)))
            break
if not errors:
    print("OK")
else:
    print("install_args errors: " + repr(errors))
'

# ─────────────────────────────────────────────────
# A15 — every MCP entry has default_scope ∈ {"user","project"} (SCOPE-01 / TEST-06)
# ─────────────────────────────────────────────────
_pyq "A15: every MCP entry has default_scope in {user, project}" '
mcp = catalog.get("components", {}).get("mcp", {})
errors = []
for name, entry in mcp.items():
    ds = entry.get("default_scope")
    if ds not in ("user", "project"):
        errors.append((name, ds))
if not errors:
    print("OK")
else:
    print("entries with bad default_scope: " + repr(errors))
'

# ─────────────────────────────────────────────────
# A16 — SCOPE-02 grid spot-check: known infra MCP defaults to project (D-07)
# ─────────────────────────────────────────────────
_pyq "A16: aws-cloudwatch-logs default_scope is project (D-07)" '
ds = catalog.get("components", {}).get("mcp", {}).get("aws-cloudwatch-logs", {}).get("default_scope")
if ds == "project":
    print("OK")
else:
    print("aws-cloudwatch-logs default_scope is " + repr(ds) + ", expected project")
'

# ─────────────────────────────────────────────────
# A17 — SCOPE-02 grid spot-check: known personal MCP defaults to user (D-06)
# ─────────────────────────────────────────────────
_pyq "A17: context7 default_scope is user (D-06)" '
ds = catalog.get("components", {}).get("mcp", {}).get("context7", {}).get("default_scope")
if ds == "user":
    print("OK")
else:
    print("context7 default_scope is " + repr(ds) + ", expected user")
'

# ─────────────────────────────────────────────────
# A18 — Phase 40 INT-13: Calendly entry has expected OAuth-only shape.
# Mirrors Notion (closest OAuth-only analog): no `unofficial` field,
# env_var_keys=[], requires_oauth=true, default_scope=user, category=workspace.
# Per CONTEXT D-09 + PATTERNS surprise #5 (official MCPs OMIT the `unofficial`
# key entirely; only community wrappers like notebooklm/telegram set it true).
# ─────────────────────────────────────────────────
_pyq "A18: calendly entry has expected shape" '
mcp = catalog.get("components", {}).get("mcp", {})
e = mcp.get("calendly", {})
if (e.get("name") == "calendly"
    and e.get("display_name") == "Calendly"
    and e.get("category") == "workspace"
    and e.get("requires_oauth") is True
    and e.get("default_scope") == "user"
    and e.get("env_var_keys") == []
    and "unofficial" not in e):
    print("OK")
else:
    print("calendly shape mismatch: " + repr(e))
'

# ─────────────────────────────────────────────────
# A19 — Phase 40 INT-14 lock: catalog must NEVER carry a Google Workspace
# MCP entry (claude.ai built-in connectors cover Gmail/Calendar/Drive).
# Per CONTEXT D-10. Defense-in-depth — the catalog has never had such an
# entry; this assertion locks the negative invariant against future drift.
# ─────────────────────────────────────────────────
_pyq "A19: no google-* MCP entries (INT-14 lock)" '
import re
mcp = catalog.get("components", {}).get("mcp", {})
pat = re.compile(r"^google-(workspace|drive|gmail|calendar)$")
hits = [n for n in mcp if pat.match(n)]
if not hits:
    print("OK")
else:
    print("forbidden google-* entries present: " + repr(hits))
'

# ─────────────────────────────────────────────────
# A20 — Phase 40 TEST-06 SCOPE-01 negative regression: validator must catch
# a mutated catalog copy that has one entry missing `default_scope`.
# Validator implementation is at scripts/validate-integrations-catalog.py
# lines 254-272 (Phase 36 work, NOT modified by Phase 40). This test locks
# the contract: removing `default_scope` from any entry produces non-zero
# exit + stderr message containing "default_scope is required".
# ─────────────────────────────────────────────────
echo ""
echo "── A20: validator catches missing default_scope (SCOPE-01 regression) ──"
_a20_tmp="$(mktemp -t catalog-mut.XXXXXX)"
# Strip default_scope from one entry (deterministic: alpha-first MCP name).
# python3 heredoc runs with $CATALOG passed as argv (line 27 — script-set, not
# user input, so no injection risk). The body uses a single-quoted heredoc so
# Python source is not subject to shell expansion.
python3 - "$CATALOG" > "$_a20_tmp" <<'PYEOF'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    c = json.load(fh)
mcp = c["components"]["mcp"]
first_name = sorted(mcp.keys())[0]
del c["components"]["mcp"][first_name]["default_scope"]
print(json.dumps(c, indent=2))
PYEOF

# Capture the validator output and exit code WITHOUT the `cmd | grep` pipeline
# (that pattern interacts badly with `set -o pipefail` — when python3 exits
# non-zero (expected here — that is exactly what we are asserting), pipefail
# bubbles python3's rc=1 up past grep's rc=0, breaking the if-test). Instead
# run the validator into a temp var, then `grep -q` against the captured
# string, and explicitly assert rc != 0 from the validator.
_a20_out="$(python3 "$REPO_ROOT/scripts/validate-integrations-catalog.py" "$_a20_tmp" 2>&1 || true)"
_a20_rc=0
python3 "$REPO_ROOT/scripts/validate-integrations-catalog.py" "$_a20_tmp" >/dev/null 2>&1 || _a20_rc=$?
if [[ "$_a20_rc" -ne 0 ]] && printf '%s\n' "$_a20_out" | grep -q 'default_scope is required'; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}OK${NC} A20: validator caught missing default_scope (SCOPE-01 regression)\n"
else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} A20: validator did NOT catch missing default_scope (rc=%s)\n" "$_a20_rc"
    printf "      validator stdout/stderr:\n"
    printf '%s\n' "$_a20_out" | sed 's/^/        /'
fi
rm -f "$_a20_tmp"

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
