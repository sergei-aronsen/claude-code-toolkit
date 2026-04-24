# Phase 8: Release Quality - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 08-release-quality
**Mode:** `--auto` (all areas auto-resolved to recommended defaults; no interactive Q&A)
**Areas discussed:** REL-01 bats port, REL-02 cell-parity, REL-03 `--collect-all`, CI integration, Transition

---

## REL-01 — bats port

### GA-1: Bats file layout

| Option | Description | Selected |
|--------|-------------|----------|
| Single file | All 13 cells as `@test` in one `release.bats` | |
| Per-mode | 4 mode files + `translation-sync.bats` (5 total) | ✓ |
| Per-cell | 13 individual `.bats` files | |

**Auto-choice:** Per-mode — balances parallelism/readability, mirrors `docs/INSTALL.md` structure, avoids 627-line monolith and 13-file sprawl.

### GA-2: Shared helpers between bash and bats runners

| Option | Description | Selected |
|--------|-------------|----------|
| Extract to shared lib | `scripts/tests/matrix/lib/helpers.bash` sourced by both | ✓ |
| Duplicate in bats | Port helpers into bats files directly | |
| Source `validate-release.sh` | Bats `setup_file` sources runner + skips main | |

**Auto-choice:** Extract lib — zero duplication, zero drift risk, clean migration path.

### GA-3: Assertion preservation strategy

| Option | Description | Selected |
|--------|-------------|----------|
| 1:1 byte-for-byte port | Same `assert_*` calls with same args from each cell | ✓ |
| bats-assert library | Rewrite via `bats-assert`/`bats-support` | |
| Mixed — bats idioms + bash helpers | Use bats `run` + custom asserts where cleaner | |

**Auto-choice:** 1:1 — 63 assertions preserved verbatim; plan-time diff audit; no semantic rewrite.

### GA-4: `make test-matrix-bats` target

| Option | Description | Selected |
|--------|-------------|----------|
| Thin wrapper | `bats scripts/tests/matrix/*.bats` | ✓ |
| Per-file targets | `test-matrix-standalone`, `test-matrix-complement-sp`, etc. | |
| Replace `make test` Test 16 | Remove bash runner from `make test` | |

**Auto-choice:** Thin wrapper — simplest surface; existing `make test` (Test 16) untouched during transition.

---

## REL-02 — cell-parity gate

### GA-5: Surface definition for RELEASE-CHECKLIST.md

| Option | Description | Selected |
|--------|-------------|----------|
| `--cell <name>` command occurrences | Grep runnable commands in doc | ✓ |
| Per-cell section headings | Restructure doc to heading-per-cell | |
| HTML comments / metadata | Hidden cell markers in doc | |

**Auto-choice:** `--cell` commands — matches doc's real cross-reference pattern; avoids doubling doc length.

### GA-6: Parity rule strictness

| Option | Description | Selected |
|--------|-------------|----------|
| Strict 3/3 | Any missing surface fails gate | ✓ |
| 2/3 allowed | Translation-sync exempt | |
| Soft warning | Fail softly, continue | |

**Auto-choice:** Strict 3/3 — literal REL-02 spec ("≤2 of 3 surfaces fails").

### GA-7: INSTALL.md `--cell` placement

| Option | Description | Selected |
|--------|-------------|----------|
| Add commands to tables | New column or inline snippet per row | ✓ |
| Leave as-is, relax parity | Drop INSTALL.md from surface list | |
| HTML-comment metadata | Invisible cell tags in doc | |

**Auto-choice:** Add commands — keeps doc user-facing; satisfies strict parity; also fixes pre-existing "12 cells" vs 13 drift.

### GA-8: Implementation language

| Option | Description | Selected |
|--------|-------------|----------|
| Pure shell + grep + jq | No new deps | ✓ |
| Python script | Reuse HARDEN-A-01 pattern | |
| Node | Use existing markdownlint infra | |

**Auto-choice:** Pure shell — POSIX-shell invariant; zero new deps; grep + jq sufficient for list cross-ref.

### GA-9: Makefile target name

| Option | Description | Selected |
|--------|-------------|----------|
| `cell-parity` | Matches REQ phrasing | ✓ |
| `matrix-parity` | Broader naming | |
| `docs-parity` | Doc-centric naming | |

**Auto-choice:** `cell-parity` — spec-literal match; consistent with existing `validate-*` / `*-align` / `*-drift` target vocabulary.

---

## REL-03 — `--collect-all` aggregation

