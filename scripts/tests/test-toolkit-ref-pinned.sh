#!/usr/bin/env bash
# Audit 2026-05-13 — REL-03: assert that scripts/init-claude.sh's
# TK_TOOLKIT_REF default points at the same tag as manifest.json:.version.
# Prevents a release-PR from shipping a default `main` (live HEAD) and
# guarantees `curl|bash` installers fetch every file from the same tag.
#
# Exit 0 on match, 1 on mismatch or parse failure.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INIT="$ROOT/scripts/init-claude.sh"
MANIFEST="$ROOT/manifest.json"

if [[ ! -f "$INIT" || ! -f "$MANIFEST" ]]; then
    echo "❌ missing init-claude.sh or manifest.json" >&2
    exit 1
fi

mver="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$MANIFEST")"
if [[ -z "$mver" ]]; then
    echo "❌ manifest.json missing 'version'" >&2
    exit 1
fi

# Extract default from TK_TOOLKIT_REF="${TK_TOOLKIT_REF:-DEFAULT}"
default="$(grep -E '^TK_TOOLKIT_REF="\$\{TK_TOOLKIT_REF:-' "$INIT" | head -n1 | sed -E 's/.*:-([^}]+)\}.*/\1/')"
if [[ -z "$default" ]]; then
    echo "❌ could not locate TK_TOOLKIT_REF default in scripts/init-claude.sh" >&2
    exit 1
fi

if [[ "$default" == "main" ]]; then
    echo "❌ TK_TOOLKIT_REF default is 'main' — release installs must pin to a tag." >&2
    echo "   Users opt in to bleeding edge via: TK_TOOLKIT_REF=main bash <(curl ...)" >&2
    exit 1
fi

if [[ "$default" != "v${mver}" && "$default" != "${mver}" ]]; then
    echo "❌ TK_TOOLKIT_REF default ($default) does not match manifest.version (v${mver})." >&2
    echo "   Release-PR forgot to bump init-claude.sh:TK_TOOLKIT_REF or manifest.json:version." >&2
    exit 1
fi

echo "✅ TK_TOOLKIT_REF default matches release tag: $default"
