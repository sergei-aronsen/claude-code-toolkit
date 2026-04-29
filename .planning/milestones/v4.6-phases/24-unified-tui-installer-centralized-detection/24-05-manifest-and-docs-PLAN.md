---
phase: 24
plan: 05
type: execute
wave: 3
depends_on:
  - 24-01
  - 24-02
  - 24-03
files_modified:
  - manifest.json
  - docs/INSTALL.md
autonomous: true
requirements:
  - BACKCOMPAT-01
  - TUI-07
requirements_addressed:
  - BACKCOMPAT-01
  - TUI-07
tags: manifest,docs,phase-24

must_haves:
  truths:
    - "manifest.json files.libs[] contains entries for tui.sh, detect2.sh, dispatch.sh (auto-discovered by update-claude.sh jq path)"
    - "manifest.json files.scripts[] contains an entry for install.sh (top-level script)"
    - "test-update-libs.sh stays green — the new lib entries trigger zero-special-casing in update-claude.sh per LIB-01 D-07 invariant"
    - "docs/INSTALL.md gains an `## install.sh (unified entry, v4.6+)` section with a flag table parallel to the existing init-claude.sh table"
    - "Documented flags: --yes, --yes --force, --dry-run, --force, --fail-fast, --no-color, --no-banner, --help"
    - "BACKCOMPAT-01 invariant: existing `## Mode: standalone` etc. install-matrix sections remain untouched"
    - "markdownlint passes after docs/INSTALL.md edit (MD040, MD031, MD032, MD026 strict)"
  artifacts:
    - path: "manifest.json"
      provides: "Distribution wiring: 3 new lib entries + 1 new script entry"
      contains: '"path": "scripts/lib/tui.sh", "path": "scripts/lib/detect2.sh", "path": "scripts/lib/dispatch.sh", "path": "scripts/install.sh"'
    - path: "docs/INSTALL.md"
      provides: "User-facing flag documentation for install.sh entry point"
      contains: "## install.sh (unified entry"
  key_links:
    - from: "manifest.json files.libs[]"
      to: "scripts/update-claude.sh:279 jq path"
      via: ".files | to_entries[] | .value[] | .path auto-discovers any new lib entry"
      pattern: "to_entries.*value.*path"
    - from: "docs/INSTALL.md"
      to: "scripts/install.sh user-facing entry"
      via: "documents flag set per D-31"
      pattern: "## install.sh"
---

<objective>
Wire the four new files (`scripts/lib/tui.sh`, `scripts/lib/detect2.sh`, `scripts/lib/dispatch.sh`, `scripts/install.sh`) into `manifest.json` so smart-update / update-claude.sh covers them automatically. Add a user-facing `## install.sh (unified entry, v4.6+)` section to `docs/INSTALL.md` documenting the new orchestrator's flag set.

This plan runs in Wave 3 PARALLEL with Plan 04 (different files: Plan 04 touches `scripts/install.sh` + tests + Makefile + quality.yml; Plan 05 touches `manifest.json` + `docs/INSTALL.md` — zero file overlap).

The `manifest.json` schema is `files.libs[] = [{"path": "..."}]` — flat objects with only a `path` field. The existing `update-claude.sh` jq path `.files | to_entries[] | .value[] | .path` auto-discovers new entries with zero `update-claude.sh` code change (verified RESEARCH §7 + Phase 22 LIB-01 D-07 zero-special-casing invariant; confirmed by `test-update-libs.sh` which builds a manifest fixture using the same jq path).

The `docs/INSTALL.md` addition is a new H2 section sitting AFTER the existing `## Installer Flags` table and BEFORE the `## Mode: standalone` install-matrix section. The new section contains a flag table mirroring the existing one's format, plus a brief invocation example.

Output: 2 files modified. No new files. Single conventional commit.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-CONTEXT.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md
@manifest.json
@docs/INSTALL.md
@scripts/tests/test-update-libs.sh

