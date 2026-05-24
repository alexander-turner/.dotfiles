#!/bin/bash
# harden-monitor.bash — root-own the AI safety monitor so the model
# being monitored cannot tamper with it. Run as root (e.g. via sudo
# in postStartCommand).
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
MONITOR="$WORKSPACE/.claude/hooks/monitor.bash"
MONITOR_LOG_DIR="/home/node/.cache/claude-monitor"

if [[ -f "$MONITOR" ]]; then
    chown root:root "$MONITOR"
    chmod 755 "$MONITOR"
    echo "monitor: hardened $MONITOR (root:root 755)"
else
    echo "monitor: $MONITOR not found, skipping"
fi

mkdir -p "$MONITOR_LOG_DIR"
chown root:root "$MONITOR_LOG_DIR"
chmod 1733 "$MONITOR_LOG_DIR"
echo "monitor: hardened $MONITOR_LOG_DIR (root:root 1733)"

CONF_DIR="/home/node/.config/claude-monitor"
for f in "$CONF_DIR/ntfy.conf" "$CONF_DIR/policy.txt"; do
    if [[ -f "$f" ]]; then
        chown root:root "$f"
        chmod 644 "$f"
        echo "monitor: hardened $f (root:root 644)"
    fi
done
