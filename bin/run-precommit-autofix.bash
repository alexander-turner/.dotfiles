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

# Tee through a temp file so we can re-emit the most diagnostic lines as
# GitHub annotations on failure (workflow log requires sign-in to read,
# annotations show up on the public run page).
out=$(mktemp)
trap 'rm -f "$out"' EXIT

set +e
pre-commit run --all-files --show-diff-on-failure 2>&1 | tee "$out"
rc=${PIPESTATUS[0]}
set -e

if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
    exit 0
fi

echo "::error::pre-commit exited with rc=$rc (FATAL, not a hook-modified-files signal)"

# Pre-commit's error_handler prints "An unexpected error has occurred: ..."
# to stdout and references a log file. Surface both as annotations.
grep -E "An unexpected error|Check the log at|FatalError|^Traceback" "$out" |
    while IFS= read -r line; do
        echo "::error::$line"
    done

log_path=$(grep -oE "Check the log at \S+" "$out" | awk '{print $NF}' | head -1)
log_path=${log_path:-$HOME/.cache/pre-commit/pre-commit.log}
if [ -f "$log_path" ]; then
    echo "::group::pre-commit.log ($log_path)"
    cat "$log_path"
    echo "::endgroup::"
    # Re-emit the traceback as an error so it lands in the annotations panel.
    awk '/^Traceback/,/^$/' "$log_path" | while IFS= read -r line; do
        echo "::error::$line"
    done
else
    echo "::error::pre-commit.log not found at $log_path (pre-commit failed before creating its store directory)"
fi

exit "$rc"
