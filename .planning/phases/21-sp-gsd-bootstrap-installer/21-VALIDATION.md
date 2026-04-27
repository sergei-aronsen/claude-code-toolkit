---
phase: 21
slug: sp-gsd-bootstrap-installer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash (plain test scripts; no test runner — same idiom as `scripts/tests/test-uninstall.sh` and `test-uninstall-prompt.sh`) |
| **Config file** | none |
| **Quick run command** | `bash scripts/tests/test-bootstrap.sh` |
| **Full suite command** | `make test` |
| **Estimated runtime** | ~6 seconds (5 hermetic scenarios in sandbox `$HOME`) |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/tests/test-bootstrap.sh`
- **After every plan wave:** Run `make test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~6 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | BOOTSTRAP-02 (constants) | — | Canonical install strings declared once in `lib/optional-plugins.sh`; bootstrap sources them — no drift | grep | `grep -q "^readonly TK_SP_INSTALL_CMD=" scripts/lib/optional-plugins.sh && grep -q "^readonly TK_GSD_INSTALL_CMD=" scripts/lib/optional-plugins.sh` | ❌ W0 | ⬜ pending |
| 21-01-02 | 01 | 1 | BOOTSTRAP-01..04 | T-21-01 (arbitrary code execution via TK_BOOTSTRAP_*_CMD) | `bootstrap_base_plugins()` exists; idempotent re-runs; fail-closed on missing TTY; flag/env precedence | grep | `grep -q "^bootstrap_base_plugins()" scripts/lib/bootstrap.sh && grep -q "/dev/tty" scripts/lib/bootstrap.sh` | ❌ W0 | ⬜ pending |
| 21-02-01 | 02 | 2 | BOOTSTRAP-01, BOOTSTRAP-04 | — | `init-claude.sh` argparse accepts `--no-bootstrap`; bootstrap call site is post-argparse, pre-`detect.sh` | grep | `grep -q "\-\-no-bootstrap)" scripts/init-claude.sh && grep -nE "bootstrap_base_plugins\|source.*detect\.sh" scripts/init-claude.sh \| awk -F: '/bootstrap_base_plugins/{b=$1} /detect\.sh/{d=$1} END {exit !(b && d && b<d)}'` | ❌ W0 | ⬜ pending |
| 21-02-02 | 02 | 2 | BOOTSTRAP-01, BOOTSTRAP-04 | — | `init-local.sh` argparse + bootstrap call site symmetry with `init-claude.sh` | grep | `grep -q "\-\-no-bootstrap)" scripts/init-local.sh && grep -q "bootstrap_base_plugins" scripts/init-local.sh` | ❌ W0 | ⬜ pending |
| 21-02-03 | 02 | 2 | BOOTSTRAP-03 | — | After bootstrap returns, both installers re-source `detect.sh` and recompute mode | grep | `grep -nE "bootstrap_base_plugins\|source.*detect\.sh\|resolve_install_mode" scripts/init-claude.sh \| awk -F: '/bootstrap_base_plugins/{b=$1} /source.*detect\.sh/{c++; if(c==2)d=$1} /resolve_install_mode/{m=$1} END {exit !(b && d && m && b<d && d<m)}'` | ❌ W0 | ⬜ pending |
| 21-03-01 | 03 | 3 | BOOTSTRAP-04 | — | S1 — both prompts answered Y → mocks invoked; toolkit-install.json mode reflects post-bootstrap state | integration | `bash scripts/tests/test-bootstrap.sh` (S1 assertions) | ❌ W0 | ⬜ pending |
| 21-03-02 | 03 | 3 | BOOTSTRAP-01 | — | S2 — both prompts answered N → no mocks invoked; mode == standalone | integration | `bash scripts/tests/test-bootstrap.sh` (S2 assertions) | ❌ W0 | ⬜ pending |
| 21-03-03 | 03 | 3 | BOOTSTRAP-04 | — | S3 — `--no-bootstrap` flag → no prompt rendered; no bootstrap log line | integration | `bash scripts/tests/test-bootstrap.sh` (S3 assertions) | ❌ W0 | ⬜ pending |
| 21-03-04 | 03 | 3 | BOOTSTRAP-02 | T-21-02 (claude CLI absent) | S4 — `claude` CLI missing → SP prompt suppressed with warn; GSD prompt still rendered | integration | `bash scripts/tests/test-bootstrap.sh` (S4 assertions) | ❌ W0 | ⬜ pending |
| 21-03-05 | 03 | 3 | BOOTSTRAP-02 | T-21-03 (upstream installer fail) | S5 — SP install fails (mock exit 1) → log_warning emitted; toolkit install continues; GSD prompt independent | integration | `bash scripts/tests/test-bootstrap.sh` (S5 assertions) | ❌ W0 | ⬜ pending |
| 21-03-06 | 03 | 3 | BOOTSTRAP-04 (CI mirror) | — | Test 28 wired into Makefile `test` target; CI quality.yml `validate-templates` job mirrors it | grep | `grep -q "Test 28: bootstrap" Makefile && grep -q "test-bootstrap.sh" .github/workflows/quality.yml` | ❌ W0 | ⬜ pending |
| 21-03-07 | 03 | 3 | BOOTSTRAP-04 (docs) | — | `--no-bootstrap` documented in `--help` of both installers AND in `docs/INSTALL.md` | grep | `bash scripts/init-claude.sh --help \| grep -q "\-\-no-bootstrap" && bash scripts/init-local.sh --help \| grep -q "\-\-no-bootstrap" && grep -q "\-\-no-bootstrap" docs/INSTALL.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/tests/test-bootstrap.sh` — hermetic test covering S1..S5 (~25 assertions)
  - Sandbox `$HOME=/tmp/tk-bootstrap-<unix-ts>-<pid>` with cleanup trap
  - Mock `claude` CLI as PATH-prepended shim; mock GSD installer via `TK_BOOTSTRAP_GSD_CMD` env override
  - TTY seam via named-file answer source: `TK_BOOTSTRAP_TTY_SRC=/path/to/answers` (cleaner than stdin redirect for two-prompt flow)
  - Each scenario asserts exit code, mock-invocation count, log-line presence/absence, and post-bootstrap state in `toolkit-install.json`
- [ ] No new fixtures needed in `scripts/tests/` — Phase 18..20 sandbox helpers are reused

*Existing infrastructure (sandbox HOME pattern, seam-env-var idiom, cleanup trap idiom) is sufficient — no new test-runner installation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real upstream installers (`claude plugin install superpowers@claude-plugins-official`, `bash <(curl -sSL …get-shit-done…/install.sh)`) actually succeed end-to-end | BOOTSTRAP-02 | Hits real Claude marketplace + GitHub raw content; not deterministic from CI; depends on upstream availability | After phase completes: in a clean `$HOME` sandbox, run `bash scripts/init-claude.sh` (no `--no-bootstrap`), answer Y to both prompts, confirm `~/.claude/plugins/cache/claude-plugins-official/superpowers/` exists and `~/.claude/get-shit-done/` exists |
| `bash <(curl -sSL …/init-claude.sh)` install path with `< /dev/tty` works on user machine | BOOTSTRAP-01 | Curl-piped install uses stdin for the script body — only real TTY exercises the prompt path | Manual: pipe `init-claude.sh` from raw URL after Phase 21 ships, accept SP+GSD prompts, observe behaviour matches local invocation |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
