# Stack Research

**Domain:** POSIX Bash CLI installer — filesystem-based plugin detection and conditional install
**Researched:** 2026-04-17 (v4.0); updated 2026-04-29 (v4.5 additions)
**Confidence:** HIGH (codebase read directly; conclusions drawn from existing code patterns, not training data)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Bash | 3.2+ (BSD compat) | All install logic | Already the project runtime. Dropping BSD compat would break macOS users without any gain — bash 4+ associative arrays are NOT worth the compat break for this use case. |
| `jq` | any stable (1.6+) | JSON read/write for manifest.json and toolkit-install.json | Already a declared runtime dependency (install-statusline.sh, rate-limit-probe.sh). Elevating it to a hard dep for ALL scripts is a natural promotion, not a new dependency. |
| `python3` | 3.8+ | JSON mutation of `~/.claude/settings.json` only | Already used in setup-security.sh for this exact task. Keep it scoped to settings.json mutation because python3 handles edge cases (JSON5-adjacent trailing commas, Unicode, nested merge) that jq cannot do atomically in a one-liner. |

### Supporting Libraries / Tools

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `mktemp` | POSIX | Atomic write via temp-file + `mv` | Every JSON write. Write to `$(mktemp)` then `mv` to destination — the only safe atomic pattern on POSIX without a lock daemon. |
| `flock` | util-linux (Linux only) | Advisory file lock for concurrent installer runs | NOT recommended — unavailable on macOS BSD. Use a `.lock` file + PID check instead (see Patterns section). |
| `cp -p` | POSIX | Timestamped backup before any mutation | Mandatory before every write to user files (`settings.json`, `toolkit-install.json`). Pattern already exists in `install-statusline.sh:104`; must be ported to all mutating scripts. |

### Development Tools (unchanged from existing)

| Tool | Purpose | Notes |
|------|---------|-------|
| `shellcheck` | Static analysis for shell scripts | Already in CI. All new scripts must pass at `warning` severity. |
| `markdownlint-cli` | Markdown lint | Unchanged. Not relevant to new shell code. |
| `make` | Task runner | Add `make validate-consistency` target to diff manifest vs script lists. |

---

## Answers to Specific Research Questions (v4.0)

### Q1: `jq` as hard dependency vs. sed/awk hacks?

**Recommendation: Make `jq` a hard dependency. Eliminate sed/awk for JSON.**

Rationale:

- `jq` is already required by `install-statusline.sh` and the `rate-limit-probe.sh`/`statusline.sh` globals. The project already lists it as a "Critical (runtime tool)" in `.planning/codebase/STACK.md:53`.
- The primary pain point that motivated this question is `update-claude.sh:147` — a hand-maintained 29-element list that drifts from `manifest.json`. The fix is `jq -r '.files.commands[]' manifest.json`, which is the exact use case `jq` is designed for.
- sed/awk on JSON is brittle: it cannot handle multiline values, nested objects, or Unicode safely. The existing `grep -o '"version": "[^"]*"'` in `update-claude.sh:74` is already an example of a fragile JSON parse that will silently return wrong data if the key appears twice or the spacing changes.
- Fail-fast guard: add `command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required. Install: brew install jq / apt install jq"; exit 1; }` at the top of every script that uses it. This is better than silent wrong behavior from sed.

**Confidence: HIGH** — based on existing declared dependency and direct code evidence of sed fragility.

### Q2: Single `manifest.json` vs. per-mode manifests?

**Recommendation: Keep one `manifest.json`. Extend it with per-file metadata fields.**

Add two optional fields per file entry:

```json
"conflicts_with": ["superpowers", "get-shit-done"],
"requires_base": null
```

Where:

- `conflicts_with`: array of base plugin IDs whose presence means this file should be skipped
- `requires_base`: array of base plugin IDs required for this file to be useful (install only when present)
- Both default to `null`/`[]` = always install

Rationale:

- The codebase already has the "manifest as source of truth" principle stated in `.planning/codebase/CONCERNS.md:189`. Splitting into per-mode manifests creates a NEW version of the four-list-drift problem. The install scripts would need to know which manifest(s) to fetch.
- A single manifest with richer per-file metadata keeps the logic in data (declarative) rather than in shell code (imperative). Shell scripts read `jq -r --arg mode "$INSTALL_MODE" '[.files.commands[] | select(.conflicts_with | map(. == $mode) | any | not) | .path] | .[]' manifest.json`.
- Per-mode manifests would also require a manifest-manifest (a manifest of which manifests apply), which is exactly the recursive complexity YAGNI warns against.

