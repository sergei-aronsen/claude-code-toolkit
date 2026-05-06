---
phase: 38
plan: 01
subsystem: wizard-dispatch
tags: [wizard, scope-routing, project-secrets, defer-secrets, disp-01, disp-02, disp-03, defense-in-depth]
requires:
  - scripts/lib/project-secrets.sh::project_secrets_write_env
  - scripts/lib/project-secrets.sh::project_secrets_ensure_gitignore
  - scripts/lib/project-secrets.sh::project_secrets_render_mcp_env_block
  - scripts/lib/project-secrets.sh::project_secrets_validate_mcp_env_block
  - scripts/lib/project-secrets.sh::_project_secrets_load_env
  - scripts/lib/project-secrets.sh::_project_secrets_index
provides:
  - mcp_wizard_run-project-scope-branch
  - deferred-queue-4-tuple
  - lazy-project-secrets-source-guard
  - tk-project-root-test-seam
affects:
  - phase 38-02 (install.sh deferred-queue 4-field reader update — same wave)
  - phase 38-03 (test-mcp-wizard.sh DISP-01/02/03 assertion extension)
  - phase 39 (TUI per-row scope dispatcher exports TK_MCP_SCOPE per row)
tech-stack:
  added: []
  patterns:
    - "Lazy sibling-source guard with re-entrancy sentinel (_MCP_SOURCING_PROJECT_SECRETS)"
    - "Per-scope dispatch via case + if-branch (Bash 3.2 substitute for assoc-array map)"
    - "Defense-in-depth pre-claude validate_mcp_env_block at wizard call site"
    - "Sentinel-gated idempotent gitignore guard (_gi_done) — fires once per wizard run"
    - "Substitution-form argv builder for claude mcp add: -e KEY=\\${KEY} (literal $/{/} sequence)"
    - "4-field tab-separated tuple write to per-run mktemp queue file"
key-files:
  created: []
  modified:
    - scripts/lib/mcp.sh
decisions:
  - "Re-entrancy sentinel _MCP_SOURCING_PROJECT_SECRETS added (not in original plan) — required to break the symmetric cold-load source loop between mcp.sh:84 and project-secrets.sh:34. Without it, sourcing mcp.sh from a clean shell causes infinite recursion → segfault (exit 139). See Deviations below."
  - "TK_PROJECT_ROOT documented as MUST be absolute in the test-seam header comment (T-38-04 accept-not-mitigate disposition honored)"
  - "_project_root + _gi_done locals declared once at the top of the wizard work block — single source of truth for both env-collection and defer branches; both branches share the same gitignore-once invariant via the sentinel"
  - "Defense-in-depth validate_mcp_env_block call site added at the wizard layer BEFORE every claude mcp add invocation in the project-scope branch — second defense after Phase 37 lib's own SEC-05 check (T-38-01)"
  - "Project-scope branch builds repeated -e KEY=\\${KEY} flags per claude mcp add --help (D-07) — NEVER passes literal values; the literal ${KEY} substring (with $/{/} characters) reaches claude argv unchanged for .mcp.json substitution at MCP launch time"
  - "User/local-scope branches preserved byte-identical to v4.6/v4.9 — regression-gated by test-mcp-wizard.sh PASS=21 + test-mcp-secrets.sh PASS=11 staying green (T-38-02 mitigation)"
  - "Deferred queue printf format grew from 3 to 4 tab-separated fields — install.sh reader update lands in plan 38-02 within the same wave (D-10 schema-with-reader same-commit invariant; queue file is per-run mktemp so no on-disk persistence concern)"
metrics:
  duration: ~25 minutes
  completed: 2026-05-04T17:52:46Z
  tasks_completed: 3
  files_created: 0
  files_modified: 1
  commits: 3
---

# Phase 38 Plan 01: Wizard Scope-Routing Branch Summary

