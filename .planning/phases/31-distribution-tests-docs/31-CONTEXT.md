# Phase 31: Distribution + Tests + Docs - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Phase 31 ships v4.7 end-to-end:

1. **`manifest.json`** registers `scripts/lib/bridges.sh` under `files.libs[]` (alphabetized) and bumps `version` to `4.7.0`. `update-claude.sh` auto-discovers via the v4.4 LIB-01 D-07 jq path with zero new code.
2. **`scripts/tests/test-bridges.sh`** (NEW) — aggregator wrapping the 3 existing hermetic tests (`test-bridges-foundation.sh` PASS=5, `test-bridges-sync.sh` PASS=25, `test-bridges-install-ux.sh` PASS=20) with a single PASS count summary. Total assertions ≥50 (well over the ROADMAP's ≥15 target).
3. **CI integration:** `.github/workflows/quality.yml` `test-init-script` job adds `bash scripts/tests/test-bridges.sh` to the test loop.
4. **Plugin version bumps:** `plugins/{tk-skills,tk-commands,tk-framework-rules}/.claude-plugin/plugin.json` → `4.7.0`.
5. **Documentation:**
   - `docs/BRIDGES.md` (NEW) — supported CLIs, plain-copy semantics, drift behavior, opt-out, symlink-vs-copy rationale.
   - `docs/INSTALL.md` `Installer Flags` table — append `--no-bridges`, `--bridges <list>`, `--break-bridge <name>`, `--restore-bridge <name>` rows.
   - `README.md` "Killer Features" grid — add multi-CLI bridge mention.
   - `CHANGELOG.md` — consolidated `[4.7.0]` entry covering all 18 BRIDGE-* REQ-IDs.

**Out of scope:** any new feature work. Phase 31 is shipping-only.

</domain>

<decisions>
## Implementation Decisions

### Manifest registration (BRIDGE-DIST-01)

- **`scripts/lib/bridges.sh`** added to `manifest.json::files.libs[]` array, alphabetized between `bootstrap.sh` and `cli-recommendations.sh` (lex order).
- **Version field:** `manifest.json::version` → `"4.7.0"` (string, follows existing pattern).
- **`manifest_version`:** unchanged (still v2 schema).
- **No new keys:** v4.4 LIB-01 D-07 invariant — adding to `files.libs[]` is zero-cost; `update-claude.sh` auto-discovers via existing jq path `.files | to_entries[] | .value[] | .path`.

### Plugin version sync (BRIDGE-DIST-02 sub-decision)

- **3 plugins:** `plugins/tk-skills/.claude-plugin/plugin.json`, `plugins/tk-commands/.claude-plugin/plugin.json`, `plugins/tk-framework-rules/.claude-plugin/plugin.json`.
- **Version field:** all bumped from `4.6.0` to `4.7.0` to keep parity with manifest.json.
- **Mirrors v4.6 ship pattern:** plugin versions match manifest version.

### Aggregator test (BRIDGE-TEST-01)

- **`scripts/tests/test-bridges.sh`** — NEW thin wrapper. Body:
  ```bash
  #!/bin/bash
  set -euo pipefail
  cd "$(dirname "$0")/.."
  PASS=0; FAIL=0
  for suite in test-bridges-foundation.sh test-bridges-sync.sh test-bridges-install-ux.sh; do
      if bash "tests/$suite" >/tmp/bridges-out.$$ 2>&1; then
          last=$(tail -1 /tmp/bridges-out.$$)
          PASS=$((PASS + $(echo "$last" | grep -oE 'PASS=[0-9]+' | tail -1 | cut -d= -f2)))
          FAIL=$((FAIL + $(echo "$last" | grep -oE 'FAIL=[0-9]+' | tail -1 | cut -d= -f2)))
          echo "  ✓ $suite — $last"
      else
          echo "  ✗ $suite FAILED"
          cat /tmp/bridges-out.$$
          FAIL=$((FAIL + 1))
      fi
      rm -f /tmp/bridges-out.$$
  done
  echo "test-bridges (aggregate) complete: PASS=$PASS FAIL=$FAIL"
  [[ $FAIL -eq 0 ]] || exit 1
  ```
- **Coverage:** by aggregating 3 existing suites it covers 50 assertions across plain-copy, idempotency, drift `[y/N/d]`, `--break-bridge` persistence, `--no-bridges` / `TK_NO_BRIDGES`, `--bridges gemini,codex` force, uninstall round-trip — exceeding ROADMAP's ≥15 minimum.
- **Why aggregator vs new test:** the 3 existing files are well-scoped per phase; rewriting into one giant file would duplicate setup/teardown. Aggregator is the standard v4.x pattern (Phase 24 had `test-update-libs.sh` aggregating per-lib smoke checks).
- **chmod +x** on the new file.
- **shellcheck `-S warning`** clean.

### CI integration

- **`.github/workflows/quality.yml`** — append `bash scripts/tests/test-bridges.sh` to the existing test list under the `test-init-script` job (line ~110-124 region after existing `test-install-skills.sh`).
- **No matrix expansion needed** — runs alongside existing tests on Ubuntu and macOS via the existing matrix.

### docs/BRIDGES.md (BRIDGE-DOCS-01)

- **NEW file** at `docs/BRIDGES.md`. Sections:
  1. **Overview** — what the multi-CLI bridge does, why it exists
  2. **Supported CLIs** — table mapping CLI → file (Gemini → `GEMINI.md`, OpenAI Codex → `AGENTS.md`). EXPLICIT note: AGENTS.md is OpenAI standard; NOT `CODEX.md`.
  3. **How it works** — plain-copy semantics + auto-generated header banner. Link to commit history showing the locked banner content.
  4. **Drift handling** — `update-claude.sh` SHA256 comparison, `[y/N/d]` prompt for user-edited bridges, `[? ORPHANED]` when CLAUDE.md missing.
  5. **Opt-out mechanics** — `--no-bridges`, `TK_NO_BRIDGES=1`, `--break-bridge <target>`, `--restore-bridge <target>` (with examples).
  6. **Force-create** — `--bridges gemini,codex` for non-interactive installs (CI/scripted).
  7. **Why no symlink** — rationale: per-CLI customization, drift handling via SHA256 + prompt vs lock-step content.
  8. **Uninstall** — bridges removed as ordinary tracked artifacts.
  9. **Future** — branding substitution layer deferred to v4.8 (BRIDGE-FUT-01).

### docs/INSTALL.md (BRIDGE-DOCS-02)

- **Installer Flags table** (existing at line 58) gains 4 new rows in the same shape as `--no-bootstrap`:
  - `--no-bridges` | `init-claude.sh`, `init-local.sh`, `install.sh` | Skip all bridge prompts. Env var: `TK_NO_BRIDGES=1`. Mirrors `--no-bootstrap` symmetry.
  - `--bridges <list>` | `init-claude.sh`, `init-local.sh`, `install.sh` | Force-create bridges for named CLIs (comma-separated). Skips per-CLI prompt. With `--fail-fast`: absent CLI exits 1.
  - `--break-bridge <target>` | `update-claude.sh` | Sets `user_owned: true` for the named bridge target. Subsequent updates skip that bridge.
  - `--restore-bridge <target>` | `update-claude.sh` | Reverses `--break-bridge`. Next update re-syncs.
- **Sub-section** after the table (mirroring `--no-bootstrap` v4.4+ block at line 74): `### Multi-CLI Bridges (v4.7+)` explaining the feature with link to docs/BRIDGES.md.

### README.md (BRIDGE-DOCS-02)

- **"Killer Features" grid** (line 133 region) — add 1 row:
  - `🌉 Multi-CLI Bridges` | Auto-sync `CLAUDE.md` to Gemini CLI's `GEMINI.md` and OpenAI Codex's `AGENTS.md`. Drift-detected, opt-out via `--no-bridges`.
- **Links** to `docs/BRIDGES.md` from the row description.

### CHANGELOG.md [4.7.0] (BRIDGE-DIST-02)

- **Single consolidated entry** mirroring v4.4 / v4.6 pattern. Sections:
  - **Added** — bullet list of all 18 BRIDGE-* REQ-IDs grouped by category (Detection, Generation, Sync, UX, Distribution, Docs, Tests).
  - **Changed** — `write_state` 10-arg backward-compatible extension (Phase 29 D-29-01).
  - **Fixed** — Phase 29 WR-01 (uninstall `[y/N/d]` bypass), WR-02 (state file path mismatch), Phase 30 WR-01 (silent --bridges failure).
  - **Tests** — 3 new hermetic suites: foundation (5), sync (25), install-ux (20) = 50 assertions.
  - **Compatibility** — BACKCOMPAT-01 preserved across v4.6 baselines.
- **Date stamp:** `[4.7.0] - 2026-04-29` (matches the actual ship date this session).

### Code organization

- This phase touches NO `scripts/lib/*.sh` files except via the manifest entry. Pure documentation + ship-glue phase.
- All new docs in Markdown follow project markdownlint rules (MD040 code blocks language, MD031/032 blank lines, MD026 no trailing punctuation in headings).
- `make check` MUST pass green.

### Recommended plan split (3 plans, 1 wave)

All three plans have ZERO file overlap → can run parallel in a single wave:

- **Plan 31-01: Manifest + plugin versions + CHANGELOG** — Files: `manifest.json`, 3 plugin.json files, `CHANGELOG.md`.
- **Plan 31-02: Aggregator test + CI** — Files: `scripts/tests/test-bridges.sh` (NEW), `.github/workflows/quality.yml`.
- **Plan 31-03: docs/BRIDGES.md + docs/INSTALL.md + README.md** — Files: `docs/BRIDGES.md` (NEW), `docs/INSTALL.md`, `README.md`.

### Claude's Discretion

- Exact wording of CHANGELOG sections (Added / Changed / Fixed) — picker fills.
- Exact wording of docs/BRIDGES.md sections — picker fills, but section structure is locked above.
- Whether to use `### Notes` inline blocks in docs/INSTALL.md table (per existing v4.4 pattern) vs separate sub-section — picker decides.
- Whether to use a single grouped Killer Features row or split into 2 (one for project bridges, one for global) — picker decides; recommend single row for compactness.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `manifest.json:228-272` — `files.libs[]` array; alphabetized. Insertion point for `bridges.sh` entry between `bootstrap.sh` and `cli-recommendations.sh`.
- `manifest.json:3` — `"version": "4.6.0"` → bump to `"4.7.0"`.
- `plugins/tk-skills/.claude-plugin/plugin.json` (and 2 siblings) — version field → `"4.7.0"`.
- `scripts/tests/test-update-libs.sh` (v4.4 LIB-01) — meta-runner pattern; reference for `test-bridges.sh` aggregator.
- `.github/workflows/quality.yml:110-124` — test list inside `test-init-script` job; new test slots in here.
- `docs/INSTALL.md:58-95` — Installer Flags table + per-flag sub-sections (v4.4 `--no-bootstrap` block at line 74 = pattern template).
- `README.md:133` — Killer Features grid section anchor.
- `CHANGELOG.md` — has prior `[4.6.0]` and `[4.4.0]` consolidated blocks as templates.

### Established Patterns

- Manifest file additions are zero-cost — v4.4 D-07 jq path auto-discovers.
- All version bumps happen in lock-step at end of milestone (manifest + plugins + CHANGELOG together).
- CI test additions just append a line to the existing `run:` block in `quality.yml`.
- Documentation pages: `docs/X.md` with markdownlint-compliant structure (MD040 langs, MD031/032 blank lines).

### Integration Points

- `update-claude.sh:269-310` — already iterates `manifest.json` via the LIB-01 D-07 jq path. Adding `bridges.sh` to `files.libs[]` makes it ship automatically on update.
- `setup-security.sh` and `init-claude.sh` curl-fetch path — same pattern. No code change.

</code_context>

<specifics>
## Specific Ideas

- **Aggregator over rewrite:** the 3 existing tests (foundation, sync, install-ux) total 50 assertions vs the ROADMAP's ≥15 minimum. No need to write a new mega-test; just aggregate.
- **CHANGELOG entry length:** v4.6 entry is ~30 lines covering 36 REQ-IDs. v4.7 entry will be ~25 lines covering 18 REQ-IDs (more focused milestone).
- **README "Killer Features" grid is the single user-discovery touchpoint** — the README mention is what brings traffic to docs/BRIDGES.md.

</specifics>

<deferred>
## Deferred Ideas

- **`/bridges` slash command** for per-project status check — defer to v4.8.
- **Bridge marketplace metadata** in `.claude-plugin/marketplace.json` — defer.
- **Branding substitution (BRIDGE-FUT-01)** — still deferred.
- **Per-CLI tone overlays (BRIDGE-FUT-02)** — defer.
- **`update-claude.sh --bridges-only` mode (BRIDGE-FUT-05)** — defer.

</deferred>
