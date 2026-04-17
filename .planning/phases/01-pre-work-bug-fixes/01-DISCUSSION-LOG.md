# Phase 1: Pre-work Bug Fixes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 01-pre-work-bug-fixes
**Areas discussed:** BUG-01 portable replace, BUG-03 JSON escape tool, BUG-06 version SSOT, BUG-07 scope, BUG-04 sudo handling, Branch strategy, Commit granularity, Verification approach

---

## Gray area selection

| Option | Description | Selected |
|--------|-------------|----------|
| BUG-01 portable replace | Which BSD-safe replacement for GNU `head -n -1` | ✓ |
| BUG-03 JSON escape tool | python3 json.dumps vs jq --arg | ✓ |
| BUG-06 version SSOT | VERSION file / manifest-read / manual-sync | ✓ |
| BUG-07 scope | Quick-fix vs structural now | ✓ |

**User's choice:** All four selected for discussion.

---

## BUG-01 portable replace

| Option | Description | Selected |
|--------|-------------|----------|
| sed '$d' (Recommended) | POSIX one-liner, BSD+GNU, drop-in replace | ✓ |
| awk-буфер | `awk 'NR>1{print last}{last=$0}'` — verbose, no advantage | |
| HTML-anchor refactor | `<!-- USER:section -->` markers, breaks existing user CLAUDE.md | |

**User's choice:** sed '$d' (Recommended)
**Notes:** HTML-anchor rejected as out-of-scope — would break every v3.x user's CLAUDE.md, belongs in a separate dedicated phase, not a bug-fix ticket.

---

## BUG-03 JSON escape tool

| Option | Description | Selected |
|--------|-------------|----------|
| python3 json.dumps (Recommended) | Already Council dep; same pattern as setup-security.sh | ✓ |
| jq --arg | Also a dep, shorter, but breaks single-tool standardization | |

**User's choice:** python3 json.dumps (Recommended)
**Notes:** Codebase standardizes on python3 for JSON mutation. Keep one pattern.

---

## BUG-06 version SSOT

| Option | Description | Selected |
|--------|-------------|----------|
| init-local.sh reads manifest.json (Recommended) | jq one-liner; manifest = SSOT; zero new files | ✓ |
| VERSION file в корне | New file, 3 sources read it; classic but adds a file | |
| Manual sync + make validate | Keep 3 sources, add equality check; weaker — drift still possible between CI runs | |

**User's choice:** init-local.sh reads manifest.json (Recommended)
**Notes:** Actual 4.0.0 bump lands in Phase 7 (per REQUIREMENTS). Phase 1 only aligns the structure so future bumps touch one file.

---

## BUG-07 scope

| Option | Description | Selected |
|--------|-------------|----------|
| Quick-fix (Recommended) | Add design.md to hand-list at update-claude.sh:147; Phase 4 UPDATE-02 does structural fix | ✓ |
| Structural now | jq-parse manifest.json already in Phase 1; overlaps Phase 2 MANIFEST-01 schema bump | |

**User's choice:** Quick-fix (Recommended)
**Notes:** Structural fix already scheduled for Phase 4. Throwaway work to do it twice.

---

## BUG-04 sudo handling

| Option | Description | Selected |
|--------|-------------|----------|
| Print command + ask (Recommended) | Remove sudo; print `sudo apt-get install tree`; [y/N] prompt; user elevates, not script | ✓ |
| Run sudo без 2>/dev/null | Keep invocation, make failures visible; still auto-elevates | |
| Skip и предупредить | tree is optional; just warn if absent | |

**User's choice:** Print command + ask (Recommended)
**Notes:** Script never invokes sudo itself. tree is optional for brain.py — non-fatal warning if declined.

---

## Branch strategy

| Option | Description | Selected |
|--------|-------------|----------|
| fix/phase-1-bugs (Recommended) | Single branch, 7 commits, one PR | ✓ |
| fix/bug-XX per bug | 7 branches + 7 PRs; high merge overhead | |

**User's choice:** fix/phase-1-bugs (Recommended)

---

## Commit granularity

| Option | Description | Selected |
|--------|-------------|----------|
| 1 commit / bug (Recommended) | 7 commits with `fix:` + BUG-XX ref; bisect-friendly, atomic revert | ✓ |
| Bundled в один commit | One `fix: phase 1 bugs` — simpler, loses granularity | |

**User's choice:** 1 commit / bug (Recommended)

---

## Verification approach

| Option | Description | Selected |
|--------|-------------|----------|
| make check + manual BSD (Recommended) | Ubuntu CI lint + manual darwin smoke for BUG-01/03/05 | ✓ |
| + CI bats сейчас | Add bats now; TEST-01 is v2 scope — creep | |
| Только make check | Lint-only; BUG-01/03/05 not caught by shellcheck | |

**User's choice:** make check + manual BSD (Recommended)
**Notes:** bats deferred to v2 (TEST-01). Phase 1 verification = shellcheck + markdownlint + hand-run smokes on darwin.

---

## Final confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| Ready for context (Recommended) | Write CONTEXT.md + DISCUSSION-LOG.md, proceed to planning | ✓ |
| Explore more gray areas | Keep discussing | |

**User's choice:** Ready for context (Recommended)

---

## Claude's Discretion

- Exact user-facing prompt wording (BUG-04 [y/N], BUG-05 restore warning)
- CHANGELOG `[Unreleased]` bullet formatting
- jq-absent fallback approach in BUG-06 (grep+cut vs python3 inline)
- make validate extension style (shell vs Python helper)

## Deferred Ideas

- HTML-anchor refactor of update-claude.sh smart-merge — future phase
- Tarball-based install — v4.1 (performance)
- bats automated test suite — v2 (TEST-01)
- Auto-cleanup of old backups — v2 (BACKUP-01/02)
- `.claude/` gitignore hygiene — follow-up chore, only if blocks make check
- Advertised count drift in README/docs — Phase 6 (DOCS-01..04)
- Pinning @google/gemini-cli and cc-safety-net — out of v4.0 scope
- Hardcoded model IDs — ORCH-FUT-03 (v4.1)