### GA-10: Aggregated output format

| Option | Description | Selected |
|--------|-------------|----------|
| Plain ASCII table | `\|`-separated rows, portable | ✓ |
| Colored per-cell blocks | Styled text output | |
| JSON + human table | Machine + human readable | |

**Auto-choice:** Plain ASCII — no jq/yaml; Phase 11 (UX-01) owns styling/coloring.

### GA-11: `--collect-all` exit code semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Binary 0/1 | 0 iff all pass; 1 if any fail | ✓ |
| Graded | Exit count of failed cells (1–127) | |
| Always 0 | Reporter-only, no signal | |

**Auto-choice:** Binary 0/1 — CI reads summary table from stdout for detail.

### GA-12: Flag coexistence with `--all`

| Option | Description | Selected |
|--------|-------------|----------|
| Coexist, mutually exclusive | `--all` fail-fast, `--collect-all` aggregate; both = arg error | ✓ |
| Replace `--all` | Make `--collect-all` the new default | |
| Single flag with modifier | `--all --continue` | |

**Auto-choice:** Coexist — zero regression in today's `--all` path; explicit opt-in for aggregate mode.

### GA-13: Default behavior (no flag)

| Option | Description | Selected |
|--------|-------------|----------|
| Unchanged fail-fast | Today's behavior preserved | ✓ |
| Switch default to collect-all | Aggregate by default | |

**Auto-choice:** Unchanged — explicit REL-03 spec: "default fail-fast behavior unchanged."

---

## CI integration

### GA-14: Bats install mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| `bats-core-action` pinned SHA | GitHub Action, convention-matched | ✓ |
| npm `bats` | Cross-platform via npm | |
| brew/apt per-OS step | Native package managers | |
| git submodule | Pin bats-core at SHA | |

**Auto-choice:** Pinned Action — matches existing SHA-pinned action convention (checkout, shellcheck, markdownlint).

### GA-15: CI job layout

| Option | Description | Selected |
|--------|-------------|----------|
| New `test-matrix-bats` job, parallel to `test-init-script` | Added to `quality.yml` | ✓ |
| Extend existing `test-init-script` | Add bats step to existing job | |
| Separate workflow file | New `.github/workflows/matrix.yml` | |

**Auto-choice:** New parallel job — isolates runtime, clearer failure attribution, matches existing job-per-concern pattern.

### GA-16: Cell-parity CI wiring

| Option | Description | Selected |
|--------|-------------|----------|
| Inside `validate-templates` job via `make check` | Single step addition | ✓ |
| Separate `cell-parity` job | New job, parallel execution | |

**Auto-choice:** Inside `validate-templates` — follows HARDEN-A-01 pattern (`make validate-commands` step); no job proliferation.

---

## Transition + compatibility

### GA-17: Bash runner lifecycle

| Option | Description | Selected |
|--------|-------------|----------|
| Keep indefinitely | Bats additive; remove decision deferred | ✓ |
| Remove at end of phase | Bats replaces bash after parity proven | |
| Mark deprecated, keep 1 milestone | Remove in v4.2 | |

**Auto-choice:** Keep indefinitely — REL-01 spec: "Bash version remains for backward compat during transition"; removal is a future-milestone decision.

### GA-18: PR granularity

| Option | Description | Selected |
|--------|-------------|----------|
| One PR per REQ | `rel-01`, `rel-02`, `rel-03` branches | ✓ |
| Single PR | All three REQs together | |
| Mixed | REL-01 standalone; REL-02+REL-03 bundled | |

**Auto-choice:** Per REQ — reviewability, independent revert, matches project Conventional-Commits + per-feature-branch convention.

---

## Claude's Discretion (captured in CONTEXT.md)

- Exact 63-assertion partition across 5 bats files (derived mechanically from cell membership)
- `setup_file` vs `setup` granularity in bats
- `printf` width vs `column -t` for aggregated table
- `--cell <name>` placement inside INSTALL.md rows (new column vs inline command)

## Deferred Ideas

- Remove bash runner (v4.2+)
- Per-cell section headings in RELEASE-CHECKLIST.md (rejected — doc-length cost)
- `--collect-all --json` output (YAGNI)
- Graded exit codes (YAGNI)
- Auto-updating INSTALL.md cell count from `--list` (Phase 9+)
- Bats-aware rewrite of `scripts/tests/test-matrix.sh` (deferred)

## Deferred: Reviewed Todos (not folded)

None — no pending todos matched Phase 8 scope.
