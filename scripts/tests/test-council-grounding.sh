#!/bin/bash
# Claude Code Toolkit - test-council-grounding.sh
# Validates v6.7 grounding-marker detection in compose_system_prompt():
# plans annotated with [VERIFIED]/[DISPUTED]/[UNVERIFIABLE] by the
# /council Step 0 fact-check pre-flight should append a grounding
# directive to the system prompt; plain plans should be unchanged.
#
# Usage: bash scripts/tests/test-council-grounding.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BRAIN="$REPO_ROOT/scripts/council/brain.py"

if [ ! -f "$BRAIN" ]; then
    printf 'ERROR: brain.py not found at %s\n' "$BRAIN" >&2
    exit 1
fi

PASS=0
FAIL=0
report_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
report_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

# ─── G1 — plain plan: directive absent ──────────────────────────────────
G1_OUT=$(BRAIN_PATH="$BRAIN" python3 - <<'PY'
import os, importlib.util
spec = importlib.util.spec_from_file_location("brain", os.environ["BRAIN_PATH"])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
plain = "Refactor the auth middleware to use httpOnly cookies."
got = m.compose_system_prompt("skeptic", plain, domain="general")
has_directive = "[VERIFIED" in got or "pre-verified against current web sources" in got
print("HAS_DIRECTIVE" if has_directive else "CLEAN")
PY
)
if [ "$G1_OUT" = "CLEAN" ]; then
    report_pass "G1: plain plan -> system prompt has no grounding directive"
else
    report_fail "G1: plain plan unexpectedly carried grounding directive (got: $G1_OUT)"
fi

# ─── G2 — VERIFIED marker triggers directive ────────────────────────────
G2_OUT=$(BRAIN_PATH="$BRAIN" python3 - <<'PY'
import os, importlib.util
spec = importlib.util.spec_from_file_location("brain", os.environ["BRAIN_PATH"])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
grounded = "Use Stripe API 2026-04-22.dahlia [VERIFIED ✓ stripe.com] for billing."
got = m.compose_system_prompt("skeptic", grounded, domain="general")
print("OK" if "pre-verified against current web sources" in got else "MISS")
PY
)
if [ "$G2_OUT" = "OK" ]; then
    report_pass "G2: [VERIFIED] marker -> grounding directive appended"
else
    report_fail "G2: [VERIFIED] plan did not get grounding directive"
fi

# ─── G3 — DISPUTED marker triggers directive ────────────────────────────
G3_OUT=$(BRAIN_PATH="$BRAIN" python3 - <<'PY'
import os, importlib.util
spec = importlib.util.spec_from_file_location("brain", os.environ["BRAIN_PATH"])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
disputed = "Migrate to Postgres 18 [DISPUTED ✗ postgres.org] this quarter."
got = m.compose_system_prompt("pragmatist", disputed, domain="general")
print("OK" if "DISPUTED" in got and "treat the claim as wrong" in got.lower() else "MISS")
PY
)
if [ "$G3_OUT" = "OK" ]; then
    report_pass "G3: [DISPUTED] marker -> directive includes 'treat as wrong' guidance"
else
    report_fail "G3: [DISPUTED] plan missing 'wrong' guidance"
fi

# ─── G4 — UNVERIFIABLE marker triggers directive ────────────────────────
G4_OUT=$(BRAIN_PATH="$BRAIN" python3 - <<'PY'
import os, importlib.util
spec = importlib.util.spec_from_file_location("brain", os.environ["BRAIN_PATH"])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
unver = "Build feature X using internal-lib v3 [UNVERIFIABLE]."
got = m.compose_system_prompt("skeptic", unver, domain="general")
print("OK" if "UNVERIFIABLE" in got and "judgment" in got.lower() else "MISS")
PY
)
if [ "$G4_OUT" = "OK" ]; then
    report_pass "G4: [UNVERIFIABLE] marker -> directive references judgment"
else
    report_fail "G4: [UNVERIFIABLE] plan missing judgment guidance"
fi

# ─── G5 — false positive guard: VERIFIED-prefix word should not trigger ──
G5_OUT=$(BRAIN_PATH="$BRAIN" python3 - <<'PY'
import os, importlib.util
spec = importlib.util.spec_from_file_location("brain", os.environ["BRAIN_PATH"])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
# Word "VERIFIEDLY" doesn't exist, but "verified" inside prose without brackets
# must not match. The regex anchors on "[" + word + "\b".
prosey = "We need to discuss whether the migration was verified properly."
print("CLEAN" if not m._plan_has_grounding(prosey) else "FALSE_POSITIVE")
PY
)
if [ "$G5_OUT" = "CLEAN" ]; then
    report_pass "G5: prose mentioning 'verified' (no brackets) -> not detected as grounded"
else
    report_fail "G5: false positive — bracketless 'verified' triggered grounding"
fi

# ─── G6 — _plan_has_grounding return values ─────────────────────────────
G6_OUT=$(BRAIN_PATH="$BRAIN" python3 - <<'PY'
import os, importlib.util
spec = importlib.util.spec_from_file_location("brain", os.environ["BRAIN_PATH"])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
cases = [
    ("[VERIFIED ✓ src]", True),
    ("[DISPUTED ✗ src]", True),
    ("[UNVERIFIABLE]", True),
    ("plain text", False),
    ("[verified]", False),  # case-sensitive, lowercase doesn't match
    ("[VERIFIEDLY]", False),  # \b boundary rejects suffix
]
ok = all(m._plan_has_grounding(t) == expected for t, expected in cases)
print("OK" if ok else "FAIL")
PY
)
if [ "$G6_OUT" = "OK" ]; then
    report_pass "G6: _plan_has_grounding handles 6 cases correctly (case-sensitive, \\b-bounded)"
else
    report_fail "G6: _plan_has_grounding mismatch on edge cases"
fi

printf '\n'
printf 'Result: PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
