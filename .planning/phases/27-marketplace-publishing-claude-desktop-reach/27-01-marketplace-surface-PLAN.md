---
phase: 27
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - .claude-plugin/marketplace.json
  - plugins/tk-skills/.claude-plugin/plugin.json
  - plugins/tk-skills/skills
  - plugins/tk-skills/LICENSE
  - plugins/tk-commands/.claude-plugin/plugin.json
  - plugins/tk-commands/commands
  - plugins/tk-framework-rules/.claude-plugin/plugin.json
  - plugins/tk-framework-rules/templates
autonomous: true
requirements:
  - MKT-01
  - MKT-02
must_haves:
  truths:
    - ".claude-plugin/marketplace.json exists at repo root and lists exactly 3 sub-plugins (tk-skills, tk-commands, tk-framework-rules)"
    - "Each sub-plugin has plugins/<name>/.claude-plugin/plugin.json with version 4.5.0 and a valid schema (name, description, version, category, tags)"
    - "marketplace.json plugin entries declare source paths only — version is set in plugin.json, not duplicated in marketplace.json (per MKT-02 single-source-of-truth rule)"
    - "tk-skills sub-plugin contains a skills/ entry (symlink) pointing to templates/skills-marketplace/ so the 22 mirrored skills surface to Claude Desktop without content duplication"
    - "tk-commands sub-plugin contains a commands/ entry (symlink) pointing to repo-root commands/ so the 29 slash commands surface to Claude Code (Desktop Code tab) without duplication"
    - "tk-framework-rules sub-plugin contains a templates/ entry (symlink) pointing to repo-root templates/ for framework CLAUDE.md fragments"
    - "Repository LICENSE is reachable from each sub-plugin (root LICENSE referenced or symlinked as plugins/tk-skills/LICENSE)"
  artifacts:
    - path: ".claude-plugin/marketplace.json"
      provides: "Marketplace manifest with 3-plugin entries"
      contains: '"name": "claude-code-toolkit"'
    - path: "plugins/tk-skills/.claude-plugin/plugin.json"
      provides: "tk-skills sub-plugin manifest"
      contains: '"version": "4.5.0"'
    - path: "plugins/tk-commands/.claude-plugin/plugin.json"
      provides: "tk-commands sub-plugin manifest"
      contains: '"version": "4.5.0"'
    - path: "plugins/tk-framework-rules/.claude-plugin/plugin.json"
      provides: "tk-framework-rules sub-plugin manifest"
      contains: '"version": "4.5.0"'
    - path: "plugins/tk-skills/skills"
      provides: "Symlink to templates/skills-marketplace/ — 22 mirrored skills"
    - path: "plugins/tk-commands/commands"
      provides: "Symlink to repo-root commands/ — 29 slash commands"
    - path: "plugins/tk-framework-rules/templates"
      provides: "Symlink to repo-root templates/ — 7 framework CLAUDE.md fragments"
  key_links:
    - from: ".claude-plugin/marketplace.json"
      to: "plugins/tk-skills/"
      via: "plugins[].source = ./plugins/tk-skills"
      pattern: "./plugins/tk-skills"
    - from: ".claude-plugin/marketplace.json"
      to: "plugins/tk-commands/"
      via: "plugins[].source = ./plugins/tk-commands"
      pattern: "./plugins/tk-commands"
    - from: ".claude-plugin/marketplace.json"
      to: "plugins/tk-framework-rules/"
      via: "plugins[].source = ./plugins/tk-framework-rules"
      pattern: "./plugins/tk-framework-rules"
    - from: "plugins/tk-skills/skills"
      to: "templates/skills-marketplace/"
      via: "ln -s ../../templates/skills-marketplace skills"
      pattern: "templates/skills-marketplace"
---

