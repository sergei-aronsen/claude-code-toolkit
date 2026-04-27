# Phase 21: SP/GSD Bootstrap Installer - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 21-sp-gsd-bootstrap-installer
**Mode:** `--auto` (Claude selected recommended defaults)
**Areas auto-resolved:** Bootstrap library, Prompt structure, Idempotency, Missing prerequisites, Output streaming, Re-detection, Flag/env semantics, Test architecture

---

## Bootstrap library + invocation site

| Option | Description | Selected |
|--------|-------------|----------|
| New `scripts/lib/bootstrap.sh` shared library | Sourced by both installers; precedent: `lib/{backup,dry-run-output,optional-plugins}.sh` | ✓ |
| Inline bootstrap logic in `init-claude.sh` only | Smaller diff but duplicates code in `init-local.sh` | |
| Subcommand `init-claude.sh bootstrap` | Adds CLI surface; out of scope | |

**Selected:** Shared library (D-01).
**Rationale:** Established pattern — every cross-script utility added since Phase 9 has been a `lib/*.sh` file. Keeps `init-claude.sh` and `init-local.sh` thin and avoids duplication.

---

## Bootstrap order

| Option | Description | Selected |
|--------|-------------|----------|
| SP first, then GSD | Plugin install (faster, fail-fast); GSD second (curl, slower) | ✓ |
| GSD first, then SP | Reverse order — no obvious advantage | |
| Parallel | Adds output interleaving complexity for no UX win | |

**Selected:** SP first, then GSD (D-04).
**Rationale:** SP install is fast and depends on `claude` CLI presence — failing fast surfaces the missing-prereq case before user invests in the GSD curl wait.

---

## Prompt fail-closed behaviour

| Option | Description | Selected |
|--------|-------------|----------|
| Fail-closed N when no `/dev/tty` | Skip both prompts silently when piped; emit single `bootstrap skipped — no TTY` info line | ✓ |
| Hard error when no TTY | Aborts install in CI — too aggressive | |
| Fall back to env-var Y | Implicit auto-yes — violates "no auto-install without consent" | |

**Selected:** Fail-closed N (D-06).
**Rationale:** Mirrors UN-03 (`prompt_modified_for_uninstall` fail-closed). Consistent across the toolkit.

---

## Idempotency

| Option | Description | Selected |
|--------|-------------|----------|
| Detect-before-prompt — skip prompt if already installed | Re-runs are quiet; no re-install attempts | ✓ |
| Always prompt; let upstream installer no-op | Upstream installer noise on every re-run | |
| Detect post-bootstrap only | Wastes user time prompting for already-installed plugin | |

**Selected:** Detect-before-prompt (D-08).
**Rationale:** `init-claude.sh` re-runs are common (CI sanity, user re-running after pull). Quiet idempotency is a polish invariant.

---

## Missing `claude` CLI

| Option | Description | Selected |
|--------|-------------|----------|
| Suppress SP prompt + warn line | Don't ask `[y/N]` for an action that cannot succeed | ✓ |
| Prompt anyway; let `claude plugin install` fail | Rude — user picks Y, then sees `command not found` | |
| Block install with `claude` install instructions | Aborts toolkit install too aggressively | |

**Selected:** Suppress SP prompt (D-09).
**Rationale:** GSD prompt independent (curl-based). User still gets toolkit-install + GSD option even without Claude CLI on PATH.

---

## Upstream installer failure

| Option | Description | Selected |
|--------|-------------|----------|
| Non-fatal warn + continue toolkit install | REQ-02 invariant; don't penalise toolkit install for upstream issues | ✓ |
| Abort toolkit install on upstream failure | Too aggressive — user wants TK regardless | |
| Retry once, then continue | Doubles network latency for marginal benefit | |

**Selected:** Non-fatal warn + continue (D-10).
**Rationale:** REQ-02 locked. Toolkit install is the primary contract; bootstrap is an opportunistic enhancement.

---

## Canonical install string source-of-truth

| Option | Description | Selected |
|--------|-------------|----------|
| Constants in `lib/optional-plugins.sh`, sourced by `bootstrap.sh` | Single source-of-truth; DRY | ✓ |
| Duplicate strings inline in `bootstrap.sh` | Drift risk between bootstrap/recommend/templates | |
| New `scripts/lib/install-strings.sh` | Adds a lib for two strings — overkill | |

**Selected:** Constants in `optional-plugins.sh` (D-12).
**Rationale:** `optional-plugins.sh` already has these strings literally. Refactoring them into named constants is a 4-line change that locks every consumer to the same string.

