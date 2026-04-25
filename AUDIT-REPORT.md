# Claude Code Toolkit — Deep Audit Report

**Date:** 2026-04-25
**Scope:** Full project deep audit — security, correctness, performance, portability, configuration integrity.
**Branch:** `claude/jolly-wing-10cbb4` (worktree of v4.1)
**Methodology:** 4 parallel Opus subagents (Security Auditor, code-reviewer, perf/correctness, JSON/manifest), each instructed to apply the project's Audit Self-Check Protocol from `CLAUDE.md` (concrete-attack-only, false-positive filter, conservative severity).

> Note: this is a documentation/templates repo, not a database-backed app. "Database" audit reframed as **JSON state-file integrity** (toolkit-install.json, manifest.json, settings.json) since those play the same role for this project.

---

## Executive Summary

| Severity | Count | Top areas |
|----------|-------|-----------|
| **CRITICAL** | 2 | `update-claude.sh` smart-merge (silent data loss); `manifest.json` version drift v4.0.0 vs git tag v4.1.0 |
| **HIGH** | 14 | OAuth/API tokens in argv; sequential review (not parallel); broken path validation in brain.py; lock-file race; mode-switch path mishandling; HTTP error bodies written to disk; hooks reference undefined `$FILE_PATH`; perf bottlenecks (jq O(N²), Python sha256 forks) |
| **MEDIUM** | 20 | Predictable `/tmp` artifacts; cp -R symlink traversal; setup-security regex anchoring; setup-security plugin presence false positives; settings.json schema redirect; broad permissions defaults; verdict extraction false positives; missing CLI pre-flight |
| **LOW** | 17 | Diagnostic obscurity; UX hygiene; LC_ALL portability; doc inconsistencies |

**Bottom-line operational risk:** Two issues can corrupt user data on a routine `update-claude.sh` run (CRIT-01, C-06 chain). One can leak Anthropic OAuth tokens to local processes (Sec-H1). Most others are hardening.

**Recommended fix order:**
1. CRIT-01 (CLAUDE.md merge), CRIT-02 (manifest version), Sec-H1 (token argv)
2. HIGH-01..04 (brain.py), C-02..C-06 (update flow correctness), S-01 (hooks)
3. PERF-01, PERF-02 (jq + sha256)
4. MEDIUM/LOW as time permits

---

## CRITICAL

### CRIT-01 — `update-claude.sh` smart-merge silently corrupts CLAUDE.md

**File:** `scripts/update-claude.sh:847-919`

**Code:**

```bash
sed -n '/^## 🎯 Project Overview/,/^## [^P]/p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.overview" 2>/dev/null || true
sed -n '/^## 📁 Project Structure/,/^## /p'    "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.structure" 2>/dev/null || true
# ...
HAS_USER_CONTENT=false
for section in overview structure commands notes; do
    if [[ -s "$USER_SECTIONS_FILE.$section" ]]; then
        if ! grep -q '\[Project Name\]\|\[Framework\]\|\[command\]\|\[List project' "$USER_SECTIONS_FILE.$section" 2>/dev/null; then
            HAS_USER_CONTENT=true
            break
        fi
    fi
done

if [[ "$HAS_USER_CONTENT" == "true" ]]; then
    cp "$CLAUDE_MD_NEW" "$CLAUDE_MD"   # ← user file already overwritten
    # then attempts re-inject by line numbers
    START_LINE=$(grep -n "^$PATTERN" "$CLAUDE_MD" | head -1 | cut -d: -f1)
    END_LINE=$(tail -n +$((START_LINE + 1)) "$CLAUDE_MD" | grep -n "^## " | head -1 | cut -d: -f1)
```

**Failure modes:**

1. Patterns hard-code emojis (`🎯`, `📁`, `⚡`, `⚠️`). Any heading rename or VS16 normalization → empty extraction → `HAS_USER_CONTENT=false` → user CLAUDE.md silently overwritten by template.
2. Terminator `/^## [^P]/` skips any heading starting with `P` (Performance, PHP Notes…), so the captured "Project Overview" balloons.
3. `sed '$d'` strips the final line — when a section is the LAST one in the file, it deletes a real user line.
4. `is_update_noop` (line 304) does not include CLAUDE.md template hash → on every update, this destructive path may run even when nothing changed (chains with C-03).
5. No dedicated backup of CLAUDE.md before mutation; only the whole-tree `cp -R` at line 671 covers it (see Sec-M-3 — that backup follows symlinks).

**Severity:** **CRITICAL** — silent loss of user-authored project documentation, the artifact the entire toolkit exists to manage.