<objective>
Create the Claude Code plugin marketplace surface — a repo-root `.claude-plugin/marketplace.json`
plus three sub-plugin trees (`plugins/tk-skills/`, `plugins/tk-commands/`,
`plugins/tk-framework-rules/`) — so the toolkit becomes discoverable via
`claude plugin marketplace add sergei-aronsen/claude-code-toolkit`.

Per CONTEXT.md decisions:

- **Three sub-plugins** with distinct reach: `tk-skills` is Desktop-Code-compatible
  (22 mirrored skills); `tk-commands` and `tk-framework-rules` are Code-only.
- **Symlinks**, not copies: each sub-plugin's content directory is a relative symlink
  to the canonical repo location (zero duplication, zero drift). Plan 02 adds a
  validator that asserts the symlinks resolve.
- **Version is declared once** in each `plugin.json` (4.5.0 — the milestone version).
  `marketplace.json` plugin entries carry `name` + `source` only, NEVER `version`
  (per MKT-02 explicit guidance: `plugin.json` silently wins).

Purpose: deliver MKT-01 (marketplace.json schema) and MKT-02 (three sub-plugin
trees with valid plugin.json each). Phase 02 will wire `make validate-marketplace`
to run `claude plugin marketplace add ./` against this exact tree.

Output: 4 new JSON files + 3 symlinks + 1 LICENSE entry under `plugins/tk-skills/`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md
@templates/skills-marketplace/
@commands/
@templates/

<interfaces>
<!-- These contracts are the entire planning surface for the executor. Do NOT explore
     the codebase beyond what is listed here. -->

CONTEXT.md decision (verbatim):

```json
{
  "name": "claude-code-toolkit",
  "owner": { "name": "sergei-aronsen" },
  "plugins": [
    { "name": "tk-skills", "source": "./plugins/tk-skills" },
    { "name": "tk-commands", "source": "./plugins/tk-commands" },
    { "name": "tk-framework-rules", "source": "./plugins/tk-framework-rules" }
  ]
}
```

CONTEXT.md plugin.json fields per sub-plugin:

- tk-skills:        version 4.5.0, category "skills",   tags ["mirror","marketplace"],         description "22 curated skills mirrored from skills.sh"
- tk-commands:      version 4.5.0, category "commands", tags ["slash-commands","code-only"],   description "29 slash commands for Claude Code workflows"
- tk-framework-rules: version 4.5.0, category "rules",  tags ["framework-templates","code-only"], description "7 framework CLAUDE.md template fragments (Laravel, Rails, Next.js, Node.js, Python, Go, base)"

Existing 22 skills directory (verified via `ls templates/skills-marketplace/`):
ai-models, analytics-tracking, chrome-extension-development, copywriting, docx,
find-skills, firecrawl, i18n-localization, memo-skill, next-best-practices,
notebooklm, pdf, resend, seo-audit, shadcn, stripe-best-practices,
tailwind-design-system, typescript-advanced-types, ui-ux-pro-max,
vercel-composition-patterns, vercel-react-best-practices, webapp-testing.

Symlink convention (verified in CONTEXT.md File Layout):

```text
plugins/tk-skills/skills            → ../../templates/skills-marketplace
plugins/tk-commands/commands        → ../../commands
plugins/tk-framework-rules/templates → ../../templates
```

NOTE: The symlinks use RELATIVE paths so the tree stays portable across clones
and CI checkouts. Absolute paths break under `claude plugin marketplace add` from
a different worktree.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create .claude-plugin/marketplace.json + plugin.json for all three sub-plugins</name>
  <files>
    .claude-plugin/marketplace.json,
    plugins/tk-skills/.claude-plugin/plugin.json,
    plugins/tk-commands/.claude-plugin/plugin.json,
    plugins/tk-framework-rules/.claude-plugin/plugin.json
  </files>
  <read_first>
    - .planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md (decision blocks)
    - manifest.json (lines 1-10 — confirm current version is 4.4.0 — 4.5.0 bump happens in Plan 04, but plugin.json declares 4.5.0 NOW per MKT-02)
  </read_first>
  <action>
