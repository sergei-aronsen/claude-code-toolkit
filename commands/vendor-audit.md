---
name: vendor-audit
description: Quarterly external dependency risk review — checks GSD, Superpowers, Morph, better-model, claude-context for maintainer activity, breaking change cadence, license drift
---

# /vendor-audit — Quarterly External Dependency Risk Review

## Purpose

Solo developers building real products on AI-assisted toolchains depend on external maintainers staying engaged and predictable. This command runs a structured quarterly check on every external dependency the toolkit recommends. Goal: catch maintainer drift, breaking-change cadence, license shifts, or marketing-driven priority changes BEFORE they break your workflow.

## When to Use

- Quarterly (every 3 months) — set calendar reminder
- After hearing news about any tool (acquisition, fork, security incident)
- Before committing to a new milestone that depends heavily on a specific tool

Not for ad-hoc one-off lookups — for those, just `gh api repos/<owner>/<repo>` directly.

## What It Audits

Five categories of external dependencies:

1. **Plugins** — GSD (gsd-build/get-shit-done), Superpowers (obra/superpowers)
2. **MCP servers** — Morph (morphllm), claude-context (zilliztech)
3. **npm tools** — better-model (talkstream/better-model)
4. **Supreme Council backends** — Gemini API, OpenAI API (model availability + pricing)
5. **Frameworks behind cheatsheets** — Laravel, Rails, Next.js, etc. (major version drift)

For each dependency:

- **Activity:** last commit date, recent commit cadence (per week)
- **Risk signals:** marketing pivot, memecoin/token launch, ownership change, license change
- **Breaking changes:** how many shipped in last 90 days?
- **Issues backlog:** open issues vs closed in last 90 days (healthy ratio = closed > opened)
- **CI health:** main branch CI green or red?

## Output

`.planning/audits/vendor-audit-YYYY-MM-DD.md` — structured report with:

- Status per dependency (GREEN / YELLOW / RED)
- Recommended actions (continue / pin version / prepare exit / abandon)
- Diff vs last quarter's audit (cadence trends)

## Usage

```text
/vendor-audit
```

Optional flags:

- `--dependency <name>` — audit only one (e.g., `/vendor-audit --dependency gsd`)
- `--since <date>` — compare against snapshot from a specific date
- `--dry-run` — show what would be checked, don't write report

## Procedure

For each external dependency:

1. **Fetch metadata** via `gh api repos/<owner>/<repo>`:
   - `pushed_at`, `updated_at`, `stargazers_count`, `open_issues_count`, `license`, `default_branch`

2. **Cadence analysis** via `gh api repos/<owner>/<repo>/commits?since=<90 days ago>`:
   - Count commits in last 90 days
   - Calculate weekly average
   - Compare against last audit's number

3. **Issue health** via `gh api repos/<owner>/<repo>/issues?state=all&since=<90 days ago>`:
   - Count opened vs closed
   - Healthy: closed/opened ≥ 0.7
   - Flag if backlog growing >20% per quarter

4. **License check** — compare `license.spdx_id` vs last audit. Any change = manual review.

5. **Marketing drift detection** — search recent README + commits for tokens/memecoins:
   - GSD has $GSD on Solana (known yellow flag)
   - Watch for token launches, "stake to vote", "join discord for whitelist"

6. **Breaking change scan** — recent CHANGELOG entries containing "BREAKING" / "breaking change":
   - >2 in 90 days = YELLOW
   - >5 in 90 days = RED (preparation for exit)

7. **Verdict per dependency:**
   - **GREEN** — continue normal use, no action
   - **YELLOW** — pin to current version, monitor monthly until next quarter
   - **RED** — prepare exit plan in next 60 days, document migration path

## Exit Plan Templates

For each high-risk dependency, the audit links to a pre-defined exit plan in the same report:

- **GSD exit** — switch to pure Superpowers + toolkit components (90% of GSD's value, controlled by you)
- **Superpowers exit** — embed the 14 skills directly into toolkit (MIT license allows)
- **Morph exit** — switch to native Edit + ripgrep
- **better-model exit** — manual `model:`/`effort:` frontmatter via toolkit-managed CLAUDE.md routing block
- **claude-context exit** — switch to Morph warpgrep_codebase_search

## Why This Matters for Non-Programmer Profile

Non-programmer cannot diagnose what broke when an external tool changes behavior. The audit catches structural risk (maintainer disengagement, vendor priority drift) BEFORE the failure shows up as cryptic runtime errors. Quarterly cadence is enough for solo workflows — daily checks would be paranoid; annual would miss trends.

## Output Format

```markdown
# Vendor Audit — 2026-MM-DD

| Dependency | Last commit | 90d commits | Open/closed | License | Verdict |
|---|---|---|---|---|---|
| GSD (gsd-build/get-shit-done) | 2026-04-30 | 47 | 12/8 | MIT | YELLOW (memecoin watch) |
| Superpowers (obra) | 2026-05-05 | 31 | 4/9 | MIT | GREEN |
| Morph MCP (morphllm) | ... | ... | ... | ... | ... |
| ... | ... | ... | ... | ... | ... |

## YELLOW: GSD memecoin signal

Last quarter: 1 marketing-related commit. This quarter: 4. Trending up.
Recommended: pin to v1.40.0 in toolkit's `recommended_versions.json`,
prepare migration script (estimated 1 day) to pure Superpowers + toolkit.

## RED: [if any]

[Full migration plan inline]

---

Next audit: 2026-MM-DD (3 months from now)
```

## Related

- `components/vendor-risk.md` — full methodology
- `components/external-tools-recommended.md` — current dependency list with rationale
- `scripts/check-better-model-drift.sh` — automated drift check for better-model