**Confidence: HIGH** — directly follows from existing codebase architecture decision.

Schema for extended manifest entry:

```json
"commands": [
  {
    "path": "commands/debug.md",
    "conflicts_with": ["superpowers"],
    "requires_base": null
  },
  {
    "path": "commands/council.md",
    "conflicts_with": [],
    "requires_base": null
  }
]
```

Migration: entries that are currently bare strings (`"commands/plan.md"`) remain valid if scripts treat strings as `{ "path": "...", "conflicts_with": [], "requires_base": null }`. Use `jq` to normalize: `jq -r 'if type == "string" then . else .path end'`.

### Q3: Similar installers for this pattern?

**Finding: No standard library exists for this. Both Superpowers and GSD use the same POSIX-bash + curl pattern.**

Verified: Superpowers install path is `~/.claude/plugins/cache/claude-plugins-official/superpowers/` and GSD is `~/.claude/get-shit-done/`. Both are shell-script-only. Neither has a plugin registry or detection API.

The standard pattern in similar CLI installers (Homebrew formula installers, mise, asdf) for "detect installed component and skip if present" is:

```bash
if [ -d "$target_path" ]; then
  echo "Already installed: $name"
else
  install "$name"
fi
```

No external library is needed. This is a solved problem in 3 lines of shell. The complexity in this project comes from the JSON state file and skip-list logic, both of which `jq` handles cleanly.

**Confidence: MEDIUM** — SP and GSD install paths verified from `.planning/PROJECT.md:34-35`; their internal scripts not read directly.

### Q4: `~/.claude/toolkit-install.json` — schema, atomic write, lock file?

**Recommended schema:**

```json
{
  "version": "1",
  "installed_at": "2026-04-17T12:00:00Z",
  "updated_at": "2026-04-17T12:00:00Z",
  "toolkit_version": "4.0.0",
  "mode": "complement-full",
  "detected_bases": {
    "superpowers": true,
    "get-shit-done": true
  },
  "installed_files": [
    "commands/council.md",
    "commands/helpme.md"
  ],
  "skipped_files": [
    "commands/debug.md",
    "commands/tdd.md"
  ],
  "skipped_reason": {
    "commands/debug.md": "conflicts_with:superpowers",
    "commands/tdd.md": "conflicts_with:superpowers"
  }
}
```

**Atomic write pattern (POSIX-safe):**

```bash
INSTALL_JSON="$HOME/.claude/toolkit-install.json"
TMP=$(mktemp "${INSTALL_JSON}.tmp.XXXXXX")
# write to TMP...
mv -f "$TMP" "$INSTALL_JSON"
```

`mv` is atomic on the same filesystem (POSIX rename(2)). Never write directly to the destination file.

**Lock file pattern (BSD-compatible, no `flock`):**

```bash
LOCK_FILE="$HOME/.claude/toolkit-install.lock"
LOCK_PID_FILE="$HOME/.claude/toolkit-install.lock.pid"

acquire_lock() {
  if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
      echo "ERROR: Another install is running (PID $OLD_PID). Exiting."
      exit 1
    fi
    # Stale lock — previous run crashed
    rm -f "$LOCK_FILE" "$LOCK_PID_FILE"
  fi
  touch "$LOCK_FILE"
  echo $$ > "$LOCK_PID_FILE"
}

release_lock() {
  rm -f "$LOCK_FILE" "$LOCK_PID_FILE"
}
trap release_lock EXIT
```

`kill -0 $PID` is POSIX and works on macOS BSD. `flock` is Linux-only — do not use it.

**Backup on update:**

```bash
if [ -f "$INSTALL_JSON" ]; then
  cp -p "$INSTALL_JSON" "${INSTALL_JSON}.bak.$(date +%Y%m%d-%H%M%S)"
fi
```

**Confidence: HIGH** — standard POSIX patterns, no framework dependency.

### Q5: BSD-compatible shell vs. bash 4+ associative arrays?

**Recommendation: Stay on bash 3.2+ / POSIX. Do NOT require bash 4+.**

Rationale:

- macOS ships bash 3.2.57 as the default and will not change this due to GPL licensing. Users who upgrade to bash 5 via homebrew are a subset. The install scripts run under `curl | bash` where the system bash is invoked — that is 3.2 on macOS.
- Associative arrays are the only bash 4+ feature that would materially help (for skip-lists like `declare -A skip_map`). The same result is achievable with a pipe through `jq` or a `grep` over a flat string — neither requires bash 4.
- The skip-list problem is: given an install mode, which files to skip? With `jq` and extended manifest metadata (see Q2 answer), the skip-list is computed as: `jq -r --arg mode "$INSTALL_MODE" '...' manifest.json`. No associative array needed.
- Portable alternative if jq is unavailable mid-script: encode skip-list as a space-separated string `SKIP=" commands/debug.md commands/tdd.md "` and test with `case " $SKIP " in *" $file "*)`.