**Fix:**
- Replace emoji-based sed extraction with explicit HTML-comment markers (`<!-- TK-USER:overview -->...<!-- /TK-USER:overview -->`) embedded in the template.
- Always create `${CLAUDE_MD}.bak.<ts>` immediately before mutation.
- Abort merge if `$CLAUDE_MD_NEW` is empty (covers C-06 chain).
- Provide a `--no-merge` flag that drops the new template alongside as `CLAUDE.md.new`, leaving the existing file untouched (chezmoi convention).

Or simpler: drop the merge entirely. Write new template as `CLAUDE.md.new`; user diffs and merges by hand.

---

### CRIT-02 — `manifest.json` version drift (4.0.0 vs git tag v4.1.0, missing CHANGELOG entry)

**File:** `manifest.json:3-4`, `CHANGELOG.md`, git tags

**Evidence:**

```json
{
  "version": "4.0.0",
  "updated": "2026-04-19",
```

- Latest git tag: `v4.1.0`, created 2026-04-25.
- `CHANGELOG.md` head entry: `[4.0.0] - 2026-04-21`.
- Memory record: "v4.1 Polish & Upstream complete 2026-04-25".

Three sources of truth disagree.

**Failure mode:** `update-claude.sh` reads version from `manifest.json` (`Makefile:42-63` per CLAUDE.md). Users on 4.1.0 see "still on 4.0.0" prompts, may trigger spurious "downgrade" warnings, and the no-op gate (`is_update_noop`) compares manifest hash → still works, but the user-facing version reporting is wrong everywhere.

**Severity:** **CRITICAL** — release-management correctness; affects every user running update.

**Fix:**

```diff
- "version": "4.0.0",
- "updated": "2026-04-19",
+ "version": "4.1.0",
+ "updated": "2026-04-25",
```

Plus add `[4.1.0] - 2026-04-25` section to `CHANGELOG.md` summarizing the polish/upstream phases.

---

## HIGH

### Sec-H1 — Anthropic OAuth bearer token leaked to `ps` argv

**File:** `templates/global/rate-limit-probe.sh:45-53`, also `scripts/install-statusline.sh:50,64`

**Code:**

```bash
TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
RESPONSE=$(curl -s -D - -o /dev/null \
    --max-time 15 \
    "https://api.anthropic.com/v1/messages" \
    -H "Authorization: Bearer $TOKEN" \
    ...)
```

**Failure mode:** macOS does NOT restrict `ps -ef -www` per-user. Any local user (or sandboxed app) polling `ps` while statusline runs (every ~60s while Claude Code is open) captures the bearer token. Token has full Claude Max/Pro privileges; attacker can charge the user's quota and read response bodies.

**Severity:** HIGH on multi-user Mac (corp fleet, shared dev box). Lower on personal laptop.

**Fix:** Pass headers via `curl -H @-` from heredoc, or write headers to `mktemp` file with `chmod 600` + `trap rm -f`:

```bash
auth_file=$(mktemp); chmod 600 "$auth_file"
trap 'rm -f "$auth_file"' EXIT
cat > "$auth_file" <<EOF
Authorization: Bearer $TOKEN
Content-Type: application/json
anthropic-version: 2023-06-01
EOF
RESPONSE=$(curl -s -D - -o /dev/null --max-time 15 \
    "https://api.anthropic.com/v1/messages" \
    -H @"$auth_file" \
    -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"h"}]}' \
    2>/dev/null)
```

---

### BRAIN-H1 — Reviewers run sequentially, not in parallel (contradicts docstring)

**File:** `scripts/council/brain.py:404-495`

**Code:**

```python
files_to_read   = ask_gemini(context_prompt, config)        # blocks
gemini_verdict  = ask_gemini(skeptic_prompt, config, ...)   # blocks
gpt_verdict     = ask_chatgpt(pragmatist_prompt, config)    # blocks
```

**Failure mode:** Worst-case wall clock 3×120s = 6 min. Docstring + README claim parallel execution; behavior contradicts docs.

**Fix:** Either correct the docstring (KISS) OR run phase-1 (Gemini context) and phase-3 (ChatGPT) concurrently via `concurrent.futures.ThreadPoolExecutor`. Skeptic→Pragmatist dependency means full parallelization isn't free; doc-fix is cheap.

---

### BRAIN-H2 — Path validation rejects valid bare filenames

**File:** `scripts/council/brain.py:172-185`

**Code:**

```python
def validate_file_path(file_path):
    file_path = file_path.strip().strip("'\"`)>")
    if not file_path or "/" not in file_path:
        return None
    resolved = Path(file_path).resolve()
    if not str(resolved).startswith(str(cwd) + os.sep):
        return None
```

**Failure modes:**
1. Bare filenames (`Makefile`, `manifest.json`) fail `"/" not in file_path` → never read.
2. CWD itself fails `startswith(cwd + os.sep)` → silently skipped.
3. String-prefix check is brittle vs `Path.is_relative_to()`.

**Fix:**

```python
def validate_file_path(file_path):
    file_path = file_path.strip().strip("'\"`)>")
    if not file_path:
        return None
    try:
        resolved = (Path.cwd() / file_path).resolve()
        resolved.relative_to(Path.cwd().resolve())
    except (ValueError, OSError):
        return None
    return resolved if resolved.is_file() else None
