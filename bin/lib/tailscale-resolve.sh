# shellcheck shell=bash
# find_tailscale — print an absolute path to a *working* `tailscale` CLI.
#
# A leftover /usr/local/bin/tailscale shim from the (uninstalled) Mac App
# Store Tailscale exec's a missing binary and silently breaks every
# caller. `command -v` alone can't tell good from bad, so each candidate
# is probed with `tailscale version` before being returned.

find_tailscale() {
    local candidate
    for candidate in /opt/homebrew/bin/tailscale /usr/local/bin/tailscale; do
        if [ -x "$candidate" ] && "$candidate" version >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    local from_path
    from_path="$(command -v tailscale 2>/dev/null || true)"
    if [ -n "$from_path" ] && "$from_path" version >/dev/null 2>&1; then
        printf '%s\n' "$from_path"
        return 0
    fi
    return 1
}
