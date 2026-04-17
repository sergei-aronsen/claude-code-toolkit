# Codebase Concerns

**Analysis Date:** 2026-04-17

## Tech Debt

**Untracked work blocking merge / leaking into commits:**

- Issue: `git status` shows two untracked paths sitting alongside production files. They have no entry in `.gitignore` and no obvious owner.
- Files:
  - `.claude/` (entire directory: `activity.log`, `audit.log`, `scratchpad/`, `settings.local.json`)
  - `templates/base/skills/debugging/SKILL.md`
- Impact:
  - `.claude/activity.log` and `.claude/audit.log` together exceed ~50KB of free-form local Claude session telemetry; if accidentally `git add .`-ed they leak personal usage data and bloat history.
  - `.claude/settings.local.json` allowlists hundreds of literal Bash commands captured during sessions (e.g., `Bash(echo '{"tool_name":"Bash"...`) — these are user-machine-specific and would corrupt other contributors' setups if committed.
  - `templates/base/skills/debugging/SKILL.md` exists ONLY in the `base` template. Every other framework template (`laravel/`, `nextjs/`, `nodejs/`, `python/`, `go/`, `rails/`) is missing a `skills/debugging/` directory. Yet `manifest.json:59` lists `skills/debugging/SKILL.md` as a shipped skill and both `scripts/init-claude.sh:153` and `scripts/update-claude.sh:130` try to copy `templates/$FRAMEWORK/skills/debugging/SKILL.md` for non-base frameworks — that copy will silently 404 on first install/update for 6 of 7 frameworks.
- Fix approach:
  - Add `.claude/` to root `.gitignore` (only `.gitignore` already excludes `*.log`, but not the directory).
  - Either commit `templates/base/skills/debugging/SKILL.md` and propagate to all 7 templates, OR remove the manifest entry and stop referencing it from the install scripts.

---

**Manifest vs. install-script drift for `commands/design.md`:**

- Issue: The `/design` command was added in commits `e941120` and `1419e13` (per recent git log) and is correctly listed in `manifest.json:30` and `scripts/init-claude.sh:167`. It is **missing** from the per-command download loop in `scripts/update-claude.sh:147`.
- Files:
  - `manifest.json:30` — declares `commands/design.md`
  - `scripts/init-claude.sh:167` — fresh installs get it
  - `scripts/update-claude.sh:147` — existing users running `/update-toolkit` will NOT receive `design.md`
  - `commands/design.md` — actual file present
- Impact: Existing users who run the smart updater never receive `/design`, leading to silent feature drift between fresh and updated installs. Documented in `CLAUDE.md` references and README claims, but undeliverable via `update-claude.sh`.
- Fix approach: Add `design.md` to the long `for file in ...` list in `scripts/update-claude.sh:147`. Better fix: drive both scripts from `manifest.json` (jq parse) instead of hand-maintained lists.

---

**Manifest vs. CHANGELOG drift:**

- Issue: `manifest.json:2` claims `"version": "3.0.0"` dated `2026-02-16`, and `CHANGELOG.md:10` matches. But several material changes have shipped since 3.0.0 with no `[Unreleased]` entries:
  - `commands/design.md` (recent commits `e941120`, `1419e13`)
  - "facts-only research" and "plan compliance checks" mentioned in commit `1419e13`
  - Curl/process-substitution install fixes (`22508f7`, `c0a8a60`, `65422f0`)
  - Counts in `README.md:20` say "30 slash commands" and "29 guides"; CHANGELOG `[3.0.0]` still says "26 → 29 slash commands"; `init-local.sh:126,277` and `docs/howto/en.md:102` say "30 slash commands"; `docs/features.md:352` says "29 guides" but ls of `components/` returns 30 (`components/README.md` is one of them but is part of the directory).
- Files:
  - `manifest.json:2-3`
  - `CHANGELOG.md:8-10` (empty `[Unreleased]` block)
  - `README.md:20`
  - `docs/howto/en.md:102`
  - `docs/features.md:352`
  - `scripts/init-local.sh:126,277`
- Impact: The `update-claude.sh` script writes `.toolkit-version` based on `manifest.json:2`. Users on 3.0.0 will see "already at 3.0.0" and skip upgrade even though they are missing changes. The 3-place advertised counts (commands / guides / audits) drift independently of each other.
- Fix approach: Bump manifest, fill the `[Unreleased]` section, and centralize the count strings (or compute them at build-time). Add a `make validate` rule that asserts `count(commands/*.md) == count(manifest.json.files.commands)` and that README counts match directory listings.

