# Phase 1: Pre-work Bug Fixes - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 8 (6 scripts + manifest.json + Makefile + CHANGELOG.md)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/update-claude.sh` (BUG-01, BUG-07) | utility | transform | `scripts/update-claude.sh` itself (self-fix) | exact |
| `scripts/setup-council.sh` (BUG-02, BUG-03, BUG-04) | config | request-response | `scripts/init-claude.sh` (BUG-02/03); `scripts/setup-council.sh` (BUG-04 target) | exact |
| `scripts/init-claude.sh` (BUG-03) | installer | request-response | `scripts/setup-council.sh` (parallel heredoc site) | role-match |
| `scripts/setup-security.sh` (BUG-05) | config | file-I/O | `scripts/install-statusline.sh:98-106` (backup) + itself (python3 mutation) | exact |
| `scripts/init-local.sh` (BUG-06) | installer | transform | `scripts/install-statusline.sh:31-40` (jq read) | role-match |
| `manifest.json` (BUG-06 context, BUG-07 audit) | config | transform | itself | exact |
| `CHANGELOG.md` (BUG-06) | documentation | transform | `CHANGELOG.md:8-10` existing `[Unreleased]` block | exact |
| `Makefile` (BUG-06 D-18, BUG-07 D-23) | build | batch | `Makefile:66-86` existing `validate` target | exact |

---

## Pattern Assignments

### `scripts/update-claude.sh` — BUG-01: replace `head -n -1` with `sed '$d'`

**Analog:** self (lines 186-195 are the target)

**Target pattern (current broken code)** (`scripts/update-claude.sh:186-195`):

```bash
sed -n '/^## 🎯 Project Overview/,/^## [^P]/p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.overview" 2>/dev/null || true

sed -n '/^## 📁 Project Structure/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.structure" 2>/dev/null || true

sed -n '/^## ⚡ Essential Commands/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.commands" 2>/dev/null || true

sed -n '/^## ⚠️ Project-Specific Notes/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.notes" 2>/dev/null || true
```

**Fix pattern — replace `| head -n -1` with `| sed '$d'`** (POSIX, BSD + GNU):

```bash
sed -n '/^## 🎯 Project Overview/,/^## [^P]/p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.overview" 2>/dev/null || true
```

Apply the same substitution to all four lines (structure, commands, notes). One-to-one replacement; the `|| true` and `2>/dev/null` stay intact.

---

### `scripts/update-claude.sh` — BUG-07: add missing commands to the install loop

**Analog:** `manifest.json:22-53` (canonical commands list)

**Target (current hand-maintained list)** (`scripts/update-claude.sh:147`):

```bash
for file in plan.md tdd.md context-prime.md checkpoint.md handoff.md audit.md test.md refactor.md doc.md fix.md explain.md helpme.md verify.md debug.md learn.md update-toolkit.md worktree.md migrate.md find-function.md find-script.md docker.md api.md e2e.md perf.md deps.md council.md deploy.md fix-prod.md rollback-update.md; do
```

**Canonical list from `manifest.json:22-53`** — commands present in manifest but absent from the loop (audit result):

- `commands/design.md` — confirmed missing (BUG-07 primary)

Cross-reference each basename in the loop against `manifest.json:22-53` at implementation time and add all drifted entries to the `for file in ...` list.

---

### `scripts/setup-council.sh` — BUG-02: `< /dev/tty` guards for interactive `read`

**Analog:** `scripts/init-claude.sh:84,430,468,479,504`

**Analog pattern — `init-claude.sh:84`** (simplest form, choice prompt):

```bash
local choice
if ! read -r -p "  Enter choice [1-8] (default: 1): " choice < /dev/tty 2>/dev/null; then
    choice="1"
fi
choice="${choice:-1}"
```

**Analog pattern — `init-claude.sh:430`** (Y/n prompt):

```bash
local configure
if ! read -r -p "  Configure Supreme Council now? [Y/n]: " configure < /dev/tty 2>/dev/null; then
    configure="N"
fi
configure="${configure:-Y}"
```

**Analog pattern — `init-claude.sh:479`** (API key, skippable):

```bash
read -r -p "    Enter Gemini API key (or press Enter to skip): " gemini_key < /dev/tty 2>/dev/null || true
```

**Target lines in `setup-council.sh`** — apply the same `< /dev/tty 2>/dev/null` suffix to:

