#!/bin/bash
# PreToolUse hook: desktop-notify when Claude is about to run a Bash
# command that's destructive or hard to reverse. Always returns 0 —
# this is a heads-up, not a gate. The matcher in settings.json scopes
# this to Bash; this script does the regex filter on the actual command.
#
# Pairs with notify.sh by synthesizing its envelope.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

envelope=$(cat || true)
[[ -z "$envelope" ]] && exit 0

cmd=$(jq -r '.tool_input.command // empty' <<<"$envelope" 2>/dev/null)
[[ -z "$cmd" ]] && exit 0

# Tight list — broad globs fire on every other turn and the user tunes
# them out. Each entry is a clear "hard-to-reverse" verb.
danger_re='(rm[[:space:]]+-([rRf]+|fr)[[:space:]]|git[[:space:]]+push[[:space:]]+(-f|--force)|git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]]+-[fdx]+|git[[:space:]]+branch[[:space:]]+-D|bw[[:space:]]+delete|envchain[[:space:]]+--unset|launchctl[[:space:]]+(unload|bootout)|sudo[[:space:]]+rm[[:space:]])'

if [[ "$cmd" =~ $danger_re ]]; then
    msg="Destructive Bash: ${cmd:0:120}"
    printf '{"message":%s}' \
        "$(jq -Rn --arg m "$msg" '$m')" |
        bash "$(dirname "$0")/notify.sh" >/dev/null 2>&1 || true
fi

exit 0
