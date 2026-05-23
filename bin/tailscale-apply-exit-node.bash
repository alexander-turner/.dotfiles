#!/usr/bin/env bash
# Applies the default Mullvad exit node after login, retrying while
# tailscaled is still handshaking with the control plane.
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
# shellcheck source=bin/lib/tailscale-resolve.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/tailscale-resolve.sh"

DEFAULT_COUNTRY="${TAILSCALE_DEFAULT_COUNTRY:-ca}"
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*"; }

TAILSCALE="$(find_tailscale)" || {
    log "no working tailscale CLI" >&2
    exit 127
}
for i in $(seq 1 20); do
    "$TAILSCALE" status >/dev/null 2>&1 &&
        exec "$DOTFILES_DIR/bin/tailscale-set-exit-node.bash" "$DEFAULT_COUNTRY"
    log "tailscaled not ready (attempt $i/20), sleeping 3s"
    sleep 3
done
log "gave up waiting for tailscaled" >&2
exit 1
