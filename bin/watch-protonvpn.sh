#!/bin/bash
# Watches for ProtonVPN and relaunches it when it stops (macOS only).
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "watch-protonvpn.sh: only supported on macOS" >&2
    exit 1
fi

log() { logger -t watch-protonvpn "$*"; }

sleep_pid=0
cleanup() { log "watcher stopped"; kill "$sleep_pid" 2>/dev/null; exit 0; }
trap cleanup INT TERM

log "watcher started"
while true; do
    if ! pgrep -x "ProtonVPN" > /dev/null; then
        if [ -d "/Applications/ProtonVPN.app" ]; then
            log "ProtonVPN not running; relaunching"
            open -a "ProtonVPN"
        fi
    fi
    # Background sleep so the trap fires immediately; track PID to kill it cleanly.
    sleep 30 & sleep_pid=$!; wait "$sleep_pid"
done