---

**`init-local.sh` carries a hand-rolled VERSION constant that is independent of `manifest.json`:**

- Issue: `scripts/init-local.sh:11` declares `VERSION="2.0.0"`. The toolkit itself is at 3.0.0 in `manifest.json:2`. `init-local.sh --version` reports the wrong number.
- Files: `scripts/init-local.sh:11`, `scripts/init-local.sh:38`
- Impact: Misleads developers verifying which version of the local installer they have; reinforces the multi-source-of-truth problem above.
- Fix approach: Read version from `../manifest.json` at runtime, or remove the constant.

---

**Possible component overlap (not deduplicated):**

- Issue: Multiple components describe overlapping workflows; consumers may load redundant context.
  - `components/structured-workflow.md` (3-phase RIPER-5) vs. `components/plan-mode-instructions.md` vs. `components/spec-driven-development.md` — all describe "plan-before-code" loops with subtle differences.
  - `components/git-worktrees-guide.md` (referenced from base template) vs. `commands/worktree.md` — content covers the same actions (create/list/remove/cleanup).
  - `components/playwright-self-testing.md` and `components/playwright-stability-guide.md` — two Playwright docs whose titles imply overlap.
  - `templates/base/skills/ai-models/SKILL.md` and `templates/base/skills/llm-patterns/SKILL.md` — both directories present, both single-file SKILLs in the AI domain.
- Files: see `/Users/sergeiarutiunian/Projects/claude-code-toolkit/components/` directory (30 files).
- Impact: When `/gsd-plan-phase` or other consumers load "all relevant components" they may pull duplicate guidance, costing context and inviting contradictions.
- Fix approach: Audit the 30 components, mark canonical vs. cross-reference, and add a `components/README.md` index that explicitly states the relationship between overlapping pairs.

---

**Deprecated MCP memory references still shipped:**

- Issue: User-memory and the active component now state that `MCP Memory Bank` and `Knowledge Graph` are deprecated (`components/memory-persistence.md:7,17`). However, the deprecation guidance is still distributed inside several user-facing files:
  - `components/mcp-servers-guide.md:278,288,295` — section explaining how to remove `memory-bank` MCP server.
  - All 7 `templates/*/rules/README.md` reference the migration text.
  - `CHANGELOG.md` versions `2.1.0`/`2.2.0`/`2.3.0` advertise the now-deprecated servers as features without a deprecation notice attached.
- Files: `components/mcp-servers-guide.md`, `components/memory-persistence.md`, `templates/*/rules/README.md`, `CHANGELOG.md:241-265`
- Impact: New users reading the changelog top-down may install deprecated MCP servers; existing users following old release notes follow stale advice.
- Fix approach: Add an explicit `> **Deprecated as of <version>**` callout to the relevant CHANGELOG entries and to `components/mcp-servers-guide.md` "Memory Bank" / "Knowledge Graph" subsections. Cross-link to `components/memory-persistence.md`.

---

## Known Bugs

**`update-claude.sh` smart-merge truncates user sections via `head -n -1`:**

- Symptoms: When a user has customized `## 🎯 Project Overview`, `## 📁 Project Structure`, etc., the merge logic strips the LAST line of each captured section.
- Files: `scripts/update-claude.sh:186-195`
- Trigger: Run `/update-toolkit` after editing `.claude/CLAUDE.md`.
- Workaround: Restore from the auto-backup at `.claude-backup-YYYYMMDD-HHMMSS/`.
- Detail: The pattern `sed -n '/^## H/,/^## /p' "$CLAUDE_MD" | head -n -1` uses GNU `head -n -1`. On macOS BSD `head` (default in `init-claude.sh` target environment), `-n -1` is unsupported and the command fails silently (capture is empty). The `HAS_USER_CONTENT=false` branch then overwrites user customizations with the fresh template — silent data loss on macOS.

---

**`update-claude.sh` lists 29 commands but manifest has 30:**