<canonical_refs>
- 24-PATTERNS.md §"manifest.json (modified — add 4 entries)" (lines 568-595) — exact entry shape for new libs[] + scripts[]
- 24-PATTERNS.md §"docs/INSTALL.md (modified — add install.sh section)" (lines 665-694) — flag table format + section heading style
- 24-RESEARCH.md §7 "manifest.json + update-claude.sh Integration" (lines 593-635) — auto-discovery jq path verification + LIB-01 D-07 zero-special-casing invariant
- 24-CONTEXT.md D-31 (preserve all v4.4 flags + adopt same flag names where applicable in install.sh)
- manifest.json:217-241 — existing files.scripts[] and files.libs[] entries (the canonical shape to extend)
- scripts/tests/test-update-libs.sh:74-91 — confirms jq auto-discovery of new lib entries
</canonical_refs>

<interfaces>
manifest.json schema (from RESEARCH §7 and confirmed by reading manifest.json:217-241):

```json
"scripts": [
  {"path": "scripts/uninstall.sh"}
],
"libs": [
  {"path": "scripts/lib/backup.sh"},
  {"path": "scripts/lib/bootstrap.sh"},
  {"path": "scripts/lib/dry-run-output.sh"},
  {"path": "scripts/lib/install.sh"},
  {"path": "scripts/lib/optional-plugins.sh"},
  {"path": "scripts/lib/state.sh"}
]
```

After this plan:

```json
"scripts": [
  {"path": "scripts/uninstall.sh"},
  {"path": "scripts/install.sh"}
],
"libs": [
  {"path": "scripts/lib/backup.sh"},
  {"path": "scripts/lib/bootstrap.sh"},
  {"path": "scripts/lib/detect2.sh"},
  {"path": "scripts/lib/dispatch.sh"},
  {"path": "scripts/lib/dry-run-output.sh"},
  {"path": "scripts/lib/install.sh"},
  {"path": "scripts/lib/optional-plugins.sh"},
  {"path": "scripts/lib/state.sh"},
  {"path": "scripts/lib/tui.sh"}
]
```

(The existing libs[] is sorted alphabetically by path; the three new entries slot into the right positions to preserve sort order. scripts[] is order-preserving — append `install.sh` after `uninstall.sh`.)

docs/INSTALL.md insertion point: after the existing `## Installer Flags` section (lines 29-43 of current file) and after the `### --keep-state for uninstall.sh (v4.4+)` subsection (around line 78), BEFORE the `## Mode: standalone` H2.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add 3 lib entries + 1 script entry to manifest.json (BACKCOMPAT-01 / LIB-01 D-07)</name>
  <files>manifest.json</files>

  <read_first>
    - manifest.json (lines 217-241) — current files.scripts[] and files.libs[] arrays
    - scripts/tests/test-update-libs.sh — confirms auto-discovery contract
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"manifest.json (modified)" (lines 568-595) — exact entry shape
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §7 — LIB-01 D-07 zero-special-casing invariant
  </read_first>

  <behavior>
    - manifest.json `files.scripts[]` array contains entry `{"path": "scripts/install.sh"}` appended after the existing `{"path": "scripts/uninstall.sh"}`
    - manifest.json `files.libs[]` contains three new entries (alphabetically sorted: detect2.sh, dispatch.sh, tui.sh) inserted at correct sort positions
    - JSON file remains valid (parses cleanly with `jq .` and `python3 -m json.tool`)
    - `bash scripts/tests/test-update-libs.sh` exits 0 (existing 15-assertion test stays green; new lib entries auto-discovered by the existing jq path with zero code changes — D-07 invariant)
    - `make validate` exits 0 (`scripts/validate-manifest.py` validates the schema)
  </behavior>

  <action>
Use the Edit tool to modify `manifest.json`. Two edits:

**Edit 1 — extend `scripts[]`:**

Find:

```json
    "scripts": [
      {
        "path": "scripts/uninstall.sh"
      }
    ],
```

