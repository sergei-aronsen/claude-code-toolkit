---
phase: 17
slug: distribution-manifest-installers-changelog
status: locked
mode: auto
created: 2026-04-25
discussed: 2026-04-25
goal: New v4.2 files reach end users via manifest, installers, and a complete [4.2.0] CHANGELOG entry
requirements:
  - DIST-01
  - DIST-02
  - DIST-03
threats:
  - T-17-01
  - T-17-02
  - T-17-03
---

# Phase 17 — Context (Auto Mode, Recommended Defaults)

## Phase Goal

Make every v4.2 artifact installable. By end of phase: a fresh `init-claude.sh` /
`update-claude.sh` install on a target project carries the FP-allowlist seed,
`/audit-skip`+`/audit-restore` commands, the structured-report `/audit` workflow, the
4-block-spliced framework prompts, and (when `setup-council.sh` runs) the
`audit-review` Council prompt. `manifest.json` is the source of truth; CHANGELOG
documents every user-visible behavior change.

## Current State (Pre-Phase Audit)

| Artifact | Status |
|----------|--------|
| `commands/audit.md` (6-phase workflow) | Already shipped in Phase 14. No change needed. |
| `commands/council.md` (`## Modes` w/ audit-review) | Already shipped in Phase 15. No change needed. |
| `commands/audit-skip.md` + `commands/audit-restore.md` (manifest) | Already in `manifest.json` (Phase 13). No change needed. |
| `templates/base/rules/audit-exceptions.md` (manifest) | File exists; manifest does NOT list it. **GAP — fix in this phase.** |
| `manifest.json` `version` field | `4.1.1` — must bump to `4.2.0`. |
| `manifest.json` `updated:` field | `2026-04-25` (already current — keep on close). |
| `scripts/council/prompts/audit-review.md` (install path) | File exists; `setup-council.sh` does NOT copy it to `~/.claude/council/prompts/`. **GAP — fix in this phase.** |
| `scripts/propagate-audit-pipeline-v42.sh` | Repo-only fan-out script; does NOT need to ship to users. No change. |
| `components/audit-fp-recheck.md` + `components/audit-output-format.md` | SOTs consumed by repo splice; manifest has no `components` section by design. No change. |
| `init-claude.sh` / `update-claude.sh` audit-exceptions seed | Already wired in Phases 13/14. No change. |
| `CHANGELOG.md` `[4.2.0]` | **MISSING — create in this phase.** |

## Decisions (Recommended Defaults Per `--auto`)

### D-01 (DIST-01) — Manifest registration of `audit-exceptions.md`

**Decision:** Add `templates/base/rules/audit-exceptions.md` to `manifest.json` under
`files.rules` (matching path style: `"path": "rules/audit-exceptions.md"`). The file is a
template-shipped seed (not generated per-project) — installers copy it like any other
rule file, then idempotently no-op if it already exists.

**Why:** The installer currently creates the seed inline (`heredoc`) inside both
`init-local.sh:317-347` and `update-claude.sh:965-1000`, but does NOT copy from
`templates/base/rules/audit-exceptions.md`. Listing the file in the manifest formalises
the inventory; installer behavior is unchanged for this phase (inline seed remains).

**Out of scope:** Refactoring the installers to read the seed body from
`templates/base/rules/audit-exceptions.md` instead of an inline heredoc — that's a
follow-up DRY pass deferred to a future hardening milestone.

### D-02 (DIST-01) — Manifest version bump

**Decision:** `version: "4.2.0"`, `updated: "<release date>"` set when this phase's
last commit lands. Aligns with the milestone-close convention used in v4.1.0 / v4.1.1.

**Why:** v4.2 contains breaking-additive changes (new commands, new audit pipeline,
mandatory Council step). Semver minor is correct (no breaking removals).

### D-03 (DIST-02) — `commands/audit.md` and `commands/council.md` documentation

**Decision:** **Already complete.** Phase 14 added the 6-phase workflow + Council
Handoff section; Phase 15 added `## Modes` with audit-review subsection to council.md.
Verify-only check: grep the markers, confirm intact, no edits.

**Why:** DIST-02 is a documentation requirement — both files already meet it. Re-doing
the work would risk drift. The Phase 17 plan validates rather than re-writes.

### D-04 (DIST-01 + new sub-requirement) — Council prompt install path

**Decision:** Extend `scripts/setup-council.sh` to copy
`scripts/council/prompts/audit-review.md` to `~/.claude/council/prompts/audit-review.md`
during install. Also extend `scripts/init-claude.sh` Council setup branch (around
line 533–553 where the `brain` shell alias is wired) to include the same copy step.
Idempotent: only copy if target missing or older.

**Why:** Without this, `/audit` Phase 5 (Council Pass) cannot dispatch in audit-review
mode on user machines — `brain.py --mode audit-review` reads the prompt from
`$COUNCIL_DIR/prompts/audit-review.md` (per Phase 15 plan). This is the missing
distribution link.

**Threat T-17-02 (council-prompt drift):** If a user has an outdated
`prompts/audit-review.md`, `/council audit-review` could send a stale prompt template
to Gemini/ChatGPT. Mitigation: `setup-council.sh` overwrites the prompt only when the
shipped version's mtime is newer (or with `--force`).

### D-05 (DIST-03) — CHANGELOG entry structure

**Decision:** Add `## [4.2.0] - 2026-04-25` (date set on milestone close) above the
`[4.1.1]` entry. Sections in order: **Added**, **Changed**, **Fixed**, **Documentation**.
Entries reference the phase that delivered each feature where useful, but stay
user-focused (no "Phase 14 plan 3 task 2" mechanics).

