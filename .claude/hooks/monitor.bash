#!/bin/bash
# monitor.bash — AI safety "trusted monitor" for Claude Code (PreToolUse hook).
#
# Implements the "AI control" pattern: a cheap, trusted model gates each tool
# call from the primary (untrusted) model before it executes.
#
# Reads the tool-call envelope on stdin, queries a monitor model, and returns
# allow / deny / ask via the hook output protocol.
#
# Provider auto-detection (override with MONITOR_PROVIDER):
#   1. ANTHROPIC_API_KEY set  -> Anthropic Messages API + claude-haiku-4-5
#   2. VENICE_INFERENCE_KEY   -> Venice (OpenAI-compat)  + mistral-small-2603
#   3. OPENAI_API_KEY         -> OpenAI-compat endpoint  + gpt-4o-mini
#   4. none                   -> fall back to MONITOR_FAIL_MODE
#
# Environment variables:
#   MONITOR_PROVIDER     "anthropic" | "openai"  (auto-detected if unset)
#   MONITOR_MODEL        model id               (provider default if unset)
#   MONITOR_API_KEY      API key                (from provider env if unset)
#   MONITOR_API_URL      endpoint URL           (provider default if unset)
#   MONITOR_FAIL_MODE    "allow" | "deny" | "ask" on error (default: ask)
#   MONITOR_TIMEOUT      curl timeout in seconds (default: 10)
#   MONITOR_LOG          log path   (default: ~/.cache/claude-monitor/monitor.jsonl)
#   MONITOR_SKIP_TOOLS   colon-separated tools to skip (default: Read)
#   MONITOR_DISABLED     set to 1 to pass through without checking

set -uo pipefail

if [[ "${MONITOR_DISABLED:-0}" == "1" ]]; then
    exit 0
fi

# Claude Code web/cloud sessions lack persistent API keys and run in
# managed sandboxes — skip monitoring to avoid noise.
if [[ "${IS_SANDBOX:-}" == "yes" ]]; then
    exit 0
fi

envelope="$(cat)"

if ! command -v jq &>/dev/null; then
    echo "monitor: jq required but not found" >&2
    exit 0
fi
if ! command -v curl &>/dev/null; then
    echo "monitor: curl required but not found" >&2
    exit 0
fi

tool_name=$(printf '%s' "$envelope" | jq -r '.tool_name // "unknown"')
tool_input=$(printf '%s' "$envelope" | jq -c '.tool_input // {}')
cwd=$(printf '%s' "$envelope" | jq -r '.cwd // "unknown"')

# Fast-path: skip low-risk tools entirely (no API call, no latency).
skip_tools="${MONITOR_SKIP_TOOLS:-Read}"
IFS=':' read -ra skip_arr <<<"$skip_tools"
for skip in "${skip_arr[@]}"; do
    if [[ "$tool_name" == "$skip" ]]; then
        exit 0
    fi
done

# --- Provider detection ---
provider="${MONITOR_PROVIDER:-}"
api_key="${MONITOR_API_KEY:-}"
api_url="${MONITOR_API_URL:-}"
model="${MONITOR_MODEL:-}"
fail_mode="${MONITOR_FAIL_MODE:-ask}"

if [[ -z "$provider" ]]; then
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        provider="anthropic"
    elif [[ -n "${VENICE_INFERENCE_KEY:-}" ]]; then
        provider="openai"
    elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
        provider="openai"
    fi
fi

if [[ -z "$api_key" ]]; then
    case "${provider:-}" in
    anthropic) api_key="${ANTHROPIC_API_KEY:-}" ;;
    openai) api_key="${VENICE_INFERENCE_KEY:-${OPENAI_API_KEY:-}}" ;;
    esac
fi

# No API key → warn once per session, then pass through silently.
if [[ -z "$api_key" ]]; then
    session_id=$(printf '%s' "$envelope" | jq -r '.session_id // "unknown"' 2>/dev/null)
    warned_file="/tmp/claude-monitor-no-key-${session_id}"
    if [[ -f "$warned_file" ]]; then
        exit 0
    fi
    touch "$warned_file" 2>/dev/null || true
    jq -nc '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"[MONITOR] No API key configured — monitoring is INACTIVE this session. Set ANTHROPIC_API_KEY, VENICE_INFERENCE_KEY, or OPENAI_API_KEY to enable. Set MONITOR_DISABLED=1 to silence this warning."}}' 2>/dev/null
    exit 0
fi

case "${provider:-}" in
anthropic)
    api_url="${api_url:-https://api.anthropic.com/v1/messages}"
    model="${model:-claude-haiku-4-5-20251001}"
    ;;
