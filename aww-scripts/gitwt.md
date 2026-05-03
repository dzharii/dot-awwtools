# Git Worktree Reference

Git worktrees let one Git repository have multiple working folders checked out at the same time.

Use them when you want to work on another branch without disturbing your current folder.

```text
my-app/
my-app-hotfix/
my-app-review/
```

Each folder has its own checked-out files. The folders share the same Git history and object database.

------

## Core Commands

------

```powershell
git worktree list
```

Shows worktrees attached to the current repository.

```powershell
git worktree add ../my-app-hotfix main
```

Creates a new worktree at `../my-app-hotfix` from `main`.

```powershell
git worktree add -b hotfix/payment-crash ../my-app-hotfix main
```

Creates a new branch `hotfix/payment-crash` from `main`, then checks it out in the new worktree.

```powershell
git worktree add --detach ../my-app-review origin/some-branch
```

Creates a new detached worktree from `origin/some-branch`.

```powershell
git worktree remove ../my-app-hotfix
```

Removes a worktree.

```powershell
git worktree prune
```

Cleans stale worktree metadata for folders that no longer exist.

------

## What A Worktree Is

------

A normal Git repository usually has one working folder.

```text
my-app/
  .git/
  src/
```

Only one branch is checked out in that folder at a time. When you switch branches, Git changes the files in that folder.

A repository with worktrees can have several folders.

```text
my-app/
my-app-feature-search/
my-app-hotfix/
my-app-release/
```

Each folder can be on a different branch or commit.

```text
my-app/                 main
my-app-feature-search/  feature/search
my-app-hotfix/          hotfix/payment-crash
my-app-release/         release/2026-05
```

Outcome:

```text
You can keep separate tasks in separate folders.
You do not need to stash just to inspect or edit another branch.
Build artifacts and editor state can stay isolated per folder.
```

------

## List Worktrees

------

Use:

```powershell
git worktree list
```

Example:

```text
/home/me/code/my-app                  a1b2c3d [main]
/home/me/code/my-app-feature-search   d4e5f6a [feature/search]
/home/me/code/my-app-hotfix           9a0b1c2 [hotfix/payment-crash]
```

Meaning:

```text
/home/me/code/my-app                  folder path
a1b2c3d                               checked-out commit
[main]                                checked-out branch
```

Use this when you need to see which worktrees already exist.

------

## Create A Worktree From An Existing Branch

------

Use:

```powershell
git worktree add ../my-app-feature-search feature/search
```

Outcome:

```text
A new folder is created at ../my-app-feature-search.
The existing branch feature/search is checked out there.
The current folder is not changed.
```

Then work normally:

```powershell
cd ../my-app-feature-search
git status
git add .
git commit -m "Update search feature"
```

Important: Git usually does not allow the same local branch to be checked out in two worktrees at once.

If `feature/search` is already checked out somewhere else, this command can fail.

------

### Create A Worktree With A New Branch

------

Use:

```powershell
git worktree add -b feature/search-v2 ../my-app-search-v2 main
```

Meaning:

```text
-b feature/search-v2      create this new branch
../my-app-search-v2       create the worktree here
main                      start the new branch from main
```

Outcome:

```text
A new branch feature/search-v2 is created from main.
A new folder ../my-app-search-v2 is created.
The new branch is checked out in that folder.
```

Then:

```powershell
cd ../my-app-search-v2
git status
```

This is one of the most common worktree commands.

------

## Create A Worktree From A Remote Branch

------

First fetch remote updates:

```powershell
git fetch
```

Then create a local branch from the remote branch:

```powershell
git worktree add -b review/some-branch ../my-app-review origin/some-branch
```

Outcome:

```text
A new local branch review/some-branch is created.
It starts from origin/some-branch.
The branch is checked out in ../my-app-review.
```

This is useful for reviewing another branch without disturbing your current folder.

Alternative detached version:

```powershell
git worktree add --detach ../my-app-review origin/some-branch
```

Outcome:

```text
The worktree is created from the remote branch commit.
No local branch is created.
This is useful for read-only review or quick inspection.
```

------

## Create A Detached Worktree

------

Use:

```powershell
git worktree add --detach ../my-app-inspect main
```

Outcome:

```text
A new folder is created from main.
No branch is checked out.
The worktree points directly at a commit.
```

Detached worktrees are useful when you want to inspect, build, or test code without moving a branch.

Create a branch later:

```powershell
cd ../my-app-inspect
git switch -c experiment/build-check
```

Outcome:

```text
The detached worktree becomes a normal branch worktree.
New commits will move experiment/build-check.
```

------

## Hotfix Workflow

------

Starting situation:

```text
my-app/    feature/search
```

Create a hotfix worktree from `main`:

```powershell
git worktree add -b hotfix/payment-crash ../my-app-hotfix main
```

Move into it:

```powershell
cd ../my-app-hotfix
```

Make the fix:

```powershell
git status
git add .
git commit -m "Fix payment crash"
git push -u origin hotfix/payment-crash
```

Outcome:

```text
The original feature/search folder stays untouched.
The hotfix work happens in ../my-app-hotfix.
The hotfix branch can be reviewed and merged separately.
```

------

## Pull Request Review Workflow

------

Fetch the latest remote state:

```powershell
git fetch
```

Create a review worktree:

```powershell
git worktree add -b review/login-redesign ../my-app-review-login origin/login-redesign
```

Move into it:

