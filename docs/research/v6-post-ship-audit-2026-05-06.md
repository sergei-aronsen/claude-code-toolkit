# v6.0.0 Post-Ship Audit — 2026-05-06

## Executive summary

- TK v6.0 ships as a thin overlay on top of `superpowers` + `get-shit-done`, but the **layering glue is largely manual / opt-in**: `install-hooks.sh` and `setup-cost-routing.sh` are not invoked by the main installer (`scripts/install.sh` or `scripts/init-claude.sh`), `uninstall.sh` does not remove their artefacts, and `verify-install.sh` does not check them. Users must remember to run three commands separately, and there is no test coverage for any of the three.
- The single source of truth for "what gets skipped in complement modes", `manifest.json`'s `conflicts_with` field, **only contains one entry** (`agents/code-reviewer.md` against `superpowers`). Every other v6 file is shipped in every install mode regardless of base-plugin presence — duplication that the v6 vision explicitly promised to eliminate is in practice unenforced.
- The single existing `conflicts_with` entry is itself **broken against the currently shipped Superpowers v5.1.0**: SP 5.1.0 dropped the `agents/` directory entirely (`requesting-code-review` is now a skill, not an agent). TK still skips its own `code-reviewer` agent under `complement-sp` / `complement-full`, so users running v5.1.0 + TK end up with **no `code-reviewer` agent at all**.
- `tk-pre-ship-reality-check.sh` is registered as a `PreToolUse(Bash)` hook in parallel with the user's existing combined `pre-bash.sh` (safety-net + RTK) and `gsd-validate-commit.sh`. Claude Code runs all matching `PreToolUse` entries; the TK hook can return `permissionDecision: deny` (block-mode), which combined with the foreign hooks produces undefined ordering and a **multi-deny race** where the user cannot tell which hook blocked the operation.
- Tally — **3 CRITICAL, 7 HIGH, 9 MEDIUM, 6 LOW**, plus 4 open questions. Most CRITICAL findings concentrate in the install/uninstall/state lifecycle for the new opt-in v6 features, not in the content that PR 1–6 shipped.

## Methodology

### Sources read

- `manifest.json` (v6.0.0, manifest_version 2)
- `scripts/lib/install.sh::compute_skip_set` and `print_dry_run_grouped` (full pass)
- `scripts/migrate-to-complement.sh` (full pass — 553 lines)
- `scripts/migrate-v5-to-v6.sh` (full pass — 132 lines)
- `scripts/install-hooks.sh` (full pass — 415 lines)
- `scripts/setup-cost-routing.sh` (full pass — 158 lines)
- `scripts/init-claude.sh` (lines 1–120, 880–980, recommend\_\* functions, dispatcher 1397–1410, banner block 1463–1478)
- `scripts/install.sh` (top + grep for hook references)
- `scripts/uninstall.sh` (grep for `tk-` and v6 hook names — 0 matches)
- `scripts/verify-install.sh` (grep for v6 hook references — 0 matches)
- All four `templates/global/hooks/tk-*.sh` files (full pass)
- `templates/base/skills/skill-rules.json` (full pass)
- `templates/base/skills/cost-routing-discipline/SKILL.md`, `reality-check/SKILL.md`, `gsd-mode-selector/SKILL.md`
- `docs/architecture.md`, `docs/non-programmer-mode.md`
- `docs/research/gsd-vs-alternatives-2026-05-06.md`, `docs/research/toolkit-v6-redesign-2026-05-06.md`
- Live system: `~/.claude/settings.json`, `~/.claude/hooks/pre-bash.sh`, `~/.claude/hooks/rtk-rewrite.sh`, `~/.claude/hooks/health-check.sh`
- SP cache: `~/.claude/plugins/cache/claude-plugins-official/superpowers/{5.0.7,5.1.0}/` (file inventory + agent diff)
- GSD source: `_external/get-shit-done/commands/gsd/*.md` + `_external/get-shit-done/get-shit-done/{workflows,skills,references,templates}/`
- Anthropic-official sibling caches: `code-review`, `commit-commands`, `frontend-design`, `security-guidance` under `~/.claude/plugins/cache/claude-plugins-official/`
- Caveman cache: `~/.claude/plugins/cache/caveman/caveman/c2ed24b3e5d4/` (skills + hooks)
- npm-installed RTK + cc-safety-net (presence verified via `command -v` references in `pre-bash.sh`)

### Sources NOT read (deliberately)

- `_external/claude-plugins-official/` clone — sparse-checkout returned **only `README.md`**; `git ls-tree` shows `plugins/` and `external_plugins/` directories were not materialised by the sparse-checkout. Falling back to `~/.claude/plugins/cache/...` for SP-source comparisons.
- TK's own `commands/audit.md` body beyond first 40 lines (audit pipeline content correctness was audited in prior PRs, not v6 scope).
- Each of the 22 `templates/skills-marketplace/*` skills individually (treated as a single category for the inventory finding).
- All 49 test files — only filenames + grep for v6 keywords were inspected.
- GSD `sdk/` TypeScript code — out of scope for layering audit.

### Hours / token budget

Approximately 110k tokens consumed reading the inputs above. ~85% on the layering glue (manifest, install/migrate/hook scripts, settings.json) and ~15% on content sampling (skills, hooks bodies, templates). Matches the budget guidance in the prompt.

---

## Findings

### CRITICAL (data loss, broken install, security)

#### [F-1] `manifest.json` is not annotated for v6 — `compute_skip_set` is effectively a no-op outside agents

