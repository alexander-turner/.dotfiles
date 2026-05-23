# shellcheck shell=bash
# Tailscale CLI + Mullvad exit-node config — single source of truth.
#
# A leftover /usr/local/bin/tailscale shim from the (uninstalled) Mac App
# Store Tailscale exec's a missing binary, so `command -v` alone isn't
# enough — each candidate is probed with `tailscale version`.

# "code flag host"  — append a row to add a country.
# shellcheck disable=SC2034
TAILSCALE_EXIT_NODES=(
    "us 🇺🇸 us-chi-wg-301.mullvad.ts.net"
    "ca 🇨🇦 ca-mtr-wg-001.mullvad.ts.net"
    "jp 🇯🇵 jp-tyo-wg-001.mullvad.ts.net"
)

# Print "flag host" for $1 (country code). Non-zero on unknown code.
tailscale_node_lookup() {
    local row
    for row in "${TAILSCALE_EXIT_NODES[@]}"; do
        [ "${row%% *}" = "$1" ] && printf '%s\n' "${row#* }" && return 0
    done
    return 1
}

# Print absolute path to a working tailscale CLI; non-zero if none found.
find_tailscale() {
    local c
    for c in /opt/homebrew/bin/tailscale /usr/local/bin/tailscale \
        "$(command -v tailscale 2>/dev/null || true)"; do
        [ -n "$c" ] && [ -x "$c" ] && "$c" version >/dev/null 2>&1 && {
            printf '%s\n' "$c"
            return 0
        }
    done
    return 1
}
