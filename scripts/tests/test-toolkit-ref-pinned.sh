#!/usr/bin/env bash
# Audit 2026-05-14 — REL-03 (strict, v6.25.0+): assert that EVERY standalone
# installer in scripts/*.sh pins TK_TOOLKIT_REF's default value to the
# manifest version. Prevents a release-PR from shipping a default `main`
# (live HEAD) in ANY installer and guarantees every `curl|bash` user gets
# a reproducible, same-tag install.
#
# v6.24.5 covered only init-claude.sh; v6.25.0 broadens the gate to all 9
# installers (init-claude, install, install-statusline, migrate-to-complement,
# setup-council, setup-prompt-engineer, setup-security, uninstall, update-claude).
# Scripts that do not define TK_TOOLKIT_REF (libs, helpers, tests) are skipped.
#
# Exit 0 if every installer's default == manifest.version; 1 otherwise.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="$ROOT/manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
    echo "❌ manifest.json missing at $MANIFEST" >&2
    exit 1
fi

mver="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$MANIFEST")"
if [[ -z "$mver" ]]; then
    echo "❌ manifest.json missing 'version'" >&2
    exit 1
fi

ERR=0
CHECKED=0

# Walk every scripts/*.sh that defines `TK_TOOLKIT_REF="${TK_TOOLKIT_REF:-...}"`.
# `find -maxdepth 1` keeps the gate focused on top-level installers — libs
# under scripts/lib/ are sourced helpers and inherit the caller's pin.
while IFS= read -r script; do
    # grep | head | sed: grep returns 1 when no line matches. Under
    # `set -o pipefail` that aborts the script before we can `continue`.
    # Wrap in `|| true` so missing matches just yield an empty `default`.
    default="$( { grep -E '^TK_TOOLKIT_REF="\$\{TK_TOOLKIT_REF:-' "$script" 2>/dev/null || true; } \
        | head -n1 | sed -E 's/.*:-([^}]+)\}.*/\1/')"
    if [[ -z "$default" ]]; then
        # Script does not define TK_TOOLKIT_REF — skip silently.
        continue
    fi
    CHECKED=$((CHECKED + 1))

    if [[ "$default" == "main" ]]; then
        echo "❌ $(basename "$script"): TK_TOOLKIT_REF default is 'main' — must pin to v${mver}" >&2
        ERR=1
        continue
    fi
    if [[ "$default" != "v${mver}" && "$default" != "${mver}" ]]; then
        echo "❌ $(basename "$script"): default ($default) ≠ manifest.version (v${mver})" >&2
        echo "   Release-PR forgot to bump this installer in lockstep with manifest.json:.version." >&2
        ERR=1
        continue
    fi
    echo "✅ $(basename "$script"): $default"
done < <(find "$ROOT/scripts" -maxdepth 1 -name '*.sh' -type f | sort)

if [[ "$CHECKED" -eq 0 ]]; then
    echo "❌ no installers defining TK_TOOLKIT_REF found — walker pattern broke" >&2
    exit 1
fi

if [[ "$ERR" -eq 0 ]]; then
    echo ""
    echo "✅ REL-03 strict: all ${CHECKED} installers pinned to v${mver}"
fi

exit "$ERR"
