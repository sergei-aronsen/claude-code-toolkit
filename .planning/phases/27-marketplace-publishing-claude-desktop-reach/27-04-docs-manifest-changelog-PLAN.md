---
phase: 27
plan: "04"
type: execute
wave: 4
depends_on: ["27-01", "27-02", "27-03"]
files_modified:
  - docs/CLAUDE_DESKTOP.md
  - docs/INSTALL.md
  - README.md
  - manifest.json
  - CHANGELOG.md
autonomous: true
requirements:
  - DESK-01
  - MKT-04
must_haves:
  truths:
    - "A new docs/CLAUDE_DESKTOP.md exists at repo root and contains a 4-column capability matrix (Capability × Desktop Code Tab × Desktop Chat Tab × Code Terminal) with at least 6 rows"
    - "docs/CLAUDE_DESKTOP.md is read-time-under-1-minute (concise; aim for <120 lines of body)"
    - "README.md gains an 'Install via marketplace' subsection alongside the existing curl-bash install instructions, with copy-pasteable command (`claude plugin marketplace add sergei-aronsen/claude-code-toolkit`)"
    - "docs/INSTALL.md gains a parallel 'Install via marketplace' section AND a 'Claude Desktop users' subsection pointing to docs/CLAUDE_DESKTOP.md"
    - "manifest.json `version` field updated from 4.4.0 → 4.5.0 and `updated` field updated to today's date (2026-04-29)"
    - "manifest.json registers all four new files added in Plans 01-03 (`scripts/validate-skills-desktop.sh` + `scripts/validate-marketplace.sh` under `files.scripts`; the `.claude-plugin/marketplace.json` and `plugins/` trees are repo-side metadata, NOT user-installable, so NOT in manifest)"
    - "CHANGELOG.md gains a new `[4.5.0] - 2026-04-29` section that consolidates Phase 24-27 deliverables (mirrors v4.4 consolidation pattern)"
    - "`make check` (which includes `version-align`) passes after all changes"
  artifacts:
    - path: "docs/CLAUDE_DESKTOP.md"
      provides: "Capability matrix + Desktop install path documentation"
      min_lines: 60
      contains: "Desktop Code Tab"
    - path: "README.md"
      provides: "Marketplace install subsection alongside curl-bash"
      contains: "claude plugin marketplace add"
    - path: "docs/INSTALL.md"
      provides: "Marketplace install section + Desktop users pointer"
      contains: "marketplace.json"
    - path: "manifest.json"
      provides: "Version 4.5.0 + new validators registered under files.scripts"
      contains: '"version": "4.5.0"'
    - path: "CHANGELOG.md"
      provides: "[4.5.0] release entry consolidating Phase 24-27"
      contains: "## [4.5.0]"
  key_links:
    - from: "README.md"
      to: "docs/CLAUDE_DESKTOP.md"
      via: "Markdown link in marketplace section"
      pattern: "CLAUDE_DESKTOP.md"
    - from: "docs/INSTALL.md"
      to: "docs/CLAUDE_DESKTOP.md"
      via: "Markdown link in Desktop users section"
      pattern: "CLAUDE_DESKTOP.md"
    - from: "manifest.json"
      to: "scripts/validate-skills-desktop.sh + scripts/validate-marketplace.sh"
      via: "files.scripts[] array entries"
      pattern: "validate-skills-desktop"
    - from: "CHANGELOG.md"
      to: "manifest.json"
      via: "version-align Make target verifies both sides"
      pattern: '## \[4.5.0\]'
---

<objective>
Land the user-facing surface for v4.5: Claude Desktop documentation, marketplace
install instructions in README + INSTALL.md, manifest version bump 4.4.0 → 4.5.0
(the **final** v4.5 milestone bump), CHANGELOG `[4.5.0]` consolidating Phase 24-27.

This plan ships in Wave 4 because:

- Manifest version bump must reflect ALL files added across the milestone (Plans 27-01..27-03 added new validators; the bump waits for them).
- CHANGELOG entry consolidates everything across Phases 24-27 — needs the full picture.
- README + docs reference the marketplace structure created in Plan 01 and the validators from Plan 02 and the install.sh routing from Plan 03.

Per CONTEXT.md decisions:

- **CLAUDE_DESKTOP.md format:** 4-column matrix (Capability × Desktop Code Tab × Desktop Chat Tab × Code Terminal). Rows: skills, slash-commands, MCPs, statusline, security wizard, framework rules. Verdicts: ✅ available, ❌ unavailable, ⚠ partial.
- **Read-time target:** under 1 minute (DESK-01). Keep it concise.
- **Marketplace as Desktop-only path:** explicitly state `/plugin marketplace add ./local-dir` is blocked — marketplace.json upstream is the only Desktop install channel.
- **Both channels documented as equivalent for Code users** (MKT-04). Marketplace is the only path for Desktop.
- **Version source-of-truth (per CONTEXT.md "Version Source-of-Truth"):** manifest.json bumped to 4.5.0; CHANGELOG `[4.5.0]` consolidates Phase 24-27 in one entry (mirrors v4.4).
- **manifest scope:** the `.claude-plugin/marketplace.json` + `plugins/` trees are repo-side metadata for the marketplace tooling, NOT user-installable files distributed via curl-bash. They go in git but NOT in `manifest.json`. Only the new VALIDATORS (`validate-skills-desktop.sh` + `validate-marketplace.sh`) are added to `files.scripts[]`.

Output: 1 new doc file + 3 modified docs + 2 modified config files.

Purpose: deliver DESK-01 (capability matrix doc) and MKT-04 (marketplace install
section in README + INSTALL.md).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md
@.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-01-marketplace-surface-PLAN.md
@.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-02-validators-and-make-wiring-PLAN.md
@.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-03-install-sh-desktop-routing-PLAN.md
@README.md
@docs/INSTALL.md
@manifest.json
@CHANGELOG.md

<interfaces>
<!-- Verbatim contracts and references the executor needs. -->

manifest.json current state (top fields, lines 1-10):

```json
{
  "manifest_version": 2,
  "version": "4.4.0",
  "updated": "2026-04-27",
  "description": "Claude Code Toolkit manifest for smart updates",
  ...
}
```

Target state in Plan 04:
- `"version": "4.5.0"`
- `"updated": "2026-04-29"`
- `files.scripts[]` array gains 2 entries: `scripts/validate-skills-desktop.sh` and `scripts/validate-marketplace.sh` (sorted alphabetically with existing scripts).

Existing files.scripts[] (around line 250 of manifest.json, before .files.skills_marketplace):
- Read manifest.json with `jq '.files.scripts'` to confirm current entries
- Both new scripts get `{"path": "scripts/validate-skills-desktop.sh"}` and `{"path": "scripts/validate-marketplace.sh"}` style entries (matching existing format)
- Position: alphabetically — `validate-skills-desktop.sh` and `validate-marketplace.sh` go AFTER any existing `scripts/uninstall.sh` entry

CHANGELOG.md current top entry (lines 8-65):

```markdown
## [4.4.0] - 2026-04-27

### Added

- **SP/GSD bootstrap installer** ...
- ...
```

Plan 04 inserts a NEW top entry BEFORE [4.4.0]:

```markdown
## [4.5.0] - 2026-04-29

### Added

- **Unified TUI installer** (`scripts/install.sh`) — TUI-01..07, DET-01..05, DISPATCH-01..03, BACKCOMPAT-01: Phase 24. Single entry point with arrow-navigable Bash 3.2 checklist...
- **MCP catalog + per-MCP wizard** (`scripts/lib/mcp.sh`, `templates/mcps/`) — MCP-01..05, MCP-SEC-01..02: Phase 25. Nine curated MCP servers...
- **Skills marketplace mirror** (`templates/skills-marketplace/`, `scripts/lib/skills.sh`) — SKILL-01..05: Phase 26. 22 curated skills mirrored from skills.sh...
- **Plugin marketplace surface** (`.claude-plugin/marketplace.json`, `plugins/tk-{skills,commands,framework-rules}/`) — MKT-01, MKT-02: Phase 27. Three sub-plugins discoverable via `claude plugin marketplace add sergei-aronsen/claude-code-toolkit`...
- **Marketplace + skills Desktop validators** (`scripts/validate-marketplace.sh`, `scripts/validate-skills-desktop.sh`) — MKT-03, DESK-02, DESK-04: Phase 27. CI gate fails if fewer than 4 skills pass Desktop-safety heuristic...
- **Desktop install routing** (`scripts/install.sh --skills-only`) — DESK-03: Phase 27. CLI-absent users auto-routed to skills-only mode; skills land in `~/.claude/plugins/tk-skills/`...
- **Claude Desktop capability matrix** (`docs/CLAUDE_DESKTOP.md`) — DESK-01: Phase 27. 4-column matrix...
- **Marketplace install docs** (README.md, docs/INSTALL.md) — MKT-04: Phase 27. Both install channels (curl-bash for Code users; marketplace for Desktop users) documented as equivalent...

(Phase 24-27 details — full requirement IDs and test coverage in respective phase plans.)
```