**One-liner:** `mcp_wizard_run` becomes scope-aware — per-scope dispatch routes secret persistence to `<project>/.env` (project) or `~/.claude/mcp-config.env` (user/local), invokes `claude mcp add -e KEY=${KEY}` substitution-form for project (literal values never reach argv), and grows the deferred-queue tuple from 3 to 4 fields so the install.sh summary printer can render scope-correct edit hints.

## Output

Modified exactly one file: `scripts/lib/mcp.sh` (1020 → 1154 lines). 159 insertions, 25 deletions across 3 atomic commits. No new files. Phase 37 library API consumed verbatim — zero changes to `scripts/lib/project-secrets.sh`.

## Files Modified

### `scripts/lib/mcp.sh`

| Region | Before | After | Purpose |
|---|---|---|---|
| Header test-seam comment block (lines 33-39) | 4 seams listed | 5 seams listed | Document new `TK_PROJECT_ROOT` (MUST be absolute) |
| Top-of-file lazy source guards (lines 65-95) | tui.sh guard only | tui.sh + project-secrets.sh guards | Lazy-source 4 Phase 37 fns; re-entrancy sentinel `_MCP_SOURCING_PROJECT_SECRETS` breaks cold-load source loop |
| `mcp_wizard_run` (lines 694-715) | scope case + scoped_args build | + `_project_root`/`_gi_done` locals + missing-lib guard | T5 mitigation: project-scope without lib → rc=1 distinct stderr (never silent fallback to user-scope) |
| Defer-secrets queue write (line 752) | `printf '%s\t%s\t%s\n'` (3 fields) | `printf '%s\t%s\t%s\t%s\n'` (4 fields) | D-10: `name\tkeys\tinstall_args\tscope` — same-wave with install.sh reader |
| Defer-secrets stub-write block (lines 762-810) | user-scope only | per-scope branch | Project: ensure-gitignore once → touch+chmod 0600 `<project>/.env` → per-key skip-if-present stub. User/local: byte-identical to v4.9. |
| Env-collection persist call (lines 858-887) | single `mcp_secrets_set` line | per-scope branch | Project: `project_secrets_ensure_gitignore` (once) + `project_secrets_write_env`; never populates `exported_env[]`. User/local: byte-identical to v4.6/v4.9. |
| Post-loop claude invocation (lines 895-933) | `env … claude mcp add` 2-branch | scope-aware 3-branch | Project: render → validate → repeated `-e KEY=${KEY}` flags. User/local: existing `env "${exported_env[@]}" claude mcp add` exec wrapper unchanged. |

## Public Contract (mcp_wizard_run extension)

| Input | Behavior |
|---|---|
| `TK_MCP_SCOPE=user` (or `local`/unset) | UNCHANGED — secrets to `~/.claude/mcp-config.env`, `env KEY=V claude mcp add` exec wrapper |
| `TK_MCP_SCOPE=project` + `TK_PROJECT_ROOT=/abs/path` | NEW — secrets to `<root>/.env` mode 0600, `.gitignore` guard once, `claude mcp add -e KEY=${KEY} --scope project ...` substitution-form |
| `TK_MCP_SCOPE=project` + Phase 37 lib unloaded | rc=1 + stderr `✗ mcp_wizard_run: project-scope requested but scripts/lib/project-secrets.sh not loaded` (T5) |
| `TK_MCP_DEFER_SECRETS=1` + project-scope | Stubs to `<root>/.env`, `.gitignore` guard once, queue 4-tuple with scope=project, claude mcp add registers without env, rc=3 |
| `TK_MCP_DEFER_SECRETS=1` + user-scope | UNCHANGED — stubs to `~/.claude/mcp-config.env`, queue 4-tuple with scope=user, rc=3 |

## Verification Performed

### Automated regression (existing tests stay green)

```text
test-mcp-wizard.sh:  Results: 21 passed, 0 failed
test-mcp-secrets.sh: Results: 11 passed, 0 failed
make shellcheck:     ShellCheck passed
```

(Plan baseline reference said "PASS=14" — actual current baseline is PASS=21; the regression invariant is "all currently-passing tests must still pass" which is satisfied.)

