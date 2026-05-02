# Phase 33: Catalog Population — 11 New Entries + Drop + Re-categorize — Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** Auto-discuss (decisions distilled from milestone-scoping conversation; package names verified at execution time)

<domain>
## Phase Boundary

Mutate `scripts/lib/integrations-catalog.json` (now schema-v2 from Phase 32) to its final 19-entry shape:

- **Add 12 new entries** (INT-01..12): supabase, cloudflare, stripe, aws-cost-explorer, aws-cloudwatch-logs, notebooklm, youtrack, linear, jira, figma, slack, telegram.
- **Drop 1 entry** (DROP-01): sequential-thinking — native Claude extended thinking covers the use case.
- **Re-categorize 8 surviving existing entries** (EXIST-01): context7, firecrawl, magic, notion, openrouter, playwright, resend, sentry — confirm/replace existing category assignments. Add optional `cli` blocks to `firecrawl`, `playwright`, `sentry` whose CLIs add real value.
- **AWS shared CLI** — both `aws-cost-explorer` and `aws-cloudwatch-logs` reference the same `aws` CLI block. Installer dedupes by `cli.detect_cmd` (Phase 34 TUI work); Phase 33 just emits the same CLI block in both entries.

**Phase 33 is data-only.** No code changes. No new scripts. JSON mutations + validator must stay green + 21-assertion `test-mcp-selector.sh` baseline must not regress.

REQ-IDs covered: INT-01..12 (12), DROP-01, EXIST-01 (14 of 36).

</domain>

<decisions>
## Implementation Decisions

### Package name verification policy

- **D-01:** For each new entry, the executor agent MUST verify the MCP npm package name exists on npm before committing it to the catalog. Use `npm view <pkg> name` or `WebFetch https://www.npmjs.com/package/<pkg>` — if a probe fails, fall back to the next-most-likely name from the candidate list (D-02..D-13) or flag for human review.
- **D-02:** Verification scope: package existence + most-recent-version date (must be within 12 months — sanity check freshness). Do NOT execute the MCP. Do NOT install dependencies during verification. Pure metadata read.
- **D-03:** When multiple equally-credible candidates exist (e.g., official vs community), prefer official > vendor-stewarded > community. Document the chosen package + alternatives evaluated in the plan SUMMARY.

### Per-entry catalog content (best-guesses; executor verifies)

For each entry below, the executor must populate this shape:

```json
"<name>": {
  "display_name": "<Display>",
  "category": "<canonical>",
  "components": {
    "mcp": {
      "install_args": ["<name>", "--", "npx", "-y", "<package>"],
      "env_var_keys": [...],
      "requires_oauth": <bool>,
      "description": "<short>"
    },
    "cli": {
      "detect_cmd": "<bin>",
      "install": {
        "darwin": "<cmd>",
        "linux": "<cmd>"
      },
      "post_install_hint": "<hint>"
    }
  },
  "unofficial": <true if applicable>
}
```

**INT-01 — supabase**
- Category: `backend`
- MCP package candidates (try in order): `@supabase/mcp-server-supabase`, `@supabase/mcp-server`, `supabase-mcp`
- env: `SUPABASE_ACCESS_TOKEN`
- requires_oauth: false
- CLI detect_cmd: `supabase`
- CLI install darwin: `brew install supabase/tap/supabase`
- CLI install linux: `curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz | sudo tar -xz -C /usr/local/bin supabase`
  - **NOTE:** This violates D-17 (no sudo). Fix to user-space install: `curl -fsSL https://supabase.com/install.sh | sh` IF such installer exists; otherwise use `npm i -g supabase` if published, else fall back to "see https://supabase.com/docs/guides/cli for your platform" hint-only entry. Executor decides at exec time based on what actually works without sudo.
- post_install_hint: `supabase login`

