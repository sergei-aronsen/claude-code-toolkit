#!/bin/bash

# Claude Code Toolkit — Backup Housekeeping Library
# Source this file. Do NOT execute it directly.
# Exposes: list_backup_dirs, warn_if_too_many_backups
# Globals: none — reads $HOME at call time
#
# Recognized backup patterns:
#   .claude-backup-<ts>-<pid>/           — update-claude.sh standard backup
#   .claude-backup-pre-migrate-<ts>/     — migrate-to-complement.sh pre-migration backup
#   .claude-backup-pre-uninstall-<ts>/   — uninstall.sh pre-uninstall backup (UN-04)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
#            Callers MUST register `trap 'release_lock' EXIT` BEFORE calling acquire_lock.

# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
NC='\033[0m'

# list_backup_dirs — stdout: one absolute path per line, newest epoch first.
# Arg 1 (optional): HOME override for tests; defaults to $HOME.
# Silently ignores dirs whose names don't match either backup pattern.
list_backup_dirs() {
    local home="${1:-$HOME}"
    while IFS= read -r dir; do
        local name epoch
        name="$(basename "$dir")"
        case "$name" in
            .claude-backup-[0-9]*-[0-9]*)
                epoch="${name#.claude-backup-}"
                epoch="${epoch%-*}"
                ;;
            .claude-backup-pre-migrate-[0-9]*)
                epoch="${name#.claude-backup-pre-migrate-}"
                ;;
            .claude-backup-pre-uninstall-[0-9]*)
                epoch="${name#.claude-backup-pre-uninstall-}"
                ;;
            *) continue ;;
        esac
        printf '%s %s\n' "$epoch" "$dir"
    done < <(find "$home" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' \
           -o -name '.claude-backup-pre-migrate-*' \
           -o -name '.claude-backup-pre-uninstall-*' \) \
        2>/dev/null) \
    | sort -rn \
    | cut -d' ' -f2-
}

# warn_if_too_many_backups — emit a single YELLOW ⚠ when combined backup dir count > 10.
# Threshold hard-coded at 10 per D-09 (v4.1; tunable in v4.2+ via env var).
# Must be called AFTER a successful backup creation (D-11).
warn_if_too_many_backups() {
    local count
    count=$(( $(find "$HOME" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' \
           -o -name '.claude-backup-pre-migrate-*' \
           -o -name '.claude-backup-pre-uninstall-*' \) \
        2>/dev/null | wc -l) ))
    if [[ $count -gt 10 ]]; then
        echo -e "${YELLOW}⚠${NC} ${count} toolkit backup dirs under \$HOME — run \`update-claude.sh --clean-backups\` to prune"
    fi
}