1. Create directory `.claude-plugin/` at repo root (sibling to `manifest.json`).

2. Write `.claude-plugin/marketplace.json` with EXACTLY this content
   (4-space indent, trailing newline, no extra keys):

   ```json
   {
     "name": "claude-code-toolkit",
     "owner": {
       "name": "sergei-aronsen"
     },
     "plugins": [
       {
         "name": "tk-skills",
         "source": "./plugins/tk-skills"
       },
       {
         "name": "tk-commands",
         "source": "./plugins/tk-commands"
       },
       {
         "name": "tk-framework-rules",
         "source": "./plugins/tk-framework-rules"
       }
     ]
   }
   ```

   CRITICAL: do NOT add a `"version"` field to any object inside `plugins[]`.
   Per MKT-02 the version source-of-truth is each sub-plugin's `plugin.json`.

3. Create directory tree:
   ```
   plugins/tk-skills/.claude-plugin/
   plugins/tk-commands/.claude-plugin/
   plugins/tk-framework-rules/.claude-plugin/
   ```

4. Write `plugins/tk-skills/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "tk-skills",
     "version": "4.5.0",
     "description": "22 curated skills mirrored from skills.sh — Claude Desktop Code tab compatible",
     "category": "skills",
     "tags": ["mirror", "marketplace", "desktop-compatible"]
   }
   ```

5. Write `plugins/tk-commands/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "tk-commands",
     "version": "4.5.0",
     "description": "29 slash commands for Claude Code workflows — Code terminal only",
     "category": "commands",
     "tags": ["slash-commands", "code-only"]
   }
   ```

6. Write `plugins/tk-framework-rules/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "tk-framework-rules",
     "version": "4.5.0",
     "description": "7 framework CLAUDE.md template fragments (Laravel, Rails, Next.js, Node.js, Python, Go, base) — Code terminal only",
     "category": "rules",
     "tags": ["framework-templates", "code-only"]
   }
   ```

7. Validate every file with `python3 -c "import json,sys; json.load(open(sys.argv[1]))" <file>`
   for all 4 JSON files. Each must parse without errors.

8. Commit: `git add .claude-plugin/ plugins/tk-skills/.claude-plugin/ plugins/tk-commands/.claude-plugin/ plugins/tk-framework-rules/.claude-plugin/ && git commit -m "feat(27): add marketplace.json + 3 sub-plugin manifests (MKT-01, MKT-02)"`
  </action>
  <verify>
    <automated>
