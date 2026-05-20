#!/bin/bash
# PostToolUse hook: after `git push` or `gh pr create`, watch the PR's
# CI checks so Claude sees the result without polling manually.
#
# Behaviour:
#   * No-ops cleanly when gh is unavailable, when the branch isn't
#     detectable (detached HEAD), or when no PR exists for the branch
#     after a short poll window.
#   * Uses a per-session log path so concurrent sessions don't clobber
#     each other's output.

set -uo pipefail

# gh is optional — if it's not installed, there's nothing to watch.
command -v gh >/dev/null 2>&1 || exit 0

branch=$(git branch --show-current 2>/dev/null)
if [ -z "$branch" ]; then
    echo "ci-watch: no current branch (detached HEAD?), skipping"
    exit 0
fi

# Poll briefly for a PR matching the pushed branch. Try once immediately
# (the happy path after `gh pr create` or a push to an existing PR), then
# retry a few times in case GitHub is still reflecting the push.
# `pr` is set to empty if gh fails — the assignment itself doesn't error
# the script under `set -uo pipefail`, so no `|| fallback` is needed.
pr=""
for attempt in 1 2 3; do
    pr=$(gh pr list --head "$branch" --state open --json number \
        --jq '.[0].number' 2>/dev/null)
    [ -n "$pr" ] && break
    [ "$attempt" -lt 3 ] && sleep 5
done

if [ -z "$pr" ]; then
    echo "ci-watch: no open PR for branch '$branch', skipping"
    exit 0
fi

log=$(mktemp "${TMPDIR:-/tmp}/claude-ci-watch-XXXXXX.log")
trap 'rm -f "$log"' EXIT

echo "ci-watch: watching CI for PR #$pr (branch '$branch')"
timeout 300 gh pr checks "$pr" --watch >"$log" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then
    echo "ci-watch: CI passed for PR #$pr"
else
    echo "ci-watch: CI failed for PR #$pr (exit $rc) — last output:"
    tail -20 "$log"
fi
