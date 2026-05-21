#!/bin/bash
# statusLine: one short line shown in the Claude Code UI.
#
# Receives JSON on stdin from Claude Code, e.g.
#   {"model":{"id":"...","display_name":"..."},
#    "workspace":{"current_dir":"..."},
#    "permission_mode":"default"}
#
# Output: single line, no trailing newline expected by the UI, no ANSI
# escapes (the UI styles its own chrome).

set -uo pipefail

payload=""
if [[ ! -t 0 ]]; then
    payload=$(cat || true)
fi

model="claude"
cwd="$PWD"
mode=""

if command -v jq >/dev/null 2>&1 && [[ -n "$payload" ]]; then
    model=$(jq -r '.model.display_name // .model.id // "claude"' <<<"$payload" 2>/dev/null || echo claude)
    cwd=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$payload" 2>/dev/null)
    mode=$(jq -r '.permission_mode // empty' <<<"$payload" 2>/dev/null)
    [[ -z "$cwd" ]] && cwd="$PWD"
fi

# Collapse $HOME to ~ and elide long paths so the chrome stays one line.
short_cwd="${cwd/#$HOME/\~}"
if [[ ${#short_cwd} -gt 40 ]]; then
    short_cwd=".../$(basename "$cwd")"
fi

branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null ||
        git -C "$cwd" rev-parse --short HEAD 2>/dev/null ||
        true)
fi

parts=("$model" "$short_cwd")
[[ -n "$branch" ]] && parts+=("git:$branch")
[[ -n "$mode" && "$mode" != "default" ]] && parts+=("[$mode]")

(
    IFS=' · '
    printf '%s' "${parts[*]}"
)
