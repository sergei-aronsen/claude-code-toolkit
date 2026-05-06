---
phase: 38
plan: 02
subsystem: wizard-dispatch
tags: [install.sh, post-install-summary, deferred-queue, 4-field-reader, per-scope-dispatch, disp-03, disp-04]
requires:
  - TK_MCP_DEFERRED_QUEUE-4-field-tuple (plan 38-01 — mcp.sh:752 writer)
  - scripts/install.sh:487-501 (TK_MCP_DEFERRED_QUEUE setup — UNCHANGED)
provides:
  - install.sh-4-field-reader
  - install.sh-per-scope-summary
  - install.sh-two-block-dispatch
affects:
  - phase 39 (TUI per-row scope toggle — exports TK_MCP_SCOPE per row; same install.sh routing point unchanged)
  - phase 38-03 (test-mcp-wizard.sh DISP-01/02/03 hermetic test extension — exit phrases here are grep contracts)
tech-stack:
  added: []
  patterns:
    - "4-field tab-separated tuple read with empty-field-fallback (`[[ -z \"${d_scope:-}\" ]] && d_scope=\"user\"`)"
    - "Two parallel arrays + post-loop two-pass dispatch (Bash 3.2 substitute for assoc-array map)"
    - "Strict per-row case dispatch (`case \"$d_scope\" in project|user|local|*`) — wrong-scope leaks impossible (T-38-06)"
    - "Tab-row split via `IFS=$'\\t'; set -- $_row` positional reset (Bash 3.2 form, avoids `<<<` heredoc with TAB delimiter)"
    - "User-scope vs project-scope copy isolation: shell-rc auto-source block lives INSIDE `if [[ \"${#_user_rows[@]}\" -gt 0 ]]` (D-15)"
key-files:
  created: []
  modified:
    - scripts/install.sh
decisions:
  - "D-13 honored verbatim — `IFS=$'\\t' read -r d_name d_keys d_args d_scope` exact form at install.sh:808"
  - "D-14 honored verbatim — project-scope copy phrases at install.sh:884/886/905/907 are byte-identical to the spec"
  - "D-15 honored verbatim — shell-rc auto-source block stays nested inside `if [[ \"${#_user_rows[@]}\" -gt 0 ]]` (install.sh:820-878). Project-scope block writes ZERO bytes to ~/.zshrc / ~/.bash_profile / ~/.bashrc"
  - "D-16 honored verbatim — user-scope block prints first (install.sh:820-878), project-scope block prints second (install.sh:881-911); each lists only its own rows by virtue of the strict `case` dispatch at install.sh:812-815"
  - "D-10 back-compat — empty 4th field → scope=user fallback at install.sh:811 (mirrors mcp.sh:674 default; covers any pre-v5.0 row that somehow lands in the per-run mktemp queue)"
  - "shellcheck SC2034 (d_args unused) suppressed via inline `# shellcheck disable=SC2034` comment at install.sh:807 — d_args is read positionally to skip the 3rd field, never consumed"
  - "Bash 3.2 invariants: `_user_rows=()` / `_project_rows=()` plain array init at top-level (NOT `local -a`, we are not inside a function); `+=` array append; `${#arr[@]}` length guard; `set -- $_row` positional reset under `IFS=$'\\t'`; `unset` cleanup"
metrics:
  duration: ~12 minutes
  completed: 2026-05-04T18:14:00Z
  tasks_completed: 1
  files_created: 0
  files_modified: 1
  commits: 1
---

# Phase 38 Plan 02: Post-install Summary Printer Summary

**One-liner:** `scripts/install.sh:801-855` post-install summary printer becomes scope-aware — reads the 4-field deferred queue tuple landed by plan 38-01, buckets rows into user/project scope arrays via strict `case` dispatch, prints user-scope block first then project-scope block when both coexist (D-16), preserves the v4.9 user-scope copy byte-identically (regression-gated), and adds a new project-scope block per D-14 that tells the user to fill `<project>/.env` without ever touching `~/.zshrc`/`~/.bash_profile` (D-15).

