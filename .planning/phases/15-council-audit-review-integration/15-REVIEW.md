---
phase: 15-council-audit-review-integration
reviewed: 2026-04-25T00:00:00Z
depth: deep
files_reviewed: 10
files_reviewed_list:
  - scripts/council/prompts/audit-review.md
  - scripts/council/brain.py
  - commands/audit.md
  - commands/council.md
  - scripts/tests/test-council-audit-review.sh
  - scripts/tests/fixtures/council/audit-report.md
  - scripts/tests/fixtures/council/stub-gemini.sh
  - scripts/tests/fixtures/council/stub-chatgpt.sh
  - scripts/tests/fixtures/council/stub-malformed.sh
  - Makefile
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-04-25
**Depth:** deep (cross-file, contract tracing)
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 15 delivers Council audit-review integration across 10 files. The core
contracts (em-dash byte-exact slot, `<verdict-table>` markers, `council_pass:`
frontmatter mutation, atomic write, parallel dispatch, disagreement resolution)
are correctly implemented and cross-file consistent. All static contracts in the
prompt file (`audit-review.md`) are verifiably present. The fixture stubs pass
shellcheck and produce deterministic output. The regression test covers D-15
assertions (a)–(g) with the appropriate test groups.

Two real bugs were found (Warning severity), both in `brain.py`:

1. `AUDIT_REVIEW_GEMINI_SYSTEM` and `AUDIT_REVIEW_GPT_SYSTEM` are defined but
   never passed to `ask_gemini`/`ask_chatgpt` — ChatGPT gets the Pragmatist
   system role instead of the Audit Reviewer role in audit-review mode.

2. The pre-set availability bypass (lines 763–766) is dead code — the pre-set
   `gemini_raw`/`chatgpt_raw` values are unconditionally overwritten by
   `future_g.result()` / `future_c.result()` inside the same executor block.

No security vulnerabilities were found. Path traversal protection is correct.
Shell injection is not possible (no `shell=True` in any subprocess call). The
`COUNCIL_STUB_*` env-var hook accepts arbitrary executable paths but is a
documented test-only design decision with no shell expansion risk.

---

## Warnings

### WR-01: Dead system-prompt constants — ChatGPT gets wrong persona in audit-review mode

**File:** `scripts/council/brain.py:67–83` and `scripts/council/brain.py:634–648`

**Issue:** `AUDIT_REVIEW_GEMINI_SYSTEM` (line 67) and `AUDIT_REVIEW_GPT_SYSTEM` (line 76)
are defined but referenced nowhere. When `dispatch_audit_review_chatgpt` calls
`ask_chatgpt(prompt, config)`, that function hardcodes `GPT_SYSTEM` (The Pragmatist —
"evaluate production readiness, maintenance cost, prior art") as the system role in
the OpenAI messages array (line 645). The audit-review-specific system prompt is silently
ignored.

The prompt template in the user message partially compensates (it establishes the
reviewer role in its `## Your Role` section), but the OpenAI system role still
primes the model toward Pragmatist framing. Gemini CLI mode is unaffected (the
Gemini CLI does not expose a system-role channel; the full prompt is the user message).
Gemini API mode also has no system role in its payload, so `AUDIT_REVIEW_GEMINI_SYSTEM`
is purely dead code.

**Fix:** Add an optional `system_prompt` parameter to `ask_chatgpt()`, defaulting to
`GPT_SYSTEM` for backward compatibility:

```python
def ask_chatgpt(prompt, config, system_prompt=None):
    ...
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt or GPT_SYSTEM},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.2
    }
```

Then in `dispatch_audit_review_chatgpt`:

```python
def dispatch_audit_review_chatgpt(prompt, config):
    stub = os.getenv("COUNCIL_STUB_CHATGPT")
    if stub:
        return run_command([stub], timeout=30)
    return ask_chatgpt(prompt, config, system_prompt=AUDIT_REVIEW_GPT_SYSTEM)
```

This also fixes the dead constant. `AUDIT_REVIEW_GEMINI_SYSTEM` should either be
removed (Gemini CLI has no system channel) or noted as reserved for future Gemini
API system-role support.

---

### WR-02: Pre-set availability bypass is dead code (lines 763–766)

**File:** `scripts/council/brain.py:759–784`

**Issue:** Lines 763–766 pre-set `gemini_raw`/`chatgpt_raw` to error strings when the
respective backends are configured as unavailable AND no stub is active:

```python
gemini_raw = None
chatgpt_raw = None

# Bypass backend availability checks when stubs are configured (Pitfall 6).
if not stub_gemini and not config.get("_gemini_available", True):
    gemini_raw = "Error: Gemini backend not available"   # line 764
if not stub_chatgpt and not config.get("_openai_available", True):
    chatgpt_raw = "Error: OpenAI backend not available"  # line 766
```

However, the `ThreadPoolExecutor` block immediately below (lines 770–784) unconditionally
submits both futures and then unconditionally overwrites both variables:

