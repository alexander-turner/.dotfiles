#!/bin/bash
# Run pre-commit in auto-fix mode for the lint CI job
# (`.github/workflows/lint.yml`).
#
# Pre-commit exit code grammar (from pre_commit/error_handler.py):
#   0  — everything passed
#   1  — at least one hook reported failure OR auto-fixed a file
#         (`--show-diff-on-failure` prints the diff)
#   3  — an unhandled Python exception inside pre-commit itself
#         (FATAL — a hook env failed to install, git misbehaved, etc.;
#          a `Check the log at …/pre-commit.log` line is printed)
# 130  — Ctrl-C
#
# The workflow's auto-fix flow wants to swallow 1 (the next commit-and-
# push step will land the fix, and the later verify step will re-run
# hooks for real failures) but must surface 3, because a swallowed 3
# is exactly the case where the verify step then dies with the same
# 3 and no diagnostic context. Hence the explicit branch instead of
# `|| true`.

set -euo pipefail

pip install pre-commit

set +e
pre-commit run --all-files --show-diff-on-failure
rc=$?
set -e

if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
    exit 0
fi

echo "::error::pre-commit exited with rc=$rc (not a hook-modified-files signal); dumping log"
cat "$HOME/.cache/pre-commit/pre-commit.log" 2>/dev/null || true
exit "$rc"
