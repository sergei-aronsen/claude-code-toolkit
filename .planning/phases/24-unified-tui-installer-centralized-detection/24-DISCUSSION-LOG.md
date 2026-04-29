# Phase 24: Unified TUI Installer + Centralized Detection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-29
**Phase:** 24-unified-tui-installer-centralized-detection
**Areas discussed:** Item ordering & grouping, SP/GSD placement, Failure handling default, --yes default-set semantics

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Item ordering & grouping | Flat dispatch order vs grouped sections (Bootstrap / Core / Optional). | (delegated) |
| SP/GSD placement | Same TUI list as TK components vs separate first-page bootstrap step. | (delegated) |
| Failure handling default | Continue-on-error vs fail-fast as default behavior; `--fail-fast` opt-in. | (delegated) |
| --yes default-set semantics | All uninstalled (auto-fix) vs minimal (toolkit only) vs everything-listed. | (delegated) |

**User's choice:** "Я хочу, чтобы ты сам принимал самые лучшие решения. Здесь я вряд ли тебе помогу." — full Claude's-discretion delegation across all four gray areas.

**Notes:** No interactive Q&A occurred. Claude locked decisions in CONTEXT.md `<decisions>` section based on prior phase context (BACKCOMPAT-01 invariant, UX-01 chezmoi-grade precedent, v4.4 BOOTSTRAP TTY pattern), existing code patterns (`dro_*` API, `bootstrap.sh` test seam shape), and stated user preferences (KISS / YAGNI / minimal surface). Each decision has rationale stated in CONTEXT.md so the planner can re-open if research surfaces a constraint.

---

## Item ordering & grouping

| Option | Description | Selected |
|--------|-------------|----------|
| Flat dispatch order | Single linear list; SP → GSD → toolkit → security → RTK → statusline. | |
| Grouped sections | Three groups: Bootstrap / Core / Optional with non-selectable section headers. | ✓ |

**Claude's choice:** Grouped sections (D-01..D-03)
**Rationale:** SP/GSD have a different lifecycle (canonical upstream installers); toolkit is load-bearing TK install; security/rtk/statusline are addons. Grouping makes the install map self-explanatory and sets a precedent for Phase 25 (MCPs group) + Phase 26 (Skills group).

---

## SP/GSD placement

| Option | Description | Selected |
|--------|-------------|----------|
| Same TUI, Bootstrap group | Single TUI render, single confirmation, SP/GSD at top in Bootstrap group. | ✓ |
| Separate first page | TUI page 1 = SP/GSD, page 2 = TK components, two confirmations. | |

**Claude's choice:** Same TUI in Bootstrap group (D-04..D-07)
**Rationale:** BACKCOMPAT-01 explicitly says `bootstrap.sh` becomes the no-TTY fallback for SP/GSD prompts only — the TUI replaces the interactive layer above it. Two TUI pages would re-introduce the multi-prompt flow we are explicitly deleting. `bootstrap.sh` library stays as the no-TTY fallback unchanged.

---

## Failure handling default

| Option | Description | Selected |
|--------|-------------|----------|
| Continue-on-error (default) | Subsequent components still run on per-component failure; recorded in summary; `--fail-fast` opts into stop-on-first. | ✓ |
| Fail-fast (default) | First failure aborts the run; `--continue` opts into resilient mode. | |

**Claude's choice:** Continue-on-error default (D-08..D-11)
**Rationale:** 5+ components in one run; a transient network failure on one should not abort the rest. Mirrors `update-claude.sh` resilient pattern. CI users who want clean exit codes pass `--fail-fast`. Per-component summary (chezmoi-grade `dro_*` table) keeps resilient mode auditable.

---

## --yes default-set semantics

| Option | Description | Selected |
|--------|-------------|----------|
| All uninstalled (auto-fix) | `--yes` installs every component currently uninstalled in canonical order. Matches TUI pre-check logic. | ✓ |
| Minimal (toolkit only) | `--yes` installs toolkit only; user opts into others explicitly. | |
| Everything-listed | `--yes` installs every component including already-installed (forces re-install). | |

**Claude's choice:** All uninstalled (D-12..D-15)
**Rationale:** `--yes` = "accept TUI defaults non-interactively", not "install everything". Symmetric with TUI: a TUI user would see exactly these items pre-checked. Already-installed components stay skipped under `--yes`; `--yes --force` is the only "install everything" surface. No `--preset` flag in v4.5 (TUI-FUT-02 deferred).

---

## Bonus decisions (small gray areas, batched)

These were not user-selected but are needed for downstream agents:

| Sub-area | Options considered | Locked-in choice | Decision ID |
|----------|-------------------|------------------|-------------|
| Selection visual | Reverse video / arrow indicator `▶` | Arrow indicator `▶` (D-16) — reverse video flaky on tmux/screen with non-default colors |
| Key bindings | Arrows + space + enter only / +vim j/k / +numbers | Arrows + space + enter + `q`/Ctrl-C only (D-18) — single canonical scheme, doc-friendly |
| Help line | Always shown / on-demand toggle | Always at bottom (D-19) — discoverability > screen real estate |
| Description placement | Inline below item / sidebar / focused-row line | Single dimmed line below help line (D-20) — saves vertical space |
| Summary format | dro_* table / plain ASCII / bulleted list | dro_* chezmoi-grade table (D-27) — UX-01 precedent, helpers reusable |
| Stderr capture on fail | None / last 5 lines / full output | Last 5 lines per failed component (D-28) — actionable without re-run |

---

## Claude's Discretion

User explicitly delegated **all four** primary gray areas plus implicit downstream choices. The CONTEXT.md `<decisions>` section is the canonical record; planner has flexibility on:

- Exact ANSI sequences for arrow / dim / bold rendering (Bash 3.2 portable forms).
- `dro_print_install_status` exact column widths and color choices.
- Whether `dispatch_<name>` is a function in `dispatch.sh` or a separate file.
- Help line placement (top vs bottom of TUI viewport) — choose post first render test.
- Keystroke-buffer flushing requirements on macOS Bash 3.2 (research per `bash-tui` patterns).
- Stderr-tail length in failure summary (5 lines starting point; tune if noisy).

## Deferred Ideas

Captured in CONTEXT.md `<deferred>` section. Highlights:

- Vim-style `j`/`k` keys → TUI-FUT-04 (new).
- Multi-line item descriptions → TUI v2.
- Live progress bars → TUI-FUT-01.
- `--preset minimal|full|dev` → TUI-FUT-02.
- Phase 25/26 group sections (MCPs / Skills) → those phases.
- `manifest.json` 4.5.0 version bump → Phase 27 distribution (single atomic bump per v4.4 precedent).
- TUI search / filter (`/`) → revisit at Phase 25 (9 MCPs) or Phase 26 (22 skills).
- Localized TUI text → English-only in v4.5.
