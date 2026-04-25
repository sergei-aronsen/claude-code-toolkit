#!/bin/bash
# TEST FIXTURE — stub-chatgpt.sh: deterministic Council audit-review output.
# Emits canned <verdict-table> where F-001=REAL, F-002=FALSE_POSITIVE, F-003=FALSE_POSITIVE.
# F-003 disagrees with stub-gemini.sh (REAL) -> Plan 15-04 marks F-003 as disputed
# with confidence min(0.9, 0.7) = 0.7.
# Used by scripts/tests/test-council-audit-review.sh via COUNCIL_STUB_CHATGPT env var.
# Exit 0 always (simulates successful ChatGPT backend call).

set -euo pipefail

cat <<'EOF'
<verdict-table>
| ID | verdict | confidence | justification |
|----|---------|------------|---------------|
| F-001 | REAL | 0.95 | "SELECT * FROM users WHERE id=" + id at auth.ts:11 confirms direct injection path with no binding |
| F-002 | FALSE_POSITIVE | 0.88 | isBuildTime() guard at build.js:39 makes Function(spec) unreachable at runtime |
| F-003 | FALSE_POSITIVE | 0.7 | sanitizeHtml is imported at render.ts:1 and used on displayName; bio assignment is documented sanitized upstream |
</verdict-table>

<missed-findings>
(none)
</missed-findings>
EOF
