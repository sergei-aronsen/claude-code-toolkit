#!/bin/bash
# TEST FIXTURE — stub-malformed.sh: emits output WITHOUT <verdict-table> markers.
# Exercises Plan 15-04 brain.py parse-error path: when a backend returns
# malformed output, the orchestrator must mutate council_pass: failed,
# write a one-line "Council parse error" comment to the verdict slot,
# and exit non-zero so /audit surfaces the failure.
# Exit 0 always (the failure is in the OUTPUT shape, not the call status).

set -euo pipefail

cat <<'EOF'
I read the audit report and have some thoughts:

F-001 looks like a real SQL injection.
F-002 is probably a false positive.
F-003 I am not sure about.

(no verdict-table block, no missed-findings block — malformed output)
EOF
