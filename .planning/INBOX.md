# Inbox — Captured ideas pending triage

Items here are raw captures from mid-workflow conversations. Triage to backlog (`/gsd-add-backlog`), to a phase scope, or to a new phase via `/gsd-insert-phase` / `/gsd-add-phase`.

---

## 2026-04-29 — Auto-update mechanism for skills + MCPs

**Captured during:** `/gsd-plan-phase 24` (Phase 24 — Unified TUI Installer)
**Source:** User request: "было бы классно ещё какой-то автоапдейт туда встроить, вот для таких штук"

### Problem

Skills and MCP servers update independently in their upstream repos. No toolkit-level mechanism today to pull those updates. Users currently must:

- **Plugin skills** — `claude plugin update <name>` (per-plugin, manual)
- **Local skill repos** — `cd ~/.claude/skills/<name> && git pull` (per-skill, manual)
- **MCP servers** — depends on transport: `npx/uvx @latest` auto-updates on CC restart; `npm update -g <pkg>` for global; rebuild for binaries
- **No "update everything" command** that fans out across all installed sources

### Proposed shape (for triage discussion)

**Scope candidates:**

1. **New phase 28: Auto-update orchestrator** — `scripts/update-skills-mcps.sh` that fans out:
   - For each plugin in `~/.claude/plugins/*` → `claude plugin update <name>` (or marketplace API)
   - For each git-tracked dir in `~/.claude/skills/*` → `git -C "$dir" pull --ff-only`
   - For each MCP in `~/.claude.json` `mcpServers{}` with `npx/uvx` transport → no-op (auto on restart) but emit advisory
   - For each MCP with pinned `npm` global → `npm update -g <pkg>`
   - Summary table via `dro_*` API matching Phase 24 install summary precedent

2. **Hook into Phase 25 (MCP Selector)** — add `--update` mode to `install-mcps.sh`
3. **Hook into Phase 26 (Skills Selector)** — add `--update` mode to `install-skills.sh`
4. **Single TUI page in `install.sh` v2** — "Update installed components" alongside "Install new"

### Open questions for triage

- Should auto-update run on a schedule (cron/launchd) or stay manual?
- Pin-vs-latest policy: opt-in only (user toggle in TUI) or opt-out by default?
- Notification UX when an update is available without applying it?
- Roll-back path if an update breaks (skill repo: `git reset --hard ORIG_HEAD`; plugin: re-install previous tag)?

### Recommended triage

- Defer until Phase 25 (MCP Selector) and Phase 26 (Skills Selector) ship — both will define the catalog format that update logic depends on
- Promote to **new Phase 28** under v4.5 milestone after Phase 26 closes (or v4.6 milestone if v4.5 closes first)

---

## 2026-04-29 — Add `huashu-design` skill to Phase 26 Skills Selector

**Captured during:** `/gsd-plan-phase 24`
**Source:** User request: "добавь в инсталлер еще 1 скилл npx skills add alchaincyf/huashu-design"

### What

Add `alchaincyf/huashu-design` to the Phase 26 Skills Selector catalog so users can install it via the toolkit TUI.

### Install command (verified shape from upstream)

```bash
npx skills add alchaincyf/huashu-design
```

This is the `claude-code-skills-marketplace` CLI (already used by other entries in the planned Phase 26 mirror). No new transport needed.

### Where it slots

- `templates/skills/huashu-design.json` (Phase 26 will define the manifest format)
- Add `is_huashu_design_installed` probe — `[ -d "$HOME/.claude/skills/huashu-design" ]` or marketplace API check
- Add `dispatch_huashu_design` — wrapper around `npx skills add alchaincyf/huashu-design`

### Recommended triage

- Add to Phase 26 CONTEXT.md `<decisions>` block when Phase 26 reaches `/gsd-discuss-phase`
- Source-of-truth for the skill list is Phase 26 — do not touch Phase 24 scope (TUI infra only, no per-skill catalog)

---