**INT-02 — cloudflare**
- Category: `backend`
- MCP package candidates: `@cloudflare/mcp-server-cloudflare`, `cloudflare-mcp`, or one of the 10+ Cloudflare-published MCPs (Workers, R2, KV). Pick the **single most general-purpose** one for the catalog (likely a "cloudflare" umbrella MCP if it exists, else stick with a focused one and document the limit).
- env: `CLOUDFLARE_API_TOKEN`
- requires_oauth: false
- CLI detect_cmd: `wrangler`
- CLI install darwin/linux: `npm install -g wrangler` (no sudo if Node is installed via nvm/asdf — flag in hint if user uses system Node)
- post_install_hint: `wrangler login`

**INT-03 — stripe**
- Category: `payments`
- MCP package candidates: `@stripe/mcp` (official agent-toolkit), `@stripe/agent-toolkit`
- env: `STRIPE_SECRET_KEY` (TEST mode by default — never live)
- requires_oauth: false
- CLI detect_cmd: `stripe`
- CLI install darwin: `brew install stripe/stripe-cli/stripe`
- CLI install linux: `wget -O stripe.tar.gz https://github.com/stripe/stripe-cli/releases/latest/download/stripe_linux_x86_64.tar.gz && tar -xzf stripe.tar.gz -C ~/.local/bin/ stripe && rm stripe.tar.gz` (user-space, no sudo). If complexity is too much for a one-liner, fall back to hint-only with link to `https://docs.stripe.com/stripe-cli`.
- post_install_hint: `stripe login`

**INT-04 — aws-cost-explorer**
- Category: `backend`
- MCP package candidates: `awslabs.cost-explorer-mcp-server`, `@awslabs/cost-explorer-mcp`. AWS Labs publishes via PyPI more than npm — may need `uvx` instead of `npx`. If npm package absent, install_args becomes `["aws-cost-explorer", "--", "uvx", "awslabs.cost-explorer-mcp-server@latest"]` provided uvx is available.
- env: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`
- requires_oauth: false
- CLI: SHARED with INT-05 (see below)

**INT-05 — aws-cloudwatch-logs**
- Category: `backend`
- MCP package candidates: `awslabs.cloudwatch-logs-mcp-server`. uvx fallback as above.
- env: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`
- requires_oauth: false
- CLI block (shared with INT-04):
  - detect_cmd: `aws`
  - install darwin: `brew install awscli`
  - install linux: `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install --install-dir ~/.local/aws-cli --bin-dir ~/.local/bin && rm -rf /tmp/aws /tmp/awscliv2.zip` (user-space). Fall back to vendor-recommended one-liner if shorter.
  - post_install_hint: `aws configure`

**INT-06 — notebooklm** (`unofficial: true`)
- Category: `docs-research`
- MCP package candidates: community packages — `mcp-server-notebooklm`, `notebooklm-mcp`, or wrap-around `nlm` CLI. **Verify currency**: if all candidates are >12 months stale and have <100 weekly downloads, flag entry as unbuildable and skip — better no entry than a broken default. Document decision in SUMMARY.
- env: none initially (browser auth via `nlm login` post-install)
- requires_oauth: true (Google account via `nlm login`)
- CLI detect_cmd: `nlm`
- CLI install darwin/linux: `pipx install nlm` if pypi package exists; else `pip install --user nlm`; else fallback to hint-only with `https://github.com/...nlm` link.
- post_install_hint: `nlm login`

**INT-07 — youtrack**
- Category: `project-management`
- MCP package candidates: `@jetbrains/mcp-server-youtrack`, `mcp-youtrack`, `youtrack-mcp`
- env: `YOUTRACK_URL`, `YOUTRACK_TOKEN`
- requires_oauth: false (permanent token from YouTrack profile)
- CLI: none

**INT-08 — linear**
- Category: `project-management`
- MCP package candidates: `@linear/mcp` (Linear-official, recently published), `linear-mcp`, `mcp-linear`
- env: `LINEAR_API_KEY`
- requires_oauth: false (personal API key)
- CLI: none

**INT-09 — jira** (Atlassian)
- Category: `project-management`
- MCP package candidates: `@atlassian/mcp-server`, `atlassian-mcp`, `mcp-atlassian`. Note: Atlassian provides both Cloud and Server flavors — catalog targets Cloud (more mainstream).
- env: `ATLASSIAN_URL`, `ATLASSIAN_EMAIL`, `ATLASSIAN_TOKEN`
- requires_oauth: false (API token from id.atlassian.com)
- CLI: none

