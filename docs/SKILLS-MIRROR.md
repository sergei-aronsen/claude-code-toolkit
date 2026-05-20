# Skills Mirror

The Claude Code Toolkit ships a curated mirror of **61 active skills** under
`templates/skills-marketplace/` (+ 1 no-upstream-found entry for the
toolkit-original `memo-skill`). Each skill is a static snapshot —
committed bytes, version-pinned, offline-installable, sha256-verified.

`scripts/install.sh --skills` copies selected skills to `~/.claude/skills/<name>/`.

## Mirror date

Snapshot taken: **2026-05-20** (v6.51.0 release).

The mirror is a frozen point-in-time copy per pinned upstream commit.
Re-sync via `scripts/sync-skills-mirror.sh` before each milestone where
upstream skill content has changed.

## Re-sync procedure

For maintainers:

1. Ensure your local `~/.claude/skills/` contains the canonical upstream snapshot
   (or use `--from-local` / `--from-remote` to control the source).
2. Run the standalone re-sync script:

   ```bash
   bash scripts/sync-skills-mirror.sh                    # all active skills
   bash scripts/sync-skills-mirror.sh --check            # diff vs upstream, no writes
   bash scripts/sync-skills-mirror.sh --apply ai-models  # apply drift for one skill
   bash scripts/sync-skills-mirror.sh --strict           # exit 1 on real drift (CI gate)
   ```

3. Verify the diff: `git diff templates/skills-marketplace/`.
4. Update the "Mirror date" above to today's date.
5. Update the catalog table below if upstream URLs or pins changed.
6. Commit with message `docs(skills): re-sync skills mirror to <YYYY-MM-DD>`.

The script is also exposed via `make sync-skills-mirror`.

## Skill catalog (61 active + 1 no-upstream)

Catalog is the authoritative live state of `manifest.json:skills_pins`.
Regenerate via `python3 -c "import json; [print(f'| {k} | {v[\"repo\"]} |') for k,v in json.load(open('manifest.json'))['skills_pins'].items()]"`.

### Marketing skills bundle (40 skills, v6.51.0)

Bulk-mirrored from canonical upstream
[coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills)
(29.6k★, MIT) at commit `114587831efbe7ac5c0a86afcb69e9cca6f728ce`.

`ab-testing`, `ad-creative`, `ads`, `ai-seo`, `analytics`, `aso`,
`churn-prevention`, `co-marketing`, `cold-email`, `community-marketing`,
`competitor-profiling`, `competitors`, `content-strategy`, `copy-editing`,
`copywriting`, `cro`, `customer-research`, `directory-submissions`,
`emails`, `free-tools`, `image`, `launch`, `lead-magnets`,
`marketing-ideas`, `marketing-psychology`, `onboarding`, `paywalls`,
`popups`, `pricing`, `product-marketing`, `programmatic-seo`,
`referrals`, `revops`, `sales-enablement`, `schema`, `seo-audit`,
`signup`, `site-architecture`, `social`, `video`.

Each skill mirror includes `SKILL.md` + `references/*.md` + `evals/evals.json`.

### Mysticaltech fork skills (2 skills, distinct names retained)

