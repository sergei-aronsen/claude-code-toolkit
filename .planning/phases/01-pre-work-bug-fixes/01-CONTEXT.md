# Phase 1: Pre-work Bug Fixes - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix seven shipped v3.x bugs (BUG-01 through BUG-07) that would silently corrupt any complement-mode logic built on top of them in Phases 2-7. No new features, no architectural refactors — only minimal, load-bearing fixes plus structural version alignment.

In scope: `scripts/update-claude.sh`, `scripts/setup-council.sh`, `scripts/init-claude.sh`, `scripts/setup-security.sh`, `scripts/init-local.sh`, `manifest.json`, `CHANGELOG.md` `[Unreleased]` entry, `Makefile` validate target.

Out of scope for this phase: filesystem detection (Phase 2), manifest schema bump (Phase 2), install-mode logic (Phase 3), `update-claude.sh` refactor to drive install loop from `manifest.json` (Phase 4), `bats` test automation (v2).

</domain>

<decisions>
## Implementation Decisions

### BUG-01 — portable replacement for GNU `head -n -1`

- **D-01:** Replace `head -n -1` in `scripts/update-claude.sh:186-195` with `sed '$d'`. POSIX, works on BSD and GNU, drop-in one-line change. Existing regex-based smart-merge logic stays intact.
- **D-02:** HTML-anchor (`<!-- USER:section -->`) refactor of smart-merge is rejected for Phase 1 — it would break every existing v3.x user's `CLAUDE.md` and is orthogonal to the bug. If the merge logic needs replacement, it belongs in a dedicated phase (not v4.0).

### BUG-02 — `< /dev/tty` guards for interactive `read` under `curl | bash`

- **D-03:** Add `< /dev/tty` to every `read -r -p` / `read -r` call in `scripts/setup-council.sh` at lines 93, 103, 134. Pattern already established in `scripts/init-claude.sh:84,430,468,479,504` — copy verbatim.
- **D-04:** Add an early guard: if `/dev/tty` is unreadable (non-interactive CI), exit with a clear message rather than consuming the `curl` stream as input.

### BUG-03 — JSON escape for API keys in config.json heredoc

- **D-05:** Use `python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))'` to escape API key values before substituting them into the config.json template. `python3` is already a Council dependency and the same pattern is used in `scripts/setup-security.sh` for settings.json mutation — keeps codebase consistent.
- **D-06:** `jq --arg` rejected because the rest of the TK codebase standardizes on `python3` for JSON mutation (settings.json, future manifest writes). One tool, one pattern.
- **D-07:** Apply the fix to all sites: `scripts/init-claude.sh:479,504,513-525` and `scripts/setup-council.sh:178-190`.
- **D-08:** Switch the key-entry `read` calls from `-r` to `-rs` (no echo) as a paired hygiene improvement — listed in CONCERNS.md as a related finding and cheap to include in the same commit.

### BUG-04 — silent `sudo apt-get` for `tree` installation

- **D-09:** Remove `sudo` from `scripts/setup-council.sh:66`. Print the exact command (`sudo apt-get install tree`) to the user and prompt `[y/N]` whether to proceed or skip. The script itself never invokes `sudo`.
- **D-10:** Drop `2>/dev/null` — any error output must be visible so the user sees what went wrong.
- **D-11:** If the user declines or the install fails, emit a non-fatal warning (`⚠ tree not found — brain.py structure analysis will be skipped`) and continue. `tree` is optional for `brain.py`, not required.

### BUG-05 — timestamp backup of `~/.claude/settings.json` before mutation

- **D-12:** Mirror the existing pattern from `scripts/install-statusline.sh:104`: `cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"` immediately before any `python3` merge in `scripts/setup-security.sh:202-237,310-333,346-364`.
- **D-13:** On Python merge failure, restore from the backup and exit non-zero with the backup path printed.
- **D-14:** Keep backup filenames as unix-timestamp suffix (not ISO date) to match the pattern in `install-statusline.sh` exactly.

### BUG-06 — version single-source-of-truth alignment

- **D-15:** `manifest.json` remains the single source of truth for the toolkit version.
- **D-16:** `scripts/init-local.sh` reads the version from `manifest.json` at runtime via `jq -r '.version' manifest.json` (or a `sed` fallback if `jq` is absent — check on a best-effort basis). The hardcoded `VERSION="2.0.0"` constant at `scripts/init-local.sh:11` is removed.
- **D-17:** No new `VERSION` file at repo root — adds a fourth source instead of removing one.
- **D-18:** Add a `make validate` check that asserts `manifest.json:.version == grep-of-CHANGELOG-top-entry`. Fails CI if they drift. `init-local.sh` no longer needs a check because it reads from the manifest.
- **D-19:** The actual bump to `4.0.0` happens in Phase 7 (per REQUIREMENTS). Phase 1 only aligns the sources structurally so the future bump touches one file (`manifest.json`) + one changelog entry.
- **D-20:** `CHANGELOG.md` `[Unreleased]` section gets a placeholder entry in Phase 1 listing the seven BUG fixes under `### Fixed`; the version line itself remains `[Unreleased]` until Phase 7 rewrites it to `[4.0.0] - <date>`.

