# Skills Pin Research — 2026-05-17

Research artifact for `manifest.skills_pins` upstream-URL discovery. Companion to v6.35.0 (scaffold) and the v6.35.0 CHANGELOG "Research backlog" entry.

## Question

For each of the 23 catalog skills under `templates/skills-marketplace/`, identify the canonical upstream GitHub repository so `scripts/update-deps.sh probe_skill_pin <name>` can detect drift between the toolkit's hand-vendored mirror and the upstream source-of-truth.

## v6.35.0 baseline (shipped)

Two skills with grounded upstream URLs in repo content:

- `huashu-design` → `https://github.com/alchaincyf/huashu-design` (MIT, 13K stars per `project_v6172_shipped.md` memory pin).
- `resend` → `https://github.com/resend/resend-skills` (frontmatter homepage attribution).

Both ship with `_status: needs-initial-pin` because the maintainer must capture the upstream HEAD before the first drift check.

## v6.35.0 research finding (NOT yet shipped to manifest)

A `caveman:cavecrew-investigator` agent ran exhaustive canonical-pattern verification against the 21 remaining catalog skills (`git ls-remote --quiet --exit-code <url> HEAD` per candidate URL) and reached a single verdict:

**All 21 unknown skills are likely sourced from `https://github.com/anthropics/skills` monorepo** (HEAD at audit time: `f458cee31a7577a47ba0c9a101976fa599385174`, 2026-05-17).

The agent did NOT verify the per-skill subpath inside the monorepo, only that the monorepo URL itself resolves. Each catalog skill maps to a subdirectory like `skills/<name>/SKILL.md` (or similar) — verification per skill is the remaining gap.

## Schema implication for v6.36.0+

The current `skills_pins` shape `{repo, tag, commit, pinned_at, _status}` is per-skill, per-repo. A monorepo source needs an additional `path` field so `probe_skill_pin` can fetch the subpath HEAD instead of the whole-repo HEAD.

Proposed extension (v6.36.0):

```jsonc
"skills_pins": {
  "<skill-name>": {
    "repo": "https://github.com/anthropics/skills",
    "path": "skills/<name>",         // NEW — relative path inside the monorepo
    "tag": null,
    "commit": null,                  // SHA of the LAST commit touching <path>
    "pinned_at": "2026-05-17",
    "_status": "active"
  }
}
```

`probe_skill_pin` becomes:

```bash
# When path is non-empty, find the last commit touching that subtree:
git -c protocol.version=2 ls-remote --quiet "$repo" HEAD | head -1
# Then compare against the pinned commit — but pin is a path-scoped SHA,
# not the monorepo HEAD. Use:
#   git -C <local-clone> log -1 --format=%H -- <path>
# A maintainer-side helper script would refresh path-scoped SHAs.
```

Caveat: `git ls-remote` returns only refs, not per-path history. To detect drift on a path inside a monorepo without a local clone, the probe needs the GitHub API:

```bash
curl -s "https://api.github.com/repos/anthropics/skills/commits?path=<path>&per_page=1" \
  | jq -r '.[0].sha[0:12]'
```

This pulls in `gh` / API rate-limit considerations not present in the v6.35.0 scaffold.

## Verification per skill (still needed)

Per skill, confirm:

1. The subpath `skills/<name>/` (or equivalent) exists in `anthropics/skills` and contains a `SKILL.md`.
2. The content of `anthropics/skills/skills/<name>/SKILL.md` is byte-comparable to `templates/skills-marketplace/<name>/SKILL.md` (with the toolkit's allowable mirror-time modifications: frontmatter `allowed-tools`, paraphrased description, etc.).

If a skill's content does NOT match `anthropics/skills`, the monorepo assumption is wrong for that skill — fall back to manual research per skill.

## Open list

The 21 unknown-upstream skills:

```
ai-models                    likely anthropics/skills/ai-models
analytics-tracking           likely anthropics/skills/analytics-tracking
chrome-extension-development likely anthropics/skills/chrome-extension-development
copywriting                  likely anthropics/skills/copywriting
docx                         likely anthropics/skills/docx
find-skills                  likely anthropics/skills/find-skills
firecrawl                    likely anthropics/skills/firecrawl
i18n-localization            likely anthropics/skills/i18n-localization
memo-skill                   likely anthropics/skills/memo-skill OR third-party
next-best-practices          likely anthropics/skills/next-best-practices
notebooklm                   likely anthropics/skills/notebooklm
pdf                          likely anthropics/skills/pdf
seo-audit                    likely anthropics/skills/seo-audit
shadcn                       likely anthropics/skills/shadcn
stripe-best-practices        likely anthropics/skills/stripe-best-practices
tailwind-design-system       likely anthropics/skills/tailwind-design-system
typescript-advanced-types    likely anthropics/skills/typescript-advanced-types
ui-ux-pro-max                likely anthropics/skills/ui-ux-pro-max
vercel-composition-patterns  likely anthropics/skills/vercel-composition-patterns
vercel-react-best-practices  likely anthropics/skills/vercel-react-best-practices
webapp-testing               likely anthropics/skills/webapp-testing
```

## Recommended next step

A v6.36.0 PR that:

1. Extends `skills_pins` schema with optional `path` field (additive, no migration).
2. Adds the GitHub-API path-scoped commit lookup to `probe_skill_pin` (gated on path being non-empty).
3. Adds the 21 monorepo entries — but ONLY after content-equivalence verification per skill (the byte-comparison step above) for the 5 most-used skills. The other 16 wait for opportunistic verification.

Do NOT bulk-pin all 21 in one shot without per-skill content verification. The agent's "likely anthropics/skills" claim is unverified at the subpath level. Wrong pins surface as false drift in the dashboard forever.

## Constraints

- `manifest.skills_pins` is consumed by `scripts/update-deps.sh probe_skill_pin`. Schema change requires lockstep update.
- `huashu-design` and `resend` (v6.35.0 pins) are standalone repos — schema extension with optional `path` does NOT break them (omit field → standalone-repo behavior).
- The mirror itself is hand-vendored via `scripts/sync-skills-mirror.sh`. Pin refresh = maintainer-only operation. Automation would require a separate `scripts/refresh-skills-pins.sh` that wraps the GitHub API call per pinned skill.
