# Release Checklist — v4.0.0

This document is the human sign-off surface for the v4.0.0 release. Each cell maps
1:1 to a cell in `docs/INSTALL.md` and to an assertion function in
`scripts/validate-release.sh`. Run the runner, then tick each checkbox.

**How to run:**

```bash
# Run all 13 cells fail-fast
bash scripts/validate-release.sh --all

# Or run individual cells for post-mortem
bash scripts/validate-release.sh --cell complement-sp-upgrade

# List all cell names
bash scripts/validate-release.sh --list
```

**Fail-fast:** The runner exits on the first red cell. Failing-cell sandbox
directories at `/tmp/tk-matrix-<cell>-<ts>/` are preserved for post-mortem.

---

## Mode: standalone

No base plugins detected. All 54 TK files install.

| Scenario | Precondition | Command | Expected output | Auto-checked | Human sign-off |
|----------|-------------|---------|-----------------|--------------|----------------|
| **Fresh install** | No SP, no GSD; no prior TK. | `bash scripts/validate-release.sh --cell standalone-fresh` | `PASS: standalone-fresh` | `validate-release.sh` | `[ ]` |
| **Upgrade from v3.x** | v3.x TK from pre-4.0 commit; no state file; no SP/GSD. | `bash scripts/validate-release.sh --cell standalone-upgrade` | `PASS: standalone-upgrade` | `validate-release.sh` | `[ ]` |
| **Re-run / idempotent** | TK installed; re-run init-local.sh with same mode. | `bash scripts/validate-release.sh --cell standalone-rerun` | `PASS: standalone-rerun` | `validate-release.sh` | `[ ]` |

---

## Mode: complement-sp

`superpowers` detected; `get-shit-done` absent. 7 files skipped (SP conflicts).

| Scenario | Precondition | Command | Expected output | Auto-checked | Human sign-off |
|----------|-------------|---------|-----------------|--------------|----------------|
| **Fresh install** | SP staged in `$HOME/.claude/plugins/cache/.../superpowers/5.0.7/`. | `bash scripts/validate-release.sh --cell complement-sp-fresh` | `PASS: complement-sp-fresh` | `validate-release.sh` (includes agent-collision check) | `[ ]` |
| **Upgrade from v3.x** | v3.x TK from pre-4.0 commit; SP staged. | `bash scripts/validate-release.sh --cell complement-sp-upgrade` | `PASS: complement-sp-upgrade` | `validate-release.sh` | `[ ]` |
| **Re-run / idempotent** | `complement-sp` state on disk; re-run install. | `bash scripts/validate-release.sh --cell complement-sp-rerun` | `PASS: complement-sp-rerun` | `validate-release.sh` (includes agent-collision check) | `[ ]` |

---

## Mode: complement-gsd

`get-shit-done` detected; `superpowers` absent. Currently 54 files install (no GSD conflicts in manifest).

| Scenario | Precondition | Command | Expected output | Auto-checked | Human sign-off |
|----------|-------------|---------|-----------------|--------------|----------------|
| **Fresh install** | GSD staged at `$HOME/.claude/get-shit-done/bin/gsd-tools.cjs`. | `bash scripts/validate-release.sh --cell complement-gsd-fresh` | `PASS: complement-gsd-fresh` | `validate-release.sh` | `[ ]` |
| **Upgrade from v3.x** | v3.x TK from pre-4.0 commit; GSD staged. | `bash scripts/validate-release.sh --cell complement-gsd-upgrade` | `PASS: complement-gsd-upgrade` | `validate-release.sh` | `[ ]` |
| **Re-run / idempotent** | `complement-gsd` state on disk; re-run install. | `bash scripts/validate-release.sh --cell complement-gsd-rerun` | `PASS: complement-gsd-rerun` | `validate-release.sh` | `[ ]` |

---

## Mode: complement-full

Both SP and GSD detected. 47 files install (SP conflicts skipped; no GSD conflicts).

| Scenario | Precondition | Command | Expected output | Auto-checked | Human sign-off |
|----------|-------------|---------|-----------------|--------------|----------------|
| **Fresh install** | SP and GSD both staged. | `bash scripts/validate-release.sh --cell complement-full-fresh` | `PASS: complement-full-fresh` | `validate-release.sh` (includes agent-collision check) | `[ ]` |
| **Upgrade from v3.x** | v3.x TK from pre-4.0 commit; SP and GSD both staged. | `bash scripts/validate-release.sh --cell complement-full-upgrade` | `PASS: complement-full-upgrade` | `validate-release.sh` | `[ ]` |
| **Re-run / idempotent** | `complement-full` state on disk; re-run install. | `bash scripts/validate-release.sh --cell complement-full-rerun` | `PASS: complement-full-rerun` | `validate-release.sh` (includes agent-collision check) | `[ ]` |

---

## Translation Sync

Structural sync check (line-count within ±20% of README.md). Content correctness
is owned by Phase 7.1; this cell only verifies the translations exist and have
not drifted structurally.

| Check | Command | Expected | Auto-checked | Human sign-off |
|-------|---------|----------|--------------|----------------|
| **README translations line-count drift** | `bash scripts/validate-release.sh --cell translation-sync` | All 8 translation files (`docs/readme/{de,es,fr,ja,ko,pt,ru,zh}.md`) within ±20% of README.md line count | `make translation-drift` (via runner) | `[ ]` |

---

## Cross-surface gates (run outside matrix)

These gates run via `make check` and must pass before tagging:

| Gate | Command | What it checks |
|------|---------|----------------|
| Shell lint | `make shellcheck` | All scripts pass shellcheck. |
| Markdown lint | `make mdlint` | All `.md` files pass markdownlint. |
| Template structure | `make validate` | Audit templates carry QUICK CHECK + SELF-CHECK sections; manifest schema passes. |
| Required Base Plugins | `make validate-base-plugins` | All 7 templates carry the Required Base Plugins section. |
| Version alignment | `make version-align` | `manifest.json` == `CHANGELOG.md` top release == `init-local.sh --version`. |
| Translation drift | `make translation-drift` | All 8 translations within ±20% of README.md. |
| Static agent-collision | `make agent-collision-static` | Manifest annotates every SP-shadowed agent with `conflicts_with: ["superpowers"]`. |

Sign off here once `make check` passes clean: `[ ]`

---

## Tagging (manual — outside Phase 7)

Phase 7 ends with the repo at **ready-to-tag**. The release cut itself is a
manual human action per `CLAUDE.md` "never push directly to main" invariant:

```bash
git tag -a v4.0.0 -m "Release 4.0.0"
git push --tags
```

Sign off here once the tag is pushed: `[ ]`

---

*See also: [docs/INSTALL.md](INSTALL.md) — the same 12 cells documented from the user-facing install perspective.*