**Confidence: HIGH** — verified against existing constraint in `.planning/PROJECT.md:79` and `.planning/codebase/STACK.md:9`.

---

## v4.5 Stack Additions

### Q6: Pure-bash TUI library/pattern — checkbox menu under macOS Bash 3.2

**Researched: 2026-04-29. Sources: Official Bash manual, live macOS Bash 3.2.57 testing, community patterns.**

**Recommendation: Pure `read -rsn1` + two-pass `read -rsn2` escape sequence polling. No library. No deps.**

#### Bash 3.2 verified constraints

macOS ships Bash 3.2.57 (`bash --version` confirmed on Apple Silicon macOS 25). Key limitations vs Bash 4+:

| Feature | Bash 3.2 (macOS default) | Bash 4+/5 |
|---------|--------------------------|-----------|
| `read -N` (exact count, ignore delim) | NOT available | Available |
| `read -t 0.001` (sub-second float timeout) | Fails: "invalid timeout specification" | Works |
| `read -t 1` (integer timeout) | Works | Works |
| `read -rsn1` (1 char, raw, silent) | Works | Works |
| `read -rsn2` (2 chars, raw, silent) | Works | Works |
| `$'\e[A'` ANSI escape literal | Works | Works |
| ANSI color codes (`\033[0m`) | Works via `echo -e` / `printf` | Works |
| `tput` cursor movement | Works (ncurses dep, always present on macOS/Linux) | Works |

The `-N` flag and sub-second float timeouts are the two Bash 4-only features commonly used in TUI libraries. Both must be avoided.

#### Verified escape sequence pattern (works on Bash 3.2)

```bash
# Arrow key reading — tested on macOS Bash 3.2.57
_read_key() {
    local key=""
    IFS= read -rsn1 key 2>/dev/null
    if [[ "$key" == $'\e' ]]; then
        local extra=""
        IFS= read -rsn2 extra 2>/dev/null  # read [A/B/C/D part
        key+="$extra"
    fi
    printf '%s' "$key"
}

# Map escape sequences to named keys
_map_key() {
    case "$1" in
        $'\e[A') echo "UP" ;;
        $'\e[B') echo "DOWN" ;;
        $'\e[C') echo "RIGHT" ;;
        $'\e[D') echo "LEFT" ;;
        ' ')     echo "SPACE" ;;
        '')      echo "ENTER" ;;      # Enter key = empty string from read -rsn1
        $'\n')   echo "ENTER" ;;
        q|Q)     echo "QUIT" ;;
        *)       echo "OTHER:$1" ;;
    esac
}
```

Live test confirmed: `printf "\e[A" | { read -rsn1 k; read -rsn2 extra; echo "ESC + [$extra]"; }` outputs `ESC + [[A]` on macOS Bash 3.2. The pattern works.

**Note on `-t` polling (blurayne gist pattern):** The gist uses `read -sN1 -t 0.0001 k` for additional bytes after the ESC — this is Bash 4+ only (`-N` and sub-second `-t`). On Bash 3.2, replace with `IFS= read -rsn2 extra` which reads exactly 2 chars without timeout. Works because after an ESC, the `[A` bytes are already buffered in the terminal's read buffer.

#### Checkbox TUI rendering pattern (Bash 3.2 safe)

```bash
# ANSI helpers — no deps, works everywhere
_tui_hide_cursor()  { printf '\033[?25l'; }
_tui_show_cursor()  { printf '\033[?25h'; }
_tui_clear_lines()  { local n=$1; printf "\033[${n}A\033[0J"; }

# Render checkbox list — call after every keypress
_tui_render() {
    local -a items=("${!1}")  # nameref to array; Bash 3.2 compatible via indirect
    local -a checked=("${!2}")
    local cursor=$3
    local n=${#items[@]}

    for (( i=0; i<n; i++ )); do
        local mark="[ ]"
        [[ "${checked[$i]}" == "1" ]] && mark="[x]"
        if [[ $i -eq $cursor ]]; then
            printf "\033[7m  %s %s\033[0m\n" "$mark" "${items[$i]}"  # reverse video
        else
            printf "  %s %s\n" "$mark" "${items[$i]}"
        fi
    done
}
```

