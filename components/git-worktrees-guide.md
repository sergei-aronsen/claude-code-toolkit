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
