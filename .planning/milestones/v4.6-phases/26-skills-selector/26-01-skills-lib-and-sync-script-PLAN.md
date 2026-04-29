---
phase: 26
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/lib/skills.sh
  - scripts/sync-skills-mirror.sh
autonomous: true
requirements: [SKILL-03]
must_haves:
  truths:
    - "scripts/lib/skills.sh sources cleanly under set -euo pipefail without altering caller error mode"
    - "is_skill_installed <name> returns 0 when ~/.claude/skills/<name>/ exists, 1 when absent"
    - "TK_SKILLS_HOME env var overrides the ~/.claude/skills/ probe path for hermetic tests"
    - "skills_catalog_names prints the 22 curated skill names alphabetically, one per line"
    - "skills_install <name> [--force] copies templates/skills-marketplace/<name>/ contents into target dir"
    - "scripts/sync-skills-mirror.sh runs standalone and refreshes templates/skills-marketplace/ from the local ~/.claude/skills/ source-of-truth"
  artifacts:
    - path: "scripts/lib/skills.sh"
      provides: "skills catalog loader, is_skill_installed probe, skills_install copy helper"
      contains: "is_skill_installed"
    - path: "scripts/sync-skills-mirror.sh"
      provides: "Standalone maintainer script that re-syncs templates/skills-marketplace/ from upstream local skills"
      contains: "TK_SKILLS_SRC"
  key_links:
    - from: "scripts/lib/skills.sh"
      to: "$HOME/.claude/skills/"
      via: "is_skill_installed directory probe with TK_SKILLS_HOME override"
      pattern: 'TK_SKILLS_HOME.*HOME/.claude/skills'
    - from: "scripts/lib/skills.sh"
      to: "templates/skills-marketplace/"
      via: "skills_install reads source files via TK_SKILLS_MIRROR_PATH override"
      pattern: 'TK_SKILLS_MIRROR_PATH'
---

<objective>
Build the foundational skills library (`scripts/lib/skills.sh`) and standalone maintainer sync script (`scripts/sync-skills-mirror.sh`). The library exposes the catalog of 22 curated skills, a directory-probe `is_skill_installed`, and a `cp -R` based installer with `--force` semantics. The sync script is the manual one-shot re-sync helper used by maintainers to refresh `templates/skills-marketplace/` from upstream skills.

Purpose: Wave 2 depends on this library to drive `--skills` TUI routing in `install.sh`. The sync script does NOT run during the install path — it is a dev-side tool that maintainers invoke manually before committing a new mirror snapshot.

Output: Two shell files. `scripts/lib/skills.sh` is sourced by Phase 26 Plans 03 and 04. `scripts/sync-skills-mirror.sh` is a standalone executable with no test wiring (per CONTEXT.md scope: "standalone script (not test-wired) for manual upstream re-sync").
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/26-skills-selector/26-CONTEXT.md
@.planning/phases/25-mcp-selector/25-01-mcp-catalog-and-loader-SUMMARY.md
@scripts/lib/mcp.sh
@scripts/lib/detect2.sh

<interfaces>
<!-- Patterns to mirror from Phase 25 mcp.sh and Phase 24 detect2.sh -->

From scripts/lib/detect2.sh — is_*_installed convention (DET-01 contract):
```bash
is_security_installed() {
    if ! command -v cc-safety-net >/dev/null 2>&1; then
        return 1
    fi
    # ... wiring check
}
```

From scripts/lib/mcp.sh — color guards + sourced-lib invariants:
```bash
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards: do NOT redefine if caller already set them.
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
[[ -z "${GREEN:-}"  ]] && GREEN='\033[0;32m'
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
[[ -z "${NC:-}"     ]] && NC='\033[0m'
```

From scripts/lib/mcp.sh — test-seam pattern:
```bash
# TK_MCP_CATALOG_PATH   — override path to mcp-catalog.json
# TK_MCP_CONFIG_HOME    — override $HOME for mcp-config.env path resolution
```

