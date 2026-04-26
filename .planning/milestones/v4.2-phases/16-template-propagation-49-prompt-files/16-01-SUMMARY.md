---
phase: 16-template-propagation-49-prompt-files
plan: "01"
subsystem: scripts
tags: [splice, audit-pipeline, bash, idempotent, awk, python3]
requirements: [TEMPLATE-01, TEMPLATE-02]
dependency_graph:
  requires: [components/audit-fp-recheck.md, components/audit-output-format.md]
  provides: [scripts/propagate-audit-pipeline-v42.sh]
  affects: [templates/*/prompts/*.md (49 files, via Plan 16-03)]
tech_stack:
  added: [python3 inline heredoc for multi-line file rewrite]
  patterns: [awk fence-aware section detection, atomic mktemp+mv, SPLICE_TEMPLATES_DIR env seam]
key_files:
  created: [scripts/propagate-audit-pipeline-v42.sh]
  modified: [components/audit-output-format.md]
decisions:
  - "Python3 inline heredoc used instead of awk -v for multi-line block injection (awk -v cannot hold newlines)"
  - "Fence-aware awk (infence toggle on ^```) prevents matching ^## inside code blocks for section-end detection"
  - "_unknown_ in audit-output-format.md changed from underscore to asterisk emphasis (MD049 compliance; rendered output identical)"
metrics:
  duration: "~90 minutes"
  completed: "2026-04-25T23:22:44Z"
  tasks: 2
  files: 2
---

# Phase 16 Plan 01: propagate-audit-pipeline-v42.sh Summary

Idempotent Bash splice tool (`scripts/propagate-audit-pipeline-v42.sh`, 395 lines) that fans out the four v4.2 audit-pipeline contract blocks across all 49 framework prompt files. Script reads Phase 14 SOT components at run time, uses `<!-- v42-splice: ... -->` sentinel idempotency, Python3-based multi-line rewrite, and `SPLICE_TEMPLATES_DIR` env seam for test isolation.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Skeleton + SOT extraction + sentinel detection | 5ed88b0 | scripts/propagate-audit-pipeline-v42.sh |
| 2 | insert_blocks() — 4-block splice + markdownlint fixes | ae58996 | scripts/propagate-audit-pipeline-v42.sh, components/audit-output-format.md |

## Final Script Structure (395 lines)

```text
scripts/propagate-audit-pipeline-v42.sh
├── CLI flag parsing (--dry-run, --help)
├── Path resolution + SOT guards (FP_RECHECK_SOT, OUTPUT_FORMAT_SOT, TEMPLATES_ROOT)
├── SOT body extraction — awk: first ^## heading through EOF
├── write_spliced_file() — Python3 inline heredoc rewrite
│   ├── Anchor detection via awk (fence-aware: /^```/ toggles infence flag)
│   ├── Block file creation: callout.txt, fp.txt, of.txt, ch.txt (printf-based)
│   └── Python3 rewrite: append_block() + ensure_single_trailing_blank() helpers
├── insert_blocks() — shape detection + heading computation + write_spliced_file + atomic mv
└── Per-file loop: find 7-filename allowlist | sort → sentinel detection → CRLF guard → splice
```

## Key Architectural Decision: Python3 Over Pure awk

The plan proposed a single awk pass with multi-line string variables (`awk -v block="..."`) for the 4-block insertion. This fails in POSIX awk: `-v` variables cannot contain literal newlines — awk emits `newline in string` at startup.

**Resolution**: Write block payloads to temp files (via `printf`), then use an inline Python3 heredoc that reads them and performs the line-by-line rewrite. Python3 is available on all supported platforms (macOS 12+, Linux CI). The awk passes are retained for the lightweight anchor detection (section start/end line numbers) since they operate on single-line output.

## Edge Cases Handled

| File shape | Detection | Behavior |
|-----------|-----------|----------|
| Has SELF-CHECK + REPORT FORMAT (e.g. `SECURITY_AUDIT.md`) | `grep -nE '^## ([0-9]+\.\s*)?SELF-CHECK'` | Replaces existing SELF-CHECK heading+body; inserts OUTPUT FORMAT after rf_end |
| Has REPORT FORMAT but no SELF-CHECK (e.g. some `CODE_REVIEW.md` variants) | sc_start == 0, rf_start > 0 | Inserts fp_blk immediately before rf_start heading |
| Has numbered sections but neither (e.g. `MYSQL_PERFORMANCE_AUDIT.md`) | sc_start == 0, rf_start == 0 | Appends fp_blk + of_blk at EOF before Council Handoff |
| DESIGN_REVIEW (unnumbered, 7 files) | `grep -qE '^## [0-9]+\.'` returns false | Emits `## SELF-CHECK (...)` and `## OUTPUT FORMAT (...)` without numeric prefix |

## Fence-Aware Section-End Detection

The awk that computes `selfcheck_end_line` and `reportfmt_end_line` tracks code fence state via `infence` toggle on `/^```/`. Without this, the `^## ` pattern matches `## Summary` inside ` ```markdown ` code blocks in REPORT FORMAT sections (e.g. `CODE_REVIEW.md`), causing the OUTPUT FORMAT block to be inserted mid-fence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] awk -v multi-line variable limitation**

- **Found during:** Task 2 smoke test
- **Issue:** `awk -v callout_block="$callout_block"` fails with `newline in string` when the variable contains literal newlines
- **Fix:** Switched to Python3 inline heredoc that reads block content from temp files; awk retained only for line-number detection
- **Files modified:** `scripts/propagate-audit-pipeline-v42.sh`
- **Commit:** ae58996

**2. [Rule 1 - Bug] awk end-line detection matched ^## inside code fences**

- **Found during:** Task 2 smoke test (CODE_REVIEW.md OUTPUT FORMAT inserted mid-fence)
- **Issue:** awk pattern `NR > start && /^## /` matched `## Summary` inside a ` ```markdown ` code block in the existing REPORT FORMAT section
- **Fix:** Added `infence` toggle (`/^```/ { infence = !infence }`) to all end-line awk patterns
- **Files modified:** `scripts/propagate-audit-pipeline-v42.sh`
- **Commit:** ae58996

**3. [Rule 1 - Bug] Double blank lines at splice insertion points**

- **Found during:** Task 2 markdownlint run (MD012 errors)
- **Issue:** The Python rewrite prepended `\n` before fp_blk, but file content before sc_start already ended with a blank line (from `---\n\n` separator), creating a double blank
- **Fix:** Replaced manual `\n` prepending with `append_block()` helper that calls `ensure_single_trailing_blank()` to normalize to exactly one blank line before each block; added `ensure_single_trailing_blank(out)` at the `in_skip` exit point so the heading at sc_end has a proper blank line before it
- **Files modified:** `scripts/propagate-audit-pipeline-v42.sh`
- **Commit:** ae58996

**4. [Rule 1 - Bug] MD049 emphasis-style violation: `_unknown_` in audit-output-format.md**

- **Found during:** Task 2 markdownlint run
- **Issue:** `_unknown_` in the Extension to Language Fence Map table uses underscore emphasis, which violates MD049 (project requires asterisk style). The SOT passes lint on its own because markdownlint's emphasis tracking is stateful — it only triggers when a prior line in the same file contains unbalanced `.*` wildcards (e.g. `172.16-31.*` in SECURITY_AUDIT.md's SSRF checklist). The splice introduces `_unknown_` into files that have those wildcards, exposing the latent issue.
- **Fix:** Changed `_unknown_` to `*unknown*` in `components/audit-output-format.md`. Rendered output is identical; no contract bytes changed (the Phase 15 Council slot string `_pending — run /council audit-review_` is unaffected — it lives inside a ` ```text ` code block in the SOT)
- **Files modified:** `components/audit-output-format.md`
- **Commit:** ae58996

## Verification Results

| Gate | Result |
|------|--------|
| `shellcheck -S warning scripts/propagate-audit-pipeline-v42.sh` | PASS (0 findings) |
| `[ -x scripts/propagate-audit-pipeline-v42.sh ]` | PASS |
| `--dry-run` lists exactly 49 files | PASS |
| Run 1: 49 spliced, 0 errors | PASS |
| Run 2: 0 spliced, 49 already-spliced, 0 errors (idempotency) | PASS |
| All 49 files have exactly 4 `<!-- v42-splice:` sentinels | PASS |
| All 49 files contain `_pending — run /council audit-review_` (U+2014) | PASS |
| 7 DESIGN_REVIEW files have unnumbered `## SELF-CHECK (FP Recheck...)` | PASS |
| `base/SECURITY_AUDIT.md` has `## 11. SELF-CHECK (FP Recheck...)` | PASS |
| All 49 files contain `1. **Read context**` (FP-recheck step 1 marker) | PASS |
| All 49 files have `## Council Handoff` heading | PASS |
| markdownlint (project config) passes on all 49 spliced files | PASS |
| Live `templates/` directory unchanged | PASS |

## Known Stubs

None — the script is fully functional. Live `templates/` modification is deferred to Plan 16-03 by design.

## Self-Check: PASSED

- `scripts/propagate-audit-pipeline-v42.sh` exists and is executable: confirmed
- Task 1 commit `5ed88b0` exists: confirmed
- Task 2 commit `ae58996` exists: confirmed
- Live `templates/` unchanged: `git diff --name-only templates/` returns empty
