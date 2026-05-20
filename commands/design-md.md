---
description: Pick a brand-inspired DESIGN.md and drop it into the project so coding agents can generate a matching UI.
---

# /design-md

## Purpose

Install a single `DESIGN.md` at the project root (or `.claude/DESIGN.md` if the user prefers) so any coding agent — Claude Code, Cursor, Aider, Copilot CLI — has a structured design system (colors, typography, spacing, radii, motion) to follow when generating UI.

The brand-inspired DESIGN.md files are mirrored from the upstream catalog [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md). Each file is a single self-contained Markdown document with YAML-frontmatter tokens. 71 brands available.

The mirror is pinned in `manifest.json:vendor_pins.awesome-design-md` (drift-tracked by `/vendor-changelog`).

## Usage

```text
/design-md                 # picker — list all brands, ask which one
/design-md <brand>         # direct install (e.g. /design-md vercel)
/design-md --list          # just print the 71 brand names
/design-md --offline       # use the toolkit clone at $TOOLKIT_DIR instead of curl
```

## What you should do

1. **Pick a brand.**
   - If the user invoked `/design-md <brand>`, use that argument.
   - Otherwise, fetch the brand list from the index — try in order:
     1. `cat "${TK_TOOLKIT_DIR:-$HOME/.claude/toolkit-src}/templates/design-md/INDEX.json"` (local clone, if present)
     2. `curl -fsSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/templates/design-md/INDEX.json`
   - Show the 71 brand names sorted. Ask which one. If the user names a brand that is not in the list, suggest the 3 closest matches by edit distance and ask again — do not guess.

2. **Decide install path.** Default: `<project-root>/DESIGN.md`. If a `DESIGN.md` already exists at the project root, ask whether to (a) overwrite, (b) write to `.claude/DESIGN.md` instead, or (c) abort.

3. **Fetch the file.** Two sources, in order:
   1. **Local clone** (preferred when available — offline-safe + version-pinned):
      `cp "${TK_TOOLKIT_DIR:-$HOME/.claude/toolkit-src}/templates/design-md/<brand>/DESIGN.md" <install-path>`
   2. **Raw GitHub** (curl from the toolkit mirror, not upstream — keeps the install on the vendor-pinned commit):
      `curl -fsSLA "$TK_USER_AGENT" "https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/templates/design-md/<brand>/DESIGN.md" -o <install-path>`

4. **Verify.** Open the first 10 lines and confirm it begins with `---` (YAML frontmatter) or `# Design System Inspired by`. If neither, the download was truncated — retry once, then surface the error.

5. **Tell the user three things:**
   - Where the file landed (absolute path).
   - One sentence describing the brand's design language — pull it from the file's `description:` frontmatter field or the first paragraph.
   - That they should mention `DESIGN.md` in their next prompt to Claude / Cursor so the agent reads it before generating UI.

## When NOT to use

- The project already has a hand-authored design system doc. `/design-md` overwrites the file by default — do not run it on top of a real design system unless the user explicitly wants to replace it.
- The user wants a custom design (not brand-inspired). Tell them `DESIGN.md` is just a Markdown file — they can write one themselves; the structure of any brand file in this catalog is a usable template.
- The user wants component code, not design tokens. This command ships tokens only. For component generation, the agent has to read DESIGN.md AND know the project's component framework (React, Vue, SwiftUI, etc.) — that part is on the user's normal prompt.

## Output format

```text
✓ Installed DESIGN.md (vercel) at /path/to/project/DESIGN.md
  Brand: Vercel — developer-platform brand, stark black-and-ink on near-white, multi-color mesh gradient as the entire decorative system.
  Next: ask Claude to "read DESIGN.md and build a hero section" or similar.
```

## Common mistakes to avoid

- **Do not fetch from `voltagent/awesome-design-md` directly** at runtime. Always fetch from the toolkit's pinned mirror — otherwise the user gets an unpinned moving target.
- **Do not list brands from a stale memory.** Read the live `INDEX.json` every invocation; the catalog grows when upstream adds brands.
- **Do not auto-install without confirming overwrite** if the file already exists. Design tokens are not safely mergeable.

## Brand catalog (71 brands, pinned 2026-05-20)

Read `templates/design-md/INDEX.json` for the authoritative current list. As of the v6.49.0 pin:

airbnb, airtable, apple, binance, bmw, bmw-m, bugatti, cal, claude, clay, clickhouse, cohere, coinbase, composio, cursor, elevenlabs, expo, ferrari, figma, framer, hashicorp, ibm, intercom, kraken, lamborghini, linear.app, lovable, mastercard, meta, minimax, mintlify, miro, mistral.ai, mongodb, nike, notion, nvidia, ollama, opencode.ai, pinterest, playstation, posthog, raycast, renault, replicate, resend, revolut, runwayml, sanity, sentry, shopify, slack, spacex, spotify, starbucks, stripe, supabase, superhuman, tesla, theverge, together.ai, uber, vercel, vodafone, voltagent, warp, webflow, wired, wise, x.ai, zapier
