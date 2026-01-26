Don't mention Claude in commit messages (no "Co-Authored-By", no "with help from Claude", etc).

Ask me to make a plan before coding anything major.

At the end of a task, if the project is version controlled, commit the changes you made (only your changes, not unrelated uncommitted work).

If you make tests, ensure they are parametrized appropriately and maximally compact while achieving high coverage. Write focused, non-duplicative tests.

When working on tasks that could run in parallel with other Claude instances (e.g., from Vagrant), use git worktrees to avoid conflicts. Create a worktree with a descriptive branch name for your task:
```
git worktree add ../repo-taskname -b taskname
cd ../repo-taskname
```
Clean up your worktree when done (after merging/pushing).