```

---

### BRAIN-H3 — Temp file with full prompt leaks under SIGKILL

**File:** `scripts/council/brain.py:282-306, 340-364`

**Code:**

```python
tmp = tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".json", prefix="council_")
json.dump(payload, tmp, ensure_ascii=False)
tmp.close()
result = run_command([..., "-d", f"@{tmp.name}", ...], timeout=120)
finally:
    if tmp and os.path.exists(tmp.name):
        os.unlink(tmp.name)
```

**Failure mode:** Temp file holds full prompt (200K+ chars including project source + CLAUDE.md). On `kill -9`, `finally` doesn't run → `/tmp/council_*.json` accumulates with project source code on shared servers.

**Fix:** Pass JSON via stdin:

```python
result = run_command([
    "curl", "-s", url,
    "-H", "Content-Type: application/json",
    "--data-binary", "@-",
], input_text=json.dumps(payload), timeout=120)
```

---

### BRAIN-H4 — OpenAI/Gemini API keys visible in `ps` argv

**File:** `scripts/council/brain.py:271, 348-355`

**Code:**

```python
# Gemini: key in URL query param
url = f"https://generativelanguage.googleapis.com/.../{model}:generateContent?key={api_key}"
result = run_command(["curl", "-s", url, ...])

# OpenAI: key in -H argument
result = run_command(["curl", "-s", URL, "-H", f"Authorization: Bearer {api_key}", ...])
```

**Failure mode:** Both visible to `ps auxe` for the duration of curl call (~5–120s). Real risk on multi-user systems and CI runners.

**Fix:** Write headers to `chmod 600` tempfile, pass via `-H @file`. Gemini's URL-key trade-off is documented in code comment (line 269) — accepted as Google API design.

---

### PERF-01 — O(N²) jq invocations in update-claude.sh diff loops

**File:** `scripts/update-claude.sh:280-298, 712-719`

**Code:**

```bash
compute_modified_actual() {
    local out="[]"
    while IFS= read -r rel; do
        stored=$(jq -r --arg p "$rel" '.installed_files[]|select(.path==$p)|.sha256' <<<"$STATE_JSON")
        ...
        if [[ "$actual" != "$stored" ]]; then
            out=$(jq --arg p "$rel" '. + [$p]' <<<"$out")   # rewrites array per match
        fi
    done < <(jq -r '.[]' <<<"$MODIFIED_CANDIDATES")
}
```

**Failure mode:** ~80 manifest files × 2 jq forks per candidate × ~30-50 ms cold-start = **5-8 s wallclock** in process spawn alone. The append pattern is true O(N²).

**Fix:** Pre-compute path→sha map ONCE into bash assoc array; collect modified into bash array; emit JSON via single jq call. ~50× speedup.

---

### PERF-02 — `sha256_file` forks Python per file (~100 ms each)

**File:** `scripts/lib/state.sh:32-36`

**Code:**

```bash
sha256_file() {
    python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$path"
}
```

**Failure mode:** Called ~80×/run. ~5–15 s wallclock per update. Also slurps full file into memory.

**Fix:**

```bash
sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        python3 -c 'import hashlib,sys
h=hashlib.sha256()
with open(sys.argv[1],"rb") as f:
    for c in iter(lambda: f.read(65536), b""): h.update(c)
