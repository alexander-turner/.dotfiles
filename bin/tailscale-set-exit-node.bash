#!/usr/bin/env bash
set -euo pipefail
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_DIR="${DOTFILES_DIR:-$(git -C "$_self_dir" rev-parse --show-toplevel)}"
# shellcheck source=bin/lib/tailscale-resolve.sh disable=SC1091
source "$DOTFILES_DIR/bin/lib/tailscale-resolve.sh"

LOG="$HOME/Library/Logs/com.turntrout.tailscale-exit-node/menu.log"
mkdir -p "${LOG%/*}"
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >>"$LOG"; }

target="${1-off}"
case "$target" in
off | "") host="" ;;
*) host="$(tailscale_node_lookup "$target" | awk '{print $2}')" ||
    {
        log "invalid target: $target"
        exit 2
    } ;;
esac

TAILSCALE="$(find_tailscale)" || {
    log "no working tailscale CLI"
    exit 127
}
args=(set "--exit-node=$host")
[ -n "$host" ] && args+=(--exit-node-allow-lan-access=true)

if out=$("$TAILSCALE" "${args[@]}" 2>&1); then
    log "${target} → ${host:-off}${out:+: $out}"
else
    rc=$?
    log "FAIL ${target} → ${host:-off} rc=$rc out=$out"
    exit "$rc"
fi
