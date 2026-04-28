#!/bin/bash
# Authenticate `gh` non-interactively using a PAT stored in Bitwarden.
#
# Looks up a Login item named `github-cli-pat` in the unlocked vault
# and pipes its password field to `gh auth login --with-token`.
# Exits non-zero (silently, unless --verbose) if anything is missing,
# so callers can fall back to an interactive flow.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
# shellcheck source=bin/lib/bw-common.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/bw-common.sh"

bw_require_cmds bw jq gh
bw_is_logged_in
bw_ensure_session

pat=$(bw get item --session "$BW_SESSION" github-cli-pat 2>/dev/null \
        | jq -r '.login.password // empty')
[ -n "$pat" ] || { echo "gh-auth-from-bw: no 'github-cli-pat' item in vault." >&2; exit 1; }

printf '%s' "$pat" | gh auth login --git-protocol ssh --with-token
