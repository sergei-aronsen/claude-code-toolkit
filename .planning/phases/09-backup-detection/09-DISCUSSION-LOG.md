# Phase 9: Backup & Detection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 09-backup-detection
**Mode:** `--auto` (all gray areas auto-selected; recommended defaults applied without AskUserQuestion)
**Areas discussed:** BACKUP-01 (cleanup flag), BACKUP-02 (threshold warning), DETECT-06 (CLI cross-check), DETECT-07 (version skew), Cross-cutting (lib layout, testing, branching)

---

## BACKUP-01 — `--clean-backups` flag

| Option | Description | Selected |
|--------|-------------|----------|
| Scan phantom `~/.claude/.toolkit-backup-*` path from spec | Match REQUIREMENTS.md wording; no dirs actually match | |
| Scan real `~/.claude-backup-*` + `~/.claude-backup-pre-migrate-*` patterns; patch spec to match code | What scripts actually create today | ✓ |
| Relocate existing backup dirs to spec path | Align to spec by moving user data | |

**Selected (auto-recommended):** real patterns, spec patched. **Rationale:** phantom path never created by any shipped script; relocating risks user data.

| Option | Description | Selected |
|--------|-------------|----------|
| `--keep N` sort by filesystem mtime (`stat -c %Y` / `stat -f %m`) | BSD/GNU split, tamperable | |
| `--keep N` sort by parsed epoch from dir name suffix | Monotonic, portable, cheap | ✓ |

**Selected:** parse epoch from name. **Rationale:** dir names carry `date -u +%s`; no syscall per dir.

| Option | Description | Selected |
|--------|-------------|----------|
| Per-dir `[y/N]` prompt | Matches migrate UX; safer | ✓ |
| Batch-list-then-one-confirm | Faster but wider blast radius | |

**Selected:** per-dir. **Rationale:** precedent in `migrate-to-complement.sh`; `curl | bash` safe via `< /dev/tty`.

| Option | Description | Selected |
|--------|-------------|----------|
| Prompt shows name only | Minimal | |
| Prompt shows name + size (du -sh) + age (epoch diff) | Full context | ✓ |

**Selected:** name + size + age.

| Option | Description | Selected |
|--------|-------------|----------|
| `--dry-run` ignored for cleanup | Treat cleanup as always-interactive | |
| `--dry-run` composes: print list with `[would remove]` / `[would keep]`, zero prompts, zero deletes | Principle of least surprise | ✓ |

**Selected:** dry-run composes. **Rationale:** Phase 11 will restyle dry-run output across all scripts — keep semantics aligned now.

---

## BACKUP-02 — threshold warning

| Option | Description | Selected |
|--------|-------------|----------|
| Count backup dirs per pattern separately | Reveals internal naming to user | |
| Combined count across both patterns | One number, user-centric | ✓ |

**Selected:** combined.

| Option | Description | Selected |
|--------|-------------|----------|
| Threshold = 5 | Aggressive | |
| Threshold = 10 (spec) | Matches REQUIREMENTS.md | ✓ |
| Threshold = 20 | Conservative | |
| Configurable via env var | Extra surface | |

**Selected:** 10 (spec literal). Tunability deferred.

| Option | Description | Selected |
|--------|-------------|----------|
| Inline warning in each creator script | Copy-paste drift risk | |
| Centralize in new `scripts/lib/backup.sh` | Single source | ✓ |
| Extend `scripts/lib/install.sh` | Mixes concerns with mode logic | |

**Selected:** new `scripts/lib/backup.sh`. **Rationale:** orthogonal concern; keeps blame readable.

| Option | Description | Selected |
|--------|-------------|----------|
| Fatal warning (exit 1) | Over-aggressive | |
| Non-fatal YELLOW ⚠ line, continues flow | Matches spec "Non-fatal" | ✓ |

**Selected:** non-fatal.

---

## DETECT-06 — `claude plugin list` cross-check

| Option | Description | Selected |
|--------|-------------|----------|
| Apply CLI check to both SP and GSD | GSD is NOT a Claude plugin | |
| Apply to SP only; document why GSD is FS-only | Verified via live CLI probe | ✓ |

**Selected:** SP only. **Rationale:** `claude plugin list --json` returns no entry for GSD (not registered as a plugin).