**Why:** Matches the prevailing CHANGELOG style (v4.1.0 / v4.1.1) and gives a clean
migration narrative for users upgrading from 4.1.x.

**Coverage requirement (DIST-03):** Every Phase 13–16 user-visible feature must appear
in at least one CHANGELOG bullet. Phase 17 plan-checker verifies via grep against a
fixed feature list (FP allowlist seed, `/audit-skip`, `/audit-restore`, 6-phase audit,
structured report schema, Council audit-review mode, 49-file template propagation,
manifest 4.2.0 bump).

### D-06 (Threat T-17-01 — version drift) — Three-file alignment gate

**Decision:** Reuse the existing `make version-align` gate (already enforced in CI
per the prior `quality.yml` audit). After Phase 17 commits land, version must be
identical across `manifest.json`, `CHANGELOG.md` heading, and the toolkit-version
echo line in `scripts/init-local.sh` (and any other version reference the gate
checks). Plan-checker confirms `make version-align` exits 0.

**Why:** v4.1.1 burned us once with a desynced version field; the gate is already
authored, this phase just leans on it.

### D-07 (Threat T-17-03 — installer breakage) — Test 16 matrix coverage

**Decision:** No new installer test required. The existing `test-matrix.sh` (Test 16)
already runs `init-local.sh` against synthetic Laravel + Next.js + generic projects
and asserts `.claude/prompts/SECURITY_AUDIT.md` lands. After Phase 17 changes, that
test must still pass (and the generic case must additionally show the seeded
`rules/audit-exceptions.md` because Phase 13 added that seed step).

**Why:** Existing harness is sufficient; expanding it would add test cost without
new coverage. Plan-checker confirms `make test` (which calls Test 16) exits 0.

### D-08 (DIST-03) — Ship date placeholder protocol

**Decision:** Initial CHANGELOG entry uses `## [4.2.0] - YYYY-MM-DD` as a literal
placeholder. The final commit in this phase (the milestone-close commit) replaces
the placeholder with the actual date. Plan-checker verifies the placeholder is
gone before accepting plan-complete.

**Why:** Avoids embedding a wrong date if the milestone slips. Mirrors the v4.1.1
release flow where the date was set on the final commit.

## Threats

| ID | Threat | Mitigation |
|----|--------|------------|
| T-17-01 | Version drift between manifest.json, CHANGELOG.md, init-local.sh — user gets ambiguous "what version am I on?" experience | `make version-align` CI gate; plan-checker requirement |
| T-17-02 | Stale Council prompt template on user machine after `setup-council.sh` upgrade — Council dispatches outdated audit-review prompt | mtime-aware copy in setup-council.sh; documented in setup-council.sh comments |
| T-17-03 | Installer regression breaks fresh-install path for v4.2 — users get incomplete .claude/ tree | Existing Test 16 matrix (test-matrix.sh) already covers Laravel/Next.js/generic; no new coverage needed |

## Plans (Provisional Breakdown — gsd-planner finalises)

- **17-01: manifest + CHANGELOG** — bump version, register rules/audit-exceptions.md, add [4.2.0] entry covering Phase 13–16 features, verify make version-align passes.
- **17-02: council prompt install** — extend setup-council.sh + init-claude.sh Council branch to copy scripts/council/prompts/audit-review.md to ~/.claude/council/prompts/. Idempotent + mtime-aware.
- **17-03: verify-and-close** — verify DIST-02 markers still intact in audit.md/council.md, replace `## [4.2.0] - YYYY-MM-DD` placeholder with real ship date, run full make check + make test gate.

Wave structure: 17-01 and 17-02 are independent (parallel). 17-03 depends on both.

## Constraints

- **No installer refactor.** The audit-exceptions seed body is currently inlined in
  both init scripts as a heredoc. Refactoring to read from the templates copy is
  deferred — keep the inline seed unchanged.
- **No Council architecture changes.** `brain.py --mode audit-review` is already
  shipped in Phase 15. This phase only fixes the install path so the prompt file
  reaches the user's machine.
- **No new tests.** Phase 16 added Test 20; Phase 17 relies entirely on existing
  Test 16 + version-align + validate-templates + Test 20 gates. New tests deferred
  to a future quality milestone.
- **Ship date placeholder must be real-dated** before phase-complete. Plan-checker
  enforces.

## Deferred (Out of Scope)

- DRY refactor of the inline audit-exceptions seed → file-copy approach (future hardening milestone)
- Adding a manifest `scripts/` or `components/` section for repo-root assets (no installer reads from those sections; would be cosmetic-only)
- Auto-update notice for users on 4.1.x upgrading to 4.2.0 (could be a separate UX phase)
- Migration script to retroactively splice user-customised prompt files (out of scope; v4.2 propagation only touches toolkit-shipped templates, not user copies)
- Localised CHANGELOG translations (deferred; English-only for the foreseeable future)

## Sign-Off

- [x] All gray areas decided per recommended defaults (--auto)
- [x] Threats identified with concrete mitigations
- [x] Plan breakdown anticipated (gsd-planner finalises)
- [x] DIST-02 status ("already complete") explicit so planner doesn't re-do work
- [x] Distribution gaps (audit-exceptions in manifest, council prompt install) made explicit

**Status:** locked, auto-mode
**Next:** `/gsd-plan-phase 17 --auto`
