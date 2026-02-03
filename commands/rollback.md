# /rollback — Rollback Toolkit Update

## Description

Rollback to a previous version of Claude Code Toolkit after a failed or unwanted update.

## Usage

```text
/rollback
/rollback list
/rollback latest
/rollback 20260203-120000
```

## Actions

### /rollback list

Show all available backups:

```bash
ls -la .claude-backup-* 2>/dev/null | head -20
```

**Example output:**

```text
Available backups:
  .claude-backup-20260203-120000/  (2 hours ago)
  .claude-backup-20260202-180000/  (1 day ago)
  .claude-backup-20260201-090000/  (2 days ago)
```

### /rollback latest

Rollback to the most recent backup:

```bash
# Find latest backup
LATEST=$(ls -d .claude-backup-* 2>/dev/null | sort -r | head -1)

if [[ -n "$LATEST" ]]; then
    # Backup current state (in case rollback was a mistake)
    mv .claude .claude-pre-rollback-$(date +%Y%m%d-%H%M%S)

    # Restore
    cp -r "$LATEST" .claude

    echo "✓ Rolled back to: $LATEST"
    echo "⚠ Restart Claude Code to apply changes"
else
    echo "✗ No backups found"
fi
```

### /rollback [timestamp]

Rollback to a specific backup:

```bash
BACKUP=".claude-backup-20260203-120000"

if [[ -d "$BACKUP" ]]; then
    mv .claude .claude-pre-rollback-$(date +%Y%m%d-%H%M%S)
    cp -r "$BACKUP" .claude
    echo "✓ Rolled back to: $BACKUP"
else
    echo "✗ Backup not found: $BACKUP"
fi
```

## Process

```text
1. List available backups (if no argument)
2. Save current .claude as .claude-pre-rollback-* (safety net)
3. Copy selected backup to .claude
4. Report success
```

## When to Use

- Update broke something
- Smart merge didn't preserve your customizations correctly
- Want to return to a known good state
- Accidentally ran `/update-toolkit` in wrong project

## Safety

- Current `.claude` is saved as `.claude-pre-rollback-*` before rollback
- You can rollback the rollback if needed
- Backups are never deleted automatically

## Cleanup Old Backups

```bash
# Keep only last 3 backups
ls -d .claude-backup-* | sort -r | tail -n +4 | xargs rm -rf

# Delete all backups (after confirming toolkit works)
rm -rf .claude-backup-* .claude-pre-rollback-*
```

## Example

**User:** `/rollback`

**Claude:**

```text
Available backups:

  .claude-backup-20260203-153022/  (30 min ago)  ← latest
  .claude-backup-20260203-120000/  (3 hours ago)
  .claude-backup-20260202-180000/  (1 day ago)

Which backup to restore?
- "latest" for most recent
- Or specify timestamp (e.g., "20260203-120000")
```

**User:** `latest`

**Claude:**

```bash
mv .claude .claude-pre-rollback-20260203-160000
cp -r .claude-backup-20260203-153022 .claude
```

```text
✓ Rolled back to: .claude-backup-20260203-153022
✓ Current state saved to: .claude-pre-rollback-20260203-160000

⚠ Restart Claude Code to apply changes
```
