#!/usr/bin/env bash
# test-integrations-catalog.sh — Phase 35 (TEST-01) hermetic schema check.
#
# Locks the v4.9 contract for scripts/lib/integrations-catalog.json:
#   - schema_version is the integer 2 (Phase 32 CAT-01 schema)
#   - categories[] is the canonical 10-list (Phase 33 D-04 final order)
#   - components.mcp has 20 entries (NOT 19 — see Phase 33 SUMMARY math note:
#     21 - 1 (DROP-01 sequential-thinking) + 0 = 20; or equivalently
#     9 baseline - 1 dropped + 12 added = 20)
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
# A5 — components.mcp has 20 entries
# (21 baseline - 1 DROP-01 = 20; OR 9 surviving Phase 32 + 12 INT-01..12 = 21
#  - 1 DROP-01 = 20. The 19-vs-20 confusion in some notes is resolved here.)
# ─────────────────────────────────────────────────
_pyq "A5: components.mcp has exactly 20 entries" '
mcp = catalog.get("components", {}).get("mcp", {})
if isinstance(mcp, dict) and len(mcp) == 20:
    print("OK")
else:
    print("components.mcp count is " + str(len(mcp)) + ", expected 20")
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

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
