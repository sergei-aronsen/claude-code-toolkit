# Phase 12: Audit Verification — Verdict Table

**Verified:** 2026-04-24
**Source:** ChatGPT pass-3 audit (15 template-level claims)
**Method:** grep/glob proof + code read per claim; direct verification by main executor agent

## Verdict Summary

| Status | Count |
|--------|-------|
| REAL | 1 |
| PARTIAL | 6 |
| FALSE | 8 |

## Claim Verdicts

| Claim # | Claim Summary | Status | Evidence | Action |
|---------|---------------|--------|----------|--------|
| AUDIT-01 | Plugin manifest schema missing — no `plugin.schema.json` for `.claude-plugin/plugin.json` validation | FALSE | `scripts/validate-manifest.py:2` validates `manifest.json` v2 schema (6 checks: version, path keys, conflicts_with vocab, duplicate paths, file existence, drift). No `.claude-plugin/plugin.json` exists in this repo. The claim targets a non-existent file type; `validate-manifest.py` covers what this repo actually ships. | → No action |
| AUDIT-02 | No template compatibility matrix — no `compatibility.json` to block incompatible stack combos | PARTIAL | `compatibility.json` not found. Inline compat metadata exists: `manifest.json:12` `conflicts_with: ["superpowers"]`, `manifest.json:35-36` `sp_equivalent` fields. No inter-template incompatibility tracking (laravel vs nextjs). Gap: only one framework template installs per run so collision risk is low, but undeclared. | → HARDEN-C-01 (deferred v4.2+) |
| AUDIT-03 | Namespace collision between templates — two framework templates ship same-named commands, overwrite each other | FALSE | `find templates -path "*/commands/*"` → not found. No `commands/` subdir exists under any framework template. All 30 commands live exclusively in repo-root `commands/`. Single-copy install; zero collision risk at the commands layer. | → No action |
| AUDIT-04 | No template merge-strategy declaration — base+python+rag overlay semantics undefined | PARTIAL | No top-level merge-strategy declaration in any installer script. Per-file idempotent guards exist: `scripts/init-local.sh:303,318,330,347` create files only-if-missing. No "rag" template exists. Multi-framework overlay not supported by design; installer picks exactly one framework. Gap: strategy is emergent from code, not declared as a policy document. | → HARDEN-C-02 (deferred v4.2+) |
| AUDIT-05 | Relative path assumptions in templates — `../skills/rag.md` inside template markdown breaks post-install | FALSE | `grep -rn "\.\./" templates/ --include="*.md"` returns only code examples inside audit prompts (path-traversal exploit examples, user's project import statements). No `@../` Claude Code file-reference syntax found in templates. No `rag.md` skill file exists. All installer paths use framework-relative references handled by the fallback chain. | → No action |
| AUDIT-06 | No template version pinning — installer pulls main branch, no `template.lock.json` / `template_version` field | PARTIAL | `scripts/init-claude.sh:18` hardcodes `REPO_URL="https://raw.githubusercontent.com/.../main"` — no `--version` flag or tag-based URL accepted. `manifest.json:3` has `"version": "4.0.0"`. No `template.lock.json` or `.toolkit-version` file found. `toolkit-install.json` records installed version post-install but user cannot request a specific version at install time. | → HARDEN-C-03 (deferred v4.2+) |
| AUDIT-07 | No template feature-flags — workflow-v2 / memory-v3 / agents-v1 versions not declared | FALSE | `grep -n "feature_flags\|workflow-v\|memory-v\|agents-v" manifest.json scripts/init-claude.sh` → no matches. These version identifiers are not a concept in this repo. The toolkit does not version individual feature subsystems. The claim describes a feature system that was never part of this toolkit's design. | → No action |
| AUDIT-08 | Stack autodetection fragile — confidence scoring, override, dry-run preview missing | FALSE | `scripts/init-claude.sh:26-27` parses `--dry-run`; `scripts/init-claude.sh:42` parses positional `FRAMEWORK` override arg; `scripts/init-claude.sh:191-198` shows interactive menu with 8 framework choices. `scripts/init-local.sh:81-82` also supports `--dry-run`. `scripts/tests/test-dry-run.sh` exists. No confidence scoring, but CLI override + interactive menu + dry-run collectively address the gap. Claim's "no override, no dry-run" is contradicted by code. | → No action |
| AUDIT-09 | No dry-run installer mode — no preview of install plan | FALSE | `scripts/tests/test-dry-run.sh` exists. `scripts/init-claude.sh:20,26-27` implements `DRY_RUN=false` / `--dry-run`. `scripts/init-local.sh:72,81-82` same. `scripts/migrate-to-complement.sh:22,27` same. `scripts/init-claude.sh:385` documents grouped [INSTALL]/[SKIP] dry-run output. All three installer scripts implement `--dry-run`. Claim fully contradicted. | → No action |
| AUDIT-10 | No collision detection with existing `.claude/` — overwrite/merge/fail behavior undeclared | PARTIAL | `scripts/init-claude.sh:118` detects existing install and redirects to `update-claude.sh` or `--force`. Per-file idempotent guards in `scripts/init-local.sh:303,318,330,347`. `scripts/migrate-to-complement.sh:6` provides 3-way diff for migration. Gap: no unified declared collision policy across all scripts; behavior varies by script without a documented top-level strategy. | → HARDEN-B-01 (deferred v4.2+) |
| AUDIT-11 | No template integrity checksum — no `manifest.hash` | FALSE | `scripts/update-claude.sh:102-104` computes `MANIFEST_HASH=$(sha256_file "$MANIFEST_TMP")` on every update. `scripts/update-claude.sh:167-182` computes per-file sha256 vs stored hash. `scripts/lib/state.sh:43+` writes sha256 per installed file. `scripts/update-claude.sh:757-761` writes `manifest_hash` to `toolkit-install.json`. Full integrity pipeline exists: per-file sha256 stored at install, compared on every update. No separate `manifest.hash` file, but functional equivalent is implemented. | → No action |
| AUDIT-12 | Markdown commands as templates without linting — required sections/frontmatter/step markers not enforced | PARTIAL | `Makefile:105-138` `validate` target enforces `QUICK CHECK` and `SELF-CHECK` markers in `templates/*/prompts/*.md` audit files only. `.github/workflows/quality.yml:37-68` mirrors this in CI. `commands/*.md` (30 files) all carry `## Purpose` and `## Usage` headings by convention but no Makefile target or CI job enforces them. `Makefile:1` `.PHONY` list has no `validate-commands` target. Gap: linting exists for ONE surface (audit prompts), missing for another (slash commands). | → HARDEN-A-01 (implemented) |
| AUDIT-13 | No dependency graph between templates — rag requires memory, installer doesn't enforce | FALSE | `manifest.json` top-level keys: `manifest_version, version, updated, description, sp_equivalent_note, files, inventory, claude_md_sections, templates` — no `requires` or `dependencies` key. No `rag` template exists (`ls templates/` → base, global, go, laravel, nextjs, nodejs, python, rails). Framework templates are self-contained and mutually exclusive; no inter-template dependencies exist by design. Claim's example (rag-requires-memory) is inapplicable. | → No action |
| AUDIT-14 | No uninstall semantics — can't remove template safely | REAL | `ls scripts/ | grep -i uninstall` → no uninstall script found. No `--uninstall` flag in any installer script. `scripts/migrate-to-complement.sh` migrates between modes (v3.x → complement) with per-file prompts but is NOT an uninstall tool — it removes SP/GSD duplicates, not the toolkit itself. User cannot remove the toolkit without manual file deletion. No partial mitigation exists for the core uninstall use case. | → HARDEN-C-04 (deferred v4.2+) |
| AUDIT-15 | No template provenance metadata — no `installed_templates.json` post-install | PARTIAL | `find . -name "installed_templates.json"` → not found. `scripts/init-claude.sh:450` calls `write_state` writing `~/.claude/toolkit-install.json` with `version, mode, detected, installed_files (per-file sha256), skipped_files, installed_at` fields. Gap: `FRAMEWORK` variable is NOT passed to `write_state` (`scripts/lib/state.sh:43+` signature: `mode, has_sp, sp_ver, has_gsd, gsd_ver, installed_csv, skipped_csv`). A future auditor cannot determine from `toolkit-install.json` alone which framework template was installed. | → HARDEN-C-05 (deferred v4.2+) |

## Wave Assignment

Per D-05, findings split into 3 waves by theme:

- **Wave A (schema/validation):** AUDIT-NN rows with REAL/PARTIAL status
  AND Action naming `HARDEN-A-NN`. These go to the user gate for approval
  into Plan 12.2.
- **Wave B (install safety):** AUDIT-NN rows with Action naming
  `HARDEN-B-NN`. Deferred v4.2+; REQ definitions here only.
- **Wave C (provenance/metadata):** AUDIT-NN rows with Action naming
  `HARDEN-C-NN`. Deferred v4.2+; REQ definitions here only.

**Wave A members:** AUDIT-12 (PARTIAL — commands/ linting gap)

**Wave B members:** AUDIT-10 (PARTIAL — collision detection policy undeclared)

**Wave C members:** AUDIT-02, AUDIT-04, AUDIT-06, AUDIT-14, AUDIT-15
(PARTIAL or REAL — provenance, version pinning, merge strategy, uninstall, compat matrix)

**FALSE (no wave):** AUDIT-01, AUDIT-03, AUDIT-05, AUDIT-07, AUDIT-08, AUDIT-09, AUDIT-11, AUDIT-13

## Proposed HARDEN-A-NN Requirements (awaiting user gate)

| HARDEN ID | Derived From | Proposed Work |
|-----------|--------------|---------------|
| HARDEN-A-01 | AUDIT-12 | Add `validate-commands` Makefile target that greps every `commands/*.md` (except README.md) for `## Purpose` and `## Usage` headings; wire into the `check` target and the `validate-templates` job in `.github/workflows/quality.yml`; fail with list of non-compliant files |