**Bash 3.2 array passing constraint:** Bash 3.2 does NOT support `declare -n` nameref. Use indirect expansion via `local arr_name=$1; eval "local items=(\"\${${arr_name}[@]}\")` or pass array elements as a delimiter-separated string.

#### Recommended minimal pattern for install.sh

Given the project's POSIX-first, no-deps constraint, use this minimal structure:

```bash
# Component menu for scripts/install.sh
# All read from /dev/tty — safe under curl | bash
_tui_select_components() {
    local tty_src="${TK_INSTALL_TTY_SRC:-/dev/tty}"
    if [[ ! -c "$tty_src" ]] && [[ ! -f "$tty_src" ]]; then
        # No TTY — fall through to bootstrap.sh y/N fallback
        return 1
    fi

    local -a labels=(
        "Toolkit (CLAUDE.md templates, commands, skills) [always]"
        "superpowers (Anthropic official plugin)"
        "get-shit-done (gsd-build plugin)"
        "Security Pack (cc-safety-net hooks)"
        "RTK (token optimizer)"
        "Statusline (macOS only)"
    )
    local -a checked=(1 0 0 0 0 0)  # Toolkit pre-checked
    local cursor=0
    local n=${#labels[@]}

    _tui_hide_cursor
    printf "Use arrow keys to move, SPACE to toggle, ENTER to confirm\n\n"
    _tui_render labels checked $cursor

    while true; do
        local raw
        raw=$(_read_key < "$tty_src")
        local key
        key=$(_map_key "$raw")

        case "$key" in
            UP)
                (( cursor > 0 )) && (( cursor-- ))
                ;;
            DOWN)
                (( cursor < n-1 )) && (( cursor++ ))
                ;;
            SPACE)
                # item 0 (Toolkit) is always checked — no toggle
                if [[ $cursor -ne 0 ]]; then
                    [[ "${checked[$cursor]}" == "1" ]] && checked[$cursor]=0 || checked[$cursor]=1
                fi
                ;;
            ENTER|QUIT)
                break
                ;;
        esac

        _tui_clear_lines $(( n + 1 ))
        _tui_render labels checked $cursor
    done

    _tui_show_cursor

    # Export results into caller env
    TUI_INSTALL_TOOLKIT=${checked[0]}
    TUI_INSTALL_SP=${checked[1]}
    TUI_INSTALL_GSD=${checked[2]}
    TUI_INSTALL_SECURITY=${checked[3]}
    TUI_INSTALL_RTK=${checked[4]}
    TUI_INSTALL_STATUSLINE=${checked[5]}
}
```

#### Fallback chain

```
curl | bash executed
  └─ TTY available?
       YES → _tui_select_components (arrow + space + enter)
       NO  → bootstrap.sh y/N sequential prompts (existing BOOTSTRAP-01 flow)
             └─ TK_NO_BOOTSTRAP=1 → silent non-interactive (CI)
```

The v4.4 `bootstrap.sh` sequential flow stays unchanged as the no-TTY fallback. `--yes` flag sets all checked=1 and skips both TUI and prompts.

**Confidence: HIGH** — pattern verified live on macOS Bash 3.2.57. Escape sequence routing confirmed. `read -rsn1` + `read -rsn2` chain confirmed working.

#### Anti-recommendation: `dialog` / `whiptail`

`dialog` is pre-installed on most Linux distros (comes with util-linux/ncurses) but is NOT installed on macOS at all — not even on Big Sur/Ventura/Sequoia. `whiptail` (newt-based alternative) similarly absent on macOS. Using either would:

- Break every macOS user unless they `brew install dialog` first
- Add a dependency not listed in any existing requirement
- Violate the "no deps in install path" constraint from `PROJECT.md:135`

Never use `dialog` or `whiptail` in this project's install scripts.

#### Anti-recommendation: `gum` / `fzf`

`gum` (charmbracelet) and `fzf` are excellent TUI tools but are both third-party binaries requiring separate install. Per project constraints, install scripts must work without any runtime dependencies beyond `bash`, `curl`, `jq` (already declared). These are disqualified.

---

### Q7: Anthropic Claude Code plugin marketplace schema

**Researched: 2026-04-29. Source: `https://code.claude.com/docs/en/plugin-marketplaces` (fetched 2026-04-29). Confidence: HIGH — read from official Anthropic docs.**

#### Directory structure

A marketplace lives in any git repository. The only required file is `.claude-plugin/marketplace.json` at the repo root:

```
sergei-aronsen/claude-code-toolkit/
├── .claude-plugin/
│   └── marketplace.json      ← marketplace catalog
├── plugins/
│   ├── tk-skills/
│   │   └── .claude-plugin/
│   │       └── plugin.json   ← optional per-plugin manifest
│   ├── tk-commands/
│   └── tk-framework-rules/
```

#### `marketplace.json` complete schema

Required fields:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | string | YES | Kebab-case, no spaces. Becomes `@name` in `/plugin install foo@name`. Reserved names blocked (see below). |
| `owner.name` | string | YES | Maintainer name |
| `plugins` | array | YES | List of plugin entries |

Optional fields:

| Field | Type | Notes |
|-------|------|-------|
| `$schema` | string | `"https://anthropic.com/claude-code/marketplace.schema.json"` — editor autocomplete only, ignored at load time |
| `description` | string | Brief marketplace description |
| `version` | string | Marketplace manifest version |
| `owner.email` | string | Contact email |
| `metadata.pluginRoot` | string | Base dir prepended to relative plugin sources, e.g. `"./plugins"` |
| `allowCrossMarketplaceDependenciesOn` | array | Other marketplace names plugins here may depend on |

Reserved marketplace names (blocked by Anthropic): `claude-code-marketplace`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `knowledge-work-plugins`, `life-sciences`. Impersonation names like `official-claude-plugins` also blocked.

#### Plugin entry inside `marketplace.json`

Required fields per plugin:

| Field | Type | Required |
|-------|------|----------|
| `name` | string | YES — kebab-case identifier |
| `source` | string or object | YES — where to fetch from |

Source types:

| Type | Format | Notes |
|------|--------|-------|
| Relative path | `"./plugins/tk-skills"` | Must start with `./`. Works only when marketplace added via git, not URL |
| `github` | `{"source":"github","repo":"owner/repo","ref?":"main","sha?":"abc..."}` | Recommended for monorepo sub-plugins |
| `git-subdir` | `{"source":"git-subdir","url":"...","path":"plugins/tk-skills","ref?":"main"}` | Sparse clone — minimizes bandwidth for monorepos |
| `url` | `{"source":"url","url":"https://...","ref?":"main"}` | Any git host |
| `npm` | `{"source":"npm","package":"@org/plugin","version?":"1.0.0"}` | npm registry |

For `sergei-aronsen/claude-code-toolkit`, use **relative paths** (monorepo with sub-plugins in `plugins/`) since users will add the marketplace via `owner/repo` GitHub shorthand, not URL. Git-based addition resolves relative paths correctly.

Optional plugin fields (can include any `plugin.json` field):

| Field | Type | Notes |
|-------|------|-------|
| `description` | string | |
| `version` | string | If set, update only on bump. Omit to use commit SHA. |
| `author.name` | string | |
| `homepage` | string | |
| `category` | string | `development`, `productivity`, `security`, etc. |
| `skills` | string or array | Custom path to skills directory |
| `commands` | string or array | Custom path(s) to command `.md` files |
| `agents` | string or array | Custom path(s) to agent files |
| `hooks` | string or object | Inline hooks or path to `hooks.json` |
| `strict` | boolean | `true` (default): `plugin.json` is authority. `false`: marketplace entry is sole definition. |

#### `plugin.json` complete schema

Location: `<plugin-root>/.claude-plugin/plugin.json`

The manifest is OPTIONAL — if omitted, Claude Code auto-discovers `skills/`, `commands/`, `agents/`, `hooks/hooks.json` from default locations and derives the plugin name from the directory name.

```json
{
  "name": "tk-skills",
  "version": "1.0.0",
  "description": "Claude Code Toolkit skills: api-design, i18n, observability, llm-patterns, docker, tailwind, database, ai-models",
  "author": {
    "name": "Sergei Aronsen",
    "email": "sergei.aronsen@gmail.com"
  },
  "homepage": "https://github.com/sergei-aronsen/claude-code-toolkit",
  "repository": "https://github.com/sergei-aronsen/claude-code-toolkit",
  "license": "MIT",
  "skills": "./skills/",
  "commands": "./commands/"
}
```

Required in `plugin.json`: only `name` (if manifest is present at all).

#### How users add the marketplace

```bash
# Inside Claude Code (interactive):
/plugin marketplace add sergei-aronsen/claude-code-toolkit

# CLI:
claude plugin marketplace add sergei-aronsen/claude-code-toolkit

# With scope (project-level, shared via .claude/settings.json):
claude plugin marketplace add sergei-aronsen/claude-code-toolkit --scope project

# Then install individual sub-plugins:
/plugin install tk-skills@claude-code-toolkit
/plugin install tk-commands@claude-code-toolkit
/plugin install tk-framework-rules@claude-code-toolkit
```

