#!/bin/bash
# Post-start entrypoint: configures the firewall as root, then locks
# it down so the node user cannot modify iptables rules.
#
# Strategy: after the firewall is up, remove the sudoers entry that
# allowed node to run this script, and strip setuid/capabilities from
# network and namespace tools so unprivileged users can't touch them.
set -euo pipefail

/usr/local/bin/init-firewall.bash

echo "Locking down firewall and namespace tools..."

rm -f /etc/sudoers.d/node-firewall

for bin in iptables iptables-save iptables-restore ip6tables ipset \
    ip nft nsenter unshare; do
    path=$(command -v "$bin" 2>/dev/null) || continue
    chmod u-s "$path"
    setcap -r "$path" 2>/dev/null || true
done

SCRUB_VARS=(
    GH_TOKEN GITHUB_TOKEN
    AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    NPM_TOKEN PYPI_TOKEN
    DOCKER_PASSWORD DOCKER_AUTH_CONFIG
)
UNSET_LINES=""
FISH_LINES=""
for var in "${SCRUB_VARS[@]}"; do
    UNSET_LINES+="unset $var;"$'\n'
    FISH_LINES+="set -e $var;"$'\n'
done
echo "$UNSET_LINES" >/etc/profile.d/scrub-secrets.sh
mkdir -p /etc/fish/conf.d
echo "$FISH_LINES" >/etc/fish/conf.d/scrub-secrets.fish

WORKSPACE="/workspace"
if [[ "${CLAUDE_SELF_EDIT:-0}" == "1" ]]; then
    echo "CLAUDE_SELF_EDIT=1 — skipping .claude/ lockdown (supervised mode)."
else
    echo "Making .claude/ config root-owned so the agent cannot modify its own guardrails..."
    if [[ -d "$WORKSPACE/.claude" ]]; then
        chown -R root:root "$WORKSPACE/.claude"
        chmod -R a+r,a-w "$WORKSPACE/.claude"
        chmod a+x "$WORKSPACE/.claude" "$WORKSPACE/.claude/hooks" 2>/dev/null || true
        find "$WORKSPACE/.claude/hooks" -name '*.bash' -exec chmod a+x {} + 2>/dev/null || true
    fi
    echo ".claude/ is root-owned — agent cannot modify its own settings or hooks."
fi

echo "Lockdown complete."
