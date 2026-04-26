#!/bin/bash
# One-time migration: copy each envchain secret into Bitwarden as a
# Login item named envchain/<namespace>/<VAR>, with the secret value in
# the Login item's password field. Existing Bitwarden items with the
# same name are left alone (skip-on-conflict) so reruns are idempotent.
#
# Secret-handling: values flow stdin → stdin between envchain and bw.
# This script never echoes a value to its own stdout/stderr; only var
# NAMES and status messages are printed.
#
# Prerequisites:
#   - bw (the official Bitwarden CLI; brew install bitwarden-cli)
#   - envchain (the source-of-truth being retired)
#   - jq
#   - $BW_SESSION must be exported (run `bw login` then `bw unlock` and
#     `export BW_SESSION=$(bw unlock --raw)` first).
#
# Why bw rather than rbw? bw has first-class JSON-based item creation
# (--in for stdin), which is the cleanest way to inject a value without
# it appearing on a command line.

set -euo pipefail

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require envchain
require bw
require jq

if [ -z "${BW_SESSION:-}" ]; then
    echo "BW_SESSION not set. Run: export BW_SESSION=\$(bw unlock --raw)" >&2
    exit 1
fi

bw sync >/dev/null

# Find or create the destination folder.
folder_name="envchain"
folder_id=$(bw list folders --session "$BW_SESSION" \
    | jq -r --arg n "$folder_name" '.[] | select(.name==$n) | .id' \
    | head -n1)
if [ -z "$folder_id" ]; then
    folder_id=$(bw get template folder \
        | jq --arg n "$folder_name" '.name=$n' \
        | bw encode \
        | bw create folder --session "$BW_SESSION" \
        | jq -r '.id')
    echo "Created Bitwarden folder: $folder_name ($folder_id)"
fi

# Build a quick lookup of existing item names so we can skip conflicts
# without listing values.
existing_names_file=$(mktemp)
trap 'rm -f "$existing_names_file"' EXIT
bw list items --folderid "$folder_id" --session "$BW_SESSION" \
    | jq -r '.[].name' > "$existing_names_file"

migrate_var() {
    local ns="$1"
    local var="$2"
    local item_name="envchain/$ns/$var"

    if grep -Fxq "$item_name" "$existing_names_file"; then
        echo "  skip   $item_name (already in vault)"
        return 0
    fi

    # Build the item template, inject the value via env var (read by jq
    # from the environment so it never appears on argv), encode, create.
    # The value never touches this script's stdout/stderr.
    local value
    value=$(envchain "$ns" printenv "$var")
    if [ -z "$value" ]; then
        echo "  WARN   $item_name (envchain returned empty; skipped)"
        return 0
    fi

    SECRET="$value" \
        bw get template item \
        | jq --arg n "$item_name" --arg fid "$folder_id" \
              '.name=$n | .folderId=$fid | .login={"username":null,"password":env.SECRET,"totp":null,"uris":[]} | .notes=null' \
        | bw encode \
        | bw create item --session "$BW_SESSION" >/dev/null
    unset value SECRET
    echo "  ok     $item_name"
}

for ns in $(envchain --list); do
    if [ "$ns" = "brew-sudo" ]; then
        echo "Skipping brew-sudo (replaced by NOPASSWD sudoers; nothing to migrate)."
        continue
    fi
    echo "Namespace: $ns"
    while IFS= read -r var; do
        [ -z "$var" ] && continue
        migrate_var "$ns" "$var"
    done < <(envchain --list "$ns")
done

bw sync >/dev/null
echo "Migration complete. Verify with: bw list items --folderid $folder_id | jq -r '.[].name'"
