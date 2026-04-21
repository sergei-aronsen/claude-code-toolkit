# Phase 5: Migration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 05-migration
**Areas discussed:** 3-way diff mechanics, User-mod detection, Orchestration, Idempotence marker

---

## Gray area selection

| Option | Description | Selected |
|--------|-------------|----------|
| 3-way diff механика | MIGRATE-02: source of 3 hashes + SP/GSD mapping + unreadable-plugin fallback | ✓ |
| User-mod детекция | MIGRATE-03 subtlety: Phase 4 D-50 synthesis defeats install_time_hash check; need second signal? | ✓ |
| Оркестрация | MIGRATE-01: strict standalone vs update-claude.sh detects + offers | ✓ |
| Idempotence маркер | MIGRATE-06: what signals "already migrated"? | ✓ |

**Claude's selection framing:** multi-select. User picked all four.

---

## 3-way diff механика

### TK template hash — source

| Option | Description | Selected |
|--------|-------------|----------|
| Remote manifest fetch (реком) | Mirror Phase 4 curl pattern; fetch each duplicate from `$REPO_URL/<path>`, sha256. 7 HTTP requests total. Accurate. No schema change. | ✓ |
| Embedded hash в manifest.json | Add `.files.*[].sha256` field pre-computed in CI. 1 HTTP request. But schema bump, CI dependency, drift risk. | |
| Git blob sha (local) | `git hash-object <path>` if running in checkout. Doesn't work for `curl \| bash`. | |

**User's choice:** Remote manifest fetch
**Notes:** matches Phase 4 remote-fetch canon; no new schema, no CI dependency.

### SP/GSD equivalent — path mapping

| Option | Description | Selected |
|--------|-------------|----------|
| Same basename (реком) | `commands/debug.md` in TK → `commands/debug.md` in SP. Verify live grep pre-lock. Zero schema change. Breaks silently if SP renames. | ✓ |
| Explicit field in manifest | Add `.files.*[].sp_equivalent` / `.gsd_equivalent`. Explicit. But schema bump, 7 manual entries, SP-version drift. | |
| Search-by-path in plugin dir | Deep `find` in `~/.claude/plugins/cache/.../superpowers/<ver>/` by basename. Survives SP reorg. Slow, false matches. | |

**User's choice:** Same basename
**Notes:** planner obligated to verify during plan-phase research — if any of 7 mismatches, switch to explicit field.

### SP/GSD path unreadable — fallback

| Option | Description | Selected |
|--------|-------------|----------|
| 2-column diff + marker (реком) | Show TK vs current, 3rd col = "— (SP file not found)". Continue prompt. Graceful degrade. | ✓ |
| Abort with advice | "SP detected but file absent — reinstall SP and retry". Exit 1. Hard UX. | |
| Skip file, log warning | Silently skip, assume "no SP equiv → don't need to remove". Risk: leaves duplicate in place under complement mode. | |

**User's choice:** 2-column diff + marker
**Notes:** user still has enough info to decide; maps to Phase 4 D-72 style graceful degrade.

---

## User-mod детекция

### Real mod detection under synthesized state

| Option | Description | Selected |
|--------|-------------|----------|
| 2 сигнала (реком) | (a) current != state.install_time_hash OR (b) current != TK_template_hash. Either triggers warning. Covers D-50 synthesis edge case. | ✓ |
| Только state.sha256 | Trust state. Document limitation: "first migrate after v3.x upgrade can't show pre-upgrade edits." | |
| Conditional on installed_at=='unknown' | Two code paths: synthesized → TK_template compare, normal → state.sha256. Fewer HTTP calls in stable case. | |

**User's choice:** 2 сигнала
**Notes:** single unified code path, covers both eras, no conditional branch.

### Prompt shape for modified files

| Option | Description | Selected |
|--------|-------------|----------|
| [y/N/d] default N (реком) | Default N. `d` = unified diff on-disk vs TK_template, re-prompt. Matches Phase 4 D-56. | ✓ |
| [y/N] + warning text | Just warning, no diff command. Simpler; user may blindly accept. | |
| [y/N/d/s] + s=skip-and-move | Extra option to move to `~/.claude/custom/`. Scope risk. | |

**User's choice:** [y/N/d] default N
**Notes:** matches Phase 4 D-56 verbatim — same mental model, same diff semantics.

### Synthesis marker in state file

| Option | Description | Selected |
|--------|-------------|----------|
| Add `synthesized_from_filesystem: true` (реком) | Explicit boolean. State schema bumps 1→2. Phase 4 D-50 writes it; Phase 5 reads it. | ✓ |
| Reuse installed_at=='unknown' | Phase 4 already emits this. No schema change. Fragile — string-based signal. | |
| Not needed (covered by Q1) | If Q1='2 сигнала', marker redundant. But explicit marker aids debuggability. | |

