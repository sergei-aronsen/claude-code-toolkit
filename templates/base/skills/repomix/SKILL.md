---
name: Repomix
description: Pack the whole repo (or a remote one) into one AI-friendly file via Repomix. Use for architectural reviews, cross-repo handoff, full-codebase audits — not for single-file lookups. Triggers on "pack repo", "feed codebase to AI", "снапшот", "analyze remote repo".
---

# Repomix Skill

> Load this skill when packing repositories for AI consumption — local or remote.
> Repomix bundles a codebase into a single XML/Markdown/JSON file, with optional
> tree-sitter compression that keeps signatures and drops bodies.

---

## Rule

**REPOMIX IS FOR BREADTH, NOT DEPTH.**

It gives an LLM a wide signatures-level view of the whole codebase. It is
not a substitute for reading one file carefully or grepping for one
function. Use the right tool for the job.

---

## When To Use Repomix

| Task | Tool | Why |
|------|------|-----|
| Find one function definition | `find-function` or `Grep` | Repomix overshoots — 1000 files for 1 symbol |
| Read a specific file | `Read` | Direct, exact, no subprocess |
| Open exploration over 2-3 files | `Explore` agent | Built-in budget control |
| Architectural review across the whole repo | **Repomix `--compress`** | Signatures of every module, fits LLM context |
| Hand the codebase to ChatGPT / web Claude / Gemini | **Repomix → clipboard** | One file, formatted for LLMs |
| Compare two upstream revisions | **Repomix `--remote --remote-branch`** | No clone needed |
| Council needs full-codebase context | **`brain --pack`** (automatic in v6.23+) | Already wired in |
| Attach codebase to a GitHub issue / PR | **Repomix `--style markdown`** | Renders nicely on GitHub |

If the task isn't on the "use" rows above — pick a sharper tool.

---

## How To Invoke

### From inside Claude Code

```text
/pack                                    # current repo, defaults
/pack --remote yamadashy/repomix         # remote
/pack --include "src/**" --format md     # subset + markdown
/pack --to clipboard                     # copy, don't write a file
```

The `/pack` command is the supported entry point. It writes to
`.claude/scratchpad/pack-<timestamp>.<ext>`.

### From your shell

```bash
# Pack this repo
npx -y repomix@1.14.0 --compress --style xml

# Pack a remote repo
npx -y repomix@1.14.0 --remote nestjs/nest --compress --style markdown --output /tmp/nest.md

# Pack a specific commit of an upstream repo
npx -y repomix@1.14.0 \
    --remote yamadashy/repomix \
    --remote-branch 5811266e6f242c6f30ad102a066acf7780dcbf30 \
    --compress

# Pack only changed files (pipe from git)
git ls-files '*.ts' | npx -y repomix@1.14.0 --stdin --stdout
```

---

## Supreme Council Integration

Supreme Council (`brain.py`) packs the local repo automatically and feeds
the compressed XML to both Skeptic (Gemini) and Pragmatist (ChatGPT)
before they review the plan. This fixes Council's prior
context-starvation problem.

```bash
brain "implement Stripe Connect onboarding flow"      # pack ON (default)
brain --no-pack "implement Stripe Connect ..."        # legacy targeted-only
brain --pack-force "..."                              # ship even oversize
brain --pack-fresh "..."                              # regenerate cache
brain --pack-remote nestjs/nest "review their DI ..." # pack a different repo
```

Pack cache lives at `.claude/scratchpad/repomix-pack.xml` and refreshes
automatically when any tracked file's mtime exceeds the cached pack's
mtime.

---

## Output Formats

| Format | When |
|--------|------|
| `xml` (default) | Best for Claude per Anthropic guidance. Ideal for Council, audits |
| `markdown` | Best for GitHub issues, ChatGPT web, human reading |
| `json` | Programmatic processing — `jq` queries, scripted pipelines |
| `plain` | Token-cheapest. Use when format-aware features aren't needed |

---

## Compression

`--compress` runs tree-sitter and extracts class/function signatures
while dropping bodies. Sample:

```typescript
// Before --compress (full file, ~500 LOC)
export class UserService {
  constructor(private db: Database) {}
  async createUser(input: CreateUserInput): Promise<User> {
    // ... 200 lines of validation + business logic ...
  }
}

// After --compress (~10 LOC)
export class UserService {
  constructor(private db: Database);
  async createUser(input: CreateUserInput): Promise<User>;
}
```

Compression ratio: **~10-15× on code-heavy repos**, **~1.0× on
documentation repos** (markdown isn't parsed by tree-sitter).

---

## Token Budget

| Repo Type | Compressed Pack Size |
|-----------|----------------------|
| Small TS/JS app (~50 files) | 5-20k tokens |
| Mid-size monorepo (~500 files) | 40-120k tokens |
| Large enterprise repo (5000+ files) | 200k-2M tokens |
| Documentation-heavy repo (this toolkit) | 1-2M tokens (compression no-op on markdown) |

Council's `--pack` flag enforces a **180k soft cap** — packs exceeding
it are dropped silently with a stderr warning, and Council falls back to
the legacy targeted-files context.

For oversize repos:

1. Add `.repomixignore` entries for vendored / generated dirs
2. Use `--include "src/**"` to scope down
3. Pass `--pack-force` only when you've verified the target model handles
   the volume (Gemini 2M+ context, GPT-5.x 400k)

---

## Security

- Secretlint is on by default — strips API keys, tokens, JWTs, PII
  patterns before the pack hits disk
- **Never pass `--no-security-check`** from toolkit code or scripts
- Brain.py re-applies its own `redact_context()` layer over the pack
  before sending to providers (defense in depth)
- Pack files in `.claude/scratchpad/` are gitignored — never commit

---

## Anti-Patterns

- ❌ Packing the repo to find one function → use `find-function`
- ❌ Packing the repo for a typo fix → use `Grep` + `Edit`
- ❌ Packing every commit → use `Read` on the diff
- ❌ Packing with `--no-security-check` to silence false positives → add
  Secretlint allowlist instead (`.secretlintignore`)
- ❌ Committing pack artifacts → `.claude/scratchpad/` is gitignored for
  a reason
- ❌ Passing user-provided URLs to `--remote` without validation → reject
  URLs with embedded credentials (`user:pass@host`)

---

## Reference

- Repository: <https://github.com/yamadashy/repomix>
- Pinned version: `repomix@1.14.0` (see `manifest.json:vendor_pins.repomix`)
- Toolkit integration: v6.23.0
- Related skill: `council-integration`
- Related command: `/pack`
- MCP integration: `repomix` server in `scripts/lib/integrations-catalog.json`

---

## Triggers (Informational)

The activation rules in `templates/base/skills/skill-rules.json` cover:

**Keywords (EN):** repomix, pack repo, pack codebase, pack repository,
codebase snapshot, full repo context, cross-repo review, analyze remote
repo, feed codebase to LLM

**Keywords (RU):** упакуй репо, снапшот, упаковать кодовую базу, обзор
архитектуры, передать репо в LLM, удалённый репо

**Intent patterns:** `pack.*repo`, `analyze.*github\.com.*`, `snapshot.*codebase`

**File patterns:** none — repomix isn't tied to specific extensions