### Acceptance-criteria substring greps (per-task)

All Task 1, Task 2, and Task 3 acceptance-criteria `grep -F` substrings present in the final file. Sample:

```text
scripts/lib/mcp.sh:88:  if ! command -v project_secrets_write_env >/dev/null 2>&1 \
scripts/lib/mcp.sh:707: local _project_root="${TK_PROJECT_ROOT:-$(pwd)}"
scripts/lib/mcp.sh:708: local _gi_done=0   # sentinel — gate ensure_gitignore to fire ONCE per wizard run
scripts/lib/mcp.sh:714: echo -e "${RED}✗${NC} mcp_wizard_run: project-scope requested but scripts/lib/project-secrets.sh not loaded" >&2
scripts/lib/mcp.sh:752: printf '%s\t%s\t%s\t%s\n' "$name" "$_deferred_keys" "${install_args[*]}" "$_scope" \
scripts/lib/mcp.sh:910: if ! project_secrets_validate_mcp_env_block "$_env_block"; then
scripts/lib/mcp.sh:924: _env_flags+=( "-e" "${_ek}=\${${_ek}}" )
```

### Hermetic smoke tests

Project-scope happy path (TTY fixture, mock claude binary):

```text
.env contents:        CONTEXT7_API_KEY=tk_secret
.gitignore contents:  # claude-code-toolkit: never commit project-scope MCP secrets
                      .env
.argv contents:       argv: mcp add -e CONTEXT7_API_KEY=${CONTEXT7_API_KEY} --scope project context7 -- npx -y @upstash/context7-mcp
✓ Real value in .env (not in argv)
✓ Substitution-form ${CONTEXT7_API_KEY} in argv (literal NOT in argv)
✓ .gitignore guard fired
```

User-scope no-regression (same TTY fixture, scope=user):

```text
.argv contents:           argv: mcp add --scope user context7 -- npx -y @upstash/context7-mcp
                          env_CTX=user_secret  (literal value passed via env wrapper)
mcp-config.env contents:  CONTEXT7_API_KEY=user_secret
<project>/.env:           NOT created (0 bytes — empty dir)
✓ <project>/.env not created in user-scope flow
✓ no substitution-form leaked into user-scope argv
```

Defer-secrets project-scope (verify <automated> per Task 3 plan):

```text
$ TK_MCP_DEFERRED_QUEUE=… TK_MCP_DEFER_SECRETS=1 TK_MCP_SCOPE=project \
  TK_PROJECT_ROOT=… TK_MCP_CLAUDE_BIN=/bin/true mcp_wizard_run context7
queue NF=4, queue $4=project, <project>/.env grep CONTEXT7_API_KEY= → match
rc=3 (registered-without-env contract D-12 preserved with mock claude returning 0)
```

Defer-secrets user-scope no-regression:

```text
queue NF=4, queue $4=user, mcp-config.env grep CONTEXT7_API_KEY= → match
(stub destination unchanged; only queue tuple grew by 1 field)
```

## Threat Model Mitigations (T-38-01..T-38-05)