Replace with:

```json
    "scripts": [
      {
        "path": "scripts/uninstall.sh"
      },
      {
        "path": "scripts/install.sh"
      }
    ],
```

**Edit 2 — extend `libs[]` with the three new sourced libs in alphabetical-by-path order:**

Find:

```json
    "libs": [
      {
        "path": "scripts/lib/backup.sh"
      },
      {
        "path": "scripts/lib/bootstrap.sh"
      },
      {
        "path": "scripts/lib/dry-run-output.sh"
      },
      {
        "path": "scripts/lib/install.sh"
      },
      {
        "path": "scripts/lib/optional-plugins.sh"
      },
      {
        "path": "scripts/lib/state.sh"
      }
    ]
```

Replace with:

```json
    "libs": [
      {
        "path": "scripts/lib/backup.sh"
      },
      {
        "path": "scripts/lib/bootstrap.sh"
      },
      {
        "path": "scripts/lib/detect2.sh"
      },
      {
        "path": "scripts/lib/dispatch.sh"
      },
      {
        "path": "scripts/lib/dry-run-output.sh"
      },
      {
        "path": "scripts/lib/install.sh"
      },
      {
        "path": "scripts/lib/optional-plugins.sh"
      },
      {
        "path": "scripts/lib/state.sh"
      },
      {
        "path": "scripts/lib/tui.sh"
      }
    ]
```

Critical rules:

1. **Schema discipline**: each entry is `{"path": "<relative-path>"}` — no extra fields. The existing `lib/install.sh` entry (different from the new top-level `scripts/install.sh`) does NOT have any extra fields; the new entries match.
2. **Alphabetical order in libs[]**: the three new entries slot at the correct positions — `detect2.sh` after `bootstrap.sh`, `dispatch.sh` after `detect2.sh`, `tui.sh` after `state.sh` (alphabetic).
3. **Append in scripts[]**: order is not strictly alphabetical in the existing array; append `install.sh` after `uninstall.sh` for now (this is the project convention for additive entries).
4. **DO NOT modify** the `manifest_version`, `version`, `updated`, or any other top-level field in this plan. The version bump to 4.6.0 is deferred to Phase 27 distribution phase per CONTEXT.md "Deferred Ideas" — auto-bump manifest.json version is explicitly out of scope.
5. After editing, run `python3 -m json.tool manifest.json > /dev/null` to confirm valid JSON.
6. Run `jq '.files.libs[].path' manifest.json` and confirm the new three paths appear in the output.

Implements LIB-01 D-07 zero-special-casing invariant (new libs auto-discovered by existing jq path) + BACKCOMPAT-01 distribution-side wiring (smart-update covers the new files automatically).
  </action>

  <verify>
    <automated>python3 -m json.tool manifest.json > /dev/null && jq -e '.files.libs | map(.path) | contains(["scripts/lib/tui.sh", "scripts/lib/detect2.sh", "scripts/lib/dispatch.sh"])' manifest.json && jq -e '.files.scripts | map(.path) | contains(["scripts/install.sh"])' manifest.json && bash scripts/tests/test-update-libs.sh</automated>
  </verify>

  <acceptance_criteria>
    - `manifest.json` is valid JSON (`python3 -m json.tool manifest.json > /dev/null` exits 0)
    - `jq '.files.libs[].path' manifest.json | grep -c '^"scripts/lib/(tui|detect2|dispatch).sh"$'` returns 3
    - `jq '.files.scripts[].path' manifest.json | grep -c 'scripts/install.sh'` returns 1
    - libs[] entries are alphabetical by path (verify: `jq -r '.files.libs[].path' manifest.json` output is sorted)
    - `bash scripts/tests/test-update-libs.sh` exits 0 (15 assertions still green; auto-discovery confirmed)
    - `python3 scripts/validate-manifest.py` exits 0 (manifest schema valid; from `make validate` recipe)
    - `make validate` exits 0 (full template validation)
    - manifest_version, version, updated, description fields UNCHANGED (no version bump in Phase 24)
  </acceptance_criteria>

  <done>
    Distribution side: smart-update covers the four new files. test-update-libs.sh confirms zero-special-casing invariant.
  </done>