The 22 curated skills (alphabetical, EXACTLY this list per SKILL-01):
ai-models, analytics-tracking, chrome-extension-development, copywriting, docx,
find-skills, firecrawl, i18n-localization, memo-skill, next-best-practices,
notebooklm, pdf, resend, seo-audit, shadcn, stripe-best-practices,
tailwind-design-system, typescript-advanced-types, ui-ux-pro-max,
vercel-composition-patterns, vercel-react-best-practices, webapp-testing
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create scripts/lib/skills.sh — catalog + is_skill_installed + skills_install</name>
  <read_first>
    - scripts/lib/mcp.sh (lines 1-100 — color guards, source-mode contract, test seams)
    - scripts/lib/detect2.sh (lines 1-50 — is_*_installed return-code convention)
  </read_first>
  <files>scripts/lib/skills.sh</files>
  <action>
Create new file `scripts/lib/skills.sh` (target ~150-200 lines). Header MUST state: "Source this file. Do NOT execute it directly." MUST include the comment "IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode." Do NOT add `set -euo pipefail`.

Color guards block (copy from mcp.sh): five guarded `[[ -z "${RED:-}" ]] && RED='\033[0;31m'` lines for RED GREEN YELLOW BLUE NC.

Hardcode the 22-skill catalog as a bash array constant (alphabetical, exactly per SKILL-01):

```bash
SKILLS_CATALOG=(
  ai-models
  analytics-tracking
  chrome-extension-development
  copywriting
  docx
  find-skills
  firecrawl
  i18n-localization
  memo-skill
  next-best-practices
  notebooklm
  pdf
  resend
  seo-audit
  shadcn
  stripe-best-practices
  tailwind-design-system
  typescript-advanced-types
  ui-ux-pro-max
  vercel-composition-patterns
  vercel-react-best-packages
  webapp-testing
)
```

Wait — the last two entries MUST be `vercel-react-best-practices` and `webapp-testing` (NOT `vercel-react-best-packages`). Type carefully — the names in REQUIREMENTS.md SKILL-01 are the exact source of truth.

Document the test seams in the header comment block:
```text
Test seams:
  TK_SKILLS_HOME          — override $HOME/.claude/skills/ probe path (used by is_skill_installed)
  TK_SKILLS_MIRROR_PATH   — override templates/skills-marketplace/ source path (used by skills_install)
```

Functions to expose (each a separate function, not collapsed):

1. `_skills_default_home()` — internal helper. Resolves probe target. Body:
   ```bash
   echo "${TK_SKILLS_HOME:-$HOME/.claude/skills}"
   ```

2. `_skills_default_mirror_path()` — internal helper. Resolves source path. Body uses BASH_SOURCE pattern from `_mcp_default_catalog_path` in mcp.sh:
   ```bash
   local d
   d="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
   echo "${TK_SKILLS_MIRROR_PATH:-${d}/../../templates/skills-marketplace}"
   ```

3. `skills_catalog_names()` — print all 22 skill names from `SKILLS_CATALOG`, one per line. Single-line implementation: `printf '%s\n' "${SKILLS_CATALOG[@]}"`.

4. `is_skill_installed <name>` — directory probe. Per SKILL-03: `[ -d ~/.claude/skills/<name>/ ]`. Two-state return (not three-state — skills have no CLI dependency).
   ```bash
   is_skill_installed() {
       local name="${1:-}"
       if [[ -z "$name" ]]; then
           echo -e "${RED}✗${NC} is_skill_installed: missing argument" >&2
           return 1
       fi
       local home
       home="$(_skills_default_home)"
       [[ -d "${home}/${name}" ]]
   }
   ```

5. `skills_status_array()` — populates parallel TUI_* arrays for the install.sh `--skills` branch (mirrors `mcp_status_array` from mcp.sh:486). Sets `TUI_INSTALLED[i]` to 1 if installed, 0 if not. Indexed by SKILLS_CATALOG order.
   ```bash
   skills_status_array() {
       TUI_INSTALLED=()
       local count=${#SKILLS_CATALOG[@]}
       local i name
       for ((i=0; i<count; i++)); do
           name="${SKILLS_CATALOG[$i]}"
           if is_skill_installed "$name"; then
               TUI_INSTALLED+=(1)
           else
               TUI_INSTALLED+=(0)
           fi
       done
   }
   ```

