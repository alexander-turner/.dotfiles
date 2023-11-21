#!/bin/bash
# Download the latest keyboard configuration
curl -s -L "https://oryx.zsa.io/rXDjb/latest/binary" -o "/tmp/ergodox.hex"

# Install it with wally-cli
wally-cli "/tmp/ergodox.hex"
