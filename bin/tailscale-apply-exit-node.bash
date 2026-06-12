#!/usr/bin/env bash
# Applies the default Mullvad exit node after login, retrying while
# tailscaled is still handshaking with the control plane.
set -euo pipefail
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_DIR="${DOTFILES_DIR:-$(git -C "$_self_dir" rev-parse --show-toplevel)}"
# shellcheck source=bin/lib/tailscale-resolve.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/tailscale-resolve.sh"

DEFAULT_COUNTRY="${TAILSCALE_DEFAULT_COUNTRY:-ca}"
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*"; }

TAILSCALE="$(find_tailscale)" || {
    log "no working tailscale CLI" >&2
    exit 127
}
health=unknown
for i in $(seq 1 20); do
    health="$(tailscale_health "$TAILSCALE")"
    case "$health" in
    ok | stopped)
        exec "$DOTFILES_DIR/bin/tailscale-set-exit-node.bash" "$DEFAULT_COUNTRY"
        ;;
    logged-out)
        # Interactive browser re-auth required — retrying can't fix this.
        log "tailscaled is logged out; cannot apply exit node — run: tailscale up" >&2
        exit 1
        ;;
    esac
    log "tailscaled not ready ($health, attempt $i/20), sleeping 3s"
    sleep 3
done
log "gave up waiting for tailscaled (last health: $health)" >&2
exit 1