#### Where plugins land after install

Installed plugins are copied to a local versioned cache:

```
~/.claude/plugins/
├── known_marketplaces.json         ← registered marketplace list
├── marketplaces/
│   └── claude-code-toolkit/        ← marketplace git clone
│       └── .claude-plugin/
│           └── marketplace.json
└── cache/
    └── claude-code-toolkit/        ← per-marketplace plugin cache
        ├── tk-skills/
        │   └── <version>/          ← versioned copy of plugin files
        ├── tk-commands/
        └── tk-framework-rules/
```

**Critical constraint:** Plugins are COPIED to the cache, not symlinked. Paths like `../shared-utils` will break — plugins cannot reference files outside their own directory tree. Sub-plugins must be self-contained.

Plugin installation scope (set via `--scope` flag):

| Scope | Settings file | Use |
|-------|---------------|-----|
| `user` (default) | `~/.claude/settings.json` | Personal, across all projects |
| `project` | `.claude/settings.json` | Team, via version control |
| `local` | `.claude/settings.local.json` | Personal, this repo only |

#### Validation

```bash
# From marketplace root:
claude plugin validate .
# or inside Claude Code:
/plugin validate .
```

Checks `plugin.json`, skill/agent/command frontmatter, `hooks/hooks.json` syntax.

**Confidence: HIGH** — sourced directly from `https://code.claude.com/docs/en/plugin-marketplaces` fetched 2026-04-29.

---

### Q8: Desktop vs. Code plugin runtime delta

**Researched: 2026-04-29. Source: `https://code.claude.com/docs/en/desktop` (fetched 2026-04-29). Confidence: HIGH.**

#### Clarification: "Claude Desktop" = Claude Desktop app's Code tab

The Anthropic docs name this "Claude Code Desktop." It is NOT a separate product — it is the **Code tab** of the Claude Desktop app (the same app that has Chat and Cowork tabs). It runs the full Claude Code engine wrapped in a GUI. The plugin system is shared.

This means the originally scoped goal ("publish for Claude Desktop users to get skills") requires **no special runtime accommodation** — Claude Desktop Code tab supports the same plugin system as the terminal CLI.

#### Capability matrix: Claude Code Desktop (GUI) vs. Terminal CLI

| Feature | Terminal CLI | Desktop Code Tab | Notes |
|---------|-------------|-----------------|-------|
| Plugin marketplace add/install | YES (slash commands + CLI) | YES (GUI + slash commands) | Desktop also has a graphical Discover/Installed/Marketplaces UI |
| Skills (`SKILL.md`) | YES | YES | Invoked via `/` menu or `+` button |
| Commands (flat `.md`) | YES | YES | Same as skills |
| Agents | YES | YES | |
| Hooks | YES | YES | |
| MCP servers (bundled) | YES | YES | |
| LSP servers | YES | YES | |
| Monitors | YES | YES | |
| Plugins for remote sessions | YES | NO | "Plugins are not available for remote sessions" — explicit doc constraint |
| Project-scoped plugins | YES | YES | |
| User-scoped plugins | YES | YES | |
| `~/.claude/settings.json` | YES | YES | Shared |
| CLAUDE.md loading | YES | YES | |
| `.claude/rules/` auto-load | YES | YES | |
| Hooks running shell commands | YES | YES | Same trust level |
| `--no-banner`, `--no-bootstrap` flags | YES | N/A | Desktop doesn't use CLI flags; env vars still honored |
| TUI installer (arrow+space) | YES (terminal only) | N/A | Desktop has its own GUI for plugin management |

**Key finding:** There is no separate "Claude Desktop runtime" that has reduced plugin capability compared to terminal Claude Code. They run the same engine. The only capability gap is remote sessions (cloud-hosted) not supporting plugins.

**Implication for Phase 25:** The original plan to ship "tk-skills (Desktop-compatible — primary Desktop value)" as a special subset is **overly conservative**. All three sub-plugins (tk-skills, tk-commands, tk-framework-rules) will work in Claude Code Desktop. The `docs/CLAUDE_DESKTOP.md` should explain this rather than restrict what's published.

**Confidence: HIGH** — confirmed from desktop docs section "Install plugins": "Plugins are reusable packages that add skills, agents, hooks, MCP servers, and LSP configurations to Claude Code. You can install plugins from the desktop app without using the terminal." Remote session exception explicitly stated: "Plugins are not available for remote sessions."