- Line 93: `read -r -p "  Enter choice [1/2] (default: 1): " GEMINI_CHOICE`
- Line 103: `read -r -p "  Enter Gemini API key (or press Enter to skip): " GEMINI_KEY`
- Line 134: `read -r -p "  Enter OpenAI API key (or press Enter to skip): " OPENAI_KEY`

**Early non-interactive guard (D-04)** — add at top of script after color constants, before Step 1:

```bash
# Guard: exit cleanly when stdin is not a terminal (CI / curl | bash)
if [[ ! -r /dev/tty ]]; then
    echo -e "${RED}✗${NC} This script requires an interactive terminal."
    echo -e "  Run it directly, not via 'curl | bash'."
    exit 1
fi
```

---

### `scripts/setup-council.sh` + `scripts/init-claude.sh` — BUG-03: JSON-escape API keys before heredoc write

**Analog:** `scripts/setup-security.sh:201-237` (python3 inline heredoc JSON mutation)

**Analog — `setup-security.sh:202-237`** (python3 heredoc pattern):

```bash
if python3 - "$SETTINGS_JSON" "$HOOK_COMMAND" << 'PYEOF' 2>/dev/null
import json, sys

settings_path = sys.argv[1]
hook_command = sys.argv[2]

with open(settings_path, 'r') as f:
    config = json.load(f)
# ... mutation ...
with open(settings_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
PYEOF
```

**Fix pattern for BUG-03** — escape each key value before interpolating into heredoc. Use `python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))'` to produce a quoted JSON string (including the surrounding `"`), then strip the outer quotes to get just the escaped value, OR write the entire config via `python3` instead of the heredoc.

Simplest approach (escape-before-interpolation):

```bash
GEMINI_KEY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$GEMINI_KEY")
OPENAI_KEY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$OPENAI_KEY")
```

Then the heredoc becomes:

```bash
cat > "$CONFIG_FILE" << CONFIGEOF
{
  "gemini": {
    "mode": "$GEMINI_MODE",
    "api_key": $GEMINI_KEY_JSON,
    "model": "gemini-3-pro-preview"
  },
  "openai": {
    "api_key": $OPENAI_KEY_JSON,
    "model": "gpt-5.2"
  }
}
CONFIGEOF
```

Note: `json.dumps()` produces `"value"` including quotes, so the heredoc line uses `$VAR_JSON` without additional `"` wrappers.

**Apply to:**

- `scripts/setup-council.sh:178-190` (heredoc write)
- `scripts/init-claude.sh:513-525` (parallel heredoc in `setup_council` function)
- `scripts/setup-council.sh:103` + `scripts/init-claude.sh:479` — add `-s` flag to `read` for silent entry: `read -rs -p "..."` (D-08)

---

### `scripts/setup-council.sh` — BUG-04: remove silent `sudo apt-get`

**Analog:** No direct analog in the codebase — the current pattern (line 66) is the anti-pattern. The correct pattern is the brew fallback already present on lines 62-64 (non-sudo, visible output).

**Target (broken, lines 59-75)**:

```bash
if ! command -v tree &>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} tree not found, installing..."
    if command -v brew &>/dev/null; then
        brew install tree 2>/dev/null
        echo -e "  ${GREEN}✓${NC} tree installed via Homebrew"
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq tree 2>/dev/null  # BUG: silent sudo
        echo -e "  ${GREEN}✓${NC} tree installed via apt"
    else
        echo -e "  ${YELLOW}⚠${NC} Could not install tree automatically"
    fi
fi
```

**Fix pattern (D-09, D-10, D-11)** — prompt user, never invoke sudo, drop `2>/dev/null`:

```bash
elif command -v apt-get &>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} tree not installed. To install, run:"
    echo -e "      sudo apt-get install tree"
    local install_tree
    if ! read -r -p "  Proceed? [y/N]: " install_tree < /dev/tty 2>/dev/null; then
        install_tree="N"
    fi
    if [[ "${install_tree:-N}" =~ ^[Yy]$ ]]; then
        sudo apt-get install tree
    else
        echo -e "  ${YELLOW}⚠${NC} tree skipped — brain.py structure analysis will be disabled"
    fi
```

Error handling pattern (consistent with setup-council.sh lines 37-39):

```bash
    # If install failed or skipped:
    echo -e "  ${YELLOW}⚠${NC} tree not found — brain.py structure analysis will be skipped"
```

---

### `scripts/setup-security.sh` — BUG-05: backup `settings.json` before mutation

**Analog:** `scripts/install-statusline.sh:103-106` (backup before overwrite)

**Analog — `install-statusline.sh:103-106`**:

