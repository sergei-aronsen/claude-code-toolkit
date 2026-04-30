---
quick_id: 260430-go5
slug: fix-all-19-audit-findings
status: complete
completed_at: 2026-04-30T12:24:00Z
branch: fix/audit-sweep-2026-04-30
total_commits: 20
total_findings: 19
findings_fixed: 18
findings_withdrawn_fp: 1
---

# SUMMARY — Audit Sweep `260430-go5`

## Outcome

All 19 PLAN.md tasks closed. 18 audit findings fixed across 31 files (+1743 / −116). One finding (H2 — `mcp.sh` join separator) **withdrawn as false positive** before sweep started: `xxd` of `scripts/lib/mcp.sh:85` confirmed the literal `\x1f` (ASCII 31) byte was already present; Read-tool renderer displayed the unit-separator as nothing, fooling the audit agent.

## Per-task results

| ID  | Finding | Commit | Status | Notes |
| --- | --- | --- | --- | --- |
| T1  | Dead-code cleanup (Gemini) | `3ce8115` | done | sha256_any unused |
| T2  | H4 — API key echo to scrollback | `144e580` | done | 3 sites; `read -rs` |
| T3  | M1 — install.sh:837 undefined `log_error` | `d38ae59` | done | inline echo |
| T4  | M3 — trap regression | `993a494` | done | propagate-audit + bootstrap |
| T5  | M5 — setup-council.sh:512 read /dev/tty | `c96bd3d` | done | `\|\| true` guard |
| T6  | M7 — quality.yml concurrency group | `ab5e768` | done | cancel-in-progress |
| T7  | M8 — BSD-only `stat -f %m` in statusline | `2dd50c1` | done | Strategy A: early-exit on non-Darwin |
| T8  | L1 — `mcp_secrets_load` keys not validated | `26c5b5a` | done | regex `^[A-Z_][A-Z0-9_]*$` |
| T9  | L2 — predictable /tmp stderr names | `8855231` | done | all 3 sites (line 892 also leaked) |
| T10 | L3 — `lib/skills.sh:147` no `/` guard | `2e58535` | done | precondition added |
| T11 | L5 — `brain.py` unsanitized LLM output | `0c1163e` | done | 3 sites including `missed_text` |
| T12 | H6 — `TK_DISPATCH_OVERRIDE_*` gate | `d7bdd0a` | done | 6 dispatchers + 7 test blocks |
| T13 | M2 — uninstall MODIFIED on empty installed-sha | `537059a` | done | reclassified as REMOVE |
| T14 | M4 — install.sh empty-array Bash 3.2 | `53fb225` | done | `${arr[@]+"${arr[@]}"}` form |
| T15 | M6 — update-claude.sh bare `mktemp` not in trap | `1805bbd` | done | EXIT trap registration |
| T16 | H1 — install.sh dispatch index mismatch | `3c59046` | done | name-based lookup + new regression test |
| T17 | H3 — `setup-security.sh` RTK.md curl\|bash | `31de6cc` | done | curl-pipe detection branch |
| T18 | L4 — curl no browser User-Agent | `5d5e470` | done | 13 scripts + 4 libs (project §2 rule) |
| T19 | H5 — `TK_TOOLKIT_REF` env var | `3125ee3` | done | 8 installers + dispatch.sh + docs/INSTALL.md |
| (meta) | planning artifacts | `d8c86ef` | done | CONTEXT/PLAN/SUMMARY/audit-* |

## Verification

- **`make check`**: PASS (exit 0). 19/19 skills PASS, 3 pre-existing FLAGs (docx/firecrawl/shadcn) — unrelated.
- **shellcheck `-S warning`**: clean across all 31 modified files.
- **markdownlint**: clean.
- **manifest schema**: valid; version-aligned to v4.8.0.
- **New test**: `scripts/tests/test-install-dispatch-h1.sh` — 6/6 PASS (proves T16 H1 fix).
- **Existing test re-runs (touched paths)**:
  - `test-mcp-secrets.sh`: 11/11
  - `test-install-skills.sh`: 15/15
  - `test-council-audit-review.sh`: 81/81
  - `test-install-tui.sh`: 43/43
  - `test-uninstall*.sh` (7 files): 75+/75+
  - `test-update-libs.sh`: 15/15
  - `test-bridges-foundation.sh`: 5/5
  - `test-bridges-install-ux.sh`: PASS
  - `test-setup-security-rtk.sh`: 3/3

## Pre-existing test flake (NOT a sweep regression)

- `test-bootstrap.sh`: 18/26 PASS — confirmed pre-existing via `git stash && bash scripts/tests/test-bootstrap.sh` BEFORE T2-T19 touched the tree. Same shape as T12 fix (test never sets `TK_TEST=1`); out of sweep scope. Documented in `deferred-items.md`.
- `test-bridges-sync.sh` S10a: BACKCOMPAT-01 step that re-runs test-bootstrap and expects PASS=26 — same upstream cause.

## Deviations from PLAN.md

- T7 M8: chose Strategy A (early-exit) over Strategy B per plan's preference annotation.
- T9 L2: line 892 had identical pattern to 355/523 — fixed all 3 instead of just 2.
- T11 L5: extended audit-mentioned 2 sites to 3 (added `missed_text` sanitization).
- T16 H1: implemented via small `_local_label_to_dispatch_name()` helper (only `get-shit-done → gsd` rename needed).
- T18 L4: chose inline `-A` injection plus shared `TK_USER_AGENT` constant in 3 libs and fallback set in every top-level installer. Echo strings displaying example commands left unmodified.
- T19 H5: `TK_TOOLKIT_PIN_SHA256` (optional checksum mode) deferred to follow-up issue per plan scope.

## Cross-audit reconciliation

Gemini's parallel audit (per user message) concluded "no critical errors, no logical holes, no resource leaks" — overly optimistic. Verification of 4 concrete claims confirmed 18/19 my-agent findings were real (H2 only was display artifact). Gemini's conclusion was based on heuristic checks (mktemp+trap pattern, shellcheck `-S warning` clean, no eval) that miss semantic bugs like:
- Undefined function reference (`log_error`)
- Index-mismatch bug fired only in single CLI scenario (Codex-only)
- Display-only API-key echo (`read -r` vs `read -rs`)
- Defense-in-depth gap (override gate parity with eval gate)
- File-path-under-curl-pipe (`dirname $0` bug)

shellcheck cannot catch these. Audit-agent + manual verification did.

## Branch state

- Branch: `fix/audit-sweep-2026-04-30`
- Range: `82d5c5c..d8c86ef`
- Files: 31 changed
- Diff: +1743 / −116
- **Not pushed.** Ready for PR.

## Suggested next step

```bash
git push -u origin fix/audit-sweep-2026-04-30
gh pr create --title "fix(audit-sweep): close 18 findings + dead code (2026-04-30)" --body-file .planning/quick/260430-go5-fix-all-19-audit-findings-h1-h6-m1-m8-l1/SUMMARY.md
```

## Follow-up items (out of scope for this sweep)

1. `TK_TOOLKIT_PIN_SHA256` optional checksum mode for advanced users (extends T19/H5).
2. `test-bootstrap.sh` 18/26 fix — pre-existing, same gating shape as H6/T12.
