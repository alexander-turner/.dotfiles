#!/bin/bash
# Commit any tree mutations the lint --fix pass made and push back to the
# PR branch. Invoked from .github/workflows/lint.yml's auto-fix job —
# extracted here so shellcheck/shfmt cover it (inline `run:` blocks skip
# the lint pipeline; see CLAUDE.md → "Workflow shell scripts live in bin/").
#
# Exits 0 with no commit when the working tree is clean.

set -euo pipefail

if git diff --quiet; then
    exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Stage by explicit pathspec — we only want changes the linters wrote.
# `git add -A` could sweep up artifacts a future CI step happens to drop.
git add -u
git commit -m "style: auto-fix lint issues [skip ci]"
git push
