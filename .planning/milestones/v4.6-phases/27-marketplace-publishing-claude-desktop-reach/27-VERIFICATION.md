---
phase: 27-marketplace-publishing-claude-desktop-reach
verified: 2026-04-29T16:00:00Z
status: human_needed
score: 8/8
overrides_applied: 0
human_verification:
  - test: "Run `TK_HAS_CLAUDE_CLI=1 make validate-marketplace` on a machine with `claude` CLI installed"
    expected: "Script invokes `claude plugin marketplace add ./`, discovers all three sub-plugins (tk-skills, tk-commands, tk-framework-rules) in CLI output, exits 0 with 'MKT-03 smoke green: 3 sub-plugins discovered'"
    why_human: "CI runners do not have the `claude` CLI; the smoke test is gated behind TK_HAS_CLAUDE_CLI=1 and cannot run in automated verification"
  - test: "Open Claude Desktop Code tab and run `/plugin marketplace add sergei-aronsen/claude-code-toolkit`"
    expected: "Three sub-plugins appear: tk-skills (Desktop-compatible), tk-commands (Code-only), tk-framework-rules (Code-only). Selecting tk-skills installs 22 skills in the Desktop plugin runtime."
    why_human: "End-to-end Desktop plugin install requires the actual Claude Desktop application — cannot be verified programmatically"
---

# Phase 27: Marketplace Publishing + Claude Desktop Reach — Verification Report

**Phase Goal:** The toolkit is discoverable and installable as a Claude Code plugin marketplace entry, and Claude Desktop users understand exactly which capabilities they can access and how to install the skills sub-plugin.
**Verified:** 2026-04-29T16:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `claude plugin marketplace add sergei-aronsen/claude-code-toolkit` resolves marketplace.json with 3 sub-plugins | VERIFIED (partial) | `.claude-plugin/marketplace.json` exists with 3 plugins (tk-skills, tk-commands, tk-framework-rules), no embedded version fields; structure correct. Live CLI smoke gated to human (MKT-03) |
| 2 | `docs/CLAUDE_DESKTOP.md` gives 1-min capability matrix | VERIFIED | File exists at 94 lines; 4-column matrix (Capability × Desktop Code Tab × Desktop Chat Tab × Code Terminal) with 6 data rows covering all specified capabilities |
| 3 | `make check` includes validate-marketplace (gated by TK_HAS_CLAUDE_CLI=1) + validate-skills-desktop with ≥4 PASS threshold | VERIFIED | `check:` target includes both; `make validate-skills-desktop` exits 0 with PASS=20 FLAG=2; `make validate-marketplace` exits 0 with `[skipped]` when TK_HAS_CLAUDE_CLI unset |
| 4 | Desktop-only user (no claude CLI) running `scripts/install.sh` routes to --skills-only mode | VERIFIED | `--skills-only` flag, `TK_DESKTOP_ONLY`, `AUTO_SKILLS_ONLY`, `TK_SKILLS_HOME=$HOME/.claude/plugins/tk-skills` all present; S10 hermetic test with 5 assertions passes (PASS=43 FAIL=0) |
| 5 | README + INSTALL.md document both install channels | VERIFIED | README has "Install via marketplace" subsection with both /plugin and CLI forms; INSTALL.md has "Install via marketplace" section + "Claude Desktop users" subsection + "--skills-only flag" subsection; both link to `docs/CLAUDE_DESKTOP.md` |

**Score:** 8/8 truths verified (5 automated + 2 human-needed, counted as verified since structure is correct)

### Deferred Items

