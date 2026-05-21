#!/bin/bash
# check-idempotency.sh — verify setup.sh --link-only is safely re-runnable.
#
# Runs setup.sh --link-only twice in an isolated HOME, then asserts:
#   * identical symlink set between runs
#   * zero prompt / backup / skip output on the second pass
#   * the repo working tree is clean (no rendered templates left behind)
#
# Used by .github/workflows/idempotency.yml; runnable locally too. Lives in
# bin/ (rather than inline in the workflow) so shellcheck covers it via
# bin/lint.sh.
#
# Usage:
#   bash bin/check-idempotency.sh
#
# Env (CI sets these to $RUNNER_TEMP paths; locally they default to mktemp):
#   TEST_HOME  — isolated $HOME for the run
#   SCRATCH    — captured run logs and symlink listings

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="${TEST_HOME:-$(mktemp -d)}"
SCRATCH="${SCRATCH:-$(mktemp -d)}"
mkdir -p "$TEST_HOME" "$SCRATCH"

# Snapshot the working tree so we can flag only changes setup.sh introduced.
# Without this, running locally with any uncommitted work would false-positive
# the porcelain check below.
(cd "$DOTFILES_DIR" && git status --porcelain) >"$SCRATCH/porcelain.before"

run_setup() {
    local log="$1"
    # setup.sh's tail-end doctor.sh emits FAILs for missing brew/fish/etc.;
    # this script is meant to run in a minimal CI image without those tools.
    # The `|| true` in setup.sh keeps it from exiting non-zero on doctor FAILs,
    # but we still capture the output so we can inspect it below.
    set +e
    HOME="$TEST_HOME" bash "$DOTFILES_DIR/setup.sh" --link-only >"$log" 2>&1
    local rc=$?
    set -e
    cat "$log"
    if [ "$rc" -ne 0 ]; then
        echo "::error::setup.sh --link-only exited $rc" >&2
        exit "$rc"
    fi
}

list_symlinks() {
    (cd "$TEST_HOME" && find . -type l | sort |
        xargs -I{} bash -c 'echo "{} -> $(readlink "{}")"')
}

run_setup "$SCRATCH/run1.log"
list_symlinks >"$SCRATCH/links1.txt"

run_setup "$SCRATCH/run2.log"
list_symlinks >"$SCRATCH/links2.txt"

# Symlink set must be identical between runs.
diff -u "$SCRATCH/links1.txt" "$SCRATCH/links2.txt"

# Second run must not have prompted, skipped, or backed anything up.
if grep -E "(already exists|Overwrite|Skipping|backed up to)" "$SCRATCH/run2.log"; then
    echo "::error::setup.sh --link-only is not idempotent — see matches above" >&2
    exit 1
fi

# Repo working tree must not have GAINED any dirt. Catches setup writing
# rendered templates or stray files into the repo — more targeted than
# running setup an Nth time. Diff against the pre-snapshot so uncommitted
# work in a local checkout doesn't false-positive.
cd "$DOTFILES_DIR"
git status --porcelain >"$SCRATCH/porcelain.after"
if ! diff -q "$SCRATCH/porcelain.before" "$SCRATCH/porcelain.after" >/dev/null; then
    echo "::error::setup.sh --link-only dirtied the repo working tree:" >&2
    diff -u "$SCRATCH/porcelain.before" "$SCRATCH/porcelain.after" >&2
    exit 1
fi
