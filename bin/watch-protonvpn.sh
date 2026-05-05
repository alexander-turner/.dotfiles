#!/bin/bash
# Watches for ProtonVPN and relaunches it when it stops (macOS only).
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "watch-protonvpn.sh: only supported on macOS" >&2
    exit 1
fi

log() { logger -t watch-protonvpn "$*"; }

cleanup() { log "watcher stopped"; exit 0; }
trap cleanup INT TERM

log "watcher started"
while true; do
    if ! pgrep -x "ProtonVPN" > /dev/null; then
        if [ -d "/Applications/ProtonVPN.app" ]; then
            log "ProtonVPN not running; relaunching"
            open -a "ProtonVPN"
        fi
    fi
    # Background sleep so the trap fires immediately on SIGTERM/SIGINT.
    sleep 30 & wait $!
done
