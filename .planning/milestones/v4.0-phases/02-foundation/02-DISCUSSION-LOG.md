# Phase 2: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 02-foundation
**Areas discussed:** Manifest v1↔v2 compat, detect.sh bootstrap, SHA256 wrapper, Lock liveness + TTL, Manifest schema layout, conflicts_with coverage

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Manifest v1↔v2 compat | How old v3.x scripts react to v2 manifest (hard error vs shim vs mixed schema) | ✓ |
| detect.sh bootstrap | How curl\|bash callers load detect.sh | ✓ |
| SHA256 wrapper | Portable sha256 for STATE-04 file hashes | ✓ |
| Lock liveness + TTL | mkdir-lock + PID file + kill -0 check vs timestamp-only TTL | ✓ |
| Manifest schema layout | Full object migration vs mixed schema | ✓ |
| conflicts_with coverage | Per-file SP/GSD/both direction decision process | ✓ |
| Skip both — let defaults ride | Accept recommended defaults without discussion | ✓ (combined with opt-ins — discussed all 6 but kept tight) |

**User's choice:** All six areas discussed with focused single-question rounds. User accepted recommended defaults throughout.

---

## Manifest v1↔v2 compat semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Hard error both ways (Recommended) | Old v3.x script sees version:2 → exits with 'update toolkit' message. New v4.0 script sees version:1 → exits with 'run install to migrate'. Clean break, no shim code. | ✓ |
| New scripts shim v1, old scripts hard-error | v4.0 scripts upgrade bare-string entries to {path: ...} objects at read time. v3.x scripts still hard-error on v2. Allows mid-upgrade users on fresh v3.x manifest. | |
| Bidirectional compat shim | Both sides tolerate both schemas. Maximum surface area — rejected in prior art for being a maintenance sink. | |

**User's choice:** Hard error both ways (Recommended)
**Notes:** Matches PROJECT.md "Clean break, Conventional Commits with BREAKING CHANGE: footers" and the v4.0.0 breaking-release positioning. No shim code to maintain.

---

## detect.sh remote bootstrap

| Option | Description | Selected |
|--------|-------------|----------|
| mktemp + curl + source (Recommended) | Download detect.sh to mktemp file, source it, trap-rm on exit. Explicit, debuggable, leaves trace in /tmp for postmortem. Matches POSIX safety idioms. | ✓ |
| eval $(curl -sSL .../detect.sh) | Inline eval without tmp file. Tiny, one line. But harder to debug when detect fails and no artifact to inspect. | |
| Inline detect functions into init-claude.sh | No separate detect.sh — violates DETECT-01/04 (must be sourced from single canonical path). Rejected. | |

**User's choice:** mktemp + curl + source (Recommended)
**Notes:** Preserves debuggability when detection misbehaves — the downloaded file remains in /tmp for postmortem until trap-rm fires.

---

## SHA256 wrapper pattern

| Option | Description | Selected |
|--------|-------------|----------|
| python3 hashlib (Recommended) | python3 -c 'import hashlib; print(hashlib.sha256(...).hexdigest())'. Matches Phase 1 D-05/D-12 standardization on python3. Single JSON+hash idiom across TK. | ✓ |
| Shell fallback (sha256sum \|\| shasum) | if command -v sha256sum; then sha256sum; else shasum -a 256; fi. Zero python dep for hash step. But introduces second portability pattern alongside python3 JSON work. | |
| Require coreutils on macOS | Document brew install coreutils as prereq. Extra user friction, rejected by project constraints. | |

**User's choice:** python3 hashlib (Recommended)
**Notes:** One-tool-one-pattern discipline. python3 >= 3.8 already verified as a dependency by setup-council.sh.

---

## Lock liveness + stale recovery

