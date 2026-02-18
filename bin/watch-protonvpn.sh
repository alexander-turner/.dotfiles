#!/bin/bash
while true; do
    if ! pgrep -x "ProtonVPN" > /dev/null; then
        open -a "ProtonVPN"
    fi
    sleep 30
done