| Option | Description | Selected |
|--------|-------------|----------|
| New sibling function `cli_plugin_status()` | Extra API surface | |
| Extend existing `detect_superpowers()` body | Thematic fit; centralized SP logic | ✓ |

**Selected:** extend in place.

| Option | Description | Selected |
|--------|-------------|----------|
| CLI path runs unconditionally; fail if `claude` missing | Breaks users without CLI | |
| `command -v claude` guard; skip CLI silently if absent | FS remains primary | ✓ |

**Selected:** silent skip when CLI absent.

| Option | Description | Selected |
|--------|-------------|----------|
| CLI version overrides FS version heuristic | Authoritative | ✓ |
| FS version stays authoritative | Avoids touching existing logic | |

**Selected:** CLI version wins when available.

| Option | Description | Selected |
|--------|-------------|----------|
| Add explicit timeout wrapper around `claude plugin list --json` | BSD/GNU timeout split | |
| No timeout — rely on CLI being fast (<200ms live probe) | Defer until a real hang is reported | ✓ |

**Selected:** no timeout.

| Option | Description | Selected |
|--------|-------------|----------|
| Add `CLAUDE_PLUGIN_LIST_CHECK` env var per REQ phrasing | Extra test-seam | |
| Automatic when `claude` on PATH; existing `HAS_SP`/`HAS_GSD` seam covers tests | Simpler | ✓ |

**Selected:** automatic, existing seam.

---

## DETECT-07 — version-skew warning

| Option | Description | Selected |
|--------|-------------|----------|
| SP only | REQ mentions "SP/GSD" — ambiguous | |
| SP + GSD (both tracked in state schema v2) | Matches state.sh lines 91–92 | ✓ |

**Selected:** both.

| Option | Description | Selected |
|--------|-------------|----------|
| Emit in `init-claude.sh` too | First install has no prior version | |
| `update-claude.sh` only (per spec) | Tight scope | ✓ |

**Selected:** update-claude.sh only.

| Option | Description | Selected |
|--------|-------------|----------|
| Emit in 4-group summary block | Groups nicely with mode-change / skip-list warnings | |
| Emit after read_state + detection, before prompts | Early signal — user can abort | ✓ |

**Selected:** early emission.

| Option | Description | Selected |
|--------|-------------|----------|
| Non-fatal one-liner | Spec says "Non-fatal" | ✓ |
| Prompt for user confirmation | Blocks flow unnecessarily | |

**Selected:** non-fatal.

| Option | Description | Selected |
|--------|-------------|----------|
| Graded severity (major/minor/patch tinted differently) | Toolkit doesn't parse semver | |
| Any version mismatch fires the warning | Simple, consistent | ✓ |

**Selected:** any mismatch.

---

## Cross-cutting

| Option | Description | Selected |
|--------|-------------|----------|
| New top-level `make check` target for Phase 9 | Pattern match w/ Phase 12 HARDEN-A-01 | |
| No new check target — runtime behavior, covered by existing test jobs | D-29 test files attach to existing CI | ✓ |

**Selected:** no new check target. **Rationale:** BACKUP/DETECT are runtime behaviors, not lints.

| Option | Description | Selected |
|--------|-------------|----------|
| Single bundled plan 09-01 for all 4 REQs | Monolithic | |
| Four per-REQ plans, one PR each | Reviewable bites; matches Phase 8 D-19 | ✓ |

**Selected:** per-REQ (planner final call).

| Option | Description | Selected |
|--------|-------------|----------|
| bats for all Phase 9 tests | Infrastructure reuse from Phase 8 | |
| bats for BACKUP-01 only (sandbox fit); bash stubs for detect paths | Pragmatic | ✓ |

**Selected:** mixed strategy.

---

## Claude's Discretion

Recorded under CONTEXT.md `<decisions>` — list of minor choices (test file
partition, age string format, lib helper surface, plan bundling vs splitting)
left to the planner / executor at implementation time.

## Deferred Ideas

Captured under CONTEXT.md `<deferred>` — tunable threshold, explicit CLI
timeout, `--force`/`--yes` bypass, backup dir relocation, version-skew on
`init-claude.sh`, graded semver severity, extended plugin list probe,
shipping `backup.sh` in `.claude/`, removing legacy bash runner.
