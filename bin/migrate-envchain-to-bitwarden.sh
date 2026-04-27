#!/bin/bash
# One-time migration: copy each envchain secret into Bitwarden as a
# Login item named envchain/<namespace>/<VAR>, with the secret value in
# the password field. Existing items with the same name are skipped, so
# reruns are idempotent.
#
# Values flow stdin → stdin between envchain and bw via jq's env.SECRET
# substitution. Nothing is logged.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "$DOTFILES_DIR/bin/lib/bw-common.sh"

bw_require_cmds bw jq envchain security || exit 1
bw_require_logged_in                    || exit 1
bw_ensure_session                       || exit 1

bw sync --session "$BW_SESSION" >/dev/null 2>&1 || true
folder_id=$(bw_envchain_folder_id --create)

# Pre-compute the set of existing item names so we can skip in O(1) and
# without re-fetching the listing per item.
existing_names_file=$(mktemp)
trap 'rm -f "$existing_names_file"' EXIT
bw list items --folderid "$folder_id" --session "$BW_SESSION" \
    | jq -r '.[].name' > "$existing_names_file"

# migrate_var: push one envchain (NS, VAR) into the vault. Returns 0 on
# success or skip; only ever prints names + status to stdout (no values).
migrate_var() {
    local ns="$1" var="$2"
    local item_name="envchain/$ns/$var"

    if grep -Fxq "$item_name" "$existing_names_file"; then
        echo "  skip   $item_name (already in vault)"
        return 0
    fi

    local value
    value=$(envchain "$ns" printenv "$var")
    if [ -z "$value" ]; then
        echo "  WARN   $item_name (envchain returned empty)"
        return 0
    fi

    SECRET="$value" bw get template item \
        | jq --arg n "$item_name" --arg fid "$folder_id" \
            '.name=$n | .folderId=$fid | .login={"username":null,"password":env.SECRET,"totp":null,"uris":[]} | .notes=null' \
        | bw encode \
        | bw create item --session "$BW_SESSION" >/dev/null
    unset value
    echo "  ok     $item_name"
}

# Iterate every namespace except brew-sudo (the brew autoupdate flow now
# uses a NOPASSWD sudoers fragment — see etc/sudoers.d/brew-autoupdate).
for ns in $(envchain --list); do
    if [ "$ns" = "brew-sudo" ]; then
        echo "Skipping brew-sudo (replaced by NOPASSWD sudoers)."
        continue
    fi
    echo "Namespace: $ns"
    while IFS= read -r var; do
        [ -n "$var" ] && migrate_var "$ns" "$var"
    done < <(envchain --list "$ns")
done

bw sync --session "$BW_SESSION" >/dev/null
echo "Migration complete. Verify with:"
echo "  bw list items --folderid $folder_id | jq -r '.[].name'"