test "$(jq -r '.name' .claude-plugin/marketplace.json)" = "claude-code-toolkit" \
  && test "$(jq -r '.owner.name' .claude-plugin/marketplace.json)" = "sergei-aronsen" \
  && test "$(jq -r '.plugins | length' .claude-plugin/marketplace.json)" = "3" \
  && test "$(jq -r '.plugins[0].name' .claude-plugin/marketplace.json)" = "tk-skills" \
  && test "$(jq -r '.plugins[1].name' .claude-plugin/marketplace.json)" = "tk-commands" \
  && test "$(jq -r '.plugins[2].name' .claude-plugin/marketplace.json)" = "tk-framework-rules" \
  && ! jq -e '.plugins[] | has("version")' .claude-plugin/marketplace.json >/dev/null \
  && test "$(jq -r '.version' plugins/tk-skills/.claude-plugin/plugin.json)" = "4.5.0" \
  && test "$(jq -r '.category' plugins/tk-skills/.claude-plugin/plugin.json)" = "skills" \
  && test "$(jq -r '.version' plugins/tk-commands/.claude-plugin/plugin.json)" = "4.5.0" \
  && test "$(jq -r '.category' plugins/tk-commands/.claude-plugin/plugin.json)" = "commands" \
  && test "$(jq -r '.version' plugins/tk-framework-rules/.claude-plugin/plugin.json)" = "4.5.0" \
  && test "$(jq -r '.category' plugins/tk-framework-rules/.claude-plugin/plugin.json)" = "rules" \
  && echo "PASS: all 4 JSON files schema-valid"
    </automated>
  </verify>
  <done>
    - `.claude-plugin/marketplace.json` exists with 3 plugin entries, no `version` keys inside `plugins[]`
    - 3 `plugins/tk-*/.claude-plugin/plugin.json` files exist, each with `"version": "4.5.0"` and the documented `category` + `tags`
    - All 4 JSON files parse via `python3 -c "import json"`
    - `jq -e '.plugins[] | has("version")' .claude-plugin/marketplace.json` exits non-zero (no embedded versions)
  </done>
  <acceptance_criteria>
    - File `.claude-plugin/marketplace.json` exists and `jq '.plugins | length'` returns `3`
    - For each of `tk-skills` / `tk-commands` / `tk-framework-rules`: `plugins/<name>/.claude-plugin/plugin.json` exists with `.version == "4.5.0"`, non-empty `.category`, and `.tags` array of length ≥ 1
    - `jq -e '.plugins[] | has("version")' .claude-plugin/marketplace.json` returns exit 1 (zero plugin entries embed a version field)
    - Tags assertions: tk-skills tags include `"mirror"` AND `"marketplace"`; tk-commands tags include `"code-only"`; tk-framework-rules tags include `"code-only"`
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: Create symlink trees for the three sub-plugins + LICENSE reference for tk-skills</name>
  <files>
    plugins/tk-skills/skills,
    plugins/tk-skills/LICENSE,
    plugins/tk-commands/commands,
    plugins/tk-framework-rules/templates
  </files>
  <read_first>
    - .planning/phases/27-marketplace-publishing-claude-desktop-reach/27-CONTEXT.md (File Layout block)
  </read_first>
  <action>
1. Create relative symlinks from each sub-plugin into the canonical repo content:

   ```bash
   # All commands MUST be run from repo root.
   ln -s ../../templates/skills-marketplace plugins/tk-skills/skills
   ln -s ../../commands                     plugins/tk-commands/commands
   ln -s ../../templates                    plugins/tk-framework-rules/templates
   ```

   The relative paths (`../../`) ensure the symlinks resolve regardless of where
   the repo is cloned (CI runners, user worktrees, hermetic test sandboxes).

2. Create LICENSE symlink for tk-skills (Desktop-distributed sub-plugin needs
   reachable license per upstream marketplace conventions):

   ```bash
   ln -s ../../LICENSE plugins/tk-skills/LICENSE
   ```

   tk-commands and tk-framework-rules are Code-only and discovered through the
   parent repo's LICENSE; no dedicated LICENSE entry required for them.

3. Verify each symlink resolves:

   ```bash
   test -d plugins/tk-skills/skills/ai-models  # via templates/skills-marketplace/ai-models/
   test -d plugins/tk-commands/commands        # via repo commands/
   test -d plugins/tk-framework-rules/templates  # via repo templates/
   test -f plugins/tk-skills/LICENSE           # via repo LICENSE
   ```

4. Verify SKILL.md files are reachable through tk-skills symlink:
   ```bash
   test -f plugins/tk-skills/skills/ai-models/SKILL.md
   test -f plugins/tk-skills/skills/webapp-testing/SKILL.md
   ```

5. Commit: `git add plugins/tk-skills/skills plugins/tk-skills/LICENSE plugins/tk-commands/commands plugins/tk-framework-rules/templates && git commit -m "feat(27): add symlink trees for marketplace sub-plugins (MKT-02)"`

   IMPORTANT: `git add` of a symlink stages the symlink itself, not the target
   contents. Verify with `git ls-files --stage plugins/` — entries should show
   mode `120000` (symlink).
  </action>
  <verify>
    <automated>
