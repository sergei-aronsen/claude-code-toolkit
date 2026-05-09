#!/bin/bash

# Open Design Setup
# One-shot installer for the optional Open Design web UI
# (https://github.com/nexu-io/open-design) — local-first prototyping
# environment that emits HTML / PDF / PPTX / MP4 from prompts. 122 skills
# + 149 brand design systems shipped in-repo.
#
# Default path: Docker (no Node/pnpm on the host). Source path is opt-in
# for contributors. Runs locally on http://localhost:<port> (default 7456).
#
# Idempotent — safe to re-run. Use --dry-run to preview without changes.
#
# Usage:
#   bash scripts/setup-open-design.sh [--dry-run] [--mode docker|source]
#                                      [--port N] [--dir PATH] [--stop]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

DRY_RUN=0
MODE="docker"
PORT="${OPEN_DESIGN_PORT:-7456}"
INSTALL_DIR="${OPEN_DESIGN_DIR:-$HOME/open-design}"
STOP=0

REPO_URL="https://github.com/nexu-io/open-design.git"

# ============================================================================
# Colors
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# Helpers
# ============================================================================

usage() {
    cat <<EOF
Usage: bash scripts/setup-open-design.sh [options]

Options:
  --dry-run           Preview actions without changing anything.
  --mode MODE         'docker' (default) or 'source'.
                      docker  — pulls vanjayak/open-design image (~few hundred MB).
                      source  — clones repo + pnpm install (Node 24, pnpm 10.33.x).
  --port N            Host port to expose. Default: 7456.
  --dir PATH          Install directory for the repo clone.
                      Default: \$HOME/open-design.
  --stop              Stop a running Open Design (docker compose down OR
                      kill background source process). Does not remove data.
  -h, --help          Show this message.

Environment overrides:
  OPEN_DESIGN_PORT    Same as --port.
  OPEN_DESIGN_DIR     Same as --dir.

What this script does (docker mode, default):
  1. Verifies Docker Desktop / 'docker compose' v2 is installed.
  2. Checks the chosen port is free.
  3. Clones nexu-io/open-design into \$INSTALL_DIR (skipped if present).
  4. Runs 'docker compose up -d' from <repo>/deploy.
  5. Prints status + the local URL.

The first 'docker compose up' downloads the image, which can take a few
minutes. Re-runs are near-instant.
EOF
}

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  [dry-run] $*"
    else
        # shellcheck disable=SC2294
        eval "$@"
    fi
}

emit_step() {
    echo -e "${CYAN}==>${NC} $*"
}

emit_ok() {
    echo -e "  ${GREEN}✓${NC} $*"
}

emit_warn() {
    echo -e "  ${YELLOW}⚠${NC} $*"
}

emit_err() {
    echo -e "${RED}Error:${NC} $*" >&2
}

# ============================================================================
# Argument parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --stop)
            STOP=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            emit_err "unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ "$MODE" != "docker" && "$MODE" != "source" ]]; then
    emit_err "--mode must be 'docker' or 'source' (got: $MODE)"
    exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 || "$PORT" -gt 65535 ]]; then
    emit_err "--port must be 1-65535 (got: $PORT)"
    exit 1
fi

# Reject path traversal in --dir; we will write into this directory.
case "$INSTALL_DIR" in
    *..*)
        emit_err "--dir must not contain '..'"
        exit 1
        ;;
esac

# ============================================================================
# Stop path — short-circuit before any install logic
# ============================================================================

if [[ $STOP -eq 1 ]]; then
    emit_step "Stopping Open Design"
    if [[ "$MODE" == "docker" ]]; then
        if [[ ! -d "$INSTALL_DIR/deploy" ]]; then
            emit_warn "no deploy/ found at $INSTALL_DIR — nothing to stop"
            exit 0
        fi
        run "(cd \"$INSTALL_DIR/deploy\" && docker compose down)"
        emit_ok "docker compose down"
    else
        # Source mode: we don't track a PID; tell the user.
        emit_warn "source mode: stop the foreground 'pnpm tools-dev' process you started manually."
    fi
    exit 0
fi

# ============================================================================
# Pre-flight
# ============================================================================

emit_step "Pre-flight checks"

if ! command -v git >/dev/null 2>&1; then
    emit_err "git not found in PATH."
    exit 1
fi
emit_ok "git present"