Existing CHANGELOG `[4.4.0]` entry stays UNTOUCHED below the new entry — it's
historic. The new entry consolidates ALL of v4.5 (Phases 24-27) in one block,
just like `[4.4.0]` consolidated Phases 21-23.

README.md install section reference (lines 60-105 — read existing structure to
find the "### Standalone install" / "### Complement install" subsection cluster).
The new "### Install via marketplace" subsection goes alongside those.

docs/INSTALL.md current structure (sections):
- Modes Overview (line 9)
- Installer Flags (line 31)
- --skills flag (line 162) [existing — added in Plan 26-04]
- Backwards compatibility (line 200)

Plan 04 adds two new sections to docs/INSTALL.md:
1. "### Install via marketplace" near the top (after Modes Overview, before Installer Flags)
2. "### Claude Desktop users" — short subsection pointing to `docs/CLAUDE_DESKTOP.md`

CONTEXT.md verbatim verbiage for the auto-route banner (already implemented in Plan 03):
> Claude CLI not detected — installing skills only. Skills available in Claude Desktop Code tab. See docs/CLAUDE_DESKTOP.md for full capability matrix.

CLAUDE_DESKTOP.md structure (per CONTEXT.md "CLAUDE_DESKTOP.md Capability Matrix"):
- Title: `# Claude Desktop Capability Matrix`
- Capability matrix table (4 cols, 6+ rows)
- Plain-English "why" section explaining Chat tab + remote sessions limitations
- Installation instructions for Desktop users (marketplace add command)
- Read-time target: under 1 minute

Markdownlint constraints (from CLAUDE.md):
- MD040: every fenced code block declares a language (use `text` for plain ASCII)
- MD031/MD032: blank line before+after every code block AND every list
- MD026: no trailing punctuation in headings (no `?`, `:`, `.`, `!`)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create docs/CLAUDE_DESKTOP.md capability matrix + update README.md and docs/INSTALL.md with marketplace install sections</name>
  <files>
    docs/CLAUDE_DESKTOP.md,
    README.md,
    docs/INSTALL.md
  </files>
  <read_first>
    - .planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md (CLAUDE_DESKTOP.md Capability Matrix section)
    - README.md (lines 50-130 — find install sections "### Standalone install", "### Complement install")
    - docs/INSTALL.md (full file — confirm section ordering)
    - .markdownlint.json + .markdownlint-cli2.jsonc (active markdownlint rules)
  </read_first>
  <action>

### Step A: Create `docs/CLAUDE_DESKTOP.md`

Create the file with this content. Keep body under 120 lines for the
"under 1 minute" read-time target.