From [mysticaltech/marketingskills](https://github.com/mysticaltech/marketingskills)
(246★ downstream fork) — kept under distinct names that the fork renamed:

| Skill | Upstream subpath | Reason for distinct mirror |
|-------|------------------|----------------------------|
| `ab-test-setup` | `skills/ab-test-setup` | mysticaltech rename of `coreyhaines31/ab-testing` |
| `analytics-tracking` | `skills/analytics-tracking` | mysticaltech rename of `coreyhaines31/analytics` |

Both fork lineages coexist intentionally — content diverged after the fork.

### Per-skill source map (other 19 skills)

| Skill | Upstream Repo | Pinned commit (first 12 chars) |
|-------|---------------|--------------------------------|
| `ai-models` | <https://github.com/artofrawr/claude-control> | `5e8f37f650ef` |
| `chrome-extension-development` | <https://github.com/Mindrally/skills> | `47f47c12e62f` |
| `docx` | <https://github.com/anthropics/skills> | (anthropics monorepo) |
| `find-skills` | <https://github.com/anthropics/skills> | (anthropics monorepo) |
| `firecrawl` | <https://github.com/firecrawl/cli> | (path-scoped) |
| `huashu-design` | <https://github.com/alchaincyf/huashu-design> | `8e25b2370974` |
| `humanizer` | <https://github.com/blader/humanizer> | `8b3a17889fbf` |
| `i18n-localization` | <https://github.com/sickn33/antigravity-awesome-skills> | `2138ff8fd03e` |
| `memo-skill` | _(toolkit-original — no upstream)_ | n/a |
| `next-best-practices` | <https://github.com/vercel-labs/agent-skills> | (vercel-labs) |
| `notebooklm` | <https://github.com/wshobson/agents> | (wshobson agents) |
| `pdf` | <https://github.com/anthropics/skills> | (anthropics monorepo) |
| `resend` | <https://github.com/resend/resend-skills> | (canonical resend) |
| `shadcn` | <https://github.com/shadcn-ui/ui> | (shadcn-ui/ui) |
| `stripe-best-practices` | <https://github.com/stripe/ai> | (canonical stripe) |
| `tailwind-design-system` | (gh-search-derived) | (path-scoped) |
| `typescript-advanced-types` | (gh-search-derived) | (path-scoped) |
| `ui-ux-pro-max` | <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill> | (canonical nextlevelbuilder) |
| `vercel-composition-patterns` | <https://github.com/vercel-labs/agent-skills> | (vercel-labs) |
| `vercel-react-best-practices` | <https://github.com/vercel-labs/skills> | (vercel-labs) |
| `webapp-testing` | <https://github.com/anthropics/skills> | (anthropics monorepo) |

For exact pinned SHAs + sha256 mirror checksums per skill, see
`manifest.json:skills_pins[<name>]`.

## License policy

Per SKILL-02:

- Every mirrored skill MUST have at least one license artifact — upstream
  `LICENSE*` file in the mirror dir OR `SKILL-LICENSE.md` fallback that
  quotes the upstream frontmatter `license:` field.
- The audit runs manually; CI does NOT enforce license correctness
  automatically (out of scope per CONTEXT.md Deferred Ideas).
- If upstream changes a skill's license, update the catalog above on the
  next re-sync.

### License-audit one-liner

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

## Drift detection

`scripts/sync-skills-mirror.sh --check` performs a 3-way classification
per skill:

- **CLEAN** — mirror sha256 matches the manifest-declared sha256.
- **SOFT** — content differs only in whitespace / line-endings /
  markdownlint-style cosmetic edits. `--strict` does NOT fail on SOFT.
- **DRIFT** — real content drift. `--strict` exits 1.

Use `--normalize` to recompute sha256 after the normalization filter
(strip CRLF→LF, strip trailing whitespace per line, collapse 3+
consecutive blank lines to 2, ensure trailing newline). Lets you
distinguish raw upstream drift from cosmetic mirror-ingestion artifacts.

## Trajectory

- **v6.35.0** (2026-05-17): schema introduced, 2 pins (`huashu-design`, `resend`).
- **v6.37.0** (2026-05-17): `+path` field for monorepo subpath probes, +3 anthropics.
- **v6.41.0** (2026-05-17): +4 vercel / firecrawl.
- **v6.44.0** (2026-05-18): +12 confirmed via gh-search + majiayu000 registry → 22 active.
- **v6.46.0** (2026-05-18): `+sha256` field, closed-loop sync, mirror↔manifest drift.
- **v6.47.0** (2026-05-18): hardened sync — atomic swap, post-checkout SHA verify, CLEAN/SOFT/DRIFT.
- **v6.50.0** (2026-05-20): +humanizer (`blader/humanizer`) → 23 active.
- **v6.51.0** (2026-05-20): +38 from `coreyhaines31/marketingskills` + migrate
  copywriting + seo-audit → 61 active.
