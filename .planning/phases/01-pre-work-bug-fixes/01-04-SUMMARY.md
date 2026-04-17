---
phase: 01-pre-work-bug-fixes
plan: "04"
subsystem: json-escape
tags: [bug-fix, json, security, shell, heredoc]
commits:
  - 78e3e5d fix(01-04): JSON-escape API keys via python3 json.dumps in setup-council.sh
  - 32fa2e7 fix(01-04): JSON-escape API keys via python3 json.dumps in init-claude.sh
---

# Plan 01-04 Summary — BUG-03

## Objective

Replace bare `"$GEMINI_KEY"` / `"$OPENAI_KEY"` heredoc interpolation in the two `config.json` writers (`scripts/setup-council.sh` Step 5 and `scripts/init-claude.sh` setup_council function) with a `python3 json.dumps()` escape pass so API keys containing `"`, `\`, `$`, or control characters produce valid JSON.

## What was done

**scripts/setup-council.sh (Step 5, config.json writer)**

Before the `cat > "$CONFIG_FILE" << CONFIGEOF` heredoc, added three escape variables:

```bash
GEMINI_MODE_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$GEMINI_MODE")
GEMINI_KEY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$GEMINI_KEY")
OPENAI_KEY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$OPENAI_KEY")
```

Heredoc now interpolates `$GEMINI_MODE_JSON` / `$GEMINI_KEY_JSON` / `$OPENAI_KEY_JSON` **without** surrounding double-quotes (python's `json.dumps` already emits the JSON string literal including quotes). Matching `# shellcheck disable=SC2016` directives guard the intentional single-quoted `json,sys` string.

**scripts/init-claude.sh (setup_council function, config.json writer)**

Mirror of the same pattern using lowercase `local`-scoped variables (`gemini_mode_json`, `gemini_key_json`, `openai_key_json`) to match the function-local style already used by `setup_council()`.

## Verification

- `shellcheck scripts/setup-council.sh scripts/init-claude.sh` → exit 0 (no new warnings)
- `bash -n` syntax check on both files → exit 0
- Python round-trip smoke test with 5 adversarial keys (plain, `"` quote, `\` backslash, `$` dollar, `\n` newline) — all parse back to the original string after `json.dumps` → `json.loads`

## Key Files

**Modified:**

- `scripts/setup-council.sh` (Step 5 config.json writer, lines ~186-210)
- `scripts/init-claude.sh` (`setup_council` config.json writer, lines ~512-533)

## Key Links

- BUG-03 requirement: D-08 (JSON escape invariant)
- Downstream consumer: `scripts/council/brain.py` reads `~/.claude/council/config.json` — now guaranteed to be valid JSON regardless of key content

## Self-Check

- [x] Both config.json writers use JSON-escaped variables
- [x] No bare `"$GEMINI_KEY"` / `"$OPENAI_KEY"` interpolation remains in either heredoc
- [x] shellcheck passes with no new warnings
- [x] Round-trip verified: escaped → written → parsed → matches original
- [x] Each fix committed atomically
