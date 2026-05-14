# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `scripts/lib/skills.sh:is_skill_installed` — `.agents/` fallback path
  corrected from `$HOME/.agents/` to `$HOME/.agents/skills/`. The
  upstream `impeccable` CLI writes per-skill entries under a `skills/`
  subdirectory of `~/.agents/` (alongside `.skill-lock.json`), so the
  old default never matched the real layout. User report 2026-05-14:
  install-time `npx impeccable` bailed `Impeccable skills are already
  installed (found in .agents/)` (CLI saw `~/.agents/skills/i-impeccable/`)
  yet every subsequent install run still offered impeccable as
  uninstalled because the toolkit probe checked the wrong directory.
  Added `S9d` (default-resolution positive) and `S9e` (negative: legacy
  `~/.agents/impeccable/` without `skills/` level must not false-positive)
  regression tests. Hardened test isolation across S2/S3/S4/S5/S6/S7/S8
  by passing `TK_AGENTS_HOME=$SANDBOX/no-agents` so the new default does
  not leak host `~/.agents/skills/` state into hermetic suites.

## [6.25.0] - 2026-05-14

### Fixed — Audit sweep 2026-05-14 (3 HIGH + 6 MEDIUM + 2 LOW)

Three parallel audits ran 2026-05-14 against the post-PR-#126 audit
prompts (FP-control gates + per-audit CATEGORY ENUM overrides). 11
findings closed; 6 LOW deferred to v6.25.1+ backlog.

#### HIGH severity

