#!/bin/bash
# Post-start entrypoint: configures the firewall as root, then locks
# it down so the node user cannot modify iptables rules.
#
# Strategy: after the firewall is up, remove the sudoers entry that
# allowed node to run this script, strip setuid/capabilities from
# the iptables/ipset binaries, and scrub sensitive env vars from the
# node user's environment so they can't leak to child processes.
set -euo pipefail

/usr/local/bin/init-firewall.bash

echo "Locking down firewall tools..."

rm -f /etc/sudoers.d/node-firewall

for bin in iptables iptables-save iptables-restore ip6tables ipset; do
    path=$(command -v "$bin" 2>/dev/null) || continue
    chmod u-s "$path" 2>/dev/null || true
    setcap -r "$path" 2>/dev/null || true
done

echo "Scrubbing sensitive environment variables..."
ENV_SCRUB_FILE="/home/node/.env_scrub.sh"
cat > "$ENV_SCRUB_FILE" << 'SCRUB'
# Sourced by shell profiles to unset leaked host env vars.
# Patterns: tokens, keys, secrets, passwords, credentials.
while IFS='=' read -r name _; do
    case "$name" in
        *TOKEN*|*SECRET*|*KEY*|*PASS*|*CREDENTIAL*|*AUTH*)
            case "$name" in
                # Keep vars the container itself needs to function
                NODE_OPTIONS|NPM_CONFIG_*|CLAUDE_CONFIG_DIR|CLAUDE_CODE_VERSION|\
                POWERLEVEL9K_*|HOME|USER|SHELL|TERM|PATH|LANG|LC_*|TZ|\
                DEVCONTAINER|DOTFILES_TOOLS|EDITOR|VISUAL)
                    ;;
                *)
                    unset "$name"
                    ;;
            esac
            ;;
    esac
done < <(env)
SCRUB
chown node:node "$ENV_SCRUB_FILE"
chmod 644 "$ENV_SCRUB_FILE"

# Inject into bash/fish profile so it runs for every new shell
BASH_PROFILE="/home/node/.bashrc"
if ! grep -q "env_scrub" "$BASH_PROFILE" 2>/dev/null; then
    echo 'source "$HOME/.env_scrub.sh"' >> "$BASH_PROFILE"
fi

echo "Firewall locked — node user cannot modify iptables rules."
echo "Sensitive env vars will be scrubbed in new shells."
