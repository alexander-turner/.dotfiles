#!/bin/bash
# UserPromptSubmit hook: refuse prompts that look like they contain a
# real secret. The unredacted prompt would otherwise be sent to the
# model and persisted with the conversation.
#
# Block patterns mirror the gitleaks built-in rule set so anything that
# would be rejected at commit-time is rejected at prompt-time too.
# Allowlist intentionally tighter than .gitleaks.toml's — false positives
# here are cheap (resubmit), false negatives are not.
#
# Exit codes:
#   0 — clean, allow submission
#   2 — block; stderr surfaced to the user as the rejection reason
#   * — soft-fail (jq missing, etc.) treated as allow; see below.
#
# Bypass: set CLAUDE_ALLOW_SECRETS=1 in your shell to override.

set -uo pipefail

# Soft-fail when jq is missing — better to fall back to no-scan than to
# break every prompt. The same prompt will still be caught at commit-time
# by gitleaks. Document this in .claude/README.md so it isn't a surprise.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

prompt=$(jq -r '.prompt // empty' 2>/dev/null)
[[ -z "$prompt" ]] && exit 0

# High-precision patterns only. Anything looser (raw hex blobs, generic
# "password=") trips on legitimate code reviews and trains the user to
# always set CLAUDE_ALLOW_SECRETS=1, defeating the gate.
patterns=(
    'AKIA[0-9A-Z]{16}' # AWS access key id
    'ASIA[0-9A-Z]{16}' # AWS STS access key id
    'aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{40}'
    'ghp_[A-Za-z0-9]{36,}'               # GitHub PAT (classic)
    'gho_[A-Za-z0-9]{36,}'               # GitHub OAuth
    'ghs_[A-Za-z0-9]{36,}'               # GitHub server-to-server
    'ghu_[A-Za-z0-9]{36,}'               # GitHub user-to-server
    'github_pat_[A-Za-z0-9_]{82,}'       # GitHub fine-grained PAT
    'sk-ant-[A-Za-z0-9_-]{50,}'          # Anthropic API key
    'sk-[A-Za-z0-9]{32,}'                # OpenAI / Venice style
    'xoxb-[0-9A-Za-z-]{10,}'             # Slack bot token
    'xoxp-[0-9A-Za-z-]{10,}'             # Slack user token
    'glpat-[A-Za-z0-9_-]{20,}'           # GitLab PAT
    '-----BEGIN [A-Z ]*PRIVATE KEY-----' # PEM private keys
)

for pat in "${patterns[@]}"; do
    if printf '%s' "$prompt" | grep -Eq "$pat"; then
        if [[ "${CLAUDE_ALLOW_SECRETS:-0}" == "1" ]]; then
            echo "scan-input: CLAUDE_ALLOW_SECRETS=1 set; allowing match /$pat/." >&2
            exit 0
        fi
        # Don't echo the matching span — that would re-leak the secret
        # into the user-visible reason. Just name the pattern.
        echo "scan-input: refused — prompt matches secret pattern /$pat/" >&2
        echo "Rotate the credential first, then retry. Override (not recommended): CLAUDE_ALLOW_SECRETS=1" >&2
        exit 2
    fi
done

exit 0
