#!/bin/bash
# statusline.bash — Claude Code status line showing model, branch, context, and cost.
# Receives session JSON on stdin; outputs a compact two-line status.

set -uo pipefail

if ! command -v jq &>/dev/null; then
    echo "model:? | branch:?"
    exit 0
fi

data=$(cat)

model=$(printf '%s' "$data" | jq -r '.model // "?"')
# Shorten common model prefixes for display.
model="${model#venice,}"
model="${model#anthropic/}"

branch=$(git branch --show-current 2>/dev/null || echo "?")
repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "?")

context_used=$(printf '%s' "$data" | jq -r '.contextTokens // 0')
context_max=$(printf '%s' "$data" | jq -r '.maxContextTokens // 1')
cost=$(printf '%s' "$data" | jq -r '.totalCost // 0')
duration=$(printf '%s' "$data" | jq -r '.durationMs // 0')

if [[ "$context_max" -gt 0 ]] 2>/dev/null; then
    pct=$((context_used * 100 / context_max))
else
    pct=0
fi

ctx_k=$((context_used / 1000))
max_k=$((context_max / 1000))

if [[ "$duration" -gt 0 ]] 2>/dev/null; then
    mins=$((duration / 60000))
    secs=$(((duration % 60000) / 1000))
    elapsed="${mins}m${secs}s"
else
    elapsed="0m0s"
fi

cost_fmt=$(printf '%.2f' "$cost" 2>/dev/null || echo "0.00")

# Context bar: green < 60%, yellow < 85%, red >= 85%.
if [[ "$pct" -lt 60 ]]; then
    color="\033[32m"
elif [[ "$pct" -lt 85 ]]; then
    color="\033[33m"
else
    color="\033[31m"
fi
nc="\033[0m"

printf '%s | %s/%s | %s\n' "$model" "$repo" "$branch" "$elapsed"
printf "${color}ctx ${ctx_k}k/${max_k}k (${pct}%%)${nc} | \$${cost_fmt}\n"
