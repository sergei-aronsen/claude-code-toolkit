---
phase: 26
plan: "02"
type: execute
wave: 1
depends_on: []
files_modified:
  - templates/skills-marketplace/ai-models/
  - templates/skills-marketplace/analytics-tracking/
  - templates/skills-marketplace/chrome-extension-development/
  - templates/skills-marketplace/copywriting/
  - templates/skills-marketplace/docx/
  - templates/skills-marketplace/find-skills/
  - templates/skills-marketplace/firecrawl/
  - templates/skills-marketplace/i18n-localization/
  - templates/skills-marketplace/memo-skill/
  - templates/skills-marketplace/next-best-practices/
  - templates/skills-marketplace/notebooklm/
  - templates/skills-marketplace/pdf/
  - templates/skills-marketplace/resend/
  - templates/skills-marketplace/seo-audit/
  - templates/skills-marketplace/shadcn/
  - templates/skills-marketplace/stripe-best-practices/
  - templates/skills-marketplace/tailwind-design-system/
  - templates/skills-marketplace/typescript-advanced-types/
  - templates/skills-marketplace/ui-ux-pro-max/
  - templates/skills-marketplace/vercel-composition-patterns/
  - templates/skills-marketplace/vercel-react-best-practices/
  - templates/skills-marketplace/webapp-testing/
autonomous: true
requirements: [SKILL-01, SKILL-02]
must_haves:
  truths:
    - "All 22 curated skill directories exist under templates/skills-marketplace/"
    - "Each mirrored skill has a SKILL.md file with valid YAML frontmatter at directory root"
    - "Each mirrored skill ships its companion files (subdirectories like references/, scripts/, agents/, assets/, rules/, evals/, plus AUTHENTICATION.md, LICENSE.txt, etc.) where the source provides them"
    - "Every mirrored skill has a license file preserved (LICENSE / LICENSE.txt / SKILL-LICENSE.md fallback) per SKILL-02"
    - "templates/skills-marketplace/ contents are loadable by Claude Code if copied unchanged to ~/.claude/skills/"
  artifacts:
    - path: "templates/skills-marketplace/ai-models/SKILL.md"
      provides: "ai-models skill mirrored"
      contains: "name:"
    - path: "templates/skills-marketplace/pdf/SKILL.md"
      provides: "pdf skill mirrored (sample with companion files)"
      contains: "name:"
    - path: "templates/skills-marketplace/tailwind-design-system/SKILL.md"
      provides: "tailwind-design-system skill mirrored"
      contains: "name:"
    - path: "templates/skills-marketplace/webapp-testing/SKILL.md"
      provides: "webapp-testing skill mirrored (last alphabetical)"
      contains: "name:"
  key_links:
    - from: "scripts/sync-skills-mirror.sh"
      to: "templates/skills-marketplace/"
      via: "cp -R from $HOME/.claude/skills/<name>/"
      pattern: "cp -R"
    - from: "templates/skills-marketplace/<name>/"
      to: "$HOME/.claude/skills/<name>/"
      via: "Plan 03 install.sh --skills branch via skills_install"
      pattern: "skills_install"
---

<objective>
Populate `templates/skills-marketplace/` with the committed snapshot of all 22 curated skills (SKILL-01) plus license preservation per skill (SKILL-02). This is the content layer the install path will copy from. Mirror is a STATIC SNAPSHOT — committed bytes, version-pinned, offline-installable. Not fetched at install time.

Purpose: Plan 03's `--skills` install branch and Plan 04's hermetic test both require these directories to exist. Without them the install path has nothing to copy.

Output: 22 directories under `templates/skills-marketplace/` populated by running `scripts/sync-skills-mirror.sh` (built in Plan 01) against the local source-of-truth at `$HOME/.claude/skills/`. Each directory contains the upstream SKILL.md plus all companion files. Each directory has a license file (LICENSE / LICENSE.txt) where the source provides one; otherwise a SKILL-LICENSE.md fallback documents the source attribution.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/26-skills-selector/26-CONTEXT.md
@scripts/sync-skills-mirror.sh

<interfaces>
<!-- The 22 curated skill names — alphabetical per SKILL-01 -->

ai-models, analytics-tracking, chrome-extension-development, copywriting, docx,
find-skills, firecrawl, i18n-localization, memo-skill, next-best-practices,
notebooklm, pdf, resend, seo-audit, shadcn, stripe-best-practices,
tailwind-design-system, typescript-advanced-types, ui-ux-pro-max,
vercel-composition-patterns, vercel-react-best-practices, webapp-testing