```python
with ThreadPoolExecutor(max_workers=2) as executor:
    future_g = executor.submit(dispatch_audit_review_gemini, prompt, config)
    future_c = executor.submit(dispatch_audit_review_chatgpt, prompt, config)
    try:
        gemini_raw = future_g.result(timeout=90)   # overwrites line 764's value
    ...
    try:
        chatgpt_raw = future_c.result(timeout=90)  # overwrites line 766's value
```

The pre-set values are always clobbered. The behavior is still correct at runtime
because `dispatch_audit_review_gemini` internally calls `ask_gemini`, which will
return an error string when Gemini is unavailable (missing CLI / no API key). But
the comment on lines 762–763 ("Bypass backend availability checks…") documents an
intent that the code does not fulfil.

**Fix:** Remove lines 759–766 (the pre-set block) and instead add an early-return
guard if both backends are unavailable and no stubs are configured:

```python
stub_gemini = os.getenv("COUNCIL_STUB_GEMINI")
stub_chatgpt = os.getenv("COUNCIL_STUB_CHATGPT")

# Fail fast if no backends are reachable and no stubs override them.
if (not stub_gemini and not config.get("_gemini_available", True) and
        not stub_chatgpt and not config.get("_openai_available", True)):
    print("\n❌ No Council backends available and no stubs configured.", file=sys.stderr)
    rewrite_report(report_path, "failed",
                   "_Council parse error: no backends available._", None)
    return 1

with ThreadPoolExecutor(max_workers=2) as executor:
    ...
```

---

## Info

### IN-01: Test Groups 6 and 9 silently require ~/.claude/council/config.json

**File:** `scripts/tests/test-council-audit-review.sh:333–340, 448–454`

**Issue:** The E2E tests (Groups 6 and 9) invoke `python3 brain.py --mode audit-review
--report ...`, which calls `load_config()` before any stub dispatch. If
`~/.claude/council/config.json` is absent (e.g. a contributor who cloned the repo
without setting up Council), `load_config()` calls `sys.exit(1)` with a "Config not
found" message. The test then records the run as failed with a misleading stderr message
that suggests a brain.py error, not a missing prerequisite.

The `make test` target does not guard Test 19 with a config-existence check, so all
10+ test groups pass but 4 E2E tests silently fail for new contributors.

Note: CI does not run `make test` (only shellcheck, markdownlint, validate-templates,
init-script, and bats). So this does not break CI. It does break the local developer
experience for contributors without Council set up.

**Fix:** Add a prerequisite check at the top of the test script, after the fixture
directory check:

```bash
if [ ! -f "$HOME/.claude/council/config.json" ]; then
    printf 'SKIP: ~/.claude/council/config.json not found — ' >&2
    printf 'Test 19 E2E groups require Council setup.\n' >&2
    printf 'Static contract checks (Groups 1-5) will still run.\n' >&2
    COUNCIL_AVAILABLE=false
else
    COUNCIL_AVAILABLE=true
fi
```

Then gate Test Groups 6, 7, 8, 9 behind `if [[ "$COUNCIL_AVAILABLE" == true ]]; then`.

---

### IN-02: resolve_council_status maps agreed NEEDS_MORE_CONTEXT to status=failed (ambiguous)

**File:** `scripts/council/brain.py:208–296`

**Issue:** `resolve_council_status` sets `has_non_real = True` for any agreed verdict
that is not `REAL` (line 268: `if verdict != "REAL": has_non_real = True`). This means
both agreed `FALSE_POSITIVE` and agreed `NEEDS_MORE_CONTEXT` map to `status = "failed"`.

D-04 specifies: `failed` when "≥1 FALSE_POSITIVE with auditor agreement". It does not
address agreed `NEEDS_MORE_CONTEXT`. The "failed" label implies confirmed false positives
requiring `/audit-skip` nudges — semantically incorrect for `NEEDS_MORE_CONTEXT`, which
means "insufficient code context" rather than "confirmed FP". No test exercises this case.

This is a corner case (both backends independently reaching `NEEDS_MORE_CONTEXT` is
unlikely) and D-04 is simply underspecified. But a future consumer reading `council_pass:
failed` will not be able to distinguish "confirmed FP" from "needs more context".

**Fix:** Add a third status variable `has_nmc` or extend the status logic:

```python
has_non_real = False
has_nmc = False

# in the agree branch:
if verdict == "FALSE_POSITIVE":
    has_non_real = True
elif verdict == "NEEDS_MORE_CONTEXT":
    has_nmc = True
```

And in the status resolution:

```python
if has_disputed:
    status = "disputed"
elif has_non_real:
    status = "failed"
elif has_nmc:
    status = "needs_more_context"
elif rows:
    status = "passed"
```

This requires `council_pass:` to accept a fourth value `needs_more_context` — a minor
schema change, out of scope for this review's fix mandate but worth tracking.

---

_Reviewed: 2026-04-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
