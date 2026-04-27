#!/bin/bash
# Pull each item in the Bitwarden `envchain` folder down into envchain.
#
# Item naming convention: envchain/<namespace>/<VAR>. The Login item's
# password field holds the value. The script never echoes a value to its
# own stdout/stderr; values transit only stdin→stdin between bw and envchain.
#
# Auth flow: bw must already be `bw login`-ed (one-time per machine, via
# bin/bw-login.sh which uses the API-key flow to bypass WebAuthn 2FA).
# This script picks up BW_SESSION from $BW_SESSION if exported, otherwise
# unlocks using the master password cached in macOS Keychain under
# service `bw-master-password`. After unlock, it iterates the envchain
# folder and refreshes envchain entries.
#
# Flags:
#   --quiet   suppress per-item output (used by shell-startup autosync).

set -euo pipefail

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help)
            sed -n 's/^# \{0,1\}//p' "$0" | head -n 20
            exit 0
            ;;
    esac
done

log() { [ "$QUIET" -eq 1 ] || echo "$@"; }
err() { echo "$@" >&2; }

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "Missing required command: $1"
        exit 1
    fi
}

require bw
require jq
require envchain
require security

# Ensure logged in.
status_json=$(bw status --raw 2>/dev/null || echo '{}')
auth_status=$(printf '%s' "$status_json" | jq -r '.status // "unauthenticated"')
if [ "$auth_status" = "unauthenticated" ]; then
    err "bw: not logged in. Run bin/bw-login.sh (or 'bw login --apikey' with BW_CLIENTID/BW_CLIENTSECRET)."
    exit 1
fi

# Get a session. Prefer an already-exported BW_SESSION; otherwise unlock
# from a master password cached in the macOS Keychain.
if [ -z "${BW_SESSION:-}" ]; then
    if mp=$(security find-generic-password -s bw-master-password -a "$USER" -w 2>/dev/null); then
        # Pipe the password into bw via stdin; never appears on argv.
        BW_SESSION=$(printf '%s' "$mp" | bw unlock --raw --passwordenv BW_DUMMY 2>/dev/null \
            || printf '%s' "$mp" | bw unlock --raw 2>/dev/null) || {
            err "bw unlock: cached master password rejected. Re-run setup.sh."
            unset mp
            exit 1
        }
        unset mp
    else
        err "bw: locked and no cached master password. Set BW_SESSION or run setup.sh."
        exit 1
    fi
fi
export BW_SESSION

# Refresh local encrypted vault.
bw sync --session "$BW_SESSION" >/dev/null 2>&1 || true

# Locate the envchain folder.
folder_id=$(bw list folders --session "$BW_SESSION" \
    | jq -r '.[] | select(.name=="envchain") | .id' | head -n1)
if [ -z "$folder_id" ]; then
    err "No 'envchain' folder in vault — nothing to seed."
    exit 0
fi

# Iterate items in the folder. We extract id + name only (no values) at
# the listing step, then fetch each value individually and pipe it
# straight into envchain.
items_json=$(bw list items --folderid "$folder_id" --session "$BW_SESSION")

count=$(printf '%s' "$items_json" | jq 'length')
log "Seeding $count items from Bitwarden folder envchain → envchain..."

printf '%s' "$items_json" | jq -r '.[] | "\(.id)\t\(.name)"' \
    | while IFS=$'\t' read -r id name; do
        # Parse "envchain/<ns>/<VAR>"
        ns=$(printf '%s' "$name" | awk -F/ '{print $2}')
        var=$(printf '%s' "$name" | awk -F/ '{print $3}')
        if [ -z "$ns" ] || [ -z "$var" ] || [ "$(printf '%s' "$name" | awk -F/ '{print $1}')" != "envchain" ]; then
            log "  skip   $name (not in envchain/<ns>/<VAR> format)"
            continue
        fi
        # Fetch value and pipe directly into envchain --set --noecho.
        # Values touch only the pipe between two child processes.
        if bw get password --session "$BW_SESSION" "$id" \
            | envchain --set --noecho "$ns" "$var" >/dev/null 2>&1; then
            log "  ok     $ns/$var"
        else
            err "  FAIL   $ns/$var (bw or envchain returned non-zero)"
        fi
    done

log "Seed complete."