All 22 verified present in $HOME/.claude/skills/ (sourcing-from-local strategy per CONTEXT.md
"Skills already installed locally in ~/.claude/skills/ are sourced from there directly").

<!-- Sample skill structures observed in $HOME/.claude/skills/ -->
ai-models/             — SKILL.md only
analytics-tracking/    — SKILL.md + companions
chrome-extension-development/ — full bundle
docx/                  — SKILL.md
firecrawl/             — SKILL.md + rules/
pdf/                   — SKILL.md + scripts/ + reference.md + forms.md + LICENSE.txt
shadcn/                — SKILL.md + agents/ + assets/ + cli.md + customization.md + evals/ + mcp.md + rules/
tailwind-design-system/ — SKILL.md + references/
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Bulk-mirror 22 skills via sync-skills-mirror.sh</name>
  <read_first>
    - .planning/phases/26-skills-selector/26-CONTEXT.md (Mirror Architecture section, License Preservation section)
    - scripts/sync-skills-mirror.sh (Plan 01 Task 2 output)
    - scripts/lib/skills.sh (Plan 01 Task 1 output — confirm SKILLS_CATALOG order)
  </read_first>
  <files>
    templates/skills-marketplace/ai-models/, templates/skills-marketplace/analytics-tracking/,
    templates/skills-marketplace/chrome-extension-development/, templates/skills-marketplace/copywriting/,
    templates/skills-marketplace/docx/, templates/skills-marketplace/find-skills/,
    templates/skills-marketplace/firecrawl/, templates/skills-marketplace/i18n-localization/,
    templates/skills-marketplace/memo-skill/, templates/skills-marketplace/next-best-practices/,
    templates/skills-marketplace/notebooklm/, templates/skills-marketplace/pdf/,
    templates/skills-marketplace/resend/, templates/skills-marketplace/seo-audit/,
    templates/skills-marketplace/shadcn/, templates/skills-marketplace/stripe-best-practices/,
    templates/skills-marketplace/tailwind-design-system/, templates/skills-marketplace/typescript-advanced-types/,
    templates/skills-marketplace/ui-ux-pro-max/, templates/skills-marketplace/vercel-composition-patterns/,
    templates/skills-marketplace/vercel-react-best-practices/, templates/skills-marketplace/webapp-testing/
  </files>
  <action>
Verify all 22 skills exist locally (the sync-skills-mirror.sh script depends on them):

```bash
for s in ai-models analytics-tracking chrome-extension-development copywriting docx \
         find-skills firecrawl i18n-localization memo-skill next-best-practices \
         notebooklm pdf resend seo-audit shadcn stripe-best-practices \
         tailwind-design-system typescript-advanced-types ui-ux-pro-max \
         vercel-composition-patterns vercel-react-best-practices webapp-testing; do
    [[ -d "$HOME/.claude/skills/$s" ]] || echo "MISSING: $s"
done
```

If any skill is missing locally, STOP and report — Plan 02 cannot complete without all 22 sources. The user has confirmed all 22 are present (per planning context).

Run the bulk sync:
```bash
bash scripts/sync-skills-mirror.sh
```

This invokes the Plan 01 Task 2 script with no arguments, syncing all 22 catalog skills from `$HOME/.claude/skills/<name>/` to `templates/skills-marketplace/<name>/`. The expected final summary line is: `Synced: 22 · Missing: 0 · Total: 22`.

If the summary shows `Missing > 0`, do NOT proceed. Investigate which skills are missing and report back.

Verify each skill has a SKILL.md at the directory root (sanity check the snapshot):
```bash
for s in templates/skills-marketplace/*/; do
    [[ -f "${s}SKILL.md" ]] || echo "BROKEN: $s missing SKILL.md"
done
# Expected: no output (all 22 have SKILL.md)
```

