#!/usr/bin/env bash
# scripts/cell-parity.sh — REL-02: assert every cell name appears in all 3 surfaces.
# Surfaces: (1) validate-release.sh --list (source of truth),
#           (2) docs/INSTALL.md (user matrix),
#           (3) docs/RELEASE-CHECKLIST.md (release process doc).
# Strict 3/3 (D-07): any cell missing from surface 2 OR 3 fails the gate.
# Exit: 0 = all cells present in all 3 surfaces; 1 = drift detected; 2 = usage error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RUNNER="${REPO_ROOT}/scripts/validate-release.sh"
INSTALL_MD="${REPO_ROOT}/docs/INSTALL.md"
CHECKLIST_MD="${REPO_ROOT}/docs/RELEASE-CHECKLIST.md"

if [ ! -x "$RUNNER" ] && [ ! -f "$RUNNER" ]; then
    echo "ERROR: $RUNNER not found" >&2; exit 2
fi
[ -f "$INSTALL_MD" ]    || { echo "ERROR: $INSTALL_MD not found" >&2; exit 2; }
[ -f "$CHECKLIST_MD" ]  || { echo "ERROR: $CHECKLIST_MD not found" >&2; exit 2; }

# bash 3.2-safe cell list (mapfile requires bash 4.0+)
CELLS=()
while IFS= read -r c; do
    [ -z "$c" ] && continue
    CELLS+=("$c")
done < <(bash "$RUNNER" --list)

if [ "${#CELLS[@]}" -eq 0 ]; then
    echo "ERROR: validate-release.sh --list returned no cells" >&2; exit 2
fi

ERRORS=0
for cell in "${CELLS[@]}"; do
    in_install=0
    in_checklist=0
    # Word-boundary pattern (Pitfall 4): prevents --cell standalone matching --cell standalone-fresh
    # [[:space:]] is POSIX portable (GNU \s not allowed)
    grep -qE -- "--cell[[:space:]]+${cell}([^a-z0-9-]|$)" "$INSTALL_MD"   2>/dev/null && in_install=1   || true
    grep -qE -- "--cell[[:space:]]+${cell}([^a-z0-9-]|$)" "$CHECKLIST_MD" 2>/dev/null && in_checklist=1 || true
    if [ "$in_install" = "0" ] || [ "$in_checklist" = "0" ]; then
        printf "❌ %-32s  INSTALL.md=%s  CHECKLIST.md=%s\n" "$cell" "$in_install" "$in_checklist"
        ERRORS=$((ERRORS + 1))
    fi
done

if [ "$ERRORS" -gt 0 ]; then
    echo "cell-parity FAILED: ${ERRORS} cell(s) missing from one or more surfaces"
    exit 1
fi
echo "✅ cell-parity passed: all ${#CELLS[@]} cells present in all 3 surfaces"
