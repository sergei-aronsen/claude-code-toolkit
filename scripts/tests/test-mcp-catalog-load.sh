#!/usr/bin/env bash
# test-mcp-catalog-load.sh — Audit 2026-05-14 H-2 regression guard.
#
# Validates that scripts/lib/mcp.sh:mcp_catalog_load:
#   1. Forks jq at most twice (was ~301 forks pre-fix; should be 1)
#   2. Returns exactly 30 entries from integrations-catalog.json
#   3. Sorts MCP_NAMES alphabetically
#   4. Keeps all 10 parallel arrays at length 30
#   5. Correctly handles entries with EMPTY env_var_keys (calendly — the
#      regression vector that broke the earlier @tsv attempt: tab+tab
#      collapsed under whitespace IFS and shifted columns by one)
#   6. Correctly populates MCP_HAS_CLI from cross-reference into
#      components.cli[<name>].detect_cmd
#   7. Preserves the in-string US ( = octal 037) separator inside
#      install_args (NOT the same as the new RS row delimiter)
#
# Hermetic. Exits 1 if any assertion fails.

set -euo pipefail

# ----- locate repo root --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SCRIPT_DIR"

CATALOG_PATH="$(pwd)/scripts/lib/integrations-catalog.json"
export TK_MCP_CATALOG_PATH="$CATALOG_PATH"

PASS=0
FAIL=0

_pass() { PASS=$((PASS + 1)); echo "  ok  $1"; }
_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1" >&2; }

# ----- T1: jq fork count via PATH-shadow wrapper -------------------------
# Resolve the REAL jq binary BEFORE we shadow PATH.
REAL_JQ="$(command -v jq || true)"
if [[ -z "$REAL_JQ" ]]; then
    # Fallback to well-known paths on macOS / Linux.
    for candidate in /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
        if [[ -x "$candidate" ]]; then
            REAL_JQ="$candidate"
            break
        fi
    done
fi
if [[ -z "$REAL_JQ" || ! -x "$REAL_JQ" ]]; then
    echo "FATAL: jq not found on PATH or known locations" >&2
    exit 2
fi

WRAPPER_DIR="$(mktemp -d)"
COUNTER_FILE="$WRAPPER_DIR/jq.count"
: > "$COUNTER_FILE"

cat > "$WRAPPER_DIR/jq" <<EOF
#!/usr/bin/env bash
echo 1 >> "$COUNTER_FILE"
exec "$REAL_JQ" "\$@"
EOF
chmod +x "$WRAPPER_DIR/jq"

# Run the loader inside a sub-shell with the wrapper FIRST on PATH so
# every jq invocation made by mcp_catalog_load goes through the wrapper.
(
    export PATH="$WRAPPER_DIR:$PATH"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/scripts/lib/mcp.sh"
    mcp_catalog_load
)

JQ_FORKS="$(wc -l < "$COUNTER_FILE" | tr -d ' ')"
if [[ "$JQ_FORKS" -le 2 ]]; then
    _pass "T1 jq fork count = $JQ_FORKS (<= 2)"
else
    _fail "T1 jq fork count = $JQ_FORKS, expected <= 2 (regression to per-row forks)"
fi

rm -rf "$WRAPPER_DIR"

# ----- Load arrays for the remaining assertions --------------------------
# shellcheck source=/dev/null
source "$SCRIPT_DIR/scripts/lib/mcp.sh"
mcp_catalog_load

# ----- T2: 30 entries ----------------------------------------------------
if [[ "${#MCP_NAMES[@]}" -eq 30 ]]; then
    _pass "T2 MCP_NAMES length = 30"
else
    _fail "T2 MCP_NAMES length = ${#MCP_NAMES[@]}, expected 30"
fi

# ----- T3: alphabetical order --------------------------------------------
EXPECTED_ORDER="$("$REAL_JQ" -r '.components.mcp | keys | sort | .[]' "$TK_MCP_CATALOG_PATH")"
ACTUAL_ORDER="$(printf '%s\n' "${MCP_NAMES[@]}")"
if [[ "$EXPECTED_ORDER" == "$ACTUAL_ORDER" ]]; then
    _pass "T3 MCP_NAMES sorted alphabetically"
else
    _fail "T3 MCP_NAMES not sorted alphabetically"
    diff <(echo "$EXPECTED_ORDER") <(echo "$ACTUAL_ORDER") >&2 || true
fi