## Output

Modified exactly one file: `scripts/install.sh` (lines 801-855 → 801-912 after expansion). 106 insertions, 49 deletions in a single atomic commit. No new files. The TK_MCP_DEFERRED_QUEUE setup at install.sh:487-501 stays UNCHANGED.

## Files Modified

### `scripts/install.sh`

| Region | Before | After | Purpose |
|---|---|---|---|
| install.sh:801-855 (deferred-queue summary block) | 3-field reader, single user-scope copy | 4-field reader → 2 parallel arrays → 2-pass dispatch | DISP-03 reader closure + DISP-04 per-scope summary |
| install.sh:807 (shellcheck pragma) | n/a | `# shellcheck disable=SC2034  # d_args read positionally...` | Suppress SC2034 for the 3rd-field positional discard |
| install.sh:808 (read line) | `while IFS=$'\t' read -r d_name d_keys _; do` | `while IFS=$'\t' read -r d_name d_keys d_args d_scope; do` | D-13 — 4-field reader |
| install.sh:811 (fallback) | n/a | `[[ -z "${d_scope:-}" ]] && d_scope="user"` | D-10 back-compat empty-field guard |
| install.sh:812-815 (dispatch) | n/a | `case "$d_scope" in project) _project_rows+=(...) ;; local|user|*) _user_rows+=(...) ;; esac` | Strict per-row routing — wrong-scope leaks impossible (T-38-06) |
| install.sh:820-878 (user-scope block) | inline body | wrapped in `if [[ "${#_user_rows[@]}" -gt 0 ]]; then ... fi` | D-15 isolation — shell-rc writes confined here |
| install.sh:881-911 (project-scope block) | n/a | new D-14 copy block | DISP-04 — user instructs to fill `<project>/.env` |

### Exact phrases (D-14 grep contracts)

The four exact phrases that form the test-suite grep contracts:

| Phrase | install.sh line |
|---|---|
| `Some project-scope MCPs need API keys finished:` | 884 |
| `Open <project>/.env (already stubbed; mode 0600) and fill in:` | 886 |
| `<project>/.gitignore already includes .env (toolkit added it).` | 905 |
| `Reload shell env from the project dir (or restart claude) and the MCP picks up the keys.` | 907 |

