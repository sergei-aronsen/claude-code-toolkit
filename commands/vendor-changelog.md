---
name: vendor-changelog
description: Functional diff analysis of pinned external vendors (Superpowers, GSD, Serena, better-model, claude-context, cc-safety-net, RTK). Clones fresh sources, diffs against manifest.json:vendor_pins, classifies each change as BREAKING / ADOPT / IGNORE / DEPRECATE. Use this when the toolkit user wants to know what changed upstream since the last toolkit release and what action items it generates.
---

# /vendor-changelog — Vendor Functional Diff Analysis

## Purpose

Solo founders building on AI-assisted toolchains depend on external maintainers
shipping useful changes (and not shipping breaking ones). The toolkit pins each
vendor at release time. This command reads those pins, fetches current vendor
HEAD, diffs the two, and returns an actionable report.

Complementary to `/vendor-audit` (which assesses **risk** — maintainer activity,
license drift, marketing pivots) — `/vendor-changelog` analyzes **content** —
what code/docs/contract actually changed.

## When to Use

- Before bumping toolkit version (so the release notes reflect upstream impact)
- Quarterly (combined with `/vendor-audit`) for a full health pass
- After hearing about a vendor release (e.g. Superpowers v0.50)
- Before adopting a new vendor feature into toolkit code paths

NOT for ad-hoc vendor lookup — for that, just `git log` directly inside
`_external/<vendor>/`.

## Usage

```text
/vendor-changelog                    # analyze all pinned vendors
/vendor-changelog --vendor <name>    # one vendor only
/vendor-changelog --deep             # use Supreme Council instead of single agent
/vendor-changelog --apply            # propose PR drafts for ADOPT/BREAKING items
/vendor-changelog --since <date>     # diff against a date instead of pinned commit
/vendor-changelog --depth <N>        # increase clone depth (default 200)
/vendor-changelog --dry-run          # preview what would be analyzed
```

## Critical context for the analysis

The analysis **must not rely on memorized knowledge** of vendor APIs. Vendor
versions evolve faster than model training cycles. The diffs in `_external/`
are the source of truth.

The prompt template injects:

- `ANALYSIS_DATE` — today (UTC)
- `TOOLKIT_VERSION` — from `manifest.json:version`
- `TOOLKIT_BUILD_DATE` — from `manifest.json:build_date`
- `DAYS_SINCE_BUILD` — `ANALYSIS_DATE - TOOLKIT_BUILD_DATE`

Every analysis prompt MUST start by acknowledging these values explicitly so
the agent does not default to memorized knowledge.

## Procedure

You should:

1. Verify `manifest.json:vendor_pins` exists and has at least one entry. If
   absent, tell the user to run `scripts/vendor/pin-vendors.sh` first.

2. Run `scripts/vendor/clone-pinned.sh` to ensure `_external/<vendor>/` is
   present and up to date for every pinned vendor. Use the toolkit-bundled
   script — do not reinvent.

3. Run `scripts/vendor/diff-summary.sh` to write `/tmp/vendor-diffs.md`.
   The script handles per-vendor commit listing, diff stat, CHANGELOG excerpt,
   and BREAKING marker detection.

4. Construct the analysis prompt. Use this template:

   ```text
   You are analyzing dependency changes for claude-code-toolkit.

   CRITICAL CONTEXT (use these, NOT memorized knowledge):
   - ANALYSIS_DATE: {ANALYSIS_DATE}
   - TOOLKIT_VERSION: {TOOLKIT_VERSION}
   - TOOLKIT_BUILD_DATE: {TOOLKIT_BUILD_DATE}
   - DAYS_SINCE_BUILD: {DAYS_SINCE_BUILD}

   You CANNOT rely on memorized knowledge of vendor versions or APIs.
   The diffs below are the source of truth for what changed.

   VENDOR DIFFS:
   {paste contents of /tmp/vendor-diffs.md}

   For each vendor change, classify:
   | Class | Definition |
   |-------|------------|
   | BREAKING | Toolkit must adapt or pin older version. |
   | ADOPT | New feature toolkit should integrate. |
   | IGNORE | Internal/cosmetic, no action. |
   | DEPRECATE | Vendor removed feature toolkit uses. |

   Output: structured markdown with:
   - Per-vendor table (Class | What changed | Toolkit file paths to modify | Suggested PR title)
   - Aggregated action item count by class
   - Top 3 risks
   - Recommended next steps (in priority order)

   For BREAKING items, identify exactly which toolkit files reference the
   broken API. Use grep over the toolkit repo (current working directory).
   ```

5. Run the analysis using either the current Claude session (single-agent
   mode, default) or `/council --personas vendor-skeptic,vendor-pragmatist`
   if `--deep` flag is given.

