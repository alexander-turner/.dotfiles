#!/usr/bin/env bash
# <bitbar.title>VPN</bitbar.title>
# <bitbar.author>turntrout</bitbar.author>
# <bitbar.desc>Status and control for Tailscale Mullvad exit node.</bitbar.desc>

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
# shellcheck source=../../bin/lib/tailscale-resolve.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/tailscale-resolve.sh"

APPLY="$DOTFILES_DIR/bin/tailscale-set-exit-node.bash"
TAILSCALE="$(find_tailscale || echo /opt/homebrew/bin/tailscale)"

line=$("$TAILSCALE" status 2>/dev/null | awk '/mullvad\.ts\.net.*exit node/ {print; exit}')
host=$(awk '{print $2}' <<<"$line")
country=${host:0:2}
state=$(grep -q active <<<"$line" && echo active || echo idle)

if [ -z "$host" ]; then
    echo "🔴 off"
else
    flag=$(tailscale_node_lookup "$country" | awk '{print $1}')
    [ "$state" = active ] && echo "$flag $country" || echo "$flag $country (idle)"
fi
echo "---"

if [ -n "$host" ]; then
    printf '%s | font=Menlo size=11\nstate: %s | font=Menlo size=11\n---\n' "$host" "$state"
fi

for row in "${TAILSCALE_EXIT_NODES[@]}"; do
    read -r c flag node <<<"$row"
    if [ "$c" = "$country" ]; then
        echo "$flag $c ✓ | shell=$APPLY param1=$c terminal=false refresh=true"
    else
        echo "$flag $c — $node | shell=$APPLY param1=$c terminal=false refresh=true"
    fi
done

if [ -n "$host" ]; then
    echo "---"
    echo "🔴 Disconnect | shell=$APPLY param1=off terminal=false refresh=true"
fi

echo "---"
echo "Refresh | refresh=true"
