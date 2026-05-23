#!/usr/bin/env bash
# <bitbar.title>VPN</bitbar.title>
# <bitbar.author>turntrout</bitbar.author>
# <bitbar.desc>Status and control for Tailscale Mullvad exit node.</bitbar.desc>

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
APPLY="$DOTFILES_DIR/bin/tailscale-set-exit-node.bash"
# shellcheck source=../../bin/lib/tailscale-resolve.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/tailscale-resolve.sh"
TAILSCALE="$(find_tailscale || echo /opt/homebrew/bin/tailscale)"

flag_for() {
    case "$1" in
    us) echo "🇺🇸" ;;
    ca) echo "🇨🇦" ;;
    jp) echo "🇯🇵" ;;
    *) echo "🟢" ;;
    esac
}

node_for() {
    case "$1" in
    us) echo "us-chi-wg-301.mullvad.ts.net" ;;
    ca) echo "ca-mtr-wg-001.mullvad.ts.net" ;;
    jp) echo "jp-tyo-wg-001.mullvad.ts.net" ;;
    esac
}

current_line=$("$TAILSCALE" status 2>/dev/null | awk '/mullvad\.ts\.net.*exit node/ {print; exit}')
current_host=$(echo "$current_line" | awk '{print $2}')
current_country=${current_host:0:2}
if echo "$current_line" | grep -q "active"; then
    current_state="active"
else
    current_state="idle"
fi

if [ -z "$current_host" ]; then
    echo "🔴 off"
else
    flag=$(flag_for "$current_country")
    if [ "$current_state" = "active" ]; then
        echo "$flag $current_country"
    else
        echo "$flag $current_country (idle)"
    fi
fi

echo "---"

if [ -n "$current_host" ]; then
    echo "$current_host | font=Menlo size=11"
    echo "state: $current_state | font=Menlo size=11"
    echo "---"
fi

for c in us ca jp; do
    flag=$(flag_for "$c")
    node=$(node_for "$c")
    if [ "$c" = "$current_country" ]; then
        echo "$flag $c ✓ | shell=$APPLY param1=$c terminal=false refresh=true"
    else
        echo "$flag $c — $node | shell=$APPLY param1=$c terminal=false refresh=true"
    fi
done

if [ -n "$current_host" ]; then
    echo "---"
    echo "🔴 Disconnect | shell=$APPLY param1=off terminal=false refresh=true"
fi

echo "---"
echo "Refresh | refresh=true"