if [[ "$MODE" == "docker" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
        emit_err "docker not found in PATH. Install Docker Desktop or use --mode source."
        exit 1
    fi
    if ! docker compose version >/dev/null 2>&1; then
        emit_err "'docker compose' v2 plugin missing. Update Docker Desktop or install the plugin."
        exit 1
    fi
    emit_ok "docker compose v2 present"
else
    if ! command -v node >/dev/null 2>&1; then
        emit_err "node not found in PATH. Install Node 24.x first."
        exit 1
    fi
    NODE_MAJOR="$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*$/\1/')"
    if [[ "$NODE_MAJOR" != "24" ]]; then
        emit_warn "Node major version is '$NODE_MAJOR'; the repo pins Node 24. Continuing anyway."
    else
        emit_ok "node 24.x present"
    fi
    if ! command -v corepack >/dev/null 2>&1; then
        emit_err "corepack missing — required to select pnpm 10.33.x. Install or upgrade Node 24."
        exit 1
    fi
    emit_ok "corepack present"
fi

# Port conflict check: lsof first (macOS + most Linux), fallback to ss.
port_in_use() {
    local p="$1"
    if command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1
    elif command -v ss >/dev/null 2>&1; then
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}\$"
    else
        return 1
    fi
}

if port_in_use "$PORT"; then
    emit_warn "TCP port $PORT is already in use."
    emit_warn "Either pass --port <other> or stop whatever holds it. Continuing — Docker / pnpm will fail loudly if the conflict is real."
else
    emit_ok "port $PORT free"
fi

# ============================================================================
# Clone (or fast-forward) the repo
# ============================================================================

emit_step "Sync nexu-io/open-design at $INSTALL_DIR"

if [[ -d "$INSTALL_DIR/.git" ]]; then
    # Existing clone — pull latest on the current branch (don't force).
    run "(cd \"$INSTALL_DIR\" && git fetch --quiet && git pull --ff-only --quiet || true)"
    emit_ok "existing clone — fetched + fast-forwarded"
elif [[ -e "$INSTALL_DIR" ]]; then
    emit_err "$INSTALL_DIR exists but is not a git repo. Remove it or pass --dir <other>."
    exit 1
else
    run "git clone --depth=1 \"$REPO_URL\" \"$INSTALL_DIR\""
    emit_ok "cloned into $INSTALL_DIR"
fi

# ============================================================================
# Mode dispatch
# ============================================================================

if [[ "$MODE" == "docker" ]]; then
    emit_step "Bring up Open Design via docker compose"
    if [[ ! -f "$INSTALL_DIR/deploy/docker-compose.yml" && ! -f "$INSTALL_DIR/deploy/compose.yaml" ]]; then
        emit_err "no compose file found under $INSTALL_DIR/deploy/. Upstream layout may have changed."
        exit 1
    fi

    # Honor the user's --port choice via deploy/.env (upstream-supported override).
    ENV_FILE="$INSTALL_DIR/deploy/.env"
    if [[ "$PORT" != "7456" ]]; then
        run "printf 'OPEN_DESIGN_PORT=%s\\n' \"$PORT\" > \"$ENV_FILE\""
        emit_ok "wrote $ENV_FILE with OPEN_DESIGN_PORT=$PORT"
    fi

    run "(cd \"$INSTALL_DIR/deploy\" && docker compose up -d)"
    emit_ok "compose stack up"
else
    emit_step "Source-mode bootstrap (pnpm install + tools-dev)"
    run "(cd \"$INSTALL_DIR\" && corepack enable)"
    run "(cd \"$INSTALL_DIR\" && corepack pnpm --version)"
    run "(cd \"$INSTALL_DIR\" && pnpm install)"
    emit_ok "dependencies installed"
    cat <<EOF

  Source mode does not start the dev server in the background — you keep
  control of the foreground process. To run it:

    cd "$INSTALL_DIR"
    pnpm tools-dev --web-port=$PORT

EOF
fi

# ============================================================================
# Summary
# ============================================================================

cat <<EOF

${GREEN}Done.${NC}

  URL:        http://localhost:$PORT
  Repo:       $INSTALL_DIR
  Mode:       $MODE
  Stop:       bash scripts/setup-open-design.sh --stop --mode $MODE${INSTALL_DIR:+ --dir "$INSTALL_DIR"}

Open Design ships 122 skills + 149 brand design systems, used by its
agent runtime — those skills do NOT auto-load into Claude Code.

Security note: the daemon binds 0.0.0.0 inside the container. The
upstream compose file maps ${PORT}:${PORT} to localhost only by default,
but verify with 'docker compose ps' if you are on a multi-user host.

EOF
