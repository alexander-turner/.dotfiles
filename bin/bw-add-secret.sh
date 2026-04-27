#!/bin/bash
# Add a new secret to the Bitwarden vault and to envchain in one shot.
#
# Usage: bw-add-secret.sh <namespace> <VAR_NAME>
#
# Reads the secret value from stdin (pipe one in) or interactively prompts
# without echo. The value flows into envchain via stdin and into bw via
# `bw create item`'s JSON, with the value injected through env-var
# substitution in jq's `env.SECRET` — never on argv, never logged.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "$DOTFILES_DIR/bin/lib/bw-common.sh"

usage() {
    echo "Usage: $(basename "$0") <namespace> <VAR_NAME>" >&2
    echo "Reads value from stdin (pipe) or prompts (no echo)." >&2
    exit 2
}

[ $# -eq 2 ] || usage
ns="$1"
var="$2"
item_name="envchain/$ns/$var"

bw_require_cmds bw jq envchain security || exit 1
bw_require_logged_in                    || exit 1
bw_ensure_session                       || exit 1

bw sync --session "$BW_SESSION" >/dev/null 2>&1 || true

# Read value into the SECRET env var. Hidden prompt on TTY, plain stdin
# read otherwise (for piping). Exported because jq references env.SECRET.
read_secret_into_SECRET() {
    if [ -t 0 ]; then
        printf 'Value for %s (hidden): ' "$item_name" >&2
        stty -echo
        IFS= read -r SECRET
        stty echo
        printf '\n' >&2
    else
        IFS= read -r SECRET
    fi
    [ -n "${SECRET:-}" ] || { echo "Empty value; aborting." >&2; exit 1; }
    export SECRET
}

# Mirror the value into envchain locally. Pipe stdin→stdin.
write_envchain() {
    printf '%s' "$SECRET" | envchain --set --noecho "$ns" "$var" >/dev/null
}

# Create the vault item (folder envchain, name $item_name, value env.SECRET).
create_vault_item() {
    local folder_id="$1"
    bw get template item \
        | jq --arg n "$item_name" --arg fid "$folder_id" \
            '.name=$n | .folderId=$fid | .login={"username":null,"password":env.SECRET,"totp":null,"uris":[]} | .notes=null' \
        | bw encode \
        | bw create item --session "$BW_SESSION" >/dev/null
}

read_secret_into_SECRET

folder_id=$(bw_envchain_folder_id --create)

# If the item already exists in the vault, just refresh envchain locally
# and bail. Updating the vault item is an explicit step (bw edit item)
# to avoid silent overwrites.
if bw_item_exists "$folder_id" "$item_name"; then
    write_envchain
    unset SECRET
    echo "Item '$item_name' already in vault; refreshed envchain only."
    echo "To update the vault, use: bw edit item ..."
    exit 0
fi

create_vault_item "$folder_id"
write_envchain
unset SECRET
echo "Added $item_name to vault and envchain."
