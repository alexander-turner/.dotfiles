#!/bin/bash
# Download and flash the latest keyboard configuration.
# KEYBOARD_BINARY_URL can be overridden to point to a different Oryx layout.
set -euo pipefail

URL="${KEYBOARD_BINARY_URL:-https://oryx.zsa.io/rXDjb/latest/binary}"
HEX=$(mktemp /tmp/ergodox-XXXXXX.hex)
trap 'rm -f "$HEX"' EXIT

if ! curl -fsSL "$URL" -o "$HEX"; then
    echo "keyboard_flash.bash: failed to download firmware from $URL" >&2
    exit 1
fi

wally-cli "$HEX"
