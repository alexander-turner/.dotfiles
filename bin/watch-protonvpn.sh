#!/bin/bash
# Watches for ProtonVPN and relaunches it when it stops (macOS only).
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "watch-protonvpn.sh: only supported on macOS" >&2
    exit 1
fi

cleanup() { exit 0; }
trap cleanup INT TERM

while true; do
    if ! pgrep -x "ProtonVPN" > /dev/null; then
        open -a "ProtonVPN"
    fi
    sleep 30
done
