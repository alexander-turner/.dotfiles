# shellcheck shell=bash
# keychain_ensure_unlocked — make sure the macOS login keychain is open
# before envchain (or anything else that needs the Security framework)
# tries to write. On headless macs the keychain doesn't auto-unlock at
# boot, so without this `envchain --set` fails with errSecInteractionNotAllowed
# (rc -25308). No-op on non-macOS.
#
# Caches the keychain password at $HOME/.config/dotfiles/keychain-password
# (mode 0600 in a 0700 dir) so subsequent runs unlock without prompting.

keychain_ensure_unlocked() {
    [ "$(uname)" = "Darwin" ] || return 0
    local kc="$HOME/Library/Keychains/login.keychain-db"
    # Probe: looking up a guaranteed-missing item reports "interaction is
    # not allowed" to stderr when the keychain is locked, and a benign
    # "could not be found" when unlocked.
    if ! security find-generic-password -s __dotfiles_lock_probe__ -a "$USER" 2>&1 >/dev/null |
        grep -q "interaction is not allowed"; then
        return 0
    fi

    local cache="$HOME/.config/dotfiles/keychain-password"
    local pw
    if [ -f "$cache" ]; then
        pw=$(cat "$cache")
        if security unlock-keychain -p "$pw" "$kc" 2>/dev/null; then
            unset pw
            security set-keychain-settings "$kc" 2>/dev/null || true
            return 0
        fi
        unset pw
        # Stale cache — fall through to interactive prompt.
    fi

    if [ ! -t 0 ]; then
        echo "keychain: locked and no usable cache at $cache (non-interactive shell)" >&2
        return 1
    fi

    printf 'macOS keychain is locked. Enter login password to unlock: ' >&2
    local saved_tty
    saved_tty=$(stty -g)
    stty -echo
    IFS= read -r pw || pw=""
    stty "$saved_tty"
    printf '\n' >&2

    if security unlock-keychain -p "$pw" "$kc" 2>/dev/null; then
        mkdir -p "$(dirname "$cache")"
        chmod 0700 "$(dirname "$cache")"
        (umask 077 && printf '%s' "$pw" >"$cache")
        unset pw
        security set-keychain-settings "$kc" 2>/dev/null || true
        return 0
    fi

    unset pw
    echo "keychain: unlock-keychain rejected the password" >&2
    return 1
}
