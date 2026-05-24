#!/bin/bash
# check-idempotency.bash — verify setup.bash --link-only is safely re-runnable.
#
# Runs setup.bash --link-only twice in an isolated HOME, then asserts:
#   * identical symlink set between runs
#   * zero prompt / backup / skip output on the second pass
#   * the repo working tree is clean (no rendered templates left behind)
#
# Used by .github/workflows/idempotency.yml; runnable locally too. Lives in
# bin/ (rather than inline in the workflow) so it gets shellcheck coverage
# via the pre-commit hook declared in .pre-commit-config.yaml.
#
# Usage:
#   bash bin/check-idempotency.bash
#
# Env (CI sets these to $RUNNER_TEMP paths; locally they default to mktemp):
#   TEST_HOME  — isolated $HOME for the run
#   SCRATCH    — captured run logs and symlink listings

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="${TEST_HOME:-$(mktemp -d)}"
SCRATCH="${SCRATCH:-$(mktemp -d)}"
mkdir -p "$TEST_HOME" "$SCRATCH"

# Snapshot the working tree so we can flag only changes setup.bash introduced.
# Without this, running locally with any uncommitted work would false-positive
# the porcelain check below.
(cd "$DOTFILES_DIR" && git status --porcelain) >"$SCRATCH/porcelain.before"

run_setup() {
    local log="$1"
    # setup.bash's tail-end doctor.bash emits FAILs for missing brew/fish/etc.;
    # this script is meant to run in a minimal CI image without those tools.
    # The `|| true` in setup.bash keeps it from exiting non-zero on doctor FAILs,
    # but we still capture the output so we can inspect it below.
    set +e
    HOME="$TEST_HOME" bash "$DOTFILES_DIR/setup.bash" --link-only >"$log" 2>&1
    local rc=$?
    set -e
    cat "$log"
    if [ "$rc" -ne 0 ]; then
        echo "::error::setup.bash --link-only exited $rc" >&2
        exit "$rc"
    fi
}

list_symlinks() {
    while IFS= read -r link; do
        printf '%s -> %s\n' "$link" "$(readlink "$TEST_HOME/${link#./}")"
    done < <(cd "$TEST_HOME" && find . -type l | sort)
}

run_setup "$SCRATCH/run1.log"
list_symlinks >"$SCRATCH/links1.txt"

run_setup "$SCRATCH/run2.log"
list_symlinks >"$SCRATCH/links2.txt"

# Symlink set must be identical between runs.
diff -u "$SCRATCH/links1.txt" "$SCRATCH/links2.txt"

# Second run must not have prompted, skipped, or backed anything up.
if grep -E "(already exists|Overwrite|Skipping|backed up to)" "$SCRATCH/run2.log"; then
    echo "::error::setup.bash --link-only is not idempotent — see matches above" >&2
    exit 1
fi

# Repo working tree must not have GAINED any dirt. Catches setup writing
# rendered templates or stray files into the repo — more targeted than
# running setup an Nth time. Diff against the pre-snapshot so uncommitted
# work in a local checkout doesn't false-positive.
cd "$DOTFILES_DIR"
git status --porcelain >"$SCRATCH/porcelain.after"
if ! diff -q "$SCRATCH/porcelain.before" "$SCRATCH/porcelain.after" >/dev/null; then
    echo "::error::setup.bash --link-only dirtied the repo working tree:" >&2
    diff -u "$SCRATCH/porcelain.before" "$SCRATCH/porcelain.after" >&2
    exit 1
fi