#### What DOES differ: Chat tab vs. Code tab

The Chat tab of the Claude Desktop app (not the Code tab) is a conversational interface with NO plugin system. It does not support Claude Code plugins, skills, hooks, or the marketplace. This is the product marketed as "Claude" (conversational), not "Claude Code." If users ask "does this work in Claude Desktop?" they might mean either — clarify in docs.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `jq` for all JSON | `python3 -c json` for all JSON | If jq is unavailable. python3 already required for settings.json mutation, so it is always present. Use as fallback only: `jq ... 2>/dev/null \|\| python3 -c "..."`. |
| Single extended `manifest.json` | Per-mode manifests (`manifest-standalone.json`, `manifest-complement.json`) | Never — creates the same four-list-drift problem at the manifest level. |
| `mv` atomic write | Direct write to destination | Never — partial writes are visible to concurrent readers and crash-interrupted writes corrupt the file. |
| `kill -0` PID lock | `flock` | Only on Linux-only tools where BSD compat is not needed. Never for this project. |
| bash 3.2+ POSIX | bash 4+ associative arrays | Only if you drop macOS as a target platform. Not justified here. |
| Pure `read -rsn1` TUI | `dialog`/`whiptail` | Never for this project. Not on macOS. Violates no-deps constraint. |
| Pure `read -rsn1` TUI | `gum`/`fzf` | Never for this project. Third-party binary, violates no-deps constraint. |
| `read -rsn2` for ESC tail | `read -sN1 -t 0.0001` (Bash 4 pattern) | Never — `-N` and sub-second `-t` both absent from Bash 3.2. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `jq` for `settings.json` mutation | `settings.json` may contain JSON5-adjacent syntax (trailing commas) or be malformed; `jq` will hard-fail and the user loses their settings | `python3` with `json.load` + `json.dump` + backup — already established in setup-security.sh |
| `sed`/`awk` for JSON parsing | Cannot handle nested structures, multiline values, Unicode; produces silent wrong output when format deviates; the existing `grep -o '"version"...'` in update-claude.sh:74 is an example of this fragility | `jq` for read, `python3` for write |
| `flock` for locking | Linux-only, not available on macOS BSD | PID-file lock with `kill -0` check |
| `head -n -1` for text processing | GNU-only; silent empty output on macOS BSD `head` — the bug documented in update-claude.sh:186 | Use `awk 'NR>1{print prev} {prev=$0}'` for "all but last line" or restructure to not need it |
| `bash 4+` associative arrays for skip-lists | Breaks macOS default bash (3.2) | `jq`-computed skip-list from manifest metadata |
| `declare -n` nameref in TUI code | Bash 4.3+ only. macOS Bash 3.2 does NOT support it | Pass array name as string, expand with `eval` or use positional parameters |
| `read -N` (capital N) | Bash 4+ only — reads exact count ignoring delimiters. Absent from Bash 3.2 | `read -rsn1` (lowercase `-n`) |
| `read -t 0.001` (float timeout) | Bash 3.2 error: "invalid timeout specification". Only integer seconds work in Bash 3.2 | Use `read -rsn2` to read the ESC tail synchronously (already buffered) |
| `dialog` | Absent on macOS (not in base system). Requires `brew install dialog`. Violates no-deps constraint | Pure `read -rsn1` TUI pattern |
| `whiptail` | Absent on macOS. Requires `brew install newt`. Violates no-deps constraint | Pure `read -rsn1` TUI pattern |
| `gum` (charmbracelet) | Third-party binary. Requires separate install step. Violates no-deps constraint | Pure `read -rsn1` TUI pattern |
| `fzf` | Third-party binary. Not universally pre-installed | Pure `read -rsn1` TUI pattern |
| Separate `manifest-*.json` per mode | Recreates the four-list-drift problem at the manifest level | Single manifest with per-file `conflicts_with` metadata |
| Parsing manifest with `grep -o` | Fragile; breaks when key appears twice or whitespace changes | `jq -r '.version'` |
| `npm` or `node` for install-state logic | No Node runtime at install time; users may not have Node on PATH | Pure bash + jq |
| Marketplace via `marketplace.json` at repo root | Wrong location — Claude Code expects `.claude-plugin/marketplace.json` at the repo root, NOT `marketplace.json` | Place at `.claude-plugin/marketplace.json` |
| Paths using `../` in plugin entries | Explicitly blocked by Anthropic validator — "plugins[0].source: Path contains `..`" | Use `./plugins/tk-skills` (relative to marketplace root) |
| Setting `version` in both `plugin.json` AND `marketplace.json` | `plugin.json` always wins silently — marketplace version is masked | Set `version` in exactly one place, or omit and use commit SHA |

