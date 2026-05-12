# /pack — Repository Pack for AI Context

## Purpose

Pack the current repository (or a remote one) into a single AI-friendly file
via [Repomix](https://github.com/yamadashy/repomix). The output lands in
`.claude/scratchpad/` and is ready to attach to any LLM — ChatGPT, Claude
web, Gemini, a teammate, an issue thread.

This is the **manual** counterpart to `/council`'s automatic pack
augmentation. Use it when you want a snapshot outside the Council flow.

---

## Usage

```text
/pack                                 # local repo, defaults (XML, compressed)
/pack --remote yamadashy/repomix      # remote repo by shorthand
/pack --remote https://github.com/x/y # full URL
/pack --include "src/**,*.md"         # filter
/pack --format markdown               # md instead of xml
/pack --format json                   # json
/pack --to clipboard                  # copy to system clipboard (pbcopy/xclip)
/pack --no-compress                   # skip tree-sitter signature extraction
/pack --include-diffs --include-logs  # add git context
```

**Examples:**

- `/pack` — pack this repo, write `.claude/scratchpad/pack-<timestamp>.xml`
- `/pack --remote nestjs/nest --include "packages/core/**"` — pack a subset of an upstream repo
- `/pack --to clipboard --format md` — quick markdown handoff for ChatGPT
- `/pack --include-diffs --include-logs` — pack with full git history (last 50 commits)

---

## When to Use

| Situation | Use /pack |
|-----------|-----------|
| Architectural review across 50+ files | yes |
| Handoff to another LLM (ChatGPT, web Claude) | yes |
| Attach codebase context to an issue / PR comment | yes |
| Snapshot for a teammate working in a different stack | yes |
| Look at the shape of an upstream library | yes (`--remote`) |
| Find a single function | no — use `/find-function` or `Grep` |
| Read one file | no — use `Read` |
| Open-ended exploration of 2-3 files | no — use `Explore` agent |
| Pre-Council context | no — Council does this automatically via `--pack` |

---

## Prerequisites

```bash
# Node + npx (no global install needed; pinned version fetched on demand)
node --version    # ≥ 18
npx --version
```

Toolkit pins `repomix@1.14.0`. The `npx -y` invocation handles the rest.

---

## Output

| Mode | Location |
|------|----------|
| Default | `.claude/scratchpad/pack-<timestamp>.xml` |
| `--format md` | `.claude/scratchpad/pack-<timestamp>.md` |
| `--format json` | `.claude/scratchpad/pack-<timestamp>.json` |
| `--to clipboard` | system clipboard (no file written) |

The command prints a one-line summary:

```text
✓ pack written to .claude/scratchpad/pack-2026-05-12T18-30-00.xml
  files=482  tokens≈84,231  size=312KB
```

---

## How It Wraps Repomix

`/pack` is a thin convenience layer around:

```bash
npx -y repomix@1.14.0 \
    --compress \
    --style <format> \
    [--remote <url>] \
    [--include <patterns>] \
    [--include-diffs --include-logs] \
    --output .claude/scratchpad/pack-<ts>.<ext>
```

Secretlint is **always on** (default repomix behavior) — secrets are stripped
before the pack hits disk. Do not pass `--no-security-check`.

---

## Iron Rules

1. **DO** redact obvious secrets before sharing externally — Secretlint
   catches API keys, but commercial PII, internal URLs, and customer
   identifiers slip through.
2. **DO NOT** commit pack artifacts. `.claude/scratchpad/` is gitignored —
   keep it that way.
3. **DO NOT** pack with `--remote https://user:token@github.com/...` —
   credentials end up in shell history and pack metadata.
4. **DO NOT** use `/pack` for single-file or single-symbol lookups — it's
   overkill, slow, and noisy. Use `Read` / `Grep` / `find-function` instead.

---

## Related Commands

- `/council` — auto-packs the local repo for Skeptic + Pragmatist review
- `/research` — Perplexity-backed web research (different tool, different job)
- `/find-function` — single-symbol lookup
- `/explain` — explain a specific file or symbol

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `command not found: npx` | Install Node 18+ (`brew install node`) |
| Pack exceeds 10MB | Add `.repomixignore` entries (e.g., `dist/`, `*.lock`) |
| `--to clipboard` does nothing | macOS: `pbcopy` is built-in; Linux: install `xclip` or `wl-copy` |
| Remote pack fails with 404 | Verify the repo is public; `--remote` doesn't authenticate |
| Output has stripped function bodies | That's `--compress` (tree-sitter); pass `--no-compress` for full source |
