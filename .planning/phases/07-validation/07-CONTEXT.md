# Phase 7: Validation - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning
**Blocker:** Phase 7.1 (README translations) must ship before Phase 7 can validate the full set.

<domain>
## Phase Boundary

Phase 7 gates the v4.0.0 release. It:

- Produces `docs/RELEASE-CHECKLIST.md` covering all 12 install matrix cells (4 modes × {fresh, upgrade-v3.x, re-run}) plus one README-translation-sync cell.
- Produces `scripts/validate-release.sh` — the runner that actually executes each cell in a sandboxed `$HOME`, asserts invariants, emits PASS/FAIL.
- Adds `make version-align` (wired into `make check`) that enforces `manifest.json` version == `CHANGELOG.md` latest-release header == `scripts/init-local.sh` runtime `--version` output.
- Finalizes `CHANGELOG.md` `[4.0.0] - TBD` header → `[4.0.0] - <release-date>`.
- Confirms VALIDATE-03: `code-reviewer` agent collision absent in every complement mode.
- Leaves the repo **ready-to-tag**: a human runs `git tag -a v4.0.0` + `git push --tags` after verifying the checklist.

**Out of scope** (captured here so downstream agents do not drift):

- Automated `git tag` / `git push` inside the phase — manual per CLAUDE.md "never push directly to main" invariant.
- Bats-based test automation — tracked as TEST-01 in v4.1 backlog.
- Docker-based cell isolation — conflicts with "POSIX shell, no runtime deps" repo invariant; plain `$HOME`-sandbox is the correct unit test.
- Translating the Phase 6 README rewrite into 8 languages — that is Phase 7.1 (inserted decimal phase). Phase 7 only *validates* the translations are synced; it does not produce them.
- Automated backup-dir hygiene (BACKUP-01/02) — v4.1.

</domain>

<decisions>
## Implementation Decisions

### Matrix Execution