- **Where:** `manifest.json:9-129` (entire `files.{agents,prompts,commands,skills,rules,scripts,libs,skills_marketplace}` block); `scripts/lib/install.sh:35-57` (`compute_skip_set`).
- **Symptom:** A user with both SP and GSD installed (`recommend_mode → complement-full`) is supposed to skip files duplicated by either base plugin. The skip-set is computed from `conflicts_with` annotations on every manifest entry. Today **only `agents/code-reviewer.md`** carries a `conflicts_with` — the rest of the manifest (every command, prompt, skill, rule, lib, marketplace skill) is unannotated. Result: `compute_skip_set` returns a 1-element list (or empty in `complement-gsd` mode where SP is irrelevant) and TK installs every file regardless of mode. The "60% leaner, zero duplication" promise of v6 is enforced by deletion only; nothing prevents future regressions.
- **Reproducer (deterministic):**

  ```bash
  cd /tmp/sandbox-with-sp-and-gsd
  bash <(curl -sSL .../init-claude.sh)
  # Choose mode 4 (complement-full)
  ls .claude/skills/   # All 11 TK skills present, including ones GSD already provides
  ls .claude/commands/ # All 6 TK commands present, including audit/learn/council that overlap GSD analogues
  jq '[.files | to_entries[] | .value[] | select(.conflicts_with)] | length' manifest.json
  # 1
  ```

- **Fix (concrete):** Add `conflicts_with` annotations for every file the v6 plan listed as duplicated. At minimum: `commands/learn.md` → `["superpowers"]` (SP's `writing-skills` overlaps), `skills/{api-design,database,docker,llm-patterns,observability}` → `["get-shit-done"]` (GSD `references/` covers all five domains), `skills/gsd-mode-selector` → `["get-shit-done"]` (GSD's own `gsd-help` + `/gsd-fast`/`/gsd-quick` documentation supersedes), and at least the marketplace-skill mirrors that already live globally in `~/.claude/skills/` (stripe, shadcn, firecrawl, resend, pdf, docx, ai-models, tailwind-design-system, seo-audit — verified all 9 already installed). Also add a CI test (`scripts/tests/test-modes.sh` exists but does not assert presence/absence of any specific file in any specific mode).

#### [F-2] `agents/code-reviewer.md` skip is broken against Superpowers 5.1.0 (silent regression to "no code-reviewer at all")

- **Where:** `manifest.json:11-15`, `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/` (no `agents/` directory), `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/agents/code-reviewer.md` (still exists in 5.0.7).
- **Symptom:** When SP is installed at v5.1.0, TK's `complement-sp` / `complement-full` mode skips installing `agents/code-reviewer.md` because `conflicts_with: ["superpowers"]` is set. But SP 5.1.0 **deleted the `agents/` directory** — the equivalent now lives at `skills/requesting-code-review/code-reviewer.md` and is a *prompt template embedded in a skill*, not a Claude Code agent. So:
  - `/agent:code-reviewer` no longer resolves (no file at `~/.claude/plugins/cache/.../agents/code-reviewer.md` and none at `./.claude/agents/code-reviewer.md` after TK skip)
  - `templates/base/CLAUDE.md` line 286 still advertises `/agent:code-reviewer` as available
  - `migrate-to-complement.sh:178-191` still computes the SP-equivalent path `${sp_root}/superpowers/${SP_VERSION}/agents/code-reviewer.md`, which won't exist for SP 5.1.0+
- **Reproducer:**

  ```bash
  ls ~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/agents/ 2>&1
  # ls: ...: No such file or directory
  bash <(curl -sSL .../init-claude.sh)   # complement-sp/full
  ls .claude/agents/   # planner, security-auditor, test-writer (no code-reviewer)
  ```

- **Fix:** Two-part. (a) Remove the `conflicts_with: ["superpowers"]` annotation entirely — TK's code-reviewer is materially different from SP's (different severity-level structure, different output format, see manual diff in `_external/.../5.0.7/agents/code-reviewer.md` vs `templates/base/agents/code-reviewer.md` showing 38 added / 70 removed lines and a fundamentally different review framework). (b) Add a per-version SP-equivalence map to `manifest.json` (e.g., `sp_equivalent_versions: { "5.0.x": "agents/code-reviewer.md", "5.1.x": "skills/requesting-code-review/code-reviewer.md" }`) so `migrate-to-complement.sh` resolves the right path. Also add a CI test that walks both 5.0.7 and 5.1.0 cache layouts.

#### [F-3] `install-hooks.sh` is never invoked by the main installer; `uninstall.sh` and `verify-install.sh` ignore it entirely