Do NOT add any new content. Do NOT modify the SKILL.md frontmatter. The mirror is a faithful upstream snapshot; modifications are out of scope for this plan.
  </action>
  <verify>
    <automated>
      [ -d templates/skills-marketplace ] && ls templates/skills-marketplace/ | wc -l | tr -d ' '
      # MUST output: 22

      ls templates/skills-marketplace/ | sort | head -1
      # MUST output: ai-models

      ls templates/skills-marketplace/ | sort | tail -1
      # MUST output: webapp-testing

      for s in ai-models analytics-tracking chrome-extension-development copywriting docx find-skills firecrawl i18n-localization memo-skill next-best-practices notebooklm pdf resend seo-audit shadcn stripe-best-practices tailwind-design-system typescript-advanced-types ui-ux-pro-max vercel-composition-patterns vercel-react-best-practices webapp-testing; do
          [[ -f "templates/skills-marketplace/${s}/SKILL.md" ]] || echo "MISSING_SKILL_MD: $s"
      done
      # MUST output nothing (all 22 have SKILL.md)
    </automated>
  </verify>
  <acceptance_criteria>
    - `templates/skills-marketplace/` exists.
    - `ls templates/skills-marketplace/ | wc -l` returns exactly `22`.
    - All 22 specific directories exist (alphabetical order: ai-models through webapp-testing).
    - Every directory contains a `SKILL.md` file at its root.
    - Companion files preserved where source provides them: `templates/skills-marketplace/pdf/scripts/` exists, `templates/skills-marketplace/shadcn/cli.md` exists, `templates/skills-marketplace/tailwind-design-system/references/` exists.
    - YAML frontmatter intact: `head -3 templates/skills-marketplace/ai-models/SKILL.md` shows `---` ... `name: ai-models` ... structure.
    - No `node_modules/`, `.git/`, or other dev junk inside any mirror dir (sync script does straight cp -R from upstream skill dirs which never contain these).
  </acceptance_criteria>
  <done>22 skill directories committed under templates/skills-marketplace/. Each contains SKILL.md + companion files faithfully mirrored from the local source. Plan 03 install branch can now copy from this layer.</done>
</task>

<task type="auto">
  <name>Task 2: Verify license preservation; add SKILL-LICENSE.md fallback where upstream LICENSE is absent</name>
  <read_first>
    - .planning/phases/26-skills-selector/26-CONTEXT.md (License Preservation section)
    - templates/skills-marketplace/pdf/LICENSE.txt (sample upstream LICENSE)
    - templates/skills-marketplace/ai-models/SKILL.md (frontmatter for license fallback content)
  </read_first>
  <files>
    templates/skills-marketplace/{name}/SKILL-LICENSE.md
    (created only for skills lacking an upstream LICENSE file — count and exact list determined by audit step)
  </files>
  <action>
Per SKILL-02 + CONTEXT.md "License Preservation":
> If upstream lacks a LICENSE, fall back to `SKILL-LICENSE.md` quoting the SKILL.md frontmatter `license:` field (or note "License not provided upstream — included under fair use mirror exception").

Run the audit script to find skills missing a license file:
```bash
for d in templates/skills-marketplace/*/; do
    name="$(basename "$d")"
    if ! ls "${d}"LICENSE* 2>/dev/null | grep -q .; then
        echo "NEEDS_FALLBACK: $name"
    fi
done
```

The audit will produce a list. For each skill in the list, create `templates/skills-marketplace/<name>/SKILL-LICENSE.md` with one of the two formats below.

**Format A** — when `SKILL.md` frontmatter contains a `license:` field:

```markdown
# License — <name>

This skill is mirrored from upstream. The upstream `SKILL.md` frontmatter declares:

```text
license: <value-from-frontmatter>
```

The mirror in `templates/skills-marketplace/<name>/` is a snapshot dated <today's-date-YYYY-MM-DD>.
Re-sync via `scripts/sync-skills-mirror.sh`. The full source URL is recorded in `docs/SKILLS-MIRROR.md` (Plan 04).
```

**Format B** — when `SKILL.md` does not declare a license:

```markdown
# License — <name>

The upstream skill does not provide an explicit license file or `license:` frontmatter field.
Included under fair-use mirror exception for the purpose of redistribution alongside the
Claude Code Toolkit installer (`scripts/install.sh --skills`).

Mirror snapshot date: <today's-date-YYYY-MM-DD>.
Re-sync via `scripts/sync-skills-mirror.sh`. The full source URL is recorded in `docs/SKILLS-MIRROR.md` (Plan 04).
```

Determine format A vs B per skill via:
```bash
sed -n '/^---$/,/^---$/p' "templates/skills-marketplace/<name>/SKILL.md" | grep -E '^license:'
```

