---
description: Audit false-positive allowlist — entries suppressed by /audit-skip
globs:
  - "**/*"
---

# Audit Exceptions — False-Positive Allowlist

Entries below are findings that `/audit` and `/audit-review` MUST treat as known false
positives. Each entry was added by `/audit-skip <file:line> <rule> <reason>` after explicit
user review. To remove an entry that turned out to be a real bug, run
`/audit-restore <file:line> <rule>`.

## Entries

<!--
Example entry (this comment is intentionally not a real entry):

Heading format: ### path:line — RULE-ID (em-dash U+2014)

- **Date:** YYYY-MM-DD
- **Council:** unreviewed
- **Reason:** explanation why this finding is a false positive

Allowed Council values: unreviewed | council_confirmed_fp | disputed
-->