**User's choice:** Add synthesized_from_filesystem: true
**Notes:** state schema bumps 1→2; Phase 4 D-50 retrofitted to write it.

---

## Оркестрация

### Entry point for migrate

| Option | Description | Selected |
|--------|-------------|----------|
| update-claude.sh detects + offers (реком) | Single-line CYAN hint when triple-AND signal true. Invocation manual — MIGRATE-01 respected. | ✓ |
| Strict standalone | Manual discovery only. Doc in README/CHANGELOG (Phase 6). Silent drift risk. | |
| Auto-run migrate from update | Auto-invoke. Violates MIGRATE-01 "one-time, isolated from routine update path". | |

**User's choice:** update-claude.sh detects + offers
**Notes:** MIGRATE-01 standalone file preserved; discoverability problem solved via non-destructive hint.

### Detection signal conditions for hint

| Option | Description | Selected |
|--------|-------------|----------|
| mode==standalone AND (SP∨GSD) AND fs-dup (реком) | Triple AND. Covers "user manually deleted duplicates" case by checking filesystem. | ✓ |
| Only mode==standalone AND SP/GSD | Simpler. Ghostly hint after manual deletion. | |
| Only fs-dup (no state check) | Spam even in complement mode. | |

**User's choice:** mode==standalone AND (SP∨GSD) AND fs-dup
**Notes:** filesystem-intersection check makes signal self-correcting.

---

## Idempotence маркер

### "Already migrated" canonical signal

| Option | Description | Selected |
|--------|-------------|----------|
| mode != standalone AND fs-dup ∩ skip_set пуст (реком) | Two signals AND. Self-healing: manual rollback recoverable, partial-migration re-runs safe. | ✓ |
| Only mode != standalone | Simple. But state corrupted → false-positive re-run. Not self-healing. | |
| Separate migrated_at timestamp | Explicit. But orthogonal to actual fs state. | |

**User's choice:** mode != standalone AND fs-dup ∩ skip_set пуст
**Notes:** no extra schema field; two existing signals sufficient.

### "Nothing to do" output + exit code

| Option | Description | Selected |
|--------|-------------|----------|
| One-line + exit 0 (реком) | `Already migrated to <mode>. Nothing to do.` exit 0. Matches Phase 4 D-59 no-op UX. | ✓ |
| Verbose: list what migrated | Print mode, list removed, timestamp. Noisy in CI. | |
| --verbose flag for details | Default one-line, --verbose expands. Duplicates CLI surface. | |

**User's choice:** One-line + exit 0
**Notes:** matches Phase 4 D-59 git-pull style.

### Partial migration mode

| Option | Description | Selected |
|--------|-------------|----------|
| recommend_mode (реком) | Write `recommend_mode(HAS_SP, HAS_GSD)`. Kept files in state.skipped_files with reason=kept_by_user. Re-run re-prompts remaining. | ✓ |
| Keep standalone if partial | Mode stays standalone unless 100%. Punishes user for partial acceptance. | |
| Ask user at the end | Extra prompt. User friction. | |

**User's choice:** recommend_mode
**Notes:** D-78's filesystem intersection makes re-run re-prompt only declined files — no wasted interaction.

---

## Ready-for-context check

| Option | Description | Selected |
|--------|-------------|----------|
| Ready for context (реком) | 4 main areas covered. Flags + summary format = Claude's Discretion; Phase 4 D-58 pattern reused. | ✓ |
| Explore flags + summary | Discuss --yes/--dry-run/--no-backup flags and MIGRATED/KEPT/BACKED UP summary structure. | |

**User's choice:** Ready for context
**Notes:** flag surface and summary format left to planner; Phase 4 D-58 provides precedent.

---

## Claude's Discretion

- Exact flag surface (`--yes`, `--dry-run`, `--verbose`; `--no-backup` rejected per invariant).
- Post-migration summary format (reuse Phase 4 D-58 4-group shape).
- Diff command exact form (`diff -u` POSIX default).
- Warning text wording for D-73 two-signal case.
- Hint wording emitted by update-claude.sh per D-76.
- Whether migrate reuses the manifest tempfile from update-claude.sh when same-session.
- Exact field name for state v2 addition (`synthesized_from_filesystem` proposed).

## Deferred Ideas

- `[y/N/d/s]` skip-and-move-to-custom shape (v4.1 candidate).
- Auto-invoke from update-claude.sh (explicitly excluded by MIGRATE-01).
- Backup rotation / auto-cleanup (BACKUP-01/02 v4.1).
- Side-by-side diff viewer (v4.1).
- `--force-mode` flag (rejected for MVP).
- Migration docs in README/CHANGELOG (Phase 6).
- Explicit `sp_equivalent:` manifest field (escape hatch only if plan-phase research surfaces mismatch).
- Release validation matrix (Phase 7).