```bash
echo -e "  ${YELLOW}⚠${NC} Could not parse settings.json, creating backup"
cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
```

**D-12 fix pattern** — timestamp-suffixed backup immediately before each python3 mutation block. Apply at `setup-security.sh:202`, `310`, and `346`:

```bash
# Backup before mutation (BUG-05)
cp "$SETTINGS_JSON" "${SETTINGS_JSON}.bak.$(date +%s)"
```

**D-13 restore-on-failure pattern** — wrap each python3 block:

```bash
SETTINGS_BACKUP="${SETTINGS_JSON}.bak.$(date +%s)"
cp "$SETTINGS_JSON" "$SETTINGS_BACKUP"

if python3 - "$SETTINGS_JSON" ... << 'PYEOF' 2>/dev/null
# ... mutation ...
PYEOF
then
    echo -e "  ${GREEN}✓${NC} settings.json updated"
else
    cp "$SETTINGS_BACKUP" "$SETTINGS_JSON"
    echo -e "  ${RED}✗${NC} JSON merge failed — restored from backup: $SETTINGS_BACKUP"
    exit 1
fi
```

D-14 note: keep `$(date +%s)` (unix timestamp), not `$(date +%Y%m%d)` — matches `install-statusline.sh` exactly. Idempotency is guaranteed by the timestamp being unique per second.

---

### `scripts/init-local.sh` — BUG-06: read version from `manifest.json` instead of hardcoded constant

**Analog:** `scripts/install-statusline.sh:31-40` (jq read pattern); `manifest.json:2` (source of truth)

**Target (broken, `init-local.sh:11`)**:

```bash
VERSION="2.0.0"
```

**Target (broken, `init-local.sh:38-40`)** — version printed via `--version` flag:

```bash
echo "claude-code-toolkit v$VERSION (local)"
```

**Fix pattern (D-16)** — read from manifest at runtime with `jq` + `sed` fallback:

```bash
MANIFEST_FILE="$GUIDES_DIR/manifest.json"
if command -v jq &>/dev/null && [[ -f "$MANIFEST_FILE" ]]; then
    VERSION=$(jq -r '.version' "$MANIFEST_FILE")
else
    VERSION=$(grep -m1 '"version"' "$MANIFEST_FILE" 2>/dev/null | sed 's/.*"version": *"\([^"]*\)".*/\1/' || echo "unknown")
fi
```

Place after `GUIDES_DIR` is set (line 15) and before the argument-parsing `while` loop (line 31). Remove the hardcoded `VERSION="2.0.0"` at line 11.

---

### `CHANGELOG.md` — BUG-06: add `[Unreleased]` placeholder entry

**Analog:** `CHANGELOG.md:10-end` (existing `[3.0.0]` section format)

**Target (current, `CHANGELOG.md:8-10`)**:

```markdown
## [Unreleased]

## [3.0.0] - 2026-02-16
```

**Fix pattern (D-20)** — add `### Fixed` bullets under `[Unreleased]`:

```markdown
## [Unreleased]

### Fixed

- BUG-01: Replace GNU-only `head -n -1` with POSIX `sed '$d'` in `update-claude.sh` smart-merge
- BUG-02: Add `< /dev/tty` guards to all interactive `read` calls in `setup-council.sh`
- BUG-03: JSON-escape API key values via `python3 json.dumps` before heredoc write in `setup-council.sh` and `init-claude.sh`
- BUG-04: Remove silent `sudo apt-get` for `tree` install; prompt user and handle skip gracefully
- BUG-05: Backup `~/.claude/settings.json` with unix-timestamp suffix before every mutation in `setup-security.sh`; restore on failure
- BUG-06: Read toolkit version from `manifest.json` at runtime in `init-local.sh`; remove hardcoded `VERSION="2.0.0"`
- BUG-07: Add `design.md` (and any other drifted commands) to `update-claude.sh` install loop

## [3.0.0] - 2026-02-16
```

---

### `Makefile` — BUG-06 (D-18) + BUG-07 (D-23): extend `validate` target

**Analog:** `Makefile:66-86` (existing `validate` target structure)

**Existing `validate` target pattern (`Makefile:66-86`)**:

```makefile
validate:
	@echo "Validating templates..."
	@ERRORS=0; \
	for f in $$(find templates -path '*/prompts/*.md' ...); do \
		if ! grep -q "QUICK CHECK" "$$f" 2>/dev/null; then \
			echo "❌ Missing QUICK CHECK: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then \
		echo "Found $$ERRORS errors"; \
		exit 1; \
	fi
	@echo "✅ All templates valid"
```

