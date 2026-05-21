#!/bin/bash
# Egress firewall for the dotfiles devcontainer.
#
# Default-DROP for OUTPUT; allow only:
#   * loopback, established/related, DNS, SSH
#   * the host subnet (so the IDE bridge keeps working)
#   * a curated allowlist of domains (resolved at boot)
#   * GitHub's published web/api/git CIDR ranges
#
# Run by postCreateCommand via sudo. Re-runs safely: phase 1 flushes
# everything so the boot resolves DNS even if a previous run already
# locked things down.
set -euo pipefail

if [[ "$(id -u)" != "0" ]]; then
    echo "init-firewall.bash: must run as root (try 'sudo')." >&2
    exit 1
fi

# ── Phase 1: open everything so DNS + GitHub meta lookup works ──────────────
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
ipset destroy allowed-domains 2>/dev/null || true

ALLOW_DOMAINS=(
    registry.npmjs.org
    api.anthropic.com
    statsig.anthropic.com
    statsig.com
    sentry.io
    pypi.org
    files.pythonhosted.org
    github.com
    api.github.com
    objects.githubusercontent.com
    codeload.github.com
    raw.githubusercontent.com
)

resolved=()
for d in "${ALLOW_DOMAINS[@]}"; do
    while IFS= read -r ip; do
        [[ -n "$ip" ]] && resolved+=("$ip")
    done < <(dig +short +time=2 +tries=2 "$d" A | grep -E '^[0-9.]+$' || true)
done

gh_ranges=()
if meta_json=$(curl -fsS --max-time 5 https://api.github.com/meta 2>/dev/null); then
    while IFS= read -r cidr; do
        [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]] && gh_ranges+=("$cidr")
    done < <(printf '%s' "$meta_json" | jq -r '.web[]?, .api[]?, .git[]?' 2>/dev/null || true)
fi

# ── Phase 2: lock down ──────────────────────────────────────────────────────
ipset create allowed-domains hash:net
for ip in ${resolved[@]+"${resolved[@]}"}; do
    ipset add allowed-domains "$ip" 2>/dev/null || true
done
for cidr in ${gh_ranges[@]+"${gh_ranges[@]}"}; do
    ipset add allowed-domains "$cidr" 2>/dev/null || true
done

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS + SSH stay open
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Host subnet — keep the IDE bridge working
default_gw=$(ip route | awk '/default/ {print $3; exit}')
if [[ -n "${default_gw:-}" ]]; then
    host_net="${default_gw%.*}.0/24"
    iptables -A OUTPUT -d "$host_net" -j ACCEPT
    iptables -A INPUT -s "$host_net" -j ACCEPT
fi

iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

echo "init-firewall: ${#ALLOW_DOMAINS[@]} domains (${#resolved[@]} IPs) + ${#gh_ranges[@]} GitHub CIDRs allowed."
