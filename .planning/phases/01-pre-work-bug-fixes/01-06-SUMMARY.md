---
phase: 01-pre-work-bug-fixes
plan: "06"
subsystem: no-sudo-advisory
tags: [bug-fix, security, privilege-escalation, apt-get, shell]
commits:
  - f3e427d fix(01-06): replace sudo apt-get with advisory flow in setup-council.sh
---

# Plan 01-06 Summary — BUG-04

## Objective

Remove the silent `sudo apt-get update -qq && sudo apt-get install -y -qq tree 2>/dev/null` in `scripts/setup-council.sh:73`. Replace with an advisory-only flow per D-09/D-10/D-11: the script prints the install command as a string, prompts `[y/N]` to acknowledge, emits a non-fatal warning on both paths, and continues execution. The script itself NEVER invokes `sudo`.

## What was done

**scripts/setup-council.sh (elif apt-get branch, post-edit lines 72-84)**

Before:

```bash
elif command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq tree 2>/dev/null
    echo -e "  ${GREEN}✓${NC} tree installed via apt"
else
```

After:

```bash
elif command -v apt-get &>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} tree not installed. To install manually, run:"
    echo -e "      ${YELLOW}Run: sudo apt-get install tree${NC}"
    INSTALL_TREE=""
    if ! read -r -p "  Proceed? [y/N]: " INSTALL_TREE < /dev/tty 2>/dev/null; then
        INSTALL_TREE="N"
    fi
    if [[ "${INSTALL_TREE:-N}" =~ ^[Yy]$ ]]; then
        echo -e "  ${YELLOW}⚠${NC} tree not found — brain.py structure analysis will be skipped"
        echo -e "  Run the command above in a separate terminal, then re-run setup-council.sh if you want tree support."
    else
        echo -e "  ${YELLOW}⚠${NC} tree not found — brain.py structure analysis will be skipped"
    fi
else
```

Key properties (D-09/D-10/D-11 verbatim):

- **D-09:** no `sudo` invocation from the script. The only occurrence of `sudo apt-get install tree` is the printed advisory string.
- **D-10:** no `2>/dev/null` on any apt-get line (moot — no apt-get invocation).
- **D-11:** non-fatal warning emitted on BOTH Y and N paths; execution continues. `tree` is optional.
- `read` uses the BUG-02 pattern from plan 01-02: `< /dev/tty 2>/dev/null` with `if ! read ...; then INSTALL_TREE="N"; fi` non-interactive fallback.

## Verification

| Acceptance | Expected | Actual |
|------------|----------|--------|
| `grep -cE "sudo apt-get (update\|install)" scripts/setup-council.sh` | 1 | 1 |
| `grep -cE "^[[:space:]]*sudo apt-get" scripts/setup-council.sh` | 0 | 0 |
| `grep -cE "apt-get.*2>/dev/null" scripts/setup-council.sh` | 0 | 0 |
| `grep -c "Run: sudo apt-get install tree" scripts/setup-council.sh` | 1 | 1 |
| `grep -c "Proceed?" scripts/setup-council.sh` | 1 | 1 |
| `grep -c "INSTALL_TREE" scripts/setup-council.sh` | ≥ 3 | 4 |
| warning present on both Y and N paths | ≥ 2 | 2 |
| `shellcheck scripts/setup-council.sh` | exit 0 | exit 0 |
| `bash -n scripts/setup-council.sh` | exit 0 | exit 0 |

## Key Files

**Modified:**

- `scripts/setup-council.sh` (elif apt-get branch, lines 72-84)

## Key Links

- BUG-04 requirement: D-09 (no sudo from script), D-10 (no 2>/dev/null on installer), D-11 (tree is optional — non-fatal warning)
- Reuses D-03/D-04 `read < /dev/tty` fallback pattern from plan 01-02
- Downstream: `brain.py` already handles missing `tree` gracefully (structure-analysis-disabled mode)

## Self-Check

- [x] Script never invokes sudo (T-06-01 Elevation of Privilege mitigated)
- [x] No `2>/dev/null` on apt-get (T-06-02 Information Disclosure mitigated)
- [x] Non-fatal on both Y and N paths (T-06-04 DoS mitigated)
- [x] Advisory string appears exactly once
- [x] Commit SHA: f3e427d