6. `skills_install <name> [--force]` — copies one skill from mirror to target. Returns 0 on success, 1 on failure (missing source, mkdir failure, cp failure), 2 if target exists and `--force` not passed.
   ```bash
   skills_install() {
       local name="${1:-}"
       local force=0
       shift || true
       while [[ $# -gt 0 ]]; do
           case "$1" in
               --force) force=1; shift ;;
               *) shift ;;
           esac
       done
       if [[ -z "$name" ]]; then
           echo -e "${RED}✗${NC} skills_install: missing skill name" >&2
           return 1
       fi
       local mirror src target home
       mirror="$(_skills_default_mirror_path)"
       src="${mirror}/${name}"
       home="$(_skills_default_home)"
       target="${home}/${name}"
       if [[ ! -d "$src" ]]; then
           echo -e "${RED}✗${NC} skills_install: source missing: $src" >&2
           return 1
       fi
       if [[ -d "$target" && "$force" -ne 1 ]]; then
           return 2
       fi
       if [[ -d "$target" && "$force" -eq 1 ]]; then
           rm -rf "$target" || return 1
       fi
       mkdir -p "$home" || return 1
       cp -R "$src" "$target" || return 1
       return 0
   }
   ```

Use `cp -R "$src" "$target"` (NOT `cp -R "$src/." "$target/"` — the trailing-dot trick is unnecessary because we delete the target first when --force, and create only via mkdir of the parent home dir). Verify: after `cp -R templates/skills-marketplace/ai-models /tmp/skills/`, the result is `/tmp/skills/ai-models/SKILL.md`, which matches SKILL-03 contract.

Add shellcheck disables only where SC2034 fires for catalog vars consumed externally (`SKILLS_CATALOG`, `TUI_INSTALLED`).
  </action>
  <verify>
    <automated>
      bash -c "set -euo pipefail; source scripts/lib/skills.sh; skills_catalog_names | wc -l | tr -d ' '"
      # MUST output exactly: 22

      bash -c "set -euo pipefail; source scripts/lib/skills.sh; skills_catalog_names | head -1"
      # MUST output exactly: ai-models

      bash -c "set -euo pipefail; source scripts/lib/skills.sh; skills_catalog_names | tail -1"
      # MUST output exactly: webapp-testing

      bash -c "set -euo pipefail; source scripts/lib/skills.sh; TK_SKILLS_HOME=/nonexistent is_skill_installed ai-models" || echo "rc=$?"
      # MUST output: rc=1

      shellcheck -S warning scripts/lib/skills.sh
      # MUST output nothing (zero warnings)
    </automated>
  </verify>
  <acceptance_criteria>
    - File `scripts/lib/skills.sh` exists.
    - `grep -c '^[[:space:]]*[a-z_-]*$' scripts/lib/skills.sh | head` shows the 22 skill names appear in `SKILLS_CATALOG` array.
    - `grep -q 'IMPORTANT: No errexit/nounset/pipefail' scripts/lib/skills.sh` succeeds.
    - `grep -q 'is_skill_installed()' scripts/lib/skills.sh` succeeds.
    - `grep -q 'skills_install()' scripts/lib/skills.sh` succeeds.
    - `grep -q 'skills_status_array()' scripts/lib/skills.sh` succeeds.
    - `grep -q 'TK_SKILLS_HOME' scripts/lib/skills.sh` succeeds.
    - `grep -q 'TK_SKILLS_MIRROR_PATH' scripts/lib/skills.sh` succeeds.
    - `grep -q 'cp -R' scripts/lib/skills.sh` succeeds (NOT `rsync`, per SKILL-03).
    - File does NOT contain `set -euo pipefail` (sourced lib invariant).
    - shellcheck -S warning passes with 0 warnings.
  </acceptance_criteria>
  <done>scripts/lib/skills.sh exists with 22-skill catalog, is_skill_installed directory probe, skills_install --force copy helper, and skills_status_array TUI populator. shellcheck clean. All 5 verify commands produce the documented output.</done>
</task>

