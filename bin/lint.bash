#!/bin/bash
# Thin wrapper around `pre-commit run --all-files`. Hooks are declared in
# .pre-commit-config.yaml — see that file to add/adjust a check. The
# pre-commit framework handles tool installation (cached per repo in
# ~/.cache/pre-commit), parallel execution, and file-pattern filtering.
#
# Usage:
#   bash bin/lint.bash         # run all hooks against all tracked files
#   bash bin/lint.bash --fix   # accepted for backwards compat; pre-commit
#                              # always edits files in place (no separate flag)
#   bash bin/lint.bash --ci    # accepted for backwards compat; no behavior diff
#
# Any remaining args are forwarded to `pre-commit run`. To target a single
# hook, run `pre-commit run <hook-id> --all-files` directly.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if ! command -v pre-commit >/dev/null 2>&1; then
    cat >&2 <<EOF
pre-commit is not installed. Install with:
  uv tool install pre-commit --with pre-commit-uv
EOF
    exit 127
fi

# Drop legacy --ci/--fix flags from the forwarded args; pre-commit auto-fixes
# in place and treats CI vs. local the same.
forwarded=()
for arg in "$@"; do
    case "$arg" in
    --ci | --fix) ;;
    *) forwarded+=("$arg") ;;
    esac
done

exec pre-commit run --all-files --show-diff-on-failure "${forwarded[@]+"${forwarded[@]}"}"
