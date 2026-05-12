# Repomix Integration

> v6.23.0+ — full-repo pack as Supreme Council context, plus a standalone
> `/pack` command, a learnable skill, an MCP entry, and an update-deps probe.

[Repomix](https://github.com/yamadashy/repomix) packs a repository into a
single AI-friendly file (XML, Markdown, JSON, or plain text). The toolkit
pins `repomix@1.14.0` and uses it as a soft dependency — every feature
degrades to a no-op when Node is absent.

---

## What Changed in v6.23.0

| Change | File(s) |
|---|---|
| `brain.py --pack` (default ON) feeds compressed full-repo XML into Council prompts | `scripts/council/brain.py`, `scripts/council/pack.py` |
| `/pack` slash command for manual repo packing | `commands/pack.md` |
| `repomix` skill with EN+RU triggers and decision matrix | `templates/base/skills/repomix/SKILL.md` |
| MCP catalog entry (29th server) | `scripts/lib/integrations-catalog.json` |
| `update-deps.sh probe_repomix` + `upgrade_repomix` | `scripts/update-deps.sh` |
| Pinned version in `vendor_pins.repomix` | `manifest.json` |

---

## Supreme Council With Pack

### Default Behavior

```bash
brain "implement Stripe Connect onboarding flow"
```

What happens behind the scenes:

1. `should_use_pack()` checks for `node`+`npx` on PATH (default ON).
2. `build_pack_block()` runs `npx -y repomix@1.14.0 --stdout --compress --style xml`.
3. Result is cached at `.claude/scratchpad/repomix-pack.xml`.
4. Cache is reused on subsequent runs unless any tracked file has a newer mtime.
5. Pack content is redacted via `redact_context()` (defense in depth on top of Secretlint).
6. Pack is wrapped in `<<<USER_DATA_BEGIN>>>` sentinels and injected into both Skeptic and Pragmatist prompts BEFORE the targeted FILES CONTEXT block.

### Flags

| Flag | What it does |
|------|--------------|
| `--no-pack` | Disable pack, revert to legacy targeted-only context |
| `--pack-force` | Ship pack even when it exceeds the 180k-token soft budget |
| `--pack-fresh` | Ignore cached pack and regenerate |
| `--pack-remote <url>` | Pack a remote repo instead of `cwd`. Refuses URLs with embedded credentials |

### Budget and Fallback

Soft cap: **180,000 tokens** (estimated; chars/4 approximation). The pipeline:

```text
1. Generate pack with --compress
2. If tokens > 180k:
   - Re-pack with auto-ignore (**/*.lock, **/*.min.*, dist/**, build/**, ...)
3. If still > 180k AND --pack-force not set:
   - Drop pack injection silently
   - Council falls back to legacy targeted-files context
   - Stderr warning explains how to add .repomixignore entries
```

Override the budget via `REPOMIX_PACK_BUDGET=<n>` env var.

### Doc-Heavy Repos

Tree-sitter compression operates on code (TS, JS, Python, Go, Rust, ...) and
**does not compress Markdown**. Documentation-heavy repos (like this toolkit
itself) frequently exceed the 180k budget. That's expected — pack drops
silently and Council still runs in legacy mode.

---

## /pack Standalone Command

```text
/pack                                 # local repo, defaults (XML compressed)
/pack --remote yamadashy/repomix      # remote
/pack --include "src/**,*.md"         # filter
/pack --format md                     # Markdown output
/pack --to clipboard                  # macOS pbcopy / Linux xclip
```

Writes `.claude/scratchpad/pack-<timestamp>.<ext>` (XML / md / json).

See `commands/pack.md` for the full spec.

---

## MCP Server

The `repomix` MCP exposes Repomix as a tool Claude can call mid-conversation
to pack remote repos or fetch a packed view of the local one.

Register at user scope:

```bash
claude mcp add repomix --scope user -- npx -y repomix@1.14.0 --mcp
```

Or pick `repomix` from the MCP wizard:

```bash
bash scripts/install.sh --mcps
```

Zero secrets, zero env vars.

---

## Skill

`templates/base/skills/repomix/SKILL.md` teaches Claude:

- When repomix beats `Grep` / `Read` / `find-function` / `Explore`
- How to invoke `/pack`, `brain --pack`, and the MCP server
- Anti-patterns (e.g., don't pack to fix a typo)
- Triggers in EN+RU

Skill loads automatically via `skill-rules.json` when keywords match.

---

## Version Pin Management

The toolkit pins `repomix@1.14.0` in three places:

1. `manifest.json:vendor_pins.repomix.tag` — source of truth
2. `scripts/council/pack.py:REPOMIX_VERSION`
3. `scripts/lib/integrations-catalog.json:components.mcp.repomix.install_args`
4. `commands/pack.md` examples
5. `templates/base/skills/repomix/SKILL.md` examples

To bump:

```bash
scripts/update-deps.sh --check repomix     # see installed vs latest
# To actually upgrade and rewrite all pin strings:
scripts/update-deps.sh                     # interactive — pick repomix row
```

`upgrade_repomix` calls `_sync_repomix_pin` which:

- Reads `npm view repomix version`
- Updates `manifest.json:vendor_pins.repomix.tag`
- Rewrites `repomix@<old>` to `repomix@<new>` in all 4 listed files

---

## Security

- **Secretlint always ON** in repomix CLI invocations. Never pass `--no-security-check` from any toolkit script.
- `redact_context()` re-applies the brain.py redaction layer over the pack before provider call.
- Pack file written with `0600` permissions.
- `.claude/scratchpad/` is gitignored — pack artifacts never enter version control.
- `--pack-remote` rejects URLs with embedded credentials (`user:pass@host`).
- Pinned version (`@1.14.0`) prevents arbitrary-version supply-chain risk via `@latest`.

---

## Disabling

If Repomix gives you problems:

```bash
# Per-invocation
brain --no-pack "..."

# Per-session
export REPOMIX_PACK_DISABLE=1
brain "..."

# Permanent: add to ~/.claude/config or shell profile
echo 'export REPOMIX_PACK_DISABLE=1' >> ~/.zshrc
```

Council still works without pack — it falls back to the pre-v6.23 targeted
file-reading flow.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `pack disabled (no Node or --no-pack)` | Node/npx not on PATH | `brew install node` or install Node 18+ |
| `pack ... tokens > budget` | Repo too large | Add `.repomixignore` entries; or `--pack-force` |
| `cached pack unreadable` | Corrupted artifact | `rm .claude/scratchpad/repomix-pack.xml && brain --pack-fresh "..."` |
| Pack stale despite recent edits | File not git-tracked | Stage with `git add` or pass `--pack-fresh` |
| `npx repomix` fetches every time | npm cache cleared | One-off — cache repopulates after first fetch |

---

## See Also

- Upstream: <https://github.com/yamadashy/repomix>
- Pinned version: `manifest.json:vendor_pins.repomix`
- Council guide: `docs/COUNCIL.md`
- Slash command: `commands/pack.md`
- Skill: `templates/base/skills/repomix/SKILL.md`
