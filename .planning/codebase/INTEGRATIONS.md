# External Integrations

**Analysis Date:** 2026-04-17

## APIs & External Services

**LLM Providers (used by Supreme Council in `scripts/council/brain.py`):**

- Anthropic API — `https://api.anthropic.com/v1/messages` referenced in `templates/global/rate-limit-probe.sh:47`.
  - Purpose: Probe rate-limit headers (`anthropic-ratelimit-unified-5h-utilization`, `anthropic-ratelimit-unified-7d-utilization`) for the statusline.
  - Auth: Bearer OAuth token read from macOS Keychain (`Claude Code-credentials`) via `security find-generic-password`.
  - Headers used: `anthropic-version: 2023-06-01`, `anthropic-beta: interleaved-thinking-2025-05-14,oauth-2025-04-20`.
  - Model: `claude-haiku-4-5-20251001` with `max_tokens=1` (cheapest possible probe).

- Google Gemini API — `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` in `scripts/council/brain.py:270`.
  - Purpose: "The Skeptic" reviewer in Supreme Council.
  - Default model: `gemini-3-pro-preview` (configured in `scripts/council/config.json.template:5` and `scripts/setup-council.sh:183`).
  - Auth: API key as URL query parameter (`?key=...`) — Google API design. Comment at `brain.py:268-269` warns key may appear in proxy logs.
  - Env: `GEMINI_API_KEY` (optional override, read in `scripts/setup-council.sh:98`).
  - Alternative mode: `gemini` CLI (`@google/gemini-cli`, `npm install -g @google/gemini-cli`) invoked via stdin pipe (`brain.py:251-260`).

- OpenAI API — `https://api.openai.com/v1/chat/completions` in `scripts/council/brain.py:350`.
  - Purpose: "The Pragmatist" reviewer in Supreme Council.
  - Default model: `gpt-5.2` (configured in `scripts/council/config.json.template:9` and `scripts/setup-council.sh:187`).
  - Auth: `Authorization: Bearer ${api_key}`.
  - Env: `OPENAI_API_KEY` (optional override, read in `scripts/setup-council.sh:129`).

**Common HTTP behavior:**

- All outgoing HTTP requests from `brain.py` use a real browser User-Agent (`USER_AGENT` constant, `brain.py:35-39`) — `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36` — never a default library UA. This is enforced by the project's own security rules in `templates/global/CLAUDE.md`.
- 120s timeout per provider call.
- Payloads are written to `tempfile.NamedTemporaryFile` and passed to `curl -d @file` to avoid argument-list length limits.

## Data Storage

**Databases:**
- None. The repository stores no application data.

**File Storage:**
- Local filesystem only. The toolkit writes:
  - `.claude/` inside target user projects (via `scripts/init-claude.sh`, `scripts/init-local.sh`, `scripts/update-claude.sh`).
  - `~/.claude/` in user home (security rules via `scripts/setup-security.sh`, statusline scripts via `scripts/install-statusline.sh`, council files via `scripts/setup-council.sh`).
  - `~/.claude/council/config.json` (chmod 600, owner-only) created by `scripts/setup-council.sh:178-192`.

**Caching:**
- `${TMPDIR:-/tmp}/claude-rate-limits.json` — Statusline rate-limit cache (60-second TTL), written by `templates/global/rate-limit-probe.sh:75+`, read by `templates/global/statusline.sh:13`.
- `${TMPDIR:-/tmp}/claude-rate-limit-probe.lock` — Atomic mkdir lock (30-second stale window) to prevent concurrent probes (`rate-limit-probe.sh:9-23`).

## Authentication & Identity

**Auth Provider:**
- macOS Keychain — Source of Claude Code OAuth access token. Read via `security find-generic-password -s "Claude Code-credentials" -w` and parsed with `jq -r '.claudeAiOauth.accessToken'` (`scripts/install-statusline.sh:50`, `templates/global/rate-limit-probe.sh:35`).
- Subscription type detected at `scripts/install-statusline.sh:64` via `.claudeAiOauth.subscriptionType` (works with Claude Max and Pro).
- No custom auth — relies entirely on Claude Code's existing OAuth flow.

## Monitoring & Observability

**Error Tracking:**
- None. Failures are echoed to stdout/stderr with ANSI color codes; cache file may contain `{"error":"no_token","ts":0}` (rate-limit-probe.sh:38).

**Logs:**
- `templates/base/settings.json:11` defines a PostToolUse hook that appends to `.claude/activity.log` after every Edit/Write.
- `templates/base/settings.json:23` defines a Stop hook that appends to `~/.claude/sessions.log`.
- No external log aggregation.

## CI/CD & Deployment

