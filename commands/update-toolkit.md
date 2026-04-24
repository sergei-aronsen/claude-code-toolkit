# /update-toolkit — Update Claude Code Toolkit

## Purpose

Smart update of Claude Code Toolkit — updates system files while preserving your customizations.

## Usage

```text
/update-toolkit
```

## What Gets Updated

| Category | Files | Behavior |
|----------|-------|----------|
| **Agents** | `agents/*.md` | Always updated |
| **Prompts** | `prompts/*.md` | Always updated |
| **Skills** | `skills/ai-models/SKILL.md` | Always updated |
| **CLAUDE.md** | Main instructions | **Smart merge** (see below) |

## What Gets Preserved

| Category | Files | Behavior |
|----------|-------|----------|
| **User sections in CLAUDE.md** | Project Overview, Structure, Commands, Notes | Preserved during merge |
| **Settings** | `settings.json`, `settings.local.json` | Never touched |
| **Memory** | `memory/*.md`, `memory/*.json` | Never overwritten |
| **Skill rules** | `skills/skill-rules.json` | Never overwritten |
| **Scratchpad** | `scratchpad/*` | Never touched |

## Smart Merge for CLAUDE.md

The update script identifies two types of sections:

**System sections** (updated):

- Compact Instructions
- Workflow Rules, Plan Mode, Git Workflow
- Security Rules, Architecture Guidelines
- Available Agents, Commands, Audits, Skills

**User sections** (preserved):

- 🎯 Project Overview
- 📁 Project Structure
- ⚡ Essential Commands
- ⚠️ Project-Specific Notes

## Process

```text
1. Detect framework (Laravel, Next.js, etc.)
2. Download manifest.json (version info)
3. Create backup (.claude-backup-YYYYMMDD-HHMMSS/)
4. Update agents, prompts, skills
5. Smart merge CLAUDE.md:
   - Download new template
   - Extract user sections from current file
   - Replace system sections with new versions
   - Restore user sections
6. Save version to .toolkit-version
7. Show changelog link
```

## Version Tracking

```bash
# Check current version
cat .claude/.toolkit-version

# Compare with remote
curl -s https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/manifest.json | grep version
```

## Manual Run

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh)
```

## After Update

1. **Review changes** — check CLAUDE.md for new sections
2. **Restart Claude Code** — exit and reopen for slash commands to reload
3. **Check changelog** — see what's new: [CHANGELOG.md](https://github.com/sergei-aronsen/claude-code-toolkit/blob/main/CHANGELOG.md)

## Rollback

If something went wrong:

```bash
# Find backup
ls -la .claude-backup-*

# Restore
rm -rf .claude
mv .claude-backup-YYYYMMDD-HHMMSS .claude
```

## Example Output

```text
Detected framework: laravel
Version: 2.6.0 -> 2.7.0
Backup: .claude-backup-20260203-120000

Updated: agents/, prompts/, skills/, CLAUDE.md (system sections)
Preserved: Project Overview, Structure, Commands, Notes, settings, memory/

Changelog: https://github.com/.../CHANGELOG.md
Warning: Restart Claude Code to apply changes
```
