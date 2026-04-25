#!/bin/bash
# TEST FIXTURE — stub-gemini.sh: deterministic Council audit-review output.
# Emits canned <verdict-table> where F-001=REAL, F-002=FALSE_POSITIVE, F-003=REAL.
# Used by scripts/tests/test-council-audit-review.sh via COUNCIL_STUB_GEMINI env var.
# Exit 0 always (simulates successful Gemini backend call).

set -euo pipefail

cat <<'EOF'
<verdict-table>
| ID | verdict | confidence | justification |
|----|---------|------------|---------------|
| F-001 | REAL | 0.9 | req.params.id concatenated into SQL string at auth.ts:11 reaches db.query without parameterized binding |
| F-002 | FALSE_POSITIVE | 0.85 | Function(spec) at build.js:43 is gated by isBuildTime(); never reached at request time |
| F-003 | REAL | 0.9 | bio assignment at render.ts:90 sets innerHTML without explicit sanitizeHtml() call; upstream comment is unverified |
</verdict-table>

<missed-findings>
(none)
</missed-findings>
EOF