**D-18 addition** — assert `manifest.json` version equals the latest non-`[Unreleased]` version in `CHANGELOG.md`:

```makefile
	@MANIFEST_VER=$$(grep -m1 '"version"' manifest.json | sed 's/.*"version": *"\([^"]*\)".*/\1/'); \
	CHANGELOG_VER=$$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/'); \
	if [ "$$MANIFEST_VER" != "$$CHANGELOG_VER" ]; then \
		echo "❌ Version mismatch: manifest.json=$$MANIFEST_VER, CHANGELOG.md=$$CHANGELOG_VER"; \
		exit 1; \
	fi; \
	echo "✅ Version aligned: $$MANIFEST_VER"
```

**D-23 addition** — assert every command file in `update-claude.sh` install loop is in `manifest.json`:

```makefile
	@ERRORS=0; \
	MANIFEST_CMDS=$$(grep '"commands/' manifest.json | sed 's|.*"commands/\([^"]*\)".*|\1|'); \
	LOOP_CMDS=$$(grep 'for file in' scripts/update-claude.sh | sed 's/.*for file in //;s/; do.*//'); \
	for cmd in $$LOOP_CMDS; do \
		if ! echo "$$MANIFEST_CMDS" | grep -qx "$$cmd"; then \
			echo "❌ update-claude.sh lists '$$cmd' not in manifest.json commands"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then exit 1; fi; \
	echo "✅ update-claude.sh commands match manifest.json"
```

Both additions append to the existing `validate` target body (before the final `@echo "✅ All templates valid"` line). Tabs must be preserved (Makefile requirement).

---

## Shared Patterns

### Script header (all shell scripts)

**Source:** `scripts/setup-security.sh:1-17`, `scripts/setup-council.sh:1-17`
**Apply to:** Any new code blocks added to existing scripts must stay within files that already have this header — no new scripts in Phase 1.

```bash
#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
```

### User-facing output (all shell scripts)

**Source:** All scripts consistently
**Apply to:** All new `echo` lines in Phase 1 fixes

```bash
echo -e "  ${GREEN}✓${NC} success message"
echo -e "  ${YELLOW}⚠${NC} warning message"
echo -e "  ${RED}✗${NC} error message"
```

### python3 JSON mutation (all JSON-writing sites)

**Source:** `scripts/setup-security.sh:201-237`
**Apply to:** BUG-03 (config.json via python3 escape), BUG-05 (backup + restore wrapper)

```bash
if python3 - "$SETTINGS_JSON" "$ARG" << 'PYEOF' 2>/dev/null
import json, sys
# ... mutation ...
with open(settings_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
PYEOF
then
    echo -e "  ${GREEN}✓${NC} ..."
else
    echo -e "  ${RED}✗${NC} Failed ..."
fi
```

### Interactive read with `/dev/tty` guard

**Source:** `scripts/init-claude.sh:84,430,468,479,504`
**Apply to:** All `read` calls in `setup-council.sh` (BUG-02)

```bash
# Required fallback form (choice with default):
if ! read -r -p "  Prompt text [default]: " VAR < /dev/tty 2>/dev/null; then
    VAR="default"
fi
VAR="${VAR:-default}"

# Required form (optional input, no default):
read -r -p "  Enter value (or press Enter to skip): " VAR < /dev/tty 2>/dev/null || true

# Required form (secret, no echo):
read -rs -p "  Enter API key (or press Enter to skip): " VAR < /dev/tty 2>/dev/null || true
```

### Makefile validate extension

**Source:** `Makefile:66-86`
**Apply to:** BUG-06 (D-18) and BUG-07 (D-23) additions

```makefile
validate:
	@ERRORS=0; \
	# ... existing checks ...
	# append new checks before final echo
	@echo "✅ All templates valid"
```

New checks use `@` prefix (silent invocation), `$$` for shell variables, and `\` line continuation — matching the existing style exactly.

---

## No Analog Found

All files in Phase 1 have close analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `scripts/`, `Makefile`, `manifest.json`, `CHANGELOG.md`
**Files read:** `scripts/update-claude.sh`, `scripts/setup-council.sh`, `scripts/init-claude.sh`, `scripts/setup-security.sh`, `scripts/init-local.sh`, `scripts/install-statusline.sh`, `manifest.json`, `Makefile`, `CHANGELOG.md`
**Pattern extraction date:** 2026-04-17
