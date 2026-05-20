# DESIGN.md — brand-inspired design tokens for coding agents

`DESIGN.md` is a single Markdown file at the project root that gives any coding
agent (Claude Code, Cursor, Aider, Copilot CLI) a structured design system —
colors, typography, spacing, radii, motion — so generated UI matches a chosen
visual language instead of defaulting to generic AI aesthetics.

The toolkit mirrors 71 brand-inspired files from
[VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md)
under `templates/design-md/<brand>/DESIGN.md`. Pinned in
`manifest.json:vendor_pins.awesome-design-md` and drift-tracked by
`/vendor-changelog`.

## Why DESIGN.md vs the Open Design integration

The toolkit ships two integrations targeting the same pain (agents make ugly
UI by default). They are complementary, not duplicates:

| Tool | Surface | Heaviest cost |
|------|---------|---------------|
| `/design-md` (this component) | Single text file at project root. Read by the agent as part of its prompt context. | Zero — one Markdown file. |
| `open-design.md` (Open Design integration) | Standalone web app on `localhost:7456`, 149 brands, emits HTML/PDF/PPTX/MP4 artifacts. | Docker daemon or Node 24 + pnpm 10. |

Pick `/design-md` when you want **the coding agent to write the UI**. Pick the
Open Design integration when you want **a separate app to render the artifact**.

## Install one DESIGN.md into a project

```text
/design-md vercel        # writes <project>/DESIGN.md from the vercel brand
/design-md               # picker — lists 71 brands, ask which one
/design-md --list        # just print brand names
```

The command resolves the file from a local toolkit clone if present, else
curls the toolkit-pinned mirror — never the moving upstream. See
`commands/design-md.md` for the full contract.

## File anatomy

Each brand DESIGN.md is one self-contained Markdown document. Two shapes exist
in the catalog:

1. **YAML-frontmatter style** (most brands): `---` block at the top with
   `colors:`, `typography:`, `spacing:`, etc., followed by prose describing
   usage. Agents can parse the frontmatter as structured tokens.
2. **Prose style with code-block tokens** (a few brands, e.g. `kraken`):
   markdown sections (`## Color Palette`, `## Typography`) with inline values.

Both shapes are agent-readable. The frontmatter style is more machine-friendly
but the prose style still works because agents read Markdown natively.

## Pairing with the rest of the toolkit

- The agent should be told to **read DESIGN.md first** before generating UI.
  Add to the project's CLAUDE.md / GEMINI.md / AGENTS.md:
  > Before generating any UI, read `DESIGN.md` and apply its tokens.
- `/design-md` does not modify CLAUDE.md. Add the line above manually if you
  want enforcement.
- For component frameworks (React/Vue/SwiftUI/Flutter) the agent still needs
  to know the project's component library — that part belongs in CLAUDE.md
  alongside the DESIGN.md pointer.

## Drift detection

`/vendor-changelog` diffs `manifest.json:vendor_pins.awesome-design-md.commit`
against upstream `main`. When upstream adds a brand or revises tokens, the
report flags it as `ADOPT` (new brand) or `BREAKING` (token rename). The
maintainer re-runs the mirror script + bumps the pin during a release. End
users get the refreshed brand catalog via `/update-toolkit`.

## Common mistakes to avoid

- Running `/design-md` on top of a real, hand-authored design system. The
  command overwrites `<project>/DESIGN.md` by default. Move the existing file
  aside first.
- Fetching from `voltagent/awesome-design-md` directly. The mirror exists to
  pin the commit; bypassing it gives an unpinned moving target.
- Treating DESIGN.md as binding. It is a Markdown file — agents can ignore it
  or misread it. Verify generated UI visually (Playwright screenshot or
  `i-webapp-testing` skill) before merging UI changes.
