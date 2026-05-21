#!/bin/bash
# Cross-platform desktop notification for Claude Code's Notification hook.
# Reads JSON on stdin (Claude Code's hook envelope) and surfaces the
# message field via the platform's native notifier:
#   * macOS  → osascript display notification
#   * Linux  → notify-send (via libnotify)
# A no-op when neither is available (e.g. headless sessions).

set -uo pipefail

# stdin is the hook envelope; extract .message, fall back to a generic
# string if jq is missing or parsing fails.
msg=""
if command -v jq >/dev/null 2>&1; then
    msg=$(jq -r '.message // empty' 2>/dev/null || true)
fi
[ -z "$msg" ] && msg="Claude Code needs your attention"

case "$(uname)" in
Darwin)
    # `display notification` truncates long bodies; trim aggressively.
    safe=${msg//\"/\\\"}
    osascript -e "display notification \"${safe:0:200}\" with title \"Claude Code\"" >/dev/null 2>&1 || true
    ;;
Linux)
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --app-name="Claude Code" "Claude Code" "$msg" || true
    fi
    ;;
esac

exit 0
