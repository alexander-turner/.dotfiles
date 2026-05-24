#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr" 2>/dev/null || true
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "pypi.org" \
    "files.pythonhosted.org" \
    "raw.githubusercontent.com" \
    "objects.githubusercontent.com" \
    "en.wikipedia.org" \
    "en.m.wikipedia.org" \
    "upload.wikimedia.org" \
    "developer.mozilla.org" \
    "docs.python.org" \
    "nodejs.org" \
    "pkg.go.dev" \
    "proxy.golang.org" \
    "docs.rs" \
    "crates.io" \
    "man7.org" \
    "stackoverflow.com" \
    "api.stackexchange.com" \
    "turntrout.com" \
    "www.turntrout.com"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "ERROR: Failed to resolve $domain"
        exit 1
    fi

    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" 2>/dev/null || true
    done < <(echo "$ips")
done

HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

echo "Host gateway detected as: $HOST_IP"

iptables -A INPUT -s "$HOST_IP" -j ACCEPT
iptables -A OUTPUT -d "$HOST_IP" -j ACCEPT

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi

# === DNS allowlist via dnsmasq ===
# Instead of rate-limiting arbitrary DNS (which still allows one-shot
# exfil), run a local resolver that only forwards whitelisted domains.
# Queries for non-allowed domains get NXDOMAIN without ever leaving
# the container — kills DNS exfiltration structurally.
echo "Configuring dnsmasq DNS allowlist..."

DNSMASQ_CONF="/etc/dnsmasq.d/allowlist.conf"
mkdir -p /etc/dnsmasq.d

cat >/etc/dnsmasq.conf <<'DNSMASQ_BASE'
no-resolv
no-hosts
listen-address=127.0.0.1
bind-interfaces
port=53
conf-dir=/etc/dnsmasq.d
DNSMASQ_BASE

# Default: NXDOMAIN for everything not explicitly allowed
echo "address=/#/" >"$DNSMASQ_CONF"

# Forward allowed domains to Docker's embedded resolver
ALLOWED_DOMAINS=(
    "github.com"
    "api.github.com"
    "registry.npmjs.org"
    "api.anthropic.com"
    "pypi.org"
    "files.pythonhosted.org"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    "en.wikipedia.org"
    "en.m.wikipedia.org"
    "upload.wikimedia.org"
    "developer.mozilla.org"
    "docs.python.org"
    "nodejs.org"
    "pkg.go.dev"
    "proxy.golang.org"
    "docs.rs"
    "crates.io"
    "man7.org"
    "stackoverflow.com"
    "api.stackexchange.com"
    "turntrout.com"
    "www.turntrout.com"
)

for domain in "${ALLOWED_DOMAINS[@]}"; do
    echo "server=/$domain/127.0.0.11" >>"$DNSMASQ_CONF"
done

dnsmasq --test && echo "dnsmasq config valid"
dnsmasq
echo "dnsmasq started — $(wc -l <"$DNSMASQ_CONF") rules"

# Replace wide-open DNS rules with locked-down policy:
# - node user can only query dnsmasq (127.0.0.1)
# - dnsmasq (running as dnsmasq user) can query Docker's resolver
# - node user CANNOT bypass dnsmasq to query Docker's resolver directly
iptables -D OUTPUT -p udp --dport 53 -j ACCEPT
iptables -D INPUT -p udp --sport 53 -j ACCEPT

NODE_UID=$(id -u node)
iptables -I OUTPUT 1 -p udp --dport 53 -d 127.0.0.11 \
    -m owner --uid-owner "$NODE_UID" -j REJECT
iptables -I OUTPUT 1 -p udp --dport 53 -d 127.0.0.1 -j ACCEPT
iptables -I OUTPUT 1 -p udp --dport 53 -d 127.0.0.11 -j ACCEPT
iptables -I INPUT 1 -p udp --sport 53 -s 127.0.0.1 -j ACCEPT
iptables -I INPUT 1 -p udp --sport 53 -s 127.0.0.11 -j ACCEPT

# Point system DNS to dnsmasq
cp /etc/resolv.conf /etc/resolv.conf.docker
echo "nameserver 127.0.0.1" >/etc/resolv.conf

# Verify DNS allowlist works
echo "Verifying DNS allowlist..."
if dig +short +timeout=2 @127.0.0.1 api.github.com A | grep -q '^[0-9]'; then
    echo "DNS allowlist passed — allowed domain resolves"
else
    echo "ERROR: DNS allowlist failed — allowed domain did not resolve"
    cat /etc/resolv.conf.docker >/etc/resolv.conf
    exit 1
fi
if dig +short +timeout=2 @127.0.0.1 evil-exfil.example.com A 2>/dev/null | grep -q '^[0-9]'; then
    echo "ERROR: DNS allowlist failed — blocked domain resolved"
    cat /etc/resolv.conf.docker >/etc/resolv.conf
    exit 1
else
    echo "DNS allowlist passed — blocked domain returns NXDOMAIN"
fi
