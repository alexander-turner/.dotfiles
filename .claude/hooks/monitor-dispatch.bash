#!/bin/bash
# Dispatch wrapper for the monitor hook. This file is intentionally
# readable — it contains no policy or detection logic. The real
# monitor is root:root 700 in the devcontainer so the monitored
# model can't read it for vulnerabilities or evasion patterns.
set -uo pipefail
MONITOR="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/monitor.bash"
if [[ -r "$MONITOR" ]]; then
    exec bash "$MONITOR"
else
    exec sudo bash "$MONITOR"
fi