The user-scope phrase `Open ~/.claude/mcp-config.env (already stubbed; mode 0600) and fill in:` (regression gate — D-13's "preserve v4.9 verbatim" requirement) is at install.sh:851.

## Public Contract (post-install summary printer)

| Queue Contents | Behavior |
|---|---|
| Empty queue | No block printed (existing v4.9 invariant preserved — `[[ -s "$TK_MCP_DEFERRED_QUEUE" ]]` outer guard) |
| User-scope rows only | User-scope block prints (existing v4.9 copy verbatim, including shell-rc auto-source detection); no project-scope block |
| Project-scope rows only | Project-scope block prints (D-14 copy); shell rc UNTOUCHED (D-15); no user-scope block |
| Mixed user + project rows | User-scope block prints FIRST, project-scope block prints SECOND (D-16); each lists only its own rows |
| 3-field row (empty 4th field) | Treated as scope=user via fallback at install.sh:811 (D-10 back-compat) |

## Verification Performed

### Automated regression (existing tests stay green)

```text
test-mcp-wizard.sh:   Results: 21 passed, 0 failed
test-install-tui.sh:  PASS=58 FAIL=0
make shellcheck:      ✅ ShellCheck passed
```

### Acceptance-criteria substring greps (all PASS)

```text
scripts/install.sh:808:  while IFS=$'\t' read -r d_name d_keys d_args d_scope; do
scripts/install.sh:811:      [[ -z "${d_scope:-}" ]] && d_scope="user"
scripts/install.sh:812:      case "$d_scope" in
scripts/install.sh:813:          project) _project_rows+=("${d_name}"$'\t'"${d_keys}") ;;
scripts/install.sh:884:      echo -e "${YELLOW}Some project-scope MCPs need API keys finished:${NC}"
scripts/install.sh:886:      echo "  1) Open <project>/.env (already stubbed; mode 0600) and fill in:"
scripts/install.sh:905:      echo "  2) <project>/.gitignore already includes .env (toolkit added it)."
scripts/install.sh:907:      echo "  3) Reload shell env from the project dir (or restart claude) and the MCP picks up the keys."
scripts/install.sh:851:      echo "  1) Open ~/.claude/mcp-config.env (already stubbed; mode 0600) and fill in:"
scripts/install.sh:843:      _rc_marker="# claude-code-toolkit: source ~/.claude/mcp-config.env into shell env"
```

`grep -c '_user_rows=()\|_project_rows=()' scripts/install.sh` → `2` (both array inits present).

### Hermetic smoke tests (4 scenarios — all pass)

**S1 — user-scope only** (`alpha\tA_KEY, B_KEY\targs1\tuser\n`):

```text
[YELLOW]Some MCPs registered without API keys — finish setup:[NC]

  1) Open ~/.claude/mcp-config.env (already stubbed; mode 0600) and fill in:
       A_KEY=<your-key>
       B_KEY=<your-key>

  2) Shell rc already configured (auto-source line found in ~/.zshrc).

  3) Reload shell env (open a fresh terminal, or run: exec $SHELL) and start claude.
```

→ User-scope copy preserved verbatim. No project-scope block printed. ✓

**S2 — project-scope only** (`beta\tBETA_KEY\targs2\tproject\n`):

```text
[YELLOW]Some project-scope MCPs need API keys finished:[NC]

  1) Open <project>/.env (already stubbed; mode 0600) and fill in:
       BETA_KEY=<your-key>

  2) <project>/.gitignore already includes .env (toolkit added it).

  3) Reload shell env from the project dir (or restart claude) and the MCP picks up the keys.
```

→ All four D-14 exact phrases present in order. No user-scope copy printed. No shell rc touched (D-15). ✓

**S3 — BOTH scopes (D-16)** (`alpha\tA_KEY\targs1\tuser\nbeta\tBETA_KEY\targs2\tproject\n`):

```text
[YELLOW]Some MCPs registered without API keys — finish setup:[NC]

  1) Open ~/.claude/mcp-config.env (already stubbed; mode 0600) and fill in:
       A_KEY=<your-key>

  2) Shell rc already configured ...

  3) Reload shell env ...

[YELLOW]Some project-scope MCPs need API keys finished:[NC]

  1) Open <project>/.env (already stubbed; mode 0600) and fill in:
       BETA_KEY=<your-key>

  2) <project>/.gitignore already includes .env (toolkit added it).

  3) Reload shell env from the project dir ...
```

→ User-scope block prints FIRST (alpha row only), project-scope block prints SECOND (beta row only). D-16 ordering and per-block row isolation confirmed. ✓

**S4 — back-compat 3-field row** (`gamma\tGAMMA_KEY\targs3\n` — note: only 3 fields, empty 4th):

```text
[YELLOW]Some MCPs registered without API keys — finish setup:[NC]

  1) Open ~/.claude/mcp-config.env (already stubbed; mode 0600) and fill in:
       GAMMA_KEY=<your-key>

  2) Shell rc already configured ...

  3) Reload shell env ...
```

→ Empty 4th field falls back to scope=user via install.sh:811 — user-scope block printed, project-scope block NOT printed. D-10 back-compat invariant honored. ✓

## Threat Model Mitigations (T-38-03, T-38-06, T-38-07, T-38-08)

| Threat ID | Status | Evidence (file:line) |
|---|---|---|
| T-38-03 (schema/reader mismatch) | mitigated | install.sh:808 `IFS=$'\t' read -r d_name d_keys d_args d_scope` — paired with mcp.sh:752 4-field writer in same wave (D-10 same-commit invariant). install.sh:811 empty-4th-field fallback to `user` covers any pre-v5.0 producer that somehow lands in the per-run mktemp queue. Queue file is per-run mktemp (CLEANUP_PATHS at install.sh:490) → no cross-run state. |
| T-38-06 (wrong-block dispatch) | mitigated | install.sh:812-815 strict `case "$d_scope" in project) _project_rows+=(...) ;; local|user|*) _user_rows+=(...) ;; esac` — project-scope rows can never land in `_user_rows[]` and vice versa. The same `case` statement that drives the dispatch populates the buckets — no second decision point can drift. |
| T-38-07 (shell rc pollution by project-scope) | mitigated | install.sh:820 `if [[ "${#_user_rows[@]}" -gt 0 ]]; then ...` opens the user-scope branch which contains the entire shell-rc auto-source block (install.sh:824-849, with `_rc_marker="# claude-code-toolkit: source ~/.claude/mcp-config.env..."` write at install.sh:849). The project-scope branch at install.sh:881-911 makes ZERO `>>` writes outside its own echo lines — no `~/.zshrc` / `~/.bash_profile` / `~/.bashrc` mutation possible. |
| T-38-08 (copy phrase drift) | mitigated | All four D-14 exact phrases listed in `<acceptance_criteria>` (and re-checked above) match the spec letter-for-letter. install.sh:884/886/905/907 are byte-identical to the spec strings. Plan 38-03 will grep these phrases verbatim — any future drift fails the gate. |

## Decisions Honored Verbatim (D-10, D-13..D-16)

| Decision | Status | Evidence |
|---|---|---|
| D-10 back-compat (empty 4th field → user) | honored | install.sh:811 |
| D-13 4-field reader (`IFS=$'\t' read -r d_name d_keys d_args d_scope`) | honored | install.sh:808 |
| D-14 project-scope copy block (4 exact phrases) | honored | install.sh:884, 886, 905, 907 |
| D-15 shell rc isolation (no project-scope writes to rc files) | honored | install.sh:820-878 (shell-rc block confined inside user-scope `if`) |
| D-16 two-block dispatch (user first, project second) | honored | install.sh:820-878 (pass 1) → install.sh:881-911 (pass 2) |

## Deviations from Plan

**None.** Plan executed exactly as written. The single inline shellcheck pragma at install.sh:807 (SC2034 suppression for `d_args`) is technically a tiny addition the plan did not explicitly enumerate, but it is a Rule 3 (blocking — `make shellcheck` failed without it) auto-fix scoped to the same line as the read statement, and it is the project's established convention for positional discards. The plan's `<acceptance_criteria>` includes "`make shellcheck` returns 0" so the pragma was the implicit requirement.

## Self-Check: PASSED

- File `scripts/install.sh` exists and was modified (1 insertion+deletion stanza, 106/49 lines).
- Commit `f85ed32` exists in git log: `feat(38-02): install.sh post-install summary 4-field reader + per-scope dispatch`.
- `make shellcheck`: green.
- `bash scripts/tests/test-mcp-wizard.sh`: 21/21 passed (cross-wave regression gate from plan 38-01).
- `bash scripts/tests/test-install-tui.sh`: 58/58 passed.
- All 11 acceptance-criteria substring greps return matches.
- All 4 hermetic smoke scenarios (user-only / project-only / both / 3-field-back-compat) print expected output.

## Threat Flags

None. The summary printer is a stdout-only output formatter — no new network endpoints, no new auth paths, no new file access patterns at trust boundaries. The user-scope branch's `~/.zshrc`/`~/.bash_profile` write is pre-existing v4.9 surface (NOT new in plan 38-02). The project-scope branch makes zero filesystem mutations outside `echo` to stdout (D-15). The 4-field tuple read is from a per-run mktemp file owned by install.sh itself (CLEANUP_PATHS-registered).
