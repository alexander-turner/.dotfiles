#!/bin/bash
# Pull each item in the Bitwarden `envchain` folder down into envchain.
#
# Item naming convention: envchain/<namespace>/<VAR>. The Login item's
# password field holds the value. Values transit only stdin→stdin between
# bw and envchain — never on argv, never logged.
#
# Auth: bw must already be `bw login`-ed (one-time per machine via
# bin/bw-login.sh). This script picks up $BW_SESSION if exported, else
# unlocks via the cached master password (see bin/lib/bw-common.sh).
#
# Flags:
#   --quiet   suppress per-item output (used by shell-startup autosync).

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
source "$DOTFILES_DIR/bin/lib/bw-common.sh"

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        -h|--help) sed -n 's/^# \{0,1\}//p' "$0" | head -n 14; exit 0 ;;
    esac
done

log() { [ "$QUIET" -eq 1 ] || echo "$@"; }
err() { echo "$@" >&2; }

bw_require_cmds bw jq envchain security awk || exit 1
bw_require_logged_in                          || exit 1
bw_ensure_session                             || exit 1

bw sync --session "$BW_SESSION" >/dev/null 2>&1 || true

folder_id=$(bw_envchain_folder_id) || exit 0  # nothing to seed yet

# seed_one: parse `envchain/<ns>/<VAR>`, fetch the password, pipe it into
# `envchain --set --noecho`. Skips items not matching the naming scheme.
seed_one() {
    local id="$1" name="$2"
    local prefix ns var
    IFS=/ read -r prefix ns var <<<"$name"
    if [ "$prefix" != "envchain" ] || [ -z "$ns" ] || [ -z "$var" ]; then
        log "  skip   $name (not in envchain/<ns>/<VAR> format)"
        return 0
    fi
    if bw get password --session "$BW_SESSION" "$id" \
            | envchain --set --noecho "$ns" "$var" >/dev/null 2>&1; then
        log "  ok     $ns/$var"
    else
        err "  FAIL   $ns/$var"
    fi
}

items_json=$(bw list items --folderid "$folder_id" --session "$BW_SESSION")
count=$(printf '%s' "$items_json" | jq 'length')
log "Seeding $count items from Bitwarden folder envchain → envchain..."

while IFS=$'\t' read -r id name; do
    [ -z "$id" ] && continue
    seed_one "$id" "$name"
done < <(printf '%s' "$items_json" | jq -r '.[] | "\(.id)\t\(.name)"')

log "Seed complete."
