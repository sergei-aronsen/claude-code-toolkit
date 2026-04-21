# Phase 2: Foundation - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the three load-bearing primitives that Phases 3–7 depend on:

1. `scripts/detect.sh` — filesystem-only detection of installed `superpowers` (SP) and `get-shit-done` (GSD) base plugins, sourced by install/update scripts.
2. `manifest.json` v2 schema — per-file objects with `conflicts_with` / `requires_base`, bumped `manifest.version: 2`, annotated duplicates.
3. `~/.claude/toolkit-install.json` + `~/.claude/.toolkit-install.lock` — atomic install-state file with SHA256 per installed file, `mkdir`-based concurrency lock with liveness recovery.

In scope: create `scripts/detect.sh`; rewrite `manifest.json` structure under `files.*` + bump `manifest.version`; annotate every confirmed hard duplicate with `conflicts_with`; extend `Makefile` `validate` to enforce schema integrity; define state-file write protocol (read path + write path) that Phase 3 install flow will invoke.

Out of scope for this phase: four install modes (Phase 3), `--dry-run` logic (Phase 3), `setup-security.sh` safe-merge (Phase 3 SAFETY-01..04), update-flow drift detection (Phase 4), migration script (Phase 5), docs reposition (Phase 6), release validation matrix (Phase 7).

Phase 2 is **plumbing only** — produces no user-visible behavior change yet. Phase 3 is the first phase that wires these primitives into `init-claude.sh`.

</domain>

<decisions>
## Implementation Decisions

### Manifest v1↔v2 compat semantics

- **D-01:** Hard error both ways on `manifest.version` mismatch. New v4.0 scripts reading a v1 manifest exit with `ERROR: manifest.json is v1; run install to migrate to v2`; old v3.x scripts reading a v2 manifest exit with `ERROR: unsupported manifest.version N; update toolkit`. No bidirectional shim — keeps surface area small and makes the version bump a clean signal, consistent with PROJECT.md "Clean break, Conventional Commits with BREAKING CHANGE: footers" and v4.0.0 being an explicit breaking release.
- **D-02:** The v1→v2 migration happens inside `init-claude.sh` / `update-claude.sh` at install time when the script detects the shipped manifest is v2 but the user's `~/.claude/toolkit-install.json` records files installed from a v1 manifest. No separate migration tool for the manifest itself — the manifest in the repo IS v2 after this phase; users consume it via install/update.

### detect.sh remote bootstrap mechanism

- **D-03:** Remote `curl | bash` callers download `scripts/detect.sh` to a `mktemp` file, source it, and `trap 'rm -f "$DETECT_TMP"' EXIT` to clean up. Pattern: `DETECT_TMP=$(mktemp) && curl -sSL "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" && source "$DETECT_TMP"`. Explicit and debuggable — if detection misbehaves the artifact is inspectable in `/tmp` for postmortem.
- **D-04:** Local `scripts/init-local.sh` and repo-clone callers source `scripts/detect.sh` directly from its committed path (`source "$(dirname "$0")/detect.sh"`). Single canonical path on disk; remote callers reproduce it in tmp.
- **D-05:** `detect.sh` is sourced (not executed) per DETECT-04. It exports `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` as shell variables for callers to read. No stdout output during sourcing — callers decide what to print.

### SHA256 wrapper pattern

- **D-06:** STATE-04 per-file SHA256 uses `python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())'`. Consistent with Phase 1 D-05 (BUG-03 python3 JSON escape) and D-12 (BUG-05 python3 settings merge). Single JSON + hash idiom across the toolkit — one tool, one pattern.
- **D-07:** Shell-only `sha256sum || shasum -a 256` fallback rejected to avoid introducing a second cross-platform pattern alongside the python3 one already shipping in Phase 1. python3 is already a documented TK dependency (`scripts/setup-council.sh:36-50` verifies python3 >= 3.8).

### Lock liveness + stale recovery