<task type="auto">
  <name>Task 2: Create scripts/sync-skills-mirror.sh — standalone maintainer re-sync script</name>
  <read_first>
    - scripts/lib/skills.sh (Task 1 output — read SKILLS_CATALOG list)
    - scripts/init-local.sh (lines 1-50 — header style + flag-parsing pattern)
  </read_first>
  <files>scripts/sync-skills-mirror.sh</files>
  <action>
Create new executable file `scripts/sync-skills-mirror.sh` (target ~120-180 lines). This is a STANDALONE script — `set -euo pipefail` at top, NOT a sourced library.

Header block:
```bash
#!/bin/bash
# Claude Code Toolkit — Skills Mirror Sync (Maintainer Tool)
#
# Re-syncs templates/skills-marketplace/<name>/ from the local user's
# ~/.claude/skills/<name>/ source-of-truth. Run manually before committing
# a new mirror snapshot. NOT wired into install path or CI.
#
# Usage:
#   bash scripts/sync-skills-mirror.sh             # sync all 22 catalog skills
#   bash scripts/sync-skills-mirror.sh ai-models   # sync one skill
#   bash scripts/sync-skills-mirror.sh --dry-run   # preview without writes
#
# Test seams:
#   TK_SKILLS_SRC      — override source skills home (default: $HOME/.claude/skills)
#   TK_SKILLS_DEST     — override dest mirror path (default: <repo>/templates/skills-marketplace)
#
# Exit codes:
#   0 success
#   1 missing source dir for one or more catalog skills
#   2 invalid argument
```

Implementation steps:

1. `set -euo pipefail` at top.
2. Color helpers (RED/GREEN/YELLOW/BLUE/NC) — same constants as installer scripts.
3. Resolve script dir + repo root via BASH_SOURCE.
4. Source `scripts/lib/skills.sh` to inherit the canonical 22-skill `SKILLS_CATALOG`. Use:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
   # shellcheck source=lib/skills.sh
   source "${SCRIPT_DIR}/lib/skills.sh"
   ```
5. Argument parsing via `while`/`case`. Recognized flags: `--dry-run`, `-h`/`--help`. Recognized positional: `<skill-name>` (single skill). Unknown args exit 2.
6. Resolve source/dest paths:
   ```bash
   SKILLS_SRC="${TK_SKILLS_SRC:-$HOME/.claude/skills}"
   SKILLS_DEST="${TK_SKILLS_DEST:-${REPO_ROOT}/templates/skills-marketplace}"
   ```
7. Build sync list: if positional arg given, sync only that skill (validate it's in SKILLS_CATALOG; exit 2 if not). Otherwise iterate `SKILLS_CATALOG`.
8. Per-skill sync logic:
   ```bash
   for name in "${sync_list[@]}"; do
       src="${SKILLS_SRC}/${name}"
       dest="${SKILLS_DEST}/${name}"
       if [[ ! -d "$src" ]]; then
           echo -e "${YELLOW}!${NC} ${name}: source missing at ${src} (skip)"
           MISSING=$((MISSING + 1))
           continue
       fi
       if [[ "$DRY_RUN" -eq 1 ]]; then
           echo -e "${BLUE}~${NC} would sync: ${src} → ${dest}"
           continue
       fi
       if [[ -d "$dest" ]]; then
           rm -rf "$dest"
       fi
       mkdir -p "$(dirname "$dest")"
       cp -R "$src" "$dest"
       echo -e "${GREEN}✓${NC} synced: ${name}"
       SYNCED=$((SYNCED + 1))
   done
   ```
9. Final summary line: `printf '\nSynced: %d · Missing: %d · Total: %d\n' "$SYNCED" "$MISSING" "${#sync_list[@]}"`. Exit 1 if `MISSING > 0`, else 0.

Do NOT touch `docs/SKILLS-MIRROR.md` from this script. Do NOT git commit. The script is purely a copy operation. The doc is updated by the maintainer manually OR by Plan 04. Per CONTEXT.md: "Documented for maintainers" — the script is documented in SKILLS-MIRROR.md (Plan 04), but the script itself does not write docs.

Make the file executable: `chmod +x scripts/sync-skills-mirror.sh` (note: in git, this is captured by mode bits — verify with `git ls-files -s scripts/sync-skills-mirror.sh` after staging).
  </action>
  <verify>
    <automated>
      bash scripts/sync-skills-mirror.sh --help
      # MUST exit 0 and print Usage: line

      TK_SKILLS_SRC=/nonexistent TK_SKILLS_DEST=/tmp/test-mirror-dest bash scripts/sync-skills-mirror.sh --dry-run | grep -c "would sync"
      # Output 0 — all sources missing in /nonexistent (zero would-sync lines)

      TK_SKILLS_SRC=/nonexistent TK_SKILLS_DEST=/tmp/test-mirror-dest bash scripts/sync-skills-mirror.sh --dry-run; echo "rc=$?"
      # rc=1 (MISSING > 0)

      shellcheck -S warning scripts/sync-skills-mirror.sh
      # 0 warnings
    </automated>
  </verify>
  <acceptance_criteria>
    - File `scripts/sync-skills-mirror.sh` exists with shebang `#!/bin/bash`.
    - File is executable (`-x` bit set: `[ -x scripts/sync-skills-mirror.sh ]`).
    - `head -1 scripts/sync-skills-mirror.sh` returns `#!/bin/bash`.
    - `grep -q 'set -euo pipefail' scripts/sync-skills-mirror.sh` succeeds (standalone script).
    - `grep -q 'TK_SKILLS_SRC' scripts/sync-skills-mirror.sh` succeeds.
    - `grep -q 'TK_SKILLS_DEST' scripts/sync-skills-mirror.sh` succeeds.
    - `grep -q 'source.*lib/skills.sh' scripts/sync-skills-mirror.sh` succeeds (inherits SKILLS_CATALOG).
    - `bash scripts/sync-skills-mirror.sh --help` exits 0.
    - `bash scripts/sync-skills-mirror.sh --dry-run` (with valid HOME) does NOT touch `templates/skills-marketplace/`.
    - shellcheck -S warning passes.
  </acceptance_criteria>
  <done>scripts/sync-skills-mirror.sh exists, executable, standalone (set -euo pipefail), sources skills.sh for the canonical catalog, supports --dry-run + per-skill positional arg + --help, never touches templates/skills-marketplace in dry-run mode. Not wired into install/CI per CONTEXT.md spec.</done>