- **D-01:** Hybrid execution — `scripts/validate-release.sh` auto-runs every cell; a human signs off semantic invariants in `docs/RELEASE-CHECKLIST.md` (SP hooks intact, translations synced, no agent-name collision).
- **D-02:** Fail-fast mode — on the first red cell, the runner exits non-zero and surfaces the failing assertion. Match `make check` semantics. No `--collect-all` flag for v4.0.
- **D-03:** Auto-runner asserts 4 invariants per cell (all enabled by default — Claude's discretion on wording):
  1. Every `init-claude.sh` / `update-claude.sh` / `migrate-to-complement.sh` invocation exits 0.
  2. `~/.claude/toolkit-install.json` parses with `jq`; `mode`, `detected`, `installed_files[].{path,sha256,installed_at}`, `skipped_files[].{path,reason}` all present; values match expected set for the cell's mode.
  3. `~/.claude/settings.json` keys outside TK's ownership surface are byte-identical pre/post (diff SP/GSD-installed hooks and `permissions` sections).
  4. Skip-list matches mode — `grep` installed files against `jq '.files[] | select(.conflicts_with[]?==<base>)'` and assert none of them landed in `complement-*` cells.

### Sandbox Isolation

- **D-04:** `HOME=/tmp/tk-matrix-<cell>-<unix-ts>/$HOME` per cell — matches existing `/tmp/test-claude-*` pattern in `Makefile` and `scripts/tests/`. No Docker.
- **D-05:** v3.x upgrade simulation: `git checkout <v3.0.0-era commit>` → run that tree's `init-claude.sh` into the sandbox → `git checkout main` → run current `update-claude.sh` → assert post-state. **Research surface:** no `v3.0.0` git tag exists (`git tag -l` empty); researcher must identify the canonical pre-4.0 commit (candidate: parent of `c5c8cbc docs(06-01): add CHANGELOG [4.0.0] entry and bump manifest version to 4.0.0`) and optionally annotate that commit with a lightweight tag `v3.0.0-preflight` at phase start so the runner has a stable ref. Do NOT create `v3.0.0` itself — that tag is reserved for the actual 3.0.0 release retrospectively if needed.
- **D-06:** Between-cell cleanup — each cell's sandbox dir is `rm -rf`d on entry (idempotent), NOT on exit (failure artifacts survive for post-mortem).

### Release Checklist Shape

- **D-07:** Dual surface, single source of truth:
  - `docs/RELEASE-CHECKLIST.md` — human-runnable doc. Per cell: description + bash snippet + expected output + `[ ]` checkbox. Audit-friendly.
  - `scripts/validate-release.sh` — executes the *same snippets*. Emits `PASS: <cell>` / `FAIL: <cell>: <reason>`.
  - The checklist md and the runner script must both reference the same snippet source (either copy-paste keeping them in lockstep with a `make validate-checklist-drift` target, or one generates the other). Planner picks the mechanism; the invariant is "one truth, two views".

### Release Cut Scope

- **D-08:** Phase 7 ends at **ready-to-tag**:
  - Commit-of-the-phase flips `CHANGELOG.md` `[4.0.0] - TBD` → `[4.0.0] - 2026-MM-DD` using the phase-completion date.
  - `make check` + `scripts/validate-release.sh` both pass before the commit lands.
  - `git tag -a v4.0.0 -m "Release 4.0.0"` + `git push --tags` — **manual human action**, outside the phase.
  - Rationale: annotated tags carry release notes + authorship; CLAUDE.md forbids direct-to-main and agent-cut tags cross that line.

### Version Alignment

- **D-09:** New Makefile target `version-align` (wired into `make check`):
  - Reads `manifest.json` `.version` via `jq`.
  - Reads the latest `## [X.Y.Z]` header from `CHANGELOG.md`.
  - Executes `scripts/init-local.sh --version` and parses its output.
  - Fails the target if any pair diverges.
- **D-10:** New Makefile target `translation-drift` (also in `make check`):
  - For each of `docs/readme/{de,es,fr,ja,ko,pt,ru,zh}.md`, assert line count within ±20% of `README.md` OR a TBD mechanism (header fingerprint, content hash banner) that Phase 7.1 establishes. Planner coordinates with Phase 7.1 on the contract.

### Agent Collision Check (VALIDATE-03)

- **D-11:** Enforced at **both** layers (Claude's discretion on exact impl):
  - Static: `make check` asserts no file with `conflicts_with=["superpowers"]` appears in the active install manifest for `complement-sp` / `complement-full` modes. Pure `jq` query, no install required.
  - Runtime: matrix cells for `complement-sp` and `complement-full` additionally `ls ~/.claude/agents/` and `ls ~/.claude/plugins/cache/claude-plugins-official/superpowers/*/agents/`, asserting no basename (`code-reviewer.md` specifically) appears in both.

### Translation Validation Scope

- **D-12:** Phase 7 validates *structural* sync only (line count, header set, canonical block presence). *Content* correctness of translations is owned by Phase 7.1. Phase 7 does not re-translate.

### Folded Todos

- None — no pending todos surfaced by `gsd-tools todo match-phase 7`.

### Claude's Discretion

- Exact assertion wording and bash mechanics inside `scripts/validate-release.sh` — planner picks, invariant is the 4-check list from D-03.
- Markdown table layout of `docs/RELEASE-CHECKLIST.md` — 12 cells in a single pipe-table vs per-cell `##` section; both acceptable.
- Whether `version-align` uses `jq` or `python3 -c 'import json'` — consistent with the rest of the script set is the guideline.
- Exact sandbox cleanup cadence inside a single `validate-release.sh` run (per-cell `rm -rf` vs shared base dir with cell subdirs).
- Whether to also validate `docs/INSTALL.md` matrix cells match `docs/RELEASE-CHECKLIST.md` cells (nice-to-have consistency check, not a blocker).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 7 requirements & roadmap

- `.planning/REQUIREMENTS.md` §Validation (VALIDATE-01..04) — success criteria.
- `.planning/ROADMAP.md` §Phase 7: Validation — goal + depends-on chain.
- `.planning/PROJECT.md` §Constraints + §Key Decisions — POSIX / filesystem-only / never-push-main invariants.

### Prior-phase context Phase 7 builds on

- `.planning/phases/02-foundation/02-CONTEXT.md` — manifest v2 schema, `conflicts_with` semantics, detect.sh contract, toolkit-install.json schema.
- `.planning/phases/03-install-flow/03-CONTEXT.md` — 4 modes + skip-list derivation + `--dry-run`.
- `.planning/phases/04-update-flow/04-CONTEXT.md` — 4-group summary format + drift detection + v3.x synthesis.
- `.planning/phases/05-migration/05-CONTEXT.md` — three-way diff + migrate-to-complement script surface.
- `.planning/phases/06-documentation/06-CONTEXT.md` — translation deferral decision (**now reversed** — see D-12 + Phase 7.1).

### Implementation artifacts to inspect

- `manifest.json` — `.version` (4.0.0), `conflicts_with`, `sp_equivalent`.
- `Makefile` §42-95 — existing 14-test harness, pattern for new matrix runner.
- `scripts/tests/test-{detect,state,modes,dry-run,safe-merge,update-drift,update-diff,update-summary,migrate-diff,migrate-flow,migrate-idempotent,setup-security-rtk}.sh` — invariant asserts to reuse/compose.
- `scripts/detect.sh` + `scripts/lib/install.sh` + `scripts/lib/state.sh` — sources the runner exercises.
- `scripts/validate-manifest.py` — already validates manifest; version-align target extends, not duplicates.
- `CHANGELOG.md` — `[4.0.0] - TBD` header to finalize.
- `docs/INSTALL.md` — 12-cell matrix cross-reference (produced in Phase 6).

### Upstream checks referenced for VALIDATE-03

- `~/.claude/plugins/cache/claude-plugins-official/superpowers/<ver>/agents/` — live SP agent dir.

### Out-of-repo / environmental

- Keychain item `Claude Code-credentials` — statusline-only, not touched by phase 7.
- No external API calls, no Firecrawl / Exa — validation is filesystem-local.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Makefile:42-95` test target — established pattern: cell = rm -rf → mkdir → bash init-local.sh → assertions. New `test-matrix.sh` / `validate-release.sh` should follow this shape.
- 14 test scripts in `scripts/tests/` already cover invariants atomically (detect, state, modes, dry-run, safe-merge, update drift/diff/summary, migrate diff/flow/idempotent, setup-security-rtk). Matrix runner can *compose* them per cell instead of re-implementing.
- `jq` is already a hard dep (per `.planning/codebase/STACK.md`) — safe to use for `toolkit-install.json` + `manifest.json` assertions.
- `scripts/lib/install.sh` exports the skip-list derivation logic — runner can source it for assertion 4 rather than re-computing.

### Established Patterns

- POSIX shell `set -euo pipefail` header at every script (CLAUDE.md §Code Style).
- Color constants `RED/GREEN/YELLOW/BLUE/CYAN/NC` for user-facing output.
- `[ -f "$file" ] || copy...` idempotent install pattern — matrix runner should exercise this.
- Backup-before-mutate with `<unix-ts>-<pid>` suffix (established in Phase 4 UPDATE-05) — matrix asserts backups land in expected paths.

### Integration Points

- `make check` — new `version-align` + `translation-drift` targets slot in alongside existing `shellcheck` + `mdlint` + `validate`.
- `.github/workflows/quality.yml` — runs `make check`; phase 7 additions ride the existing CI surface with no new workflow file.
- `scripts/tests/` — new `test-matrix.sh` wrapper + any helper fixtures land here; Makefile `test:` target gets a new `Test 15: full install matrix` entry.

</code_context>

<specifics>
## Specific Ideas

- User explicitly reversed the Phase 6 "translations deferred to v4.1" decision mid-discuss. Translations now ship with v4.0 via Phase 7.1. Phase 7 gates on Phase 7.1 completion.
- User preference on release cut: manual `git tag` + `git push --tags` outside phase boundary, to preserve CLAUDE.md "never push directly to main" invariant and to keep agent-cut tags out of release metadata.
- User deferred specific implementation wording of auto-runner asserts to Claude's discretion ("сам решай") — 4-invariant list (D-03) stays as the contract; exact bash/jq composition is planner choice.

</specifics>

<deferred>
## Deferred Ideas

- **v4.1:** Bats-based matrix automation (TEST-01) — stays out of v4.0.
- **v4.1:** `--clean-backups` flag (BACKUP-01) and backup-count warning (BACKUP-02) — out of scope.
- **v4.1:** Styled diff for `--dry-run` (chezmoi-grade) — locked out in REQUIREMENTS.md.
- **v4.1 or later:** Docker-per-cell reproducibility — conflicts with "POSIX shell, no runtime deps" invariant.
- **v4.1:** `docs/INSTALL.md` ↔ `docs/RELEASE-CHECKLIST.md` cell-parity auto-check — nice-to-have, not a release blocker.
- **v4.1 or later:** Auto-advance phase 7 to `git tag` / `git push --tags` — requires stronger auth-in-the-loop model than current agent harness.

### Reviewed Todos (not folded)

- None — `gsd-tools todo match-phase 7` returned empty.

</deferred>

---

*Phase: 07-validation*
*Context gathered: 2026-04-20*