**Hosting / Distribution:**
- GitHub repository `sergei-aronsen/claude-code-toolkit` (referenced in every script's `REPO_URL` constant).
- Distribution endpoint: `https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main` — used by `scripts/init-claude.sh:18`, `scripts/init-local.sh` (local variant uses filesystem path), `scripts/install-statusline.sh:15`, `scripts/setup-security.sh:19`, `scripts/setup-council.sh:19`, `scripts/update-claude.sh:15`, `scripts/verify-install.sh:380-383`, and `scripts/council/brain.py:97`.
- Manifest endpoint: `https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/manifest.json` consumed by `scripts/update-claude.sh:17,67`.
- Changelog reference: `https://github.com/sergei-aronsen/claude-code-toolkit/blob/main/CHANGELOG.md` (`scripts/update-claude.sh:299`).

**CI Pipeline:**
- GitHub Actions — `.github/workflows/quality.yml` (single workflow, 4 jobs).
  - Triggers: `push` to `main`, `pull_request` to `main`.
  - Permissions: `contents: read` (least-privilege at workflow level).
  - All third-party actions pinned to full SHA (security best practice from the project's own rules):
    - `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4`
    - `ludeeus/action-shellcheck@00b27aa7cb85167568cb48a3838b75f4265f2bca  # v2.0.0`
    - `DavidAnson/markdownlint-cli2-action@455b6612a7b7a80f28be9e019b70abdd11696e4e  # v14`
  - Jobs:
    1. `shellcheck` — runs `ludeeus/action-shellcheck` against `./scripts` with severity `warning`.
    2. `markdownlint` — runs `markdownlint-cli2-action` with `globs: '**/*.md'` and config `.markdownlint.json`.
    3. `validate-templates` — bash inline; greps `templates/**/{SECURITY,PERFORMANCE}_AUDIT.md`, `templates/**/CODE_REVIEW.md`, `templates/**/DEPLOY_CHECKLIST.md` for `QUICK CHECK`, `САМОПРОВЕРКА|SELF-CHECK`, `ФОРМАТ ОТЧЁТА|OUTPUT FORMAT` headings.
    4. `test-init-script` — synthesizes Laravel (`touch artisan`) and Next.js (`touch next.config.js`) projects in `/tmp` and runs `scripts/init-local.sh`, asserting `.claude/prompts/SECURITY_AUDIT.md` is created.
- No CD pipeline — no auto-deploy, no release automation, no package publishing.

**Pre-commit (optional, local-only):**
- `.pre-commit-config.yaml` references three external repos:
  - `https://github.com/koalaman/shellcheck-precommit` @ `v0.9.0`
  - `https://github.com/igorshubovych/markdownlint-cli` @ `v0.37.0`
  - `https://github.com/pre-commit/pre-commit-hooks` @ `v4.5.0`

## Environment Configuration

**Required env vars:**
- None for using the repository.
- Optional for Supreme Council install:
  - `GEMINI_API_KEY` — Picked up by `scripts/setup-council.sh:98` if set.
  - `OPENAI_API_KEY` — Picked up by `scripts/setup-council.sh:129` if set.
- Optional flags consumed by `scripts/init-claude.sh`: `--dry-run`, `--no-council`, and a positional framework argument (`laravel|nextjs|nodejs|python|go|rails|base`).

**Secrets location:**
- Never in repository files. `.gitignore` does not list secrets explicitly (none expected).
- `~/.claude/council/config.json` — created with `chmod 600` (`scripts/setup-council.sh:191`).
- macOS Keychain — sole source of Claude OAuth tokens.
- The `detect-private-key` pre-commit hook (`.pre-commit-config.yaml:28`) provides a defensive scan.

## Webhooks & Callbacks

**Incoming:**
- None. Repository exposes no HTTP endpoints.

**Outgoing:**
- One-shot probe to `api.anthropic.com` from the user's machine via `templates/global/rate-limit-probe.sh` (triggered by the Claude Code statusline every >60s).
- One-shot calls to `generativelanguage.googleapis.com` and `api.openai.com` from `scripts/council/brain.py` whenever the user runs `brain "..."` / `/council`.

## Referenced External Resources (for documentation only)

These URLs appear in scripts/components as guidance, not as runtime integrations:

- `https://aistudio.google.com/app/apikey` — Where to get a Gemini API key (`scripts/council/README.md:32`).
- `https://platform.openai.com/api-keys` — Where to get an OpenAI key (`scripts/init-claude.sh:507`, `scripts/setup-council.sh:137`).
- `https://jqlang.github.io/jq/download/` — `jq` install link (`scripts/install-statusline.sh:37`).
- `https://mama.indstate.edu/users/ice/tree/` — `tree` install link (`scripts/setup-council.sh:70`).
- `https://github.com/anthropics/claude-code-security-review` — Recommended SAST GitHub Action (`scripts/setup-security.sh:493`).
- `https://semgrep.dev` — Recommended SAST tool (`scripts/setup-security.sh:495`).
- `https://json.schemastore.org/claude-code-settings.json` — JSON schema for Claude Code settings (`templates/base/settings.json:2`).

---

*Integration audit: 2026-04-17*