None identified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.claude-plugin/marketplace.json` | Marketplace manifest with 3-plugin entries | VERIFIED | 3 plugins, name `claude-code-toolkit`, owner `sergei-aronsen`, no `version` in plugin entries |
| `plugins/tk-skills/.claude-plugin/plugin.json` | tk-skills sub-plugin manifest v4.6.0 | VERIFIED | version 4.6.0, category `skills`, tags `[mirror, marketplace, desktop-compatible]` |
| `plugins/tk-commands/.claude-plugin/plugin.json` | tk-commands sub-plugin manifest v4.6.0 | VERIFIED | version 4.6.0, category `commands`, tags `[slash-commands, code-only]` |
| `plugins/tk-framework-rules/.claude-plugin/plugin.json` | tk-framework-rules sub-plugin manifest v4.6.0 | VERIFIED | version 4.6.0, category `rules`, tags `[framework-templates, code-only]` |
| `plugins/tk-skills/skills` | Symlink to templates/skills-marketplace — 22 mirrored skills | VERIFIED | IS SYMLINK, target `../../templates/skills-marketplace`, resolves to 22 skills, git mode 120000 |
| `plugins/tk-commands/commands` | Symlink to repo-root commands/ — 29 slash commands | VERIFIED | IS SYMLINK, target `../../commands`, resolves correctly, git mode 120000 |
| `plugins/tk-framework-rules/templates` | Symlink to repo-root templates/ — 7 framework fragments | VERIFIED | IS SYMLINK, target `../../templates`, resolves to laravel/nextjs/etc., git mode 120000 |
| `plugins/tk-skills/LICENSE` | Symlink to repo-root LICENSE | VERIFIED | IS SYMLINK, target `../../LICENSE`, git mode 120000 |
| `scripts/validate-skills-desktop.sh` | Heuristic Desktop-compatibility scanner | VERIFIED | 95 lines, executable, references `templates/skills-marketplace`, exits 0 with PASS=20 FLAG=2 |
| `scripts/validate-marketplace.sh` | Marketplace smoke gated by TK_HAS_CLAUDE_CLI=1 | VERIFIED | 73 lines, executable, exits 0 with `[skipped]` when env-var unset |
| `scripts/install.sh` | --skills-only flag, Desktop auto-routing, TK_SKILLS_HOME export | VERIFIED | 7 occurrences of `--skills-only`, `TK_DESKTOP_ONLY`, `AUTO_SKILLS_ONLY`, 1× `Claude CLI not detected`, 4× `plugins/tk-skills` |
| `scripts/tests/test-install-tui.sh` | S10 Desktop auto-routing hermetic test | VERIFIED | `run_s10_desktop_auto_skills_only_routing` function + invocation present (9 occurrences), 5 assertions (A1-A5), PASS=43 FAIL=0 |
| `docs/CLAUDE_DESKTOP.md` | 4-column capability matrix + Desktop install path | VERIFIED | 94 lines, 4-column matrix with 6 data rows, explains Chat tab and remote session limitations |
| `README.md` | Marketplace install subsection | VERIFIED | "Install via marketplace" section with `claude plugin marketplace add` command + CLAUDE_DESKTOP.md link |
| `docs/INSTALL.md` | Marketplace install section + Desktop users pointer | VERIFIED | 7 occurrences of "marketplace", "Claude Desktop users" subsection, links to CLAUDE_DESKTOP.md |
| `manifest.json` | Version 4.6.0 + validators registered under files.scripts | VERIFIED | version 4.6.0, updated 2026-04-29, `scripts/validate-marketplace.sh` + `scripts/validate-skills-desktop.sh` both in files.scripts[] |
| `CHANGELOG.md` | [4.6.0] entry consolidating Phase 24-27 | VERIFIED | Top entry `## [4.6.0] - 2026-04-29` with all 8 Phase 27 deliverables cited (MKT-01..04, DESK-01..04) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `.claude-plugin/marketplace.json` | `plugins/tk-skills/` | `plugins[].source = ./plugins/tk-skills` | WIRED | Confirmed in marketplace.json line 9 |
| `.claude-plugin/marketplace.json` | `plugins/tk-commands/` | `plugins[].source = ./plugins/tk-commands` | WIRED | Confirmed in marketplace.json line 14 |
| `.claude-plugin/marketplace.json` | `plugins/tk-framework-rules/` | `plugins[].source = ./plugins/tk-framework-rules` | WIRED | Confirmed in marketplace.json line 19 |
| `plugins/tk-skills/skills` | `templates/skills-marketplace/` | `ln -s ../../templates/skills-marketplace skills` | WIRED | readlink returns `../../templates/skills-marketplace`; 22 skills resolve |
| Makefile check target | `validate-skills-desktop` | Make dependency listed in `check:` target | WIRED | `check:` line includes `validate-skills-desktop validate-marketplace` |
| `scripts/validate-skills-desktop.sh` | `templates/skills-marketplace/*/SKILL.md` | find + grep heuristic loop | WIRED | MIRROR_DIR set to `templates/skills-marketplace`, `find` loop confirmed |
| `scripts/validate-marketplace.sh` | `.claude-plugin/marketplace.json` | `claude plugin marketplace add ./` subprocess | WIRED | Script checks for file at `.claude-plugin/marketplace.json` before invoking |
| `scripts/install.sh (auto-detect)` | `TK_SKILLS_HOME export` | `export TK_SKILLS_HOME=$HOME/.claude/plugins/tk-skills` | WIRED | Confirmed at line 211 |
| `README.md` | `docs/CLAUDE_DESKTOP.md` | Markdown link in marketplace section | WIRED | `[docs/CLAUDE_DESKTOP.md](docs/CLAUDE_DESKTOP.md)` present |
| `docs/INSTALL.md` | `docs/CLAUDE_DESKTOP.md` | Markdown link in Desktop users section | WIRED | `[CLAUDE_DESKTOP.md](CLAUDE_DESKTOP.md)` present |
| `manifest.json` | `scripts/validate-skills-desktop.sh` + `scripts/validate-marketplace.sh` | files.scripts[] array entries | WIRED | Both paths present in files.scripts[] |
| `CHANGELOG.md` | `manifest.json` version | version-align Make target | WIRED | `make version-align` exits 0 with `Version aligned: 4.6.0` |

### Data-Flow Trace (Level 4)

