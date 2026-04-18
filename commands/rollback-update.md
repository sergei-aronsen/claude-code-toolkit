# /rollback-update — Rollback Toolkit Update

## Description

Rollback to a previous version of Claude Code Toolkit after a failed or unwanted update.

## Usage

```text
/rollback-update
/rollback-update list
/rollback-update latest
/rollback-update 1713456789-42315
```

## Backup Naming (v4.0+)

Starting with v4.0.0, `update-claude.sh` writes backups to `.claude-backup-<unix-ts>-<pid>/`
(e.g. `.claude-backup-1713456789-42315/`) instead of the v3.x `<YYYYMMDD-HHMMSS>` format.
This prevents naming collisions when two updates run in the same second.

The listing glob `.claude-backup-*` still matches both formats, so this command works
unchanged on v3.x backups and v4.0+ backups alike.

## Actions

### /rollback list

Show all available backups:

```bash
ls -la .claude-backup-* 2>/dev/null | head -20
```

**Example output:**

```text
Available backups:
  .claude-backup-1713456789-42315/  (2 hours ago)
  .claude-backup-1713434567-38901/  (1 day ago)
  .claude-backup-1713348167-31044/  (2 days ago)
```

### /rollback latest

Rollback to the most recent backup:

```bash
# Find latest backup
# Glob matches both v3.x (YYYYMMDD-HHMMSS) and v4.0+ (unix-ts-pid) formats.
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
BACKUP=".claude-backup-1713456789-42315"

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

  .claude-backup-1713458422-42315/  (30 min ago)  ← latest
  .claude-backup-1713456789-38901/  (3 hours ago)
  .claude-backup-1713434567-31044/  (1 day ago)

Which backup to restore?
- "latest" for most recent
- Or specify backup name (e.g., "1713456789-42315")
```

**User:** `latest`

**Claude:**

```bash
mv .claude .claude-pre-rollback-1713460022-55123
cp -r .claude-backup-1713458422-42315 .claude
```

```text
✓ Rolled back to: .claude-backup-1713458422-42315
✓ Current state saved to: .claude-pre-rollback-1713460022-55123

⚠ Restart Claude Code to apply changes
```