**INT-10 — figma**
- Category: `design`
- MCP package candidates: `figma-developer-mcp` (Framelink, popular community), `@figma/mcp-server` (if official exists). Figma's official "Dev Mode MCP" is desktop-app-only — skip; pick the Framelink npm package which works headless.
- env: `FIGMA_API_KEY` (personal access token)
- requires_oauth: false
- CLI: none

**INT-11 — slack**
- Category: `communication`
- MCP package candidates: `@slack/mcp-server` (if Slack publishes one), `mcp-slack`, `slack-mcp`. Note: `@modelcontextprotocol/server-slack` was deprecated by Anthropic; community forks exist.
- env: `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID`
- requires_oauth: false (bot token)
- CLI: none

**INT-12 — telegram** (`unofficial: true`)
- Category: `communication`
- MCP package candidates: community — `telegram-mcp`, `mcp-telegram`, `mcp-server-telegram`. **Verify currency** as with notebooklm. Pin to specific version if community quality is mixed.
- env: `TELEGRAM_BOT_TOKEN`
- requires_oauth: false
- CLI: none

### Existing entry re-categorization

- **D-04:** Final categories for the 8 survivors (Phase 32 set best-guesses; Phase 33 confirms or fixes):
  - `context7` → `docs-research` ✓
  - `firecrawl` → `docs-research` ✓ + add CLI block (`firecrawl` npm package: `npm i -g @mendable/firecrawl-cli` if exists, else MCP-only)
  - `magic` → `dev-tools` (UI generation tool, fits dev-tools)
  - `notion` → `workspace` ✓
  - `openrouter` → `dev-tools` ✓ (multi-LLM router for dev experimentation)
  - `playwright` → `dev-tools` ✓ + add CLI block (`npm i -g @playwright/test` then `npx playwright install` for browsers — composite hint)
  - `resend` → `email` ✓
  - `sentry` → `monitoring` ✓ + add CLI block (`brew install getsentry/tools/sentry-cli` darwin / `curl -sL https://sentry.io/get-cli/ | bash` linux — vendor's official one-liner)

### DROP

- **D-05:** `sequential-thinking` deletion: simply remove the JSON key. No grep-rg sweep needed across the codebase — this entry was a single-file occurrence (catalog only). Validator must still pass post-delete.

### Plan structure (4 plans per STATE.md estimate)

- **D-06:** Plan 33-01: Backend cluster — INT-01 (supabase), INT-02 (cloudflare), INT-04 (aws-cost-explorer), INT-05 (aws-cloudwatch-logs). 4 entries; AWS shares CLI block.
- **D-07:** Plan 33-02: Payments + Project Management + Design — INT-03 (stripe), INT-07 (youtrack), INT-08 (linear), INT-09 (jira), INT-10 (figma). 5 entries.
- **D-08:** Plan 33-03: Communication + Research with `unofficial` flags — INT-06 (notebooklm), INT-11 (slack), INT-12 (telegram). 3 entries; 2 carry unofficial: true.
- **D-09:** Plan 33-04: DROP-01 (remove sequential-thinking) + EXIST-01 (re-categorize 8 + add CLI blocks to firecrawl/playwright/sentry). 9 mutations on existing entries.

Wave structure: 33-01, 33-02, 33-03 are parallel-safe in worktrees (each touches a different region of the catalog file but git can auto-merge JSON object additions when they touch different keys). 33-04 runs in Wave 2 because EXIST-01 mutates the same file regions Phase 32 produced + must run after the 12 new entries are present (so the validator final-state check sees all 19).

**Refinement:** Because all 4 plans mutate the SAME file (`integrations-catalog.json`), parallel worktrees will produce conflicts at merge. **Force sequential execution for Phase 33** — set `parallelization: false` for this phase (or simply run one wave at a time). This is faster than dealing with merge conflicts on a single 19-key JSON file.

- **D-10:** Phase 33 plans run **sequentially** (Wave 1: 33-01, Wave 2: 33-02, Wave 3: 33-03, Wave 4: 33-04). Each plan re-reads the current catalog state and adds/mutates. Validator passes after every plan.

### Validation cadence

- **D-11:** After EVERY plan: `python3 scripts/validate-integrations-catalog.py` must exit 0. After EVERY plan: `bash scripts/tests/test-mcp-selector.sh` must still pass 21/21 baseline. After Plan 33-04: count entries — must be exactly 19.
- **D-12:** Each plan ships a single commit with conventional commit prefix `feat(33-NN):` for new entries / `chore(33-04):` for the drop+recategorize plan.

### Sudo / privilege boundary

- **D-13:** Per Phase 32 D-17, NO entry's CLI install command may invoke `sudo`. Where vendor-recommended install requires `sudo` (e.g., supabase linux tarball), substitute user-space install OR fall back to **hint-only** (no `cli` block; just MCP block + post_install_hint that points to vendor docs). Executor decides per-entry at exec time. Document in SUMMARY which entries went hint-only.

### Worktree isolation gotcha

- **D-14:** Worktrees created from current main inherit the manifest.json including `cli-installer.sh` registration (Phase 32 Plan 32-02 deviation). Plans must NOT touch manifest.json — version bump is Phase 35 DIST-01.

### Claude's Discretion

- Exact ordering of keys within JSON entries (validator is shape-driven, not order-driven).
- Whether to use `npx -y` vs `npx --yes` (both work; pick whichever existing entries already use).
- Description text wording for new entries (must be <80 chars, terse, accurate).
- Whether to consolidate AWS env_vars list (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) or use AWS_PROFILE alternative — pick whichever the chosen MCP package documents.
- Best-effort matching of MCP package name when verification finds multiple candidates.

</decisions>

<specifics>
## Specific Ideas

- The 12 new entries split across 4 plans (D-06..D-09) reduces single-plan blast radius if one entry's package can't be verified — that plan reverts cleanly without invalidating the other 3 plans' work.
- For `unofficial: true` entries (notebooklm, telegram), the catalog flag is what Phase 34 reads to render the yellow `!` glyph + confirm prompt. Phase 33 only sets the flag.
- AWS shared-CLI dedup is a Phase 34 TUI concern (TUI-02 status detect re-runs `command -v aws` once per session and shares the result). Phase 33's job is just to emit the same `cli` block in both INT-04 and INT-05; downstream code dedupes.
- The validator schema enforces the canonical 10-list of categories. Any typo in a `category` field will fail validation immediately — this is the strongest guardrail against drift.
- Existing entries gaining CLI blocks (firecrawl, playwright, sentry) must NOT break the v4.6 `test-mcp-selector.sh` PASS=21 baseline. That test reads the catalog via `mcp_catalog_load` and exercises only the MCP wizard — it ignores `cli` blocks. Should be safe but verify after each mutation.
- Plan 33-04 runs LAST because the entry count check (= 19) is meaningful only after all additions and the deletion are applied.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scoping
- `.planning/PROJECT.md` § Current Milestone v4.9 — full scope, key context, AWS scope-cap rationale, unofficial badge semantics.
- `.planning/REQUIREMENTS.md` — INT-01..12, DROP-01, EXIST-01 with verbatim spec text per entry.
- `.planning/ROADMAP.md` Phase 33 — success criteria.
- `.planning/STATE.md` § Plan Count Estimate (Phase 33 = 4 plans).

### Phase 32 outputs (Phase 33 builds on these)
- `scripts/lib/integrations-catalog.json` — current state (9 existing entries wrapped in `components.mcp`, all carry stub categories from Phase 32 Plan 32-01).
- `scripts/validate-integrations-catalog.py` — validator (Phase 32 Plan 32-01 output). Phase 33 must keep this passing after every mutation.
- `scripts/lib/cli-installer.sh` — CLI installer library (Phase 32 Plan 32-02 output). Phase 33 doesn't call it directly (data-only phase) but produces the catalog data that Phase 34 will feed to it.
- `.planning/phases/32-foundation-schema-migration-cli-installer-library/32-01-SUMMARY.md` — schema details + 9-entry baseline category assignments.
- `.planning/phases/32-foundation-schema-migration-cli-installer-library/32-02-SUMMARY.md` — CLI installer API surface + seam env vars (TK_CLI_UNAME, TK_CLI_BREW_BIN).
- `.planning/phases/32-foundation-schema-migration-cli-installer-library/32-03-SUMMARY.md` — hermetic test patterns (model for Phase 33 if any new tests needed; Phase 33 should stay test-passive).

### MCP package verification surfaces
- npm registry: `https://www.npmjs.com/package/<name>` — verify package exists + recent maintenance.
- AWS Labs MCP repo: `https://github.com/awslabs/mcp` — canonical AWS MCP package list.
- Cloudflare MCP repo: `https://github.com/cloudflare/mcp-server-cloudflare` — canonical Cloudflare MCP packages.
- Slack: official MCP page (deprecated `@modelcontextprotocol/server-slack` is the precedent — find current).

### Project conventions
- `CLAUDE.md` — markdown lint, conventional commits, never push to main.
- `Makefile` — `validate-catalog` target (Phase 32 Plan 32-01 output) + existing `check` chain.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`scripts/validate-integrations-catalog.py`** — already validates `category` enum, required fields, unofficial bool. Use it as the per-plan green gate.
- **`scripts/lib/integrations-catalog.json`** — already has 9 entries in v2 schema. Phase 33 mutates this JSON in place. Use `python -c "import json; ..."` for atomic JSON edits OR direct text edits if the structure stays simple (preferred — git diffs read better).
- **`scripts/tests/test-mcp-selector.sh`** — 21-assertion baseline. Phase 33 must keep it green after every plan.

### Established Patterns
- All existing entries follow the same key order: `display_name`, `category`, `components`, `(optional) unofficial`, `(optional) description` if at top level. New entries match.
- `install_args[]` first element duplicates the entry name (pattern from current 9 entries).
- Description is short (<80 chars), terse, factual. No marketing.

### Integration Points
- After each plan, the validator reads the file from `scripts/lib/integrations-catalog.json` (default path).
- Phase 34 TUI grouping reads `category` field and groups visually.
- Phase 34 unofficial-confirm reads `unofficial` field.
- Phase 35 docs (DOCS-01) generates a 19-entry table from this catalog (probably via a small `gen-integrations-table.py` script — but that's Phase 35's concern).

</code_context>

<deferred>
## Deferred Ideas

- **Per-entry README links** in the JSON (`docs_url`) — could enable Phase 35 DOCS-01 to generate richer tables. Not required for v4.9; revisit if friction emerges in docs generation.
- **MCP package version pinning** in `install_args` (e.g., `@supabase/mcp-server@1.2.3` instead of letting `npx -y` pull latest) — KISS deferred per CLI-FUT-02; revisit on real drift incidents.
- **Per-entry "minimum permissions" hint** for OAuth/token entries — useful for security-conscious users but adds catalog complexity. Future phase.
- **Custom Telegram MCP fork pinned by SHA** — REQUIREMENTS.md INT-12 mentions "pinned by SHA" but `npx -y` doesn't support SHA pinning natively. Defer SHA pinning until a workable mechanism exists; for v4.9 use the most-credible community npm package and document its risks in the entry's `description`.
- **Atlassian Server (self-hosted Jira) variant** — Phase 33 only ships Cloud variant (INT-09). Server is a future entry if demand surfaces.
- **Discord MCP** — INT-FUT-03 in REQUIREMENTS.md.
- **Mailgun MCP** — INT-FUT-01.
- **Cursor `.cursorrules` / Aider `CONVENTIONS.md` bridges** — BRIDGE-FUT-03/04 from v4.8 carry-over.

</deferred>

---

*Phase: 33-catalog-population-11-new-entries-drop-recategorize*
*Context gathered: 2026-05-02*