| Threat ID | Status | Evidence (file:line) |
|---|---|---|
| T-38-01 (literal secret in `.mcp.json`) | mitigated | mcp.sh:910 — `project_secrets_validate_mcp_env_block "$_env_block"` runs BEFORE `claude mcp add` invocation in project-scope branch (mcp.sh:927). Refusal → rc=1, claude never invoked. |
| T-38-02 (wrong-scope leak) | mitigated | mcp.sh:766 — `if [[ "$_scope" == "project" ]]; then ... else ... fi` strict per-scope dispatch; `collected_value` flows to `project_secrets_write_env` OR `mcp_secrets_set`, never both. Same shape at mcp.sh:862 in defer branch. Regression-gated by test-mcp-wizard.sh PASS=21 + test-mcp-secrets.sh PASS=11 (both green). |
| T-38-03 (schema/reader mismatch) | mitigated | mcp.sh:752 — `printf '%s\t%s\t%s\t%s\n' … "$_scope"` 4-tuple writer. install.sh reader update is plan 38-02 (same wave). Per-run mktemp queue → no on-disk persistence. Empty-4th-field fallback to `user` is install.sh's responsibility. |
| T-38-04 (TK_PROJECT_ROOT injection) | accept | mcp.sh:35 (header doc): `TK_PROJECT_ROOT — override pwd for project-scope dispatch (Phase 38 DISP-01); MUST be absolute`. mcp.sh:707 `_project_root="${TK_PROJECT_ROOT:-$(pwd)}"` no realpath normalization (Phase 37 D-06 boundary). Caller-controlled — exploitable only with shell-level access. |
| T-38-05 (sibling-lib missing) | mitigated | mcp.sh:713-715 — `if [[ "$_scope" == "project" ]] && ! command -v project_secrets_write_env >/dev/null 2>&1; then echo … "project-scope requested but scripts/lib/project-secrets.sh not loaded" >&2; return 1; fi` — distinct stderr, never silent fallback to user-scope. |

## Decisions Honored Verbatim (D-01..D-12)

| Decision | Status |
|---|---|
| D-01: TK_MCP_SCOPE branch at env-var collection step | mcp.sh:766 (env-collection), mcp.sh:862 (defer) |
| D-02: project_root resolution TK_PROJECT_ROOT → pwd | mcp.sh:707 |
| D-03: Lazy `command -v project_secrets_write_env` source guard | mcp.sh:88-95 (with re-entrancy sentinel — see Deviations) |
| D-04: ensure_gitignore ONCE before first write_env | mcp.sh:768-773, 869-875 (gated by `_gi_done` sentinel mcp.sh:708) |
| D-05: 3-attempt hidden-input loop UNCHANGED | mcp.sh:817-833 (loop body byte-identical to pre-Phase-38 — only persistence call swapped at line 838+) |
| D-06: render_mcp_env_block + validate_mcp_env_block BEFORE claude | mcp.sh:906-913 (refusal returns rc=1 before claude invocation at line 927) |
| D-07: claude CLI surface = repeated `-e KEY=${KEY}` (NOT --env-from-json) | mcp.sh:921-925 — `_env_flags+=( "-e" "${_ek}=\${${_ek}}" )` produces literal `${KEY}` in argv |
| D-08: project-scope does NOT use `env KEY=V claude mcp add` wrapper | mcp.sh:884-886 (project branch never appends to `exported_env[]`); the elif/else at mcp.sh:929-933 only fires for non-project scopes |
| D-09: defer-mode stubs to `<project>/.env` (printf '%s=\n') | mcp.sh:892 — same printf format as user-scope at mcp.sh:907 |
| D-10: deferred queue tuple grew from 3 to 4 fields | mcp.sh:752 — `printf '%s\t%s\t%s\t%s\n'` |
| D-11: claude mcp add registration call inside defer branch UNCHANGED | mcp.sh:828 (`"$claude_bin" mcp add "${scoped_args[@]}"`) |
| D-12: rc=3 = registered-without-env preserved | mcp.sh:836 (verified end-to-end with mock claude → rc=3) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Re-entrancy sentinel for symmetric source loop**

- **Found during:** Task 1 (initial Bash verify produced exit code 139 — segfault)
- **Issue:** mcp.sh:84 lazy-sources project-secrets.sh, but project-secrets.sh:34 lazy-sources mcp.sh. On a cold load (`source mcp.sh` from a clean shell), `_mcp_validate_value` is defined later in mcp.sh (line 446), so when the top-of-file project-secrets.sh source runs at line 88, project-secrets.sh's own guard at line 34 fires (`_mcp_validate_value` not yet defined) and re-sources mcp.sh. mcp.sh's guard at line 84 fires again (`project_secrets_write_env` still mid-source, body not yet declared) → infinite recursion → segfault.
- **Fix:** Added `_MCP_SOURCING_PROJECT_SECRETS` re-entrancy sentinel. Set to 1 before sourcing, unset after. The second-entry path sees the sentinel and skips the inner source — breaking the cycle. The Phase 37 symmetric guard does NOT need a matching sentinel because once mcp.sh has started executing, project-secrets.sh's guard inside it succeeds (functions get defined progressively as mcp.sh body executes).
- **Files modified:** scripts/lib/mcp.sh (lines 88-100)
- **Commit:** eebf599

