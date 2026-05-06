#!/usr/bin/env bash
# scripts/install-claude-memo.sh
#
# Standalone installer for sergei-aronsen/claude-memo — persistent
# engineering memory for Claude Code (vault + SQLite + FTS5 + local
# multilingual-e5-large embeddings + 4 hooks for auto-capture and
# SessionStart context loading).
#
# Steps (each idempotent):
#   1. Verify python3 ≥ 3.11 and git on PATH.
#   2. Clone or git-pull into $HOME/.claude/skills/memo-skill.
#   3. pip install -r requirements.txt (uv when available, falls back to
#      python -m pip).
#   4. Initialise vault at $HOME/memo-vault (or --vault-path).
#   5. Download embedding model (~1.1 GB) — REQUIRES --yes or interactive
#      confirmation because it is a one-time large download.
#   6. Install cron + git auto-push automation.
#   7. Idempotently merge 4 hooks into $HOME/.claude/settings.json.
#   8. Append MEMO_VAULT_PATH export to shell rc (~/.zshrc and ~/.bashrc)
#      if missing.
#   9. Print a one-line summary + next-step hint.
#
# Flags:
#   --dry-run         Print what would happen, write nothing.
#   --yes             Skip all interactive confirmations (CI, auto mode).
#   --vault-path P    Override default vault location ($HOME/memo-vault).
#   --skip-model      Skip the 1.1 GB embedding model download (user can
#                     run `python3 ~/.claude/skills/memo-skill/scripts/memo_engine.py warm-up`
#                     later).
#   --skip-hooks      Skip the settings.json hook merge (advanced — install
#                     manually from examples/hooks.json).
#   --uninstall       Remove hooks, env exports, automation. Vault is left
#                     in place — user can rm -rf ~/memo-vault manually.
#
# Exit codes:
#   0  success (or dry-run)
#   1  missing prerequisite (python3 too old, git missing, jq missing)
#   2  user declined large download confirmation
#   3  pip / git / clone failure
#   4  hook merge failure (settings.json not writable / jq error)

set -euo pipefail

# ───── color helpers (match toolkit convention) ─────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# ───── defaults ─────
REPO_URL="https://github.com/sergei-aronsen/claude-memo.git"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.claude/skills/memo-skill}"
DEFAULT_VAULT="${HOME}/memo-vault"
VAULT_PATH="$DEFAULT_VAULT"
DRY_RUN=0
YES=0
SKIP_MODEL=0
SKIP_HOOKS=0
UNINSTALL=0

# ───── arg parse ─────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)          DRY_RUN=1 ;;
        --yes|-y)           YES=1 ;;
        --vault-path)       shift; VAULT_PATH="${1:?--vault-path needs an arg}" ;;
        --skip-model)       SKIP_MODEL=1 ;;
        --skip-hooks)       SKIP_HOOKS=1 ;;
        --uninstall)        UNINSTALL=1 ;;
        -h|--help)
            sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo -e "${RED}✗${NC} unknown flag: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# ───── helpers ─────
_log()  { printf '%b\n' "$*"; }
_step() { _log "${CYAN}▸${NC} $*"; }
_ok()   { _log "${GREEN}✓${NC} $*"; }
_warn() { _log "${YELLOW}!${NC} $*"; }
_err()  { _log "${RED}✗${NC} $*" >&2; }
_dry()  { _log "${DIM}[dry-run]${NC} $*"; }

# Run a command unless --dry-run; in dry-run, print it.
_run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        _dry "$*"
    else
        "$@"
    fi
}

# Confirm prompt — auto-yes when --yes or --dry-run, otherwise read /dev/tty.
_confirm() {
    local msg="$1" reply
    if [[ $YES -eq 1 || $DRY_RUN -eq 1 ]]; then
        return 0
    fi
    if [[ ! -e /dev/tty ]]; then
        _err "no /dev/tty — pass --yes to skip confirmation"
        return 1
    fi
    printf '%b ' "${YELLOW}?${NC} $msg [y/N]:" >&2
    IFS= read -r reply </dev/tty
    [[ "$reply" =~ ^[yY] ]]
}

