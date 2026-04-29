# Skills Mirror

The Claude Code Toolkit ships a curated mirror of 22 skills under `templates/skills-marketplace/`.
Each skill is a static snapshot — committed bytes, version-pinned, offline-installable.
`scripts/install.sh --skills` copies selected skills to `~/.claude/skills/<name>/`.

## Mirror date

Snapshot taken: 2026-04-29

The mirror is a frozen point-in-time copy. Re-sync via `scripts/sync-skills-mirror.sh`
before each milestone where upstream skill content has changed.

## Re-sync procedure

For maintainers:

1. Ensure your local `~/.claude/skills/` contains the canonical upstream snapshot.
2. Run the standalone re-sync script:

   ```bash
   bash scripts/sync-skills-mirror.sh        # all 22 skills
   bash scripts/sync-skills-mirror.sh ai-models   # single skill
   bash scripts/sync-skills-mirror.sh --dry-run   # preview without writes
   ```

3. Verify the diff: `git diff templates/skills-marketplace/`.
4. Update the "Mirror date" above to today's date.
5. Update entries in the table below if upstream URLs changed.
6. Commit with message `docs(26): re-sync skills mirror to <YYYY-MM-DD>`.

The script is also exposed via `make sync-skills-mirror`.

## Skill catalog

| Skill | License | Upstream URL | Companion files |
|-------|---------|--------------|-----------------|
| ai-models | SKILL-LICENSE.md fallback | <https://skills.sh/ai-models> | SKILL.md |
| analytics-tracking | SKILL-LICENSE.md fallback | <https://skills.sh/analytics-tracking> | SKILL.md + companions |
| chrome-extension-development | SKILL-LICENSE.md fallback | <https://skills.sh/chrome-extension-development> | SKILL.md + companions |
| copywriting | SKILL-LICENSE.md fallback | <https://skills.sh/copywriting> | SKILL.md |
| docx | Upstream LICENSE | <https://skills.sh/docx> | SKILL.md |
| find-skills | SKILL-LICENSE.md fallback | <https://skills.sh/find-skills> | SKILL.md |
| firecrawl | SKILL-LICENSE.md fallback | <https://skills.sh/firecrawl> | SKILL.md + rules/ |
| i18n-localization | SKILL-LICENSE.md fallback | <https://skills.sh/i18n-localization> | SKILL.md |
| memo-skill | Upstream LICENSE | <https://skills.sh/memo-skill> | SKILL.md |
| next-best-practices | SKILL-LICENSE.md fallback | <https://skills.sh/next-best-practices> | SKILL.md |
| notebooklm | Upstream LICENSE | <https://skills.sh/notebooklm> | SKILL.md |
| pdf | Upstream LICENSE | <https://skills.sh/pdf> | SKILL.md + scripts/ + reference.md + forms.md |
| resend | SKILL-LICENSE.md fallback | <https://skills.sh/resend> | SKILL.md |
| seo-audit | SKILL-LICENSE.md fallback | <https://skills.sh/seo-audit> | SKILL.md |
| shadcn | SKILL-LICENSE.md fallback | <https://skills.sh/shadcn> | SKILL.md + agents/ + assets/ + cli.md + customization.md + evals/ + mcp.md + rules/ |
| stripe-best-practices | SKILL-LICENSE.md fallback | <https://skills.sh/stripe-best-practices> | SKILL.md |
| tailwind-design-system | SKILL-LICENSE.md fallback | <https://skills.sh/tailwind-design-system> | SKILL.md + references/ |
| typescript-advanced-types | SKILL-LICENSE.md fallback | <https://skills.sh/typescript-advanced-types> | SKILL.md |
| ui-ux-pro-max | SKILL-LICENSE.md fallback | <https://skills.sh/ui-ux-pro-max> | SKILL.md |
| vercel-composition-patterns | SKILL-LICENSE.md fallback | <https://skills.sh/vercel-composition-patterns> | SKILL.md |
| vercel-react-best-practices | SKILL-LICENSE.md fallback | <https://skills.sh/vercel-react-best-practices> | SKILL.md |
| webapp-testing | Upstream LICENSE | <https://skills.sh/webapp-testing> | SKILL.md |

License column values:

- `Upstream LICENSE` — preserved verbatim from upstream source
- `SKILL-LICENSE.md fallback` — upstream did not ship a license file; fair-use mirror
  exception per Plan 02; SKILL-LICENSE.md quotes upstream frontmatter `license:` field

## Verifying the License column

Run:

```bash
for d in templates/skills-marketplace/*/; do
    name="$(basename "$d")"
    if ls "${d}"LICENSE* 2>/dev/null | grep -q .; then
        echo "$name: upstream LICENSE"
    elif [[ -f "${d}SKILL-LICENSE.md" ]]; then
        echo "$name: SKILL-LICENSE.md fallback"
    else
        echo "$name: MISSING LICENSE"
    fi
done
```

Update the License column whenever the audit output changes.

## License-audit policy

Per SKILL-02:

- Every mirrored skill MUST have at least one license artifact (upstream `LICENSE*`
  OR `SKILL-LICENSE.md` fallback).
- The audit runs manually; CI does NOT enforce license correctness automatically
  (out of scope per CONTEXT.md Deferred Ideas).
- If upstream changes a skill's license, update the License column on the next re-sync.