This deviation is mechanical (Rule 3 — blocking issue prevented even loading the file) and required because the plan's `<read_first>` for Task 1 referenced "the existing tui.sh source guard at line 65-75" as the canonical template — but tui.sh's load order is unilateral (tui.sh does NOT lazy-source mcp.sh back). The project-secrets.sh ↔ mcp.sh pair IS bilateral, hence the cycle. The plan's note "(D-16) — single source of truth" assumed both libs were already loaded into the running shell. Fresh-load (test harness, install.sh) requires the sentinel.

### No Other Deviations

D-01 through D-12 honored verbatim. All exact-phrase stderr contracts preserved (`✗ mcp_wizard_run:`, `✗ refusing to write literal value into .mcp.json`, `! ${env_key} cannot be empty`).

## Phase 37 LOW-01 Investigation

The `<output>` block in the prompt asked: "fix LOW-01 from Phase 37 review IF still relevant (clearer error when sibling missing)". I read scripts/lib/project-secrets.sh:34-40 (the symmetric source guard) — it silently no-ops when `mcp.sh` sibling file is absent. The Phase 38 wizard now shoulders the "fail loudly" responsibility for the project-scope branch via the T5 mitigation at mcp.sh:713-715 (`✗ mcp_wizard_run: project-scope requested but scripts/lib/project-secrets.sh not loaded`). Modifying project-secrets.sh to add a symmetric loud-warning would be a Phase 37 backport — out of scope for plan 38-01 per `<files_modified>` frontmatter (`scripts/lib/mcp.sh` only). LOW-01 closure remains a Phase 37-VERIFICATION concern, not a Phase 38 deliverable. No changes made to project-secrets.sh.

## Deferred Items

- **Plan 38-02:** install.sh deferred-queue 4-field reader (the `IFS=$'\t' read -r d_name d_keys d_args d_scope` extension and per-scope summary block). Same-wave with this plan per D-10 schema-with-reader same-commit invariant.
- **Plan 38-03:** test-mcp-wizard.sh DISP-01/02/03 assertion extension (PASS≥20 → PASS extension target). Smoke tests already exercised happy-paths in this plan's verification block; formal hermetic test cases come next.
- **Phase 39:** TUI per-row scope toggle (TUI-SCOPE-01..05) — exports `TK_MCP_SCOPE` per row before invoking `mcp_wizard_run`, exercising the branch this plan ships.

## Self-Check: PASSED

- File `scripts/lib/mcp.sh` exists (1154 lines after changes).
- Three commits exist:
  - `eebf599` feat(38-01): add lazy project-secrets.sh source guard + scope-routing locals
  - `82eaf27` feat(38-01): scope-route env-collection persistence + claude invocation
  - `f511b5b` feat(38-01): scope-route defer-secrets stubs + grow queue tuple to 4 fields
- All Phase 37 functions resolvable from a freshly-sourced mcp.sh: `declare -F project_secrets_write_env project_secrets_ensure_gitignore project_secrets_render_mcp_env_block project_secrets_validate_mcp_env_block` → all 4 declared.
- test-mcp-wizard.sh: 21/21 passed.
- test-mcp-secrets.sh: 11/11 passed.
- make shellcheck: passed.

## Threat Flags

None. The new surface stays inside the documented `<project>/.env` and `<project>/.gitignore` write boundaries (Phase 37 lib boundary) plus the existing `claude mcp add` argv exec — no new network endpoints, no new auth paths, no new file access patterns. The substitution-form argv builder is the explicit anti-leak mechanism (T-38-01 mitigation), not a new surface.