### BUG-07 — `commands/design.md` missing from `update-claude.sh`

- **D-21:** Phase 1 does a quick fix only: add `design.md` to the hand-maintained `for file in ...` list in `scripts/update-claude.sh:147`. Also audit the list against `manifest.json:22-53` and add any other files that drifted.
- **D-22:** The structural fix (drive the list from `manifest.json` via `jq`) is rejected here because UPDATE-02 in Phase 4 already plans to rewrite the entire install loop from the manifest. Doing it twice is throwaway work.
- **D-23:** Add a `make validate` check that every filename in `scripts/update-claude.sh`'s install loop is present in `manifest.json.files.commands` — catches this class of drift until Phase 4 removes the loop entirely.

### Process

- **D-24:** All seven bug fixes ship on a single branch `fix/phase-1-bugs`, merged via one PR at the end of the phase.
- **D-25:** One commit per bug (seven commits total). Commit subject format `fix: <one-line summary>`; body includes `Refs: BUG-XX` and the touched file:line. Git-bisect friendly, atomic revert.
- **D-26:** Verification = `make check` (shellcheck + markdownlint + validate) clean on CI (Ubuntu) + manual smoke on darwin for: BUG-01 (run `update-claude.sh` with a customized `CLAUDE.md` on BSD, diff before/after), BUG-03 (write config.json with API key containing `"` and `\`, reparse with `python3 -c 'import json; json.load(open("..."))'`), BUG-05 (confirm `settings.json.bak.<ts>` exists after `setup-security.sh`).
- **D-27:** No `bats` suite in this phase — TEST-01 is explicitly v2 scope. If a fix ever needs a runtime assertion, embed it in `make validate` instead.

### Claude's Discretion

- Exact wording of user-facing prompts (`[y/N]` for BUG-04, warnings in BUG-05 restore path)
- Exact structure of the `CHANGELOG.md` `[Unreleased]` entry bullets
- Whether the `jq`-absent fallback in BUG-06 uses `grep` + `cut` or `python3 -c 'import json; ...'`
- Whether the `make validate` extensions (D-18, D-23) land as shell one-liners or Python helpers

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` §"Pre-work Bug Fixes" — the seven BUG-XX specifications (source of truth for acceptance criteria)
- `.planning/ROADMAP.md` §"Phase 1: Pre-work Bug Fixes" — phase goal + success criteria (1-5)
- `.planning/PROJECT.md` §"Constraints" — BSD compatibility, `curl | bash` safety, never-overwrite invariants

### Files to fix (per bug)

- `scripts/update-claude.sh:186-195` — BUG-01 target (smart-merge `head -n -1`)
- `scripts/update-claude.sh:147` — BUG-07 target (hand-maintained commands list)
- `scripts/setup-council.sh:93,103,134` — BUG-02 targets (interactive `read` calls)
- `scripts/setup-council.sh:66` — BUG-04 target (silent `sudo apt-get`)
- `scripts/setup-council.sh:103,134,178-190` — BUG-03 targets (key entry + heredoc write)
- `scripts/init-claude.sh:479,504,513-525` — BUG-03 targets (key entry + heredoc write)
- `scripts/setup-security.sh:202-237,310-333,346-364` — BUG-05 targets (settings.json mutation sites)
- `scripts/init-local.sh:11,38` — BUG-06 target (hardcoded VERSION)
- `manifest.json:2-3,22-53` — BUG-06 and BUG-07 context (version + commands list)
- `CHANGELOG.md:8-10` — BUG-06 target (`[Unreleased]` block)

### Existing patterns to mirror

- `scripts/install-statusline.sh:104` — settings.json backup pattern for BUG-05
- `scripts/init-claude.sh:84,430,468,479,504` — `< /dev/tty` guard pattern for BUG-02
- `scripts/setup-security.sh:202-237` — `python3 json.load`/`json.dump` pattern for BUG-03 (JSON escape use) and BUG-05 (mutation idiom)

### Background analysis

- `.planning/codebase/CONCERNS.md` — all seven bugs documented with symptoms, triggers, and fix approach
- `.planning/codebase/CONVENTIONS.md` §"Code Style — Shell Scripts" — `set -euo pipefail`, ANSI color helpers, error handling idioms
- `.planning/codebase/STRUCTURE.md` — for cross-referencing touched files against the manifest

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/install-statusline.sh:104` — `cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"` — lift verbatim for BUG-05.
- `scripts/init-claude.sh` `< /dev/tty` pattern — lift verbatim for BUG-02 in `setup-council.sh`.
- `python3 json.load`/`json.dump` block in `scripts/setup-security.sh` — the BUG-03 JSON escape reuses the same `python3 -c` shape; keeps the toolkit on a single JSON-mutation idiom.
- `jq` is already a runtime dependency used in `scripts/install-statusline.sh:31-40` and `templates/global/statusline.sh` — BUG-06's `jq -r '.version' manifest.json` adds no new dependency.
- `manifest.json:22-53` declarative commands list — BUG-07's quick-fix audits this list against `scripts/update-claude.sh:147`; the same list becomes the source of truth for the Phase 4 structural refactor.

### Established Patterns

- All install scripts open with `#!/bin/bash` + `set -euo pipefail` + ANSI color constants (`RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `NC`). New code must match.
- User-facing messages use `echo -e` + color helpers, never `printf` for prose.
- Idempotent writes check `[ ! -f "$file" ]` before overwrite — BUG-05 backup writes must not blow away an earlier backup in the same second (but unix-ts suffix already prevents that in practice; the BUG-05 fix does not need to change the check).
- Conventional Commits with `fix:` for all seven commits; never push to `main`; branch is `fix/phase-1-bugs`.

### Integration Points

- `make check` (Makefile) runs `shellcheck` + `markdownlint` + `validate` — the new BUG-06 (D-18) and BUG-07 (D-23) validate rules plug into the existing `validate` target.
- `.github/workflows/quality.yml` runs on every PR — the new validate checks must pass there without platform-specific flags (CI is Ubuntu; fixes must also work on darwin).
- `scripts/update-claude.sh`'s in-scope edits (BUG-01, BUG-07) touch code that Phase 4 will rewrite. Fixes must be minimal and local so Phase 4 is not entangled with Phase 1 changes.
- `.claude/` directory sits in the repo (currently untracked) — do not commit it as part of Phase 1 work. The `.gitignore` hygiene finding from CONCERNS.md is a separate concern, not a BUG-XX entry.

</code_context>

<specifics>
## Specific Ideas

- "BSD-compatibility is non-negotiable" — every fix is validated on darwin before merge.
- "Stay consistent with existing toolkit idioms" — python3 for JSON, `< /dev/tty` verbatim from init-claude.sh, backup pattern verbatim from install-statusline.sh. Phase 1 introduces zero new patterns.
- "Phase 4 owns the structural refactor of `update-claude.sh`" — Phase 1 stays minimal so Phase 4 has a clean slate.
- BUG-06 result mirrors the canonical "VERSION in one place" pattern most repos follow, but uses `manifest.json` (already present) as the canonical file rather than introducing a new `VERSION` file.

</specifics>

<deferred>
## Deferred Ideas

- HTML-anchor refactor of `update-claude.sh` smart-merge — noted in CONCERNS.md as a robustness improvement. Belongs in a dedicated post-v4.0 phase (not v4.0 scope).
- Tarball-based install (`curl -L .../archive/...tar.gz | tar -xz`) to replace ~60 sequential `curl` round-trips — CONCERNS.md §"Performance Bottlenecks". Deferred to v4.1 (performance, not correctness).
- `bats` automated test suite — explicitly v2 (TEST-01 in REQUIREMENTS.md).
- Auto-cleanup of old `.claude-backup-*` directories — BACKUP-01/02 in v2.
- `.claude/` directory gitignore hygiene — CONCERNS.md §"Tech Debt". Separate concern from BUG-XX. Add in a follow-up chore commit on the same branch only if it blocks `make check`; otherwise queue for a later phase.
- Three-place advertised count drift (commands/guides/audits in `README.md`, `docs/howto/en.md`, `docs/features.md`, `init-local.sh`) — Phase 6 (DOCS-01..DOCS-04) already touches these files; fix the counts there.
- Pinning `@google/gemini-cli` and `cc-safety-net` versions — CONCERNS.md §"Dependencies at Risk". Not in v4.0 scope.
- Hardcoded model IDs (`gemini-3-pro-preview`, `gpt-5.2`) — ORCH-FUT-03 in REQUIREMENTS.md (v4.1 orchestration-pattern work).

</deferred>

---

*Phase: 01-pre-work-bug-fixes*
*Context gathered: 2026-04-17*
