#!/bin/bash
# Dispatch wrapper for the monitor hook. Prefers the sidecar container
# (full process/filesystem isolation) when available, falls back to the
# local root-owned monitor for non-compose environments.
set -uo pipefail

SOCKET="/var/run/monitor/monitor.sock"
MONITOR="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/monitor.bash"
CHECKSUM_FILE="/etc/claude-monitor/monitor.sha256"

# --- Sidecar (full isolation) ---
if [[ -S "$SOCKET" ]]; then
    exec curl -s --max-time 30 --unix-socket "$SOCKET" \
        -X POST -H "Content-Type: application/json" -d @- \
        http://localhost/check
fi

# --- Local fallback: readable monitor (non-hardened host) ---
if [[ -r "$MONITOR" ]]; then
    exec bash "$MONITOR"
fi

# --- Local fallback: root-owned monitor with integrity check ---
if [[ -f "$CHECKSUM_FILE" ]]; then
    expected=$(cat "$CHECKSUM_FILE")
    actual=$(sudo sha256sum "$MONITOR" | awk '{print $1}')
    if [[ "$expected" != "$actual" ]]; then
        echo '{"decision":"ask","reason":"monitor.bash integrity check failed — file may have been tampered with"}' >&2
        exit 1
    fi
fi

exec sudo bash "$MONITOR"
