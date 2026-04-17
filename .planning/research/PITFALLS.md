# Pitfalls Research

**Domain:** Installer refactor — multi-mode detection + conditional install + migration for a shell-based toolkit
**Researched:** 2026-04-17
**Confidence:** HIGH (all findings grounded in the actual codebase files read)

---

## Critical Pitfalls

### Pitfall 1: Detection False Negatives on Non-Standard Plugin Layouts

**What goes wrong:**
The complement-mode detector checks `[ -d ~/.claude/plugins/cache/claude-plugins-official/superpowers/ ]`
and `[ -d ~/.claude/get-shit-done/ ]`. A user who installed via a different path, symlinked the
directory, or uses a non-standard `CLAUDE_DIR` env var will fail detection silently. The script
concludes "standalone" mode and installs duplicate commands on top of an existing SP/GSD install,
producing namespace collisions that appear as confusing double definitions of `/debug`, `/audit`, etc.

**Why it happens:**
Filesystem detection is path-literal. It does not follow symlinks unless the test explicitly uses
`-L`, and it cannot discover plugin variants that differ only in capitalization on case-insensitive
macOS HFS+.

**How to avoid:**
- Use `[ -d path ] || [ -L path ]` to catch symlinks.
- Also check the canonical secondary signal: `command -v superpowers` or presence of
  `~/.claude/CLAUDE.md` markers left by the plugin installer (`grep -q "superpowers" ~/.claude/CLAUDE.md`).
- Print the detected mode before asking the user to confirm: `"Detected: standalone — is this correct? [Y/n]"`.
- Document the expected paths in a `DETECTION_PATHS` constant at the top of the script so a
  single variable change handles path drift.

**Warning signs:**
- User reports `/debug` command appearing twice or behaving differently than SP's version.
- `toolkit-install.json` records `mode: standalone` but `~/.claude/get-shit-done/` exists at runtime.

**Phase to address:** Phase 1 (Detection + install-state scaffolding).

---

### Pitfall 2: Detection False Positives from Stale Plugin Cache