- **D-08:** Lock is `mkdir "$HOME/.claude/.toolkit-install.lock"` (POSIX-atomic, no `flock` — `flock` is Linux-only per Out of Scope). Inside the lock dir, write `$$` to `.toolkit-install.lock/pid` as the first action after acquisition.
- **D-09:** Stale recovery: if `mkdir` fails, check `.toolkit-install.lock/pid`; if the PID is no longer alive (`kill -0 $PID 2>/dev/null` fails) OR the lock dir mtime is older than 1 hour, `rm -rf` the lock dir and retry `mkdir`. Emit `⚠ Reclaimed stale lock from PID $OLD_PID` on recovery.
- **D-10:** Lock acquisition trap: `trap 'rm -rf "$HOME/.claude/.toolkit-install.lock"' EXIT` — always release on script exit, including on error (because of `set -euo pipefail`).
- **D-11:** `mtime > 1h` uses BSD-safe `stat -f %m` (macOS) / `stat -c %Y` (Linux) wrapped in a portability shim. Pattern to copy into `detect.sh` or a `scripts/_posix.sh` helper sourced by both install paths.

### Manifest schema layout

- **D-12:** Full object migration: every entry under `files.agents[]`, `files.commands[]`, `files.prompts[]`, `files.skills[]`, `files.rules[]`, and `templates.*` upgrades from bare string to `{ "path": "...", "conflicts_with": [...]?, "requires_base": [...]? }`. `conflicts_with` and `requires_base` are optional — absent means TK-unique (always installs). Homogeneous reader path downstream; single jq expression across all file lists.
- **D-13:** `claude_md_sections` (PROJECT.md tracked separately) stays as-is in v2 — it is not per-file and does not carry conflict metadata. Only the `files.*` and `templates.*` branches migrate.
- **D-14:** Top-level `manifest.version` field bumps to `2`. Product version (`version: "3.0.0"` today, `"4.0.0"` in Phase 7) is orthogonal and stays separately. Two distinct version fields.

### conflicts_with coverage direction

- **D-15:** `gsd-phase-researcher` greps `~/.claude/plugins/cache/claude-plugins-official/superpowers/` and `~/.claude/get-shit-done/` (both installed on the dev machine) to verify, per TK duplicate file, which base plugin actually owns it. Produces an authoritative per-file map in `RESEARCH.md` that the planner copies into `manifest.json` during execution.
- **D-16:** Seed list for the researcher (from PROJECT.md §"Confirmed conflicts with SP/GSD"): `commands/debug.md`, `commands/tdd.md`, `commands/worktree.md`, `commands/verify.md`, `commands/checkpoint.md`, `commands/handoff.md`, `commands/learn.md`, `commands/audit.md`, `commands/context-prime.md`, `commands/plan.md`, `templates/base/skills/debugging/SKILL.md`, `templates/base/agents/code-reviewer.md`, `templates/base/agents/planner.md`. Total 13 entries — exceeds MANIFEST-03's "≥10".
- **D-17:** Researcher MUST also flag any duplicate not yet on the seed list that it finds while scanning SP/GSD dirs. New entries get added to both the seed list AND the manifest. This catches coverage drift now rather than in Phase 4 update-flow debugging.
- **D-18:** `conflicts_with` values are restricted to the literal strings `"superpowers"` and `"get-shit-done"`. `make validate` (MANIFEST-04) enforces the vocabulary — any other value is a hard error. No `"claude-plugins-official"`, no `"sp"` abbreviation, no typos.

### Install state file semantics

