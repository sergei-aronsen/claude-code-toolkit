# Security Audit — claude-code-toolkit

**Project:** /Users/sergeiarutiunian/Projects/claude-code-toolkit
**Date:** 2026-04-30
**Scope:** All scripts under `scripts/` (shell + Python), `.github/workflows/`, MCP server, libs.
**Trust model:** End user runs `bash <(curl -sSL .../scripts/init-claude.sh)`. Upstream HTTPS (`raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main`) is the trust anchor. A repo or DNS compromise is out of scope (already fully owns the user). The audit looks for vulnerabilities that an attacker without prior compromise can exploit through normal user usage.

Prior security work (memory + git log: L2/L7/M2/M6/L4/M3/M5/M1/M10/L6/L12) is **not re-flagged**.

---

## Executive Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 1 |
| Medium   | 1 |
| Low      | 2 |
| Info     | 1 |
| FP-skipped (after self-check) | 7 |

Overall risk: **Low** for the curl|bash entry path. The codebase has been hardened over numerous prior audit waves; the bulk of remaining issues are quality-of-implementation, not directly exploitable by a remote attacker. The single High finding is a regression of an already-correct pattern that lives in the standalone setup script — it leaks API keys to terminal scrollback during one specific install path.

---

## H1 — API keys echoed to terminal scrollback during init-claude.sh Council setup

- **Severity:** High (confidentiality)
- **OWASP:** A09 (Logging Failures, related: scrollback as side-channel) / A02 (Cryptographic Failures — improper handling of secrets)
- **Files:**
  - `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/init-claude.sh:970`
  - `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/init-claude.sh:1020`
  - `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/init-claude.sh:1035`

```bash
# init-claude.sh:970
read -r -p "    Enter Gemini API key (or press Enter to skip): " gemini_key < /dev/tty 2>/dev/null || true
# init-claude.sh:1020
read -r -p "    Enter OpenAI API key (or press Enter to skip): " openai_key < /dev/tty 2>/dev/null || true
# init-claude.sh:1035
read -r -p "    Enter OpenRouter API key (or press Enter to skip): " openrouter_key < /dev/tty 2>/dev/null || true
```

**Compare with the same prompts in `scripts/setup-council.sh`:**

```bash
# setup-council.sh:155, 209, 234 — uses -rs (silent)
read -rs -p "  Enter Gemini API key (or press Enter to skip): " GEMINI_KEY < /dev/tty 2>/dev/null || true
```

`init-claude.sh` calls its own **inline** `setup_council` function (line 724–1122) which forgot the `-s` flag. As a result the secret value is **echoed to the terminal in cleartext** while typing.

### Exploit scenario (no prior compromise)

A user runs the documented onboarding command:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

The installer asks for OpenAI / Gemini / OpenRouter API keys. The secrets are visible:

1. On the user's terminal during typing (shoulder-surfing, recorded screen-share, screencap).
2. **In terminal scrollback buffer** — `iTerm2`, `Terminal.app`, `tmux`, `screen`, vscode-integrated-terminal, JetBrains, Warp, ghostty all retain scrollback by default. A later `cat ~/.iterm2_history`, screenshare, screen recording, or simple scroll-up exposes the key.
3. In `script(1)` typescript files if recording is on.
4. In CI logs if the install is captured (CI shouldn't enter this path because there's no TTY, but the read still echoes if a TTY is forwarded).

### False-positive check

- The `-s` flag is the standard, well-known mitigation; the codebase uses it correctly in `setup-council.sh` — proving the maintainer knows the pattern. The init-claude.sh copy is therefore a regression, not by-design.
- The `2>/dev/null || true` suffix swallows the read failure but does not stop echo.
- No alternative redirection (e.g. piped stdin) hides the typed bytes; bash echoes user input by default unless `stty -echo` or `read -s` is in effect.
- Confidence: ≥95% real exploitability; happens to **every** user who selects API mode in `init-claude.sh` Council setup.

### Fix

Add `-s` to all three prompts (and print a literal `\n` after each, since `-s` suppresses the trailing newline too):

```bash
read -rs -p "    Enter Gemini API key (or press Enter to skip): " gemini_key < /dev/tty 2>/dev/null || true
echo
read -rs -p "    Enter OpenAI API key (or press Enter to skip): " openai_key < /dev/tty 2>/dev/null || true
echo
read -rs -p "    Enter OpenRouter API key (or press Enter to skip): " openrouter_key < /dev/tty 2>/dev/null || true
echo
```