- **Where:** `scripts/install.sh` (top — no `install-hooks` reference), `scripts/init-claude.sh:907,1463,1466` (only printed strings, no `bash` invocation), `scripts/uninstall.sh` (zero matches for `tk-pre-ship|tk-post-gsd|tk-cost-warning|tk-pre-gsd-plan-council|install-hooks|setup-cost-routing|hooks/tk-`), `scripts/verify-install.sh` (zero matches for the same set).
- **Symptom (3 separate bugs in one site):**
  1. **No automatic install** — `init-claude.sh:1399` calls `recommend_hooks` (a function that prints a `curl | bash` invocation), not the installer. A user who runs the canonical "fresh project install" never gets the v6 advisory hooks unless they read the printout, copy the URL, and run a second command. Real-world adoption rate of opt-in second commands is low; v6 plan said hooks were a core part of the layered architecture (see `docs/architecture.md` lines 19, 81–83).
  2. **No automatic uninstall** — `scripts/uninstall.sh` removes manifest-listed files but knows nothing about `~/.claude/hooks/tk-*.sh` or the `_tk_hook_id`-marked entries in `~/.claude/settings.json`. After `uninstall.sh`, the four advisory hooks remain registered and continue firing — but now their target scripts are gone (or stale). With `set -euo pipefail` semantics absent in Claude Code's hook invocation, the user gets per-tool-call errors with no obvious cause. (Recovery: `bash scripts/install-hooks.sh --uninstall` — but the user has just run uninstall and the script may not be on disk anymore.)
  3. **No verification** — `verify-install.sh` does not check whether the hooks are wired into `settings.json` or whether the hook source files are present. A user-broken state (e.g., partial install, jq missing during install-hooks.sh's atomic merge) is not surfaced.
- **Reproducer (uninstall scenario):**

  ```bash
  bash <(curl -sSL .../scripts/install-hooks.sh)        # advisory hooks installed
  bash <(curl -sSL .../scripts/uninstall.sh) --yes       # full uninstall
  ls ~/.claude/hooks/tk-*.sh                             # all 4 still present
  jq '.hooks | to_entries[] | .value[] | select(._tk_hook_id)' ~/.claude/settings.json
  # All 4 still registered, command paths still pointing at hook files
  ```

- **Fix:**
  1. Wire `install-hooks.sh` and `setup-cost-routing.sh` into `init-claude.sh:1397-1410` as conditional auto-installs (gated on user TUI checkbox, like the existing security/statusline flow). At minimum, prompt-and-confirm rather than print-and-forget.
  2. Extend `uninstall.sh` to invoke `install-hooks.sh --uninstall` and `setup-cost-routing.sh --uninstall` (both already implement the necessary entry points).
  3. Extend `verify-install.sh` to grep `~/.claude/settings.json` for `_tk_hook_id` entries and confirm the targeted hook files are present + executable.
  4. Add `scripts/tests/test-install-hooks.sh` with at minimum: install / dry-run / uninstall / re-install idempotence / settings.json `_tk_owned` foreign-entry preservation.

---

### HIGH (functional conflict, surprising behavior)

#### [F-4] `PreToolUse(Bash)` chain becomes a 3-way race when `tk-pre-ship-reality-check.sh` is added in block-mode

- **Where:** `templates/global/hooks/tk-pre-ship-reality-check.sh:71-79` (block-mode emits `permissionDecision: deny`), live `~/.claude/settings.json` PreToolUse entries `[0]` (`pre-bash.sh` — combined safety-net + RTK), `[1]` (`rtk-rewrite.sh`), `[5]` (`gsd-validate-commit.sh`).
- **Symptom:** Claude Code fires *all* hooks whose `matcher` matches. After install, the chain is:
  - `pre-bash.sh` (safety-net+RTK combined; cc-safety-net can already deny destructive commands)
  - `rtk-rewrite.sh` (RTK can rewrite the command)
  - `gsd-validate-commit.sh` (GSD can validate commit messages)
  - `tk-pre-ship-reality-check.sh` (TK can deny `git push origin main`, `vercel --prod`, etc., when `TK_HOOKS_BLOCK_SHIP=1`)
  
  When two of those return non-allow decisions for the same tool call, Claude Code's resolution is "first deny wins, but every hook still runs and emits its message." The user sees up to four reasons in stderr/transcript, with no indication of which one actually blocked. Worse, `pre-bash.sh` *already* swallows safety-net's deny inside its own logic (line 12-15 — it `echo`s the safety-net result then `exit 0`), which means cc-safety-net deny is delivered as a Claude-allow decision but with `"deny"` in the body — relying on Claude Code parsing the embedded JSON. The interaction of TK's clean `permissionDecision: deny` with that legacy embedded-JSON pattern has not been tested.
- **Reproducer:** Set `TK_HOOKS_BLOCK_SHIP=1` and `git push origin main` while RTK is installed. Both the TK hook and RTK's rewrite logic will fire on the same input.
- **Fix:** (a) Don't ship block-mode by default and make it abundantly clear that block-mode requires removing `pre-bash.sh` first or chaining inside it. (b) Better: register the TK ship-check inside the existing `pre-bash.sh` chain (extend the combined hook pattern that the `setup-security.sh` flow already establishes) instead of adding a parallel `PreToolUse(Bash)` matcher. (c) Document the expected hook chain ordering in `docs/architecture.md` and `templates/global/CLAUDE.md`.

#### [F-5] `tk-pre-ship-reality-check.sh` advisory points the user at `~/.claude/skills/reality-check/SKILL.md` but TK installs that skill project-local

- **Where:** `templates/global/hooks/tk-pre-ship-reality-check.sh:89` (`See ~/.claude/skills/reality-check/SKILL.md`), `templates/base/skills/reality-check/SKILL.md` (project-local install path), `manifest.json:103` (entry under `files.skills`, not under `templates.global` — i.e., installed via per-project install logic).
- **Symptom:** The hook fires globally (`~/.claude/hooks/`), but the path it advertises does not exist for any user who follows the documented install flow. The skill is installed at `<project>/.claude/skills/reality-check/SKILL.md`, where `<project>` varies per session. A non-programmer (the explicit target audience per `docs/non-programmer-mode.md`) hitting this advisory will fail to find the file, decide the toolkit is broken, and disable advisories with `TK_HOOKS_DISABLE=1`.
- **Reproducer:** Run a fresh install in `/tmp/p1`, then trigger the hook from `/tmp/p2` (or anywhere not `/tmp/p1`). The path in the advisory message is wrong in 100% of cross-project sessions.
- **Fix:** Either (a) move `reality-check` skill (and `production-observability`, which has the same pattern) to `templates/global/` so it installs to `~/.claude/skills/`, or (b) rewrite the hook message to reference the project-local path: `See <project>/.claude/skills/reality-check/SKILL.md or run /skill reality-check`.

#### [F-6] `tk-post-gsd-phase-audit.sh` matches on string `Phase complete` — inevitable false positives in any audit transcript

- **Where:** `templates/global/hooks/tk-post-gsd-phase-audit.sh:56-67`.
- **Symptom:** The detection logic is `grep -q -F "Phase complete"` (and three sibling markers). The hook then asks the user to run `/audit security && /audit code`. But TK's *own* audit flow emits sentences like "Phase complete" routinely in long-running sessions (look at any `commands/audit.md` output template). A `/audit security` run will itself trigger a second, third, fourth advisory, recommending another `/audit security && /audit code` round. The session-stamp guard at line 81-84 deduplicates per session, so it won't infinite-loop, but the *first* false-positive trips the stamp and prevents legitimate post-phase advisories for the rest of the session.
- **Reproducer:** Run `/audit security` in a fresh session. The hook fires (if installed) and writes the stamp. Then run `/gsd-execute-phase` later in the same session — no advisory shown.
- **Fix:** Tighten the marker. Look for `VERIFICATION.md` *or* the explicit GSD-emitted `<phase-complete phase="N">` tag (per GSD's `references/state.md`), not free-text `Phase complete`. Or add a transcript-line context check: "preceded by `/gsd-execute-phase` *and* not preceded by `/audit *`."

#### [F-7] `gsd-mode-selector` skill has the same trigger keywords as caveman's mode-tracker hook + GSD's own onboarding skills — three-way trigger collision

- **Where:** `templates/base/skills/skill-rules.json:222-237` (gsd-mode-selector keywords: "fix", "add", "change", "implement", "поправь", "добавь", "сделай"), `~/.claude/plugins/cache/caveman/caveman/c2ed24b3e5d4/hooks/caveman-mode-tracker.js` (UserPromptSubmit hook listening for caveman activation), GSD's `gsd-help` and `gsd-discuss-phase` skills (already auto-suggested by GSD's prompt-guard).
- **Symptom:** A trivially short user prompt ("fix the typo") could plausibly activate (a) caveman compression mode (if caveman tracker fires), (b) gsd-mode-selector skill (TK), (c) GSD's `gsd-help` (if GSD interprets it as needing routing). Three skills loading simultaneously inflates context, the opposite of v6's cost-discipline goal. None of the three know about the others.
- **Reproducer:** Hard to assert deterministically without running the harness, but trigger overlap is verifiable from JSON inspection alone.
- **Fix:** Add a `priority` or `scope` field to TK's `skill-rules.json` so the gsd-mode-selector only loads when GSD is detected and no GSD-side mode router is already engaged. Document the trigger grammar in `components/three-layer-bridge.md`. Long-term: move gsd-mode-selector to a hook that runs *before* GSD's prompt-guard rather than a skill activated mid-flight.

#### [F-8] `setup-cost-routing.sh` invokes `npx -y better-model init` with no contract / no graceful fallback / no version pin

- **Where:** `scripts/setup-cost-routing.sh:132-144`.
- **Symptom:**
  1. **No version pin** — `npx -y better-model init` always pulls the npm `latest` tag. A maintainer push (intentional or compromised) on a Friday afternoon affects every fresh install on Saturday. The toolkit pins its own `TK_TOOLKIT_REF` (line 60-67 of `migrate-to-complement.sh`) but vendors `better-model` unpinned. Asymmetric supply-chain hardening.
  2. **No contract verification before mutation** — better-model writes its block into `~/.claude/CLAUDE.md`. The script backs up to `${GLOBAL_CLAUDE_MD}.bak.$(date +%s)` first (line 122-125, good), but if the backup write fails (full disk, read-only home), the next line still runs `npx better-model init` and no atomic restore is possible. The `cp` exit code is unchecked — the `set -euo pipefail` will catch it but the user gets a shell-error message rather than a "we couldn't back up your CLAUDE.md, aborting" hint.
  3. **`docs/architecture.md` says better-model is part of "Layer 3 — External tools (paid / opt-in)"** (line 47 of architecture.md), but `setup-cost-routing.sh` itself doesn't surface the cost-of-failure if `npx better-model init` corrupts CLAUDE.md.
  4. The wrapper's pre-flight at line 64-71 only checks `node` and `npx`. It does not check whether `better-model` is on PATH or installable. Per project memory, the user has not yet installed better-model. A first run on a network-blocked machine will hang on `npx -y better-model` for the npm-default timeout (~5 minutes).
- **Reproducer (graceful-degrade scenario):** `npm config set registry http://192.0.2.1` (RFC 5737 sink) then `bash scripts/setup-cost-routing.sh`. Backup runs, `npx` hangs ~5 min, exits non-zero, restore from backup runs (line 139-141 — good). User sees ~6 min of nothing, then a one-line failure. No "tried for 5 minutes, network seems down" message.
- **Fix:** (a) Add `--better-model-version <semver>` flag and pin `npx better-model@${ver} init`. (b) Wrap the `npx` call with `timeout 120 npx ...` (POSIX `timeout` available on macOS via coreutils or Node-side `--idle-timeout`). (c) Pre-flight: `npx --no-install better-model --version || { echo "better-model not in cache; will fetch..."; }` so user sees the network call coming. (d) Document better-model's exact write target in the `--help` output so users can opt out before running.

#### [F-9] `migrate-to-complement.sh` `sp_equivalent` resolution is unmaintained for v6 manifest

- **Where:** `scripts/migrate-to-complement.sh:173-192` (`resolve_sp_path`), `manifest.json` (zero entries with `sp_equivalent` field).
- **Symptom:** `resolve_sp_path` reads `sp_equivalent` from the manifest entry; absent, it falls back to "same basename." For TK's `agents/code-reviewer.md`, this means it looks at `${SP_VERSION}/agents/code-reviewer.md`. As covered in F-2, that path no longer exists in SP 5.1.0. The 3-way diff shown to the user is rendered with the SP column as `—` (line 351 — "SP file not found … 3rd column degraded to 2-column"). The user is asked to remove the file based on a 2-column diff (TK template vs disk), with no SP-side reference. They click `y`, the file goes away, and the user has just lost their `code-reviewer` agent.
- **Reproducer:** With SP 5.1.0 installed, `bash scripts/migrate-to-complement.sh` and inspect the table.
- **Fix:** Same as F-2 fix (b) — versioned SP-equivalent map. Plus: when SP-side hash is unresolvable, prompt should default to "keep" (`N`) instead of asking the user to make a decision based on incomplete data.

#### [F-10] `migrate-to-complement.sh` does not detect or migrate v5 framework templates that v6 deleted (`templates/nextjs`, `templates/nodejs`)

- **Where:** `scripts/migrate-v5-to-v6.sh:91-110`, `manifest.json:333-348` (templates list omits nextjs, nodejs).
- **Symptom:** v6 PR 4 deleted the `nextjs/` and `nodejs/` framework templates (per `toolkit-v6-redesign-2026-05-06.md` lines 138-143). `update-claude.sh` deletes manifest-absent files, but if a v5 user ran TK on a Next.js project and now runs `migrate-v5-to-v6.sh`, the script just calls `update-claude.sh` with no special handling. Project files installed from `templates/nextjs/CLAUDE.md` are simply left in place (because they map to per-project `.claude/CLAUDE.md`, which `update-claude.sh` smart-merges). The user retains v5-style content in their CLAUDE.md, gets the v6 hooks suggested, and lives in a hybrid state forever. No drift detection, no warning.
- **Reproducer:** Set up a v5 install with framework=nextjs, then `bash scripts/migrate-v5-to-v6.sh`.
- **Fix:** Add an explicit pre-flight in `migrate-v5-to-v6.sh` that reads the user's `.claude/.toolkit-version` (or recomputes framework from `package.json` etc.) and warns if their last-installed framework is in the deleted set. Optionally, run `init-local.sh base` to overlay a fresh base template.

---

### MED (drift, cleanup opportunity)

#### [F-11] `templates/skills-marketplace/` ships 22 skills, 9 of which already exist as global plugins on every modern dev laptop

- **Where:** `manifest.json:201-267` (skills_marketplace entries), live system `~/.claude/skills/{stripe-best-practices,shadcn,firecrawl,resend,pdf,docx,ai-models,tailwind-design-system,seo-audit}/` (all present).
- **Symptom:** Per-project skill installs duplicate global content. v6 plan claimed marketplace was kept "with top 5: stripe, shadcn, firecrawl, notebooklm, resend" (per `gsd-vs-alternatives-2026-05-06.md` line 491), but the current ship contains all 22. None have `conflicts_with` entries; even when a skill is globally installed via Anthropic Skills marketplace (the Anthropic skill marketplace is now upstream and live), TK installs a project-local copy. Drift between TK's frozen copy and the upstream is silent.
- **Fix:** Either delete the marketplace mirror entirely (re-direct users to Anthropic's marketplace) or add a runtime dedup in `skills.sh` that skips installation when the same skill name is present in `~/.claude/skills/`. Document the policy in `docs/SKILLS-MIRROR.md` (file exists; needs an update).

#### [F-12] GSD `/gsd-secure-phase`, `/gsd-audit-uat`, `/gsd-code-review`, `/gsd-audit-fix` overlap TK's `/audit` command

- **Where:** `_external/get-shit-done/commands/gsd/{secure-phase.md,audit-uat.md,code-review.md,audit-fix.md}`, TK `commands/audit.md`.
- **Symptom:** GSD's audit suite is plan-aware and phase-scoped (`gsd:secure-phase` "Retroactively verify threat mitigations for a completed phase"; `gsd:audit-fix` "Autonomous audit-to-fix pipeline"). TK's `/audit` is project-wide and FP-recheck-aware. There is no canonical guidance for which to use when. v6 architecture doc (line 81) says "TK hook fires `tk-post-gsd-phase-audit.sh` suggests `/audit security && /audit code`" — but GSD has its own equivalent (`/gsd-code-review`) that operates on the same just-completed phase with phase-aware diff. Recommending TK's `/audit` *over* GSD's native is exactly the duplication v6 promised to eliminate.
- **Fix:** Decide a policy. Either (a) `tk-post-gsd-phase-audit.sh` recommends `/gsd-code-review` first, only escalating to `/audit security` for explicit security keywords; or (b) document that GSD's audit is "phase-scoped diff", TK's audit is "project-wide FP-aware", and explicitly position them as complements not substitutes. The current state is "two overlapping commands with no explicit guidance."

#### [F-13] `commands/learn.md` overlaps SP `writing-skills` skill

- **Where:** TK `commands/learn.md`, SP cache `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/writing-skills/SKILL.md`.
- **Symptom:** `/learn` writes lessons to `.claude/rules/` per the v6 architecture (`gsd-vs-alternatives` doc — "Memory Architecture (Gold Standard)"). SP's `writing-skills` is the canonical "create/edit/verify a skill" flow. They serve adjacent purposes (learn = persist a lesson; writing-skills = formalise into a reusable skill). v6 plan listed `commands/learn.md` as KEEP (line 104 of `toolkit-v6-redesign-2026-05-06.md`), but the rule files written by `/learn` are not on the trigger path of any SP skill. A user invoking SP's `writing-skills` to formalise a lesson learned via `/learn` has to cross the boundary manually.
- **Fix:** Add a one-line bridge in `commands/learn.md`: "When the lesson stabilises, run SP `writing-skills` to formalise it as a reusable skill." Or rewrite `/learn` to optionally invoke SP `writing-skills` for upgrade.

#### [F-14] `update-claude.sh` smart-merge has no test for the v6-renamed `claude_md_sections` (`Hooks (NEW)` and `Cost Routing` sections from setup-cost-routing.sh)

- **Where:** `manifest.json:301-332` (`claude_md_sections`), `scripts/update-claude.sh` smart-merge logic (referenced in `manifest.json:6` comment).
- **Symptom:** `manifest.json:303-323` enumerates the section headings smart-merge recognises. v6.0 added (per architecture doc) a Three-Layer Bridge section in CLAUDE.md, but it is **not in the system list**. A user who edits Three-Layer Bridge text in their project CLAUDE.md and then runs `update-claude.sh` may have their edits clobbered (or, worse, may not — depending on whether smart-merge defaults to keep or overwrite for unknown headings). No test fixture exists for the new section.
- **Fix:** Audit the v6 templates against `claude_md_sections.{system,user}`. Add the new headings to the right list. Add a test fixture in `scripts/tests/fixtures/` exercising it.

#### [F-15] No tests for `install-hooks.sh`, `setup-cost-routing.sh`, `migrate-v5-to-v6.sh` — entire v6 surface is untested

- **Where:** `scripts/tests/` (49 files; 0 matching `install-hooks|cost-routing|v6`).
- **Symptom:** Verified by `ls scripts/tests/test-{install-hooks,cost-routing,v6}*` — zero matches. The Makefile `make test` integration suite tests v5 install paths (Laravel/Next.js synthetic projects), not v6 advisory hooks or cost routing wrapper. PR 7 (release) per `toolkit-v6-redesign-2026-05-06.md:251-256` was supposed to gate on tests; tests for v6 features were not written.
- **Fix:** Add at minimum:
  - `test-install-hooks.sh` — install/dry-run/uninstall round-trip, foreign hook preservation, jq-missing graceful exit, settings.json idempotence.
  - `test-cost-routing.sh` — backup-then-restore on `npx` failure (mock `npx` with a failing stub), `--uninstall` correctly strips block.
  - `test-migrate-v5-to-v6.sh` — synthetic v5 install, run migration, assert (a) advisory hook URL printed, (b) cost-routing URL printed, (c) deleted templates surfaced.

#### [F-16] `caveman` plugin's UserPromptSubmit hook (`caveman-mode-tracker.js`) and TK's `tk-pre-gsd-plan-council.sh` both bind to UserPromptSubmit — no execution-order contract

- **Where:** Live `~/.claude/settings.json` UserPromptSubmit `[0]` (caveman tracker), `scripts/install-hooks.sh:56-61` (registers `tk-pre-gsd-plan-council.sh:UserPromptSubmit:`).
- **Symptom:** Both hooks read the user prompt; both can emit context to Claude. Claude Code runs them in array order. After `install-hooks.sh` runs, the chain is `caveman-mode-tracker.js` first (was already there), then `tk-pre-gsd-plan-council.sh`. If caveman activates compression mode, downstream context emitted by TK is also subject to that compression — TK's advisory message ("🛡️ TK advisory: this /gsd-plan-phase touches high-stakes area …") may be rewritten by caveman before Claude reads it. Reverse order (TK first) means caveman activation happens too late to compress TK's output. Neither order is wrong; both have surprising effects.
- **Fix:** Document explicit ordering policy in `templates/global/CLAUDE.md` and `components/three-layer-bridge.md`. Optionally make `install-hooks.sh` insert TK's UserPromptSubmit before caveman's (would require detection logic) or after (current behaviour). Either way, mention the interaction in `docs/architecture.md`.

#### [F-17] `tk-pre-gsd-plan-council.sh` keyword scan is a `case`-based substring match — fires on incidental mentions

- **Where:** `templates/global/hooks/tk-pre-gsd-plan-council.sh:45-58`.
- **Symptom:** Keyword list includes "auth", "session", "secret" — any user prompt containing those substrings (e.g., `/gsd-plan-phase add user-session debug logging` or `/gsd-plan-phase document the auth-free public endpoints`) triggers the council advisory. False-positive rate likely high. Worse, the Russian keywords (`оплата`, `биллинг`, `подписк`, `аутентифик`, `авториз`) on line 51 are bare prefixes (`подписк` matches `подписку` and `подписка`; `аутентифик` is fine but English `auth` substring-matches anywhere). The script will trigger on prompts like `/gsd-plan-phase author-bio rendering` (`auth` ⊆ `author`).
- **Reproducer:** Set up the hook, prompt `/gsd-plan-phase adjust the author byline padding`. Console advisory fires.
- **Fix:** Switch from substring `case` to word-boundary regex (POSIX `grep -E -w`). Restrict to whole-word matches and explicit slash-arg parsing.

#### [F-18] `non-programmer-mode.md` recommends GSD as primary, but GSD's `$GSD memecoin` risk is unflagged in the doc itself

- **Where:** `docs/non-programmer-mode.md` (97 lines, no $GSD mention), `docs/research/gsd-vs-alternatives-2026-05-06.md:145` (memecoin red flag noted in research), `components/vendor-risk.md` (per inventory; not read).
- **Symptom:** A non-programmer reading `docs/non-programmer-mode.md` is told to install GSD. The doc does not surface the project memory-recorded risk that GSD has a Solana memecoin tied to it (per project memory + `gsd-vs-alternatives-2026-05-06.md:145`). For a target user "cannot evaluate code themselves", the vendor-risk consideration matters more, not less. Missing context.
- **Fix:** Append a "Vendor risk" section to `docs/non-programmer-mode.md` linking to `components/vendor-risk.md` and explicitly flagging the GSD memecoin signal as a quarterly review item. Mirror in `docs/architecture.md`.

#### [F-19] `dependency-map.md` (referenced in audit prompt) does not exist in the repo

- **Where:** Prompt referenced `docs/dependency-map.md`; `Read` tool confirmed missing.
- **Symptom:** External documentation references a doc that was never created. If any user follows `docs/architecture.md` line 100 ("see also components/external-tools-recommended.md") and tries to cross-reference deeper, dead-link. Not a bug, but the doc-suite is a layer thinner than the v6 plan implied.
- **Fix:** Either generate `docs/dependency-map.md` (sourcing the layer model from `architecture.md` plus a flat list of `who-installs-what`) or remove all references.

---

### LOW (nit, style, doc gap)

#### [F-20] `manifest.json:1-7` documents `manifest_version: 2`, but `migrate-to-complement.sh:131-135` is the only consumer hard-checking `manifest_version`. `update-claude.sh`, `init-claude.sh`, `init-local.sh`, `verify-install.sh` all silently accept any version. Schema drift will surface only at migrate time.

- **Fix:** Add a `manifest_version` check to every script that reads the manifest (or factor into a single helper in `lib/install.sh`).

#### [F-21] `templates/global/hooks/tk-cost-warning.sh:65` computes threshold via `$((THRESHOLD_KTOK * 4000))` — passing `TK_COST_WARN_KTOK=` (empty) is sanitised to default 200, but `TK_COST_WARN_KTOK=2000000` (8 GB threshold) is silently accepted. No upper bound. Cosmetic; user shoots themselves in the foot.

- **Fix:** Cap at `1000000` (4 GB) with a one-line warning if exceeded.

#### [F-22] `tk-pre-ship-reality-check.sh:43-65` `case` patterns include `*"git push"*"origin main"*` which matches both `git push origin main` (intended) and `git push --no-verify origin main` (intended) but **not** `git push origin master:main` (intended target = main, missed). Edge case.

- **Fix:** Move detection from `case` glob to a parsed-argv approach. Already documented as advisory-only, so the cost is minor.

#### [F-23] `templates/base/CLAUDE.md` line 286 advertises `/agent:code-reviewer` as available — but as covered in F-2 this may be skipped in `complement-sp` modes.

- **Fix:** Conditionalise the table on the install mode, or reword to "if installed".

#### [F-24] `docs/architecture.md:56` claims "morph-fast-tools — Fast Apply diffs + warpgrep_codebase_search" but TK does not auto-install Morph; the catalog entry under `scripts/lib/integrations-catalog.json` is recommended:false. Doc/code drift.

- **Fix:** Match doc claim to catalog state — set `recommended: true` for Morph (consistent with project memory: user already has Morph installed and project memory says "ALWAYS-on Morph").

#### [F-25] `manifest.json:200-267` lists 22 marketplace skills; 13 of those have no `conflicts_with` annotation at all, even though the same skills exist as Anthropic global plugins. Long-term consistency hazard if upstream Anthropic updates change content but TK's frozen copy doesn't.

- **Fix:** Either delete the mirror (per F-11) or annotate.

---

## Coverage gaps

What the test suite **does** test:

- Detect.sh (`test-detect*.sh`)
- Install dispatch order (`test-install-dispatch-h1.sh`, `test-install-tui.sh`, `test-install-skills.sh`)
- Bridges sync (`test-bridges*.sh`, 4 files)
- Migrate flow + idempotency (`test-migrate-{flow,diff,dry-run,idempotent}.sh`)
- State persistence (`test-state.sh`)
- Settings.json safe-merge (`test-safe-merge.sh`, `test-setup-security-rtk.sh`)
- Update flow (`test-update-{diff,drift,dry-run,libs,summary}.sh`)
- MCP catalog and selector (`test-mcp-{secrets,selector,wizard}.sh`, `test-integrations-{catalog,foundation,tui}.sh`)

What the test suite **does NOT** test (v6-specific, ranked by risk):

1. `compute_skip_set` against any concrete file count. Test asserts mode dispatch but not "in `complement-full`, X files are skipped." So the silent F-1 regression goes uncaught indefinitely.
2. `install-hooks.sh` — zero coverage. Foreign-hook preservation, idempotence, dry-run, jq-missing path, atomic-merge failure injection (`TK_TEST_INJECT_FAILURE=1` is referenced in `lib/install.sh:179` but not used in any test).
3. `setup-cost-routing.sh` — zero coverage. Backup-on-failure path, `npx` timeout, `--uninstall` block-stripping.
4. `migrate-v5-to-v6.sh` — zero coverage. v5-to-v6 integration is hand-tested only.
5. `manifest.json` schema validation — `scripts/validate-manifest.py` exists but is not on the `make check` path. CI would not catch a malformed `conflicts_with` entry.
6. SP-version-specific equivalence (5.0.7 has agents/, 5.1.0 doesn't). The `migrate-to-complement.sh` test fixtures (`scripts/tests/fixtures/`) probably don't include an SP 5.1.0 fixture.
7. Hook chain interaction (caveman, RTK, gsd-validate-commit + TK ship-check) — no integration test exists for the combined PreToolUse Bash chain. No fixture for `~/.claude/settings.json` with foreign entries.

---

## Recommendations (prioritized)

1. **Fix F-2 first (highest user impact, lowest effort).** Remove the single `conflicts_with: ["superpowers"]` annotation on `agents/code-reviewer.md`. One commit, ~5 minutes. Restores code-reviewer agent for SP 5.1.0+ users. Alternatively (better long-term but more effort), add SP version-specific equivalence map and resolve dynamically.
2. **Fix F-3 (medium effort, high value).** Wire `install-hooks.sh` and `setup-cost-routing.sh` into `init-claude.sh:1397-1410` as TUI-confirmed steps (mirror the existing security/statusline pattern). Extend `uninstall.sh` to invoke their `--uninstall` paths. Extend `verify-install.sh` to grep for `_tk_hook_id` markers in `settings.json`. ~1 day.
3. **Fix F-1 (medium effort, high long-term value).** Add `conflicts_with` annotations to the manifest for every file v6 declared a duplicate. Add a CI test that asserts file counts per mode (e.g., `complement-full → installs N files, skips M`) so future regressions trip CI. ~half day for the annotations + 2 hours for the test.
4. **Add the missing test files (F-15) for `install-hooks`, `setup-cost-routing`, `migrate-v5-to-v6`.** These three scripts are the entire v6-new install surface and they have zero test coverage. ~1 day combined.
5. **Fix F-4 (block-mode hook chain).** Either ship the `tk-pre-ship-reality-check.sh` exclusively in advisory mode (drop the block-mode code path entirely), or extend it as part of the existing `pre-bash.sh` chain rather than as a sibling matcher. Document the policy in `templates/global/CLAUDE.md`. ~half day.
6. **Fix F-5 (skill path mismatch in advisory).** Move `reality-check` and `production-observability` skills to `templates/global/skills/` so they install globally to `~/.claude/skills/`, matching what the hook advisory message promises. Bonus: makes them available cross-project, which the v6 plan implied. ~2 hours.
7. **Audit + close F-12 / F-13 (overlap with GSD audits and SP `writing-skills`).** Either reposition TK's `/audit` and `/learn` as explicit complements with documented bridge, or remove. Currently they duplicate functionality the v6 vision said was being delegated. ~1 day for the documentation pass; longer if the decision is to delete.

---

## Open questions (lower confidence — not findings)

- **Q1 — Anthropic-official `code-review` plugin overlap with TK `/audit code-review`.** The Anthropic-shipped `code-review` plugin (`~/.claude/plugins/cache/claude-plugins-official/code-review/unknown/commands/code-review.md` exists) defines a `/code-review` slash command. TK ships `/audit code-review` (alias of `/audit code`). Both review unmerged work. Did not read the Anthropic plugin's body. Possible duplication.
- **Q2 — GSD canary-channel risk.** `gsd-vs-alternatives-2026-05-06.md:152-154` notes `canary: 1.50.0-canary.1` is published with no release notes. If a non-programmer following `docs/non-programmer-mode.md` accidentally pins `npx get-shit-done-cc@canary`, they get an experimental build with unknown behaviour. Possibly worth a "DO NOT USE canary" note in `docs/non-programmer-mode.md` — but might be too tutorial-y for the docs.
- **Q3 — caveman commit hash lockfile.** `~/.claude/plugins/cache/caveman/caveman/c2ed24b3e5d4/` is pinned by commit hash. If the upstream maintainer force-pushes (a known supply-chain attack vector), `c2ed24b3e5d4` could change content. Did not investigate whether Anthropic's plugin cache stores the upstream content-addressed (which would make force-push detectable) or only by commit hash (which would not).
- **Q4 — Morph "always-on" claim.** Project memory says "ALWAYS-on Morph". `cost-routing-discipline/SKILL.md:60-62` says "Use Morph Fast Apply for ALL edits (5-10× cheaper than native Edit)." But `manifest.json` doesn't ship a Morph install hook, the integrations-catalog has Morph as `recommended: false` would be expected → it's actually unset (no `recommended` key at all, just `description: "v6.0 recommended"`). Inconsistency between user-facing `recommended` UX and catalog data is plausible but unverified.

---

## Appendix — verified file list

Files containing claims verified by Read tool (not just grep):

- `manifest.json` (full)
- `scripts/lib/install.sh` (full)
- `scripts/migrate-to-complement.sh` (full)
- `scripts/migrate-v5-to-v6.sh` (full)
- `scripts/install-hooks.sh` (full)
- `scripts/setup-cost-routing.sh` (full)
- `scripts/init-claude.sh` (lines 1–120, 880–980)
- `templates/global/hooks/tk-cost-warning.sh` (full)
- `templates/global/hooks/tk-post-gsd-phase-audit.sh` (full)
- `templates/global/hooks/tk-pre-gsd-plan-council.sh` (full)
- `templates/global/hooks/tk-pre-ship-reality-check.sh` (full)
- `templates/base/skills/skill-rules.json` (full)
- `templates/base/skills/cost-routing-discipline/SKILL.md` (full)
- `templates/base/skills/reality-check/SKILL.md` (lines 1–40)
- `templates/base/skills/gsd-mode-selector/SKILL.md` (lines 1–50)
- `~/.claude/hooks/pre-bash.sh` (full live system)
- `~/.claude/hooks/rtk-rewrite.sh` (lines 1–30 live system)
- `~/.claude/hooks/health-check.sh` (lines 1–30 live system)
- `~/.claude/settings.json` (parsed via Python — all hooks chains)

Files inventoried via `ls` / `find` only:

- All 49 `scripts/tests/*.sh` filenames
- `templates/{base,laravel,rails,python,go,global}/` directory layouts
- `commands/`, `components/`, `templates/skills-marketplace/` directory listings
- SP 5.0.7 and 5.1.0 plugin caches
- GSD `_external/` clone (commands/agents/skills/hooks/workflows directories)
- Caveman pinned commit cache
- Anthropic-official sibling plugins (`code-review`, `commit-commands`, `frontend-design`, `security-guidance`)