print(h.hexdigest())' "$1"
    fi
}
```

`shasum` ships with macOS by default; `sha256sum` standard on Linux. ~5–10 ms.

---

### C-02 — `acquire_lock` PID file race deletes live-process locks

**File:** `scripts/lib/state.sh:116-150`

**Code:**

```bash
acquire_lock() {
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        old_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
        if [[ -n "$old_pid" ]] && ! kill -0 "$old_pid" 2>/dev/null; then
            rm -rf "$LOCK_DIR"   # ← reclaim "stale" lock
        fi
        ...
    done
    echo $$ > "$LOCK_DIR/pid"   # ← race window: lock dir exists but PID not yet written
    return 0
}
```

**Failure mode:** TOCTOU — process A creates `$LOCK_DIR` (mkdir succeeds), then before line writing PID, process B reads empty `$LOCK_DIR/pid`, treats as "stale," and `rm -rf "$LOCK_DIR"`. Both processes now think they hold the lock → concurrent `toolkit-install.json` writes corrupt state.

**Fix:** Wait for PID file to appear before declaring stale, OR switch to `flock(1)` on a regular file (kernel auto-releases on process death — no heuristics needed).

---

### C-03 — `is_update_noop` ignores extras, missing real changes

**File:** `scripts/update-claude.sh:304-315`

**Failure mode:** `MANIFEST_HASH` covers manifest.json only. `templates/<framework>/CLAUDE.md`, `settings.json`, cheatsheets are EXTRAS — NOT in manifest. When upstream updates them, no-op fires falsely → users never get the change.

**Fix:** Either register extras in manifest, or extend hash input to include them.

---

### C-04 — `synthesize_v3_state` writes empty `manifest_hash`, breaking no-op forever

**File:** `scripts/update-claude.sh:257-269, 962-968`

**Failure mode:** First migration from v3.x writes state with no `manifest_hash`. Splice at end of run sets it. If interrupted between `write_state` and splice → permanently un-noop-able; every subsequent update runs full destructive path.

**Fix:** Make `manifest_hash` a parameter to `write_state`; remove the post-hoc splice.

---

### C-05 — Mode-switch confuses absolute vs relative paths, may delete files in CWD

**File:** `scripts/update-claude.sh:504-557, 596-599`

**Failure mode:** `execute_mode_switch` runs BEFORE the path-normalization at line 596. It assumes `installed_files[].path` is absolute. After a previous run, paths are stored relative — mode-switch reads them as "relative-but-labeled-abs," and `rm -f` runs against relative paths in CWD (project root), potentially deleting matching files outside `~/.claude/`.

**Fix:** Move the normalization at line 596 BEFORE the mode-switch block; treat paths as relative throughout; build absolute paths on demand via `$CLAUDE_DIR/$rel`.

---

### C-06 — `curl -sSL` (no `-f`) writes HTTP error bodies to disk

**File:** `scripts/init-claude.sh:380`, `scripts/update-claude.sh:837-838`

**Code:**

```bash
if curl -sSL "$full_url" -o "$full_dest" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $dest"
else
    base_src="${src/templates\/$FRAMEWORK/templates\/base}"
    curl -sSL "$REPO_URL/$base_src" -o "$full_dest" 2>/dev/null || true
fi
```

**Failure mode:** `curl -sSL` exits 0 on HTTP 404. Writes "404: Not Found" body into the destination file. Fallback never triggers. For `update-claude.sh:837`, an upstream 404 leaves an empty `$CLAUDE_MD_NEW` → CRIT-01 merge sees `[[ -f file ]]` true → wipes user CLAUDE.md.

**Fix:** Use `curl -sSLf` everywhere user-facing files are downloaded. Already used correctly for libs/manifest at `init-claude.sh:69`.

---

### S-01 — Hooks reference undefined `$FILE_PATH` env var

**File:** `templates/{base,laravel,nextjs,nodejs,python,go,rails}/settings.json`

**Code (representative):**

```json
{
  "hooks": [
    {"matcher": "Edit|Write",
     "hooks": [{"type": "command",
                "command": "[[ \"$FILE_PATH\" == *.go ]] && gofmt -w \"$FILE_PATH\" && echo '[$(date)] $FILE_PATH' >> .claude/activity.log"}]}
  ]
}
```

**Failure mode:** Claude Code passes hook payload as JSON over stdin; path lives at `tool_input.file_path`. `$FILE_PATH` env var is **not documented**. Hook silently formats empty string → activity log gains blank entries; gofmt/pyfmt/etc. never fires. Single-quoted `echo '...$FILE_PATH...'` makes it worse — even if the var were defined, it's not expanded.

**Fix:**

```json
"command": "f=$(cat /dev/stdin | jq -r '.tool_input.file_path // empty'); [ -n \"$f\" ] && [[ \"$f\" == *.go ]] && gofmt -w \"$f\" && echo \"[$(date +%H:%M:%S)] $f\" >> .claude/activity.log"
```

(Reference: `scripts/setup-security.sh:213` already uses correct STDIN+jq pattern.)

---

### T-02 — Zero test coverage for CLAUDE.md smart-merge

**File:** `scripts/tests/`

**Failure mode:** The most fragile + destructive code in the repo (CRIT-01) has zero unit tests. CI cannot catch regressions in the emoji regex or path-traversal-via-merge.

**Fix:** Add `scripts/tests/test-smart-merge.sh` with fixtures covering:
- User-typical (all sections customized)
- Heading without emoji (template drift)
- Section is the LAST in file (`sed '$d'` truncation case)
- File has 2 headings starting with `P` (regex `[^P]` failure case)
- Round-trip idempotence

---

## MEDIUM

### Sec-M1 — Predictable `/tmp` cache/lock files (symlink attack vector)

**File:** `templates/global/rate-limit-probe.sh:8-9`, `templates/global/statusline.sh:13`, `scripts/install-statusline.sh:118`

**Code:**

```bash
CACHE_FILE="${TMPDIR:-/tmp}/claude-rate-limits.json"
LOCK_DIR="${TMPDIR:-/tmp}/claude-rate-limit-probe.lock"
```

**Failure mode:** Falls through to `/tmp` if `$TMPDIR` unset (launchd, cron, sandboxed contexts). Local attacker pre-creates `/tmp/claude-rate-limits.json` → `~/victim/.zshrc`. Next probe writes attacker-controlled JSON to symlink target. Also `install-statusline.sh:118` hard-codes `/tmp/`, diverging from the macOS `$TMPDIR` location → `rm` is no-op on macOS.

**Fix:** Use per-UID name (`claude-rate-limits.$(id -u).json`) under `~/.claude/cache/`; reject symlinks before write:

```bash
[[ -L "$CACHE_FILE" ]] && rm -f "$CACHE_FILE"
```

---

### Sec-M2 — Manifest path traversal → arbitrary file write on repo compromise

**File:** `scripts/update-claude.sh:679-707, 738, 822`, `scripts/init-claude.sh:432`, `scripts/init-local.sh:267`

**Code:**

```bash
while IFS= read -r rel; do
    dest="$CLAUDE_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    curl -sSLf "$REPO_URL/$rel" -o "$dest"