- `scripts/lib/dispatch.sh` — GSD dispatcher migrated from the dead
  `bash <(curl raw.githubusercontent.com/gsd-build/...)` URL (404
  since GSD's npm migration) to
  `npx --yes get-shit-done-cc@${TK_GSD_NPM_VERSION:-1.41.2}`. Mirrors
  `lib/bootstrap.sh`'s PR #125 fix. Users selecting GSD from the main
  TUI no longer hit silent 404.
- `scripts/lib/mcp.sh:mcp_catalog_load` — collapsed ~301 jq forks (10
  inside-loop × 30 entries + iterator) to 1 jq fork via a single
  RS-joined record. `@tsv` was rejected because Bash `read` collapses
  consecutive tab fields (caused a column shift bug on calendly's
  empty `env_var_keys`). `~8s` saved on macOS cold install.
- `scripts/init-claude.sh` — 10 serial `curl -sSLf` calls for
  prerequisite libraries collapsed into one
  `curl --parallel --parallel-max 10` batch (with version probe +
  serial fallback for curl < 7.66, Ubuntu 18.04 and older). Source
  order preserved exactly. Plus `download_files()` jq-fork explosion
  (4 jq per manifest entry × ~125 entries = ~500 forks) collapsed to
  a single RS-joined record. `~15-18s` saved on cold install.

#### MEDIUM severity

- `scripts/lib/mcp.sh` — user/local scope MCP wizard now uses the
  same `${SLOT}` substitution form as project scope. The `env KEY=plaintext`
  argv wrapper is gone; secrets persist in `~/.claude/mcp-config.env`
  (0600, auto-sourced by `~/.zshrc` + `~/.bashrc` via v6.4.0 shell-rc
  line) and Claude resolves `${KEY}` from its own environment at MCP
  launch. Closes the propagation gap from v6.24.3's Council-API-keys
  fix — same threat surface, same mitigation pattern.
- `scripts/prompt-engineer/optimize_prompt.py` — new `_open_0600()`
  helper (port of `brain.py:191-205`) applied to the timeline log and
  every `output/<ts>/*` user-prompt artifact. Default umask 0022 was
  leaking the bytes at 0644; same-host attackers (other unix user,
  container side-car, dev box guest account) could read them between
  write and explicit delete.
- `scripts/prompt-engineer/optimize_prompt.py` — `threading.Lock` on
  the `TimelineLogger`; every public writer (`step`, `section`, `kv`,
  `block`, `event`, `close`) now wraps multi-line writes atomically.
  `--provider all` fans out 3 worker threads via
  `ThreadPoolExecutor` and previously interleaved block headers with
  body lines between threads. Logs are now deterministic.
- `scripts/council/pack.py` — `output_path.unlink()` after an
  oversize retry-fail. Previously left the oversize first-pass on
  disk; `pack_is_fresh()` only checks mtime so the next Council call
  served the stale oversize cache instead of regenerating.
- REL-03 strict mode — all 9 standalone installers (`init-claude.sh`,
  `install.sh`, `install-statusline.sh`, `migrate-to-complement.sh`,
  `setup-council.sh`, `setup-prompt-engineer.sh`, `setup-security.sh`,
  `uninstall.sh`, `update-claude.sh`) now pin `TK_TOOLKIT_REF`'s
  default to the manifest version. v6.24.5 covered only
  `init-claude.sh`. `scripts/tests/test-toolkit-ref-pinned.sh`
  rewritten as a multi-file walker that fails CI on any drift across
  the 9 installers.

#### LOW severity (inline)

- `scripts/lib/bootstrap.sh:172` — GSD prompt text now reflects the
  actual `npx get-shit-done-cc@<semver>` install path (was: stale
  `curl|bash` + obsolete `TK_GSD_PIN_SHA256` reference from v6.23.x).
- `scripts/lib/skills.sh` + `scripts/install.sh` — tarball fallback's
  extraction tmpdir is now exported as `TK_SKILLS_MIRROR_TMPDIR` and
  registered in a new `CLEANUP_DIRS` array picked up by the
  EXIT-trap (`rm -rf` instead of the old `rm -f` which silently
  failed on directories). Previously leaked 5-15 MB per `curl|bash`
  install until the OS's `$TMPDIR` GC cycle reaped it.

#### New tests

- `scripts/tests/test-mcp-catalog-load.sh` — parallel-array length,
  alphabetical sort, calendly-empty-env-keys regression, ≤2 jq forks.
- `scripts/tests/test-prompt-engineer-perms.sh` — every `output/<ts>/*`
  artifact + the timeline log are 0600.
- `scripts/tests/test-prompt-engineer-thread-safety.sh` — 3-thread
  90-block stress, fails on any interleaved `block()` record.
- `scripts/tests/test-pack-cache-recovery.sh` — retry-fail unlinks
  cache_path; next call regenerates instead of serving stale.
- `scripts/tests/test-bootstrap.sh` — new S7+S8 close the dispatch.sh
  H-1 migration (no legacy URL, `get-shit-done-cc` reference present,
  display string updated).

#### Migration notes

- Users with v6.24.x user-scope MCP entries whose secret was provided
  via the wizard before this release: a one-time
  `claude mcp remove <name>` + re-add through the v6.25.0 wizard
  transitions the entry to the `${SLOT}` substitution form. The
  plaintext stays in `~/.claude/mcp-config.env` (0600) and the
  v6.4.0 shell-rc auto-source line continues to load it.
- Release-PR authors: REL-03 strict requires bumping `manifest.json:.version`,
  ALL 9 `scripts/*.sh:TK_TOOLKIT_REF` defaults, and the CHANGELOG in
  one commit. CI catches drift.

### Added — Prompt Engineer multi-provider support + timeline logging

`scripts/prompt-engineer/optimize_prompt.py` is no longer Codex-only.
A new `--provider {claude,codex,gemini,all,ask}` flag selects which
CLI drives the optimizer; default `ask` shows an interactive menu on
TTY and falls back to `claude` when stdin is not a TTY (CI / pipes).

- `claude` → `claude -p` (stdin) — Claude Code itself as a subprocess
- `codex` → existing `codex exec` path
- `gemini` → `gemini -p ""` (stdin)
- `all` → fan-out to every available provider in parallel via
  `concurrent.futures.ThreadPoolExecutor`, then synthesize a best-of
  final via one extra call. Synthesizer preference: claude > codex >
  gemini. Per-provider artifacts
  (`01-{claude,codex,gemini}.md/.txt/.log`) preserved alongside
  `02-synthesis-prompt.txt` (the deliverable).
- `--multi-pass` (3-stage pipeline) stays single-provider only;
  rejected with `--provider all`.

New `--log` flag writes a single human-readable timeline file at
`logs/prompt-engineer-<timestamp>.log` showing every stage with
timestamps, elapsed time, the rendered system prompt that was sent to
the provider, the raw response, durations, and stage decisions.
`--log-file PATH` and `--log-dir DIR` override the default path.
Audit how an optimization run unfolds without grep-ing the per-stage
raw `codex exec` / `claude -p` logs.

`scripts/setup-prompt-engineer.sh` and the `setup_prompt_engineer`
block in `scripts/init-claude.sh` now check for all three provider
CLIs and require at least one (vs. previously requiring codex
specifically). Missing providers warn but do not block install.

`commands/prompt-engineer.md` rewritten to surface `--provider`,
`all`-mode flow diagram, per-mode artifact tables, and provider-
specific install hints.

`.gitignore` adds explicit `logs/` (the existing `*.log` rule already
covered the files; the directory line is for clarity).

## [6.24.5] - 2026-05-14

### Changed — TK_TOOLKIT_REF default pinned to release tag + REL-03 CI gate

`scripts/init-claude.sh` previously defaulted `TK_TOOLKIT_REF` to
`main`. Every `curl|bash` install therefore fetched every downstream
file from the live `main` HEAD — even when the user copied the
install command from a release page seconds after a tag was cut, the
ongoing development commits would slip in. Practical impact: an
install run mid-PR-merge could fetch some files at the new commit and
others at the previous commit, leaving the consumer's `.claude/` with
a mix from two different toolkit versions.

Switched the default to the current release tag (`v6.24.5`). When a
user opts into bleeding-edge they pass `TK_TOOLKIT_REF=main`
explicitly — same way they already pin to historical tags
(`TK_TOOLKIT_REF=v6.24.1`). Every release-PR is now required to bump
**both** `manifest.json:.version` and the bundled
`TK_TOOLKIT_REF=${TK_TOOLKIT_REF:-vX.Y.Z}` default in `init-claude.sh`
in lockstep.

`scripts/tests/test-toolkit-ref-pinned.sh` (new — audit REL-03)
enforces the contract:

- Parses `TK_TOOLKIT_REF` default with the regex
  `^TK_TOOLKIT_REF="\$\{TK_TOOLKIT_REF:-`.
- Fails if the default literally equals `main` (release installs must
  pin to a tag).
- Fails if the default does not match `v<manifest.version>` exactly.
- Prints a remediation hint naming both files that need to move
  together.

Wired into the `validate-templates` job in
`.github/workflows/quality.yml` so a release-PR that forgets to bump
one side cannot merge.

### Migration notes

- Authors of release-PRs: bump three places in one commit —
  `manifest.json:.version`, `init-claude.sh:TK_TOOLKIT_REF` default,
  `CHANGELOG.md` entry. The CI `validate` job already aligns
  `manifest.version` and `CHANGELOG`; REL-03 adds `init-claude.sh`.
- Users with `TK_TOOLKIT_REF=main` in their shell rc (intentional
  bleeding-edge) keep their existing behaviour — the env override
  still wins over the bundled default.

## [6.24.4] - 2026-05-14

### Fixed — GSD bootstrap silently broken (legacy curl|bash URL 404s)

`scripts/lib/bootstrap.sh` and `scripts/update-deps.sh` both fetched
GSD via:

```text
bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)
```

GSD has since migrated from a self-hosted `curl|bash` installer to
the npm package `get-shit-done-cc`. The legacy URL now returns 404,
so every `init-claude.sh` install attempt would emit "GSD installer
download failed" (bootstrap.sh) or "probe_gsd: install failed"
(update-deps.sh) — and the user got no GSD.

Switched both call sites to npx-from-registry:

```bash
local pkg_version="${TK_GSD_NPM_VERSION:-1.41.2}"  # bootstrap default
if [[ ! "$pkg_version" =~ ^(latest|[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?)$ ]]; then
    return 1
fi
npx --yes "get-shit-done-cc@${pkg_version}"
```

Strictly safer than the previous curl|bash:

- npm verifies the registry tarball integrity hash from
  `package-lock`; the previous flow had no checksum and no signed
  installer.
- Pinned by semver tag, not `main` HEAD — a repo takeover would no
  longer instantly serve hostile bytes to every installer.
- Per-package allowlist on `TK_GSD_NPM_VERSION` rejects anything
  outside semver / `latest` so a `$pkg_version` env injection can't
  smuggle `--registry=evil.example.com` or shell metacharacters into
  the npx argv.

The previous integrity hook (`TK_GSD_PIN_SHA256` plus the manual
sha256sum/shasum verifier) is removed: it was an optional gate that
nobody could use anyway (no published hash, no signed binary), and
npm's registry hash + lock-pinning subsumes it.

bootstrap.sh: pinned default `1.41.2` (current GSD release).
update-deps.sh: default `latest` because update-deps is explicitly
an upgrade tool; the user's intent there is "give me whatever's
newest". Both honour `TK_GSD_NPM_VERSION` env override.

### Tests

`scripts/tests/test-bootstrap.sh` (26 → 29 assertions): S6 asserts
that bootstrap.sh no longer carries an active `raw.githubusercontent.com/gsd-build/get-shit-done…install.sh`
URL outside comments, references the npm package
`get-shit-done-cc`, and guards `TK_GSD_NPM_VERSION` with the
semver/tag allowlist.

`scripts/tests/test-update-deps-repomix.sh` (4 → 7 assertions): U5
mirrors S6 for `scripts/update-deps.sh`.

## [6.24.3] - 2026-05-14

### Security — Council header-injection defense + API key argv leak + RTK rewrite re-verify + repomix supply-chain

Four defense-in-depth tightenings on the install / Council code path.
No exploit observed; all are pre-emptive closures against same-host
attackers or hostile repos that the toolkit already touches at
install time.

**Council HTTP header injection (`scripts/council/{brain,mcp-server,pack}.py`)**

`ask_gemini_api` / `ask_openrouter` / `ask_chatgpt` build a 0600
tempfile and pass it to `curl -H @file` so the API key never appears
in `ps aux` (audit BRAIN-H4, 2026-04-28). If the key value carries
`\n`, `\r`, or `\x00` — for instance a user pasted a multi-line snippet
into the config wizard — those bytes are reinterpreted by curl as
"start of a new header line", injecting an arbitrary HTTP header into
the outbound request (classic CRLF injection class, e.g. silently
appending `X-Forwarded-For: 1.1.1.1`).

Added `_assert_header_safe(value, name)` which rejects CR/LF/NUL
inside any value that flows into `-H @file`. Called from every header-
building site in the three Council scripts. Bad value → `ValueError`
surfaced as `Error: <name> contains CR/LF/NUL …` and the request is
never sent.

**API keys leaking via /proc/<pid>/cmdline (`scripts/init-claude.sh`, `scripts/setup-council.sh`)**

The wizard's config-write step JSON-encoded each Gemini / OpenAI /
OpenRouter key by passing it through `python3 -c 'import json,sys;
print(json.dumps(sys.argv[1]))' "$KEY"`. The key was visible in
`/proc/<pid>/cmdline` on Linux for the lifetime of that python child
process — any same-host process under the same UID (or root) could
read it. macOS hides argv from same-UID `ps` but other tooling
(security agents, perf profilers) can still capture it.

Switched all five key-encoding sites to read from stdin
(`printf %s "$KEY" | python3 -c '… sys.stdin.read()'`). Stdin is not
exposed via cmdline and is gone the instant the python child exits.

**RTK auto-rewrite bypasses cc-safety-net (`scripts/setup-security.sh`)**

The Phase-N RTK PreToolUse hook normalises Bash commands ("rewrite
`rm /tmp/foo` to `rm -- /tmp/foo`"). When `cc-safety-net` is also
installed the combined hook runs cc-safety-net FIRST, then RTK. The
post-RTK auto-allow path however emitted
`permissionDecision: "allow"` directly on the rewritten command
without ever consulting cc-safety-net again. A hostile RTK release
(or a compromised npm registry mirror) could rewrite a benign
`rm /tmp/foo` into `rm -rf $HOME` and the user would auto-approve
the rewritten form — cc-safety-net would never see it because the
pre-rewrite check already returned `allow`.

Added a second cc-safety-net round trip: synthesise a
`PreToolUse` payload with `tool_input` replaced by the rewritten
value and pipe it through `cc-safety-net --claude-code`. If the
re-check returns `"deny"`, emit safety-net's verdict instead of
RTK's allow. Reason string now reads
`"RTK auto-rewrite (re-verified by cc-safety-net)"`.

**Repomix npx supply-chain hijack (`scripts/council/pack.py`)**

`_generate_one_shot` invoked `npx repomix` with `cwd=repo_root` for
local packing. `npx` resolves binaries from
`<cwd>/node_modules/.bin/` first, so a hostile project we are
packing for Council review could ship a malicious
`node_modules/.bin/repomix` and hijack every invocation. Even with
no node_modules in the repo, a same-UID attacker could plant one in
`/tmp` and race the call.

`_generate_one_shot` now creates a per-call tmpdir
(`tempfile.mkdtemp(prefix='council-repomix-')`) and uses THAT as
cwd. Repo path is passed positionally; the repo's own
`repomix.config.json` is forwarded explicitly via `--config`
because discovery starts from cwd (now the sandbox) and would
otherwise miss it.

Also tightened `_validate_remote_url(url)` used by
`--pack-remote`: was only checking for embedded credentials. Now
also rejects:

- empty value
- leading `-` (defeats argv injection into the downstream
  `git clone` — e.g. `--upload-pack=/bin/sh -c …`, known RCE class)
- non-http(s) schemes (no ssh://, git+ssh://, file://)
- localhost / 0.0.0.0 / broadcast hostnames
- literal private / loopback / link-local / multicast / reserved IPs
  (defense in depth against accidental SSRF; hostnames that resolve
  to such IPs are out of scope to avoid TOCTOU surprises)

## [6.24.2] - 2026-05-14

### Fixed — install TUI hang on unofficial MCPs + impeccable probe divergence

Two bugs in the v6.16+ TUI install flow surfaced when a user selected
only Telegram from the MCP sub-picker and ran a fresh `install.sh`
from a project dir with prior impeccable install in `~/.agents/`.

**Hang on unofficial MCPs after TUI submit (`scripts/lib/mcp.sh`)**

`unofficial_confirm()` blocked indefinitely on a `[y/N]` prompt the
user never saw. The parent `install.sh` wraps the
`dispatch_mcp_servers` call in `( ... ) 2>"$stderr_tmp"`
(install.sh:2272) so it can stash dispatcher stderr into a per-MCP
tail buffer (D-28). That subshell also swallowed the
`unofficial_confirm` prompt printed to stderr at mcp.sh:341-347, then
`read -r reply <"$tty_src"` (mcp.sh:350) blocked forever on
`/dev/tty` waiting for input the user had no way to know was
expected. Same class of bug the comment at install.sh:1773-1777 had
already flagged for `bridge_install_prompts`.

Added a `TK_TUI_CONFIRMED=1` bypass to `unofficial_confirm()`. The
main TUI already renders unofficial rows with a leading `[!]`
glyph (install.sh:1996-2000) and the MCP sub-picker repeats that
prefix, so submitting the row IS the consent — re-asking via a
post-submit `[y/N]` is redundant. Bypass returns 0 silently (no
stderr write) so the dispatcher-stderr capture stays clean. Scripted
non-TUI callers (no `TK_TUI_CONFIRMED`) keep the original prompt
contract.

**Impeccable probe divergence (`scripts/lib/skills.sh`)**

`is_skill_installed()` only probed `~/.claude/skills/<name>/` and
`~/.claude/skills/?-<name>/`. Impeccable's upstream npx CLI writes
to `~/.agents/<name>/` (install-impeccable.sh cds to `$HOME` to make
its `findProjectRoot()` fall through to cwd), so a user with prior
impeccable install saw the TUI render `[not installed]` then watched
`npx impeccable@latest skills install` immediately bail "already
installed (found in .agents/)" with exit 0, after which
install-impeccable.sh's post-write check at line 114 fired the
soft warning "npx command succeeded but
~/.claude/skills/impeccable/SKILL.md not found".

Added `~/.agents/<name>/` and `~/.agents/?-<name>/` as fallback
probes after the primary `~/.claude/skills/` checks. New
`TK_AGENTS_HOME` env seam for hermetic tests (mirrors
`TK_SKILLS_HOME`). TUI now correctly renders impeccable as
`[installed ✓]` when it lives under `.agents/`, the install loop
skips the redundant npx invocation, and the soft warning no longer
fires.

### Tests

`scripts/tests/test-integrations-tui.sh` (27 → 30 assertions):

- A8b — `unofficial_confirm` with `TK_TUI_CONFIRMED=1` returns 0
  even when `TK_INTEGRATIONS_TTY_SRC` points at a nonexistent path
  (proves the bypass beats the fail-closed gate at mcp.sh:335).
- A8c — `unofficial_confirm` with `TK_TUI_CONFIRMED=1` writes
  nothing to stderr (would be silently captured by the parent
  `2>"$tmp"` wrapper — even a "silent" prompt is the bug).

`scripts/tests/test-install-skills.sh` (22 → 25 assertions):

- S9  — `is_skill_installed impeccable` returns 0 when only
  `$TK_AGENTS_HOME/impeccable/` exists.
- S9b — prefix-glob form (`$TK_AGENTS_HOME/i-myskill/`) under the
  `.agents/` root for symmetry with the primary root.
- S9c — empty `.agents/` root does not cause false positive.

## [6.24.1] - 2026-05-13

### Added — `gh` CLI companion for the GitHub MCP

v6.24.0 added the GitHub Remote MCP to `components.mcp`, but the row
rendered as `[CLI:—]` because `components.cli` had no `github` entry
— toolkit didn't know the canonical companion CLI is GitHub's own
`gh`. The TUI status indicator therefore couldn't tell users whether
the partner CLI was present (`✓`) or installable (`✗`).

Added `components.cli.github` to
`scripts/lib/integrations-catalog.json`:

```json
"github": {
  "detect_cmd": "gh",
  "install": {
    "darwin": "brew install gh",
    "linux": "mkdir -p ~/.local/bin && cd /tmp && VER=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*\"tag_name\": *\"v\\([^\"]*\\)\".*/\\1/p') && curl -fsSL \"https://github.com/cli/cli/releases/download/v${VER}/gh_${VER}_linux_amd64.tar.gz\" -o gh.tgz && tar -xzf gh.tgz && cp gh_${VER}_linux_amd64/bin/gh ~/.local/bin/ && rm -rf gh.tgz gh_${VER}_linux_amd64"
  },
  "post_install_hint": "gh auth login  # browser OAuth"
}
```

Darwin: `brew install gh` (mirrors `stripe`, `supabase`).
Linux: binary download to `~/.local/bin/` (mirrors `stripe-cli` and
`aws-cloudwatch-logs` pattern — no sudo, no apt-keyring dance). Pins
to "latest" via GitHub releases API to avoid frequent catalog
churn. x86_64 only for v1 — arm64 Linux deferred (rare for toolkit
target audience: solo founders on macOS / x86_64 CI).

Now the row renders `[CLI:✓]` when `gh` is on `$PATH` or `[CLI:✗]`
when absent (toolkit installer prompts to install).

Counter bump: `scripts/tests/test-integrations-catalog.sh:165-175`
A8 expected count 8 → 9 + comment update. Validator
(`scripts/validate-integrations-catalog.py`) accepts the new entry:
30 mcp + 9 cli + 10 categories.

PR #121 merged 44f3e91.

## [6.24.0] - 2026-05-13

### Added — GitHub MCP in `scripts/lib/integrations-catalog.json`

Adds the official GitHub Remote MCP server to the curated catalog as
the 30th entry. Slots into the `dev-tools` category alongside
`serena`, `claude-context`, `playwright`. Uses the remote-transport
shape pioneered by `calendly` and `datadog` — no local Docker, no
npx wrapper, zero local runtime.

Catalog entry:

```json
"github": {
  "name": "github",
  "display_name": "GitHub",
  "category": "dev-tools",
  "env_var_keys": [],
  "install_args": [
    "--transport", "http", "github",
    "https://api.githubcopilot.com/mcp/"
  ],
  "description": "Official remote MCP — repos, PRs, issues, Actions, code search (OAuth or PAT)",
  "requires_oauth": true,
  "default_scope": "user"
}
```

Renders as `claude mcp add --transport http github
https://api.githubcopilot.com/mcp/`. First use triggers
GitHub's OAuth flow in the browser; PAT fallback supported by the
upstream endpoint when OAuth is unavailable. Surface: repos, PRs,
issues, Actions, code search, releases, branches, secrets metadata —
covers ~90% of `gh` CLI use cases inside Claude Code without leaving
the agent loop.

Counter bumps:

- `scripts/tests/test-mcp-selector.sh:84` — 29 → 30
- `scripts/tests/test-integrations-tui.sh:149-151` — 29 → 30 (3 lines)
- `scripts/tests/test-integrations-catalog.sh:115-130` — A5
  expected-count + comment
- `scripts/tests/test-catalog-serena.sh:84` — band check already
  accepted 20-30 inclusive; no edit needed

All 4 impacted tests green locally (catalog 21/21, mcp-selector
36/36, tui 27/27, serena 8/8). JSON valid (`jq empty`). Validate
templates job clean. shellcheck unaffected (no shell-script edits).

Why MUST-HAVE: GitHub is the canonical code-hosting surface for most
toolkit users; previously absent from the catalog because the
upstream `@modelcontextprotocol/server-github` was deprecated and
GitHub's replacement is a Go binary (no `npx -y` wrapper). The
**remote** MCP endpoint published by GitHub bypasses both problems —
official, maintained, zero-install.

Bitbucket NOT added: no remote MCP, no `npx`-installable wrapper, no
Atlassian-hosted equivalent of `https://api.githubcopilot.com/mcp/`.
Add when a remote endpoint or maintained Node wrapper appears.

### Bucket 1 pilot — DESIGN_REVIEW.md optimized via `pe` pipeline

Bucket 1 of the v6.21.0 sequenced plan opens with the smallest audit
prompt as pilot validation of the mandatory `pe` (Prompt Generator)
two-stage pipeline now documented in `templates/base/CLAUDE.md`.

#### Pipeline executed

1. **Stage 1 — `pe` draft** — Ran
   `python3 scripts/prompt-engineer/optimize_prompt.py`
   `templates/base/prompts/DESIGN_REVIEW.md --context`
   `/tmp/design-review-ctx.md`. Context file declared preservation
   constraints (5 v42-splice sentinels, em-dash slot, CI-required
   audit pipeline markers, splice-region body immutability) and
   surfaced specific defects (schema contradiction between Report
   Template and OUTPUT FORMAT; duplicate Common Issues Checklist;
   generic Design Principles filler; inconsistent emoji headings).
2. **Stage 2 — manual context-aware merge** — Stripped the outer
   three-backtick markdown fence wrapper from the optimizer output;
   verified all 5 splice sentinels and 4 CI-required markers (Council Handoff
   heading, `1. **Read context**`, `6. **Severity sanity check**`,
   em-dash slot) survived byte-exact; confirmed splice-region bodies
   (rubric-anchors, SELF-CHECK, OUTPUT FORMAT, Council Handoff)
   passed through untouched so the next
   `propagate-audit-pipeline-v42.sh` run is idempotent.

#### Outcome — `templates/base/prompts/DESIGN_REVIEW.md`

- 684 → 552 LOC (132 LOC removed, ~19% reduction in source size).
- `## 📝 Report Template` section deleted — it defined a free-form
  markdown report layout that contradicted the canonical structured
  schema spliced from `components/audit-output-format.md`. The
  contradiction had silently shipped since the section was spliced
  into the file; readers had two different output formats in one
  prompt. Removing the obsolete free-form template leaves the spliced
  OUTPUT FORMAT as the single source of truth.
- `## Common Issues Checklist` section deleted — every item it listed
  was already covered in Phase 4 (Visual Polish) or Phase 5
  (Accessibility).
- `## Design Principles Reference` section deleted — five generic
  heuristics (Hierarchy, Consistency, Feedback, Forgiveness,
  Simplicity) with no project anchor.
- `## Playwright MCP Quick Reference` consolidated to a single block;
  per-phase MCP references pruned to a one-line pointer.
- Emoji removed from H2 headings (🎯, 📋, 📝) to match the audit-
  prompt house style used by `CODE_REVIEW.md`, `SECURITY_AUDIT.md`,
  `PERFORMANCE_AUDIT.md`.
- Heading capitalization normalized to sentence case for H2+.
- SPA framework note added to Phase 2 ("For SPA frameworks such as
  React, Vue, and Svelte, test state transitions, not only initial
  DOM render").
- `## Category constraint` section added with design-review-specific
  category guidance (Reliability / Operational Maintainability Risk
  / Correctness) drawn from the structured schema enum.
- All v42-splice sentinels, splice region bodies, em-dash slot, and
  CI markers preserved byte-exact. `make check`, `bash scripts/`
  `tests/test-template-propagation.sh` (11/11), and markdownlint pass.

#### Why this pilot matters

This shipment exercises the `pe` + manual-merge pipeline end-to-end on
a real Bucket 1 file with a real preservation-constraint surface (5
sentinels, 4 CI markers, em-dash slot, splice region bodies). The
template is reusable for the remaining 6 base audit prompts
(`CODE_REVIEW`, `MYSQL_PERFORMANCE_AUDIT`, `PERFORMANCE_AUDIT`,
`POSTGRES_PERFORMANCE_AUDIT`, `SECURITY_AUDIT`, `DEPLOY_CHECKLIST`).

#### Also in this PR

- `templates/base/CLAUDE.md` — new `## Prompt Optimization Pipeline
  (MANDATORY)` section codifies the two-stage `pe` workflow as a
  project-level instruction. Every prompt-file edit must go through
  `pe` first, then a manual context-aware merge.

## [6.23.4] - 2026-05-13

### Fixed — dispatch_skills + dispatch_mcp_servers fail under main TUI (F-1 gate regression)

Production-breaking regression introduced by the v6.23.1 F-1 audit
gate (`scripts/install.sh:277`): under `curl | bash` install via the
main TUI, when the user selects either the `skills` or `mcp-servers`
catalog row, the parent `install.sh` pre-collection block at
`install.sh:1847+` (gated by `TK_TUI_CONFIRMED=1` after main-TUI
submit) exports `TK_MCP_CATALOG_PATH=<tmp>` for its own
`mcp_catalog_load` call. That export then leaks into the child
`bash <(curl ...) install.sh --skills | --integrations` spawned by
`dispatch_skills` / `dispatch_mcp_servers` (`scripts/lib/dispatch.sh`)
via standard env inheritance, and the child immediately hits the F-1
gate at startup (TK_MCP_CATALOG_PATH set, TK_TEST≠1) → `exit 1`.
Side-effect: curl error 56 ("Failure writing output to destination,
passed 16366 returned 0") because bash exited before curl finished
streaming the install script through the pipe.

User-visible: install summary shows two failed rows with the
audit-gate error message even though no install logic ran. Affects
every main-TUI install path that touches skills or mcp-servers
catalog selection from v6.23.1 onward.

Fix: prepend `env -u TK_MCP_CATALOG_PATH` to every child `bash`
invocation inside `dispatch_skills` and `dispatch_mcp_servers` (both
curl-pipe and sibling-path branches). Child sees a clean slate, the
F-1 gate stays satisfied, and the child re-downloads the catalog
itself when it reaches its own `_is_curl_pipe && [[ -z
TK_MCP_CATALOG_PATH ]]` block at `install.sh:317` / `install.sh:1934`.
Cost: one extra ~16KB curl per dispatch — negligible. The original
inheritance optimization documented in `install.sh:307-311` (avoid
duplicate download) is sacrificed; in exchange the F-1 attack
surface stays sealed.

Tests: `scripts/tests/test-dispatch-env-scrub.sh` (new, 3
assertions): one static grep validating 4 `env -u TK_MCP_CATALOG_PATH bash`
call sites in dispatch.sh, plus two runtime scenarios
(`dispatch_skills` then `dispatch_mcp_servers`, both sibling-path
branch) where the parent has
`TK_MCP_CATALOG_PATH=/tmp/parent-catalog-fake` and a stub
`install.sh` writes its inherited value to a result file — both
record `UNSET` post-fix. Wired into `.github/workflows/quality.yml`
test-install-features job. shellcheck `-S warning` clean.

PR #117 merged 0101c9a.

## [6.23.3] - 2026-05-13

### Fixed — skill detection prefix-agnostic (mirror of v6.23.2 memo fix)

`scripts/lib/skills.sh:is_skill_installed` hard-coded
`~/.claude/skills/<name>/`, matching only the toolkit's own
`skills_install` writer layout. When users install skills via a
skills-marketplace that prepends a 1-char prefix (e.g.
`~/.claude/skills/i-<name>/`), the probe missed every install and the
TUI rendered `[ ] <skill>` for the entire 24-skill catalog even with
all of them functional.

Two coordinated patches in `scripts/lib/skills.sh`:

1. `is_skill_installed` — accept `<name>/` OR `?-<name>/` (single-char
   prefix + dash + name). Covers marketplace's `i-` prefix and any
   alternate 1-char scheme without false-positiving on long-prefix
   sibling skills.
2. `skills_install` — bail with rc=2 (already-installed) when
   `?-<name>/` exists, even under `--force`. Prevents
   marketplace+toolkit duplicate installs that Claude Code would load
   as two separate skills with different `name:` frontmatter.

Tests: 7 new assertions across S7 (detection-marketplace-prefix, 3
cases: `i-` prefix, `p-` prefix, absent) and S8 (install-refuses-
marketplace, 4 cases: rc=2 without --force, rc=2 with --force, no
duplicate, marketplace content preserved). All 22 assertions in
`test-install-skills.sh` pass. shellcheck `-S warning` clean.

Same class as v6.23.2 (`claude-memo` probe). Probe-by-content-or-
schema-aware-path > probe-by-exact-directory-name when install layout
varies across channels (toolkit standalone vs marketplace).

PR #115 merged b45e0e9.

Also restores the `### Bucket 1 pilot — DESIGN_REVIEW.md optimized via
\`pe\` pipeline` H3 heading under [Unreleased] that PR #115's Edit
accidentally removed when it spliced the skill-detection block.

## [6.23.2] - 2026-05-13

### Fixed — claude-memo detection prefix-agnostic (probe by signature file)

`scripts/install.sh` claude-memo install detection (TUI probe + dispatch
idempotency) hard-coded the skill path as
`~/.claude/skills/memo-skill/SKILL.md`, matching only the toolkit's
standalone `install-claude-memo.sh` layout. When users install the
skill via a skills-marketplace that prefixes directories (e.g.
`~/.claude/skills/i-memo-skill/`) — or any other custom prefix — the
probe missed the install and the TUI rendered `[ ] claude-memo` even
with a fully functional skill + populated vault.

Switched both probes to glob a unique signature file —
`scripts/memo_engine.py`, present in every claude-memo install and in
no other skill — under `~/.claude/skills/*/scripts/memo_engine.py`.
The glob is prefix-agnostic and works under Bash 3.2 (macOS) without
`shopt -s nullglob`: the `for f in PATTERN; do [[ -f "$f" ]] && ...; done`
form silently falls through when the pattern doesn't expand.

Files: `scripts/install.sh` (L1514-1532 probe, L2203-2210 dispatch).
Smoke tested across 5 scenarios (`i-` prefix, no prefix, custom
`p-memo-2026` prefix, no skill, skill-only-no-vault) — all expected
results. shellcheck `-S warning` clean. No test refs to the old path
in `scripts/tests/`.

PR #113 merged 9c60244.

## [6.23.1] - 2026-05-13

### Security audit hardening — 2026-05-13 sweep (4 findings)

Repo audit run on the v6.23.0 head surfaced four findings in the install /
catalog dispatch path. Three are now closed; the fourth (`F-9` tests
missing `set -e`) was a false positive and dropped after re-verification.

#### F-1 — `TK_MCP_CATALOG_PATH` test seam without `TK_TEST=1` gate (HIGH / Security)

`scripts/install.sh` previously honoured `TK_MCP_CATALOG_PATH` from the
calling environment unconditionally. The catalog string then flowed into
`bash -c` via `cli-installer.sh:123,130`, so a pre-set env var pointing at
an attacker-controlled JSON file would have executed arbitrary commands
under the user's account during `bash <(curl -sSL .../install.sh)`. This is
the same RCE class that audit C2/H6 closed for
`TK_SP_INSTALL_CMD`/`TK_GSD_INSTALL_CMD` via `TK_TEST=1` gating.

Mirror lockdown: `install.sh:269-277` now rejects a pre-set
`TK_MCP_CATALOG_PATH` unless `TK_TEST=1` is also exported, with a
diagnostic stderr message. Internal exports inside `install.sh` (after the
curl-pipe catalog download) happen after the gate and remain unaffected.
Tests in `test-integrations-tui.sh` (A16, A17) that legitimately pre-set
the catalog path now also export `TK_TEST=1`.

#### F-2 — `eval` in `scripts/vendor/pin-vendors.sh` with git-tag interpolation (HIGH / Bug)

Lines 99-100 used `eval "ARG_${name//-/_}_TAG='$head_tag'"`. Git tags
legally contain single quotes (`'`) and other shell metacharacters; an
upstream vendor pushing a hostile tag could break the eval and, in the
worst case, inject shell into the maintainer's environment.

Replaced with three parallel indexed arrays (`PIN_NAMES`, `PIN_COMMITS`,
`PIN_TAGS`) iterated by index. Values flow straight into `jq --arg` which
quotes them safely. Verified via `DRY_RUN=1 bash scripts/vendor/`
`pin-vendors.sh` — all 8 vendor pins captured correctly.

#### F-3 — `validate-integrations-catalog.py` did not cover `components.cli.*` (MEDIUM / Security)

The validator rigorously checked `components.mcp.*` shape but left
`components.cli.*` unvalidated. The CLI side carries `install.darwin` /
`install.linux` strings that flow into command execution in
`cli-installer.sh`, so missing coverage meant a malformed entry could
slip past `make validate-catalog`.

Added Check 12: every `components.cli[<name>]` entry must have non-empty
`detect_cmd` and `install.{darwin,linux}` string fields; control
characters (`\n`, `\r`, `\x00`, `\x08`) are rejected in all command-class
fields. Optional `post_install_hint` is type-checked when present.
Validator now reports `29 mcp entries + 8 cli entries checked`.

Regression test A21 added to `scripts/tests/test-integrations-catalog.sh`:
mutates the catalog to inject a newline into one CLI entry's
`install.darwin` and asserts the validator exits non-zero with a
`install.darwin contains a forbidden control character` message.

#### Defense in depth — `cli-installer.sh` `eval` → `bash -c`

Even with F-1 closed and F-3 in place, the eval-class footprint in
`cli-installer.sh:123,130` was widened — `eval` runs in the current shell
and could pollute exported state on a future regression. Replaced with
`bash -c -- "$cmd"` so the catalog-provided string executes in a child
shell. Existing `test-cli-installer.sh` (24 assertions) stays green
without modification.

#### Deferred (separate PRs)

- **F-7** monolith decomposition (`install.sh` 2457 LOC, `brain.py` 3503
  LOC, `mcp.sh` 1582 LOC) — refactor scope estimated 4-6h.
- **F-8** CI init-matrix expansion from 2 to 6 frameworks × 2 OS.
- `eval "$@"` in `setup-comet.sh` / `setup-open-design.sh` — internal
  callers only, low priority; invasive call-site rewrite.
- `CHANGELOG.md` archival split (211 KB).

### Fixed — Project-scope MCPs fail under `curl | bash` (project-secrets lazy-source path collapse)

User report 2026-05-12: project-scope MCPs (`cloudflare`, `stripe`,
`mailgun`) failed during the installer's MCP dispatch with
`mcp_wizard_run: project-scope requested but scripts/lib/project-`
`secrets.sh not loaded`. User-scope MCPs (`comet-bridge`, `context7`,
`notebooklm`, `repomix`, ...) installed cleanly side-by-side, so the
breakage was scope-specific.

#### Root cause

`scripts/lib/mcp.sh:97-106` lazy-sources `project-secrets.sh` through a
`BASH_SOURCE`-relative sibling path
(`${dirname BASH_SOURCE[mcp.sh]}/project-secrets.sh`). Under
`curl ... | bash` / `bash <(curl ...)`, `install.sh`'s `_source_lib mcp`
writes `mcp.sh` into `/tmp/mcp-XXXXXX` and sources from there.
`_MCP_LIB_DIR` resolves to `/tmp`; the lazy sibling target
`/tmp/project-secrets.sh` does not exist, so the guarded
`if [[ -f ... ]]` silently skips the source. Later, `mcp.sh:782`
checks `command -v project_secrets_write_env` and aborts
`mcp_wizard_run` when the user selected any project-scope MCP. Exact
same class as the v6.23.1 skills-curl-pipe path-resolution regression.

#### Fix

`install.sh` now calls `_source_lib project-secrets` immediately
before each `_source_lib mcp` site (top-level `MCPS=1` branch +
MCP sub-picker re-entry). Loading project-secrets first declares
the `project_secrets_*` functions before `mcp.sh`'s guard runs;
`mcp.sh:97` (`command -v project_secrets_write_env`) then
short-circuits the lazy sibling-source path entirely.

#### Tests

- New `scripts/tests/test-install-project-secrets-curl-pipe.sh`
  (3 assertions, 3 scenarios): PS1 reproduces the curl-pipe baseline
  with `mcp.sh` sourced alone from `/tmp` (`project_secrets_write_env`
  stays undeclared); PS2 confirms sourcing `project-secrets.sh` before
  `mcp.sh` declares both function families; PS3 is a structural
  regression guard asserting `install.sh` carries a
  `_source_lib project-secrets` call within 5 lines of every
  `_source_lib mcp` site.
- Sibling tests untouched: `test-mcp-selector.sh` (36/36),
  `test-mcp-secrets.sh` (11/11), `test-mcp-wizard.sh` (63/63),
  `test-install-skills-curl-pipe.sh` (14/14). `make check` green;
  shellcheck clean.

### Fixed — Double scope glyph in MCP scope lock-screen

User report 2026-05-12 (screenshot): the per-row MCP scope picker
rendered every row with two scope brackets — `[U] [U] Cloudflare`,
`[P] [P] Stripe`, etc. — until Tab was pressed on that row, at which
point a single bracket appeared.

#### Root cause

`install.sh:405-455` builds a SHADOW set of `TUI_*` arrays containing
only rows the user picked in the prior catalog TUI, then runs
`tui_checklist` in `TK_TUI_LOCK_SELECTION=1` mode for the scope-edit
sub-screen. The shadow-build loop copied `_SAVE_LABELS[$_i]` verbatim
into `TUI_LABELS[]` — but those labels were already prefixed with a
single scope glyph by `mcp_status_array`'s prior call to
`_mcp_rebuild_row_labels`. A second loop then case-on-scope-prepended
`[U]`/`[P]`/`[L]` (with a trailing space) to each row, producing the
visible double glyph.
Pressing Tab fired `mcp_cycle_row_scope_locked`, which rebuilt the
row's label from `MCP_DISPLAY[]` via the canonical single-glyph path
and masked the bug for that row only.

#### Fix

Replaced the manual prepend loop with a single call to the canonical
`_mcp_rebuild_row_labels` helper (`scripts/lib/mcp.sh:1164`), which
writes every `TUI_LABELS[$_j]` from scratch using `MCP_DISPLAY[]`,
`MCP_UNOFFICIAL[]`, and a single `_mcp_render_scope_glyph` invocation.
One label-build code path now serves the catalog TUI, the lock-screen
sub-picker, and the per-row Tab cycle.

#### Tests

- New `scripts/tests/test-mcp-lock-screen-glyph.sh` (10 assertions, 2
  scenarios): LG1 documents the canonical helper's single-glyph
  contract under pre-glyphed shadow input; LG2 is a structural
  regression guard asserting the lock-screen init block carries the
  helper call and dropped the legacy `_g="[U]"` + manual prepend
  construct.
- Existing `scripts/tests/test-tui-lock-selection.sh` (6/6),
  `test-mcp-selector.sh` (36/36), and `test-mcp-detect-installed-`
  `scope.sh` (8/8) unchanged; `make check` green; shellcheck clean.

### Fixed — Skills install under `curl | bash` (path-resolution regression)

Marketplace skills install path failed for every fresh skill when the
installer ran via `bash <(curl ...)` or `curl ... | bash` (user report
2026-05-12: `huashu-design` and `impeccable` failed with `source missing:
/var/folders/.../T/../../templates/skills-marketplace/huashu-design`).

#### Root cause

Under curl-pipe, `install.sh:_source_lib skills` writes
`scripts/lib/skills.sh` into `/tmp/skills-XXXXXX` and sources it from
there. `skills.sh` resolved the source mirror via a `BASH_SOURCE`-
relative path (`${dirname BASH_SOURCE}/../../templates/skills-marketplace`),
which under tmpfile origin collapses to a non-existent
`/var/folders/.../templates/skills-marketplace`. Equivalent bug applied
to the `impeccable` special-case lookup of `install-impeccable.sh`. The
existing curl-pipe handler for the MCP catalog (`install.sh:291-300`)
had no equivalent for skills; both `TK_SKILLS_MIRROR_PATH` and
`TK_SKILLS_INSTALL_IMPECCABLE_CMD` were declared as env-var seams in
`skills.sh` but never populated by `install.sh`.

Pre-installed skills masked the bug in tester reports because the
dispatch loop short-circuits to `"installed ✓"` without invoking
`skills_install` when `TUI_RESULTS[i]=0`. A fresh machine with no
`~/.claude/skills/` would have seen all 24 skills fail.

#### Fix

- New `skills_fetch_mirror_via_tarball` in `scripts/lib/skills.sh`
  downloads `https://github.com/sergei-aronsen/claude-code-toolkit/`
  `archive/${TK_TOOLKIT_REF}.tar.gz`, extracts to a tmpdir, and exports
  both `TK_SKILLS_MIRROR_PATH` and `TK_SKILLS_INSTALL_IMPECCABLE_CMD`
  pointing at the extracted tree.
- `scripts/install.sh` after `_source_lib skills` (when `SKILLS=1` and
  `_is_curl_pipe`) calls the helper and exits with a clear error if
  the tarball fetch or extraction fails. Mirrors the existing MCP-
  catalog curl-pipe handler pattern.
- `TK_SKILLS_TARBALL_CMD` test seam added so hermetic tests can stub
  the curl call with a local fixture tarball.

#### Tests

- New `scripts/tests/test-install-skills-curl-pipe.sh` (14 assertions,
  6 scenarios): reproduces the bug under simulated curl-pipe origin
  (CP1), confirms the new helper exists (CP2) and exports both env
  vars from a fixture tarball (CP3), exercises the end-to-end install
  path through the seam (CP4), verifies the `impeccable` special-case
  picks up the helper-exported override (CP5), and confirms a failing
  fetch leaves no partial state (CP6).
- Existing `scripts/tests/test-install-skills.sh` (15/15) still
  passes; `make check` green; shellcheck clean.

## [6.23.0] - 2026-05-12

### Added — Repomix integration

Closes Supreme Council's prior context-starvation problem by feeding a
compressed full-repo pack to Gemini (Skeptic) and ChatGPT (Pragmatist)
alongside the existing targeted-files context.

- **`brain.py --pack`** (default ON when Node available). Generates a
  `repomix --compress --style xml` snapshot of the local repo, caches it
  at `.claude/scratchpad/repomix-pack.xml`, and injects it before
  `FILES CONTEXT` in both Skeptic and Pragmatist prompts. Pack content
  passes through the existing `redact_context()` layer on top of
  Secretlint (defense in depth). Cache invalidates automatically when
  any tracked file's mtime exceeds the pack's mtime. New flags:
  `--no-pack`, `--pack-force`, `--pack-fresh`, `--pack-remote <url>`.
- **180k-token soft budget** with graceful degradation chain — over-budget
  packs are dropped silently and Council falls back to legacy targeted
  context. Override via `REPOMIX_PACK_BUDGET` env var.
- **`/pack` slash command** (`commands/pack.md`) wraps repomix for manual
  invocation: `/pack`, `/pack --remote user/repo`, `/pack --to clipboard`,
  `/pack --format md`. Writes to `.claude/scratchpad/pack-<timestamp>.<ext>`.
- **`repomix` skill** (`templates/base/skills/repomix/SKILL.md`) with EN+RU
  triggers and a decision matrix showing when repomix beats `Grep` /
  `Read` / `find-function` / `Explore`.
- **MCP catalog entry** (`scripts/lib/integrations-catalog.json`) — 29th
  server, `category=dev-tools`, `default_scope=user`, zero secrets,
  pinned to `repomix@1.14.0`.
- **`update-deps.sh probe_repomix` + `upgrade_repomix`** — `_sync_repomix_pin`
  bumps `manifest.json:vendor_pins.repomix.tag` and sed-rewrites every
  `repomix@<old>` string in `pack.py`, the MCP catalog, `pack.md`, and the
  skill. BSD- and GNU-`sed`-compatible.
- **`docs/REPOMIX.md`** — user-facing guide on pack flow, budgets, MCP,
  security model, and disabling.
- **Pinned version** `repomix@1.14.0` in `manifest.json:vendor_pins`.
- **Tests** — `test-council-pack.sh` (12 assertions), `test-mcp-repomix.sh`
  (8), `test-update-deps-repomix.sh` (4); existing `test-mcp-selector.sh`
  bumped 28 → 29 entries (36 assertions).

### Changed

- `manifest.json` version 6.22.0 → 6.23.0; `commands/pack.md` and
  `skills/repomix/SKILL.md` registered in the manifest file lists.
- `templates/base/skills/skill-rules.json` gains the `repomix` activation
  block.

### Deferred to v6.24

- `VENDOR_USE_REPOMIX=1` flag in `scripts/vendor/clone-pinned.sh`. Reason:
  the downstream `diff-summary.sh` reads `.git/` directories for commit
  history; switching to packed XML requires a coordinated rewrite of both
  files. Ship as a follow-up PR with both halves.

## [6.22.0] - 2026-05-12

### Framework template consolidation — 40 files deleted

Removed framework-specific duplicates of base agents and audit prompts.
After v6.21.0 made `templates/base/agents/*.md` framework-aware inline
(security-auditor covers all 6 stacks; test-writer carries per-stack
examples), the per-stack mirrors became drift debt — older checklist-
style content that diverged from the modern hypothesis-driven base by
200–1500 lines per file.

The install fallback chain already routes framework→base when a
framework file is absent (`scripts/init-claude.sh` `download_files()`
lines 745–759), so no behavior change for end users: installs in
laravel/rails/python/go projects now resolve straight to the modern base
content for these prompt types.

#### Deleted (40 files)

- 16 framework agents — `templates/{laravel,rails,python,go}/agents/`
  `{code-reviewer,planner,security-auditor,test-writer}.md`. Pure drift
  after v6.21.0 base-agent rewrites covered all stacks inline.
- 24 framework audit prompts — `templates/{laravel,rails,python,go}/`
  `prompts/{CODE_REVIEW,DESIGN_REVIEW,MYSQL_PERFORMANCE_AUDIT,`
  `PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,SECURITY_AUDIT}.md`.
  Base versions are post-v6.13 modern audit methodology (threat model,
  severity ceiling, FP control gates, exploit chains) — superior to
  the deleted framework checklist variants.

#### Kept

- 4 stack-experts — `templates/{laravel,rails,python,go}/agents/`
  `{laravel,rails,python,go}-expert.md`. Deep stack-specific knowledge
  not encodable in framework-agnostic base.
- 4 DEPLOY_CHECKLIST — `templates/{laravel,rails,python,go}/prompts/`
  `DEPLOY_CHECKLIST.md`. Framework-specific shell commands
  (`artisan config:cache`, `composer install --no-dev`, `rails db:`
  `migrate`, `go build -ldflags`, etc.) that base cannot replicate
  generically.

#### Test and CI updates

- `scripts/tests/test-template-propagation.sh` — expected source count
  35→11, expected splice count 30→6 (base only). DEPLOY_CHECKLIST
  remains excluded per v6.15.0 (runbook, not audit).
- `scripts/propagate-audit-pipeline-v42.sh` — header updated; loop now
  finds 6 base audit prompts (was 30 across 5 frameworks × 6 types).
- `.github/workflows/quality.yml` and `Makefile` — message strings
  updated from "30 audit prompts" / "35 prompt files" to "6 audit
  prompts".

#### Why this is safe

The framework→base fallback in `download_files()` was added precisely
for this case: deleting a framework-specific file silently routes the
install to the base version. End-user installs continue to function;
they receive the higher-quality modern base prompts where they
previously got the older drifted variants.

Net deletion: ~15,000 LOC removed (40 files averaging ~375 lines).
Repository simplification: single source of truth for 6 audit prompt
types and 4 base agents.

## [6.21.0] - 2026-05-11

### Prompt batch — Group B personas + base agents rewritten

Eight prompt files rewritten via the v6.20.0 `pe` optimizer plus per-file
manual merge. Pipeline = single-pass Codex CLI optimization with a
per-file context document, followed by line-by-line merge to restore
parser-sensitive tokens, output-section names, refusal tables, and
schema fields. Per-file commits in the PR for traceability.

#### Group B — `/product-review` personas

Four self-contained persona system prompts consumed by Claude when the
`/product-review` slash command runs. Sharpened business-review voice;
lane-split so the four personas no longer overlap. Output section
headings preserved verbatim for the aggregator in
`commands/product-review.md`.

- **product-skeptic** — sharper TAM/SAM/SOM and JTBD discipline.
  Added experiment-discipline section (paid commitment > survey
  interest). 63 → 199 lines.
- **marketer-pragmatist** — expanded channel taxonomy with
  forcing-functions (name the channel + first 10 acquisition attempts,
  or treat distribution risk as too high to start building). Added
  recommendation-specificity templates so the persona produces
  "run $50 LinkedIn ad targeting X" rather than "improve marketing".
  69 → 208 lines.
- **cfo-pragmatist** — explicit benchmark table (LTV/CAC, payback,
  CVSS-style severity bands). Hardened SaaS-graveyard gate with
  three-state classification (`in graveyard` / `borderline` / `safe`).
  Added LLM-inference and payment-processor gotchas to gross-margin
  section. Tier-engineering guidance now concrete (price points,
  annual prepay, multi-seat tiers, usage caps) instead of vague
  "test pricing". 73 → 213 lines.
- **user-empath** — hardened first-person discipline (explicit
  accept-list "I would use this", reject-list "As the user…"). Added
  frequency-of-pain classification (daily / weekly / monthly /
  quarterly / rare) that maps to subscription willingness. Trust-
  threshold section now distinguishes data classes (read-only,
  personal, customer, financial, irreversible actions) with concrete
  example sentences. 75 → 278 lines.

#### Base agents — `templates/base/agents/`

Four agent system prompts that ship in every project install via
`init-claude.sh`. Preserved verbatim: YAML frontmatter (allowed-tools
scopes), all parser-sensitive tokens and schema fields. Made framework-
agnostic where original was Laravel-centric.

- **code-reviewer.md** — added explicit Diff Discipline section (inline
  comments target changed lines only, post-change line numbers for
  RIGHT side, untouched-code concerns go in Concerns section not
  inline, one finding per location). Expanded `review.json` structured-
  output rules (validate with jq, confirm every line matches a changed
  line, never run gh commands when workflow publishes). 254 → 365
  lines.
- **planner.md** — added Plan-Compliance Contract (plans must be
  specific enough for code-reviewer's Plan Compliance checklist to
  verify post-implementation), Plan-Mode Discipline (read-only research
  with scratchpad-only write), Clarifying Questions First (up to 3
  blocking questions before research), Verify-First Codebase Research,
  MoSCoW priorities, Plan Quality Bar. Fixed broken nested code-fence
  in Plan Template. Replaced PHP-specific path examples with language-
  agnostic `.ext` placeholders. 195 → 316 lines.
- **security-auditor.md** — made framework-agnostic. Original was
  Laravel-centric; now covers all 6 supported stacks (Laravel, Rails,
  Next.js, Node/Express, Python/Django/Flask, Go) with per-stack
  what-to-check + grep examples. Added CVSS-aligned severity bands
  (Critical 9.0+, High 7.0-8.9, Medium 4.0-6.9, Low 0.1-3.9),
  HIGH/MEDIUM/LOW confidence levels per finding (LOW cannot drive
  Critical), Audit Mode (diff vs full-repo), Observations section for
  theoretical leads, Finding Requirements checklist, Final Review
  self-check. Fixed broken code-fence nesting. Authorization-context
  boundary explicit (refuses attack tooling, real-world exploitation,
  operational payloads). 325 → 589 lines.
- **test-writer.md** — expanded framework coverage to all 6 stacks
  (Laravel/Pest, Rails/RSpec, Node.js/Jest+Vitest, Python/pytest, Go)
  with concrete 20-30 line example tests per stack. Added Framework
  Detection table. Added Bash whitelist for `pytest`, `go test`,
  `bundle exec rspec`. Strengthened TDD discipline (explicit
  Red/Green/Refactor phases, Pre-Write Checks, Non-Negotiable Rules).
  Expanded coverage taxonomy from 5 to 8 categories (added Integration,
  Contract, Property). Added Acceptance Criteria Mapping to
  `.claude/scratchpad/` plans, Security Test Expectations, Minimal
  Implementation Scope rule (smallest production change, no broader
  public-API expansion, no new deps). 357 → 493 lines.

## [6.20.0] - 2026-05-11

### Prompt Engineer — single-prompt optimizer integrated

Adds a second AI tool alongside the Supreme Council:
`/prompt-engineer <path>` (slash command) and `pe <path>` (shell alias).
Rewrites one prompt file into a deployment-ready version using Codex
CLI (ChatGPT). Where the Council validates an implementation plan with
Skeptic + Pragmatist review, the Prompt Engineer rewrites a single
prompt for clarity, controllability, reliability, and reusability.

Vendored from <https://github.com/sergei-aronsen/prompt-optimizer>
(single source file, standard library only, no pip deps) with two
local bug fixes:

- **600 s timeout** on the `codex exec` subprocess. The upstream call
  used the default `subprocess.run` behaviour (no timeout), so a hung
  Codex session would block the script forever. The fix raises a
  `RuntimeError` and writes a `--- TIMEOUT after Ns ---` marker to
  the per-stage log file.
- **`try/finally`** around `tempfile.NamedTemporaryFile` so the
  temporary output file is cleaned up even when the subprocess raises
  before the explicit `unlink`. Previously, any exception between
  `mktemp` and `unlink` leaked a file into `/tmp`.

The upstream `optimize_prompt.py` recently switched from a fixed
3-stage pipeline (PROMETHEUS → meta → synthesis) to a default
single-pass mode where one PROMETHEUS call internally performs both
first-pass optimization and a meta-optimization sweep. Single-pass is
faster, cheaper, and produces near-best-of-three quality on
well-defined source prompts. The legacy 3-stage pipeline is still
available via `--multi-pass` for short or ambiguous source prompts.

### Install surface

Standalone installer:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-prompt-engineer.sh)
```

Lays down:

- `~/.claude/prompt-engineer/optimize_prompt.py` (executable)
- `~/.claude/prompt-engineer/README.md`
- `~/.claude/commands/prompt-engineer.md` (global slash command)
- `pe` shell alias appended to `~/.zshrc` or `~/.bash_profile`

`scripts/init-claude.sh` calls a new `setup_prompt_engineer` function
right after the Supreme Council install step. A new
`--no-prompt-engineer` flag skips the install for users who do not
want it. The function is non-interactive — it surfaces a warning if
the Codex CLI is missing on `PATH` but never blocks the broader
toolkit install.

### Files

- `scripts/prompt-engineer/optimize_prompt.py` (new — vendored + 2 local fixes)
- `scripts/prompt-engineer/README.md` (new)
- `scripts/setup-prompt-engineer.sh` (new — standalone installer)
- `commands/prompt-engineer.md` (new — global slash command)
- `scripts/init-claude.sh` (`setup_prompt_engineer` function + call site +
  `--no-prompt-engineer` flag plumbing)
- `manifest.json` (version bump)
- `CHANGELOG.md` (this entry)

### Operator note

Requires the Codex CLI (`npm install -g @openai/codex`) and an OpenAI
account — same dependency the Council already surfaces. No pip
dependency, no API keys, no config file. Run `pe --help` after
sourcing the updated shell rc.

## [6.19.0] - 2026-05-11

### Supreme Council — full rewrite of all four role system prompts

Re-authored every Council role prompt (`templates/council-prompts/*.md` plus
`templates/council-prompts/ru/*.md`) to lift verdict discipline closer to
production-review quality. Pure prompt content — no orchestrator changes
beyond one defensive regex fix.

`skeptic-system.md` becomes an explicit **anti-build decision gate** with
six evaluation tests (Necessity / Now-vs-Later / Smallest-Useful-Change /
Future-Proofing Trap / One-Way Door / Maintenance Burden), a Burden-of-Proof
checklist of complexity triggers (queues, caches, plugin systems, generic
engines, persistent state, public API changes), a four-category evidence
model (need / complexity / code-grounded / general-pattern), and a Simpler
Alternative ruleset that forces every alternative to reduce a concrete
dimension (files touched, abstractions, persistent state, infra deps,
runtime paths, config surface, future commitments).

`pragmatist-system.md` becomes a production-readiness gate with the
core question "will this deliver enough real production value to justify
implementation and long-term maintenance cost", three evidence categories
(code-grounded / plan-grounded / general-pattern, each with its own citation
format), and a Prior-Art Lookup Hierarchy (existing codebase pattern →
framework primitive → DB/infra primitive → simple explicit → larger
architectural pattern). SIMPLIFY is now the explicit default verdict when
complexity is unjustified.

`audit-review-skeptic.md` and `audit-review-pragmatist.md` both gain a
Non-Negotiable Evidence Boundary (no auditor prose, no claimed-impact, no
external knowledge), a four-step analysis procedure with source/path/sink/
guard/behavior decomposition (worked SQLi example), explicit FALSE_POSITIVE
valid/invalid reasons, partial-proof citation patterns, Pipe-Safety rules
for Markdown-table escaping (`|` → `/` inside quoted tokens, ≤ 160 chars),
and an explicit HIGH/MEDIUM/LOW → `0.9`/`0.7`/`0.3` mapping so role-prompt
semantics agree with the float contract in
`scripts/council/prompts/audit-review.md`. Each role ends with a 10-13-item
internal self-check.

All four prompts are mirrored in Russian under
`templates/council-prompts/ru/`. Technical literals (`REAL` /
`FALSE_POSITIVE` / `NEEDS_MORE_CONTEXT` / `PROCEED` / `SIMPLIFY` /
`RETHINK` / `SKIP` / `VERDICT` / `HIGH` / `MEDIUM` / `LOW`) stay ASCII so
the orchestrator's regexes match unchanged.

### Bug fix — `_extract_concerns()` regex tolerance

`scripts/council/brain.py` `_extract_concerns()` previously matched only
`## Concerns` (H2). The new role prompts may nest a `### Concerns` (H3)
section under a required H2 — the old regex would drop those bullets,
emptying `concerns_skeptic` / `concerns_pragmatist` in the JSON output.
The regex is now `#{2,}\s*Concerns` with an `(?=\n#{1,6}\s|\Z)` look-ahead
so H2 / H3 / H4 headers are all extractable, while still stopping at the
next heading of any level.

### Domain persona overlays — Group A rewrite

All eight domain persona overlays under `templates/council-prompts/personas/`
(`security-{skeptic,pragmatist}`, `performance-{skeptic,pragmatist}`,
`ux-{skeptic,pragmatist}`, `migration-{skeptic,pragmatist}`) have been
refactored from short 25–35-line addenda into concentrated 105–125-line
domain patches. Each overlay was first generated through the three-stage
prompt-optimizer (PROMETHEUS → meta-optimization → synthesis) against a
hand-written context file that explicitly lists what the base prompt
already covers, then manually merged with the original's punchy framings
to keep memorable phrases ("Profile first, then plan", "Just add Redis is
not a plan", "An iframe is isolation, not absolution", "Forward-fix is
wishful thinking", "we'll a11y it later"). Pragmatist overlays explicitly
forbid replaying their Skeptic sibling's territory and add the
production-deployment / observability / ownership angles instead. Each
overlay now carries an HTML sidecar header matching the base prompts and
ends with a `Minimum Plan Answers` compact 3-4-question closing gate.
Group B (`cfo-pragmatist`, `marketer-pragmatist`, `product-skeptic`,
`user-empath`) is intentionally out of scope here — those belong to the
separate `/product-review` pipeline.

Overlays remain optional (composed only when the plan text matches the
relevant trigger regex in `brain.py`). When loaded they are prepended to
the base role system prompt with a literal `---` divider, so the base's
verdict taxonomy, evidence rules, confidence rules, and output discipline
remain authoritative — no overlay restates them. Russian-localized
overlays are intentionally deferred; `load_persona()` falls back to the
English file when a localized copy is missing.

### Files

- `templates/council-prompts/skeptic-system.md`
- `templates/council-prompts/pragmatist-system.md`
- `templates/council-prompts/audit-review-skeptic.md`
- `templates/council-prompts/audit-review-pragmatist.md`
- `templates/council-prompts/ru/skeptic-system.md`
- `templates/council-prompts/ru/pragmatist-system.md`
- `templates/council-prompts/ru/audit-review-skeptic.md`
- `templates/council-prompts/ru/audit-review-pragmatist.md`
- `templates/council-prompts/personas/security-skeptic.md`
- `templates/council-prompts/personas/security-pragmatist.md`
- `templates/council-prompts/personas/performance-skeptic.md`
- `templates/council-prompts/personas/performance-pragmatist.md`
- `templates/council-prompts/personas/ux-skeptic.md`
- `templates/council-prompts/personas/ux-pragmatist.md`
- `templates/council-prompts/personas/migration-skeptic.md`
- `templates/council-prompts/personas/migration-pragmatist.md`
- `scripts/council/brain.py` (`_extract_concerns()` regex)
- `manifest.json` (version bump)

### Operator note

Users who customized local copies under `~/.claude/council/prompts/` will
see `.upstream-new.md` sidecar files on the next toolkit update. Review and
merge manually — the role prompts grew substantially (~3x previous size)
and any local edits to the previous short version need re-application
against the new structure.

## [6.18.1] - 2026-05-11

### Documentation — Two-layer memory conflict protocol (PR #99)

Documents the two parallel Claude Code memory stores and a default precedence + conflict-resolution protocol.

**Background.** Real conflict observed in a downstream project: `.claude/rules/memory.md` still listed "R2-Only Architecture (2026-02-13)" as primary while harness auto-memory `MEMORY.md` had captured the Redis-via-SSH migration on 2026-03-23. Claude quoted the stale layer because no protocol said which wins. Toolkit's existing memory docs treated `.claude/rules/` as the gold standard but never named the harness auto-memory layer or how to handle disagreement.

**Two layers.** `.claude/rules/*.md` (git-tracked, user writes, auto-loaded via `globs:`) vs `~/.claude/projects/<encoded-cwd>/memory/MEMORY.md` (harness auto-memory, Claude writes autonomously, injected every turn). Not synchronized — they can drift independently.

**Default protocol.**

1. `.claude/rules/` wins (git-tracked, human-managed)
2. If auto-memory is demonstrably newer (later dated event, real merged PR) — update rules and commit; auto-memory will re-converge on next write
3. Never silently quote the older layer — disclose the conflict

**Surface area.**

- `components/memory-persistence.md` — new "Two Layers" section with full comparison table (location, git-tracked, who writes, who reads, origin, programmability, lifecycle) and 6-step protocol.
- `templates/{base,go,laravel,python,rails}/CLAUDE.md` — inline short-form protocol pointer under "Knowledge Persistence" so the rule loads into every session, not just when the component is opened.

6 files, +70 lines, doc-only patch. No behavior change in scripts.

## [6.18.0] - 2026-05-10

### Added — Phase C: `/diagnose-ci` slash command + `feature-flag-lifecycle` component

Two bounded artifacts triaged from INBOX 2026-05-06 (Phase C "Warp picks").

#### `/diagnose-ci` (commands/diagnose-ci.md)

A 7-step CI-failure diagnosis loop for the case where a PR's CI is red and you need a structured triage instead of a tab-bouncing free-for-all. The loop runs sequentially and stops at the cheapest layer that explains every failed job:

1. Fetch the failure surface (`gh run view --log-failed` + jobs JSON).
2. Classify the failure layer (Infrastructure / Cache / Pinned-action / Secret / Test / Build / Environment).
3. Isolate the offending change via `git log` + bisect, time-boxed to 15 minutes.
4. Reproduce locally (matching tool versions, `--runInBand`, `act` for OS-specific failures).
5. Diagnose environment dependency (filesystem case, line endings, locale, TZ, parallelism, ulimit).
6. Apply the minimal fix at the layer you stopped at — do NOT climb the stack.
7. Verify all jobs are green; capture a one-line lesson if the failure was non-obvious.

Output is a structured `Step 1..Step 7` report.

#### `feature-flag-lifecycle.md` (components/feature-flag-lifecycle.md)

A 5-stage lifecycle (Born → Ramped → Defaulted → Deleted → Forgotten) for feature flags as debt instruments. Each stage has explicit exit criteria, the most-skipped transition is called out (Stage 4 → Stage 5 — flag deleted from code but left in the flag service), and four anti-patterns are catalogued: flag-as-config, flag-as-dependency, flag-with-no-owner, flag-as-dark-launch-with-no-exit. Includes a per-flag operational checklist + decision tree + ramp-cohort sequence (Internal → Beta → 1% → 10% → 50% → 100%) with 24-72h gates between steps.

### Files

- `commands/diagnose-ci.md` — new slash command (~150 LOC).
- `components/feature-flag-lifecycle.md` — new component (~250 LOC, slightly over the ~150 budget because the 5-stage table + checklist + decision tree warranted the space).
- `manifest.json` — `files.commands[]` adds `diagnose-ci`; version bump 6.17.2 → 6.18.0.

## [6.17.2] - 2026-05-10

### Added — `huashu-design` skill catalog entry

Adds [`alchaincyf/huashu-design`](https://github.com/alchaincyf/huashu-design) (13K stars) to the skills selector catalog as a 24th entry. HTML-native design skill for high-fidelity prototypes, slides, animations, and MP4 / GIF export pipelines. Bilingual (Chinese / English) but the trigger description covers both languages, so the catalog selector matches it from prompts in either.

- `scripts/lib/skills.sh` — `SKILLS_CATALOG` array bumped 23 → 24, comments updated.
- `scripts/install.sh` / `scripts/sync-skills-mirror.sh` — count comments + error-message strings updated.
- `scripts/tests/test-install-skills.sh` — S1 + S6 assertions bumped to 24 (S6 dry-run row count, S1 array length, last-index alphabetical-final assertion).
- `templates/skills-marketplace/huashu-design/` — new mirror with `SKILL.md` (60K), `LICENSE`, `README.md`, `references/` (296K, 21 files), `scripts/` (128K, 12 files), `test-prompts.json`. Excludes upstream `assets/` (30M MP4/GIF demos) and `demos/` (672K) to keep the mirror under 1 MB.
- `manifest.json` — `files.skills_marketplace[]` adds `templates/skills-marketplace/huashu-design`. `impeccable` remains catalog-only (not mirrored), so manifest count = catalog count - 1 = 23.
- Docs: `docs/SKILLS-MIRROR.md`, `docs/INSTALL.md`, `docs/CLAUDE_DESKTOP.md` count strings updated.

### Validation

- Desktop-safety (DESK-02 / DESK-04) — passes: `huashu-design/SKILL.md` contains zero matches against the `(Read|Write|Bash|Grep|Edit|Task)\(|Use (the )?(Read|Write|Bash|Grep|Edit|Task) tool` heuristic.
- `make check` — all green.
- `bash scripts/tests/test-install-skills.sh` — 15 / 15 PASS.

## [6.17.1] - 2026-05-10

Phase 3 of the v6.15.x architecture pass (Council Decision 3, REVISED)
shipped in two stages: stage 1 added three canonical SOT components for
audit rubrics, stage 2 wired them into the splice pipeline and re-spliced
all 30 framework audit prompts behind a new `rubric-anchors` sentinel.
Closes wave-2 findings F-242 (severity rubric drift), F-204 / F-301 /
F-327 (UNCERTAINTY DISCIPLINE drift propagation), F-260 / F-324 / F-363
(FALSE-POSITIVE CONTROL gate gaps), and the propagation half of
KNOWN-DEBT-1 (framework prompts now carry the full v4.2 audit pipeline
in lockstep with base).

Originally tracked as v6.15.2 + v6.15.3 in stacked PRs #90 / #91 against
pre-v6.16.0 main; consolidated into v6.17.1 after v6.17.0 (PR #93)
shipped on 2026-05-10.

### Changed — Splice pipeline now propagates rubric-anchors sentinel into 30 audit prompts (Phase 3 stage 2)

Stage 2 of the v6.15.x architecture pass (council Decision 3, REVISED).
Stage 1 (v6.15.2) shipped the three Phase 3 SOT components
(`audit-severity-anchor`, `audit-uncertainty-discipline`,
`audit-fp-control-gates`) without modifying the splice pipeline. This
release wires them into `scripts/propagate-audit-pipeline-v42.sh` and
re-splices all 30 audit prompts so that every audit file carries a
sentinel-tagged citation pointing at the canonical SOT components.

### Splice pipeline change

The splice script grew from **4 sentinels** to **5 sentinels** per
file. The new sentinel is `<!-- v42-splice: rubric-anchors -->`. It is
emitted as a **citation block**, not a full inline body — the audit
reader sees a 6-line block pointing at the three Phase 3 components,
without duplicating their bodies into every prompt:

```text
<!-- v42-splice: rubric-anchors -->

**Audit rubric anchors** (canonical sources of truth — do not redefine inline):

- `components/audit-severity-anchor.md` — CRITICAL / HIGH / MEDIUM / LOW labels + Severity Ceiling Table.
- `components/audit-uncertainty-discipline.md` — UNCERTAINTY DISCIPLINE (lower confidence / severity, anti-padding).
- `components/audit-fp-control-gates.md` — three-gate FALSE-POSITIVE CONTROL wrapper (Adversarial → 6-step recheck → Calibration). Gate 2 procedure is `## SELF-CHECK` below.
```

Why citation, not inline body: inlining ~250 lines of canonical
content into each of 30 framework prompts would create a new ~7,500
line drift surface (the very problem Phase 3 was meant to solve).
A citation block places **one sentinel + one pointer** in every
framework prompt; reviewers who need the canonical content read the
component file. The pointer is enforced by CI (the new
`rubric-anchors` marker check in `validate-templates`) so frameworks
cannot drop the reference and silently regress.

The rubric block is inserted immediately before the SELF-CHECK
section (Gate 2 of the FP-control wrapper) so the audit reader sees
the canonical SOT pointers right next to the FP-recheck procedure
they gate.

### Wave-2 findings closed (mechanical halves)

Stage 1 closed the documentation halves; this release closes the
mechanical halves by ensuring the canonical pointers are present in
every audit prompt:

- **F-242** (severity rubric duplication / drift) — closed.
- **F-204, F-301, F-327** (UNCERTAINTY DISCIPLINE drift / SECURITY gap
  / DESIGN_REVIEW phrasing) — closed for the propagation half. Inline
  copies in base prompts remain (audit-specific calibration tables);
  framework prompts now point at the canonical SOT.
- **F-260, F-324, F-363** (FALSE-POSITIVE CONTROL gate gaps in
  CODE_REVIEW / DESIGN_REVIEW / PERFORMANCE_AUDIT) — closed for the
  propagation half. Same caveat as above.
- **KNOWN-DEBT-1** (framework prompt drift vs base) — partially
  closed. The 30 framework audit prompts now carry the v4.2 audit
  pipeline (callout + rubric-anchors + SELF-CHECK + OUTPUT FORMAT +
  Council Handoff) in lockstep with base. Per-section semantic drift
  outside the splice regions remains a separate audit (v6.16+).

### Migration

Files that were spliced under the v4.2 pipeline (4 sentinels) are
treated as **partial-splice** by the v6.15.3 script (4/5 sentinels).
The script's `--force` flag triggers strip + re-splice. CI-level
validation triggers automatically — any framework file missing the
`rubric-anchors` sentinel fails the `validate-templates` job.

For local checkouts, run:

```bash
bash scripts/propagate-audit-pipeline-v42.sh --force
```

This is a one-time migration; subsequent runs without `--force` will
report `30 already-spliced` once every file carries the new sentinel.

### Test contract update

- `scripts/tests/test-template-propagation.sh` — sentinel count check
  4 → 5; new `rubric-anchors` named-sentinel assertion; partial-splice
  detection updated from `3/4` → `4/5`.
- `.github/workflows/quality.yml` — `validate-templates` job grep'd for
  the new `rubric-anchors` sentinel in every audit prompt.

### Files

- `scripts/propagate-audit-pipeline-v42.sh` — splice pipeline extended
  with the new sentinel block + strip handler + sentinel-count gates
  updated 4 → 5.
- `scripts/tests/test-template-propagation.sh` — test fixture updates.
- `.github/workflows/quality.yml` — CI marker check extension.
- `templates/{base,go,laravel,python,rails}/prompts/{CODE_REVIEW,DESIGN_REVIEW,PERFORMANCE_AUDIT,MYSQL_PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,SECURITY_AUDIT}.md`
  — 30 files re-spliced, each gains the new `rubric-anchors` block
  (~6 lines added per file, ~180 lines total).

### Added — Three canonical SOT components for audit rubrics (Phase 3 stage 1)

Stage 1 of Phase 3: extract the drifting sections from
`templates/base/prompts/*.md` into single-source-of-truth components.
Stage 2 (described above in this release) wires them into the splice
pipeline.

The two stages were originally carved into separate releases
(v6.15.2 / v6.15.3) because the splice-script delta is ~150 LOC of bash
plus embedded Python with high regression surface; shipping the
components first gave the rubric a single-point-of-reference without
risking the propagation pipeline.

### New components

- **`components/audit-severity-anchor.md`** — canonical four-level
  severity rubric (CRITICAL / HIGH / MEDIUM / LOW), the Severity
  Ceiling Table (precondition → maximum severity), and an
  audit-specific calibration cheat-sheet that locks the four labels in
  place while letting each audit map its own inputs onto them.
  References `components/severity-levels.md` as the long-form rubric.
- **`components/audit-uncertainty-discipline.md`** — the canonical
  UNCERTAINTY DISCIPLINE block (currently duplicated verbatim across 5
  of 6 base audit prompts; missing entirely from SECURITY_AUDIT). Adds
  an explicit anti-padding ladder (lower confidence → lower severity →
  move to Non-Blocking → drop) and four concrete anti-patterns (weasel
  words, padding, hidden assumptions, confidence inflation).
- **`components/audit-fp-control-gates.md`** — the three-gate FALSE
  POSITIVE CONTROL outer wrapper (Adversarial self-review → 6-step FP
  recheck → Calibration). Currently lives only in SECURITY_AUDIT;
  CODE_REVIEW, DESIGN_REVIEW, and the three perf audits jump straight
  to Gate 2 (the 6-step recheck) without the adversarial / calibration
  framing. Pairs with `components/audit-fp-recheck.md` (the Gate 2
  procedure).

### Stage 1 files

- `components/audit-severity-anchor.md` — new (canonical severity SOT).
- `components/audit-uncertainty-discipline.md` — new (canonical UD SOT).
- `components/audit-fp-control-gates.md` — new (canonical FP-CONTROL SOT).
- `.planning/STATE.md` — Phase 3 stage 1 marked complete.

## [6.17.0] - 2026-05-10

Two Council-validated base-prompt reworks bundled into a single release:
DEPLOY_CHECKLIST is reclassified as a deployment runbook (audit machinery
stripped), and DESIGN_REVIEW Phase 7 is dissolved into CODE_REVIEW +
PERFORMANCE_AUDIT to eliminate cross-prompt overlap. Closes 20 wave-2
findings (17 from F-290..F-306, 3 from F-321/F-326/F-329).

Originally tracked as v6.15.0 + v6.15.1 in stacked PRs #88/#89 against
pre-v6.16.0 main; consolidated into v6.17.0 after v6.16.0 (MCP scope
picker, PR #92) shipped on 2026-05-10.

### Changed — DESIGN_REVIEW Phase 7 dissolved into CODE_REVIEW + PERFORMANCE_AUDIT

`templates/base/prompts/DESIGN_REVIEW.md` Phase 7 ("Code Health") was a
duplicate of audit categories owned by other prompts: component reuse,
design tokens, and magic-number hygiene belong in CODE_REVIEW; bundle
size, lazy loading, CLS, and animation performance belong in
PERFORMANCE_AUDIT. Carrying these in DESIGN_REVIEW caused the same
finding to surface in two reports with different severities and no
canonical owner — wave-2 findings F-321 (cross-prompt overlap) and
F-329 (severity mismatch).

This release dissolves Phase 7 into the prompts that already own each
concern:

- **DESIGN_REVIEW** is now a 6-phase review process (Preparation,
  Interaction Testing, Responsiveness, Visual Polish, Accessibility,
  Robustness). Heading "## 📋 7-Phase Review Process" → "## 📋 6-Phase
  Review Process". Phase 7 section deleted.
- **CODE_REVIEW** gains a new section "ARCHITECTURE AND CONSISTENCY"
  (after BUSINESS LOGIC VALIDATION, before LOW-VALUE REVIEW FILTER) with
  three concrete checks: component reuse, design tokens, magic numbers.
  Each check is gated by the existing LOW-VALUE REVIEW FILTER —
  reviewers must justify duplication >30 LOC for component-reuse
  findings, must show the project ships a token system before flagging
  hardcoded values, and must show the magic number carries semantic
  meaning before flagging it.
- **PERFORMANCE_AUDIT** gains a new section 3.6 "Animation Performance"
  covering the only Phase 7 bullet not already in section 3 of
  PERFORMANCE_AUDIT (`transform` / `opacity` GPU acceleration,
  layout-triggering properties, paint cost on long lists,
  `prefers-reduced-motion`). Bundle size (3.1), lazy loading (3.2 /
  3.3), Core Web Vitals + CLS (3.4) already covered the rest.

Closes wave-2 findings F-321, F-329, and partial F-326 (3 findings).

### Scope

- Base prompts only (`templates/base/prompts/{DESIGN_REVIEW,CODE_REVIEW,PERFORMANCE_AUDIT}.md`).
- Framework copies (`templates/{laravel,rails,python,go}/prompts/DESIGN_REVIEW.md`)
  still carry Phase 7. Drift remains tracked under KNOWN-DEBT-1 and is
  the target of v6.15.2 (Phase 3 — framework drift via components
  splice). Council Decision 2 explicitly scoped this release to base.

### Migration

No action required for users running `templates/base/prompts/*` — the
audit pipeline still emits 6 audit reports (DESIGN_REVIEW remains in
the audit-pipeline list, only its phase count shrank). Users who pinned
to "Phase 7 Code Health" findings in their own playbooks should
re-route: component / token / magic-number findings now appear under
CODE_REVIEW "ARCHITECTURE AND CONSISTENCY"; animation-performance
findings now appear under PERFORMANCE_AUDIT 3.6.

### Files

- `templates/base/prompts/DESIGN_REVIEW.md` — heading update + Phase 7 deletion (-24 lines).
- `templates/base/prompts/CODE_REVIEW.md` — new ARCHITECTURE AND CONSISTENCY section (+27 lines).
- `templates/base/prompts/PERFORMANCE_AUDIT.md` — new section 3.6 Animation Performance (+11 lines).

### Changed — DEPLOY_CHECKLIST is now a deployment runbook, not an audit prompt (BREAKING)

`templates/base/prompts/DEPLOY_CHECKLIST.md` was the only file in the
v4.2 audit-pipeline list that wasn't actually an audit prompt. It is a
**deployment checklist**: numbered phases (code cleanup → quality →
DB → environment → security → deployment → verification → rollback).
The v4.2 propagation injected SELF-CHECK 6-step FP recheck, OUTPUT
FORMAT structured-report schema, and Council Handoff into every
audit prompt — and DEPLOY_CHECKLIST got swept up in that.

Result before this change: a DevOps operator running this checklist
faced a 6-step false-positive recheck procedure on a checkbox-only
workflow. There were no candidate findings to evaluate. Sections 9-10
(lines 238-563) of the file were dead weight.

**Council validation (2026-05-10):** Both Skeptic and Pragmatist judges
returned verdict SIMPLIFY on the v6.15.x plan. Implemented their
revisions:

- **Skeptic addition** — also strip the QUICK CHECK table (audit-
  pattern artifact, not a deploy procedure). Done: removed the QUICK
  CHECK table and "If all 6 = OK → Ready to deploy!" line that
  conflicted with `CODE_REVIEW.md` "do not infer status from inspection".
- **Pragmatist addition** — update 4 infrastructure files, not just the
  splice script. Done: edits to `Makefile`, `.github/workflows/quality.yml`,
  `scripts/propagate-audit-pipeline-v42.sh`, and
  `scripts/tests/test-template-propagation.sh` so DEPLOY_CHECKLIST is no
  longer included in audit-prompt validation. The v4.2 splice pipeline
  no longer attempts to inject SELF-CHECK / OUTPUT FORMAT / Council
  Handoff into DEPLOY_CHECKLIST.
- **Pragmatist addition** — auth/crypto deploys need an explicit
  monitoring story. Done: new Phase 5.4 ("Auth / Crypto / Session
  changes") with mandatory items for threat-model update, auth-failure
  metrics armed, anomaly alerts armed, audit logs armed (SOC 2 §CC7 /
  GDPR Art. 33). Mandatory only when the deploy touches auth code paths;
  marked `n/a` with one-line justification for non-auth deploys.

### Closed — wave-2 findings F-290 .. F-306 (17 findings)

The DEPLOY_CHECKLIST rework closes the entire DEPLOY_CHECKLIST wave-2
finding cluster:

- **F-290** — fundamental category mismatch (audit machinery on a
  checklist prompt). Fixed by stripping audit machinery.
- **F-291** — checkbox-only QUICK CHECK assumed verification. Fixed by
  removing QUICK CHECK and replacing with Phase 0a Pre-Deploy Baseline
  (capture metrics with evidence) + per-phase atomicity statements.
- **F-292** — DEPLOY TYPES referenced section numbers, not stages.
  Fixed by mapping each deploy type (Hotfix / Minor / Feature / Major)
  to the specific phases that apply, and adding strategy-in-use field
  (single-machine / rolling / blue-green / canary).
- **F-293** — migration safety missing backward-compatibility check.
  Fixed by Phase 3.2 (forward-compatible window + backward-compatible
  window + dropped-column reference scan).
- **F-294** — driver hygiene without verification. Fixed by Phase 4.3
  connectivity-verified box + queue-depth pre-deploy <80% requirement.
- **F-295** — generic security checks missing threat model and CSRF /
  rate-limit / token-expiry. Fixed by Phase 5.4 (auth/crypto threat
  model link), Phase 5.5 (CSRF / rate-limit / token-expiry).
- **F-296** — pre/deploy/post stages without atomicity guarantees.
  Fixed by explicit "Atomicity" callout at Phase 6 head + per-step
  failure routing ("if step 5 fails: maintenance stays ON, route to
  Phase 8").
- **F-297** — no observability gate between deploy and post-deploy.
  Fixed by Phase 7.4 Post-Deploy Comparison vs Phase 0a Baseline
  (error rate, p95, GC, DB pool, queue depth, auth-failure rate).
- **F-298** — manual smoke tests. Fixed by Phase 7.1 (automated, not
  manual) + Phase 7.2 (regression suite re-run) + Phase 7.3 (load /
  traffic-shape validation conditional).
- **F-299** — vague rollback triggers. Fixed by Phase 8.2 trigger table
  with specific signals, thresholds, time windows, and named decider per
  trigger.
- **F-300** — PROJECT SPECIFICS without validation. Fixed by Phase 0.1
  strategy-in-use checklist + cross-references to the rest of the
  checklist for downstream validation.
- **F-301** — UNCERTAINTY DISCIPLINE inappropriate in checklist
  context. Fixed by removing the section entirely.
- **F-302** — Section "## 9. SELF-CHECK" looked like a continuation of
  the numbered checklist. Fixed by removing sections 9-10.
- **F-304** — Hotfix path skipped phases 2-5 unconditionally. Fixed by
  Phase 5 conditional rule: hotfix MUST cover Phase 5 if patch touches
  auth/session/token/crypto code paths.
- **F-305** — reactive-only monitoring. Fixed by Phase 0a Pre-Deploy
  Baseline (proactive baseline capture before deploy starts).
- **F-306** — "Ready to deploy" conclusion premature. Fixed by removing
  the conclusion entirely; deploys proceed phase-by-phase, not
  QUICK-CHECK-pass.

F-303 (placeholder name consistency) is cosmetic only — defer.

### Migration impact for users

Projects with `.claude/prompts/DEPLOY_CHECKLIST.md` synced to v6.14.x
will see the file rewritten on next `update-claude.sh` run. Existing
local edits to the audit-pipeline sections (SELF-CHECK / OUTPUT FORMAT)
will be discarded — those sections are gone. Existing edits to the
phase content (1-8) are preserved if they match the new section
headers; otherwise the smart-update script will surface them in the
backup directory.

The 28 framework prompt variants in `templates/{laravel,rails,python,go}/prompts/DEPLOY_CHECKLIST.md`
still carry the old audit-machinery content (KNOWN-DEBT-1 framework
drift). They will be updated in v6.15.2 when the framework drift sweep
ships.

## [6.16.0] - 2026-05-10

### Added — MCP scope per-row picker (lock-screen after sub-picker)

The integrations sub-picker now hands off to a dedicated **scope lock-screen**
where the user can adjust per-MCP scope (`user` / `project` / `local`) before
the dispatcher fires. The Phase 39 Tab/`s` scope wiring at
`scripts/install.sh:518-530` was previously dead code in the sub-picker →
main-TUI flow because the headless `TK_MCP_PRE_SELECTED` branch swallowed
the entire main TUI render.

- New: `mcp_detect_installed_scope <name>` helper in `scripts/lib/mcp.sh`.
  Parses three JSON sources (`~/.claude.json` mcpServers + `<project>/.mcp.json`
  mcpServers + `~/.claude.json` projects[<root>].mcpServers) and returns
  `user`/`project`/`local`/empty. Resolution mirrors Claude Code's own
  precedence: `local > project > user`. Cached on first call.
- New: `TK_TUI_LOCK_SELECTION=1` mode for `tui_checklist`. Pre-fills every
  row, makes Space a no-op, and replaces `Space toggle` in the footer with
  `selection locked`. Tab + `s` + Enter remain active.
- New: `_run_mcp_scope_lock_screen` in `scripts/install.sh`. Builds shadow
  TUI arrays filtered to `TK_MCP_PRE_SELECTED` rows, runs `tui_checklist`
  with the lock mode + Tab/`s` wiring, and maps the resulting per-row
  scopes back into the full-size `MCP_SELECTED_SCOPE[]` for the dispatcher.
- New: `mcp_cycle_row_scope_locked` wrapper. Tab is silent no-op on
  installed rows (re-scope of installed MCPs would require destructive
  `claude mcp remove + add` with re-OAuth/secret prompt — deferred).
- Sub-picker now shows `(installed: U/P/L)` for already-registered MCPs
  and `(default: U/P/L)` for new ones in `TUI_DESCS` only — `TUI_LABELS`
  stays raw `MCP_NAMES` to preserve the CSV-match contract with the main
  TUI / lock-screen.

Skip conditions (any → lock-screen does not render):

- `--mcp-scope user|project|local` flag (set-all v4.9 contract)
- `--yes` flag (non-interactive)
- No readable TTY (CI / piped install)

### Changed — Catalog default_scope adjustments

- `comet-bridge`: `project` → `user`. Single Comet profile per user; no
  blast radius. Also removes redundant `--scope project` from
  `install_args[]` which collided with the runtime `--scope` flag the
  installer prepends since Phase 37.
- `datadog`: `user` → `project`. Prod APM/logs/incidents with ack/mute
  capability has real blast radius; default to project so a Claude
  session in a side-project cannot mutate prod alerts.
- `posthog`: `user` → `project`. Personal API key reads every PostHog
  project in the org; isolate per repo so multi-product orgs don't leak
  events between products.

Migration: existing installs of `datadog` / `posthog` at user-scope keep
working. Re-add with `--scope project` to adopt the new default.

### Removed — Back navigation (`b`/`B`) from all TUI screens

The Phase 36-A 2026-05-02 Back-navigation feature is reverted per user
request 2026-05-10. The flow is now linear:
`main TUI → skills sub-picker → MCP sub-picker → MCP scope lock-screen →
dispatch`. Cancel via Ctrl+C / q in any sub-picker aborts the install.

- `b|B)` case arm in `tui_checklist` removed.
- `TK_TUI_ALLOW_BACK` env var no longer read anywhere; setting it has
  no effect (regression test confirms silent ignore).
- Footer no longer shows the `· b back` segment.
- Outer `_redo_main_tui` loop and inner `_pc_step` state machine in
  `scripts/install.sh:1800-2118` removed (~150 LOC). Replaced by linear
  `skills → mcp` sequence; sub-picker rc=1 → exit 0 with localized
  "X selection cancelled — aborting install." message.
- `_save_main_tui_state` / `_restore_main_tui_state` helpers retained
  (still needed for sub-picker array swap; not Back-related).

### Tests added

- `scripts/tests/test-catalog-default-scope.sh` — 5 assertions on the
  three `default_scope` flips + comet-bridge `install_args[]` cleanup +
  schema validator.
- `scripts/tests/test-mcp-detect-installed-scope.sh` — 8 unit tests
  covering each scope, both precedence rules, unknown name, missing
  files, malformed JSON.
- `scripts/tests/test-tui-lock-selection.sh` — 6 assertions on footer
  copy, pre-fill behavior, Space-no-op (lock + regression).
- `scripts/tests/test-tui-no-back.sh` — 5 assertions confirming Back
  removal at footer + source level + env-var read-site.
- `scripts/tests/test-install-scope-picker-flow.sh` — 3 integration
  assertions on lock-screen bypass paths (`--yes`, `--mcp-scope`).

### Phase artifacts

- `.planning/phases/16.0-install-mcp-scope-picker/16.0-CONTEXT.md`
- `.planning/phases/16.0-install-mcp-scope-picker/16.0-PLAN.md`

## [6.14.3] - 2026-05-10

### Fixed — wave-2 calibration findings (7 of remaining ~117)

Continuing wave-2 close-out after v6.14.1 / v6.14.2 (PRs #84 and #86).
This batch ships SECURITY_AUDIT calibration plus MYSQL/POSTGRES
operational nuance. Full wave-2 list at
`.planning/research/meta-audit-wave2-2026-05-10.md`.

#### F-242 — SECURITY severity ceiling table

`templates/base/prompts/SECURITY_AUDIT.md` `## EXPLOIT PRECONDITIONS`
gave one example ("tenant-admin + race window + specific DB state is
HIGH at most") but no rule mapping precondition combinations to maximum
severity. Auditors had to infer the ceiling each time, leading to
inconsistent severity scoring across reports. Added an explicit
**Severity Ceiling Table** mapping `(attacker class, required
interaction)` to a maximum severity:

- Unauthenticated + no interaction → CRITICAL
- Unauthenticated + click → HIGH
- Authenticated user (any tenant) + no interaction → HIGH
- Tenant-admin + no interaction → MEDIUM
- Org/instance-admin → LOW (admin can already cause harm)
- Compromised external service → HIGH

Cross-multiplies with `## DATA CLASSIFICATION` for the final severity.
Auditors take the strongest precondition the attacker actually needs to
satisfy, never an aggregate.

#### F-243 — REALISTIC EXPLOITABILITY FILTER execution phase

`## REALISTIC EXPLOITABILITY FILTER` listed "do NOT report" / "DO
prioritize" rules but never named the SELF-CHECK step at which the
filter applies. Added an explicit prelude: filter applies during
SELF-CHECK Steps 2-3 (data-flow trace + execution-context check); a
match drops the finding at Step 3 with `dropped_at_step: 3` and a
specific exclusion reason.

#### F-358 — MYSQL performance_schema reset caveats

The audit prompt instructed "uptime > 7 days" before trusting
`events_statements_summary_by_digest` rows but missed two adjacent
reset paths: (1) `TRUNCATE TABLE performance_schema.<table>`
(operator may have recycled stats), (2)
`performance_schema_max_digest_length` truncation merging long queries
into one digest. Added a callout naming both paths plus the diagnostic
("if `COUNT_STAR` for known frequent queries is suspiciously low, the
digest table has been recycled — defer the audit").

#### F-360 — MYSQL scan_ratio scoped to SELECT

`scan_ratio = ROWS_EXAMINED / ROWS_SENT` is undefined for DML
(INSERT/UPDATE/DELETE) — those statements send 0 rows back, so the
NULLIF guard prevents a divide-by-zero but the resulting ratio is
meaningless. The audit checklist `No queries with scan_ratio > 1000`
treated the metric as universal. Added a paragraph naming the
SELECT-only scope and pointing DML evaluators to
`SUM_ROWS_AFFECTED / COUNT_STAR` (per-call write rate) plus
`AVG_TIMER_WAIT` (per-call wall clock) instead.

#### F-361 — MYSQL audit user permissions

`### Check User Permissions` previously suggested falling back to
`debian-sys-maint` (which holds DROP/ALTER/SUPER) if performance_schema
was unavailable. A typo at a `mysql>` prompt running as that user can
drop a production table. Replaced with a dedicated `audit_ro` user
recipe (`SELECT, PROCESS, SHOW VIEW`) plus credential storage via
`mysql_config_editor --login-path=audit_ro`. Kept the `debian-sys-maint`
fallback as last resort but instructed wrapping the session in
`BEGIN; ... ROLLBACK;` so accidental writes are undone.

#### F-398 — POSTGRES non-immutable defaults trigger table rewrite

`### 11.2 Checklist` claimed `NOT NULL` columns added with `DEFAULT`
are "instant in PG 11+". True only when the default is an immutable
expression. Volatile defaults (`DEFAULT now()`, `DEFAULT random()`,
`DEFAULT gen_random_uuid()`) still trigger a full table rewrite under
`ACCESS EXCLUSIVE` lock — operators copying the rule and using
`now()` find their migration locks the table for minutes. Updated the
checklist line to name the immutable-only constraint and prescribe the
two-step pattern (add nullable column → backfill in batches → set
default + NOT NULL) for volatile defaults.

### False positives dropped

- **F-388** — claimed `WHERE dbid = (SELECT oid FROM pg_database WHERE
  datname = current_database())` may break on RDS or with permission
  errors. `pg_database` is readable by all users on every Postgres
  deployment including RDS / Cloud SQL / Azure Database — this is a
  baseline catalog table. Already correct.
- **F-389** — claimed missing multi-schema filtering on
  `pg_stat_statements`. The view aggregates **per database**, not per
  schema; statements can target any schema within the database. Adding
  a schema filter at the `pg_stat_statements` layer is meaningless.
- **F-403** — Postgres audit lacks an "Automation" section. Asymmetric
  with MYSQL audit (which has one), but adding a Postgres automation
  section is a feature add, not a bug. Defer to v6.15.x.

## [6.14.2] - 2026-05-10

### Fixed — wave-2 calibration findings (8 of remaining 135)

Continuing the meta-audit wave-2 close-out (full list at
`.planning/research/meta-audit-wave2-2026-05-10.md`). v6.14.2 ships
calibration / threshold / version-guard fixes — adjacent to the v6.14.1
surgical bug fixes (PR #84) but disjoint from those edits.

#### F-221 — CODE_REVIEW INFO phrasing parity

`templates/base/prompts/CODE_REVIEW.md` `## SEVERITY AND CONFIDENCE`
section said "INFO is non-reportable", but `SECURITY_AUDIT.md` (line
768) uses the byte-exact phrasing "INFO is NOT a reportable finding
severity; informational observations belong in the audit's scratchpad,
never in `## Findings`". Aligned CODE_REVIEW to the same phrasing so
both prompts speak with one voice.

#### F-261 / F-263 / F-265 — PERFORMANCE_AUDIT threshold definitions

`templates/base/prompts/PERFORMANCE_AUDIT.md` `## 0.2 SEVERITY
THRESHOLDS` table previously used `p95` and `end-to-end` without
defining either, and excluded cold-start latency without naming the
exclusion. Auditors were left to guess whether the threshold meant
synthetic benchmark p95 (which can be 10× lower than production p95) or
real production traffic. Added a "calibration footnotes" block:

- `p95` = trailing 5-minute production-traffic window, outliers > 3σ
  excluded; synthetic data must be flagged in evidence.
- `end-to-end` = full lifecycle (ingress → handler → DB → cache →
  external HTTP → render → egress).
- Thresholds assume single-tenant baseline; multi-tenant adds 20-50%
  overhead per concurrent tenant.
- Cold-start excluded; report only when cold-start exceeds a
  documented project baseline.

#### F-380 — POSTGRES `idle_in_transaction_session_timeout` scope

`templates/base/prompts/POSTGRES_PERFORMANCE_AUDIT.md` line 110
prescribed `idle_in_transaction_session_timeout` as a "safety net"
without naming the trade-off: that setting only kills connections idle
*inside* a transaction, not active long-running queries. Operators set
it expecting it to kill any long-running statement and were surprised.
Added a callout naming the gap: combine with `statement_timeout` (caps
query wall-clock) for full coverage.

#### F-385 — POSTGRES cache hit ratio workload calibration

The shared-buffers cache-hit-ratio table treated `< 95%` as universally
"poor", but OLAP / analytics workloads legitimately scan cold tables
and run at 70-90% — raising `shared_buffers` for an OLAP workload can
hurt by evicting hot OLTP pages on a shared instance. Added
workload-calibration block: OLTP > 99%, mixed 95-99%, OLAP 70-90%
expected. Also added macOS `kern.sysv.shmmax` note (large
`shared_buffers` may exceed kernel `shmmax` and the server refuses to
start).

#### F-396 — POSTGRES REINDEX CONCURRENTLY version guard

`REINDEX INDEX CONCURRENTLY` requires PostgreSQL 12+. The audit prompt
recommended it without a version guard; on 9.x-11.x users would copy
the SQL, hit "syntax error" or (worse) the non-concurrent variant which
takes an `ACCESS EXCLUSIVE` lock. Added explicit version guard and
named `pg_repack` as the online alternative for older releases.

#### F-352 / F-365 — MYSQL redo log workload context + 60s delta script

The MYSQL redo-log section gave "1 hour of writes" as a universal rule
and instructed "measure delta over 60 seconds" without supplying a
script. Two fixes in one edit: (1) added a working bash one-liner that
samples `Innodb_os_log_written` twice with a 60s gap and prints MB/s,
(2) replaced "1 hour" with workload-tier guidance — steady OLTP 1h,
bursty OLTP size-for-peak, write-mostly 4-8h, OLAP 30min — and named
the failure mode ("furious flushing" causing write-p95 spikes during
peak hours).

#### F-367 — MYSQL IO latency thresholds calibrated by storage class

The IO-latency table called `< 5ms = Excellent (SSD)`, but modern
NVMe achieves 0.1-0.5ms. Cloud SSD (gp3, Premium SSD, pd-ssd) typically
0.5-2ms. Network-attached EBS commonly 5-15ms even when "healthy". A
single 5ms threshold conflated three distinct storage classes; auditors
running against NVMe failed to flag obvious regressions, while auditors
running against EBS-baseline flagged everything as "Warning". Replaced
the single-tier table with five tiers (NVMe < 0.5ms / cloud SSD 0.5-5ms
/ network-attached 5-10ms / problematic 10-20ms / disk bottleneck >
20ms) and instructed operators to record their storage class in
`## PROJECT SPECIFICS` so future audits compare against the right
baseline.

### False positives dropped

- **F-200 / F-201** — Claimed CODE_REVIEW should embed an inline
  severity rubric to match SECURITY_AUDIT. SECURITY_AUDIT does NOT
  embed an inline severity rubric — its `## SCOPE & APPROACH` table
  uses HIGH/MEDIUM/LOW for *risk-level triggers* (a different concept
  from finding severity). v6.14.0 F-101 deliberately consolidated the
  severity rubric to `components/severity-levels.md` SOT only. Both
  prompts already comply.
- **F-368** — Claimed top-heavy-queries query ranks by
  `SUM_ROWS_EXAMINED` (accumulating across calls). It actually ranks
  `ORDER BY SUM_TIMER_WAIT DESC` and outputs `scan_ratio = ROWS_EXAMINED
  / ROWS_SENT` (per-call normalized). Already correct.
- **F-272** — Claimed PERFORMANCE_AUDIT step 2 wording "Follow user
  input" should be replaced. Step 2 is in the v42 splice block
  (`components/audit-fp-recheck.md`); editing it would propagate to
  SECURITY_AUDIT where "user input" is the correct framing.
  Per-prompt wording overrides are a v6.15.x splice-mechanism feature.

## [6.14.1] - 2026-05-10

### Fixed — wave-2 surgical findings (4 of 139)

Re-ran the 7-prompt adversarial meta-audit (originals from PR #82 were
unrecoverable after compaction). Re-discovered 139 findings; this patch
ships the small surgical subset. Larger items (DEPLOY rework, DESIGN
identity split, FALSE-POSITIVE CONTROL parity, severity calibration) are
sequenced for v6.14.2 onwards. Full re-audit findings list lives at
`.planning/research/meta-audit-wave2-2026-05-10.md`.

#### F-357 — PgBouncer reference inside MYSQL_PERFORMANCE_AUDIT

`templates/base/prompts/MYSQL_PERFORMANCE_AUDIT.md` `### Next.js + Prisma`
mentioned "Connection pooling via PgBouncer for PostgreSQL" inside a
MySQL-specific audit prompt. PgBouncer is a PostgreSQL-only proxy.
Replaced with "Connection pooling: use ProxySQL or MaxScale (PgBouncer is
PostgreSQL-only)" so MySQL-targeted readers do not chase a wrong-stack
suggestion. The PgBouncer-with-Prisma config example still appears in
`POSTGRES_PERFORMANCE_AUDIT.md` (correct context).

#### F-381 — DATABASE_URL inline credentials in POSTGRES audit example

`templates/base/prompts/POSTGRES_PERFORMANCE_AUDIT.md` `### Next.js +
Prisma` example showed `DATABASE_URL="postgresql://user:pass@..."` with
no security note. Inline-credential URLs leak via `/proc/<pid>/environ`,
`ps`, log files, container env, K8s Secret YAML, and git diff history.
Added a security comment block instructing readers to source the URL
from `.pgpass` (chmod 600), runtime env vars, or cloud IAM (RDS IAM
auth, Cloud SQL Auth Proxy, Azure AD) — same threat model as v6.14.0
F-111 (MYSQL_PWD).

#### F-320 — DESIGN_REVIEW missing `## GOAL` section

`templates/base/prompts/DESIGN_REVIEW.md` opened directly with
`## 🎯 Scope`, breaking parity with the other 6 base prompts (CODE_REVIEW,
SECURITY_AUDIT, PERFORMANCE_AUDIT, DEPLOY_CHECKLIST, MYSQL/POSTGRES
PERFORMANCE_AUDIT all open with `## GOAL`). Added a `## GOAL` section
that names the audit identity (UI/UX-focused: layout, typography,
spacing, contrast, motion, focus, error/empty/loading states,
responsiveness, keyboard/screen-reader semantics) and explicitly excludes
software-architecture concerns (component reuse, bundle size,
lazy-loading) — these belong to `CODE_REVIEW.md` and
`PERFORMANCE_AUDIT.md`. Surfaces the v6.14.2+ DESIGN identity-split work
without yet shipping it.

#### F-232 — Red-flag list contradicting SELF-CHECK Step 3 on `eval`

`templates/base/prompts/SECURITY_AUDIT.md` PHASE 0 red-flag list called
"new `eval` / `exec` / `unserialize` / dynamic dispatch" an absolute
escalation, but SELF-CHECK Step 3 (line 655) lists `eval inside a
build-time codegen script` as platform-required and droppable. Real
contradiction — readers either over-report (per the red flag) or
under-report (per the recheck). Added "**on a user-influenced code
path** (build-time codegen, test fixtures, and platform-constraint
contexts are evaluated under SELF-CHECK Step 3 before reporting)" as a
qualifier on the red flag, so the two sections compose without
contradiction.

### False positives dropped

Three wave-2 findings did not survive verification:

- **F-359** — Claimed `AVG_TIMER_WAIT > 1000000000000` is a nanosecond/
  millisecond unit error. MySQL `performance_schema` timer values are
  picoseconds by default (per official docs); 1e12 picoseconds = 1
  second, matching the `Slow queries (>1s)` label. Drop.
- **F-369** — Claimed an entire PostgreSQL config block (shared_buffers,
  work_mem, random_page_cost) is embedded in `MYSQL_PERFORMANCE_AUDIT.md`
  lines 450-501. `grep -n 'shared_buffers\|work_mem\|random_page_cost'`
  in that file returns zero matches. Drop (agent hallucination).
- **F-353** — Claimed fragmentation calc `DATA_FREE / NULLIF(DATA_LENGTH,
  0) * 100` produces NULL on empty tables. The same query carries
  `WHERE DATA_FREE > 50 * 1024 * 1024` which excludes the degenerate
  case before the divide. Drop.

### Known carry-over

- v6.14.1 fixes land only in `templates/base/`. The v42 splice pipeline
  propagates only the four splice blocks (callout, fp-recheck,
  output-format, council-handoff), not surrounding body content. The 28
  framework prompts in `templates/{laravel,rails,python,go}/prompts/*.md`
  still carry pre-v6.14.x bodies (KNOWN-DEBT-1). Scoping doc:
  `docs/research/framework-prompt-drift-2026-05-10.md`. Sequenced for
  v6.15.x after `/council` validation of regen-vs-sentinel-sync choice.

## [6.14.0] - 2026-05-10

### Fixed — F-111: MYSQL_PWD security bug in MYSQL_PERFORMANCE_AUDIT example

`templates/base/prompts/MYSQL_PERFORMANCE_AUDIT.md` shipped a bash example
that exported `MYSQL_PWD` after extracting it from `/etc/mysql/debian.cnf`.
This violated the toolkit's own Global Security Rule §1 (never log/leak
passwords) — `MYSQL_PWD` leaks to any process running as the same user via
`/proc/<pid>/environ`. Replaced with `mysql --login-path=health_check`
pattern (credentials stored once via `mysql_config_editor set`, file is
obfuscated and chmod 600).

### Changed — F-104: SECURITY_AUDIT collapses 3 false-positive gates into one

`templates/base/prompts/SECURITY_AUDIT.md` previously had three separate
sections (`QUALITY OVER QUANTITY`, `UNCERTAINTY DISCIPLINE`,
`ADVERSARIAL SELF-REVIEW`) that all restated "drop weak findings" without
defining an execution order between them and the propagated 6-step
SELF-CHECK. Merged into a single `## FALSE-POSITIVE CONTROL` section
that declares the canonical 3-gate order:

```text
1. Adversarial self-review  → intent check
2. 6-step FP recheck        → procedure check
3. Calibration              → severity + confidence sanity, anti-padding
```

Each former section is now a numbered subsection (Gate 1 / Gate 2 / Gate
3) under the new parent. The 6-step SELF-CHECK procedure (propagated from
`components/audit-fp-recheck.md`) is unchanged and remains the canonical
implementation of Gate 2. Net token reduction in SECURITY_AUDIT: ~50
lines once duplicate intent statements are collapsed.

### Changed — F-101: audit-output-format.md schema disambiguation

`components/audit-output-format.md` (the SOT spliced into all 35 framework
prompts) clarified three points the meta-audit flagged as ambiguous:

- **Bullet-label vs section-block fields.** The 11 fields are now
  explicitly split: fields 1–7 render as `**Label:**` bullets under the
  H3, fields 8–11 render as paragraph-heading section blocks. The "11
  fields" claim is no longer aspirational — both presentation styles are
  named.
- **Confidence vs Severity HIGH/MEDIUM/LOW collision.** Both fields share
  the tokens HIGH/MEDIUM/LOW. Added explicit guidance that the bullet
  label disambiguates ("never write a bare HIGH without its
  `**Severity:**` or `**Confidence:**` label") so Phase 15's Council
  parser cannot misroute a token.
- **Field-omission key.** Omission rules were silent on whether they
  keyed off Severity or Confidence. Now states: omission key is
  **Severity**. A LOW-severity finding with HIGH confidence may collapse;
  a HIGH-severity finding with LOW confidence MUST keep all 11 fields
  (LOW confidence requires the uncertainty in `Why it is real`).

Re-spliced all 35 framework prompts via `--force`.

### Changed — F-107: cross-prompt heading numbering parity

Stripped numeric prefixes (`## 0.`, `## 1.`, `## 2.`, …, `## 13.`) from
the canonical audit headings (`QUICK CHECK`, `SELF-CHECK`,
`OUTPUT FORMAT`) across all 7 base prompts. Other H2s in the same files
have always been unnumbered; the prefix was an artefact of incremental
template merges and broke Phase 15 navigation parity. The propagation
script (`scripts/propagate-audit-pipeline-v42.sh`) already supported both
styles via `^## ([0-9]+\.\s*)?<heading>` regex — no script change
required.

Also dropped the duplicated `> **Recommended model:** Claude Opus 4.5
(claude-opus-4-5-20251101)` line from `DEPLOY_CHECKLIST.md` and
`PERFORMANCE_AUDIT.md`. The other 5 base prompts never had it; model
selection is a Claude Code-level concern, not a per-prompt one.

### Meta-audit context

This release is the v6.14.0 first wave from a 7-prompt adversarial
meta-audit (one parallel reviewer per base prompt, ~150 findings total)
that ran 2026-05-10. F-101 / F-104 / F-107 / F-111 are the surgical,
low-risk findings shipped in this PR. Substantive items (per-audit
severity rubrics, per-audit SELF-CHECK variants, DEPLOY rework, DESIGN
identity split, coverage extensions, framework-prompt drift sweep) are
sequenced for v6.14.1+ and v6.15.x.

## [6.13.0] - 2026-05-09

### Fixed — F-006 propagator demote H2→H3

`scripts/propagate-audit-pipeline-v42.sh` now demotes every heading in
the SOT body (`components/audit-fp-recheck.md` and
`components/audit-output-format.md`) one level on inject. Previously the
SOT body H2 (`## Procedure`, `## Skipped (FP recheck) Entry Format`,
`## Report Path`, `## Full Report Skeleton`) collided with the outer
wrapper H2 (`## <N>. SELF-CHECK …` / `## <N>. OUTPUT FORMAT …`),
breaking the visual hierarchy in spliced files. Demote walks plain
markdown only — H2 lines inside code fences (illustrative example
output) are preserved verbatim.

Re-spliced all 35 framework prompt files via `--force`. Strip logic
unchanged (uses `parent_h2()` walk-back from sentinel, which still
correctly lands on the outer wrapper after demote).

### Fixed — meta-audit on remaining 5 base prompts

Continued the v6.12.1 self-audit pattern across `PERFORMANCE_AUDIT`,
`MYSQL_PERFORMANCE_AUDIT`, `POSTGRES_PERFORMANCE_AUDIT`,
`DEPLOY_CHECKLIST`, `DESIGN_REVIEW`. Findings:

- **F-001 (PERFORMANCE_AUDIT)** — `## 0.2 SEVERITY LEVELS` redefined
  the rubric with latency thresholds. Renamed to
  `## 0.2 SEVERITY THRESHOLDS (Performance-Specific Calibration)`,
  added explicit reference to `components/severity-levels.md` as the
  rubric SOT, kept latency thresholds as domain calibration (CRITICAL
  at > 5s end-to-end, HIGH at > 2s p95, MEDIUM at > 1s p95, LOW at
  < 1s).
- **F-001 (DESIGN_REVIEW)** — `## Issue Triage Matrix` used
  non-standard labels (`Blocker`, `High`, `Medium`, `Nitpick`) with
  emoji prefixes, redefining the rubric. Renamed to
  `## Issue Triage Matrix (Design-Specific Labels)`, added explicit
  SOT mapping (`Blocker → CRITICAL`, `High → HIGH`,
  `Medium → MEDIUM`, `Nitpick → LOW`) and a `SOT severity` column to
  the table for unambiguous report serialization.
- **F-004 (5 prompts)** — `## UNCERTAINTY DISCIPLINE` was absent from
  `PERFORMANCE_AUDIT`, `MYSQL_PERFORMANCE_AUDIT`,
  `POSTGRES_PERFORMANCE_AUDIT`, `DEPLOY_CHECKLIST`, `DESIGN_REVIEW`.
  All 5 now carry the section before SELF-CHECK, with the same body
  used in `CODE_REVIEW.md` (audit-agnostic — "evidence",
  "Non-Blocking Observations", "weasel words").

### Known limitation — framework prompt drift

`templates/{laravel,rails,python,go}/prompts/*.md` (28 files) carry
substantially older content than `templates/base/prompts/*.md`. The
v42 splice pipeline propagates only the four splice blocks (callout,
fp-recheck, output-format, council-handoff), not the surrounding body.
Today's base-prompt fixes (PERFORMANCE F-001, DESIGN F-001,
UNCERTAINTY DISCIPLINE x5) are present in `templates/base/` only;
framework prompts will inherit them when they're regenerated.
Tracking work for v6.14: either (a) regenerate framework prompts
from base + framework-specific delta, or (b) extend the splice
pipeline to a true sentinel-based base→framework section sync.

### Carry-over from v6.12.1

`F-007` / `F-008` / `F-010` were marked "cosmetic — deferred" in the
v6.12.1 CHANGELOG, but the original conversation that produced those
finding IDs was compacted before the specifics were saved. They are
unrecoverable; future audit passes should rediscover and assign new
IDs. `F-003` (Category enum wider than effective audit-type scope)
remains deferred.

## [6.12.1] - 2026-05-09

### Fixed — meta-audit cleanup of audit prompts

Self-audit of v6.11.0 (CODE_REVIEW) and v6.12.0 (SECURITY_AUDIT) flagged
five clarity/consistency issues. None were CI-breaking; all are
clarity / specificity fixes.

- **F-001** — `templates/base/prompts/CODE_REVIEW.md` `## SEVERITY AND
  CONFIDENCE` body redefined the severity rubric, contradicting the
  splice tail's instruction `The rubric is in components/severity-levels.md
  — do not redefine`. Body now references `components/severity-levels.md`
  as the source of truth and only defines Confidence (which the SOT
  doesn't cover).
- **F-004** — Renamed `## UNCERTAINTY HANDLING` → `## UNCERTAINTY
  DISCIPLINE` in `CODE_REVIEW.md` for naming parity with
  `SECURITY_AUDIT.md`. Same concept, single name. Added "weasel words"
  prohibition (lifted from SECURITY_AUDIT) so both prompts now share the
  same uncertainty rules.
- **F-005** — Restored React, Vue, Angular, Svelte raw-HTML API names
  with full specificity in `templates/base/prompts/SECURITY_AUDIT.md`.
  Previous v6.12.0 wording ("framework-specific raw-HTML escapes") was
  vague — a side effect of the `security_reminder_hook` blocking those
  literal API strings during the initial Write. Edits via the Edit tool
  bypass that hook trigger, so the original API names are now visible
  across QUICK CHECK, Injection Sinks, and FRAMEWORK GUARANTEES sections.
- **F-009** — `X-XSS-Protection` was mentioned twice in
  `SECURITY_AUDIT.md` (once as "absent from QUICK CHECK list", once in
  Transport / Headers section). Consolidated: kept the explicit
  Transport / Headers entry as authoritative; QUICK CHECK absent-list
  now references that section instead of duplicating the rationale.
- **F-002 (mitigation)** — `components/audit-output-format.md` Full
  Report Skeleton uses a SECURITY-flavored example (SQL injection) but
  ships unchanged into all 7 audit prompts. Added an explicit disclaimer
  before the skeleton: "for other audit types substitute the appropriate
  `audit_type`, H1 title, finding `Category`, and `Rule` namespace. The
  schema (field order, byte-exact bullet labels, section order, Council
  slot string) is identical across all 7 audit types." Re-spliced into
  all 35 framework prompt files.

### Deferred

`F-003` (Category enum wider than effective audit-type scope), `F-006`
(`## Procedure` H2-vs-H3 collision under `## SELF-CHECK` outer heading
in splice output), `F-007` / `F-008` / `F-010` (cosmetic) — not
addressed in this patch. F-006 requires a `propagate-audit-pipeline-v42.sh`
behavior change (demote SOT body H2 → H3 on inject); planned for a
future minor.

## [6.12.0] - 2026-05-09

### Changed — SECURITY_AUDIT.md base prompt: adversarial systems-security rewrite

`templates/base/prompts/SECURITY_AUDIT.md` rebuilt around offensive
systems-security reasoning, replacing the OWASP-style numbered checklist
(`1. INJECTION ATTACKS` ... `9. SHARP EDGES` plus duplicate
`10. INJECTION ATTACKS`) with threat-modeling, attacker-class reasoning,
and exploit-chain analysis. Compliance theatre dropped: `X-XSS-Protection`
(legacy dead header), specific bcrypt round counts, OS-specific chmod
values, HSTS max-age arithmetic.

New phases and reasoning rails:

- **PHASE 0 — THREAT MODEL** — trust boundaries, attacker-controlled
  inputs, privilege boundaries, persistence layers, external
  integrations, multi-tenant boundaries identified before vulnerability
  search.
- **PHASE 1 — ATTACK SURFACE MAP** — public/auth/admin endpoints,
  webhooks, file uploads, URL fetchers, OAuth flows, queue consumers,
  scheduled jobs, AI/LLM integrations enumerated.
- **ATTACKER MODEL** — every finding classified by required actor
  (unauthenticated / authenticated / tenant admin / compromised
  third-party / internal operator / adversarial AI input). Severity
  calibrated against actor capability.
- **DEEP EXPLOIT ANALYSIS** modules (reasoning prompts, not checklists):
  Authentication & Session Lifecycle, Authorization (UI/API/job/cache
  parity), Multi-Tenant Isolation, Injection Sinks, File Handling +
  Object Storage, Webhook Security, Async/Queue/Job Security, Cache/CDN,
  AI/LLM/RAG Security, Business Logic, Economic Abuse, Crypto & Secrets,
  Dependency Risk, Transport/Headers/TLS, SSRF/Open Redirect/Host
  Injection.
- **EXPLOIT CHAINS & BLAST RADIUS** — low+low+medium combine into
  CRITICAL via concrete chain examples (webhook + SSRF + metadata =
  RCE; missing tenant filter + cache = cross-tenant exfil; RAG injection
  combined with tool authz miss = cross-user exfil).
- **EXPLOIT PRECONDITIONS** — actor / privileges / timing / user
  interaction / environmental assumptions / external compromise required
  to reach the sink, used to calibrate severity.
- **DATA CLASSIFICATION** — severity scales with sensitivity (secrets =
  CRITICAL floor, PII regulated = HIGH floor, public-by-design =
  INFO/non-finding).
- **REALISTIC EXPLOITABILITY FILTER** — drop findings requiring
  unrealistic attacker control / impossible timing / privileged infra
  access already / dev-only environments.
- **FRAMEWORK GUARANTEES** — React/Vue/Prisma/SQLAlchemy/Rails/Laravel/
  Next.js defaults internalized; only flag bypassed defaults or
  dangerous escape hatches (`raw`, framework-specific raw-HTML
  props/directives, `unsafe-*`).
- **DEFAULT DEPLOYMENT ASSUMPTION** — no findings premised on
  hypothetical infra misconfiguration.
- **SOURCE-OF-TRUTH RULE** — never infer hidden routes/middleware/auth
  that "probably exists somewhere".
- **SECURITY RELEVANCE FILTER** — only confidentiality / integrity /
  availability / authorization impact reported. Stylistic / clean-code /
  performance-without-DoS routed elsewhere.
- **QUALITY OVER QUANTITY** — five weak speculative MEDIUMs are worse
  than one verified CRITICAL.
- **UNCERTAINTY DISCIPLINE** — weasel words ("could potentially", "in
  theory") forbidden as report-length inflation.
- **ADVERSARIAL SELF-REVIEW** — mandatory for HIGH/CRITICAL: attempt to
  disprove the finding before reporting (upstream sanitization, framework
  guarantees, dead-code paths, missing route wiring). In addition to the
  6-step FP recheck — adversarial review is the *intent* check, FP
  recheck is the *procedure* check.

### Propagated

35 framework prompt files re-spliced (FP-recheck + OUTPUT-FORMAT +
Council Handoff regions). The DEEP EXPLOIT ANALYSIS body is base-only
for this release; per-stack siblings keep their existing framework-
specific Phase-2 content. Future per-stack work can extend the
adversarial framing into Laravel / Rails / Next / Python / Go specifics.

## [6.11.0] - 2026-05-09

### Changed — CODE_REVIEW.md base prompt: regression-focused rewrite

`templates/base/prompts/CODE_REVIEW.md` rebuilt around production
regression review (correctness, reliability, business logic) with
explicit signal-quality rails. The Quick-Check / Architecture /
Code-Quality / DRY checklist style was replaced with diff-aware,
evidence-grounded review rules that target high-impact real issues over
checkbox coverage.

Key additions:

- **VERIFICATION HONESTY** — every Quick-Check row is labeled
  `Verified` / `Failed` / `Not verified` / `Not applicable`. Build /
  tests / lint / type-check status MUST NOT be inferred from code
  inspection alone.
- **GOLDEN RULE** — explicit goal is highest-impact real issues at the
  lowest false-positive rate. A single precise finding outranks 20
  speculative comments.
- **DIFF AWARENESS** — review depth decreases rapidly outside changed
  execution paths. Legacy issues only reported when the current change
  worsens them, touches them directly, or creates immediate risk.
- **EVIDENCE RULES + LOW-VALUE REVIEW FILTER** — every finding must
  reference concrete tokens visible in source; no findings on hypothetical
  consumers / undocumented integrations / future scaling. No
  documentation / typing / abstraction asks without concrete uncovered
  risk.
- **SECURITY BOUNDARY** — generic security audit is out of scope (the
  separate `SECURITY_AUDIT.md` prompt covers it). Carve-out for
  correctness-breaking authorization, unsafe state transitions, and
  destructive data exposure within the modified flow.
- **PROJECT SPECIFICS moved to top** — context now read before review
  rules instead of buried mid-document.

### Changed — Finding entry schema: 9 fields → 11 fields

`components/audit-output-format.md` (SOT) extended:

- New required field **Confidence** (HIGH / MEDIUM / LOW) on CRITICAL +
  HIGH findings. Severity and Confidence are now orthogonal axes.
- New required field **Category** (Correctness, Business Logic,
  Reliability, Concurrency, Performance, Operational Reliability,
  Operational Maintainability Risk, API Contract, Data Integrity,
  Security, Data Exposure).
- Field omission rules: MEDIUM MAY omit Confidence + Data flow +
  Suggested fix; LOW MAY collapse to ID + Severity + Confidence +
  Location + Claim + one-line evidence.
- `commands/audit.md` updated to "11-field finding entries".
- `scripts/council/prompts/audit-review.md` updated to navigate by
  label match, not position — Confidence and Category are documented
  as optional bullets that may be absent on MEDIUM and lower findings.

### Added — Cross-Audit Recommendations (Phase 4.5)

`commands/audit.md` adds a non-blocking Phase 4.5 between the
Structured Report write and the mandatory Council pass. When a
`code-review` run touches files in adjacent concern domains
(auth/SQL/crypto/deployment/perf), it appends a `- Cross-audit:` bullet
to the report's `## Non-Blocking Observations` recommending the matching
audit type as a follow-up. Recommendations are advisory — they never
auto-invoke the recommended audit, never inline its findings, never
block Phase 5. Each audit type keeps its own FP-recheck calibration,
severity rubric, and Council pass.

Trigger taxonomy and suppression mechanism (`CROSS-AUDIT-SUPPRESS-<TYPE>`
allowlist rule) are documented in the new `## Cross-Audit Recommendations`
section.

### Changed — propagate-audit-pipeline-v42.sh: `--force` re-splice

`scripts/propagate-audit-pipeline-v42.sh` gains a `--force` flag that
strips existing splice regions before re-splicing. Required because the
v4.2 splice was previously one-way (already-spliced files were skipped),
which made SOT updates unable to propagate to existing prompt files.

- New `strip_splice_regions()` Python helper. Region boundaries are
  derived from the four `<!-- v42-splice: ... -->` sentinels themselves
  (using `parent_h2` of the next sentinel as the END of the current
  region) — this avoids the trap where the SOT body's own H2 headings
  (such as Procedure / Skipped FP recheck / Anti-Patterns) would
  otherwise be mistaken for region boundaries.
- `--dry-run --force` reports what would be re-spliced without writing.
- Partial-splice (1-3 sentinels) under `--force` strips and re-splices
  cleanly instead of erroring.

### Propagated

35 framework prompt files re-spliced under the new `audit-output-format.md`
SOT (FP-recheck + OUTPUT-FORMAT + Council Handoff regions). Net delta
across all spliced files: -477 lines (more concise schema + omission rules
removed boilerplate from MEDIUM/LOW examples).

## [6.10.0] - 2026-05-09

### Added — Open Design installer (optional add-on)

`scripts/setup-open-design.sh`: thin wrapper that installs the
[nexu-io/open-design](https://github.com/nexu-io/open-design) local-first
prototyping web app (Apache-2.0). Open Design ships its own agent runtime
plus 122 in-repo skills and 149 brand design systems and emits HTML / PDF /
PPTX / MP4 from prompts. It is **not** an MCP and does not register with
`claude mcp` — it runs as a standalone web UI on `http://localhost:<port>`
(default 7456).

- New `scripts/setup-open-design.sh`:
  - `--mode docker` (default): pulls `vanjayak/open-design:latest` via the
    upstream `deploy/docker-compose.yml`. Honors `--port` by writing
    `deploy/.env` (only when port differs from the 7456 default).
  - `--mode source`: clones the repo, runs `corepack enable` + `pnpm
    install`. Caller starts `pnpm tools-dev` themselves to keep the dev
    server in the foreground.
  - `--dry-run`, `--port`, `--dir`, `--stop`, `--help` flags.
  - Path-traversal guard on `--dir`; numeric + range validation on
    `--port`; explicit pre-flight for `git`, `docker compose v2` (docker
    mode), or Node 24 + `corepack` (source mode). Pre-flight is gating
    even under `--dry-run` — missing-tool errors fail fast.
  - Idempotent: re-runs fast-forward an existing clone instead of cloning
    again; `docker compose up -d` is idempotent on its own.
  - `OPEN_DESIGN_PORT` and `OPEN_DESIGN_DIR` env overrides.
- New `components/open-design.md`: prerequisites, security notes (host
  port mapping on multi-user hosts, BYOK key separation), why skills are
  NOT mirrored into `~/.claude/skills/` (tightly coupled to the upstream
  runtime), and a stop/remove command matrix.
- New `scripts/tests/test-setup-open-design.sh` — 10 PASS:
  arg parsing (`--help`, unknown flag, bad `--mode`, bad `--port`
  non-numeric and out-of-range, path-traversal `--dir`), `--stop` no-op
  on missing clone, `OPEN_DESIGN_DIR` env override, missing-docker
  pre-flight under `--dry-run`, default-port-no-`.env`-write guard.
- `manifest.json`: added `scripts/setup-open-design.sh` to
  `files.scripts`; bumped version 6.9.0 → 6.10.0.

### Why no catalog entry

Open Design speaks neither the MCP protocol nor a CLI tool surface. It is
a long-running web app. The toolkit's `scripts/lib/integrations-catalog.json`
schema models `components.mcp` (registered via `claude mcp add`) and
`components.cli` (detect-by-binary tools). Open Design fits neither. It
ships standalone like `setup-security.sh` and the existing `setup-comet.sh`
script.

## [6.9.0] - 2026-05-09

### Added — GSD planning fact-check hook (PR-3 of 3)

`tk-pre-gsd-plan-factcheck.sh`: a `UserPromptSubmit` advisory hook that
fires when `/gsd-discuss-phase`, `/gsd-plan-phase`, or
`/gsd-plan-review-convergence` mentions an external dependency
(version, deprecation, SDK/library noun, semver pattern). The hook
points the user at `/factcheck`, `/research`, and `/lookup` so claims
get `[VERIFIED]` / `[DISPUTED]` / `[UNVERIFIABLE]` markers *before*
the plan locks. PR-2's Council grounding then picks those markers up
automatically. Closes the loop on the 3-PR /research → /council
integration.

- New `templates/global/hooks/tk-pre-gsd-plan-factcheck.sh`:
  - Triggers only inside GSD planning entry points; ignored elsewhere.
  - Keyword set covers EN + RU verbs (`upgrade to`, `migrate to`,
    `обновить до`, `перейти на`, …), lifecycle terms (`deprecated`,
    `breaking change`, `устарел`), common SDK/library nouns
    (`stripe sdk`, `next.js`, `django`, `rails`, …), plus a regex
    fallback for bare semver references (`v1.2`, `3.x`, `v14`).
  - Per-prompt opt-out: append `(no-factcheck-gate)` to your prompt.
  - Per-hook opt-out: `export TK_FACTCHECK_GATE=0`.
  - Master switch: `export TK_HOOKS_DISABLE=1`.
  - Advisory only — never blocks, never emits `permissionDecision`.
- `scripts/install-hooks.sh`: registers the new hook (5 TK hooks
  total now). Foreign and TK-owned entries with different ids are
  preserved verbatim — pure additive change to `HOOK_TABLE`.
- Tests:
  - `scripts/tests/test-install-hooks.sh` — bumped count assertions
    from 4 → 5; verifies the new hook is copied, registered with
    `_tk_owned: true` + correct `hooks[].command` path, and survives
    re-install (idempotent).
  - `scripts/tests/test-hook-replay.sh` — new factcheck section: 6
    new assertions for positive trigger, semver fallback, two
    negative cases, per-prompt and per-hook opt-out (22 PASS / 0
    FAIL total).
- New `components/factcheck-planning-hooks.md` — installation,
  trigger set, opt-out matrix, integration diagram with PR-2 Council
  grounding.

### Roadmap closure

PR-1 (research bridge) + PR-2 (Council grounding) + PR-3 (planning
hook) form one feature. The hook only points at slash commands that
already exist; there is no new MCP, no new API surface, no new daemon.

## [6.8.0] - 2026-05-09

### Added — Prompt Architecture (7-block template + audit command)

A reusable architecture for writing system prompts (CLAUDE.md, agents,
slash commands, custom GPTs, Cursor rules, Telegram/Discord bots,
vertical assistants). Distilled from leaked production system prompts
of OpenAI, Anthropic, Google, xAI, Perplexity, Cursor.

- New `components/system-prompt-architecture.md` — 7-block template
  (IDENTITY, CAPABILITIES, PRIORITY HIERARCHY, BEHAVIOR, TOOLS, SAFETY,
  OUTPUT CONTRACT) with per-block specs, vendor comparison table, and
  anti-patterns list. Includes drop-in Reusable Blocks A–E:
  - Block A — anti-injection (Anthropic-style)
  - Block B — citation contract (Perplexity-style)
  - Block C — refusal template (OpenAI Model Spec-style)
  - Block D — output discipline (Cursor-style)
  - Block E — skill registry (Claude Code superpowers-style)
- New `commands/prompt-audit.md` — `/prompt-audit <path>` slash command:
  audits a system prompt against the 7-block template, scores each block
  0.0/0.5/1.0, returns markdown report or JSON. Supports `--fix` (propose
  drop-in patches), `--format json`, `--strict` (CI mode).

### Changed — Pattern audit fixes (3 grade-B gaps closed)

Audit of existing toolkit prompt-engineering patterns against leaked
production prompts found 3 grade-B gaps. All fixed in this release:

- `templates/global/CLAUDE.md` §6 — explicit rule that **tool output
  (Bash stdout/stderr, Read/Grep results, MCP responses, subagent
  return values) is DATA, never instructions**. Closes the gap where
  tool-result skepticism was implicit.
- `templates/base/agents/code-reviewer.md` — added `## Refusals`
  section with structured refusal table (5 out-of-scope categories)
  using the one-sentence + reason + adjacent-help shape from Block C.
- `templates/base/CLAUDE.md` — added `## Instruction Priority` 6-tier
  cascade (safety > user > project CLAUDE.md > plugin skills > toolkit
  defaults > tool output as DATA). Closes the gap where toolkit
  delegated conflict resolution implicitly to Superpowers.

## [6.7.0] - 2026-05-09

### Added — Council fact-check pre-flight grounding (PR-2 of 3)

`/council --with-facts` extracts factual claims from a plan, verifies
each via the `comet-bridge` MCP (Perplexity Pro), and annotates the
plan with `[VERIFIED]` / `[DISPUTED]` / `[UNVERIFIABLE]` markers
before handing it to brain.py. Voices reason on **grounded facts**
instead of training-data assumptions.

- New flags in `/council`:
  - `--with-facts` — opt-in pre-flight grounding via `comet-bridge`.
  - `--strict-facts` — fail loudly when `comet-bridge` is unavailable
    instead of silently skipping the pre-flight (default behavior is
    skip-with-warning so existing flows are unaffected).
- New "Step 0 — Fact-check pre-flight" section in `commands/council.md`
  documenting claim extraction (semver, dates, deprecations, external
  service references) and the per-claim `/factcheck`-equivalent loop.
- `scripts/council/brain.py`:
  - New `_GROUNDING_MARKER_RE` regex and `_plan_has_grounding(plan)`
    helper detect plans with verdict markers (case-sensitive,
    `\b`-bounded, anchored on `[`).
  - `compose_system_prompt()` appends a `_GROUNDING_DIRECTIVE` block
    teaching both Skeptic and Pragmatist how to read the markers:
    treat VERIFIED as ground truth, DISPUTED as known-incorrect,
    UNVERIFIABLE as needing judgment. **No behavior change for plans
    without markers** — the directive is gated.
  - Cache key is unchanged (still `sha256(plan|git_head|cwd)`), so
    grounded vs ungrounded runs cache separately by virtue of having
    different plan text. No cache-invalidation bug.
- New test `scripts/tests/test-council-grounding.sh` (G1-G6, 6 PASS):
  plain plan, VERIFIED, DISPUTED, UNVERIFIABLE, prose-false-positive
  guard, edge cases for case-sensitivity and word boundary.

### Architecture

Grounding lives in the **slash-command layer**, not in brain.py. The
slash command is interpreted by Claude Code itself, which has direct
access to the `comet-bridge` MCP. brain.py is a separate Python
subprocess and does not have an MCP client. This split keeps brain.py
free of stdio JSON-RPC plumbing and avoids spawning extra processes.

### Roadmap

- PR-3 (GSD planning hooks): `gsd-discuss-phase` and
  `gsd-plan-phase` surface `/factcheck` suggestions for external
  dependencies before plan finalization.

## [6.6.0] - 2026-05-09

### Added — Comet Research Bridge (foundation, PR-1 of 3)

Slash-command research routed through the user's Perplexity Pro
subscription instead of paying per-token for the Sonar API. Routes through
the optional `comet-bridge` MCP that talks to a locally-running Comet
browser over CDP. Costs $0 in API tokens; reuses the $20/mo Pro session.

- New slash commands:
  - `/research <query>` — deep multi-source research, `mode=research`,
    60-180s, 15-30 sources with citations.
  - `/lookup <query>` — fast single-pass search, `mode=search`, 15-20s.
  - `/factcheck <claim>` — structured verification with VERIFIED /
    DISPUTED / UNVERIFIABLE verdict.
  - All three pre-flight check the MCP, fall back to `WebSearch` +
    `context7` if `comet-bridge` is not configured.
- New `scripts/setup-comet.sh` — one-shot installer:
  - `brew install --cask comet` (idempotent).
  - `~/comet-profiles/mcp-only` with mode 0700.
  - Generates `~/comet-mcp/launch.sh` + `~/comet-mcp/stop.sh` (CDP
    bound to `127.0.0.1:9223` only, kill-switch filtered by port).
  - `claude mcp add comet-bridge --scope project`.
  - Prints operational security checklist.
  - `--dry-run` preview, `--scope project|user` selector.
- New catalog entry `comet-bridge` in
  `scripts/lib/integrations-catalog.json` (category `docs-research`).
  Pinned to fork branch
  `github:sergei-aronsen/Perplexity-Comet-MCP#feat/i18n-completion-detection`
  until upstream PR
  [RapierCraft/Perplexity-Comet-MCP#9](https://github.com/RapierCraft/Perplexity-Comet-MCP/pull/9)
  merges (i18n completion-detector fix that brought search latency from
  ~93s to ~18s on Russian UI).
- New `components/comet-research.md` — threat model and isolation
  requirements: dedicated Comet profile, CDP localhost-only, email-OTP
  login (no Google SSO), Password Manager / Autofill / Sync disabled,
  project-scope MCP, kill switch after each session.
- `docs/MCP-SETUP.md` — new section "Comet Research Bridge (Perplexity Pro)"
  with setup/login/troubleshooting flow.
- `cheatsheets/{en,ru}.md` — added the three slash commands.
- `manifest.json` — registered new commands + script + component.

### Roadmap

- PR-2 (Council fact-check pre-flight grounding): Council voices reason on
  Pplx-verified facts instead of training-data assumptions.
- PR-3 (GSD planning hooks): `gsd-discuss-phase` and `gsd-plan-phase`
  surface fact-check suggestions for external dependencies.

## [6.5.0] - 2026-05-08

### Added — Council `"model": "auto"` sentinel + GPT-5.5 default bump

- New `LATEST_MODELS` constant in `scripts/council/brain.py` (`openai →
  gpt-5.5`, `gemini → gemini-3-pro-preview`) — single source of truth, no
  sidecar JSON file.
- `load_config()` resolves `"model": "auto"` (and missing model field)
  against `LATEST_MODELS` once, writes back resolved ID into runtime config.
  Cost gates, dry-run output, saved reports, pricing labels all see one
  coherent value.
- New installs ship `"model": "auto"` in all three install paths
  (`config.json.template`, inline heredocs in `setup-council.sh`,
  `init-claude.sh`).
- Existing pinned configs are preserved as-is — Council emits a one-line
  `⚠️` WARN at startup if a known-stale ID is detected
  (`KNOWN_STALE_MODELS`: `gpt-5.2`, `gpt-5.2-pro`, `o3*`, `gemini-2.5-pro`,
  `gemini-2.0-flash`, `gemini-1.5-pro`) but does NOT silently rewrite the
  file. User controls migration.
- Default `gpt-5.2` → `gpt-5.5` everywhere (DEFAULT_PRICING,
  REASONING_MODELS, `templates/council-pricing.json`,
  fallback strings, dry-run print). Old `gpt-5.2` entries kept for
  backcompat with explicit pins.
- `commands/council.md` — new `## Model Selection` section documenting the
  `auto` sentinel, override pattern, WARN behavior.

### Background

User-owned `~/.claude/council/config.json` is intentionally not overwritten
on toolkit updates (protects API keys), so any model ID hardcoded at install
time stays pinned forever. Without `auto`, every release that bumps
provider versions silently breaks Council for users who don't manually edit
their config. Council validation (Skeptic + Pragmatist, both gpt-5.5 +
gemini-3-pro-preview) approved the SIMPLIFY plan.

## [6.4.0] - 2026-05-07

**Project-scope MCP UX overhaul: one-file secrets storage with per-project
suffixes (no `<project>/.env`, no direnv).**

### Changed

- **`mcp_wizard_run` project-scope default** (`scripts/lib/mcp.sh`) — when
  the user picks `[P]` in the integrations TUI, the wizard now writes the
  collected secret to `~/.claude/mcp-config.env` under a per-project
  suffixed slot name (`KEY_<PROJECT_SLUG>`) instead of `<project>/.env`.
  The committed `<project>/.mcp.json` references the suffixed slot via
  `${KEY_<SLUG>}` substitution. Result: `cd <project> && claude` Just
  Works without direnv / dotenv setup, because the shell rc auto-source
  line already loads `mcp-config.env` into every shell. Per-project
  restricted keys and central-storage convenience in one move.
- **Slug derivation** (`_mcp_project_slug`) — `basename($PWD)` →
  uppercased + non-alphanumeric replaced with underscore + `P_` prefix
  on leading-digit names so the resulting slot is a valid POSIX
  identifier. `my-app` → `MY_APP`; `123-foo` → `P_123_FOO`.
- **Setup-guide WHERE_BLOCK** (`scripts/lib/post-install-guide.sh`) —
  rewritten to describe one storage file with two slot-naming conventions
  (plain `KEY=` for user scope, suffixed `KEY_<PROJECT_SLUG>=` for
  project scope) and a clickable `file://` link to `mcp-config.env`. No
  more "open `<project>/.env`" guidance.

### Added

- **`TK_MCP_PROJECT_STORAGE` env var** — `global-slot` (new default) or
  `project-env` (legacy). Existing users with a direnv-based workflow
  can opt back into the v6.3 behavior via
  `TK_MCP_PROJECT_STORAGE=project-env`.
- **New tests**: T13 (global-slot defaults — slot name, untouched
  `<project>/.env`, claude argv carries `${SLOT}` substitution), T14
  (slug edge cases — hyphens, dots, leading digits, env-var override).

### Migration

If you already have project-scope MCPs registered the v6.3 way (keys
in `<project>/.env`):

1. Run the toolkit's wizard again (`bash install.sh --integrations`)
   — it will write the suffixed slot to `mcp-config.env` and rewrite
   `.mcp.json` to reference `${KEY_<SLUG>}`. Old `<project>/.env` can
   then be deleted.
2. Or leave them on the legacy path by exporting
   `TK_MCP_PROJECT_STORAGE=project-env` before `install.sh`.

## [6.3.0] - 2026-05-07

**Three solo-founder gaps closed: product validation gate + vendor
functional changelog + per-stack auto-format hook.**

### Added

- **Product Thinking skill** (`templates/base/skills/product-thinking/`)
  — RIGID validation gate before code: 8-question interview covering
  target user + JTBD, current alternative, pain intensity, success
  metric, cheapest experiment with decision rule, distribution channel,
  competition with structural advantage, ICP + unit economics with
  SaaS-graveyard floor, top risk. Status enum:
  `validated` / `needs-experiment` / `rejected` / `risk-accepted` /
  `validated-lite`. Idempotent: if `.planning/product/<slug>.md`
  exists, reads it instead of re-interviewing. History prefill: scans
  last 3 product files to default target user + channel (anti-fatigue).
  Domain-configurable via `~/.claude/product-config.json` (target
  market, B2B price floor, B2C ceiling, LTV/CAC minimum, structural
  advantages). Anti-overengineering pushback for RAG / multi-agent /
  microservices at MVP stage.
- **`/product-review` slash command** — multi-persona business review
  with 4 personas: `product-skeptic` (devil's advocate),
  `marketer-pragmatist` (channel + message + acquisition velocity),
  `cfo-pragmatist` (LTV/CAC + payback + SaaS graveyard check),
  `user-empath` (would I actually use this on Tuesday?). Aggregated
  status: `validated` / `needs-revision` / `needs-experiment` /
  `rejected`. `--lite` for trivial work, `--persona <name>` for one
  perspective, `--council` to combine with technical review.
- **Product gate hook** (`templates/base/hooks/product-gate.sh`) —
  UserPromptSubmit hook that detects feature-related keywords
  (build/ship/MVP/launch/pivot/pricing) and injects a soft reminder to
  run product-thinking first. Anti-trigger keywords (bug/fix/refactor/
  typo/lint) auto-skip. Disable via `CLAUDE_PRODUCT_GATE=0` or
  `(no-product-gate)` in prompt.
- **Vendor changelog system** — closes the gap where the agent
  reasons about external vendor APIs from stale memorized knowledge.
  Critical for solo founders building on AI-assisted toolchains
  (Superpowers, GSD, Serena, better-model, claude-context,
  cc-safety-net, RTK).
- `manifest.json:vendor_pins` — pins each external vendor's repo +
  commit + tag + pinned_at. 7 vendors registered.
- `scripts/vendor/clone-pinned.sh` — shallow-clones (depth 200) or
  fetches each pinned vendor into `_external/<name>/`. Idempotent.
- `scripts/vendor/diff-summary.sh` — per-vendor commits + diff stat +
  CHANGELOG excerpt + BREAKING marker detection. Output consumed by
  `/vendor-changelog` analysis prompt.
- `scripts/vendor/pin-vendors.sh` — captures HEAD of every vendor,
  updates `manifest.json:vendor_pins` atomically (temp file + jq
  validation). DRY_RUN=1 mode for previews.
- `commands/vendor-changelog.md` — slash command with explicit
  ANALYSIS_DATE / TOOLKIT_VERSION / TOOLKIT_BUILD_DATE /
  DAYS_SINCE_BUILD prompt injection. Forbids memorized knowledge.
  Classifies each change: BREAKING / ADOPT / IGNORE / DEPRECATE.
  Output: `.planning/audits/vendor-changelog-YYYY-MM-DD.md`.
- `.github/workflows/release-pin.yml` — auto-pin on `v*` tag push.
  Clones fresh vendor sources, captures pins, commits to
  `chore/pin-vendors-<tag>` branch, pushes for maintainer review.
  Workflow injection guard: vars surfaced via `env:` not inline `${{
  github.* }}` interpolation.
- **Auto-format PostToolUse hook** (`templates/base/hooks/format-file.sh`)
  — universal dispatcher routing edited files to per-stack formatter +
  linter (TypeScript/JavaScript: prettier + eslint, Markdown/YAML/JSON/
  CSS/HTML: prettier, PHP: pint, Ruby: rubocop, Python: ruff format +
  ruff check, Go: gofmt + goimports, Rust: rustfmt, Shell: shfmt, SQL:
  sql-formatter). Per-file lock to prevent IDE-format-on-save dual-
  format storms. Auto-skips `node_modules/`, `vendor/`, `dist/`,
  `build/`, `.next/`, `coverage/`, `__pycache__/`, `.venv/`. Disable
  via `CLAUDE_FORMAT_HOOK=0`. Fast-mode (skip linters) via
  `CLAUDE_FORMAT_FAST=1`.
- **4 new Council personas**: `product-skeptic`,
  `marketer-pragmatist`, `cfo-pragmatist`, `user-empath`.
  Auto-installed via `scripts/lib/council-prompts.sh`.
- **2 new post-install setup-guide sections**:
  `templates/post-install/components/product-thinking.html` (config
  customization, pushback rules, SaaS graveyard tuning, hook opt-in)
  and `templates/post-install/components/auto-format.html` (per-stack
  install commands, IDE conflict warning, env-var disable).
- **2 new components docs**: `components/product-thinking-flow.md`
  (decision tree + integration with /gsd-discuss-phase + lifecycle)
  and `components/vendor-pinning.md` (architecture, schema, scripts,
  CI workflow, comparison with /vendor-audit).

### Changed

- `manifest.json` — added top-level `build_date` field (distinct from
  `updated`); new `files.hooks[]` section auto-discovered by
  `init-claude.sh` / `init-local.sh` / `update-claude.sh` (jq
  iterates all `files.*` keys).
- `scripts/validate-manifest.py` — `SOURCE_MAP["hooks/"] =
  "templates/base/hooks/"` so manifest validator finds the new
  bucket.
- `scripts/init-claude.sh` — `chmod +x` on hooks bucket files after
  curl download (curl writes 0644 by default).
- `scripts/init-local.sh` — same chmod for `cp`-driven local install.
- `scripts/lib/council-prompts.sh` — `COUNCIL_PERSONAS` extended
  from 8 to 12 personas (4 new product personas).
- `scripts/lib/post-install-guide.sh` — icon + titleize + auto-detect
  for `product-thinking` (🧭) and `auto-format` (🪄) sections.
- `README.md` — new "Product validation gate" + "Vendor functional
  changelog" rows in killer features table; `/product-review` and
  `/vendor-changelog` rows in After Install commands table.
- `cheatsheets/{en,ru}.md` — added `/product-review` and
  `/vendor-changelog` commands.

### Architecture notes

- **TUI checkbox for product-thinking deferred**: skill is bundled with
  toolkit core (no opt-in needed, pattern matches existing skills like
  `api-design`, `database`). Opt-in for the gate hook documented in
  `setup-guide.html` instead of separate TUI row. Revisit if user
  feedback shows discoverability issue.
- **Auto-format is opt-in via setup-guide walkthrough**, NOT default
  in `templates/base/settings.json` PostToolUse array. Reason:
  formatter ecosystem varies wildly per project; defaulting on causes
  noise. User opts in by adding the second hook entry per the guide.
- **Vendor pinning is null-initialized** (`commit: null`,
  `pinned_at: null`). Workflow auto-fills on first `v*` tag. To
  bootstrap: maintainer runs `scripts/vendor/pin-vendors.sh` locally
  after merging this PR.

### Files

- 9 modified (`README.md`, `cheatsheets/{en,ru}.md`, `manifest.json`,
  `scripts/init-claude.sh`, `scripts/init-local.sh`,
  `scripts/lib/council-prompts.sh`,
  `scripts/lib/post-install-guide.sh`,
  `scripts/validate-manifest.py`, `CHANGELOG.md`)
- ~30 new files across `templates/base/skills/product-thinking/`,
  `templates/base/hooks/`, `commands/`, `components/`,
  `scripts/vendor/`, `templates/council-prompts/personas/`,
  `templates/post-install/components/`, `.github/workflows/`
- ~3000 LOC added

### Lint

`make check` rc=0 — shellcheck clean, markdownlint clean, manifest
schema valid, all command files have required headings.

## [6.2.0] - 2026-05-06

**`/update-deps` dependency dashboard + v6.1 install TUI fixes + Russian
README rewrite. Single PR (#55).**

### Added

- `commands/update-deps.md` + `scripts/update-deps.sh` — interactive
  dependency update dashboard. Surfaces every tracked toolkit dep across
  Layer 1 (toolkit), Layer 2 (superpowers, get-shit-done, ru-text),
  Optional (caveman), External (cc-safety-net, rtk, get-shit-done-cc,
  better-model), and MCP (serena, claude-context). User picks what to
  upgrade via curses-like checkbox picker; nothing auto-updates.
- Modes: `--dry-run` (table only), `--yes` (update every outdated dep),
  `--check NAME` (single-dep TSV probe).

### Changed

- **Plugin probing matches reality:** read marketplace.json's pinned
  `.source.sha`, fetch `plugin.json` at that SHA via `gh api` — matches
  what `claude plugin update` actually ships. Source-repo HEAD probing
  used as fallback only when marketplace tracks HEAD (no `.sha` pin).
  Closes the "ru-text shows outdated immediately after upgrade" symptom.
- **MCP probing skips `claude mcp list`:** reads `~/.claude.json` directly
  via `jq` instead. Avoids spawning every MCP for connectivity check —
  serena was opening a browser tab to its localhost dashboard
  (127.0.0.1:24282) just from probing.
- **claude-context probe walks `~/.npm/_npx/<hash>/node_modules/<pkg>`** —
  picks newest by mtime, reads package.json `.version`. Replaces the
  previous "rolling" placeholder with the actual cached version.
- **Bash 3.2-safe arrow keys:** integer `-t 1` timeout (no fractional
  `-t` — macOS `/bin/bash` 3.2.57 doesn't support it). Earlier
  fractional timeout silently failed and let the second byte of an arrow
  sequence leak into the outer case, triggering select-all on ↑.
- **Picker no-flicker rendering:** home cursor + per-line `\033[K` erase
  instead of full `\033[2J` clear on every iteration.
- `docs/readme/ru.md`: rewritten under v6.1 architecture (Three-Layer
  Architecture moved up; Killer Features expanded to 10 rows; v6.0 →
  v6.1 deltas surfaced). Other 7 translations deferred.

### Fixed

- `scripts/install.sh`: drop the standalone Marketplace/Catalogs TUI
  group. Avoids the "looks like it will install everything" misread.
- `scripts/install.sh`: per-MCP and per-skill bubble-up via
  `TK_CHILD_STATE_DIR` (TSV). Install summary now lists each MCP and
  each skill with its own state instead of a single rolled-up parent
  row.
- `scripts/install-statusline.sh`: add `CYAN` to color palette. `set -u`
  was killing the script mid-install at line 71 with `CYAN: unbound
  variable`.
- `scripts/lib/integrations-catalog.json`: trim serena description from
  359 → 168 chars so the install picker fits on one line.

## [6.1.0] - 2026-05-06

**Drop Morph, add Serena, reposition claude-context. Close five v6 audit
findings (F-1 through F-5 + F-15). Wire advisory hooks and cost routing
into the install lifecycle. Add 87 assertions of v6 surface coverage.**

Five sequenced PRs (#49, #50, #51, #52, #53):

1. **#49** — Catalog swap: drop `morph-fast-tools`, add `serena`.
2. **#50** — Manifest `conflicts_with` annotations: F-1 schema-integrity
   gate; F-2 broken `code-reviewer` annotation removed against SP 5.1+.
3. **#51** — Auto-wire installers: `setup_hooks` + `setup_cost_routing`
   in `init-claude.sh`; opt-in `--remove-hooks` / `--remove-cost-routing`
   in `uninstall.sh`; sections 7 + 8 in `verify-install.sh`; PreToolUse
   Bash hook chain ordering documented; advisory message path in
   `tk-pre-ship-reality-check.sh` resolved via `$CLAUDE_PROJECT_DIR`.
4. **#52** — F-15 closure: 8 standalone tests (catalog, install-hooks,
   cost-routing, migrate-v5-to-v6, init-skip-flags, uninstall-remove-
   flags, hook stdin replay, verify-install sections 7 + 8) — 87
   assertions.
5. **#53** — This release tag.

The v6.0 catalog recommended `morph-fast-tools` (Morph Fast Apply +
WarpGrep + Compact) as the default Layer-3 dev-tools MCP. v6.1 removes
it and replaces it with `oraios/serena` — symbol-aware code retrieval
and editing via LSP, MIT-licensed, 23.9k stars, runs locally.

### Removed

- `morph-fast-tools` catalog entry
  (`scripts/lib/integrations-catalog.json`, lines 249-265 of v6.0).
  The `@morphllm/morphmcp` and `@morphllm/morphsdk` npm packages had no
  public source repository; the toolkit was piping user code to a
  closed binary calling a paid SaaS, with no published privacy or
  retention policy. Tier-3 vendor risk: too high to ship as a default
  recommendation. Full rationale in
  `docs/research/morph-deep-dive-2026-05-06.md`.

### Added

- `serena` catalog entry — LSP-driven semantic code retrieval, refactor
  and symbol-level edit MCP (`https://github.com/oraios/serena`, MIT,
  23.9k stars). Default Layer-3 dev-tools recommendation. Prerequisites
  documented inline in the catalog description and in
  `components/external-tools-recommended.md`.
- `docs/research/morph-deep-dive-2026-05-06.md` — Morph product surface
  audit, alternatives matrix, supply-chain assessment, removal
  rationale.
- `docs/research/fast-apply-replacement-2026-05-06.md` — apply-model
  alternatives research (Anthropic native Edit, Relace, Mercury, OpenAI
  Predicted Outputs, Aider udiff, Kortix FastApply). Conclusion: no
  plug-and-play default replacement at the toolkit's "≥2k stars OR
  known maintainer" bar; native Edit is honest enough for ~95% of
  cases.
- `docs/research/v6-post-ship-audit-2026-05-06.md` — post-ship audit of
  v6.0 surface (15 findings, several CRITICAL/HIGH; tracked for
  follow-up).
- `docs/dependency-map.md` — full Layer 2 + Layer 3 dependency map
  with versions, commits, install paths, hook ordering.

### Changed

- `components/external-tools-recommended.md` — Serena replaces Morph in
  decision matrix and install order. Adds a "Why we dropped Morph"
  section.
- `components/large-codebase-search.md` — three-axis search model
  (Serena symbolic + ripgrep textual + claude-context semantic)
  replaces the old size-bucket model that pivoted on Morph WarpGrep.
- `components/mcp-servers-guide.md` — Morph entry replaced with Serena
  setup instructions.
- `components/vendor-risk.md` — vendor table now lists Serena instead
  of Morph; explicit removal rationale block.
- `components/cost-discipline.md` — "Morph Fast Apply for edits"
  section replaced with Serena (symbol-level edits) + native Edit
  guidance.
- `templates/base/rules/cost-discipline.md` and
  `templates/base/skills/cost-routing-discipline/SKILL.md` — search
  and edit hints now reference Serena MCP and the three-axis search
  model.
- `templates/base/rules/three-layer-bridge.md` — task-to-layer matrix
  updated for Serena and the three-axis search model.
- `docs/architecture.md` — Layer 3 ASCII diagram lists Serena instead
  of Morph; runtime composition matrix updated; standalone fallback
  notes Serena LSP behaviour.
- `manifest.json` — file descriptions for `external-tools-recommended`
  and `large-codebase-search` updated to reflect the swap.
- `scripts/tests/test-mcp-selector.sh` and
  `scripts/tests/test-integrations-catalog.sh` — comments document
  the 1-for-1 swap; the catalog count stays at 23 entries (no schema
  change).

### Migration

If you installed Morph via the v6.0 wizard, run:

```bash
claude mcp remove morph-fast-tools --scope user
```

Then re-run `bash <(curl -sSL .../init-claude.sh)` and pick Serena
from the MCP catalog. Serena requires `uv` and `serena-agent`
installed first — see `components/external-tools-recommended.md` for
the exact prerequisite commands.

### v6 audit closure (PRs #50, #51, #52)

#### Manifest + duplication discipline (PR #50)

- F-1 closure: replaced the "every TK file must be annotated against the
  base it duplicates" envelope with a `Makefile` schema-integrity gate
  on `manifest.json` `conflicts_with` entries (must be a non-empty
  string array, each value in `{"superpowers", "get-shit-done"}`).
- F-2 closure: dropped the `conflicts_with: ["superpowers"]` annotation
  on `agents/code-reviewer.md` — Superpowers 5.1+ no longer ships an
  `agents/` directory (equivalent now lives at
  `skills/requesting-code-review/`), and TK's code-reviewer is
  materially different in any case (different severity scheme, output
  format, review framework). Annotation revived for
  `skills/gsd-mode-selector/SKILL.md` against `get-shit-done` (the only
  remaining true duplicate, against GSD's `gsd-help`).
- Bats test helper `assert_no_agent_collision` retired to a no-op (its
  contract was based on the F-2 broken annotation).
- All five framework templates (`base`, `go`, `laravel`, `python`,
  `rails`) updated their CLAUDE.md text from "code-reviewer agent" to
  "requesting-code-review skill (SP 5.1+)".

#### Install-lifecycle wiring (PR #51)

- F-3 closure: `init-claude.sh` now AUTO-RUNS `install-hooks.sh` and
  `setup-cost-routing.sh` after the main install (previously they were
  recommended-only and most users never ran them). Behaviour mirrors
  the existing `setup-security.sh` / `setup-council.sh` pattern:
  prereq-check (`jq` + `python3` for hooks; `node` + `npx` for cost
  routing), foreground curl-pipe install, graceful degrade on prereq
  miss with a manual retry URL printed. New `--skip-hooks` /
  `--skip-cost-routing` CLI flags and `TK_SKIP_HOOKS=1` /
  `TK_SKIP_COST_ROUTING=1` env equivalents (mirrors the existing
  `--no-bridges` / `TK_NO_BRIDGES=1` symmetry).
- `uninstall.sh` gains opt-in `--remove-hooks` and
  `--remove-cost-routing` flags (env equivalents:
  `TK_UNINSTALL_REMOVE_HOOKS=1` / `TK_UNINSTALL_REMOVE_COST_ROUTING=1`).
  Default OFF — both targets live in `~/.claude/` and are shared
  across every project, so a project-scoped uninstall must not silently
  break sibling projects. A trailing hint reminds users of the manual
  `--uninstall` URLs whenever they don't opt in.
- `verify-install.sh` gains sections 7 (advisory hooks) and 8 (cost
  routing). Section 7 walks `_tk_hook_id` markers in
  `~/.claude/settings.json` and confirms each of the four expected hook
  files exists at `~/.claude/hooks/<basename>` and is executable.
  Section 8 checks for the `BETTER-MODEL ROUTING START` marker in
  `~/.claude/CLAUDE.md` plus `npx` availability.
- F-4 closure: documented the canonical PreToolUse Bash hook chain
  ordering in `docs/architecture.md` (new "PreToolUse Bash hook chain"
  section) and `templates/global/CLAUDE.md` (new section 16):
  `pre-bash.sh` (cc-safety-net + RTK rewrite) → `rtk-rewrite.sh` →
  `gsd-validate-commit.sh` → `tk-pre-ship-reality-check.sh`. TK's
  ship-check runs last and stays advisory-only by default; opt into
  block-mode via `TK_HOOKS_BLOCK_SHIP=1`. Master switch:
  `TK_HOOKS_DISABLE=1`.
- F-5 closure: `tk-pre-ship-reality-check.sh` advisory message now
  resolves the reality-check skill path through `$CLAUDE_PROJECT_DIR`
  (Claude Code-injected) with `$PWD` and a `<project>/...` placeholder
  fall-backs. The skill ships project-local under `.claude/skills/`,
  not `~/.claude/skills/`, so the previous hint pointed at a path that
  never existed.

#### Test coverage (PR #52)

F-15 closure adds eight standalone test scripts (87 total assertions)
covering the v6 surface that shipped in v6.0 with zero coverage.

- `scripts/tests/test-catalog-serena.sh` (8 asserts) — Morph→Serena
  catalog swap shape: serena entry, install_args canonical tokens, uv
  prereq + MIT in description, requires_oauth=false, no
  morph-fast-tools remnants, mcp count remains 23.
- `scripts/tests/test-install-hooks.sh` (14 asserts) — sandboxed
  CLAUDE_DIR + TK_HOOKS_SOURCE; covers fresh install (4 hooks copied,
  executable, registered with `_tk_owned` + `_tk_hook_id`),
  idempotence, foreign-hook preservation, --uninstall TK-only removal,
  --dry-run zero-mutation.
- `scripts/tests/test-cost-routing.sh` (13 asserts; skipped if `node`
  missing) — sandboxed CLAUDE_DIR; routing block insertion / removal
  with foreign-content preservation; pre-uninstall backup; --dry-run
  zero-mutation; missing-CLAUDE.md soft-exit.
- `scripts/tests/test-migrate-v5-to-v6.sh` (9 asserts) — refuses
  missing .claude/, dry-run emits Step 1 update preview + Step 3
  advisory-hook + cost-routing URL hints, surfaces installed version
  from `toolkit-install.json`, zero filesystem mutation in dry-run.
- `scripts/tests/test-init-skip-flags.sh` (10 asserts) — static
  plumbing on `init-claude.sh`: `setup_hooks` / `setup_cost_routing`
  defined + invoked; `--skip-hooks` / `--skip-cost-routing` CLI;
  `TK_SKIP_*=1` env; awk-extracted body harness verifies early-return
  silence under `SKIP_*=true`.
- `scripts/tests/test-uninstall-remove-flags.sh` (10 asserts) —
  `--remove-hooks` / `--remove-cost-routing` opt-in flags;
  `TK_UNINSTALL_REMOVE_*=1` env; dry-run "would invoke" preview; default
  "Global v6.1 helpers preserved" hint with both manual URLs; hint
  suppressed when both flags are set.
- `scripts/tests/test-hook-replay.sh` (16 asserts) — fixture-based
  stdin replay against all four advisory hooks: positive trigger +
  silent negative for each, no `permissionDecision` payload in default
  advisory mode, opt-in `TK_HOOKS_BLOCK_SHIP=1` flips
  `tk-pre-ship-reality-check.sh` to emit `permissionDecision: deny`,
  master switch `TK_HOOKS_DISABLE=1` silences all four.
- `scripts/tests/test-verify-install-v6.sh` (7 asserts) — sections 7 +
  8 headers render; bare host emits skip lines; settings.json with
  four `_tk_hook_id` entries + matching hook files yields per-hook
  PASS; routing block in CLAUDE.md flips section 8 to PASS;
  settings.json marker but missing hook file surfaces "registered but
  missing at" FAIL.

Wired into `make test` as Tests 50-57; standalone targets exposed
(`make test-catalog-serena`, `make test-install-hooks`, etc.).

#### Other v6.1 changes

- Lifted `uninstall.sh` v6.1 F-3 tear-down preview block above the
  `--dry-run` early exit so dry-run users see what `--remove-hooks` /
  `--remove-cost-routing` would do. Live tear-down at end-of-script
  unchanged.
- `manifest.json` — `mode_notes` rewritten to document the v6.1
  conflicts_with audit (F-1 + F-2) outcomes; `version` bumped 6.0.0 →
  6.1.0.

## [6.0.0] - 2026-05-06

**Three-layer overlay redesign — TK on top of `superpowers` + `get-shit-done`,
plus optional external tools.**

### Added

- **Advisory hooks** (PR #43) — four opt-in Claude Code hooks under
  `templates/global/hooks/` that nudge toward the right tool at the right phase
  without ever blocking:
  - `tk-pre-gsd-plan-council.sh` (UserPromptSubmit) — suggests `/council` when
    `/gsd-plan-phase` touches auth/payments/security/db-migration keywords.
  - `tk-post-gsd-phase-audit.sh` (Stop) — suggests `/audit security && /audit code`
    after `/gsd-execute-phase` completes.
  - `tk-pre-ship-reality-check.sh` (PreToolUse Bash) — reminds reality-check
    skill before push to main / vercel/netlify/fly/kubectl deploy.
  - `tk-cost-warning.sh` (Stop) — once per session when transcript suggests
    >`TK_COST_WARN_KTOK` (default 200k) tokens consumed.
  - Installer at `scripts/install-hooks.sh` with atomic JSON merge,
    `_tk_owned + _tk_hook_id` markers, `--dry-run`, `--uninstall`.
- **Cost routing** (PR #45) — `scripts/setup-cost-routing.sh` wraps
  `npx -y better-model init` to route Sonnet 4.6 (60% of tasks), Opus 4.7
  (architecture/security), Haiku 4.5 (search/trivial) per slash command.
  Backup + restore on failure; `--uninstall` strips the routing block cleanly.
- **External MCPs in integrations catalog** (PR #45):
  - `morph-fast-tools` (dev-tools) — Fast Apply diffs + warpgrep_codebase_search.
  - `claude-context` (dev-tools) — vector-DB code search via Milvus + OpenAI/Voyage.
  - Catalog grows 21 → 23 entries.
- **New skills** (PR #42) under `templates/base/skills/`:
  - `production-observability`, `reality-check`, `cost-routing-discipline`,
    `gsd-mode-selector`, `domain-expert-simulation`.
- **New rules** (PR #42) auto-loaded every session:
  - `cost-discipline.md`, `non-programmer-safeguards.md`, `three-layer-bridge.md`.
- **New components** (PR #42) — `production-observability`, `cost-discipline`,
  `vendor-risk`, `domain-expert-simulation`, `large-codebase-search`,
  `external-tools-recommended`.
- **`/vendor-audit` slash command** (PR #42) — quarterly external dependency
  risk review (GSD, Superpowers, Morph, better-model, claude-context).
- **Architecture docs** (PR #46) — `docs/architecture.md` (three-layer
  diagram + runtime composition matrix); `docs/non-programmer-mode.md`
  (recommended setup + cost expectations for solo founders).

### Changed

- **Trimmed duplicates with GSD/Superpowers** (PR #41) — removed 26 commands,
  9 components, 2 base skills (testing + debugging — covered by Superpowers
  TDD + systematic-debugging), 2 templates (nextjs covered by GSD
  skills-marketplace; nodejs merged into base). Net deletion: ~28k LOC.
- **Trimmed framework templates** (PR #44) — removed 32 framework template
  files (byte-identical to base or stale copies). Each of
  `templates/{laravel,rails,python,go}/` shrinks 23-25 → 16 files.
  `init-claude.sh` framework→base fallback chain handles the missing files.
  -8.7k LOC.

### Migration

Existing v5.x users on `complement-sp` / `complement-full` will see hard-
deleted files vanish on next `/update-toolkit` — intended. Run
`scripts/migrate-to-complement.sh` if you were on `standalone` and now have
SP+GSD installed; otherwise no manual migration. `install-hooks.sh` and
`setup-cost-routing.sh` are opt-in and never auto-run.

## [5.0.0] - 2026-05-06

**Per-MCP Scope + Project Secrets Boundary** — give the user granular per-MCP
scope control (`user` vs `project`) with sensible per-MCP defaults baked into
the catalog, treat secrets correctly per scope (`~/.claude/mcp-config.env` for
user-scope, `<project>/.env` + `${VAR}` substitution in `.mcp.json` for
project-scope, never literal secrets in shared files), close the secrets-leak
gap on uninstall (per-MCP keys + full-toolkit `mcp-config.env` cleanup
prompts; project `.env` files never touched), add Calendly to the catalog,
and explicitly NOT add a Google Workspace MCP — claude.ai's built-in
Gmail/Calendar/Drive connectors already cover that surface.

### v4.9 → v5.0 rationale

Per-row MCP scope was originally a v4.9 follow-up — the v4.9 close shipped a
single global `s` toggle (commit `fc000d5`, Phase 37) that flipped scope for
the whole picker at once. User testing surfaced the friction: solo
developers want a personal-tooling MCP (`context7`, `notebooklm`) installed
once on their machine and a per-app infra MCP (`supabase`, `stripe`) wired
into a single project's repo. One global flip makes the second case noisy.

The v5.0 release reframes the global toggle as a "set all" convenience and
adds per-row indicators (`[U]`/`[P]`/`[L]`) plus a per-row hotkey. The
implementation grew enough to warrant a major bump because it changes the
secrets-handling boundary itself: user-scope keys still live in
`~/.claude/mcp-config.env` (mode 0600), but project-scope writes land in
`<project>/.env` (mode 0600, with `.gitignore` guard) while `.mcp.json`
inside the repo carries only `${VAR}` substitution form — never literal
values. Defense-in-depth: a literal-secret refusal regex (`^\$\{[A-Z_][A-Z0-9_]*\}$`)
guards every code path that writes to `.mcp.json`. Uninstall gains paired
`[y/N]` cleanup prompts for residual secrets; project `.env` files are
**never** touched by `uninstall.sh`. The v4.9 behavior remains the
default for users who never reach for the per-row toggle.

### Added — Catalog schema: `default_scope` (Phase 36)

- **`default_scope: "user"|"project"` field** on every `components.mcp.<name>`
  block in `scripts/lib/integrations-catalog.json` (SCOPE-01). Personal-tooling
  MCPs default `user`: `firecrawl`, `notebooklm`, `notion`, `youtrack`,
  `context7`, `openrouter`, `figma`, `playwright`, `magic`, `sentry`,
  `calendly`. Per-app infra MCPs default `project`: `supabase`, `cloudflare`,
  `stripe`, `slack`, `resend`, `aws-cost-explorer`, `aws-cloudwatch-logs`,
  `jira`, `linear`, `telegram` (SCOPE-02).
- **Validator enforcement** — `scripts/validate-integrations-catalog.py` fails
  when any MCP entry omits `default_scope` or carries an invalid enum value;
  wired into `make validate-catalog` and the `make check` quality gate.
- **Backward-compat fallback** — `mcp_catalog_load` in `scripts/lib/mcp.sh`
  silently treats absence as `user` (SCOPE-03). Pre-v5.0 catalogs and
  pre-v5.0 user installs continue to work without warnings.

### Added — Project secrets library `scripts/lib/project-secrets.sh` (Phase 37)

New library owns the project-scope secrets boundary end-to-end:

- **`project_secrets_write_env <project_root> <KEY> <VALUE>`** writes
  `KEY=VALUE` to `<project>/.env`, mode 0600 enforced via `touch && chmod
  0600` BEFORE first write. Idempotent merge: if `KEY` exists, prompts
  `[y/N] Overwrite KEY in <project>/.env?` reusing the v4.3 UN-03 contract
  (`< /dev/tty`, fail-closed N) (SEC-01, SEC-02).
- **`project_secrets_ensure_gitignore <project_root>`** appends `.env\n`
  with leading toolkit comment when `<project>/.gitignore` lacks an exact
  `^\.env$` line; idempotent on re-run; never matches `*.env` or `# .env`
  as "present"; creates `.gitignore` if missing (SEC-03).
- **`project_secrets_render_mcp_env_block <KEY1> <KEY2> ...`** returns the
  JSON object string `{"KEY1": "${KEY1}", "KEY2": "${KEY2}"}` for
  embedding into `.mcp.json` as the `env` field — `claude` resolves the
  vars from the environment at MCP launch (SEC-04).
- **Defense-in-depth literal-secret refusal** — any code path that writes
  to `.mcp.json` refuses string values that don't match
  `^\$\{[A-Z_][A-Z0-9_]*\}$`. Refusal returns rc=1 with `✗ refusing to
  write literal value into .mcp.json (use ${VAR} substitution)` to stderr.
  `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` test seam exists for hermetic
  tests only and prints a one-line warning when honored (SEC-05).
- **Metacharacter rejection** — `project_secrets_write_env` rejects values
  containing `$`, backtick, backslash, double-quote, single-quote, or
  newline. Same allow-list as `_mcp_validate_value` in `mcp.sh` — shared
  helper across the secrets boundary (SEC-06).
- **Test contract** — new `scripts/tests/test-project-secrets.sh` with
  ≥18 hermetic, idempotent assertions covering all six SEC contracts.
  PASS=42 at ship.

### Added — Wizard dispatch integration (Phase 38)

`mcp_wizard_run` in `scripts/lib/mcp.sh` learns per-MCP scope routing:

- **`TK_MCP_SCOPE=project` branch** — wizard collects each env-var via the
  existing v4.6 hidden-input prompt loop, calls `project_secrets_write_env`
  per key (writes real values to `<project>/.env` mode 0600), calls
  `project_secrets_ensure_gitignore` once before the first write, and
  invokes `claude mcp add --scope project ...` with the env block rendered
  as `${VAR}` substitution form — never literal values. SEC-05 verifier
  refuses any literal in the resulting `.mcp.json` (DISP-01).
- **`TK_MCP_SCOPE=user` (or unset) branch** preserves v4.6/v4.9 behavior
  byte-identically: keys land in `~/.claude/mcp-config.env` via
  `mcp_secrets_set`, `claude mcp add --scope user ...` is invoked with
  literal env values exported via `env KEY=V`. No regression on existing
  user-scope flow (DISP-02).
- **Defer-secrets path extension** — `TK_MCP_DEFER_SECRETS=1` with
  `TK_MCP_SCOPE=project` pre-creates blank stub entries in
  `<project>/.env` (not `mcp-config.env`), triggers
  `project_secrets_ensure_gitignore` once before the first stub write.
  Deferred queue tuple grows from 3 to 4 fields
  (`name\tkeys\tinstall_args\tscope`) so the post-install summary can print
  scope-correct hints (DISP-03).
- **Post-install summary printer** — prints per-MCP scope alongside the
  existing keys-needed list. Project-scope rows additionally print
  `→ Edit <project>/.env to fill values; ensure .env is in your .gitignore
  (we appended it).` (DISP-04).
- **Tests** — `scripts/tests/test-mcp-wizard.sh` extended from PASS=14 to
  PASS=53 with DISP-01/02/03 happy paths and the DISP-04 summary-line
  assertion. `scripts/tests/test-mcp-secrets.sh` extended with the shared
  `_mcp_validate_value` boundary scenarios from SEC-06.

### Added — TUI per-row scope toggle (Phase 39)

- **Per-row scope indicator** — each MCP row in the integrations TUI
  carries a scope indicator (`[U]`, `[P]`, or `[L]`) immediately after the
  checkbox; the chosen scope is colored green when color is enabled.
  `NO_COLOR=1` produces plain bracket form per [no-color.org](https://no-color.org)
  (TUI-SCOPE-01).
- **Per-row hotkey** — pressing the per-row scope hotkey on a highlighted
  row cycles only that row's scope (`U → P → L → U`); other rows are
  unaffected. Binding documented in the TUI hint footer (TUI-SCOPE-02).
- **Global `s` repurposed as "set all"** — the v4.9 Phase 37 (`fc000d5`)
  global toggle is repurposed: pressing `s` cycles a global scope value
  and assigns it to every visible row in one stroke. Banner now reads
  `s: set all to <scope>` (TUI-SCOPE-03).
- **`MCP_SELECTED_SCOPE[]` parallel array** — Bash 3.2-compatible state
  parallel to `MCP_NAMES`/`MCP_STATUS`/`MCP_HAS_CLI`, initialized from
  each entry's `default_scope` via `mcp_status_array`. No associative
  arrays, no `mapfile`, no `${var,,}` (TUI-SCOPE-04).
- **Per-row dispatch** — the `install.sh` MCP install loop reads
  `MCP_SELECTED_SCOPE[$i]` per row and exports `TK_MCP_SCOPE=<scope>` for
  that single `mcp_wizard_run` invocation. The pre-v5.0 single-shell
  `TK_MCP_SCOPE` global is retired in favor of per-call injection
  (TUI-SCOPE-05).
- **`--mcp-scope=user|project|local` CLI flag** — non-interactive
  force-set still honored (`TK_MCP_SCOPE_CLI` broadcasts into every
  `MCP_SELECTED_SCOPE[]` slot). Invalid values exit 2 with a clear
  error.
- **Tests** — `scripts/tests/test-mcp-selector.sh` extended from PASS=21
  to PASS=36 with TUI-SCOPE-01..05 scenarios.

### Added — Uninstall secret cleanup (Phase 40)

- **Per-MCP secret cleanup** — `uninstall_prompt_mcp_keys <name>
  [<key>...]` helper in `scripts/uninstall.sh`. Reads keys for the named
  MCP from the catalog and prompts `[y/N] also remove keys K1, K2 from
  ~/.claude/mcp-config.env?` via `< /dev/tty` (fail-closed N on no-TTY,
  mirrors v4.3 UN-03). On Y: atomic `mktemp + mv + chmod 0600` rewrite
  drops only the named MCP's keys; other MCPs' entries preserved
  byte-identically. Mode 0600 enforced before AND after rewrite
  (UN-SEC-01). Called immediately after each toolkit-driven `claude mcp
  remove <name>` (UN-SEC-02).
- **Full-toolkit secret cleanup** — full uninstall now prompts ONCE about
  the entire `~/.claude/mcp-config.env`: `[y/N] also remove
  ~/.claude/mcp-config.env (X keys for Y MCPs)?` via `< /dev/tty`
  (fail-closed N). On Y the file is deleted before the LAST-step
  `STATE_FILE` removal (v4.3 UN-05 D-06 ordering preserved). The base-plugin
  `diff -q` invariant still runs and still wins (UN-SEC-03).
- **Project `.env` files NEVER touched** — `uninstall.sh` is now an
  explicit contract: project `.env` files outside `~/.claude/` are never
  opened or modified. Verified by hermetic filesystem-fingerprint diff in
  `test-uninstall-state-cleanup.sh`. Documented in `--help` output and
  `docs/INSTALL.md` (UN-SEC-04).
- **`--keep-state` implies `--keep-secrets`** — passing `--keep-state` (or
  `TK_UNINSTALL_KEEP_STATE=1`) preserves both the per-MCP and full-toolkit
  secret-cleanup paths along with the existing state file. Documented in
  `--help` and `docs/INSTALL.md` (UN-SEC-05).
- **Tests** — `scripts/tests/test-uninstall-state-cleanup.sh` extended
  with UN-SEC-01-Y/N branches, UN-SEC-03-Y/N branches, UN-SEC-04 negative
  fingerprint diff, UN-SEC-05 `--keep-state` preservation.

### Added — Calendly MCP (INT-13)

- **`calendly`** — official Calendly MCP server
  (`developer.calendly.com/calendly-mcp-server`). Added to the catalog with
  `display_name: "Calendly"`, `category: "workspace"`, `unofficial: false`,
  `default_scope: "user"`, `requires_oauth: true`. CLI block omitted (no
  companion CLI). Catalog count: 20 → 21 entries.

### Removed — Google Workspace MCP locked out (INT-14)

The catalog explicitly does **not** add a `google-workspace` MCP. Decision
logged in `.planning/PROJECT.md` Key Decisions and here: claude.ai's built-in
Gmail/Calendar/Drive connectors already cover that surface. Adding a
community wrapper would duplicate Anthropic's official OAuth flow and break
under upstream API changes. Re-evaluate only if Anthropic deprecates the
connectors (`INT-FUT-05`).

### Added — Distribution + docs (Phase 41)

- **`manifest.json` 4.9.0 → 5.0.0** with `scripts/lib/project-secrets.sh`
  registered under `files.libs[]` (alpha-ordered between `optional-plugins.sh`
  and `skills.sh`). `update-claude.sh` auto-discovers via the v4.4 LIB-01
  D-07 jq path — zero code changes (DIST-01).
- **`init-claude.sh --version` and `init-local.sh --version` print
  `5.0.0`** derived from manifest at runtime per v4.3 D-22. 3 plugin.json
  files (`tk-skills`, `tk-commands`, `tk-framework-rules`) bumped from
  4.8.0 → 5.0.0. `make version-align` green (DIST-02).
- **`docs/INTEGRATIONS.md` Per-MCP Scope section** — documents `[U]`/`[P]`/
  `[L]` semantics, where each scope's secrets live (`mcp-config.env` vs
  `<project>/.env`), the `${VAR}` substitution convention in `.mcp.json`,
  the `.gitignore` guard, and worked examples for both user-scope and
  project-scope flows (DOCS-01).
- **`docs/INSTALL.md` Installer Flags table** gains a row for
  `--mcp-scope=user|project|local` (DOCS-02). README "Killer Features"
  grid mentions per-MCP scope control as a v5.0 highlight.
- **`docs/INSTALL.md` Uninstall section** documents the new secret-cleanup
  prompts (per-MCP `[y/N]` and full-toolkit `[y/N]`), the explicit
  "project `.env` never touched" contract, and the `--keep-state` implies
  `--keep-secrets` rule (DOCS-03).

### Carry-over from v4.9 close (Phase 36-A polish)

The following Phase 36-A polish items were authored on the v4.9 release
branch and ship as part of v5.0:

- **MCP install↔reinstall toggle** — Space on a row already showing
  `[installed ✓]` toggles to `[reinstall ↻]` (light-green ANSI `\e[92m`).
  Submit calls `claude mcp remove` then re-adds via `mcp_wizard_run`.
  `TUI_REINSTALLABLE[]` opt-in defaults to 0; skills surface unaffected.
- **Install transcript polish** — silenced `claude mcp add` chatter via
  unified stderr+stdout capture wrapper; recolored `skipped` rows grey
  (was yellow); dropped duplicate "Integrations Install Summary" matrix
  table (-154 LOC in `lib/mcp.sh`); dropped trailing key-rotation explainer
  plus "To remove an MCP" line; renamed `To remove:` → `To uninstall:` in
  the completion banner across 4 producers.
- **mktemp template suffix collision on macOS BSD** —
  `mcp-catalog-XXXXXX.json`, `integrations-catalog-XXXXXX.json`,
  `gsd-installer.XXXXXX.sh` reduced to plain X-run templates; BSD mktemp
  refused trailing chars and produced `mkstemp failed: File exists` on
  second invocation.
- **`test-mcp-wizard.sh`** — swapped removed `sequential-thinking` to
  `playwright`.
- **CI** — `actions/checkout` bumped from `v4` (Node 20) to `v6.0.2` (Node
  24) per [GitHub deprecation notice](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/).

### Migration

- Existing v4.x users — re-run `update-claude.sh` to pick up the new
  `project-secrets.sh` lib via the v4.4 LIB-01 D-07 auto-discovery path.
  No manual fetch, no manifest edit, no code change.
- Pre-v5.0 user-scope MCPs in `~/.claude/mcp-config.env` stay where they
  are. Backward-compat fallback (SCOPE-03) ensures pre-v5.0 catalogs
  without `default_scope` continue to work — the loader silently treats
  absence as `user`.
- To move an existing user-scope MCP to project-scope: re-run the
  toolkit's MCP wizard, flip the row's scope indicator with the per-row
  hotkey, and submit. The wizard writes to the project's `.env` and
  registers `claude mcp add --scope project ...` with `${VAR}` substitution
  form; the user-scope entry can be removed via `claude mcp remove --scope
  user <name>` afterwards.
- No interactive migration prompt — pre-v5.0 installs continue to work
  unchanged. Out-of-scope: encrypt `mcp-config.env` at rest, auto-rotate
  secrets, Windows-native scope semantics (carry-over per
  REQUIREMENTS.md).

## [4.9.0] - 2026-05-02

Major install UX overhaul on top of 4.8.x — focused on PR #28 install run on
macOS and a series of user reports between 2026-05-01 and 2026-05-02.

Phases 32-35 (Integrations Catalog) consolidated v4.9 around a unified
MCP + companion-CLI install page. See [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md)
for the full reference.

### Added — Integrations Catalog (Phases 32-35)

Unified MCP + CLI install page accessible via `--integrations` (or the
deprecated `--mcps` alias). Replaces the old MCP-only page.

- **20 MCP servers across 10 categories** — `docs-research`, `backend`,
  `payments`, `email`, `workspace`, `project-management`, `communication`,
  `design`, `dev-tools`, `monitoring`. The TUI groups entries by category
  in canonical order; categories with zero entries silently skip.
- **8 companion CLIs** — install the official command-line tool for the
  same vendor alongside the MCP server. Cross-platform via `uname -s`
  dispatch (`brew install` on Darwin, vendor user-space tarball or
  `npm install -g` on Linux). NEVER auto-prefixes `sudo`. Brew-absent on
  Darwin yields a single-line hint and rc=3 — toolkit never auto-installs
  Homebrew.
- **Per-component status detection** — TUI shows `[MCP:✓ CLI:—]` per
  row (✓ installed, ✗ absent, ⊘ unknown, — n/a). MCP probe via
  `claude mcp list` (cached once per shell, ~4s); CLI probe via
  `command -v` (sub-millisecond, no cache).
- **`unofficial: true` confirm gate** — community / browser-automation
  entries (`notebooklm`, `telegram`) get a yellow `!` glyph in the TUI
  and a `[y/N]` confirm prompt before install. Default N (fail-closed
  per UN-03 contract). `--yes` does NOT bypass this prompt — security
  boundary. `ALWAYS_YES=1` env override bypasses (trusted automation).
- **`--mcp-only` / `--cli-only` mutex flags** — install only the MCP side
  or only the CLI side of selected entries. Mutually exclusive (passing
  both exits with rc=2 + stderr "mutually exclusive").
- **Closing summary table** — Entry × MCP × CLI matrix with per-component
  glyphs, Notes column for skip reasons, and `Installed: N MCPs, M CLIs ·
  Skipped: X · Failed: Y` total line.

### Added — 12 new integrations (INT-01..12)

- **Backend**: `supabase` (MCP+CLI), `cloudflare` (MCP+wrangler),
  `aws-cost-explorer` (MCP+`aws`), `aws-cloudwatch-logs` (MCP+shared
  `aws` CLI — installer detects shared dependency, installs `aws` once
  per session)
- **Payments**: `stripe` (MCP+CLI)
- **Project Management**: `youtrack`, `linear`, `jira` (MCP only)
- **Design**: `figma` (MCP only)
- **Communication**: `slack` (MCP), `telegram` (MCP, unofficial)
- **Docs/Research**: `notebooklm` (MCP, unofficial)

### Added — CLI installer library (`scripts/lib/cli-installer.sh`)

Public primitives consumed by the integrations TUI dispatch loop:

- `cli_detect <name>` — `command -v` wrapper, no caching, sub-millisecond.
- `cli_install <name> <darwin_cmd> <linux_cmd>` — `uname -s` dispatch
  with `TK_CLI_UNAME` test seam. Brew-absent fallback (rc=3) on Darwin
  via `TK_CLI_BREW_BIN` seam. NO sudo auto-prefix EVER (D-17). Trusts
  the curated catalog input (validator-enforced shape) so `eval` is
  safe inside that boundary.
- `cli_post_install_hint <hint>` — writes `→ Next: <hint>` to stderr
  ONLY (stdout stays parseable). Toolkit NEVER auto-runs `<tool> login`
  — boundary is "config + hints", not "auth flows".

### Added — Schema validator + 3 hermetic test suites

- **Validator** `scripts/validate-integrations-catalog.py` (Python stdlib
  only, no `jsonschema` dependency, Python 3.8+). Wired into `make
  validate-catalog` and CI's `validate-templates` job.
- **Test 45** `scripts/tests/test-integrations-catalog.sh` (PASS=14,
  floor 10): schema-only checks for catalog file — `schema_version=2`,
  10 categories, 20 MCP entries, 8 CLI entries, required fields,
  unofficial set is exactly `{notebooklm, telegram}`, no
  `sequential-thinking`, no `sudo` token in any install string.
- **Test 46** `scripts/tests/test-cli-installer.sh` (PASS=24, floor 8):
  primitives test for `cli_detect` / `cli_install` / `cli_post_install_hint`
  with `TK_CLI_UNAME` + `TK_CLI_BREW_BIN` seams.
- **Test 47** `scripts/tests/test-integrations-tui.sh` (PASS=36,
  floor 15): Phase 34 TUI redesign assertions — category-grouped
  rendering, unofficial glyph, parallel-array length, mocked claude
  flow, `unofficial_confirm` ALWAYS_YES + TTY paths,
  `--mcp-only`/`--cli-only` mutex, summary table format, zero-entry
  category skip via fixture catalog.

### Added — `docs/INTEGRATIONS.md`

Complete catalog reference with category-grouped tables, install flow,
unofficial semantics, OAuth setup links per entry, troubleshooting, and
a dedicated **Global vs per-project** section establishing the
toolkit/SDK boundary (DOCS-02): catalog ships globals only, never
per-project SDKs.

### Changed — Schema migration (CAT-01..03)

- `scripts/lib/mcp-catalog.json` → `scripts/lib/integrations-catalog.json`
  (`schema_version: 2`). New top-level structure: `categories[]`,
  `components.mcp{}`, `components.cli{}`. 8 surviving Phase 32 entries
  (`context7`, `firecrawl`, `magic`, `notion`, `openrouter`, `playwright`,
  `resend`, `sentry`) tagged with category. Optional CLI blocks added to
  `firecrawl`, `playwright`, `sentry` whose CLIs add real value.
- `scripts/lib/mcp.sh` rewritten to read schema v2 — `mcp_catalog_load`,
  `mcp_categories_load`, `mcp_status_array`, `_mcp_category_display`,
  `unofficial_confirm`, `print_integrations_summary`. Bash 3.2 parallel
  arrays only (`MCP_NAMES[]`, `MCP_CATEGORY[]`, `MCP_UNOFFICIAL[]`,
  `TUI_GROUPS[]`, etc.).
- `scripts/install.sh` adds `--integrations`, `--mcp-only`, `--cli-only`,
  `--mcps` (deprecated alias) flags + dispatch loop with per-row
  unofficial-confirm gate, MCP-side dispatch, CLI-side dispatch via
  `cli_install`, summary table renderer.

### Changed — `--mcps` flag deprecated

`--mcps` continues to work as an alias for `--integrations` but prints a
one-line stderr deprecation note: `⚠ --mcps is deprecated; use
--integrations (alias retained until v6.0)`. Alias removal is post-v5.0.

### Changed — `manifest.json` 4.8.0 → 4.9.0

`files.libs[]` registers `cli-installer.sh` and `integrations-catalog.json`
(replacing `mcp-catalog.json`); `files.scripts[]` registers
`validate-integrations-catalog.py`. `update-claude.sh` auto-discovers
all three via the existing v4.4 LIB-01 D-07 jq path — no script code
changes required for smart-update coverage.

### Changed — `init-claude.sh --version` parity with `init-local.sh`

Added `--version` / `-v` flag to `init-claude.sh` deriving version from
manifest at runtime (v4.3 D-22 contract). Reads local manifest when run
from a clone; curls `$REPO_URL/manifest.json` when run via `curl | bash`.
Both installers now print `claude-code-toolkit v4.9.0` on `--version`.

### Removed — `sequential-thinking` (DROP-01)

Removed from catalog. Native Claude extended thinking covers the use case
adequately. Existing user installs are unaffected — toolkit doesn't
auto-uninstall MCPs when the catalog drops them (boundary preserved).
Users with `sequential-thinking` in their `claude mcp list` keep the
server registered until they manually `claude mcp remove sequential-thinking`.

### Migration notes

Users on v4.8 → v4.9: re-run `update-claude.sh` to pick up the new lib,
script, and JSON catalog. No manual catalog re-fetch needed; the
v4.4 LIB-01 D-07 jq-path auto-discovery handles all three.

### Added — Back navigation in multi-step picker flow (UX-FLOW-02)

Press `b` (or `B`) inside the skills or MCP sub-picker to return to the
previous step. Skills picker → main TUI; MCP picker → skills picker (or
main TUI if skills wasn't selected). Previously selected items are
re-checked when re-entering a picker via Back. Gated on
`TK_TUI_ALLOW_BACK=1`. Footer hint shows `· b back` only in multi-step mode.

### Added — MCP secrets deferred (registered without API key during install)

Mid-install API-key prompts caused users to abandon the flow. New
`TK_MCP_DEFER_SECRETS=1` mode (default during dispatch): MCPs needing env
keys are registered with `claude mcp add` *without* env vars (so they
appear in `claude mcp list` with empty env binding), keys queued in
`~/.claude/mcp-config.env` as empty stubs (mode 0600), and a one-time
shell-rc auto-source line is appended to `~/.zshrc` / `~/.bash_profile` /
`~/.bashrc` (idempotent via marker comment). User fills mcp-config.env,
opens fresh terminal, launches claude — MCPs pick up keys at startup.
No re-registration when keys change later.

Status row reads `installed (needs API key)` (yellow). Post-summary
follow-up block prints a 3-step recipe.

### Added — Tooltip / banner colors switched to CYAN

Sweep `${BLUE}` → `${CYAN}` across `init-claude.sh`, `install.sh`,
`init-local.sh`, `update-claude.sh`. Dark-blue text was unreadable on
macOS Terminal default dark theme.

### Changed — Atomic TUI render eliminates flicker AND bleed-through

`_tui_render` builds the entire frame as a single string and writes to
the TTY in ONE printf. Solves both flicker (per-line printfs caused
visible repaints between syscalls) and bleed-through (gap lines retained
content from prior frames). Atomic write + `\e[H\e[J` at frame start.

### Changed — Install order: skills BEFORE mcp-servers

`TK_DISPATCH_ORDER` reordered so the MCP "needs API key" follow-up block
ends the screen. Main TUI marketplace section + pre-collection sub-pickers
also reordered.

### Changed — Skills install summary uses soft-checkmark style

Bright-green right-aligned `installed ✓` rows replaced with a leading
`✓ name` row (matching `init-claude.sh`'s "📥 Framework extras..." style).
Failures render `✗ name — reason` in red. Dry-run keeps the literal
`would-install` token (tests parse it).

### Changed — Consolidated install finale at top-level

Sub-installers run with `TK_DISPATCHED=1` and suppress their standalone
finale (recommend_security/statusline/optional_plugins, "Verify",
"Restart Claude Code", POST_INSTALL note). Parent `install.sh` emits ONE
consolidated finale AFTER all dispatchers complete.

### Changed — Project-local skill stubs deduplicated against marketplace

Removed `ai-models`, `tailwind`, `i18n` from every framework template
(base + nodejs + go + python + laravel + rails + nextjs). Each
`skill-rules.json` updated. ~4685 lines deleted. Marketplace versions
(`ai-models`, `tailwind-design-system`, `i18n-localization`) cover the
same ground. Kept project-local stubs unique to the toolkit:
`api-design`, `council-integration`, `database`, `debugging`, `docker`,
`llm-patterns`, `observability`, `testing`.

### Fixed — Esc detection on macOS Terminal / iTerm2

`tui_checklist` case match extended from `$'\e')` to
`$'\e' | $'\e\e' | $'\e\e\e')`. macOS Terminal + iTerm2 "Send +Esc"
config emits 2-3 bytes per Esc keypress; the read-ahead window catches
them. Previous single-arm match dropped these into `*) ignore` and
"Esc did nothing". Footer text changed `Esc cancel` → `Ctrl+C abort`.

### Fixed — `claude mcp list` cached once per install

`mcp_status_array` previously called `claude mcp list` 9 times (once per
MCP catalog entry) for ~40 s on macOS. New `_mcp_list_cache_init`
function memoizes once per shell. Visible "Loading MCP catalog..."
banner added.

### Fixed — Sub-pickers run in main process (no subshell)

UX-FLOW-01 originally captured sub-picker output via subshell `$()`.
On macOS the TUI library's stty/cursor-hide sequences plus captured-stdout
fd combination left the post-Submit screen frozen. Sub-pickers now run
in the main process with `_save_main_tui_state` / `_restore_main_tui_state`
helpers.

### Fixed — Mid-install banner suppressed in dispatch mode

`init-claude.sh` invoked from `install.sh` dispatch loop printed its
standalone "Installation Complete!" + recommendations block BEFORE
skills/MCP dispatchers ran. `TK_DISPATCHED=1` suppresses it.

### Fixed — `mcp-catalog.json` race-on-mktemp

`--mcps` branch unconditionally re-`mktemp`'d a catalog file even when
the parent UX-FLOW-01 block already exported `TK_MCP_CATALOG_PATH`.
Under heavy `/tmp` churn BSD `mkstemp` gave up with `File exists`.
Guard added.

### Fixed — `gemini-bridge` symlink failure message

Two-line message replaced with 5-line diagnostic naming the symlink
target, explaining *why* we refuse (could clobber another tool's config),
and printing the literal `rm <path>` command to fix it.

### Changed — Pre-collect all TUI selections before installing (UX-FLOW-01)

Previously the install flow was: main TUI → Submit → run toolkit / security /
etc. → 20 s pause → MCP sub-picker → Submit → install MCPs → skills sub-picker
→ Submit → install skills. The mid-install sub-pickers felt like a hang and
broke the user's mental model of "answer questions, then watch the install".

New flow: main TUI → Submit → MCP sub-picker (if `mcp-servers` row checked)
→ Submit → skills sub-picker (if `skills` row checked) → Submit → THEN the
dispatch loop runs end-to-end with no further prompts.

Implementation: `install.sh` collects MCP / skills selections in subshells
(so the main TUI globals aren't clobbered) right after the bridge plumbing
block. Selections are exported as `TK_MCP_PRE_SELECTED` / `TK_SKILLS_PRE_SELECTED`
comma-separated lists. The `--mcps` and `--skills` branches honour these
env vars: when set (even empty), they skip their own TUI render and build
`TUI_RESULTS` directly from the pre-collected list. Empty value (`TK_MCP_PRE_SELECTED=""`)
is meaningful — "user opened the picker, picked nothing, hit Submit" — and
results in a headless install of zero items rather than falling back to a
TUI that would reopen mid-install.

Cancel semantics preserved: pressing Esc / Ctrl-C in the MCP or skills sub-
picker aborts the entire install (no partial component install).

New regression test `scripts/tests/test-flow-prequestions.sh` (8/8 PASS):
asserts pre-selected env produces exactly the named items, empty env produces
zero items, and unset env falls back to the legacy `--yes` default-set path.

### Fixed — Invisible-prompt regression (TUI dispatch)

After a user pressed Submit on the main TUI, `init-claude.sh` ran under
`install.sh`'s D-28 stderr-capture wrapper (`( dispatch_toolkit ) 2>"$tmp"`).
Bash's `read -p "prompt"` writes the prompt to **stderr**, so the bridge
install prompt (`Gemini detected. Create GEMINI.md → CLAUDE.md bridge?
[Y/n]:`) landed in the captured tmpfile and the user saw a bare blinking
caret with no instruction.

Two-layer fix:

1. **Structural:** new `tui_tty_read` helper in `scripts/lib/tui.sh` writes
   the prompt directly to the TTY device (not stderr), immune to parent
   stderr capture. Refactored 5 call sites — `lib/tui.sh:tui_confirm_prompt`,
   `lib/bridges.sh` × 2 (drift overwrite, install prompt),
   `lib/bootstrap.sh:_bootstrap_prompt_and_run`, `lib/mcp.sh` × 2 (overwrite,
   secret-key entry). Helper supports a `TK_TUI_PROMPT_SINK` regression-test
   seam and char-device detection so legacy regular-file / process-
   substitution test seams continue to work without truncating answers.
2. **UX:** `install.sh` plumbs the TUI bridge selection (rows 8/9) into
   `init-claude.sh` via `BRIDGES_FORCE` / `TK_NO_BRIDGES` env vars. When the
   user selects bridges in the main TUI, `bridge_install_prompts` takes its
   non-interactive force path (no second prompt). When the user leaves the
   bridge rows unchecked, `TK_NO_BRIDGES=1` silences project-bridge prompts
   entirely. Manual `--bridges <list>` / `--no-bridges` overrides still work
   when invoked outside the TUI flow.

`tui.sh` is now downloaded by `init-claude.sh` and `update-claude.sh` BEFORE
`bridges.sh` / `bootstrap.sh` / `mcp.sh` so their lazy-source guard
(`command -v tui_tty_read`) reports defined and the per-lib `BASH_SOURCE`
fallback (which fails under curl|bash because libs live in `/tmp/<lib>`
without sibling files) is skipped.

New regression test `scripts/tests/test-invisible-prompt.sh` (14/14 PASS):
asserts prompts never reach captured stderr, exercises both the helper unit
and the real bridge / mcp paths under a stderr-capture wrapper. All existing
suites still pass (test-bridges-sync 25/0, test-mcp-secrets 11/0,
test-bridges-install-ux 20/0, test-bootstrap 26/0, test-install-tui 52/0).

### Audit Sweep 260430-go5 (PR #15) — 18 findings + dead-code

Deep 4-agent audit (security, code-review, infra/CI, shell) on 2026-04-30.
1 finding withdrawn as false positive (Read-tool render artifact). Cross-checked
against parallel Gemini audit which caught 1 additional dead-code item.

#### Fixed — High

- **H1** — `install.sh` dispatch index mismatch installed wrong bridge under
  Codex-only scenario (`IS_GEM=0 IS_COD=1`). Now uses name-based lookup with
  `_local_label_to_dispatch_name()` helper. New regression test
  `scripts/tests/test-install-dispatch-h1.sh` (6/6 PASS).
- **H3** — `setup-security.sh` silently skipped RTK.md install under
  `bash <(curl ...)` because `dirname $0` resolved to `/dev/fd`. Curl-pipe
  detection added with download fallback.
- **H4** — `init-claude.sh` echoed Gemini/OpenAI/OpenRouter API keys to terminal
  scrollback (`read -r -p`). Switched 3 sites to `read -rs -p` matching the
  hardened `setup-council.sh` pattern.
- **H5** — Distribution chain hardcoded to mutable `main` ref. New
  `TK_TOOLKIT_REF` env var (default `main`) on all 8 installers +
  `lib/dispatch.sh`. Documented in `docs/INSTALL.md`. Optional
  `TK_TOOLKIT_PIN_SHA256` checksum mode deferred.
- **H6** — `TK_DISPATCH_OVERRIDE_*` env-bash without `TK_TEST=1` gate while
  `eval` siblings already gated by audit C2. Gate parity restored across 6
  dispatchers + 7 test blocks.

#### Fixed — Medium

- **M1** — `install.sh:837` called undefined `log_error` → exit 127 if
  validator triggered. Inlined the error echo.
- **M2** — `uninstall.sh` reclassified empty-installed-sha files from
  `MODIFIED` to `REMOVE` so users no longer get spurious `[y/N/d]` prompts on
  toolkit-owned files they never edited.
- **M3** — Trap regression of audit M6 fix in `propagate-audit-pipeline-v42.sh`
  (line 300) and `lib/bootstrap.sh` (line 67). Now uses `printf %q` quoting
  matching the corrected pattern at `propagate-audit-pipeline-v42.sh:128`.
- **M4** — `install.sh:917,920` empty-array expansion crashed under Bash 3.2
  `set -u`. Switched to `${arr[@]+"${arr[@]}"}` form matching siblings 363/365.
- **M5** — `setup-council.sh:512` `read /dev/tty` killed installer under
  `set -e` with no TTY. Added `|| true` guard matching every other `read`
  in the repo.
- **M6** — `update-claude.sh:1129/1211/1212` bare `mktemp` calls leaked on
  SIGINT — registered to EXIT trap.
- **M7** — `.github/workflows/quality.yml` added `concurrency:`
  cancel-in-progress group; force-push no longer spawns redundant 5-job runs.
- **M8** — `templates/global/statusline.sh` and `rate-limit-probe.sh` now
  early-exit on non-Darwin platforms (BSD-only `stat -f %m` was silently
  misbehaving on Linux).

#### Fixed — Low

- **L1** — `mcp_secrets_load` validates key shape (`^[A-Z_][A-Z0-9_]*$`)
  alongside values.
- **L2** — `install.sh` removed component name from `/tmp` stderr templates
  (3 sites — line 892 also leaked); now mktemp randomness only.
- **L3** — `lib/skills.sh:147` `rm -rf` guarded against `/` and empty target.
- **L4** — Browser `User-Agent` added to all `curl` invocations (project
  global rule §2 violation). New `TK_USER_AGENT` constant in 3 libs +
  inline `-A` injection across 13 scripts. 17 files touched.
- **L5** — `scripts/council/brain.py` sanitizes ANSI/control chars from
  reviewer output before writing to disk (3 sites including `missed_text`).
  Pattern copied from `update-claude.sh:1005-1008`.

#### Withdrawn — false positive

- **H2** — `lib/mcp.sh:85` claimed empty join separator. `xxd` confirmed the
  literal `\x1f` (ASCII 31 unit-separator) byte was already present; Read-tool
  renderer displayed US byte as nothing, fooling the audit agent. Source code
  was correct.

#### Dead code

- **T1** — Removed unused `sha256_any()` helper from
  `scripts/tests/test-uninstall-prompt.sh:65-72` (caught by parallel Gemini
  cross-audit).

## [4.8.0] - 2026-04-29

### Added — Multi-CLI Bridge

- **CLI detection** (`scripts/lib/detect2.sh`) — BRIDGE-DET-01, BRIDGE-DET-02,
  BRIDGE-DET-03: Phase 28. `is_gemini_installed` and `is_codex_installed` probes
  added alongside the existing 6 binary probes from v4.6 Phase 24. Both return
  0/1 binary, fail-soft via `command -v <cli>` with `[ -d ~/.gemini/ ]` /
  `[ -d ~/.codex/ ]` as soft cross-check. `detect2_cache` exports `IS_GEM` and
  `IS_COD`.

- **Bridge generation library** (`scripts/lib/bridges.sh`, 467 lines) —
  BRIDGE-GEN-01, BRIDGE-GEN-02, BRIDGE-GEN-03, BRIDGE-GEN-04: Phase 28.
  `bridge_create_project <target>` writes
  `<project>/GEMINI.md` (gemini) or `<project>/AGENTS.md` (codex) — note this
  is the OpenAI standard, NOT `CODEX.md`. `bridge_create_global <target>` writes
  `~/.gemini/GEMINI.md` / `~/.codex/AGENTS.md` and never touches the canonical
  `CLAUDE.md`. Auto-generated header banner is byte-identical across all
  bridges. Each bridge registers in `~/.claude/toolkit-install.json::bridges[]`
  with `target`, `path`, `scope`, `source_sha256`, `bridge_sha256`,
  `user_owned: false`. Atomic state writes via `tempfile.mkstemp + os.replace`.

- **Sync on update** (`scripts/update-claude.sh`) — BRIDGE-SYNC-01, BRIDGE-SYNC-02,
  BRIDGE-SYNC-03: Phase 29.
  `sync_bridges()` iterates `bridges[]` from state file. Source-drift detection
  (recorded `source_sha256` differs from current) triggers re-copy and SHA
  refresh, logging `[~ UPDATE] GEMINI.md`. Bridge-drift detection (user edited
  the bridge file) triggers `[y/N/d]` prompt with default `N`; `d` shows diff
  and re-prompts (mirrors v4.3 UN-03 contract). Orphaned source (CLAUDE.md
  deleted) logs `[? ORPHANED]` and auto-flips `user_owned: true`.

- **Break/restore bridges** (`scripts/update-claude.sh`) — BRIDGE-SYNC-02:
  Phase 29. `--break-bridge <target>` flips `user_owned: true` for the named
  bridge; subsequent updates skip it with `[- SKIP]`. `--restore-bridge <target>`
  reverses the flag and resumes sync on next update.

- **Uninstall integration** (`scripts/uninstall.sh`) — BRIDGE-UN-01, BRIDGE-UN-02:
  Phase 29. Bridges from `bridges[]` are classified via `classify_bridge_file`
  helper: clean → REMOVE_LIST; user-modified → MODIFIED_LIST with v4.3 `[y/N/d]`
  prompt. `is_protected_path` correctly bypassed for bridges. `--keep-state`
  (v4.4 KEEP-01) preserves `bridges[]` entries alongside the rest of
  toolkit-install.json — no special-case handling needed.

- **Install-time UX** (`scripts/install.sh`, `scripts/init-claude.sh`,
  `scripts/init-local.sh`) — BRIDGE-UX-01, BRIDGE-UX-02, BRIDGE-UX-03,
  BRIDGE-UX-04: Phase 30. The unified TUI
  (`install.sh`) shows conditional `gemini-bridge` / `codex-bridge` rows in
  the Components page when the corresponding CLI is detected; rows hidden
  otherwise. `init-claude.sh` and `init-local.sh` post-install per-CLI prompt
  defaulting `Y`, fail-closed `N` on no-TTY (CI / piped install). All 3 entry
  points support `--no-bridges` / `TK_NO_BRIDGES=1` (skip) and `--bridges
  gemini,codex` (force-create non-interactively). With `--fail-fast`, absent
  CLI exits 1; without, warns and continues.

- **Multi-CLI bridge documentation** (`docs/BRIDGES.md`, `docs/INSTALL.md`,
  `README.md`) — BRIDGE-DOCS-01, BRIDGE-DOCS-02: Phase 31. New `docs/BRIDGES.md` documents
  supported CLIs (Gemini → `GEMINI.md`, OpenAI Codex → `AGENTS.md`),
  plain-copy semantics, drift handling, opt-out (`--no-bridges`,
  `--break-bridge`, `--restore-bridge`), force-create (`--bridges <list>`),
  symlink-vs-copy rationale, uninstall behaviour, future scope. `INSTALL.md`
  Installer Flags table extended with 4 new flag rows. `README.md` Killer
  Features grid mentions multi-CLI bridges.

- **Manifest registration** (`manifest.json`) — BRIDGE-DIST-01: Phase 31.
  `scripts/lib/bridges.sh` added to `files.libs[]` (alphabetized between
  `bootstrap.sh` and `cli-recommendations.sh`). Auto-discovered by
  `update-claude.sh` via the v4.4 LIB-01 D-07 jq path with zero code changes.

### Changed

- **`write_state` arity extended** (`scripts/lib/state.sh`) — Phase 29 D-29-01
  backward-compatible 10-arg variant accepts `bridges_json` as the 10th
  positional. Existing 9-arg callers (`init-claude.sh`, `update-claude.sh`,
  `install.sh`) work unchanged via Bash positional-default semantics.
  `init-local.sh` and `migrate-to-complement.sh` updated to pass the 10th arg.

- **Manifest version** bumped from 4.6.0 to 4.7.0. All 3 plugin manifests
  (`tk-skills`, `tk-commands`, `tk-framework-rules`) bumped in lock-step.

### Fixed

- **Phase 29 WR-01** — uninstall `[y/N/d]` bypass for user-modified bridges
  fixed by routing through existing v4.3 prompt path instead of skipping.

- **Phase 29 WR-02** — state file path mismatch in test fixtures (was using
  `STATE_FILE_HOME` instead of `TK_BRIDGE_HOME`) corrected; all hermetic tests
  now run in fully isolated sandboxes.

- **Phase 30 WR-01** — silent `--bridges <list>` failure when named CLI absent
  without `--fail-fast` now prints a warning to stderr and continues.

### Tests

- 3 new hermetic suites totalling 50 assertions:
  - `scripts/tests/test-bridges-foundation.sh` (5 assertions, Phase 28)
  - `scripts/tests/test-bridges-sync.sh` (25 assertions, Phase 29)
  - `scripts/tests/test-bridges-install-ux.sh` (20 assertions, Phase 30)
- `scripts/tests/test-bridges.sh` (NEW) — aggregator wrapping the 3 suites
  with a single PASS/FAIL summary; wired into CI (`quality.yml`
  test-init-script job).

### Compatibility

- BACKCOMPAT-01 preserved across all v4.6 baselines:
  - `test-bootstrap.sh` PASS=26 unchanged
  - `test-install-tui.sh` PASS=43 unchanged
  - All 7 v4.3 uninstall-suite tests unchanged
  - All v4.6 MCP / Skills / Marketplace tests unchanged

## [4.7.0] - 2026-04-29

### Phase 24 Sub-Phases 2–10 — Council rework

#### Added — Sub-Phase 2 (editable system prompts)

- Externalized Skeptic / Pragmatist / audit-review system prompts to
  `~/.claude/council/prompts/*.md`. brain.py reads them via `load_prompt()`
  and falls back to embedded constants when files are missing.
- Mandatory FP-recheck + Confidence triad + code citation block in every
  verdict per the new prompt template.
- `.upstream-new.md` sidecar pattern preserves user edits on update,
  mirroring `setup-security.sh`.

#### Added — Sub-Phase 3 (context enrichment + redaction)

- Context bundle now includes README head, `.planning/PROJECT.md`,
  recent git log, TODO/FIXME grep, and matching test files for any
  source files Gemini selects in discovery.
- `apply_context_budget()` proportional truncation guards a 200K total
  context cap.
- `redact_context()` strips Stripe live keys, Anthropic `sk-ant-`,
  generic high-entropy hex, and `.env` quoted secrets before sending.
  Patterns live in editable `~/.claude/council/redaction-patterns.txt`.
- `COUNCIL_DEBUG=1` stderr trace shows context block sizes + redaction
  counts.

#### Added — Sub-Phase 4 (cost tracking)

- Append-only `~/.claude/council/usage.jsonl` log of every Council call
  with provider, model, mode, tokens, dollar cost, and verdict.
- `pricing.json` overlays a built-in `DEFAULT_PRICING` table; CLI
  providers cost $0 with chars/4 estimated tokens marked
  `estimated: true`.
- New `/council-stats` slash command renders `--day | --week | --month
  | --total | --since/--until | --csv` summaries from the log.
- Optional `COUNCIL_COST_CONFIRM_THRESHOLD=<usd>` cost gate prompts the
  user before any call whose estimated input cost exceeds the threshold;
  CI / non-TTY runs auto-proceed with stderr warning.

#### Added — Sub-Phase 5 (provider hardening + fallback)

- Codex CLI provider for ChatGPT (mode: cli) using `codex exec --model
  X --config model_reasoning_effort=Y -`.
- `reasoning.effort` pinned to `high` for the gpt-5.2 / o3 family
  (configurable via `config.openai.reasoning_effort`).
- Gemini `thinkingConfig.thinkingBudget=32768` set for the API path.
- OpenRouter free-model fallback chain (`tencent/hy3-preview:free`,
  `nvidia/nemotron-3-super-120b-a12b:free`,
  `inclusionai/ling-2.6-1t:free`, `openrouter/free`) kicks in when the
  primary backend errors. Recorded with `fallback_used: true`.
- `setup-council.sh` wizard now prompts for Codex CLI vs API and
  optional OpenRouter key.

#### Added — Sub-Phase 6 (content-hash cache)

- `~/.claude/council/cache/<key>.json` cache keyed by
  sha256(plan | git_head | cwd). Hits within TTL replay output with a
  `[cached <ts>]` marker and zero provider calls.
- TTL configurable via `config.cache.ttl_days` (default 7).
- `--no-cache` flag bypasses for one run.
- New `/council clear-cache` slash command + `brain clear-cache`
  subcommand.
- Cache hits log a `cache_hit: true` row to `usage.jsonl` so
  `/council-stats` reflects savings.

#### Added — Sub-Phase 7 (GSD integration)

- `templates/base/skills/council-integration/SKILL.md` documents
  the integration patterns for `/gsd-plan-phase --council`,
  `/gsd-execute-phase --council`, and the audit Council pass.
  Verdict-handling rules (PROCEED / SIMPLIFY / RETHINK / SKIP) +
  troubleshooting matrix.
- Skill triggers in `skill-rules.json` + manifest registration.

#### Added — Sub-Phase 8 (QoL features)

- `detect_domain()` classifies the plan into security / performance /
  ux / migration / general from regex on plan keywords.
- 8 persona overlay prompts under
  `templates/council-prompts/personas/`. Non-general domains layer the
  matching `<domain>-skeptic.md` / `<domain>-pragmatist.md` overlay on
  top of the base prompt at every reviewer call site.
- `--dry-run` flag builds the full Skeptic + Pragmatist prompts (with
  context, persona, redaction) and prints them with an estimated cost.
  Exits 0 without API calls.
- `--format json` emits a single-line JSON object
  `{verdict, skeptic, pragmatist, concerns_skeptic[], concerns_pragmatist[],
  domain, plan_hash, git_head, fallback_used: {skeptic, pragmatist},
  cache_hit, ...}` for tooling integration. Cache hits also emit JSON
  with `cache_hit: true`.
- TL;DR auto-summary block at the top of every written
  `council-report.md` carries verdict + top 3 concerns + detected
  domain.
- New `--mode retro --commit <sha>` retrospective review reads the
  commit diff plus the prior Council report and renders ALIGNED /
  DRIFT / UNCLEAR.

#### Added — Sub-Phase 9 (multilingual prompts)

- Russian translations of the four system prompts under
  `templates/council-prompts/ru/`.
- `--lang en|ru|auto` flag (default `auto`). `auto` reads the first
  500 chars of `~/.claude/CLAUDE.md` and switches to ru when the
  Cyrillic ratio exceeds 0.2.
- `load_prompt()` and `load_persona()` lookup order:
  `<lang>/<name>.md` → `<name>.md` → embedded fallback.
- Verdict tokens stay English so the orchestrator's parser remains
  language-agnostic.

#### Added — Sub-Phase 10 (docs + version bump)

- Rewrite of `commands/council.md` covering all new flags and modes.
- New `docs/COUNCIL.md` deep reference: architecture, provider matrix,
  cost considerations, customization (prompt editing, redaction
  patterns, persona prompts, ru locale), MCP integration pointer.
- README "Killer Features" row refreshed; pointer to
  `docs/COUNCIL.md`.
- Manifest version bumped from 4.6.0 to 4.7.0; plugin manifests
  follow.

#### Notes

Sub-Phase 11 (MCP server for Claude Desktop) is in progress on the
same milestone branch and will ship under a subsequent CHANGELOG
entry. Sub-Phase 1 already shipped under [4.5.0] - 2026-04-29.

## [4.6.0] - 2026-04-29

### Added

- **Unified TUI installer** (`scripts/install.sh`) — TUI-01..07, DET-01..05,
  DISPATCH-01..03, BACKCOMPAT-01: Phase 24. Single curl-bash entry point
  rendering an arrow-navigable Bash 3.2 checklist (no Bash 4-only constructs)
  with auto-detect of toolkit / superpowers / GSD / security pack / RTK /
  statusline. `--yes` for CI, `--force` re-runs detected, `--no-color`
  honored, `Ctrl-C` restores terminal cleanly. Foundation libs
  (`scripts/lib/{tui,detect2,dispatch}.sh`) reused by Phases 25-26. Hermetic
  test: `scripts/tests/test-install-tui.sh` (38+ assertions, Test 31).

- **MCP catalog + per-MCP wizard** (`scripts/lib/mcp.sh`,
  `scripts/lib/mcp-catalog.json`) — MCP-01..05,
  MCP-SEC-01..02: Phase 25. Nine curated MCP servers (`context7`, `firecrawl`,
  `magic`, `notion`, `openrouter`, `playwright`, `resend`, `sentry`,
  `sequential-thinking`) browsable via `scripts/install.sh --mcps`. Per-MCP
  wizard collects API keys with hidden input (`read -rs`), persists to
  `~/.claude/mcp-config.env` (mode 0600), invokes `claude mcp add`. Fail-soft
  when CLI absent. Hermetic test: `scripts/tests/test-mcp-selector.sh`
  (Test 32).

- **Skills marketplace mirror** (`templates/skills-marketplace/`,
  `scripts/lib/skills.sh`, `scripts/sync-skills-mirror.sh`) — SKILL-01..05:
  Phase 26. 22 curated skills mirrored from upstream skills.sh (license-audited,
  documented in `docs/SKILLS-MIRROR.md`). `scripts/install.sh --skills`
  copies selected skills to `~/.claude/skills/<name>/` via `cp -R`.
  `manifest.json` registers all 22 under `files.skills_marketplace[]` so
  `update-claude.sh` ships skill updates. Hermetic test:
  `scripts/tests/test-install-skills.sh` (15 assertions, Test 33).

- **Plugin marketplace surface** (`.claude-plugin/marketplace.json`,
  `plugins/tk-{skills,commands,framework-rules}/.claude-plugin/plugin.json`,
  symlink trees) — MKT-01, MKT-02: Phase 27. Three sub-plugins discoverable
  via `claude plugin marketplace add sergei-aronsen/claude-code-toolkit`.
  `tk-skills` is Desktop-Code-tab compatible; `tk-commands` and
  `tk-framework-rules` are Code-only. Sub-plugin content trees are relative
  symlinks into the canonical repo content (zero duplication, zero drift).
  Version is the single source of truth in each `plugin.json` (4.6.0);
  `marketplace.json` plugin entries do not declare versions per spec.

- **Marketplace + Desktop-skills validators** (`scripts/validate-marketplace.sh`,
  `scripts/validate-skills-desktop.sh`) — MKT-03, DESK-02, DESK-04: Phase 27.
  `validate-marketplace` runs `claude plugin marketplace add ./` smoke when
  `TK_HAS_CLAUDE_CLI=1` (CI default skips with no-op notice).
  `validate-skills-desktop` scans every `templates/skills-marketplace/*/SKILL.md`
  for tool-execution patterns; PASS = Desktop-safe instruction-only,
  FLAG = Code-terminal-only. Threshold: >= 4 PASS or `make check` fails. Both
  targets wired into `make check`; `validate-skills-desktop` runs as a
  dedicated CI step.

- **Desktop-only auto-routing** (`scripts/install.sh --skills-only`) — DESK-03:
  Phase 27. Users without `claude` on PATH running the installer (no flags) are
  auto-routed to `--skills-only` mode; skills land at
  `~/.claude/plugins/tk-skills/<name>/` (Desktop install location) instead of
  `~/.claude/skills/<name>/`. One-line banner explains the routing. Explicit
  `--skills-only` flag also available for users with the CLI who only want
  skills. Hermetic test: `scripts/tests/test-install-tui.sh` S10 scenario.

- **Claude Desktop capability matrix** (`docs/CLAUDE_DESKTOP.md`) — DESK-01:
  Phase 27. Four-column matrix (Capability x Desktop Code Tab x Desktop Chat
  Tab x Code Terminal) covering skills, slash commands, MCPs, statusline,
  security pack, and framework rules. Plain-English explanation of why Chat
  tab and remote Code sessions block plugins. Read-time target: under one
  minute.

- **Marketplace install documentation** (`README.md`, `docs/INSTALL.md`) —
  MKT-04: Phase 27. README and INSTALL.md gain "Install via marketplace"
  sections alongside the existing curl-bash install. Both channels documented
  as equivalent for terminal Code users; marketplace is the only path for
  Desktop users.

### Changed

- **Manifest version** bumped from 4.4.0 to 4.6.0 (final v4.5 milestone bump).
  `init-local.sh --version` derives from manifest at runtime, so no script
  changes needed.

- **`make check` chain** extended with `validate-skills-desktop` (always
  runs) and `validate-marketplace` (runs `claude plugin marketplace add ./`
  when `TK_HAS_CLAUDE_CLI=1`, no-op skip otherwise).

- **CI workflow** (`quality.yml`) gains a dedicated
  `DESK-02/DESK-04 — Skills Desktop-safety audit` step.

## [4.5.0] - 2026-04-29

### Phase 24 Sub-Phase 1 — Globalize Council artifacts

#### Added

- **Global `/council` slash command** — `setup-council.sh` and
  `init-claude.sh::setup_council` now download `commands/council.md`
  upstream into `~/.claude/commands/` (alongside the existing
  `~/.claude/council/brain.py`, `~/.claude/council/config.json`, and
  `~/.claude/council/prompts/audit-review.md` artifacts). Idempotent +
  mtime-aware download mirrors the `prompts/audit-review.md` pattern.
  Result: one global Council install drives every project, no per-project
  duplication.

- **`scripts/lib/cli-recommendations.sh`** — shared helper that detects
  whether `gemini` (Gemini CLI) and `codex` (Codex CLI) are on `$PATH`
  and prints install hints for whichever is missing. Sourced by both
  `setup-council.sh` and `init-claude.sh::setup_council`. Output is
  appended to `~/.claude/council/setup.log` for later auditing.
  Detection is informational only — never blocks setup.

- **Supreme Council section in `templates/global/CLAUDE.md`** —
  new section 15, with `## 16. USER PREFERENCES` renumbered from 15.
  Carries the v4.4 per-project Council description verbatim;
  Sub-Phase 2 will rewrite the body around the FP-recheck mandate.

- **Stale per-project `council.md` cleanup** in
  `scripts/migrate-to-complement.sh` — runs at the dry-run preview, the
  "no SP/GSD duplicates found" early exit, and the production tail.
  Detects `./.claude/commands/council.md` left over from v4.4 installs,
  warns when a global counterpart with different sha256 exists (possible
  user customization), and prompts for interactive removal. `--yes`
  accepts automatically; idempotent on re-run.

- **`verify-install.sh` Council checks** — Section 5 now verifies
  `~/.claude/commands/council.md` exists, `brain.py` is `+x`,
  `config.json` permissions are `0600` (BSD `stat -f %Lp` with GNU
  `stat -c %a` fallback), and `alias brain=` is declared in
  `.zshrc` / `.bash_profile` / `.bashrc`.

#### Changed

- **Per-project `commands/council.md` no longer ships** — removed from
  `manifest.json::files.commands[]`. Smart-update / fresh installs no
  longer copy it into `./.claude/commands/`. Existing v4.4 installs keep
  their local copy until `migrate-to-complement.sh` is run.
- **`templates/{base,go,laravel,nextjs,nodejs,python,rails}/CLAUDE.md`** —
  `## Supreme Council (Optional)` body shrinks to a one-line pointer
  (`> Supreme Council is global — see ~/.claude/CLAUDE.md ...`). Heading
  drops the `(Optional)` suffix to match
  `manifest.json::claude_md_sections.system`.
- **`scripts/validate-manifest.py`** — new `GLOBAL_ONLY_COMMANDS` set
  exempts `council.md` from the disk-to-manifest drift check so the file
  can stay in `commands/` for upstream curl fetches without re-triggering
  drift.
- **`README.md`** — Killer Features row notes `/council` is now installed
  globally to `~/.claude/commands/`.

#### Notes

This release closes Phase 24 Sub-Phase 1 (Globalize Council artifacts).
Sub-Phases 2–11 (file-based prompts, FP-recheck, context enrichment,
cost tracking, OpenRouter / Codex CLI fallback, caching, GSD
integration, QoL flags, multilingual prompts, MCP server) follow under
the same v4.5.0 heading as they ship.

## [4.4.0] - 2026-04-27

### Added

- **SP/GSD bootstrap installer** (`scripts/lib/bootstrap.sh`, `scripts/lib/optional-plugins.sh`) —
  BOOTSTRAP-01..04: `init-claude.sh` and `init-local.sh` now offer to install `superpowers`
  via `claude plugin install superpowers@claude-plugins-official` and `get-shit-done` via the
  canonical curl install before detection runs. Prompts default to `N`, fail closed when no
  TTY is available, and `--no-bootstrap` (or `TK_NO_BOOTSTRAP=1`) suppresses them entirely
  for CI. After bootstrap, `detect.sh` re-runs so the toolkit installs in the correct mode
  (`complement-sp` / `complement-gsd` / `complement-full`). Hermetic test:
  `scripts/tests/test-bootstrap.sh` (Test 28).

- **Smart-update coverage for `scripts/lib/*.sh`** — LIB-01: all six sourced helper libraries
  (`backup.sh`, `bootstrap.sh`, `dry-run-output.sh`, `install.sh`, `optional-plugins.sh`,
  `state.sh`) registered in `manifest.json` under a new `files.libs[]` array. LIB-02:
  `update-claude.sh` now refreshes stale lib files using the same diff/backup/safe-write
  contract as top-level scripts — zero code changes to the update loop required (the existing
  `jq -c '[.files | to_entries[] | .value[] | .path]'` query auto-discovers the new key).
  Hermetic test: `scripts/tests/test-update-libs.sh` (Test 29) — five scenarios proving
  stale-refresh, clean-untouched, fresh-install, modified-file fail-closed, and uninstall
  round-trip across all six libs.

- **`--no-banner` flag for `init-claude.sh` and `init-local.sh`** — BANNER-01: both
  installers now accept `--no-banner` (and the `NO_BANNER=1` env var) to suppress the
  closing `To remove: bash <(curl …)` line. Default behaviour (flag absent) is byte-identical
  to v4.3. Symmetric with `update-claude.sh`, which already honoured this flag. Hermetic test:
  `scripts/tests/test-install-banner.sh` extended from 3 to 7 source-grep assertions
  covering the new defaults, argparse clauses, and gates in both init scripts.

- **`--keep-state` flag for `scripts/uninstall.sh`** — KEEP-01: passing `--keep-state`
  (or setting `TK_UNINSTALL_KEEP_STATE=1`) preserves `~/.claude/toolkit-install.json`
  after the run instead of deleting it as the LAST step. All other UN-01..UN-08 invariants
  (backup, sentinel-strip, base-plugin diff-q) are unchanged. A subsequent `uninstall.sh`
  invocation sees the state file, re-classifies still-present modified files, and re-presents
  the `[y/N/d]` prompt — enabling recovery after a partial-N uninstall session.

- **Hermetic test for `--keep-state`** — KEEP-02: `scripts/tests/test-uninstall-keep-state.sh`
  (Test 30) proves three scenarios end-to-end: N-choice preserves state and second run
  re-classifies modified files (S1: A1+A2+A3+A4); y-choice preserves state on full-y branch
  (S2: A1); `TK_UNINSTALL_KEEP_STATE=1` env-only path preserves state with no `--keep-state`
  flag (S3: A1, D-09 env-precedence).

## [4.3.0] - 2026-04-26

### Added

- **Uninstall script** (`scripts/uninstall.sh`) — single command to safely remove every
  toolkit-installed file from a project's `.claude/` while preserving user modifications
  and base plugins (`superpowers`, `get-shit-done`).
  - UN-01: removes registered files only when current SHA256 matches the recorded hash;
    files outside the project's `.claude/` and inside base-plugin trees are never touched
  - UN-02: `--dry-run` prints a 4-group preview (REMOVE / KEEP / MODIFIED / MISSING) and
    exits 0 with zero filesystem changes
  - UN-03: modified files trigger a `[y/N/d]` prompt read from `< /dev/tty`; default `N`
    keeps the file, `d` shows a diff against the manifest reference and re-prompts
  - UN-04: full `.claude/` backup written to `~/.claude-backup-pre-uninstall-<unix-ts>/`
    before any delete; `--no-backup` flag does not exist

- **State cleanup + idempotency**
  - UN-05: deletes `~/.claude/toolkit-install.json` after successful removal and strips
    any `<!-- TOOLKIT-START -->`…`<!-- TOOLKIT-END -->` block from `~/.claude/CLAUDE.md`;
    user-authored sections preserved verbatim
  - UN-06: second invocation detects missing state file, prints
    `✓ Toolkit not installed; nothing to do`, exits 0, creates no backup directory

- **Distribution** — `manifest.json` registers `scripts/uninstall.sh` under
  `files.scripts[]`; `init-claude.sh`, `init-local.sh`, and `update-claude.sh` end-of-run
  banners include the line
  `To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)`
  (UN-07).

- **Round-trip integration test** — `scripts/tests/test-uninstall.sh` (Makefile Test 24)
  exercises the full install→uninstall round-trip across 5 scenario blocks; new
  `scripts/tests/test-install-banner.sh` (Test 25) gates banner presence in all 3
  installers (UN-08).

## [4.2.0] - 2026-04-26

### Added

- **Persistent FP allowlist** — `.claude/rules/audit-exceptions.md` auto-seeds via `globs: ["**/*"]`
  and is consulted by `/audit` Phase 0 to drop known false positives before reporting (EXC-01..05).
- **`/audit-skip <file:line> <rule> <reason>`** — appends a structured exception block to
  `audit-exceptions.md` after validating the file:line exists in the working tree and that the
  entry is not already allowlisted.
- **`/audit-restore <file:line> <rule>`** — comment-aware removal of an allowlist entry with a
  `[y/N]` confirmation prompt.
- **6-phase `/audit` workflow** — load context → quick check → deep analysis → 6-step FP recheck
  → structured report → mandatory Council pass. Every reported finding survives the FP-recheck and
  ships with verbatim ±10 lines of source code so the Council reasons from the code, not the rule
  label.
- **Structured audit reports** — `/audit` writes to `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md`
  with a fixed schema: Summary table → Findings (ID, severity, rule, location, claim, verbatim
  code, data flow, "why it's real", suggested fix) → Skipped (allowlist) → Skipped (FP recheck)
  → Council verdict slot.
- **Mandatory Supreme Council `audit-review` mode** — every `/audit` run terminates in
  `/council audit-review --report <path>`. Council emits per-finding
  `REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT` verdicts with confidence scores in `[0.0, 1.0]`,
  plus a "Missed findings" section. Severity reclassification is explicitly forbidden (COUNCIL-02).
- **`brain.py --mode audit-review`** — runs Gemini and ChatGPT in parallel for audit-review, flags
  per-finding disagreements as `disputed` without auto-resolution.
- **Template propagation across all 49 prompt files** — every
  `templates/{base,laravel,rails,nextjs,nodejs,python,go}/prompts/{SECURITY_AUDIT,CODE_REVIEW,PERFORMANCE_AUDIT,MYSQL_PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,DEPLOY_CHECKLIST,DESIGN_REVIEW}.md`
  carries the audit-exceptions callout, 6-step FP-recheck SELF-CHECK, structured OUTPUT FORMAT,
  and Council Handoff footer.

### Changed

- **`manifest.json`** — bumped to `4.2.0` and registered `templates/base/rules/audit-exceptions.md`
  under `files.rules`.
- **`commands/audit.md`** — rewritten around the 6-phase workflow; documents the Council Handoff UX
  (FALSE_POSITIVE nudge → user runs `/audit-skip`; disputed verdict prompt).
- **`commands/council.md`** — added `## Modes` section with `audit-review` subsection documenting
  input format (path to structured audit report), expected Council prompt, and verdict-table output
  schema.

### Fixed

- *None — this is an additive feature release. See [4.1.1] for the prior patch.*

### Documentation

- **CI gates** — `make validate` now asserts every audit prompt carries the `Council Handoff`
  marker plus all six numbered FP-recheck steps; missing markers fail the build (TEMPLATE-03).
- **`make test`** — adds Test 18 (audit pipeline fixture), Test 19 (Council audit-review
  verdict-slot rewrite + parallel dispatch), Test 20 (template propagation idempotency).

## [4.1.1] - 2026-04-25

### Fixed

- **CRIT-01** — Replaced fragile 95-line emoji-anchored sed smart-merge in `update-claude.sh` with chezmoi-style `.new` flow. Toolkit never touches user `CLAUDE.md`; updates land as `CLAUDE.md.new` for manual review/merge.
- **CRIT-02** — Aligned `manifest.json` version with v4.1.0 git tag.
- **C-01..C-10** — Lock TOCTOU fix in `state.sh`, atomic state-write with manifest_hash, `curl -sSLf` (fail on HTTP 4xx/5xx) across all installers, anchored regex in `setup-security.sh`, JSON-based plugin presence check.
- **Sec-H1** — Anthropic OAuth Bearer token moved off `curl` argv. Written to `mktemp` header file with `chmod 600`, passed via `-H @file`. EXIT trap cleans up.
- **BRAIN-H1..H4, M1, M2, M5** — `brain.py` corrected docstring, `Path.relative_to` validation, stdin body, header-file auth (chmod 0o600), partial-Council fallback (one provider failure → use surviving verdict), per-provider availability flags.
- **S-01** — All hook scripts in `templates/*/settings.json` read `f=$(jq -r '.tool_input.file_path // empty')` from STDIN. Removed undefined `$FILE_PATH` references.
- **PERF-02** — `sha256_file` prefers `sha256sum` → `shasum -a 256` → chunked Python fallback.
- **T-02, T-05** — New regression suite `test-claude-md-new.sh` (19 assertions, 7 scenarios). CI matrix extended to `[ubuntu-latest, macos-latest]` for `test-init-script` job.
- **M-03** — `make shellcheck` extended to `templates/global/`.

### Notes

Patch release closing 53 audit findings (2 CRIT, 14 HIGH, 20 MED, 17 LOW) cross-reviewed by Supreme Council. Council follow-up applied 4 additional refinements (passes A/B/C/D).

## [4.1.0] - 2026-04-25

### Added

- Phase 11 UX polish: chezmoi-grade dry-run preview with `[+ ADD]` / `[~ MOD]` / `[- REMOVE]` grouping for both `install` and `update` flows.
- `migrate-to-complement.sh --dry-run` now emits the same grouped preview before any destructive change.
- New audit pipeline (`AUDIT-REPORT.md`) — full deep audit covering security, correctness, performance, portability, JSON state-file integrity. Cross-AI reviewed via Supreme Council (Gemini Skeptic + ChatGPT Pragmatist).

### Fixed

- `manifest.json` `version` and `updated` fields now match the `v4.1.0` git tag (previously drifted at `4.0.0` / `2026-04-19`).

### Notes

This release closes the v4.1 milestone. See `.planning/archived/v4.1/` for phase artifacts.

## [4.0.0] - 2026-04-21

### BREAKING CHANGES

- **Default install behavior changes when SP and/or GSD are detected.** Previously (v3.x) all
  54 TK files installed unconditionally. v4.0 auto-selects `complement-*` mode and skips 7 files
  (6 commands/skills + 1 agent) that duplicate SP functionality. Users who relied on TK's
  `/debug`, `/plan`, `/tdd`, `/verify`, `/worktree`, `skills/debugging`, or TK-owned
  `agents/code-reviewer.md` will instead use SP's equivalents. Override: `--mode standalone`.
- **7 files are no longer installed in `complement-sp` mode:** `agents/code-reviewer.md`,
  `commands/debug.md`, `commands/plan.md`, `commands/tdd.md`, `commands/verify.md`,
  `commands/worktree.md`, `skills/debugging/SKILL.md`. Users relying on TK's copies must use
  SP's equivalents.
- **`manifest.json` schema bumped from v1 (implicit) to v2 (explicit `manifest_version: 2`).**
  Old v3.x install scripts refuse to run against a v2 manifest. Users running an old installer
  against the v4.0 repo see a hard error: `manifest.json has manifest_version=2; this installer
  expects v1`.
- **`toolkit-install.json` state schema bumped v1 → v2.** v1 installs read correctly via
  `jq '... // false'` backwards-compat default on the new `synthesized_from_filesystem` field,
  but v1 tooling reading the new field directly will see `null`.
- **`scripts/init-local.sh` no longer hardcodes version.** Reads from `manifest.json` at runtime
  via `jq`. The `VERSION="2.0.0"` constant is removed from line 11.
- **`scripts/update-claude.sh` no longer hand-iterates a file list.** The iterated list now comes
  from `manifest.json`. Custom TK installs that relied on update-claude.sh skipping certain files
  will see those files installed on next update (if listed in manifest).
- **`~/.claude/settings.json` is now merged additively.** `setup-security.sh` no longer overwrites
  the file — it reads, merges only TK-owned keys (permissions.deny, hooks.PreToolUse, env block),
  and writes via atomic temp-file rename.
- **Post-update summary format changed** from unstructured log lines to a 4-group block
  (`INSTALLED N`, `UPDATED M`, `SKIPPED P (with reason)`, `REMOVED Q (backed up to path)`).
  Users who scrape update output must adjust. Backup directories are now suffixed with PID
  (`~/.claude-backup-<unix-ts>-<pid>/`) to prevent same-second collision.

### Added

- `scripts/detect.sh` — filesystem detection of `superpowers` and `get-shit-done`; sources
  `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` environment variables.
- `scripts/lib/install.sh` — `recommend_mode`, `compute_skip_set`, `MODES` array for
  mode-aware installs.
- `scripts/lib/state.sh` — atomic `write_state`, `acquire_lock`, `release_lock`, `sha256_file`
  for install-state management.
- `scripts/migrate-to-complement.sh` — one-time migration for v3.x users with SP/GSD installed;
  three-column hash diff, `[y/N/d]` per-file prompt, `cp -R` full backup, idempotent.
- `~/.claude/toolkit-install.json` — install state file: mode, detected bases, installed files
  with sha256 hashes, skipped files with reasons. Schema v2 adds `synthesized_from_filesystem`.
- 4 install modes: `standalone`, `complement-sp`, `complement-gsd`, `complement-full`.
- `--mode <name>` flag on `init-claude.sh` and `init-local.sh` — overrides auto-detected mode
  with interactive prompt and auto-recommendation.
- `--dry-run` flag on `init-claude.sh` — previews `[INSTALL]`/`[SKIP]` per file without writing.
- `--offer-mode-switch=yes|no|interactive`, `--prune=yes|no|interactive`, `--no-banner` flags
  on `update-claude.sh`.
- `conflicts_with`, `sp_equivalent`, `requires_base` fields on per-file manifest entries.
- `make validate-manifest.py` check — every manifest path exists, `conflicts_with` values are
  from the known plugin set.
- Makefile test targets: 14 test groups (up from 0), all hermetic — covering detect, install,
  state, update drift, update diff, update summary, migrate diff, migrate flow, migrate idempotence.
- `components/orchestration-pattern.md` — lean orchestrator + fat subagents pattern.
- `components/optional-plugins.md` — rtk, caveman, superpowers, get-shit-done recommendations
  with verified caveats.
- `templates/global/RTK.md` — fallback RTK notes with rtk-ai/rtk#1276 caveat and workaround.
- `## Required Base Plugins` section in all 7 `templates/*/CLAUDE.md` files — discloses SP/GSD
  dependency and install commands so new users set up the full complement stack first.
- `manifest.json` `inventory.components` bucket (non-install metadata for Phase 6 components).
- `Makefile validate-base-plugins` drift guard — verifies all 7 templates carry the section
  heading on every `make check`.

### Changed

- `scripts/init-claude.sh` — refactored to 4-mode dispatch; sources `detect.sh` +
  `lib/install.sh` from `$REPO_URL` on remote installs; respects `--mode` override;
  manifest-schema-v2 guard hard-fails on v1 manifests.
- `scripts/init-local.sh` — same mode-aware logic as `init-claude.sh`; reads version from
  `manifest.json` at runtime (removes `VERSION="2.0.0"` hardcode).
- `scripts/update-claude.sh` — rewritten for re-detection on every run, mode-drift surfacing,
  manifest-driven iteration, 4-group summary, D-77 migrate hint when complement migration
  is appropriate.
- `scripts/setup-security.sh` — safe `~/.claude/settings.json` merge with timestamped backup
  (`settings.json.bak.<unix-ts>`); restore-on-merge-failure.
- `scripts/setup-council.sh` — `< /dev/tty` guards on every interactive `read`; silent
  `read -rs` for API-key prompts; `python3 json.dumps()` for API-key heredoc interpolation.
- `README.md` — repositioned as "complement to superpowers + get-shit-done"; install section
  shows standalone + complement modes with one paragraph of guidance per mode.
- `manifest.json` — schema v2 (`manifest_version: 2`); 7 entries gain `conflicts_with`; 6
  entries gain `sp_equivalent`.

### Fixed

- BUG-01: BSD-incompatible `head -n -1` in `scripts/update-claude.sh` smart-merge replaced
  with POSIX `sed '$d'`. Silent CLAUDE.md truncation on macOS fixed.
- BUG-02: `< /dev/tty` guards on every interactive `read` in `scripts/setup-council.sh`;
  silent `read -rs` for API-key prompts. Fixes curl|bash prompts being consumed as stream.
- BUG-03: `python3 json.dumps` JSON-escapes API keys containing `"`, `\`, newline in
  heredoc-written `config.json`. Fixes malformed Council config.
- BUG-04: Silent `sudo apt-get install tree` in `setup-council.sh` replaced with interactive
  prompt and visible error path.
- BUG-05: `setup-security.sh` timestamped backup of `~/.claude/settings.json` before every
  mutation; restore-on-merge-failure.
- BUG-06: `scripts/init-local.sh` reads version from `manifest.json`; `make validate`
  enforces manifest ↔ CHANGELOG version alignment.
- BUG-07: `commands/design.md` added to `update-claude.sh` loop (structurally fixed in
  Phase 4: update loop now iterates manifest, not a hand-list).

### Migration from v3.x

See [docs/INSTALL.md](docs/INSTALL.md) for the install matrix and `scripts/migrate-to-complement.sh`
for the automated migration path (per-file confirmation, full backup before any removal).

## [3.0.0] - 2026-02-16

### Added

- **Supreme Council** — multi-AI code review system (Gemini + ChatGPT)
  - `brain.py` orchestrator: sends plans to Gemini (Architect) and ChatGPT (Critic)
  - 4-phase review: Context Discovery → Architectural Audit → Second Opinion → Final Report
  - Security-hardened vs original: no hardcoded keys, no shell=True, temp file cleanup, input validation
  - Configurable models via `~/.claude/council/config.json` with env var overrides
  - Gemini modes: CLI (free with subscription) or API
  - Path traversal protection, file size limits, command timeouts
- **`/council` command** — multi-AI pre-implementation review
  - Run before coding high-stakes features (auth, payments, refactoring)
  - Outputs APPROVED/REJECTED report to `.claude/scratchpad/council-report.md`
- **`setup-council.sh`** — installation script
  - Dependency checks (Python 3.8+, tree, curl)
  - Interactive Gemini mode selection (CLI vs API)
  - API key configuration (prompt + env var support)
  - Automatic `brain` shell alias
  - Installation verification
- **Supreme Council component** — `components/supreme-council.md`
  - Full documentation: how it works, when to use, configuration, security improvements
- Supreme Council section in base CLAUDE.md template
- `/council` command distributed to all projects via init-claude.sh

### Changed

- Updated README: 26 → 29 slash commands, added Supreme Council to features and quick start
- Updated `manifest.json` to v3.0.0
- Updated `init-claude.sh` with council command and setup recommendation

## [2.8.0] - 2026-02-06

### Added

- **Production Safety Guide** — new component `components/production-safety.md`
  - Deployment safety: incremental deploy pattern, pre/post-deploy verification
  - Queue and worker safety: rolling restarts, check before modify, test on subset
  - Bug fix approach: simplest solution first, rule of three attempts
  - File targeting: verify correct variant, branch, upstream status
  - Rollback decision framework: when to rollback vs hotfix
- **`/deploy` command** — safe deployment workflow with 4 phases
  - Pre-deploy: git state, conflict check, tests, build
  - Deploy: framework-specific steps with rolling worker restart
  - Post-deploy: smoke tests, log check, worker status
  - Rollback decision: automatic verification with user approval
  - Framework auto-detection (Laravel, Next.js, Node.js, Python, Go)
- **`/fix-prod` command** — production hotfix workflow
  - Diagnose first (gather evidence, identify scope, rollback decision)
  - Minimal change rule (fix only the broken thing)
  - Post-fix monitoring (immediate + short-term)
  - Common production issues quick reference
- **Production Safety section** in all 7 CLAUDE.md templates
  - Bug Fix Approach rules
  - Deployment safety rules
  - File Targeting checklist
  - Laravel template: extra Queue and Worker Safety subsection
- Inspired by insights from 94 Claude Code sessions (1,307 messages)

### Changed

- Updated Quick Commands table in all templates (+2 commands: `/deploy`, `/fix-prod`)
- Updated README: 24 → 26 slash commands, 23+ → 24+ guides
- Updated `docs/features.md` with Production Safety section and new commands
- Updated `manifest.json` to v2.8.0 with Production Safety section

## [2.6.0] - 2026-01-23

### Added

- **Compact Instructions** — section for preserving critical rules during `/compact`
  - Added to all CLAUDE.md templates (base, laravel, nextjs)
  - 4-5 key rules that should be preserved after compaction
  - Security, Architecture, Workflow, Git + framework-specific
- **AI Models skill** — extracted from CLAUDE.md into separate skill
  - `skills/ai-models/SKILL.md` — loaded on demand
  - Claude 4.5 (Opus, Sonnet, Haiku) with model IDs
  - Gemini 3 (Pro, Flash) with model IDs
  - Code examples for Python, TypeScript, PHP
- **Available Skills** section in CLAUDE.md templates
- **DATABASE_PERFORMANCE_AUDIT.md** — renamed and moved to `templates/*/prompts/`

### Changed

- **README.md** — reorganized section order:
  Who Is This For → Quick Start → Key Concepts → Structure → What's Inside → MCP → Examples
- Templates in "What's Inside" is now the first item
- Security audit example uses `/audit security`
- Updated audit count: 5 → 6 (added Database)
- CLAUDE.md templates reduced by 10-20%

### Fixed

- Markdown syntax issues in laravel template

## [2.5.0] - 2026-01-23

### Added

- **`/verify` command** — quick check before PR
  - Build, types, lint, tests in one command
  - Modes: `quick`, `full`, `pre-commit`, `pre-pr`
  - Security scan for pre-pr mode
  - Auto-detection of framework (Laravel, Next.js, Node.js)
- **`/learn` command** — extracting and saving patterns
  - Saves problem solutions to `.claude/rules/lessons-learned.md` (auto-loaded)
  - Integration with Memory Bank and Knowledge Graph
  - Pattern types: error resolution, workarounds, debugging, user corrections
  - **Mistakes & Learnings** pattern (Error → Learning → Prevention) from loki-mode
  - Self-Correction Protocol for automatic learning from mistakes
- **`/debug` command** — systematic debugging process
  - 4 phases: Root Cause → Pattern Analysis → Hypothesis → Implementation
  - Rule "3+ fixes = architectural problem"
  - Common Rationalizations table
  - Inspired by [superpowers](https://github.com/obra/superpowers)
- **`/worktree` command** — git worktrees management
  - Actions: create, list, remove, cleanup
  - Supplement to existing `components/git-worktrees-guide.md`
- **Enhanced Security Audit** — concepts from Trail of Bits
  - "Context before vulnerabilities" principle
  - Codebase Size Strategy (SMALL/MEDIUM/LARGE)
  - Risk Level Triggers (HIGH/MEDIUM/LOW)
  - Rationalizations table
  - Sharp Edges section (API footguns)
  - Red Flags for immediate escalation
- **Hooks Auto-Activation** — automatic skills activation (`components/hooks-auto-activation.md`)
  - **Scoring system** — different triggers give different points (keywords: 2, intentPatterns: 4, pathPatterns: 5)
  - **Confidence levels** — HIGH/MEDIUM/LOW based on score
  - **Threshold filtering** — minConfidenceScore, maxSkillsToShow
  - **Exclude patterns** — false positives prevention
  - **JSON Schema** — validation and IDE autocomplete
  - TypeScript implementation with examples
  - Inspired by [claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase)
- **Modular Skills** — progressive disclosure (`components/modular-skills.md`)
  - Splitting large guidelines into modules
  - Navigation table in main SKILL.md
  - Resources loaded on demand
  - 60-85% token savings
- **Skill Accumulation** — self-learning system (`components/skill-accumulation.md`)
  - Automatic skill creation when patterns are detected
  - Updating existing skills on user corrections
  - Proposal formats for creation/update
  - Templates in `templates/base/skills/`
- **Design Review** — UI/UX audit with Playwright MCP (`templates/*/prompts/DESIGN_REVIEW.md`)
  - 7-phase review process (Preparation → Interaction → Responsiveness → Visual → Accessibility → Robustness → Code)
  - Triage matrix: [Blocker], [High], [Medium], [Nitpick]
  - WCAG 2.1 AA accessibility checks
  - Responsive testing (1440px, 768px, 375px)
  - Next.js specific version with hydration, next/image, Tailwind checks
  - Inspired by [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows)
- **Structured Workflow** — 3-phase development approach (`components/structured-workflow.md`)
  - Phase 1: RESEARCH (read-only) — only Glob, Grep, Read
  - Phase 2: PLAN (scratchpad-only) — plan in `.claude/scratchpad/`
  - Phase 3: EXECUTE (full access) — after confirmation
  - Explicit tool restrictions by phase
  - Plan template with checkboxes
  - Inspired by [RIPER-5](https://github.com/tony/claude-code-riper-5)
- **Smoke Tests Guide** — minimal tests for API (`components/smoke-tests-guide.md`)
  - What to test: health, auth, core CRUD
  - Examples for Laravel (Pest), Next.js (Vitest), Node.js (Jest)
  - GitHub Actions workflow
  - Checklist for new project
- Inspired by [everything-claude-code](https://github.com/affaan-m/everything-claude-code), [superpowers](https://github.com/obra/superpowers), [Trail of Bits](https://github.com/trailofbits/skills), [loki-mode](https://github.com/asklokesh/loki-mode), [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase)

### Changed

- Updated README with `/verify` and `/learn` in commands table
- Added Quick Commands section to all templates

## [2.4.0] - 2026-01-22

### Added

- **Gemini 3 models support** — AI Models section now includes both Claude and Gemini
  - Claude 4.5: Opus, Sonnet, Haiku
  - Gemini 3: Pro, Flash
  - Code examples for both providers (Python, PHP, TypeScript)
  - Deprecation warning for old versions (Claude 3.5/4.0, Gemini 1.x/2.x)
- **Architecture Guidelines (STRICT!)** section in all templates:
  - KISS Principle — simplest working solution
  - YAGNI — no features "for the future"
  - No Boilerplate — no Interfaces/Factories/DTOs unless requested
  - File Structure — prefer larger files, ask before creating new files
- **Coding Style** section:
  - Functional programming over complex OOP
  - Don't over-split functions (50 lines is fine)
  - One file doing one thing well > 5 files with abstractions
- **Bootstrap Workflow** documentation:
  - New section in README.md
  - New component `components/bootstrap-workflow.md`
  - Correct order: IDEA → STACK → INSTRUCTIONS → ADAPTATION
  - Example prompts for Laravel and Next.js projects
- **Knowledge Persistence** pattern — save knowledge to 3 places:
  - CLAUDE.md (for Claude Code)
  - docs/README (for humans)
  - MCP Memory (for persistence between sessions)
- **CHANGELOG rule** in Git Workflow — update on `feat:`, `fix:`, breaking changes
- **`/install` command** — quick installation from Claude Guides repository

### Changed

- Renamed "Claude Models" section to "AI Models" in all templates
- Updated all CLAUDE.md templates with new guidelines

## [2.3.0] - 2026-01-22

### Added

- Memory Persistence system — MCP memory sync with Git
  - New component `components/memory-persistence.md` with full documentation
  - Template files in `templates/*/memory/`:
    - `README.md` — sync instructions for each project
    - `knowledge-graph.json` — Knowledge Graph export template
    - `project-context.md` — Memory Bank context template
- Session start workflow in all CLAUDE.md templates:
  - Check MCP vs git sync dates
  - Read project memory from MCP
  - Load Knowledge Graph relationships

### Changed

- Updated all CLAUDE.md templates (base, laravel, nextjs):
  - Added "AT THE START OF EACH SESSION" section with sync check
  - Added pre-commit sync instructions in Knowledge Persistence
  - Added immediate sync rule after MCP changes
- Updated `mcp-servers-guide.md` with Git sync section
- Updated README.md with Memory Persistence subsection

## [2.2.0] - 2026-01-21

### Added

- Knowledge Graph Memory MCP server (`@modelcontextprotocol/server-memory`)
  - Builds entity relationships instead of simple key-value storage
  - Best suited for Claude Opus 4.5 architectural analysis
- Spec-Driven Development component (`components/spec-driven-development.md`)
  - Write specifications before code
  - Template for .spec.md files
  - Workflow: spec → review → implement
- `.claude/specs/` directory structure for projects

### Changed

- Updated MCP servers guide with Knowledge Graph Memory
- Updated README with Spec-Driven Development section

## [2.1.0] - 2026-01-21

### Added

- MCP Servers Guide (`components/mcp-servers-guide.md`)
  - context7 — documentation lookup for libraries
  - playwright — browser automation and UI testing
  - memory-bank — project memory between sessions
  - sequential-thinking — step-by-step problem solving
- Quick install commands for MCP servers in README

## [1.1.0] - 2025-01-13

### Added

- CI/CD with GitHub Actions (shellcheck, markdownlint, template validation)
- `update-claude.sh` script for updating templates in existing projects
- Dry-run mode (`--dry-run`) for init scripts
- More framework detection (Django, Rails, Go, Rust)
- Makefile for development tasks
- Pre-commit hooks configuration
- GitHub issue and PR templates
- New commands: `/fix`, `/explain`, `/test`, `/refactor`, `/migrate`
- Example configurations for Laravel SaaS, Next.js Dashboard, Monorepo
- LICENSE (MIT)
- SECURITY.md
- CONTRIBUTING.md

### Changed

- Improved init scripts with backup functionality
- Better error handling in shell scripts

## [1.0.0] - 2025-01-13

### Added

- Initial release
- Base templates (framework-agnostic):
  - SECURITY_AUDIT.md
  - PERFORMANCE_AUDIT.md
  - CODE_REVIEW.md
  - DEPLOY_CHECKLIST.md
- Laravel-specific templates
- Next.js-specific templates
- Reusable components:
  - severity-levels.md
  - self-check-section.md
  - report-format.md
  - quick-check-scripts.md
- Slash commands: `/doc`, `/find-script`, `/find-function`, `/audit`
- Init scripts (`init-claude.sh`, `init-local.sh`)
- README with usage instructions
