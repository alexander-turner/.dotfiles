#!/bin/bash
# One-time-per-machine bw login using a Bitwarden personal API key.
#
# Why API key: WebAuthn-only accounts can't `bw login` interactively (bw
# doesn't support WebAuthn). The personal API key bypasses 2FA at login
# but does not unlock the vault, so the master password is still required
# — encryption boundary preserved.
#
# Get your API key from the Bitwarden web vault:
#   Account settings → Security → Keys → "View API Key"
#
# This script:
#   1. If bw is already logged in, skip the API-key step (resumable).
#      Otherwise prompt for client_id/client_secret (skippable) and
#      stash them in macOS Keychain.
#   2. Run `bw login --apikey` (env-var creds, not argv).
#   3. Prompt for the master password (skippable). Stash in Keychain so
#      the seed/add scripts can auto-unlock unattended.
#   4. Unlock and run an initial seed.
#
# Re-running is safe: existing keychain items are overwritten (`-U`).
# To remove cached creds:
#   security delete-generic-password -s bw-api-credentials -a $USER
#   security delete-generic-password -s bw-master-password -a $USER

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
# shellcheck source=bin/lib/bw-common.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/bw-common.sh"

bw_require_cmds bw security || exit 1

# Prompt for a value into the named variable; empty input is an explicit
# skip signal. If $3 == "hidden", echo is suppressed.
prompt_skippable() {
    local prompt="$1" varname="$2" hidden="${3:-}" value
    printf '%s (empty to skip): ' "$prompt" >&2
    if [ "$hidden" = "hidden" ]; then
        stty -echo
        IFS= read -r value
        stty echo
        printf '\n' >&2
    else
        IFS= read -r value
    fi
    printf -v "$varname" '%s' "$value"
}

api_login() {
    local CLIENT_ID CLIENT_SECRET

    prompt_skippable "Bitwarden API client_id" CLIENT_ID
    if [ -z "${CLIENT_ID:-}" ]; then
        echo "Skipping bw bootstrap (no API client_id provided)."
        exit 0
    fi
    prompt_skippable "Bitwarden API client_secret" CLIENT_SECRET hidden
    [ -n "${CLIENT_SECRET:-}" ] \
        || { echo "client_secret required when client_id is set." >&2; exit 1; }

    security add-generic-password \
        -s bw-api-credentials -a "$USER" -U \
        -w "$CLIENT_ID:$CLIENT_SECRET" >/dev/null

    BW_CLIENTID="$CLIENT_ID" BW_CLIENTSECRET="$CLIENT_SECRET" \
        bw login --apikey >/dev/null
}

cache_master_and_seed() {
    local MASTER
    prompt_skippable "Bitwarden master password" MASTER hidden
    if [ -z "${MASTER:-}" ]; then
        echo "Logged in but skipping unlock-cache and initial seed."
        echo "Run later: bash $DOTFILES_DIR/bin/bw-seed-envchain.sh"
        return 0
    fi

    security add-generic-password \
        -s bw-master-password -a "$USER" -U \
        -w "$MASTER" >/dev/null

    # Pass via --passwordenv (scoped to the bw subprocess) — bw on newer
    # Node versions has an inquirer bug that crashes on stdin pipes.
    BW_SESSION=$(BW_PASSWORD="$MASTER" bw unlock --raw --passwordenv BW_PASSWORD)
    unset MASTER
    export BW_SESSION

    bash "$DOTFILES_DIR/bin/bw-seed-envchain.sh"
    echo "bw login + initial envchain seed complete."
}

if bw_is_logged_in; then
    echo "bw already logged in; skipping API-key step."
else
    api_login
fi

cache_master_and_seed
