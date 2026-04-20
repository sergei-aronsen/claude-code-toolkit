#!/usr/bin/env bash
# test-matrix.sh — Phase 7 full install matrix wrapper (Test 16).
# Delegates to scripts/validate-release.sh --all. Adds timeout + clear output framing.
# Usage: bash scripts/tests/test-matrix.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Running Phase 7 install matrix (13 cells)..."
echo "Runner: scripts/validate-release.sh --all"
echo ""

exec bash "$REPO_ROOT/scripts/validate-release.sh" --all
