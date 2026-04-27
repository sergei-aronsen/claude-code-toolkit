# Phase 22: Smart-Update Coverage for `scripts/lib/*.sh` - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `22-CONTEXT.md` — this log preserves the alternatives Claude considered.

**Date:** 2026-04-27
**Phase:** 22-smart-update-coverage-for-scripts-lib-sh
**Mode:** `--auto --chain` (Claude auto-selected recommended defaults; no user prompts shown)
**Areas auto-resolved:** Manifest Structure, Lib Coverage Scope, Install Paths, Test Strategy, Version & Release Surface, CI / Quality Gates, Backward Compatibility, Symmetric Uninstall Coverage

---

## Manifest Structure

| Option | Description | Selected |
|--------|-------------|----------|
| New `files.libs[]` array | Parallel to `files.scripts[]`. Semantic separation: scripts = entry points, libs = sourced helpers. Auto-discovered by existing `update-claude.sh` iteration loop. | ✓ |
| Extend `files.scripts[]` | Reuse existing array. Smaller manifest delta, but loses semantic distinction; future readers cannot tell entry points from helpers. | |
| New `files.helpers[]` array | Same as libs[] but different name. Less aligned with on-disk `lib/` directory naming. | |

**Selected:** New `files.libs[]` (recommended)
**Notes:** Recommended because `scripts/lib/` is the canonical on-disk location — manifest naming should mirror filesystem layout. Zero code change needed in `update-claude.sh:266` since the iteration is `to_entries[] | .value[]`.

---

## Lib Coverage Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Cover all 6 lib files | Include phase-21-added `bootstrap.sh` + `optional-plugins.sh` alongside the original 4. Treats "all sourced libs" as the unit. | ✓ |
| Cover only the 4 named in REQ | Strict ROADMAP scope: `backup.sh`, `dry-run-output.sh`, `install.sh`, `state.sh`. | |

**Selected:** Cover all 6 (recommended)
**Notes:** REQ was authored before Phase 21 shipped. Bootstrap.sh + optional-plugins.sh share the identical gap symptom. Excluding them would re-open this work as Phase 22.1; including them keeps make-check honest immediately.

---

## Install Paths

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror source layout | `scripts/lib/X.sh` → `~/.claude/scripts/lib/X.sh`. Matches existing `scripts/uninstall.sh` registration. | ✓ |
| Flatten to `~/.claude/lib/X.sh` | Shorter on-disk path, but breaks `update-claude.sh` `$CLAUDE_DIR/$path` literal prepend pattern. | |

**Selected:** Mirror source layout (recommended)
**Notes:** Zero translation logic, matches `uninstall.sh` precedent, satisfies `update-claude.sh:262` `if [[ -f "$CLAUDE_DIR/$path" ]]` guard literally.

---

## Test Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Hermetic 5-scenario test (S1–S5) | Stale-refresh, clean-untouched, fresh-install, modified-prompt, uninstall round-trip. Mirrors `test-bootstrap.sh` shape. | ✓ |
| Single-scenario stale-refresh test | Just LIB-02 minimum. Faster to write, weaker coverage. | |
| Bats-based test in `scripts/tests/matrix/` | Reuses bats infra. Higher complexity for a 1-file feature. | |

**Selected:** Hermetic 5-scenario test (recommended)
**Notes:** Mirrors Phase 21 test shape exactly (Test 28 → Test 29 progression). Provides regression coverage for symmetric uninstall path that Phase 22 implicitly extends.

---

## Version & Release Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Bump `4.3.0` → `4.4.0` + consolidated CHANGELOG | Single atomic version bump. CHANGELOG `[4.4.0]` covers Phase 21 + Phase 22 in one entry (Phase 21 unreleased). | ✓ |
| Bump to `4.3.1` patch | Treats bootstrap + lib coverage as patches. Misleading — bootstrap is a new user-facing capability. | |
| Bump to `5.0.0` major | No breaking changes occurred; misleading semver bump. | |

**Selected:** `4.4.0` minor bump (recommended)
**Notes:** Phase 21 added a new opt-in installer behaviour (BOOTSTRAP-01..04) — minor bump per semver. Phase 22 closes a coverage gap — also minor. Single release `[4.4.0]` is cleaner than two adjacent micro-releases.

---

## CI / Quality Gates

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing step `Tests 21-28` → `Tests 21-29` | Append `bash scripts/tests/test-update-libs.sh` to existing inline test runner step. | ✓ |
| Add a new dedicated job in `quality.yml` | Separate job `test-update-libs`. Increases CI matrix complexity for marginal isolation benefit. | |
| Skip CI mirror | Local Makefile only. Fails Phase 20 convention that every test gets a CI mirror. | |

**Selected:** Extend existing step (recommended)
**Notes:** Established by Phase 20 / Phase 21. Keeps CI matrix flat and the `Tests 21-N` step name consistent.

---

## Backward Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| Zero special-casing | Rely on existing `if [[ -f $CLAUDE_DIR/$path ]]` guard + `synthesize_v3_state()` iteration. First post-4.4.0 update auto-installs new libs and appends to STATE_JSON. | ✓ |
| Add migration step for STATE_JSON | Detect v4.3.x users, retro-add lib paths to `installed_files[]`. Unnecessary — same outcome as zero special-casing on first run. | |

**Selected:** Zero special-casing (recommended)
**Notes:** Idempotent by design — the install loop treats missing files as "needs install" and present-with-different-SHA as "needs refresh". STATE_JSON write happens at end of run, capturing post-state correctly.

---

## Symmetric Uninstall Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Extend test S5 to verify uninstall round-trip | Confirms libs registered in manifest are also reachable by `uninstall.sh` SHA256 classifier. Closes implicit symmetry. | ✓ |
| Defer to Phase 23 | KEEP-01/02 already cover uninstall paths. But Phase 23 doesn't test lib coverage specifically. | |
| Skip explicit test | Relies on `uninstall.sh` reading STATE_JSON correctly without coverage. Risky — Phase 20 caught Rule-1 install/uninstall gaps via similar round-trip. | |

**Selected:** Extend test S5 to verify round-trip (recommended)
**Notes:** Single hermetic test covers both LIB-01 (install/refresh) and the implicit uninstall extension — same pattern Phase 20 used to catch the `INSTALLED_PATHS[]` gap.

---

## Claude's Discretion

- Alphabetical ordering of `files.libs[]` entries by basename (matches existing array conventions).
- Omit per-lib `description:` field (existing `files.scripts[]` omits; descriptions live in lib file headers).
- TAB indentation for new Makefile target (Make requirement).

## Deferred Ideas

None — Phase 23 already covers banner consistency (BANNER-01) and uninstall recovery (KEEP-01, KEEP-02). No scope creep surfaced.
