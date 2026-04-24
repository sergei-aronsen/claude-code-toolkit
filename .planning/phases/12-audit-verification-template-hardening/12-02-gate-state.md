# Plan 12.2 Gate State

**Read at:** 2026-04-24T00:00:00Z

## Approved HARDEN-A-NN REQs (will be implemented by Plan 12.2)

| HARDEN ID | Derived From | Proposed Work |
|-----------|--------------|----------------|
| HARDEN-A-01 | AUDIT-12 | Add `validate-commands` Makefile target that greps every `commands/*.md` (except README.md) for `## Purpose` and `## Usage` headings; wire into the `check` target and the `validate-templates` job in `.github/workflows/quality.yml`; fail with list of non-compliant files |

## Rejected / Deferred / Closed HARDEN-A-NN REQs (skipped)

| HARDEN ID | Status | Reason |
|-----------|--------|--------|
| (none) | — | All Wave A proposals approved or none rejected — only HARDEN-A-01 was in Wave A |