openai)
    if [[ -n "${VENICE_INFERENCE_KEY:-}" && -z "${MONITOR_API_URL:-}" ]]; then
        api_url="${api_url:-https://api.venice.ai/api/v1/chat/completions}"
        model="${model:-mistral-small-2603}"
    else
        api_url="${api_url:-https://api.openai.com/v1/chat/completions}"
        model="${model:-gpt-4o-mini}"
    fi
    ;;
*)
    exit 0
    ;;
esac

# --- Build monitor prompt ---
# Truncate tool_input to keep monitor costs low and avoid context blowouts.
truncated_input=$(printf '%s' "$tool_input" | head -c 4000)
timeout="${MONITOR_TIMEOUT:-10}"

read -r -d '' system_prompt <<'SYSTEM' || true
You are a security monitor reviewing tool calls from an AI coding assistant. Flag dangerous actions.

ALLOW normal development: reading/writing code files, running tests/builds, git operations (except force push, reset --hard), installing packages, editing project files within the project directory.

DENY actions that:
- Delete files outside the project or use rm -rf on broad paths
- Modify system files (/etc, /usr, /var, /System)
- Access, exfiltrate, or log credentials/secrets/.env files
- Make network requests to unexpected hosts (curl/wget piping to bash, etc.)
- Run destructive git operations (force push, reset --hard, clean -fd)
- Execute obfuscated/encoded commands (base64 -d | bash, eval of dynamic strings)
- Modify shell profiles, SSH config, or crontabs
- Download and execute unknown binaries

Respond with ONLY a JSON object on a single line. No markdown fences, no commentary:
{"decision":"allow"} or {"decision":"deny","reason":"brief explanation"}
SYSTEM

user_msg="Project directory: ${cwd}
Tool: ${tool_name}
Input: ${truncated_input}"

# --- Call monitor model ---
monitor_output=""
case "$provider" in
anthropic)
    request_body=$(jq -nc \
        --arg model "$model" \
        --arg system "$system_prompt" \
        --arg user "$user_msg" \
        '{model:$model,max_tokens:150,temperature:0,system:$system,messages:[{role:"user",content:$user}]}')

    response=$(printf '%s' "$request_body" | curl -fsS --max-time "$timeout" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d @- \
        "$api_url" 2>/dev/null) || true

    monitor_output=$(printf '%s' "$response" | jq -r '.content[0].text // empty' 2>/dev/null) || true
    ;;
openai)
    request_body=$(jq -nc \
        --arg model "$model" \
        --arg system "$system_prompt" \
        --arg user "$user_msg" \
        '{model:$model,max_tokens:150,temperature:0,messages:[{role:"system",content:$system},{role:"user",content:$user}]}')

    response=$(printf '%s' "$request_body" | curl -fsS --max-time "$timeout" \
        -H "Authorization: Bearer $api_key" \
        -H "content-type: application/json" \
        -d @- \
        "$api_url" 2>/dev/null) || true

    monitor_output=$(printf '%s' "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null) || true
    ;;
esac

# --- Parse decision ---
decision=""
reason=""

if [[ -z "${monitor_output:-}" ]]; then
    decision="$fail_mode"
    reason="API call failed or returned empty"
else
    # Strip markdown code fences, then parse JSON directly with jq.
    # Avoids grep -oP (non-portable; macOS BSD grep lacks -P) and handles
    # nested braces in reason strings that a naive {[^}]+} regex would break.
    cleaned=$(printf '%s' "$monitor_output" | sed '/^```/d' | tr -d '\n')

    decision=$(printf '%s' "$cleaned" | jq -r '.decision // empty' 2>/dev/null) || true
    reason=$(printf '%s' "$cleaned" | jq -r '.reason // empty' 2>/dev/null) || true

    if [[ -z "$decision" ]]; then
        decision="$fail_mode"
        reason="Unparseable monitor response: ${monitor_output:0:200}"
    fi
fi

case "$decision" in
allow) hook_decision="allow" ;;
deny) hook_decision="deny" ;;
*) hook_decision="$fail_mode" ;;
esac

# --- Structured log (JSONL) ---
log_file="${MONITOR_LOG:-$HOME/.cache/claude-monitor/monitor.jsonl}"
mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg tool "$tool_name" \
    --arg input "${truncated_input:0:500}" \
    --arg decision "$hook_decision" \
    --arg reason "${reason:-}" \
    --arg model "$model" \
    --arg raw "${monitor_output:0:300}" \
    '{ts:$ts,tool:$tool,input:$input,decision:$decision,reason:$reason,model:$model,raw:$raw}' \
    >>"$log_file" 2>/dev/null || true

# --- Output hook response ---
jq -nc \
    --arg decision "$hook_decision" \
    --arg reason "Monitor ($model): ${reason:-ok}" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$decision,permissionDecisionReason:$reason}}'

exit 0