</task>

<task type="auto">
  <name>Task 2: Add `## install.sh (unified entry, v4.6+)` section to docs/INSTALL.md (D-31)</name>
  <files>docs/INSTALL.md</files>

  <read_first>
    - docs/INSTALL.md (full file, especially lines 29-78 — Installer Flags section + subsections)
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"docs/INSTALL.md (modified)" (lines 665-694) — flag table format + section heading style
    - .markdownlint.json or .markdownlint-cli2.jsonc — markdown lint config (MD040 fenced-block lang, MD031/032 blank lines, MD026 no trailing punctuation in headings)
  </read_first>

  <behavior>
    - docs/INSTALL.md gains a new H2 section `## install.sh (unified entry, v4.6+)` between the existing `## Installer Flags` (with all its subsections through `### --keep-state for uninstall.sh (v4.4+)`) and the existing `## Mode: standalone` H2
    - The section contains a flag table parallel to the existing one's format
    - The section includes a brief invocation example showing `bash <(curl -sSL .../scripts/install.sh) --yes` and a paragraph noting BACKCOMPAT-01 (init-claude.sh URL still works)
    - markdownlint passes (`make mdlint` exits 0)
    - All v4.4 flags continue to be documented in their original sections (no deletions; D-31 invariant)
  </behavior>

  <action>
Use the Edit tool to insert the new section. Find the existing closing `---` separator BEFORE the `## Mode: standalone` heading (around line 80):

```markdown
behavioural delta is the LAST step (`rm -f $STATE_FILE`) — replaced with a `log_info`
message when `--keep-state` is set.

---

## Mode: standalone
```

Replace with:

```markdown
behavioural delta is the LAST step (`rm -f $STATE_FILE`) — replaced with a `log_info`
message when `--keep-state` is set.

---

## install.sh (unified entry, v4.6+)

`scripts/install.sh` is the single entry point for the unified TUI installer flow
introduced in v4.6. It complements the per-component `init-claude.sh` /
`setup-security.sh` / `install-statusline.sh` URLs (which all continue to work
unchanged — BACKCOMPAT-01).

### Quick start

```bash
# Interactive — TUI checklist with arrow/space/enter navigation
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)

# Non-interactive — install all uninstalled components in canonical order
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --yes

# Re-run everything regardless of detection
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --yes --force
```

### Flags

| Flag | Effect |
|------|--------|
| `--yes` | Skip TUI; install all uninstalled components in canonical order (superpowers, get-shit-done, toolkit, security, rtk, statusline) |
| `--yes --force` | Skip TUI; re-run all components regardless of detection |
| `--dry-run` | Show what would run without invoking any installer |
| `--force` | Re-run already-installed components |
| `--fail-fast` | Stop on first component failure (default behaviour: continue-on-error) |
| `--no-color` | Disable ANSI output. Also honoured via `NO_COLOR` env per [no-color.org](https://no-color.org) |
| `--no-banner` | Suppress the closing `To remove: ...` banner line. Also honoured via `NO_BANNER=1` env |
| `--help` | Print usage and exit 0 |

### TUI controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move focus up/down |
| `space` | Toggle current item (already-installed items are immutable) |
| `enter` | Confirm selection |
| `q` or `Ctrl-C` | Cancel without installing |

After `enter`, a confirmation prompt asks `Install N component(s)? [y/N]` (default
`N` cancels). Already-installed components render as `[installed ✓]` and are
pre-unchecked; uninstalled components are pre-checked.

### Backwards compatibility

All v4.4 flags on `init-claude.sh` (`--no-bootstrap`, `--no-banner`,
`TK_NO_BOOTSTRAP`, `NO_BANNER`) are preserved unchanged. The 26-assertion
`test-bootstrap.sh` regression test stays green throughout v4.6. Both entry
points coexist indefinitely; there is no deprecation schedule for
`init-claude.sh`.

When `/dev/tty` is unavailable (CI, piped install) and `--yes` is not passed,
`install.sh` exits 0 with a "no-TTY, run with `--yes` for non-interactive
install" message. This is the same fail-closed behaviour as v4.4 `bootstrap.sh`.

---

## Mode: standalone
```