</task>

</tasks>

<verification>
After both tasks:

1. `bash -c "set -euo pipefail; source scripts/lib/skills.sh; skills_catalog_names" | wc -l` → 22
2. `bash -c "set -euo pipefail; source scripts/lib/skills.sh; declare -p SKILLS_CATALOG" | grep -c 'webapp-testing'` → 1
3. `[ -x scripts/sync-skills-mirror.sh ]` → exit 0
4. `bash scripts/sync-skills-mirror.sh --help | grep -q Usage` → exit 0
5. `shellcheck -S warning scripts/lib/skills.sh scripts/sync-skills-mirror.sh` → exit 0
6. `make check` (full repo gate) → still passes
</verification>

<success_criteria>
- `scripts/lib/skills.sh` exposes `SKILLS_CATALOG` (22 names alphabetical), `skills_catalog_names`, `is_skill_installed`, `skills_install`, `skills_status_array`.
- `is_skill_installed <name>` returns 0 when `~/.claude/skills/<name>/` exists, 1 otherwise (overridable via `TK_SKILLS_HOME`).
- `skills_install <name> [--force]` copies via `cp -R` from `templates/skills-marketplace/<name>/` to `~/.claude/skills/<name>/`; returns 2 if target exists without `--force`.
- `scripts/sync-skills-mirror.sh` is a standalone executable that re-syncs templates/skills-marketplace from local skills HOME, supports `--dry-run`, single-skill arg, `--help`. Not wired into CI or test suite.
- shellcheck -S warning passes on both files.
- Both files committed via the executor's normal Wave 1 git commit step.
</success_criteria>

<output>
After completion, create `.planning/phases/26-skills-selector/26-01-skills-lib-and-sync-script-SUMMARY.md`
</output>