| Option | Description | Selected |
|--------|-------------|----------|
| mkdir + PID file + kill -0 + 1h TTL (Recommended) | mkdir ~/.claude/.toolkit-install.lock → write $$ to lock/pid → stale check: if pid gone (kill -0 fails) OR dir mtime > 1h, rm -rf and re-acquire with warning. Most accurate liveness. | ✓ |
| mkdir + 1h timestamp-only TTL | Simpler: no PID file. Stale = dir mtime > 1h. Can leave user blocked up to 1h after crash. Simpler code, weaker UX. | |
| mkdir + PID via mktemp+mv | Atomic PID write inside lock. Overkill for single-writer scenario since mkdir already atomic. | |

**User's choice:** mkdir + PID file + kill -0 + 1h TTL (Recommended)
**Notes:** Belt-and-suspenders — covers both "PID reused" and "process alive but hung" failure modes.

---

## Manifest schema layout

| Option | Description | Selected |
|--------|-------------|----------|
| Full object migration (Recommended) | Every entry under files.* becomes {path, conflicts_with?, requires_base?}. Large one-time diff but homogeneous schema downstream. Simpler jq queries, no dual-path parsing. | ✓ |
| Mixed schema — only conflict-flagged | Files without conflicts stay as bare strings; only duplicates upgrade to objects. Smaller diff, but every reader needs dual-path logic (string \| object). | |
| Full migration + sibling metadata file | files.* stays bare; new manifest-metadata.json holds conflicts. Two files of truth — drift risk, rejected. | |

**User's choice:** Full object migration (Recommended)
**Notes:** Homogeneous reader path downstream — single jq/python expression across all file lists. Avoids dual-path conditionals.

---

## conflicts_with coverage direction

| Option | Description | Selected |
|--------|-------------|----------|
| Researcher verifies each file (Recommended) | gsd-phase-researcher greps SP/GSD plugin dirs to verify each TK duplicate's actual source. Lands authoritative per-file conflicts_with list in RESEARCH.md. Planner writes it into manifest. | ✓ |
| Default both, narrow on verification | Assume every listed duplicate conflicts with both SP and GSD unless researcher proves otherwise. Safer skip behavior but risks over-skipping TK-unique files. | |
| User fills in per-file map now | Skip research — user dictates SP/GSD/both per file. Not feasible without reading both plugin codebases. | |

**User's choice:** Researcher verifies each file (Recommended)
**Notes:** Seed list of 13 duplicates supplied from PROJECT.md. Researcher must also flag newly discovered duplicates during its scan.

---

## Wrap-up

| Option | Description | Selected |
|--------|-------------|----------|
| Ready for context (Recommended) | Write CONTEXT.md + DISCUSSION-LOG.md, commit, route to plan-phase. | ✓ |
| Explore more gray areas | Surface additional decisions (detect.sh SP version string format, STATE.md installed_at timezone, mkdir-lock message copy). | |

**User's choice:** Ready for context (Recommended)

## Claude's Discretion

- Exact wording of `⚠ Reclaimed stale lock from PID $OLD_PID` warning.
- Exact filename/layout of POSIX `stat` portability shim (standalone file vs inlined function block in detect.sh).
- Whether `scripts/validate-manifest.py` splits out as a separate file or stays inline in the Makefile (rule of thumb: >~30 lines → split out).
- Exact error message strings for manifest version mismatch.
- Exact structure of `scripts/tests/test-detect.sh` harness (any approach producing four cases + pass/fail output acceptable).

## Deferred Ideas

- CLI-based detection via `claude plugin list` (DETECT-FUT-01, v2).
- Plugin version skew detection (DETECT-FUT-02, v2).
- `bats` automated test suite (TEST-01, v2).
- Auto-cleanup of `.claude-backup-*` dirs (BACKUP-01/02, v2).
- Dry-run preview (MODE-06, Phase 3).
- Install-mode logic (MODE-01..05, Phase 3).
- Update-flow drift detection (UPDATE-01..06, Phase 4).
- Migration script (MIGRATE-01..06, Phase 5).
- Orchestration pattern (ORCH-FUT-01..06, v4.1).
- Styled diff dry-run (v4.1 per Out of Scope).
