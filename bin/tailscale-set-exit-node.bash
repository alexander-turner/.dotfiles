#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
# shellcheck source=bin/lib/tailscale-resolve.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/tailscale-resolve.sh"

LOG_DIR="$HOME/Library/Logs/com.turntrout.tailscale-exit-node"
LOG_FILE="$LOG_DIR/menu.log"
mkdir -p "$LOG_DIR"

if ! TAILSCALE="$(find_tailscale)"; then
    printf '%s no working tailscale CLI on PATH\n' "$(date -u +%FT%TZ)" >>"$LOG_FILE"
    exit 127
fi

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >>"$LOG_FILE"; }

host_for() {
    case "$1" in
    us) echo "us-chi-wg-301.mullvad.ts.net" ;;
    ca) echo "ca-mtr-wg-001.mullvad.ts.net" ;;
    jp) echo "jp-tyo-wg-001.mullvad.ts.net" ;;
    off | "") echo "" ;;
    *) return 1 ;;
    esac
}

target="${1-}"
if ! host="$(host_for "$target")"; then
    log "invalid target: $target"
    exit 2
fi

if [ -z "$host" ]; then
    if out=$("$TAILSCALE" set --exit-node= 2>&1); then
        log "disconnected (exit-node cleared)${out:+: $out}"
    else
        rc=$?
        log "FAIL disconnect rc=$rc out=$out"
        exit "$rc"
    fi
else
    if out=$("$TAILSCALE" set --exit-node="$host" --exit-node-allow-lan-access=true 2>&1); then
        log "applied $target → $host${out:+: $out}"
    else
        rc=$?
        log "FAIL apply $target → $host rc=$rc out=$out"
        exit "$rc"
    fi
fi