# ----- T4: every parallel array has length 30 ----------------------------
len=0
for arr in MCP_DISPLAY MCP_ENV_KEYS MCP_INSTALL_ARGS MCP_DESCS MCP_OAUTH \
           MCP_CATEGORY MCP_HAS_CLI MCP_CLI_DETECT MCP_UNOFFICIAL MCP_DEFAULT_SCOPE; do
    eval "len=\${#${arr}[@]}"
    if [[ "$len" -eq 30 ]]; then
        _pass "T4 $arr length = 30"
    else
        _fail "T4 $arr length = $len, expected 30"
    fi
done

# ----- T5: calendly column alignment (critical regression test) ----------
# Find calendly's index in MCP_NAMES (alpha sort puts it early — after
# any name starting with "ca*" earlier; in this catalog it's near index 2).
CAL_IDX=-1
for i in "${!MCP_NAMES[@]}"; do
    if [[ "${MCP_NAMES[$i]}" == "calendly" ]]; then
        CAL_IDX=$i
        break
    fi
done

if [[ "$CAL_IDX" -lt 0 ]]; then
    _fail "T5 calendly not found in MCP_NAMES"
else
    cal_env="${MCP_ENV_KEYS[$CAL_IDX]}"
    cal_scope="${MCP_DEFAULT_SCOPE[$CAL_IDX]}"
    cal_cat="${MCP_CATEGORY[$CAL_IDX]}"
    cal_oauth="${MCP_OAUTH[$CAL_IDX]}"
    cal_disp="${MCP_DISPLAY[$CAL_IDX]}"

    if [[ -z "$cal_env" ]]; then
        _pass "T5a calendly MCP_ENV_KEYS empty (column alignment OK)"
    else
        _fail "T5a calendly MCP_ENV_KEYS = '$cal_env', expected empty"
    fi

    if [[ "$cal_scope" == "user" ]]; then
        _pass "T5b calendly MCP_DEFAULT_SCOPE = user"
    else
        _fail "T5b calendly MCP_DEFAULT_SCOPE = '$cal_scope', expected user"
    fi

    if [[ "$cal_cat" == "workspace" ]]; then
        _pass "T5c calendly MCP_CATEGORY = workspace"
    else
        _fail "T5c calendly MCP_CATEGORY = '$cal_cat', expected workspace"
    fi

    if [[ "$cal_oauth" == "1" ]]; then
        _pass "T5d calendly MCP_OAUTH = 1"
    else
        _fail "T5d calendly MCP_OAUTH = '$cal_oauth', expected 1"
    fi

    if [[ "$cal_disp" == "Calendly" ]]; then
        _pass "T5e calendly MCP_DISPLAY = Calendly"
    else
        _fail "T5e calendly MCP_DISPLAY = '$cal_disp', expected Calendly"
    fi
fi

# ----- T6: serena HAS_CLI matches catalog cross-ref ----------------------
SERENA_IDX=-1
for i in "${!MCP_NAMES[@]}"; do
    if [[ "${MCP_NAMES[$i]}" == "serena" ]]; then
        SERENA_IDX=$i
        break
    fi
done

if [[ "$SERENA_IDX" -lt 0 ]]; then
    _fail "T6 serena not found in MCP_NAMES"
else
    has_cli_arr="${MCP_HAS_CLI[$SERENA_IDX]}"
    has_cli_json="$("$REAL_JQ" -r '
        if (.components.cli.serena.detect_cmd // "") == "" then "0" else "1" end
    ' "$TK_MCP_CATALOG_PATH")"
    if [[ "$has_cli_arr" == "$has_cli_json" ]]; then
        _pass "T6 serena MCP_HAS_CLI ($has_cli_arr) matches components.cli.serena.detect_cmd presence"
    else
        _fail "T6 serena MCP_HAS_CLI = $has_cli_arr, expected $has_cli_json (catalog says detect_cmd ${has_cli_json}=present)"
    fi
fi

# ----- T7: install_args preserves US (octal 037) byte ---------------------
# Find the first entry whose install_args contains >= 2 elements. Most
# entries do (e.g. npx + package). We just need *some* US byte to verify
# the in-string separator survived the row-delimiter swap.
US_FOUND=0
for i in "${!MCP_INSTALL_ARGS[@]}"; do
    args="${MCP_INSTALL_ARGS[$i]}"
    if printf '%s' "$args" | od -An -c | grep -q '037'; then
        US_FOUND=1
        _pass "T7 MCP_INSTALL_ARGS[$i] (${MCP_NAMES[$i]}) preserves US (\\037) separator"
        break
    fi
done
if [[ "$US_FOUND" -eq 0 ]]; then
    _fail "T7 no MCP_INSTALL_ARGS entry contains US (\\037) — install_args separator lost"
fi

# ----- Summary -----------------------------------------------------------
echo
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
