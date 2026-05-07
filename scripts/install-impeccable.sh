#!/usr/bin/env bash
# scripts/install-impeccable.sh
#
# Standalone installer for pbakaus/impeccable — frontend design skill +
# 23 commands (craft, shape, audit, polish, harden, animate, etc.) plus
# 27 deterministic anti-pattern rules. Apache-2.0, derived from
# Anthropic's frontend-design skill.
#
# Strategy: wrap the upstream `npx impeccable skills install` CLI rather
# than vendoring the ~250KB skill payload into this repo. Pros: stays in
# sync with upstream, opt-in updates via `npx impeccable skills update`,
# no license-attribution drift. Cons: requires node + network at install
# time. Mirrors the toolkit's serena/claude-memo pattern of being a thin
# wrapper around upstream tooling.
#
# User-scope (default, matches toolkit's other skills): the upstream CLI
# resolves the install root by walking up from cwd looking for a `.git`
# marker. We cd to $HOME (no .git there for normal users) so the root
# falls back to cwd → npx writes $HOME/.claude/skills/impeccable/. That
# is the same root the toolkit's skills picker uses for every other
# skill, so a single user-restart of Claude Code picks the new skill up
# globally across all projects.
#
# Steps:
#   1. Verify node + npx on PATH.
#   2. cd to $HOME and run `npx -y impeccable@latest skills install` so
#      the upstream CLI writes $HOME/.claude/skills/impeccable/.
#   3. Verify SKILL.md landed; report success / failure.
#
# Flags:
#   --dry-run    Print the npx command, write nothing.
#   --yes        Pass through (npx is non-interactive anyway; honoured for
#                dispatcher symmetry with the rest of the toolkit).
#
# Exit codes:
#   0  success (or dry-run)
#   1  missing prerequisite (node / npx not on PATH)
#   2  npx command failed (network down, package error, install rejected)

set -euo pipefail

# ───── color helpers (match toolkit convention) ─────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=0
YES=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes)     YES=1; shift ;;
        -h|--help)
            cat <<USAGE
Usage: bash scripts/install-impeccable.sh [--dry-run] [--yes]

Installs pbakaus/impeccable frontend design skill into <cwd>/.claude/skills/.
Requires node + npx on PATH. Idempotent — re-running updates to latest.
USAGE
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument:${NC} $1" >&2
            exit 1
            ;;
    esac
done
: "$YES"

# ───── prerequisite check ─────
if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} node not found on PATH — install Node.js first (https://nodejs.org/)" >&2
    exit 1
fi
if ! command -v npx >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} npx not found on PATH — included with npm; reinstall Node.js" >&2
    exit 1
fi

SKILL_TARGET="${HOME}/.claude/skills/impeccable/SKILL.md"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[+ INSTALL] impeccable (would run: cd \"\$HOME\" && npx -y impeccable@latest skills install)"
    exit 0
fi

# Refuse to install when $HOME contains a .git marker — the upstream CLI's
# findProjectRoot() would then resolve that as "the project root" and write
# the skill there, polluting the user's home git repo. Rare but possible
# (some users keep dotfiles in a $HOME-rooted repo). Tell them to remove the
# marker or install impeccable per-project via `cd <project> && npx ...`.
if [[ -e "$HOME/.git" ]]; then
    echo -e "${RED}✗${NC} \$HOME contains .git — the upstream CLI would treat \$HOME as a project root." >&2
    echo "  Install impeccable per-project instead: cd <your-project> && npx -y impeccable@latest skills install" >&2
    exit 2
fi

echo -e "${CYAN}Installing impeccable into${NC} ${HOME}/.claude/skills/impeccable/"
echo -e "${YELLOW}!${NC} Fetches ~250KB of skill content from npm — first run only."

# cd to $HOME so the upstream CLI's findProjectRoot() falls back to cwd
# (no .git ancestor) and writes $HOME/.claude/skills/impeccable/. The
# subshell scopes the cd so the caller's cwd is unchanged.
if ! ( cd "$HOME" && npx -y impeccable@latest skills install ); then
    echo -e "${RED}✗${NC} npx impeccable skills install failed (exit $?)" >&2
    exit 2
fi

# Verify the skill landed where we expect. The upstream CLI may evolve its
# layout, so a missing SKILL.md is a soft warning rather than a hard fail.
if [[ -f "$SKILL_TARGET" ]]; then
    echo -e "${GREEN}✓${NC} impeccable skill installed at ~/.claude/skills/impeccable/"
    echo -e "  Restart Claude Code to load the new skill, then try ${CYAN}/impeccable shape${NC}."
else
    echo -e "${YELLOW}!${NC} npx command succeeded but ${SKILL_TARGET} not found."
    echo -e "  The upstream CLI may have changed its install layout — check"
    echo -e "  https://github.com/pbakaus/impeccable for the current path."
fi

exit 0
