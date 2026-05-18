#!/bin/bash
# scripts/lib/skill-checksum.sh — reproducible directory content hash for
# skill mirrors. Used by sync-skills-mirror.sh and probe_skill_pin.
#
# Algorithm: for every file under <dir> (depth-first, lexicographic sort,
# excluding dotfiles and .DS_Store), emit "<relative_path>\t<sha256>(content)"
# then sha256 that aggregated text. Result is byte-deterministic across
# macOS BSD and GNU Linux given identical file contents + file names.
#
# v6.47.0: optional --normalize flag applies whitespace normalization
# before hashing (strip CRLF→LF, strip trailing whitespace per line,
# collapse 3+ consecutive blank lines to 2, ensure trailing newline).
# Used by sync-skills-mirror.sh to distinguish raw-content drift from
# markdownlint-ingestion artifacts.
#
# Why not `tar | sha256sum`: tar headers differ between BSD and GNU tar
# (mtime, uid/gid, sparse flags), so identical content produces different
# tarball bytes. The relative-path + content-hash aggregation avoids that.
#
# Usage:
#   sha=$(bash scripts/lib/skill-checksum.sh <dir>)
#   sha=$(bash scripts/lib/skill-checksum.sh --normalize <dir>)

set -euo pipefail

NORMALIZE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --normalize) NORMALIZE=1; shift ;;
        -h|--help)
            sed -n '2,22p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        --) shift; break ;;
        -*) echo "skill-checksum: unknown flag: $1" >&2; exit 1 ;;
        *)  break ;;
    esac
done

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
# AUDIT v6.47.0: -print0 + read -d '' tolerates file names containing TAB
# or LF. Defensive in-path encoding (\t→%09, \n→%0a) keeps the aggregation
# row a single logical line even on hostile names.
(
    cd "$dir" || exit 1
    find . -type f \
        ! -name '.*' \
        ! -path '*/.*' \
        ! -name '.DS_Store' \
        -print0 2>/dev/null \
        | LC_ALL=C sort -z \
        | while IFS= read -r -d '' f; do
            rel="${f#./}"
            rel_escaped="${rel//$'\t'/%09}"
            rel_escaped="${rel_escaped//$'\n'/%0a}"
            if [[ "$NORMALIZE" -eq 1 && "$f" == *.md ]]; then
                # markdownlint-ingestion-equivalent normalization:
                # CRLF → LF, strip per-line trailing whitespace, collapse
                # any run of blank lines to a single blank line (MD012),
                # strip leading + trailing blank lines around the body.
                # Portable awk; only .md files normalized (binary stays
                # byte-exact). Used for soft-equivalence: upstream raw
                # vs mirror-after-ingestion.
                file_sha=$(awk '
                    {
                        sub(/\r$/, "")
                        sub(/[ \t]+$/, "")
                        lines[NR] = $0
                        n = NR
                    }
                    END {
                        # Find first/last non-blank line indices
                        first = 0; last = 0
                        for (i = 1; i <= n; i++) if (lines[i] != "") { first = i; break }
                        for (i = n; i >= 1; i--) if (lines[i] != "") { last = i; break }
                        if (first == 0) { exit }  # all blank
                        prev_blank = 0
                        for (i = first; i <= last; i++) {
                            if (lines[i] == "") {
                                if (prev_blank == 0) print ""
                                prev_blank = 1
                            } else {
                                print lines[i]
                                prev_blank = 0
                            }
                        }
                    }
                ' "$f" | _sha)
            else
                file_sha=$(_sha < "$f")
            fi
            printf '%s\t%s\n' "$rel_escaped" "$file_sha"
        done
) | _sha
