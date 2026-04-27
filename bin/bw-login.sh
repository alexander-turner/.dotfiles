#!/bin/bash
# One-time-per-machine bw login using a Bitwarden personal API key.
#
# Why API key: WebAuthn-only accounts can't log in via `bw login` interactively
# (bw doesn't support WebAuthn). The personal API key bypasses 2FA for the
# login step; the master password is still required to unlock the vault,
# preserving the encryption boundary.
#
# Get your API key from the Bitwarden web vault:
#   Account settings → Security → Keys → "View API Key"
#
# This script:
#   1. Prompts for client_id/client_secret (skip with empty input).
#   2. Stashes them in the macOS Keychain under service `bw-api-credentials`.
#   3. Runs `bw login --apikey` using BW_CLIENTID/BW_CLIENTSECRET env vars.
#   4. Prompts for the Bitwarden master password (also skippable).
#   5. Stashes it under service `bw-master-password` so the seeder can
#      auto-unlock without re-prompting.
#   6. Performs an initial unlock + seed via bw-seed-envchain.sh.
#
# Re-running the script is safe: existing keychain items are overwritten
# (`-U`). To remove cached credentials:
#   security delete-generic-password -s bw-api-credentials -a $USER
#   security delete-generic-password -s bw-master-password -a $USER

set -euo pipefail

require() {
    command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require bw
require security

DOTFILES_DIR="$(cd "$(dirname "$0")"/.. && pwd)"

prompt_with_default_skip() {
    # $1=prompt, $2=variable name to set, $3="hidden" if password
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

# Skip the API-key login step if bw already has a session (logged in or
# locked). Running bw login --apikey while already logged in is an error,
# and re-prompting the user for credentials they already entered is rude.
if bw status --raw 2>/dev/null | grep -qE '"status":"(locked|unlocked)"'; then
    echo "bw already logged in; skipping API-key step."
else
    prompt_with_default_skip "Bitwarden API client_id" CLIENT_ID
    if [ -z "${CLIENT_ID:-}" ]; then
        echo "Skipping bw bootstrap (no API client_id provided)."
        exit 0
    fi
    prompt_with_default_skip "Bitwarden API client_secret" CLIENT_SECRET hidden
    [ -n "${CLIENT_SECRET:-}" ] || { echo "client_secret required when client_id is set." >&2; exit 1; }

    # Stash API creds (combined as "id:secret" in a single keychain item).
    security add-generic-password \
        -s bw-api-credentials -a "$USER" -U \
        -w "$CLIENT_ID:$CLIENT_SECRET" >/dev/null

    # Login via API key. Values come from env, not argv.
    BW_CLIENTID="$CLIENT_ID" BW_CLIENTSECRET="$CLIENT_SECRET" bw login --apikey >/dev/null
    unset CLIENT_ID CLIENT_SECRET
fi

prompt_with_default_skip "Bitwarden master password" MASTER hidden
if [ -z "${MASTER:-}" ]; then
    echo "Logged in but skipping unlock-cache and initial seed."
    echo "To run the seed manually later: BW_SESSION=\$(bw unlock --raw); bash bin/bw-seed-envchain.sh"
    exit 0
fi

# Cache master password.
security add-generic-password \
    -s bw-master-password -a "$USER" -U \
    -w "$MASTER" >/dev/null

# Unlock and run initial seed. Pass master password via `--passwordenv`
# rather than stdin — bw on newer Node versions has an inquirer bug
# (`ERR_USE_AFTER_CLOSE`) when stdin closes after a piped password.
# BW_PASSWORD is scoped to just the bw subprocess; same threat model as
# the stdin pipe (env vars are not in argv/ps on macOS).
BW_SESSION=$(BW_PASSWORD="$MASTER" bw unlock --raw --passwordenv BW_PASSWORD)
unset MASTER
export BW_SESSION

bash "$DOTFILES_DIR/bin/bw-seed-envchain.sh"

echo "bw login + initial envchain seed complete."