done < <(jq -r '.[]' <<<"$NEW_FILES")
```

**Failure mode:** No path-traversal guard. Compromised manifest with `commands/../../../etc/cron.d/evil` writes arbitrary files outside `.claude/`. `migrate-to-complement.sh:152` already has the right guard — apply consistently.

**Severity:** MEDIUM (defense-in-depth; full repo compromise is the precondition, but the fix is one line).

**Fix:**

```bash
case "$rel" in
    /*|*"/../"*|*"/./"*|*$'\n'*) log_warning "Rejecting suspicious path: $rel"; continue ;;
esac
```

---

### Sec-M3 — `cp -R` follows symlinks, can leak secrets into backup

**File:** `scripts/update-claude.sh:671`, `scripts/migrate-to-complement.sh:287`

**Code:**

```bash
cp -R "$CLAUDE_DIR" "$BACKUP_DIR"
```

**Failure mode:** macOS BSD `cp -R` follows symlinks. A malicious VS Code extension or compromised dev dep drops `.claude/commands/sneak.md` → symlink to `~/.aws/credentials`. Update creates backup, copies credential content into `~/.claude-backup-*/commands/sneak.md`. User tarballs backups for a bug report → leak.

**Fix:**

```bash
cp -RP "$CLAUDE_DIR" "$BACKUP_DIR"   # -P: don't follow symlinks (BSD + GNU)
```

---

### BRAIN-M1 — Verdict extraction false-positives on prompt echo

**File:** `scripts/council/brain.py:67-80`

**Failure mode:** Fallback scans full text for `SKIP|RETHINK|SIMPLIFY|PROCEED` in priority order. If the model echoes the prompt (which contains "- SKIP — this doesn't need to be done"), `SKIP` matches first → wrong verdict.

**Fix:** Restrict fallback to last 500 chars (where verdict line normally lives), or require explicit `VERDICT:` and surface "UNKNOWN" otherwise.

---

### BRAIN-M2 — API errors silently coerced to "RETHINK" verdict

**File:** `scripts/council/brain.py:498-504`

**Failure mode:** Failed API call returns `"Error: command timed out"`. `extract_verdict` returns "RETHINK" fallback. User sees a phantom RETHINK from infrastructure failure, not actual model decision.

**Fix:** Detect `Error:`/`Gemini API error`/`OpenAI API error` prefixes and surface explicit failure or one-reviewer-unavailable note.

---

### BRAIN-M3 — `get_validated_paths` and `read_files` validate twice

**File:** `scripts/council/brain.py:411-412`

**Failure mode:** Double stat + double print of skip warnings; can diverge if filesystem state changes between calls.

**Fix:** Validate once, pass resolved tuples through both functions.

---

### BRAIN-M5 — Gemini CLI mode returns "RETHINK" silently when CLI missing

**File:** `scripts/council/brain.py:251-260`

**Failure mode:** Missing `gemini` binary → run_command returns `"Error: command not found"` → `extract_verdict` → "RETHINK". User sees verdict from missing tool, not setup error.

**Fix:** Pre-flight `shutil.which("gemini")` check at startup if mode is `cli`.

---

### C-09 — `setup-security.sh` regex matches `## 1.` inside `## 12.`

**File:** `scripts/setup-security.sh:104-143`

**Code:**

```bash
SECTION_NUM=$(echo "$HEADER" | grep -o '## [0-9]\+\.' || true)
if [[ -n "$SECTION_NUM" ]] && ! grep -q "$SECTION_NUM" "$CLAUDE_MD" 2>/dev/null; then
```

**Failure mode:** Unanchored — `## 1.` substring matches `## 12.`, `## 13.`, etc. After section 1 exists, sections 10-19 are reported "already present" and skipped.