Optional: factor the helper out so init-claude.sh and setup-council.sh share one implementation and cannot drift again.

---

## M1 — `log_error` undefined in `install.sh` validation guard

- **Severity:** Medium (operational reliability; not directly an exploit, but it disables a security guard)
- **OWASP:** A04 (Insecure Design — defective control)
- **File:** `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/install.sh:837`

```bash
for _local_check_name in "${TK_DISPATCH_ORDER[@]}"; do
    if [[ ! "$_local_check_name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        log_error "TK_DISPATCH_ORDER contains invalid component name: ${_local_check_name@Q}"
        exit 1
    fi
done
```

The string `log_error` is not defined anywhere in `install.sh` and is not exported by any of the libs it sources (`detect2.sh`, `dispatch.sh`, `tui.sh`, `dry-run-output.sh`, `bridges.sh`, optionally `mcp.sh`/`skills.sh`). Verified via:

```bash
grep -n "log_error\b" scripts/install.sh scripts/lib/*.sh
# only hit: scripts/install.sh:837
```

Under `set -euo pipefail`, calling an undefined function would normally `exit 127`. The guarded branch never runs in practice today because `TK_DISPATCH_ORDER` is set from a hardcoded array literal (`dispatch.sh:75`) that always passes the regex. So it is a **dead defensive check**.

### Exploit scenario (no prior compromise)

A future patch (or local maintainer fork) that sources `TK_DISPATCH_ORDER` from env or from a parsed file could submit a value like `;rm -rf` and bypass the validator because the validator itself crashes before it can `exit 1`:

```bash
TK_DISPATCH_ORDER=("evil; rm -rf ~"); log_error not callable -> 127 -> set -e exits before exit 1
```

In the **current** code, `TK_DISPATCH_ORDER` cannot be poisoned by an unprivileged remote attacker, so this is not directly exploitable today — but it is a **silent disablement of a defense-in-depth guard**, and the comment "Audit M-Install" implies the guard was intentionally added in response to a prior audit.

### False-positive check

- Confirmed `log_error` undefined: `grep -rn "^log_error\|log_error()" scripts/install.sh scripts/lib/*.sh` returns 0 hits.
- Other dispatchers (uninstall, update-claude, migrate-to-complement) do define `log_error()` locally.
- Confidence ≥85% that this is a latent regression. Skipped a Critical rating because exploitation requires a *future* code change to populate `TK_DISPATCH_ORDER` from untrusted input.

### Fix

