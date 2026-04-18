# Deferred Items — Pre-existing Lint Errors Outside Plan 05-01 Scope

## Markdownlint failures unrelated to 05-01 changes

These were present BEFORE Plan 05-01 and are NOT caused by the retrofits in this plan. Per SCOPE BOUNDARY in the executor rules, they are logged here rather than auto-fixed.

- `CLAUDE.md:471` MD022/blanks-around-headings
- `CLAUDE.md:486` MD032/blanks-around-lists
- `components/orchestration-pattern.md:211,225,231` MD031/blanks-around-fences
- `components/orchestration-pattern.md:214,221,224,229` MD029/ol-prefix
- `components/orchestration-pattern.md:230` MD032/blanks-around-lists
- `components/orchestration-pattern.md:231` MD040/fenced-code-language

**Impact:** `make check` fails on mdlint. `make validate` and all `make test` pass. `shellcheck` passes.

**Scope:** These files are not in Plan 05-01's `files_modified` list (scripts/lib/state.sh, scripts/update-claude.sh, manifest.json, scripts/tests/test-update-drift.sh).
