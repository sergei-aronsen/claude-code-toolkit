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

### Working in worktree (work-1, work-2, etc.)

1. **Before starting work** — sync with main:
   \`\`\`bash
   git fetch origin main
   git reset --hard origin/main
   \`\`\`

2. **Work normally** — make changes, test

3. **When task is complete** — merge to main:
   \`\`\`bash
   # Commit in current branch
   git add <files> && git commit -m "feat: ..."

   # Switch to main, merge, push
   git checkout main
   git merge work-X --no-edit
   git push origin main

   # Return to worktree branch and reset for next task
   git checkout work-X
   git reset --hard origin/main
   \`\`\`

### Avoiding conflicts

- Each worktree = separate physical folder = no race conditions
- Always sync with main before starting new task
- Merge conflicts are resolved during `git merge`, not by overwriting
```

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
# Check if main has new commits
git fetch origin main
git log HEAD..origin/main --oneline

# If yes — stash your changes, reset, reapply
git stash
git reset --hard origin/main
git stash pop
# Resolve any conflicts manually
```