- Symptoms: After running `/update-toolkit`, `commands/design.md` is missing.
- Files: `scripts/update-claude.sh:147` (29-element loop), `manifest.json:22-53` (30 commands).
- Trigger: Any incremental upgrade.
- Workaround: Re-run `init-claude.sh` instead of the smart updater, or manually `curl` the missing file.

---

## Security Considerations

**`curl … | bash` install pattern across all entry-point docs:**

- Risk: The README and every install command instructs users to pipe a remote shell script directly into `bash <(curl -sSL …)`. Standard supply-chain risk: a compromise of the `main` branch immediately becomes RCE on every new install.
- Files:
  - `README.md:33,54,69` — Security Pack, statusline, and project init
  - `scripts/init-claude.sh:384,392,410,416,425,436,479,504` — references re-emitted in user output
  - `scripts/setup-security.sh`, `scripts/setup-council.sh`, `scripts/install-statusline.sh`, `scripts/update-claude.sh`, `scripts/verify-install.sh` — all promote the same pattern
- Current mitigation: `set -euo pipefail` is set in every script (`init-claude.sh:8`, `setup-security.sh:9`, `setup-council.sh:9`, `install-statusline.sh:6`, `update-claude.sh:6`, `verify-install.sh:10`); URLs use HTTPS to `raw.githubusercontent.com`.
- Recommendations:
  - Provide a pinned-tag alternative in the README (e.g., `…/v3.0.0/scripts/init-claude.sh`), document SHA verification, and offer a "download then inspect then run" path.
  - Optionally publish a `.sha256` next to each script and have the README show how to verify.
  - Long-term: ship as an installable package (`npm`, `brew tap`) so users get signed/published artifacts.

---

**API keys written into `~/.claude/council/config.json` from interactive prompts:**

- Risk: `scripts/init-claude.sh:479,504` and `scripts/setup-council.sh:103,134` use `read -r -p` (no `-s`) to capture Gemini/OpenAI API keys, so the keys echo to the terminal and end up in shell history if the user accidentally pre-fills them. Keys then get written to `~/.claude/council/config.json` via heredoc that interpolates `$gemini_key` / `$openai_key` directly.
- Files:
  - `scripts/init-claude.sh:479` (Gemini), `scripts/init-claude.sh:504` (OpenAI), `scripts/init-claude.sh:513-525` (heredoc write)
  - `scripts/setup-council.sh:103,134` (read), `scripts/setup-council.sh:178-190` (write)
