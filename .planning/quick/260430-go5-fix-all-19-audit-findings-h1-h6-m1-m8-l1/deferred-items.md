# Deferred items — out of scope for audit-sweep 260430-go5

## Pre-existing test failures NOT introduced by this sweep

### test-bootstrap.sh — 8/26 failing on baseline

Confirmed via `git stash && bash scripts/tests/test-bootstrap.sh` BEFORE
any of T2-T19 were applied. PASS=18 FAIL=8 was the starting state.

Failing assertions:

- S1: SP mock invoked / GSD mock invoked / no install-failed warning
- S4: GSD mock still invoked / no install-failed warning
- S5: SP mock was invoked / SP failure warning emitted / GSD mock still invoked

Root cause (likely): the test never sets `TK_TEST=1`, but
`scripts/lib/bootstrap.sh:112-118` (audit C2 hardening, commit 76fcc4c)
gates the `TK_BOOTSTRAP_OVERRIDE_CMD` eval on `TK_TEST=1` AND a non-empty
override. Without TK_TEST=1 the test seam is silently ignored.

Fix would be the same shape as my T12 (H6) update to test-install-tui.sh:
add `TK_TEST=1 \` to each env-block. Out of scope for this sweep — the
audit findings list does not include this.

Also affects test-bridges-sync.sh S10a (BACKCOMPAT check that re-runs
test-bootstrap.sh and expects PASS=26 FAIL=0).
