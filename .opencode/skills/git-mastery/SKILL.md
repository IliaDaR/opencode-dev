---
name: git-mastery
description: Use when performing git operations beyond basic commit/push — rebasing, cherry-picking, resolving conflicts, cleaning history, bisecting bugs, or designing branching strategies.
---

# Git Mastery

## Mental Model

Git is a content-addressed filesystem with a DAG of commits. A branch is a pointer to a commit. Merging creates a new commit with two parents. Rebasing rewrites history.

## Branching Strategy

### Trunk-Based Development (recommended)
```
main ───●─────●─────●─────●─────●
         \     /
feature   ●───●
```
- Short-lived branches (< 2 days)
- Merge to main via PR
- Feature flags for incomplete work
- Best for: CI/CD, fast feedback, small teams

### Git Flow (for versioned releases)
```
main     ──●────────────●──────────
           /            /
develop  ─●────●──────●────●──────
         /    /       /
feature ●───● release●──● hotfix
```
- Long-lived develop branch
- release and hotfix branches
- Best for: products with versioned releases, enterprise

## Essential Operations

### Interactive Rebase (clean your history)
```bash
git rebase -i HEAD~4

# Commands inside editor:
# pick — keep the commit
# reword — change the message
# squash — merge into previous commit
# fixup — merge into previous, discard its message
# drop — remove the commit
# edit — stop to amend the commit

# Golden rule: NEVER rebase commits that have been pushed to a shared branch
# Rebase is for local cleanup before pushing
```

### Cherry-Pick
```bash
# Grab a specific commit from another branch
git cherry-pick abc1234

# Cherry-pick a range (not including A, through B)
git cherry-pick A..B

# Without committing (to modify first):
git cherry-pick --no-commit abc1234
```

### Bisect (find which commit broke something)
```bash
git bisect start
git bisect bad HEAD       # Current commit is broken
git bisect good v1.2.3    # Last known good
# Git checks out a commit in the middle
# Test it, then:
git bisect good           # If this commit works
git bisect bad            # If this commit is broken
# Repeat until git identifies the exact commit
git bisect reset          # Return to HEAD
```

### Reflog (undo almost anything)
```bash
git reflog
# Shows every HEAD movement (commits, checkouts, rebases, resets)
# Even "deleted" commits are here for 30 days

# Recover "lost" commit:
git checkout HEAD@{2}

# Undo a rebase:
git reset --hard HEAD@{before-rebase}
```

### Stash (save work-in-progress)
```bash
git stash                    # Stash all changes
git stash push -m "WIP: refactoring auth"
git stash list
git stash pop                # Apply and remove from stash
git stash apply stash@{1}    # Apply specific stash, keep it
git stash drop stash@{1}     # Delete a stash

# Stash only some files:
git stash push -m "only styles" -- src/styles/
```

## Fixing Mistakes

### Amending the Last Commit
```bash
# Change the message:
git commit --amend -m "New message"

# Add forgotten file:
git add forgotten-file.ts
git commit --amend --no-edit  # Keep the message
```

### Undoing Commits
```bash
# Undo last commit, keep changes staged:
git reset --soft HEAD~1

# Undo last commit, keep changes unstaged:
git reset HEAD~1

# Undo last commit, DELETE changes:
git reset --hard HEAD~1  # DANGER: data loss

# Revert a pushed commit (creates a new commit):
git revert abc1234
```

### Fixing Merge Conflicts
```bash
# During merge/rebase conflict:
git status  # See conflicted files

# In conflicted file:
<<<<<<< HEAD
your changes
=======
their changes
>>>>>>> branch-name

# Resolve by editing, then:
git add resolved-file.ts
git merge --continue  # or git rebase --continue

# Abort the whole thing:
git merge --abort
git rebase --abort

# Use a tool:
git mergetool  # Opens configured diff tool (vscode, beyond compare)
```

## Advanced Techniques

### Partial Staging
```bash
# Stage only parts of a file
git add -p file.ts
# Interactively pick hunks: y (yes), n (no), s (split), e (edit)
```

### Worktrees (work on multiple branches simultaneously)
```bash
git worktree add ../project-hotfix hotfix/bug-123
# Creates a new directory with hotfix branch checked out
# Share the same .git, no need to stash/switch

git worktree list
git worktree remove ../project-hotfix
```

### Clean Up
```bash
# Delete merged branches:
git branch --merged | grep -v "main\|dev" | xargs git branch -d

# Prune remote tracking branches:
git remote prune origin

# Garbage collect:
git gc --aggressive  # Compress and clean up repository

# Find large files in history:
git rev-list --objects --all | git cat-file --batch-check | sort -k3nr | head -20
```

## .gitignore Patterns
```gitignore
# Dependencies
node_modules/
.pnp.*

# Build output
dist/
build/
.next/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*

# But NOT these (negate pattern):
!.vscode/settings.json
!.vscode/extensions.json
```

## Commit Message Convention
```
<type>(<scope>): <subject>

[optional body — explain WHY, not WHAT]

[optional footer — BREAKING CHANGE:, Closes #123]
```

Types: feat, fix, docs, chore, refactor, test, perf, ci, style
Subject: present tense, imperative mood ("add" not "added" or "adds"), ≤ 72 chars

## Anti-Patterns

- **Committing secrets**: ever. Rotate immediately if you do
- **`git push --force` on shared branches**: rewrites history others depend on; use `--force-with-lease`
- **Committing generated files**: `dist/`, `.next/`, compiled output — add to .gitignore
- **Large binary files in repo**: use Git LFS or exclude; they bloat the repo forever
- **Merge commits on trivial syncs**: `git pull --rebase` instead of `git pull` (avoids noise)
- **Long-lived branches**: > 3 days — merge conflicts compound, integration becomes painful
