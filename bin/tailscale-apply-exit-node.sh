#!/usr/bin/env bash
# Applies the hardcoded Mullvad exit node after login. Retries while
# tailscaled is still handshaking with the control plane.
set -euo pipefail

EXIT_NODE="ca-mtr-wg-001.mullvad.ts.net"
TAILSCALE=/opt/homebrew/bin/tailscale
MAX_ATTEMPTS=20
SLEEP_BETWEEN=3

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*"; }

for i in $(seq 1 "$MAX_ATTEMPTS"); do
    if "$TAILSCALE" status >/dev/null 2>&1; then
        "$TAILSCALE" set --exit-node="$EXIT_NODE" --exit-node-allow-lan-access=true
        log "applied exit node $EXIT_NODE"
        exit 0
    fi
    log "tailscaled not ready (attempt $i/$MAX_ATTEMPTS), sleeping ${SLEEP_BETWEEN}s"
    sleep "$SLEEP_BETWEEN"
done

log "gave up waiting for tailscaled" >&2
exit 1
