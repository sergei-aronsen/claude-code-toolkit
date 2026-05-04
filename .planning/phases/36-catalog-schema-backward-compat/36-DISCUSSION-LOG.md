# Phase 36: Catalog Schema + Backward Compat - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-04
**Phase:** 36-catalog-schema-backward-compat
**Mode:** `--auto` (autonomous workflow, single-pass)
**Areas discussed:** Schema enforcement, default assignments, backward-compat fallback, test contract

---

## Schema Enforcement Strictness

| Option | Description | Selected |
|--------|-------------|----------|
| Strict enum (`user`/`project` only) | Validator fails on missing field or any other value | ✓ |
| Nullable allowed | Treat `null` as fallback | |
| Soft enforcement (warn only) | Log warning, do not fail build | |

**Auto-pick rationale:** SCOPE-01 acceptance criterion explicitly says "fails loudly when an MCP entry lacks `default_scope` or carries an invalid enum value". Strict enum is the only path that satisfies the contract.

---

## Default-Scope Assignment Source

| Option | Description | Selected |
|--------|-------------|----------|
| User-supplied list (REQUIREMENTS SCOPE-02) | Bake the explicit personal/infra split from requirements | ✓ |
| Heuristic (auto-detect from catalog metadata) | Infer from `requires_oauth`, `category`, etc. | |
| Configurable via env-var | Let users override at install time | |

**Auto-pick rationale:** SCOPE-02 enumerates the exact list. Heuristics would re-derive the same answer with extra failure modes. Per-install override is a Phase 38/39 concern (`TK_MCP_SCOPE` + TUI hotkey).

---

## Backward-Compat Fallback Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Silent fallback to `user` | No stderr emission on missing field | ✓ |
| Warn-and-fallback | Emit deprecation warning to stderr | |
| Fail loudly | Refuse to load pre-v5.0 catalogs | |

**Auto-pick rationale:** SCOPE-03 explicitly forbids stderr emission ("silently treating that entry as `user` with no warning emitted on stderr"). Pre-v5.0 user installs that re-source an old catalog must not surface noise.

---

## Test Coverage Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing validator tests + extend existing catalog test | Reuse `test-integrations-catalog.sh` and `validate-integrations-catalog.py` | ✓ |
| New dedicated test file | `test-catalog-scope-fallback.sh` standalone | (Claude discretion during planning) |
| Snapshot-based regression | Diff against committed snapshot | |

**Auto-pick rationale:** TEST-06 explicitly says "Existing `scripts/validate-integrations-catalog.py` extended (no new file)" for the validator change. Whether the backward-compat hermetic assertion extends the existing test or lands as a sibling is left to the planner — both meet the contract.

---

## Claude's Discretion

- Validator implementation detail (jsonschema-lite vs hand-rolled jq vs Python dict walk) — match existing validator style.
- Fallback implementation (`jq // "user"` vs explicit branch) — match existing `mcp_catalog_load` patterns.
- Test file location for the backward-compat assertion (extend `test-integrations-catalog.sh` vs new sibling).
- Internal helper naming.

## Deferred Ideas

- Calendly catalog entry — Phase 40 (INT-13).
- TUI per-row scope state — Phase 39.
- Wizard scope routing — Phase 38.
- Project `.env` writer — Phase 37.
- Docs + CHANGELOG + manifest bump — Phase 41.
