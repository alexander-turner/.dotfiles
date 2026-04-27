#!/bin/bash
# Add a new secret to the Bitwarden vault and to envchain in one shot.
#
# Usage: bw-add-secret.sh <namespace> <VAR_NAME>
#
# Reads the secret value from stdin (pipe one in) or interactively prompts
# without echo. The value flows into envchain via stdin and into bw via
# stdin (`bw create item` reads JSON; the value is injected via env-var
# substitution in jq's `env.SECRET`, never on argv). Nothing is logged.

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <namespace> <VAR_NAME>" >&2
    echo "Reads value from stdin (pipe) or prompts (no echo)." >&2
    exit 2
}

[ $# -eq 2 ] || usage
ns="$1"
var="$2"

require() {
    command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require bw
require jq
require envchain

# Authenticate.
status_json=$(bw status --raw 2>/dev/null || echo '{}')
auth_status=$(printf '%s' "$status_json" | jq -r '.status // "unauthenticated"')
if [ "$auth_status" = "unauthenticated" ]; then
    echo "bw: not logged in. Run bin/bw-login.sh first." >&2
    exit 1
fi

if [ -z "${BW_SESSION:-}" ]; then
    if mp=$(security find-generic-password -s bw-master-password -a "$USER" -w 2>/dev/null); then
        # See bw-login.sh for why we use --passwordenv instead of stdin.
        BW_SESSION=$(BW_PASSWORD="$mp" bw unlock --raw --passwordenv BW_PASSWORD 2>/dev/null) || {
            echo "bw unlock failed; re-run setup.sh." >&2
            unset mp
            exit 1
        }
        unset mp
    else
        echo "bw: locked. Export BW_SESSION or run setup.sh to cache master password." >&2
        exit 1
    fi
fi
export BW_SESSION

bw sync --session "$BW_SESSION" >/dev/null 2>&1 || true

# Read value from stdin (preferred for piping) or prompt without echo.
if [ -t 0 ]; then
    printf 'Value for envchain/%s/%s (hidden): ' "$ns" "$var" >&2
    stty -echo
    IFS= read -r SECRET
    stty echo
    printf '\n' >&2
else
    IFS= read -r SECRET
fi
[ -n "$SECRET" ] || { echo "Empty value; aborting." >&2; exit 1; }
export SECRET  # required for jq's env.SECRET

# Find or create the envchain folder.
folder_id=$(bw list folders --session "$BW_SESSION" \
    | jq -r '.[] | select(.name=="envchain") | .id' | head -n1)
if [ -z "$folder_id" ]; then
    folder_id=$(bw get template folder \
        | jq '.name="envchain"' \
        | bw encode \
        | bw create folder --session "$BW_SESSION" \
        | jq -r '.id')
fi

item_name="envchain/$ns/$var"

# Skip if the item already exists in the vault — update path is manual to
# avoid accidental overwrites.
if bw list items --folderid "$folder_id" --session "$BW_SESSION" \
    | jq -e --arg n "$item_name" '.[] | select(.name==$n)' >/dev/null; then
    echo "Item '$item_name' already exists in vault. Use 'bw edit item ...' to change it." >&2
    # Still update envchain so the local cache matches the bw vault value.
    printf '%s' "$SECRET" | envchain --set --noecho "$ns" "$var" >/dev/null
    echo "Refreshed envchain $ns/$var from supplied value."
    unset SECRET
    exit 0
fi

# Create the vault item with value from env.
bw get template item \
    | jq --arg n "$item_name" --arg fid "$folder_id" \
        '.name=$n | .folderId=$fid | .login={"username":null,"password":env.SECRET,"totp":null,"uris":[]} | .notes=null' \
    | bw encode \
    | bw create item --session "$BW_SESSION" >/dev/null

# And mirror into envchain locally.
printf '%s' "$SECRET" | envchain --set --noecho "$ns" "$var" >/dev/null

unset SECRET
echo "Added $item_name to vault and envchain."
