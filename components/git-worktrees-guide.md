# Git Worktrees Guide

Use git worktrees for parallel development tasks.

---

## What Are Worktrees

Git worktrees allow multiple working directories from the same repository. Perfect for:

- Working on multiple features simultaneously
- Quick bug fixes while feature work is in progress
- Code reviews without stashing changes
- Running tests on different branches

---

## Basic Commands

### Create Worktree

```bash
# Create worktree for a new branch
git worktree add ../project-feature feature/new-feature

# Create worktree for existing branch
git worktree add ../project-bugfix bugfix/urgent-fix

# Create worktree at specific commit
git worktree add ../project-review abc123
```

### List Worktrees

```bash
git worktree list
# /path/to/main         abc1234 [main]
# /path/to/main-feature def5678 [feature/x]
# /path/to/main-bugfix  ghi9012 [bugfix/y]
```

### Remove Worktree

```bash
# Remove worktree (keeps branch)
git worktree remove ../project-feature

# Force remove (if has changes)
git worktree remove --force ../project-feature

# Clean up stale worktrees
git worktree prune
```

---

## Workflow Example

### Scenario: Bug Fix During Feature Work

```bash
# You're working on feature branch
cd ~/projects/myapp
git checkout feature/new-dashboard

# Urgent bug comes in!
# Create worktree for bugfix (don't lose feature work)
git worktree add ../myapp-bugfix bugfix/critical-fix

# Switch to bugfix
cd ../myapp-bugfix

# Fix the bug
# ... make changes ...
git add .
git commit -m "fix: resolve critical issue"
git push origin bugfix/critical-fix

# Go back to feature
cd ../myapp
# Continue feature work (nothing lost!)

# After bugfix is merged, clean up
git worktree remove ../myapp-bugfix
```

---

## Directory Structure

```text
projects/
├── myapp/                 # Main worktree (main branch)
├── myapp-feature-auth/    # Feature worktree
├── myapp-bugfix-123/      # Bugfix worktree
└── myapp-review-pr-456/   # Code review worktree
```

---

## Best Practices

### Naming Convention

```bash
# Pattern: {project}-{type}-{name}
git worktree add ../myapp-feature-oauth feature/oauth
git worktree add ../myapp-fix-login bugfix/login-issue
git worktree add ../myapp-review-42 pr/42
```

### Cleanup Routine

```bash
# Weekly cleanup
git worktree list
git worktree prune
# Remove merged branches
git branch --merged | grep -v main | xargs git branch -d
```

### With Node Projects

```bash
# After creating worktree, install dependencies
cd ../myapp-feature
npm install  # or pnpm install

# Note: node_modules is NOT shared between worktrees
```

### With Laravel Projects

```bash
cd ../myapp-feature
composer install
cp ../.env .env  # Copy env from main
php artisan key:generate
```

---

## Common Issues

### "fatal: is already checked out"

```bash
# Branch is checked out in another worktree
# Either remove that worktree or use different branch
git worktree list  # Find which worktree has it
```

### Database Conflicts

```bash
# Use different databases per worktree
# In .env:
DB_DATABASE=myapp_feature_oauth
```

---

## Integration with Claude Code

When working with Claude across worktrees:

1. Each worktree can have its own `.claude/` directory
2. Or share via symlink: `ln -s ../myapp/.claude .claude`
3. Scratchpad can track which worktree you're in

---

## Worktree Isolation Problem (Claude Code Jumping Between Folders)

**Problem:** When working in a worktree (e.g., `lantern-1`), Claude Code sometimes "jumps" to the main repo folder (`lantern`) or another worktree during task execution.

**Why it happens:** Git worktrees don't have a full `.git` directory — they have a `.git` file pointing to the main repository. Claude Code may get confused about project boundaries.

### Solution 1 — Always Launch From Inside Worktree

**Most important.** Never `cd` into worktree from Claude session. Launch Claude Code while already inside:

```bash
# CORRECT — launch from inside worktree
cd ~/projects/lantern-1 && claude

# WRONG — launching from parent or main folder
cd ~/projects && claude
# then "cd lantern-1" inside session — DON'T DO THIS
```

### Solution 2 — Restrict Allowed Directories

Create `.claude/settings.local.json` in each worktree to restrict Claude to that folder only:

```bash
# In each worktree
mkdir -p ~/projects/lantern-1/.claude
```

**File: `lantern-1/.claude/settings.local.json`**

```json
{
  "permissions": {
    "allowedDirectories": [
      "/Users/sergeiarutiunian/projects/lantern-1"
    ]
  }
}
```

Repeat for each worktree with its own path.

### Solution 3 — Use .claudeignore

Create `.claudeignore` in each worktree to explicitly exclude other worktrees:

**File: `lantern-1/.claudeignore`**

```text
# Exclude main repo and other worktrees
../lantern
../lantern-2
../lantern-3
../lantern-4
```

### Solution 4 — Session Start Check

Add to your worktree's `CLAUDE.md`:

```markdown
## Session Start (REQUIRED)

1. Verify working directory:
   \`\`\`bash
   pwd
   \`\`\`

2. If NOT in the expected worktree — STOP and ask user to restart Claude Code from correct folder.

3. Stay in this directory for the entire session. Do NOT cd to parent or sibling folders.
```

### Solution 5 — Separate Terminal Processes

Each terminal tab must run a **separate** Claude Code process:

```bash
# Tab 1
cd ~/projects/lantern-1 && claude

# Tab 2 (new terminal)
cd ~/projects/lantern-2 && claude

# Tab 3 (new terminal)
cd ~/projects/lantern-3 && claude
```