test -L plugins/tk-skills/skills \
  && test -L plugins/tk-commands/commands \
  && test -L plugins/tk-framework-rules/templates \
  && test -L plugins/tk-skills/LICENSE \
  && test -d plugins/tk-skills/skills/ai-models \
  && test -d plugins/tk-skills/skills/webapp-testing \
  && test -f plugins/tk-skills/skills/ai-models/SKILL.md \
  && test -d plugins/tk-commands/commands \
  && test -f plugins/tk-commands/commands/audit.md \
  && test -d plugins/tk-framework-rules/templates/laravel \
  && test -d plugins/tk-framework-rules/templates/nextjs \
  && test -f plugins/tk-skills/LICENSE \
  && test "$(git ls-files --stage plugins/tk-skills/skills | awk '{print $1}')" = "120000" \
  && echo "PASS: all 4 symlinks resolved and staged as symlinks"
    </automated>
  </verify>
  <done>
    - 4 symlinks exist (3 content dirs + LICENSE) and all resolve to existing targets
    - Symlinks use RELATIVE paths (no absolute paths starting with `/`)
    - Git stages them as mode `120000` (symlink), not as regular files
    - Sample skill SKILL.md files are readable through the symlink (`plugins/tk-skills/skills/ai-models/SKILL.md`)
  </done>
  <acceptance_criteria>
    - `test -L plugins/tk-skills/skills && test -L plugins/tk-skills/LICENSE && test -L plugins/tk-commands/commands && test -L plugins/tk-framework-rules/templates` all pass
    - Symlinks resolve: `ls plugins/tk-skills/skills/ | wc -l` returns ≥ 22 (one entry per mirrored skill)
    - Symlinks are RELATIVE: `readlink plugins/tk-skills/skills` returns `../../templates/skills-marketplace` (NOT an absolute path)
    - Git records as symlinks: `git ls-files --stage plugins/tk-commands/commands | awk '{print $1}'` returns `120000`
  </acceptance_criteria>
</task>

</tasks>

<verification>
After both tasks:

1. Repository tree under `plugins/` has 3 sub-plugins each containing:
   - `.claude-plugin/plugin.json` (regular file, JSON-valid, version 4.5.0)
   - One symlink to canonical content (skills/ or commands/ or templates/)
   - LICENSE symlink (tk-skills only)

2. Repo-root `.claude-plugin/marketplace.json` lists 3 plugins by name + source.

3. `make check` should still pass — these are new files, no existing
   shell/markdown contract is touched. (`validate-marketplace` is added by Plan 02
   so its absence here is expected.)

Run: `make check` — must pass.
Run: `find plugins -name plugin.json | wc -l` — must equal `3`.
Run: `find plugins -type l | wc -l` — must equal `4` (3 content + 1 LICENSE).
</verification>

<success_criteria>
- `.claude-plugin/marketplace.json` declares 3 sub-plugins (`tk-skills`, `tk-commands`, `tk-framework-rules`) with `source` paths and no embedded `version` fields (MKT-01)
- 3 sub-plugin `plugin.json` files declare version 4.5.0 + the documented `category`/`tags`/`description` (MKT-02)
- 3 content symlinks (`skills/`, `commands/`, `templates/`) resolve from each sub-plugin to the canonical repo content via RELATIVE paths
- 1 LICENSE symlink under `plugins/tk-skills/` resolves to repo-root LICENSE
- `make check` continues to pass (no regressions in existing markdown/shellcheck/validate gates)
- Git records symlinks with mode `120000` (true symlinks, not directory copies)
</success_criteria>

<output>
After completion, create `.planning/phases/27-marketplace-publishing-claude-desktop-reach/27-01-marketplace-surface-SUMMARY.md` with:

- `requirements_addressed: [MKT-01, MKT-02]`
- `files_created`: list all 4 JSON files
- `symlinks_created`: list all 4 symlinks (target + path)
- Note: marketplace smoke validation (`claude plugin marketplace add ./`) is gated to Plan 02
</output>