```markdown
# Claude Desktop Capability Matrix

Plugins are a Claude Code feature. Some Code surfaces also exist in Claude
Desktop, others do not. This page tells you which toolkit capabilities are
available where, so you can decide what to install.

## Capability Matrix

| Capability | Desktop Code Tab | Desktop Chat Tab | Code Terminal |
|------------|:---------------:|:---------------:|:------------:|
| Skills (`tk-skills`) | available | unavailable | available |
| Slash commands (`tk-commands`) | available | unavailable | available |
| MCPs (Model Context Protocol servers) | available | unavailable | available |
| Statusline (rate-limit + token usage) | unavailable | unavailable | available |
| Security pack (`cc-safety-net` + hooks) | unavailable | unavailable | available |
| Framework CLAUDE.md rules (`tk-framework-rules`) | available | unavailable | available |

Verdicts: **available** = works on this surface, **unavailable** = blocked by
the platform.

## Why the Chat Tab Has No Plugins

Claude Desktop's Chat tab does not run the plugin runtime. There is no
mechanism in the chat interface to load skills, commands, MCPs, or any other
plugin-system capability. This is a platform limitation set by Anthropic, not
something a marketplace listing can change.

The Desktop **Code** tab (the IDE-style surface) does run the plugin runtime
and reaches feature parity with terminal Claude Code for skills, slash
commands, MCPs, and rules.

## Why Remote Code Sessions Block Plugins

Cloud-hosted Claude Code sessions (the ones spawned from a browser, not from
your local terminal) explicitly block plugin loading per Anthropic's
documentation. Plugins run only on local Code sessions — terminal or Desktop
Code tab. This is also a platform constraint.

## Install Via Marketplace

Marketplace is the **only** way to install plugins on Claude Desktop. The
local-directory shortcut `/plugin marketplace add ./some-dir` does **not**
work in Desktop — only the upstream marketplace identifier resolves.

Open Claude Desktop, switch to the Code tab, and run:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

You will see three sub-plugins:

- `tk-skills` — 22 curated skills (Desktop-compatible)
- `tk-commands` — 29 slash commands (Code-only; appears greyed out on Chat tab)
- `tk-framework-rules` — 7 framework CLAUDE.md fragments (Code-only)

Pick `tk-skills` for the Desktop Code tab. The other two are visible but only
take effect in terminal Code sessions.

## Install Via Curl-Bash (Code Terminal Users)

If you run Claude Code in your terminal, the legacy curl-bash install is
equivalent to the marketplace install for the toolkit's content:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

Choose the channel that matches your environment. Both work for terminal Code
users; marketplace is the only path for Desktop users.

## Skills-Only Auto-Route

If you run `scripts/install.sh` on a system without the `claude` CLI on PATH
(for example, a Desktop-only workstation), the installer auto-routes to
`--skills-only` mode and places skills under
`~/.claude/plugins/tk-skills/<name>/` so Claude Desktop's plugin runtime
discovers them. You will see a one-line banner explaining the routing.

## Limitations and Future Work

- **Statusline + security pack** are macOS Keychain / shell-hook based —
  there is no Desktop equivalent surface today.
- **Cross-platform Desktop reach beyond skills** (MCPs, statusline, etc.)
  needs Anthropic plugin-runtime expansion. Tracked as deferred.
- **Upstream registry submission** of `claude-code-toolkit` to the central
  Anthropic marketplace is a manual maintainer task post-merge.

## Related

- `docs/INSTALL.md` — full install matrix and flag reference
- `README.md` — install commands and feature overview
- `.claude-plugin/marketplace.json` — repo-side marketplace manifest
- `plugins/tk-skills/` — Desktop-compatible sub-plugin tree
```

### Step B: Update `README.md`

Find the existing install-mode subsection cluster (`### Standalone install` /
`### Complement install`) around lines 65-105. AFTER the `### Complement install`
subsection (and BEFORE `### Upgrading from v3.x`), insert this new subsection:

```markdown
### Install via marketplace

For Claude Desktop users, the toolkit is available as a Claude Code plugin
marketplace listing. From the Desktop Code tab (or terminal Claude Code with
plugin support enabled), run:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

You will get three sub-plugins:

- `tk-skills` — 22 curated skills (Desktop-compatible)
- `tk-commands` — 29 slash commands (terminal Code only)
- `tk-framework-rules` — 7 framework CLAUDE.md fragments (terminal Code only)

The marketplace install is **equivalent** to the curl-bash install for terminal
Code users. For Desktop users, marketplace is the **only** install path — see
[docs/CLAUDE_DESKTOP.md](docs/CLAUDE_DESKTOP.md) for the full capability matrix.
```

(Note: README.md already disables MD013 / MD040 enforcement via `.markdownlint.json`;
the inline ```` ```text ```` blocks satisfy MD040 explicitly.)

### Step C: Update `docs/INSTALL.md`

Insert two new sections in `docs/INSTALL.md`.

**Section 1 — Install via marketplace** (insert AFTER `## Modes Overview`,
BEFORE `## Installer Flags`, around line 30):

```markdown
## Install via marketplace

The toolkit ships a Claude Code plugin marketplace listing at the repository's
`.claude-plugin/marketplace.json`. Three sub-plugins are exposed:

| Sub-plugin | Reach | Content |
|------------|-------|---------|
| `tk-skills` | Desktop Code tab + terminal Code | 22 curated skills mirrored from skills.sh |
| `tk-commands` | Terminal Code only | 29 slash commands for Claude Code workflows |
| `tk-framework-rules` | Terminal Code only | 7 framework CLAUDE.md fragments (Laravel, Rails, Next.js, Node.js, Python, Go, base) |

Install all three via:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

This works in both Claude Desktop's Code tab and terminal Claude Code with plugin
support enabled. The marketplace channel is **equivalent** to curl-bash for terminal
Code users; for Desktop users it is the **only** install path.

### Claude Desktop users

Claude Desktop's Chat tab does not run the plugin runtime. The Code tab does and
has feature parity with terminal Code for skills, slash commands, MCPs, and rules.
See [CLAUDE_DESKTOP.md](CLAUDE_DESKTOP.md) for the full capability matrix.
```

**Section 2 — `--skills-only` flag documentation** (insert AFTER the existing
`### --skills flag` subsection, around line 195):

