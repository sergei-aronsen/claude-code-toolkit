# /worktree — Git Worktree Operations

## Purpose

Manage git worktrees for parallel work on multiple branches.

---

## Usage

```text
/worktree <action> [args]
```

**Actions:**

- `create` — create a new worktree
- `list` — show all worktrees
- `remove` — remove a worktree
- `cleanup` — clean up stale worktrees

---

## What Are Worktrees?

Git worktrees = multiple working directories of the same repository.

**Without worktrees:**

```text
my-project/     ← switch between branches (git checkout)
```

**With worktrees:**

```text
my-project/           ← main branch
my-project-feature/   ← feature/new-login (separate directory)
my-project-hotfix/    ← hotfix/urgent (another directory)
```

---

## Actions

### /worktree create

```text
/worktree create feature/oauth
/worktree create bugfix/login-issue
```

**Process:**

```bash
# Creates directory next to the project
git worktree add ../[project]-[branch-name] [branch]

# Example:
git worktree add ../myapp-feature-oauth feature/oauth
```

**After creation:**

```bash
cd ../myapp-feature-oauth

# For Node.js:
pnpm install

# For Laravel:
composer install
cp ../.env .env
```

---

### /worktree list

```text
/worktree list
```

**Output:**

```text
Worktrees:
1. /path/to/myapp           [main]        abc1234
2. /path/to/myapp-feature   [feature/x]   def5678
3. /path/to/myapp-bugfix    [bugfix/y]    ghi9012
```

---

### /worktree remove

```text
/worktree remove feature/oauth
```

**Process:**

```bash
git worktree remove ../myapp-feature-oauth
```

---

### /worktree cleanup

```text
/worktree cleanup
```

**Process:**

```bash
git worktree prune
git worktree list
```

---

## When to Use

| Situation | Action |
|-----------|--------|
| Urgent bug while working on a feature | `/worktree create hotfix/bug` |
| Code review without losing context | `/worktree create review/pr-123` |
| Parallel work by AI agents | Each agent in its own worktree |
| Comparing two code versions | Two worktrees side by side |

---

## Example Workflow

```text
# Working on a feature
cd ~/projects/myapp
git checkout feature/dashboard

# Urgent bug comes in!
/worktree create hotfix/critical

# Claude creates:
git worktree add ../myapp-hotfix-critical hotfix/critical

# Switch to hotfix
cd ../myapp-hotfix-critical
# Fix the bug, commit, push

# Return to feature
cd ../myapp
# Everything is in place!

# After merging hotfix — cleanup
/worktree remove hotfix/critical
```

---

## Directory Naming

```text
{project}-{type}-{name}

Examples:
myapp-feature-oauth
myapp-fix-login
myapp-review-pr-42
```

---

## ⚠️ Safety Rules

**Before ANY destructive git command (`reset --hard`, `checkout .`, `clean -f`):**

1. Run `git status` in the target directory
2. If uncommitted changes exist — **STOP and ASK USER**
3. Show what will be lost with `git diff`
4. Only proceed after explicit confirmation

**This applies to bulk operations on multiple worktrees!**

---

## Common Issues

### "Branch is already checked out"

```bash
# Branch is already used in another worktree
git worktree list  # Find where
```

### Database Conflicts (Laravel)

```bash
# Use different databases for each worktree
# In .env:
DB_DATABASE=myapp_feature_oauth
```

### node_modules

```bash
# node_modules is NOT shared between worktrees
# Separate npm install needed in each
```

---

## Full Documentation

Detailed guide: `components/git-worktrees-guide.md`