- **D-19:** `~/.claude/toolkit-install.json` is the single source of truth for what was installed and in which mode. Schema per STATE-01: `{ version, mode, detected: { superpowers: {present, version}, gsd: {present, version} }, installed_files: [{path, sha256, installed_at}], skipped_files: [{path, reason}], installed_at }`.
- **D-20:** Writes are atomic via `mktemp -t toolkit-install.XXXXXX` + `mv` per STATE-02. Never leave a half-written JSON.
- **D-21:** `version` field inside `toolkit-install.json` is a separate schema version from `manifest.version` — starts at `1` with the schema defined in this phase. Future schema changes bump this without touching manifest.
- **D-22:** `installed_at` timestamps are ISO-8601 UTC with seconds precision (`date -u +%Y-%m-%dT%H:%M:%SZ`) — BSD and GNU `date` both support this form.
- **D-23:** `skipped_files[*].reason` uses structured string `"conflicts_with:<plugin>"` (e.g., `"conflicts_with:superpowers"`) for reader programmatic use. Future update-flow (Phase 4) `SKIPPED P (reason)` output parses this directly.

### Validation extensions (`make validate`)

- **D-24:** `make validate` per MANIFEST-04 extends to: (a) every `files.*[].path` and `templates.*` path exists on disk; (b) every file in `commands/`, `templates/base/{agents,prompts,skills,rules}/` etc. is listed in manifest (no drift); (c) every `conflicts_with` value is in the allowed set `["superpowers", "get-shit-done"]`; (d) `manifest.version == 2`.
- **D-25:** The validate implementation is a `python3` helper (inline `python3 -c '...'` in Makefile or a dedicated `scripts/validate-manifest.py`) — reuses the Phase 1 python3 standardization. shellcheck stays for `scripts/`, markdownlint for `.md`, this new check sits alongside.

### Process

- **D-26:** All Phase 2 work ships on branch `feature/phase-2-foundation`, merged via one PR.
- **D-27:** One atomic commit per requirement cluster: `feat(02-01): detect.sh filesystem detection (DETECT-01..05)`, `feat(02-02): manifest v2 schema + conflicts_with annotations (MANIFEST-01..04)`, `feat(02-03): toolkit-install.json atomic writes + mkdir lock (STATE-01..05)`. Three primary commits; `feat(02): <bundle>` pattern matches Phase 1's atomic-per-bug discipline.
- **D-28:** No production code consumes these primitives until Phase 3. Phase 2 ships unit-scope verification only: (a) `detect.sh` sourced in four synthetic environments (neither / SP only / GSD only / both) returns correct `HAS_*` values; (b) `make validate` passes on the new manifest; (c) writing + reading `toolkit-install.json` in a scratch harness round-trips.
- **D-29:** detection unit tests live in `scripts/tests/test-detect.sh` (new directory — smallest possible bash test harness, POSIX-shell, zero deps). Runs in CI via `make test`. Not `bats` — TEST-01 is v2 scope per Phase 1 D-27.

### Claude's Discretion