**Warning for tmux/screen users:** Ensure environment variables (especially `$PWD`, cache paths) are not shared between panes.

### Full Isolation Setup (Recommended)

Combine all solutions: create worktrees, then for each one create
`settings.local.json` (with `allowedDirectories`), `.claudeignore` (excluding siblings),
and install dependencies. See Solutions 1-5 above for the individual configs.

### Debugging: Where Am I

```bash
pwd                                # Current directory
git branch --show-current          # Worktree indicator
git rev-parse --show-toplevel      # Should be THIS worktree, not main repo
```

---

## Parallel Claude Sessions Workflow

**Problem:** Multiple Claude Code sessions in the same directory cause race conditions — one session overwrites another's changes.

**Solution:** Each Claude session runs in its own worktree (work-1, work-2, work-3, work-4).

### Setup (one-time)

```bash
cd ~/projects/myapp

# Create worktrees for parallel sessions
git worktree add ../myapp-work-1 -b work-1
git worktree add ../myapp-work-2 -b work-2
git worktree add ../myapp-work-3 -b work-3
git worktree add ../myapp-work-4 -b work-4

# Install dependencies in each (Node.js example)
cd ../myapp-work-1 && npm install
cd ../myapp-work-2 && npm install
cd ../myapp-work-3 && npm install
cd ../myapp-work-4 && npm install
```

### Claude Auto-Detection (add to CLAUDE.md)

```markdown
## Git Worktree Workflow (Parallel Sessions)

**Multiple Claude Code sessions run in parallel using git worktree.**

### At session start — detect worktree

\`\`\`bash
git branch --show-current
\`\`\`

- If branch is `work-1`, `work-2`, `work-3`, or `work-4` → you're in a worktree
- If branch is `main` → you're in the main repo (avoid parallel work here)

### ⚠️ NEVER Run Destructive Git Commands Without Asking

**Destructive commands that require user confirmation:**

- `git reset --hard`
- `git checkout .`
- `git clean -f`
- `git rebase` (when uncommitted changes exist)
- `git stash` (automatic stash is risky!)

**Before ANY of these:**

1. Run `git status` in EACH affected directory
2. If there are uncommitted changes — **STOP and ASK USER**
3. Show what will be lost with `git diff`
4. Only proceed after explicit confirmation

**⚠️ NEVER do `git stash && git rebase && git stash pop` automatically!**

Why this is dangerous:

- If `stash pop` has conflicts — changes get "stuck" in stash
- User loses visibility of what's happening
- Silent data loss risk

**Correct approach:**

1. First commit ALL changes (including logs, temp files)
2. Then rebase
3. Or use `merge` instead of `rebase`

**⚠️ NEVER resolve merge conflicts automatically!**

If you see `CONFLICT` in git output:

1. **STOP immediately**
2. Show user which files have conflicts
3. **ASK how to resolve** — don't use `--theirs` or `--ours` without permission
4. Let user decide what to keep

Automatic `git checkout --theirs` or `--ours` = silent data loss!

### Files That Should NOT Be Committed

`.claude/activity.log` and `.claude/audit.log` are session-local files.
They cause pointless merge conflicts and should be in `.gitignore`.

**If already tracked, remove from git:**

```bash
git rm --cached .claude/activity.log .claude/audit.log
echo "activity.log" >> .claude/.gitignore
echo "audit.log" >> .claude/.gitignore
git add .claude/.gitignore
git commit -m "chore: stop tracking session logs"
```

**This applies to bulk operations on multiple worktrees too!**

### IMPORTANT: Sync Before Push (Parallel Sessions)

When multiple Claude sessions work in parallel, **always fetch and merge before EVERY push to main**:

```bash
git fetch origin main
git merge origin/main
# If CONFLICT — STOP and ask user!
git push origin main
```

Why: Each session only sees its own commits. Without fetch/merge, pushing to main overwrites changes from other sessions.

This also applies before build/deploy — otherwise the build will miss changes from other sessions.

### Working in worktree (work-1, work-2, etc.)

1. **Before starting work** — sync with main:

   ```bash
   # CRITICAL: Check for uncommitted changes FIRST!
   git status
   # If there are changes — ASK USER before proceeding!
   # Only then:
   git fetch origin main
   git reset --hard origin/main
   ```

2. **Work normally** — make changes, test

3. **When task is complete** — commit, sync, push:

   ```bash
   # Commit in current branch
   git add <files> && git commit -m "feat: ..."

   # Sync with main FIRST (other sessions may have pushed!)
   git fetch origin main
   git merge origin/main
   # If CONFLICT — STOP and ask user!

   # Push to main
   git push origin work-X:main

   # Reset for next task
   git fetch origin main
   git reset --hard origin/main
   ```

### Avoiding conflicts

- Each worktree = separate physical folder = no race conditions
- Always sync with main before starting new task
- Merge conflicts are resolved during `git merge`, not by overwriting

### Why This Works

| Without Worktrees | With Worktrees |
|-------------------|----------------|
| 3 Claude sessions in one folder | 3 Claude sessions in 3 folders |
| All read/write same files | Each has its own copy |
| Race condition on every save | No conflict until merge |
| Last writer wins (data loss) | Git merge resolves conflicts |

### Emergency: Session Already Started Without Sync

If you realize you're in a worktree but didn't sync with main:

```bash
# FIRST: Check for uncommitted changes!
git status

# If there are changes — DO NOT reset! Use stash:
git stash

# Check if main has new commits
git fetch origin main
git log HEAD..origin/main --oneline

# If yes — reset and reapply
git reset --hard origin/main
git stash pop
# Resolve any conflicts manually
```

**⚠️ Never run `git reset --hard` without checking `git status` first!**
