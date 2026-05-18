#!/bin/bash
# scripts/lib/skill-checksum.sh — reproducible directory content hash for
# skill mirrors. Used by sync-skills-mirror.sh and probe_skill_pin.
#
# Algorithm: for every file under <dir> (depth-first, lexicographic sort,
# excluding dotfiles and .DS_Store), emit "<relative_path>\t<sha256>(content)"
# then sha256 that aggregated text. Result is byte-deterministic across
# macOS BSD and GNU Linux given identical file contents + file names.
#
# Why not `tar | sha256sum`: tar headers differ between BSD and GNU tar
# (mtime, uid/gid, sparse flags), so identical content produces different
# tarball bytes. The relative-path + content-hash aggregation avoids that.
#
# Usage:
#   sha=$(bash scripts/lib/skill-checksum.sh templates/skills-marketplace/<name>)
#   echo "$sha"  # 64 hex chars

set -euo pipefail

dir="${1:-}"
[ -d "$dir" ] || { echo "skill-checksum: not a directory: $dir" >&2; exit 1; }

# Pick the right hashing tool: GNU coreutils has `sha256sum`, BSD has `shasum -a 256`.
if command -v sha256sum >/dev/null 2>&1; then
    _sha() { sha256sum | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
    _sha() { shasum -a 256 | awk '{print $1}'; }
else
    echo "skill-checksum: no sha256 tool found (need sha256sum or shasum)" >&2
    exit 1
fi

# Walk dir, sort by relative path, skip dotfiles + .DS_Store.
# Print "<rel_path>\t<sha256_of_file>" per file, then hash the aggregate.
(
    cd "$dir" || exit 1
    # `find . -type f` then strip leading "./"; exclude dotfiles + .DS_Store.
    find . -type f \
        ! -name '.*' \
        ! -path '*/.*' \
        ! -name '.DS_Store' \
        -print 2>/dev/null \
        | LC_ALL=C sort \
        | while IFS= read -r f; do
            rel="${f#./}"
            file_sha=$(_sha < "$f")
            printf '%s\t%s\n' "$rel" "$file_sha"
        done
) | _sha
