# Deferred Items — Pre-existing Lint Errors Outside Plan 05-01/02/03 Scope

## Markdownlint failures unrelated to phase 05 changes

These were present BEFORE phase 05 started and are NOT caused by the retrofits in this phase. Per SCOPE BOUNDARY in the executor rules, they are logged here rather than auto-fixed.

- `CLAUDE.md` — multiple MD022/MD032/MD036 errors (~100 lines reported by markdownlint)
- `components/orchestration-pattern.md` — MD029/MD031/MD032/MD040 errors (~10 lines)

**Impact:** `make check` fails on mdlint. `make validate` and all 14 `make test` groups pass. `shellcheck` is clean across all phase-touched scripts.

**Scope:** Neither file is in any phase 05 plan's `files_modified` list. Plans 05-01/02/03 touched only:

- `scripts/lib/state.sh`, `scripts/update-claude.sh`, `manifest.json` (05-01)
- `scripts/migrate-to-complement.sh`, `scripts/tests/test-migrate-diff.sh`, `scripts/tests/fixtures/...`, `Makefile` (05-02)
- `scripts/migrate-to-complement.sh`, `scripts/tests/test-migrate-flow.sh`, `scripts/tests/test-migrate-idempotent.sh`, `Makefile` (05-03)

All of the above files pass their respective linters (shellcheck for .sh, Makefile parses cleanly). Fix for the pre-existing markdownlint errors should be tracked as a separate doc-cleanup task (not blocking phase 05 completion).

## Test 3 verify-block `make check` reference

Plan 05-03 Task 3's `<verify>` block invokes `make check`. It fails for the reasons above. `make shellcheck`, `make validate`, and `make test` (all 14 groups) pass. The `make check` failure is OUT OF SCOPE for Plan 05-03 and is tracked under this deferred-items section.
