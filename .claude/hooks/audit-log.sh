#!/bin/bash
# PostToolUse hook: append every tool invocation to
# ~/.claude/audit/<UTC-date>.jsonl. Local-only, append-only, chmod 600.
#
# Stamps with a server-side timestamp (date -u +%FT%TZ) so log lines
# aren't trivially forgeable from data the model controls. Truncates
# the tool response to 500 chars — full response would balloon the log
# without adding evidence (the tool_input is the auditable bit).
#
# Failure is non-fatal: this hook must never block tool use.

set -uo pipefail

audit_dir="${HOME}/.claude/audit"
mkdir -p "$audit_dir" 2>/dev/null || exit 0
chmod 700 "$audit_dir" 2>/dev/null || true

log="$audit_dir/$(date -u +%F).jsonl"
touch "$log" 2>/dev/null || exit 0
chmod 600 "$log" 2>/dev/null || true

ts=$(date -u +%FT%TZ)

if command -v jq >/dev/null 2>&1; then
    jq -c --arg ts "$ts" \
        '{ts:$ts, tool:.tool_name, input:.tool_input, response:(.tool_response|tostring|.[0:500])}' \
        >>"$log" 2>/dev/null || true
else
    # No jq: capture the raw envelope so we at least have evidence.
    {
        printf '{"ts":"%s","raw":' "$ts"
        cat
        printf "}\n"
    } >>"$log" 2>/dev/null || true
fi

exit 0