**Fix:** Anchor with `grep -qE "^${SECTION_NUM} "`. Also use `-E` for `[0-9]+\.` since BSD grep doesn't reliably support `\+` in BRE.

---

### C-10 — `setup-security.sh` plugin presence check uses substring grep

**File:** `scripts/setup-security.sh:316-345`

**Failure mode:** `grep -q "$plugin"` matches inside JSON comments, inside `"_disabled_..."` keys, inside `"foreign-..."` keys. Reports "all plugins enabled" falsely. If user has explicit `false` value → re-enable doesn't run.

**Fix:** Use jq/python for proper JSON presence check.

---

### C-12 — `migrate-to-complement.sh --help` broken under `bash <(curl ...)`

**File:** `scripts/migrate-to-complement.sh:33-36`

**Code:**

```bash
sed -n '3,18p' "${BASH_SOURCE[0]}"
```

**Failure mode:** `${BASH_SOURCE[0]}` is `/dev/fd/63` under process substitution — `sed` can't reopen. Help prints empty.

**Fix:** Embed help text in heredoc.

---

### MAN-M1 — `templates/global/` template not registered in manifest

**File:** `manifest.json:148-156`

**Failure mode:** Disk ships `templates/global/` (CLAUDE.md + RTK.md + statusline scripts), referenced by setup-security.sh and install-statusline.sh, but never declared in manifest. Inconsistent SoT.

**Fix:** Add to manifest or document deliberate omission.

---

### S-02 — Hook `echo` uses single quotes — `$FILE_PATH` not expanded

**File:** `templates/*/settings.json` (multiple)

**Code:**

```json
"command": "...echo '[$(date +%H:%M:%S)] File modified: $FILE_PATH' >> .claude/activity.log"
```

**Failure mode:** Single quotes prevent `$FILE_PATH` and `$(date)` expansion. Activity log contains literal `$FILE_PATH` text and `[$(date +%H:%M:%S)]` rather than values. Cosmetic but renders the activity log useless.

**Fix:** Use double quotes (with escape inside JSON).

---

### S-03 — `$schema` URL returns 301

**File:** `templates/*/settings.json:1`

```json
"$schema": "https://json.schemastore.org/claude-code-settings.json"
```

**Failure mode:** `curl -I` returns 301. Editor schema validation follows redirect transparently but is brittle.

**Fix:** Update to canonical destination.

---

### S-04 — Default `permissions.allow` overly broad

**File:** `templates/base/settings.json:38-50` and framework variants

**Failure mode:** `Edit(*)`, `Write(*)`, `Bash(rm *)`, `Bash(mv *)`, `Bash(cp *)`, `Bash(find *)` — broad enough to cover destructive paths. User accepting defaults grants effectively unrestricted Bash.

**Fix:** Tighten or document broad defaults are intentional for solo-dev DX.

---

### M-03 (Makefile) — `shellcheck` target misses `templates/global/*.sh`

**File:** `Makefile:32-34`

```makefile
shellcheck:
	@find scripts -name '*.sh' -exec shellcheck -S warning {} +
```

**Failure mode:** `templates/global/rate-limit-probe.sh` and `statusline.sh` distribute to users but never get linted.

**Fix:**

```makefile
shellcheck:
	@find scripts templates/global -name '*.sh' -o -name '*.bash' \
	    | xargs shellcheck -S warning
```

---

### Po-06 — `python3` invocation assumes `python3` in PATH

**File:** `scripts/lib/state.sh:35,40,47`, `scripts/lib/install.sh:169,223`, `scripts/setup-security.sh:248,330`

**Failure mode:** Some envs only have `python` (3.x) in PATH (minimal Alpine, certain pyenv setups). Every state operation fails.

**Fix:** Detect once at top of state.sh:

```bash
PYTHON_BIN=$(command -v python3 || command -v python || echo "")
```

---

### R-01 — `globs: ["**/*"]` in seed `project-context.md` violates own guidance

**File:** `templates/base/rules/project-context.md:3-5`

**Failure mode:** Seed pattern violates `templates/base/rules/README.md:24-30` guidance to scope. Sets bad example.

**Fix:** Either document deliberate broad scope or demonstrate scoped usage.

---

### T-03..T-05 — Test gaps

- T-03: No test for backup→install atomicity / interrupted-update rollback.
- T-04: No test for `setup-security.sh` CLAUDE.md merge / `## NN.` section drift.
- T-05: CI is Linux-only (`ubuntu-latest`) — BSD-vs-GNU divergence (head, sed, awk variants) caught only by manual macOS testing.

**Fix:** Add scenarios + macOS CI runner (e.g., `macos-latest` matrix in `.github/workflows/quality.yml`).

---

## LOW

### Sec-L1 — `read -r` (not `-rs`) for API key prompts in init-claude.sh