---

## Stack Patterns by Mode

**If `standalone` mode (no SP, no GSD detected):**

- Install all files from manifest regardless of `conflicts_with`
- Write `toolkit-install.json` with `"mode": "standalone"`, `"detected_bases": {"superpowers": false, "get-shit-done": false}`

**If `complement-full` mode (both SP and GSD detected):**

- Read `conflicts_with` from each manifest entry; skip files that conflict with either base
- Write install state with full skip-list and skip reasons

**If partial complement mode (`complement-sp` or `complement-gsd`):**

- Same logic; filter only against the detected base's conflicts

**Detection logic (filesystem only, 2 checks, no CLI dependency):**

```bash
SP_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
GSD_DIR="$HOME/.claude/get-shit-done"

HAVE_SP=false
HAVE_GSD=false
[ -d "$SP_DIR" ] && HAVE_SP=true
[ -d "$GSD_DIR" ] && HAVE_GSD=true
```

**If TUI available (interactive terminal with `/dev/tty`):**

- Use `_tui_select_components()` pattern — arrow + space + enter
- Pre-check Toolkit (always), pre-check detected components as `[installed]` with grayed label
- On ENTER: iterate checked array, call per-component install functions

**If no TTY (piped, CI, `--yes` flag):**

- Fall through to `bootstrap_base_plugins()` sequential y/N (existing BOOTSTRAP-01)
- `--yes` flag: skip both TUI and prompts, install default set non-interactively
- `TK_NO_BOOTSTRAP=1`: byte-quiet opt-out (existing)

---

## Sources

- `.planning/PROJECT.md` — filesystem detection paths, out-of-scope decisions, constraints (HIGH confidence, primary source)
- `.planning/codebase/STACK.md` — existing declared dependencies including `jq` as Critical runtime tool (HIGH confidence)
- `.planning/codebase/CONCERNS.md` — sed fragility evidence (`update-claude.sh:74`), GNU `head -n -1` bug (HIGH confidence, direct code evidence)
- `scripts/update-claude.sh:147` — hand-maintained command list vs manifest drift (HIGH confidence, direct code read)
- `scripts/setup-security.sh` — established `python3` + inline heredoc JSON mutation pattern (HIGH confidence, direct code read)
- `scripts/init-claude.sh` — `< /dev/tty` guard pattern for interactive reads under curl|bash (HIGH confidence)
- POSIX specification — `mv` atomicity, `kill -0`, `mktemp` (HIGH confidence, standard)
- `https://code.claude.com/docs/en/plugin-marketplaces` — marketplace.json schema, plugin.json schema, install paths, source types, strict mode (HIGH confidence, official Anthropic docs, fetched 2026-04-29)
- `https://code.claude.com/docs/en/plugins` — plugin component types, directory structure, conversion guide (HIGH confidence, official Anthropic docs, fetched 2026-04-29)
- `https://code.claude.com/docs/en/plugins-reference` — complete plugin manifest schema, installation scopes, SKILL.md frontmatter (HIGH confidence, official Anthropic docs, fetched 2026-04-29)
- `https://code.claude.com/docs/en/skills` — SKILL.md frontmatter reference, invocation control, Desktop skill support (HIGH confidence, official Anthropic docs, fetched 2026-04-29)
- `https://code.claude.com/docs/en/desktop` — Claude Code Desktop capabilities, plugin support in Desktop GUI, remote session limitations (HIGH confidence, official Anthropic docs, fetched 2026-04-29)
- `https://github.com/anthropics/claude-plugins-official/blob/main/.claude-plugin/marketplace.json` — real marketplace.json example from Anthropic's official plugin repo (HIGH confidence, primary source)
- macOS Bash 3.2.57 live testing — `read -rsn1`/`read -rsn2` escape sequences confirmed working; `read -t 0.001` confirmed broken; `read -N` confirmed absent (HIGH confidence, direct test)
- Community pure-bash TUI gist (blurayne) — `read -sN1 -t 0.0001` pattern confirmed Bash 4-only (MEDIUM confidence, community, cross-checked against live Bash 3.2 test)

---

*Stack research for: claude-code-toolkit v4.0 complement-mode refactor + v4.5 TUI installer + marketplace publishing*
*v4.0 researched: 2026-04-17*
*v4.5 additions researched: 2026-04-29*