```markdown
### --skills-only flag

`--skills-only` redirects the install target so skills land at
`~/.claude/plugins/tk-skills/<name>/` (the Desktop plugin tree) instead of
`~/.claude/skills/<name>/`. Use this when you want the toolkit's skills
available in Claude Desktop's Code tab.

```bash
# Explicit Desktop install (works regardless of CLI presence)
bash scripts/install.sh --skills-only --yes
```

Auto-routing: when `claude` is not on PATH and no other page flag is passed,
`scripts/install.sh` automatically promotes to `--skills-only` mode and prints:

```text
! Claude CLI not detected — installing skills only.
  Skills available in Claude Desktop Code tab.
  See docs/CLAUDE_DESKTOP.md for full capability matrix.
```

This makes the installer Desktop-friendly out of the box. Pass any explicit
flag (`--mcps`, `--skills`, `--components`, `--yes`) to opt out of auto-routing.
```

### Step D: Verify markdown lint

Run markdownlint against the three files:

```bash
markdownlint docs/CLAUDE_DESKTOP.md docs/INSTALL.md README.md --config .markdownlint.json
```

If any MD040 / MD031 / MD026 violations surface — fix them before committing.
Common gotchas:

- Every code fence must declare a language (` ```text` for plain ASCII tables).
- Headings must NOT end with `?`, `:`, `.`, `!`.
- Blank line BEFORE and AFTER every code fence and every list.

### Step E: Commit

```bash
git add docs/CLAUDE_DESKTOP.md docs/INSTALL.md README.md
git commit -m "docs(27): add CLAUDE_DESKTOP.md capability matrix + marketplace install sections (DESK-01, MKT-04)"
```
  </action>
  <verify>
    <automated>
test -f docs/CLAUDE_DESKTOP.md \
  && grep -q "Capability Matrix" docs/CLAUDE_DESKTOP.md \
  && grep -q "Desktop Code Tab" docs/CLAUDE_DESKTOP.md \
  && grep -q "Desktop Chat Tab" docs/CLAUDE_DESKTOP.md \
  && grep -q "Code Terminal" docs/CLAUDE_DESKTOP.md \
  && grep -q "tk-skills" docs/CLAUDE_DESKTOP.md \
  && grep -q "claude plugin marketplace add" README.md \
  && grep -q "CLAUDE_DESKTOP.md" README.md \
  && grep -q "Install via marketplace" docs/INSTALL.md \
  && grep -q "CLAUDE_DESKTOP.md" docs/INSTALL.md \
  && grep -q "skills-only" docs/INSTALL.md \
  && markdownlint docs/CLAUDE_DESKTOP.md docs/INSTALL.md README.md --config .markdownlint.json \
  && BODY_LINES=$(wc -l < docs/CLAUDE_DESKTOP.md) \
  && test "$BODY_LINES" -le 130 \
  && echo "PASS: docs landed (CLAUDE_DESKTOP.md $BODY_LINES lines)"
    </automated>
  </verify>
  <done>
    - `docs/CLAUDE_DESKTOP.md` exists with capability matrix containing 4 columns and ≥ 6 rows; total file ≤ 130 lines
    - `README.md` contains "Install via marketplace" subsection with `claude plugin marketplace add` command + link to CLAUDE_DESKTOP.md
    - `docs/INSTALL.md` contains "Install via marketplace" section + "Claude Desktop users" subsection + "--skills-only flag" subsection
    - markdownlint clean on all 3 files
  </done>
  <acceptance_criteria>
    - `wc -l docs/CLAUDE_DESKTOP.md` returns ≤ 130
    - `grep -c '|' docs/CLAUDE_DESKTOP.md` returns ≥ 30 (capability matrix has 4 cols × ≥ 8 rows including header/separator = ≥ 32 pipe chars)
    - `grep -c 'tk-skills\|tk-commands\|tk-framework-rules' README.md` returns ≥ 3 (one mention each minimum)
    - `grep -c 'marketplace' docs/INSTALL.md` returns ≥ 4 (Install via marketplace heading + table mentions)
    - `markdownlint docs/CLAUDE_DESKTOP.md docs/INSTALL.md README.md --config .markdownlint.json` exits 0
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: Bump manifest.json to 4.5.0 + register validators + add CHANGELOG [4.5.0] entry</name>
  <files>
    manifest.json,
    CHANGELOG.md
  </files>
  <read_first>
    - manifest.json (lines 1-15 + the entire `files.scripts` array — confirm existing entries)
    - CHANGELOG.md (lines 1-65 — confirm [4.4.0] entry structure to mirror)
    - .planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md (Version Source-of-Truth section)
  </read_first>
  <action>

### Step A: Bump manifest.json

1. Update top-level fields in manifest.json:

   - Change `"version": "4.4.0"` to `"version": "4.5.0"`
   - Change `"updated": "2026-04-27"` to `"updated": "2026-04-29"`

2. Add two new entries to `files.scripts[]` array. Use jq to discover existing
   entries first:

   ```bash
   jq '.files.scripts' manifest.json
   ```

   Then add the new entries while preserving alphabetical sort order. The two
   new entries are:

   ```json
   {"path": "scripts/validate-marketplace.sh"},
   {"path": "scripts/validate-skills-desktop.sh"}
   ```

   They land alphabetically between any existing `scripts/uninstall.sh` (or
   similar `u*` entries) and any existing `scripts/v*` entry. If no `v*` entry
   exists, they go at the end of the scripts array (still alphabetical).

3. Validate the result:

   ```bash
   python3 -c "import json; json.load(open('manifest.json'))"
   python3 scripts/validate-manifest.py
   ```

   Both must exit 0. The validator may flag the new files as not yet existing
   on disk — they DO exist (created by Plan 02), so this should pass.

   IMPORTANT: do NOT add `.claude-plugin/marketplace.json` or `plugins/`
   subtrees to manifest.json. These are repo-side metadata for marketplace
   tooling, not user-installable files distributed via curl-bash. Per CONTEXT.md
   and Plan 01 frontmatter, they live in git but stay out of the install
   manifest.

### Step B: Add CHANGELOG [4.5.0] entry

Insert the following block at the TOP of the CHANGELOG, AFTER the existing
preamble (lines 1-7: title + format note + semver note) and BEFORE the existing
`## [4.4.0] - 2026-04-27` section:

```markdown
## [4.5.0] - 2026-04-29

### Added

- **Unified TUI installer** (`scripts/install.sh`) — TUI-01..07, DET-01..05,
  DISPATCH-01..03, BACKCOMPAT-01: Phase 24. Single curl-bash entry point
  rendering an arrow-navigable Bash 3.2 checklist (no Bash 4-only constructs)
  with auto-detect of toolkit / superpowers / GSD / security pack / RTK /
  statusline. `--yes` for CI, `--force` re-runs detected, `--no-color`
  honored, `Ctrl-C` restores terminal cleanly. Foundation libs
  (`scripts/lib/{tui,detect2,dispatch}.sh`) reused by Phases 25-26. Hermetic
  test: `scripts/tests/test-install-tui.sh` (38+ assertions, Test 31).

- **MCP catalog + per-MCP wizard** (`scripts/lib/mcp.sh`,
  `scripts/lib/mcp-catalog.json`, `templates/mcps/`) — MCP-01..05,
  MCP-SEC-01..02: Phase 25. Nine curated MCP servers (`context7`, `magic`,
  `notebooklm`, `openrouter`, `playwright`, `sentry`, `sequential-thinking`,
  `toolbox`, `youtrack`) browsable via `scripts/install.sh --mcps`. Per-MCP
  wizard collects API keys with hidden input (`read -rs`), persists to
  `~/.claude/mcp-config.env` (mode 0600), invokes `claude mcp add`. Fail-soft
  when CLI absent. Hermetic test: `scripts/tests/test-mcp-selector.sh`
  (Test 32).

- **Skills marketplace mirror** (`templates/skills-marketplace/`,
  `scripts/lib/skills.sh`, `scripts/sync-skills-mirror.sh`) — SKILL-01..05:
  Phase 26. 22 curated skills mirrored from upstream skills.sh (license-audited,
  documented in `docs/SKILLS-MIRROR.md`). `scripts/install.sh --skills`
  copies selected skills to `~/.claude/skills/<name>/` via `cp -R`.
  `manifest.json` registers all 22 under `files.skills_marketplace[]` so
  `update-claude.sh` ships skill updates. Hermetic test:
  `scripts/tests/test-install-skills.sh` (15 assertions, Test 33).

- **Plugin marketplace surface** (`.claude-plugin/marketplace.json`,
  `plugins/tk-{skills,commands,framework-rules}/.claude-plugin/plugin.json`,
  symlink trees) — MKT-01, MKT-02: Phase 27. Three sub-plugins discoverable
  via `claude plugin marketplace add sergei-aronsen/claude-code-toolkit`.
  `tk-skills` is Desktop-Code-tab compatible; `tk-commands` and
  `tk-framework-rules` are Code-only. Sub-plugin content trees are relative
  symlinks into the canonical repo content (zero duplication, zero drift).
  Version is the single source of truth in each `plugin.json` (4.5.0);
  `marketplace.json` plugin entries do not declare versions per spec.

- **Marketplace + Desktop-skills validators** (`scripts/validate-marketplace.sh`,
  `scripts/validate-skills-desktop.sh`) — MKT-03, DESK-02, DESK-04: Phase 27.
  `validate-marketplace` runs `claude plugin marketplace add ./` smoke when
  `TK_HAS_CLAUDE_CLI=1` (CI default skips with no-op notice).
  `validate-skills-desktop` scans every `templates/skills-marketplace/*/SKILL.md`
  for tool-execution patterns; PASS = Desktop-safe instruction-only,
  FLAG = Code-terminal-only. Threshold: ≥ 4 PASS or `make check` fails. Both
  targets wired into `make check`; `validate-skills-desktop` runs as a
  dedicated CI step.

- **Desktop-only auto-routing** (`scripts/install.sh --skills-only`) — DESK-03:
  Phase 27. Users without `claude` on PATH running the installer (no flags) are
  auto-routed to `--skills-only` mode; skills land at
  `~/.claude/plugins/tk-skills/<name>/` (Desktop install location) instead of
  `~/.claude/skills/<name>/`. One-line banner explains the routing. Explicit
  `--skills-only` flag also available for users with the CLI who only want
  skills. Hermetic test: `scripts/tests/test-install-tui.sh` S10 scenario.

- **Claude Desktop capability matrix** (`docs/CLAUDE_DESKTOP.md`) — DESK-01:
  Phase 27. Four-column matrix (Capability × Desktop Code Tab × Desktop Chat
  Tab × Code Terminal) covering skills, slash commands, MCPs, statusline,
  security pack, and framework rules. Plain-English explanation of why Chat
  tab and remote Code sessions block plugins. Read-time target: under one
  minute.

- **Marketplace install documentation** (`README.md`, `docs/INSTALL.md`) —
  MKT-04: Phase 27. README and INSTALL.md gain "Install via marketplace"
  sections alongside the existing curl-bash install. Both channels documented
  as equivalent for terminal Code users; marketplace is the only path for
  Desktop users.

### Changed

- **Manifest version** bumped from 4.4.0 to 4.5.0 (final v4.5 milestone bump).
  `init-local.sh --version` derives from manifest at runtime, so no script
  changes needed.

- **`make check` chain** extended with `validate-skills-desktop` (always
  runs) and `validate-marketplace` (runs `claude plugin marketplace add ./`
  when `TK_HAS_CLAUDE_CLI=1`, no-op skip otherwise).

- **CI workflow** (`quality.yml`) gains a dedicated
  `DESK-02/DESK-04 — Skills Desktop-safety audit` step.

```

(The `### Changed` section uses bullets; ensure blank line before/after the
list and around code spans for MD031/MD032.)

### Step C: Run version-align gate

```bash
make version-align
```

Expected output:

```text
✅ Version aligned: 4.5.0
```

If this fails, fix whichever side is out of sync (manifest.json `version`,
CHANGELOG `## [X.Y.Z]` top header, or — though this is unlikely since
init-local.sh derives from manifest — the script).

### Step D: Run full make check

```bash
make check
```

Expected: exits 0 with `All checks passed!`. The chain runs:
`lint validate validate-base-plugins version-align translation-drift
agent-collision-static validate-commands validate-skills-desktop
validate-marketplace cell-parity`.

If `validate` (which calls `validate-manifest.py`) fails because the new
script entries are not on disk, that means Plan 02 wasn't fully landed —
re-verify the validators exist and are listed correctly.

### Step E: Commit

```bash
git add manifest.json CHANGELOG.md
git commit -m "chore(27): bump manifest 4.4.0 → 4.5.0, register validators, consolidate v4.5 CHANGELOG (final v4.5 milestone bump)"
```

After this commit, the v4.5 milestone is content-complete. Final tagging
(`v4.5.0`) is a maintainer manual step per CLAUDE.md "never push directly to
main" — out of scope for this plan.
  </action>
  <verify>
    <automated>
test "$(jq -r '.version' manifest.json)" = "4.5.0" \
  && test "$(jq -r '.updated' manifest.json)" = "2026-04-29" \
  && jq -e '.files.scripts[] | select(.path == "scripts/validate-skills-desktop.sh")' manifest.json >/dev/null \
  && jq -e '.files.scripts[] | select(.path == "scripts/validate-marketplace.sh")' manifest.json >/dev/null \
  && python3 -c "import json; json.load(open('manifest.json'))" \
  && python3 scripts/validate-manifest.py \
  && grep -q '## \[4.5.0\] - 2026-04-29' CHANGELOG.md \
  && grep -q 'Plugin marketplace surface' CHANGELOG.md \
  && grep -q 'Desktop-only auto-routing' CHANGELOG.md \
  && grep -q 'Claude Desktop capability matrix' CHANGELOG.md \
  && CHANGELOG_VER=$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/') \
  && test "$CHANGELOG_VER" = "4.5.0" \
  && make version-align > /tmp/va.out 2>&1 \
  && grep -q 'Version aligned: 4.5.0' /tmp/va.out \
  && make check > /tmp/check.out 2>&1 \
  && grep -q 'All checks passed' /tmp/check.out \
  && echo "PASS: manifest=4.5.0, CHANGELOG=[4.5.0], make check green"
    </automated>
  </verify>
  <done>
    - `manifest.json` `.version == "4.5.0"`, `.updated == "2026-04-29"`
    - `manifest.json` `.files.scripts[]` includes both `scripts/validate-skills-desktop.sh` and `scripts/validate-marketplace.sh`
    - `python3 scripts/validate-manifest.py` exits 0
    - `CHANGELOG.md` top entry is `## [4.5.0] - 2026-04-29` with `### Added` containing all eight Phase-24-27 deliverables (Unified TUI installer, MCP catalog, Skills mirror, Plugin marketplace, Validators, Desktop routing, Capability matrix, Marketplace docs)
    - `make version-align` reports `Version aligned: 4.5.0`
    - `make check` exits 0 with `All checks passed!`
  </done>
  <acceptance_criteria>
    - `jq -r '.version' manifest.json` returns `4.5.0`
    - `jq -r '.updated' manifest.json` returns `2026-04-29`
    - `jq '[.files.scripts[].path] | sort | unique | length' manifest.json` equals the actual script count (no duplicate path entries)
    - `jq -e '[.files.scripts[].path] | contains(["scripts/validate-skills-desktop.sh", "scripts/validate-marketplace.sh"])' manifest.json` returns `true`
    - `head -10 CHANGELOG.md | grep -c '## \[4.5.0\]'` returns `1`
    - `grep -A 200 '## \[4.5.0\]' CHANGELOG.md | grep -c -E '(MKT-|DESK-|TUI-|MCP-|SKILL-|DET-|DISPATCH-|BACKCOMPAT-)'` returns ≥ 5 (multiple requirement IDs cited)
    - `make version-align` exits 0
    - `make check` exits 0
    - `python3 scripts/validate-manifest.py` exits 0
  </acceptance_criteria>
</task>

</tasks>

<verification>
After both tasks:

1. `docs/CLAUDE_DESKTOP.md` exists with the documented capability matrix (DESK-01 satisfied).
2. `README.md` and `docs/INSTALL.md` carry marketplace install sections (MKT-04 satisfied).
3. `manifest.json` is at version 4.5.0 with the two new validators registered.
4. `CHANGELOG.md` has `[4.5.0] - 2026-04-29` consolidating Phase 24-27.
5. `make version-align` and `make check` both pass.

Phase 27 is content-complete. The maintainer's manual final step is to tag
`v4.5.0` (per CLAUDE.md "never push directly to main").
</verification>

<success_criteria>
- `docs/CLAUDE_DESKTOP.md` exists with capability matrix readable in <1 min (DESK-01)
- README + docs/INSTALL.md document marketplace install channel as equivalent for Code users; marketplace-only for Desktop (MKT-04)
- manifest.json version 4.5.0 + updated 2026-04-29 + 2 new validators registered
- CHANGELOG.md top entry `[4.5.0] - 2026-04-29` consolidates all Phase 24-27 deliverables
- `make version-align` and `make check` both green
- markdownlint clean on all touched docs
</success_criteria>

<output>
After completion, create `.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-04-docs-manifest-changelog-SUMMARY.md` with:

- `requirements_addressed: [DESK-01, MKT-04]`
- `version_align_result`: actual output of `make version-align`
- `make_check_result`: exit code + key output line of final `make check`
- Notes on what was added to manifest.json files.scripts[] (path entries, sort position)
- Indication that v4.5 is content-complete — only `git tag v4.5.0` remains for the maintainer
</output>