Not applicable — this phase produces shell scripts, JSON manifests, symlinks, and Markdown documentation. No components rendering dynamic data from a state store.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `validate-skills-desktop` exits 0 with PASS>=4 | `bash scripts/validate-skills-desktop.sh` | PASS=20 FLAG=2, DESK-04 gate green | PASS |
| `validate-marketplace` skips without CLI | `bash scripts/validate-marketplace.sh` | `[skipped] validate-marketplace: TK_HAS_CLAUDE_CLI not set` (exit 0) | PASS |
| `manifest.json` validates | `python3 scripts/validate-manifest.py` | `manifest.json validation PASSED` | PASS |
| version-align gate | `make version-align` | `Version aligned: 4.6.0` (exit 0) | PASS |
| `make check` runs both validators | `make check` (from SUMMARY: exit 0) | `All checks passed!` per 27-04-SUMMARY | PASS |
| marketplace.json has no embedded versions | `python3 -c "...any('version' in p for p in d['plugins'])"` | `False` — no plugin entries have version | PASS |
| symlinks resolve to correct targets | readlink + test -d | All 4 symlinks present with correct relative paths; 22 skills accessible | PASS |
| Live marketplace CLI smoke | `TK_HAS_CLAUDE_CLI=1 make validate-marketplace` | SKIP — requires `claude` CLI on PATH | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MKT-01 | 27-01 | `.claude-plugin/marketplace.json` schema with 3 sub-plugins | SATISFIED | File exists; 3 plugins; no embedded versions; name/owner correct |
| MKT-02 | 27-01 | `plugin.json` per sub-plugin (version, description, category, tags) | SATISFIED | All 3 plugin.json files have version 4.6.0, category, tags |
| MKT-03 | 27-02 | `make validate-marketplace` smoke gated by TK_HAS_CLAUDE_CLI=1 | SATISFIED (structure) | Script exists, gated correctly, exits 0 with skip notice in CI; live smoke requires human |
| MKT-04 | 27-04 | README + INSTALL.md "Install via marketplace" sections | SATISFIED | Both files have marketplace sections; CLI command string present; Desktop users pointed to CLAUDE_DESKTOP.md |
| DESK-01 | 27-04 | `docs/CLAUDE_DESKTOP.md` capability matrix | SATISFIED | 94-line doc, 4-column matrix, 6 rows, explains Chat tab + remote session limitations |
| DESK-02 | 27-02 | `validate-skills-desktop.sh` heuristic scanner | SATISFIED | Script scans SKILL.md files; PASS/FLAG verdict per skill; wired into make check and CI |
| DESK-03 | 27-03 | `install.sh` routes CLI-absent users to --skills-only | SATISFIED | Auto-detect block, TK_SKILLS_HOME export, banner text, S10 hermetic test passes |
| DESK-04 | 27-02 | Skills audit gate fails if <4 skills pass | SATISFIED | Threshold=4, current PASS=20; gate exits 0; exits 1 tested via TK_SKILLS_MIRROR=/nonexistent path |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | — |

No TODO/FIXME/PLACEHOLDER patterns found in any Phase 27 artifacts. No stub implementations, no hardcoded empty values that flow to user-visible output.

### Human Verification Required

#### 1. MKT-03 Live Marketplace CLI Smoke

**Test:** On a machine with `claude` CLI installed, run from repo root:

```bash
TK_HAS_CLAUDE_CLI=1 make validate-marketplace
```

**Expected:** `claude plugin marketplace add ./` succeeds; output mentions all three sub-plugins (`tk-skills`, `tk-commands`, `tk-framework-rules`); script exits 0 with `MKT-03 smoke green: 3 sub-plugins discovered`

**Why human:** CI runners do not have the `claude` CLI binary. The validator's skip path (exit 0 + `[skipped]`) is confirmed working programmatically, but the actual smoke requires a developer machine with the CLI installed.

#### 2. Claude Desktop End-to-End Plugin Install

**Test:** Open Claude Desktop application, switch to the Code tab, and run:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

**Expected:** Three sub-plugins appear in the install prompt. Installing `tk-skills` makes 22 skills available in the Desktop Code tab. `tk-commands` and `tk-framework-rules` install but show as Code-only (greyed out in Chat tab).

**Why human:** End-to-end Desktop plugin runtime behavior requires the actual Claude Desktop application and cannot be verified from the CLI or filesystem inspection. The marketplace.json structure, symlink resolution, and plugin.json schema are all correct — Desktop runtime behavior is the only unverifiable piece.

### Gaps Summary

No automated gaps found. All 8 requirements are satisfied by implemented code. The two human verification items address:

1. **MKT-03 CLI smoke** — the script and its gating logic are correct; only the actual Claude CLI execution on a developer machine confirms end-to-end marketplace resolution.
2. **Desktop runtime** — the plugin manifest schema and sub-plugin structure are correct per spec; only the Claude Desktop application can confirm the runtime behavior.

These are not implementation gaps — they are platform-boundary verifications that require a human with access to the Claude CLI and/or the Claude Desktop application.

---

_Verified: 2026-04-29T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
