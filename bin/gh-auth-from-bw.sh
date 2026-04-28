#!/bin/bash
# Authenticate `gh` non-interactively using a PAT stored in Bitwarden.
#
# Looks up the Login item `envchain/github/PAT` (created via
# `bin/bw-add-secret.sh github PAT`) in the unlocked vault and pipes its
# password field to `gh auth login --with-token`. Exits non-zero if
# anything is missing, so callers can fall back to an interactive flow.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
# shellcheck source=bin/lib/bw-common.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/bw-common.sh"

bw_require_cmds bw jq gh
bw_is_logged_in
bw_ensure_session

item_name="envchain/github/PAT"
pat=$(bw get item --session "$BW_SESSION" "$item_name" 2>/dev/null \
        | jq -r '.login.password // empty')
[ -n "$pat" ] || { echo "gh-auth-from-bw: no '$item_name' item in vault. Add with: bin/bw-add-secret.sh github PAT" >&2; exit 1; }

printf '%s' "$pat" | gh auth login --git-protocol ssh --with-token