Add the missing helper at the top of `install.sh` next to the other log helpers (which `install.sh` doesn't currently define at all — it relies on the bridges/dispatch libs to define them via guards). Easiest:

```bash
# install.sh, near line 30
log_error() { echo -e "${RED}✗${NC} $1" >&2; }
```

Or replace the call with a literal `echo` so the guard works without any helper dependency:

```bash
echo -e "${RED}✗${NC} TK_DISPATCH_ORDER contains invalid component name: ${_local_check_name@Q}" >&2
exit 1
```

---

## L1 — `mcp_secrets_load` does not validate keys before exposing them

- **Severity:** Low (defense-in-depth; needs prior write to `mcp-config.env` to be exploitable)
- **OWASP:** A03 (related — input validation around a secrets loader)
- **File:** `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/lib/mcp.sh:184–199`

The loader trims leading/trailing whitespace from the key but does NOT reject keys with spaces, embedded `=`, control characters, etc. The setter (`mcp_secrets_set`) only validates the *value* via `_mcp_validate_value` — it never validates the *key*. A pre-existing line like `   FOO; rm -rf ~ =bar` would be loaded into `MCP_SECRET_KEYS[]`. Subsequent code path in `mcp_wizard_run`:

```bash
exported_env+=("${env_key}=${collected_value}")
env "${exported_env[@]}" "$claude_bin" mcp add "${install_args[@]}"
```

`env` accepts `KEY=VALUE` strings; if `env_key` came from the catalog (controlled) the line is safe. The catalog flow does not feed user-loaded keys into `env`, so today this is not directly exploitable.

### Exploit scenario

Requires the attacker to plant a malformed `~/.claude/mcp-config.env` first (e.g. via another vulnerability or a tampered install). Out-of-scope under the stated trust model.

### Fix

Add a key-shape validation in both `mcp_secrets_load` and `mcp_secrets_set`:

```bash
# Reject keys that aren't a sane env-var identifier.
[[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
```

---

## L2 — Predictable `install.sh` per-component stderr tmpfile naming

- **Severity:** Low (information disclosure on shared/multi-user host)
- **OWASP:** A09
- **File:** `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/install.sh:355, 523, 892`

```bash
stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-install-${local_name}-XXXXXX") || stderr_tmp=""
```

`mktemp` is fine — `XXXXXX` randomization plus default `0600` perms protects against symlink races. However the suffix includes the component name (e.g. `tk-install-superpowers-7sQ3aC`) which leaks **which components the user is installing** to anyone with `ls /tmp` access on a shared host (CI runner, multi-user dev box). For example, an attacker on the same host can correlate the install's per-component progress and time installer runs.

### False-positive check

- The file content is bounded to `tail -5` of stderr, which is normally just status messages — but on a failing install path could include URLs / partial config data.
- macOS uses per-user `TMPDIR` (`/var/folders/.../T/`), so this only matters on Linux multi-user hosts.

### Fix

Use generic prefix:

```bash
stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-install-XXXXXX") || stderr_tmp=""
```

(The component name was for debugging convenience and isn't used by any subsequent logic — index in `COMPONENT_NAMES` already tracks it.)

---

## I1 — Council reviewer responses inserted into atomic markdown reports without HTML / control-char sanitization

- **Severity:** Info (no privilege boundary crossed; report is local + user-readable)
- **OWASP:** N/A (no traditional XSS sink)
- **Files:**
  - `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/council/brain.py:2643–2698` (`_run_validate_plan`)
  - `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/council/brain.py:2200–2220` (`run_audit_review`)

`gemini_verdict` and `gpt_verdict` strings come from external LLM providers (Gemini API / OpenAI API / OpenRouter). They are written verbatim into `.claude/scratchpad/council-report.md` and the rewritten audit report. A hostile LLM (or a MITM that managed to swap a TLS cert — out-of-scope) could embed:

- ANSI escape sequences that hijack the user's terminal next time the report is `cat`'d.
- Markdown-injected slash commands or shell snippets that another Claude session might be told to "execute the example".

The report is rendered to `print(display_text)` (terminal echo) and persisted with `atomic_write_text` (which is safely symlink-refused — good).

### False-positive check

- The Council prompt explicitly tells the reviewer to output a `VERDICT: PROCEED/SIMPLIFY/RETHINK/SKIP` line. Anything else from the model is non-malicious noise in the common case.
- The `update-claude.sh:1005-1008` removed-file-name path **does** strip `\033` and non-printable chars before printing — so the precedent for sanitization exists. Council does not apply the same hygiene before printing/writing reviewer output.
- Exploitability requires a hostile model response; not a remote attacker against the toolkit alone. Hence Info, not Low.

### Recommended hardening

Apply the same sanitization wrapper used in update-claude.sh's prune prompt:

```python
def _strip_control(text: str) -> str:
    return "".join(c for c in text if c == "\n" or (32 <= ord(c) < 127) or ord(c) >= 128)
```

Run it on `gemini_verdict` / `gpt_verdict` (and on the `verdict_text` / `missed_text` blobs) **before** they hit `print(...)` or `atomic_write_text`. Keep raw text in `usage.jsonl` — that file is JSON-encoded so escapes are inert.

---

## False positives explicitly skipped (with reason)

| Pattern | Where | Why it is NOT a finding |
|---------|-------|---|
| `eval "$_parent_exit_trap"` | `lib/tui.sh:264` | Input is the exact byte-for-byte output of `trap -p EXIT`, which bash itself shell-quotes. Re-evaluating it is the documented round-trip pattern. |
| `eval "$TK_SP_INSTALL_CMD"` / `eval "$TK_GSD_INSTALL_CMD"` | `lib/dispatch.sh:128, 163`; `lib/bootstrap.sh:112` | Already gated by `TK_TEST=1` (production path uses hardcoded function). The prior audit (commit 4dcdcbc / C2) closed the env-injection RCE shape. |
| `bash "$TK_DISPATCH_OVERRIDE_*"` | `lib/dispatch.sh:117, 153, 189, 231, 268, 304` | Documented test seam; environment must already be attacker-controlled. Not reachable from a normal `curl|bash` flow. |
| `STATE_JSON` driving `rm -f` paths | `uninstall.sh:670` | All paths run through `is_protected_path` (anchors to `$CLAUDE_DIR/`), and bridges go through `classify_bridge_file`. Poisoning state requires write to `~/.claude/toolkit-install.json` — prior compromise. |
| `manifest.json` paths fed to `curl -o $CLAUDE_DIR/$rel` | `update-claude.sh:971`, `init-claude.sh:551` | Manifest is fetched from the toolkit's own HTTPS origin; trusting it is the trust-root assumption. A path-traversal entry (`../../etc/x`) would still be confined by the attacker who already controls the upstream. |
| `bash <(curl -sSL .../gsd-build/get-shit-done/.../install.sh)` | `lib/bootstrap.sh:92` | Third-party curl|bash, but: explicitly prompted `[y/N]`, default N, copy now flags the trust boundary, optional `TK_GSD_PIN_SHA256` for integrity verification. As good as it gets without abandoning the upstream installer entirely. |
| `os.replace` / mkstemp atomic JSON merges in `lib/install.sh`, `lib/bridges.sh`, `setup-security.sh` | various | Already use `tempfile.mkstemp(dir=...)` + `os.replace` (POSIX atomic). Symlink-refuse + 0600 perms enforced. |

---

## Vulnerability count

```
Critical: 0
High:     1
Medium:   1
Low:      2
Info:     1
FP-skipped: 7
```

---

## Recommended actions

### Immediate (this week)

1. Add `-s` to the three `read -r -p` prompts in `init-claude.sh` (H1) and unify the council-setup logic between `init-claude.sh` and `setup-council.sh` so the regression cannot recur. This is a one-character diff per line plus a follow-up `echo`.

### Short-term (next release)

2. Define `log_error` (and `log_info`/`log_warning` for symmetry) in `install.sh`, OR replace the single call site with an inline `echo` (M1). Add a unit test that exercises the dispatcher-name guard with a poisoned `TK_DISPATCH_ORDER` so the regression stays caught.
3. Sanitize Council reviewer text before writing/printing reports (I1). Apply the same `LC_ALL=C tr -d '\033\007\010' | tr -cd '[:print:]\n'` recipe used in `update-claude.sh:1005-1008`.
4. Tighten `mcp_secrets_load` key validation (L1).
5. Drop the component name from `mktemp` prefixes in `install.sh` (L2).

### Long-term

6. Adopt a single `lib/log.sh` and source it from every entry-point script so log helpers cannot silently drop again (root cause of M1).
7. Consider an automated `shellcheck`-style helper-availability check in CI: `bash -n` would surface undefined function calls only at runtime; a `make check` step that runs each install path with `-x` and grep for "command not found" would catch M1-class regressions before merge.

---

## Appendix: scope coverage

| Area | Files audited (LoC summed) |
|------|--------|
| Shell installers | `init-claude.sh` (1240), `init-local.sh` (533), `update-claude.sh` (1352), `uninstall.sh` (812), `setup-security.sh` (614), `setup-council.sh` (657), `install.sh` (1001), `install-statusline.sh` (282), `migrate-to-complement.sh` (527), `verify-install.sh` (438), `sync-skills-mirror.sh` (196) |
| Shell libs | `lib/state.sh` (262), `lib/install.sh` (298), `lib/bridges.sh` (674), `lib/bootstrap.sh` (160), `lib/dispatch.sh` (321), `lib/mcp.sh` (492), `lib/skills.sh` (152), `lib/tui.sh` (294), `lib/optional-plugins.sh` (42), `lib/backup.sh` (68) |
| Python | `council/brain.py` (3263), `council/mcp-server.py` (304), `validate-manifest.py`, `validate-commands.py` |
| CI | `.github/workflows/quality.yml` |
| Maintainer-only | `cell-parity.sh`, `validate-release.sh`, `validate-marketplace.sh`, `validate-skills-desktop.sh`, `propagate-audit-pipeline-v42.sh`, `detect.sh`, `lib/detect2.sh`, `lib/dry-run-output.sh`, `lib/cli-recommendations.sh`, `lib/council-prompts.sh` (read but not deeply analyzed — not in the curl|bash user path) |

Total: roughly 14k lines of shell + 3.5k lines of Python reviewed.