If the grep matches → Format A using the matched value. Otherwise → Format B.

Create only the SKILL-LICENSE.md files needed (do NOT create SKILL-LICENSE.md for skills that already have an upstream LICENSE/LICENSE.txt file — that would be redundant).

Mark every SKILL-LICENSE.md fallback file with the same date (today's date) for consistency.

Do NOT modify any upstream SKILL.md. Do NOT modify any upstream LICENSE file. The fallback is purely additive.

Verify outcome:
```bash
for d in templates/skills-marketplace/*/; do
    name="$(basename "$d")"
    if ! ls "${d}"LICENSE* "${d}"SKILL-LICENSE.md 2>/dev/null | grep -q .; then
        echo "STILL_MISSING_LICENSE: $name"
    fi
done
# Expected: no output — every directory has at least one of LICENSE / LICENSE.txt / SKILL-LICENSE.md
```
  </action>
  <verify>
    <automated>
      # Every mirror dir has a license file (upstream OR fallback)
      missing=0
      for d in templates/skills-marketplace/*/; do
          name="$(basename "$d")"
          if ! ls "${d}"LICENSE* "${d}"SKILL-LICENSE.md 2>/dev/null | grep -q .; then
              echo "MISSING: $name"
              missing=$((missing + 1))
          fi
      done
      [[ $missing -eq 0 ]] && echo "all-licensed"
      # MUST output: all-licensed

      # Markdownlint clean on any fallbacks created
      find templates/skills-marketplace -name SKILL-LICENSE.md -print0 | xargs -0 markdownlint 2>&1 | tail -5
      # MUST exit 0 with no errors
    </automated>
  </verify>
  <acceptance_criteria>
    - For each of the 22 mirror dirs: at least one of `LICENSE`, `LICENSE.txt`, `LICENSE.md`, or `SKILL-LICENSE.md` exists.
    - Every newly-created `SKILL-LICENSE.md` follows Format A or Format B and includes the mirror date.
    - markdownlint passes for all SKILL-LICENSE.md files (MD040 fenced code blocks tagged, no trailing punctuation in headings, no double-blank-line issues).
    - No upstream LICENSE / SKILL.md files modified.
  </acceptance_criteria>
  <done>Every mirrored skill has a license file. Skills lacking an upstream LICENSE got a SKILL-LICENSE.md fallback (Format A or B) per SKILL-02. markdownlint passes.</done>
</task>

</tasks>

<verification>
After both tasks:

1. `ls templates/skills-marketplace/ | wc -l` → `22`
2. `find templates/skills-marketplace -name SKILL.md | wc -l` → `22`
3. `for d in templates/skills-marketplace/*/; do ls "$d"{LICENSE*,SKILL-LICENSE.md} 2>/dev/null | head -1; done | wc -l` → `22`
4. `markdownlint 'templates/skills-marketplace/**/*.md' --ignore-path .markdownlintignore` exit 0 (existing repo lint config)
5. `make check` (full repo gate) still passes (NOTE: if a particular upstream SKILL.md violates a markdownlint rule we'd have surfaced this in Plan 03/04 testing; per CONTEXT.md the mirror is faithful — modifications are out of scope. If markdownlint fails on imported content, add to `.markdownlintignore` rather than modify the source.)

If `make check` fails on imported skill content (a known risk for upstream content not authored under this repo's conventions), the resolution is to add `templates/skills-marketplace/` to `.markdownlintignore` — coordinate this with Plan 04 since Plan 04 owns lint wiring updates.
</verification>

<success_criteria>
- All 22 skill directories under `templates/skills-marketplace/`, alphabetical, faithfully mirroring upstream content.
- Every mirror dir has a license artifact (upstream LICENSE OR generated SKILL-LICENSE.md fallback).
- Companion files (subdirs and aux markdown) preserved where source provides them.
- No modification of upstream SKILL.md or LICENSE files.
- Mirror is a static snapshot — Plan 03 install branch will copy from these directories at install time.
</success_criteria>

<output>
After completion, create `.planning/phases/26-skills-selector/26-02-mirror-content-snapshot-SUMMARY.md`. Include in the SUMMARY: total bytes added (rough — `du -sh templates/skills-marketplace/`), count of upstream LICENSE files vs SKILL-LICENSE.md fallbacks, and any markdownlint adjustments needed (e.g. if `templates/skills-marketplace/` was added to `.markdownlintignore`).
</output>
