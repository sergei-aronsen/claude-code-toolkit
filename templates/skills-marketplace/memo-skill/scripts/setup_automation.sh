#!/usr/bin/env bash
# setup_automation.sh — Install cron jobs for vault maintenance.
#
# What it sets up:
#   1. Auto-reindex every 30 min (catches Obsidian edits)
#   2. Git auto-commit + push every hour (backup)
#   3. Model warm-up at login (eliminates cold start)
#
# Usage: bash setup_automation.sh ~/memo-vault

set -euo pipefail

VAULT_PATH="${1:-$HOME/memo-vault}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEMO_ENGINE="$SCRIPT_DIR/memo_engine.py"

# Resolve full path to python3 so cron can find it (cron has minimal PATH)
PYTHON3="$(which python3)"

echo "═══════════════════════════════════════════════"
echo "  Setting up vault automation"
echo "  Vault: $VAULT_PATH"
echo "  Python: $PYTHON3"
echo "═══════════════════════════════════════════════"

# ─── 1. Auto-reindex cron (every 30 min) ───

REINDEX_CRON="*/30 * * * * cd $VAULT_PATH && $PYTHON3 $MEMO_ENGINE reindex --vault $VAULT_PATH --incremental >> $VAULT_PATH/.memo/reindex.log 2>&1"

# Check if cron already exists
if crontab -l 2>/dev/null | grep -q "memo_engine.py reindex"; then
    echo "  ✓ Auto-reindex cron already installed"
else
    (crontab -l 2>/dev/null; echo "$REINDEX_CRON") | crontab -
    echo "  ✓ Auto-reindex cron installed (every 30 min)"
fi

# ─── 2. Git auto-commit + push (every hour) ───

GIT_CRON="0 * * * * cd $VAULT_PATH && git add -A && git diff --cached --quiet || git commit -m 'auto: vault sync \$(date +\\%Y-\\%m-\\%d\\ \\%H:\\%M)' && git push origin main 2>/dev/null || true"

if crontab -l 2>/dev/null | grep -q "vault sync"; then
    echo "  ✓ Git sync cron already installed"
else
    # Only install if git remote is configured
    if cd "$VAULT_PATH" && git remote get-url origin >/dev/null 2>&1; then
        (crontab -l 2>/dev/null; echo "$GIT_CRON") | crontab -
        echo "  ✓ Git sync cron installed (every hour)"
    else
        echo "  ⚠ No git remote configured. Skipping auto-push."
        echo "    To enable: cd $VAULT_PATH && git remote add origin <your-repo-url>"
        echo "    Then re-run this script."
    fi
fi

# ─── 3. Compile daily logs → wiki articles (daily at 18:00) ───

COMPILE_SCRIPT="$SCRIPT_DIR/compile_logs.py"
COMPILE_CRON="0 18 * * * $PYTHON3 $COMPILE_SCRIPT --vault $VAULT_PATH >> $VAULT_PATH/.memo/compile.log 2>&1"

if crontab -l 2>/dev/null | grep -q "compile_logs.py"; then
    echo "  ✓ Compile cron already installed"
else
    (crontab -l 2>/dev/null; echo "$COMPILE_CRON") | crontab -
    echo "  ✓ Compile cron installed (daily at 18:00)"
fi

# ─── 4. Model warm-up at login ───

WARMUP_LINE="# Memo vault: pre-load embedding model"
WARMUP_CMD="($PYTHON3 $MEMO_ENGINE warm-up > /dev/null 2>&1 &)"

# Detect shell config file
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC=""
fi

if [ -n "$SHELL_RC" ]; then
    if grep -q "memo_engine.py warm-up" "$SHELL_RC" 2>/dev/null; then
        echo "  ✓ Model warm-up already in $SHELL_RC"
    else
        echo "" >> "$SHELL_RC"
        echo "$WARMUP_LINE" >> "$SHELL_RC"
        echo "$WARMUP_CMD" >> "$SHELL_RC"
        echo "  ✓ Model warm-up added to $SHELL_RC"
        echo "    Model will pre-load in background when you open terminal"
    fi
fi

# ─── 5. Environment variable for vault path ───

if [ -n "$SHELL_RC" ]; then
    if grep -q "MEMO_VAULT_PATH" "$SHELL_RC" 2>/dev/null; then
        echo "  ✓ MEMO_VAULT_PATH already set"
    else
        echo "export MEMO_VAULT_PATH=\"$VAULT_PATH\"" >> "$SHELL_RC"
        echo "  ✓ MEMO_VAULT_PATH added to $SHELL_RC"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  Automation ready!"
echo ""
echo "  Cron jobs: crontab -l"
echo "  Reindex log: $VAULT_PATH/.memo/reindex.log"
echo "  Auto-memo log: $VAULT_PATH/.memo/auto_memo.log"
echo "═══════════════════════════════════════════════"