**File:** `scripts/init-claude.sh:641, 666`

`setup-council.sh:113,145` correctly uses `read -rs`. init-claude.sh echoes typed chars during paste.

**Fix:** Replace `read -r` with `read -rs` + explicit `echo ""`.

---

### Sec-L2 — Heredoc files don't `chmod 600`

`POST_INSTALL.md`, `current-task.md`, `lessons-learned.md` end up world-readable (umask 022). May accumulate sensitive lessons via `/learn`.

**Fix:** `umask 077` at top of script or per-file `chmod 600`.

---

### Sec-L3 — PID file content not validated as integer

**File:** `scripts/lib/state.sh:121-128`

Theoretical terminal-injection if attacker plants escape sequences in lock pid file (requires already-compromised home dir).

**Fix:** `[[ "$old_pid" =~ ^[0-9]+$ ]] || old_pid=""`.

---

### Sec-L4 — RTK rewrite trust path documented but worth a comment in generated hook

**File:** `scripts/setup-security.sh:217-222`

Design trade-off, not a bug. User consent is documented in RTK.md.

---

### Sec-L5 — `find $HOME -maxdepth 1` slow if user has thousands of dotfiles

**File:** `scripts/lib/backup.sh:37-41,49-51`

DoS-via-clutter; not a real attacker scenario but worth noting.

---

### BRAIN-L1..L5

- L1: `commands/council.md` example lacks plan-arg quoting note.
- L2: bare `except Exception as e:` is fine (KeyboardInterrupt not caught) but could narrow.
- L3: `get_project_rules()` uses `Path.cwd()` not project root.
- L4: `sanitize_error` doesn't redact URL-encoded keys (works for actually-used key formats).
- L5: 100K-char plan limit conservative vs 200K-token model contexts.

---

### C-07 — `_fmt_age` arithmetic crashes on malformed backup dir name

**File:** `scripts/update-claude.sh:140-150,196-198`

Manual-corruption case; rare. `(( now_epoch - epoch ))` errors with `set -e`.

**Fix:** Validate `$epoch =~ ^[0-9]+$` before arithmetic.

---

### C-08 — `prompt_modified_file` RETURN trap leaks tempfiles under SIGINT

**File:** `scripts/update-claude.sh:782-785`

Per-iteration `mktemp` cleaned by RETURN trap, not main EXIT trap. SIGINT during interactive read leaks files.

**Fix:** Track in global array cleaned by main EXIT trap.

---

### Po-01..Po-09 — Portability hygiene

- Po-01: `date +%s` vs `date -u +%s` mixed (cosmetic).
- Po-02: `mktemp` 6 X's POSIX-min, fine on macOS+Linux.
- Po-03: `stat -f %m` vs `-c %Y` already branched correctly.
- Po-04: `wc -l` whitespace on macOS — current usage safe.
- Po-05: `sed '$d'` portable.
- Po-07: `2>/dev/null` on read swallows real reasons (diagnostic obscurity).
- Po-08: `du -sh` locale-dependent (`1,2M` under non-C locale). Cosmetic.
- Po-09: Bash 3.2 array-empty contract should be documented.

---

### MAN-M2..M3 (manifest hygiene)

- `inventory.components` lists 2 of 33 — fine if "curated subset," but rename to `featured_components` for clarity.
- `sp_equivalent_note` references "D-71" with no in-repo definition.

---

### S-05..S-08 (settings.json hygiene)

- S-05: Inconsistent blank-line patterns. Run `jq .` formatter.
- S-06: `Bash(npx prisma migrate reset --force)` deny shadowed by `Bash(npx *)` allow — depends on Claude Code precedence.
- S-07: `Bash(alembic downgrade base)` deny without matching allow → unreachable deny.
- S-08: Empty `"PreToolUse": []` may overwrite global cc-safety-net hook on per-scope merge.

---

### T-01..T-02 (template consistency)

- T-01: Per-stack skills (e.g., `templates/laravel/skills/laravel/`) not in manifest → never refresh.
- T-02: Per-stack expert agents not in manifest → same.

---

## False Positives Considered and Rejected

These triggered initial concern but were verified non-vulnerabilities:

1. `eval "color_val=\${$color_var:-}"` in `lib/dry-run-output.sh:52` — only called with hard-coded literals. Not exploitable.
2. `python3 -c "with open('$MCP_GLOBAL')..."` in `verify-install.sh:307,333` — paths are `$HOME/...` (operator-controlled). No external untrusted input.
3. `source "$DETECT_TMP"` post-curl — same trust as parent script. Not a *new* vector beyond the curl|bash trust assumption.
4. `merge_settings_python` heredoc — uses `<<'PYEOF'` (quoted), bash doesn't interpolate inside. Vars passed via argv only.
5. `SP_VERSION` from `find ... | basename` — paths inside `$HOME/.claude/plugins/` (operator-trusted).
6. `cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"` race — single user, no contention.
7. Backgrounded `bash ~/.claude/rate-limit-probe.sh &` — no special privileges inherited.
8. `2>/dev/null` suppressions — diagnostic, not security.
9. `setup-security.sh` hooks heredoc — `<<'HOOKEOF'` quoted, no injection points.
10. `migrate-to-complement.sh` traversal guard checks `/../`, `/./`, `/foo` — covers the cases that actually have write primitives.
11. `json.load(f)` for config — Python's json module is safe for untrusted input (in contrast to unsafe deserializers).
12. `subprocess.run` always with list args, never `shell=True`.
13. Gemini API key in URL — documented in inline comment, Google API design.
14. `tempfile.NamedTemporaryFile(delete=False)` — needed for curl file pickup; real issue is leak under SIGKILL (BRAIN-H3).
15. `set -e` defeated by `||` in color-init guards — intentional pattern, single-statement.
16. `sed -i` portability — codebase doesn't use it. Verified.
17. `readlink -f` / `realpath` BSD compatibility — codebase doesn't use either.
18. `local` keyword outside function at update-claude.sh:562 — `local_switch_decision` is a regular var name.
19. `find -printf` — not used. BSD-compatible find calls only.
20. Color leak into pipes — gated by `[ -t 1 ]` AND `${NO_COLOR+x}`.
21. `< /dev/tty` missing — covered correctly with fail-closed defaults.
22. `mktemp` portability — uses portable form on BSD+GNU.
23. `acquire_lock` race — partially real (C-02), but mtime-staleness fallback bounds damage.

---

## Top-Priority Fix Order

| # | Finding | Severity | Why first |
|---|---------|----------|-----------|
| 1 | CRIT-01 | CRITICAL | Silent destruction of user docs every update |
| 2 | CRIT-02 | CRITICAL | Version drift breaks update-flow correctness |
| 3 | C-06 | HIGH | Chains into CRIT-01; HTTP error bodies as files |
| 4 | Sec-H1 | HIGH | OAuth token leak on shared Macs |
| 5 | C-02 | HIGH | Lock-file race corrupts state |
| 6 | C-03, C-04 | HIGH | No-op gate broken; synthesis state half-written |
| 7 | C-05 | HIGH | Mode-switch may delete files in CWD |
| 8 | S-01 | HIGH | Hooks never fire as documented |
| 9 | BRAIN-H2, H3, H4 | HIGH | Silent context loss + token argv + temp leak |
| 10 | BRAIN-H1 | HIGH | Doc claim contradicts behavior (cheap fix) |
| 11 | PERF-01, PERF-02 | HIGH | 10–20s update wallclock; biggest UX win |
| 12 | T-02 | HIGH | Add tests around CRIT-01 to prevent regressions |
| 13–end | MEDIUM/LOW | as time |

---

## Files Reviewed (absolute paths)

`/Users/sergeiarutiunian/projects/claude-code-toolkit/.claude/worktrees/jolly-wing-10cbb4/`:

- `scripts/init-claude.sh`
- `scripts/init-local.sh`
- `scripts/update-claude.sh`
- `scripts/setup-security.sh`
- `scripts/setup-council.sh`
- `scripts/install-statusline.sh`
- `scripts/migrate-to-complement.sh`
- `scripts/verify-install.sh`
- `scripts/cell-parity.sh`
- `scripts/detect.sh`
- `scripts/lib/install.sh`
- `scripts/lib/state.sh`
- `scripts/lib/backup.sh`
- `scripts/lib/optional-plugins.sh`
- `scripts/lib/dry-run-output.sh`
- `scripts/council/brain.py`
- `scripts/council/config.json.template`
- `scripts/council/README.md`
- `templates/global/rate-limit-probe.sh`
- `templates/global/statusline.sh`
- `templates/{base,laravel,nextjs,nodejs,python,go,rails}/settings.json`
- `templates/base/rules/project-context.md`
- `manifest.json`
- `Makefile`
- `CHANGELOG.md`

---

## Methodology Notes

- **Audit Self-Check Protocol applied per CLAUDE.md.** Every CRITICAL/HIGH finding re-read with the question "would the developer say 'that's how it's supposed to work'?". Filter discarded ~30+ pattern-matches that turned out non-issues (catalogued above).
- **Threat model.** Operator IS the attacker for argv-injection purposes (this is a CLI tool, not a service). Adversarial inputs come from: (a) network during curl, (b) other local users on shared systems, (c) malicious symlinks/files planted by other compromised processes, (d) future-Claude-instance behavior.
- **Verification floor.** Every CRITICAL/HIGH finding has: file:line, code excerpt, concrete failure mode (not theoretical), severity rationale, and a code-level fix.