- Exact wording of the `⚠ Reclaimed stale lock from PID $OLD_PID` warning (D-09).
- Exact filename/layout of the POSIX `stat` portability shim (D-11) — standalone helper file vs inlined function block at top of `detect.sh`.
- Whether `scripts/validate-manifest.py` is a separate file (D-25) or an inline `python3 -c` one-liner in `Makefile`. Rule of thumb: if the script exceeds ~30 lines, split it out.
- Exact error message strings for manifest version mismatch (D-01) — any clear, actionable phrasing is fine.
- Exact structure of the `scripts/tests/test-detect.sh` harness (D-29) — any approach that produces four cases and pass/fail output is acceptable.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` §"Plugin Detection" — DETECT-01..05 specifications (source of truth).
- `.planning/REQUIREMENTS.md` §"Manifest Schema" — MANIFEST-01..04 specifications.
- `.planning/REQUIREMENTS.md` §"Install State" — STATE-01..05 specifications.
- `.planning/ROADMAP.md` §"Phase 2: Foundation" — phase goal + success criteria 1–5.
- `.planning/PROJECT.md` §"Constraints" — BSD compatibility, `curl | bash` safety, filesystem-only detection invariant, python3 JSON standardization.
- `.planning/PROJECT.md` §"Context → Confirmed conflicts with SP/GSD" — seed list for MANIFEST-03 coverage (13 duplicates).

### Prior phase context (carry-forward)

- `.planning/phases/01-pre-work-bug-fixes/01-CONTEXT.md` §"Implementation Decisions → BUG-03" — python3 JSON escape pattern (source for D-06).
- `.planning/phases/01-pre-work-bug-fixes/01-CONTEXT.md` §"Implementation Decisions → BUG-05" — python3 merge + unix-timestamp backup pattern (shape for D-20).
- `.planning/phases/01-pre-work-bug-fixes/01-CONTEXT.md` §"Process" — branch per phase + atomic-per-bug commit discipline (shape for D-26/D-27).

### Files to create or extend

- `scripts/detect.sh` — NEW. `detect_superpowers()`, `detect_gsd()`, exports `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION`.
- `scripts/tests/test-detect.sh` — NEW. Four-case harness (neither/SP/GSD/both).
- `manifest.json` — SCHEMA REWRITE. Bump `manifest.version` to 2, rewrite all `files.*` entries to object form, annotate 13 duplicates with `conflicts_with`.
- `Makefile` — EXTEND `validate` target (MANIFEST-04).
- `scripts/validate-manifest.py` (if needed per D-25) — NEW, python3.
- `~/.claude/toolkit-install.json` — schema defined here, **written by Phase 3** (not Phase 2).
- `~/.claude/.toolkit-install.lock/` — directory layout defined here, **acquired by Phase 3**.

### Existing patterns to mirror

- `scripts/install-statusline.sh:31-40` — existing `jq` usage (`detect.sh` can reuse jq for settings.json `enabledPlugins` cross-reference per DETECT-03).
- `scripts/setup-security.sh:202-237` — `python3 json.load` / `json.dump` idiom (shape for D-20 atomic state writes).
- `scripts/init-claude.sh:84,430,468,479,504` — `< /dev/tty` guard idiom (copy into `detect.sh` if it ever prompts; likely not in Phase 2).
- `scripts/install-statusline.sh:104` — `cp "$file" "$file.bak.$(date +%s)"` backup idiom (reused when Phase 3 writes first `toolkit-install.json` over a hypothetical existing one).
- All existing `scripts/*.sh` open with `#!/bin/bash` + `set -euo pipefail` + ANSI color constants (`RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC`) per `.planning/codebase/CONVENTIONS.md`. `detect.sh` follows suit.

### Background analysis

- `.planning/codebase/STRUCTURE.md` — manifest layout, script list, which files are in which bucket under `files.*`.
- `.planning/codebase/CONVENTIONS.md` §"Code Style — Shell Scripts" — header comment format, function naming, error handling.
- `.planning/codebase/CONCERNS.md` — duplicate file list + manifest drift findings informing MANIFEST-03 seed.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/install-statusline.sh:104` — `cp "$file" "$file.bak.$(date +%s)"` pattern; reused if an existing `toolkit-install.json` must be backed up before rewrite in Phase 3.
- `scripts/setup-security.sh` `python3 json.load` / `json.dump` block — shape for D-20 atomic writes. Copy the idiom verbatim.
- `jq` is already a runtime dependency (`scripts/install-statusline.sh:31-40`, `templates/global/statusline.sh`) — `detect.sh`'s DETECT-03 `enabledPlugins` cross-reference can use `jq` without adding a dependency.
- `python3 >= 3.8` is already verified by `scripts/setup-council.sh:36-50` — the hashlib + json + mktemp-via-python path in D-06 / D-20 adds no new dependency.
- Color constants (`RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC`) are repeated top-of-file in every install script — `detect.sh` and any new helper file reuse the same block.

### Established Patterns

- `#!/bin/bash` + `set -euo pipefail` + ANSI color constants at top of every script.
- User-facing output uses `echo -e` with color codes, never `printf` for prose.
- Idempotent writes check `[ ! -f "$file" ]` before overwrite. For `toolkit-install.json` writes this does NOT apply (always overwrite with atomic `mv` per D-20).
- Conventional Commits: one commit per requirement cluster, branch `feature/phase-2-foundation`, never push to `main`.
- `manifest.json` is authored by humans and diff-reviewed in PRs (not regenerated). The v1→v2 rewrite is a single large hand-reviewed commit.

### Integration Points

- `make check` (Makefile) runs `shellcheck` + `markdownlint` + `validate` — MANIFEST-04 extends `validate`. New CI job surface = zero (reuses existing `make check` run in `.github/workflows/quality.yml`).
- `.github/workflows/quality.yml:70-92` `test-init-script` job — DOES NOT invoke `detect.sh` yet (Phase 2 outputs plumbing only). Phase 3 wires it in. `make test` (new, D-29) runs the `scripts/tests/test-detect.sh` harness.
- `scripts/init-claude.sh` and `scripts/update-claude.sh` — Phase 2 adds source-from-`detect.sh` call-sites as STUBS only; they export variables that Phase 3 consumes. No behavior change in Phase 2 run of either script.
- `scripts/setup-council.sh` and `scripts/install-statusline.sh` — untouched by Phase 2.

### Files NOT Touched in Phase 2

- Every file under `templates/*/` — Phase 2 does not edit template contents. It only rewrites `templates.*` entries in manifest.json to the object form.
- `CHANGELOG.md` — Phase 1 seeded an `[Unreleased]` entry; Phase 2 does not append here. Phase 6 (DOCS-03) writes the 4.0.0 entry.
- `README.md` and any doc — Phase 6 (DOCS-01..08).

</code_context>

<specifics>
## Specific Ideas

- "Phase 2 is plumbing only — zero user-visible behavior change in Phase 2." The install/update scripts can source `detect.sh` and export variables, but they must not branch on those variables until Phase 3.
- "One tool, one pattern" — python3 for JSON + hash, `mkdir` for lock, `< /dev/tty` verbatim. Phase 2 introduces zero new cross-cutting patterns.
- "Homogeneous manifest" — full object migration (D-12) so downstream jq/python readers have a single code path. No "if string else object" conditionals anywhere.
- "Test harness stays minimal" — POSIX shell, four cases, pass/fail output. No `bats`, no frameworks. If a test needs more structure, defer to v2 (TEST-01).
- "Lock liveness is belt-and-suspenders" — both PID liveness AND 1h mtime TTL. Either alone leaves failure modes; together they cover "PID reused" and "process alive but hung" separately.
- "conflicts_with vocabulary is closed" — only `"superpowers"` and `"get-shit-done"`. Validated by `make validate`. Future bases would require an explicit schema bump, preserving v4.0's clean-break shape.

</specifics>

<deferred>
## Deferred Ideas

- `claude plugin list` CLI-based detection — DETECT-FUT-01 (v2). Filesystem stays primary per PROJECT.md Out of Scope.
- Plugin version skew detection ("SP too old, suggest update") — DETECT-FUT-02 (v2).
- `bats` automated test suite — TEST-01 (v2), per Phase 1 D-27.
- Auto-cleanup of old `.claude-backup-*` directories — BACKUP-01/02 (v2).
- Dry-run preview (`--dry-run` per-file `[INSTALL]` / `[SKIP]` output) — MODE-06 belongs in Phase 3.
- Install-mode selection (`--mode <name>`, auto-recommendation) — MODE-01..05, Phase 3.
- Update-flow drift detection (new/removed manifest entries, mode change prompts) — UPDATE-01..06, Phase 4.
- Migration script for v3.x users — MIGRATE-01..06, Phase 5.
- Orchestration pattern adoption (`tk-tools.sh init <workflow>`) — ORCH-FUT-01..06 (v4.1 milestone per REQUIREMENTS.md v2).
- Styled diff for dry-run — explicitly v4.1 per PROJECT.md Out of Scope.

</deferred>

---

*Phase: 02-foundation*
*Context gathered: 2026-04-17*