Critical rules:

1. **Markdownlint compliance** (CLAUDE.md project requirement):
   - MD040: every fenced code block declares a language (`bash`, `markdown`, etc.)
   - MD031: blank line BEFORE and AFTER each fenced block
   - MD032: blank line BEFORE and AFTER each list / table
   - MD026: no trailing punctuation in headings (no `?`, `!`, `:`, `.`)
   - Linkify [no-color.org](https://no-color.org) explicitly (one of the project's existing patterns)
2. **Section position**: AFTER `### --keep-state for uninstall.sh (v4.4+)` block (closing line: "behavioural delta is the LAST step ... when `--keep-state` is set."), BEFORE `## Mode: standalone`. The existing `---` separator stays where it is (right before `## Mode: standalone`); the new section gets its own `---` separator at the end before the existing one. Net result: TWO `---` separators consecutively — one closing the new section, one opening `## Mode: standalone`. (This is the pattern the existing file uses for section boundaries.)
3. **Heading style**: H2 for the section title (`## install.sh (unified entry, v4.6+)`); H3 for subsections (`### Quick start`, `### Flags`, etc.). Mirrors existing `### --keep-state for uninstall.sh (v4.4+)` H3 pattern.
4. **TUI controls table**: documents the D-18 key bindings (no vim-j/k per D-18). The "[installed ✓]" glyph is documented per D-17.
5. **Run `make mdlint`** after the edit to confirm no lint regressions. Common fixups: trailing spaces, missing language tags on fenced blocks, blank lines around tables.

Implements D-31 documentation surface: install.sh flags documented alongside (NOT replacing) init-claude.sh flags. BACKCOMPAT-01 explicitly stated in the doc.
  </action>

  <verify>
    <automated>grep -q '## install.sh (unified entry, v4.6+)' docs/INSTALL.md && grep -q '## Mode: standalone' docs/INSTALL.md && grep -q '\-\-fail-fast' docs/INSTALL.md && grep -q 'BACKCOMPAT-01' docs/INSTALL.md && make mdlint</automated>
  </verify>

  <acceptance_criteria>
    - `docs/INSTALL.md` contains heading `## install.sh (unified entry, v4.6+)`
    - The new section sits BEFORE `## Mode: standalone` (verified by line-number check: `grep -n '^## ' docs/INSTALL.md` shows `install.sh` line < `Mode: standalone` line)
    - Section contains `### Quick start`, `### Flags`, `### TUI controls`, `### Backwards compatibility` H3 subsections
    - Flag table includes all 8 flags: `--yes`, `--yes --force`, `--dry-run`, `--force`, `--fail-fast`, `--no-color`, `--no-banner`, `--help`
    - Section explicitly mentions BACKCOMPAT-01 invariant and the 26-assertion test
    - `make mdlint` exits 0 (no lint regressions)
    - Existing `## Mode: standalone` section is UNCHANGED (verified: `git diff docs/INSTALL.md` shows additions only for the new section, no deletions in the modes section)
    - All existing `### --no-bootstrap (v4.4+)`, `### --no-banner (v4.4+)`, `### --keep-state for uninstall.sh (v4.4+)` subsections remain untouched (D-31 preserve all v4.4 flags)
  </acceptance_criteria>

  <done>
    docs/INSTALL.md documents the new `install.sh` entry alongside the existing init-claude.sh flag set. markdownlint clean.
  </done>
</task>

<task type="auto">
  <name>Task 3: Run make check + commit Wave 3 distribution wiring</name>
  <files>manifest.json, docs/INSTALL.md</files>

  <read_first>
    - Makefile (lines 36-43) — make check / lint / validate targets
    - manifest.json + docs/INSTALL.md (post-Task 1+2)
  </read_first>

  <action>
1. Run `make check` and confirm all gates pass (shellcheck + markdownlint + validate + base-plugins + version-align + translation-drift + agent-collision-static + validate-commands + cell-parity).

If `make check` fails on:
- shellcheck — Phase 24 doesn't add new shell scripts in this plan; failure indicates an unrelated regression. Stop and investigate.
- mdlint — fix the offending markdown (likely in docs/INSTALL.md). Common: missing fenced code language, missing blank lines, trailing punctuation in heading.
- validate-manifest — JSON schema mismatch in manifest.json. Run `python3 scripts/validate-manifest.py` to see the exact error.
- version-align — `version` field in manifest.json must equal CHANGELOG.md top entry version. Phase 24 does NOT bump the version (deferred to Phase 27); if CHANGELOG.md has been pre-bumped to 4.6.0 elsewhere, this check would fail and that's a Plan-05 boundary issue. STOP and ask.

2. Run BACKCOMPAT-01 + Phase 22 LIB-01 invariant tests:

```bash
bash scripts/tests/test-bootstrap.sh
bash scripts/tests/test-update-libs.sh
```

Both must exit 0. The lib-update test specifically confirms the manifest changes don't break smart-update — the new libs[] entries auto-discover via the existing `update-claude.sh:279` jq path.

3. Commit both files together as ONE atomic commit:

```bash
git add manifest.json docs/INSTALL.md
git commit -m "$(cat <<'EOF'
docs(24): wire install.sh + 3 new libs into manifest.json + INSTALL.md

manifest.json gains 4 entries:
  files.scripts[]: scripts/install.sh
  files.libs[]:    scripts/lib/{detect2,dispatch,tui}.sh

The new lib entries auto-discover via the existing update-claude.sh
jq path (.files | to_entries[] | .value[] | .path) per LIB-01 D-07
zero-special-casing invariant. test-update-libs.sh stays green: 15
assertions confirm smart-update covers the new files. Manifest version
unchanged (4.6.0 bump deferred to Phase 27 distribution phase per
CONTEXT.md "Deferred Ideas").

docs/INSTALL.md gains a new "## install.sh (unified entry, v4.6+)"
section between the existing "## Installer Flags" subsections and
"## Mode: standalone". Documents:
  - Flag set: --yes, --yes --force, --dry-run, --force, --fail-fast,
    --no-color, --no-banner, --help
  - TUI controls: ↑↓ space enter q (no vim j/k per D-18)
  - Backwards compatibility: init-claude.sh URL byte-identical;
    test-bootstrap.sh 26 assertions stay green; both entry points
    coexist indefinitely

BACKCOMPAT-01 invariant preserved across the wiring: existing
init-claude.sh / setup-security.sh / install-statusline.sh URLs
unchanged.

Refs: 24-CONTEXT.md D-31 (preserve v4.4 flags); 24-RESEARCH.md §7
(manifest auto-discovery); LIB-01 (Phase 22).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

4. After commit, run `git show --stat HEAD` to confirm only `manifest.json` and `docs/INSTALL.md` are in the commit (no other files accidentally staged).
  </action>

  <verify>
    <automated>make check && bash scripts/tests/test-bootstrap.sh && bash scripts/tests/test-update-libs.sh && git log -1 --pretty=%B | head -1 | grep -q '^docs(24): wire install.sh' && git show --stat HEAD | grep -E '^(manifest.json|docs/INSTALL.md)' | wc -l | grep -q '^[ ]*2$'</automated>
  </verify>

  <acceptance_criteria>
    - `make check` exits 0 (full quality gate green)
    - `bash scripts/tests/test-bootstrap.sh` exits 0 (BACKCOMPAT-01 — 26 assertions)
    - `bash scripts/tests/test-update-libs.sh` exits 0 (LIB-01 — auto-discovery confirmed)
    - Most recent commit subject: `docs(24): wire install.sh + 3 new libs into manifest.json + INSTALL.md`
    - Commit modifies exactly 2 files: `manifest.json`, `docs/INSTALL.md`
    - `git show HEAD -- manifest.json` shows ONLY additions to `files.libs[]` and `files.scripts[]` (no schema changes, no version bump, no removals)
    - `git show HEAD -- docs/INSTALL.md` shows ONLY a new H2 section (`## install.sh ...`) and its subsections; existing v4.4 sections unchanged
  </acceptance_criteria>

  <done>
    Plan 05 lands as a single conventional commit. Phase 24 distribution side complete: manifest auto-discovers the new libs; docs explain the new entry to users.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user → manifest.json | Read-only file consumed by update-claude.sh; no code execution from manifest content |
| user → docs/INSTALL.md | Read-only documentation; no code execution |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-24-13 | Tampering | manifest.json schema injection | accept | Schema is hardcoded `{"path": "..."}` shape; the jq query in update-claude.sh:279 explicitly extracts only `.path` strings; no eval of manifest content |
| T-24-14 | Information disclosure | docs/INSTALL.md leaking internal URL | accept | URLs are public (raw.githubusercontent.com on a public repo) |
</threat_model>

<verification>
After Task 3 completes:

```bash
# Manifest valid JSON
python3 -m json.tool manifest.json > /dev/null

# New entries present
jq '.files.libs | map(.path) | contains(["scripts/lib/tui.sh", "scripts/lib/detect2.sh", "scripts/lib/dispatch.sh"])' manifest.json
jq '.files.scripts | map(.path) | contains(["scripts/install.sh"])' manifest.json

# Auto-discovery still works (zero-special-casing invariant)
bash scripts/tests/test-update-libs.sh

# Markdownlint clean
make mdlint

# Full quality gate
make check

# BACKCOMPAT-01 invariant
bash scripts/tests/test-bootstrap.sh
```
</verification>

<success_criteria>
- `manifest.json` has new entries for `scripts/install.sh` and `scripts/lib/{tui,detect2,dispatch}.sh`
- JSON valid; auto-discovery via existing jq path works (LIB-01 D-07 zero-special-casing)
- `test-update-libs.sh` 15 assertions stay green
- `docs/INSTALL.md` has new `## install.sh (unified entry, v4.6+)` section with flag table + TUI controls + BACKCOMPAT note
- markdownlint passes
- All existing v4.4 sections in `docs/INSTALL.md` UNCHANGED (D-31)
- `test-bootstrap.sh` 26 assertions stay green (BACKCOMPAT-01)
- `make check` exits 0
- Single conventional commit `docs(24): wire install.sh + 3 new libs into manifest.json + INSTALL.md`
</success_criteria>

<output>
After Plan 05 completes, create `.planning/phases/24-unified-tui-installer-centralized-detection/24-05-SUMMARY.md` describing:
- Files modified: `manifest.json` (+4 entries), `docs/INSTALL.md` (+1 H2 section + 4 H3 subsections)
- Auto-discovery contract verification: `test-update-libs.sh` confirms zero-special-casing
- D-31 v4.4 flag preservation: existing `init-claude.sh` doc subsections untouched
- Decisions implemented: D-31 (preserve v4.4 + adopt same flag names where applicable)
- Requirements addressed: BACKCOMPAT-01 (distribution side), TUI-07 (Test 31 wiring referenced — actual test creation lives in Plan 04)
- Phase 24 deliverables complete: 5 plans, 4 new files (tui.sh, detect2.sh, dispatch.sh, install.sh), 4 modified files (setup-security.sh, install-statusline.sh, manifest.json, docs/INSTALL.md), 1 modified test (test-install-tui.sh extended), 2 CI hooks (Makefile, quality.yml)
</output>
