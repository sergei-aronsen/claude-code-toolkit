---
phase: 24
slug: unified-tui-installer-centralized-detection
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-29
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: 24-RESEARCH.md §9.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash native (no external framework — hermetic shell scripts) |
| **Config file** | None — `scripts/tests/test-*.sh` are self-contained |
| **Quick run command** | `bash scripts/tests/test-install-tui.sh` |
| **Full suite command** | `make test` (Tests 21–31) |
| **Estimated runtime** | ~8 seconds (TUI test alone), ~25 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/tests/test-install-tui.sh`
- **After every plan wave:** Run `make test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~8 seconds per task commit

---

## Per-Task Verification Map

> Per-REQ-ID verification map. Task IDs filled by planner 2026-04-29 (5 plans / 18 tasks). Format: `P<plan>-T<task>` (e.g. P01-T1 = Plan 01 Task 1).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| P02-T1 | 02 | 1 | TUI-01 | — | Arrow/space/enter keystrokes consumed without canonical line buffering on Bash 3.2 | unit | `bash scripts/tests/test-install-tui.sh` | ❌ Wave 0 | ⬜ pending |
| P02-T1 | 02 | 1 | TUI-02 | — | `TK_TUI_TTY_SRC` redirects to fixture; absent `/dev/tty` + no `--yes` → fail-closed exit 0 | unit | same | ❌ Wave 0 | ⬜ pending |
| P02-T1 | 02 | 1 | TUI-03 | — | Ctrl-C mid-render restores `stty sane` and shows cursor (`\e[?25h`) | unit (signal-trap fixture) | same | ❌ Wave 0 | ⬜ pending |
| P02-T1 | 02 | 1 | TUI-04 | — | Already-installed components render `[installed ✓]`, pre-unchecked | unit | same | ❌ Wave 0 | ⬜ pending |
| P02-T1 | 02 | 1 | TUI-05 | — | Confirmation prompt `Install N component(s)? [y/N]` shown before dispatch | unit | same | ❌ Wave 0 | ⬜ pending |
| P02-T1 | 02 | 1 | TUI-06 | — | `NO_COLOR=1` set → no ANSI escape bytes in output (bold-only fallback) | unit | same | ❌ Wave 0 | ⬜ pending |
| P04-T2 | 04 | 3 | TUI-07 | — | `test-install-tui.sh` contains ≥15 distinct `assert_*` calls | meta-assertion (count via grep) | `grep -c '^assert' scripts/tests/test-install-tui.sh` | ❌ Wave 0 | ⬜ pending |
| P01-T1+T2 | 01 | 1 | DET-01 | — | `detect2.sh` sources `detect.sh`; `is_superpowers_installed` / `is_gsd_installed` return 0/1 matching `HAS_SP` / `HAS_GSD` | unit | `bash scripts/tests/test-install-tui.sh` (detection scenario) | ❌ Wave 0 | ⬜ pending |
| P01-T1+T2 | 01 | 1 | DET-02 | — | `is_security_installed` returns 0 when `cc-safety-net` is on `$PATH` AND wired in `~/.claude/hooks/pre-bash.sh` or `~/.claude/settings.json` | unit (mock $PATH + tmp HOME) | same | ❌ Wave 0 | ⬜ pending |
| P01-T1+T2 | 01 | 1 | DET-03 | — | `is_statusline_installed` returns 0 when `~/.claude/statusline.sh` exists AND `"statusLine"` key present in `~/.claude/settings.json` | unit | same | ❌ Wave 0 | ⬜ pending |
| P01-T1+T2 | 01 | 1 | DET-04 | — | `is_rtk_installed` returns 0 when `command -v rtk` resolves | unit (mock $PATH) | same | ❌ Wave 0 | ⬜ pending |
| P01-T1+T2 | 01 | 1 | DET-05 | — | `is_toolkit_installed` returns 0 when `~/.claude/toolkit-install.json` exists | unit | same | ❌ Wave 0 | ⬜ pending |
| P03-T1 | 03 | 2 | DISPATCH-01 | — | Dispatch order = SP → GSD → toolkit → security → RTK → statusline | unit (mock dispatchers record call order) | same | ❌ Wave 0 | ⬜ pending |
| P03-T2+T3 | 03 | 2 | DISPATCH-02 | — | `setup-security.sh --yes` exits 0 with no `read: ...` errors; `install-statusline.sh --yes` no-op exits 0 | smoke | `bash scripts/setup-security.sh --yes --dry-run; bash scripts/install-statusline.sh --yes` | ❌ Wave 0 | ⬜ pending |
| P04-T1+T2 | 04 | 3 | DISPATCH-03 | — | `install.sh` flow: detect → TUI → confirm → dispatch in order → `dro_*` summary; exit code = 0 on no failures, 1 on any | integration | `bash scripts/tests/test-install-tui.sh` | ❌ Wave 0 | ⬜ pending |
| P04-T1+T4 | 04 | 3 | BACKCOMPAT-01 | — | All 26 assertions in `test-bootstrap.sh` stay green; `init-claude.sh` URL byte-identical | regression | `bash scripts/tests/test-bootstrap.sh` | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/tests/test-install-tui.sh` — hermetic test ≥15 assertions covering TUI-01..07, DET-01..05, DISPATCH-01..03 (created in Wave 0 / Plan 04)
- [ ] `scripts/lib/tui.sh` — TUI library (created in Wave 1 / Plan 02)
- [ ] `scripts/lib/detect2.sh` — detection v2 library (created in Wave 1 / Plan 01)
- [ ] `scripts/lib/dispatch.sh` — dispatch library (created in Wave 2 / Plan 03)
- [ ] `scripts/install.sh` — top-level orchestrator (created in Wave 3 / Plan 04)
- [ ] `setup-security.sh --yes` — flag added in Wave 2 / Plan 03
- [ ] `install-statusline.sh --yes` — no-op stub added in Wave 2 / Plan 03
- [ ] `manifest.json` files.libs[] + files.scripts[] entries for new libs (Plan 05 wiring)

*Existing infrastructure that does NOT need rebuild: `test-bootstrap.sh` (BACKCOMPAT-01 regression baseline), `dro_*` API in `scripts/lib/dry-run-output.sh` (D-27 reuse), `bootstrap.sh` (D-04/D-05 fallback).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Arrow rendering on real terminal (macOS Terminal.app, iTerm2, gnome-terminal, tmux, screen, SSH) | TUI-01, TUI-06 | TUI fidelity over real escape sequences cannot be fully fixture-tested — must visually confirm `▶` arrow tracks focus, no flicker, no color leak | Run `bash scripts/install.sh --dry-run` interactively; navigate ↑↓, observe arrow movement, then `q` to cancel and confirm terminal returns to normal |
| `rtk init -g` interactivity (Assumption A2 from RESEARCH §10.7) | DISPATCH-01 | Cannot mock the real RTK installer; need to confirm `rtk init -g` completes without TTY prompt under `--yes` | Run `bash scripts/install.sh --yes` on a clean system; verify RTK dispatch completes without hanging |
| Cross-platform Bash 3.2 (macOS) + Bash 4+ (Linux) parity | TUI-01..06 | CI runs Linux only; macOS Bash 3.2 quirks (no `read -t 0`, no associative arrays) need real-hardware verification | Run hermetic test on macOS dev box; compare assertion count + exit status to Ubuntu CI run |

---

## Nyquist Evaluation Signals (≥6 required — 6 confirmed)

1. **Assertion-based (TUI-07):** `test-install-tui.sh` ≥15 distinct assertions covering all keystroke paths, flag modes, no-TTY fallback, terminal restore. Verified by `grep -c '^assert' scripts/tests/test-install-tui.sh ≥ 15`.
2. **Output conformance (D-27):** `dro_print_install_status` state strings (`installed ✓`, `skipped`, `failed (exit N)`) verified by `assert_contains` grep against captured stdout.
3. **Zero-mutation (`--dry-run`):** Mock dispatchers write a sentinel file when invoked. After `bash scripts/install.sh --yes --dry-run`, `assert_not_exists` for every sentinel file. Proves no installer subprocess ran.
4. **Terminal restore on signal (TUI-03):** After Ctrl-C fixture, `stty -g` matches pre-test capture (or `stty sane` triple-fallback recovers it).
5. **Backcompat regression (BACKCOMPAT-01):** `test-bootstrap.sh` 26 assertions remain green throughout. Run as separate gate before / after every Phase 24 commit.
6. **Flag symmetry (DISPATCH-02):** `setup-security.sh --yes` and `install-statusline.sh --yes` both exit 0 with empty stderr (no `read: ...` errors).

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies (filled by planner per task)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (8 Wave 0 items above)
- [ ] No watch-mode flags (`-w`, `--watch`) in test commands
- [ ] Feedback latency < 10s for `test-install-tui.sh`
- [ ] `nyquist_compliant: true` set in frontmatter once planner has filled per-task rows

**Approval:** approved 2026-04-29 (planner)
