#!/usr/bin/env bash
# Round-trip check: setup.sh --link-only must produce some symlinks into the
# dotfiles repo, and uninstall.sh --yes must remove all of them. Enforces the
# CLAUDE.md "Uninstall upkeep" invariant — every safe_link in setup.sh whose
# target lives in $HOME has a matching entry in bin/lib/symlinks.sh, so
# uninstall.sh sees it.
#
# Scope matches uninstall.sh's documented scope: symlinks only. setup.sh also
# creates touch-files (.extras.bash, .hushlogin, …) and parent dirs under
# ~/.config; uninstall.sh intentionally leaves those, so this script ignores
# them too.
#
# Run locally:  HOME=$(mktemp -d) bash bin/test-uninstall-roundtrip.sh
# In CI:        invoked by .github/workflows/uninstall.yml on every push/PR.
#
# Side effects: creates symlinks under $HOME, then removes them. Run with an
# isolated $HOME — never against a real one.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# List every symlink under $HOME that points into the dotfiles repo. That's
# the set uninstall.sh is responsible for.
repo_symlinks() {
    find "$HOME" -type l 2>/dev/null | sort | while read -r link; do
        local tgt
        tgt="$(readlink "$link")"
        case "$tgt" in
        "$DOTFILES_DIR"/*) printf '%s -> %s\n' "$link" "$tgt" ;;
        esac
    done
}

set +e
bash "$DOTFILES_DIR/setup.sh" --link-only >setup.log 2>&1
rc=$?
set -e
cat setup.log
if [ $rc -ne 0 ]; then
    echo "::error::setup.sh --link-only exited $rc" >&2
    exit $rc
fi

repo_symlinks >installed.txt
if [ ! -s installed.txt ]; then
    echo "::error::setup.sh --link-only produced zero symlinks into the repo — test is no longer testing anything." >&2
    exit 1
fi
echo "--- symlinks setup.sh created (uninstall.sh must remove these) ---"
cat installed.txt

set +e
bash "$DOTFILES_DIR/bin/uninstall.sh" --yes >uninstall.log 2>&1
rc=$?
set -e
cat uninstall.log
if [ $rc -ne 0 ]; then
    echo "::error::uninstall.sh --yes exited $rc" >&2
    exit $rc
fi

repo_symlinks >leftover.txt
if [ -s leftover.txt ]; then
    echo "--- symlinks into the repo that survived uninstall.sh ---"
    cat leftover.txt
    echo "::error::uninstall.sh left repo-pointing symlinks in \$HOME. Likely cause: a safe_link in setup.sh has no matching entry in bin/lib/symlinks.sh, so uninstall.sh never sees it. See CLAUDE.md → 'Uninstall upkeep'." >&2
    exit 1
fi

echo "Round-trip OK."