- Current mitigation: After write the file is `chmod 600` (`scripts/init-claude.sh:526`, `scripts/setup-council.sh:191`). Env-var path (`OPENAI_API_KEY`, `GEMINI_API_KEY`) is preferred when present.
- Recommendations:
  - Use `read -rs -p` for key entry (no echo).
  - Quote/escape the value before substituting into the JSON heredoc (special characters like `"` or `\` will currently corrupt the file or break out of the JSON string).
  - Recommend secret managers (1Password CLI, `pass`, OS keychain) over plaintext config in the README.

---

**Combined PreToolUse hook is materialized via heredoc-to-disk and chmod-ed on the user's machine:**

- Risk: `scripts/setup-security.sh:146-186` writes `~/.claude/hooks/pre-bash.sh` from an in-script heredoc and `chmod +x`-es it. Any tampering with the heredoc (e.g., a malicious PR to `setup-security.sh`) becomes a persistent shell script executed before every `Bash` tool call by Claude Code.
- Files: `scripts/setup-security.sh:146-189`
- Current mitigation: The heredoc is short and reviewable; the script is fetched over HTTPS; `set -euo pipefail` aborts on errors.
- Recommendations: Same as the "curl | bash" risk — pin a tag or ship a checksum so users can verify the bytes before they land in `~/.claude/hooks/`.

---

**Inline Python heredocs in `setup-security.sh` mutate `~/.claude/settings.json`:**

- Risk: `scripts/setup-security.sh:202-237,310-333,346-364` open the user's `settings.json`, parse it, and rewrite it. The script does not back up `settings.json` before mutating it (compare with `install-statusline.sh:104` which does create `${SETTINGS_FILE}.bak`). A malformed `settings.json` (e.g., trailing comments, JSON5 syntax) will throw inside `json.load`, the `python3 - << PYEOF` block exits non-zero, and the visible message is just `✗ Failed to configure — add manually` — the user has no automatic recovery path.
- Files: `scripts/setup-security.sh:202-237`
- Current mitigation: Hook-already-configured paths short-circuit the rewrite.
- Recommendations: Always copy `settings.json` to `settings.json.bak.<timestamp>` before any mutation, mirroring `install-statusline.sh:104`.

---

**`setup-council.sh` calls `sudo apt-get` non-interactively to install `tree`:**

- Risk: `scripts/setup-council.sh:66` runs `sudo apt-get update -qq && sudo apt-get install -y -qq tree 2>/dev/null`. If the user has passwordless sudo it installs without confirmation; if not, the prompt is hidden by `2>/dev/null` and the user only sees a generic failure. Either way, an install script silently elevates privileges.
- Files: `scripts/setup-council.sh:60-72`
- Current mitigation: The block is gated on `command -v tree` failing first; failure is non-fatal.
- Recommendations: Remove `sudo`, or print the exact `sudo apt-get install …` command and ask the user to run it. Never `2>/dev/null` a sudo invocation.

---

## Performance Bottlenecks

**`update-claude.sh` performs ~60+ sequential `curl` round-trips per upgrade:**

- Problem: For each agent (4), prompt (7), skill (10), command (29) the script fires a separate `curl -sSL` call. On a slow link this can take minutes; on a flaky link any single 404 silently leaves a stale local file.
- Files: `scripts/update-claude.sh:99-153`
- Cause: One-file-per-curl pattern; no batching, no `git clone --depth 1`, no tarball.
- Improvement path: `curl -L https://github.com/.../archive/refs/heads/main.tar.gz | tar -xz` and copy from the extracted tree. Same applies to `init-claude.sh` (~55 files).

---

## Fragile Areas

**Template install workflow is hand-mirrored in three places that disagree:**

- Files:
  - `manifest.json:6-71` — declarative list (treat as source of truth)
  - `scripts/init-claude.sh:128-240` — imperative list with `:dest` mapping
  - `scripts/update-claude.sh:99-153` — a third imperative list
  - `scripts/init-local.sh:147-196` — a fourth list (uses `cp` instead of `curl`)
- Why fragile: Adding a new command/skill/agent requires updating four files perfectly. The recent `commands/design.md` addition demonstrates the failure mode (manifest+init updated, update-claude not updated).
- Safe modification: Always grep for the file basename across `scripts/` and `manifest.json` before adding a command. Prefer driving the install loops from `jq -r '.files.commands[]' manifest.json`.
- Test coverage: There is no test that asserts the four lists agree. `make validate` does not currently catch this.

---

**Cross-template skill divergence:**

- Files: `templates/*/skills/`
  - `templates/base/skills/` — 11 entries (10 dirs + `skill-rules.json`).
  - `templates/nextjs/skills/` and `templates/nodejs/skills/` — 13 entries (add `nextjs`/`nodejs` + `shadcn`).
  - `templates/laravel/skills/` — 12 entries (adds `laravel`, no `debugging`).
  - `templates/go/skills/`, `templates/python/skills/`, `templates/rails/skills/` — 12 entries each (add framework dir, no `debugging`, no `shadcn`).
- Why fragile: The `debugging` skill exists in `base` only (and is currently uncommitted); `shadcn` exists only in `nextjs` + `nodejs`; framework "expert" skills exist only in their own template. Init/update scripts assume "skill in base also exists in framework" and silently fall back when it doesn't.
- Safe modification: When adding a skill, add it to all 7 templates or document the intentional gap in `manifest.json`.
- Test coverage: `make validate` does not enumerate skill folders per template.

---

**`update-claude.sh` smart-merge depends on exact section header strings with emojis:**

- Files: `scripts/update-claude.sh:186-195,222-228`
- Why fragile: User customization detection looks for literal `^## 🎯 Project Overview`, `^## 📁 Project Structure`, etc. If the upstream template ever renames a section or removes an emoji (which the templates have done historically — see CHANGELOG `[2.6.0]` "reduced by 10-20%"), every existing user's customizations are silently overwritten with template defaults.
- Safe modification: Rename templates with care; keep the section anchor stable. Better: use HTML comment anchors (`<!-- USER:project-overview -->`) for diff-resistant merging.
- Test coverage: None.

---

**Version-string drift between `manifest.json`, `CHANGELOG.md`, and `init-local.sh`:**

- Files: `manifest.json:2`, `CHANGELOG.md:10`, `scripts/init-local.sh:11`
- Why fragile: Three independent sources of "what version are we on?" mean any release inevitably leaves at least one stale.
- Safe modification: Adopt a `VERSION` file at the repo root and have all three sources read from it.

---

## Scaling Limits

**Init/update over HTTP per file does not scale to more skills/commands:**

- Current capacity: 30 commands + 10 skills + 7 prompts + 4 agents = ~50 files per install. ~10s on a fast link, much more on flaky networks.
- Limit: Add another 30 commands and the install becomes user-hostile.
- Scaling path: Switch to tarball download (single round-trip), as noted under Performance Bottlenecks.

---

## Dependencies at Risk

**`@google/gemini-cli` and `cc-safety-net` are referenced as install-time deps but versions are not pinned:**

- Risk: `scripts/init-claude.sh:488` recommends `npm install -g @google/gemini-cli`; `scripts/setup-security.sh:123` runs `npm install -g cc-safety-net` with no version constraint. A breaking change in either becomes a Day-1 install failure for new users.
- Impact: Hooks may misbehave; council may stop working after a global npm update.
- Migration plan: Pin to known-good versions (`cc-safety-net@^X.Y`) and bump deliberately as part of toolkit releases. Document tested versions in `manifest.json` under a new `dependencies` key.

---

**Hardcoded model names will go stale:**

- Risk: `scripts/init-claude.sh:447,451`, `scripts/setup-council.sh:183,187`, `scripts/council/brain.py:29` ship literal model IDs `gemini-3-pro-preview` and `gpt-5.2`. These are previewed/numbered models that providers regularly rename or sunset.
- Impact: Brand-new installs fail immediately when the IDs are retired.
- Migration plan: Make the IDs configurable from the toolkit-level `manifest.json` so a single PR updates them everywhere; or use a model-resolver that asks the provider for the latest stable preview ID.

---

## Missing Critical Features

**No automated check for manifest/script/CHANGELOG consistency:**

- Problem: The drifts documented above are all detectable mechanically (compare `manifest.json` against `ls commands/`, `scripts/*.sh`, `CHANGELOG.md`).
- Blocks: Reliable releases. CI cannot tell the maintainer "you forgot to update update-claude.sh again."
- Suggested fix: Add a `make validate-consistency` target that diffs the four sources of truth and fails on mismatch.

---

**No backup of `~/.claude/settings.json` in `setup-security.sh`:**

- Problem: The script mutates the file without a timestamped copy.
- Blocks: Recovery from a corrupted settings file or a botched merge.
- Suggested fix: Always `cp settings.json settings.json.bak.<ts>` before write (already done in `install-statusline.sh:104`, just port the pattern).

---

## Test Coverage Gaps

**Shell scripts have no automated test, only `shellcheck`:**

- What's not tested: The smart-merge logic in `scripts/update-claude.sh:179-266`, the JSON mutation in `scripts/setup-security.sh:202-237,310-333`, the heredoc-driven `pre-bash.sh` writer in `scripts/setup-security.sh:146-186`, and the interactive `read -r -p` paths.
- Files: all of `scripts/*.sh`.
- Risk: Silent data loss (smart-merge), silent corruption (settings.json mutation), or silent install failure (interactive paths in non-interactive shells like `curl … | bash`). The latter is partially mitigated by `< /dev/tty` guards in `init-claude.sh:84,430,468,479,504`, but `setup-council.sh:93,103,134` does not have those guards — running it via `curl … | bash` will fail because stdin is the curl pipe.
- Priority: High for `update-claude.sh` (potential customization loss), Medium for `setup-security.sh` (recoverable via OS-level config restore), Medium for `setup-council.sh` (interactive-only failure mode).

---

**No coverage for "manifest is the source of truth" invariants:**

- What's not tested: That every file in `manifest.json` exists on disk; that every file under `commands/`, `templates/base/skills/`, `templates/base/prompts/`, `templates/base/agents/` is referenced by `manifest.json`; that `init-claude.sh`, `update-claude.sh`, `init-local.sh` cover the same set as the manifest.
- Files: `Makefile`, `.github/workflows/quality.yml`.
- Risk: Drift like the `commands/design.md` case slips through to users.
- Priority: High — would prevent a recurring class of bugs.

---

*Concerns audit: 2026-04-17*