**What goes wrong:**
A user ran SP once, then uninstalled it, but `~/.claude/plugins/cache/claude-plugins-official/superpowers/`
still exists (claude's plugin cache is not cleaned on uninstall in at least some plugin manager versions).
The TK detects `complement-sp` mode and skips installing TK's `/debug`, `/audit` etc. The user has no
working `/debug` because SP is not actually active.

**Why it happens:**
Directory presence is used as a proxy for "plugin is active", but the cache directory may outlive the
plugin's enabled state. The `enabledPlugins` key in `~/.claude/settings.json` is the actual source of
truth for whether SP is active.

**How to avoid:**
- Cross-reference: if the cache dir exists, also check `grep -q "superpowers" ~/.claude/settings.json`
  or check `enabledPlugins`. If the settings file does NOT list the plugin as enabled, treat the cache
  dir as stale and fall back to standalone.
- Alternatively, define detection as: cache dir present AND `settings.json` enables it AND at least
  one expected command file exists inside the cache dir.
- If the cross-reference fails, warn: `"Found SP cache dir but it does not appear active in settings.json — treating as absent."`.

**Warning signs:**
- User reports commands missing after complement-mode install despite having an SP cache directory.
- `toolkit-install.json` says `detected_sp: true` but user says SP was uninstalled months ago.

**Phase to address:** Phase 1 (Detection + install-state scaffolding).

---

### Pitfall 3: Non-Idempotent Update Due to Skipped Files Not Being Re-Evaluated

**What goes wrong:**
`toolkit-install.json` persists `skipped_files: ["commands/debug.md", ...]` from the first install.
On the second `update-claude.sh` run, the script reads the saved skip-list and skips those files again —
even if the user has since uninstalled SP. The update does not re-run detection; it trusts the stale
`install_mode` in the JSON. The user is left without `/debug` despite SP being gone.

**Why it happens:**
Caching the install mode in JSON trades accuracy for speed. Without a "re-detect" flag the cached
state silently diverges from reality.

**How to avoid:**
- Always re-run detection at update time, then compare to the saved mode.
- If the mode changed, print: `"Install mode changed: complement-sp → standalone. Re-evaluating skip-list."`.
- Offer to install previously-skipped files when the base plugin that caused skipping is gone.
- Add a `--redetect` flag for explicit re-evaluation without the interactive prompt.

**Warning signs:**
- Running update twice changes no files when it should (idempotence), but also installs no new files
  when the environment changed (incorrect idempotence).
- `toolkit-install.json` `detected_at` timestamp is months old but `install_mode` is still trusted.

**Phase to address:** Phase 2 (Update + re-detection logic).

---

### Pitfall 4: Migration Data Loss — User-Customized Files Deleted as Duplicates

**What goes wrong:**
The migration path for v3.x users offers to "remove duplicates" — TK files that now conflict with SP
(e.g., `commands/debug.md` which copies SP's "Iron Law" verbatim). The script identifies the file as
a TK-original and removes it. But the user had customized that file (added their own debugging
workflow steps). The file is removed, the customization is lost, and the backup was placed in
`.claude-backup-YYYYMMDD/` which the user may not discover.

**Why it happens:**
The duplicate-detection logic checks whether the file's content matches the shipped TK template, but
users who ran `/learn` or hand-edited the file will have diverged content. A simple content-hash check
against the repo's template version will not detect user modifications correctly (the file differs from
both template and SP's version).

**How to avoid:**
- Before any removal, diff the candidate file against the installed TK template hash stored in
  `toolkit-install.json` at install time. If the file differs from the template, it has been modified
  by the user — do NOT remove it silently.
- Print a three-way diff summary: `"TK template | Your version | SP version"`.
- Require explicit per-file confirmation: `"Remove commands/debug.md? (modified by user) [y/N]:"`.
- Never remove a file without first copying it to a timestamped backup that the user is told about on
  screen: `"Backed up to: .claude-backup-20260417-120000/commands/debug.md"`.
- Store a content hash of each installed file in `toolkit-install.json` at install time so migration
  can reliably detect user modifications.

**Warning signs:**
- User reports `/debug` is gone after running migration.
- Backup directory exists but user was not informed of its location.

**Phase to address:** Phase 3 (Migration + duplicate-removal).

---

### Pitfall 5: Partial Write Corrupts `toolkit-install.json` (Atomic Write Missing)

**What goes wrong:**
`toolkit-install.json` is written with a direct `cat > ~/.claude/toolkit-install.json << EOF` or
`json.dump(config, open(path, 'w'))`. If the script is interrupted mid-write (Ctrl-C, power loss,
OOM kill), the file is left truncated or with incomplete JSON. The next `update-claude.sh` run calls
`json.load()` on it, throws a `JSONDecodeError`, and the script exits — leaving the user unable to
update without manually deleting the state file.

**Why it happens:**
Shell heredocs and Python `open(path, 'w')` truncate the file before writing. Any interruption
between truncation and close produces a zero-byte or partial file.

**How to avoid:**
```bash
# Shell pattern — write to tmp, then atomic rename
TMP=$(mktemp "${INSTALL_JSON}.tmp.XXXXXX")
python3 -c "..." > "$TMP"
mv "$TMP" "$INSTALL_JSON"
```
```python
# Python pattern
import tempfile, os, json
tmp = tempfile.NamedTemporaryFile(
    mode='w', dir=os.path.dirname(path),
    suffix='.tmp', delete=False
)
json.dump(data, tmp, indent=2)
tmp.flush(); os.fsync(tmp.fileno()); tmp.close()
os.replace(tmp.name, path)  # atomic on POSIX
```
- Also: validate `toolkit-install.json` on every read with a try/except and fall back to re-running
  detection rather than crashing.

**Warning signs:**
- `toolkit-install.json` is 0 bytes or fails `python3 -m json.tool`.
- Update script exits immediately with a JSON parse error.

**Phase to address:** Phase 1 (install-state scaffolding) — establish the atomic-write pattern before
any other code depends on the file.

---

### Pitfall 6: `setup-security.sh` JSON Merge Clobbers Unknown `settings.json` Keys

**What goes wrong:**
The Python merge in `setup-security.sh:202-237` reads `settings.json`, adds/replaces `hooks.PreToolUse`
and `enabledPlugins`, then writes back with `json.dump(config, f, indent=2)`. This is safe for known
keys, but:

1. If Claude Code adds new top-level keys in a future release (e.g., `telemetry`, `mcpServers`,
   `experimental`) they survive the merge only if they were already present when the script read the
   file. The current implementation does preserve unknown keys because it reads the full object — this
   is actually correct. The risk is a different one: the script replaces ALL `Bash` PreToolUse entries
   (`config['hooks']['PreToolUse'] = [e for e in ... if e.get('matcher') != 'Bash']`), which will
   silently discard any Bash hooks that SP or GSD previously installed.
2. The script does this without taking a backup first (unlike `install-statusline.sh:104` which does
   `${SETTINGS_FILE}.bak`).

**How to avoid:**
- Take a timestamped backup before ANY write: `cp settings.json settings.json.bak.$(date +%s)`.
- When removing Bash PreToolUse hooks, print each one being removed and ask for confirmation if any
  hook was NOT installed by TK (i.e., not `pre-bash.sh`): `"Removing unknown Bash hook: /path/to/sp-hook.sh — continue? [y/N]"`.
- Validate the output is valid JSON before replacing the original: write to tmp, parse it back, then
  `mv`.
- Store the set of hook paths that TK installed in `toolkit-install.json` so future runs know which
  hooks are "ours".

**Warning signs:**
- SP or GSD stops functioning after running `setup-security.sh` (their hooks were removed).
- `settings.json` lacks the `pre-bash.sh` reference but other hooks are also gone.

**Phase to address:** Phase 1 or 2 — any phase that touches `setup-security.sh` must apply this pattern.

---

### Pitfall 7: BSD `head -n -1` Silently Destroys User-Customized CLAUDE.md Sections

**What goes wrong:**
This bug is already documented in CONCERNS.md and confirmed in `update-claude.sh:186-195`. On macOS
BSD `head`, `-n -1` is invalid syntax. BSD `head` with an unrecognized flag either ignores the flag
and outputs everything (making `head -n -1` a no-op) or exits non-zero. With `set -euo pipefail` the
pipeline exits and `$USER_SECTIONS_FILE.overview` is empty. `HAS_USER_CONTENT` stays `false`. The
fresh template overwrites the user's customized sections. This is silent data loss on every macOS
update run.

The complement-mode refactor will add new section-extraction logic (for detecting mode preferences
saved in CLAUDE.md), multiplying the blast radius of this bug if not fixed first.

**How to avoid:**
Replace all `head -n -1` usage with a POSIX-compatible equivalent:
```bash
# Remove last line — POSIX, works on both macOS BSD and GNU
sed '$d' file
# Or: pipe through awk
awk 'NR>1{print prev} {prev=$0}' file
```
Add a `make shellcheck` rule that specifically bans `head -n -[0-9]` in scripts (shellcheck
`SC2006` doesn't catch this; a custom grep rule in `Makefile` will).

**Warning signs:**
- On macOS: user sections are blank after update.
- CI runs on Linux and passes; Mac users report data loss.
- `$USER_SECTIONS_FILE.overview` is 0 bytes after the sed pipeline.

**Phase to address:** Phase 0 / pre-work (fix before adding any new CLAUDE.md merge logic).

---

### Pitfall 8: `curl|bash` with Stdin-Consuming Interactive Prompts

**What goes wrong:**
`setup-council.sh:93,103,134` uses bare `read -r -p "..."` without `< /dev/tty`. When the script is
piped from `curl | bash`, stdin is the curl network socket. `read` consumes a chunk of the download
stream as the "user's answer" (often empty or garbled), then continues with an incorrect value.
Because the script has `set -euo pipefail`, an unexpected empty value for `GEMINI_CHOICE` falls
through to `GEMINI_CHOICE=${GEMINI_CHOICE:-1}` — which looks safe, but only for the first prompt.
If a later `read` receives EOF (curl finished), bash may exit immediately with no diagnostic.

`init-claude.sh` already guards its prompts with `< /dev/tty 2>/dev/null` (lines 84, 430, 468, 479,
504). The complement-mode refactor will add new interactive prompts (mode selection, migration
confirmation); every new prompt must follow the same pattern.

**How to avoid:**
```bash
# Correct pattern for every interactive prompt in installer scripts:
if ! read -r -p "Configure now? [Y/n]: " ANSWER < /dev/tty 2>/dev/null; then
    ANSWER="N"   # non-interactive fallback
fi
ANSWER="${ANSWER:-Y}"
```
Add a `shellcheck` rule or grep-based `make check` that flags bare `read` (without `< /dev/tty`)
in any file under `scripts/`.

**Warning signs:**
- Running `bash <(curl ... setup-council.sh)` exits immediately with no visible error.
- Mode selection prompt is skipped and an unexpected default is used.
- Integration test that pipes `echo "1" | bash script.sh` succeeds, but real `curl|bash` fails.

**Phase to address:** Phase 0 / pre-work (fix `setup-council.sh`) and enforced on every new prompt
added in Phase 1–3.

---

### Pitfall 9: API Keys Echoed to Terminal and Injected Unescaped into JSON

**What goes wrong:**
`init-claude.sh:479,504` and `setup-council.sh:103,134` use `read -r -p` (no `-s` flag), so API keys
echo to the terminal and appear in the shell's scrollback buffer. Worse, the keys are then interpolated
directly into a JSON heredoc:

```bash
cat > "$CONFIG_FILE" << CONFIGEOF
{
  "openai": { "api_key": "$OPENAI_KEY" }
}
CONFIGEOF
```

If `OPENAI_KEY` contains a `"` or `\` character (which is valid in some key formats), the heredoc
produces invalid JSON. With `set -euo pipefail`, the file is still written but the JSON is malformed.
`python3 -m json.tool config.json` will fail, and Council will not start. The user has no clear error
message because the write succeeded from the shell's perspective.

In complement-mode the same pattern will be used to write `toolkit-install.json` key metadata — if
any value is user-supplied, the same risk applies.

**How to avoid:**
- Use `read -rs` (silent mode) for any secret input.
- Never interpolate user input into JSON via heredoc. Use Python or `jq` to write JSON:
  ```bash
  python3 -c "
  import json, sys
  data = {'openai': {'api_key': sys.argv[1]}}
  print(json.dumps(data, indent=2))
  " "$OPENAI_KEY" > "$CONFIG_FILE"
  ```
  or with `jq`:
  ```bash
  jq -n --arg key "$OPENAI_KEY" '{"openai":{"api_key":$key}}' > "$CONFIG_FILE"
  ```
- Always validate the output with `python3 -m json.tool "$CONFIG_FILE" > /dev/null`.

**Warning signs:**
- Council fails with a JSON parse error immediately after first run.
- `config.json` contains a literal `"` in the middle of a string value.
- User reports API key containing special characters causes install failure.

**Phase to address:** Phase 0 / pre-work and Phase 1 (wherever new JSON is written with user input).

---

### Pitfall 10: Backup Hygiene — Naming Collisions and Uncleaned Accumulation

**What goes wrong:**
`update-claude.sh:86` creates `.claude-backup-YYYYMMDD-HHMMSS/` in the project directory. If
`update-claude.sh` is run twice within the same second (e.g., in CI, or a script loop), the second
backup attempt hits a naming collision and `cp -r` either fails (aborting the update due to
`set -euo pipefail`) or merges into the existing directory (masking which backup is from which run).
Additionally, after running updates monthly for a year, the project accumulates 12+ `.claude-backup-*`
directories. There is no cleanup mechanism.

**How to avoid:**
```bash
# Use a unique suffix that includes PID to avoid same-second collisions:
BACKUP_DIR=".claude-backup-$(date +%Y%m%d-%H%M%S)-$$"
# Or use mktemp:
BACKUP_DIR=$(mktemp -d ".claude-backup-XXXXXX")
```
- After backup creation, tell the user explicitly: `"Backup: $BACKUP_DIR (safe to delete after verifying update)"`.
- Add a `rollback-update.md` command (already exists) that lists available backups and lets the user
  pick one to restore from.
- Add a `make clean-backups` target or a `--clean-backups` flag to update-claude.sh that removes
  backups older than N days (default: 30), with confirmation.

**Warning signs:**
- `ls -d .claude-backup-*/` shows 20+ directories.
- Update fails with `cp: cannot create directory` when re-run within the same second.

**Phase to address:** Phase 2 (update-claude.sh refactor).

---

### Pitfall 11: Manifest-Driven Skip-List Not Reflected in All Four Install Paths

**What goes wrong:**
The v4.0 design adds `requires_base` / `conflicts_with` to `manifest.json` per file. But the install
logic exists in four separate hand-maintained lists: `init-claude.sh`, `update-claude.sh`,
`init-local.sh`, and the inline FILES array. The `commands/design.md` omission from
`update-claude.sh` (CONCERNS.md) demonstrates the failure mode: one of the four lists is updated,
the others are not. In complement-mode, the skip-list is more critical — failing to skip a duplicate
command silently installs a conflicting file.

**How to avoid:**
Drive all four install paths from `manifest.json` using `jq`:
```bash
# Commands not flagged as conflicting with the detected base:
COMMANDS=$(jq -r --arg base "$DETECTED_BASE" \
    '.files.commands[] | select(.conflicts_with | map(. == $base) | any | not) | .path' \
    manifest.json)
```
Add a `make validate-consistency` target that diffs the manifest's file list against
`ls commands/ templates/base/skills/ ...` and fails CI if they diverge. This is the single fix that
prevents the entire class of drift bugs.

**Warning signs:**
- A new command is added to `commands/` but missing from `manifest.json` or vice versa.
- `make validate-consistency` does not exist (the gate is missing).
- `update-claude.sh` has a hardcoded command list that doesn't match `manifest.json`.

**Phase to address:** Phase 1 (manifest schema extension) — the declarative approach must be
established before the skip-list logic is built on top of it.

---

### Pitfall 12: Race Condition Between Concurrent Init and Update Runs

**What goes wrong:**
A user runs `bash <(curl ... init-claude.sh)` in one terminal window and simultaneously runs
`bash <(curl ... update-claude.sh)` in another (realistic if the init script prints the update
command and the user runs it immediately). Both scripts read `toolkit-install.json`, then both write
it. The second writer's `json.dump` silently overwrites the first's. `update-claude.sh` also creates
a backup of `.claude/` at the start — if it reads the directory mid-init, the backup may contain a
partial install.

**Why it happens:**
No file locking is used on `toolkit-install.json` or `.claude/`.

**How to avoid:**
Use a lock file pattern:
```bash
LOCK_FILE="${CLAUDE_DIR}/.toolkit.lock"
# Acquire lock (atomic mkdir is POSIX-reliable)
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
    echo "Another toolkit operation is running. Exit it first."
    exit 1
fi
trap 'rmdir "$LOCK_FILE" 2>/dev/null' EXIT INT TERM
```
Document in the README that concurrent installs are not supported.

**Warning signs:**
- `toolkit-install.json` contains a mix of init and update state that is internally inconsistent.
- Files expected by the init run are absent because update overwrote them.

**Phase to address:** Phase 1 (install-state scaffolding) — establish the lock before any state is
written.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoded command list in `update-claude.sh` instead of `jq`-driven | No `jq` dependency | Every new file requires updating 4 places; drift causes silent omissions | Never for new code |
| `grep -q "superpowers"` as sole detection signal | Simple, 0 deps | False positive if a user mentioned superpowers in a comment; false negative after path change | Only as secondary cross-check, never primary |
| Backup via `cp -r` (not rsync or tar) | Simple | Copies symlinks incorrectly on some systems; no compression; grows unboundedly | Acceptable for MVP; add cleanup before GA |
| Storing `install_mode` without re-detecting on update | Fast | Stale state causes wrong skips when plugin state changes | Never without a staleness-check |
| Bare `read` without `< /dev/tty` | Simpler code | Silent failure or wrong default under `curl|bash` | Never in installer scripts |
| Heredoc interpolation for JSON with user values | Simpler code | JSON injection from special characters in keys/paths | Never — always use `jq` or Python |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `settings.json` hook merge | Replace all Bash PreToolUse entries blindly | Load existing entries, keep entries not owned by TK, append/replace TK's entry only |
| `settings.json` plugin merge | Add plugins without checking existing enabled state | Read `enabledPlugins`, add only absent keys, never set existing keys to `false` |
| SP detection via cache dir | Trust cache dir alone | Cross-reference with `settings.json` `enabledPlugins` key |
| `toolkit-install.json` reads | `json.load()` without error handling | Wrap in try/except, fall back to re-detection on parse failure |
| Shell alias append to `.zshrc` | Append every run (idempotence missing) | Check `grep -q "alias brain="` before appending (already done correctly in `setup-council.sh:214`) |
| `mktemp -d -t prefix` | GNU form `-t` is position-sensitive on BSD | BSD form: `mktemp -d /tmp/prefix.XXXXXX`; POSIX form: `mktemp -d` without `-t` |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| 60+ sequential `curl` calls per update | Install takes 30–120s on normal connections | Single `tar.gz` archive download + local extract | Always — each `curl` is ~100ms RTT minimum |
| Re-downloading unchanged files every update | Wasted bandwidth, slower updates | Compare remote manifest hash against `toolkit-install.json` `installed_hash` per file | Immediately — no threshold |
| `sudo apt-get` in `setup-council.sh` with `2>/dev/null` | Hidden failures, surprise privilege escalation | Remove sudo; print manual install command | Any non-Debian system or no-sudo environment |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| `read -r -p` (no `-s`) for API keys | Key echoes to terminal, ends up in scrollback and shell history | `read -rs -p` for all secret input |
| Heredoc interpolation of API keys into JSON | Special chars (`"`, `\`) produce invalid JSON or JSON injection | Use `jq --arg` or Python `json.dumps()` for all JSON construction with user values |
| No backup before `settings.json` mutation | Unrecoverable corruption if Python parser fails mid-write | Timestamped `cp settings.json settings.json.bak.$(date +%s)` before every write |
| `sudo apt-get ... 2>/dev/null` in setup script | Silent privilege escalation, hidden failure | Never `2>/dev/null` a sudo call; never auto-sudo without explicit user consent |
| `cat > config.json` (non-atomic write) | Interrupted write produces corrupt state file | Write to temp file, validate JSON, `mv` (atomic rename) |
| Hook heredoc in `setup-security.sh` without checksum | Malicious PR produces persistent hook executed before every Bash call | Distribute hook as a versioned file with SHA256; verify before install |

---

## "Looks Done But Isn't" Checklist

- [ ] **Mode detection:** Tested with SP cache dir present but `enabledPlugins` absent — verify stale-cache handling.
- [ ] **Idempotence:** Running `update-claude.sh` twice produces identical state — verify no double-entries in settings.json hooks array.
- [ ] **Migration backup:** User is told the backup path on screen AND the backup contains the modified file — verify diff against template.
- [ ] **Atomic writes:** `toolkit-install.json` survives a `kill -9` mid-write — verify no truncated JSON.
- [ ] **BSD compatibility:** All `head`, `sed -i`, `mktemp`, `readarray` usage passes on macOS `/bin/bash` (3.2) and macOS `sed` — verify with `shellcheck` + manual test on macOS.
- [ ] **curl|bash prompts:** Every `read` in every script uses `< /dev/tty` — verify with `grep -r "read -r" scripts/` that none are bare.
- [ ] **JSON safety:** No user-supplied value is interpolated bare into a JSON heredoc — verify with `grep -n '"\$' scripts/`.
- [ ] **Manifest consistency:** `jq -r '.files.commands[].path' manifest.json | sort` matches `ls commands/*.md | sort` — verify CI gate exists.
- [ ] **Skip-list coverage:** The skip-list from `manifest.json` is applied in ALL four install paths, not just `init-claude.sh` — verify by tracing `update-claude.sh` code path.
- [ ] **Lock file cleanup:** Lock file is removed on EXIT, INT, and TERM signals — verify trap covers all three.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Corrupted `toolkit-install.json` | LOW | Delete file; next update re-detects from scratch |
| User CLAUDE.md sections overwritten | MEDIUM | Restore from `.claude-backup-*/CLAUDE.md`; if no backup, restore from git history |
| `settings.json` clobbered by bad merge | MEDIUM | Restore from `settings.json.bak.*`; if absent, recreate from Claude Code defaults |
| SP hooks removed by TK security setup | MEDIUM | Re-run SP's own setup script to restore its hooks; long-term: TK must not blindly drop Bash hooks |
| Duplicate commands installed (both TK + SP version) | LOW | Manually delete the TK version; re-run update with correct mode flag |
| API key special char breaks config.json | LOW | Manually edit `~/.claude/council/config.json` to escape the value; or re-run setup |
| Lock file left behind after crash | LOW | `rmdir ~/.claude/.toolkit.lock` manually |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Detection false negatives (symlinks, alternate paths) | Phase 1: Detection scaffolding | Test with symlinked plugin dir; test with `enabledPlugins` absent |
| Detection false positives (stale cache) | Phase 1: Detection scaffolding | Test with cache dir present + plugin disabled in settings.json |
| Stale `install_mode` on update | Phase 2: Update + re-detection | Run update after uninstalling SP; verify mode changed |
| Migration data loss (user modifications) | Phase 3: Migration + duplicate removal | Install TK, modify debug.md, run migration, verify file preserved or backed up |
| Partial write corrupts state file | Phase 1: install-state scaffolding | `kill -9` mid-write; verify next run recovers |
| JSON merge clobbers SP hooks | Phase 1 or 2: setup-security.sh refactor | Install SP, run setup-security.sh, verify SP hooks still present |
| BSD `head -n -1` destroys CLAUDE.md | Phase 0: Pre-work bug fixes | Run update on macOS; verify user sections present in output |
| `curl|bash` interactive prompt failure | Phase 0: Pre-work + Phase 1–3 enforcement | Run every script via `bash <(curl ...)` in non-interactive env |
| API key echoed / JSON injection | Phase 0: Pre-work security fixes | Enter key with `"` in it; verify config.json is valid |
| Backup naming collision | Phase 2: Update refactor | Run update twice in the same second in a loop; verify no crash |
| Manifest drift across 4 install paths | Phase 1: manifest schema extension | Add a dummy command to manifest only; verify CI fails |
| Concurrent init + update race | Phase 1: install-state scaffolding | Run both scripts simultaneously; verify no torn state |

---

## Sources

- Codebase audit: `/Users/sergeiarutiunian/Projects/claude-code-toolkit/.planning/codebase/CONCERNS.md` (2026-04-17)
- Codebase read: `scripts/init-claude.sh`, `scripts/update-claude.sh`, `scripts/setup-security.sh`, `scripts/setup-council.sh`
- Project requirements: `.planning/PROJECT.md` — complement-mode v4.0 spec
- POSIX shell portability: known `head -n -1` BSD incompatibility, `sed -i` requires extension argument on macOS, `mktemp -t` positional difference
- JSON atomic write pattern: standard POSIX `rename(2)` guarantees; Python `os.replace()` docs
- curl|bash stdin consumption: documented behavior in bash when stdin is a pipe vs. terminal

---

*Pitfalls research for: installer refactor — complement-mode detection + conditional install + migration*
*Researched: 2026-04-17*
