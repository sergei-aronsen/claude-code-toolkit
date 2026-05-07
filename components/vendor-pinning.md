# Vendor Pinning

> v6.3 — toolkit-side functional change tracking for external dependencies.

## Why

The toolkit overlays seven external projects:

- Superpowers (skills + workflows)
- Get Shit Done (planning commands)
- Serena (LSP-backed code search MCP)
- better-model (cost routing wrapper)
- claude-context (semantic vector search MCP)
- cc-safety-net (PreToolUse safety hook)
- RTK (token rewriter)

Every one of those changes faster than the model training cycle. Without an
automated mechanism, the agent reasons about vendor APIs from memorized
training data — which can be 6+ months stale.

Vendor pinning solves this by recording the exact commit + tag of each vendor
at the moment of every toolkit release, then exposing a workflow to diff
those pins against vendor HEAD when the maintainer wants an analysis.

## Architecture

### Storage — `manifest.json:vendor_pins`

```json
{
  "vendor_pins": {
    "superpowers": {
      "repo": "https://github.com/obra/superpowers",
      "tag": "v0.42.0",
      "commit": "abc123def456...",
      "pinned_at": "2026-05-06"
    },
    ...
  }
}
```

Schema:

| Field | Required | Notes |
|-------|----------|-------|
| `repo` | yes | Git URL — must be cloneable without auth (public). |
| `tag` | optional | Nearest tag at pin time. May be empty for vendors that don't tag. |
| `commit` | yes after first pin | Full 40-char SHA. `null` before first pin. |
| `pinned_at` | yes after first pin | ISO 8601 date (`YYYY-MM-DD`). `null` before first pin. |

### Scripts — `scripts/vendor/`

| Script | Purpose |
|--------|---------|
| `clone-pinned.sh` | Shallow-clones (or fetches) every vendor into `_external/<name>/`. Idempotent. Default depth 200 (≈6 months). |
| `diff-summary.sh` | For each vendor, writes structured markdown (commits + diff stat + CHANGELOG + BREAKING markers) to a target file. Consumed by `/vendor-changelog` analysis prompt. |
| `pin-vendors.sh` | Captures current HEAD of every vendor, updates `manifest.json:vendor_pins`. Atomic write via temp file + jq validation. Has DRY_RUN=1 mode. |

All three pass shellcheck `-S warning` and are POSIX-compatible (Bash 3.2+).

### Command — `/vendor-changelog`

Reads pins → runs scripts → constructs analysis prompt with explicit
`ANALYSIS_DATE` / `TOOLKIT_VERSION` / `TOOLKIT_BUILD_DATE` / `DAYS_SINCE_BUILD`
context (forbidding memorized knowledge) → writes
`.planning/audits/vendor-changelog-YYYY-MM-DD.md`.

Each change is classified:

| Class | Action |
|-------|--------|
| BREAKING | Toolkit must adapt or pin older version. |
| ADOPT | New feature toolkit should integrate. |
| IGNORE | Internal/cosmetic, no action. |
| DEPRECATE | Vendor removed feature toolkit uses. |

### Auto-pin on release — `.github/workflows/release-pin.yml`

Triggers on `v*` tag push. Runs `pin-vendors.sh`, commits to a feature branch
(`chore/pin-vendors-<tag>`), pushes for maintainer review. Does NOT auto-merge
to `main` — maintainer opens PR.

This means "last release" = "last pin", so `/vendor-changelog` always reports
drift relative to the most recent published toolkit version.

## Adding a new vendor

1. Append a new entry to `manifest.json:vendor_pins` with `repo`, leave
   `tag`/`commit`/`pinned_at` as `null`.
2. Run `scripts/vendor/pin-vendors.sh` locally to capture initial pin.
3. Commit + push.
4. Future releases auto-pin via the workflow.

## Removing a vendor

1. Delete entry from `manifest.json:vendor_pins`.
2. `rm -rf _external/<name>/`.
3. Document the removal in `CHANGELOG.md` (e.g. "v6.4: remove Morph from
   vendor catalog — replaced by Serena").

## Comparison with /vendor-audit

| Aspect | `/vendor-audit` | `/vendor-changelog` |
|--------|-----------------|----------------------|
| Frequency | Quarterly | Per-release or on-demand |
| Focus | Risk (maintainer activity, license, drift, pivots) | Content (commits, API changes, BREAKING markers) |
| Source | GitHub API metadata | Git clones + diff + CHANGELOG |
| Output | Risk report (GREEN/YELLOW/RED per dependency) | Action report (BREAKING/ADOPT/IGNORE/DEPRECATE per change) |
| Cost | ~$0 (gh-cli queries) | ~$0.05-0.30 if using --deep flag |

Run both quarterly for full coverage:

```text
/vendor-audit          # are vendors healthy?
/vendor-changelog      # what did they change?
```

## Risks

| Risk | Mitigate |
|------|----------|
| Pinned commit force-pushed | `diff-summary.sh` detects "pinned commit not in clone" and asks for deeper fetch. |
| Vendor archive/delete | `clone-pinned.sh` emits `⚠` per failed vendor, continues with rest. |
| Memorized knowledge contamination | `/vendor-changelog` prompt template explicitly forbids it; ANALYSIS_DATE/VERSION/DAYS_SINCE_BUILD are injected. |
| Stale `_external/` | Each run fetches before analysis. CI workflow always clones fresh. |
| Disk space | Shallow clones (~5-50 MB each). 7 vendors ≈ 100-300 MB total. Add `_external/` to `.gitignore`. |

## .gitignore

`_external/` is git-ignored — it's a workspace cache, not source code:

```text
# Vendor cache for /vendor-changelog
_external/
```

The pins themselves live in `manifest.json` (committed). The clones are
ephemeral.

## See also

- `commands/vendor-audit.md` — quarterly risk review (complementary)
- `components/vendor-risk.md` — vendor risk methodology
- `components/external-tools-recommended.md` — install matrix for the
  vendors being pinned