# ───── uninstall path ─────
if [[ $UNINSTALL -eq 1 ]]; then
    _log "${CYAN}Uninstalling claude-memo wiring${NC}"
    _log ""

    if [[ -f "$HOME/.claude/settings.json" ]] && command -v jq >/dev/null 2>&1; then
        local_settings="$HOME/.claude/settings.json"
        _step "Removing claude-memo hooks from $local_settings"
        if [[ $DRY_RUN -eq 0 ]]; then
            local_backup="${local_settings}.bak.$(date +%s)"
            cp "$local_settings" "$local_backup"
            jq '
              .hooks.SessionStart = ((.hooks.SessionStart // []) | map(
                .hooks |= map(select(.command | test("memo-skill") | not))
              ) | map(select((.hooks // []) | length > 0))) |
              .hooks.SessionEnd = ((.hooks.SessionEnd // []) | map(
                .hooks |= map(select(.command | test("memo-skill") | not))
              ) | map(select((.hooks // []) | length > 0))) |
              .hooks.PreCompact = ((.hooks.PreCompact // []) | map(
                .hooks |= map(select(.command | test("memo-skill") | not))
              ) | map(select((.hooks // []) | length > 0))) |
              .hooks.Stop = ((.hooks.Stop // []) | map(
                .hooks |= map(select(.command | test("memo-skill") | not))
              ) | map(select((.hooks // []) | length > 0)))
            ' "$local_settings" > "${local_settings}.tmp" && mv "${local_settings}.tmp" "$local_settings"
            _ok "Hooks removed (backup: $local_backup)"
        else
            _dry "jq filter to drop memo-skill hooks from $local_settings"
        fi
    fi

    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [[ -f "$rc" ]] && grep -qE '^export MEMO_VAULT_PATH=' "$rc" 2>/dev/null; then
            _step "Removing MEMO_VAULT_PATH export from $rc"
            if [[ $DRY_RUN -eq 0 ]]; then
                cp "$rc" "${rc}.bak.$(date +%s)"
                grep -v -E '^export MEMO_VAULT_PATH=|^# Added by claude-memo installer' "$rc" > "${rc}.tmp"
                mv "${rc}.tmp" "$rc"
                _ok "Export removed from $rc"
            else
                _dry "strip MEMO_VAULT_PATH export from $rc"
            fi
        fi
    done

    _log ""
    _warn "Vault left in place at $VAULT_PATH and skill at $INSTALL_DIR — remove manually if desired:"
    _log "  rm -rf $INSTALL_DIR $VAULT_PATH"
    exit 0
fi

# ───── prereqs ─────
_log "${CYAN}claude-memo installer${NC} ${DIM}(toolkit v6.2)${NC}"
_log ""

_step "Checking prerequisites"

if ! command -v python3 >/dev/null 2>&1; then
    _err "python3 not on PATH — install Python 3.11+ first"
    exit 1
fi
PY_MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
PY_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')
if (( PY_MAJOR < 3 || (PY_MAJOR == 3 && PY_MINOR < 11) )); then
    _err "python3 ${PY_MAJOR}.${PY_MINOR} found, but claude-memo requires Python 3.11+"
    exit 1
fi
_ok "python3 ${PY_MAJOR}.${PY_MINOR}"

for tool in git jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        _err "$tool not on PATH — install via brew/apt and retry"
        exit 1
    fi
done
_ok "git + jq on PATH"

# Detect uv (faster pip) — optional.
PIP_CMD=("python3" "-m" "pip" "install" "-r")
if command -v uv >/dev/null 2>&1; then
    PIP_CMD=("uv" "pip" "install" "-r")
    _ok "uv detected — will use uv pip (faster)"
fi

# ───── prominent disk-space + download warning ─────
_log ""
_log "${YELLOW}━━━ Heads-up: this installer will ━━━${NC}"
_log "  • Clone claude-memo (~5 MB) into $INSTALL_DIR"
_log "  • Install Python deps (sentence-transformers, numpy, PyYAML, mcp[cli])"
if [[ $SKIP_MODEL -eq 0 ]]; then
    _log "  • ${YELLOW}Download multilingual-e5-large embedding model (~1.1 GB) ONE TIME${NC}"
    _log "    Cached at ~/.cache/memo-models — never re-downloaded after first run."
else
    _log "  • ${DIM}Skip model download (--skip-model passed)${NC}"
fi
_log "  • Initialise vault at $VAULT_PATH (~few KB)"
_log "  • Install cron jobs (reindex every 30 min, git push every hour)"
if [[ $SKIP_HOOKS -eq 0 ]]; then
    _log "  • Idempotently merge 4 hooks into ~/.claude/settings.json"
else
    _log "  • ${DIM}Skip hook merge (--skip-hooks passed)${NC}"
fi
_log ""

if ! _confirm "Proceed?"; then
    _err "Cancelled."
    exit 2
fi

# ───── 1. clone or pull ─────
_log ""
_step "Step 1/7 — Clone or update claude-memo at $INSTALL_DIR"

if [[ -d "$INSTALL_DIR/.git" ]]; then
    _ok "Existing clone detected — pulling latest"
    if [[ $DRY_RUN -eq 0 ]]; then
        ( cd "$INSTALL_DIR" && git pull --ff-only origin main >/dev/null 2>&1 ) \
            || _warn "git pull failed (offline?) — continuing with cached copy"
    else
        _dry "git -C $INSTALL_DIR pull --ff-only origin main"
    fi
else
    _run mkdir -p "$(dirname "$INSTALL_DIR")"
    _run git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" || {
        _err "git clone failed"
        exit 3
    }
fi

# ───── 2. python deps ─────
_log ""
_step "Step 2/7 — Install Python dependencies"

if [[ $DRY_RUN -eq 0 ]]; then
    "${PIP_CMD[@]}" "$INSTALL_DIR/requirements.txt" || {
        _err "pip install failed — check the error above and retry"
        exit 3
    }
    _ok "Dependencies installed"
else
    _dry "${PIP_CMD[*]} $INSTALL_DIR/requirements.txt"
fi

# ───── 3. vault init ─────
_log ""
_step "Step 3/7 — Initialise vault at $VAULT_PATH"

if [[ -f "$VAULT_PATH/INDEX.md" ]]; then
    _ok "Vault already exists at $VAULT_PATH — skipping init"
else
    _run bash "$INSTALL_DIR/scripts/init_vault.sh" "$VAULT_PATH"
    _ok "Vault initialised"
fi

# ───── 4. embedding model warm-up (the BIG step) ─────
_log ""
if [[ $SKIP_MODEL -eq 1 ]]; then
    _step "Step 4/7 — Skipping model download (--skip-model)"
    _warn "Run later: python3 $INSTALL_DIR/scripts/memo_engine.py warm-up"
elif [[ -d "$HOME/.cache/memo-models" ]] && [[ -n "$(ls -A "$HOME/.cache/memo-models" 2>/dev/null)" ]]; then
    _step "Step 4/7 — Embedding model already cached at ~/.cache/memo-models"
    _ok "Skipping (re)download"
else
    _step "Step 4/7 — Downloading multilingual-e5-large (~1.1 GB, one-time)"
    _log "${DIM}This takes 2-5 minutes on a normal connection. Progress to follow.${NC}"
    if [[ $DRY_RUN -eq 0 ]]; then
        python3 "$INSTALL_DIR/scripts/memo_engine.py" warm-up || {
            _err "Model download failed — check network + disk space"
            exit 3
        }
        _ok "Model cached at ~/.cache/memo-models"
    else
        _dry "python3 $INSTALL_DIR/scripts/memo_engine.py warm-up"
    fi
fi

# ───── 5. automation (cron + git auto-push) ─────
_log ""
_step "Step 5/7 — Install cron + git auto-push automation"

_run bash "$INSTALL_DIR/scripts/setup_automation.sh" "$VAULT_PATH"
_ok "Automation installed"

# ───── 6. hook merge ─────
_log ""
if [[ $SKIP_HOOKS -eq 1 ]]; then
    _step "Step 6/7 — Skipping hook merge (--skip-hooks)"
    _warn "Manually merge $INSTALL_DIR/examples/hooks.json into ~/.claude/settings.json"
else
    _step "Step 6/7 — Idempotent hook merge into ~/.claude/settings.json"

    SETTINGS="$HOME/.claude/settings.json"
    HOOKS_SRC="$INSTALL_DIR/examples/hooks.json"

    if [[ $DRY_RUN -eq 1 ]]; then
        _dry "would jq-merge $HOOKS_SRC into $SETTINGS (idempotent dedup by command string)"
    elif [[ ! -f "$HOOKS_SRC" ]]; then
        _err "hook source missing: $HOOKS_SRC"
        exit 4
    fi

    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$(dirname "$SETTINGS")"
        if [[ ! -f "$SETTINGS" ]]; then
            echo '{}' > "$SETTINGS"
        fi
        # Backup before mutating shared global config.
        BACKUP="${SETTINGS}.bak.$(date +%s)"
        cp "$SETTINGS" "$BACKUP"

        # Merge: for each event (SessionStart/SessionEnd/PreCompact/Stop), append
        # claude-memo hooks IF a matching command (containing "memo-skill") is not
        # already present. Idempotent — safe to rerun.
        TMP=$(mktemp)
        jq --slurpfile new "$HOOKS_SRC" '
          def merge_event(event):
            (.hooks // {}) as $cur |
            ($new[0].hooks[event] // []) as $new_event |
            (($cur[event] // []) + $new_event) as $combined |
            # Drop duplicates by stringifying each entry.
            ($combined | unique_by(. | tostring)) as $dedup |
            .hooks = (($cur // {}) + {(event): $dedup});

          merge_event("SessionStart") |
          merge_event("SessionEnd") |
          merge_event("PreCompact") |
          merge_event("Stop")
        ' "$SETTINGS" > "$TMP" || {
            _err "jq merge failed — settings.json untouched"
            rm -f "$TMP"
            exit 4
        }
        mv "$TMP" "$SETTINGS"
        _ok "Hooks merged (backup: $BACKUP)"
    fi
fi

# ───── 7. shell rc env export ─────
_log ""
_step "Step 7/7 — Append MEMO_VAULT_PATH export to shell rc files"

EXPORT_LINE="export MEMO_VAULT_PATH=$VAULT_PATH"
MARKER="# Added by claude-memo installer"
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if grep -qE '^export MEMO_VAULT_PATH=' "$rc" 2>/dev/null; then
        _ok "$rc already exports MEMO_VAULT_PATH — skipping"
        continue
    fi
    if [[ $DRY_RUN -eq 0 ]]; then
        {
            echo ""
            echo "$MARKER"
            echo "$EXPORT_LINE"
        } >> "$rc"
        _ok "Appended export to $rc"
    else
        _dry "append '$EXPORT_LINE' to $rc"
    fi
done

# ───── summary ─────
_log ""
_log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
_log "${GREEN}claude-memo installed.${NC}"
_log ""
_log "  Vault:       $VAULT_PATH"
_log "  Skill:       $INSTALL_DIR"
_log "  Settings:    $HOME/.claude/settings.json (4 hooks merged)"
_log ""
_log "Next steps:"
_log "  1. ${CYAN}source ~/.zshrc${NC} (or open a new terminal) — picks up MEMO_VAULT_PATH"
_log "  2. (optional) ${CYAN}export ANTHROPIC_API_KEY=…${NC} — enables auto-classification (~\$0.002/session)"
_log "     Without it, manual ${CYAN}/memo${NC} still works for free."
_log "  3. Restart Claude Code in a project directory — SessionStart hook injects vault context."
_log ""
_log "Docs: https://github.com/sergei-aronsen/claude-memo"
_log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