```powershell
cd ../my-app-review-login
```

Run checks:

```powershell
git status
npm install
npm test
```

Outcome:

```text
The review branch is isolated in its own folder.
Your current branch and local changes stay untouched.
You can delete the review worktree after review.
```

------

## Release Branch Workflow

------

Create a worktree for a release branch:

```powershell
git worktree add ../my-app-release release/2026-05
```

Move into it:

```powershell
cd ../my-app-release
```

Use it for release-only work:

```powershell
git status
git pull
```

Outcome:

```text
The release branch stays available in a stable folder.
Feature work can continue elsewhere.
Switching between release and feature work does not require stashing.
```

------

## Remove A Worktree

------

Use:

```powershell
git worktree remove ../my-app-hotfix
```

Outcome:

```text
The worktree folder is deleted.
Git unregisters it as a worktree.
The branch is not deleted.
```

If Git refuses because the worktree has local changes:

```powershell
git worktree remove --force ../my-app-hotfix
```

Outcome:

```text
The worktree is removed even if local changes exist.
Uncommitted work in that folder is discarded.
```

Use `--force` only when those local changes are not needed.

------

## Clean Stale Worktree Records

------

If a worktree folder was deleted manually:

```powershell
rm -rf ../my-app-hotfix
```

Git may still remember it.

Clean stale records:

```powershell
git worktree prune
```

Outcome:

```text
Git removes metadata for missing worktree folders.
Existing worktrees are not deleted.
```

Check again:

```powershell
git worktree list
```

------

## Lock A Worktree

------

Use:

```powershell
git worktree lock ../my-app-release
```

Outcome:

```text
The worktree is protected from pruning.
```

Add a reason:

```powershell
git worktree lock --reason "release branch kept on external drive" ../my-app-release
```

Unlock it:

```powershell
git worktree unlock ../my-app-release
```

Locking is useful for worktrees on removable drives or locations that may be temporarily unavailable.

------

## Move A Worktree

------

Use:

```powershell
git worktree move ../my-app-review ../reviews/my-app-review
```

Outcome:

```text
The worktree folder is moved.
Git updates its worktree metadata.
```

Use this instead of manually moving the folder.

------

## Repair Worktree Metadata

------

Use:

```powershell
git worktree repair
```

Outcome:

```text
Git repairs worktree administrative files when possible.
```

This is useful after moving repository folders manually or restoring them from backup.

If a specific path needs repair:

```powershell
git worktree repair ../my-app-review
```

------

## Branch Checkout Rules

------

A local branch usually cannot be checked out in two worktrees at once.

This can fail:

```powershell
git worktree add ../another-main main
```

If `main` is already checked out elsewhere, use a new branch:

```powershell
git worktree add -b test-main ../another-main main
```

Or use a detached worktree:

```powershell
git worktree add --detach ../another-main main
```

Outcome:

```text
A new branch is best for editing.
A detached worktree is best for inspecting, building, or testing.
```

------

## Uncommitted Changes

------

Uncommitted changes are local to one worktree folder.

If this folder has edits:

```text
my-app/    feature/search    3 changed files
```

Creating another worktree does not copy those edits:

```powershell
git worktree add -b hotfix/payment-crash ../my-app-hotfix main
```

Outcome:

```text
../my-app-hotfix starts from committed Git history.
Uncommitted files in my-app/ stay only in my-app/.
```

To carry current edits elsewhere, commit or stash first.

Commit:

```powershell
git add .
git commit -m "Save current work"
```

Stash:

```powershell
git stash push -m "temporary work"
```

Then apply in another worktree if needed:

```powershell
git stash list
git stash apply
```

------

## Mental Model

------

```text
Repository    shared Git database and history
Worktree      one working folder
Branch        movable name pointing to a commit
Commit        saved snapshot
HEAD          current checked-out branch or commit
```

A worktree is not a copy of the repository history. It is another working folder attached to the same repository.

This is why creating a worktree is usually faster and smaller than cloning the repository again.

------

## Common Mistakes

------

Deleting a worktree folder manually can leave stale Git metadata.

Use:

```powershell
git worktree remove ../my-app-hotfix
```

If already deleted manually:

```powershell
git worktree prune
```

Trying to reuse the same branch in two worktrees can fail.

Use:

```powershell
git worktree add -b new-task ../my-app-new-task main
```

Creating worktrees inside the repository folder can make paths messy.

Prefer sibling folders:

```text
my-app/
my-app-new-task/
my-app-hotfix/
```

Not:

```text
my-app/
  my-app-new-task/
  src/
```

------

## Quick Reference

------

```powershell
# Show all worktrees
git worktree list

# Create a worktree from an existing branch
git worktree add ../my-app-feature feature/search

# Create a worktree with a new branch
git worktree add -b feature/search-v2 ../my-app-search-v2 main

# Create a detached worktree
git worktree add --detach ../my-app-inspect main

# Create a worktree from a remote branch
git fetch
git worktree add -b review/some-branch ../my-app-review origin/some-branch

# Remove a worktree
git worktree remove ../my-app-review

# Force remove a worktree
git worktree remove --force ../my-app-review

# Clean stale records
git worktree prune

# Lock and unlock a worktree
git worktree lock ../my-app-release
git worktree unlock ../my-app-release

# Move a worktree
git worktree move ../my-app-review ../reviews/my-app-review

# Repair worktree metadata
git worktree repair
```