---

## Re-detection after bootstrap

| Option | Description | Selected |
|--------|-------------|----------|
| Re-source `detect.sh` + recompute mode | Mode reflects post-bootstrap reality; existing primitives sufficient | ✓ |
| Re-run `init-claude.sh` from inside itself | Recursion — fragile and confusing | |
| Force user to re-run install manually | Bad UX | |

**Selected:** Re-source + recompute (D-14).
**Rationale:** REQ-03 locked. `detect.sh` is already idempotent; calling it twice is safe.

---

## State schema change

| Option | Description | Selected |
|--------|-------------|----------|
| No new field — mode change captures effect | Schema-stable; minimum surface area | ✓ |
| Add `bootstrap_run: true` flag | No consumer needs it; schema drift | |
| Add `bootstrap.sp_installed: bool` + `bootstrap.gsd_installed: bool` | More info but nobody consumes; drift | |

**Selected:** No schema change (D-15).
**Rationale:** YAGNI. If a future feature wants per-plugin install history, add then.

---

## `--no-bootstrap` flag vs env var precedence

| Option | Description | Selected |
|--------|-------------|----------|
| CLI flag wins, then env, then default | Mirrors `NO_BANNER` precedence (UN-07) | ✓ |
| Env wins over CLI flag | Inverts user intent when both set | |
| First-set wins (any order) | Confusing; pattern-mismatch with UN-07 | |

**Selected:** CLI flag → env → default (D-16).
**Rationale:** Consistency with NO_BANNER. Predictable.

---

## Test seam

| Option | Description | Selected |
|--------|-------------|----------|
| Env vars `TK_BOOTSTRAP_SP_CMD` / `TK_BOOTSTRAP_GSD_CMD` override real install | Hermetic; matches `TK_UNINSTALL_*` precedent | ✓ |
| Mock `claude` and `curl` binaries on PATH | Heavier sandbox; harder to make hermetic | |
| Skip integration test; unit-test bootstrap.sh helpers only | Misses the prompt + flow contract | |

**Selected:** Env-var seams (D-19).
**Rationale:** Phase 18 established this idiom. Reuse, don't invent.

---

## Test scope

| Option | Description | Selected |
|--------|-------------|----------|
| 5 scenarios: prompt-y, prompt-N, --no-bootstrap, claude-missing, install-fail | Covers all branches + edge cases | ✓ |
| 3 scenarios: y, N, --no-bootstrap | Misses claude-missing + install-fail | |
| Full matrix (16 combinations) | Combinatorial bloat; no proportional value | |

**Selected:** 5 scenarios (D-20).
**Rationale:** Branch coverage that matches REQ-04 mandate.

---

## Bootstrap reach (which installers?)

| Option | Description | Selected |
|--------|-------------|----------|
| `init-claude.sh` + `init-local.sh` only | First-run UX surface; matches REQ scope | ✓ |
| Also `update-claude.sh` | Re-prompting on every update — noise | |
| Also `migrate-to-complement.sh` | Migration users have already chosen — irrelevant | |

**Selected:** Init scripts only (D-03).
**Rationale:** Migration and update are post-install workflows. Bootstrap is a first-run feature.

---

## Manifest scope (Phase 21 vs Phase 22 split)

| Option | Description | Selected |
|--------|-------------|----------|
| Ship `bootstrap.sh` in Phase 21; register in manifest in Phase 22 | Clean phase boundary; LIB-01 owns manifest schema change | ✓ |
| Ship + register in Phase 21 | Couples Phase 21 to a Phase 22 success criterion | |
| Defer file shipping to Phase 22 | Blocks BOOTSTRAP-01..04 unnecessarily | |

**Selected:** Ship in 21, register in 22 (D-22).
**Rationale:** Phase boundaries match REQ boundaries. Phase 22 owns LIB-01 — the manifest schema change is part of that contract.

---

## Claude's Discretion

- Exact log-line wording (researcher / planner picks consistent with `lib/install.sh` styling)
- One entry-point function vs SP/GSD helpers — testability call
- `bash <(curl …)` direct invocation vs temp-file wrapper — testability call

## Deferred Ideas

- Non-interactive `--bootstrap=sp|gsd|both` flag — v4.5+ if CI surfaces demand
- Bootstrap during `update-claude.sh` — out of scope; revisit only on user signal
- Auto-installing rtk / caveman / Claude itself — out of scope by design

---

*Phase: 21-sp-gsd-bootstrap-installer*
*Discussion logged: 2026-04-27 (auto mode)*
