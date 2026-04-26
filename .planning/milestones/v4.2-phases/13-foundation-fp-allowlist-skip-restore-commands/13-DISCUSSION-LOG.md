# Phase 13: Foundation — FP Allowlist + Skip/Restore Commands - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 13 — Foundation — FP Allowlist + Skip/Restore Commands
**Areas discussed:** Entry schema/format, Command UX + git boundary, Duplicate matching key, council_status field semantics

---

## Area selection

**Question:** Which areas to discuss for Phase 13?
**Options presented:**

| Option | Selected |
|--------|----------|
| Entry schema/format | ✓ |
| Command UX + git boundary | ✓ |
| Duplicate matching key | ✓ |
| council_status field semantics | ✓ |

**User's choice:** All four areas selected.

---

## Entry schema/format

### Q1 — Entry structure

| Option | Description | Selected |
|--------|-------------|----------|
| ATX heading block (Recommended) | `### path:line — rule-id` heading + key:value bullets (Date, Council, Reason). Human-readable, LLM-friendly, grep-parseable. | ✓ |
| Markdown table row | `\| path:line \| rule \| date \| council \| reason \|`. Compact; multi-line reasons messy. | |
| YAML-fenced blocks | ```yaml ... ```. Machine-parseable; adds yq dependency or brittle awk. | |
| HTML-comment sentinels + markdown body | `<!-- audit-skip:start ... -->`. Bullet-proof bash ranged-delete; clutter. | |

**User's choice:** ATX heading block.
**Notes:** Preview confirmed format with concrete `### scripts/setup-security.sh:142 — SEC-RAW-EXEC` example showing Date/Council/Reason bullets and multi-line reason continuation.

### Q2 — Seed structure + entry order

| Option | Description | Selected |
|--------|-------------|----------|
| Append-only chronological (Recommended) | Frontmatter + intro + `## Entries` H2 + commented example. New entries land at EOF. | ✓ |
| Grouped by file path, alphabetically sorted | Entries clustered by path; `/audit-skip` needs sort-and-rewrite. | |
| Grouped by rule-id | Cluster by rule; same downsides as path-grouping. | |

**User's choice:** Append-only chronological.

---

## Command UX + git boundary

### Q3 — Reason text with spaces

| Option | Description | Selected |
|--------|-------------|----------|
| Trailing concat (Recommended) | `<file:line> <rule>` positional, everything after = reason joined with spaces. No quoting needed; `git commit -m`-style. | ✓ |
| Require quotes | Strict positional: `"reason text"`. Predictable parse; easy to forget. | |
| Interactive prompt for reason | Pass `<file:line> <rule>` only; command prompts `Reason: ` interactively. | |

**User's choice:** Trailing concat.

### Q4 — Untracked file handling

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail, suggest staging (Recommended) | `git ls-files --error-unmatch` strict; refuse with `git add` suggestion; no `--force`. | ✓ |
| Warn and allow if file exists on disk | Soft check; emit warning; proceed. Lets users skip findings on WIP code. | |
| Hard fail by default, --force escape | Default refuses; `--force` allows. Adds documented escape hatch. | |

**User's choice:** Hard fail, suggest staging.

---

## Duplicate matching key

### Q5 — Strictness of `path:line + rule` match

| Option | Description | Selected |
|--------|-------------|----------|
| Exact triple match (Recommended) | `<exact path>:<exact line>:<exact rule-id>` byte-for-byte case-sensitive. Same path+rule on different line = NEW entry. | ✓ |
| Path+rule overlap (loose) | `<path>:<rule-id>` (line ignored). Refuses any same-file-same-rule entry. Blocks legitimate distinct findings. | |
| Exact triple + warn on path+rule overlap | Reject only on exact triple but warn on path+rule overlap at different line. User-visible signal without blocking. | |

**User's choice:** Exact triple match.

---

## council_status field semantics

### Q6 — Allowed values + initial state

| Option | Description | Selected |
|--------|-------------|----------|
| `unreviewed \| council_confirmed_fp \| disputed` (Recommended) | Three values. Default `unreviewed`. `--council=council_confirmed_fp` flag for Phase 15 FP persistence. `disputed` for Phase 15 disagreement. | ✓ |
| `unreviewed \| confirmed` (binary) | Two values. Disputes stay in council reports, only resolved-FP lands here. | |
| Free-text status field | Any string; convention enforced by /audit but not validated. | |

**User's choice:** `unreviewed | council_confirmed_fp | disputed`.

---

## Wrap-up: Installer wiring + git ops

### Q7 — Discuss low-level details or defer to Claude's discretion?

| Option | Description | Selected |
|--------|-------------|----------|
| Discuss them | Cover (a) installer seed pattern (manifest vs inline heredoc) and (b) `/audit-skip` post-write behavior. | |
| Claude's discretion + ready for context (Recommended) | Defer both. Default to lessons-learned.md inline-seed precedent and write-only (no git ops). | ✓ |

**User's choice:** Claude's discretion + ready for context.

---

## Claude's Discretion

The following decisions were deferred to research/planning per the user's wrap-up choice:

- **CD-01:** Installer seed pattern — default to `lessons-learned.md` precedent (inline heredoc in init-claude.sh / init-local.sh, NOT registered in `manifest.files.rules[]`)
- **CD-02:** `/audit-skip` post-write behavior — write file only, no `git add`, no `git commit`
- **CD-03:** Validation/parser logic location — inline in `commands/audit-skip.md` markdown spec; extract to `scripts/lib/audit-exceptions.sh` only if dedup across `/audit-skip`, `/audit-restore`, and Phase 14 `/audit` justifies it
- **CD-04:** Markdown lint compliance for the seed file and appended entries (MD040, MD031/032, MD026)

---

## Deferred Ideas

- Batch-import from Phase 14 audit report (`/audit-skip --from-report`) — explicitly forbidden by REQ-COUNCIL-05
- Cross-repo exception sync — deferred per REQUIREMENTS.md Out of Scope
- Sentry/Linear ticket creation per council REAL finding — post-v4.2
- `--no-council` flag on `/audit` — forbidden in v4.2

(No scope-creep ideas surfaced during the discussion — user stayed inside the phase boundary.)