6. Write the report to `.planning/audits/vendor-changelog-YYYY-MM-DD.md`
   (use `date -u +%Y-%m-%d`).

7. Print summary to stdout — do NOT dump the full report. Format:

   ```text
   ✓ Vendor changelog analysis complete

   Report: .planning/audits/vendor-changelog-2026-05-07.md
   Summary:
     - 1 BREAKING (rtk hook contract change)
     - 2 ADOPT (Superpowers verification-before-completion v2, Serena Python LSP)
     - 14 IGNORE
     - 0 DEPRECATE

   Top action: address rtk BREAKING before next toolkit release.

   Run /vendor-changelog --apply to draft PRs for action items.
   ```

## Flags

- `--vendor <name>` — analyze only one vendor (e.g. `/vendor-changelog --vendor superpowers`)
- `--deep` — use Supreme Council (Gemini + ChatGPT) instead of single-agent. Costs ~$0.10-0.30. Use for major version bumps.
- `--apply` — after analysis, propose PR drafts for each ADOPT/BREAKING item. Does NOT push or open PRs — just stages changes on a feature branch for human review.
- `--since <date>` — diff against a specific date instead of pinned commit (useful for ad-hoc cross-version research).
- `--depth <N>` — clone depth (default 200). Increase for very long pin windows.
- `--dry-run` — show what would be analyzed, do not write a report.

## Storage

```text
.planning/audits/
├── vendor-changelog-2026-05-07.md   # current run
├── vendor-changelog-2026-04-07.md   # previous run
└── vendor-changelog-latest.md       # symlink to most recent
```

The symlink lets you `cat .planning/audits/vendor-changelog-latest.md` for
quick check after CI updates pins. After writing the report, update the
symlink:

```bash
ln -sfn "vendor-changelog-$(date -u +%Y-%m-%d).md" \
        .planning/audits/vendor-changelog-latest.md
```

## Integration with /update-deps

The dependency dashboard (`/update-deps`) shows installed-vs-latest version
numbers. This command shows **what those version diffs mean**. Together they
answer "should I update?" (numbers) and "what breaks if I do?" (content).

`/update-deps --analyze` invokes `/vendor-changelog` first, then renders the
dashboard with a "Functional changes" column.

## Manual pin on release

After cutting a release with `gh release create vX.Y.Z`, run
`scripts/vendor/pin-vendors.sh` manually and commit the resulting
`manifest.json:vendor_pins` block. The previous CI auto-pin workflow was
removed in v6.14.0 due to GitHub Actions firing phantom push-event run
failures regardless of the `on:` filter; the script side is unchanged.
See `components/vendor-pinning.md` for the manual recipe.

"Last release" = "last manual pin", so `/vendor-changelog` reports drift
since the most recent release where the maintainer ran the script.

## Risks & limitations

| Risk | Mitigate |
|------|----------|
| Vendor renames repo | `pin-vendors.sh` detects 404 on clone and emits a `⚠` per vendor; report still includes the rest. |
| Vendor force-pushes pinned commit | `diff-summary.sh` detects "pinned commit not in clone" and asks for `VENDOR_CLONE_DEPTH=1000`. |
| Clone-depth too shallow | Default 200 covers ~6 months of typical OSS cadence. Increase via `VENDOR_CLONE_DEPTH=` env. |
| Memorized vendor knowledge | The prompt template explicitly forbids it. Always re-derive from `_external/`. |
| Disk space (`_external/`) | Each vendor is shallow-cloned (~5-50 MB). 7 vendors ≈ 100-300 MB. |

## Output artifact spec

The report must include:

```markdown
# Vendor Changelog Analysis

**Generated:** YYYY-MM-DD UTC
**Toolkit version:** X.Y.Z (built YYYY-MM-DD, N days ago)

## Summary

- BREAKING: N
- ADOPT: N
- IGNORE: N
- DEPRECATE: N

## Top risks

1. <risk with vendor + impact>
2. ...

## Per-vendor analysis

### <vendor name>

**Pinned:** `<sha>` (<tag>) at <date>
**HEAD:** `<sha>` at <date>
**Commits since pin:** N

| Class | What changed | Toolkit files affected | Suggested PR title |
|-------|--------------|------------------------|---------------------|
| BREAKING | ... | scripts/foo.sh:42 | fix(vendor): adapt to <vendor> X breaking change |
| ADOPT | ... | components/bar.md | feat(vendor): integrate <vendor> Y feature |

### <next vendor>
...

## Recommended next steps

1. <highest priority action>
2. <next action>
3. ...
```

## When NOT to use

- Toolkit just released — pins are current, no drift to analyze.
- Vendor sources unavailable (no internet, repo deleted) — fall back to
  `/vendor-audit` for risk assessment.
- Single-vendor research — direct `git log` in `_external/<vendor>/` is faster.
